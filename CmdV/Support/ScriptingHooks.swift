import Foundation

/// Darwin-notification triggers so the shelf can be driven from scripts and
/// automation tools (and headless testing):
///
///     notifyutil -p com.tonmoybishwas.CmdV.toggleShelf
///     notifyutil -p com.tonmoybishwas.CmdV.togglePasteStack
@MainActor
enum ScriptingHooks {
    static let toggleShelfNotification = "com.tonmoybishwas.CmdV.toggleShelf"
    static let toggleStackNotification = "com.tonmoybishwas.CmdV.togglePasteStack"

    static func install(appState: AppState) {
        observe(toggleShelfNotification, appState: appState) { $0.toggleShelf() }
        observe(toggleStackNotification, appState: appState) { $0.pasteStack?.toggle() }
    }

    private static func observe(
        _ name: String,
        appState: AppState,
        action: @escaping @MainActor (AppState) -> Void
    ) {
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        let observer = Unmanaged.passUnretained(appState).toOpaque()
        let box = ActionBox(action: action)
        actions[name] = box
        CFNotificationCenterAddObserver(
            center,
            observer,
            { _, observer, cfName, _, _ in
                guard let observer, let cfName else { return }
                let appState = Unmanaged<AppState>.fromOpaque(observer).takeUnretainedValue()
                let key = cfName.rawValue as String
                DispatchQueue.main.async {
                    ScriptingHooks.actions[key]?.action(appState)
                }
            },
            name as CFString,
            nil,
            .deliverImmediately
        )
    }

    private struct ActionBox {
        let action: @MainActor (AppState) -> Void
    }

    private static var actions: [String: ActionBox] = [:]
}
