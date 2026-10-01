import Cocoa
import ApplicationServices
import AutoPassCore

// MARK: Apple's helper

struct HelperReading {
    let pid: pid_t
    let parentPID: pid_t
    let hasWindow: Bool
    /// When this helper process started (seconds since 1970), if readable.
    let startTime: Int?
    /// Stable identity of this helper process: pid plus start time. nil if the start time couldn't be read.
    let identity: String?
    /// Parsed only if some text in the helper's window is exactly six digits.
    let code: String?
    /// The window's Done button, found during the same read, so closing it later is a single press.
    let doneButton: AXUIElement?
    /// For diagnostics when no code could be read: roles and lengths of the window's text, never the text itself.
    let shape: String
}

enum HelperScanner {
    private static let windowControls: Set<String> = [kAXCloseButtonSubrole, kAXMinimizeButtonSubrole, kAXZoomButtonSubrole, kAXFullScreenButtonSubrole]

    /// Closes Apple's code window with the Done button found when it was read (one press), falling back to looking for it.
    static func dismiss(_ reading: HelperReading) -> Bool {
        if let done = reading.doneButton, AXUIElementPerformAction(done, kAXPressAction as CFString) == .success { return true }
        return dismiss(pid: reading.pid)
    }

    /// Presses the Done button of Apple's code window, closing it. The pairing code stays valid for the extension; the window
    /// only exists so a person can read the code.
    static func dismiss(pid: pid_t) -> Bool {
        let windowControls: Set<String> = [kAXCloseButtonSubrole, kAXMinimizeButtonSubrole, kAXZoomButtonSubrole, kAXFullScreenButtonSubrole]
        for window in AX.windows(AX.app(pid)) {
            var done: AXUIElement?
            AX.walk(window, maxDepth: 12) { el in
                guard done == nil, AX.role(el) == kAXButtonRole, !windowControls.contains(AX.string(el, kAXSubroleAttribute) ?? "") else { return }
                done = el
            }
            if let done { return AXUIElementPerformAction(done, kAXPressAction as CFString) == .success }
        }
        return false
    }

    static func scan() -> [HelperReading] {
        NSRunningApplication.runningApplications(withBundleIdentifier: ICloudExtension.helperBundleID).map { app in
            let pid = app.processIdentifier
            let windows = AX.windows(AX.app(pid))
            var code: String?
            var done: AXUIElement?
            var shape: [String] = []
            for window in windows {
                AX.walk(window, maxDepth: 12) { el in
                    let role = AX.role(el)
                    if done == nil, role == kAXButtonRole, !windowControls.contains(AX.string(el, kAXSubroleAttribute) ?? "") { done = el }
                    guard role == kAXStaticTextRole || role == kAXTextFieldRole else { return }
                    let text = AX.string(el, kAXValueAttribute)
                    shape.append("\(role)(\(text.map { "len=\($0.count),digits=\($0.filter(\.isNumber).count)" } ?? "no-value"))")
                    if code == nil, let text { code = VerificationCode.parse(text) }
                }
            }
            let start = ProcessInspector.startTime(of: pid)
            return HelperReading(pid: pid, parentPID: ProcessInspector.parentPID(of: pid) ?? -1,
                                 hasWindow: !windows.isEmpty,
                                 startTime: start,
                                 identity: start.map { "\(pid)@\($0)" },
                                 code: code, doneButton: done, shape: "windows=\(windows.count) \(shape)")
        }
    }
}

// MARK: The browser

struct PopupReading {
    /// The window holding the popup, so it can be moved.
    let window: AXUIElement?
    let url: String
    let fields: [AXUIElement]
    let values: [String]
    let focusedIndex: Int?
    /// Position of the whole popup page; the same popup can be exposed under two windows, and this is how they're matched.
    let areaFrame: CGRect?
    /// The page's own ✕ (close) link in its top-right corner, if present.
    let closeButton: AXUIElement?
}

enum ToolbarSearch {
    case found(AXUIElement)
    case notFound
    case noWindow
}

