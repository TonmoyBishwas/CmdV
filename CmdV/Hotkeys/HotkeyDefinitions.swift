import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    /// Open/close the shelf (Paste's muscle memory: ⇧⌘V).
    static let openShelf = Self("openShelf", default: .init(.v, modifiers: [.command, .shift]))
    /// Start/stop the Paste Stack queue.
    static let pasteStack = Self("pasteStack", default: .init(.c, modifiers: [.command, .shift]))
    /// Registered only while the Paste Stack is active: consumes ⌘V.
    static let stackPaste = Self("stackPaste")
}
