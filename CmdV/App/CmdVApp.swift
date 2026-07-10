import SwiftUI

@main
struct CmdVApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var appState: AppState

    init() {
        let state = AppState()
        _appState = State(initialValue: state)
        state.start()
    }

    var body: some Scene {
        // The real status item is AppKit-managed (StatusItemController) so a
        // click, press-and-hold, and right-click can be told apart — which
        // MenuBarExtra cannot do. SwiftUI requires at least one scene, so keep
        // a never-inserted placeholder. Settings open through
        // SettingsWindowController for the same reason (no SettingsLink host).
        MenuBarExtra("CmdV", systemImage: "clipboard", isInserted: .constant(false)) {
            EmptyView()
        }
    }
}
