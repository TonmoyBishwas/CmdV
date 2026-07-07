import Foundation

/// UserDefaults-backed app settings.
enum Defaults {
    enum Keys {
        static let retentionDays = "retentionDays"
        static let maxItems = "maxItems"
        static let excludedApps = "excludedApps"
        static let pollInterval = "pollInterval"
        static let shelfHeight = "shelfHeight"
        static let compactMode = "compactMode"
        static let restoreClipboardAfterPaste = "restoreClipboardAfterPaste"
    }

    static func register() {
        UserDefaults.standard.register(defaults: [
            Keys.retentionDays: 30,
            Keys.maxItems: 1000,
            Keys.excludedApps: [String](),
            Keys.pollInterval: 0.5,
            Keys.shelfHeight: 320.0,
            Keys.compactMode: false,
            Keys.restoreClipboardAfterPaste: false,
        ])
    }

    static var retentionDays: Int {
        get { UserDefaults.standard.integer(forKey: Keys.retentionDays) }
        set { UserDefaults.standard.set(newValue, forKey: Keys.retentionDays) }
    }

    static var maxItems: Int {
        get { UserDefaults.standard.integer(forKey: Keys.maxItems) }
        set { UserDefaults.standard.set(newValue, forKey: Keys.maxItems) }
    }

    static var excludedApps: [String] {
        get { UserDefaults.standard.stringArray(forKey: Keys.excludedApps) ?? [] }
        set { UserDefaults.standard.set(newValue, forKey: Keys.excludedApps) }
    }

    static var pollInterval: TimeInterval {
        let value = UserDefaults.standard.double(forKey: Keys.pollInterval)
        return value > 0 ? value : 0.5
    }

    static var restoreClipboardAfterPaste: Bool {
        get { UserDefaults.standard.bool(forKey: Keys.restoreClipboardAfterPaste) }
        set { UserDefaults.standard.set(newValue, forKey: Keys.restoreClipboardAfterPaste) }
    }
}

/// True when running inside a unit-test host, in which case the app skips
/// starting its engines so tests control all state.
var isRunningTests: Bool {
    let env = ProcessInfo.processInfo.environment
    return env["XCTestConfigurationFilePath"] != nil
        || env["XCTestSessionIdentifier"] != nil
        || env["XCTestBundlePath"] != nil
        || NSClassFromString("XCTestCase") != nil
}
