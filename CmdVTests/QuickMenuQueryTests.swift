import Foundation
import SwiftData
import Testing
@testable import CmdV

@Suite("QuickMenuQuery")
@MainActor
struct QuickMenuQueryTests {
    // Tests must hold the container itself: mainContext does not keep its
    // container alive, and using a context after the container deallocates
    // crashes inside SwiftData.
    private func makeContainer() throws -> ModelContainer {
        try StoreFactory.makeContainer(inMemory: true)
    }

    private func insertItems(into context: ModelContext) throws -> Pinboard {
        let board = Pinboard(name: "Keep", colorHex: "#0090ff", sortOrder: 0)
        context.insert(board)
        for index in 0..<6 {
            let item = ClipItem(
                createdAt: Date(timeIntervalSinceNow: TimeInterval(-index)),
                kind: .text,
                plainText: "recent \(index)",
                contentHash: "r\(index)"
            )
            context.insert(item)
        }
        for index in 0..<3 {
            let item = ClipItem(
                createdAt: Date(timeIntervalSinceNow: TimeInterval(-100 - index)),
                kind: .text,
                plainText: "pinned \(index)",
                contentHash: "p\(index)"
            )
            // Relationships may only be set between already-inserted models;
            // assigning before insert crashes inside SwiftData.
            context.insert(item)
            item.pinboard = board
        }
        try context.save()
        return board
    }

    @Test func splitsPinnedFromRecent() throws {
        let container = try makeContainer()
        let context = container.mainContext
        _ = try insertItems(into: context)

        let pinned = QuickMenuQuery.items(in: context, pinned: true, limit: 10)
        let recent = QuickMenuQuery.items(in: context, pinned: false, limit: 10)

        #expect(pinned.count == 3)
        #expect(pinned.allSatisfy { $0.pinboard != nil })
        #expect(recent.count == 6)
        #expect(recent.allSatisfy { $0.pinboard == nil })
    }

    @Test func respectsLimitAndNewestFirst() throws {
        let container = try makeContainer()
        let context = container.mainContext
        _ = try insertItems(into: context)

        let recent = QuickMenuQuery.items(in: context, pinned: false, limit: 2)

        #expect(recent.count == 2)
        #expect(recent[0].plainText == "recent 0")
        #expect(recent[1].plainText == "recent 1")
    }

    @Test func zeroLimitReturnsNothing() throws {
        let container = try makeContainer()
        let context = container.mainContext
        _ = try insertItems(into: context)

        #expect(QuickMenuQuery.items(in: context, pinned: true, limit: 0).isEmpty)
        #expect(QuickMenuQuery.items(in: context, pinned: false, limit: 0).isEmpty)
    }
}
