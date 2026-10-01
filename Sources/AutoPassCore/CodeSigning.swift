import Foundation
import Security
import Darwin

public enum CodeSigning {
    /// Does the running process `pid` satisfy `requirement` (checked against its live code, not its path)?
    public static func process(_ pid: pid_t, satisfies requirement: String) -> Bool {
        var code: SecCode?
        let attrs = [kSecGuestAttributePid: pid] as CFDictionary
        guard SecCodeCopyGuestWithAttributes(nil, attrs, [], &code) == errSecSuccess, let code else { return false }
        var req: SecRequirement?
        guard SecRequirementCreateWithString(requirement as CFString, [], &req) == errSecSuccess, let req else { return false }
        return SecCodeCheckValidity(code, [], req) == errSecSuccess
    }

    public struct AppIdentity: Equatable, Sendable {
        public var name: String
        public var bundleID: String
        public var signingID: String
        public var teamID: String
    }

    public enum InspectError: Error, LocalizedError {
        case notAnApp, unreadable, invalidSignature, unidentifiedDeveloper

        public var errorDescription: String? {
            switch self {
            case .notAnApp: "That isn't an app."
            case .unreadable: "AutoPass couldn't read the app's signature."
            case .invalidSignature: "The app's signature isn't valid."
            case .unidentifiedDeveloper: "The app isn't signed by an identified developer, so AutoPass can't trust it."
            }
        }
    }

    /// Validates the bundle's signature and extracts the identity AutoPass would pin. Slow for large
    /// apps (validates every resource): call off the main thread.
    public static func inspectApp(at url: URL) throws -> AppIdentity {
        guard let bundle = Bundle(url: url), let bundleID = bundle.bundleIdentifier else { throw InspectError.notAnApp }
        var staticCode: SecStaticCode?
        guard SecStaticCodeCreateWithPath(url as CFURL, [], &staticCode) == errSecSuccess, let staticCode else { throw InspectError.unreadable }
        guard SecStaticCodeCheckValidityWithErrors(staticCode, SecCSFlags(rawValue: kSecCSCheckAllArchitectures), nil, nil) == errSecSuccess else {
            throw InspectError.invalidSignature
        }
        var info: CFDictionary?
        guard SecCodeCopySigningInformation(staticCode, SecCSFlags(rawValue: kSecCSSigningInformation), &info) == errSecSuccess,
              let dict = info as? [String: Any], let signingID = dict[kSecCodeInfoIdentifier as String] as? String else { throw InspectError.unreadable }
        guard let team = dict[kSecCodeInfoTeamIdentifier as String] as? String, TrustedBrowser.isValidTeamID(team) else { throw InspectError.unidentifiedDeveloper }
        let name = (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
            ?? (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String)
            ?? url.deletingPathExtension().lastPathComponent
        return AppIdentity(name: name, bundleID: bundleID, signingID: signingID, teamID: team)
    }
}

public enum ProcessInspector {
    public static func parentPID(of pid: pid_t) -> pid_t? {
        var info = proc_bsdinfo()
        let n = proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, Int32(MemoryLayout<proc_bsdinfo>.size))
        return n == Int32(MemoryLayout<proc_bsdinfo>.size) ? pid_t(info.pbi_ppid) : nil
    }

    /// When the process started (seconds since 1970). With the pid it identifies one process even across AutoPass restarts.
    public static func startTime(of pid: pid_t) -> Int? {
        var info = proc_bsdinfo()
        let n = proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, Int32(MemoryLayout<proc_bsdinfo>.size))
        return n == Int32(MemoryLayout<proc_bsdinfo>.size) ? Int(info.pbi_start_tvsec) : nil
    }

    /// argv of a same-user process (KERN_PROCARGS2 layout: argc, exec path, NUL padding, argv...).
    public static func arguments(of pid: pid_t) -> [String] {
        var mib: [Int32] = [CTL_KERN, KERN_PROCARGS2, pid]
        var size = 0
        guard sysctl(&mib, 3, nil, &size, nil, 0) == 0, size > 4 else { return [] }
        var buf = [UInt8](repeating: 0, count: size)
        guard sysctl(&mib, 3, &buf, &size, nil, 0) == 0, size > 4 else { return [] }
        let argc = Int(buf.withUnsafeBytes { $0.loadUnaligned(as: Int32.self) })
        let parts = buf[4..<size].split(separator: 0, omittingEmptySubsequences: true)
            .map { String(decoding: $0, as: UTF8.self) }
        return Array(parts.dropFirst().prefix(argc))   // drop exec path; keep argv
    }
}
