import XCTest
@testable import BASOrchestration
@testable import BASRuntimeCore
@testable import BASWorldPrior

/// M452-M455 (chapter 一百十九) — pin that
/// `BASUnknownRetentionLoop.derive(...)` (M452) and
/// `BASNonEuclideanCandidate.deriveAll(...)` (M453) helpers
/// produce stable, deterministic outputs from existing turn
/// state.
final class M452CthulhuDeriveSourcesTests: XCTestCase {

    // MARK: - M452 — BASUnknownRetentionLoop derive

    /// Pin: unrestricted reserve → no retention loop synthesized.
    func testUnrestrictedReserveProducesNoLoop() {
        let reserve = BASUnknownReserve(
            reserveID: "r-unrestricted",
            unknownRefs: [],
            whyUnresolved: "",
            forbiddenInferences: [],
            evidenceNeeded: [],
            assertionCeiling: .unrestricted)
        let loop = BASUnknownRetentionLoop.derive(
            from: reserve, turnID: "t1")
        XCTAssertNil(loop, "unrestricted reserve must not synthesize a loop")
    }

    /// Pin: every non-unrestricted ceiling produces a loop with
    /// expected cooling period + safe ceiling per chapter 一百十九
    /// mapping table.
    func testCeilingTierMappingTable() {
        // Walk all 5 cases (anti-drift via .allCases)
        let mapping: [(BASUnknownAssertionCeiling, Int, Double, Bool)] = [
            (.unrestricted, 0, 0, false),  // expect nil
            (.provisional,
             BASUnknownRetentionLoop.coolingSecondsForProvisionalCeiling,
             BASUnknownRetentionLoop.safeCeilingForProvisional, true),
            (.qualified,
             BASUnknownRetentionLoop.coolingSecondsForQualifiedCeiling,
             BASUnknownRetentionLoop.safeCeilingForQualified, true),
            (.metaOnly,
             BASUnknownRetentionLoop.coolingSecondsForMetaOnlyCeiling,
             BASUnknownRetentionLoop.safeCeilingForMetaOnly, true),
            (.none,
             BASUnknownRetentionLoop.coolingSecondsForNoneCeiling,
             BASUnknownRetentionLoop.safeCeilingForNone, true),
        ]
        for (ceiling, expectedCooling, expectedSafe, shouldExist) in mapping {
            let reserve = BASUnknownReserve(
                reserveID: "r-\(ceiling.rawValue)",
                unknownRefs: ["unk-1", "unk-2"],
                whyUnresolved: "test",
                forbiddenInferences: [],
                evidenceNeeded: ["evidence-needed-1"],
                assertionCeiling: ceiling)
            let loop = BASUnknownRetentionLoop.derive(
                from: reserve, turnID: "test")
            if !shouldExist {
                XCTAssertNil(loop)
                continue
            }
            guard let loop = loop else {
                XCTFail("expected loop for ceiling \(ceiling.rawValue)")
                continue
            }
            XCTAssertEqual(loop.coolingPeriodSeconds, expectedCooling)
            XCTAssertEqual(loop.safeAssertionCeiling, expectedSafe,
                           accuracy: 0.001)
            XCTAssertEqual(loop.preservedUnknownRefs, ["unk-1", "unk-2"])
            XCTAssertEqual(loop.reExamineTriggers, ["evidence-needed-1"])
        }
    }

    /// Anti-drift: every BASUnknownAssertionCeiling case must
    /// either produce nil OR a loop without crashing.
    func testRetentionLoopDeriveIsTotal() {
        for ceiling in BASUnknownAssertionCeiling.allCases {
            let reserve = BASUnknownReserve(
                reserveID: "r-\(ceiling.rawValue)",
                unknownRefs: ["x"],
                whyUnresolved: "",
                forbiddenInferences: [],
                evidenceNeeded: [],
                assertionCeiling: ceiling)
            // Should not crash for any case.
            _ = BASUnknownRetentionLoop.derive(
                from: reserve, turnID: "totalTest")
        }
    }