/// What a web area in a browser's accessibility tree is.
enum PageKind {
    /// A website (http, https, file, ...). Never descended into; only its URL scheme is read.
    case content
    /// One of Apple's extension pages.
    case officialExtension
    /// Anything else: the browser's own interface. Vivaldi, for example, draws its whole UI (toolbar, tabs) as
    /// web content from its own `chrome-extension://` pages, so these are descended into.
    case browserUI

    static func of(_ url: String?) -> PageKind {
        guard let url, let parts = URLComponents(string: url), let scheme = parts.scheme?.lowercased() else { return .browserUI }
        if ["http", "https", "file", "ftp", "about", "data", "blob", "view-source"].contains(scheme) { return .content }
        if scheme == "chrome-extension", ICloudExtension.officialIDs.contains(parts.host?.lowercased() ?? "") { return .officialExtension }
        return .browserUI
    }
}

/// Reads a browser's UI tree. Website content is never descended into (only its URL scheme is read),
/// so page content is not observed.
final class BrowserScanner {
    private var forcedWebAX = Set<pid_t>()

    private static let buttonRoles: Set<String> = [kAXPopUpButtonRole, kAXButtonRole, kAXMenuButtonRole].reduce(into: []) { $0.insert($1) }

    private func app(_ pid: pid_t) -> AXUIElement {
        let el = AX.app(pid)
        _ = AX.role(el)      // Chrome builds its accessibility tree once a client reads the app's role
        return el
    }

    static func frame(_ el: AXUIElement) -> CGRect? {
        var pos = CGPoint.zero, size = CGSize.zero
        guard let p = AX.attr(el, kAXPositionAttribute), AXValueGetValue(p as! AXValue, .cgPoint, &pos),
              let s = AX.attr(el, kAXSizeAttribute), AXValueGetValue(s as! AXValue, .cgSize, &size) else { return nil }
        return CGRect(origin: pos, size: size)
    }

    static func sameSpot(_ a: CGRect?, _ b: CGRect?) -> Bool {
        guard let a, let b else { return false }
        return abs(a.minX - b.minX) < 2 && abs(a.minY - b.minY) < 2 && abs(a.width - b.width) < 2
    }

    private enum Step { case descend, skipChildren, stop }

    /// Depth-first walk of a window that treats web content correctly: browser-UI web areas are descended into,
    /// website content and Apple's popup are handed to `visit` but never entered. `budget` caps the work.
    @discardableResult
    private func walkUI(_ el: AXUIElement, depth: Int = 0, budget: inout Int,
                        _ visit: (AXUIElement, String, PageKind?) -> Step) -> Bool {
        guard budget > 0 else { return true }
        budget -= 1
        let role = AX.role(el)
        let kind: PageKind? = role == "AXWebArea" ? PageKind.of(AX.url(el)) : nil
        switch visit(el, role, kind) {
        case .stop: return true
        case .skipChildren: return false
        case .descend: break
        }
        guard depth < 40 else { return false }
        for child in AX.children(el) {
            if walkUI(child, depth: depth + 1, budget: &budget, visit) { return true }
        }
        return false
    }

    /// The same popup, read again cheaply: only the values and focus are fetched, not the whole window tree. nil if the popup
    /// has gone (its elements are no longer valid), in which case the caller scans afresh.
    func refresh(_ r: PopupReading, pid: pid_t) -> PopupReading? {
        guard !r.fields.isEmpty, AX.string(r.fields[0], kAXValueAttribute) != nil else { return nil }
        let focusFrame = AX.focused(app(pid)).flatMap(Self.frame)
        let frames = r.fields.map(Self.frame)
        let focused = focusFrame.flatMap { ff in frames.firstIndex { Self.sameSpot($0, ff) } }
        return PopupReading(window: r.window, url: r.url, fields: r.fields, values: r.fields.map { AX.string($0, kAXValueAttribute) ?? "" },
                            focusedIndex: focused, areaFrame: r.areaFrame, closeButton: r.closeButton)
    }

