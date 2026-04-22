import XCTest
import BASMemory
import BASSovereign
import BASOrchestration
@testable import QinaoHost
@testable import QinaoRuntime
@testable import QinaoSovereign

/// M80 — cross-chain shadow-trial audit tests.
///
/// Before M80, QinaoFurnace's L13 evolution ledger and
/// QinaoSovereignControlPlane's L14 audit ledger were two separate
/// hash chains. A host-private experience candidate could traverse
/// the full `submit → observe → finalize → seal` state machine on
/// the furnace side with NO cryptographic linkage to the sovereign
/// chain, which was the last unresolved seam on the honesty-board's
/// invariant 3 ("宿主私有经验不进基础权重") row.
///
/// M80 introduces `QinaoSovereignCrossChainLedger` — a dual-writer
/// that appends every shadow-trial event to the sovereign
/// append-only chain first (fail-closed) and to the in-memory
/// read-side ledger second, and a `QinaoRuntime.makeFurnace(joinedTo:)`
/// factory that is the only supported path for constructing a joined
/// furnace. These tests prove the seam end-to-end:
///
/// 1. Submit on a joined furnace appends identical entries
///    (same auditID / sessionID / turnID / verdictRef) to both
///    chains — strict byte-equal provenance.
/// 2. A full workbench (submit + observe + finalize) appends N
///    entries to each side; sovereign `verifyChainIntegrity()`
///    passes after the run (chain hash root is intact).
/// 3. Fail-closed: if the sovereign side rejects the append (stub
///    ledger that always throws), the furnace throws
///    `FurnaceError.ledgerAppendFailed`, the primary has zero
///    entries, and the coordinator holds no in-memory state for
///    the candidate. `replay` would return nothing.
/// 4. Cross-chain writes do not break the replay contract:
///    `furnace.allTrialEvents()` and `furnace.replay(candidateID:)`
///    produce the same events as a non-joined furnace would.
/// 5. `QinaoRuntime.makeFurnace(joinedTo:)` factory produces a
///    furnace wired to the control plane's bootstrapped audit
///    chain; a submit via the factory-produced furnace is visible
///    on the plane's audit chain.
/// 6. Blocked finalization cross-chains every sub-event (trial
///    blocked + seal denied + retraction queued), proving the
///    seam covers the full terminal-state machinery, not just the
///    happy path.
/// 7. Chain integrity across mixed-event-kind history — a workbench
///    that mixes submit / observe / fail / finalize appends to a
///    single sovereign chain that still passes integrity
///    verification (no tampering, signatures line up).
final class QinaoFurnaceSovereignAuditTests: XCTestCase {

    // MARK: - Fixtures

    private static let fixedNow = Date(timeIntervalSince1970: 1_730_500_000)

    private func makeClock() -> @Sendable () -> Date {
        let target = Self.fixedNow
        return { target }
    }

    private func makeCandidate(
        id: String = "candidate.sovereign-chain.v1",
        sourceRefs: [String] = ["src-a", "src-b"]
    ) -> BASExperienceCandidate {
        BASExperienceCandidate(
            candidateID: id,
            sourceRefs: sourceRefs,
            candidateType: .bias,
            summary: "summary for \(id)",
            stabilitySignal: 0.7,
            contaminationRisk: 0.2,
            hostScope: "host.domain.joined",
            sovereignScope: "sovereign.scope.growth")
    }

    /// Build a joined furnace where:
    /// - `primary` is an in-memory ledger we can read to assert
    ///   that cross-chained writes arrived on the primary side.
    /// - `external` is a `BASSovereignAuditLedger` — the SAME type
    ///   the control plane holds, so we exercise the real
    ///   `BASSovereignAuditLedger: BASShadowTrialLedger` extension
    ///   from `BASOrchestration`.
    private func makeJoinedFurnace(
        trialIDs: [String] = [],
        sealIDs: [String] = [],
        retractionIDs: [String] = [],
        auditIDs: [String] = []
    ) -> (QinaoFurnace,
          BASInMemoryShadowTrialLedger,
          BASSovereignAuditLedger)
    {
        let primary = BASInMemoryShadowTrialLedger()
        let sovereign = BASSovereignAuditLedger.withSeed(
            "m80-test-seed-\(UUID().uuidString)")
        let cross = QinaoSovereignCrossChainLedger(
            primary: primary,
            external: sovereign)
        let trialPump = CounterPump(ids: trialIDs, prefix: "trial")
        let sealPump = CounterPump(ids: sealIDs, prefix: "seal")
        let retractPump = CounterPump(ids: retractionIDs, prefix: "retract")
        let auditPump = CounterPump(ids: auditIDs, prefix: "audit")
        let furnace = QinaoFurnace(
            primaryLedger: primary,
            coordinatorLedger: cross,
            clock: makeClock(),
            nextAuditID: { auditPump.next() },
            nextTrialID: { trialPump.next() },
            nextSealID: { sealPump.next() },
            nextRetractionID: { retractPump.next() })
        return (furnace, primary, sovereign)
    }

