import Cocoa
import ServiceManagement
import UserNotifications
import os
import AutoPassCore

@MainActor
final class AppModel: ObservableObject {
    static let shared = AppModel()

    // Security policy: persisted to the keychain, editable only while unlocked.
    @Published var policy: SecurityPolicy { didSet { policyChanged(from: oldValue) } }
    @Published private(set) var isUnlocked = false
    @Published private(set) var policyStoreError: String?

    // Preferences (UserDefaults).
    @Published var showMenuBarIcon: Bool { didSet { UserDefaults.standard.set(showMenuBarIcon, forKey: "showMenuBarIcon") } }
    @Published var notificationsEnabled: Bool { didSet { UserDefaults.standard.set(notificationsEnabled, forKey: "notifications"); if notificationsEnabled { requestNotificationAuthorization() } } }

    // Live state from the engine.
    @Published private(set) var status: EngineStatus = .idle {
        didSet { if status != oldValue { Self.logger.notice("status: \(self.status.summary, privacy: .public)") } }
    }
    @Published private(set) var log: [LogEntry] = []
    @Published private(set) var health = Health()
    @Published private(set) var isPaused = false
    @Published private(set) var launchAtLogin = false
    @Published private(set) var launchAtLoginError: String?

    /// What Apple's helper on this Mac will accept as a parent (read from its code signature).
    @Published private(set) var supportedBrowsers: [AllowedBrowserGroup] = []

    /// Mirrors the Activity list into the system log (`log stream --predicate 'subsystem == "com.zhehanz.AutoPass"'`).
    /// Messages never contain verification codes.
    private nonisolated static let logger = Logger(subsystem: "com.zhehanz.AutoPass", category: "engine")
    private var engine: PairingEngine?
    private var relockTask: Task<Void, Never>?
    /// A Touch ID or password prompt is already up; more clicks on locked controls shouldn't stack another.
    private var isAuthenticating = false
    private var storeHealthy = true
    private var revertingPolicy = false

    init() {
        let defaults = UserDefaults.standard
        showMenuBarIcon = defaults.object(forKey: "showMenuBarIcon") as? Bool ?? true
        notificationsEnabled = defaults.object(forKey: "notifications") as? Bool ?? true

        switch KeychainPolicyStore.load() {
        case .loaded(let stored):
            let upgraded = stored.migrated()
            policy = upgraded
            if upgraded != stored { try? KeychainPolicyStore.save(upgraded) }
        case .none:
            policy = SecurityPolicy()
            try? KeychainPolicyStore.save(policy)
        case .failed:
            policy = SecurityPolicy()
            storeHealthy = false
            policyStoreError = "AutoPass couldn't read your saved settings, so it's using safe defaults. Changes won't be saved until this is fixed."
        }

        refreshLaunchAtLogin()
        Task { [weak self] in
            let groups = await Task.detached { LaunchConstraintReader.allowedBrowsers() ?? [] }.value
            self?.supportedBrowsers = groups
        }

        let sink = EngineSink(
            status: { [weak self] s in Task { @MainActor in self?.status = s } },
            log: { [weak self] level, message in Task { @MainActor in self?.append(level, message) } },
            health: { [weak self] h in Task { @MainActor in if self?.health != h { self?.health = h } } },
            notify: { [weak self] title, body in Task { @MainActor in self?.notify(title, body) } },
            promptExtension: { [weak self] prompt in Task { @MainActor in self?.handle(prompt) } },
            trace: { message in Self.logger.notice("trace: \(message, privacy: .public)") })
        let engine = PairingEngine(policy: policy, hideWindows: true, sink: sink)
        self.engine = engine
        Task { await engine.start() }
        if notificationsEnabled { requestNotificationAuthorization() }
    }

    // MARK: Policy & lock

    var isLocked: Bool { policy.isSettingsProtected && !isUnlocked }

