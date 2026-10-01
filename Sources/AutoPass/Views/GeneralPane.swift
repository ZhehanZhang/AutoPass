import SwiftUI

struct GeneralPane: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        PaneScroll(pane: .general) {
            Card {
                ToggleRow(title: "Open at login", subtitle: "Start AutoPass when you sign in",
                          isOn: Binding(get: { model.launchAtLogin }, set: { model.setLaunchAtLogin($0) }))
                CardDivider()
                ToggleRow(title: "Menu bar icon", subtitle: "If you hide it, open AutoPass again from Applications to come back here", isOn: $model.showMenuBarIcon)
                CardDivider()
                ToggleRow(title: "Notifications", subtitle: "Tell me when AutoPass needs me", isOn: $model.notificationsEnabled)
            }

            if let error = model.launchAtLoginError {
                Text(error).font(.caption).foregroundStyle(Palette.warn).padding(.horizontal, 8)
            }

            Card(title: "Permissions", footer: "AutoPass needs Accessibility to read Apple's code window and type it into your browser. Notifications are only used to tell you when AutoPass needs you.") {
                SettingRow(title: "Accessibility", subtitle: "Lets AutoPass see Apple's code window and type into your browser") {
                    if model.permissions.accessibility {
                        PermissionValue(allowed: true, text: "Allowed")
                    } else {
                        PermissionValue(allowed: false, text: "Not allowed", action: ("Allow…", {
                            model.requestAccessibility(); model.openAccessibilitySettings()
                        }))
                    }
                }
                CardDivider()
                SettingRow(title: "Notifications", subtitle: "System permission to show them") { notificationValue }
                if model.permissions.loginItem == .needsApproval {
                    CardDivider()
                    SettingRow(title: "Login Items", subtitle: "macOS needs your approval to open AutoPass at login") {
                        PermissionValue(allowed: false, text: "Needs approval", action: ("Open Settings", { model.openLoginItemsSettings() }))
                    }
                }
            }

            Card(title: "About", footer: "AutoPass is free software under the GNU Affero General Public License 3.0. If you change it and let other people use it over a network, share your changes under the same license.") {
                SettingRow(title: "Version") {
                    Text(version).foregroundStyle(.secondary)
                }
                CardDivider()
                SettingRow(title: "Source code") {
                    Link("github.com/ZhehanZhang/AutoPass", destination: URL(string: "https://github.com/ZhehanZhang/AutoPass")!)
                }
                CardDivider()
                SettingRow(title: "License") {
                    Link("GNU AGPL 3.0", destination: URL(string: "https://www.gnu.org/licenses/agpl-3.0.html")!)
                }
                CardDivider()
                SettingRow(title: "Website") {
                    Link("zhehanz.com", destination: URL(string: "https://zhehanz.com")!)
                }
            }
        }
    }

    @ViewBuilder private var notificationValue: some View {
        switch model.permissions.notifications {
        case .allowed: PermissionValue(allowed: true, text: "Allowed")
        case .notAsked: PermissionValue(allowed: false, text: "Not asked yet", action: ("Allow…", { model.askForNotifications(openSettingsIfDenied: true) }))
        case .denied: PermissionValue(allowed: false, text: "Off in System Settings", action: ("Open Settings", { model.openNotificationSettings() }))
        case .unknown: PermissionValue(allowed: false, text: "Not available")
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