    // MARK: - 1. Dual-write identity on submit

    func testSubmitOnJoinedFurnaceAppendsToBothChains() async throws {
        let (furnace, primary, sovereign) = makeJoinedFurnace(
            trialIDs: ["t-1"], auditIDs: ["aud-open-1"])

        _ = try await furnace.submit(
            candidate: makeCandidate(),
            sessionID: "session-joined-1",
            turnID: "turn-1",
            trialScope: "scope.growth")

        // Primary has exactly one entry (the open event).
        let primaryAll = await primary.all()
        XCTAssertEqual(primaryAll.count, 1)
        XCTAssertEqual(primaryAll[0].auditID, "aud-open-1")
        XCTAssertEqual(primaryAll[0].eventKind, "shadow_trial_opened")

        // Sovereign has exactly one entry with the same audit ID
        // and the same scalar fields — this is the core dual-write
        // invariant.
        let sovereignCount = await sovereign.count()
        XCTAssertEqual(sovereignCount, 1)
        let fetched = try await sovereign.query(byAuditRef: "aud-open-1")
        XCTAssertEqual(fetched.entry.auditID, "aud-open-1")
        XCTAssertEqual(fetched.entry.sessionID, "session-joined-1")
        XCTAssertEqual(fetched.entry.turnID, "turn-1")
        XCTAssertEqual(
            fetched.entry.verdictRef, "shadow_trial:t-1")
        XCTAssertEqual(
            fetched.entry.ruleIDs, ["L13.shadow_trial_opened"])
        XCTAssertEqual(fetched.entry.actionRefs, [makeCandidate().candidateID])
        XCTAssertEqual(fetched.entry.snapshotRef, "scope.growth")
    }

    // MARK: - 2. Workbench → chain integrity holds

    func testWorkbenchOnJoinedFurnacePreservesChainIntegrity() async throws {
        let (furnace, primary, sovereign) = makeJoinedFurnace(
            trialIDs: ["t-wb"],
            sealIDs: ["s-wb"],
            auditIDs: [
                "aud-open", "aud-observe", "aud-passed", "aud-seal"])

        let plan = QinaoFurnace.WorkbenchPlan(
            candidate: makeCandidate(),
            trialScope: "scope.growth",
            observedEffects: ["adopted-new-routine"],
            failConditions: [],
            outcome: .passed)

        _ = try await furnace.runWorkbench(
            plan: plan,
            sessionID: "session-wb",
            turnID: "turn-wb")

        // 4 events on the primary side: opened, effect observed,
        // passed, seal issued.
        let primaryKinds = await primary.eventKinds()
        XCTAssertEqual(
            primaryKinds,
            [
                "shadow_trial_opened",
                "shadow_trial_effect_observed",
                "shadow_trial_passed",
                "evolution_seal_issued"
            ])

        // Same 4 events on sovereign, in the same order.
        let sovereignEntries = await sovereign.snapshot()
        XCTAssertEqual(sovereignEntries.count, 4)
        XCTAssertEqual(
            sovereignEntries.map { $0.entry.auditID },
            ["aud-open", "aud-observe", "aud-passed", "aud-seal"])

        // Hash-chain integrity passes — every entry's priorHash
        // links to the previous entry's selfHash, every signature
        // re-signs to the same bytes, namespace matches.
        try await sovereign.verifyChainIntegrity()
    }

    // MARK: - 3. Fail-closed on sovereign rejection

