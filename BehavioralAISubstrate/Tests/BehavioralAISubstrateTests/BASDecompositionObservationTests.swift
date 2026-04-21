import XCTest
@testable import BASOrchestration

final class BASDecompositionObservationTests: XCTestCase {
    // MARK: - Helpers

    private func observation(
        _ kind: BASDecompositionSignalKind,
        salience: Double = 0.5,
        confidence: Double = 0.5,
        content: String = "obs"
    ) -> BASDecompositionObservation {
        BASDecompositionObservation(
            kind: kind,
            salience: salience,
            confidence: confidence,
            content: content,
            observedAt: Date(timeIntervalSince1970: 0))
    }

    private func bundle(
        turn: String = "t1",
        session: String = "s1",
        observations: [BASDecompositionObservation]
    ) -> BASDecompositionObservationBundle {
        BASDecompositionObservationBundle(
            turnID: turn,
            sessionID: session,
            observations: observations,
            emittedAt: Date(timeIntervalSince1970: 0))
    }

    // MARK: - Observation clamping

    func testObservationClampsSalienceAndConfidence() {
        let obs = BASDecompositionObservation(
            kind: .factShard,
            salience: 4.2,
            confidence: -1.1,
            content: "huge",
            observedAt: Date())
        XCTAssertEqual(obs.salience, 1.0)
        XCTAssertEqual(obs.confidence, 0.0)
    }

    // MARK: - Kind filtering

    func testObservationsOfKindReturnsOnlyMatching() {
        let b = bundle(observations: [
            observation(.factShard, salience: 0.2),
            observation(.contradiction, salience: 0.6),
            observation(.factShard, salience: 0.9),
            observation(.manipulation, salience: 0.4)
        ])
        let facts = b.observations(of: .factShard)
        XCTAssertEqual(facts.count, 2)
        XCTAssertEqual(facts.map { $0.salience }, [0.2, 0.9])
    }

    func testDominantObservationPicksHighestSalience() {
        let b = bundle(observations: [
            observation(.contradiction, salience: 0.2),
            observation(.contradiction, salience: 0.7),
            observation(.contradiction, salience: 0.5)
        ])
        let dominant = b.dominantObservation(of: .contradiction)
        XCTAssertEqual(dominant?.salience, 0.7)
    }

    func testDominantObservationIsNilWhenKindAbsent() {
        let b = bundle(observations: [observation(.factShard)])
        XCTAssertNil(b.dominantObservation(of: .mirrorDraft))
    }

    // MARK: - Core signal coverage

    func testCoreSignalCoverageRequiresFactContradictionMirror() {
        let full = bundle(observations: [
            observation(.factShard),
            observation(.contradiction),
            observation(.mirrorDraft),
            observation(.pressure)
        ])
        XCTAssertTrue(full.hasCoreSignalCoverage)

        let missingMirror = bundle(observations: [
            observation(.factShard),
            observation(.contradiction),
            observation(.unknown)
        ])
        XCTAssertFalse(missingMirror.hasCoreSignalCoverage)

        let factOnly = bundle(observations: [
            observation(.factShard)
        ])
        XCTAssertFalse(factOnly.hasCoreSignalCoverage)

        let empty = bundle(observations: [])
        XCTAssertFalse(empty.hasCoreSignalCoverage)
    }

    // MARK: - Total salience

    func testTotalSalienceSumsObservations() {
        let b = bundle(observations: [
            observation(.factShard, salience: 0.2),
            observation(.contradiction, salience: 0.3),
            observation(.mirrorDraft, salience: 0.4)
        ])
        XCTAssertEqual(b.totalSalience, 0.9, accuracy: 1e-9)
    }

    // MARK: - Budget

    func testBudgetTotalCostSumsPerSignalCosts() {
        // factShard(0.10) + contradiction(0.25) + mirrorDraft(0.35)
        // = 0.70
        let b = bundle(observations: [
            observation(.factShard),
            observation(.contradiction),
            observation(.mirrorDraft)
        ])
        XCTAssertEqual(
            BASDecompositionObservationBudget.totalCost(for: b),
            0.70,
            accuracy: 1e-9)
    }

