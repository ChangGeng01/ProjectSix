import XCTest
@testable import BASOrchestration

final class BASCandidateObservationTests: XCTestCase {
    // MARK: - Helpers

    private func observation(
        _ kind: BASCandidateSignalKind,
        candidate: String = "c1",
        salience: Double = 0.5,
        confidence: Double = 0.5,
        content: String = "obs"
    ) -> BASCandidateObservation {
        BASCandidateObservation(
            kind: kind,
            candidateID: candidate,
            salience: salience,
            confidence: confidence,
            content: content,
            observedAt: Date(timeIntervalSince1970: 0))
    }

    private func bundle(
        turn: String = "t1",
        session: String = "s1",
        observations: [BASCandidateObservation]
    ) -> BASCandidateObservationBundle {
        BASCandidateObservationBundle(
            turnID: turn,
            sessionID: session,
            observations: observations,
            emittedAt: Date(timeIntervalSince1970: 0))
    }

    // MARK: - Observation clamping

    func testObservationClampsSalienceAndConfidence() {
        let obs = BASCandidateObservation(
            kind: .candidate,
            candidateID: "c-99",
            salience: 2.5,
            confidence: -0.7,
            content: "oops",
            observedAt: Date())
        XCTAssertEqual(obs.salience, 1.0)
        XCTAssertEqual(obs.confidence, 0.0)
    }

    // MARK: - Kind filtering

    func testObservationsOfKindReturnsOnlyMatching() {
        let b = bundle(observations: [
            observation(.candidate, candidate: "a"),
            observation(.guardianBranch, candidate: "g"),
            observation(.candidate, candidate: "b"),
            observation(.diversitySignal, candidate: "a")
        ])
        let cands = b.observations(of: .candidate)
        XCTAssertEqual(cands.count, 2)
        XCTAssertEqual(cands.map { $0.candidateID }, ["a", "b"])
    }

    // MARK: - Candidate grouping

    func testObservationsForCandidateGroupsAcrossKinds() {
        let b = bundle(observations: [
            observation(.candidate, candidate: "a"),
            observation(.reversibilitySignal, candidate: "a"),
            observation(.candidate, candidate: "b"),
            observation(.guardianBranch, candidate: "a")
        ])
        let a = b.observations(forCandidate: "a")
        XCTAssertEqual(a.count, 3)
        XCTAssertEqual(
            a.map { $0.kind },
            [.candidate, .reversibilitySignal, .guardianBranch])
    }

    func testCandidateIDsPreserveFirstSeenOrder() {
        let b = bundle(observations: [
            observation(.candidate, candidate: "beta"),
            observation(.dominanceSignal, candidate: "alpha"),
            observation(.candidate, candidate: "gamma"),
            observation(.guardianBranch, candidate: "alpha"),
            observation(.candidate, candidate: "beta")
        ])
        XCTAssertEqual(b.candidateIDs, ["beta", "alpha", "gamma"])
    }

    // MARK: - Dominant observation

    func testDominantObservationPicksHighestSalience() {
        let b = bundle(observations: [
            observation(.reversibilitySignal,
                        candidate: "a", salience: 0.3),
            observation(.reversibilitySignal,
                        candidate: "b", salience: 0.8),
            observation(.reversibilitySignal,
                        candidate: "c", salience: 0.5)
        ])
        let dominant = b.dominantObservation(of: .reversibilitySignal)
        XCTAssertEqual(dominant?.candidateID, "b")
        XCTAssertEqual(dominant?.salience, 0.8)
    }

    func testDominantObservationIsNilWhenKindAbsent() {
        let b = bundle(observations: [observation(.candidate)])
        XCTAssertNil(b.dominantObservation(of: .delayRecommendation))
    }

    // MARK: - Core signal coverage

    func testCoreSignalCoverageRequiresCandidateReversibilityGuardian() {
        let full = bundle(observations: [
            observation(.candidate),
            observation(.reversibilitySignal),
            observation(.guardianBranch),
            observation(.diversitySignal)
        ])
        XCTAssertTrue(full.hasCoreSignalCoverage)

        let missingGuardian = bundle(observations: [
            observation(.candidate),
            observation(.reversibilitySignal),
            observation(.dominanceSignal)
        ])
        XCTAssertFalse(missingGuardian.hasCoreSignalCoverage)

        let candOnly = bundle(observations: [observation(.candidate)])
        XCTAssertFalse(candOnly.hasCoreSignalCoverage)

        let empty = bundle(observations: [])
        XCTAssertFalse(empty.hasCoreSignalCoverage)
    }

