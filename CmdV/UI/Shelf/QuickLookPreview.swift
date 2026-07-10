import AppKit
import Quartz

/// Spacebar Quick Look for clipboard items. Text-based items are written to
/// a temp file so the system previewer can render them.
@MainActor
final class QuickLookController: NSObject, @preconcurrency QLPreviewPanelDataSource, QLPreviewPanelDelegate {
    static let shared = QuickLookController()

    private var previewURL: URL?
    private let imageStore = ImageFileStore.default()

    func preview(item: ClipItem) {
        previewURL = url(for: item)
        guard previewURL != nil, let panel = QLPreviewPanel.shared() else { return }
        panel.dataSource = self
        panel.delegate = self
        panel.reloadData()
        panel.makeKeyAndOrderFront(nil)
    }

    private func url(for item: ClipItem) -> URL? {
        switch item.kind {
        case .file:
            return item.fileURLPaths.first.map { URL(fileURLWithPath: $0) }
        case .image:
            return item.imageFileName.map { imageStore.url(forFileName: $0) }
        default:
            guard let text = item.plainText else { return nil }
            let ext = item.kind == .code ? "swift" : "txt"
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("CmdV-QuickLook-\(item.uuid.uuidString).\(ext)")
            try? text.write(to: url, atomically: true, encoding: .utf8)
            return url
        }
    }

    // MARK: - QLPreviewPanelDataSource

    func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
        previewURL == nil ? 0 : 1
    }

    func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> QLPreviewItem! {
        previewURL as NSURL?
    }
}
