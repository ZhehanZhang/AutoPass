import Foundation

/// Facts about Apple's iCloud Passwords browser extension that the helper relies on.
public enum ICloudExtension {
    /// Chrome Web Store ID (Chrome, Vivaldi, Brave, Arc, ...) and the Edge Add-ons ID.
    /// Both are hard-coded in Apple's native messaging manifest and in the helper binary.
    public static let officialIDs: Set<String> = [
        "pejdijmoenmkgeppbflobdenhhabjlaj",
        "mfbcdcnpokpoajjciilocoachedjkima",
    ]

    public static let helperBundleID = "com.apple.PasswordManagerBrowserExtensionHelper"
    public static let helperRequirement = #"anchor apple and identifier "com.apple.PasswordManagerBrowserExtensionHelper""#

    /// The helper is launched by the browser as `helper chrome-extension://<id>/`.
    /// Returns the extension ID only if it is one of Apple's.
    public static func extensionID(fromHelperArguments args: [String]) -> String? {
        let prefix = "chrome-extension://"
        guard let origin = args.first(where: { $0.hasPrefix(prefix) }) else { return nil }
        let id = origin.dropFirst(prefix.count).prefix { $0 != "/" }.lowercased()
        return officialIDs.contains(id) ? id : nil
    }

    /// Any of Apple's popup pages, regardless of which browser's extension ID it is.
    public static func isOfficialPopupURL(_ string: String) -> Bool {
        officialIDs.contains { isPopupURL(string, extensionID: $0) }
    }

    /// True for `chrome-extension://<id>/page_popup.html` (optionally `?popupWindow=1`, the
    /// stand-alone window the in-page "Enable Password AutoFill" prompt opens).
    public static func isPopupURL(_ string: String, extensionID: String) -> Bool {
        guard let url = URLComponents(string: string),
              url.scheme == "chrome-extension",
              url.host?.lowercased() == extensionID,
              url.path == "/page_popup.html",
              url.fragment == nil, url.user == nil, url.port == nil
        else { return false }
        return url.query == nil || url.query == "popupWindow=1"
    }
}
