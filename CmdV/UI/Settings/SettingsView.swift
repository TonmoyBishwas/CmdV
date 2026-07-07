import SwiftUI

struct SettingsView: View {
    let appState: AppState

    var body: some View {
        TabView {
            GeneralSettings()
                .tabItem { Label("General", systemImage: "gearshape") }
            PrivacySettings(appState: appState)
                .tabItem { Label("Privacy", systemImage: "hand.raised") }
            ShortcutsSettings()
                .tabItem { Label("Shortcuts", systemImage: "keyboard") }
        }
        .frame(width: 480)
        .fixedSize(horizontal: false, vertical: true)
    }
}
