// Read-only feasibility probe for AutoPass. It never types, clicks, or prints the code (digits are masked).
//
// 1. Give the terminal you run this from Accessibility permission
//    (System Settings > Privacy & Security > Accessibility).
// 2. Run: swift tools/ax-probe.swift 60
// 3. Within 60s, click the iCloud Passwords toolbar button in Chrome so the verification code window appears.
import Cocoa
import ApplicationServices

let helperID = "com.apple.PasswordManagerBrowserExtensionHelper"
let extOrigins = ["chrome-extension://pejdijmoenmkgeppbflobdenhhabjlaj/", "chrome-extension://mfbcdcnpokpoajjciilocoachedjkima/"]
let helperReq = #"identifier "com.apple.PasswordManagerBrowserExtensionHelper" and anchor apple"#
let chromeReq = #"identifier "com.google.Chrome" and anchor apple generic and certificate leaf[subject.OU] = "EQHXZ8M8AV""#
let wait = Double(CommandLine.arguments.dropFirst().first ?? "0") ?? 0

func attr(_ el: AXUIElement, _ name: String) -> AnyObject? {
    var v: AnyObject?
    return AXUIElementCopyAttributeValue(el, name as CFString, &v) == .success ? v : nil
}
func children(_ el: AXUIElement) -> [AXUIElement] { (attr(el, kAXChildrenAttribute) as? [AXUIElement]) ?? [] }
func role(_ el: AXUIElement) -> String { attr(el, kAXRoleAttribute) as? String ?? "" }
func mask(_ s: String) -> String { String(s.map { $0.isNumber ? "#" : $0 }) }
func url(_ el: AXUIElement) -> String? { (attr(el, "AXURL") as? URL)?.absoluteString ?? (attr(el, "AXURL").map { "\($0)" }) }
func all(_ el: AXUIElement, _ d: Int = 0) -> [AXUIElement] { d > 40 ? [] : [el] + children(el).flatMap { all($0, d + 1) } }

func signed(_ pid: pid_t, _ req: String) -> Bool {
    var code: SecCode?, r: SecRequirement?
    guard SecCodeCopyGuestWithAttributes(nil, [kSecGuestAttributePid: pid] as CFDictionary, [], &code) == errSecSuccess,
          SecRequirementCreateWithString(req as CFString, [], &r) == errSecSuccess, let code, let r else { return false }
    return SecCodeCheckValidity(code, [], r) == errSecSuccess
}
// argv of a same-user process via KERN_PROCARGS2 (layout: argc, exec path, NULs, argv...).
func args(_ pid: pid_t) -> [String] {
    var mib = [CTL_KERN, KERN_PROCARGS2, pid], size = 0
    guard sysctl(&mib, 3, nil, &size, nil, 0) == 0 else { return [] }
    var buf = [UInt8](repeating: 0, count: size)
    guard sysctl(&mib, 3, &buf, &size, nil, 0) == 0, size > 4 else { return [] }
    let argc = Int(buf.withUnsafeBytes { $0.load(as: Int32.self) })
    let parts = buf[4..<size].split(separator: 0, omittingEmptySubsequences: true).map { String(decoding: $0, as: UTF8.self) }
    return Array(parts.dropFirst().prefix(argc))
}
let riskyFlags = ["--user-data-dir", "--remote-debugging", "--load-extension", "--headless", "--enable-unsafe-extension-debugging", "--extensions-on-extension-urls"]

func parent(_ pid: pid_t) -> pid_t {
    var info = proc_bsdinfo()
    let n = proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, Int32(MemoryLayout<proc_bsdinfo>.size))
    return n > 0 ? pid_t(info.pbi_ppid) : -1
}

print("AXIsProcessTrusted:", AXIsProcessTrusted())
guard AXIsProcessTrusted() else { print("Grant Accessibility to this terminal first."); exit(1) }

