import XCTest
@testable import BASOrchestration

final class BASPresenceObservationTests: XCTestCase {
    // MARK: - Helpers

    private func observation(
        _ channel: BASPresenceChannel,
        salience: Double = 0.5,
        confidence: Double = 0.5,
        content: String = "obs"
    ) -> BASPresenceObservation {
        BASPresenceObservation(
            channel: channel,
            salience: salience,
            confidence: confidence,
            content: content,
            observedAt: Date(timeIntervalSince1970: 0))
    }

    private func bundle(
        turn: String = "t1",
        session: String = "s1",
        observations: [BASPresenceObservation]
    ) -> BASPresenceObservationBundle {
        BASPresenceObservationBundle(
            turnID: turn,
            sessionID: session,
            observations: observations,
            emittedAt: Date(timeIntervalSince1970: 0))
    }

    // MARK: - Observation clamping

    func testObservationClampsSalienceAndConfidence() {
        let obs = BASPresenceObservation(
            channel: .task,
            salience: 3.7,
            confidence: -0.4,
            content: "high",
            observedAt: Date())
        XCTAssertEqual(obs.salience, 1.0)
        XCTAssertEqual(obs.confidence, 0.0)
    }

    // MARK: - Channel filtering

    func testObservationsForChannelReturnsOnlyMatchingChannel() {
        let b = bundle(observations: [
            observation(.task, salience: 0.3),
            observation(.risk, salience: 0.7),
            observation(.task, salience: 0.9),
            observation(.manipulation, salience: 0.5)
        ])
        let tasks = b.observations(for: .task)
        XCTAssertEqual(tasks.count, 2)
        XCTAssertEqual(tasks.map { $0.salience }, [0.3, 0.9])
    }

    func testDominantObservationPicksHighestSalience() {
        let b = bundle(observations: [
            observation(.risk, salience: 0.3),
            observation(.risk, salience: 0.9),
            observation(.risk, salience: 0.5)
        ])
        let dominant = b.dominantObservation(for: .risk)
        XCTAssertEqual(dominant?.salience, 0.9)
    }

    func testDominantObservationIsNilWhenChannelAbsent() {
        let b = bundle(observations: [observation(.task)])
        XCTAssertNil(b.dominantObservation(for: .manipulation))
    }

    // MARK: - Core channel coverage

    func testCoreChannelCoverageRequiresTaskRiskAndManipulation() {
        let full = bundle(observations: [
            observation(.task),
            observation(.risk),
            observation(.manipulation),
            observation(.environment)
        ])
        XCTAssertTrue(full.hasCoreChannelCoverage)

        let missingManipulation = bundle(observations: [
            observation(.task),
            observation(.risk),
            observation(.environment)
        ])
        XCTAssertFalse(missingManipulation.hasCoreChannelCoverage)

        let taskOnly = bundle(observations: [observation(.task)])
        XCTAssertFalse(taskOnly.hasCoreChannelCoverage)

        let empty = bundle(observations: [])
        XCTAssertFalse(empty.hasCoreChannelCoverage)
    }

    // MARK: - Budget

    func testBudgetTotalCostSumsPerChannelCosts() {
        // task(0.10) + risk(0.25) + manipulation(0.30) = 0.65
        let b = bundle(observations: [
            observation(.task),
            observation(.risk),
            observation(.manipulation)
        ])
        XCTAssertEqual(
            BASPresenceObservationBudget.totalCost(for: b),
            0.65,
            accuracy: 1e-9)
    }

    func testBudgetTotalCostClampsAtOne() {
        // All five channels + extras → well over 1.0, should clamp.
        let many = (0..<20).map { _ in observation(.manipulation) }
        let b = bundle(observations: many)
        XCTAssertEqual(
            BASPresenceObservationBudget.totalCost(for: b),
            1.0,
            accuracy: 1e-9)
    }

    func testBudgetPerChannelTableIsExhaustive() {
        for channel in BASPresenceChannel.allCases {
            let cost = BASPresenceObservationBudget.cost(for: channel)
            XCTAssertGreaterThanOrEqual(
                cost, 0, "channel \(channel) has negative cost")
            XCTAssertLessThanOrEqual(
                cost, 1, "channel \(channel) cost > 1")
        }
    }

    // MARK: - Ledger

    func testLedgerAppendsAndSnapshots() async {
        let ledger = BASPresenceObservationLedger(capacity: 8)
        let b1 = bundle(turn: "t-1", observations: [observation(.task)])
        let b2 = bundle(turn: "t-2", observations: [observation(.risk)])
        await ledger.record(b1)
        await ledger.record(b2)

        let snapshot = await ledger.snapshot()
        XCTAssertEqual(snapshot.count, 2)
        XCTAssertEqual(snapshot.map { $0.turnID }, ["t-1", "t-2"])
    }

    func testLedgerRingCapsAtConfiguredCapacity() async {
        let ledger = BASPresenceObservationLedger(capacity: 3)
        for i in 0..<10 {
            await ledger.record(
                bundle(
                    turn: "t-\(i)",
                    observations: [observation(.task)]))
        }
        let snapshot = await ledger.snapshot()
        XCTAssertEqual(snapshot.count, 3)
        XCTAssertEqual(
            snapshot.map { $0.turnID }, ["t-7", "t-8", "t-9"])
    }

    func testLedgerFiltersBySession() async {
        let ledger = BASPresenceObservationLedger(capacity: 16)
        await ledger.record(
            bundle(
                turn: "t-a",
                session: "alpha",
                observations: [observation(.task)]))
        await ledger.record(
            bundle(
                turn: "t-b",
                session: "beta",
                observations: [observation(.risk)]))
        await ledger.record(
            bundle(
                turn: "t-c",
                session: "alpha",
                observations: [observation(.manipulation)]))

        let alpha = await ledger.bundles(forSession: "alpha")
        XCTAssertEqual(alpha.map { $0.turnID }, ["t-a", "t-c"])
        let beta = await ledger.bundles(forSession: "beta")
        XCTAssertEqual(beta.map { $0.turnID }, ["t-b"])
    }

    func testLedgerLooksUpBundleByTurnID() async {
        let ledger = BASPresenceObservationLedger(capacity: 8)
        await ledger.record(
            bundle(turn: "t-x", observations: [observation(.task)]))
        let found = await ledger.bundle(forTurn: "t-x")
        XCTAssertEqual(found?.turnID, "t-x")
        let missing = await ledger.bundle(forTurn: "nope")
        XCTAssertNil(missing)
    }

    func testLedgerClearEmpties() async {
        let ledger = BASPresenceObservationLedger(capacity: 4)
        await ledger.record(
            bundle(turn: "t-1", observations: [observation(.task)]))
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
                observation(.task, salience: 0.2),
                observation(.risk, salience: 0.7, confidence: 0.8),
                observation(.manipulation, salience: 0.1)
            ])

        let data = try JSONEncoder().encode(b)
        let decoded = try JSONDecoder().decode(
            BASPresenceObservationBundle.self, from: data)
        XCTAssertEqual(decoded, b)
    }
}
