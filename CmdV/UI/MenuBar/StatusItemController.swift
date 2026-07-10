import AppKit
import SwiftData

/// AppKit-managed menu bar item. A plain click pops the quick copy list
/// (pinned + recent items — click one to copy it); press-and-hold or
/// right-click opens the options menu. MenuBarExtra cannot tell these
/// gestures apart, which is why this is not SwiftUI.
@MainActor
final class StatusItemController: NSObject {
    /// How long the button must stay pressed before the options menu opens
    /// instead of the quick list.
    private static let holdThreshold: TimeInterval = 0.35

    private let statusItem: NSStatusItem
    private unowned let appState: AppState

    init(appState: AppState) {
        self.appState = appState
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()
        if let button = statusItem.button {
            button.target = self
            button.action = #selector(statusItemClicked(_:))
            button.sendAction(on: [.leftMouseDown, .rightMouseDown])
        }
        refreshIcon()
    }

    func refreshIcon() {
        statusItem.button?.image = NSImage(
            systemSymbolName: appState.isPaused ? "clipboard.fill" : "clipboard",
            accessibilityDescription: "CmdV"
        )
    }

    // MARK: - Click routing

    @objc private func statusItemClicked(_ sender: Any?) {
        appState.syncPauseState()
        if NSApp.currentEvent?.type == .rightMouseDown {
            show(menu: optionsMenu())
        } else if waitForMouseUp(within: Self.holdThreshold) {
            show(menu: quickMenu())
        } else {
            // Still pressed after the threshold: hold gesture. The menu keeps
            // tracking the held button, so drag-to-item-and-release works.
            show(menu: optionsMenu())
        }
    }

    /// Synchronously tracks the pressed button; true if released in time.
    private func waitForMouseUp(within timeout: TimeInterval) -> Bool {
        let deadline = Date(timeIntervalSinceNow: timeout)
        while let event = NSApp.nextEvent(
            matching: [.leftMouseUp, .leftMouseDragged],
            until: deadline,
            inMode: .eventTracking,
            dequeue: true
        ) {
            if event.type == .leftMouseUp { return true }
        }
        return false
    }

    private func show(menu: NSMenu) {
        menu.delegate = self
        // Attaching the menu makes performClick pop it with correct placement
        // and highlight; menuDidClose detaches it so the next physical click
        // reaches our action again instead of reopening the same menu.
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
    }

    // MARK: - Quick copy menu

