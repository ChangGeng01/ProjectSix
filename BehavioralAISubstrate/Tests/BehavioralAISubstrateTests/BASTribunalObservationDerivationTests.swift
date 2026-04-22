import XCTest
@testable import BASOrchestration

/// M55 — L10 tri-self tribunal main-chain wiring.
///
/// The M25 per-voice tribunal observation primitives (shape
/// covered by `BASTribunalObservationTests`) were originally
/// emitted only by hand-crafted test helpers; the coordinator never
/// produced a bundle at all. These tests pin the main-chain
/// behavior:
///
///   1. `BASTribunalObservationBundle.derive(from:turnID:
///      sessionID:emittedAt:)` emits a bundle whose contents
///      deterministically mirror the thought frame's tribunal
///      records (same frame → same bundle byte-for-byte).
///   2. Each of the four tribunal signal kinds (.vote / .objection
///      / .dissent / .convergence) is emitted iff the frame
///      carries structural evidence for it. An empty frame
///      produces zero observations.
///   3. Voice mapping is deterministic: baseSelf ← idScore,
///      ruleSelf ← superegoScore, aspireSelf ← egoScore. Veto
///      types map to specific voices. Dissent / convergence emit
///      with voice=nil (tribunal-level signals).
///   4. Signal payloads (salience / confidence / content) are
///      computed from the frame's records — no magic constants
///      smuggled in.
///   5. `BASThoughtFrame.withDerivedTribunalObservationBundle(...)`
///      returns a copy with the bundle attached and leaves every
///      other field untouched.
///   6. The bundle feeds the M32 `.triSelfTribunal` coverage
///      projection (`hasCoreSignalCoverage` == `allVoicesSpoke`).
///   7. Budget stays clamped in [0, 1] even when many signals are
///      emitted simultaneously.
///   8. Legacy pre-M55 frames (persisted without the new key)
///      decode with `tribunalObservationBundle == nil`.
final class BASTribunalObservationDerivationTests: XCTestCase {

    // MARK: - Fixtures

    private let fixedDate = Date(timeIntervalSince1970: 1_000_000)

    /// Builds a thought frame with only the tribunal-relevant
    /// records populated. Non-tribunal fields stay at their
    /// defaults — tests only need to control triScores / vetoMarks
    /// / remandOrders / courtDecisionDraft for the derive behavior
    /// to be testable.
    private func frame(
        triScores: [BASTriSelfScore] = [],
        vetoMarks: [BASVetoMark]? = nil,
        remandOrders: [BASRemandOrder]? = nil,
        courtDecisionDraft: BASCourtDecisionDraft? = nil
    ) -> BASThoughtFrame {
        BASThoughtFrame(
            stepIndex: 0,
            decomposeRef: "d-1",
            triScores: triScores,
            vetoMarks: vetoMarks,
            remandOrders: remandOrders,
            courtDecisionDraft: courtDecisionDraft
        )
    }

    private func triScore(
        candidateID: String = "cand-1",
        idScore: Double = 0.5,
        egoScore: Double = 0.5,
        superegoScore: Double = 0.5,
        mergedScore: Double = 0.5,
        veto: Bool = false
    ) -> BASTriSelfScore {
        BASTriSelfScore(
            candidateID: candidateID,
            idScore: idScore,
            egoScore: egoScore,
            superegoScore: superegoScore,
            mergedScore: mergedScore,
            veto: veto)
    }

    private func vetoMark(
        candidateID: String = "cand-1",
        vetoType: BASCourtVetoType = .boundary,
        reasonCodes: [String] = ["reason-a"],
        compensable: Bool = false
    ) -> BASVetoMark {
        BASVetoMark(
            candidateID: candidateID,
            vetoType: vetoType,
            reasonCodes: reasonCodes,
            compensable: compensable)
    }

    private func remandOrder(
        targetLayer: String = "L6",
        requiredWork: [String] = ["gather-more-facts"],
        reasonCodes: [String] = ["insufficient-evidence"]
    ) -> BASRemandOrder {
        BASRemandOrder(
            targetLayer: targetLayer,
            requiredWork: requiredWork,
            reasonCodes: reasonCodes)
    }

