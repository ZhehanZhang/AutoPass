import Foundation

/// What this Mac can offer right now when AutoPass asks you to authenticate.
public struct AuthAvailability: Equatable, Sendable {
    /// Touch ID (or an Apple Watch) can be used: there is a sensor and fingerprints are enrolled.
    public var touchID: Bool
    /// The account password prompt can be used.
    public var password: Bool

    public init(touchID: Bool, password: Bool) {
        self.touchID = touchID
        self.password = password
    }

    /// The prompt AutoPass can really show for `mode`, or nil when none can be shown.
    ///
    /// Touch ID only falls back to the password prompt on a Mac that can't offer Touch ID, so a setting never turns into
    /// "no check" or into being locked out of your own settings. Nil means nothing can be shown at all; callers then
    /// refuse (typing) or stay locked, never skip the check.
    public func effective(_ mode: ApprovalMode) -> ApprovalMode? {
        switch mode {
        case .none: return ApprovalMode.none
        case .biometricsOnly: return touchID ? .biometricsOnly : (password ? .deviceOwner : nil)
        case .deviceOwner: return password ? .deviceOwner : (touchID ? .biometricsOnly : nil)
        }
    }

    /// True when `mode` is asked for but a different prompt will be shown in its place.
    public func usesFallback(for mode: ApprovalMode) -> Bool {
        guard mode != .none, let shown = effective(mode) else { return false }
        return shown != mode
    }
}
