import Foundation
import Observation

/// UI state for the shelf, shared between the SwiftUI views and the
/// panel controller's key-event routing.
@MainActor
@Observable
final class ShelfViewModel {
    var searchText = ""
    var kindFilter: ClipKind?
    /// Selected pinboard (nil = main history).
    var pinboardUUID: UUID?
    var selectedUUID: UUID?
    /// UUIDs currently visible in filtered order — kept in sync by the view
    /// so keyboard navigation knows the ordering.
    var visibleUUIDs: [UUID] = []
    /// Multi-select set (⌘-click / ⇧-click).
    var multiSelection: Set<UUID> = []
    /// Requests focus of the search field (⌘F).
    var searchFocusRequested = false
    /// Item being renamed (⌘R) / edited (⌘E), if any.
    var renamingUUID: UUID?
    var editingUUID: UUID?

    func reset() {
        searchText = ""
        kindFilter = nil
        selectedUUID = nil
        multiSelection = []
        renamingUUID = nil
        editingUUID = nil
    }

    private var selectedIndex: Int? {
        selectedUUID.flatMap { visibleUUIDs.firstIndex(of: $0) }
    }

    func selectFirst() {
        selectedUUID = visibleUUIDs.first
    }

    func selectNext() {
        guard !visibleUUIDs.isEmpty else { return }
        if let index = selectedIndex, index + 1 < visibleUUIDs.count {
            selectedUUID = visibleUUIDs[index + 1]
        } else if selectedIndex == nil {
            selectFirst()
        }
    }

    func selectPrevious() {
        guard !visibleUUIDs.isEmpty else { return }
        if let index = selectedIndex, index > 0 {
            selectedUUID = visibleUUIDs[index - 1]
        } else if selectedIndex == nil {
            selectFirst()
        }
    }

    /// Keep selection valid when the visible list changes (search, deletes).
    func visibleListChanged() {
        if let selected = selectedUUID, !visibleUUIDs.contains(selected) {
            selectedUUID = visibleUUIDs.first
        }
        multiSelection = multiSelection.filter { visibleUUIDs.contains($0) }
    }
}
