import Foundation

/// Derives the one-line label a clip shows in the menu bar quick copy list.
/// Pure so it stays unit-testable.
enum QuickMenuLabel {
    static let maxLength = 50

    static func label(
        title: String?,
        plainText: String?,
        fileNames: [String],
        fallback: String
    ) -> String {
        if let title {
            let line = firstLine(of: title)
            if !line.isEmpty { return truncate(line) }
        }
        if let plainText {
            let line = firstLine(of: plainText)
            if !line.isEmpty { return truncate(line) }
        }
        if !fileNames.isEmpty {
            return truncate(fileNames.joined(separator: ", "))
        }
        return fallback
    }

    private static func firstLine(of text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .newlines)
            .first?
            .trimmingCharacters(in: .whitespaces) ?? ""
    }

    private static func truncate(_ text: String) -> String {
        text.count <= maxLength ? text : String(text.prefix(maxLength - 1)) + "…"
    }
}
