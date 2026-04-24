import XCTest
@testable import BASOrchestration
@testable import BASRuntimeCore

/// M89 — L10 full-body tribunal schema + derivation tests.
///
/// Pins:
///
/// 1. **Schema init clamping / trimming** — scalar fields clamp to
///    `[0, 1]`, id fields trim whitespace, categorical arrays pass
///    through verbatim.
///
/// 2. **Derivation determinism** — repeated calls on the same frame
///    produce byte-equal outputs (same sort order, same aggregate
///    formulas).
///
/// 3. **Projection formulas**
///    - `BASIdImpulseProfile.controlRecoveryNeed` = mean(idScore)
///    - `BASIdImpulseProfile.urgencyFeel` = max(idScore × (1 − conf))
///    - `BASIdImpulseProfile.vitalityLoad` = max(expectedBenefit)
///    - `BASEgoRealityAssessment` partitions candidates into
///      feasible (egoScore ≥ 0.5 AND no veto), blocked (egoScore < 0.3
///      OR veto), undecided (otherwise)
///    - `BASEgoRealityAssessment.realismScore` = mean(egoScore)
///    - `BASSuperegoJudgment.vetoCandidateIDs` = deduped + sorted
///    - `BASSuperegoJudgment` buckets veto reason codes by
///      `vetoType.rawValue` category (boundary / dignity /
///      irreversible)
///    - `BASArbitrationFrame.aggregate` stitches sub-profiles + derives
///      refs from veto marks / remand orders / tradeoff ledgers /
///      decision draft
///
/// 4. **Backward compatibility** — `BASThoughtFrame(...)` without the
///    four new fields still compiles and produces a frame with
///    `idImpulseProfile == nil`.
///
/// 5. **Composite helper** —
///    `frame.withDerivedL10FullBody(frameIDBase:)` returns a copy
///    with all four sub-records populated; `frameIDBase` is the
///    stable prefix for every sub-record's ID.
final class BASTribunalFullBodyTests: XCTestCase {

    // MARK: - Fixtures

    private func path(
        _ id: String,
        benefit: Double = 0.5,
        cost: Double = 0.3,
        reversibility: Double = 0.5,
        confidence: Double = 0.5
    ) -> BASCandidatePath {
        BASCandidatePath(
            candidateID: id,
            title: "title-\(id)",
            actionSummary: "summary-\(id)",
            expectedBenefit: benefit,
            expectedCost: cost,
            reversibility: reversibility,
            confidence: confidence)
    }

