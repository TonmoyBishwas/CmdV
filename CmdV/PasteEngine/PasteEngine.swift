import AppKit
import os.log

/// Writes clip items back to the pasteboard. The CGEvent auto-paste layer
/// sits on top of this (KeySimulator).
@MainActor
enum PasteEngine {
    private static let log = Logger(subsystem: "com.tonmoybishwas.CmdV", category: "paste")

    /// Puts an item on the general pasteboard with its richest representations.
    /// Flags the resulting changeCount as a self-copy so the monitor skips it.
    static func copy(
        _ item: ClipItem,
        plainTextOnly: Bool,
        monitor: ClipboardMonitor,
        imageStore: ImageFileStore = .default()
    ) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        if plainTextOnly {
            pasteboard.setString(item.plainText ?? "", forType: .string)
        } else {
            switch item.kind {
            case .file:
                let urls = item.fileURLPaths.map { URL(fileURLWithPath: $0) as NSURL }
                if !urls.isEmpty {
                    pasteboard.writeObjects(urls)
                }
            case .image:
                if let name = item.imageFileName,
                   let data = try? Data(contentsOf: imageStore.url(forFileName: name)) {
                    let type: NSPasteboard.PasteboardType = name.hasSuffix(".png") ? .png : .tiff
                    pasteboard.setData(data, forType: type)
                } else if let thumb = item.thumbnailData {
                    pasteboard.setData(thumb, forType: .png)
                }
            default:
                if let rtf = item.rtfData {
                    pasteboard.setData(rtf, forType: .rtf)
                }
                if let html = item.htmlString {
                    pasteboard.setString(html, forType: .html)
                }
                if let text = item.plainText {
                    pasteboard.setString(text, forType: .string)
                }
            }
        }

        monitor.expectSelfCopy(changeCount: pasteboard.changeCount)
        log.debug("Copied item \(item.uuid, privacy: .public) (plain: \(plainTextOnly))")
    }

    /// Writes a raw capture (Paste Stack entries) back to the pasteboard.
    static func copyCapture(_ capture: ClipboardCapture, monitor: ClipboardMonitor) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        if !capture.fileURLs.isEmpty {
            pasteboard.writeObjects(capture.fileURLs.map { $0 as NSURL })
        } else if let image = capture.imageData {
            pasteboard.setData(image, forType: capture.imageIsPNG ? .png : .tiff)
        } else {
            if let rtf = capture.rtfData {
                pasteboard.setData(rtf, forType: .rtf)
            }
            if let html = capture.htmlString {
                pasteboard.setString(html, forType: .html)
            }
            if let text = capture.plainText {
                pasteboard.setString(text, forType: .string)
            }
        }
        monitor.expectSelfCopy(changeCount: pasteboard.changeCount)
    }

    // MARK: - Snapshot / restore (optional "restore clipboard after paste")

    typealias PasteboardSnapshot = [[String: Data]]

    /// Captures the current pasteboard contents so they can be restored
    /// after CmdV pastes an item.
    static func snapshot() -> PasteboardSnapshot {
        (NSPasteboard.general.pasteboardItems ?? []).map { item in
            var entry: [String: Data] = [:]
            for type in item.types {
                if let data = item.data(forType: type) {
                    entry[type.rawValue] = data
                }
            }
            return entry
        }
    }

    static func restore(_ snapshot: PasteboardSnapshot, monitor: ClipboardMonitor) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        let items = snapshot.map { entry in
            let item = NSPasteboardItem()
            for (type, data) in entry {
                item.setData(data, forType: NSPasteboard.PasteboardType(type))
            }
            return item
        }
        pasteboard.writeObjects(items)
        monitor.expectSelfCopy(changeCount: pasteboard.changeCount)
    }

    /// Copies several items joined as text (multi-select paste).
    static func copyMultiple(
        _ items: [ClipItem],
        plainTextOnly: Bool,
        monitor: ClipboardMonitor
    ) {
        guard !items.isEmpty else { return }
        if items.count == 1 {
            copy(items[0], plainTextOnly: plainTextOnly, monitor: monitor)
            return
        }
        let joined = items.compactMap(\.plainText).joined(separator: "\n")
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(joined, forType: .string)
        monitor.expectSelfCopy(changeCount: pasteboard.changeCount)
    }
}
