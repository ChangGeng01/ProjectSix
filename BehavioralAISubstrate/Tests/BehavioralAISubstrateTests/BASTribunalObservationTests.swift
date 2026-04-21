import XCTest
@testable import BASOrchestration

final class BASTribunalObservationTests: XCTestCase {
    // MARK: - Helpers

    private func vote(
        _ voice: BASTribunalVoice,
        on subject: String,
        _ disposition: BASTribunalDisposition,
        salience: Double = 0.5,
        confidence: Double = 0.5
    ) -> BASTribunalObservation {
        BASTribunalObservation(
            kind: .vote,
            voice: voice,
            disposition: disposition,
            subjectID: subject,
            salience: salience,
            confidence: confidence,
            content: "vote-\(voice.rawValue)",
            observedAt: Date(timeIntervalSince1970: 0))
    }

    private func objection(
        by voice: BASTribunalVoice,
        on subject: String,
        salience: Double = 0.5
    ) -> BASTribunalObservation {
        BASTribunalObservation(
            kind: .objection,
            voice: voice,
            disposition: nil,
            subjectID: subject,
            salience: salience,
            confidence: 0.5,
            content: "obj",
            observedAt: Date(timeIntervalSince1970: 0))
    }

    private func convergence(
        on subject: String
    ) -> BASTribunalObservation {
        BASTribunalObservation(
            kind: .convergence,
            voice: nil,
            disposition: nil,
            subjectID: subject,
            salience: 0.5,
            confidence: 0.5,
            content: "conv",
            observedAt: Date(timeIntervalSince1970: 0))
    }

    private func bundle(
        turn: String = "t1",
        session: String = "s1",
        observations: [BASTribunalObservation]
    ) -> BASTribunalObservationBundle {
        BASTribunalObservationBundle(
            turnID: turn,
            sessionID: session,
            observations: observations,
            emittedAt: Date(timeIntervalSince1970: 0))
    }

    // MARK: - Clamping

    func testObservationClampsSalienceAndConfidence() {
        let obs = BASTribunalObservation(
            kind: .vote,
            voice: .baseSelf,
            disposition: .affirm,
            subjectID: "c-1",
            salience: 3.0,
            confidence: -2.0,
            content: "x",
            observedAt: Date())
        XCTAssertEqual(obs.salience, 1.0)
        XCTAssertEqual(obs.confidence, 0.0)
    }

    // MARK: - Kind / voice / subject filters

    func testObservationsOfKindReturnsOnlyMatching() {
        let b = bundle(observations: [
            vote(.baseSelf, on: "c-1", .affirm),
            objection(by: .ruleSelf, on: "c-1"),
            vote(.ruleSelf, on: "c-1", .oppose),
            convergence(on: "c-2")
        ])
        XCTAssertEqual(b.observations(of: .vote).count, 2)
        XCTAssertEqual(b.observations(of: .objection).count, 1)
        XCTAssertEqual(b.observations(of: .convergence).count, 1)
    }

    func testObservationsByVoiceExcludesTribunalWholeSignals() {
        let b = bundle(observations: [
            vote(.baseSelf, on: "c-1", .affirm),
            vote(.baseSelf, on: "c-2", .oppose),
            convergence(on: "c-1")
        ])
        let base = b.observations(by: .baseSelf)
        XCTAssertEqual(base.count, 2)
        XCTAssertTrue(base.allSatisfy { $0.voice == .baseSelf })
    }

    func testObservationsForSubjectIncludesAllKinds() {
        let b = bundle(observations: [
            vote(.baseSelf, on: "c-1", .affirm),
            vote(.ruleSelf, on: "c-2", .affirm),
            objection(by: .ruleSelf, on: "c-1"),
            convergence(on: "c-1")
        ])
        let target = b.observations(forSubject: "c-1")
        XCTAssertEqual(target.count, 3)
    }

    func testSubjectIDsPreserveFirstSeenOrder() {
        let b = bundle(observations: [
            vote(.baseSelf, on: "beta", .affirm),
            vote(.ruleSelf, on: "alpha", .affirm),
            vote(.aspireSelf, on: "beta", .oppose),
            convergence(on: "gamma")
        ])
        XCTAssertEqual(b.subjectIDs, ["beta", "alpha", "gamma"])
    }

    // MARK: - Tribunal quorum + agreement

    func testAllVoicesSpokeRequiresEveryVoiceToCastAVote() {
        let partial = bundle(observations: [
            vote(.baseSelf, on: "c-1", .affirm),
            vote(.ruleSelf, on: "c-1", .oppose)
        ])
        XCTAssertFalse(partial.allVoicesSpoke)

        let full = bundle(observations: [
            vote(.baseSelf, on: "c-1", .affirm),
            vote(.ruleSelf, on: "c-1", .affirm),
            vote(.aspireSelf, on: "c-1", .oppose)
        ])
        XCTAssertTrue(full.allVoicesSpoke)
    }

