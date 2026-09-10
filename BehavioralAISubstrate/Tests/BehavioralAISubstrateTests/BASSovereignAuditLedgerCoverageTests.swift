import XCTest
@testable import BASRuntimeCore
@testable import BASSovereign

/// M45 — tests for the coverage-verdict storage + queries grafted onto
/// `BASSovereignAuditLedger`.
///
/// These are intentionally separated from the BR-012 hash-chain tests in
/// `BASSovereignAuditLedgerTests.swift`: coverage verdicts live in a
/// parallel array (they are structural reads of observation reports, not
/// sovereign verdicts) so the two concerns are audited independently.
final class BASSovereignAuditLedgerCoverageTests: XCTestCase {
    // MARK: - Helpers

    private func makeLedger(seed: String = "m45-coverage-seed")
        -> BASSovereignAuditLedger
    {
        BASSovereignAuditLedger.withSeed(seed)
    }

    private func makeVerdict(
        turn: String = "turn-1",
        session: String = "session-A",
        severity: BASObservationReconciliationSeverity = .clean,
        findings: [BASObservationReconciliationFinding] = [],
        emittedAt: Date = Date(timeIntervalSince1970: 1_700_000_000)
    ) -> BASObservationReconciliationVerdict {
        BASObservationReconciliationVerdict(
            turnID: turn,
            sessionID: session,
            severity: severity,
            findings: findings,
            emittedAt: emittedAt)
    }

    // MARK: - Empty-ledger semantics

    func testFreshLedgerHasNoCoverageVerdicts() async {
        let ledger = makeLedger()
        let count = await ledger.coverageVerdictCount()
        let snapshot = await ledger.coverageVerdictSnapshot()
        let lookup = await ledger.coverageVerdict(
            forSession: "session-A", turn: "turn-1")
        let perSession = await ledger.coverageVerdicts(
            forSession: "session-A")
        XCTAssertEqual(count, 0)
        XCTAssertTrue(snapshot.isEmpty)
        XCTAssertNil(lookup)
        XCTAssertTrue(perSession.isEmpty)
    }

    // MARK: - Record + query

    func testRecordSingleVerdictIsRetrievable() async {
        let ledger = makeLedger()
        let verdict = makeVerdict()
        await ledger.recordCoverageVerdict(verdict)

        let fetched = await ledger.coverageVerdict(
            forSession: "session-A", turn: "turn-1")
        XCTAssertEqual(fetched, verdict)

        let count = await ledger.coverageVerdictCount()
        XCTAssertEqual(count, 1)
    }

    func testRecordManyVerdictsAcrossTurnsIsOrdered() async {
        let ledger = makeLedger()
        let v1 = makeVerdict(turn: "turn-1")
        let v2 = makeVerdict(turn: "turn-2")
        let v3 = makeVerdict(turn: "turn-3")
        await ledger.recordCoverageVerdict(v1)
        await ledger.recordCoverageVerdict(v2)
        await ledger.recordCoverageVerdict(v3)

        let all = await ledger.coverageVerdicts(forSession: "session-A")
        XCTAssertEqual(all, [v1, v2, v3])
        let count = await ledger.coverageVerdictCount()
        XCTAssertEqual(count, 3)
    }

    func testPerSessionQueryFiltersOtherSessions() async {
        let ledger = makeLedger()
        let a1 = makeVerdict(turn: "turn-1", session: "session-A")
        let a2 = makeVerdict(turn: "turn-2", session: "session-A")
        let b1 = makeVerdict(turn: "turn-1", session: "session-B")
        await ledger.recordCoverageVerdict(a1)
        await ledger.recordCoverageVerdict(b1)
        await ledger.recordCoverageVerdict(a2)

        let sessionA = await ledger.coverageVerdicts(
            forSession: "session-A")
        let sessionB = await ledger.coverageVerdicts(
            forSession: "session-B")
        let totalCount = await ledger.coverageVerdictCount()

        XCTAssertEqual(sessionA, [a1, a2])
        XCTAssertEqual(sessionB, [b1])
        XCTAssertEqual(totalCount, 3)
    }

    // MARK: - Last-write-wins per (session, turn)

    func testReRecordingSameTurnReplacesInPlace() async {
        let ledger = makeLedger()
        let original = makeVerdict(severity: .clean)
        let replacement = makeVerdict(
            severity: .halt,
            findings: [.budgetOverspend(observed: 0.9, ceiling: 0.5)])
        await ledger.recordCoverageVerdict(original)
        await ledger.recordCoverageVerdict(replacement)

        let fetched = await ledger.coverageVerdict(
            forSession: "session-A", turn: "turn-1")
        let count = await ledger.coverageVerdictCount()
        let snapshot = await ledger.coverageVerdictSnapshot()

        XCTAssertEqual(fetched, replacement)
        XCTAssertEqual(count, 1)
        XCTAssertEqual(snapshot, [replacement])
    }

    func testReplacementPreservesFirstSeenOrder() async {
        let ledger = makeLedger()
        let v1 = makeVerdict(turn: "turn-1")
        let v2 = makeVerdict(turn: "turn-2")
        let v3 = makeVerdict(turn: "turn-3")
        await ledger.recordCoverageVerdict(v1)
        await ledger.recordCoverageVerdict(v2)
        await ledger.recordCoverageVerdict(v3)

        // Replace turn-2 with an advisory verdict; its slot in the
        // ordering must not move.
        let v2Replacement = makeVerdict(
            turn: "turn-2",
            severity: .advisory,
            findings: [.missingLayer(.worldPrior)])
        await ledger.recordCoverageVerdict(v2Replacement)

        let all = await ledger.coverageVerdicts(forSession: "session-A")
        XCTAssertEqual(all, [v1, v2Replacement, v3])
    }

    // MARK: - Isolation from hash-chain entries

    func testCoverageVerdictsDoNotAffectChainedEntryCount() async throws {
        let ledger = makeLedger()

        // Record coverage verdicts.
        await ledger.recordCoverageVerdict(makeVerdict(turn: "turn-1"))
        await ledger.recordCoverageVerdict(makeVerdict(turn: "turn-2"))

        // Chain-side `count()` must still be zero — coverage verdicts
        // never enter the hash-chained ledger.
        let chainCount = await ledger.count()
        let coverageCount = await ledger.coverageVerdictCount()
        XCTAssertEqual(chainCount, 0)
        XCTAssertEqual(coverageCount, 2)

        // Chain integrity is trivially OK on an empty chain.
        try await ledger.verifyChainIntegrity()
    }

    func testLookupMissesWhenTurnDoesNotMatch() async {
        let ledger = makeLedger()
        await ledger.recordCoverageVerdict(makeVerdict(turn: "turn-1"))
        let miss = await ledger.coverageVerdict(
            forSession: "session-A", turn: "turn-99")
        let sessionMiss = await ledger.coverageVerdict(
            forSession: "session-Z", turn: "turn-1")
        XCTAssertNil(miss)
        XCTAssertNil(sessionMiss)
    }
}
