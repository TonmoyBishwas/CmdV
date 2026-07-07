import AppKit

/// Resolves which app put the current content on the pasteboard.
@MainActor
enum SourceAppResolver {
    /// Prefer the explicit marker written by well-behaved apps
    /// (org.nspasteboard.source), fall back to the frontmost app.
    static func resolve(pasteboard: NSPasteboard) -> String? {
        let sourceType = NSPasteboard.PasteboardType("org.nspasteboard.source")
        if let marked = pasteboard.string(forType: sourceType), !marked.isEmpty {
            return marked
        }
        return NSWorkspace.shared.frontmostApplication?.bundleIdentifier
    }

    static func icon(forBundleID bundleID: String?) -> NSImage? {
        guard let bundleID,
              let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
        else { return nil }
        return NSWorkspace.shared.icon(forFile: url.path)
    }

    static func displayName(forBundleID bundleID: String?) -> String? {
        guard let bundleID,
              let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
        else { return nil }
        return FileManager.default.displayName(atPath: url.path)
    }
}