    private func quickMenu() -> NSMenu {
        let menu = NSMenu()
        let pinned = fetchItems(pinned: true, limit: Defaults.menuBarPinnedCount)
        let recent = fetchItems(pinned: false, limit: Defaults.menuBarRecentCount)

        if pinned.isEmpty && recent.isEmpty {
            let empty = NSMenuItem(title: "Nothing Copied Yet", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            menu.addItem(empty)
        }
        if !pinned.isEmpty {
            menu.addItem(.sectionHeader(title: "Pinned"))
            pinned.forEach { menu.addItem(menuItem(for: $0)) }
        }
        if !recent.isEmpty {
            menu.addItem(.sectionHeader(title: "Recent"))
            recent.forEach { menu.addItem(menuItem(for: $0)) }
        }
        menu.addItem(.separator())
        menu.addItem(makeItem("Open CmdV", action: #selector(openShelf)))
        return menu
    }

    private func fetchItems(pinned: Bool, limit: Int) -> [ClipItem] {
        QuickMenuQuery.items(in: appState.container.mainContext, pinned: pinned, limit: limit)
    }

    private func menuItem(for item: ClipItem) -> NSMenuItem {
        let label = QuickMenuLabel.label(
            title: item.title,
            plainText: item.plainText,
            fileNames: item.fileURLPaths.map { ($0 as NSString).lastPathComponent },
            fallback: fallbackLabel(for: item)
        )
        let menuItem = NSMenuItem(title: label, action: #selector(copyClip(_:)), keyEquivalent: "")
        menuItem.target = self
        menuItem.representedObject = item.uuid
        if item.kind == .image, let data = item.thumbnailData, let thumb = NSImage(data: data) {
            menuItem.image = resized(thumb, maxHeight: 22, maxWidth: 44)
        } else {
            menuItem.image = NSImage(systemSymbolName: item.kind.symbolName, accessibilityDescription: nil)
        }
        return menuItem
    }

    private func fallbackLabel(for item: ClipItem) -> String {
        switch item.kind {
        case .image:
            item.pixelWidth > 0 ? "Image \(item.pixelWidth)×\(item.pixelHeight)" : "Image"
        case .file: "File"
        case .link: "Link"
        case .color: "Color"
        case .code: "Code"
        case .text: "Text"
        }
    }

    private func resized(_ image: NSImage, maxHeight: CGFloat, maxWidth: CGFloat) -> NSImage {
        let scale = min(maxHeight / max(image.size.height, 1), maxWidth / max(image.size.width, 1), 1)
        let size = NSSize(width: max(image.size.width * scale, 1), height: max(image.size.height * scale, 1))
        let out = NSImage(size: size)
        out.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: size))
        out.unlockFocus()
        return out
    }

    @objc private func copyClip(_ sender: NSMenuItem) {
        guard let uuid = sender.representedObject as? UUID else { return }
        appState.copyItem(uuid: uuid)
    }

    // MARK: - Options menu

    private func optionsMenu() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(makeItem("Open CmdV", action: #selector(openShelf)))
        menu.addItem(makeItem(
            appState.pasteStack?.isActive == true ? "Stop Paste Stack" : "Start Paste Stack",
            action: #selector(togglePasteStack)
        ))
        menu.addItem(.separator())
        if appState.isPaused {
            menu.addItem(makeItem("Resume Capturing", action: #selector(togglePause), key: "t"))
        } else {
            menu.addItem(makeItem("Pause Capturing", action: #selector(togglePause), key: "t"))
            let pauseFor = NSMenuItem(title: "Pause For", action: nil, keyEquivalent: "")
            let submenu = NSMenu()
            submenu.addItem(makeItem("5 Minutes", action: #selector(pauseFive)))
            submenu.addItem(makeItem("30 Minutes", action: #selector(pauseThirty)))
            submenu.addItem(makeItem("1 Hour", action: #selector(pauseHour)))
            pauseFor.submenu = submenu
            menu.addItem(pauseFor)
        }
        menu.addItem(.separator())
        menu.addItem(makeItem("Clear History…", action: #selector(clearHistory)))
        menu.addItem(.separator())
        menu.addItem(makeItem("Settings…", action: #selector(openSettings), key: ","))
        menu.addItem(makeItem("About CmdV", action: #selector(showAbout)))
        menu.addItem(makeItem("Quit CmdV", action: #selector(quit), key: "q"))
        return menu
    }

    private func makeItem(_ title: String, action: Selector, key: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        return item
    }

    @objc private func openShelf() { appState.toggleShelf() }
    @objc private func togglePasteStack() { appState.pasteStack?.toggle() }
    @objc private func togglePause() {
        appState.togglePause()
    }
    @objc private func pauseFive() { appState.pause(for: 5 * 60) }
    @objc private func pauseThirty() { appState.pause(for: 30 * 60) }
    @objc private func pauseHour() { appState.pause(for: 60 * 60) }
    @objc private func openSettings() { appState.showSettings() }
    @objc private func showAbout() {
        NSApp.orderFrontStandardAboutPanel(nil)
    }
    @objc private func quit() { NSApp.terminate(nil) }

    @objc private func clearHistory() {
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

extension StatusItemController: NSMenuDelegate {
    func menuDidClose(_ menu: NSMenu) {
        // Detach asynchronously — clearing during tracking teardown is unsafe.
        DispatchQueue.main.async { [weak self] in
            self?.statusItem.menu = nil
        }
    }
}
