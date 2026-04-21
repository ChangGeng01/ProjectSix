import XCTest
@testable import BASPolicy

final class BASRiskObservationTests: XCTestCase {
    // MARK: - Helpers

    private func observation(
        _ kind: BASRiskSignalKind,
        intent: String = "i1",
        salience: Double = 0.5,
        confidence: Double = 0.5,
        content: String = "obs"
    ) -> BASRiskObservation {
        BASRiskObservation(
            kind: kind,
            intentID: intent,
            salience: salience,
            confidence: confidence,
            content: content,
            observedAt: Date(timeIntervalSince1970: 0))
    }

    private func bundle(
        turn: String = "t1",
        session: String = "s1",
        observations: [BASRiskObservation]
    ) -> BASRiskObservationBundle {
        BASRiskObservationBundle(
            turnID: turn,
            sessionID: session,
            observations: observations,
            emittedAt: Date(timeIntervalSince1970: 0))
    }

    // MARK: - Clamping

    func testObservationClampsSalienceAndConfidence() {
        let obs = BASRiskObservation(
            kind: .hazardReading,
            intentID: "i-1",
            salience: 2.5,
            confidence: -0.4,
            content: "high",
            observedAt: Date())
        XCTAssertEqual(obs.salience, 1.0)
        XCTAssertEqual(obs.confidence, 0.0)
    }

    // MARK: - Kind filtering

    func testObservationsOfKindReturnsOnlyMatching() {
        let b = bundle(observations: [
            observation(.hazardReading, intent: "a", salience: 0.3),
            observation(
                .irreversibilityReading, intent: "b", salience: 0.7),
            observation(.hazardReading, intent: "c", salience: 0.9)
        ])
        let hazards = b.observations(of: .hazardReading)
        XCTAssertEqual(hazards.count, 2)
        XCTAssertEqual(hazards.map { $0.salience }, [0.3, 0.9])
    }

    // MARK: - Intent grouping

    func testObservationsForIntentGroupsAcrossKinds() {
        let b = bundle(observations: [
            observation(.hazardReading, intent: "a"),
            observation(.irreversibilityReading, intent: "a"),
            observation(.hazardReading, intent: "b"),
            observation(.harmPotentialReading, intent: "a")
        ])
        let a = b.observations(forIntent: "a")
        XCTAssertEqual(a.count, 3)
        XCTAssertEqual(
            a.map { $0.kind },
            [.hazardReading,
             .irreversibilityReading,
             .harmPotentialReading])
    }

    func testIntentIDsPreserveFirstSeenOrder() {
        let b = bundle(observations: [
            observation(.hazardReading, intent: "beta"),
            observation(.gatePressure, intent: "alpha"),
            observation(.hazardReading, intent: "gamma"),
            observation(.noveltyReading, intent: "alpha"),
            observation(.hazardReading, intent: "beta")
        ])
        XCTAssertEqual(b.intentIDs, ["beta", "alpha", "gamma"])
    }

    // MARK: - Dominant observation

    func testDominantObservationPicksHighestSalience() {
        let b = bundle(observations: [
            observation(
                .harmPotentialReading, intent: "a", salience: 0.3),
            observation(
                .harmPotentialReading, intent: "b", salience: 0.8),
            observation(
                .harmPotentialReading, intent: "c", salience: 0.5)
        ])
        let dominant = b.dominantObservation(of: .harmPotentialReading)
        XCTAssertEqual(dominant?.intentID, "b")
        XCTAssertEqual(dominant?.salience, 0.8)
    }

    func testDominantObservationIsNilWhenKindAbsent() {
        let b = bundle(observations: [observation(.hazardReading)])
        XCTAssertNil(b.dominantObservation(of: .gatePressure))
    }

    // MARK: - Core coverage

    func testCoreSignalCoverageRequiresThreePillars() {
        let full = bundle(observations: [
            observation(.hazardReading),
            observation(.irreversibilityReading),
            observation(.harmPotentialReading),
            observation(.noveltyReading)
        ])
        XCTAssertTrue(full.hasCoreSignalCoverage)

        let missingHarm = bundle(observations: [
            observation(.hazardReading),
            observation(.irreversibilityReading),
            observation(.noveltyReading)
        ])
        XCTAssertFalse(missingHarm.hasCoreSignalCoverage)

        let hazardOnly = bundle(observations: [
            observation(.hazardReading)
        ])
        XCTAssertFalse(hazardOnly.hasCoreSignalCoverage)

        let empty = bundle(observations: [])
        XCTAssertFalse(empty.hasCoreSignalCoverage)
    }

    // MARK: - Peak salience

    func testPeakSalienceReturnsMaxForIntent() {
        let b = bundle(observations: [
            observation(.hazardReading, intent: "a", salience: 0.2),
            observation(
                .harmPotentialReading, intent: "a", salience: 0.8),
            observation(.hazardReading, intent: "b", salience: 1.0)
        ])
        XCTAssertEqual(b.peakSalience(forIntent: "a"), 0.8)
        XCTAssertEqual(b.peakSalience(forIntent: "b"), 1.0)
    }