    private func triScore(
        _ candidateID: String,
        id idScore: Double,
        ego egoScore: Double,
        superego superegoScore: Double,
        merged mergedScore: Double = 0.5,
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

    private func veto(
        _ candidateID: String,
        type: BASCourtVetoType = .boundary,
        reasons: [String] = []
    ) -> BASVetoMark {
        BASVetoMark(
            candidateID: candidateID,
            vetoType: type,
            reasonCodes: reasons,
            compensable: false)
    }

    private func frame(
        candidates: [BASCandidatePath] = [],
        triScores: [BASTriSelfScore] = [],
        vetoMarks: [BASVetoMark]? = nil,
        remandOrders: [BASRemandOrder]? = nil,
        tradeoffLedgers: [BASTradeoffLedger]? = nil,
        decisionDraft: BASCourtDecisionDraft? = nil
    ) -> BASThoughtFrame {
        BASThoughtFrame(
            stepIndex: 0,
            decomposeRef: "decompose-m89",
            candidates: candidates,
            triScores: triScores,
            vetoMarks: vetoMarks,
            tradeoffLedgers: tradeoffLedgers,
            remandOrders: remandOrders,
            courtDecisionDraft: decisionDraft)
    }

    // MARK: - 1. Schema init clamping / trimming

    func testIdImpulseProfileInitClampsScalarsToUnitInterval() {
        let lo = BASIdImpulseProfile(
            profileID: "id-low",
            controlRecoveryNeed: -1.0,
            urgencyFeel: -0.5,
            vitalityLoad: -99)
        XCTAssertEqual(lo.controlRecoveryNeed, 0, accuracy: 1e-12)
        XCTAssertEqual(lo.urgencyFeel, 0, accuracy: 1e-12)
        XCTAssertEqual(lo.vitalityLoad, 0, accuracy: 1e-12)

        let hi = BASIdImpulseProfile(
            profileID: "id-high",
            controlRecoveryNeed: 9,
            urgencyFeel: 2.5,
            vitalityLoad: 100)
        XCTAssertEqual(hi.controlRecoveryNeed, 1, accuracy: 1e-12)
        XCTAssertEqual(hi.urgencyFeel, 1, accuracy: 1e-12)
        XCTAssertEqual(hi.vitalityLoad, 1, accuracy: 1e-12)
    }

    func testEgoRealityAssessmentInitClampsScalarsToUnitInterval() {
        let hi = BASEgoRealityAssessment(
            assessmentID: "ego-hi",
            timingFit: 5,
            evidenceReadiness: 2.3,
            leaseFit: 1.7,
            realismScore: 12)
        XCTAssertEqual(hi.timingFit, 1, accuracy: 1e-12)
        XCTAssertEqual(hi.evidenceReadiness, 1, accuracy: 1e-12)
        XCTAssertEqual(hi.leaseFit, 1, accuracy: 1e-12)
        XCTAssertEqual(hi.realismScore, 1, accuracy: 1e-12)
    }

    func testSuperegoJudgmentPreservesCategoricalArrays() {
        let j = BASSuperegoJudgment(
            judgmentID: "superego-m89",
            dignityRisks: ["public-shaming"],
            boundaryConflicts: ["sleep-boundary"],
            valueViolations: ["honesty"],
            relationEthicsLoad: ["owe-trust-to-N"],
            irreversibleWarnings: ["cannot-unsend"],
            vetoCandidateIDs: ["c-1", "c-2"])
        XCTAssertEqual(j.dignityRisks, ["public-shaming"])
        XCTAssertEqual(j.boundaryConflicts, ["sleep-boundary"])
        XCTAssertEqual(j.valueViolations, ["honesty"])
        XCTAssertEqual(j.relationEthicsLoad, ["owe-trust-to-N"])
        XCTAssertEqual(j.irreversibleWarnings, ["cannot-unsend"])
        XCTAssertEqual(j.vetoCandidateIDs, ["c-1", "c-2"])
    }

    func testArbitrationFrameTrimsIDFields() {
        let frame = BASArbitrationFrame(
            frameID: "  trimmed  ",
            candidateFrontierRef: "  frontier-1  ",
            hostConstitutionRef: "  host-v1  ",
            memoryBundleRef: "  mem-99  ",
            agencyReservationRef: "  agency-a  ",
            decisionDraftRef: "  draft-x  ")
        XCTAssertEqual(frame.frameID, "trimmed")
        XCTAssertEqual(frame.candidateFrontierRef, "frontier-1")
        XCTAssertEqual(frame.hostConstitutionRef, "host-v1")
        XCTAssertEqual(frame.memoryBundleRef, "mem-99")
        XCTAssertEqual(frame.agencyReservationRef, "agency-a")
        XCTAssertEqual(frame.decisionDraftRef, "draft-x")
    }

    // MARK: - 2. Id-voice derivation formulas

    func testIdImpulseProfileDerivationControlRecoveryMeansIdScores() {
        let f = frame(
            candidates: [path("a"), path("b")],
            triScores: [
                triScore("a", id: 0.8, ego: 0.4, superego: 0.3),
                triScore("b", id: 0.2, ego: 0.6, superego: 0.5)
            ])
        let profile = BASIdImpulseProfile.derive(
            from: f, profileID: "id-profile")
        XCTAssertEqual(
            profile.controlRecoveryNeed,
            (0.8 + 0.2) / 2.0,
            accuracy: 1e-9)
    }

    func testIdImpulseProfileDerivationVitalityLoadIsMaxExpectedBenefit() {
        let f = frame(
            candidates: [
                path("a", benefit: 0.3),
                path("b", benefit: 0.9),
                path("c", benefit: 0.6)
            ],
            triScores: [
                triScore("a", id: 0.5, ego: 0.5, superego: 0.5),
                triScore("b", id: 0.5, ego: 0.5, superego: 0.5),
                triScore("c", id: 0.5, ego: 0.5, superego: 0.5)
            ])
        let profile = BASIdImpulseProfile.derive(
            from: f, profileID: "id-profile")
        XCTAssertEqual(profile.vitalityLoad, 0.9, accuracy: 1e-9)
    }

    func testIdImpulseProfileDerivationUrgencyUsesIdScoreTimesOneMinusConfidence() {
        let f = frame(
            candidates: [
                path("a", confidence: 0.2),  // low confidence
                path("b", confidence: 0.9)   // high confidence
            ],
            triScores: [
                triScore("a", id: 1.0, ego: 0.5, superego: 0.5),
                triScore("b", id: 1.0, ego: 0.5, superego: 0.5)
            ])
        let profile = BASIdImpulseProfile.derive(
            from: f, profileID: "id-profile")
        // max of [1.0 * (1-0.2), 1.0 * (1-0.9)] = max(0.8, 0.1) = 0.8
        XCTAssertEqual(profile.urgencyFeel, 0.8, accuracy: 1e-9)
    }

    // MARK: - 3. Ego-voice derivation formulas

    func testEgoRealityAssessmentPartitionsCandidatesByScoreAndVeto() {
        let f = frame(
            candidates: [
                path("a"), path("b"), path("c"), path("d")
            ],
            triScores: [
                triScore("a", id: 0.3, ego: 0.8, superego: 0.5),  // feasible
                triScore("b", id: 0.3, ego: 0.2, superego: 0.5),  // blocked
                triScore("c", id: 0.3, ego: 0.4, superego: 0.5),  // undecided
                triScore("d", id: 0.3, ego: 0.9, superego: 0.5)   // vetoed → blocked
            ],
            vetoMarks: [veto("d")])
        let assessment = BASEgoRealityAssessment.derive(
            from: f, assessmentID: "ego-assessment")
        XCTAssertEqual(assessment.feasibleCandidateIDs, ["a"])
        XCTAssertEqual(
            assessment.blockedCandidateIDs.sorted(),
            ["b", "d"])
        XCTAssertFalse(
            assessment.feasibleCandidateIDs.contains("c"),
            "undecided candidates land in neither array")
        XCTAssertFalse(
            assessment.blockedCandidateIDs.contains("c"))
    }

    func testEgoRealityAssessmentRealismScoreMeansEgoScores() {
        let f = frame(
            candidates: [path("a"), path("b"), path("c")],
            triScores: [
                triScore("a", id: 0, ego: 0.4, superego: 0),
                triScore("b", id: 0, ego: 0.6, superego: 0),
                triScore("c", id: 0, ego: 0.8, superego: 0)
            ])
        let assessment = BASEgoRealityAssessment.derive(
            from: f, assessmentID: "ego-realism")
        XCTAssertEqual(
            assessment.realismScore,
            (0.4 + 0.6 + 0.8) / 3.0,
            accuracy: 1e-9)
    }

    // MARK: - 4. Superego-voice derivation

    func testSuperegoJudgmentCollectsVetoCandidateIDsSortedAndDeduped() {
        let f = frame(
            triScores: [
                triScore("x", id: 0.5, ego: 0.5, superego: 0.5),
                triScore("y", id: 0.5, ego: 0.5, superego: 0.5),
                triScore("z", id: 0.5, ego: 0.5, superego: 0.5)
            ],
            vetoMarks: [
                veto("z"), veto("x"), veto("z"),  // duplicate z
                veto("y")
            ])
        let j = BASSuperegoJudgment.derive(
            from: f, judgmentID: "superego-dedup")
        XCTAssertEqual(j.vetoCandidateIDs, ["x", "y", "z"])
    }

    func testSuperegoJudgmentRoutesVetoReasonsByVetoTypeCategory() {
        let f = frame(
            vetoMarks: [
                veto("a",
                     type: .boundary,
                     reasons: ["commitment-to-spouse"]),
                veto("b",
                     type: .boundary,
                     reasons: ["sleep-boundary"])
            ])
        let j = BASSuperegoJudgment.derive(
            from: f, judgmentID: "superego-cat")
        XCTAssertEqual(
            j.boundaryConflicts,
            ["commitment-to-spouse", "sleep-boundary"],
            "boundary-tagged veto reasons collected, sorted")
    }

    // MARK: - 5. Arbitration frame aggregation

    func testArbitrationFrameAggregatesRefsAndSubProfiles() {
        let id = BASIdImpulseProfile(profileID: "id-x")
        let ego = BASEgoRealityAssessment(assessmentID: "ego-y")
        let superego = BASSuperegoJudgment(judgmentID: "super-z")

        let frame = BASArbitrationFrame.aggregate(
            frameID: "arb-1",
            candidateFrontierRef: "frontier-42",
            hostConstitutionRef: "host-v3",
            memoryBundleRef: "mem-77",
            idProfile: id,
            egoAssessment: ego,
            superegoJudgment: superego,
            vetoMarks: [
                veto("c1"), veto("c2")
            ],
            remandOrders: [
                BASRemandOrder(targetLayer: "L7", reasonCodes: ["evidence-gap"]),
                BASRemandOrder(targetLayer: "L4", reasonCodes: ["prior-check"])
            ],
            tradeoffLedgers: [
                BASTradeoffLedger(candidateID: "c1", gains: ["g"])
            ],
            decisionDraft: BASCourtDecisionDraft(
                preferredCandidateID: "cbest",
                readinessLevel: "ready"))

        XCTAssertEqual(frame.frameID, "arb-1")
        XCTAssertEqual(frame.candidateFrontierRef, "frontier-42")
        XCTAssertEqual(frame.hostConstitutionRef, "host-v3")
        XCTAssertEqual(frame.memoryBundleRef, "mem-77")
        XCTAssertEqual(frame.idProfile?.profileID, "id-x")
        XCTAssertEqual(frame.egoAssessment?.assessmentID, "ego-y")
        XCTAssertEqual(frame.superegoJudgment?.judgmentID, "super-z")
        XCTAssertEqual(frame.vetoRefs, ["c1", "c2"])
        XCTAssertEqual(frame.remandRefs, ["L7", "L4"])
        XCTAssertEqual(frame.tradeoffLedgerRefs, ["c1"])
        XCTAssertEqual(frame.decisionDraftRef, "cbest")
    }

    // MARK: - 6. Empty-frame derivation (no-voice-this-turn)

    func testEmptyFrameDerivationsProduceZeroScoresAndEmptyArrays() {
        let empty = frame()
        let id = BASIdImpulseProfile.derive(
            from: empty, profileID: "id-empty")
        let ego = BASEgoRealityAssessment.derive(
            from: empty, assessmentID: "ego-empty")
        let superego = BASSuperegoJudgment.derive(
            from: empty, judgmentID: "super-empty")

        XCTAssertEqual(id.controlRecoveryNeed, 0, accuracy: 1e-12)
        XCTAssertEqual(id.urgencyFeel, 0, accuracy: 1e-12)
        XCTAssertEqual(id.vitalityLoad, 0, accuracy: 1e-12)

        XCTAssertEqual(ego.realismScore, 0, accuracy: 1e-12)
        XCTAssertEqual(ego.timingFit, 0, accuracy: 1e-12)
        XCTAssertTrue(ego.feasibleCandidateIDs.isEmpty)
        XCTAssertTrue(ego.blockedCandidateIDs.isEmpty)

        XCTAssertTrue(superego.vetoCandidateIDs.isEmpty)
        XCTAssertTrue(superego.boundaryConflicts.isEmpty)
    }

    // MARK: - 7. Composite helper

    func testWithDerivedL10FullBodyAttachesAllFourSubRecords() {
        let base = frame(
            candidates: [path("a", benefit: 0.7)],
            triScores: [
                triScore("a", id: 0.7, ego: 0.8, superego: 0.4)
            ],
            vetoMarks: [veto("a", reasons: ["test"])],
            decisionDraft: BASCourtDecisionDraft(
                preferredCandidateID: "a",
                readinessLevel: "ready"))

        let enriched = base.withDerivedL10FullBody(
            frameIDBase: "s1.t1")

        XCTAssertNotNil(enriched.idImpulseProfile)
        XCTAssertNotNil(enriched.egoRealityAssessment)
        XCTAssertNotNil(enriched.superegoJudgment)
        XCTAssertNotNil(enriched.arbitrationFrame)

        XCTAssertEqual(
            enriched.idImpulseProfile?.profileID, "s1.t1.id")
        XCTAssertEqual(
            enriched.egoRealityAssessment?.assessmentID, "s1.t1.ego")
        XCTAssertEqual(
            enriched.superegoJudgment?.judgmentID, "s1.t1.superego")
        XCTAssertEqual(
            enriched.arbitrationFrame?.frameID, "s1.t1.arbitration")
    }

    func testWithDerivedL10FullBodyPreservesPreExistingFrameFields() {
        let base = frame(
            candidates: [path("a")],
            triScores: [
                triScore("a", id: 0.5, ego: 0.5, superego: 0.5)
            ])
        let enriched = base.withDerivedL10FullBody(
            frameIDBase: "s1.t1")

        XCTAssertEqual(
            enriched.stepIndex, base.stepIndex,
            "stepIndex preserved")
        XCTAssertEqual(
            enriched.decomposeRef, base.decomposeRef,
            "decomposeRef preserved")
        XCTAssertEqual(
            enriched.candidates.map(\.candidateID),
            ["a"])
        XCTAssertEqual(enriched.triScores.count, 1)
    }

    // MARK: - 8. Backward compatibility

    func testBASThoughtFrameLegacyInitPreservesPreM89Shape() {
        // Legacy init (no M89 fields) must produce a valid frame with
        // all four sub-records == nil.
        let legacy = BASThoughtFrame(
            stepIndex: 0,
            decomposeRef: "decompose-legacy")
        XCTAssertNil(legacy.idImpulseProfile)
        XCTAssertNil(legacy.egoRealityAssessment)
        XCTAssertNil(legacy.superegoJudgment)
        XCTAssertNil(legacy.arbitrationFrame)
    }

    // MARK: - 9. Determinism pin (same inputs → same outputs)

    func testAllFourDerivationsAreDeterministicOnIdenticalInputs() {
        let f = frame(
            candidates: [path("a"), path("b")],
            triScores: [
                triScore("a", id: 0.4, ego: 0.6, superego: 0.5),
                triScore("b", id: 0.7, ego: 0.3, superego: 0.8)
            ],
            vetoMarks: [veto("b")])

        let id1 = BASIdImpulseProfile.derive(
            from: f, profileID: "det-id")
        let id2 = BASIdImpulseProfile.derive(
            from: f, profileID: "det-id")
        let ego1 = BASEgoRealityAssessment.derive(
            from: f, assessmentID: "det-ego")
        let ego2 = BASEgoRealityAssessment.derive(
            from: f, assessmentID: "det-ego")
        let su1 = BASSuperegoJudgment.derive(
            from: f, judgmentID: "det-super")
        let su2 = BASSuperegoJudgment.derive(
            from: f, judgmentID: "det-super")

        XCTAssertEqual(id1, id2)
        XCTAssertEqual(ego1, ego2)
        XCTAssertEqual(su1, su2)
    }

    // MARK: - 10. Schema version contracts

    func testSchemaVersionsStable() {
        XCTAssertEqual(
            BASIdImpulseProfile.currentSchemaVersion, "1.0.0")
        XCTAssertEqual(
            BASEgoRealityAssessment.currentSchemaVersion, "1.0.0")
        XCTAssertEqual(
            BASSuperegoJudgment.currentSchemaVersion, "1.0.0")
        XCTAssertEqual(
            BASArbitrationFrame.currentSchemaVersion, "1.0.0")
    }
}
