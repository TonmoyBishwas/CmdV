import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // LSUIElement in Info.plist already keeps us out of the Dock;
        // set the policy explicitly so behavior is identical when run from DerivedData.
        NSApp.setActivationPolicy(.accessory)
    }
}
