import XCTest
@testable import BASMemory

/// M215 — coverage for `BASMemoryMutationWriter` applying
/// reconciler decisions to a store.
///
/// Five transition types map to four store ops:
///
///   .hold              → store unchanged (skipped)
///   .promote / .demote → store.updateTier
///   .quarantineSuggest → store.updateGovernanceStatus(.quarantined)
///   .evictSuggest      → store.remove
///
/// Each test sets up the store with known atoms, builds a
/// reconciler outcome with a single decision targeting one of
/// those atoms (or a missing one), runs apply, asserts both the
/// store mutation and the outcome's count.
final class BASMemoryMutationWriterTests: XCTestCase {

    // MARK: - Fixtures

    private func makeAtom(
        id: UUID = UUID(),
        tier: BASMemoryTier = .warm,
        governanceStatus: BASMemoryGovernanceStatus = .governed
    ) -> BASGovernedMemory {
        BASGovernedMemory(
            id: id,
            kind: .episodic,
            content: "test atom",
            scope: .session,
            sensitivity: .low,
            tier: tier,
            confidence: 0.7,
            sourceType: "test",
            governanceStatus: governanceStatus,
            provenanceSummary: "test")
    }

    private func makeOutcome(
        decisions: [BASMemoryTieringReconciliationOutcome.Decision]
    ) -> BASMemoryTieringReconciliationOutcome {
        var heldCount = 0
        var promotedCount = 0
        var demotedCount = 0
        var quarantineCount = 0
        var evictCount = 0
        for d in decisions {
            switch d.transition {
            case .hold: heldCount += 1
            case .promote: promotedCount += 1
            case .demote: demotedCount += 1
            case .quarantineSuggest: quarantineCount += 1
            case .evictSuggest: evictCount += 1
            }
        }
        let now = Date()
        return BASMemoryTieringReconciliationOutcome(
            evaluatedCount: decisions.count,
            heldCount: heldCount,
            promotedCount: promotedCount,
            demotedCount: demotedCount,
            quarantineSuggestedCount: quarantineCount,
            evictSuggestedCount: evictCount,
            decisions: decisions,
            startedAt: now,
            completedAt: now)
    }

    private func makeProfile(
        atomID: String,
        currentTier: BASMemoryTier = .warm
    ) -> BASMemoryTieringProfile {
        BASMemoryTieringProfile(
            atomID: atomID,
            currentTier: currentTier,
            recencyScore: 0.5,
            accessFrequency: 0.5,
            sensitivityDrift: 0,
            worldContextStaleness: 0,
            observedAt: Date())
    }

    // MARK: - 1. .hold → skipped, store unchanged

    func testHoldDecisionLeavesStoreUnchanged() async throws {
        let atom = makeAtom(tier: .warm)
        let store = BASInMemoryMemoryAtomStore(initial: [atom])
        let writer = BASMemoryMutationWriter(store: store)

        let decision = BASMemoryTieringReconciliationOutcome
            .Decision(
                profile: makeProfile(atomID: atom.id.uuidString),
                transition: .hold(
                    tier: .warm,
                    reason: .withinThresholds))
        let outcome = await writer.apply(
            outcome: makeOutcome(decisions: [decision]))

        XCTAssertEqual(outcome.evaluated, 1)
        XCTAssertEqual(outcome.applied, 0)
        XCTAssertEqual(outcome.skipped, 1)
        XCTAssertEqual(outcome.notFound, 0)

        // Store unchanged.
        let after = await store.atom(forID: atom.id.uuidString)
        XCTAssertEqual(after?.tier, .warm)
    }

    // MARK: - 2. .promote → tier updated

    func testPromoteDecisionUpdatesTier() async throws {
        let atom = makeAtom(tier: .warm)
        let store = BASInMemoryMemoryAtomStore(initial: [atom])
        let writer = BASMemoryMutationWriter(store: store)

        let decision = BASMemoryTieringReconciliationOutcome
            .Decision(
                profile: makeProfile(atomID: atom.id.uuidString),
                transition: .promote(
                    from: .warm,
                    to: .hot,
                    reason: .compositeHeatAboveUpperBand))
        let outcome = await writer.apply(
            outcome: makeOutcome(decisions: [decision]))

        XCTAssertEqual(outcome.applied, 1)
        XCTAssertEqual(outcome.notFound, 0)
        let after = await store.atom(forID: atom.id.uuidString)
        XCTAssertEqual(
            after?.tier, .hot,
            "atom must be promoted from .warm to .hot")
    }

