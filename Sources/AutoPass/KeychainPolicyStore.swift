import Foundation
import Security
import AutoPassCore

/// Stores the security policy as a generic-password item in the login keychain. The item's access list
/// is the creating app (by code signature), so another process reading or rewriting it triggers a
/// system prompt instead of silently turning approval off or trusting a new browser.
enum KeychainPolicyStore {
    /// "com.zhehanz.AutoPass.policy" for the real app. It follows the bundle identifier, so a differently identified copy
    /// (a test build) never reads or overwrites this app's policy.
    private static let service = (Bundle.main.bundleIdentifier ?? "com.zhehanz.AutoPass") + ".policy"
    private static let account = "security-policy-v1"

    enum LoadResult {
        case loaded(SecurityPolicy)
        case none                       // first run
        case failed(String)             // present but unreadable (denied prompt, corrupt data, ...)
    }

    private static var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: account]
    }

    static func load() -> LoadResult {
        var q = query
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var out: CFTypeRef?
        let status = SecItemCopyMatching(q as CFDictionary, &out)
        switch status {
        case errSecSuccess:
            guard let data = out as? Data, let policy = try? JSONDecoder().decode(SecurityPolicy.self, from: data) else {
                return .failed("the stored policy is corrupt")
            }
            return .loaded(policy.sanitized())
        case errSecItemNotFound:
            return .none
        default:
            return .failed(SecCopyErrorMessageString(status, nil) as String? ?? "keychain error \(status)")
        }
    }

    static func save(_ policy: SecurityPolicy) throws {
        let data = try JSONEncoder().encode(policy.sanitized())
        let status = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if status == errSecItemNotFound {
            var add = query
            add[kSecValueData as String] = data
            add[kSecAttrLabel as String] = "AutoPass security policy"
            let addStatus = SecItemAdd(add as CFDictionary, nil)
            guard addStatus == errSecSuccess else { throw StoreError(status: addStatus) }
        } else if status != errSecSuccess {
            throw StoreError(status: status)
        }
    }

    struct StoreError: LocalizedError {
        let status: OSStatus
        var errorDescription: String? { SecCopyErrorMessageString(status, nil) as String? ?? "keychain error \(status)" }
    }
}
