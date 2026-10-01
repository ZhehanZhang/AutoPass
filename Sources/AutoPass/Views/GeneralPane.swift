import SwiftUI

struct GeneralPane: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        PaneScroll(pane: .general) {
            Card {
                SettingRow(title: tr("Language"), subtitle: tr("Choose the language AutoPass uses. System follows your Mac.")) {
                    Picker(tr("Language"), selection: $model.language) {
                        Text(tr("System")).tag(L10n.system)
                        Divider()
                        ForEach(L10n.languages) { Text($0.name).tag($0.code) }
                    }
                    .labelsHidden()
                    .frame(width: 190)
                }
                CardDivider()
                ToggleRow(title: tr("Open at login"), subtitle: tr("Start AutoPass when you sign in"),
                          isOn: Binding(get: { model.launchAtLogin }, set: { model.setLaunchAtLogin($0) }))
                CardDivider()
                ToggleRow(title: tr("Menu bar icon"), subtitle: tr("If you hide it, open AutoPass again from Applications to come back here"), isOn: $model.showMenuBarIcon)
                CardDivider()
                ToggleRow(title: tr("Notifications"), subtitle: tr("Tell me when AutoPass needs me"), isOn: $model.notificationsEnabled)
            }

            if let error = model.launchAtLoginError {
                Text(error).font(.caption).foregroundStyle(Palette.warn).padding(.horizontal, 8)
            }

            Card(title: tr("Permissions"), footer: tr("AutoPass needs Accessibility to read Apple's code window and type it into your browser. Notifications are only used to tell you when AutoPass needs you.")) {
                SettingRow(title: tr("Accessibility"), subtitle: tr("Lets AutoPass see Apple's code window and type into your browser")) {
                    if model.permissions.accessibility {
                        PermissionValue(allowed: true, text: tr("Allowed"))
                    } else {
                        PermissionValue(allowed: false, text: tr("Not allowed"), action: (tr("Allow…"), {
                            model.requestAccessibility(); model.openAccessibilitySettings()
                        }))
                    }
                }
                CardDivider()
                SettingRow(title: tr("Notifications"), subtitle: tr("System permission to show them")) { notificationValue }
                if model.permissions.loginItem == .needsApproval {
                    CardDivider()
                    SettingRow(title: tr("Login Items"), subtitle: tr("macOS needs your approval to open AutoPass at login")) {
                        PermissionValue(allowed: false, text: tr("Needs approval"), action: (tr("Open Settings"), { model.openLoginItemsSettings() }))
                    }
                }
            }

            Card(title: tr("About"), footer: tr("AutoPass is free software under the GNU Affero General Public License 3.0. If you change it and let other people use it over a network, share your changes under the same license.")) {
                SettingRow(title: tr("Version")) {
                    Text(version).foregroundStyle(.secondary)
                }
                CardDivider()
                SettingRow(title: tr("Source code")) {
                    Link("github.com/ZhehanZhang/AutoPass", destination: URL(string: "https://github.com/ZhehanZhang/AutoPass")!)
                }
                CardDivider()
                SettingRow(title: tr("License")) {
                    Link("GNU AGPL 3.0", destination: URL(string: "https://www.gnu.org/licenses/agpl-3.0.html")!)
                }
                CardDivider()
                SettingRow(title: tr("Website")) {
                    Link("zhehanz.com", destination: URL(string: "https://zhehanz.com")!)
                }
            }
        }
    }

    @ViewBuilder private var notificationValue: some View {
        switch model.permissions.notifications {
        case .allowed: PermissionValue(allowed: true, text: tr("Allowed"))
        case .notAsked: PermissionValue(allowed: false, text: tr("Not asked yet"), action: (tr("Allow…"), { model.askForNotifications(openSettingsIfDenied: true) }))
        case .denied: PermissionValue(allowed: false, text: tr("Off in System Settings"), action: (tr("Open Settings"), { model.openNotificationSettings() }))
        case .unknown: PermissionValue(allowed: false, text: tr("Not available"))
        }
    }

    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
    }
}

/// A permission's state, with a button to fix it when it isn't allowed.
private struct PermissionValue: View {
    let allowed: Bool
    let text: String
    var action: (title: String, run: () -> Void)?

    var body: some View {
        HStack(spacing: 10) {
            Label(text, systemImage: allowed ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .foregroundStyle(.secondary)
                .labelStyle(StatusLabelStyle(tint: allowed ? Palette.ok : Palette.warn))
            if let action {
                Button(action.title, action: action.run).glassButton(prominent: !allowed)
            }
        }
    }
}

private struct StatusLabelStyle: LabelStyle {
    let tint: Color

    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 6) {
            configuration.icon.foregroundStyle(tint)
            configuration.title
        }
    }
}
