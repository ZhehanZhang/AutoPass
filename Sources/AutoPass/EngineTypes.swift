import Foundation

enum LogLevel { case info, warning, error }

struct LogEntry: Identifiable, Equatable {
    let id = UUID()
    let date = Date()
    let level: LogLevel
    /// Never contains a verification code.
    let message: String
}

enum EngineStatus: Equatable {
    case needsAccessibility
    case paused
    case idle                      // no trusted browser running
    case watching(String)          // a trusted browser is running; nothing to do right now
    case waiting(String)           // will open iCloud Passwords once the user is browsing
    case awaitingApproval
    case openingPopup
    case typing
    case paired(String)
    case attention(String)

    /// A full sentence for tooltips and the log.
    var summary: String {
        switch self {
        case .needsAccessibility: "AutoPass needs Accessibility access"
        case .paused: "Paused"
        case .idle: "No browser is open"
        case .watching(let b): "Watching \(b)"
        case .waiting(let b): "Waiting to pair with \(b)"
        case .awaitingApproval: "Waiting for your approval"
        case .openingPopup: "Opening iCloud Passwords"
        case .typing: "Filling in the code"
        case .paired(let b): "Paired with \(b)"
        case .attention(let why): why
        }
    }

    /// Whether the status disc is a solid tint (there is something to say) or clear glass (quiet).
    var isLoud: Bool {
        switch self {
        case .paired, .needsAccessibility, .attention, .awaitingApproval, .openingPopup, .typing: true
        case .paused, .watching, .waiting, .idle: false
        }
    }

    var isWorking: Bool {
        switch self { case .awaitingApproval, .openingPopup, .typing: true; default: false }
    }
    var isPaired: Bool {
        if case .paired = self { true } else { false }
    }
}

struct BrowserHealth: Identifiable, Equatable {
    var id: pid_t { pid }
    let signingID: String
    let name: String
    let pid: pid_t
    let helperRunning: Bool
    /// AutoPass looked for iCloud Passwords in this browser and didn't find it (not installed, or turned off).
    let extensionMissing: Bool
    let paired: Bool?
}

struct Health: Equatable {
    var accessibility = false
    var postEvents = false
    var browsers: [BrowserHealth] = []
}

/// iCloud Passwords isn't in a browser: the user can install it or turn it on.
struct ExtensionPrompt: Sendable {
    let browserName: String
    let bundleID: String
    let signingID: String
    /// The user asked for pairing (so an alert is fine), as opposed to AutoPass trying on its own.
    let userInitiated: Bool
}

/// Everything the engine reports back to the UI. Closures hop to the main actor on the receiving side.
struct EngineSink: Sendable {
    var status: @Sendable (EngineStatus) -> Void
    var log: @Sendable (LogLevel, String) -> Void
    var health: @Sendable (Health) -> Void
    var notify: @Sendable (String, String) -> Void
    var promptExtension: @Sendable (ExtensionPrompt) -> Void
    /// Diagnostics for the system log only (never shown in the UI, never contains codes or page addresses).
    var trace: @Sendable (String) -> Void
}
