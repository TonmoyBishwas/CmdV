import KeyboardShortcuts
import SwiftUI

struct ShortcutsSettings: View {
    var body: some View {
        Form {
            Section {
                KeyboardShortcuts.Recorder("Open CmdV:", name: .openShelf)
                KeyboardShortcuts.Recorder("Start Paste Stack:", name: .pasteStack)
            }
            Section {
                Text("""
                Inside the shelf: ← → to browse · Return to paste · ⇧Return pastes as \
                plain text · ⌘1–⌘9 for quick paste · Space for Quick Look · ⌘F to search · \
                ⌘R rename · ⌘E edit · ⌘N new item · ⇧⌘N new pinboard · Delete removes an item.
                """)
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding(.vertical, 8)
    }
}
