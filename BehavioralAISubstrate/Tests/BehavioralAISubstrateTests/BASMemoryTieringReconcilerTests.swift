import XCTest
@testable import BASMemory

final class BASMemoryTieringReconcilerTests: XCTestCase {
    // MARK: - Helpers

    private func profile(
        id: String,
        tier: BASMemoryTier,
        recency: Double = 0.5,
        frequency: Double = 0.5,
        sensitivity: Double = 0.0,
        staleness: Double = 0.0
    ) -> BASMemoryTieringProfile {
        BASMemoryTieringProfile(
            atomID: id,
            currentTier: tier,
            recencyScore: recency,
            accessFrequency: frequency,
            sensitivityDrift: sensitivity,
            worldContextStaleness: staleness,
            observedAt: Date(timeIntervalSince1970: 0))
    }

    private func makeReconciler(
        at timestamp: TimeInterval = 1_000
    ) -> (BASMemoryTieringReconciler, BASMemoryTierTransitionLog) {
        let log = BASMemoryTierTransitionLog(capacity: 64)
        let reconciler = BASMemoryTieringReconciler(
            log: log,
            clock: { Date(timeIntervalSince1970: timestamp) })
        return (reconciler, log)
    }

    // MARK: - Empty batch

    func testEmptyBatchReturnsNoOpOutcome() async {
        let (reconciler, log) = makeReconciler()
        let outcome = await reconciler.reconcile(profiles: [])
        XCTAssertEqual(outcome.evaluatedCount, 0)
        XCTAssertEqual(outcome.mutationCount, 0)
        XCTAssertTrue(outcome.isNoOp)
        XCTAssertTrue(outcome.decisions.isEmpty)
        let count = await log.count()
        XCTAssertEqual(count, 0)
    }

    // MARK: - Counters

    func testCountersMatchPerBranchDecisions() async {
        let (reconciler, _) = makeReconciler()
        let outcome = await reconciler.reconcile(profiles: [
            profile(id: "hold", tier: .warm,
                    recency: 0.5, frequency: 0.5),         // hold
            profile(id: "promote-cold", tier: .cold,
                    recency: 0.8, frequency: 0.3),         // promote
            profile(id: "demote-hot", tier: .hot,
                    recency: 0.1, frequency: 0.1),         // demote
            profile(id: "quarantine-sens", tier: .warm,
                    recency: 1.0, frequency: 1.0,
                    sensitivity: 0.9),                     // quarantine
            profile(id: "evict-cold", tier: .cold,
                    recency: 0.0, frequency: 0.0)          // evict
        ])

        XCTAssertEqual(outcome.evaluatedCount, 5)
        XCTAssertEqual(outcome.heldCount, 1)
        XCTAssertEqual(outcome.promotedCount, 1)
        XCTAssertEqual(outcome.demotedCount, 1)
        XCTAssertEqual(outcome.quarantineSuggestedCount, 1)
        XCTAssertEqual(outcome.evictSuggestedCount, 1)
        XCTAssertEqual(outcome.mutationCount, 4)
        XCTAssertFalse(outcome.isNoOp)
    }

    // MARK: - Logging

    func testReconcilerLogsEveryDecisionExactlyOnce() async {
        let (reconciler, log) = makeReconciler()
        _ = await reconciler.reconcile(profiles: [
            profile(id: "a", tier: .warm),
            profile(id: "b", tier: .cold, recency: 0.0, frequency: 0.0),
            profile(id: "c", tier: .warm, sensitivity: 0.95)
        ])
        let snapshot = await log.snapshot()
        XCTAssertEqual(snapshot.count, 3)
        XCTAssertEqual(
            snapshot.map { $0.profile.atomID }, ["a", "b", "c"])
    }

    // MARK: - Ordering: insertion

    func testInsertionOrderingPreservesInputOrder() async {
        let (reconciler, _) = makeReconciler()
        let profiles = (0..<5).map {
            profile(id: "id-\($0)", tier: .warm)
        }
        let outcome = await reconciler.reconcile(
            profiles: profiles, ordering: .insertionOrder)
        XCTAssertEqual(
            outcome.decisions.map { $0.profile.atomID },
            profiles.map { $0.atomID })
    }

    // MARK: - Ordering: highest heat first