// Wait for the helper's verification-code window.
var helper: NSRunningApplication?, windows: [AXUIElement] = []
let deadline = Date().addingTimeInterval(wait)
repeat {
    helper = NSRunningApplication.runningApplications(withBundleIdentifier: helperID).first
    if let h = helper { windows = (attr(AXUIElementCreateApplication(h.processIdentifier), kAXWindowsAttribute) as? [AXUIElement]) ?? [] }
    if !windows.isEmpty || Date() >= deadline { break }
    Thread.sleep(forTimeInterval: 0.25)
} while true
guard let helper else { print("Helper not running."); exit(0) }

let hpid = helper.processIdentifier, ppid = parent(hpid)
print("\n== Helper pid \(hpid) | Apple-signed: \(signed(hpid, helperReq)) | parent pid \(ppid) | AX windows: \(windows.count)")
for w in windows {
    for el in all(w) {
        guard let s = attr(el, kAXValueAttribute) as? String ?? attr(el, kAXTitleAttribute) as? String, !s.isEmpty else { continue }
        let compact = s.filter { !$0.isWhitespace }
        let isCode = compact.count == 6 && compact.allSatisfy(\.isASCII) && compact.allSatisfy(\.isNumber)
        print("  \(role(el)) \"\(mask(s))\"\(isCode ? "   <-- 6-digit code readable via AX" : "")")
    }
}
for w in (CGWindowListCopyWindowInfo([.optionAll], kCGNullWindowID) as? [[String: Any]]) ?? []
where (w[kCGWindowOwnerPID as String] as? pid_t) == hpid && (w[kCGWindowIsOnscreen as String] as? Bool) == true {
    print("  CGWindow layer=\(w[kCGWindowLayer as String] ?? "-") sharingState=\(w[kCGWindowSharingState as String] ?? "-") (0 = hidden from capture)")
}

// Inspect the browser that launched the helper.
guard let browser = NSRunningApplication(processIdentifier: ppid) else { exit(0) }
let bEl = AXUIElementCreateApplication(ppid)
_ = role(bEl) // Chrome turns its web AX tree on when a client reads the app's AXRole
Thread.sleep(forTimeInterval: 0.5)
let hasWebArea = ((attr(bEl, kAXWindowsAttribute) as? [AXUIElement]) ?? []).contains { all($0).contains { role($0) == "AXWebArea" } }
if !hasWebArea { // last resort: full screen-reader mode (side effects: slower Chrome, odd window animations)
    print("Chrome web AX tree was off; enabling AXEnhancedUserInterface")
    AXUIElementSetAttributeValue(bEl, "AXEnhancedUserInterface" as CFString, kCFBooleanTrue)
    Thread.sleep(forTimeInterval: 0.5)
}
print("\n== Parent \(browser.bundleIdentifier ?? "?") pid \(ppid) | Google-signed Chrome: \(signed(ppid, chromeReq)) | frontmost: \(browser.isActive)")
let flagged = args(ppid).filter { a in riskyFlags.contains { a.hasPrefix($0) } }
print("  launch flags that should block auto-fill: \(flagged.isEmpty ? "none" : flagged.joined(separator: " "))")
for w in (attr(bEl, kAXWindowsAttribute) as? [AXUIElement]) ?? [] {
    guard let web = all(w).first(where: { role($0) == "AXWebArea" }), let u = url(web) else { continue }
    let isExt = extOrigins.contains { u.hasPrefix($0) }
    let fields = all(web).filter { role($0) == "AXTextField" }
    print("  window webArea url=\(u) \(isExt ? "<-- iCloud Passwords popup" : "") textFields=\(fields.count)")
}
if let f = attr(bEl, kAXFocusedUIElementAttribute) {
    let f = f as! AXUIElement
    var anc: AXUIElement? = f
    while let a = anc, role(a) != "AXWebArea" { anc = attr(a, kAXParentAttribute).map { $0 as! AXUIElement } }
    print("  focused: \(role(f)) in webArea url=\(anc.flatMap(url) ?? "-")")
}
