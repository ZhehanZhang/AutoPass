import SwiftUI
import AppKit

// MARK: Palette
//
// Calm and low-saturation: one faint cool backdrop, and small, muted semantic colors for state.

enum Palette {
    /// Paired / ready.
    static let ok = Color(hue: 0.40, saturation: 0.38, brightness: 0.72)
    /// Needs attention.
    static let warn = Color(hue: 0.10, saturation: 0.50, brightness: 0.88)
    /// Working.
    static let busy = Color(hue: 0.60, saturation: 0.36, brightness: 0.86)
    /// Armed and waiting.
    static let waiting = Color(hue: 0.55, saturation: 0.22, brightness: 0.78)
    /// The mark on clear glass while it waits: darker than `waiting` so the faint code dots still read.
    static let waitingInk = Color(hue: 0.58, saturation: 0.32, brightness: 0.58)
    /// Backdrop wash.
    static let wash = Color(hue: 0.60, saturation: 0.20, brightness: 0.90)
}

// MARK: Liquid Glass helpers
//
// Glass APIs are macOS 26+. Everything here falls back to materials and bordered buttons on older systems,
// so the rest of the UI can use these without availability checks.

extension View {
    /// Content panel: clear Liquid Glass, or a thin material before macOS 26.
    @ViewBuilder
    func cardSurface(cornerRadius: CGFloat = 24) -> some View {
        if #available(macOS 26.0, *), !Compat.noGlass {
            self.glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
        } else {
            // The same pale panel the glass shows, without the glass.
            self.background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous).fill(Color(nsColor: .textBackgroundColor).opacity(0.7))
                    .overlay(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous).strokeBorder(Color.white.opacity(0.5), lineWidth: 0.5))
                    .shadow(color: .black.opacity(0.05), radius: 12, y: 4)
            }
        }
    }

    /// A pill button. Liquid Glass on macOS 26+; without glass, the same size and shape with a plain translucent fill.
    @ViewBuilder
    func glassButton(prominent: Bool = false, tint: Color? = nil, large: Bool = false) -> some View {
        if #available(macOS 26.0, *), !Compat.noGlass {
            if prominent { self.buttonStyle(.glassProminent).buttonBorderShape(.capsule).tint(tint) } else { self.buttonStyle(.glass).buttonBorderShape(.capsule).tint(tint) }
        } else {
            self.buttonStyle(FlatButtonStyle(prominent: prominent, tint: tint, large: large))
        }
    }

    /// A round icon button, likewise.
    @ViewBuilder
    func glassIconButton(tint: Color? = nil) -> some View {
        if #available(macOS 26.0, *), !Compat.noGlass {
            self.buttonStyle(.glass).buttonBorderShape(.circle).tint(tint)
        } else {
            self.buttonStyle(FlatIconButtonStyle(tint: tint))
        }
    }
}

/// What a pill button looks like without glass: same size and shape, a plain material (or tint) fill, no glass.
struct FlatButtonStyle: ButtonStyle {
    var prominent = false
    var tint: Color?
    var large = false

    func makeBody(configuration: Configuration) -> some View { Dimmed(configuration: configuration, style: self) }

    private struct Dimmed: View {
        let configuration: Configuration
        let style: FlatButtonStyle
        @Environment(\.isEnabled) private var isEnabled

        var body: some View { style.render(configuration).opacity(isEnabled ? 1 : 0.4) }
    }

    fileprivate func render(_ configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(prominent ? Color.white : Color.primary)
            .padding(.horizontal, large ? 18 : 12)
            .padding(.vertical, large ? 6 : 4)
            .background {
                if prominent { Capsule().fill(tint ?? Color.accentColor) }
                else { Capsule().fill(Color(nsColor: .textBackgroundColor).opacity(0.7)) }
            }
            .overlay { if !prominent { Capsule().strokeBorder(Color.primary.opacity(0.10), lineWidth: 0.5) } }
            .opacity(configuration.isPressed ? 0.7 : 1)
            .contentShape(Capsule())
    }
}

struct FlatIconButtonStyle: ButtonStyle {
    var tint: Color?

    func makeBody(configuration: Configuration) -> some View { Dimmed(configuration: configuration, style: self) }

    private struct Dimmed: View {
        let configuration: Configuration
        let style: FlatIconButtonStyle
        @Environment(\.isEnabled) private var isEnabled

        var body: some View { style.render(configuration).opacity(isEnabled ? 1 : 0.4) }
    }

    fileprivate func render(_ configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(tint ?? Color.primary)
            .padding(4)
            .background(Circle().fill(Color(nsColor: .textBackgroundColor).opacity(0.7)).padding(-1))
            .overlay(Circle().strokeBorder(Color.primary.opacity(0.10), lineWidth: 0.5).padding(-1))
            .opacity(configuration.isPressed ? 0.7 : 1)
            .contentShape(Circle())
    }
}

// MARK: Locked controls

extension View {
    /// Controls that need settings to be unlocked. While locked they look disabled, and clicking one asks for Touch ID
    /// or your password straight away instead of doing nothing.
    func lockGated(dims: Bool = true) -> some View { modifier(LockGate(dims: dims)) }
}

private struct LockGate: ViewModifier {
    @EnvironmentObject var model: AppModel
    let dims: Bool

