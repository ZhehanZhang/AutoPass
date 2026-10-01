import Foundation

/// A snapshot of everything AutoPass observed about one pending pairing. The app target fills this
/// in from the system (code signatures, process table, Accessibility); the rules live here so they
/// can be unit-tested without any permission.
public struct PairingFacts: Equatable, Sendable {
    public var helperIsAppleSigned = false
    /// Extension ID from the helper's argv, or nil if absent / not one of Apple's.
    public var helperExtensionID: String?
    public var helperParentPID: Int32 = 0
    /// How many Apple-helper processes under the same browser are currently showing a code.
    public var codeWindowsForBrowser = 0
    public var code: String?

    /// Extension pages (popups) open in the browser that started the helper; there must be exactly one.
    public var popupCount = 0
    /// PID of the process that owns the popup we would type into.
    public var popupOwnerPID: Int32?
    /// The popup's owner satisfies the code-signing requirement of an enabled trusted browser.
    public var browserMatchesTrusted = false
    public var browserLaunchFlags: [String] = []
    public var browserIsFrontmost = false

    public var popupURL: String?
    public var popupFieldCount = 0
    public var popupFieldsEmpty = false
    public var popupFirstFieldFocused = false

    /// Seconds since the last real keystroke (clicks don't count: clicking the toolbar button is how pairing starts).
    public var userIdleSeconds: Double = 0

    public init() {}
}

public enum Denial: Equatable, Sendable {
    case helperNotApple
    case helperExtensionUnknown
    case ambiguousCodeWindows
    case popupNotFound
    case ambiguousPopups
    case parentMismatch
    case browserNotTrusted
    case riskyFlags([String])
    case browserNotFrontmost
    case popupWrongPage
    case popupWrongShape(fields: Int)
    case popupNotEmpty
    case popupNotFocused
    case codeMalformed
    case userActive
    case rateLimited

    /// Expected for a moment while a popup is still loading or the user is mid-action; only worth
    /// reporting if it persists. The others are real refusals and are reported immediately.
    public var isTransient: Bool {
        switch self {
        case .popupNotFound, .popupWrongShape, .popupNotEmpty, .popupNotFocused, .userActive, .browserNotFrontmost: true
        default: false
        }
    }

    public var message: String {
        switch self {
        case .helperNotApple: "That window isn't from Apple's password helper."
        case .helperExtensionUnknown: "The helper wasn't started by iCloud Passwords."
        case .ambiguousCodeWindows: "More than one code is showing, so AutoPass can't tell which popup it belongs to."
        case .popupNotFound: "No iCloud Passwords popup is open."
        case .ambiguousPopups: "More than one popup is open, so AutoPass won't guess."
        case .parentMismatch: "The popup belongs to a different app than the helper."
        case .browserNotTrusted: "That browser isn't on your trusted list."
        case .riskyFlags: "The browser was started with debugging options."
        case .browserNotFrontmost: "The browser isn't in front."
        case .popupWrongPage: "The popup isn't Apple's extension page."
        case .popupWrongShape(let n): "AutoPass expected six code boxes but found \(n)."
        case .popupNotEmpty: "The code boxes aren't empty."
        case .popupNotFocused: "The first code box isn't selected."
        case .codeMalformed: "The code window doesn't show six digits."
        case .userActive: "You're typing, so AutoPass is waiting."
        case .rateLimited: "There were too many attempts recently, so AutoPass is pausing."
        }
    }
}

public enum PairingPolicy {
    /// Returns nil when typing is allowed, otherwise the first rule that failed. Order matters only for
    /// which message the user sees; every rule must hold.
    public static func evaluate(_ f: PairingFacts, policy: SecurityPolicy, rateLimited: Bool = false) -> Denial? {
        guard f.helperIsAppleSigned else { return .helperNotApple }
        guard let extensionID = f.helperExtensionID else { return .helperExtensionUnknown }
        guard f.codeWindowsForBrowser == 1 else { return .ambiguousCodeWindows }
        guard f.popupCount > 0, let owner = f.popupOwnerPID else { return .popupNotFound }
        guard f.popupCount == 1 else { return .ambiguousPopups }
        guard owner == f.helperParentPID else { return .parentMismatch }
        guard f.browserMatchesTrusted else { return .browserNotTrusted }
        if policy.refuseDebugFlags, !f.browserLaunchFlags.isEmpty { return .riskyFlags(f.browserLaunchFlags) }
        guard f.browserIsFrontmost else { return .browserNotFrontmost }       // never optional
        guard let url = f.popupURL, ICloudExtension.isPopupURL(url, extensionID: extensionID) else { return .popupWrongPage }
        guard f.popupFieldCount == 6 else { return .popupWrongShape(fields: f.popupFieldCount) }
        guard f.popupFieldsEmpty else { return .popupNotEmpty }
        guard f.popupFirstFieldFocused else { return .popupNotFocused }
        guard let code = f.code, VerificationCode.parse(code) != nil else { return .codeMalformed }
        guard f.userIdleSeconds >= policy.minimumIdleSeconds else { return .userActive }
        if rateLimited { return .rateLimited }
        return nil
    }
}

/// Sliding-window cap on how many codes AutoPass will type, so a loop or an attacker-induced retry
/// cycle can't hammer the helper (which locks out after repeated wrong codes).
public struct AttemptLimiter: Sendable {
    private var stamps: [Date] = []
    public init() {}

    public mutating func record(at now: Date = Date()) { stamps.append(now) }

    public func isLimited(max: Int, window: TimeInterval, now: Date = Date()) -> Bool {
        stamps.filter { now.timeIntervalSince($0) < window }.count >= max
    }

    public mutating func reset() { stamps.removeAll() }
}

/// How long to wait before trying again after an interruption (you typed, switched windows, the popup closed on its own).
/// Interruptions are never failures: the wait grows a little each time, is capped, and there's no point at which AutoPass stops
/// trying for good.
public enum RetryBackoff {
    public static func delay(afterInterruptions n: Int) -> TimeInterval { min(1.5 * Double(max(n, 1)), 20) }
}
