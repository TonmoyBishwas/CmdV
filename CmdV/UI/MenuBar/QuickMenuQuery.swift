import Foundation
import SwiftData

/// Fetches what the menu bar quick copy list shows. Separated from the
/// controller so the relationship predicate is unit-testable against an
/// in-memory store.
enum QuickMenuQuery {
    static func items(in context: ModelContext, pinned: Bool, limit: Int) -> [ClipItem] {
        guard limit > 0 else { return [] }
        var descriptor = FetchDescriptor<ClipItem>(
            predicate: pinned
                ? #Predicate { $0.pinboard != nil }
                : #Predicate { $0.pinboard == nil },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return (try? context.fetch(descriptor)) ?? []
    }
}
