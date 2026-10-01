import Foundation
import AutoPassCore

/// The language AutoPass shows. Each language is a `Localizable.strings` file in `Resources/<code>.lproj`, keyed by the
/// English text (see `Localizer`). English is the built-in text, so it needs no table. You can follow the Mac's language
/// or pick one in Settings, and the change applies straight away.
enum L10n {
    struct Language: Identifiable, Hashable {
        let code: String
        /// Written in the language itself, so it can always be found.
        let name: String
        var id: String { code }
    }

    static let languages: [Language] = [
        Language(code: "en", name: "English"),
        Language(code: "zh-Hans", name: "简体中文"),
        Language(code: "zh-Hant", name: "繁體中文"),
        Language(code: "es", name: "Español"),
        Language(code: "fr", name: "Français"),
        Language(code: "de", name: "Deutsch"),
        Language(code: "ja", name: "日本語"),
        Language(code: "ko", name: "한국어"),
        Language(code: "pt-BR", name: "Português (Brasil)"),
        Language(code: "ru", name: "Русский"),
        Language(code: "it", name: "Italiano"),
    ]

    /// The choice that follows the Mac's language.
    static let system = "system"

    private static let lock = NSLock()
    private static var localizer = Localizer(table: [:])
    private static var activeCode = "en"

    /// The language in use.
    static var code: String { lock.withLock { activeCode } }

    /// Switches language: `system`, or one of the codes above.
    static func select(_ choice: String) {
        let resolved = resolve(choice)
        let next = Localizer(table: table(for: resolved))
        lock.withLock { localizer = next; activeCode = resolved }
    }

    /// What a choice means right now. `system` is the closest language to the Mac's, or English.
    static func resolve(_ choice: String) -> String {
        if languages.contains(where: { $0.code == choice }) { return choice }
        let codes = languages.map(\.code)
        return Bundle.preferredLocalizations(from: codes, forPreferences: Locale.preferredLanguages).first ?? "en"
    }

    private static func table(for code: String) -> [String: String] {
        guard code != "en",
              let url = Bundle.main.url(forResource: "Localizable", withExtension: "strings", subdirectory: nil, localization: code),
              let strings = NSDictionary(contentsOf: url) as? [String: String] else { return [:] }
        return strings
    }

    /// A string with `%@` placeholders filled in English, whatever language is in use (for the system log).
    static func english(_ key: String, _ args: [String]) -> String {
        args.reduce(key) { text, arg in
            guard let range = text.range(of: "%@") else { return text }
            return text.replacingCharacters(in: range, with: arg)
        }
    }

    private static var current: Localizer { lock.withLock { localizer } }

    static func format(_ key: String, _ args: [String]) -> String { current.format(key, args) }

    /// Translates a sentence that was put together in English (Activity entries, status text, error messages).
    static func message(_ english: String) -> String { current.translate(english) }
}

/// The translation of a fixed string, or of one with `%@` placeholders filled in order by `args`.
func tr(_ key: String, _ args: String...) -> String { L10n.format(key, args) }
