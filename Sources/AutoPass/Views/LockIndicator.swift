import SwiftUI

/// Settings protection, shown in the top right corner of the panes that have locked settings: whether the browsers and
/// security settings are locked, with the words for it. Clicking it locks or unlocks them with Touch ID or your
/// password (or turns protection on, the first time).
struct LockIndicator: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        Button { Task { await model.toggleLock() } } label: {
            Label(title, systemImage: symbol)
                .contentTransition(.symbolEffect(.replace))
                .symbolEffect(.bounce, value: model.isLocked)
        }
        .modifier(LockPillStyle(unlocked: unlocked))
        .help(help)
    }

    /// Protection is on and the settings are open for changes.
    private var unlocked: Bool { model.policy.isSettingsProtected && !model.isLocked }
    private var symbol: String { !model.policy.isSettingsProtected ? "lock.open" : model.isLocked ? "lock.fill" : "lock.open.fill" }
    private var title: String { !model.policy.isSettingsProtected ? "Lock Settings" : model.isLocked ? "Locked" : "Unlocked" }
    private var help: String {
        !model.policy.isSettingsProtected ? "Ask for Touch ID or your password before settings change"
            : model.isLocked ? "Unlock with Touch ID or your password"
            : "Lock now. Settings lock again after five minutes"
    }
}

/// Glass while locked. Unlocked it's the system accent color itself, the same blue as the selected sidebar row (a tinted
/// glass pill comes out lighter than that).
private struct LockPillStyle: ViewModifier {
    let unlocked: Bool

    @ViewBuilder func body(content: Content) -> some View {
        if unlocked {
            content.buttonStyle(FlatButtonStyle(prominent: true))
        } else {
            content.glassButton()
        }
    }
}