    func testSovereignRejectionPreventsPrimaryCommit() async throws {
        let primary = BASInMemoryShadowTrialLedger()
        let rejecting = AlwaysRejectingLedger()
        let cross = QinaoSovereignCrossChainLedger(
            primary: primary, external: rejecting)
        let trialPump = CounterPump(ids: ["t-doomed"], prefix: "trial")
        let auditPump = CounterPump(ids: ["aud-doomed"], prefix: "audit")
        let furnace = QinaoFurnace(
            primaryLedger: primary,
            coordinatorLedger: cross,
            clock: makeClock(),
            nextAuditID: { auditPump.next() },
            nextTrialID: { trialPump.next() },
            nextSealID: { "seal-\(UUID().uuidString)" },
            nextRetractionID: { "retract-\(UUID().uuidString)" })

        do {
            _ = try await furnace.submit(
                candidate: makeCandidate(),
                sessionID: "session-fc",
                turnID: "turn-fc",
                trialScope: "scope.growth")
            XCTFail("expected submit to throw on sovereign rejection")
        } catch QinaoFurnace.FurnaceError.ledgerAppendFailed(let reason) {
            // Coordinator wraps our throw into ledgerAppendFailed;
            // the reason string contains the upstream description.
            XCTAssertTrue(
                reason.contains("rejected") || reason.contains("AlwaysRejecting"),
                "expected fail-closed reason to name the rejecting ledger; "
                + "got: \(reason)")
        } catch {
            XCTFail(
                "expected FurnaceError.ledgerAppendFailed, got \(error)")
        }

        // Primary stayed empty — sovereign threw first, so primary
        // was never touched.
        let primaryCount = await primary.count()
        XCTAssertEqual(primaryCount, 0)

        // Coordinator has no in-memory state for the candidate —
        // the throw prevented the commit.
        let visible = await furnace.candidate(for: makeCandidate().candidateID)
        XCTAssertNil(visible)

        // Replay returns nothing — nothing committed, nothing visible.
        let replay = await furnace.replay(candidateID: makeCandidate().candidateID)
        XCTAssertTrue(replay.isEmpty)
    }

    // MARK: - 4. Replay still reads from primary

    func testReplayReadsFromPrimaryUnchangedByCrossChain() async throws {
        let (furnace, _, _) = makeJoinedFurnace(
            trialIDs: ["t-replay"],
            sealIDs: ["s-replay"],
            auditIDs: ["aud-open-r", "aud-obs-r", "aud-pass-r", "aud-seal-r"])

        let plan = QinaoFurnace.WorkbenchPlan(
            candidate: makeCandidate(id: "candidate.replay.v1"),
            trialScope: "scope.growth",
            observedEffects: ["observed-one"],
            failConditions: [],
            outcome: .passed)

        _ = try await furnace.runWorkbench(
            plan: plan,
            sessionID: "session-replay",
            turnID: "turn-replay")

        let events = await furnace.replay(candidateID: "candidate.replay.v1")
        XCTAssertEqual(
            events.map(\.eventKind),
            [
                "shadow_trial_opened",
                "shadow_trial_effect_observed",
                "shadow_trial_passed",
                "evolution_seal_issued"
            ])
        XCTAssertEqual(
            events.map(\.auditID),
            ["aud-open-r", "aud-obs-r", "aud-pass-r", "aud-seal-r"])
        // And `allTrialEvents` returns the identical set (no other
        // candidate touched the furnace).
        let all = await furnace.allTrialEvents()
        XCTAssertEqual(all.count, events.count)
        XCTAssertEqual(all.map(\.auditID), events.map(\.auditID))
    }

    // MARK: - 5. makeFurnace(joinedTo:) factory

    func testMakeFurnaceJoinedToControlPlaneWritesToPlaneLedger() async throws {
        let config = QinaoSovereignControlPlane.Configuration(
            ledgerSigningSecret: Data("m80-factory-seed".utf8))
        let (plane, _) = QinaoSovereignControlPlane.bootstrap(
            configuration: config)

        let furnace = await QinaoRuntime.makeFurnace(joinedTo: plane)

        _ = try await furnace.submit(
            candidate: makeCandidate(id: "candidate.factory.v1"),
            sessionID: "session-factory",
            turnID: "turn-factory",
            trialScope: "scope.growth")

        // The factory-produced furnace writes to the plane's own
        // audit chain. Reach the plane's ledger via the same
        // `package` seam the factory uses (same module boundary).
        let planLedger = await plane.sharedAppendOnlyChain()
        let count = await planLedger.count()
        XCTAssertEqual(count, 1)

        let session = await planLedger.entries(
            forSession: "session-factory")
        XCTAssertEqual(session.count, 1)
        XCTAssertEqual(session[0].entry.turnID, "turn-factory")
        XCTAssertEqual(
            session[0].entry.verdictRef.hasPrefix("shadow_trial:"),
            true)
    }

    // MARK: - 6. Blocked finalize — every sub-event cross-chains

