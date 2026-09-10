import XCTest
@testable import BASWorldPrior

final class BASWorldPriorObservationTests: XCTestCase {
    // MARK: - Helpers

    private func observation(
        _ kind: BASWorldPriorSignalKind,
        template: String = "tpl-1",
        evidence: BASWorldPriorEvidenceLevel = .plausible,
        salience: Double = 0.5,
        confidence: Double = 0.5,
        content: String = "obs"
    ) -> BASWorldPriorObservation {
        BASWorldPriorObservation(
            kind: kind,
            templateID: template,
            evidenceLevel: evidence,
            salience: salience,
            confidence: confidence,
            content: content,
            observedAt: Date(timeIntervalSince1970: 0))
    }

    private func bundle(
        turn: String = "t1",
        session: String = "s1",
        observations: [BASWorldPriorObservation]
    ) -> BASWorldPriorObservationBundle {
        BASWorldPriorObservationBundle(
            turnID: turn,
            sessionID: session,
            observations: observations,
            emittedAt: Date(timeIntervalSince1970: 0))
    }

    // MARK: - Clamping

    func testObservationClampsSalienceAndConfidence() {
        let obs = BASWorldPriorObservation(
            kind: .templateMatched,
            templateID: "tpl-1",
            evidenceLevel: .plausible,
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
            observation(.templateMatched, template: "a"),
            observation(.counterfactualSeeded, template: "a"),
            observation(.templateMatched, template: "b"),
            observation(.domainBridgeCrossed, template: "a")
        ])
        XCTAssertEqual(b.observations(of: .templateMatched).count, 2)
        XCTAssertEqual(b.observations(of: .counterfactualSeeded).count, 1)
        XCTAssertEqual(b.observations(of: .domainBridgeCrossed).count, 1)
    }

    func testObservationsForTemplateGroupsAcrossKinds() {
        let b = bundle(observations: [
            observation(.templateMatched, template: "a"),
            observation(.counterfactualSeeded, template: "a"),
            observation(.templateMatched, template: "b"),
            observation(.evidenceRevised, template: "a")
        ])
        let a = b.observations(forTemplate: "a")
        XCTAssertEqual(a.count, 3)
        XCTAssertEqual(
            a.map { $0.kind },
            [.templateMatched, .counterfactualSeeded, .evidenceRevised])
    }

    func testTemplateIDsPreserveFirstSeenOrder() {
        let b = bundle(observations: [
            observation(.templateMatched, template: "beta"),
            observation(.counterfactualSeeded, template: "alpha"),
            observation(.templateMatched, template: "gamma"),
            observation(.domainBridgeCrossed, template: "beta")
        ])
        XCTAssertEqual(b.templateIDs, ["beta", "alpha", "gamma"])
    }

    // MARK: - Evidence level

    func testHighestEvidenceLevelPicksMaxAcrossTemplate() {
        let b = bundle(observations: [
            observation(
                .templateMatched,
                template: "a",
                evidence: .plausible),
            observation(
                .counterfactualSeeded,
                template: "a",
                evidence: .wellSupported),
            observation(
                .evidenceRevised,
                template: "a",
                evidence: .speculative)
        ])
        XCTAssertEqual(
            b.highestEvidenceLevel(forTemplate: "a"),
            .wellSupported)
    }

    func testHighestEvidenceLevelIsNilForAbsentTemplate() {
        let b = bundle(observations: [
            observation(.templateMatched, template: "a")
        ])
        XCTAssertNil(b.highestEvidenceLevel(forTemplate: "nope"))
    }

    func testHighestEvidenceLevelRespectsAxiomaticRank() {
        let b = bundle(observations: [
            observation(
                .boundaryBedrockConsulted,
                template: "bedrock",
                evidence: .axiomatic),
            observation(
                .templateMatched,
                template: "bedrock",
                evidence: .contested)
        ])
        XCTAssertEqual(
            b.highestEvidenceLevel(forTemplate: "bedrock"),
            .axiomatic)
    }

    // MARK: - Contradiction

    func testPriorContradictionTrueWhenSignaled() {
        let b = bundle(observations: [
            observation(.templateMatched, template: "a"),
            observation(.priorContradiction, template: "a")
        ])
        XCTAssertTrue(b.priorContradiction(forTemplate: "a"))
    }

    func testPriorContradictionFalseWhenOnlyMatch() {
        let b = bundle(observations: [
            observation(.templateMatched, template: "a"),
            observation(.counterfactualSeeded, template: "a")
        ])
        XCTAssertFalse(b.priorContradiction(forTemplate: "a"))
    }

    // MARK: - Core coverage

    func testCoreSignalCoverageMatchPlusCounterfactual() {
        let b = bundle(observations: [
            observation(.templateMatched),
            observation(.counterfactualSeeded)
        ])
        XCTAssertTrue(b.hasCoreSignalCoverage)
    }

    func testCoreSignalCoverageMatchPlusBedrock() {
        let b = bundle(observations: [
            observation(.templateMatched),
            observation(.boundaryBedrockConsulted)
        ])
        XCTAssertTrue(b.hasCoreSignalCoverage)
    }

    func testCoreSignalCoverageFailsWithoutMatch() {
        let b = bundle(observations: [
            observation(.counterfactualSeeded),
            observation(.boundaryBedrockConsulted)
        ])
        XCTAssertFalse(b.hasCoreSignalCoverage)
    }

    func testCoreSignalCoverageFailsWithOnlyMatch() {
        let b = bundle(observations: [
            observation(.templateMatched),
            observation(.evidenceRevised)
        ])
        XCTAssertFalse(b.hasCoreSignalCoverage)
    }

    func testCoreSignalCoverageEmpty() {
        let b = bundle(observations: [])
        XCTAssertFalse(b.hasCoreSignalCoverage)
    }

    // MARK: - Budget

    func testBudgetTotalCostSumsPerSignalCosts() {
        // templateMatched(0.10) + counterfactualSeeded(0.30)
        //   + boundaryBedrock(0.15) = 0.55
        let b = bundle(observations: [
            observation(.templateMatched),
            observation(.counterfactualSeeded),
            observation(.boundaryBedrockConsulted)
        ])
        XCTAssertEqual(
            BASWorldPriorObservationBudget.totalCost(for: b),
            0.55,
            accuracy: 1e-9)
    }

    func testBudgetTotalCostClampsAtOne() {
        let many = (0..<20).map { _ in
            observation(.counterfactualSeeded)
        }
        let b = bundle(observations: many)
        XCTAssertEqual(
            BASWorldPriorObservationBudget.totalCost(for: b),
            1.0,
            accuracy: 1e-9)
    }

    func testBudgetPerSignalTableIsExhaustive() {
        for kind in BASWorldPriorSignalKind.allCases {
            let cost = BASWorldPriorObservationBudget.cost(for: kind)
            XCTAssertGreaterThanOrEqual(
                cost, 0, "signal \(kind) has negative cost")
            XCTAssertLessThanOrEqual(
                cost, 1, "signal \(kind) cost > 1")
        }
    }

    func testBudgetCounterfactualIsMostExpensiveSignal() {
        let sorted = BASWorldPriorObservationBudget.signalCost
            .sorted { $0.value < $1.value }
        XCTAssertEqual(sorted.last?.key, .counterfactualSeeded)
    }

    // MARK: - Ledger

    func testLedgerAppendsAndSnapshots() async {
        let ledger = BASWorldPriorObservationLedger(capacity: 8)
        let b1 = bundle(
            turn: "t-1",
            observations: [observation(.templateMatched)])
        let b2 = bundle(
            turn: "t-2",
            observations: [observation(.counterfactualSeeded)])
        await ledger.record(b1)
        await ledger.record(b2)

        let snapshot = await ledger.snapshot()
        XCTAssertEqual(snapshot.count, 2)
        XCTAssertEqual(snapshot.map { $0.turnID }, ["t-1", "t-2"])
    }

    func testLedgerRingCapsAtConfiguredCapacity() async {
        let ledger = BASWorldPriorObservationLedger(capacity: 3)
        for i in 0..<10 {
            await ledger.record(
                bundle(
                    turn: "t-\(i)",
                    observations: [observation(.templateMatched)]))
        }
        let snapshot = await ledger.snapshot()
        XCTAssertEqual(snapshot.count, 3)
        XCTAssertEqual(
            snapshot.map { $0.turnID }, ["t-7", "t-8", "t-9"])
    }

    func testLedgerFiltersBySession() async {
        let ledger = BASWorldPriorObservationLedger(capacity: 16)
        await ledger.record(
            bundle(
                turn: "t-a",
                session: "alpha",
                observations: [observation(.templateMatched)]))
        await ledger.record(
            bundle(
                turn: "t-b",
                session: "beta",
                observations: [observation(.counterfactualSeeded)]))
        await ledger.record(
            bundle(
                turn: "t-c",
                session: "alpha",
                observations: [observation(.domainBridgeCrossed)]))

        let alpha = await ledger.bundles(forSession: "alpha")
        XCTAssertEqual(alpha.map { $0.turnID }, ["t-a", "t-c"])
        let beta = await ledger.bundles(forSession: "beta")
        XCTAssertEqual(beta.map { $0.turnID }, ["t-b"])
    }

    func testLedgerLooksUpBundleByTurnID() async {
        let ledger = BASWorldPriorObservationLedger(capacity: 8)
        await ledger.record(
            bundle(
                turn: "t-x",
                observations: [observation(.templateMatched)]))
        let found = await ledger.bundle(forTurn: "t-x")
        XCTAssertEqual(found?.turnID, "t-x")
        let missing = await ledger.bundle(forTurn: "nope")
        XCTAssertNil(missing)
    }

    func testLedgerClearEmpties() async {
        let ledger = BASWorldPriorObservationLedger(capacity: 4)
        await ledger.record(
            bundle(
                turn: "t-1",
                observations: [observation(.templateMatched)]))
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
                    .templateMatched,
                    template: "a",
                    evidence: .wellSupported,
                    salience: 0.3),
                observation(
                    .counterfactualSeeded,
                    template: "a",
                    evidence: .speculative,
                    salience: 0.7,
                    confidence: 0.8),
                observation(
                    .boundaryBedrockConsulted,
                    template: "bedrock",
                    evidence: .axiomatic,
                    salience: 0.5)
            ])

        let data = try JSONEncoder().encode(b)
        let decoded = try JSONDecoder().decode(
            BASWorldPriorObservationBundle.self, from: data)
        XCTAssertEqual(decoded, b)
    }
}
