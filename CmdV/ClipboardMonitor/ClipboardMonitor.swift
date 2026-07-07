import AppKit
import os.log

/// Polls NSPasteboard.general for changes (macOS has no change notification)
/// and forwards recordable captures to the ClipStore.
@MainActor
final class ClipboardMonitor {
    private let log = Logger(subsystem: "com.tonmoybishwas.CmdV", category: "monitor")
    private let store: ClipStore
    private var timer: Timer?
    private var lastChangeCount: Int
    /// Change counts CmdV produced itself (via PasteEngine) — never recorded.
    private var expectedChangeCounts: Set<Int> = []

    /// Invoked for every recorded capture (Paste Stack feeds off this).
    var onCapture: ((ClipboardCapture) -> Void)?

    /// When non-nil and in the future, capture is paused.
    var pausedUntil: Date?
    /// Paused indefinitely (until manually resumed).
    var isPausedManually = false

    var isPaused: Bool {
        if isPausedManually { return true }
        if let until = pausedUntil, until > Date() { return true }
        return false
    }

    init(store: ClipStore) {
        self.store = store
        self.lastChangeCount = NSPasteboard.general.changeCount
    }

    func start() {
        stop()
        let interval = Defaults.pollInterval
        let timer = Timer(timeInterval: interval, repeats: true) { _ in
            Task { @MainActor [weak self] in
                self?.poll()
            }
        }
        timer.tolerance = interval / 4
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        log.info("Clipboard monitor started (interval \(interval, privacy: .public)s)")
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    /// PasteEngine calls this right after writing to the pasteboard so the
    /// monitor skips CmdV's own copies.
    func expectSelfCopy(changeCount: Int) {
        expectedChangeCounts.insert(changeCount)
    }

    func pause(for duration: TimeInterval?) {
        if let duration {
            pausedUntil = Date().addingTimeInterval(duration)
            isPausedManually = false
        } else {
            isPausedManually = true
            pausedUntil = nil
        }
    }

    func resume() {
        isPausedManually = false
        pausedUntil = nil
    }

    // MARK: - Polling

    private func poll() {
        let pasteboard = NSPasteboard.general
        let changeCount = pasteboard.changeCount
        guard changeCount != lastChangeCount else { return }
        lastChangeCount = changeCount

        guard !isPaused else { return }

        let isSelfCopy = expectedChangeCounts.remove(changeCount) != nil
        let types = Set((pasteboard.types ?? []).map(\.rawValue))
        let source = SourceAppResolver.resolve(pasteboard: pasteboard)

        let verdict = PrivacyGate.evaluate(
            isSelfCopy: isSelfCopy,
            types: types,
            sourceAppBundleID: source,
            excludedApps: Set(Defaults.excludedApps)
        )
        guard verdict == .record else {
            log.debug("Skipped pasteboard change: \(String(describing: verdict), privacy: .public)")
            return
        }

        guard let capture = read(pasteboard: pasteboard, types: types, source: source) else {
            return
        }
        onCapture?(capture)
        Task {
            await store.ingest(capture)
        }
    }

    /// Snapshot pasteboard contents defensively — some apps write promises
    /// that materialize lazily, and contents can mutate mid-read.
    private func read(
        pasteboard: NSPasteboard,
        types: Set<String>,
        source: String?
    ) -> ClipboardCapture? {
        var capture = ClipboardCapture(
            types: types,
            plainText: nil,
            rtfData: nil,
            htmlString: nil,
            imageData: nil,
            imageIsPNG: false,
            fileURLs: [],
            sourceAppBundleID: source,
            capturedAt: Date()
        )

        if types.contains(NSPasteboard.PasteboardType.fileURL.rawValue) {
            let options: [NSPasteboard.ReadingOptionKey: Any] = [.urlReadingFileURLsOnly: true]
            if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: options) as? [URL] {
                capture.fileURLs = urls
            }
        }

        if capture.fileURLs.isEmpty {
            if let png = pasteboard.data(forType: .png) {
                capture.imageData = png
                capture.imageIsPNG = true
            } else if let tiff = pasteboard.data(forType: .tiff) {
                capture.imageData = tiff
                capture.imageIsPNG = false
            }
        }

        capture.plainText = pasteboard.string(forType: .string)
        if capture.imageData == nil {
            capture.rtfData = pasteboard.data(forType: .rtf)
            capture.htmlString = pasteboard.string(forType: .html)
        }

        guard !capture.isEmpty else {
            log.debug("Pasteboard change had no readable content (promise-only?)")
            return nil
        }
        return capture
    }
}
