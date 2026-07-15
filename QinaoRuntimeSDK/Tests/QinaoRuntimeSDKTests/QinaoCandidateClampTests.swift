import XCTest
@testable import QinaoLoop

/// audit F8 (2026-07-12) — CandidateInput clamps every [0,1] field on receive, so a sloppy or
/// hostile caller can't poison the frontier with Infinity/NaN/out-of-range values.
final class QinaoCandidateClampTests: XCTestCase {

    private func make(_ v: Double) -> QinaoLoop.CandidateInput {
        QinaoLoop.CandidateInput(
            candidateID: "c", title: "t", actionSummary: "s",
            expectedBenefit: v, expectedCost: v, reversibility: v, confidence: v,
            evidenceGap: v, manipulationRisk: v, emotionalBias: v, boundaryConflict: v)
    }

    func testPositiveInfinityClampsToOne() {
        let c = make(.infinity)
        for f in [c.expectedBenefit, c.expectedCost, c.reversibility, c.confidence,
                  c.evidenceGap, c.manipulationRisk, c.emotionalBias, c.boundaryConflict] {
            XCTAssertEqual(f, 1.0, "+Infinity must clamp to 1 (was: permanently tops the frontier)")
        }
    }

    func testNaNClampsToZero(){
        let c = make(.nan)
        for f in [c.expectedBenefit, c.expectedCost, c.reversibility, c.confidence,
                  c.evidenceGap, c.manipulationRisk, c.emotionalBias, c.boundaryConflict] {
            XCTAssertFalse(f.isNaN, "NaN must not survive (breaks strict-weak sort ordering)")
            XCTAssertEqual(f, 0.0, "NaN clamps to the neutral floor 0")
        }
    }

    func testNegativeClampsToZeroAndAboveOneClampsToOne() {
        XCTAssertEqual(make(-5.0).expectedBenefit, 0.0)
        XCTAssertEqual(make(2.0).confidence, 1.0)
        XCTAssertEqual(make(-.infinity).reversibility, 0.0)
    }

    func testInRangeValuesPassThroughUnchanged() {
        let c = make(0.37)
        XCTAssertEqual(c.expectedBenefit, 0.37, accuracy: 1e-12)
        XCTAssertEqual(c.confidence, 0.37, accuracy: 1e-12)
    }

    func testClamp01HelperIsFiniteSafe() {
        XCTAssertEqual(QinaoLoop.CandidateInput.clamp01(.nan), 0)
        XCTAssertEqual(QinaoLoop.CandidateInput.clamp01(.infinity), 1)
        XCTAssertEqual(QinaoLoop.CandidateInput.clamp01(-.infinity), 0)
        XCTAssertEqual(QinaoLoop.CandidateInput.clamp01(0.5), 0.5, accuracy: 1e-12)
    }
}
