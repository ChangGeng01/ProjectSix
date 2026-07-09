// MARK: - BASMemorySleepConsolidationPassTests — 全面进化 T3.1 gate
//
// Phase-C evidence for the sleep/consolidation orchestrator。 The
// load-bearing claims:
//   1. QUARANTINE-NEVER-REMOVE (亏的不要): an applied pass moves
//      forget candidates to `.quarantined` with a `manual_review`
//      release condition;every atom REMAINS retrievable in the
//      store。 `remove` is never reachable from the pass。
//   2. Dry-run honesty: verdicts are computed + recorded,zero
//      writes,and the chain hash does NOT move。
//   3. Applied passes move the chain hash (the tamper-evident
//      ledger mark) — pre ≠ post ⟺ state mutated。
//   4. Window-budget honesty: an exhausted window stops the
//      pipeline between stages and the checkpoint records partial
//      completion。
//   5. Unjoined candidates are recorded,never acted on。
//   6. The gating flag defaults OFF (byte-equal by construction —
//      nothing constructs the pass while false)。

import XCTest
import Foundation
@testable import BASHostKit
@testable import BASMemory
@testable import BASRustCoreBridge

final class BASMemorySleepConsolidationPassTests: XCTestCase {

    private let referenceNow = Date(timeIntervalSince1970: 1_700_000_000)

    /// Seed: N store atoms (warm tier) + tracker retrieval records
    /// with staggered ages so the Rust forget verdict is non-trivial。
    /// Tracker atomIDs == store `id.uuidString` (identity join)。
    private func makeSeededFixture(
        atomCount: Int = 6,
        recentCount: Int = 2
    ) async throws -> (
        tracker: BASRustMemoryUsageTrackerActor,
        applier: BASMemoryClosedLoopApplier,
        store: BASInMemoryMemoryAtomStore,
        atomIDs: [String],
        atomTiers: [String: BASMemoryTier]
    ) {
        let atoms = (0..<atomCount).map { i in
            BASGovernedMemory(
                id: UUID(),
                kind: .episodic,
                content: "atom-\(i)",
                scope: .session,
                sensitivity: .low,
                tier: .warm,
                confidence: 0.7,
                sourceType: "test",
                governanceStatus: .governed,
                provenanceSummary: "t31-gate")
        }
        let store = BASInMemoryMemoryAtomStore(initial: atoms)
        let tracker = try BASRustMemoryUsageTrackerActor(
            useRustCore: true)
        let atomIDs = atoms.map { $0.id.uuidString }
        // Old, single-touch records for most atoms;recent,
        // multi-touch for the first `recentCount` (high importance)。
        for (i, id) in atomIDs.enumerated() {
            let isRecent = i < recentCount
            let age: TimeInterval = isRecent ? 60 : 14 * 24 * 3600
            let touches = isRecent ? 3 : 1
            for t in 0..<touches {
                _ = try await tracker.record(
                    atomID: id,
                    sessionRef: "t31-session",
                    turnRef: "turn-\(i)-\(t)",
                    permitMode: "safe",
                    retrievedAt: referenceNow.addingTimeInterval(-age))
            }
        }
        let applier = BASMemoryClosedLoopApplier(
            store: store, tracker: BASMemoryUsageTracker())
        let atomTiers = Dictionary(
            uniqueKeysWithValues: atomIDs.map { ($0, BASMemoryTier.warm) })
        return (tracker, applier, store, atomIDs, atomTiers)
    }

    private func makePass(
        tracker: BASRustMemoryUsageTrackerActor,
        applier: BASMemoryClosedLoopApplier,
        store: BASInMemoryMemoryAtomStore,
        storeAtomID: @escaping @Sendable (String) -> String? = { $0 },
        clock: @escaping @Sendable () -> Date = { Date() }
    ) -> BASMemorySleepConsolidationPass {
        BASMemorySleepConsolidationPass(
            tracker: tracker,
            applier: applier,
            store: store,
            storeAtomID: storeAtomID,
            clock: clock)
    }

    // MARK: - 6. Flag default

    func testSleepConsolidationFlagDefaultsOff() {
        XCTAssertFalse(
            BASMemorySleepConsolidationPass.sleepConsolidationEnabled,
            "default-off = byte-equal by construction (ADR-014); " +
            "promotion is a manual reviewed commit, never automatic")
    }

    // MARK: - 2. Dry-run honesty