    private func courtDraft(
        preferredCandidateID: String = "cand-1",
        readinessLevel: String = "ready",
        fallbackCandidateIDs: [String] = [],
        requiredDisclosures: [String] = []
    ) -> BASCourtDecisionDraft {
        BASCourtDecisionDraft(
            preferredCandidateID: preferredCandidateID,
            fallbackCandidateIDs: fallbackCandidateIDs,
            requiredDisclosures: requiredDisclosures,
            readinessLevel: readinessLevel)
    }

    // MARK: - 1. Emission

    func testDeriveEmitsZeroObservationsOnTrulyEmptyFrame() {
        // A frame with no tribunal records at all must produce an
        // empty bundle — this is the "light turn" invariant the
        // tribunal contract shares with L6/L7/L9.
        let f = frame()
        let bundle = BASTribunalObservationBundle.derive(
            from: f,
            turnID: "t-1",
            sessionID: "s-1",
            emittedAt: fixedDate)

        XCTAssertTrue(bundle.observations.isEmpty)
        XCTAssertEqual(bundle.turnID, "t-1")
        XCTAssertEqual(bundle.sessionID, "s-1")
        XCTAssertEqual(bundle.emittedAt, fixedDate)
    }

    func testDeriveEmitsThreeVotesPerTriScore() {
        let f = frame(triScores: [
            triScore(candidateID: "a"),
            triScore(candidateID: "b")
        ])
        let bundle = BASTribunalObservationBundle.derive(
            from: f,
            turnID: "t",
            sessionID: "s",
            emittedAt: fixedDate)

        let votes = bundle.observations(of: .vote)
        XCTAssertEqual(votes.count, 6) // 3 voices × 2 candidates
        let voicesForA = Set(votes
            .filter { $0.subjectID == "a" }
            .compactMap { $0.voice })
        let voicesForB = Set(votes
            .filter { $0.subjectID == "b" }
            .compactMap { $0.voice })
        XCTAssertEqual(
            voicesForA,
            Set(BASTribunalVoice.allCases))
        XCTAssertEqual(
            voicesForB,
            Set(BASTribunalVoice.allCases))
    }

    func testDeriveEmitsObjectionPerVetoMark() {
        let f = frame(
            triScores: [triScore(candidateID: "cand-1")],
            vetoMarks: [
                vetoMark(candidateID: "cand-1", vetoType: .boundary),
                vetoMark(candidateID: "cand-1", vetoType: .dignity)
            ])
        let bundle = BASTribunalObservationBundle.derive(
            from: f,
            turnID: "t",
            sessionID: "s",
            emittedAt: fixedDate)

        let objections = bundle.observations(of: .objection)
        XCTAssertEqual(objections.count, 2)
    }

    func testDeriveEmitsDissentPerRemandOrder() {
        let f = frame(
            triScores: [triScore()],
            remandOrders: [
                remandOrder(targetLayer: "L6"),
                remandOrder(targetLayer: "L8")
            ])
        let bundle = BASTribunalObservationBundle.derive(
            from: f,
            turnID: "t",
            sessionID: "s",
            emittedAt: fixedDate)

        let dissents = bundle.observations(of: .dissent)
        XCTAssertEqual(dissents.count, 2)
        let subjects = Set(dissents.map { $0.subjectID })
        XCTAssertEqual(subjects, ["L6", "L8"])
    }

    func testDeriveEmitsConvergenceWhenVoicesAgreeAndNoVetos()
        throws
    {
        // All three voices affirm (score ≥ 0.6), no vetos, decision
        // draft exists → convergence must be emitted.
        let f = frame(
            triScores: [triScore(
                candidateID: "cand-1",
                idScore: 0.8,
                egoScore: 0.8,
                superegoScore: 0.8,
                mergedScore: 0.9)],
            courtDecisionDraft: courtDraft(
                preferredCandidateID: "cand-1"))
        let bundle = BASTribunalObservationBundle.derive(
            from: f,
            turnID: "t",
            sessionID: "s",
            emittedAt: fixedDate)

        let convergences = bundle.observations(of: .convergence)
        XCTAssertEqual(convergences.count, 1)
        let obs = try XCTUnwrap(convergences.first)
        XCTAssertNil(obs.voice)
        XCTAssertEqual(obs.subjectID, "cand-1")
        XCTAssertEqual(obs.salience, 1.0, accuracy: 1e-9)
    }