    /// Pin: cooling period invariant — none > metaOnly > qualified
    /// > provisional > unrestricted (loop with longer cooling
    /// implies stricter assertion ceiling).
    func testCoolingPeriodIsMonotoneInStrictness() {
        XCTAssertGreaterThan(
            BASUnknownRetentionLoop.coolingSecondsForNoneCeiling,
            BASUnknownRetentionLoop.coolingSecondsForMetaOnlyCeiling)
        XCTAssertGreaterThan(
            BASUnknownRetentionLoop.coolingSecondsForMetaOnlyCeiling,
            BASUnknownRetentionLoop.coolingSecondsForQualifiedCeiling)
        XCTAssertGreaterThanOrEqual(
            BASUnknownRetentionLoop.coolingSecondsForQualifiedCeiling,
            BASUnknownRetentionLoop.coolingSecondsForProvisionalCeiling)
    }

    // MARK: - M453 — BASNonEuclideanCandidate.deriveAll

    func testEmptyCandidatesProducesEmpty() {
        let result = BASNonEuclideanCandidate.deriveAll(
            from: [], turnID: "t1")
        XCTAssertEqual(result.count, 0)
    }

    /// High-confidence candidates filtered out.
    func testHighConfidenceCandidatesAreFiltered() {
        let highConf = BASCandidatePath(
            candidateID: "c-high",
            title: "high",
            actionSummary: "do it",
            requiredEvidence: [],
            expectedBenefit: 0.5,
            expectedCost: 0.5,
            reversibility: 0.5,
            confidence: 0.9)
        let result = BASNonEuclideanCandidate.deriveAll(
            from: [highConf], turnID: "t1")
        XCTAssertEqual(result.count, 0,
                       "confidence above threshold filtered out")
    }

