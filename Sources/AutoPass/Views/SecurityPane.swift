import SwiftUI
import AutoPassCore

struct SecurityPane: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        PaneScroll(pane: .security, showsLock: true) {
            Card(title: tr("Authentication"), footer: authenticationFooter) {
                SettingRow(title: tr("Before typing")) {
                    AuthenticationPicker(title: tr("Before typing"), selection: $model.policy.approval)
                }
                if model.policy.approval != .none {
                    CardDivider()
                    SettingRow(title: tr("Remember for"), subtitle: tr("How long one approval lasts")) {
                        HStack(spacing: 8) {
                            Text(graceText).monospacedDigit().foregroundStyle(.secondary)
                            Stepper(tr("Remember for"), value: $model.policy.approvalGraceSeconds, in: 0...900, step: 30).labelsHidden()
                        }
                    }
                }
                CardDivider()
                SettingRow(title: tr("Edit browsers and security settings")) {
                    AuthenticationPicker(title: tr("Edit browsers and security settings"), selection: $model.policy.settingsAuth)
                }
            }
            .lockGated()

            Card(title: tr("Pairing"), footer: tr("AutoPass always fills in the code when Apple's window appears. This also lets it open iCloud Passwords for you once a browser is ready and you've paused.")) {
                ToggleRow(title: tr("Start when I start browsing"),
                          isOn: Binding(get: { model.policy.autoPair == .whenBrowsing },
                                        set: { model.policy.autoPair = $0 ? .whenBrowsing : .off }))
            }
            .lockGated()

            Card(title: tr("Safeguards"), footer: tr("AutoPass always checks for Apple's signed helper, Apple's popup with six empty boxes, and a trusted browser that's in front.")) {
                ToggleRow(title: tr("Block debugging flags"), subtitle: tr("Skip browsers started with automation or remote debugging"), isOn: $model.policy.refuseDebugFlags)
                CardDivider()
                SettingRow(title: tr("Typing pause"), subtitle: tr("Wait this long after your last keystroke")) {
                    HStack(spacing: 8) {
                        Text(tr("%@ s", String(format: "%.2g", model.policy.minimumIdleSeconds))).monospacedDigit().foregroundStyle(.secondary)
                        Stepper(tr("Typing pause"), value: $model.policy.minimumIdleSeconds, in: 0.25...10, step: 0.25).labelsHidden()
                    }
                }
                CardDivider()
                SettingRow(title: tr("Attempt limit"), subtitle: tr("Stops retries from locking out Apple's helper")) {
                    HStack(spacing: 8) {
                        Text(tr("%@ per %@ min", "\(model.policy.maxAttempts)", "\(model.policy.attemptWindowMinutes)")).monospacedDigit().foregroundStyle(.secondary)
                        Stepper(tr("Attempt limit"), value: $model.policy.maxAttempts, in: 1...10).labelsHidden()
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

    private var authenticationFooter: String {
        let base = tr("Before typing asks before AutoPass fills in a code, and one approval covers a short while. Edit browsers and security settings asks before this window lets you change them. Touch ID uses your fingerprint only. Password asks for your account password and also accepts Touch ID.")
        return model.permissions.auth.touchID ? base : base + " " + tr("Touch ID isn't available on this Mac, so AutoPass asks for your password instead.")
    }

    private var graceText: String {
        let s = model.policy.approvalGraceSeconds
        return s == 0 ? tr("Every time") : s % 60 == 0 ? tr("%@ min", "\(s / 60)") : tr("%@ s", "\(s)")
    }
}

/// Off, Touch ID or Password. Touch ID is fingerprint only; Password is the system prompt, which asks for the account
/// password and also takes Touch ID.
private struct AuthenticationPicker: View {
    let title: String
    @Binding var selection: ApprovalMode

    var body: some View {
        Picker(title, selection: $selection) {
            Text(tr("Off")).tag(ApprovalMode.none)
            Text(tr("Touch ID")).tag(ApprovalMode.biometricsOnly)
            Text(tr("Password")).tag(ApprovalMode.deviceOwner)
        }
        .labelsHidden()
        .frame(width: 140)
    }
}
