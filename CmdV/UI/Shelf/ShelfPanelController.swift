import AppKit
import SwiftUI
import os.log

/// Owns the shelf panel: creation, slide-up/down animation, key-event
/// routing, and dismissal. Records the frontmost app before showing so
/// pastes can target it.
@MainActor
final class ShelfPanelController: NSObject, NSWindowDelegate {
    private let log = Logger(subsystem: "com.tonmoybishwas.CmdV", category: "shelf")

    private unowned let appState: AppState
    let viewModel = ShelfViewModel()
    private var panel: ShelfPanel?
    private var keyMonitor: Any?
    private var clickMonitor: Any?

    /// The app that was frontmost when the shelf opened — paste target.
    private(set) var previousApp: NSRunningApplication?

    var isVisible: Bool { panel?.isVisible ?? false }

    init(appState: AppState) {
        self.appState = appState
        super.init()
    }

    // MARK: - Show / hide

    func toggle() {
        isVisible ? hide() : show()
    }

    func show() {
        previousApp = NSWorkspace.shared.frontmostApplication
        let panel = ensurePanel()

        guard let screen = activeScreen() else { return }
        let height = max(220, CGFloat(UserDefaults.standard.double(forKey: Defaults.Keys.shelfHeight)))
        let inset: CGFloat = 12
        let frame = NSRect(
            x: screen.visibleFrame.minX + inset,
            y: screen.visibleFrame.minY + inset,
            width: screen.visibleFrame.width - inset * 2,
            height: height
        )

        viewModel.reset()
        viewModel.selectFirst()

        // Slide up from below the bottom edge.
        var start = frame
        start.origin.y -= height + inset
        panel.setFrame(start, display: false)
        panel.alphaValue = 0
        panel.makeKeyAndOrderFront(nil)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.22
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().setFrame(frame, display: true)
            panel.animator().alphaValue = 1
        }

        installMonitors()
        log.info("Shelf shown (\(Int(frame.width))×\(Int(frame.height)), \(self.viewModel.visibleUUIDs.count) items visible)")
    }

    func hide() {
        guard let panel, panel.isVisible else { return }
        log.info("Shelf hidden")
        removeMonitors()
        var end = panel.frame
        end.origin.y -= panel.frame.height + 12
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.18
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().setFrame(end, display: true)
            panel.animator().alphaValue = 0
        }, completionHandler: {
            Task { @MainActor in
                panel.orderOut(nil)
            }
        })
    }

    /// Hide, then run an action once the previous app is frontmost again.
    func hideAndFocusPreviousApp(then action: (() -> Void)? = nil) {
        let target = previousApp
        hide()
        target?.activate()
        if let action {
            // Give the target app a beat to take key focus before synthetic ⌘V.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                action()
            }
        }
    }

    // MARK: - Panel setup

    private func ensurePanel() -> ShelfPanel {
        if let panel { return panel }
        let panel = ShelfPanel()
        panel.delegate = self
        panel.minSize = NSSize(width: 400, height: 220)
        panel.maxSize = NSSize(width: 10_000, height: 700)
        let root = ShelfRootView(model: viewModel, appState: appState)
            .modelContainer(appState.container)
        panel.contentView = NSHostingView(rootView: root)
        self.panel = panel
        return panel
    }

    private func activeScreen() -> NSScreen? {
        let mouse = NSEvent.mouseLocation
        return NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
    }

    // MARK: - Event routing

    private func installMonitors() {
        removeMonitors()
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            return self.handleKey(event)
        }
        // Any click outside the panel dismisses the shelf.
        clickMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.hide()
            }
        }
    }

    private func removeMonitors() {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        if let clickMonitor { NSEvent.removeMonitor(clickMonitor) }
        keyMonitor = nil
        clickMonitor = nil
    }

    /// Returns nil to consume the event, or the event to pass it on
    /// (e.g. into the search field).
    private func handleKey(_ event: NSEvent) -> NSEvent? {
        guard isVisible else { return event }

        // While renaming/editing, only intercept Esc.
        if viewModel.renamingUUID != nil || viewModel.editingUUID != nil {
            if event.keyCode == 53 {
                viewModel.renamingUUID = nil
                viewModel.editingUUID = nil
                return nil
            }
            return event
        }

        let command = event.modifierFlags.contains(.command)
        let shift = event.modifierFlags.contains(.shift)

        // ⌘1–⌘9 quick paste.
        if command, let chars = event.charactersIgnoringModifiers,
           let digit = Int(chars), (1...9).contains(digit) {
            let index = digit - 1
            if index < viewModel.visibleUUIDs.count {
                appState.pasteItem(uuid: viewModel.visibleUUIDs[index], plainTextOnly: shift)
            }
            return nil
        }

        switch event.keyCode {
        case 53: // Esc
            if !viewModel.searchText.isEmpty {
                viewModel.searchText = ""
            } else {
                hide()
            }
            return nil
        case 123: // ←
            viewModel.selectPrevious()
            return nil
        case 124: // →
            viewModel.selectNext()
            return nil
        case 36, 76: // Return / keypad Enter
            if command || shift {
                // ⇧Return = paste as plain text
                appState.pasteSelected(plainTextOnly: true)
            } else {
                appState.pasteSelected(plainTextOnly: false)
            }
            return nil
        case 49: // Space — Quick Look
            appState.quickLookSelected()
            return nil
        case 51: // Delete
            if viewModel.searchText.isEmpty {
                appState.deleteSelected()
                return nil
            }
            return event
        default:
            break
        }

        if command, let chars = event.charactersIgnoringModifiers?.lowercased() {
            switch chars {
            case "c":
                if let uuid = viewModel.selectedUUID {
                    appState.copyItem(uuid: uuid)
                }
                return nil
            case "f":
                viewModel.searchFocusRequested = true
                return nil
            case "r":
                viewModel.renamingUUID = viewModel.selectedUUID
                return nil
            case "e":
                viewModel.editingUUID = viewModel.selectedUUID
                return nil
            case "n":
                if shift {
                    appState.createPinboardRequested()
                } else {
                    appState.createNewItemRequested()
                }
                return nil
            case "a":
                viewModel.multiSelection = Set(viewModel.visibleUUIDs)
                return nil
            default:
                break
            }
        }

        return event
    }

    // MARK: - NSWindowDelegate

    func windowDidResignKey(_ notification: Notification) {
        // Clicking another app's window takes key away — dismiss.
        hide()
    }

    func windowWillResize(_ sender: NSWindow, to frameSize: NSSize) -> NSSize {
        // Only the height is user-adjustable; width stays pinned to the screen.
        NSSize(width: sender.frame.width, height: frameSize.height)
    }

    func windowDidEndLiveResize(_ notification: Notification) {
        guard let panel else { return }
        UserDefaults.standard.set(Double(panel.frame.height), forKey: Defaults.Keys.shelfHeight)
    }
}
