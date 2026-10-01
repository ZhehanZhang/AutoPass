import Foundation

/// Command-line flags that mean a browser is not a plain, user-driven instance: automation,
/// remote debugging, throwaway profiles, or sideloaded extensions. A browser launched this way
/// can host a forged copy of Apple's extension, so AutoPass never types into it.
public enum LaunchFlags {
    public static let risky: [String] = [
        "--user-data-dir",
        "--remote-debugging-port",
        "--remote-debugging-pipe",
        "--remote-debugging-address",
        "--remote-allow-origins",
        "--enable-automation",
        "--headless",
        "--load-extension",
        "--disable-extensions-except",
        "--enable-unsafe-extension-debugging",
        "--extensions-on-extension-urls",
        "--disable-web-security",
        "--no-sandbox",
    ]

    /// Flag names (without values) present in `args` that are on the risky list.
    public static func findRisky(in args: [String]) -> [String] {
        var found: [String] = []
        for arg in args where arg.hasPrefix("--") {
            let name = String(arg.prefix { $0 != "=" })
            if risky.contains(name), !found.contains(name) { found.append(name) }
        }
        return found
    }
}