    private func policyChanged(from old: SecurityPolicy) {
        guard !revertingPolicy, policy != old else { return }
        // Defense in depth: the UI disables controls while locked, but never persist a change made while locked.
        if policy.isSettingsProtected && !isUnlocked && old.isSettingsProtected {
            revertingPolicy = true; policy = old; revertingPolicy = false
            return
        }
        let clean = policy.sanitized()
        Task { await engine?.update(policy: clean) }
        guard storeHealthy else { return }
        do { try KeychainPolicyStore.save(clean); policyStoreError = nil }
        catch { policyStoreError = "AutoPass couldn't save your settings. \(error.localizedDescription)" }
    }

    func unlock() async {
        guard policy.isSettingsProtected, !isUnlocked, !isAuthenticating else { return }
        isAuthenticating = true
        defer { isAuthenticating = false }
        let reason = "Change AutoPass security settings"
        var outcome = await Approval.authenticate(mode: policy.settingsAuth, reason: reason)
        // Touch ID only, on a Mac that can't offer it right now: the settings still have to be reachable.
        if case .unavailable = outcome, policy.settingsAuth == .biometricsOnly {
            outcome = await Approval.authenticate(mode: .deviceOwner, reason: reason)
        }
        if case .approved = outcome {
            isUnlocked = true
            relockTask?.cancel()
            relockTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(300))
                if !Task.isCancelled { self?.lock() }
            }
        }
    }

    func lock() { isUnlocked = false; relockTask?.cancel() }

    // MARK: Engine controls

    func pairNow(browserPID: pid_t? = nil) { Task { await engine?.pairNow(browserPID: browserPID) } }

    /// The sidebar lock: turns settings protection on (and locks) the first time; afterwards locks or unlocks.
    func toggleLock() async {
        if !policy.isSettingsProtected {
            policy.settingsAuth = .deviceOwner
            isUnlocked = false
        } else if isUnlocked {
            lock()
        } else {
            await unlock()
        }
    }

    /// Per-browser pause: AutoPass leaves that browser alone until resumed (resets when AutoPass restarts).
    @Published private(set) var pausedBrowsers: Set<String> = []

    func setBrowserPaused(_ browser: TrustedBrowser, _ paused: Bool) {
        if paused { pausedBrowsers.insert(browser.signingID) } else { pausedBrowsers.remove(browser.signingID) }
        Task { await engine?.setBrowserPaused(signingID: browser.signingID, name: browser.name, paused) }
    }

    func setPaused(_ paused: Bool, minutes: Int? = nil) {
        isPaused = paused
        Task { await engine?.setPaused(paused, minutes: minutes) }
        if paused, let minutes {
            Task { [weak self] in
                try? await Task.sleep(for: .seconds(minutes * 60))
                if self?.isPaused == true { self?.isPaused = false }
            }
        }
    }

    func setHealthDemand(_ on: Bool) { Task { await engine?.setHealthDemand(on) } }

    func requestAccessibility() { _ = AX.isTrusted(prompt: true) }

    func openAccessibilitySettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }


    // MARK: Browsers

    func isSupportedByHelper(_ identity: CodeSigning.AppIdentity) -> Bool? {
        guard !supportedBrowsers.isEmpty else { return nil }
        return supportedBrowsers.contains { $0.teamID == identity.teamID && $0.signingIDs.contains(identity.signingID) }
    }

    func add(_ identity: CodeSigning.AppIdentity) {
        guard !policy.trustedBrowsers.contains(where: { $0.signingID == identity.signingID }) else { return }
        policy.trustedBrowsers.append(TrustedBrowser(name: identity.name, bundleID: identity.bundleID,
                                                      signingID: identity.signingID, teamID: identity.teamID))
    }

    func remove(_ browser: TrustedBrowser) { policy.trustedBrowsers.removeAll { $0.signingID == browser.signingID } }

    /// Installed apps that Apple's helper accepts as parents and that aren't trusted yet.
    func suggestedBrowsers() -> [(name: String, url: URL)] {
        let supported = Set(supportedBrowsers.flatMap(\.signingIDs))
        let trusted = Set(policy.trustedBrowsers.map(\.bundleID))
        let roots = [URL(fileURLWithPath: "/Applications"), FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications")]
        var found: [(String, URL)] = []
        for root in roots {
            let apps = (try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)) ?? []
            for url in apps where url.pathExtension == "app" {
                guard let b = Bundle(url: url), let id = b.bundleIdentifier, supported.contains(id), !trusted.contains(id),
                      !(id.hasPrefix("org.mozilla") || id.contains("firefox")) else { continue }   // Firefox uses a different extension
                let name = (b.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
                    ?? (b.object(forInfoDictionaryKey: "CFBundleName") as? String) ?? url.deletingPathExtension().lastPathComponent
                found.append((name, url))
            }
        }
        return found.sorted { $0.0.localizedCaseInsensitiveCompare($1.0) == .orderedAscending }
    }

    // MARK: Launch at login & notifications

    func refreshLaunchAtLogin() { launchAtLogin = SMAppService.mainApp.status == .enabled }

    func setLaunchAtLogin(_ on: Bool) {
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            launchAtLoginError = nil
        } catch {
            launchAtLoginError = error.localizedDescription
        }
        refreshLaunchAtLogin()
    }

    private func requestNotificationAuthorization() {
        guard Bundle.main.bundleIdentifier != nil else { return }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert]) { _, _ in }
    }

    // MARK: iCloud Passwords missing from a browser

    /// iCloud Passwords isn't in a browser. If you asked to pair, say so right away with a way to fix it; if AutoPass was
    /// trying on its own, send a quiet notification instead of interrupting you.
    private func handle(_ prompt: ExtensionPrompt) {
        guard prompt.userInitiated else {
            notify("iCloud Passwords isn't in \(prompt.browserName)", "Install it or turn it on to use AutoPass with it.")
            return
        }
        let alert = NSAlert()
        alert.messageText = "iCloud Passwords isn't in \(prompt.browserName)"
        alert.informativeText = "Install it or turn it on, then pair again."
        alert.addButton(withTitle: "Install")
        alert.addButton(withTitle: "Turn On")
        alert.addButton(withTitle: "Cancel")
        NSApp.activate(ignoringOtherApps: true)
        switch alert.runModal() {
        case .alertFirstButtonReturn: installExtension(bundleID: prompt.bundleID, signingID: prompt.signingID)
        case .alertSecondButtonReturn: turnOnExtension(bundleID: prompt.bundleID, signingID: prompt.signingID)
        default: break
        }
    }

    func installExtension(bundleID: String, signingID: String) {
        open(ExtensionLinks.installURL(forSigningID: signingID), inBrowser: bundleID)
    }

    func turnOnExtension(bundleID: String, signingID: String) {
        open(ExtensionLinks.manageURL(forSigningID: signingID), inBrowser: bundleID)
    }

    /// Opens a link in one specific browser, not whichever is the default.
    private func open(_ url: URL, inBrowser bundleID: String) {
        guard let app = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { NSWorkspace.shared.open(url); return }
        NSWorkspace.shared.open([url], withApplicationAt: app, configuration: NSWorkspace.OpenConfiguration())
    }

    private func notify(_ title: String, _ body: String) {
        guard notificationsEnabled, Bundle.main.bundleIdentifier != nil else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
    }

    private func append(_ level: LogLevel, _ message: String) {
        switch level {
        case .info: Self.logger.notice("\(message, privacy: .public)")
        case .warning: Self.logger.warning("\(message, privacy: .public)")
        case .error: Self.logger.error("\(message, privacy: .public)")
        }
        log.insert(LogEntry(level: level, message: message), at: 0)
        if log.count > 200 { log.removeLast(log.count - 200) }
    }
}
