import SwiftUI
import AutoPassCore

/// System Settings–style window: a sidebar and a detail pane of glass cards on a faint wash.
struct SettingsView: View {
    @EnvironmentObject var model: AppModel
    @EnvironmentObject var nav: SettingsNav

    var body: some View {
        NavigationSplitView(columnVisibility: .constant(.all)) {
            Sidebar()
                .navigationSplitViewColumnWidth(190)
        } detail: {
            ZStack {
                PaneBackground()
                detail
            }
        }
        .toolbar(removing: .sidebarToggle)
        // The layout is designed for at least this size; below it the rows start to wrap badly.
        .frame(minWidth: 800, minHeight: 560)
        .onAppear { model.setHealthDemand(true) }
        .onDisappear { model.setHealthDemand(false); model.lock() }
    }

    @ViewBuilder private var detail: some View {
        switch nav.pane {
        case .browsers: BrowsersPane()
        case .security: SecurityPane()
        case .general: GeneralPane()
        }
    }
}

private struct Sidebar: View {
    @EnvironmentObject var nav: SettingsNav
    @EnvironmentObject var model: AppModel

    var body: some View {
        // SwiftUI writes selection bindings on updates too; only assign real changes or the write loops.
        List(selection: Binding<SettingsPane?>(get: { nav.pane }, set: { if let v = $0, v != nav.pane { nav.pane = v } })) {
            ForEach(SettingsPane.allCases) { pane in
                Label {
                    Text(pane.title)
                } icon: {
                    if pane == .browsers {
                        // Our own mark: solid when paired, with faint dots while something is pending.
                        AppMark(filled: model.status.isPaired ? 6 : 0, dim: 0.45)
                            .frame(width: 15, height: 15)
                    } else {
                        Image(systemName: pane.symbol)
                    }
                }
                .padding(.vertical, 2)
                .tag(pane)
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .bottom) { QuickActions().padding(.horizontal, 12).padding(.vertical, 12) }
    }
}

/// Pair now or pause, for every browser at once: two tall buttons side by side.
private struct QuickActions: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        HStack(spacing: 8) {
            Button { model.pairNow() } label: {
                tile("Pair Now", symbol: "key.fill")
            }
            .buttonStyle(TileButtonStyle())
            .disabled(model.status == .needsAccessibility)
            .help("Pair with your browsers now")

            Button { model.setPaused(!model.isPaused) } label: {
                tile(model.isPaused ? "Resume" : "Pause", symbol: model.isPaused ? "play.fill" : "pause.fill")
            }
            .buttonStyle(TileButtonStyle())
            .help(model.isPaused ? "Let AutoPass pair again" : "Stop AutoPass from touching your browsers until you resume")
        }
    }

    private func tile(_ title: String, symbol: String) -> some View {
        VStack(spacing: 5) {
            Image(systemName: symbol).font(.system(size: 17, weight: .medium)).contentTransition(.symbolEffect(.replace))
            Text(title).font(.caption)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
    }
}

/// A tall rounded button: glass on macOS 26+, a plain pale panel without it, the same size either way.
private struct TileButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View { Tile(configuration: configuration) }

    private struct Tile: View {
        let configuration: ButtonStyleConfiguration
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            configuration.label
                .foregroundStyle(Color.primary)
                .frame(maxWidth: .infinity, minHeight: 54)
                .cardSurface(cornerRadius: 20)
                .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .opacity(isEnabled ? (configuration.isPressed ? 0.7 : 1) : 0.4)
        }
    }
}