    func testDeriveSuppressesConvergenceWhenVetosPresent() {
        // Even with all voices agreeing, a lingering veto must
        // suppress the convergence signal — the tribunal hasn't
        // fully converged if a structural objection remains.
        let f = frame(
            triScores: [triScore(
                candidateID: "cand-1",
                idScore: 0.8,
                egoScore: 0.8,
                superegoScore: 0.8,
                mergedScore: 0.9)],
            vetoMarks: [vetoMark(candidateID: "cand-1")],
            courtDecisionDraft: courtDraft(
                preferredCandidateID: "cand-1"))
        let bundle = BASTribunalObservationBundle.derive(
            from: f,
            turnID: "t",
            sessionID: "s",
            emittedAt: fixedDate)

        XCTAssertTrue(bundle.observations(of: .convergence).isEmpty)
    }

    func testDeriveSuppressesConvergenceWhenVoicesDisagree() {
        // Voices disagree (one affirms, one opposes) → no
        // convergence even though a draft and no vetos exist.
        let f = frame(
            triScores: [triScore(
                candidateID: "cand-1",
                idScore: 0.8,       // affirm
                egoScore: 0.2,      // oppose
                superegoScore: 0.8, // affirm
                mergedScore: 0.6)],
            courtDecisionDraft: courtDraft(
                preferredCandidateID: "cand-1"))
        let bundle = BASTribunalObservationBundle.derive(
            from: f,
            turnID: "t",
            sessionID: "s",
            emittedAt: fixedDate)

        XCTAssertTrue(bundle.observations(of: .convergence).isEmpty)
    }

    func testDeriveSuppressesConvergenceWhenNoDecisionDraft() {
        // No decision draft → no convergence even if voices agree.
        let f = frame(
            triScores: [triScore(
                candidateID: "cand-1",
                idScore: 0.8,
                egoScore: 0.8,
                superegoScore: 0.8,
                mergedScore: 0.9)])
        let bundle = BASTribunalObservationBundle.derive(
            from: f,
            turnID: "t",
            sessionID: "s",
            emittedAt: fixedDate)

        XCTAssertTrue(bundle.observations(of: .convergence).isEmpty)
    }

    // MARK: - 2. Determinism

    func testDeriveIsDeterministicForSameFrame() {
        let f = frame(
            triScores: [
                triScore(candidateID: "a"),
                triScore(candidateID: "b")
            ],
            vetoMarks: [vetoMark(candidateID: "a")],
            remandOrders: [remandOrder()])
        let first = BASTribunalObservationBundle.derive(
            from: f,
            turnID: "t",
            sessionID: "s",
            emittedAt: fixedDate)
        let second = BASTribunalObservationBundle.derive(
            from: f,
            turnID: "t",
            sessionID: "s",
            emittedAt: fixedDate)
        XCTAssertEqual(first, second)
    }

    // MARK: - 3. Payload fidelity — voice mapping

    func testVoteVoiceToScoreMappingIsDeterministic() throws {
        // idScore → baseSelf (质我)
        // superegoScore → ruleSelf (律我)
        // egoScore → aspireSelf (向我)
        let f = frame(triScores: [triScore(
            candidateID: "cand-1",
            idScore: 0.1,
            egoScore: 0.5,
            superegoScore: 0.9,
            mergedScore: 0.5)])
        let bundle = BASTribunalObservationBundle.derive(
            from: f,
            turnID: "t",
            sessionID: "s",
            emittedAt: fixedDate)
        let baseVote = try XCTUnwrap(
            bundle.vote(by: .baseSelf, on: "cand-1"))
        let ruleVote = try XCTUnwrap(
            bundle.vote(by: .ruleSelf, on: "cand-1"))
        let aspireVote = try XCTUnwrap(
            bundle.vote(by: .aspireSelf, on: "cand-1"))
        XCTAssertEqual(baseVote.salience, 0.1, accuracy: 1e-9)
        XCTAssertEqual(ruleVote.salience, 0.9, accuracy: 1e-9)
        XCTAssertEqual(aspireVote.salience, 0.5, accuracy: 1e-9)
    }

