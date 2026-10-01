import Foundation

/// Where to install or turn on Apple's iCloud Passwords extension, per browser.
public enum ExtensionLinks {
    /// Edge has its own listing and ID; every other Chromium browser uses the Chrome Web Store one.
    public static func extensionID(forSigningID signingID: String) -> String {
        signingID.hasPrefix("com.microsoft.edgemac") ? "mfbcdcnpokpoajjciilocoachedjkima" : "pejdijmoenmkgeppbflobdenhhabjlaj"
    }

    public static func installURL(forSigningID signingID: String) -> URL {
        let id = extensionID(forSigningID: signingID)
        if signingID.hasPrefix("com.microsoft.edgemac") {
            return URL(string: "https://microsoftedge.microsoft.com/addons/detail/icloud-passwords/\(id)")!
        }
        return URL(string: "https://chromewebstore.google.com/detail/icloud-passwords/\(id)")!
    }

    /// The browser's own extensions page for this extension, where it can be turned on.
    public static func manageURL(forSigningID signingID: String) -> URL {
        URL(string: "\(internalScheme(forSigningID: signingID))://extensions/?id=\(extensionID(forSigningID: signingID))")!
    }

    static func internalScheme(forSigningID id: String) -> String {
        let table: [(prefix: String, scheme: String)] = [
            ("com.microsoft.edgemac", "edge"),
            ("com.vivaldi.Vivaldi", "vivaldi"),
            ("com.brave.Browser", "brave"),
            ("company.thebrowser", "arc"),
            ("com.operasoftware", "opera"),
        ]
        return table.first { id.hasPrefix($0.prefix) }?.scheme ?? "chrome"
    }
}