    func testDryRunComputesVerdictsWithoutWritesOrHashMovement() async throws {
        let fx = try await makeSeededFixture()
        let pass = makePass(
            tracker: fx.tracker, applier: fx.applier, store: fx.store)
        let checkpoint = await pass.run(BASSleepConsolidationRequest(
            atomTiers: fx.atomTiers,
            now: referenceNow,
            retainFraction: 0.5,
            maintenanceClass: .standard,
            windowMs: 60_000,
            dryRun: true))
        XCTAssertFalse(checkpoint.partialCompletion,
            "generous window + dry-run completes: \(checkpoint.failureReasons)")
        XCTAssertFalse(checkpoint.forgetCandidateAtomIDs.isEmpty,
            "retain 50% of 6 atoms ⇒ the Rust verdict names candidates")
        XCTAssertTrue(checkpoint.quarantinedAtomIDs.isEmpty,
            "dry-run writes nothing")
        XCTAssertEqual(checkpoint.preChainHash, checkpoint.postChainHash,
            "no ledger mark on dry-run ⇒ chain hash must not move")
        for id in fx.atomIDs {
            let atom = await fx.store.atom(forID: id)
            XCTAssertEqual(atom?.governanceStatus, .governed,
                "dry-run leaves every atom untouched")
        }
    }

    // MARK: - audit memory-b F7 — a dry-run observation reflects the REAL universe
    //
    // Before the fix, a dry-run checkpoint's tier-move surface was structurally empty:
    // appliedMutations/rejectedMutations are both [:] on a dry-run (nothing is written),
    // and the scorer's report.mutations (the actual verdict) was dropped — so the
    // "instrument read a constant zero" regardless of the corpus. recommendedTierMoves
    // now carries the scorer's verdict on a dry-run, so the observation is informative
    // WITHOUT writing anything.

    func testDryRunSurfacesRecommendedTierMovesFromRealUniverse() async throws {
        let fx = try await makeSeededFixture()
        let pass = makePass(
            tracker: fx.tracker, applier: fx.applier, store: fx.store)
        let checkpoint = await pass.run(BASSleepConsolidationRequest(
            atomTiers: fx.atomTiers,   // a REAL (atomID → .warm) universe
            now: referenceNow,
            retainFraction: 0.5,
            maintenanceClass: .standard,
            windowMs: 60_000,
            dryRun: true))
        // The load-bearing teeth: the scorer's tier-move verdict is surfaced on a dry-run.
        XCTAssertFalse(checkpoint.recommendedTierMoves.isEmpty,
            "a dry-run over a populated universe must surface the scorer's tier-move verdict, "
            + "not a structural zero")
        // Every recommendation is a genuine MOVE off the seeded .warm tier.
        for (_, tier) in checkpoint.recommendedTierMoves {
            XCTAssertNotEqual(tier, .warm, "recommendedTierMoves holds only actual changes")
        }
        // Still a proper dry-run — nothing written, hash unmoved.
        XCTAssertTrue(checkpoint.appliedMutations.isEmpty, "dry-run applies nothing")
        XCTAssertTrue(checkpoint.quarantinedAtomIDs.isEmpty, "dry-run quarantines nothing")
        XCTAssertEqual(checkpoint.preChainHash, checkpoint.postChainHash,
            "dry-run leaves no ledger mark")
    }

    // MARK: - 1+3. Applied pass: quarantine-never-remove + hash moves