    func testPeakSalienceIsZeroForAbsentIntent() {
        let b = bundle(observations: [
            observation(.hazardReading, intent: "a", salience: 0.5)
        ])
        XCTAssertEqual(b.peakSalience(forIntent: "nope"), 0)
    }

    // MARK: - Budget

    func testBudgetTotalCostSumsPerSignalCosts() {
        // hazard(0.15) + irrev(0.20) + harm(0.25) = 0.60
        let b = bundle(observations: [
            observation(.hazardReading),
            observation(.irreversibilityReading),
            observation(.harmPotentialReading)
        ])
        XCTAssertEqual(
            BASRiskObservationBudget.totalCost(for: b),
            0.60,
            accuracy: 1e-9)
    }

    func testBudgetTotalCostClampsAtOne() {
        let many = (0..<20).map { _ in
            observation(.consequenceHorizonReading)
        }
        let b = bundle(observations: many)
        XCTAssertEqual(
            BASRiskObservationBudget.totalCost(for: b),
            1.0,
            accuracy: 1e-9)
    }

    func testBudgetPerSignalTableIsExhaustive() {
        for kind in BASRiskSignalKind.allCases {
            let cost = BASRiskObservationBudget.cost(for: kind)
            XCTAssertGreaterThanOrEqual(
                cost, 0, "signal \(kind) has negative cost")
            XCTAssertLessThanOrEqual(
                cost, 1, "signal \(kind) cost > 1")
        }
    }

    func testBudgetConsequenceHorizonIsMostExpensiveSignal() {
        let sorted = BASRiskObservationBudget.signalCost
            .sorted { $0.value < $1.value }
        XCTAssertEqual(sorted.last?.key, .consequenceHorizonReading)
    }

    // MARK: - Ledger

    func testLedgerAppendsAndSnapshots() async {
        let ledger = BASRiskObservationLedger(capacity: 8)
        let b1 = bundle(
            turn: "t-1",
            observations: [observation(.hazardReading)])
        let b2 = bundle(
            turn: "t-2",
            observations: [observation(.harmPotentialReading)])
        await ledger.record(b1)
        await ledger.record(b2)

        let snapshot = await ledger.snapshot()
        XCTAssertEqual(snapshot.count, 2)
        XCTAssertEqual(snapshot.map { $0.turnID }, ["t-1", "t-2"])
    }

    func testLedgerRingCapsAtConfiguredCapacity() async {
        let ledger = BASRiskObservationLedger(capacity: 3)
        for i in 0..<10 {
            await ledger.record(
                bundle(
                    turn: "t-\(i)",
                    observations: [observation(.hazardReading)]))
        }
        let snapshot = await ledger.snapshot()
        XCTAssertEqual(snapshot.count, 3)
        XCTAssertEqual(
            snapshot.map { $0.turnID }, ["t-7", "t-8", "t-9"])
    }

    func testLedgerFiltersBySession() async {
        let ledger = BASRiskObservationLedger(capacity: 16)
        await ledger.record(
            bundle(
                turn: "t-a",
                session: "alpha",
                observations: [observation(.hazardReading)]))
        await ledger.record(
            bundle(
                turn: "t-b",
                session: "beta",
                observations: [observation(.irreversibilityReading)]))
        await ledger.record(
            bundle(
                turn: "t-c",
                session: "alpha",
                observations: [observation(.harmPotentialReading)]))

        let alpha = await ledger.bundles(forSession: "alpha")
        XCTAssertEqual(alpha.map { $0.turnID }, ["t-a", "t-c"])
        let beta = await ledger.bundles(forSession: "beta")
        XCTAssertEqual(beta.map { $0.turnID }, ["t-b"])
    }

    func testLedgerLooksUpBundleByTurnID() async {
        let ledger = BASRiskObservationLedger(capacity: 8)
        await ledger.record(
            bundle(
                turn: "t-x",
                observations: [observation(.hazardReading)]))
        let found = await ledger.bundle(forTurn: "t-x")
        XCTAssertEqual(found?.turnID, "t-x")
        let missing = await ledger.bundle(forTurn: "nope")
        XCTAssertNil(missing)
    }

    func testLedgerClearEmpties() async {
        let ledger = BASRiskObservationLedger(capacity: 4)
        await ledger.record(
            bundle(
                turn: "t-1",
                observations: [observation(.hazardReading)]))
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
                observation(
                    .hazardReading, intent: "a", salience: 0.3),
                observation(
                    .irreversibilityReading,
                    intent: "a",
                    salience: 0.7,
                    confidence: 0.8),
                observation(
                    .harmPotentialReading,
                    intent: "a",
                    salience: 0.5)
            ])

        let data = try JSONEncoder().encode(b)
        let decoded = try JSONDecoder().decode(
            BASRiskObservationBundle.self, from: data)
        XCTAssertEqual(decoded, b)
    }
}
