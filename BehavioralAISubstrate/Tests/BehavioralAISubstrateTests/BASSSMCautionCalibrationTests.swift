// Phase 2 — caution-scale CALIBRATION pin. The SSM caution scalar must DISCRIMINATE proportionally to
// temporal pressure across the realistic magnitude range (not sit near-inert as it did under the original
// all-ones analytic reference 0.063, where even a high-pressure turn normalized to only ~0.20). These
// assertions pin the calibrated reference (0.025) by its OBSERVABLE behavior — a monotonic gradient from
// benign → mid → high-pressure → saturated, with the saturated extreme at the 1.0 cap and a realistic
// high-pressure turn landing in a responsive mid-high band. Robust bands (not exact values) so small,
// legitimate scan drift doesn't break the pin, while a regression toward an inert reference would.
//
// SAFETY NOTE: the calibration changes only the flag-ON raise MAGNITUDE (within [0, increment]); the
// safety proofs (raise-only / monotonic / byte-equal-off / verdict-gated) are magnitude-independent and
// live in BASSSMCautionInputTests + BASSSMCautionOperatorRunTurnTests.

import XCTest
import Foundation
@testable import BASHostKit
@testable import BASOrchestration

final class BASSSMCautionCalibrationTests: XCTestCase {

    private func affect(_ i: Double, _ v: Double, _ s: Double) -> BASAffectLayer {
        BASAffectLayer(tone: "t", intensity: i, volatility: v, spilloverRisk: s)
    }
    private func cand(_ b: Double, _ c: Double, _ r: Double, _ cf: Double) -> BASCandidatePath {
        BASCandidatePath(candidateID: "c", title: "t", actionSummary: "a",
            expectedBenefit: b, expectedCost: c, reversibility: r, confidence: cf)
    }
    private func caution(
        _ affects: [BASAffectLayer], _ history: [String], _ cands: [BASCandidatePath]
    ) -> Double {
        BASSSMCautionInput.cautionScalar(
            affectLayers: affects, turnHistory: history, candidates: cands) ?? -1
    }

    // Representative turns spanning the realistic space (same fixtures used to MEASURE the calibration).
    private var minimalCaution: Double { caution([], [], [cand(0.5, 0.5, 0.5, 0.5)]) }
    private var midCaution: Double {
        caution([affect(0.5, 0.5, 0.25), affect(0.4, 0.6, 0.24)], ["a normal turn here"],
                [cand(0.5, 0.5, 0.5, 0.5), cand(0.4, 0.6, 0.5, 0.45)])
    }
    private var highPressureCaution: Double {
        caution([affect(0.9, 0.9, 0.81), affect(0.85, 0.8, 0.68)],
                ["urgent now act immediately or lose everything"],
                [cand(0.2, 0.9, 0.15, 0.3), cand(0.3, 0.8, 0.2, 0.35)])
    }
    private var saturatedCaution: Double {
        caution((0..<8).map { _ in affect(0.95, 0.95, 0.9) },
                (0..<8).map { "high tension entry \($0) escalating fast" },
                (0..<8).map { _ in cand(0.2, 0.95, 0.1, 0.3) })
    }

    func testAllCautionsAreBounded() {
        for c in [minimalCaution, midCaution, highPressureCaution, saturatedCaution] {
            XCTAssertTrue(c >= 0 && c <= 1, "every caution scalar is bounded [0,1]")
        }
    }

    func testMonotonicGradientWithPressure() {
        // Strictly increasing with turn pressure — the core discrimination property.
        XCTAssertLessThan(minimalCaution, midCaution,
            "a minimal turn raises less caution than a mid turn")
        XCTAssertLessThan(midCaution, highPressureCaution,
            "a mid turn raises less caution than a high-pressure turn")
        XCTAssertLessThanOrEqual(highPressureCaution, saturatedCaution,
            "a high-pressure turn raises no more caution than a fully-saturated turn")
    }

    func testHighPressureTurnIsResponsive() {
        // THE calibration win: a genuinely high-pressure turn lands in a responsive mid-high band.
        // Under the old inert reference (0.063) this was ~0.20 — this assertion would fail on a
        // regression back toward an over-large reference.
        let c = highPressureCaution
        XCTAssertGreaterThanOrEqual(c, 0.45,
            "a high-pressure turn must raise meaningful caution (≥0.45) — not near-inert")
        XCTAssertLessThanOrEqual(c, 0.80,
            "but a single realistic high-pressure turn should not fully saturate (headroom kept)")
    }

    func testBenignTurnStaysModest() {
        XCTAssertLessThanOrEqual(minimalCaution, 0.25,
            "a benign minimal turn raises only modest caution")
    }

    func testMidTurnLandsMidRange() {
        let c = midCaution
        XCTAssertGreaterThan(c, 0.20, "a mid turn is clearly above benign")
        XCTAssertLessThan(c, 0.50, "but clearly below a high-pressure turn")
    }

    func testSaturatedTurnReachesTheCap() {
        XCTAssertEqual(saturatedCaution, 1.0, accuracy: 1e-9,
            "all three sources saturated (8 maxed rows each) reaches the 1.0 cap")
    }
}
