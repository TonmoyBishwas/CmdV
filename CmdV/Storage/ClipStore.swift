import CryptoKit
import Foundation
import SwiftData
import os.log

/// The single writer for the SwiftData store. All mutations are serialized
/// through this actor; the UI reads via @Query on the main context.
@ModelActor
actor ClipStore {
    private static let log = Logger(subsystem: "com.tonmoybishwas.CmdV", category: "store")

    private var imageStore = ImageFileStore.default()

    func setImageStore(_ store: ImageFileStore) {
        imageStore = store
    }

    // MARK: - Ingest

    /// Classify, hash, dedupe, and persist one capture.
    func ingest(_ capture: ClipboardCapture) {
        let kind = ItemClassifier.classify(
            plainText: capture.plainText,
            hasImage: capture.imageData != nil,
            fileURLs: capture.fileURLs
        )
        let hash = Self.contentHash(for: capture)

        // Re-copying something already in history bumps it to the top
        // instead of duplicating. Pinned items are left alone.
        if let existing = fetchUnpinned(hash: hash) {
            existing.createdAt = capture.capturedAt
            saveQuietly()
            return
        }

        let uuid = UUID()
        var imageFileName: String?
        var thumbnail: Data?
        var pixelWidth = 0
        var pixelHeight = 0

        if let imageData = capture.imageData {
            let thumb = ImageFileStore.thumbnail(from: imageData)
            thumbnail = thumb.thumbnail
            pixelWidth = thumb.width
            pixelHeight = thumb.height
            do {
                imageFileName = try imageStore.save(imageData, isPNG: capture.imageIsPNG, uuid: uuid)
            } catch {
                Self.log.error("Failed to store image: \(error, privacy: .public)")
                return
            }
        }

        let item = ClipItem(
            uuid: uuid,
            createdAt: capture.capturedAt,
            kind: kind,
            plainText: capture.plainText,
            rtfData: capture.rtfData,
            htmlString: capture.htmlString,
            imageFileName: imageFileName,
            thumbnailData: thumbnail,
            fileURLPaths: capture.fileURLs.map(\.path),
            sourceAppBundleID: capture.sourceAppBundleID,
            byteCount: capture.imageData?.count ?? capture.plainText?.utf8.count ?? 0,
            charCount: capture.plainText?.count ?? 0,
            pixelWidth: pixelWidth,
            pixelHeight: pixelHeight,
            contentHash: hash
        )
        modelContext.insert(item)
        saveQuietly()
        prune()
    }

    /// Create a text item authored inside CmdV (⌘N).
    func createTextItem(_ text: String) {
        let capture = ClipboardCapture(
            types: [],
            plainText: text,
            rtfData: nil,
            htmlString: nil,
            imageData: nil,
            imageIsPNG: false,
            fileURLs: [],
            sourceAppBundleID: Bundle.main.bundleIdentifier,
            capturedAt: Date()
        )
        ingest(capture)
    }

    // MARK: - Mutations

    func delete(uuid: UUID) {
        guard let item = fetch(uuid: uuid) else { return }
        if let file = item.imageFileName {
            imageStore.delete(fileName: file)
        }
        modelContext.delete(item)
        saveQuietly()
    }

    func deleteAllHistory() {
        let descriptor = FetchDescriptor<ClipItem>(
            predicate: #Predicate { $0.pinboard == nil }
        )
        guard let items = try? modelContext.fetch(descriptor) else { return }
        for item in items {
            if let file = item.imageFileName {
                imageStore.delete(fileName: file)
            }
            modelContext.delete(item)
        }
        saveQuietly()
    }

    func rename(uuid: UUID, title: String?) {
        guard let item = fetch(uuid: uuid) else { return }
        item.title = (title?.isEmpty == true) ? nil : title
        saveQuietly()
    }

    func updateText(uuid: UUID, text: String) {
        guard let item = fetch(uuid: uuid) else { return }
        item.plainText = text
        item.rtfData = nil
        item.htmlString = nil
        item.charCount = text.count
        item.byteCount = text.utf8.count
        item.contentHash = Self.hash(of: Data(text.utf8))
        saveQuietly()
    }

    func setOCRText(uuid: UUID, text: String) {
        guard let item = fetch(uuid: uuid) else { return }
        item.ocrText = text
        saveQuietly()
    }

    // MARK: - Pinboards

    func createPinboard(name: String, colorHex: String) {
        let count = (try? modelContext.fetchCount(FetchDescriptor<Pinboard>())) ?? 0
        modelContext.insert(Pinboard(name: name, colorHex: colorHex, sortOrder: count))
        saveQuietly()
    }

    func deletePinboard(uuid: UUID) {
        let descriptor = FetchDescriptor<Pinboard>(predicate: #Predicate { $0.uuid == uuid })
        guard let board = try? modelContext.fetch(descriptor).first else { return }
        // Items return to plain history rather than being destroyed.
        for item in board.items {
            item.pinboard = nil
        }
        modelContext.delete(board)
        saveQuietly()
    }

    func renamePinboard(uuid: UUID, name: String, colorHex: String) {
        let descriptor = FetchDescriptor<Pinboard>(predicate: #Predicate { $0.uuid == uuid })
        guard let board = try? modelContext.fetch(descriptor).first else { return }
        board.name = name
        board.colorHex = colorHex
        saveQuietly()
    }

    /// Pins an item to the most recently created pinboard (used right after
    /// "New Pinboard…" from an item's context menu).
    func pinToNewestPinboard(itemUUID: UUID) {
        var descriptor = FetchDescriptor<Pinboard>(sortBy: [SortDescriptor(\.sortOrder, order: .reverse)])
        descriptor.fetchLimit = 1
        guard let board = try? modelContext.fetch(descriptor).first,
              let item = fetch(uuid: itemUUID)
        else { return }
        item.pinboard = board
        saveQuietly()
    }

    func pin(itemUUID: UUID, toPinboard pinboardUUID: UUID?) {
        guard let item = fetch(uuid: itemUUID) else { return }
        if let pinboardUUID {
            let descriptor = FetchDescriptor<Pinboard>(
                predicate: #Predicate { $0.uuid == pinboardUUID }
            )
            item.pinboard = try? modelContext.fetch(descriptor).first
        } else {
            item.pinboard = nil
        }
        saveQuietly()
    }

    // MARK: - Retention

    func prune(policy: RetentionPolicy? = nil) {
        let policy = policy ?? RetentionPolicy(
            maxAgeDays: Defaults.retentionDays,
            maxItems: Defaults.maxItems
        )
        let descriptor = FetchDescriptor<ClipItem>()
        guard let items = try? modelContext.fetch(descriptor) else { return }
        let candidates = items.map {
            RetentionPolicy.Candidate(
                uuid: $0.uuid,
                createdAt: $0.createdAt,
                isPinned: $0.pinboard != nil
            )
        }
        let doomed = policy.itemsToPrune(from: candidates)
        guard !doomed.isEmpty else { return }
        for item in items where doomed.contains(item.uuid) {
            if let file = item.imageFileName {
                imageStore.delete(fileName: file)
            }
            modelContext.delete(item)
        }
        saveQuietly()
        Self.log.info("Pruned \(doomed.count, privacy: .public) items")
    }

    // MARK: - Queries (for non-UI callers)

    func itemCount() -> Int {
        (try? modelContext.fetchCount(FetchDescriptor<ClipItem>())) ?? 0
    }

    // MARK: - Helpers

    private func fetch(uuid: UUID) -> ClipItem? {
        let descriptor = FetchDescriptor<ClipItem>(predicate: #Predicate { $0.uuid == uuid })
        return try? modelContext.fetch(descriptor).first
    }

    private func fetchUnpinned(hash: String) -> ClipItem? {
        let descriptor = FetchDescriptor<ClipItem>(
            predicate: #Predicate { $0.contentHash == hash && $0.pinboard == nil }
        )
        return try? modelContext.fetch(descriptor).first
    }

    private func saveQuietly() {
        do {
            try modelContext.save()
        } catch {
            Self.log.error("Save failed: \(error, privacy: .public)")
        }
    }

    static func contentHash(for capture: ClipboardCapture) -> String {
        if let image = capture.imageData {
            return hash(of: image)
        }
        if !capture.fileURLs.isEmpty {
            return hash(of: Data(capture.fileURLs.map(\.path).joined(separator: "\n").utf8))
        }
        return hash(of: Data((capture.plainText ?? "").utf8))
    }

    static func hash(of data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Container factory

enum StoreFactory {
    static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        let schema = Schema([ClipItem.self, Pinboard.self])
        if inMemory {
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            return try ModelContainer(for: schema, configurations: [config])
        }
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("CmdV", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let config = ModelConfiguration(schema: schema, url: dir.appendingPathComponent("CmdV.store"))
        return try ModelContainer(for: schema, configurations: [config])
    }
}
