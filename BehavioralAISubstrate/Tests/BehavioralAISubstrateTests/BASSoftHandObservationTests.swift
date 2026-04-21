import XCTest
@testable import BASOrchestration

final class BASSoftHandObservationTests: XCTestCase {
    // MARK: - Helpers

    private func observation(
        _ kind: BASSoftHandSignalKind,
        mode: BASSoftHandMode,
        subject: String = "s-1",
        salience: Double = 0.5,
        confidence: Double = 0.5,
        content: String = "obs"
    ) -> BASSoftHandObservation {
        BASSoftHandObservation(
            kind: kind,
            mode: mode,
            subjectID: subject,
            salience: salience,
            confidence: confidence,
            content: content,
            observedAt: Date(timeIntervalSince1970: 0))
    }

    private func bundle(
        turn: String = "t1",
        session: String = "s1",
        observations: [BASSoftHandObservation]
    ) -> BASSoftHandObservationBundle {
        BASSoftHandObservationBundle(
            turnID: turn,
            sessionID: session,
            observations: observations,
            emittedAt: Date(timeIntervalSince1970: 0))
    }

    // MARK: - Clamping

    func testObservationClampsSalienceAndConfidence() {
        let obs = BASSoftHandObservation(
            kind: .render,
            mode: .compare,
            subjectID: "s-1",
            salience: 2.0,
            confidence: -0.3,
            content: "x",
            observedAt: Date())
        XCTAssertEqual(obs.salience, 1.0)
        XCTAssertEqual(obs.confidence, 0.0)
    }

    // MARK: - Filters

    func testObservationsOfKindReturnsOnlyMatching() {
        let b = bundle(observations: [
            observation(.suggestion, mode: .compare),
            observation(.selection, mode: .compare),
            observation(.suggestion, mode: .draft),
            observation(.render, mode: .compare)
        ])
        XCTAssertEqual(b.observations(of: .suggestion).count, 2)
        XCTAssertEqual(b.observations(of: .selection).count, 1)
        XCTAssertEqual(b.observations(of: .render).count, 1)
    }

    func testObservationsForModeGroupsAcrossKinds() {
        let b = bundle(observations: [
            observation(.suggestion, mode: .compare),
            observation(.selection, mode: .compare),
            observation(.render, mode: .compare),
            observation(.suggestion, mode: .draft)
        ])
        XCTAssertEqual(b.observations(forMode: .compare).count, 3)
        XCTAssertEqual(b.observations(forMode: .draft).count, 1)
    }

    func testObservationsForSubjectGroupsAcrossModes() {
        let b = bundle(observations: [
            observation(
                .selection, mode: .compare, subject: "a"),
            observation(
                .render, mode: .compare, subject: "a"),
            observation(
                .selection, mode: .boundary, subject: "b")
        ])
        XCTAssertEqual(b.observations(forSubject: "a").count, 2)
        XCTAssertEqual(b.observations(forSubject: "b").count, 1)
    }

    func testSubjectIDsPreserveFirstSeenOrder() {
        let b = bundle(observations: [
            observation(
                .suggestion, mode: .compare, subject: "beta"),
            observation(
                .suggestion, mode: .draft, subject: "alpha"),
            observation(
                .render, mode: .compare, subject: "beta")
        ])
        XCTAssertEqual(b.subjectIDs, ["beta", "alpha"])
    }

    // MARK: - Selected mode / rendered-as-selected

    func testSelectedModeReturnsLatestSelection() {
        let b = bundle(observations: [
            observation(.selection, mode: .draft),
            observation(.selection, mode: .compare)
        ])
        XCTAssertEqual(b.selectedMode, .compare)
    }

    func testSelectedModeIsNilWhenNoSelection() {
        let b = bundle(observations: [
            observation(.suggestion, mode: .draft)
        ])
        XCTAssertNil(b.selectedMode)
    }

    func testRenderedAsSelectedTrueWhenRenderMatchesSelection() {
        let b = bundle(observations: [
            observation(.selection, mode: .compare),
            observation(.render, mode: .compare)
        ])
        XCTAssertTrue(b.renderedAsSelected)
    }

    func testRenderedAsSelectedFalseWhenRenderDiffers() {
        let b = bundle(observations: [
            observation(.selection, mode: .compare),
            observation(.render, mode: .silentStub)
        ])
        XCTAssertFalse(b.renderedAsSelected)
    }