    func testVoteDispositionFollowsScoreThresholds() throws {
        // Affirm >= 0.6, oppose <= 0.3, abstain otherwise.
        let f = frame(triScores: [triScore(
            candidateID: "cand-1",
            idScore: 0.8,         // affirm
            egoScore: 0.45,       // abstain
            superegoScore: 0.2,   // oppose
            mergedScore: 0.5)])
        let bundle = BASTribunalObservationBundle.derive(
            from: f,
            turnID: "t",
            sessionID: "s",
            emittedAt: fixedDate)
        let base = try XCTUnwrap(
            bundle.vote(by: .baseSelf, on: "cand-1"))
        let rule = try XCTUnwrap(
            bundle.vote(by: .ruleSelf, on: "cand-1"))
        let aspire = try XCTUnwrap(
            bundle.vote(by: .aspireSelf, on: "cand-1"))
        XCTAssertEqual(base.disposition, .affirm)
        XCTAssertEqual(rule.disposition, .oppose)
        XCTAssertEqual(aspire.disposition, .abstain)
    }

    func testVoteBoundaryThresholdsAreInclusive() throws {
        // Exactly 0.6 → affirm; exactly 0.3 → oppose.
        let f = frame(triScores: [triScore(
            candidateID: "cand-1",
            idScore: 0.6,         // affirm (>=)
            egoScore: 0.3,        // oppose (<=)
            superegoScore: 0.31,  // abstain (strictly between)
            mergedScore: 0.5)])
        let bundle = BASTribunalObservationBundle.derive(
            from: f,
            turnID: "t",
            sessionID: "s",
            emittedAt: fixedDate)
        let base = try XCTUnwrap(
            bundle.vote(by: .baseSelf, on: "cand-1"))
        let aspire = try XCTUnwrap(
            bundle.vote(by: .aspireSelf, on: "cand-1"))
        let rule = try XCTUnwrap(
            bundle.vote(by: .ruleSelf, on: "cand-1"))
        XCTAssertEqual(base.disposition, .affirm)
        XCTAssertEqual(aspire.disposition, .oppose)
        XCTAssertEqual(rule.disposition, .abstain)
    }

    func testVoteConfidenceIsMergedScore() throws {
        let f = frame(triScores: [triScore(
            candidateID: "cand-1",
            idScore: 0.4,
            egoScore: 0.5,
            superegoScore: 0.6,
            mergedScore: 0.77)])
        let bundle = BASTribunalObservationBundle.derive(
            from: f,
            turnID: "t",
            sessionID: "s",
            emittedAt: fixedDate)
        for voice in BASTribunalVoice.allCases {
            let v = try XCTUnwrap(
                bundle.vote(by: voice, on: "cand-1"))
            XCTAssertEqual(
                v.confidence,
                0.77,
                accuracy: 1e-9,
                "mergedScore should flow to confidence for \(voice)")
        }
    }

    // MARK: - 4. Payload fidelity — objection voice mapping

    func testObjectionVoiceFollowsVetoType() throws {
        let cases: [(BASCourtVetoType, BASTribunalVoice)] = [
            (.boundary, .ruleSelf),
            (.hostConstitution, .ruleSelf),
            (.sovereignPrecondition, .ruleSelf),
            (.dignity, .baseSelf),
            (.irreversibility, .aspireSelf),
            (.calibration, .aspireSelf)
        ]
        for (type, expectedVoice) in cases {
            let f = frame(
                triScores: [triScore()],
                vetoMarks: [vetoMark(vetoType: type)])
            let bundle = BASTribunalObservationBundle.derive(
                from: f,
                turnID: "t",
                sessionID: "s",
                emittedAt: fixedDate)
            let obj = try XCTUnwrap(
                bundle.observations(of: .objection).first)
            XCTAssertEqual(
                obj.voice,
                expectedVoice,
                "vetoType \(type) should map to \(expectedVoice)")
        }
    }

    func testObjectionSalienceTracksCompensability() throws {
        let fA = frame(
            triScores: [triScore()],
            vetoMarks: [vetoMark(compensable: false)])
        let fB = frame(
            triScores: [triScore()],
            vetoMarks: [vetoMark(compensable: true)])
        let bundleA = BASTribunalObservationBundle.derive(
            from: fA,
            turnID: "t",
            sessionID: "s",
            emittedAt: fixedDate)
        let bundleB = BASTribunalObservationBundle.derive(
            from: fB,
            turnID: "t",
            sessionID: "s",
            emittedAt: fixedDate)
        let objA = try XCTUnwrap(
            bundleA.observations(of: .objection).first)
        let objB = try XCTUnwrap(
            bundleB.observations(of: .objection).first)
        XCTAssertEqual(objA.salience, 1.0, accuracy: 1e-9)
        XCTAssertEqual(objB.salience, 0.7, accuracy: 1e-9)
    }