    /// Every Apple extension page open in the browser (deduplicated: Chrome can expose one popup under two windows).
    /// Other extension pages, including a browser's own interface, are ignored.
    ///
    /// Apple's popup is normally a window of its own, so those are searched first; the browser's main windows (a much
    /// bigger tree) are only walked if it isn't found there. If a second popup exists in a main window the first pass
    /// won't see it, which is safe: two popups mean two code windows, and the policy refuses to type then.
    func extensionPopups(pid: pid_t) -> [PopupReading] {
        let appEl = app(pid)
        let focus = AX.focused(appEl)
        let focusFrame = focus.flatMap(Self.frame)
        let windows = AX.windows(appEl)
        let isMain: (AXUIElement) -> Bool = { AX.string($0, kAXSubroleAttribute) == kAXStandardWindowSubrole }
        var sawWebArea = false

        func scan(_ windows: [AXUIElement]) -> [PopupReading] {
            var popups: [PopupReading] = []
            for window in windows {
                var budget = 2500
                walkUI(window, budget: &budget) { el, role, kind in
                    guard let kind else { return .descend }
                    sawWebArea = true
                    guard kind == .officialExtension, let url = AX.url(el) else { return kind == .browserUI ? .descend : .skipChildren }
                    let fields = AX.descendants(of: el, maxDepth: 25) { AX.role($0) == kAXTextFieldRole }
                    let frames = fields.map(Self.frame)
                    let focused = focusFrame.flatMap { ff in frames.firstIndex { Self.sameSpot($0, ff) } }
                    let area = Self.frame(el)
                    let close = AX.descendants(of: el, maxDepth: 25) { AX.role($0) == "AXLink" }.first { link in
                        guard let f = Self.frame(link), let a = area else { return false }
                        return f.minY - a.minY < 40 && a.maxX - f.maxX < 60      // top-right corner
                    }
                    let reading = PopupReading(window: AX.attr(el, kAXWindowAttribute).map { $0 as! AXUIElement }, url: url, fields: fields, values: fields.map { AX.string($0, kAXValueAttribute) ?? "" },
                                               focusedIndex: focused, areaFrame: area, closeButton: close)
                    if !popups.contains(where: { $0.url == url && Self.sameSpot($0.areaFrame, area) }) { popups.append(reading) }
                    return .skipChildren
                }
            }
            return popups
        }

        var popups = scan(windows.filter { !isMain($0) })
        if popups.isEmpty { popups = scan(windows.filter(isMain)) }
        if !sawWebArea, forcedWebAX.insert(pid).inserted {
            // Last resort when the browser exposes no web content at all: ask it for full accessibility mode.
            AXUIElementSetAttributeValue(appEl, "AXEnhancedUserInterface" as CFString, kCFBooleanTrue)
        }
        return popups
    }

    /// One-line description of what the browser exposes, for diagnostics. Only kinds and URL schemes, never addresses.
    func describeBrowsing(pid: pid_t) -> String {
        let appEl = app(pid)
        let windows = AX.windows(appEl)
        let main = AX.attr(appEl, kAXMainWindowAttribute)
        var seen: [String] = []
        for window in windows {
            var budget = 2500
            walkUI(window, budget: &budget) { el, _, kind in
                guard let kind else { return .descend }
                let scheme = AX.url(el).flatMap { URL(string: $0)?.scheme } ?? "no-url"
                seen.append("\(kind)/\(scheme)")
                return kind == .browserUI ? .descend : .skipChildren
            }
        }
        return "windows=\(windows.count) mainWindow=\(main != nil) webAreas=\(seen)"
    }

    /// True if the browser's main window has web content of any kind (a website, an internal page like a new tab, or a UI
    /// drawn as web content), i.e. the browser is up and in use. Apple's own popup doesn't count.
    func isBrowsingWebPage(pid: pid_t) -> Bool {
        let appEl = app(pid)
        let windows = [AX.attr(appEl, kAXMainWindowAttribute).map { $0 as! AXUIElement }].compactMap { $0 }
        for window in windows {
            var found = false
            var budget = 2500
            walkUI(window, budget: &budget) { el, _, kind in
                guard let kind else { return .descend }
                found = true                                   // a website, a new tab, or the browser's own web-drawn UI: it's up and in use
                return .stop
            }
            if found { return true }
        }
        return false
    }