    func testRenderedAsSelectedFalseWhenNoRender() {
        let b = bundle(observations: [
            observation(.selection, mode: .compare)
        ])
        XCTAssertFalse(b.renderedAsSelected)
    }

    // MARK: - Core coverage

    func testCoreSignalCoverageRequiresSelectionAndRender() {
        let full = bundle(observations: [
            observation(.suggestion, mode: .compare),
            observation(.selection, mode: .compare),
            observation(.render, mode: .compare)
        ])
        XCTAssertTrue(full.hasCoreSignalCoverage)

        let missingRender = bundle(observations: [
            observation(.suggestion, mode: .compare),
            observation(.selection, mode: .compare)
        ])
        XCTAssertFalse(missingRender.hasCoreSignalCoverage)

        let missingSelection = bundle(observations: [
            observation(.render, mode: .compare)
        ])
        XCTAssertFalse(missingSelection.hasCoreSignalCoverage)

        let empty = bundle(observations: [])
        XCTAssertFalse(empty.hasCoreSignalCoverage)
    }

    // MARK: - Budget

    func testBudgetTotalCostSumsPerSignalCosts() {
        // suggestion(0.10) + selection(0.10) + render(0.15) = 0.35
        let b = bundle(observations: [
            observation(.suggestion, mode: .compare),
            observation(.selection, mode: .compare),
            observation(.render, mode: .compare)
        ])
        XCTAssertEqual(
            BASSoftHandObservationBudget.totalCost(for: b),
            0.35,
            accuracy: 1e-9)
    }

    func testBudgetTotalCostClampsAtOne() {
        let many = (0..<20).map { _ in
            observation(.escalation, mode: .boundary)
        }
        let b = bundle(observations: many)
        XCTAssertEqual(
            BASSoftHandObservationBudget.totalCost(for: b),
            1.0,
            accuracy: 1e-9)
    }

    func testBudgetPerSignalTableIsExhaustive() {
        for kind in BASSoftHandSignalKind.allCases {
            let cost = BASSoftHandObservationBudget.cost(for: kind)
            XCTAssertGreaterThanOrEqual(
                cost, 0, "signal \(kind) has negative cost")
            XCTAssertLessThanOrEqual(
                cost, 1, "signal \(kind) cost > 1")
        }
    }

    func testBudgetEscalationIsMostExpensiveSignal() {
        let sorted = BASSoftHandObservationBudget.signalCost
            .sorted { $0.value < $1.value }
        XCTAssertEqual(sorted.last?.key, .escalation)
    }

    // MARK: - Ledger

    func testLedgerAppendsAndSnapshots() async {
        let ledger = BASSoftHandObservationLedger(capacity: 8)
        let b1 = bundle(
            turn: "t-1",
            observations: [observation(.selection, mode: .compare)])
        let b2 = bundle(
            turn: "t-2",
            observations: [observation(.render, mode: .compare)])
        await ledger.record(b1)
        await ledger.record(b2)

        let snapshot = await ledger.snapshot()
        XCTAssertEqual(snapshot.count, 2)
        XCTAssertEqual(snapshot.map { $0.turnID }, ["t-1", "t-2"])
    }

    func testLedgerRingCapsAtConfiguredCapacity() async {
        let ledger = BASSoftHandObservationLedger(capacity: 3)
        for i in 0..<10 {
            await ledger.record(
                bundle(
                    turn: "t-\(i)",
                    observations: [
                        observation(.selection, mode: .compare)
                    ]))
        }
        let snapshot = await ledger.snapshot()
        XCTAssertEqual(snapshot.count, 3)
        XCTAssertEqual(
            snapshot.map { $0.turnID }, ["t-7", "t-8", "t-9"])
    }

    func testLedgerClearEmpties() async {
        let ledger = BASSoftHandObservationLedger(capacity: 4)
        await ledger.record(
            bundle(
                turn: "t-1",
                observations: [
                    observation(.selection, mode: .compare)
                ]))
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
                    .suggestion,
                    mode: .compare,
                    salience: 0.3),
                observation(
                    .selection,
                    mode: .compare,
                    salience: 0.7,
                    confidence: 0.8),
                observation(
                    .render, mode: .compare, salience: 0.9)
            ])

        let data = try JSONEncoder().encode(b)
        let decoded = try JSONDecoder().decode(
            BASSoftHandObservationBundle.self, from: data)
        XCTAssertEqual(decoded, b)
    }
}
