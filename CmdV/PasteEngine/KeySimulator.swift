import CoreGraphics
import os.log

/// Posts a synthetic ⌘V so the frontmost app pastes what PasteEngine just
/// put on the pasteboard. Requires Accessibility permission; callers fall
/// back to copy-only (content stays on the clipboard) when not granted.
@MainActor
enum KeySimulator {
    private static let log = Logger(subsystem: "com.tonmoybishwas.CmdV", category: "keysim")

    private static let vKeyCode: CGKeyCode = 9

    /// Returns true if the paste keystroke was posted.
    @discardableResult
    static func pasteIfTrusted() -> Bool {
        guard AccessibilityPermission.isTrusted else {
            log.info("Accessibility not granted — item left on clipboard for manual ⌘V")
            AccessibilityPermission.promptIfNeeded()
            return false
        }
        let source = CGEventSource(stateID: .combinedSessionState)
        guard let down = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: false)
        else {
            log.error("Failed to create CGEvents for paste")
            return false
        }
        down.flags = .maskCommand
        up.flags = .maskCommand
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
        return true
    }
}
