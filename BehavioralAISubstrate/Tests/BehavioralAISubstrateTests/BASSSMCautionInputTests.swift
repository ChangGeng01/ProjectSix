// Phase 2 (unit) — the SSM operator as an AUTHORITATIVE raise-caution-only INPUT, BEFORE the L11 seam.
// Proves the safety math the seam rests on, in isolation: `raisedTotalRisk` is MONOTONIC (≥ current,
// ≤ 1), is EXACTLY current when the signal is 0 (the byte-equal-off anchor), clamps NaN/out-of-range to
// no-raise (a degenerate scan can never LOWER risk — the safe direction), and the caution scalar is
// deterministic, bounded, nil-on-empty, and identical to the observation's `ssmCaution` (no drift).

import XCTest
import Foundation
@testable import BASHostKit
@testable import BASOrchestration

final class BASSSMCautionInputTests: XCTestCase {

    private func affect(_ i: Double, _ v: Double, _ s: Double) -> BASAffectLayer {
        BASAffectLayer(tone: "t", intensity: i, volatility: v, spilloverRisk: s)
    }
    private func candidate(_ benefit: Double, _ cost: Double,
                           _ rev: Double, _ conf: Double) -> BASCandidatePath {
        BASCandidatePath(
            candidateID: "c", title: "t", actionSummary: "a",
            expectedBenefit: benefit, expectedCost: cost, reversibility: rev, confidence: conf)
    }

    // MARK: - raisedTotalRisk: the safe-direction proof

    func testRaisedTotalRiskIsMonotonicNeverBelowCurrent() {
        // For a grid of (current, signal), the raised value is ALWAYS ≥ current and ≤ 1.
        for current in stride(from: 0.0, through: 1.0, by: 0.1) {
            for s in stride(from: 0.0, through: 1.0, by: 0.1) {
                let raised = BASSSMCautionInput.raisedTotalRisk(current, ssmCaution: s)
                XCTAssertGreaterThanOrEqual(raised, current,
                    "raise-only: signal \(s) must never LOWER risk from \(current)")
                XCTAssertLessThanOrEqual(raised, 1.0, "risk stays bounded ≤ 1")
            }
        }
    }

    func testZeroSignalIsExactlyCurrent() {
        // s == 0 ⇒ no raise ⇒ byte-equal-off anchor at the math level.
        for current in stride(from: 0.0, through: 1.0, by: 0.05) {
            XCTAssertEqual(BASSSMCautionInput.raisedTotalRisk(current, ssmCaution: 0),
                           current, accuracy: 0, "zero signal ⇒ exactly current (no raise)")
        }
    }

    func testFullSignalAddsTheIncrementAndCaps() {
        XCTAssertEqual(BASSSMCautionInput.raisedTotalRisk(0.5, ssmCaution: 1.0),
                       0.5 + BASSSMCautionInput.ssmCautionRiskIncrement, accuracy: 1e-12,
                       "signal 1 ⇒ current + full increment")
        XCTAssertEqual(BASSSMCautionInput.raisedTotalRisk(0.99, ssmCaution: 1.0),
                       1.0, accuracy: 1e-12, "capped at 1")
        XCTAssertEqual(BASSSMCautionInput.raisedTotalRisk(0.5, ssmCaution: 0.5),
                       0.5 + 0.5 * BASSSMCautionInput.ssmCautionRiskIncrement, accuracy: 1e-12,
                       "increment scales linearly with the signal")
    }

    func testNaNAndOutOfRangeSignalNeverLowersRisk() {
        XCTAssertEqual(BASSSMCautionInput.raisedTotalRisk(0.4, ssmCaution: .nan),
                       0.4, accuracy: 0, "NaN ⇒ clamped to 0 ⇒ no raise (never lowers)")
        XCTAssertEqual(BASSSMCautionInput.raisedTotalRisk(0.4, ssmCaution: -5),
                       0.4, accuracy: 0, "negative ⇒ clamped to 0 ⇒ no raise")
        XCTAssertEqual(BASSSMCautionInput.raisedTotalRisk(0.4, ssmCaution: 99),
                       0.4 + BASSSMCautionInput.ssmCautionRiskIncrement, accuracy: 1e-12,
                       "above 1 ⇒ clamped to 1 ⇒ full increment (still a raise)")
    }

    // MARK: - cautionScalar: deterministic, bounded, nil-on-empty, no drift vs observation

    func testCautionScalarBoundedAndDeterministic() throws {
        let s1 = try XCTUnwrap(BASSSMCautionInput.cautionScalar(
            affectLayers: [affect(0.9, 0.9, 0.9)], turnHistory: ["escalating now"],
            candidates: [candidate(0.1, 0.9, 0.2, 0.3)]))
        XCTAssertTrue(s1 >= 0 && s1 <= 1, "caution scalar bounded [0,1]")
        let s2 = try XCTUnwrap(BASSSMCautionInput.cautionScalar(
            affectLayers: [affect(0.9, 0.9, 0.9)], turnHistory: ["escalating now"],
            candidates: [candidate(0.1, 0.9, 0.2, 0.3)]))
        XCTAssertEqual(s1, s2, "same inputs ⇒ identical scalar (CPU-deterministic)")
    }

    func testCautionScalarNilWhenAllSourcesEmpty() {
        XCTAssertNil(BASSSMCautionInput.cautionScalar(
            affectLayers: [], turnHistory: [], candidates: []),
            "all-empty ⇒ nil ⇒ clean per-turn no-op")
    }

    func testCautionScalarEqualsObservationSSMCaution() throws {
        // The unit-tested scalar must be byte-identical to the scalar the seam raises with.
        let scalar = try XCTUnwrap(BASSSMCautionInput.cautionScalar(
            affectLayers: [affect(0.8, 0.7, 0.6)], turnHistory: ["tense moment"],
            candidates: [candidate(0.2, 0.8, 0.3, 0.4)]))
        let obs = try XCTUnwrap(BASSSMCautionInput.observation(
            sessionID: "s", turnID: "t",
            affectLayers: [affect(0.8, 0.7, 0.6)], turnHistory: ["tense moment"],
            candidates: [candidate(0.2, 0.8, 0.3, 0.4)]))
        XCTAssertEqual(scalar, obs.ssmCaution, "scalar == observation.ssmCaution (single surface, no drift)")
        XCTAssertEqual(obs.affectCount, 1)
        XCTAssertEqual(obs.historyCount, 1)
        XCTAssertEqual(obs.candidateCount, 1)
    }
}