    // MARK: - 3. .demote → tier updated

    func testDemoteDecisionUpdatesTier() async throws {
        let atom = makeAtom(tier: .warm)
        let store = BASInMemoryMemoryAtomStore(initial: [atom])
        let writer = BASMemoryMutationWriter(store: store)

        let decision = BASMemoryTieringReconciliationOutcome
            .Decision(
                profile: makeProfile(atomID: atom.id.uuidString),
                transition: .demote(
                    from: .warm,
                    to: .cold,
                    reason: .compositeHeatBelowLowerBand))
        let outcome = await writer.apply(
            outcome: makeOutcome(decisions: [decision]))

        XCTAssertEqual(outcome.applied, 1)
        let after = await store.atom(forID: atom.id.uuidString)
        XCTAssertEqual(
            after?.tier, .cold,
            "atom must be demoted from .warm to .cold")
    }

    // MARK: - 4. .quarantineSuggest → governanceStatus updated

    func testQuarantineDecisionUpdatesGovernanceStatus()
        async throws
    {
        let atom = makeAtom(governanceStatus: .governed)
        let store = BASInMemoryMemoryAtomStore(initial: [atom])
        let writer = BASMemoryMutationWriter(store: store)

        let decision = BASMemoryTieringReconciliationOutcome
            .Decision(
                profile: makeProfile(atomID: atom.id.uuidString),
                transition: .quarantineSuggest(
                    from: .warm,
                    reason: .sensitivityEscalated))
        let outcome = await writer.apply(
            outcome: makeOutcome(decisions: [decision]))

        XCTAssertEqual(outcome.applied, 1)
        let after = await store.atom(forID: atom.id.uuidString)
        XCTAssertEqual(
            after?.governanceStatus, .quarantined,
            "quarantine suggestion must flip status to " +
            ".quarantined; got " +
            "\(String(describing: after?.governanceStatus))")
    }

    // MARK: - 5. .evictSuggest → atom removed

    func testEvictDecisionRemovesAtom() async throws {
        let atom = makeAtom(tier: .cold)
        let store = BASInMemoryMemoryAtomStore(initial: [atom])
        let writer = BASMemoryMutationWriter(store: store)

        let decision = BASMemoryTieringReconciliationOutcome
            .Decision(
                profile: makeProfile(atomID: atom.id.uuidString),
                transition: .evictSuggest(
                    from: .cold,
                    reason: .coldStaleUnused))
        let outcome = await writer.apply(
            outcome: makeOutcome(decisions: [decision]))

        XCTAssertEqual(outcome.applied, 1)
        let after = await store.atom(forID: atom.id.uuidString)
        XCTAssertNil(
            after,
            "evict suggestion must remove the atom from the store")
    }

    // MARK: - 6. Missing atom → notFound, no store change

    func testDecisionTargetingMissingAtomCountsAsNotFound()
        async throws
    {
        let store = BASInMemoryMemoryAtomStore(initial: [])
        let writer = BASMemoryMutationWriter(store: store)

        let phantomID = UUID().uuidString
        let decision = BASMemoryTieringReconciliationOutcome
            .Decision(
                profile: makeProfile(atomID: phantomID),
                transition: .promote(
                    from: .warm,
                    to: .hot,
                    reason: .compositeHeatAboveUpperBand))
        let outcome = await writer.apply(
            outcome: makeOutcome(decisions: [decision]))

        XCTAssertEqual(outcome.evaluated, 1)
        XCTAssertEqual(outcome.applied, 0)
        XCTAssertEqual(outcome.notFound, 1)
        XCTAssertFalse(outcome.isFullyApplied)
    }

    // MARK: - 7. Mixed batch — counts add up to evaluated

