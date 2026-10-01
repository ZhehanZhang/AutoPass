import Foundation
import ServiceManagement
import AutoPassCore

/// What the system currently allows AutoPass to do. Shown in Settings and refreshed while the window is open and
/// whenever AutoPass becomes the active app (you've probably just been in System Settings).
struct Permissions: Equatable {
    enum Notifications: Equatable {
        case unknown        // not running as an app bundle
        case notAsked
        case allowed
        case denied
    }

    enum LoginItem: Equatable {
        case off
        case on
        case needsApproval  // registered, but you have to allow it in System Settings → Login Items
        case unavailable
    }

    var accessibility = false
    var notifications: Notifications = .unknown
    var loginItem: LoginItem = .off
    var auth = AuthAvailability(touchID: true, password: true)
}

extension SMAppService.Status {
    var loginItem: Permissions.LoginItem {
        switch self {
        case .enabled: .on
        case .requiresApproval: .needsApproval
        case .notRegistered: .off
        default: .unavailable
        }
    }
}
