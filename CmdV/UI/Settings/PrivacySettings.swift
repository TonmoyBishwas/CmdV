import AppKit
import SwiftUI

struct PrivacySettings: View {
    let appState: AppState

    @State private var excludedApps = Defaults.excludedApps
    @State private var selection: String?
    @State private var accessibilityGranted = AccessibilityPermission.isTrusted

    var body: some View {
        Form {
            Section("Direct Paste") {
                HStack {
                    Image(systemName: accessibilityGranted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundStyle(accessibilityGranted ? .green : .orange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(accessibilityGranted
                             ? "Accessibility permission granted"
                             : "Accessibility permission needed")
                        Text(accessibilityGranted
                             ? "CmdV pastes directly at your cursor."
                             : "Without it, CmdV copies items and you press ⌘V yourself.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if !accessibilityGranted {
                        Button("Open System Settings") {
                            AccessibilityPermission.promptIfNeeded()
                            AccessibilityPermission.openSystemSettings()
                        }
                    }
                }
            }

            Section("Ignored Apps") {
                Text("Anything copied in these apps is never recorded. Password managers that mark their copies as concealed are ignored automatically.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                List(selection: $selection) {
                    ForEach(excludedApps, id: \.self) { bundleID in
                        HStack {
                            if let icon = SourceAppResolver.icon(forBundleID: bundleID) {
                                Image(nsImage: icon)
                                    .resizable()
                                    .frame(width: 20, height: 20)
                            }
                            Text(SourceAppResolver.displayName(forBundleID: bundleID) ?? bundleID)
                            Spacer()
                            Text(bundleID)
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        .tag(bundleID)
                    }
                }
                .frame(minHeight: 120)

                HStack {
                    Button("Add App…") { addApp() }
                    Button("Remove") { removeSelected() }
                        .disabled(selection == nil)
                }
            }
        }
        .formStyle(.grouped)
        .padding(.vertical, 8)
        .onReceive(NotificationCenter.default.publisher(
            for: NSApplication.didBecomeActiveNotification
        )) { _ in
            accessibilityGranted = AccessibilityPermission.isTrusted
        }
    }

    private func addApp() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowsMultipleSelection = true
        guard panel.runModal() == .OK else { return }
        for url in panel.urls {
            if let bundleID = Bundle(url: url)?.bundleIdentifier,
               !excludedApps.contains(bundleID) {
                excludedApps.append(bundleID)
            }
        }
        Defaults.excludedApps = excludedApps
    }

    private func removeSelected() {
        guard let selection else { return }
        excludedApps.removeAll { $0 == selection }
        Defaults.excludedApps = excludedApps
        self.selection = nil
    }
}
