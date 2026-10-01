import Foundation

/// Looks up translations by their English text.
///
/// The English text is the key. Strings with names or numbers in them use `%@` for each one ("Paired with %@"), and a
/// translation may reorder them with `%1$@`, `%2$@`. `translate(_:)` also handles sentences that were already put
/// together in English ("Paired with Google Chrome"): it matches them against the templates and fills the translated
/// template with the pieces, translating each piece on its own too ("The browser isn't in front.").
public final class Localizer: @unchecked Sendable {
    private struct Template {
        let regex: NSRegularExpression
        let localized: String
        let literalLength: Int
    }

    private let table: [String: String]
    private let templates: [Template]

    /// An empty table is English: everything comes back as it went in.
    public init(table: [String: String]) {
        self.table = table
        var found: [Template] = []
        for (key, value) in table where key.contains("%@") && !value.isEmpty {
            let parts = key.components(separatedBy: "%@")
            let pattern = "^" + parts.map { NSRegularExpression.escapedPattern(for: $0) }.joined(separator: "(.+?)") + "$"
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else { continue }
            found.append(Template(regex: regex, localized: value, literalLength: parts.reduce(0) { $0 + $1.count }))
        }
        // The most specific template first, so "…because you were busy in %@…" wins over "…because %@…".
        templates = found.sorted { $0.literalLength > $1.literalLength }
    }

    public var isEnglish: Bool { table.isEmpty }

    /// The translation of a fixed string, or the string itself.
    public func string(_ key: String) -> String {
        guard let value = table[key], !value.isEmpty else { return key }
        return value
    }

    /// The translation of a string with `%@` placeholders, filled in.
    public func format(_ key: String, _ args: [String]) -> String {
        let template = string(key)
        guard !args.isEmpty else { return template }
        return String(format: template, arguments: args.map { $0 as NSString })
    }

    /// Translates a sentence that has already been put together in English. Anything it doesn't know comes back unchanged.
    public func translate(_ message: String, depth: Int = 0) -> String {
        if isEnglish { return message }
        if let exact = table[message], !exact.isEmpty { return exact }
        guard depth < 3 else { return message }
        let whole = NSRange(message.startIndex..., in: message)
        for template in templates {
            guard let match = template.regex.firstMatch(in: message, options: [], range: whole) else { continue }
            var pieces: [String] = []
            for index in 1..<match.numberOfRanges {
                guard let range = Range(match.range(at: index), in: message) else { return message }
                pieces.append(translate(String(message[range]), depth: depth + 1))
            }
            return String(format: template.localized, arguments: pieces.map { $0 as NSString })
        }
        return message
    }
}
