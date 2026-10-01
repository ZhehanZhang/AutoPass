import Cocoa
import ApplicationServices
import AutoPassCore

/// Moves windows off every display and puts them back. Every hidden window is remembered with its owner, so it can always be
/// restored if AutoPass decides not to finish a pairing, and everything is restored when AutoPass quits.
final class WindowHider: @unchecked Sendable {
    static let shared = WindowHider()

    private struct Entry { let owner: pid_t; let element: AXUIElement; let original: CGPoint; let at: Date }
    private var hidden: [Entry] = []
    private let lock = NSLock()

    private func position(of window: AXUIElement) -> CGPoint? {
        guard let v = AX.attr(window, kAXPositionAttribute) else { return nil }
        var p = CGPoint.zero
        return AXValueGetValue(v as! AXValue, .cgPoint, &p) ? p : nil
    }

    private func set(_ window: AXUIElement, to point: CGPoint) -> Bool {
        var p = point
        guard let value = AXValueCreate(.cgPoint, &p) else { return false }
        return AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, value) == .success
    }

    /// Moves the window far off screen. Returns false if it can't be moved, was already hidden, or moved itself back.
    @discardableResult
    func hide(_ window: AXUIElement, owner: pid_t) -> Bool {
        guard let original = position(of: window), original.x > -1_000 else { return false }
        guard set(window, to: CGPoint(x: -30_000, y: -30_000)) else { return false }
        // Some windows clamp themselves back on screen; that doesn't count as hidden.
        guard let now = position(of: window), now.x < -1_000 else { _ = set(window, to: original); return false }
        lock.lock(); hidden.append(Entry(owner: owner, element: window, original: original, at: Date())); lock.unlock()
        return true
    }

    func isHiding(owner: pid_t) -> Bool { lock.lock(); defer { lock.unlock() }; return hidden.contains { $0.owner == owner } }
    func age(owner: pid_t) -> TimeInterval? {
        lock.lock(); defer { lock.unlock() }
        return hidden.filter { $0.owner == owner }.map(\.at).min().map { Date().timeIntervalSince($0) }
    }
    func windows(owner: pid_t) -> [AXUIElement] { lock.lock(); defer { lock.unlock() }; return hidden.filter { $0.owner == owner }.map(\.element) }

    /// Puts an owner's hidden windows back where they were.
    func restore(owner: pid_t) {
        lock.lock(); let mine = hidden.filter { $0.owner == owner }; hidden.removeAll { $0.owner == owner }; lock.unlock()
        for e in mine { _ = set(e.element, to: e.original) }
    }

    func restore(windows: [AXUIElement]) {
        lock.lock()
        let mine = hidden.filter { e in windows.contains { CFEqual($0, e.element) } }
        hidden.removeAll { e in windows.contains { CFEqual($0, e.element) } }
        lock.unlock()
        for e in mine { _ = set(e.element, to: e.original) }
    }

    /// Stop tracking an owner's windows without moving them (they're gone: the popup closed, the helper window was dismissed).
    func forget(owner: pid_t) { lock.lock(); hidden.removeAll { $0.owner == owner }; lock.unlock() }

    func restoreAll() {
        lock.lock(); let all = hidden; hidden.removeAll(); lock.unlock()
        for e in all { _ = set(e.element, to: e.original) }
    }
}

extension WindowHider {
    /// Restores the windows an owner had hidden that still exist, and forgets the rest (they closed). Used when a pairing is
    /// over: a leftover window must never stay off screen, but one that's already gone must not be touched.
    func finish(owner: pid_t) {
        let alive = windows(owner: owner).filter { !AX.role($0).isEmpty }
        if alive.isEmpty { forget(owner: owner) } else { restore(owner: owner) }
    }
}

/// Watches for the windows a pairing opens, hides them within a frame or two, and measures how long each was on screen.
///
/// It finds new windows from the window server's list (one cheap call that puts no load on the browser) and only asks the
/// browser's Accessibility for the window's handle once a new one is known. Hiding is optional; the measurements are always
/// reported, so how visible a pairing really was can be read from the log instead of guessed.
final class WindowWatch: @unchecked Sendable {
    private struct Sighting {
        let owner: pid_t
        let isHelper: Bool
        let bounds: CGRect
        let appeared: Date
        var hiddenAfter: TimeInterval?
        var attempts = 0
        var reported = false
    }

    private let lock = NSLock()
    private var generation = 0
    private var hideBrowserWindows = true

    func start(browserPID: pid_t, browserName: String, hide: Bool, seconds: TimeInterval, report: @escaping @Sendable (String) -> Void) {
        lock.lock(); generation += 1; let mine = generation; hideBrowserWindows = hide; lock.unlock()
        let thread = Thread { [self] in run(browserPID: browserPID, name: browserName, hide: hide, seconds: seconds, generation: mine, report: report) }
        thread.qualityOfService = .userInteractive
        thread.start()
    }

    /// The popup has been found; stop moving the browser's other windows (Apple's code window is still hidden).
    func stopHidingBrowserWindows() { lock.lock(); hideBrowserWindows = false; lock.unlock() }
    func stop() { lock.lock(); generation += 1; lock.unlock() }