    func testHighestHeatFirstSortsHottestToFront() {
        let inputs = [
            BASMemoryTieringProfile(
                atomID: "cool",
                currentTier: .warm,
                recencyScore: 0.2,
                accessFrequency: 0.2,
                sensitivityDrift: 0.0,
                worldContextStaleness: 0.0,
                observedAt: Date()),
            BASMemoryTieringProfile(
                atomID: "hot",
                currentTier: .warm,
                recencyScore: 1.0,
                accessFrequency: 1.0,
                sensitivityDrift: 0.0,
                worldContextStaleness: 0.0,
                observedAt: Date()),
            BASMemoryTieringProfile(
                atomID: "mid",
                currentTier: .warm,
                recencyScore: 0.6,
                accessFrequency: 0.6,
                sensitivityDrift: 0.0,
                worldContextStaleness: 0.0,
                observedAt: Date())
        ]
        let reordered = BASMemoryTieringReconciler.reorder(
            inputs, by: .highestHeatFirst)
        XCTAssertEqual(
            reordered.map { $0.atomID },
            ["hot", "mid", "cool"])
    }

    // MARK: - Ordering: most risky first

    func testMostRiskyFirstSortsBySensitivityAndStaleness() {
        let inputs = [
            BASMemoryTieringProfile(
                atomID: "clean",
                currentTier: .warm,
                recencyScore: 1.0,
                accessFrequency: 1.0,
                sensitivityDrift: 0.0,
                worldContextStaleness: 0.0,
                observedAt: Date()),
            BASMemoryTieringProfile(
                atomID: "stale",
                currentTier: .warm,
                recencyScore: 0.1,
                accessFrequency: 0.1,
                sensitivityDrift: 0.0,
                worldContextStaleness: 0.8,
                observedAt: Date()),
            BASMemoryTieringProfile(
                atomID: "sensitive",
                currentTier: .warm,
                recencyScore: 0.1,
                accessFrequency: 0.1,
                sensitivityDrift: 0.95,
                worldContextStaleness: 0.1,
                observedAt: Date())
        ]
        let reordered = BASMemoryTieringReconciler.reorder(
            inputs, by: .mostRiskyFirst)
        XCTAssertEqual(
            reordered.map { $0.atomID },
            ["sensitive", "stale", "clean"])
    }

    // MARK: - Outcome timing

    func testOutcomeCarriesStartAndCompletionTimes() async {
        let clockBox = _ClockBox(
            stampedAt: Date(timeIntervalSince1970: 100))
        let log = BASMemoryTierTransitionLog(capacity: 16)
        let reconciler = BASMemoryTieringReconciler(
            log: log,
            clock: { clockBox.now() })

        // Seed the clock so startedAt < completedAt.
        let outcome = await reconciler.reconcile(profiles: [
            profile(id: "t", tier: .warm)
        ])
        XCTAssertLessThanOrEqual(
            outcome.startedAt, outcome.completedAt)
    }

    // MARK: - isNoOp semantics

    func testAllHoldBatchIsNoOp() async {
        let (reconciler, _) = makeReconciler()
        let outcome = await reconciler.reconcile(profiles: [
            profile(id: "a", tier: .warm),
            profile(id: "b", tier: .warm, recency: 0.4, frequency: 0.4)
        ])
        XCTAssertTrue(outcome.isNoOp)
        XCTAssertEqual(outcome.mutationCount, 0)
        XCTAssertEqual(outcome.heldCount, 2)
    }

    // MARK: - Policy parity

    func testReconcilerDecisionsMatchStandalonePolicy() async {
        let profiles = [
            profile(id: "a", tier: .warm, recency: 0.5, frequency: 0.5),
            profile(id: "b", tier: .cold, recency: 0.0, frequency: 0.0),
            profile(id: "c", tier: .hot, recency: 0.1, frequency: 0.1),
            profile(id: "d", tier: .warm, sensitivity: 0.9)
        ]
        let expected = profiles.map {
            BASMemoryTemperaturePolicy.recommendTransition(for: $0)
        }

        let (reconciler, _) = makeReconciler()
        let outcome = await reconciler.reconcile(
            profiles: profiles, ordering: .insertionOrder)
        XCTAssertEqual(
            outcome.decisions.map { $0.transition }, expected)
    }
}

// MARK: - Test clock

/// A trivial monotonically-advancing clock used only in
/// `testOutcomeCarriesStartAndCompletionTimes`. Captures the first
/// call time and returns an incrementing `Date` on each call so
/// `startedAt <= completedAt` is true under the current-Date clock.
private final class _ClockBox: @unchecked Sendable {
    private var counter: Double = 0
    private let base: Date

    init(stampedAt: Date) { self.base = stampedAt }

    func now() -> Date {
        defer { counter += 1 }
        return base.addingTimeInterval(counter)
    }
}