    // MARK: - 5. Payload fidelity — dissent + convergence

    func testDissentIsTribunalLevelSignalWithNilVoice() throws {
        let f = frame(
            triScores: [triScore()],
            remandOrders: [remandOrder(targetLayer: "L9")])
        let bundle = BASTribunalObservationBundle.derive(
            from: f,
            turnID: "t",
            sessionID: "s",
            emittedAt: fixedDate)
        let dissent = try XCTUnwrap(
            bundle.observations(of: .dissent).first)
        XCTAssertNil(dissent.voice)
        XCTAssertEqual(dissent.subjectID, "L9")
        XCTAssertEqual(dissent.salience, 0.8, accuracy: 1e-9)
        XCTAssertEqual(dissent.confidence, 1.0, accuracy: 1e-9)
    }

    func testConvergenceIsTribunalLevelSignalWithNilVoice() throws {
        let f = frame(
            triScores: [triScore(
                candidateID: "cand-1",
                idScore: 0.8,
                egoScore: 0.8,
                superegoScore: 0.8,
                mergedScore: 0.95)],
            courtDecisionDraft: courtDraft(
                preferredCandidateID: "cand-1",
                readinessLevel: "ready",
                fallbackCandidateIDs: ["cand-2"],
                requiredDisclosures: ["disclosure-a"]))
        let bundle = BASTribunalObservationBundle.derive(
            from: f,
            turnID: "t",
            sessionID: "s",
            emittedAt: fixedDate)
        let conv = try XCTUnwrap(
            bundle.observations(of: .convergence).first)
        XCTAssertNil(conv.voice)
        XCTAssertEqual(conv.subjectID, "cand-1")
        XCTAssertTrue(conv.content.contains("readiness:ready"))
        XCTAssertTrue(conv.content.contains("fallbacks:1"))
        XCTAssertTrue(conv.content.contains("disclosures:1"))
    }

    // MARK: - 6. withDerived helper contract

    func testWithDerivedBundleAttachesBundleOnCopy() {
        let f = frame(triScores: [triScore()])
        let enriched = f.withDerivedTribunalObservationBundle(
            turnID: "t-2",
            sessionID: "s-2",
            emittedAt: fixedDate)

        XCTAssertNil(f.tribunalObservationBundle)
        XCTAssertNotNil(enriched.tribunalObservationBundle)
        XCTAssertEqual(
            enriched.tribunalObservationBundle?.turnID, "t-2")
        XCTAssertEqual(
            enriched.tribunalObservationBundle?.sessionID, "s-2")
    }

    func testWithDerivedBundlePreservesEveryOtherField() {
        let f = frame(
            triScores: [triScore(candidateID: "cand-1")],
            vetoMarks: [vetoMark(candidateID: "cand-1")],
            remandOrders: [remandOrder()],
            courtDecisionDraft: courtDraft())

        let enriched = f.withDerivedTribunalObservationBundle(
            turnID: "t",
            sessionID: "s",
            emittedAt: fixedDate)

        XCTAssertEqual(enriched.triScores, f.triScores)
        XCTAssertEqual(enriched.vetoMarks, f.vetoMarks)
        XCTAssertEqual(enriched.remandOrders, f.remandOrders)
        XCTAssertEqual(
            enriched.courtDecisionDraft?.preferredCandidateID,
            f.courtDecisionDraft?.preferredCandidateID)
        XCTAssertEqual(enriched.stepIndex, f.stepIndex)
        XCTAssertEqual(enriched.decomposeRef, f.decomposeRef)
        XCTAssertEqual(enriched.schemaVersion, f.schemaVersion)
    }

    // MARK: - 7. M32 coverage projection integration

