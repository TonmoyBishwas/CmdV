import Foundation
import Testing
@testable import CmdV

struct RetentionPolicyTests {
    private func candidate(daysOld: Double, pinned: Bool = false, now: Date) -> RetentionPolicy.Candidate {
        RetentionPolicy.Candidate(
            uuid: UUID(),
            createdAt: now.addingTimeInterval(-daysOld * 86_400),
            isPinned: pinned
        )
    }

    @Test func oldItemsArePruned() {
        let now = Date()
        let fresh = candidate(daysOld: 1, now: now)
        let stale = candidate(daysOld: 40, now: now)
        let policy = RetentionPolicy(maxAgeDays: 30, maxItems: nil)
        let doomed = policy.itemsToPrune(from: [fresh, stale], now: now)
        #expect(doomed == [stale.uuid])
    }

    @Test func pinnedItemsSurviveAgePruning() {
        let now = Date()
        let pinnedStale = candidate(daysOld: 400, pinned: true, now: now)
        let policy = RetentionPolicy(maxAgeDays: 30, maxItems: nil)
        #expect(policy.itemsToPrune(from: [pinnedStale], now: now).isEmpty)
    }

    @Test func countCapKeepsNewest() {
        let now = Date()
        let items = (0..<10).map { candidate(daysOld: Double($0), now: now) }
        let policy = RetentionPolicy(maxAgeDays: nil, maxItems: 3)
        let doomed = policy.itemsToPrune(from: items, now: now)
        #expect(doomed.count == 7)
        // The three newest (0, 1, 2 days old) survive.
        for survivor in items.prefix(3) {
            #expect(!doomed.contains(survivor.uuid))
        }
    }

    @Test func pinnedItemsDoNotCountTowardCap() {
        let now = Date()
        let pinned = (0..<5).map { candidate(daysOld: Double($0), pinned: true, now: now) }
        let unpinned = (0..<3).map { candidate(daysOld: Double($0), now: now) }
        let policy = RetentionPolicy(maxAgeDays: nil, maxItems: 3)
        #expect(policy.itemsToPrune(from: pinned + unpinned, now: now).isEmpty)
    }

    @Test func disabledPolicyPrunesNothing() {
        let now = Date()
        let items = (0..<5).map { candidate(daysOld: Double($0 * 100), now: now) }
        let policy = RetentionPolicy(maxAgeDays: nil, maxItems: nil)
        #expect(policy.itemsToPrune(from: items, now: now).isEmpty)
        let zeroPolicy = RetentionPolicy(maxAgeDays: 0, maxItems: 0)
        #expect(zeroPolicy.itemsToPrune(from: items, now: now).isEmpty)
    }

    @Test func ageAndCountCompose() {
        let now = Date()
        let stale = candidate(daysOld: 50, now: now)
        let mid = (0..<5).map { candidate(daysOld: Double($0 + 2), now: now) }
        let policy = RetentionPolicy(maxAgeDays: 30, maxItems: 2)
        let doomed = policy.itemsToPrune(from: [stale] + mid, now: now)
        // stale dies to age; 3 of the 5 mid items die to the cap.
        #expect(doomed.count == 4)
        #expect(doomed.contains(stale.uuid))
    }
}
