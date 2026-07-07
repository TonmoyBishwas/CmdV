import AppKit
import KeyboardShortcuts
import Observation
import SwiftUI
import os.log

/// The Paste Stack mode: while active, every copy appends to a queue and
/// each ⌘V pastes-and-consumes the next entry. ⌘V is claimed via a
/// temporary global hotkey (no Input Monitoring permission needed) and
/// released when the stack ends.
@MainActor
@Observable
final class PasteStackController {
    private static let log = Logger(subsystem: "com.tonmoybishwas.CmdV", category: "stack")

    private(set) var isActive = false
    private(set) var queue = PasteStackQueue()

    private let monitor: ClipboardMonitor
    private var overlay: NSPanel?

    init(monitor: ClipboardMonitor) {
        self.monitor = monitor
        // If a crash ever left the temporary ⌘V binding persisted, clear it
        // before it can shadow the system's paste.
        KeyboardShortcuts.setShortcut(nil, for: .stackPaste)
        KeyboardShortcuts.onKeyDown(for: .stackPaste) { [weak self] in
            self?.pasteNext()
        }
    }

    func toggle() {
        isActive ? deactivate() : activate()
    }

    func activate() {
        guard !isActive else { return }
        isActive = true
        queue.clear()
        KeyboardShortcuts.setShortcut(.init(.v, modifiers: [.command]), for: .stackPaste)
        showOverlay()
        Self.log.info("Paste Stack activated")
    }

    func deactivate() {
        guard isActive else { return }
        isActive = false
        KeyboardShortcuts.setShortcut(nil, for: .stackPaste)
        hideOverlay()
        queue.clear()
        Self.log.info("Paste Stack deactivated")
    }

    /// Called by the clipboard monitor for every recorded capture.
    func noteCapture(_ capture: ClipboardCapture) {
        guard isActive else { return }
        withAnimation(.spring(duration: 0.3)) {
            queue.append(capture)
        }
        Self.log.info("Stack: appended entry, queue now \(self.queue.count, privacy: .public)")
    }

    func remove(id: UUID) {
        withAnimation(.spring(duration: 0.3)) {
            queue.remove(id: id)
        }
    }

    func toggleReversed() {
        withAnimation(.spring(duration: 0.3)) {
            queue.toggleReversed()
        }
    }

    /// The claimed ⌘V: paste the next entry into the frontmost app.
    func pasteNext() {
        guard isActive else { return }
        var popped: PasteStackQueue.Entry?
        withAnimation(.spring(duration: 0.3)) {
            popped = queue.next()
        }
        guard let entry = popped else {
            deactivate()
            return
        }
        PasteEngine.copyCapture(entry.capture, monitor: monitor)

        // The synthetic ⌘V we post would re-trigger our own hotkey — release
        // it around the keystroke.
        KeyboardShortcuts.setShortcut(nil, for: .stackPaste)
        let pasted = KeySimulator.pasteIfTrusted()
        if !pasted {
            Self.log.info("Stack paste fell back to copy-only (no Accessibility)")
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self, self.isActive else { return }
            if self.queue.isEmpty {
                self.deactivate()
            } else {
                KeyboardShortcuts.setShortcut(.init(.v, modifiers: [.command]), for: .stackPaste)
            }
        }
    }

    // MARK: - Overlay panel

    private func showOverlay() {
        let panel: NSPanel
        if let overlay {
            panel = overlay
        } else {
            panel = NSPanel(
                contentRect: .zero,
                styleMask: [.nonactivatingPanel, .borderless],
                backing: .buffered,
                defer: true
            )
            panel.isFloatingPanel = true
            panel.level = .floating
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.hasShadow = true
            panel.isMovableByWindowBackground = true
            panel.isReleasedWhenClosed = false
            panel.contentView = NSHostingView(rootView: PasteStackOverlayView(controller: self))
            overlay = panel
        }
        guard let screen = NSScreen.main else { return }
        let size = NSSize(width: 280, height: 340)
        panel.setFrame(
            NSRect(
                x: screen.visibleFrame.maxX - size.width - 24,
                y: screen.visibleFrame.maxY - size.height - 24,
                width: size.width,
                height: size.height
            ),
            display: false
        )
        panel.orderFrontRegardless()
    }

    private func hideOverlay() {
        overlay?.orderOut(nil)
    }
}
