import Foundation

/// Decides which history items to prune. Pure logic — unit-testable.
/// Pinned items (on any pinboard) are always exempt.
struct RetentionPolicy: Sendable {
    /// Delete items older than this many days. nil/<=0 = keep forever.
    var maxAgeDays: Int?
    /// Keep at most this many unpinned items. nil/<=0 = unlimited.
    var maxItems: Int?

    struct Candidate: Sendable {
        var uuid: UUID
        var createdAt: Date
        var isPinned: Bool
    }

    /// Returns the UUIDs that should be deleted.
    func itemsToPrune(from items: [Candidate], now: Date = Date()) -> Set<UUID> {
        var doomed: Set<UUID> = []
        let unpinned = items.filter { !$0.isPinned }

        if let days = maxAgeDays, days > 0 {
            let cutoff = now.addingTimeInterval(-TimeInterval(days) * 86_400)
            for item in unpinned where item.createdAt < cutoff {
                doomed.insert(item.uuid)
            }
        }

        if let cap = maxItems, cap > 0 {
            let survivors = unpinned
                .filter { !doomed.contains($0.uuid) }
                .sorted { $0.createdAt > $1.createdAt }
            if survivors.count > cap {
                for item in survivors[cap...] {
                    doomed.insert(item.uuid)
                }
            }
        }

        return doomed
    }
}