    /// URL of the web page that currently holds keyboard focus (nil if focus isn't inside a web page).
    func focusedPageURL(pid: pid_t) -> String? {
        var el = AX.focused(app(pid))
        for _ in 0..<40 {
            guard let current = el else { return nil }
            if AX.role(current) == "AXWebArea" { return AX.url(current) }
            el = AX.parent(current)
        }
        return nil
    }

    /// What browsers call the toolbar's Extensions (puzzle piece) button, in the languages they ship in.
    private static let extensionsButtonNames = [
        "Extensions", "Extension", "扩展程序", "擴充功能", "拡張機能", "확장 프로그램", "Erweiterungen", "Extensiones",
        "Estensioni", "Extensões", "Расширения", "Extensies", "Uzantılar", "Rozszerzenia", "Tillägg",
    ]

    private static func isExtensionsButtonLabel(_ label: String) -> Bool {
        extensionsButtonNames.contains { label.caseInsensitiveCompare($0) == .orderedSame }
    }

    /// Of the elements whose label contains `hint`, the one that is the extension's own button: an exact
    /// "iCloud Passwords" if there is one, otherwise the shortest label (so "Pin iCloud Passwords" and
    /// "More actions for iCloud Passwords" lose to it).
    private static func best(_ candidates: [(el: AXUIElement, labels: [String])], hint: String) -> AXUIElement? {
        let hits: [(el: AXUIElement, label: String)] = candidates.compactMap { c in
            guard let label = c.labels.filter({ $0.range(of: hint, options: [.caseInsensitive, .diacriticInsensitive]) != nil })
                .min(by: { $0.count < $1.count }) else { return nil }
            return (c.el, label)
        }
        if let exact = hits.first(where: { $0.label.caseInsensitiveCompare("iCloud Passwords") == .orderedSame }) { return exact.el }
        return hits.min(by: { $0.label.count < $1.label.count })?.el
    }

    private func standardWindows(_ appEl: AXUIElement) -> [AXUIElement] {
        let windows = AX.windows(appEl).filter { AX.string($0, kAXSubroleAttribute) == kAXStandardWindowSubrole }
        let main = AX.attr(appEl, kAXMainWindowAttribute).map { $0 as! AXUIElement }
        return [main].compactMap { $0 } + windows
    }

    /// The two controls AutoPass can press to open iCloud Passwords.
    struct ToolbarElements {
        /// The button pinned in the toolbar, if it is pinned.
        var pinned: AXUIElement?
        /// The Extensions (puzzle piece) button, which lists extensions that aren't pinned.
        var extensionsButton: AXUIElement?
    }

    enum Located {
        case noWindow
        case elements(ToolbarElements)
    }

    private var toolbarCache: [pid_t: (elements: ToolbarElements, at: Date)] = [:]

    private static func isValid(_ el: AXUIElement?) -> Bool { el == nil || !AX.role(el!).isEmpty }

    /// Finds both buttons in one pass over the browser's windows (covering browsers that draw their toolbar as web content).
    /// Walking the window tree is the slowest thing AutoPass does, so the result is reused for 30 seconds while the elements
    /// are still valid; `force` skips the reuse.
    func locateToolbar(pid: pid_t, nameHint: String, force: Bool = false) -> Located {
        let appEl = app(pid)
        let windows = standardWindows(appEl)
        guard !windows.isEmpty else { return .noWindow }
        if !force, let c = toolbarCache[pid], Date().timeIntervalSince(c.at) < 30,
           Self.isValid(c.elements.pinned), Self.isValid(c.elements.extensionsButton) {
            return .elements(c.elements)
        }

        let hint = nameHint.trimmingCharacters(in: .whitespaces)
        var found = ToolbarElements()
        for window in windows {
            var pinnedCandidates: [(el: AXUIElement, labels: [String])] = []
            var extensions: AXUIElement?
            var exactPinned = false
            var budget = 2500
            walkUI(window, budget: &budget) { el, role, kind in
                if let kind { return kind == .browserUI ? .descend : .skipChildren }
                guard Self.buttonRoles.contains(role) else { return .descend }
                let labels = AX.labels(el)
                if extensions == nil, labels.contains(where: Self.isExtensionsButtonLabel) { extensions = el }
                if !hint.isEmpty, labels.contains(where: { $0.range(of: hint, options: [.caseInsensitive, .diacriticInsensitive]) != nil }) {
                    pinnedCandidates.append((el, labels))
                    if labels.contains(where: { $0.caseInsensitiveCompare("iCloud Passwords") == .orderedSame }) { exactPinned = true }
                }
                return exactPinned && extensions != nil ? .stop : .descend
            }
            if found.pinned == nil { found.pinned = Self.best(pinnedCandidates, hint: hint) }
            if found.extensionsButton == nil { found.extensionsButton = extensions }
            if found.pinned != nil && found.extensionsButton != nil { break }
        }
        toolbarCache[pid] = (found, Date())
        return .elements(found)
    }

