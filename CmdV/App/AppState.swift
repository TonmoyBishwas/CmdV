import AppKit
import KeyboardShortcuts
import Observation
import SwiftData
import os.log

/// Root object wiring the engines together. Created once at launch.
@MainActor
@Observable
final class AppState {
    private static let log = Logger(subsystem: "com.tonmoybishwas.CmdV", category: "app")

    let container: ModelContainer
    let store: ClipStore
    let monitor: ClipboardMonitor
    private(set) var shelf: ShelfPanelController!

    /// Mirrored pause state for menu/UI display.
    var isPaused = false

    init() {
        Defaults.register()
        do {
            container = try StoreFactory.makeContainer()
        } catch {
            // A corrupt store should not brick the app: fall back to in-memory
            // so the user can still use CmdV and we can surface the problem.
            Self.log.fault("Persistent store failed, using in-memory: \(error, privacy: .public)")
            container = try! StoreFactory.makeContainer(inMemory: true)
        }
        store = ClipStore(modelContainer: container)
        monitor = ClipboardMonitor(store: store)
        shelf = ShelfPanelController(appState: self)
    }

    func start() {
        guard !isRunningTests else { return }
        monitor.start()
        KeyboardShortcuts.onKeyDown(for: .openShelf) { [weak self] in
            self?.shelf.toggle()
        }
        ScriptingHooks.install(appState: self)
    }

    // MARK: - Shelf

    func toggleShelf() {
        shelf.toggle()
    }

    // MARK: - Pause

    func togglePause() {
        if monitor.isPaused {
            monitor.resume()
        } else {
            monitor.pause(for: nil)
        }
        isPaused = monitor.isPaused
    }

    func pause(for duration: TimeInterval?) {
        monitor.pause(for: duration)
        isPaused = monitor.isPaused
    }

    // MARK: - Item lookup (main context, UI-driven actions)

    private func item(uuid: UUID) -> ClipItem? {
        let descriptor = FetchDescriptor<ClipItem>(predicate: #Predicate { $0.uuid == uuid })
        return try? container.mainContext.fetch(descriptor).first
    }

    // MARK: - Paste / copy actions

    func pasteSelected(plainTextOnly: Bool) {
        let model = shelf.viewModel
        if !model.multiSelection.isEmpty {
            let items = model.visibleUUIDs
                .filter { model.multiSelection.contains($0) }
                .compactMap { item(uuid: $0) }
            guard !items.isEmpty else { return }
            PasteEngine.copyMultiple(items, plainTextOnly: plainTextOnly, monitor: monitor)
            shelf.hideAndFocusPreviousApp {
                KeySimulator.pasteIfTrusted()
            }
            return
        }
        guard let uuid = model.selectedUUID else { return }
        pasteItem(uuid: uuid, plainTextOnly: plainTextOnly)
    }

    func pasteItem(uuid: UUID, plainTextOnly: Bool) {
        guard let item = item(uuid: uuid) else { return }
        PasteEngine.copy(item, plainTextOnly: plainTextOnly, monitor: monitor)
        shelf.hideAndFocusPreviousApp {
            KeySimulator.pasteIfTrusted()
        }
    }

    func copyItem(uuid: UUID) {
        guard let item = item(uuid: uuid) else { return }
        PasteEngine.copy(item, plainTextOnly: false, monitor: monitor)
        shelf.hide()
    }

    // MARK: - Item mutations

    func deleteSelected() {
        let model = shelf.viewModel
        let doomed = model.multiSelection.isEmpty
            ? (model.selectedUUID.map { [$0] } ?? [])
            : Array(model.multiSelection)
        guard !doomed.isEmpty else { return }
        // Move selection before the items disappear.
        model.selectNext()
        Task {
            for uuid in doomed {
                await store.delete(uuid: uuid)
            }
        }
    }

    func deleteItem(uuid: UUID) {
        Task {
            await store.delete(uuid: uuid)
        }
    }

    func renameItem(uuid: UUID, title: String) {
        Task {
            await store.rename(uuid: uuid, title: title)
        }
    }

    func updateItemText(uuid: UUID, text: String) {
        Task {
            await store.updateText(uuid: uuid, text: text)
        }
    }

    func pinItem(uuid: UUID, pinboardUUID: UUID?) {
        Task {
            await store.pin(itemUUID: uuid, toPinboard: pinboardUUID)
        }
    }

    func clearHistory() {
        Task {
            await store.deleteAllHistory()
        }
    }

    // MARK: - Pinboards

    func deletePinboard(uuid: UUID) {
        Task {
            await store.deletePinboard(uuid: uuid)
        }
    }

    func createPinboardRequested(pinning itemUUID: UUID? = nil) {
        let alert = NSAlert()
        alert.messageText = "New Pinboard"
        alert.informativeText = "Pinned items are kept forever, separate from history."
        alert.addButton(withTitle: "Create")
        alert.addButton(withTitle: "Cancel")

        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 220, height: 24))
        field.placeholderString = "Name"
        alert.accessoryView = field
        alert.window.initialFirstResponder = field

        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let name = field.stringValue.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        let palette = ["#e5484d", "#f76b15", "#ffc53d", "#46a758", "#0090ff", "#8e4ec6", "#e93d82"]
        let color = palette.randomElement() ?? "#0090ff"
        Task {
            await store.createPinboard(name: name, colorHex: color)
            if let itemUUID {
                await store.pinToNewestPinboard(itemUUID: itemUUID)
            }
        }
    }

    // MARK: - New item (⌘N)

    func createNewItemRequested() {
        let alert = NSAlert()
        alert.messageText = "New Clipboard Item"
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")

        let scroll = NSScrollView(frame: NSRect(x: 0, y: 0, width: 320, height: 120))
        let textView = NSTextView(frame: scroll.bounds)
        textView.font = .systemFont(ofSize: NSFont.systemFontSize)
        textView.isRichText = false
        scroll.documentView = textView
        scroll.hasVerticalScroller = true
        alert.accessoryView = scroll
        alert.window.initialFirstResponder = textView

        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let text = textView.string
        guard !text.isEmpty else { return }
        Task {
            await store.createTextItem(text)
        }
    }

    // MARK: - Quick Look

    func quickLookSelected() {
        guard let uuid = shelf.viewModel.selectedUUID, let item = item(uuid: uuid) else { return }
        QuickLookController.shared.preview(item: item)
    }
}
