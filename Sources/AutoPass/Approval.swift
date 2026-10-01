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

    static func authenticate(mode: ApprovalMode, reason: String) async -> Outcome {
        guard mode != .none else { return .approved }
        let context = LAContext()
        context.touchIDAuthenticationAllowableReuseDuration = 0
        let policy: LAPolicy = mode == .biometricsOnly ? .deviceOwnerAuthenticationWithBiometrics : .deviceOwnerAuthentication
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
