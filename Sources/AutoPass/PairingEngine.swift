import Cocoa
import ApplicationServices
import CryptoKit
import AutoPassCore

/// Watches trusted browsers and Apple's helper. When a pairing code appears it re-checks every rule in
/// `PairingPolicy`, asks for approval if configured, and types the code into the browser's popup, one
/// verified digit at a time. By default it also opens the popup itself once the user is browsing, and
/// closes it again when pairing is done, so the whole thing is over in about a second.
actor PairingEngine {
    private struct RunningBrowser {
        let app: NSRunningApplication
        let trusted: TrustedBrowser
        var pid: pid_t { app.processIdentifier }
    }

    private struct HelperRecord {
        var parentPID: pid_t
        /// pid@startTime; lets a pairing be remembered across AutoPass restarts.
        var identity: String?
        /// We saw this helper start while AutoPass was running, so its session is known to be fresh (unpaired).
        /// Otherwise we don't know whether it was already paired before AutoPass launched.
        var seenSpawning: Bool
        var paired = false
    }

    /// Bookkeeping for AutoPass opening the popup, per browser process. Per browser (not per helper) because
    /// a fresh browser has no helper at all until something opens the extension.
    private struct BrowserRecord {
        var attempts = 0
        var nextAttemptAt = Date.distantPast
        var popupOpenedAt: Date?
        /// The user asked for it with Pair Now.
        var userRequested = false
        /// A helper existed (so the extension was already running) when we opened the popup.
        var helperExistedAtOpen = false
        var helperWasFresh = false
        /// How many times in a row this browser's pairing was interrupted (for spacing out the retries).
        var interruptions = 0
    }

    /// `interrupted` means something outside AutoPass got in the way (you typed, switched windows, cancelled an approval, no window
    /// was open yet). It never counts as a failure, and AutoPass tries again once things are calm.
    private enum OpenResult { case opened, failed, extensionMissing, interrupted }

    // Timings: everything here is tuned to feel instant while still waiting for the page and the user.
    private enum Timing {
        static let idleTick: Duration = .milliseconds(250)
        static let hotTick: Duration = .milliseconds(25)       // while a pairing is under way
        static let hotWindow: TimeInterval = 5                 // how long after opening the popup to stay on the fast tick
        static let browserSettle: TimeInterval = 0.6           // browser has been running this long
        static let userPause: TimeInterval = 0.5               // no keys/clicks/scrolling before AutoPass acts on its own
        static let pageSettle: TimeInterval = 0.15             // a web page has been showing this long
        static let codeWait: TimeInterval = 2.0                // after AutoPass opens the popup, how long to wait for a code
        static let codeWaitUserRequested: TimeInterval = 1.4   // after Pair Now: answer quickly if it was already paired
        static let extensionsMenuWait: TimeInterval = 2.0      // how long to wait for the Extensions menu to list iCloud Passwords
    }

    private let sink: EngineSink
    private let browserScanner = BrowserScanner()

    private var policy: SecurityPolicy
    /// iCloud Passwords is found by this part of its name (it's the same in every browser).
    private let toolbarHint = "iCloud"
    /// Keep the popup out of sight while pairing runs (restored if it can't finish). Apple's own window is never moved.
    private var hideWindows: Bool
    private let windowWatch = WindowWatch()
    private let helperObserver = HelperWindowObserver()
    /// The popup as last scanned, so the moment Apple's window appears it can be re-checked cheaply instead of rescanned.
    private var popupCache: [pid_t: (reading: PopupReading, at: Date)] = [:]
    private var pausedUntil: Date?
    /// Signing IDs of browsers AutoPass has been told to leave alone (Pair Now still works for them).
    private var pausedBrowserIDs = Set<String>()
    private var loop: Task<Void, Never>?
    private var busy = false
    /// When AutoPass itself started. A helper that started earlier has a session of unknown state (maybe already paired).
    private let appStartTime = ProcessInspector.startTime(of: getpid()) ?? 0

    private var helpers: [pid_t: HelperRecord] = [:]
    private var browserRecords: [pid_t: BrowserRecord] = [:]
    private var browsingSince: [pid_t: Date] = [:]
    private var limiter = AttemptLimiter()
    private var lastApproval: Date?
    private var handledCodes = Set<String>()          // typed or declined; fingerprints only, never codes
    private var lastDenial: [pid_t: Denial] = [:]
    private var denialSince: [pid_t: (denial: Denial, since: Date)] = [:]
    private var focusAttempted = Set<String>()
    /// Browsers (by process) where iCloud Passwords wasn't in the toolbar or the Extensions menu.
    private var extensionMissing = Set<pid_t>()
    private var probedBrowsers = Set<pid_t>()
    /// Stay on the fast tick until this time (set when AutoPass opens the popup).
    private var hotUntil = Date.distantPast
    /// Timestamps of the current pairing, for one timing line in the log.
    private var pairClock: (start: Date, popup: Date?, seen: Date?, typing: Date?, typed: Date?)?
    /// A hard refusal for one code window isn't re-evaluated every tick.
    private var skipUntil: [String: Date] = [:]
    /// Close Apple's code window the moment the code has been read, instead of leaving it open while typing. Turned off for the
    /// session if pairing ever fails right after doing it.
    private var closeHelperEarly = true
    /// Per helper process: signed by Apple, and which extension it was started for. Neither changes while it runs.
    private var helperFacts: [pid_t: (signedByApple: Bool, extensionID: String?)] = [:]
    private var trustCache: [pid_t: (browser: TrustedBrowser?, flags: [String], at: Date)] = [:]
    private var runningCache: (at: Date, list: [RunningBrowser])?
    private var wantsHealth = false
    private var lastHealthAt = Date.distantPast
    private var lastStatus: EngineStatus?
    private var lastTrace: [String: String] = [:]
    private var lastFrontBrowserPID: pid_t?
    /// Helper processes known to be paired, as pid@startTime. Persisted so restarting AutoPass doesn't re-probe them.
    private var pairedIdentities: Set<String> = Set(UserDefaults.standard.stringArray(forKey: "pairedHelpers") ?? [])

    init(policy: SecurityPolicy, hideWindows: Bool, sink: EngineSink) {
        self.policy = policy
        self.hideWindows = hideWindows
        self.sink = sink
    }

    // MARK: Control surface (called from the UI)

    func start() {
        guard loop == nil else { return }
        // Apple's code window is handled the instant the helper reports it, not on the next tick.
        helperObserver.onWindow = { [weak self] pid in Task { await self?.helperWindowAppeared(pid) } }
        loop = Task { [weak self] in
            while !Task.isCancelled {
                let hot = await self?.tick() ?? false
                try? await Task.sleep(for: hot ? Timing.hotTick : Timing.idleTick)
            }
        }
    }

    func stop() { loop?.cancel(); loop = nil }
    func update(policy: SecurityPolicy) { self.policy = policy.sanitized(); trustCache.removeAll(); runningCache = nil }
    func setHealthDemand(_ on: Bool) { wantsHealth = on; if on { lastHealthAt = .distantPast } }

    func setBrowserPaused(signingID: String, name: String, _ paused: Bool) {
        if paused { pausedBrowserIDs.insert(signingID) } else { pausedBrowserIDs.remove(signingID) }
        log(.info, paused ? "Paused \(name)" : "Resumed \(name)")
        lastHealthAt = .distantPast
    }

    func setPaused(_ paused: Bool, minutes: Int? = nil) {
        pausedUntil = paused ? (minutes.map { Date().addingTimeInterval(Double($0) * 60) } ?? .distantFuture) : nil
        log(.info, paused ? "Paused" : "Resumed")
    }

    /// User-initiated: open iCloud Passwords in a trusted browser right now. With no browser given, uses the frontmost
    /// trusted browser, else the one you were last in. Clicking in AutoPass's own window makes AutoPass frontmost, so the
    /// browser is brought forward first (activation has to be yielded to it explicitly on current macOS).
    func pairNow(browserPID: pid_t? = nil) async {
        guard !busy else { log(.info, "AutoPass is busy. Try again in a moment."); return }
        guard AX.isTrusted(prompt: false) else { publish(.needsAccessibility); return }
        busy = true; defer { busy = false }

        let running = runningTrustedBrowsers()
        let frontPID = NSWorkspace.shared.frontmostApplication?.processIdentifier
        let target = browserPID.flatMap { id in running.first { $0.pid == id } }
            ?? running.first { $0.pid == frontPID }
            ?? lastFrontBrowserPID.flatMap { id in running.first { $0.pid == id } }
            ?? running.first
        guard let browser = target else {
            log(.warning, "None of your trusted browsers is open."); publish(.attention("No trusted browser is open")); return
        }
        let name = browser.trusted.name

        guard await bringForward(browser) else {
            log(.warning, "AutoPass couldn't bring \(name) forward."); publish(.attention("Couldn't bring \(name) forward")); return
        }

        // Don't mark the browser unpaired up front: if it's already paired and the attempt fails for some other reason,
        // the status must keep saying so. A code window appearing is what proves it isn't paired.
        extensionMissing.remove(browser.pid)
        // One deliberate attempt: the automatic logic must not press the button again behind it.
        browserRecords[browser.pid] = BrowserRecord(attempts: 1, nextAttemptAt: Date().addingTimeInterval(30))
        log(.info, "Pairing with \(name)")
        if await openPopup(browser, reason: "Pair iCloud Passwords with \(name)", userInitiated: true) == .opened {
            markPopupOpened(browserPID: browser.pid, userRequested: true)
        }
    }

    // MARK: Main loop

    /// Returns true while a helper window is on screen (the caller then polls faster).
    private func tick() async -> Bool {
        guard AX.isTrusted(prompt: false) else { publish(.needsAccessibility); return false }
        if let until = pausedUntil {
            if Date() < until { publish(.paused); return false }
            pausedUntil = nil
            log(.info, "Pause ended")
        }

        if let front = NSWorkspace.shared.frontmostApplication?.processIdentifier,
           runningTrustedBrowsers().contains(where: { $0.pid == front }) { lastFrontBrowserPID = front }

        let readings = HelperScanner.scan()
        track(readings)
        if let unreadable = readings.first(where: { $0.hasWindow && $0.code == nil }) {
            trace("Apple's helper has a window but no readable 6-digit code: \(unreadable.shape)")
        }

        if !busy {
            if let reading = readings.first(where: { $0.code != nil }) {
                await handleCodeWindow(reading, allWithCode: readings.filter { $0.code != nil })
            } else {
                await considerProactive()
                await checkCodeTimeouts()
            }
        }
        if !busy { publishIdleStatus() }
        if wantsHealth, Date().timeIntervalSince(lastHealthAt) > 3 { lastHealthAt = Date(); sink.health(computeHealth()) }
        return readings.contains { $0.code != nil } || Date() < hotUntil
    }

    private func track(_ readings: [HelperReading]) {
        let live = Set(readings.map(\.pid))
        for pid in helpers.keys where !live.contains(pid) {
            helpers[pid] = nil; lastDenial[pid] = nil; denialSince[pid] = nil; helperFacts[pid] = nil
            helperObserver.unwatch(pid: pid)
        }
        for r in readings where helpers[r.pid] == nil {
            let predatesAutoPass = (r.startTime ?? Int.max) < appStartTime
            var record = HelperRecord(parentPID: r.parentPID, identity: r.identity, seenSpawning: !predatesAutoPass)
            if let id = r.identity, pairedIdentities.contains(id) { record.paired = true }     // paired before AutoPass restarted
            helpers[r.pid] = record
            helperObserver.watch(pid: r.pid)
            _ = helperFactsFor(r.pid)                                 // signature and extension ID, ready before any window shows
            _ = trustCheck(pid: r.parentPID)                          // likewise the browser's
            browserRecords[r.parentPID]?.attempts = 0                 // a new helper is a new session
            extensionMissing.remove(r.parentPID)                      // the extension is running after all
        }
        let runningPIDs = Set(NSWorkspace.shared.runningApplications.map(\.processIdentifier))
        for pid in browserRecords.keys where !runningPIDs.contains(pid) { browserRecords[pid] = nil; browsingSince[pid] = nil }
        extensionMissing = extensionMissing.filter { runningPIDs.contains($0) }
        let now = Date()
        trustCache = trustCache.filter { now.timeIntervalSince($0.value.at) < 10 }
    }

    /// One status for every running trusted browser: anything not yet paired takes priority over what is.
    private func publishIdleStatus() {
        let running = runningTrustedBrowsers()
        guard !running.isEmpty else { publish(.idle); return }
        var unpaired: [RunningBrowser] = [], paired: [RunningBrowser] = []
        for b in running {
            let mine = helpers.values.filter { $0.parentPID == b.pid }
            if !mine.isEmpty && mine.allSatisfy(\.paired) { paired.append(b) } else { unpaired.append(b) }
        }
        func names(_ list: [RunningBrowser]) -> String { list.map(\.trusted.name).joined(separator: " and ") }
        if !unpaired.isEmpty {
            let canAuto = policy.autoPair == .whenBrowsing && unpaired.contains { (browserRecords[$0.pid]?.attempts ?? 0) < 2 }
            publish(canAuto ? .waiting(names(unpaired)) : .watching(names(unpaired)))
        } else {
            publish(.paired(names(paired)))
        }
    }

    // MARK: A code is on screen

    /// Called the moment Apple's helper reports a new window: start handling the code right away. The window's text can take a few
    /// milliseconds to appear, so it's read until it does.
    func helperWindowAppeared(_ pid: pid_t) async {
        guard !busy else { return }
        for _ in 0..<20 {
            let readings = HelperScanner.scan()
            let withCode = readings.filter { $0.code != nil }
            if let reading = withCode.first(where: { $0.pid == pid }) ?? withCode.first {
                track(readings)
                await handleCodeWindow(reading, allWithCode: withCode)
                return
            }
            guard readings.contains(where: { $0.pid == pid && $0.hasWindow }) else { return }
            try? await Task.sleep(for: .milliseconds(3))
        }
    }

    private func handleCodeWindow(_ reading: HelperReading, allWithCode: [HelperReading]) async {
        let key = fingerprint(reading)
        guard !handledCodes.contains(key) else { return }
        if let until = skipUntil[key], Date() < until { return }
        browserRecords[reading.parentPID]?.popupOpenedAt = nil    // a code arrived: the "no code" timer is moot
        if let trusted = trustCheck(pid: reading.parentPID).0, pausedBrowserIDs.contains(trusted.signingID) {
            trace("\(trusted.name) is paused; leaving Apple's code window alone", key: "paused"); return
        }
        trace("code window seen for helper \(reading.pid) (parent \(reading.parentPID))", key: "codeseen-\(reading.pid)")
        if pairClock?.seen == nil { pairClock?.seen = Date() }

        var (facts, popup) = gatherFacts(reading, allWithCode: allWithCode)
        if let denial = PairingPolicy.evaluate(facts, policy: policy, rateLimited: isRateLimited()) {
            // A popup opened by hand sometimes doesn't take keyboard focus. If everything else about it checks
            // out (Apple's page, six empty boxes), focus the first box once, like clicking into it would.
            if denial == .popupNotFocused, let popup, focusAttempted.insert(key).inserted,
               let first = popup.fields.first {
                AXUIElementSetAttributeValue(first, kAXFocusedAttribute as CFString, kCFBooleanTrue)
                return
            }
            noteDenial(denial, for: reading.pid)
            restoreWindows(browserPID: reading.parentPID)                                  // AutoPass won't fill it: show it
            if !denial.isTransient { skipUntil[key] = Date().addingTimeInterval(1) }      // a real refusal: don't re-check every tick

            // A popup that's been typed into, or has been waiting a long time, is no use any more: start over with a fresh one
            // instead of refusing forever.
            let waited = denialSince[reading.pid].map { Date().timeIntervalSince($0.since) } ?? 0
            let dirty = denial == .popupNotEmpty || denial == .popupNotFocused
            if (dirty && waited > 1.5) || (denial.isTransient && waited > 25) {
                handledCodes.insert(key)
                log(.info, "AutoPass is starting over because the popup was in the way.")
                await abandonPopup(browserPID: reading.parentPID)
                scheduleRetry(browserPID: reading.parentPID)
            }
            return
        }
        lastDenial[reading.pid] = nil
        denialSince[reading.pid] = nil

        busy = true; defer { busy = false }
        let browserName = browserName(for: reading.parentPID)
        var latest = reading                                      // the most recent read of Apple's window (its Done button)

        if policy.approval != .none {
            guard await approveIfNeeded(reason: "Enter the iCloud Passwords verification code in \(browserName)") else {
                handledCodes.insert(key)                 // declined: don't prompt again for this same code
                restoreWindows(browserPID: reading.parentPID)
                return
            }
            // Approval takes time; the world may have changed. Look again, and apply every rule again.
            guard let again = HelperScanner.scan().first(where: { $0.pid == reading.pid }), again.code == reading.code else {
                // Typically the popup closed when the approval prompt took focus. The approval is remembered,
                // so opening iCloud Passwords again fills in without a second prompt.
                log(.info, "The popup closed while waiting for approval. Open iCloud Passwords again and AutoPass will fill it in without asking again.")
                publish(.attention("Open iCloud Passwords again"))
                restoreWindows(browserPID: reading.parentPID)
                return
            }
            latest = again
            (facts, popup) = gatherFacts(again, allWithCode: HelperScanner.scan().filter { $0.code != nil })
            if let denial = PairingPolicy.evaluate(facts, policy: policy, rateLimited: isRateLimited()) {
                log(.warning, "AutoPass didn't type the code. \(denial.message)")
                restoreWindows(browserPID: reading.parentPID); return
            }
        }
        guard let code = reading.code, let popup else { restoreWindows(browserPID: reading.parentPID); return }
        hidePopups([popup], browserPID: reading.parentPID)                                // keep the popup out of sight for the typing

        handledCodes.insert(key)
        publish(.typing)
        pairClock?.typing = Date()
        var closedEarly = false
        let outcome = await type(code, popup: popup, browserPID: reading.parentPID, helperPID: reading.pid) { [self] in
            // Everything is checked and the keys are about to go: the code has been read, so the window can close now.
            if closeHelperEarly, HelperScanner.dismiss(latest) { closedEarly = true }
        }
        switch outcome {
        case .success:
            markPaired(helper: reading.pid)
            extensionMissing.remove(reading.parentPID)
            log(.info, "Paired with \(browserName)")
            publish(.paired(browserName))
            pairClock?.typed = Date()
            await closePopup(browserPID: reading.parentPID)
            WindowHider.shared.finish(owner: reading.parentPID)                 // anything left behind is shown again
            windowWatch.stop()
            browserRecords[reading.parentPID]?.attempts = 0
            browserRecords[reading.parentPID]?.interruptions = 0
            if let c = pairClock, let popup = c.popup, let seen = c.seen, let typing = c.typing, let typed = c.typed {
                func ms(_ a: Date, _ b: Date) -> Int { Int(b.timeIntervalSince(a) * 1000) }
                trace("timing ms: open \(ms(c.start, popup)), Apple's window appears \(ms(popup, seen)), checks \(ms(seen, typing)), type and confirm \(ms(typing, typed)), close \(ms(typed, Date())), total \(ms(c.start, Date()))", key: "timing")
            }
            pairClock = nil
        case .interrupted(let why):
            // Not a failure: you (or the browser) got in the way. Clean up and try again once things are calm.
            log(.info, "AutoPass paused because \(why). It will try again.")
            restoreWindows(browserPID: reading.parentPID)
            await abandonPopup(browserPID: reading.parentPID)
            scheduleRetry(browserPID: reading.parentPID)
        case .failed(let why):
            if hasHiddenWindows(browserPID: reading.parentPID) {
                restoreWindows(browserPID: reading.parentPID)
                hideWindows = false                                       // it failed while the popup was hidden; stop doing that
                trace("pairing failed while the popup was hidden; hiding is off for this session")
                log(.info, "AutoPass turned off hiding the popup because that pairing didn't finish.")
            }
            if closedEarly {
                closeHelperEarly = false          // closing the window early may be what broke it; go back to leaving it open
                trace("pairing failed after closing Apple's window early; leaving it open from now on")
            }
            limiter.record()                      // only real failures count toward the attempt limit
            browserRecords[reading.parentPID, default: BrowserRecord()].attempts += 1
            log(.warning, "AutoPass stopped because \(why).")
            publish(.attention("Pairing stopped"))
            await abandonPopup(browserPID: reading.parentPID)
        }
    }

    /// Closes a popup that can't be used any more (it's half filled, or the pairing was interrupted) so the next attempt starts clean.
    /// The page's own ✕ works without the browser being in front; Escape is the fallback.
    private func abandonPopup(browserPID: pid_t) async {
        popupCache[browserPID] = nil
        let popups = browserScanner.extensionPopups(pid: browserPID)
        guard popups.count == 1, let popup = popups.first else { return }              // the browser already closed it
        if let close = popup.closeButton, browserScanner.press(close) { return }
        if NSWorkspace.shared.frontmostApplication?.processIdentifier == browserPID,
           let focused = browserScanner.focusedPageURL(pid: browserPID), ICloudExtension.isOfficialPopupURL(focused) {
            KeyInjector.escape(toPID: browserPID)
        }
    }

    /// After an interruption: try again in a moment, a little later each time it keeps happening. Never counts as a failure.
    private func scheduleRetry(browserPID: pid_t) {
        browserRecords[browserPID, default: BrowserRecord()].interruptions += 1
        let delay = RetryBackoff.delay(afterInterruptions: browserRecords[browserPID]?.interruptions ?? 1)
        browserRecords[browserPID]?.nextAttemptAt = Date().addingTimeInterval(delay)
        browserRecords[browserPID]?.popupOpenedAt = nil
    }

    private func gatherFacts(_ h: HelperReading, allWithCode: [HelperReading]) -> (PairingFacts, PopupReading?) {
        var f = PairingFacts()
        let facts = helperFactsFor(h.pid)
        f.helperIsAppleSigned = facts.signedByApple
        f.helperExtensionID = facts.extensionID
        f.helperParentPID = h.parentPID
        f.codeWindowsForBrowser = allWithCode.filter { $0.parentPID == h.parentPID }.count
        f.code = h.code
        f.userIdleSeconds = Input.keyboardIdleSeconds()

        let bpid = h.parentPID
        let (trusted, flags) = trustCheck(pid: bpid)
        f.browserMatchesTrusted = trusted != nil
        f.browserLaunchFlags = flags
        f.browserIsFrontmost = NSWorkspace.shared.frontmostApplication?.processIdentifier == bpid

        // Only look inside a browser we already trust.
        guard f.browserMatchesTrusted else { return (f, nil) }
        // The popup was scanned when it opened; re-reading just its values and focus is far cheaper than scanning again.
        var popups: [PopupReading]
        if let cached = popupCache[bpid], Date().timeIntervalSince(cached.at) < 3, let fresh = browserScanner.refresh(cached.reading, pid: bpid) {
            popups = [fresh]
        } else {
            popups = browserScanner.extensionPopups(pid: bpid)
            if popups.count == 1 { popupCache[bpid] = (popups[0], Date()) }
        }
        f.popupCount = popups.count
        guard let popup = popups.first else { return (f, nil) }
        f.popupOwnerPID = bpid
        f.popupURL = popup.url
        f.popupFieldCount = popup.fields.count
        f.popupFieldsEmpty = popup.values.allSatisfy { $0.isEmpty }
        f.popupFirstFieldFocused = popup.focusedIndex == 0
        return (f, popups.count == 1 ? popup : nil)
    }

    private func helperFactsFor(_ pid: pid_t) -> (signedByApple: Bool, extensionID: String?) {
        if let cached = helperFacts[pid] { return cached }
        let computed = (signedByApple: CodeSigning.process(pid, satisfies: ICloudExtension.helperRequirement),
                        extensionID: ICloudExtension.extensionID(fromHelperArguments: ProcessInspector.arguments(of: pid)))
        helperFacts[pid] = computed
        return computed
    }

    // MARK: Hiding windows while pairing

    /// Hides the popup AutoPass opened (if the watcher hasn't already). If the browser won't let it move, it just stays where it is.
    private func hidePopups(_ popups: [PopupReading], browserPID: pid_t) {
        guard hideWindows else { return }
        let popupWindows = popups.compactMap(\.window)
        for window in popupWindows { WindowHider.shared.hide(window, owner: browserPID) }
        trace("\(browserName(for: browserPID)): popup hidden \(WindowHider.shared.isHiding(owner: browserPID))", key: "hidepopup-\(browserPID)")
    }

    /// Puts hidden windows back where they were, so a person can see and use them.
    private func restoreWindows(browserPID: pid_t) {
        windowWatch.stop()
        WindowHider.shared.restore(owner: browserPID)
    }

    private func hasHiddenWindows(browserPID: pid_t) -> Bool { WindowHider.shared.isHiding(owner: browserPID) }

    /// Signature + launch flags of a browser process, cached for a few seconds (neither can change while it runs).
    private func trustCheck(pid: pid_t) -> (TrustedBrowser?, [String]) {
        if let c = trustCache[pid], Date().timeIntervalSince(c.at) < 10 { return (c.browser, c.flags) }
        var result: (TrustedBrowser?, [String]) = (nil, [])
        for browser in policy.enabledBrowsers {
            if let requirement = browser.codeRequirement, CodeSigning.process(pid, satisfies: requirement) {
                result = (browser, LaunchFlags.findRisky(in: ProcessInspector.arguments(of: pid)))
                break
            }
        }
        trustCache[pid] = (result.0, result.1, Date())
        return result
    }

    private func noteDenial(_ denial: Denial, for pid: pid_t) {
        // Transient states (popup still loading, you're mid-keystroke) are normal for a moment; only report
        // them if they persist.
        if denial.isTransient {
            if denialSince[pid]?.denial != denial { denialSince[pid] = (denial, Date()) }
            guard let since = denialSince[pid]?.since, Date().timeIntervalSince(since) >= 4 else { return }
        }
        trace("code window present but not typing yet: \(denial.message)")
        guard lastDenial[pid] != denial else { return }       // log each distinct reason once
        lastDenial[pid] = denial
        log(.warning, "AutoPass didn't type the code. \(denial.message)")
        switch denial {
        case .browserNotTrusted, .riskyFlags, .helperNotApple, .helperExtensionUnknown, .rateLimited:
            publish(.attention("AutoPass didn't fill in the code"))
        default: break
        }
    }

    private func isRateLimited() -> Bool {
        limiter.isLimited(max: policy.maxAttempts, window: Double(policy.attemptWindowMinutes) * 60)
    }

    private func fingerprint(_ r: HelperReading) -> String {
        let digest = SHA256.hash(data: Data("\(r.pid):\(r.code ?? "")".utf8))
        return digest.prefix(8).map { String(format: "%02x", $0) }.joined()
    }

    // MARK: Typing

    /// `interrupted`: you or the browser got in the way (retry when calm). `failed`: a real failure (counts toward the attempt limit).
    private enum TypeOutcome { case success, interrupted(String), failed(String) }

    /// Types the six digits as one quick burst. Everything is checked first (the popup is Apple's, its six boxes are
    /// empty, the first has focus, the browser is in front), `beforeTyping` runs once those pass (it closes Apple's code
    /// window), and the result is confirmed from the popup: it moves on to its paired view, or closes itself. A rejected
    /// code shows up as the helper issuing a new one.
    private func type(_ code: String, popup: PopupReading, browserPID: pid_t, helperPID: pid_t,
                      beforeTyping: () -> Void) async -> TypeOutcome {
        let appEl = AX.app(browserPID)
        let fields = popup.fields
        guard fields.count == 6 else { return .interrupted("the popup changed") }
        guard NSRunningApplication(processIdentifier: browserPID) != nil else { return .interrupted("the browser quit") }
        if NSWorkspace.shared.frontmostApplication?.processIdentifier != browserPID {
            return .interrupted("you switched away from the browser")
        }
        let first = BrowserScanner.frame(fields[0])
        guard let focus = AX.focused(appEl), BrowserScanner.sameSpot(BrowserScanner.frame(focus), first) else { return .interrupted("the selection moved off the first box") }
        guard AX.string(fields[0], kAXValueAttribute)?.isEmpty == true else { return .interrupted("the code boxes weren't empty") }

        beforeTyping()
        let keysBefore = Input.keyDownCount()
        guard KeyInjector.typeBurst(Array(code), toPID: browserPID) else { return .failed("it couldn't send the keys") }
        let userKeys = Input.keyDownCount() != keysBefore

        func helperRejected() -> Bool {
            guard let now = HelperScanner.scan().first(where: { $0.pid == helperPID }), let newCode = now.code else { return false }
            return newCode != code
        }

        // The boxes took the code, or the popup already moved on.
        var landed = false
        for _ in 0..<60 {                                                    // up to ~0.9 s, normally the first poll
            let popups = browserScanner.extensionPopups(pid: browserPID)
            if popups.isEmpty { landed = true; break }                       // closed itself after a good code
            if popups.count == 1 {
                if popups[0].fields.isEmpty { return .success }              // already on the paired view
                if popups[0].values.joined() == code { landed = true; break }
            }
            if helperRejected() { return .failed("Apple's helper rejected the code") }
            try? await Task.sleep(for: .milliseconds(15))
        }
        guard landed else { return userKeys ? .interrupted("you pressed a key while it was typing") : .failed("the code didn't go into the boxes") }

        // The extension submits on the sixth digit. The popup leaving its code view is the helper accepting it.
        for _ in 0..<200 {                                                   // up to ~3 s
            let popups = browserScanner.extensionPopups(pid: browserPID)
            if popups.isEmpty { return .success }
            if popups.count == 1, popups[0].fields.isEmpty { return .success }
            if helperRejected() { return .failed("Apple's helper rejected the code") }
            try? await Task.sleep(for: .milliseconds(15))
        }
        return .failed("Apple's popup didn't confirm the pairing")
    }

    // MARK: Opening and closing the popup (automatic pairing)

    private func considerProactive() async {
        guard policy.autoPair == .whenBrowsing else { trace("auto-pair is off", key: "proactive"); return }
        let now = Date()
        guard let front = NSWorkspace.shared.frontmostApplication else { return }
        guard let browser = runningTrustedBrowsers().first(where: { $0.pid == front.processIdentifier }) else {
            browsingSince.removeAll(); trace("frontmost app is not a trusted browser", key: "proactive"); return
        }
        let name = browser.trusted.name
        guard !pausedBrowserIDs.contains(browser.trusted.signingID) else { trace("\(name): paused", key: "proactive"); return }
        let record = browserRecords[browser.pid] ?? BrowserRecord()
        let mine = helpers.values.filter { $0.parentPID == browser.pid }
        // No helper means no session: the extension hasn't been started, so it's certainly unpaired.
        if !mine.isEmpty, mine.allSatisfy(\.paired) { trace("\(name): already paired", key: "proactive"); return }
        guard record.attempts < 2 else { trace("\(name): gave up after 2 attempts", key: "proactive"); return }
        guard record.popupOpenedAt == nil else { return }                       // a popup we opened is still being waited on
        guard now >= record.nextAttemptAt else { return }

        // Cheap gates first: the browser has settled and you've stopped to look at something.
        guard now.timeIntervalSince(browser.app.launchDate ?? .distantPast) >= Timing.browserSettle else { trace("\(name): just launched", key: "proactive"); return }
        let idle = Input.idleSeconds()
        guard idle >= max(policy.minimumIdleSeconds, Timing.userPause), !Input.mouseButtonDown() else {
            trace("\(name): waiting for you to pause", key: "proactive"); return
        }

        browserRecords[browser.pid, default: BrowserRecord()].nextAttemptAt = now.addingTimeInterval(0.25)  // throttle the tree walk below
        guard browserScanner.isBrowsingWebPage(pid: browser.pid) else {
            browsingSince[browser.pid] = nil
            trace("\(name): no web page visible: \(browserScanner.describeBrowsing(pid: browser.pid))", key: "proactive"); return
        }
        let since = browsingSince[browser.pid] ?? now
        browsingSince[browser.pid] = since
        guard now.timeIntervalSince(since) >= Timing.pageSettle else { trace("\(name): page settling", key: "proactive"); return }

        busy = true; defer { busy = false }
        trace("opening iCloud Passwords in \(name) (helpers running: \(mine.count))", key: "proactive")
        let result = await openPopup(browser, reason: "Pair iCloud Passwords with \(name)", userInitiated: false)
        switch result {
        case .opened:
            browserRecords[browser.pid, default: BrowserRecord()].nextAttemptAt = Date().addingTimeInterval(8)
            markPopupOpened(browserPID: browser.pid, userRequested: false)
        case .interrupted:
            // Something got in the way before it could finish: not a failure. Try again soon.
            scheduleRetry(browserPID: browser.pid)
            trace("\(name): interrupted; will try again", key: "proactive")
        case .failed:
            browserRecords[browser.pid, default: BrowserRecord()].attempts += 1
            browserRecords[browser.pid]?.nextAttemptAt = Date().addingTimeInterval(5)
            trace("\(name): could not open the popup (see Activity)", key: "proactive")
        case .extensionMissing:
            break
        }
    }

    private func markPopupOpened(browserPID: pid_t, userRequested: Bool) {
        let helper = helpers.first { $0.value.parentPID == browserPID }?.value
        browserRecords[browserPID, default: BrowserRecord()].popupOpenedAt = Date()
        browserRecords[browserPID]?.userRequested = userRequested
        browserRecords[browserPID]?.helperExistedAtOpen = helper != nil
        browserRecords[browserPID]?.helperWasFresh = helper?.seenSpawning ?? false
    }

    /// What the browser's Apple popup is showing, for classifying "no code appeared".
    private enum PopupState { case pairedView, codeEntry, gone }

    private func popupState(browserPID: pid_t) -> PopupState {
        let popups = browserScanner.extensionPopups(pid: browserPID)
        guard popups.count == 1 else { return .gone }
        return popups[0].fields.isEmpty ? .pairedView : .codeEntry
    }

    /// After AutoPass opened the popup, Apple's helper should show a code within a moment. If it doesn't, the popup
    /// itself says why: a paired session shows its credentials view (no code boxes), while a locked-out or stalled
    /// helper leaves the six empty boxes up.
    private func checkCodeTimeouts() async {
        for (bpid, rec) in browserRecords {
            guard let opened = rec.popupOpenedAt else { continue }
            let wait = rec.userRequested ? Timing.codeWaitUserRequested : Timing.codeWait
            guard Date().timeIntervalSince(opened) > wait else { continue }
            browserRecords[bpid]?.popupOpenedAt = nil
            let name = browserName(for: bpid)
            let mine = helpers.filter { $0.value.parentPID == bpid }
            let state = popupState(browserPID: bpid)
            trace("\(name): popup opened \(Int(wait))s ago and Apple's helper never showed a code (helpers running: \(mine.count), popup: \(state))", key: "timeout")

            func alreadyPaired() async {
                for key in mine.keys { markPaired(helper: key) }
                log(.info, "\(name) is already paired")
                publish(.paired(name))
                await closePopup(browserPID: bpid)
                WindowHider.shared.finish(owner: bpid)
                windowWatch.stop()
            }

            if mine.isEmpty {
                restoreWindows(browserPID: bpid)
                browserRecords[bpid]?.attempts = 2
                log(.warning, "Apple's helper didn't start for \(name). Make sure iCloud Passwords is turned on in \(name).")
                continue
            }
            switch state {
            case .pairedView:
                await alreadyPaired()
            case .codeEntry:
                restoreWindows(browserPID: bpid)
                browserRecords[bpid]?.attempts = 2
                log(.warning, "Apple's helper isn't showing a code in \(name). It may be locked out after wrong codes, so try again in a few minutes.")
            case .gone:
                // The popup closed before a code appeared. If you were typing or switched away, the browser closes its popups
                // when it loses focus; that's an interruption, so try again once you're back.
                let youGotInTheWay = NSWorkspace.shared.frontmostApplication?.processIdentifier != bpid
                    || Input.idleSeconds() < Date().timeIntervalSince(opened)
                restoreWindows(browserPID: bpid)
                if youGotInTheWay {
                    log(.info, "The popup closed in \(name) because you were busy. AutoPass will try again.")
                    scheduleRetry(browserPID: bpid)
                } else if (rec.helperExistedAtOpen && !rec.helperWasFresh) || rec.userRequested {
                    await alreadyPaired()
                } else {
                    browserRecords[bpid]?.attempts += 1
                    scheduleRetry(browserPID: bpid)
                    log(.warning, "The popup closed in \(name) before a code appeared. AutoPass will try again.")
                }
            }
        }
    }

    /// Closes Apple's popup once the extension has left the code-entry view. Escape is fast and reliable, but only goes
    /// to the browser, and only if Apple's popup has focus; otherwise (or if it doesn't take) the page's own ✕ link is pressed.
    private func closePopup(browserPID: pid_t) async {
        popupCache[browserPID] = nil
        var target: PopupReading?
        for _ in 0..<160 {                                                 // up to ~2.5 s for the extension to finish pairing
            let popups = browserScanner.extensionPopups(pid: browserPID)
            if popups.isEmpty { trace("popup already closed"); return }    // it closed itself
            if popups.count == 1, popups[0].fields.isEmpty, ICloudExtension.isOfficialPopupURL(popups[0].url) { target = popups[0]; break }
            try? await Task.sleep(for: .milliseconds(15))
        }
        guard let popup = target else { trace("not closing the popup: it never left the code-entry view"); return }

        func closed(within ms: Int) async -> Bool {
            for _ in 0..<(ms / 20) {
                try? await Task.sleep(for: .milliseconds(20))
                if browserScanner.extensionPopups(pid: browserPID).isEmpty { return true }
            }
            return false
        }

        if NSWorkspace.shared.frontmostApplication?.processIdentifier == browserPID,
           let focused = browserScanner.focusedPageURL(pid: browserPID), ICloudExtension.isOfficialPopupURL(focused) {
            KeyInjector.escape(toPID: browserPID)
            if await closed(within: 300) { trace("closed the popup with Escape"); return }
            trace("Escape didn't close the popup")
        } else {
            trace("Apple's popup doesn't have focus; skipping Escape")
        }
        if let close = popup.closeButton, browserScanner.press(close), await closed(within: 450) { trace("closed the popup with its ✕"); return }
        trace("couldn't close the popup; leaving it open")
    }

    /// Brings a browser to the front. Clicking in AutoPass's own window (or an approval prompt) takes the front, and
    /// activation has to be yielded to the browser explicitly on current macOS.
    private func bringForward(_ browser: RunningBrowser) async -> Bool {
        func isFront() -> Bool { NSWorkspace.shared.frontmostApplication?.processIdentifier == browser.pid }
        if isFront() { return true }
        let app = browser.app
        await MainActor.run { NSApp.yieldActivation(to: app); app.activate() }
        for _ in 0..<40 {                                                     // up to 2 s
            if isFront() { break }
            try? await Task.sleep(for: .milliseconds(50))
        }
        guard isFront() else { return false }
        try? await Task.sleep(for: .milliseconds(120))                        // let its window settle
        return true
    }

    /// Did pressing the button really open something? Either Apple's popup is on screen or the helper is showing a code.
    /// A press can report success without the browser opening the popup, so this is checked rather than assumed.
    private func popupAppeared(browserPID: pid_t) async -> Bool {
        for _ in 0..<60 {                                                     // up to ~1.5 s
            try? await Task.sleep(for: .milliseconds(25))
            let popups = browserScanner.extensionPopups(pid: browserPID)
            if !popups.isEmpty {
                if popups.count == 1 { popupCache[browserPID] = (popups[0], Date()) }
                windowWatch.stopHidingBrowserWindows(); hidePopups(popups, browserPID: browserPID); return true
            }
            if HelperScanner.scan().contains(where: { $0.parentPID == browserPID && $0.hasWindow }) { return true }
        }
        return false
    }

    /// Identity check, approval (if configured), then open the extension's popup: through the pinned toolbar button if
    /// there is one, otherwise through the Extensions menu. Each press is verified, with a real click and then the
    /// other route as fallbacks. The popup itself requests the code.
    private func openPopup(_ browser: RunningBrowser, reason: String, userInitiated: Bool) async -> OpenResult {
        let name = browser.trusted.name
        let (trusted, flags) = trustCheck(pid: browser.pid)
        guard trusted != nil else {
            log(.warning, "AutoPass skipped \(name) because its signature didn't match.")
            publish(.attention("\(name) didn't match its signature")); return .failed
        }
        if policy.refuseDebugFlags, !flags.isEmpty {
            log(.warning, "AutoPass skipped \(name) because it was started with debugging options.")
            publish(.attention("\(name) has debugging options on")); return .failed
        }

        let locateStart = Date()
        guard case .elements(var toolbar) = browserScanner.locateToolbar(pid: browser.pid, nameHint: toolbarHint) else {
            if userInitiated { log(.warning, "Open a window in \(name) first."); publish(.attention("Open a \(name) window first")) }
            return .interrupted                                           // nothing to press yet; try again shortly
        }
        trace("\(name): toolbar located in \(Int(Date().timeIntervalSince(locateStart) * 1000)) ms", key: "locate")
        guard toolbar.pinned != nil || toolbar.extensionsButton != nil else {
            log(.warning, "AutoPass can't find the Extensions menu in \(name). Pin iCloud Passwords to its toolbar instead.")
            publish(.attention("Can't find the Extensions menu in \(name)")); return .failed
        }

        if policy.approval != .none {
            guard await approveIfNeeded(reason: reason) else { return .failed }
            // The approval prompt can take the browser out of front (and typing a password isn't "switching away").
            guard await bringForward(browser) else {
                log(.warning, "AutoPass couldn't bring \(name) forward."); publish(.attention("Couldn't bring \(name) forward")); return .interrupted
            }
        }

        publish(.openingPopup)
        hotUntil = Date().addingTimeInterval(Timing.hotWindow)
        pairClock = (Date(), nil, nil, nil, nil)

        var result = OpenResult.failed

        if let button = toolbar.pinned {
            trace("\(name): pinned button \(browserScanner.describe(button))", key: "route")
            var pinned = button
            startWatch(browser)                                                  // from here, watch what the press opens
            var pressed = browserScanner.press(pinned)
            if !pressed, case .elements(let fresh) = browserScanner.locateToolbar(pid: browser.pid, nameHint: toolbarHint, force: true),
               let again = fresh.pinned {
                toolbar = fresh; pinned = again; pressed = browserScanner.press(pinned)         // the cached element had gone stale
            }
            if pressed, await popupAppeared(browserPID: browser.pid) {
                result = .opened
            } else {
                trace("\(name): pressing the pinned button didn't open the popup; trying a click", key: "route")
                if browserScanner.click(pinned, pid: browser.pid), await popupAppeared(browserPID: browser.pid) { result = .opened }
            }
        }

        if result != .opened, toolbar.extensionsButton != nil {
            result = await openThroughExtensionsMenu(browser, toolbar: toolbar, declareMissing: toolbar.pinned == nil, userInitiated: userInitiated)
            if result == .extensionMissing { restoreWindows(browserPID: browser.pid); return .extensionMissing }
        }

        if result == .opened { pairClock?.popup = Date(); log(.info, "Opened iCloud Passwords in \(name)") }
        else {
            // If you switched away or were typing, that's why it didn't open; it isn't a failure.
            let youGotInTheWay = NSWorkspace.shared.frontmostApplication?.processIdentifier != browser.pid || Input.idleSeconds() < 1.0
            if youGotInTheWay {
                restoreWindows(browserPID: browser.pid)
                log(.info, "AutoPass paused because you were busy in \(name). It will try again.")
                return .interrupted
            }
            if hasHiddenWindows(browserPID: browser.pid) {
                restoreWindows(browserPID: browser.pid)
                hideWindows = false                           // a window was hidden and the popup still didn't open; stop hiding
                trace("the popup didn't open while a window was hidden; hiding is off for this session")
            }
            log(.warning, "AutoPass pressed iCloud Passwords in \(name) but the popup didn't open.")
        }
        return result
    }

    /// Watches the windows a press opens: hides them within a frame or two, and logs how long each was on screen.
    private func startWatch(_ browser: RunningBrowser) {
        let sink = self.sink
        windowWatch.start(browserPID: browser.pid, browserName: browser.trusted.name, hide: hideWindows, seconds: 4) { sink.trace($0) }
    }

    /// Opens the popup by choosing iCloud Passwords from the Extensions (puzzle piece) menu. If it isn't listed and
    /// `declareMissing`, it's treated as not installed or turned off.
    private func openThroughExtensionsMenu(_ browser: RunningBrowser, toolbar: BrowserScanner.ToolbarElements,
                                           declareMissing: Bool, userInitiated: Bool) async -> OpenResult {
        let name = browser.trusted.name
        func closeMenu() { if NSWorkspace.shared.frontmostApplication?.processIdentifier == browser.pid { KeyInjector.escape(toPID: browser.pid) } }

        var pressed = toolbar.extensionsButton.map(browserScanner.press) ?? false
        if !pressed, case .elements(let fresh) = browserScanner.locateToolbar(pid: browser.pid, nameHint: toolbarHint, force: true),
           let button = fresh.extensionsButton {
            pressed = browserScanner.press(button)                           // the cached element had gone stale
        }
        guard pressed else { log(.warning, "AutoPass couldn't open the Extensions menu in \(name)."); return .failed }

        var entry: AXUIElement?
        for _ in 0..<Int(Timing.extensionsMenuWait * 40) {                     // the menu takes a moment to appear
            try? await Task.sleep(for: .milliseconds(25))
            entry = browserScanner.extensionsMenuEntry(pid: browser.pid, nameHint: toolbarHint)
            if entry != nil { break }
        }
        trace("\(name): Extensions menu opened, iCloud Passwords listed: \(entry != nil)", key: "menu")
        guard let entry else {
            closeMenu()
            guard declareMissing else { return .failed }
            handleExtensionMissing(browser, userInitiated: userInitiated)
            return .extensionMissing
        }
        trace("\(name): menu entry \(browserScanner.describe(entry))", key: "route")
        startWatch(browser)                                                      // the menu is already open, so it isn't a "new" window
        guard browserScanner.press(entry) else { closeMenu(); return .failed }
        if await popupAppeared(browserPID: browser.pid) { return .opened }
        trace("\(name): choosing it from the menu didn't open the popup; trying a click", key: "route")
        if browserScanner.click(entry, pid: browser.pid), await popupAppeared(browserPID: browser.pid) { return .opened }
        closeMenu()
        return .failed
    }

    /// iCloud Passwords isn't in the toolbar or the Extensions menu, so it's missing or turned off. Stop trying on
    /// its own and let the user install it or turn it on.
    private func handleExtensionMissing(_ browser: RunningBrowser, userInitiated: Bool) {
        let name = browser.trusted.name
        browserRecords[browser.pid, default: BrowserRecord()].attempts = 2
        extensionMissing.insert(browser.pid)
        lastHealthAt = .distantPast
        log(.warning, "iCloud Passwords isn't in \(name). Install it or turn it on.")
        publish(.attention("iCloud Passwords isn't in \(name)"))
        sink.promptExtension(ExtensionPrompt(browserName: name, bundleID: browser.trusted.bundleID,
                                             signingID: browser.trusted.signingID, userInitiated: userInitiated))
    }

    // MARK: Approval

    private func approveIfNeeded(reason: String) async -> Bool {
        guard policy.approval != .none else { return true }
        if let t = lastApproval, Date().timeIntervalSince(t) < Double(policy.approvalGraceSeconds) { return true }
        publish(.awaitingApproval)
        switch await Approval.authenticate(mode: policy.approval, reason: reason) {
        case .approved:
            lastApproval = Date(); return true
        case .cancelled:
            log(.info, "Approval was canceled, so nothing was typed."); return false
        case .unavailable:
            log(.warning, "Approval isn't available, so nothing was typed."); publish(.attention("Approval isn't available")); return false
        case .failed:
            log(.warning, "Approval didn't go through, so nothing was typed."); return false
        }
    }

    // MARK: Helpers

    private func markPaired(helper pid: pid_t) {
        helpers[pid]?.paired = true
        guard let id = helpers[pid]?.identity else { return }
        pairedIdentities.insert(id)
        let live = Set(helpers.values.compactMap(\.identity))
        pairedIdentities = pairedIdentities.filter { live.contains($0) }              // drop entries for helpers that are gone
        UserDefaults.standard.set(Array(pairedIdentities), forKey: "pairedHelpers")
    }

    /// Running trusted browsers, listed at most every 200 ms (the engine asks several times per tick).
    private func runningTrustedBrowsers() -> [RunningBrowser] {
        if let c = runningCache, Date().timeIntervalSince(c.at) < 0.2 { return c.list }
        let list: [RunningBrowser] = NSWorkspace.shared.runningApplications.compactMap { app in
            guard app.activationPolicy == .regular, let bundleID = app.bundleIdentifier,
                  let trusted = policy.enabledBrowsers.first(where: { $0.bundleID == bundleID }) else { return nil }
            return RunningBrowser(app: app, trusted: trusted)
        }
        runningCache = (Date(), list)
        return list
    }

    private func browserName(for pid: pid_t) -> String {
        runningTrustedBrowsers().first { $0.pid == pid }?.trusted.name ?? "the browser"
    }

    private func computeHealth() -> Health {
        var health = Health(accessibility: AX.isTrusted(prompt: false), postEvents: CGPreflightPostEventAccess())
        guard health.accessibility else { return health }
        for b in runningTrustedBrowsers() {
            if probedBrowsers.insert(b.pid).inserted {
                // Once per browser: can AutoPass find its pinned button and its Extensions button? (Nothing is pressed.)
                if case .elements(let e) = browserScanner.locateToolbar(pid: b.pid, nameHint: toolbarHint) {
                    trace("\(b.trusted.name): pinned button \(e.pinned != nil ? "yes" : "no"), Extensions button \(e.extensionsButton != nil ? "yes" : "no")", key: "probe-\(b.pid)")
                }
            }
            let mine = helpers.values.filter { $0.parentPID == b.pid }
            health.browsers.append(BrowserHealth(signingID: b.trusted.signingID, name: b.trusted.name, pid: b.pid,
                                                 helperRunning: !mine.isEmpty, extensionMissing: extensionMissing.contains(b.pid),
                                                 paired: mine.isEmpty ? nil : mine.allSatisfy(\.paired)))
        }
        return health
    }

    private func publish(_ status: EngineStatus) {
        guard status != lastStatus else { return }
        lastStatus = status
        if wantsHealth { lastHealthAt = .distantPast }
        sink.status(status)
    }

    private func log(_ level: LogLevel, _ message: String) { sink.log(level, message) }

    /// Reports a reason once per change, so the system log explains silence without flooding.
    private func trace(_ message: String, key: String = "-") {
        guard lastTrace[key] != message else { return }
        lastTrace[key] = message
        sink.trace(message)
    }
}
