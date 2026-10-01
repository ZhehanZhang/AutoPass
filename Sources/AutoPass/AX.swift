import Cocoa
import ApplicationServices

/// Thin Accessibility helpers. All reads are bounded by a messaging timeout so a hung browser
/// can't stall the engine.
enum AX {
    static func app(_ pid: pid_t) -> AXUIElement {
        let el = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(el, 1.0)
        return el
    }

    static func attr(_ el: AXUIElement, _ name: String) -> AnyObject? {
        var v: AnyObject?
        return AXUIElementCopyAttributeValue(el, name as CFString, &v) == .success ? v : nil
    }

    static func string(_ el: AXUIElement, _ name: String) -> String? { attr(el, name) as? String }
    static func role(_ el: AXUIElement) -> String { string(el, kAXRoleAttribute) ?? "" }
    static func children(_ el: AXUIElement) -> [AXUIElement] { (attr(el, kAXChildrenAttribute) as? [AXUIElement]) ?? [] }
    static func windows(_ el: AXUIElement) -> [AXUIElement] { (attr(el, kAXWindowsAttribute) as? [AXUIElement]) ?? [] }
    static func focused(_ el: AXUIElement) -> AXUIElement? { (attr(el, kAXFocusedUIElementAttribute)).map { $0 as! AXUIElement } }
    static func parent(_ el: AXUIElement) -> AXUIElement? { (attr(el, kAXParentAttribute)).map { $0 as! AXUIElement } }

    static func url(_ el: AXUIElement) -> String? {
        guard let v = attr(el, "AXURL") else { return nil }
        return (v as? URL)?.absoluteString ?? (v as? String)
    }

    /// Any of the attributes a browser might use to name a toolbar button.
    static func labels(_ el: AXUIElement) -> [String] {
        [kAXTitleAttribute, kAXDescriptionAttribute, kAXHelpAttribute].compactMap { string(el, $0) }
    }

    /// Depth-first walk. `skip` prunes a subtree (used to avoid walking whole web pages).
    static func walk(_ el: AXUIElement, depth: Int = 0, maxDepth: Int = 40,
                     skip: (AXUIElement) -> Bool = { _ in false }, visit: (AXUIElement) -> Void) {
        visit(el)
        guard depth < maxDepth, !skip(el) else { return }
        for c in children(el) { walk(c, depth: depth + 1, maxDepth: maxDepth, skip: skip, visit: visit) }
    }

    static func descendants(of el: AXUIElement, maxDepth: Int = 40, where match: (AXUIElement) -> Bool) -> [AXUIElement] {
        var out: [AXUIElement] = []
        walk(el, maxDepth: maxDepth) { if match($0) { out.append($0) } }
        return out
    }

    static func isTrusted(prompt: Bool) -> Bool {
        AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: prompt] as CFDictionary)
    }
}
