import Foundation

public enum ApprovalMode: String, Codable, CaseIterable, Sendable {
    /// Type the code without asking.
    case none
    /// Touch ID, Apple Watch, or the account password.
    case deviceOwner
    /// Touch ID / Apple Watch only; no password fallback.
    case biometricsOnly
}

public enum AutoPairMode: String, Codable, CaseIterable, Sendable {
    /// Only act when the user opens the iCloud Passwords popup (or its in-page prompt) themselves.
    case off
    /// Also open the popup automatically once the user is actually browsing in a trusted browser.
    case whenBrowsing
}

/// Everything that decides whether AutoPass may type. Stored in the keychain (see `KeychainPolicyStore`
/// in the app target) so other processes cannot quietly rewrite it.
public struct SecurityPolicy: Codable, Equatable, Sendable {
    /// 1: first release (Touch ID on by default). 2: quiet defaults (no approval prompt, unlocked settings).
    public static let currentSchema = 2

    public var schemaVersion: Int
    public var trustedBrowsers: [TrustedBrowser]
    public var approval: ApprovalMode
    /// After a successful approval, further pairings within this many seconds do not prompt again
    /// (covers a cancelled-and-retried pairing, or two profiles pairing back to back).
    public var approvalGraceSeconds: Int
    /// The user must have stopped typing for this long before AutoPass types a code (and, when it opens
    /// the popup itself, stopped typing or clicking for at least 1.5 s).
    public var minimumIdleSeconds: Double
    public var refuseDebugFlags: Bool
    public var autoPair: AutoPairMode
    public var maxAttempts: Int
    public var attemptWindowMinutes: Int
    /// What the preferences window asks for before browsers or security settings can change: nothing, Touch ID, or a
    /// password.
    public var settingsAuth: ApprovalMode

    public init(
        schemaVersion: Int = SecurityPolicy.currentSchema,
        trustedBrowsers: [TrustedBrowser] = [.chrome],
        approval: ApprovalMode = .none,
        approvalGraceSeconds: Int = 120,
        minimumIdleSeconds: Double = 0.5,
        refuseDebugFlags: Bool = true,
        autoPair: AutoPairMode = .whenBrowsing,
        maxAttempts: Int = 3,
        attemptWindowMinutes: Int = 10,
        settingsAuth: ApprovalMode = .none
    ) {
        self.schemaVersion = schemaVersion
        self.trustedBrowsers = trustedBrowsers
        self.approval = approval
        self.approvalGraceSeconds = approvalGraceSeconds
        self.minimumIdleSeconds = minimumIdleSeconds
        self.refuseDebugFlags = refuseDebugFlags
        self.autoPair = autoPair
        self.maxAttempts = maxAttempts
        self.attemptWindowMinutes = attemptWindowMinutes
        self.settingsAuth = settingsAuth
    }

    // Tolerant decoding: missing keys fall back to the secure defaults, so adding a setting later
    // never discards a stored policy.
    public init(from decoder: Decoder) throws {
        let d = SecurityPolicy()
        let c = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try c.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1   // absent = written before versioning
        trustedBrowsers = try c.decodeIfPresent([TrustedBrowser].self, forKey: .trustedBrowsers) ?? d.trustedBrowsers
        approval = try c.decodeIfPresent(ApprovalMode.self, forKey: .approval) ?? d.approval
        approvalGraceSeconds = try c.decodeIfPresent(Int.self, forKey: .approvalGraceSeconds) ?? d.approvalGraceSeconds
        minimumIdleSeconds = try c.decodeIfPresent(Double.self, forKey: .minimumIdleSeconds) ?? d.minimumIdleSeconds
        refuseDebugFlags = try c.decodeIfPresent(Bool.self, forKey: .refuseDebugFlags) ?? d.refuseDebugFlags
        autoPair = try c.decodeIfPresent(AutoPairMode.self, forKey: .autoPair) ?? d.autoPair
        maxAttempts = try c.decodeIfPresent(Int.self, forKey: .maxAttempts) ?? d.maxAttempts
        attemptWindowMinutes = try c.decodeIfPresent(Int.self, forKey: .attemptWindowMinutes) ?? d.attemptWindowMinutes
        if let auth = try c.decodeIfPresent(ApprovalMode.self, forKey: .settingsAuth) {
            settingsAuth = auth
        } else {
            // Earlier versions stored a plain on/off switch for the settings lock.
            let legacy = try decoder.container(keyedBy: LegacyKeys.self)
            settingsAuth = (try legacy.decodeIfPresent(Bool.self, forKey: .protectSettings) ?? false) ? .deviceOwner : .none
        }
    }

    private enum LegacyKeys: String, CodingKey { case protectSettings }

    /// Upgrades a stored policy. v1 shipped with Touch ID approval and a locked settings screen on by default;
    /// v2 defaults to neither, so a v1 policy that still has them is moved to the new defaults. Everything
    /// else (trusted browsers, safeguards) is kept.
    public func migrated() -> SecurityPolicy {
        var p = self
        if schemaVersion < 2 {
            if approval == .deviceOwner { p.approval = .none }
            p.settingsAuth = .none
        }
        p.schemaVersion = Self.currentSchema
        return p
    }

    /// Values outside these ranges can only come from tampering or a bug; clamp rather than trust them.
    public func sanitized() -> SecurityPolicy {
        var p = self
        p.schemaVersion = min(max(schemaVersion, 1), Self.currentSchema)
        p.trustedBrowsers = trustedBrowsers.filter(\.isWellFormed)
        p.approvalGraceSeconds = min(max(approvalGraceSeconds, 0), 900)
        p.minimumIdleSeconds = min(max(minimumIdleSeconds, 0.25), 30)
        p.maxAttempts = min(max(maxAttempts, 1), 10)
        p.attemptWindowMinutes = min(max(attemptWindowMinutes, 1), 120)
        return p
    }

    public var isSettingsProtected: Bool { settingsAuth != .none }

    public var enabledBrowsers: [TrustedBrowser] { trustedBrowsers.filter { $0.isEnabled && $0.isWellFormed } }
}
