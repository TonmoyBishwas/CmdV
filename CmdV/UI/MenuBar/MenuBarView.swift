import SwiftUI

struct MenuBarView: View {
    @Bindable var appState: AppState

    var body: some View {
        Button("Open CmdV") {
            appState.toggleShelf()
        }
        Divider()
        if appState.isPaused {
            Button("Resume Capturing") {
                appState.togglePause()
            }
            .keyboardShortcut("t")
        } else {
            Button("Pause Capturing") {
                appState.togglePause()
            }
            .keyboardShortcut("t")
            Menu("Pause For") {
                Button("5 Minutes") { appState.pause(for: 5 * 60) }
                Button("30 Minutes") { appState.pause(for: 30 * 60) }
                Button("1 Hour") { appState.pause(for: 60 * 60) }
            }
        }
        Divider()
        Button("Clear History…") {
            confirmClearHistory()
        }
        Divider()
        Button("About CmdV") {
            NSApp.orderFrontStandardAboutPanel(nil)
        }
        Button("Quit CmdV") {
            NSApp.terminate(nil)
        }
        .keyboardShortcut("q")
    }

    private func confirmClearHistory() {
        let alert = NSAlert()
        alert.messageText = "Clear clipboard history?"
        alert.informativeText = "All unpinned items will be deleted. Pinboards are kept."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Clear History")
        alert.addButton(withTitle: "Cancel")
        NSApp.activate()
        if alert.runModal() == .alertFirstButtonReturn {
            appState.clearHistory()
        }
    }
}