    func body(content: Content) -> some View {
        content
            .disabled(model.isLocked)
            .opacity(dims && model.isLocked ? 0.6 : 1)
            .overlay {
                if model.isLocked {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture { Task { await model.unlock() } }
                        .help("Unlock to change this")
                }
            }
    }
}

// MARK: Navigation

enum SettingsPane: String, CaseIterable, Identifiable {
    case browsers, security, general

    var id: String { rawValue }

    var title: String {
        switch self {
        case .browsers: "AutoPass"
        case .security: "Security"
        case .general: "General"
        }
    }

    var symbol: String {
        switch self {
        case .browsers: "key.fill"      // unused: the sidebar draws the AutoPass mark
        case .security: "lock.shield"
        case .general: "gearshape"
        }
    }

}

@MainActor
final class SettingsNav: ObservableObject {
    @Published var pane: SettingsPane = .browsers
}

// MARK: Status styling

extension EngineStatus {
    var tint: Color {
        switch self {
        case .paired: Palette.ok
        case .needsAccessibility, .attention: Palette.warn
        case .awaitingApproval, .openingPopup, .typing: Palette.busy
        case .watching, .waiting: Palette.waiting
        case .paused, .idle: Color.secondary
        }
    }

    /// The mark's color on clear glass (quiet states); on a tinted disc it is white.
    var markColor: Color {
        switch self {
        case .watching, .waiting: Palette.waitingInk
        default: Color.secondary
        }
    }

    /// A word or two, for the menu bar menu and under the status icon.
    var short: String {
        switch self {
        case .needsAccessibility: "Needs access"
        case .paused: "Paused"
        case .idle: "No browser"
        case .watching: "Ready"
        case .waiting: "Waiting"
        case .awaitingApproval: "Approve…"
        case .openingPopup: "Opening…"
        case .typing: "Filling…"
        case .paired: "Paired"
        case .attention: "Needs attention"
        }
    }
}

// MARK: Layout components

/// A very faint cool wash so glass has a little to refract, without color.
struct PaneBackground: View {
    var body: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
            if #available(macOS 15.0, *) {
                MeshGradient(width: 3, height: 3,
                             points: [[0, 0], [0.5, 0], [1, 0], [0, 0.5], [0.6, 0.4], [1, 0.5], [0, 1], [0.5, 1], [1, 1]],
                             colors: [Palette.wash.opacity(0.22), Palette.wash.opacity(0.10), Color.clear,
                                      Color.clear, Palette.wash.opacity(0.12), Color.clear,
                                      Palette.wash.opacity(0.08), Color.clear, Palette.wash.opacity(0.16)])
            } else {
                LinearGradient(colors: [Palette.wash.opacity(0.20), Color.clear], startPoint: .topLeading, endPoint: .bottomTrailing)
            }
        }
        .ignoresSafeArea()
    }
}

/// Scrolling detail pane with an optional title.
struct PaneScroll<Content: View>: View {
    let pane: SettingsPane
    var showsTitle = true
    /// Shows the lock state in the top right corner, next to the title. For panes with settings that can be locked.
    var showsLock = false
    @ViewBuilder var content: () -> Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if showsTitle {
                    HStack(alignment: .center) {
                        Text(pane.title).font(.title.bold())
                        Spacer(minLength: 12)
                        if showsLock { LockIndicator() }
                    }
                    .padding(.horizontal, 4)
                }
                content()
            }
            .padding(.horizontal, 28)
            .padding(.top, 38)
            .padding(.bottom, 20)
            .frame(maxWidth: 680, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .scrollIndicators(.hidden)
        // The title sits level with the window's traffic lights, like System Settings, instead of under the title bar.
        .ignoresSafeArea(.container, edges: .top)
    }
}

/// A titled panel; rows inside are separated with `CardDivider`. The footer is a short note on what the settings do.
struct Card<Content: View>: View {
    var title: String?
    var footer: String?
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title {
                Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(.secondary).padding(.horizontal, 8)
            }
            VStack(alignment: .leading, spacing: 0) { content() }
                .padding(.horizontal, 18)
                .padding(.vertical, 4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .cardSurface()
            if let footer { Note(footer).padding(.horizontal, 8) }
        }
    }
}

struct CardDivider: View {
    var body: some View { Divider().opacity(0.5) }
}

/// A setting: a title, an optional one-line explanation, and its control.
struct SettingRow<Control: View>: View {
    let title: String
    var subtitle: String?
    @ViewBuilder var control: () -> Control

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                if let subtitle {
                    Text(subtitle).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 12)
            control()
        }
        .padding(.vertical, 11)
    }
}

struct ToggleRow: View {
    let title: String
    var subtitle: String?
    @Binding var isOn: Bool

    var body: some View {
        SettingRow(title: title, subtitle: subtitle) {
            Toggle(title, isOn: $isOn).labelsHidden().toggleStyle(.switch)
        }
    }
}

/// Footnote: leading-aligned caption text.
struct Note: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

func appIcon(forBundleID id: String) -> NSImage {
    if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) { return NSWorkspace.shared.icon(forFile: url.path) }
    return NSImage(systemSymbolName: "globe", accessibilityDescription: nil) ?? NSImage()
}
