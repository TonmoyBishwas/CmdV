import Foundation
import SwiftData

@Model
final class ClipItem {
    @Attribute(.unique) var uuid: UUID
    var createdAt: Date
    var kindRaw: String
    var plainText: String?
    var rtfData: Data?
    var htmlString: String?
    /// Full-size image stored on disk (see ImageFileStore); path relative to the images directory.
    var imageFileName: String?
    /// Small pre-rendered thumbnail for instant card rendering.
    var thumbnailData: Data?
    var fileURLPaths: [String]
    var sourceAppBundleID: String?
    /// User-assigned title (⌘R rename).
    var title: String?
    var pinboard: Pinboard?
    /// Text recognized in images (Vision OCR), included in search.
    var ocrText: String?
    var byteCount: Int
    var charCount: Int
    var pixelWidth: Int
    var pixelHeight: Int
    var contentHash: String

    var kind: ClipKind {
        get { ClipKind(rawValue: kindRaw) ?? .text }
        set { kindRaw = newValue.rawValue }
    }

    init(
        uuid: UUID = UUID(),
        createdAt: Date = Date(),
        kind: ClipKind,
        plainText: String? = nil,
        rtfData: Data? = nil,
        htmlString: String? = nil,
        imageFileName: String? = nil,
        thumbnailData: Data? = nil,
        fileURLPaths: [String] = [],
        sourceAppBundleID: String? = nil,
        title: String? = nil,
        ocrText: String? = nil,
        byteCount: Int = 0,
        charCount: Int = 0,
        pixelWidth: Int = 0,
        pixelHeight: Int = 0,
        contentHash: String
    ) {
        self.uuid = uuid
        self.createdAt = createdAt
        self.kindRaw = kind.rawValue
        self.plainText = plainText
        self.rtfData = rtfData
        self.htmlString = htmlString
        self.imageFileName = imageFileName
        self.thumbnailData = thumbnailData
        self.fileURLPaths = fileURLPaths
        self.sourceAppBundleID = sourceAppBundleID
        self.title = title
        self.ocrText = ocrText
        self.byteCount = byteCount
        self.charCount = charCount
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
        self.contentHash = contentHash
    }
}

@Model
final class Pinboard {
    @Attribute(.unique) var uuid: UUID
    var name: String
    var colorHex: String
    var sortOrder: Int
    @Relationship(inverse: \ClipItem.pinboard) var items: [ClipItem]

    init(uuid: UUID = UUID(), name: String, colorHex: String, sortOrder: Int) {
        self.uuid = uuid
        self.name = name
        self.colorHex = colorHex
        self.sortOrder = sortOrder
        self.items = []
    }
}
