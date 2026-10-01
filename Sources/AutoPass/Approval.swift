import Foundation
import LocalAuthentication
import AutoPassCore

/// Touch ID / Apple Watch / password gate. The system draws the prompt; AutoPass never sees credentials.
enum Approval {
    enum Outcome {
        case approved
        case cancelled
        case unavailable(String)
        case failed(String)
    }

    /// What this Mac can show right now.
    static func availability() -> AuthAvailability {
        func can(_ policy: LAPolicy) -> Bool { LAContext().canEvaluatePolicy(policy, error: nil) }
        return AuthAvailability(touchID: can(.deviceOwnerAuthenticationWithBiometrics), password: can(.deviceOwnerAuthentication))
    }

    static func authenticate(mode: ApprovalMode, reason: String) async -> Outcome {
        guard mode != .none else { return .approved }
        // Touch ID on a Mac that can't offer it asks for the password instead. If nothing can be shown, say so: the caller
        // refuses, it never treats that as approved.
        guard let shown = availability().effective(mode) else { return .unavailable("authentication is not available") }
        let context = LAContext()
        context.touchIDAuthenticationAllowableReuseDuration = 0
        let policy: LAPolicy = shown == .biometricsOnly ? .deviceOwnerAuthenticationWithBiometrics : .deviceOwnerAuthentication
        var error: NSError?
        guard context.canEvaluatePolicy(policy, error: &error) else {
            return .unavailable(error?.localizedDescription ?? "authentication is not available")
        }
        do {
            return try await context.evaluatePolicy(policy, localizedReason: reason) ? .approved : .failed("not approved")
        } catch let e as LAError where [.userCancel, .appCancel, .systemCancel].contains(e.code) {
            return .cancelled
        } catch {
            return .failed(error.localizedDescription)
        }
    }
}
