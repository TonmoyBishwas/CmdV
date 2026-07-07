import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Stores full-size copied images as files under Application Support so the
/// SwiftData store stays small; generates thumbnails for card rendering.
struct ImageFileStore: Sendable {
    let directory: URL

    static func `default`() -> ImageFileStore {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return ImageFileStore(directory: base.appendingPathComponent("CmdV/Images", isDirectory: true))
    }

    func ensureDirectory() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    /// Writes image data to disk, returns the stored file name.
    func save(_ data: Data, isPNG: Bool, uuid: UUID) throws -> String {
        try ensureDirectory()
        let name = "\(uuid.uuidString).\(isPNG ? "png" : "tiff")"
        try data.write(to: directory.appendingPathComponent(name), options: .atomic)
        return name
    }

    func url(forFileName name: String) -> URL {
        directory.appendingPathComponent(name)
    }

    func delete(fileName: String) {
        try? FileManager.default.removeItem(at: url(forFileName: name(from: fileName)))
    }

    private func name(from fileName: String) -> String {
        // Defensive: never allow path traversal out of the images directory.
        URL(fileURLWithPath: fileName).lastPathComponent
    }

    /// Thumbnail (PNG data) + pixel dimensions, generated off the main thread
    /// via ImageIO (thread-safe, no NSImage).
    static func thumbnail(
        from data: Data,
        maxPixelSize: Int = 600
    ) -> (thumbnail: Data?, width: Int, height: Int) {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            return (nil, 0, 0)
        }
        var width = 0
        var height = 0
        if let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] {
            width = props[kCGImagePropertyPixelWidth] as? Int ?? 0
            height = props[kCGImagePropertyPixelHeight] as? Int ?? 0
        }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
            kCGImageSourceCreateThumbnailWithTransform: true,
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return (nil, width, height)
        }
        let out = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(out, UTType.png.identifier as CFString, 1, nil) else {
            return (nil, width, height)
        }
        CGImageDestinationAddImage(dest, cgImage, nil)
        CGImageDestinationFinalize(dest)
        return (out as Data, width, height)
    }
}