    func testBlockedWorkbenchCrossChainsEverySubEvent() async throws {
        let (furnace, primary, sovereign) = makeJoinedFurnace(
            trialIDs: ["t-blk"],
            sealIDs: ["s-blk"],
            retractionIDs: ["r-blk"],
            auditIDs: [
                "aud-open-blk",
                "aud-fail-cond",
                "aud-blocked",
                "aud-seal-denied",
                "aud-retract"])

        let plan = QinaoFurnace.WorkbenchPlan(
            candidate: makeCandidate(id: "candidate.blocked.v1"),
            trialScope: "scope.growth",
            observedEffects: [],
            failConditions: ["boundary-violation"],
            outcome: .blocked)

        _ = try await furnace.runWorkbench(
            plan: plan,
            sessionID: "session-blk",
            turnID: "turn-blk")

        let expectedKinds = [
            "shadow_trial_opened",
            "shadow_trial_fail_condition_recorded",
            "shadow_trial_blocked",
            "evolution_seal_denied",
            "retraction_order_queued"
        ]
        let primaryKinds = await primary.eventKinds()
        XCTAssertEqual(primaryKinds, expectedKinds)

        let sovereignEntries = await sovereign.snapshot()
        XCTAssertEqual(
            sovereignEntries.map { $0.entry.ruleIDs.first ?? "?" },
            expectedKinds.map { "L13.\($0)" })

        // Integrity still holds after a blocked-path run.
        try await sovereign.verifyChainIntegrity()
    }

    // MARK: - 7. Mixed-event-kind chain integrity

    func testChainIntegrityAcrossMixedEventKinds() async throws {
        let (furnace, _, sovereign) = makeJoinedFurnace()

        // Run two workbenches on different candidates to force a
        // mixed event-kind stream into the sovereign chain.
        let planA = QinaoFurnace.WorkbenchPlan(
            candidate: makeCandidate(id: "candidate.mix.a"),
            trialScope: "scope.growth",
            observedEffects: ["obs-a-1", "obs-a-2"],
            failConditions: [],
            outcome: .passed)
        let planB = QinaoFurnace.WorkbenchPlan(
            candidate: makeCandidate(
                id: "candidate.mix.b", sourceRefs: ["src-c"]),
            trialScope: "scope.growth",
            observedEffects: [],
            failConditions: ["host-rejected"],
            outcome: .failed)

        _ = try await furnace.runWorkbench(
            plan: planA, sessionID: "session-mix", turnID: "turn-mix-a")
        _ = try await furnace.runWorkbench(
            plan: planB, sessionID: "session-mix", turnID: "turn-mix-b")

        // 5 events for plan A (open + 2 observe + passed + seal
        // issued) + 5 events for plan B (open + fail-cond + failed
        // + seal-denied + retraction-queued) = 10 entries.
        let count = await sovereign.count()
        XCTAssertEqual(count, 10)
        try await sovereign.verifyChainIntegrity()
    }
}

// MARK: - Utilities

/// Thread-safe monotonic pump for deterministic IDs. Duplicated
/// from `QinaoFurnaceTests` (it is `private` there) so this
/// separate test file does not have to reach across file scope.
private final class CounterPump: @unchecked Sendable {
    private let lock = NSLock()
    private var nextIndex = 0
    private let ids: [String]
    private let prefix: String

    init(ids: [String], prefix: String) {
        self.ids = ids
        self.prefix = prefix
    }

    func next() -> String {
        lock.lock()
        defer { lock.unlock() }
        if nextIndex < ids.count {
            let value = ids[nextIndex]
            nextIndex += 1
            return value
        }
        let value = "\(prefix)-auto-\(nextIndex)"
        nextIndex += 1
        return value
    }
}

/// Fail-closed harness for Test #3. Always throws
/// `AlwaysRejectingLedger.Rejected` on append, proving that a
/// sovereign rejection propagates through the cross-chain ledger,
/// then through the coordinator's `ledgerAppendFailed` wrap, and
/// finally through the furnace's `FurnaceError.ledgerAppendFailed`
/// translation — without ever committing to the primary side.
private actor AlwaysRejectingLedger: BASShadowTrialLedger {
    struct Rejected: Error, CustomStringConvertible {
        let description = "AlwaysRejectingLedger rejected append"
    }

    func appendShadowTrialEvent(
        _: BASShadowTrialLedgerEntry
    ) async throws -> String {
        throw Rejected()
    }
}
