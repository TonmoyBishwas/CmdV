import AppKit
import SwiftUI

/// Hosts SettingsView in a plain window. The SwiftUI `Settings` scene can only
/// be opened from SwiftUI (`SettingsLink`); with the status item now
/// AppKit-managed there is no SwiftUI menu left, so CmdV owns its settings
/// window directly.
@MainActor
final class SettingsWindowController: NSWindowController {
    convenience init(appState: AppState) {
        let hosting = NSHostingController(rootView: SettingsView(appState: appState))
        let window = NSWindow(contentViewController: hosting)
        window.title = "CmdV Settings"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        self.init(window: window)
    }

    func show() {
        if window?.isVisible != true {
            window?.center()
        }
        // Activating here is fine — settings is a normal window, not the shelf.
        NSApp.activate()
        window?.makeKeyAndOrderFront(nil)
    }
}
