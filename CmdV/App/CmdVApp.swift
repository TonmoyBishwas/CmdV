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
        MenuBarExtra("CmdV", systemImage: appState.isPaused ? "clipboard.fill" : "clipboard") {
            MenuBarView(appState: appState)
        }
    }
}
