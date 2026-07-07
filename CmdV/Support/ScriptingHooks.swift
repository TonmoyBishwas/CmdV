import Foundation

/// Darwin-notification triggers so the shelf can be driven from scripts and
/// automation tools (and headless testing):
///
///     notifyutil -p com.tonmoybishwas.CmdV.toggleShelf
@MainActor
enum ScriptingHooks {
    static let toggleShelfNotification = "com.tonmoybishwas.CmdV.toggleShelf"

    static func install(appState: AppState) {
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        let observer = Unmanaged.passUnretained(appState).toOpaque()
        CFNotificationCenterAddObserver(
            center,
            observer,
            { _, observer, _, _, _ in
                guard let observer else { return }
                let appState = Unmanaged<AppState>.fromOpaque(observer).takeUnretainedValue()
                DispatchQueue.main.async {
                    appState.toggleShelf()
                }
            },
            toggleShelfNotification as CFString,
            nil,
            .deliverImmediately
        )
    }
}
