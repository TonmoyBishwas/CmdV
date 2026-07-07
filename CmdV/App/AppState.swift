import AppKit
import Observation
import SwiftData
import os.log

/// Root object wiring the engines together. Created once at launch.
@MainActor
@Observable
final class AppState {
    private static let log = Logger(subsystem: "com.tonmoybishwas.CmdV", category: "app")

    let container: ModelContainer
    let store: ClipStore
    let monitor: ClipboardMonitor

    /// Mirrored pause state for menu/UI display.
    var isPaused = false

    init() {
        Defaults.register()
        do {
            container = try StoreFactory.makeContainer()
        } catch {
            // A corrupt store should not brick the app: fall back to in-memory
            // so the user can still use CmdV and we can surface the problem.
            Self.log.fault("Persistent store failed, using in-memory: \(error, privacy: .public)")
            container = try! StoreFactory.makeContainer(inMemory: true)
        }
        store = ClipStore(modelContainer: container)
        monitor = ClipboardMonitor(store: store)
    }

    func start() {
        guard !isRunningTests else { return }
        monitor.start()
    }

    func togglePause() {
        if monitor.isPaused {
            monitor.resume()
        } else {
            monitor.pause(for: nil)
        }
        isPaused = monitor.isPaused
    }

    func pause(for duration: TimeInterval?) {
        monitor.pause(for: duration)
        isPaused = monitor.isPaused
    }

    func clearHistory() {
        Task {
            await store.deleteAllHistory()
        }
    }
}
