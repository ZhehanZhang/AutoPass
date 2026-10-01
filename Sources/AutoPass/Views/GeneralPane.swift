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

    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
    }
}
