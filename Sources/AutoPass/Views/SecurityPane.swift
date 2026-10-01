import SwiftUI
import AutoPassCore

struct SecurityPane: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        PaneScroll(pane: .security, showsLock: true) {
            Card(title: "Authentication", footer: "Before typing asks before AutoPass fills in a code, and one approval covers a short while. Edit browsers and security settings asks before this window lets you change them. Touch ID uses your fingerprint only. Password asks for your account password and also accepts Touch ID.") {
                SettingRow(title: "Before typing") {
                    AuthenticationPicker(title: "Before typing", selection: $model.policy.approval)
                }
                if model.policy.approval != .none {
                    CardDivider()
                    SettingRow(title: "Remember for", subtitle: "How long one approval lasts") {
                        HStack(spacing: 8) {
                            Text(graceText).monospacedDigit().foregroundStyle(.secondary)
                            Stepper("Remember for", value: $model.policy.approvalGraceSeconds, in: 0...900, step: 30).labelsHidden()
                        }
                    }
                }
                CardDivider()
                SettingRow(title: "Edit browsers and security settings") {
                    AuthenticationPicker(title: "Edit browsers and security settings", selection: $model.policy.settingsAuth)
                }
            }
            .lockGated()

            Card(title: "Pairing", footer: "AutoPass always fills in the code when Apple's window appears. This also lets it open iCloud Passwords for you once a browser is ready and you've paused.") {
                ToggleRow(title: "Start when I start browsing",
                          isOn: Binding(get: { model.policy.autoPair == .whenBrowsing },
                                        set: { model.policy.autoPair = $0 ? .whenBrowsing : .off }))
            }
            .lockGated()

            Card(title: "Safeguards", footer: "AutoPass always checks for Apple's signed helper, Apple's popup with six empty boxes, and a trusted browser that's in front.") {
                ToggleRow(title: "Block debugging flags", subtitle: "Skip browsers started with automation or remote debugging", isOn: $model.policy.refuseDebugFlags)
                CardDivider()
                SettingRow(title: "Typing pause", subtitle: "Wait this long after your last keystroke") {
                    HStack(spacing: 8) {
                        Text(String(format: "%.2g s", model.policy.minimumIdleSeconds)).monospacedDigit().foregroundStyle(.secondary)
                        Stepper("Typing pause", value: $model.policy.minimumIdleSeconds, in: 0.25...10, step: 0.25).labelsHidden()
                    }
                }
                CardDivider()
                SettingRow(title: "Attempt limit", subtitle: "Stops retries from locking out Apple's helper") {
                    HStack(spacing: 8) {
                        Text("\(model.policy.maxAttempts) per \(model.policy.attemptWindowMinutes) min").monospacedDigit().foregroundStyle(.secondary)
                        Stepper("Attempt limit", value: $model.policy.maxAttempts, in: 1...10).labelsHidden()
                    }
                }
            }
            .lockGated()

            if let error = model.policyStoreError {
                Label(error, systemImage: "exclamationmark.triangle.fill").foregroundStyle(Palette.warn).font(.callout)
                    .padding(14).cardSurface(cornerRadius: 18)
            }
        }
    }

    private var graceText: String {
        let s = model.policy.approvalGraceSeconds
        return s == 0 ? "Every time" : s % 60 == 0 ? "\(s / 60) min" : "\(s) s"
    }
}

/// Off, Touch ID or Password. Touch ID is fingerprint only; Password is the system prompt, which asks for the account
/// password and also takes Touch ID.
private struct AuthenticationPicker: View {
    let title: String
    @Binding var selection: ApprovalMode

    var body: some View {
        Picker(title, selection: $selection) {
            Text("Off").tag(ApprovalMode.none)
            Text("Touch ID").tag(ApprovalMode.biometricsOnly)
            Text("Password").tag(ApprovalMode.deviceOwner)
        }
        .labelsHidden()
        .frame(width: 140)
    }
}
