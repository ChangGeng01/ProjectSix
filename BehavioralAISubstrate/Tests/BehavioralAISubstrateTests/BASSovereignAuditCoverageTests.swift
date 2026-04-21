import XCTest
import BASRuntimeCore
@testable import BASSovereign

/// M38 — L14 sovereign audit-ledger coverage projection tests.
///
/// Exercises the pure `projectCoverage(...)` helper (no actor
/// hop) and the async `coverageSummary(turnID:sessionID:
/// emittedAt:)` on the actor. Both paths must produce the same
/// summary for the same input.
final class BASSovereignAuditCoverageTests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 1_700_000_000)

    // MARK: - Helpers

    private func makeEntry(
        auditID: String,
        session: String = "s-1",
        turn: String = "t-1",
        verdict: String = "v-1",
        ruleIDs: [String] = ["BR-001"],
        actor: BASSovereignAuditActor = .system
    ) -> BASSovereignAuditEntry {
        BASSovereignAuditEntry(
            auditID: auditID,
            sessionID: session,
            turnID: turn,
            verdictRef: verdict,
            ruleIDs: ruleIDs,
            signalRefs: [],
            actionRefs: [],
            snapshotRef: "snap-1",
            actor: actor,
            signature: "",
            appendedAt: t0)
    }

    private func wrap(
        _ draft: BASSovereignAuditEntry,
        priorHash: String = "GENESIS",
        selfHash: String = "x"
    ) -> BASSovereignAuditLedger.AppendedEntry {
        BASSovereignAuditLedger.AppendedEntry(
            entry: draft, priorHash: priorHash, selfHash: selfHash)
    }

    // MARK: - Pure projection shape

    func testProjectCoverageCarriesLayerAndFields() {
        let entries = [
            wrap(makeEntry(
                auditID: "a-1",
                verdict: "v-a",
                ruleIDs: ["BR-001", "BR-002"])),
            wrap(makeEntry(
                auditID: "a-2",
                verdict: "v-b",
                ruleIDs: ["BR-003"])),
            // Same verdict as a-1 — collapses in distinct count.
            wrap(makeEntry(
                auditID: "a-3",
                verdict: "v-a",
                ruleIDs: [])),
        ]
        let s = BASSovereignAuditLedger.projectCoverage(
            from: entries,
            turnID: "t-1",
            sessionID: "s-1",
            emittedAt: t0)
        XCTAssertEqual(s.layer, .sovereign)
        XCTAssertEqual(s.turnID, "t-1")
        XCTAssertEqual(s.sessionID, "s-1")
        XCTAssertEqual(s.totalObservations, 3)
        XCTAssertEqual(
            s.distinctSubjectCount, 2,
            "two distinct verdicts: v-a and v-b")
        XCTAssertTrue(
            s.hasCoreSignalCoverage,
            "at least one entry carries ruleIDs")
        XCTAssertEqual(
            s.budgetTotalCost,
            0.10 + 0.10 + 0.10,
            accuracy: 1e-9)
    }

    // MARK: - hasCoreSignalCoverage semantics

    func testEmptyLedgerHasNoCoreSignalCoverage() {
        let s = BASSovereignAuditLedger.projectCoverage(
            from: [],
            turnID: "t-empty",
            sessionID: "s-1",
            emittedAt: t0)
        XCTAssertEqual(s.totalObservations, 0)
        XCTAssertEqual(s.distinctSubjectCount, 0)
        XCTAssertFalse(s.hasCoreSignalCoverage)
        XCTAssertEqual(s.budgetTotalCost, 0.0, accuracy: 1e-12)
    }

    func testEntriesWithoutRuleIDsAreNotCoreSignal() {
        // A bookkeeping entry (token rotation, snapshot boot check)
        // has empty ruleIDs. The ledger is alive but the sovereign
        // did not evaluate a rule-bearing decision.
        let entries = [
            wrap(makeEntry(auditID: "b-1", ruleIDs: [])),
            wrap(makeEntry(auditID: "b-2", ruleIDs: [])),
        ]
        let s = BASSovereignAuditLedger.projectCoverage(
            from: entries,
            turnID: "t-1",
            sessionID: "s-1",
            emittedAt: t0)
        XCTAssertEqual(s.totalObservations, 2)
        XCTAssertFalse(
            s.hasCoreSignalCoverage,
            "entries without ruleIDs are alive but not rule-bearing")
    }

    // MARK: - Actor-aware budget

    func testOperatorEntriesCostMoreThanSystemEntries() {
        let entries = [
            wrap(makeEntry(auditID: "a-s", actor: .system)),
            wrap(makeEntry(auditID: "a-op", actor: .operator)),
        ]
        let s = BASSovereignAuditLedger.projectCoverage(
            from: entries,
            turnID: "t-1",
            sessionID: "s-1",
            emittedAt: t0)
        XCTAssertEqual(
            s.budgetTotalCost,
            0.10 + 0.15,
            accuracy: 1e-9)
    }

    func testBudgetClampsAtOne() {
        // 10 operator entries at 0.15 each = 1.50 raw → clamps to 1.0.
        let entries = (0..<10).map {
            wrap(makeEntry(
                auditID: "op-\($0)",
                verdict: "v-\($0)",
                actor: .operator))
        }
        let s = BASSovereignAuditLedger.projectCoverage(
            from: entries,
            turnID: "t-1",
            sessionID: "s-1",
            emittedAt: t0)
        XCTAssertEqual(s.budgetTotalCost, 1.0, accuracy: 1e-12)
        XCTAssertEqual(s.distinctSubjectCount, 10)
    }

    // MARK: - Turn/session filtering

    func testProjectionFiltersOutCrossTurnEntries() {
        let entries = [
            wrap(makeEntry(auditID: "a-1", turn: "t-1")),
            wrap(makeEntry(auditID: "a-2", turn: "t-2")),
            wrap(makeEntry(auditID: "a-3", turn: "t-1")),
        ]
        let s = BASSovereignAuditLedger.projectCoverage(
            from: entries,
            turnID: "t-1",
            sessionID: "s-1",
            emittedAt: t0)
        XCTAssertEqual(
            s.totalObservations, 2,
            "only t-1 entries count; t-2 is dropped")
    }

    func testProjectionFiltersOutCrossSessionEntries() {
        let entries = [
            wrap(makeEntry(auditID: "a-1", session: "s-1")),
            wrap(makeEntry(auditID: "a-2", session: "s-2")),
        ]
        let s = BASSovereignAuditLedger.projectCoverage(
            from: entries,
            turnID: "t-1",
            sessionID: "s-1",
            emittedAt: t0)
        XCTAssertEqual(s.totalObservations, 1)
    }

    // MARK: - Async path parity

    func testAsyncCoverageSummaryMatchesPurePath() async throws {
        let ledger = BASSovereignAuditLedger.withSeed("m38-test")
        _ = try await ledger.append(
            makeEntry(auditID: "a-1", verdict: "v-a"))
        _ = try await ledger.append(
            makeEntry(
                auditID: "a-2",
                turn: "t-1",
                verdict: "v-b",
                ruleIDs: ["BR-099"]))
        _ = try await ledger.append(
            makeEntry(
                auditID: "a-3",
                turn: "t-2",
                verdict: "v-c"))

        // Async actor path.
        let actorSummary = await ledger.coverageSummary(
            turnID: "t-1", sessionID: "s-1", emittedAt: t0)

        // Pure path fed from a snapshot.
        let snapshot = await ledger.snapshot()
        let pureSummary =
            BASSovereignAuditLedger.projectCoverage(
                from: snapshot,
                turnID: "t-1",
                sessionID: "s-1",
                emittedAt: t0)

        XCTAssertEqual(actorSummary, pureSummary)
        XCTAssertEqual(actorSummary.layer, .sovereign)
        XCTAssertEqual(actorSummary.totalObservations, 2)
        XCTAssertEqual(actorSummary.distinctSubjectCount, 2)
        XCTAssertTrue(actorSummary.hasCoreSignalCoverage)
    }

    // MARK: - Cross-layer integration

    func testSovereignSummaryFeedsReconciliationReport() async throws {
        let ledger = BASSovereignAuditLedger.withSeed("m38-report")
        _ = try await ledger.append(
            makeEntry(auditID: "a-1", verdict: "v-a"))
        let summary = await ledger.coverageSummary(
            turnID: "t-1", sessionID: "s-1", emittedAt: t0)
        let report = BASObservationReconciliationReport(
            turnID: "t-1", sessionID: "s-1",
            summaries: [summary])
        XCTAssertEqual(report.coveredLayers, [.sovereign])
        XCTAssertTrue(
            report.isFullyObserved(expected: [.sovereign]))
    }
}