    func testBudgetTotalCostClampsAtOne() {
        let many = (0..<20).map { _ in observation(.mirrorDraft) }
        let b = bundle(observations: many)
        XCTAssertEqual(
            BASDecompositionObservationBudget.totalCost(for: b),
            1.0,
            accuracy: 1e-9)
    }

    func testBudgetPerSignalTableIsExhaustive() {
        for kind in BASDecompositionSignalKind.allCases {
            let cost = BASDecompositionObservationBudget
                .cost(for: kind)
            XCTAssertGreaterThanOrEqual(
                cost, 0, "signal \(kind) has negative cost")
            XCTAssertLessThanOrEqual(
                cost, 1, "signal \(kind) cost > 1")
        }
    }

    func testBudgetMirrorDraftIsMostExpensiveSignal() {
        let sorted = BASDecompositionObservationBudget.signalCost
            .sorted { $0.value < $1.value }
        XCTAssertEqual(sorted.last?.key, .mirrorDraft)
    }

    // MARK: - Ledger

    func testLedgerAppendsAndSnapshots() async {
        let ledger = BASDecompositionObservationLedger(capacity: 8)
        let b1 = bundle(
            turn: "t-1",
            observations: [observation(.factShard)])
        let b2 = bundle(
            turn: "t-2",
            observations: [observation(.contradiction)])
        await ledger.record(b1)
        await ledger.record(b2)

        let snapshot = await ledger.snapshot()
        XCTAssertEqual(snapshot.count, 2)
        XCTAssertEqual(
            snapshot.map { $0.turnID }, ["t-1", "t-2"])
    }

    func testLedgerRingCapsAtConfiguredCapacity() async {
        let ledger = BASDecompositionObservationLedger(capacity: 3)
        for i in 0..<10 {
            await ledger.record(
                bundle(
                    turn: "t-\(i)",
                    observations: [observation(.factShard)]))
        }
        let snapshot = await ledger.snapshot()
        XCTAssertEqual(snapshot.count, 3)
        XCTAssertEqual(
            snapshot.map { $0.turnID }, ["t-7", "t-8", "t-9"])
    }

    func testLedgerFiltersBySession() async {
        let ledger = BASDecompositionObservationLedger(capacity: 16)
        await ledger.record(
            bundle(
                turn: "t-a",
                session: "alpha",
                observations: [observation(.factShard)]))
        await ledger.record(
            bundle(
                turn: "t-b",
                session: "beta",
                observations: [observation(.contradiction)]))
        await ledger.record(
            bundle(
                turn: "t-c",
                session: "alpha",
                observations: [observation(.mirrorDraft)]))

        let alpha = await ledger.bundles(forSession: "alpha")
        XCTAssertEqual(alpha.map { $0.turnID }, ["t-a", "t-c"])
        let beta = await ledger.bundles(forSession: "beta")
        XCTAssertEqual(beta.map { $0.turnID }, ["t-b"])
    }

    func testLedgerLooksUpBundleByTurnID() async {
        let ledger = BASDecompositionObservationLedger(capacity: 8)
        await ledger.record(
            bundle(
                turn: "t-x",
                observations: [observation(.factShard)]))
        let found = await ledger.bundle(forTurn: "t-x")
        XCTAssertEqual(found?.turnID, "t-x")
        let missing = await ledger.bundle(forTurn: "nope")
        XCTAssertNil(missing)
    }

    func testLedgerClearEmpties() async {
        let ledger = BASDecompositionObservationLedger(capacity: 4)
        await ledger.record(
            bundle(
                turn: "t-1",
                observations: [observation(.factShard)]))
        await ledger.clear()
        let snapshot = await ledger.snapshot()
        XCTAssertTrue(snapshot.isEmpty)
    }

    // MARK: - Codable

    func testBundleIsCodableRoundTrip() throws {
        let b = bundle(
            turn: "t-rt",
            session: "s-rt",
            observations: [
                observation(.factShard, salience: 0.2),
                observation(
                    .contradiction, salience: 0.6, confidence: 0.8),
                observation(.mirrorDraft, salience: 0.4)
            ])

        let data = try JSONEncoder().encode(b)
        let decoded = try JSONDecoder().decode(
            BASDecompositionObservationBundle.self, from: data)
        XCTAssertEqual(decoded, b)
    }
}