    private func state(_ generation: Int) -> (alive: Bool, hideBrowser: Bool) {
        lock.lock(); defer { lock.unlock() }
        return (generation == self.generation, hideBrowserWindows)
    }

    private static func displayRects() -> [CGRect] {
        var count: UInt32 = 0
        CGGetActiveDisplayList(0, nil, &count)
        var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
        CGGetActiveDisplayList(count, &ids, &count)
        return ids.map { CGDisplayBounds($0) }
    }

    private static func snapshot() -> [(id: CGWindowID, pid: pid_t, owner: String, bounds: CGRect)] {
        guard let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else { return [] }
        return list.compactMap { w in
            guard let pid = w[kCGWindowOwnerPID as String] as? Int32, let id = w[kCGWindowNumber as String] as? Int,
                  let dict = w[kCGWindowBounds as String] as? NSDictionary,
                  let bounds = CGRect(dictionaryRepresentation: dict as CFDictionary) else { return nil }
            return (CGWindowID(id), pid_t(pid), w[kCGWindowOwnerName as String] as? String ?? "", bounds)
        }
    }

    /// The Accessibility element for a window the window server reported, matched by where it is and how big.
    private static func axWindow(owner: pid_t, bounds: CGRect) -> AXUIElement? {
        AX.windows(AX.app(owner)).first { w in
            guard let f = BrowserScanner.frame(w) else { return false }
            return abs(f.minX - bounds.minX) < 3 && abs(f.minY - bounds.minY) < 3 && abs(f.width - bounds.width) < 3 && abs(f.height - bounds.height) < 3
        }
    }

    private func run(browserPID: pid_t, name: String, hide: Bool, seconds: TimeInterval, generation: Int, report: @escaping @Sendable (String) -> Void) {
        let displays = Self.displayRects()
        func isVisible(_ r: CGRect) -> Bool { displays.contains { $0.intersects(r) } }

        let baseline = Set(Self.snapshot().filter { $0.pid == browserPID }.map(\.id))     // windows open before the press
        var sightings: [CGWindowID: Sighting] = [:]
        var helperOK: [pid_t: Bool] = [:]
        let deadline = Date().addingTimeInterval(seconds)
        var tick = 0

        func finish(_ id: CGWindowID, _ s: inout Sighting, until end: Date, how: String) {
            guard !s.reported else { return }
            s.reported = true
            let visibleMS = Int((s.hiddenAfter ?? end.timeIntervalSince(s.appeared)) * 1000)
            let what = s.isHelper ? "Apple's code window" : "a \(Int(s.bounds.width))x\(Int(s.bounds.height)) window"
            report("\(name): \(what) was on screen \(visibleMS) ms (\(how))")
        }

        while Date() < deadline {
            let st = state(generation)
            guard st.alive else { break }
            let now = Date()
            let snap = Self.snapshot()
            let present = Set(snap.map(\.id))

            for w in snap where sightings[w.id] == nil && !baseline.contains(w.id) {
                if w.pid == browserPID {
                    sightings[w.id] = Sighting(owner: w.pid, isHelper: false, bounds: w.bounds, appeared: now)
                } else if w.owner.contains("PasswordManagerBrowserExtensionHelper") || w.owner.contains("Passwords Extension Helper") {
                    if helperOK[w.pid] == nil {
                        helperOK[w.pid] = ProcessInspector.parentPID(of: w.pid) == browserPID
                            && CodeSigning.process(w.pid, satisfies: ICloudExtension.helperRequirement)
                    }
                    if helperOK[w.pid] == true { sightings[w.id] = Sighting(owner: w.pid, isHelper: true, bounds: w.bounds, appeared: now) }
                }
            }

            for (id, var s) in sightings where !s.reported {
                if !present.contains(id) { finish(id, &s, until: now, how: "then it closed"); sightings[id] = s; continue }
                let current = snap.first { $0.id == id }?.bounds ?? s.bounds
                if !isVisible(current) {                                      // it moved off screen
                    if s.hiddenAfter == nil { s.hiddenAfter = now.timeIntervalSince(s.appeared) }
                    finish(id, &s, until: now, how: "then hidden"); sightings[id] = s; continue
                }
                // Try to hide it (every few ticks: the lookup asks the app for its windows).
                let popupSized = s.bounds.width >= 200 && s.bounds.width <= 560 && s.bounds.height >= 80 && s.bounds.height <= 420
                let eligible = hide && !s.isHelper && st.hideBrowser && popupSized        // Apple's code window is never moved
                if eligible, s.attempts < 60, tick % 2 == 0 {
                    s.attempts += 1
                    if let ax = Self.axWindow(owner: s.owner, bounds: current), WindowHider.shared.hide(ax, owner: s.owner) {
                        s.hiddenAfter = Date().timeIntervalSince(s.appeared)
                        finish(id, &s, until: Date(), how: "then hidden")
                    }
                }
                sightings[id] = s
            }
            tick += 1
            usleep(3_000)
        }
        let end = Date()
        for (id, var s) in sightings where !s.reported {
            finish(id, &s, until: end, how: "still showing when it stopped watching"); sightings[id] = s
        }
    }
}