    /// iCloud Passwords in the open Extensions menu. The menu is its own window in most browsers, so those are searched first;
    /// in Vivaldi and Edge it can be web content inside the main window, which is walked only if it isn't found.
    func extensionsMenuEntry(pid: pid_t, nameHint: String) -> AXUIElement? {
        let appEl = app(pid)
        let hint = nameHint.trimmingCharacters(in: .whitespaces)
        guard !hint.isEmpty else { return nil }
        let windows = AX.windows(appEl)
        let isMain: (AXUIElement) -> Bool = { AX.string($0, kAXSubroleAttribute) == kAXStandardWindowSubrole }

        func search(_ windows: [AXUIElement]) -> AXUIElement? {
            var candidates: [(el: AXUIElement, labels: [String])] = []
            for window in windows {
                var budget = 2500
                walkUI(window, budget: &budget) { el, role, kind in
                    if let kind { return kind == .browserUI ? .descend : .skipChildren }
                    if Self.buttonRoles.contains(role) || role == kAXMenuItemRole {
                        let labels = AX.labels(el)
                        if !labels.contains(where: Self.isExtensionsButtonLabel) { candidates.append((el, labels)) }
                    }
                    return .descend
                }
            }
            return Self.best(candidates, hint: hint)
        }
        return search(windows.filter { !isMain($0) }) ?? search(windows.filter(isMain))
    }

    func press(_ button: AXUIElement) -> Bool {
        AXUIElementPerformAction(button, kAXPressAction as CFString) == .success
    }

    /// Role, name and actions of an element, for diagnostics. Only used on controls matched by the extension's name.
    func describe(_ el: AXUIElement) -> String {
        var names: CFArray?
        AXUIElementCopyActionNames(el, &names)
        let actions = (names as? [String]) ?? []
        let frame = Self.frame(el).map { "\(Int($0.width))x\(Int($0.height))" } ?? "no frame"
        return "role=\(AX.role(el)) label=\(AX.labels(el)) actions=\(actions) size=\(frame)"
    }

    /// A real mouse click on a control, for browsers whose accessibility press doesn't open it. It only clicks if the
    /// element found at that spot on screen is the control itself (or part of it), so it can't land on something else.
    func click(_ el: AXUIElement, pid: pid_t) -> Bool {
        guard let f = Self.frame(el), f.width > 2, f.height > 2 else { return false }
        let point = CGPoint(x: f.midX, y: f.midY)
        var hit: AXUIElement?
        guard AXUIElementCopyElementAtPosition(app(pid), Float(point.x), Float(point.y), &hit) == .success, let hit else { return false }
        var node: AXUIElement? = hit
        var isTarget = false
        for _ in 0..<3 {
            guard let n = node else { break }
            if CFEqual(n, el) { isTarget = true; break }
            node = AX.parent(n)
        }
        guard isTarget else { return false }
        let source = CGEventSource(stateID: .privateState)
        guard let down = CGEvent(mouseEventSource: source, mouseType: .leftMouseDown, mouseCursorPosition: point, mouseButton: .left),
              let up = CGEvent(mouseEventSource: source, mouseType: .leftMouseUp, mouseCursorPosition: point, mouseButton: .left) else { return false }
        down.postToPid(pid)
        usleep(30_000)
        up.postToPid(pid)
        return true
    }
}