    // MARK: - Budget

    func testBudgetTotalCostSumsPerSignalCosts() {
        // candidate(0.15) + reversibility(0.25) + guardian(0.30)
        // = 0.70
        let b = bundle(observations: [
            observation(.candidate),
            observation(.reversibilitySignal),
            observation(.guardianBranch)
        ])
        XCTAssertEqual(
            BASCandidateObservationBudget.totalCost(for: b),
            0.70,
            accuracy: 1e-9)
    }

    func testBudgetTotalCostClampsAtOne() {
        let many = (0..<20).map { _ in
            observation(.guardianBranch)
        }
        let b = bundle(observations: many)
        XCTAssertEqual(
            BASCandidateObservationBudget.totalCost(for: b),
            1.0,
            accuracy: 1e-9)
    }

    func testBudgetPerSignalTableIsExhaustive() {
        for kind in BASCandidateSignalKind.allCases {
            let cost = BASCandidateObservationBudget.cost(for: kind)
            XCTAssertGreaterThanOrEqual(
                cost, 0, "signal \(kind) has negative cost")
            XCTAssertLessThanOrEqual(
                cost, 1, "signal \(kind) cost > 1")
        }
    }

    func testBudgetGuardianBranchIsMostExpensiveSignal() {
        let sorted = BASCandidateObservationBudget.signalCost
            .sorted { $0.value < $1.value }
        XCTAssertEqual(sorted.last?.key, .guardianBranch)
    }

    // MARK: - Ledger

    func testLedgerAppendsAndSnapshots() async {
        let ledger = BASCandidateObservationLedger(capacity: 8)
        let b1 = bundle(
            turn: "t-1",
            observations: [observation(.candidate)])
        let b2 = bundle(
            turn: "t-2",
            observations: [observation(.guardianBranch)])
        await ledger.record(b1)
        await ledger.record(b2)

        let snapshot = await ledger.snapshot()
        XCTAssertEqual(snapshot.count, 2)
        XCTAssertEqual(snapshot.map { $0.turnID }, ["t-1", "t-2"])
    }

    func testLedgerRingCapsAtConfiguredCapacity() async {
        let ledger = BASCandidateObservationLedger(capacity: 3)
        for i in 0..<10 {
            await ledger.record(
                bundle(
                    turn: "t-\(i)",
                    observations: [observation(.candidate)]))
        }
        let snapshot = await ledger.snapshot()
        XCTAssertEqual(snapshot.count, 3)
        XCTAssertEqual(
            snapshot.map { $0.turnID }, ["t-7", "t-8", "t-9"])
    }

    func testLedgerFiltersBySession() async {
        let ledger = BASCandidateObservationLedger(capacity: 16)
        await ledger.record(
            bundle(
                turn: "t-a",
                session: "alpha",
                observations: [observation(.candidate)]))
        await ledger.record(
            bundle(
                turn: "t-b",
                session: "beta",
                observations: [observation(.reversibilitySignal)]))
        await ledger.record(
            bundle(
                turn: "t-c",
                session: "alpha",
                observations: [observation(.guardianBranch)]))

        let alpha = await ledger.bundles(forSession: "alpha")
        XCTAssertEqual(alpha.map { $0.turnID }, ["t-a", "t-c"])
        let beta = await ledger.bundles(forSession: "beta")
        XCTAssertEqual(beta.map { $0.turnID }, ["t-b"])
    }

    func testLedgerLooksUpBundleByTurnID() async {
        let ledger = BASCandidateObservationLedger(capacity: 8)
        await ledger.record(
            bundle(
                turn: "t-x",
                observations: [observation(.candidate)]))
        let found = await ledger.bundle(forTurn: "t-x")
        XCTAssertEqual(found?.turnID, "t-x")
        let missing = await ledger.bundle(forTurn: "nope")
        XCTAssertNil(missing)
    }

    func testLedgerClearEmpties() async {
        let ledger = BASCandidateObservationLedger(capacity: 4)
        await ledger.record(
            bundle(
                turn: "t-1",
                observations: [observation(.candidate)]))
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
                observation(.candidate,
                            candidate: "a", salience: 0.3),
                observation(.reversibilitySignal,
                            candidate: "a",
                            salience: 0.7,
                            confidence: 0.8),
                observation(.guardianBranch,
                            candidate: "g", salience: 0.5)
            ])

        let data = try JSONEncoder().encode(b)
        let decoded = try JSONDecoder().decode(
            BASCandidateObservationBundle.self, from: data)
        XCTAssertEqual(decoded, b)
    }
}
