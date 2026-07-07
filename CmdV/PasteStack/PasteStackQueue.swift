import Foundation

/// The Paste Stack's queue: copies append, ⌘V consumes in copy order
/// (or reversed). Pure logic — unit-testable.
struct PasteStackQueue: Sendable {
    struct Entry: Sendable, Identifiable, Equatable {
        let id: UUID
        var label: String
        var kind: ClipKind
        var capture: ClipboardCapture

        static func == (lhs: Entry, rhs: Entry) -> Bool { lhs.id == rhs.id }
    }

    private(set) var entries: [Entry] = []
    /// false = first copied pastes first (FIFO); true = last copied first.
    private(set) var isReversed = false

    var isEmpty: Bool { entries.isEmpty }
    var count: Int { entries.count }

    /// Entries in the order they will paste.
    var pasteOrder: [Entry] {
        isReversed ? entries.reversed() : entries
    }

    mutating func append(_ capture: ClipboardCapture) {
        let kind = ItemClassifier.classify(
            plainText: capture.plainText,
            hasImage: capture.imageData != nil,
            fileURLs: capture.fileURLs
        )
        let label: String
        switch kind {
        case .image:
            label = "Image"
        case .file:
            label = capture.fileURLs.first?.lastPathComponent ?? "File"
        default:
            label = String((capture.plainText ?? "").trimmingCharacters(in: .whitespacesAndNewlines).prefix(40))
        }
        entries.append(Entry(id: UUID(), label: label, kind: kind, capture: capture))
    }

    /// Pops the next entry to paste.
    mutating func next() -> Entry? {
        guard !entries.isEmpty else { return nil }
        return isReversed ? entries.removeLast() : entries.removeFirst()
    }

    mutating func remove(id: UUID) {
        entries.removeAll { $0.id == id }
    }

    mutating func toggleReversed() {
        isReversed.toggle()
    }

    mutating func clear() {
        entries = []
        isReversed = false
    }
}
