import SwiftUI
import AppKit
import AutoPassCore

@MainActor
private final class BrowsersUI: ObservableObject {
    @Published var pending: PendingBrowser?
    @Published var inspecting = false
    @Published var errorMessage: String?
    @Published var suggestions: [(name: String, url: URL)] = []
}

private struct PendingBrowser: Identifiable {
    let id = UUID()
    let identity: CodeSigning.AppIdentity
    let supported: Bool?
}

/// Status and controls in one place: the status icon on the left, one row per trusted browser on the right.
struct BrowsersPane: View {
    @EnvironmentObject var model: AppModel
    @StateObject private var ui = BrowsersUI()

    var body: some View {
        PaneScroll(pane: .browsers, showsLock: true) {
            mainCard
            activity
        }
        .onAppear { ui.suggestions = model.suggestedBrowsers() }
        .onChange(of: model.policy.trustedBrowsers) { _, _ in ui.suggestions = model.suggestedBrowsers() }
        .onChange(of: model.supportedBrowsers.count) { _, _ in ui.suggestions = model.suggestedBrowsers() }
        .alert("Can't add this browser", isPresented: Binding(get: { ui.errorMessage != nil }, set: { if !$0 { ui.errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(ui.errorMessage ?? "") }
        .sheet(item: $ui.pending) { p in
            ConfirmBrowserSheet(pending: p) { model.add(p.identity); ui.pending = nil } cancel: { ui.pending = nil }
        }
    }

    // MARK: Status + browsers

    private var mainCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            mainContent
            Note("Use the key to pair now. Pause stops AutoPass from touching that browser until you resume.")
                .padding(.horizontal, 8)
        }
    }

    private var mainContent: some View {
        HStack(alignment: .top, spacing: 24) {
            statusColumn
            VStack(spacing: 0) {
                if model.policy.trustedBrowsers.isEmpty {
                    Text("No browsers").foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 18)
                }
                ForEach($model.policy.trustedBrowsers) { $browser in
                    if browser.id != model.policy.trustedBrowsers.first?.id { CardDivider() }
                    row(for: $browser)
                }
                CardDivider()
                addMenu.frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 9)
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface(cornerRadius: 30)
    }

    private var statusColumn: some View {
        VStack(spacing: 10) {
            StatusIcon(status: model.status, size: 92)
                .frame(width: 104, height: 104)
            Text(model.status.short).font(.callout).foregroundStyle(.secondary)
            if model.status == .needsAccessibility {
                Button("Allow") { model.requestAccessibility(); model.openAccessibilitySettings() }.glassButton(prominent: true)
            }
        }
        .frame(width: 112)
        .padding(.top, 4)
        .help(model.status.summary)
    }

    private func row(for browser: Binding<TrustedBrowser>) -> some View {
        let b = browser.wrappedValue
        let health = model.health.browsers.first { $0.signingID == b.signingID }
        let paused = model.pausedBrowsers.contains(b.signingID)
        let missing = health?.extensionMissing == true
        return HStack(spacing: 12) {
            ZStack(alignment: .bottomTrailing) {
                Image(nsImage: appIcon(forBundleID: b.bundleID)).resizable().frame(width: 32, height: 32).opacity(b.isEnabled ? 1 : 0.45)
                if let badge = badge(b, health, paused) { StatusBadge(symbol: badge.symbol, tint: badge.tint).offset(x: 5, y: 5) }
            }
            .padding(.trailing, 4)
            VStack(alignment: .leading, spacing: 2) {
                Text(b.name)
                Text(state(b, health, paused)).font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            if missing {
                Menu {
                    Button("Install iCloud Passwords") { model.installExtension(bundleID: b.bundleID, signingID: b.signingID) }
                    Button("Turn On iCloud Passwords") { model.turnOnExtension(bundleID: b.bundleID, signingID: b.signingID) }
                } label: {
                    Image(systemName: "arrow.down.circle").frame(width: 16, height: 16)
                }
                .menuStyle(.button)
                .glassIconButton()
                .menuIndicator(.hidden)
                .fixedSize()
                .help("Install or turn on iCloud Passwords")
            } else {
                Button { if let pid = health?.pid { model.pairNow(browserPID: pid) } } label: {
                    Image(systemName: "key.fill").frame(width: 16, height: 16)
                        .symbolEffect(.bounce, value: health?.paired)
                }
                .glassIconButton()
                .disabled(health == nil || !b.isEnabled)
                .help("Pair now")
            }
            Button { model.setBrowserPaused(b, !paused) } label: {
                Image(systemName: paused ? "play.fill" : "pause.fill").frame(width: 16, height: 16)
                    .contentTransition(.symbolEffect(.replace))
            }
            .glassIconButton()
            .disabled(!b.isEnabled)
            .help(paused ? "Resume" : "Pause")
            Menu {
                Button(b.isEnabled ? "Turn Off" : "Turn On") { browser.wrappedValue.isEnabled.toggle() }
                Button("Remove", role: .destructive) { model.remove(b) }
            } label: {
                Image(systemName: "ellipsis").frame(width: 16, height: 16)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .lockGated(dims: false)
            .help("More")
        }
        .padding(.vertical, 6)
    }

    /// The little status disc on a browser's icon. Nothing when it's off or not running.
    private func badge(_ b: TrustedBrowser, _ health: BrowserHealth?, _ paused: Bool) -> (symbol: String, tint: Color)? {
        if !b.isEnabled { return nil }
        if paused { return ("pause.circle.fill", Color.secondary) }
        guard let health else { return nil }
        if health.extensionMissing { return ("exclamationmark.circle.fill", Palette.warn) }
        return health.paired == true ? ("checkmark.circle.fill", Palette.ok) : ("ellipsis.circle.fill", Palette.waiting)
    }

    private func state(_ b: TrustedBrowser, _ health: BrowserHealth?, _ paused: Bool) -> String {
        if !b.isEnabled { return "Off" }
        if paused { return "Paused" }
        guard let health else { return "Not running" }
        if health.extensionMissing { return "iCloud Passwords not found" }
        return health.paired == true ? "Paired" : "Not paired"
    }

    private var addMenu: some View {
        HStack(spacing: 10) {
            Menu {
                ForEach(ui.suggestions, id: \.url) { s in Button(s.name) { inspect(s.url) } }
                if !ui.suggestions.isEmpty { Divider() }
                Button("Choose…") { choose() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                    Text("Add Browser")
                    Image(systemName: "chevron.down").font(.system(size: 9, weight: .semibold))
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Add Browser")
            }
            .menuStyle(.button)
            .menuIndicator(.hidden)
            .glassButton()
            .fixedSize()
            .lockGated(dims: false)
            if ui.inspecting { ProgressView().controlSize(.small) }
        }
    }

    // MARK: Activity

    private var activity: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Activity").font(.subheadline.weight(.semibold)).foregroundStyle(.secondary).padding(.horizontal, 8)

            // A fixed height that shows the newest few entries, so the page never grows or scrolls.
            VStack(spacing: 0) {
                if model.log.isEmpty {
                    Text("No activity yet").foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 8)
                }
                ForEach(Array(model.log.prefix(Self.activityRows).enumerated()), id: \.element.id) { index, entry in
                    if index > 0 { CardDivider() }
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Image(systemName: entry.level == .info ? "checkmark.circle" : "exclamationmark.triangle.fill")
                            .foregroundStyle(entry.level == .info ? Color.secondary : Palette.warn)
                            .frame(width: 18)
                        Text(entry.message).font(.callout).lineLimit(1)
                        Spacer(minLength: 8)
                        Text(entry.date, style: .time).font(.caption).foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 7)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, minHeight: Self.activityHeight, maxHeight: Self.activityHeight, alignment: .topLeading)
            .cardSurface()
        }
    }

    private static let activityRows = 3
    private static let activityHeight: CGFloat = 112

    // MARK: Adding

    private func choose() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose"
        if panel.runModal() == .OK, let url = panel.url { inspect(url) }
    }