    func testAppliedPassQuarantinesReversiblyAndMovesChainHash() async throws {
        let fx = try await makeSeededFixture()
        let pass = makePass(
            tracker: fx.tracker, applier: fx.applier, store: fx.store)
        let checkpoint = await pass.run(BASSleepConsolidationRequest(
            atomTiers: fx.atomTiers,
            now: referenceNow,
            retainFraction: 0.5,
            maintenanceClass: .standard,
            windowMs: 60_000,
            dryRun: false))
        XCTAssertFalse(checkpoint.partialCompletion,
            "failures: \(checkpoint.failureReasons)")
        XCTAssertFalse(checkpoint.quarantinedAtomIDs.isEmpty,
            "the joined forget candidates must be quarantined")
        XCTAssertNotEqual(checkpoint.preChainHash, checkpoint.postChainHash,
            "an applied pass leaves a tamper-evident ledger mark")
        // 亏的不要 — every atom (quarantined included) REMAINS in the
        // store, reversibly:
        for id in fx.atomIDs {
            let atom = await fx.store.atom(forID: id)
            XCTAssertNotNil(atom, "NEVER removed — quarantine only")
        }
        for id in checkpoint.quarantinedAtomIDs {
            let atom = await fx.store.atom(forID: id)
            XCTAssertEqual(atom?.governanceStatus, .quarantined)
        }
        // Reversibility contract on every record:
        for record in checkpoint.quarantineRecords {
            XCTAssertTrue(record.releaseConditions.contains("manual_review"))
            XCTAssertTrue(record.reasonCodes.contains(
                BASMemorySleepConsolidationPass.quarantineReasonCode))
        }
        // Recent, important atoms survive a 50% retain verdict:
        let recentID = fx.atomIDs[0]
        XCTAssertFalse(checkpoint.quarantinedAtomIDs.contains(recentID),
            "the most-touched recent atom must be retained")
        XCTAssertEqual(checkpoint.maintenanceClass,
                       BASMaintenanceClass.standard.rawValue)
    }

    // MARK: - 4. Window-budget honesty

    func testExhaustedWindowStopsPipelineAndRecordsPartial() async throws {
        let fx = try await makeSeededFixture()
        // A clock that leaps 10s per inspection ⇒ the budget is
        // spent after the very first stage completes。
        let leaps = LeapClock(start: referenceNow, stepSeconds: 10)
        let pass = makePass(
            tracker: fx.tracker, applier: fx.applier, store: fx.store,
            clock: { leaps.next() })
        let checkpoint = await pass.run(BASSleepConsolidationRequest(
            atomTiers: fx.atomTiers,
            now: referenceNow,
            retainFraction: 0.5,
            maintenanceClass: .light,
            windowMs: 5,
            dryRun: false))
        XCTAssertTrue(checkpoint.partialCompletion,
            "a 5ms window cannot fit the pipeline")
        XCTAssertTrue(checkpoint.completedStages.contains(
            BASConsolidationCheckpoint.Stage.preChainHash))
        XCTAssertFalse(checkpoint.completedStages.contains(
            BASConsolidationCheckpoint.Stage.quarantineWrite),
            "the pipeline must stop BEFORE the write stage")
        XCTAssertTrue(checkpoint.quarantinedAtomIDs.isEmpty)
    }

    /// audit M-h F6 — the tamper-evidence invariant. The ledger mark
    /// (⑥, the ONLY chain-hash mover) used to sit INSIDE the `pipeline`
    /// block after ⑤, so a window-exhaust `break` AFTER a mutating stage
    /// (③ tier-apply) skipped it → the store was mutated but
    /// preChainHash == postChainHash. An external tamper that also
    /// skipped the mark would then read as clean。 ⑥ now fires OUTSIDE
    /// the window budget: any pass that mutated state moves the chain,
    /// wherever the pipeline stopped。
    func testMutationThenWindowExhaustStillMovesChainHash() async throws {
        let fx = try await makeSeededFixture()
        // step 10s per clock read; startedAt + guards at ①/②/③ ⇒
        // elapsed 10s/20s/30s. A 25s window survives ①②③ (③ demotes
        // the old atoms — a REAL store mutation) then exhausts at the
        // tier-apply post-guard, BEFORE ④⑤。
        let leaps = LeapClock(start: referenceNow, stepSeconds: 10)
        let pass = makePass(
            tracker: fx.tracker, applier: fx.applier, store: fx.store,
            clock: { leaps.next() })
        let checkpoint = await pass.run(BASSleepConsolidationRequest(
            atomTiers: fx.atomTiers,
            now: referenceNow,
            retainFraction: 0.5,
            maintenanceClass: .standard,
            windowMs: 25_000,
            dryRun: false))
        XCTAssertTrue(checkpoint.partialCompletion,
            "a 25s window exhausts at the tier-apply post-guard")
        XCTAssertTrue(checkpoint.completedStages.contains(
            BASConsolidationCheckpoint.Stage.tierApply),
            "③ tier-apply ran")
        XCTAssertFalse(checkpoint.appliedMutations.isEmpty,
            "③ demoted the old atoms — a REAL store mutation")
        XCTAssertFalse(checkpoint.completedStages.contains(
            BASConsolidationCheckpoint.Stage.quarantineWrite),
            "the window exhausted BEFORE ④⑤ — a genuine mid-pipeline stop")
        XCTAssertTrue(checkpoint.quarantinedAtomIDs.isEmpty,
            "⑤ was skipped by the exhausted window")
        // THE invariant — the anchor fires outside the window budget:
        XCTAssertTrue(checkpoint.completedStages.contains(
            BASConsolidationCheckpoint.Stage.ledgerMark),
            "the tamper-evidence anchor must fire on a mutating partial pass")
        XCTAssertNotEqual(checkpoint.preChainHash, checkpoint.postChainHash,
            "mutation ⟹ chain moves — even when the window exhausted mid-pipeline")
    }

