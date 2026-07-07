import SwiftUI

@main
struct CmdVApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("CmdV", systemImage: "clipboard") {
            Button("About CmdV") {
                NSApp.orderFrontStandardAboutPanel(nil)
            }
            Divider()
            Button("Quit CmdV") {
                NSApp.terminate(nil)
            }
            .keyboardShortcut("q")
        }
    }
}
