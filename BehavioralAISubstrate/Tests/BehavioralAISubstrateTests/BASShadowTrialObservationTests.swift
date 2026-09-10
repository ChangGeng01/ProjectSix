import XCTest
@testable import BASMemory

final class BASShadowTrialObservationTests: XCTestCase {
    // MARK: - Helpers

    private func observation(
        _ kind: BASShadowTrialSignalKind,
        ticket: String = "tk-1",
        salience: Double = 0.5,
        confidence: Double = 0.5,
        content: String = "obs"
    ) -> BASShadowTrialObservation {
        BASShadowTrialObservation(
            kind: kind,
            ticketID: ticket,
            salience: salience,
            confidence: confidence,
            content: content,
            observedAt: Date(timeIntervalSince1970: 0))
    }

    private func bundle(
        turn: String = "t1",
        session: String = "s1",
        observations: [BASShadowTrialObservation]
    ) -> BASShadowTrialObservationBundle {
        BASShadowTrialObservationBundle(
            turnID: turn,
            sessionID: session,
            observations: observations,
            emittedAt: Date(timeIntervalSince1970: 0))
    }

    // MARK: - Clamping

    func testObservationClampsSalienceAndConfidence() {
        let obs = BASShadowTrialObservation(
            kind: .trialRun,
            ticketID: "tk-1",
            salience: 2.0,
            confidence: -0.4,
            content: "x",
            observedAt: Date())
        XCTAssertEqual(obs.salience, 1.0)
        XCTAssertEqual(obs.confidence, 0.0)
    }

    // MARK: - Filters

    func testObservationsOfKindReturnsOnlyMatching() {
        let b = bundle(observations: [
            observation(.ticketIssued, ticket: "a"),
            observation(.trialRun, ticket: "a"),
            observation(.parityVerified, ticket: "a"),
            observation(.ticketIssued, ticket: "b")
        ])
        XCTAssertEqual(b.observations(of: .ticketIssued).count, 2)
        XCTAssertEqual(b.observations(of: .trialRun).count, 1)
        XCTAssertEqual(b.observations(of: .parityVerified).count, 1)
    }

    func testObservationsForTicketGroupsAcrossKinds() {
        let b = bundle(observations: [
            observation(.ticketIssued, ticket: "a"),
            observation(.trialRun, ticket: "a"),
            observation(.ticketIssued, ticket: "b"),
            observation(.promotionVote, ticket: "a")
        ])
        let a = b.observations(forTicket: "a")
        XCTAssertEqual(a.count, 3)
        XCTAssertEqual(
            a.map { $0.kind },
            [.ticketIssued, .trialRun, .promotionVote])
    }

    func testTicketIDsPreserveFirstSeenOrder() {
        let b = bundle(observations: [
            observation(.ticketIssued, ticket: "beta"),
            observation(.trialRun, ticket: "alpha"),
            observation(.ticketIssued, ticket: "gamma"),
            observation(.trialRun, ticket: "beta")
        ])
        XCTAssertEqual(b.ticketIDs, ["beta", "alpha", "gamma"])
    }

    // MARK: - Core coverage

    func testCoreSignalCoverageRequiresIssueTrialAndParityOrRegression() {
        let fullParity = bundle(observations: [
            observation(.ticketIssued),
            observation(.trialRun),
            observation(.parityVerified)
        ])
        XCTAssertTrue(fullParity.hasCoreSignalCoverage)

        let fullRegression = bundle(observations: [
            observation(.ticketIssued),
            observation(.trialRun),
            observation(.regressionDetected)
        ])
        XCTAssertTrue(fullRegression.hasCoreSignalCoverage)

        let missingTrial = bundle(observations: [
            observation(.ticketIssued),
            observation(.parityVerified)
        ])
        XCTAssertFalse(missingTrial.hasCoreSignalCoverage)

        let missingVerdict = bundle(observations: [
            observation(.ticketIssued),
            observation(.trialRun),
            observation(.promotionVote)
        ])
        XCTAssertFalse(missingVerdict.hasCoreSignalCoverage)

        let empty = bundle(observations: [])
        XCTAssertFalse(empty.hasCoreSignalCoverage)
    }

    // MARK: - Net promotion score

    func testNetPromotionScoreCountsVotes() {
        let b = bundle(observations: [
            observation(.promotionVote, ticket: "a"),
            observation(.promotionVote, ticket: "a"),
            observation(.quarantineVote, ticket: "a"),
            observation(.promotionVote, ticket: "b"),
            observation(.quarantineVote, ticket: "b"),
            observation(.quarantineVote, ticket: "b")
        ])
        XCTAssertEqual(b.netPromotionScore(forTicket: "a"), 1)
        XCTAssertEqual(b.netPromotionScore(forTicket: "b"), -1)
    }

    func testNetPromotionScoreIsZeroForAbsentTicket() {
        let b = bundle(observations: [
            observation(.promotionVote, ticket: "a")
        ])
        XCTAssertEqual(b.netPromotionScore(forTicket: "nope"), 0)
    }

    // MARK: - Regression detection