    // MARK: - 5. Unjoined candidates recorded, never acted on

    func testUnjoinedCandidatesAreRecordedNotActedOn() async throws {
        let fx = try await makeSeededFixture()
        let pass = makePass(
            tracker: fx.tracker, applier: fx.applier, store: fx.store,
            storeAtomID: { _ in nil })  // no join available
        let checkpoint = await pass.run(BASSleepConsolidationRequest(
            atomTiers: fx.atomTiers,
            now: referenceNow,
            retainFraction: 0.5,
            maintenanceClass: .standard,
            windowMs: 60_000,
            dryRun: false))
        XCTAssertFalse(checkpoint.unjoinedForgetCandidateAtomIDs.isEmpty,
            "unjoinable candidates are RECORDED")
        XCTAssertTrue(checkpoint.quarantinedAtomIDs.isEmpty,
            "…and never acted on")
        for id in fx.atomIDs {
            let atom = await fx.store.atom(forID: id)
            XCTAssertEqual(atom?.governanceStatus, .governed)
        }
    }

    // MARK: - Checkpoint wire round-trip

    func testCheckpointCodableRoundTrip() async throws {
        let fx = try await makeSeededFixture()
        let pass = makePass(
            tracker: fx.tracker, applier: fx.applier, store: fx.store)
        let checkpoint = await pass.run(BASSleepConsolidationRequest(
            atomTiers: fx.atomTiers,
            now: referenceNow,
            maintenanceClass: .standard,
            windowMs: 60_000,
            dryRun: true))
        let data = try JSONEncoder().encode(checkpoint)
        let decoded = try JSONDecoder().decode(
            BASConsolidationCheckpoint.self, from: data)
        XCTAssertEqual(decoded.preChainHash, checkpoint.preChainHash)
        XCTAssertEqual(decoded.completedStages, checkpoint.completedStages)
        XCTAssertEqual(decoded.dryRun, true)
        XCTAssertEqual(decoded.recommendedTierMoves, checkpoint.recommendedTierMoves,
            "new field round-trips")
    }

    // audit memory-b F7 — byte-stability: a checkpoint LOGGED before recommendedTierMoves
    // existed omits the key and must still decode (to [:]), not throw.
    func testCheckpointDecodesLegacyLogMissingRecommendedTierMoves() async throws {
        let fx = try await makeSeededFixture()
        let pass = makePass(tracker: fx.tracker, applier: fx.applier, store: fx.store)
        let checkpoint = await pass.run(BASSleepConsolidationRequest(
            atomTiers: fx.atomTiers, now: referenceNow,
            maintenanceClass: .standard, windowMs: 60_000, dryRun: true))
        var obj = try JSONSerialization.jsonObject(
            with: JSONEncoder().encode(checkpoint)) as! [String: Any]
        obj.removeValue(forKey: "recommendedTierMoves")   // checkpoint logged before the field
        let legacy = try JSONSerialization.data(withJSONObject: obj)
        let decoded = try JSONDecoder().decode(BASConsolidationCheckpoint.self, from: legacy)
        XCTAssertTrue(decoded.recommendedTierMoves.isEmpty,
            "absent key ⇒ [:] (byte-stable; pre-field checkpoints still decode)")
        XCTAssertEqual(decoded.dryRun, true, "the rest of the legacy checkpoint decodes intact")
    }
}

/// Deterministic leaping clock for window-budget tests (class —
/// the pass's `@Sendable () -> Date` seam needs shared state)。
private final class LeapClock: @unchecked Sendable {
    private let lock = NSLock()
    private var current: Date
    private let step: TimeInterval

    init(start: Date, stepSeconds: TimeInterval) {
        self.current = start
        self.step = stepSeconds
    }

    func next() -> Date {
        lock.lock()
        defer { lock.unlock() }
        current = current.addingTimeInterval(step)
        return current
    }
}
