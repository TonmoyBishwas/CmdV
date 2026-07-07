import SwiftData
import SwiftUI

/// The shelf: search + filters on top, horizontally scrolling glass cards below.
struct ShelfRootView: View {
    @Bindable var model: ShelfViewModel
    let appState: AppState

    @Query(sort: \ClipItem.createdAt, order: .reverse) private var items: [ClipItem]
    @Query(sort: \Pinboard.sortOrder) private var pinboards: [Pinboard]
    @FocusState private var searchFocused: Bool

    private var filtered: [ClipItem] {
        items.filter { item in
            if let boardUUID = model.pinboardUUID {
                guard item.pinboard?.uuid == boardUUID else { return false }
            } else {
                guard item.pinboard == nil else { return false }
            }
            if let kind = model.kindFilter, item.kind != kind { return false }
            if !model.searchText.isEmpty {
                return item.matches(query: model.searchText)
            }
            return true
        }
    }

    var body: some View {
        VStack(spacing: 10) {
            header
            cardStrip
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .glassEffect(.regular, in: .rect(cornerRadius: 26))
        .onAppear {
            searchFocused = true
            syncVisible()
        }
        .onChange(of: filtered.map(\.uuid)) { _, uuids in
            model.visibleUUIDs = uuids
            model.visibleListChanged()
        }
        .onChange(of: model.searchFocusRequested) { _, requested in
            if requested {
                searchFocused = true
                model.searchFocusRequested = false
            }
        }
    }

    private func syncVisible() {
        model.visibleUUIDs = filtered.map(\.uuid)
        model.visibleListChanged()
    }

    // MARK: - Header (search + filter chips + pinboards)

    private var header: some View {
        HStack(spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search clipboard history…", text: $model.searchText)
                    .textFieldStyle(.plain)
                    .focused($searchFocused)
                    .frame(maxWidth: 260)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.quaternary.opacity(0.5), in: .capsule)

            filterChips

            Spacer()

            pinboardChips
        }
    }

    private var filterChips: some View {
        HStack(spacing: 4) {
            chip(label: "All", isOn: model.kindFilter == nil) {
                model.kindFilter = nil
            }
            ForEach(ClipKind.allCases, id: \.self) { kind in
                chip(label: kind.displayName, isOn: model.kindFilter == kind) {
                    model.kindFilter = model.kindFilter == kind ? nil : kind
                }
            }
        }
    }

    private var pinboardChips: some View {
        HStack(spacing: 4) {
            chip(label: "History", isOn: model.pinboardUUID == nil) {
                model.pinboardUUID = nil
            }
            ForEach(pinboards) { board in
                chip(
                    label: board.name,
                    isOn: model.pinboardUUID == board.uuid,
                    dotColor: Color(hexString: board.colorHex)
                ) {
                    model.pinboardUUID = model.pinboardUUID == board.uuid ? nil : board.uuid
                }
                .contextMenu {
                    Button("Delete Pinboard") {
                        appState.deletePinboard(uuid: board.uuid)
                    }
                }
            }
            Button {
                appState.createPinboardRequested()
            } label: {
                Image(systemName: "plus")
            }
            .buttonStyle(.plain)
            .padding(6)
            .help("New Pinboard (⇧⌘N)")
        }
    }

    private func chip(
        label: String,
        isOn: Bool,
        dotColor: Color? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let dotColor {
                    Circle().fill(dotColor).frame(width: 7, height: 7)
                }
                Text(label)
                    .font(.callout)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(isOn ? AnyShapeStyle(.tint.opacity(0.35)) : AnyShapeStyle(.quaternary.opacity(0.4)), in: .capsule)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Card strip

    private var cardStrip: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    if filtered.isEmpty {
                        emptyState
                    }
                    ForEach(Array(filtered.enumerated()), id: \.element.uuid) { index, item in
                        ClipCardView(
                            item: item,
                            quickPasteNumber: index < 9 ? index + 1 : nil,
                            isSelected: model.selectedUUID == item.uuid
                                || model.multiSelection.contains(item.uuid),
                            model: model,
                            appState: appState
                        )
                        .id(item.uuid)
                    }
                }
                .padding(.horizontal, 2)
                .padding(.bottom, 4)
            }
            .onChange(of: model.selectedUUID) { _, uuid in
                if let uuid {
                    withAnimation(.easeOut(duration: 0.15)) {
                        proxy.scrollTo(uuid, anchor: nil)
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "clipboard")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            Text(model.searchText.isEmpty ? "Nothing here yet — copy something!" : "No matches")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }
}

extension ClipKind {
    var displayName: String {
        switch self {
        case .text: "Text"
        case .link: "Links"
        case .image: "Images"
        case .file: "Files"
        case .color: "Colors"
        case .code: "Code"
        }
    }

    var symbolName: String {
        switch self {
        case .text: "text.alignleft"
        case .link: "link"
        case .image: "photo"
        case .file: "doc"
        case .color: "paintpalette"
        case .code: "chevron.left.forwardslash.chevron.right"
        }
    }
}

extension ClipItem {
    /// Search across title, content, OCR text, and source app.
    func matches(query: String) -> Bool {
        let q = query.lowercased()
        if let title, title.lowercased().contains(q) { return true }
        if let plainText, plainText.lowercased().contains(q) { return true }
        if let ocrText, ocrText.lowercased().contains(q) { return true }
        if let source = sourceAppBundleID, source.lowercased().contains(q) { return true }
        if fileURLPaths.contains(where: { $0.lowercased().contains(q) }) { return true }
        return false
    }
}