    func testBundleFeedsM32TriSelfTribunalCoverageProjection() {
        let f = frame(triScores: [
            triScore(candidateID: "cand-1"),
            triScore(candidateID: "cand-2")
        ])
        let bundle = BASTribunalObservationBundle.derive(
            from: f,
            turnID: "turn-xyz",
            sessionID: "session-xyz",
            emittedAt: fixedDate)

        let summary = bundle.coverageSummary
        XCTAssertEqual(summary.layer, .triSelfTribunal)
        XCTAssertEqual(summary.turnID, "turn-xyz")
        XCTAssertEqual(summary.sessionID, "session-xyz")
        // 2 distinct candidate subjects.
        XCTAssertEqual(summary.distinctSubjectCount, 2)
        // All three voices voted → core coverage.
        XCTAssertTrue(summary.hasCoreSignalCoverage)
    }

    func testCoreCoverageRequiresAllThreeVoicesVoting() {
        // An empty frame (no triScores) cannot satisfy core
        // coverage — at least one triScore is required to seed
        // votes from all three voices.
        let f = frame()
        let bundle = BASTribunalObservationBundle.derive(
            from: f,
            turnID: "t",
            sessionID: "s",
            emittedAt: fixedDate)
        XCTAssertFalse(bundle.coverageSummary.hasCoreSignalCoverage)
    }

    // MARK: - 8. Budget clamping

    func testBundleBudgetStaysClampedOnDenseEmission() {
        // A dense tribunal round: 4 candidates (12 votes),
        // 2 vetos, 2 remands, and a convergence. Votes alone are
        // 12 * 0.10 = 1.20 → must clamp to 1.0.
        let scores = (0..<4).map { i in
            triScore(
                candidateID: "cand-\(i)",
                idScore: 0.7,
                egoScore: 0.7,
                superegoScore: 0.7,
                mergedScore: 0.8)
        }
        let f = frame(
            triScores: scores,
            vetoMarks: [
                vetoMark(candidateID: "cand-0"),
                vetoMark(candidateID: "cand-1")
            ],
            remandOrders: [
                remandOrder(targetLayer: "L7"),
                remandOrder(targetLayer: "L8")
            ])
        let bundle = BASTribunalObservationBundle.derive(
            from: f,
            turnID: "t",
            sessionID: "s",
            emittedAt: fixedDate)

        let cost = BASTribunalObservationBudget
            .totalCost(for: bundle)
        XCTAssertEqual(cost, 1.0, accuracy: 1e-9)
    }

    // MARK: - 9. Backwards compatibility

    func testThoughtFrameNilBundleRoundTripsThroughCodable() throws {
        let f = frame()
        let data = try JSONEncoder().encode(f)
        let decoded = try JSONDecoder().decode(
            BASThoughtFrame.self, from: data)
        XCTAssertNil(decoded.tribunalObservationBundle)
    }

    func testThoughtFrameWithBundleRoundTripsThroughCodable()
        throws
    {
        let enriched = frame(
            triScores: [triScore(candidateID: "cand-1")],
            vetoMarks: [vetoMark(candidateID: "cand-1")])
            .withDerivedTribunalObservationBundle(
                turnID: "rt",
                sessionID: "rt-s",
                emittedAt: fixedDate)

        let data = try JSONEncoder().encode(enriched)
        let decoded = try JSONDecoder().decode(
            BASThoughtFrame.self, from: data)

        XCTAssertNotNil(decoded.tribunalObservationBundle)
        XCTAssertEqual(
            decoded.tribunalObservationBundle?.turnID, "rt")
        XCTAssertEqual(
            decoded.tribunalObservationBundle?.observations.count,
            enriched.tribunalObservationBundle?
                .observations.count)
    }

    func testLegacyJSONWithoutBundleFieldDecodesWithNilBundle()
        throws
    {
        // Simulates a persisted pre-M55 frame that lacks the new
        // key. Swift's synthesized Codable tolerates missing keys
        // for optional fields — decoding must succeed and leave
        // `tribunalObservationBundle` as nil.
        let legacy = """
        {
          "schemaVersion": "1.4.0",
          "stepIndex": 0,
          "decomposeRef": "d-1",
          "memoryRefs": [],
          "candidates": [],
          "forecasts": [],
          "critiques": [],
          "triScores": [],
          "stabilityScore": 0
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(
            BASThoughtFrame.self, from: legacy)
        XCTAssertNil(decoded.tribunalObservationBundle)
        XCTAssertEqual(decoded.schemaVersion, "1.4.0")
    }
}
