import ServiceManagement
import SwiftUI
import os.log

struct GeneralSettings: View {
    private static let log = Logger(subsystem: "com.tonmoybishwas.CmdV", category: "settings")

    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @AppStorage(Defaults.Keys.retentionDays) private var retentionDays = 30
    @AppStorage(Defaults.Keys.maxItems) private var maxItems = 1000
    @AppStorage(Defaults.Keys.restoreClipboardAfterPaste) private var restoreClipboard = false

    var body: some View {
        Form {
            Section {
                Toggle("Launch CmdV at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in
                        do {
                            if enabled {
                                try SMAppService.mainApp.register()
                            } else {
                                try SMAppService.mainApp.unregister()
                            }
                        } catch {
                            Self.log.error("Login item change failed: \(error, privacy: .public)")
                            launchAtLogin = SMAppService.mainApp.status == .enabled
                        }
                    }
            }

            Section("History") {
                Picker("Keep items for", selection: $retentionDays) {
                    Text("1 day").tag(1)
                    Text("1 week").tag(7)
                    Text("1 month").tag(30)
                    Text("3 months").tag(90)
                    Text("1 year").tag(365)
                    Text("Forever").tag(0)
                }
                Picker("Maximum items", selection: $maxItems) {
                    Text("100").tag(100)
                    Text("500").tag(500)
                    Text("1,000").tag(1000)
                    Text("5,000").tag(5000)
                    Text("Unlimited").tag(0)
                }
                Text("Pinned items are always kept, no matter these limits.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Pasting") {
                Toggle("Restore previous clipboard after pasting", isOn: $restoreClipboard)
                Text("After CmdV pastes an item, whatever was on the clipboard before is put back.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding(.vertical, 8)
    }
}