    private func inspect(_ url: URL) {
        ui.inspecting = true
        Task {
            let result = await Task.detached { Result { try CodeSigning.inspectApp(at: url) } }.value
            ui.inspecting = false
            switch result {
            case .success(let identity):
                if model.policy.trustedBrowsers.contains(where: { $0.signingID == identity.signingID }) {
                    ui.errorMessage = "\(identity.name) is already added."
                } else {
                    ui.pending = PendingBrowser(identity: identity, supported: model.isSupportedByHelper(identity))
                }
            case .failure(let error):
                ui.errorMessage = error.localizedDescription
            }
        }
    }
}

private struct ConfirmBrowserSheet: View {
    let pending: PendingBrowser
    let add: () -> Void
    let cancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 14) {
                Image(nsImage: appIcon(forBundleID: pending.identity.bundleID)).resizable().frame(width: 48, height: 48)
                Text("Trust \(pending.identity.name)?").font(.title3.weight(.semibold))
            }

            VStack(spacing: 0) {
                row("Identifier", pending.identity.signingID)
                CardDivider()
                row("Team", pending.identity.teamID)
            }
            .padding(.horizontal, 14)
            .cardSurface(cornerRadius: 16)

            switch pending.supported {
            case true?: Label("Apple's helper supports this browser", systemImage: "checkmark.circle.fill").foregroundStyle(Palette.ok)
            case false?: Label("Apple's helper doesn't list this browser", systemImage: "exclamationmark.triangle.fill").foregroundStyle(Palette.warn)
            case nil: EmptyView()
            }

            HStack {
                Spacer()
                Button("Cancel", role: .cancel, action: cancel).glassButton().keyboardShortcut(.cancelAction)
                Button(pending.supported == false ? "Add Anyway" : "Trust", action: add).glassButton(prominent: true).keyboardShortcut(.defaultAction)
            }
            .controlSize(.large)
        }
        .padding(24)
        .frame(width: 420)
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack { Text(label).foregroundStyle(.secondary); Spacer(); Text(value).textSelection(.enabled) }.padding(.vertical, 8)
    }
}
