import AppKit

/// Borderless, non-activating floating panel: it can become key (so the
/// search field receives typing) while the app underneath stays frontmost
/// and active — essential for pasting into it afterwards.
final class ShelfPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    init() {
        super.init(
            contentRect: .zero,
            styleMask: [.nonactivatingPanel, .borderless, .resizable],
            backing: .buffered,
            defer: true
        )
        isFloatingPanel = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        hidesOnDeactivate = false
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        isMovable = false
        animationBehavior = .none
        isReleasedWhenClosed = false
    }
}
