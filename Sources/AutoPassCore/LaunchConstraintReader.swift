import Foundation

/// One entry of the allow-list in Apple's helper: browsers with this team ID and one of these
/// signing identifiers may launch it.
public struct AllowedBrowserGroup: Equatable, Sendable {
    public var teamID: String
    public var signingIDs: [String]
}

/// Reads the parent launch constraint embedded in the helper's code signature, so the "supported
/// browsers" list always reflects *this* Mac's helper (it changes with macOS updates) instead of a
/// copy that goes stale. The constraint is a DER blob in the signature's SuperBlob (slot 9).
public enum LaunchConstraintReader {
    public static let helperBinaryPath =
        "/System/Cryptexes/App/System/Library/CoreServices/PasswordManagerBrowserExtensionHelper.app/Contents/MacOS/PasswordManagerBrowserExtensionHelper"

    static let parentConstraintSlot: UInt32 = 9

    public static func allowedBrowsers(helperBinary: URL = URL(fileURLWithPath: helperBinaryPath)) -> [AllowedBrowserGroup]? {
        guard let data = try? Data(contentsOf: helperBinary, options: .mappedIfSafe),
              let der = parentConstraintDER(inMachO: data) else { return nil }
        let groups = groups(fromConstraintDER: der)
        return groups.isEmpty ? nil : groups
    }

    // MARK: Constraint DER -> groups

    public static func groups(fromConstraintDER der: Data) -> [AllowedBrowserGroup] {
        let strings = derStrings([UInt8](der))
        var groups: [AllowedBrowserGroup] = []
        var ids: [String] = []
        var collecting = false
        var i = 0
        while i < strings.count {
            switch strings[i] {
            case "signing-identifier":
                collecting = true
                ids = []
            case "team-identifier":
                collecting = false
                if i + 1 < strings.count, TrustedBrowser.isValidTeamID(strings[i + 1]), !ids.isEmpty {
                    groups.append(AllowedBrowserGroup(teamID: strings[i + 1], signingIDs: ids))
                    i += 1
                }
            default:
                if collecting, !strings[i].hasPrefix("$") { ids.append(strings[i]) }
            }
            i += 1
        }
        return groups
    }

    /// UTF8String values of a DER document in document order (constructed types are descended into).
    static func derStrings(_ d: [UInt8]) -> [String] {
        var out: [String] = []
        func walk(_ start: Int, _ end: Int, depth: Int) {
            guard depth < 32 else { return }
            var i = start
            while i < end {
                let tag = d[i]; i += 1
                guard i < end else { return }
                var len = Int(d[i]); i += 1
                if len & 0x80 != 0 {
                    let n = len & 0x7F
                    guard n > 0, n <= 4, i + n <= end else { return }
                    len = 0
                    for _ in 0..<n { len = (len << 8) | Int(d[i]); i += 1 }
                }
                guard len >= 0, i + len <= end else { return }
                if tag & 0x20 != 0 { walk(i, i + len, depth: depth + 1) }
                else if tag == 0x0C { out.append(String(decoding: d[i..<(i + len)], as: UTF8.self)) }
                i += len
            }
        }
        walk(0, d.count, depth: 0)
        return out
    }

    // MARK: Mach-O -> constraint DER

    static func parentConstraintDER(inMachO data: Data) -> Data? {
        for slice in machOSlices(data) {
            if let sig = codeSignature(in: data, slice: slice),
               let der = constraintBlob(in: data, signature: sig, slot: parentConstraintSlot) {
                return der
            }
        }
        return nil
    }

    private static func u32(_ d: Data, _ off: Int, bigEndian: Bool) -> UInt32? {
        guard off >= 0, off + 4 <= d.count else { return nil }
        let v = d.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: off, as: UInt32.self) }
        return bigEndian ? UInt32(bigEndian: v) : UInt32(littleEndian: v)
    }

    private static func machOSlices(_ d: Data) -> [Range<Int>] {
        guard let magicBE = u32(d, 0, bigEndian: true) else { return [] }
        if magicBE == 0xCAFEBABE || magicBE == 0xCAFEBABF {
            let is64 = magicBE == 0xCAFEBABF
            guard let n = u32(d, 4, bigEndian: true), n < 16 else { return [] }
            let entry = is64 ? 32 : 20
            var out: [Range<Int>] = []
            for k in 0..<Int(n) {
                let base = 8 + k * entry
                if is64 {
                    guard let offHi = u32(d, base + 8, bigEndian: true), let offLo = u32(d, base + 12, bigEndian: true),
                          let szHi = u32(d, base + 16, bigEndian: true), let szLo = u32(d, base + 20, bigEndian: true) else { continue }
                    let off = Int(offHi) << 32 | Int(offLo), size = Int(szHi) << 32 | Int(szLo)
                    if off >= 0, size > 0, off + size <= d.count { out.append(off..<(off + size)) }
                } else {
                    guard let off = u32(d, base + 8, bigEndian: true), let size = u32(d, base + 12, bigEndian: true) else { continue }
                    if Int(off) + Int(size) <= d.count { out.append(Int(off)..<(Int(off) + Int(size))) }
                }
            }
            return out
        }
        if u32(d, 0, bigEndian: false) == 0xFEEDFACF { return [0..<d.count] }
        return []
    }

    private static func codeSignature(in d: Data, slice: Range<Int>) -> Range<Int>? {
        guard u32(d, slice.lowerBound, bigEndian: false) == 0xFEEDFACF,
              let ncmds = u32(d, slice.lowerBound + 16, bigEndian: false), ncmds < 1024 else { return nil }
        var p = slice.lowerBound + 32
        for _ in 0..<Int(ncmds) {
            guard let cmd = u32(d, p, bigEndian: false), let size = u32(d, p + 4, bigEndian: false), size >= 8 else { return nil }
            if cmd == 0x1D, let off = u32(d, p + 8, bigEndian: false), let len = u32(d, p + 12, bigEndian: false) {
                let start = slice.lowerBound + Int(off)
                guard start + Int(len) <= slice.upperBound else { return nil }
                return start..<(start + Int(len))
            }
            p += Int(size)
        }
        return nil
    }

    static func constraintBlob(in d: Data, signature sig: Range<Int>, slot: UInt32) -> Data? {
        guard u32(d, sig.lowerBound, bigEndian: true) == 0xFADE0CC0,
              let count = u32(d, sig.lowerBound + 8, bigEndian: true), count < 64 else { return nil }
        for k in 0..<Int(count) {
            let idx = sig.lowerBound + 12 + k * 8
            guard let type = u32(d, idx, bigEndian: true), let off = u32(d, idx + 4, bigEndian: true) else { return nil }
            guard type == slot else { continue }
            let blob = sig.lowerBound + Int(off)
            guard u32(d, blob, bigEndian: true) == 0xFADE8181, let len = u32(d, blob + 4, bigEndian: true),
                  len > 8, blob + Int(len) <= sig.upperBound else { return nil }
            return d.subdata(in: (blob + 8)..<(blob + Int(len)))
        }
        return nil
    }
}
