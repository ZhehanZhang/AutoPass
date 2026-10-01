import SwiftUI
import AppKit

@main
struct AutoPassApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @ObservedObject private var model = AppModel.shared

    var body: some Scene {
        // SwiftUI writes this binding on every update; only assign real changes, or the write re-invalidates
        // the body and loops forever.
        MenuBarExtra(isInserted: Binding(get: { model.showMenuBarIcon }, set: { if model.showMenuBarIcon != $0 { model.showMenuBarIcon = $0 } })) {
            MenuContent(openSettings: { delegate.showSettings() })
                .environmentObject(model)
        } label: {
            MenuLabel().environmentObject(model)
        }
        .menuBarExtraStyle(.menu)
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    var model: AppModel { AppModel.shared }
    private let settings = SettingsWindow()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // First run (or permission revoked): open the window so the setup checklist is the first thing seen.
        if !AX.isTrusted(prompt: false) || CommandLine.arguments.contains("--settings") { showSettings() }
    }

    func showSettings() { settings.show(model: model) }

    /// Never leave a window hidden if AutoPass quits mid-pairing.
    func applicationWillTerminate(_ notification: Notification) { WindowHider.shared.restoreAll() }

    /// Opening AutoPass again (Finder, Spotlight) brings up Settings, which is the way back in if the menu bar icon is hidden.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showSettings()
        return true
    }
}

private struct MenuLabel: View {
    @EnvironmentObject var model: AppModel
    var body: some View { Image(nsImage: MenuBarIcon.image(for: model.status)) }
}

private struct MenuContent: View {
    @EnvironmentObject var model: AppModel
    let openSettings: () -> Void

    var body: some View {
        Text(model.status.short)
        Divider()
        Button("Pair Now") { model.pairNow() }
            .disabled(model.status == .needsAccessibility)
        if model.isPaused {
            Button("Resume") { model.setPaused(false) }
        } else {
            Menu("Pause") {
                Button("15 Minutes") { model.setPaused(true, minutes: 15) }
                Button("1 Hour") { model.setPaused(true, minutes: 60) }
                Button("Until I Resume") { model.setPaused(true) }
            }
        }
        Divider()
        if model.status == .needsAccessibility {
            Button("Grant Accessibility Access…") { model.requestAccessibility(); model.openAccessibilitySettings() }
        }
        Button("Settings…") { openSettings() }.keyboardShortcut(",")
        Divider()
        Button("Quit AutoPass") { NSApplication.shared.terminate(nil) }.keyboardShortcut("q")
    }
}

/// Owns the preferences window. The app is a menu bar agent (no Dock icon), so it has to become a
/// regular app while the window is open for the window to take focus properly.
@MainActor
final class SettingsWindow {
    let nav = SettingsNav()
    private var window: NSWindow?
    private var closeObserver: NSObjectProtocol?

    /// A System Settings–style window: full-size content under a transparent titlebar, so the glass
    /// sidebar and tinted detail pane run edge to edge.
    static func makeWindow(model: AppModel, nav: SettingsNav) -> NSWindow {
        let host = NSHostingController(rootView: SettingsView().environmentObject(model).environmentObject(nav))
        let w = NSWindow(contentViewController: host)
        w.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        w.titlebarAppearsTransparent = true
        w.titleVisibility = .hidden
        w.isMovableByWindowBackground = true
        w.isReleasedWhenClosed = false
        // A settings window has no use for full screen or a huge frame.
        w.setContentSize(NSSize(width: 840, height: 600))
        w.contentMinSize = NSSize(width: 800, height: 560)
        w.contentMaxSize = NSSize(width: 960, height: 720)
        w.collectionBehavior.insert(.fullScreenNone)
        w.standardWindowButton(.zoomButton)?.isEnabled = false
        w.center()
        return w
    }

    func show(model: AppModel) {
        if window == nil {
            let w = Self.makeWindow(model: model, nav: nav)
            w.title = "AutoPass"
            closeObserver = NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: w, queue: .main) { _ in
                NSApp.setActivationPolicy(.accessory)
            }
            window = w
        }
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}