    func testMixedBatchProducesCorrectCounts() async throws {
        let promoteAtom = makeAtom(tier: .warm)
        let demoteAtom = makeAtom(tier: .warm)
        let holdAtom = makeAtom(tier: .warm)
        let evictAtom = makeAtom(tier: .cold)
        let quarantineAtom = makeAtom(governanceStatus: .governed)

        let store = BASInMemoryMemoryAtomStore(
            initial: [
                promoteAtom, demoteAtom, holdAtom,
                evictAtom, quarantineAtom
            ])
        let writer = BASMemoryMutationWriter(store: store)

        let decisions = [
            BASMemoryTieringReconciliationOutcome.Decision(
                profile: makeProfile(
                    atomID: promoteAtom.id.uuidString),
                transition: .promote(
                    from: .warm, to: .hot,
                    reason: .compositeHeatAboveUpperBand)),
            .init(
                profile: makeProfile(
                    atomID: demoteAtom.id.uuidString),
                transition: .demote(
                    from: .warm, to: .cold,
                    reason: .compositeHeatBelowLowerBand)),
            .init(
                profile: makeProfile(
                    atomID: holdAtom.id.uuidString),
                transition: .hold(
                    tier: .warm,
                    reason: .withinThresholds)),
            .init(
                profile: makeProfile(
                    atomID: evictAtom.id.uuidString),
                transition: .evictSuggest(
                    from: .cold,
                    reason: .coldStaleUnused)),
            .init(
                profile: makeProfile(
                    atomID: quarantineAtom.id.uuidString),
                transition: .quarantineSuggest(
                    from: .warm,
                    reason: .sensitivityEscalated)),
            // 6th decision: phantom atom → notFound
            .init(
                profile: makeProfile(
                    atomID: UUID().uuidString),
                transition: .promote(
                    from: .warm, to: .hot,
                    reason: .compositeHeatAboveUpperBand))
        ]

        let outcome = await writer.apply(
            outcome: makeOutcome(decisions: decisions))

        // 4 applied (promote/demote/evict/quarantine) +
        // 1 skipped (hold) + 1 notFound = 6 evaluated.
        XCTAssertEqual(outcome.evaluated, 6)
        XCTAssertEqual(
            outcome.applied, 4,
            "4 successful mutations expected (promote/demote/" +
            "evict/quarantine)")
        XCTAssertEqual(outcome.skipped, 1)
        XCTAssertEqual(outcome.notFound, 1)
        XCTAssertFalse(outcome.isFullyApplied)

        // Verify each store change landed.
        let promoteAfter = await store.atom(
            forID: promoteAtom.id.uuidString)
        XCTAssertEqual(promoteAfter?.tier, .hot)
        let demoteAfter = await store.atom(
            forID: demoteAtom.id.uuidString)
        XCTAssertEqual(demoteAfter?.tier, .cold)
        let holdAfter = await store.atom(
            forID: holdAtom.id.uuidString)
        XCTAssertEqual(
            holdAfter?.tier, .warm,
            "held atom must NOT be mutated")
        let evictAfter = await store.atom(
            forID: evictAtom.id.uuidString)
        XCTAssertNil(evictAfter)
        let quarantineAfter = await store.atom(
            forID: quarantineAtom.id.uuidString)
        XCTAssertEqual(
            quarantineAfter?.governanceStatus, .quarantined)
    }

    // MARK: - 8. isFullyApplied invariant

    func testIsFullyAppliedTrueWhenAllDecisionsLand()
        async throws
    {
        let atom = makeAtom(tier: .warm)
        let store = BASInMemoryMemoryAtomStore(initial: [atom])
        let writer = BASMemoryMutationWriter(store: store)

        let decisions = [
            BASMemoryTieringReconciliationOutcome.Decision(
                profile: makeProfile(
                    atomID: atom.id.uuidString),
                transition: .hold(
                    tier: .warm,
                    reason: .withinThresholds))
        ]
        let outcome = await writer.apply(
            outcome: makeOutcome(decisions: decisions))
        XCTAssertTrue(
            outcome.isFullyApplied,
            "outcome with only .hold + .applied decisions " +
            "(no notFound) MUST report isFullyApplied = true")
    }

    // MARK: - 9. Empty outcome → zero everything, fully applied

    func testEmptyOutcomeProducesZeroCounts() async throws {
        let store = BASInMemoryMemoryAtomStore(initial: [])
        let writer = BASMemoryMutationWriter(store: store)
        let outcome = await writer.apply(
            outcome: makeOutcome(decisions: []))
        XCTAssertEqual(outcome.evaluated, 0)
        XCTAssertEqual(outcome.applied, 0)
        XCTAssertEqual(outcome.skipped, 0)
        XCTAssertEqual(outcome.notFound, 0)
        XCTAssertTrue(outcome.isFullyApplied)
    }
}
