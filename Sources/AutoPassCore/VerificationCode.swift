import Foundation

public enum VerificationCode {
    /// Parses the text Apple's helper shows, e.g. "474 311". Whitespace and invisible formatting
    /// characters (bidi marks, thin spaces) are ignored. Returns nil unless exactly six ASCII
    /// digits remain, so a window that merely contains other numbers can never be mistaken for a code.
    public static func parse(_ text: String) -> String? {
        var digits = ""
        for scalar in text.unicodeScalars {
            if CharacterSet.whitespacesAndNewlines.contains(scalar) { continue }
            if scalar.properties.generalCategory == .format { continue }
            guard scalar.value >= 0x30, scalar.value <= 0x39 else { return nil }
            digits.unicodeScalars.append(scalar)
        }
        return digits.count == 6 ? digits : nil
    }
}
