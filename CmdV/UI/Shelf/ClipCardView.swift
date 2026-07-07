import SwiftUI
import UniformTypeIdentifiers

/// One clipboard item card: header (icon, title, time), body (preview),
/// footer (metadata), numbered quick-paste badge.
struct ClipCardView: View {
    let item: ClipItem
    let quickPasteNumber: Int?
    let isSelected: Bool
    @Bindable var model: ShelfViewModel
    let appState: AppState

    @State private var renameText = ""
    @State private var editText = ""

    private var isRenaming: Bool { model.renamingUUID == item.uuid }
    private var isEditing: Bool { model.editingUUID == item.uuid }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            cardHeader
            cardBody
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            cardFooter
        }
        .padding(12)
        .frame(width: 230)
        .frame(maxHeight: .infinity)
        .background(.regularMaterial, in: .rect(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.separator.opacity(0.5)),
                    lineWidth: isSelected ? 2.5 : 1
                )
        }
        .overlay(alignment: .topTrailing) {
            if let number = quickPasteNumber {
                Text("⌘\(number)")
                    .font(.caption2.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(.quaternary.opacity(0.7), in: .capsule)
                    .padding(6)
            }
        }
        .contentShape(.rect(cornerRadius: 16))
        .onTapGesture(count: 2) {
            appState.pasteItem(uuid: item.uuid, plainTextOnly: false)
        }
        .onTapGesture {
            handleSingleClick()
        }
        .draggable(DraggableClip(item: item))
        .contextMenu { contextMenuItems }
    }

    private func handleSingleClick() {
        if NSEvent.modifierFlags.contains(.command) {
            if model.multiSelection.contains(item.uuid) {
                model.multiSelection.remove(item.uuid)
            } else {
                model.multiSelection.insert(item.uuid)
                if let selected = model.selectedUUID {
                    model.multiSelection.insert(selected)
                }
            }
        } else if NSEvent.modifierFlags.contains(.shift),
                  let anchor = model.selectedUUID,
                  let from = model.visibleUUIDs.firstIndex(of: anchor),
                  let to = model.visibleUUIDs.firstIndex(of: item.uuid) {
            let range = min(from, to)...max(from, to)
            model.multiSelection = Set(model.visibleUUIDs[range])
        } else {
            model.multiSelection = []
            model.selectedUUID = item.uuid
        }
    }

    // MARK: - Header

    private var cardHeader: some View {
        HStack(spacing: 6) {
            if let icon = SourceAppResolver.icon(forBundleID: item.sourceAppBundleID) {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 18, height: 18)
            } else {
                Image(systemName: item.kind.symbolName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if isRenaming {
                TextField("Title", text: $renameText)
                    .textFieldStyle(.roundedBorder)
                    .font(.caption)
                    .onAppear { renameText = item.title ?? "" }
                    .onSubmit {
                        appState.renameItem(uuid: item.uuid, title: renameText)
                        model.renamingUUID = nil
                    }
            } else {
                Text(item.displayTitle)
                    .font(.caption.weight(.medium))
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            Text(item.createdAt, format: .relative(presentation: .named))
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
        }
    }

    // MARK: - Body

    @ViewBuilder
    private var cardBody: some View {
        if isEditing {
            TextEditor(text: $editText)
                .font(.callout)
                .scrollContentBackground(.hidden)
                .background(.quaternary.opacity(0.3), in: .rect(cornerRadius: 8))
                .onAppear { editText = item.plainText ?? "" }
                .onDisappear {
                    if editText != (item.plainText ?? "") {
                        appState.updateItemText(uuid: item.uuid, text: editText)
                    }
                }
        } else {
            CardPreview(item: item)
        }
    }

    // MARK: - Footer

    private var cardFooter: some View {
        HStack {
            Text(footerText)
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
            Spacer(minLength: 0)
            if item.pinboard != nil {
                Image(systemName: "pin.fill")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var footerText: String {
        switch item.kind {
        case .image:
            if item.pixelWidth > 0 {
                return "\(item.pixelWidth) × \(item.pixelHeight)"
            }
            return "Image"
        case .file:
            let count = item.fileURLPaths.count
            return count == 1
                ? (item.fileURLPaths.first.map { URL(fileURLWithPath: $0).lastPathComponent } ?? "File")
                : "\(count) files"
        case .link:
            return URL(string: item.plainText ?? "")?.host() ?? "Link"
        default:
            let chars = item.charCount
            let words = item.plainText?.split(whereSeparator: \.isWhitespace).count ?? 0
            return "\(chars) characters · \(words) words"
        }
    }

    // MARK: - Context menu

    @ViewBuilder
    private var contextMenuItems: some View {
        Button("Paste") {
            appState.pasteItem(uuid: item.uuid, plainTextOnly: false)
        }
        Button("Paste as Plain Text") {
            appState.pasteItem(uuid: item.uuid, plainTextOnly: true)
        }
        Button("Copy") {
            appState.copyItem(uuid: item.uuid)
        }
        Divider()
        PinboardMenu(item: item, appState: appState)
        Button("Rename…") {
            model.renamingUUID = item.uuid
        }
        if item.kind == .text || item.kind == .code || item.kind == .link {
            Button("Edit…") {
                model.editingUUID = item.uuid
            }
        }
        Divider()
        Button("Quick Look") {
            model.selectedUUID = item.uuid
            appState.quickLookSelected()
        }
        Divider()
        Button("Delete", role: .destructive) {
            appState.deleteItem(uuid: item.uuid)
        }
    }
}

/// Submenu listing pinboards to pin/unpin the item.
struct PinboardMenu: View {
    let item: ClipItem
    let appState: AppState
    @Query(sort: \Pinboard.sortOrder) private var pinboards: [Pinboard]

    var body: some View {
        Menu("Pin to") {
            ForEach(pinboards) { board in
                Button {
                    appState.pinItem(uuid: item.uuid, pinboardUUID: board.uuid)
                } label: {
                    if item.pinboard?.uuid == board.uuid {
                        Label(board.name, systemImage: "checkmark")
                    } else {
                        Text(board.name)
                    }
                }
            }
            if item.pinboard != nil {
                Divider()
                Button("Unpin") {
                    appState.pinItem(uuid: item.uuid, pinboardUUID: nil)
                }
            }
            Divider()
            Button("New Pinboard…") {
                appState.createPinboardRequested(pinning: item.uuid)
            }
        }
    }
}

/// Transferable payload for dragging cards out into other apps.
struct DraggableClip: Transferable {
    let text: String

    init(item: ClipItem) {
        self.text = item.plainText ?? ""
    }

    static var transferRepresentation: some TransferRepresentation {
        ProxyRepresentation(exporting: \.text)
    }
}

import SwiftData

extension ClipItem {
    var displayTitle: String {
        if let title, !title.isEmpty { return title }
        switch kind {
        case .image: return "Image"
        case .file: return fileURLPaths.count == 1 ? "File" : "Files"
        case .link: return "Link"
        case .color: return "Color"
        case .code: return "Code"
        case .text: return "Text"
        }
    }
}
