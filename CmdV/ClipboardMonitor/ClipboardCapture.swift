import Foundation

/// A value snapshot of one pasteboard change, safe to send across actors.
struct ClipboardCapture: Sendable {
    var types: Set<String>
    var plainText: String?
    var rtfData: Data?
    var htmlString: String?
    var imageData: Data?          // PNG preferred, TIFF fallback
    var imageIsPNG: Bool
    var fileURLs: [URL]
    var sourceAppBundleID: String?
    var capturedAt: Date

    var isEmpty: Bool {
        plainText == nil && rtfData == nil && htmlString == nil
            && imageData == nil && fileURLs.isEmpty
    }
}