    func testAllVoicesSpokeIgnoresObjectionsAndConvergence() {
        let b = bundle(observations: [
            vote(.baseSelf, on: "c-1", .affirm),
            vote(.ruleSelf, on: "c-1", .affirm),
            objection(by: .aspireSelf, on: "c-1"),
            convergence(on: "c-1")
        ])
        // aspireSelf only objected, didn't vote → quorum fails.
        XCTAssertFalse(b.allVoicesSpoke)
    }

    func testVoteReturnsLatestVoteForVoiceOnSubject() {
        let b = bundle(observations: [
            vote(.baseSelf, on: "c-1", .affirm, salience: 0.2),
            vote(.baseSelf, on: "c-1", .oppose, salience: 0.8)
        ])
        let latest = b.vote(by: .baseSelf, on: "c-1")
        XCTAssertEqual(latest?.disposition, .oppose)
        XCTAssertEqual(latest?.salience, 0.8)
    }

    func testVoicesAgreeTrueWhenAllThreeMatch() {
        let b = bundle(observations: [
            vote(.baseSelf, on: "c-1", .affirm),
            vote(.ruleSelf, on: "c-1", .affirm),
            vote(.aspireSelf, on: "c-1", .affirm)
        ])
        XCTAssertTrue(b.voicesAgree(on: "c-1"))
    }

    func testVoicesAgreeFalseWhenOneDiffers() {
        let b = bundle(observations: [
            vote(.baseSelf, on: "c-1", .affirm),
            vote(.ruleSelf, on: "c-1", .affirm),
            vote(.aspireSelf, on: "c-1", .oppose)
        ])
        XCTAssertFalse(b.voicesAgree(on: "c-1"))
    }

    func testVoicesAgreeFalseWhenOneVoiceMissing() {
        let b = bundle(observations: [
            vote(.baseSelf, on: "c-1", .affirm),
            vote(.ruleSelf, on: "c-1", .affirm)
        ])
        XCTAssertFalse(b.voicesAgree(on: "c-1"))
    }

    // MARK: - Budget

    func testBudgetTotalCostSumsPerSignalCosts() {
        // 3 votes(0.10 ea) + 1 objection(0.25) = 0.55
        let b = bundle(observations: [
            vote(.baseSelf, on: "c-1", .affirm),
            vote(.ruleSelf, on: "c-1", .oppose),
            vote(.aspireSelf, on: "c-1", .affirm),
            objection(by: .ruleSelf, on: "c-1")
        ])
        XCTAssertEqual(
            BASTribunalObservationBudget.totalCost(for: b),
            0.55,
            accuracy: 1e-9)
    }

    func testBudgetTotalCostClampsAtOne() {
        let many = (0..<20).map { _ in
            objection(by: .ruleSelf, on: "c-1")
        }
        let b = bundle(observations: many)
        XCTAssertEqual(
            BASTribunalObservationBudget.totalCost(for: b),
            1.0,
            accuracy: 1e-9)
    }

    func testBudgetObjectionIsMostExpensiveSignal() {
        let sorted = BASTribunalObservationBudget.signalCost
            .sorted { $0.value < $1.value }
        XCTAssertEqual(sorted.last?.key, .objection)
    }

    // MARK: - Ledger

    func testLedgerAppendsAndSnapshots() async {
        let ledger = BASTribunalObservationLedger(capacity: 8)
        let b1 = bundle(
            turn: "t-1",
            observations: [vote(.baseSelf, on: "c-1", .affirm)])
        let b2 = bundle(
            turn: "t-2",
            observations: [vote(.ruleSelf, on: "c-1", .affirm)])
        await ledger.record(b1)
        await ledger.record(b2)

        let snapshot = await ledger.snapshot()
        XCTAssertEqual(snapshot.count, 2)
        XCTAssertEqual(snapshot.map { $0.turnID }, ["t-1", "t-2"])
    }

    func testLedgerRingCapsAtConfiguredCapacity() async {
        let ledger = BASTribunalObservationLedger(capacity: 3)
        for i in 0..<10 {
            await ledger.record(
                bundle(
                    turn: "t-\(i)",
                    observations: [
                        vote(.baseSelf, on: "c-\(i)", .affirm)
                    ]))
        }
        let snapshot = await ledger.snapshot()
        XCTAssertEqual(snapshot.count, 3)
        XCTAssertEqual(
            snapshot.map { $0.turnID }, ["t-7", "t-8", "t-9"])
    }

    func testLedgerClearEmpties() async {
        let ledger = BASTribunalObservationLedger(capacity: 4)
        await ledger.record(
            bundle(
                turn: "t-1",
                observations: [vote(.baseSelf, on: "c-1", .affirm)]))
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
                vote(.baseSelf, on: "c-1", .affirm, salience: 0.3),
                vote(.ruleSelf, on: "c-1", .oppose,
                     salience: 0.7, confidence: 0.8),
                objection(by: .ruleSelf, on: "c-1", salience: 0.6),
                convergence(on: "c-1")
            ])

        let data = try JSONEncoder().encode(b)
        let decoded = try JSONDecoder().decode(
            BASTribunalObservationBundle.self, from: data)
        XCTAssertEqual(decoded, b)
    }
}
