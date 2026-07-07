import Foundation

/// The content kinds CmdV distinguishes for previews and filtering.
enum ClipKind: String, CaseIterable, Sendable, Codable {
    case text
    case link
    case image
    case file
    case color
    case code
}

/// Classifies a capture into a ClipKind. Pure logic — unit-testable.
enum ItemClassifier {
    static func classify(
        plainText: String?,
        hasImage: Bool,
        fileURLs: [URL]
    ) -> ClipKind {
        if !fileURLs.isEmpty { return .file }
        if hasImage { return .image }

        guard let text = plainText?.trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty
        else { return hasImage ? .image : .text }

        if isColor(text) { return .color }
        if isSingleURL(text) { return .link }
        if looksLikeCode(text) { return .code }
        return .text
    }

    // MARK: - Color detection

    static func isColor(_ text: String) -> Bool {
        let hex = #"^#(?:[0-9a-fA-F]{3}|[0-9a-fA-F]{4}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$"#
        let rgb = #"^rgba?\(\s*\d{1,3}\s*,\s*\d{1,3}\s*,\s*\d{1,3}\s*(?:,\s*(?:0|1|0?\.\d+)\s*)?\)$"#
        return text.range(of: hex, options: .regularExpression) != nil
            || text.range(of: rgb, options: .regularExpression) != nil
    }

    // MARK: - URL detection

    static func isSingleURL(_ text: String) -> Bool {
        // Must be one token, no whitespace, and parse as a URL with a web scheme.
        guard !text.contains(where: \.isWhitespace),
              let url = URL(string: text),
              let scheme = url.scheme?.lowercased()
        else { return false }
        return ["http", "https", "ftp", "file"].contains(scheme) && url.host() != nil
            || scheme == "file"
    }

    // MARK: - Code heuristics

    private static let codeKeywords: [String] = [
        "func ", "def ", "class ", "struct ", "import ", "#include", "const ",
        "let ", "var ", "return ", "public ", "private ", "fn ", "=>", "->",
        "if (", "for (", "while (", "</", "/>", "#!/",
    ]

    static func looksLikeCode(_ text: String) -> Bool {
        let lines = text.components(separatedBy: .newlines)
        guard lines.count >= 2 else {
            // Single line: only obvious shell/code fragments count.
            return text.hasPrefix("#!/") || text.hasPrefix("$ ")
        }
        var signals = 0
        if text.contains("{") && text.contains("}") { signals += 1 }
        if text.contains(";") { signals += 1 }
        if lines.contains(where: { $0.hasPrefix("    ") || $0.hasPrefix("\t") }) { signals += 1 }
        if codeKeywords.contains(where: { text.contains($0) }) { signals += 2 }
        return signals >= 2
    }
}
