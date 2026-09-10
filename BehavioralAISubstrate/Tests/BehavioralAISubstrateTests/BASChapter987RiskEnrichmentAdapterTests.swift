// MARK: - BASChapter987RiskEnrichmentAdapterTests
// chapter 九百八十七 / M3640 — Cross-Module Integration Arc ch5
//
// Closes ch 982.5 META-REVIEW cross-module Gap 3:
// BASRiskSeat consumed BASRiskInput derived ONLY from L7 Scout
// output — orthogonal to the host's live BASRiskServicing's
// BASRiskCard。 Two parallel risk computations,no path
// connecting them。
//
// Tests pin:
//   1. Monotonic raise — pressureLevel only goes UP
//   2. Manipulation signal trigger at card.manipulationStrength
//      >= 0.5
//   3. boundaryTouched unchanged (signal comes from L7 Scout)
//   4. card.totalRisk clamped at adapter boundary (defense)
//   5. Candidates passed through unchanged
//   6. Determinism

import XCTest
@testable import BASOrchestration
@testable import BASMemory
@testable import BASPolicy

final class BASChapter987RiskEnrichmentAdapterTests: XCTestCase {

    // MARK: - Monotonic raise

    func testMonotonicRaise_HigherCardRiskRaisesPressure() {
        let base = BASRiskInput(
            candidates: [],
            pressureLevel: 0.3,
            manipulationDetected: false,
            boundaryTouched: false)
        let card = sampleCard(totalRisk: 0.8)
        let enriched = BASAgentFabricAdapters
            .enrichRiskInput(from: card, baseRiskInput: base)
        XCTAssertEqual(enriched.pressureLevel, 0.8,
            accuracy: 0.001,
            "ch 987 Gap 3: higher card risk MUST raise pressure")
    }

    func testCRITICAL_MonotonicRaise_LowerCardRiskCannotLowerPressure() {
        let base = BASRiskInput(
            candidates: [],
            pressureLevel: 0.9,
            manipulationDetected: false,
            boundaryTouched: false)
        let card = sampleCard(totalRisk: 0.1)
        let enriched = BASAgentFabricAdapters
            .enrichRiskInput(from: card, baseRiskInput: base)
        XCTAssertEqual(enriched.pressureLevel, 0.9,
            accuracy: 0.001,
            "ch 987 CRITICAL Gap 3: lower card risk MUST NOT " +
            "lower base pressure (ch 967 monotonic-raise)")
    }

    // MARK: - Manipulation signal

    func testManipulation_StrongCardSignalActivates() {
        let base = BASRiskInput(
            candidates: [],
            pressureLevel: 0.0,
            manipulationDetected: false,
            boundaryTouched: false)
        let card = sampleCard(
            totalRisk: 0.0,
            manipulationStrength: 0.7)
        let enriched = BASAgentFabricAdapters
            .enrichRiskInput(from: card, baseRiskInput: base)
        XCTAssertTrue(enriched.manipulationDetected,
            "ch 987 Gap 3: card.manipulationStrength >= 0.5 " +
            "MUST activate manipulationDetected")
    }

    func testManipulation_WeakCardSignalLeavesUnset() {
        let base = BASRiskInput(
            candidates: [],
            pressureLevel: 0.0,
            manipulationDetected: false,
            boundaryTouched: false)
        let card = sampleCard(
            totalRisk: 0.0,
            manipulationStrength: 0.3)
        let enriched = BASAgentFabricAdapters
            .enrichRiskInput(from: card, baseRiskInput: base)
        XCTAssertFalse(enriched.manipulationDetected,
            "ch 987 Gap 3: card.manipulationStrength < 0.5 " +
            "MUST leave manipulation unset")
    }

    func testCRITICAL_Manipulation_AlreadyTrueStaysTrue() {
        let base = BASRiskInput(
            candidates: [],
            pressureLevel: 0.0,
            manipulationDetected: true,
            boundaryTouched: false)
        let card = sampleCard(
            totalRisk: 0.0,
            manipulationStrength: 0.1)
        let enriched = BASAgentFabricAdapters
            .enrichRiskInput(from: card, baseRiskInput: base)
        XCTAssertTrue(enriched.manipulationDetected,
            "ch 987 CRITICAL: pre-existing manipulationDetected " +
            "MUST persist even if card disagrees (ch 967 " +
            "monotonic — flag only flips ON,never OFF)")
    }

    // MARK: - boundaryTouched preservation

    func testBoundaryTouched_PreservedFromBase() {
        let base = BASRiskInput(
            candidates: [],
            pressureLevel: 0.0,
            manipulationDetected: false,
            boundaryTouched: true)
        let card = sampleCard(totalRisk: 0.0)
        let enriched = BASAgentFabricAdapters
            .enrichRiskInput(from: card, baseRiskInput: base)
        XCTAssertTrue(enriched.boundaryTouched,
            "ch 987 Gap 3: boundaryTouched preserved from base " +
            "(L7 Scout signal,not in card)")
    }