    func testRegressionDetectedTrueWhenSignaled() {
        let b = bundle(observations: [
            observation(.ticketIssued, ticket: "a"),
            observation(.regressionDetected, ticket: "a")
        ])
        XCTAssertTrue(b.regressionDetected(forTicket: "a"))
    }

    func testRegressionDetectedFalseWhenOnlyParity() {
        let b = bundle(observations: [
            observation(.ticketIssued, ticket: "a"),
            observation(.parityVerified, ticket: "a")
        ])
        XCTAssertFalse(b.regressionDetected(forTicket: "a"))
    }

    // MARK: - Budget

    func testBudgetTotalCostSumsPerSignalCosts() {
        // ticketIssued(0.10) + trialRun(0.40) + parity(0.20) = 0.70
        let b = bundle(observations: [
            observation(.ticketIssued),
            observation(.trialRun),
            observation(.parityVerified)
        ])
        XCTAssertEqual(
            BASShadowTrialObservationBudget.totalCost(for: b),
            0.70,
            accuracy: 1e-9)
    }

    func testBudgetTotalCostClampsAtOne() {
        let many = (0..<20).map { _ in observation(.trialRun) }
        let b = bundle(observations: many)
        XCTAssertEqual(
            BASShadowTrialObservationBudget.totalCost(for: b),
            1.0,
            accuracy: 1e-9)
    }

    func testBudgetPerSignalTableIsExhaustive() {
        for kind in BASShadowTrialSignalKind.allCases {
            let cost = BASShadowTrialObservationBudget.cost(for: kind)
            XCTAssertGreaterThanOrEqual(
                cost, 0, "signal \(kind) has negative cost")
            XCTAssertLessThanOrEqual(
                cost, 1, "signal \(kind) cost > 1")
        }
    }

    func testBudgetTrialRunIsMostExpensiveSignal() {
        let sorted = BASShadowTrialObservationBudget.signalCost
            .sorted { $0.value < $1.value }
        XCTAssertEqual(sorted.last?.key, .trialRun)
    }

    // MARK: - Ledger

    func testLedgerAppendsAndSnapshots() async {
        let ledger = BASShadowTrialObservationLedger(capacity: 8)
        let b1 = bundle(
            turn: "t-1",
            observations: [observation(.ticketIssued)])
        let b2 = bundle(
            turn: "t-2",
            observations: [observation(.trialRun)])
        await ledger.record(b1)
        await ledger.record(b2)

        let snapshot = await ledger.snapshot()
        XCTAssertEqual(snapshot.count, 2)
        XCTAssertEqual(snapshot.map { $0.turnID }, ["t-1", "t-2"])
    }

    func testLedgerRingCapsAtConfiguredCapacity() async {
        let ledger = BASShadowTrialObservationLedger(capacity: 3)
        for i in 0..<10 {
            await ledger.record(
                bundle(
                    turn: "t-\(i)",
                    observations: [observation(.ticketIssued)]))
        }
        let snapshot = await ledger.snapshot()
        XCTAssertEqual(snapshot.count, 3)
        XCTAssertEqual(
            snapshot.map { $0.turnID }, ["t-7", "t-8", "t-9"])
    }

    func testLedgerFiltersBySession() async {
        let ledger = BASShadowTrialObservationLedger(capacity: 16)
        await ledger.record(
            bundle(
                turn: "t-a",
                session: "alpha",
                observations: [observation(.ticketIssued)]))
        await ledger.record(
            bundle(
                turn: "t-b",
                session: "beta",
                observations: [observation(.trialRun)]))
        await ledger.record(
            bundle(
                turn: "t-c",
                session: "alpha",
                observations: [observation(.parityVerified)]))

        let alpha = await ledger.bundles(forSession: "alpha")
        XCTAssertEqual(alpha.map { $0.turnID }, ["t-a", "t-c"])
        let beta = await ledger.bundles(forSession: "beta")
        XCTAssertEqual(beta.map { $0.turnID }, ["t-b"])
    }

    func testLedgerLooksUpBundleByTurnID() async {
        let ledger = BASShadowTrialObservationLedger(capacity: 8)
        await ledger.record(
            bundle(
                turn: "t-x",
                observations: [observation(.ticketIssued)]))
        let found = await ledger.bundle(forTurn: "t-x")
        XCTAssertEqual(found?.turnID, "t-x")
        let missing = await ledger.bundle(forTurn: "nope")
        XCTAssertNil(missing)
    }

    func testLedgerClearEmpties() async {
        let ledger = BASShadowTrialObservationLedger(capacity: 4)
        await ledger.record(
            bundle(
                turn: "t-1",
                observations: [observation(.ticketIssued)]))
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
                    .ticketIssued, ticket: "a", salience: 0.3),
                observation(
                    .trialRun,
                    ticket: "a",
                    salience: 0.7,
                    confidence: 0.8),
                observation(
                    .parityVerified, ticket: "a", salience: 0.5)
            ])

        let data = try JSONEncoder().encode(b)
        let decoded = try JSONDecoder().decode(
            BASShadowTrialObservationBundle.self, from: data)
        XCTAssertEqual(decoded, b)
    }
}
