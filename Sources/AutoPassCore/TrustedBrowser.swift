import Foundation

/// A browser the user has chosen to trust. Identity is the *code signature* (signing identifier
/// plus Apple-issued team ID), never the app's name or path, so a renamed or lookalike app is not trusted.
public struct TrustedBrowser: Codable, Hashable, Identifiable, Sendable {
    public var name: String
    public var bundleID: String
    public var signingID: String
    public var teamID: String
    public var isEnabled: Bool

    public var id: String { signingID }

    public init(name: String, bundleID: String, signingID: String, teamID: String, isEnabled: Bool = true) {
        self.name = name
        self.bundleID = bundleID
        self.signingID = signingID
        self.teamID = teamID
        self.isEnabled = isEnabled
    }

    public static let chrome = TrustedBrowser(
        name: "Google Chrome", bundleID: "com.google.Chrome", signingID: "com.google.Chrome", teamID: "EQHXZ8M8AV")

    /// Values are interpolated into a code-signing requirement, so anything unexpected is rejected
    /// (policy is read back from storage and must not be able to inject requirement syntax).
    public var isWellFormed: Bool {
        Self.isValidIdentifier(signingID) && Self.isValidIdentifier(bundleID) && Self.isValidTeamID(teamID)
    }

    /// Satisfied only by a running process signed with this identifier by an Apple-issued certificate of this team.
    public var codeRequirement: String? {
        guard isWellFormed else { return nil }
        return #"identifier "\#(signingID)" and anchor apple generic and certificate leaf[subject.OU] = "\#(teamID)""#
    }

    static func isValidIdentifier(_ s: String) -> Bool {
        !s.isEmpty && s.count <= 255 && s.unicodeScalars.allSatisfy {
            ($0.value < 128) && (CharacterSet.alphanumerics.contains($0) || $0 == "." || $0 == "-" || $0 == "_")
        }
    }

    static func isValidTeamID(_ s: String) -> Bool {
        s.count == 10 && s.unicodeScalars.allSatisfy { ($0.value >= 0x30 && $0.value <= 0x39) || ($0.value >= 0x41 && $0.value <= 0x5A) }
    }
}
