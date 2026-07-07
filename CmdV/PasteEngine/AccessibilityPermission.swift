import ApplicationServices
import AppKit

/// Accessibility (TCC) permission flow for synthetic keystrokes.
@MainActor
enum AccessibilityPermission {
    /// Note: AXIsProcessTrusted() can cache a stale answer after the app is
    /// re-signed while running; that only heals on relaunch, so we keep the
    /// check simple rather than probing with event taps (which would drag in
    /// the separate Input Monitoring permission).
    static var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    /// Shows the system prompt that lists CmdV in
    /// System Settings → Privacy & Security → Accessibility.
    static func promptIfNeeded() {
        guard !isTrusted else { return }
        // kAXTrustedCheckOptionPrompt is a mutable C global that Swift 6
        // strict concurrency rejects; its value is this stable literal.
        AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
    }

    static func openSystemSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }
}