    /// Low-confidence + low-reversibility → collapsedOnGrasp.
    func testCollapsedOnGraspClassification() {
        let candidate = BASCandidatePath(
            candidateID: "c-collapse",
            title: "low conf low reversibility",
            actionSummary: "x",
            requiredEvidence: [],
            expectedBenefit: 0.3,
            expectedCost: 0.3,
            reversibility: 0.1,
            confidence: 0.3)
        let result = BASNonEuclideanCandidate.deriveAll(
            from: [candidate], turnID: "t1")
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].failureModeWhenGrasped,
                       .collapsedOnGrasp)
        XCTAssertEqual(
            result[0].nonStandardTopology,
            BASNonEuclideanCandidate.topologyLabelCollapsedOnGrasp)
    }

    /// High benefit + very low reversibility → boundaryViolation
    /// (priority over collapsedOnGrasp because benefit is high).
    func testBoundaryViolationClassification() {
        let candidate = BASCandidatePath(
            candidateID: "c-boundary",
            title: "high benefit very irreversible",
            actionSummary: "x",
            requiredEvidence: [],
            expectedBenefit: 0.9,
            expectedCost: 0.5,
            reversibility: 0.1,
            confidence: 0.3)
        let result = BASNonEuclideanCandidate.deriveAll(
            from: [candidate], turnID: "t1")
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].failureModeWhenGrasped,
                       .boundaryViolation)
        XCTAssertEqual(
            result[0].nonStandardTopology,
            BASNonEuclideanCandidate.topologyLabelBoundaryViolation)
    }

    /// Many required-evidence refs → topologyDistortion.
    func testTopologyDistortionClassification() {
        let candidate = BASCandidatePath(
            candidateID: "c-topology",
            title: "evidence heavy",
            actionSummary: "x",
            requiredEvidence: ["e1", "e2", "e3", "e4", "e5", "e6"],
            expectedBenefit: 0.4,
            expectedCost: 0.4,
            reversibility: 0.5,
            confidence: 0.3)
        let result = BASNonEuclideanCandidate.deriveAll(
            from: [candidate], turnID: "t1")
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].failureModeWhenGrasped,
                       .topologyDistortion)
        XCTAssertEqual(result[0].supportingAnchors.count, 6,
                       "supportingAnchors mirror requiredEvidence")
    }

    /// Low confidence default → consistencyLoss.
    func testConsistencyLossDefault() {
        let candidate = BASCandidatePath(
            candidateID: "c-cons-loss",
            title: "low conf",
            actionSummary: "x",
            requiredEvidence: ["e1"],
            expectedBenefit: 0.3,
            expectedCost: 0.3,
            reversibility: 0.5,
            confidence: 0.3)
        let result = BASNonEuclideanCandidate.deriveAll(
            from: [candidate], turnID: "t1")
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].failureModeWhenGrasped,
                       .consistencyLoss)
    }

    /// `consistentUnderPartialView` true when confidence above
    /// `partialViewConsistencyThreshold`.
    func testConsistentUnderPartialViewThreshold() {
        let above = BASCandidatePath(
            candidateID: "c-above-threshold",
            title: "above threshold",
            actionSummary: "x",
            requiredEvidence: [],
            expectedBenefit: 0.3,
            expectedCost: 0.3,
            reversibility: 0.5,
            confidence: 0.3)
        let resultAbove = BASNonEuclideanCandidate.deriveAll(
            from: [above], turnID: "t1")
        XCTAssertTrue(resultAbove[0].consistentUnderPartialView,
                      "0.3 confidence is above partial-view threshold (0.2)")

        let below = BASCandidatePath(
            candidateID: "c-below-threshold",
            title: "below threshold",
            actionSummary: "x",
            requiredEvidence: [],
            expectedBenefit: 0.3,
            expectedCost: 0.3,
            reversibility: 0.5,
            confidence: 0.1)
        let resultBelow = BASNonEuclideanCandidate.deriveAll(
            from: [below], turnID: "t1")
        XCTAssertFalse(resultBelow[0].consistentUnderPartialView,
                       "0.1 confidence is below partial-view threshold")
    }

    /// Anti-drift: every BASNonEuclideanFailureMode case must
    /// have a topology label.
    func testEveryFailureModeHasLabel() {
        for mode in BASNonEuclideanFailureMode.allCases {
            let label = BASNonEuclideanCandidate.topologyLabel(
                for: mode)
            XCTAssertFalse(label.isEmpty,
                           "topology label for \(mode.rawValue) " +
                           "must not be empty")
        }
    }

    // MARK: - Anti-magic-number named-constant pins

    func testNamedConstantsStable() {
        XCTAssertEqual(
            BASNonEuclideanCandidate.nonEuclideanConfidenceThreshold,
            0.4, accuracy: 0.001)
        XCTAssertEqual(
            BASNonEuclideanCandidate.collapsedOnGraspReversibilityThreshold,
            0.3, accuracy: 0.001)
        XCTAssertEqual(
            BASNonEuclideanCandidate.topologyDistortionEvidenceCountThreshold,
            5)
        XCTAssertEqual(
            BASNonEuclideanCandidate.boundaryViolationBenefitThreshold,
            0.7, accuracy: 0.001)
        XCTAssertEqual(
            BASNonEuclideanCandidate.boundaryViolationReversibilityThreshold,
            0.2, accuracy: 0.001)
        XCTAssertEqual(
            BASNonEuclideanCandidate.partialViewConsistencyThreshold,
            0.2, accuracy: 0.001)

        XCTAssertEqual(
            BASUnknownRetentionLoop.coolingSecondsForNoneCeiling, 600)
        XCTAssertEqual(
            BASUnknownRetentionLoop.coolingSecondsForMetaOnlyCeiling, 300)
        XCTAssertEqual(
            BASUnknownRetentionLoop.coolingSecondsForQualifiedCeiling, 60)
        XCTAssertEqual(
            BASUnknownRetentionLoop.safeCeilingForNone, 0.1, accuracy: 0.001)
        XCTAssertEqual(
            BASUnknownRetentionLoop.safeCeilingForMetaOnly, 0.3, accuracy: 0.001)
        XCTAssertEqual(
            BASUnknownRetentionLoop.safeCeilingForQualified, 0.5, accuracy: 0.001)
    }
}