    // MARK: - Defensive clamp

    func testDefensiveClamp_OutOfRangeCardRisk() {
        let base = BASRiskInput(
            candidates: [],
            pressureLevel: 0.0,
            manipulationDetected: false,
            boundaryTouched: false)
        let cardHigh = sampleCard(totalRisk: 2.0)
        // BASRiskCard init already clamps but defense-in-depth
        let enriched = BASAgentFabricAdapters
            .enrichRiskInput(from: cardHigh, baseRiskInput: base)
        XCTAssertLessThanOrEqual(enriched.pressureLevel, 1.0,
            "ch 987 Gap 3: pressureLevel MUST clamp at 1.0 " +
            "(defense-in-depth at adapter boundary)")
    }

    // MARK: - Candidate passthrough

    func testCandidates_PassedThroughUnchanged() {
        let candidates = [
            BASRiskCandidate(
                candidateID: "c.1",
                reversibility: 0.7,
                expectedBenefit: 0.5,
                expectedCost: 0.3),
        ]
        let base = BASRiskInput(
            candidates: candidates,
            pressureLevel: 0.0,
            manipulationDetected: false,
            boundaryTouched: false)
        let card = sampleCard(totalRisk: 0.0)
        let enriched = BASAgentFabricAdapters
            .enrichRiskInput(from: card, baseRiskInput: base)
        XCTAssertEqual(enriched.candidates.count, 1)
        XCTAssertEqual(enriched.candidates[0].candidateID, "c.1")
    }

    // MARK: - chapter 九百九十一.5 META-REVIEW GAP-1 boundary tests

    /// GAP-1 (Reviewer 2): mutation `>= → >` on
    /// manipulationStrength threshold was not caught by tests
    /// using 0.7 (above) or 0.3 (below)。 This pins the exact
    /// boundary at 0.5。
    func testCRITICAL_ManipulationThreshold_ExactBoundaryActivates() {
        let base = BASRiskInput(
            candidates: [],
            pressureLevel: 0.0,
            manipulationDetected: false,
            boundaryTouched: false)
        let card = sampleCard(
            totalRisk: 0.0,
            manipulationStrength: 0.5)  // exactly at boundary
        let enriched = BASAgentFabricAdapters
            .enrichRiskInput(from: card, baseRiskInput: base)
        XCTAssertTrue(enriched.manipulationDetected,
            "ch 991.5 GAP-1 CRITICAL: manipulationStrength == " +
            "0.5 (exact boundary) MUST activate flag (>= 0.5 " +
            "trigger,not > 0.5 — mutation-safety pin)")
    }

    /// Equal-stays-equal pin (Reviewer 2 GAP-7)
    func testEqualBaseAndCardPressure_OutputExactlyEqual() {
        let base = BASRiskInput(
            candidates: [],
            pressureLevel: 0.5,
            manipulationDetected: false,
            boundaryTouched: false)
        let card = sampleCard(totalRisk: 0.5)
        let enriched = BASAgentFabricAdapters
            .enrichRiskInput(from: card, baseRiskInput: base)
        XCTAssertEqual(enriched.pressureLevel, 0.5,
            accuracy: 0.001,
            "ch 991.5 GAP-7: base == card pressure MUST produce " +
            "exact equality (mutation-safety pin for max())")
    }

    // MARK: - Determinism

    func testAdapter_IsDeterministic() {
        let base = BASRiskInput(
            candidates: [],
            pressureLevel: 0.4,
            manipulationDetected: false,
            boundaryTouched: false)
        let card = sampleCard(
            totalRisk: 0.6,
            manipulationStrength: 0.5)
        let e1 = BASAgentFabricAdapters
            .enrichRiskInput(from: card, baseRiskInput: base)
        let e2 = BASAgentFabricAdapters
            .enrichRiskInput(from: card, baseRiskInput: base)
        XCTAssertEqual(e1.pressureLevel, e2.pressureLevel)
        XCTAssertEqual(e1.manipulationDetected,
            e2.manipulationDetected)
    }

    // MARK: - Helpers

    private func sampleCard(
        totalRisk: Double,
        manipulationStrength: Double = 0.0
    ) -> BASRiskCard {
        BASRiskCard(
            totalRisk: totalRisk,
            riskLevel: .medium,
            factors: [],
            uncertainty: 0.5,
            irreversibility: 0.5,
            manipulationStrength: manipulationStrength,
            gsiScore: 0.5,
            recommendedMode: .answer)
    }
}
