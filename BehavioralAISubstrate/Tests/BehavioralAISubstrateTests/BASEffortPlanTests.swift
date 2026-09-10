// ch1045 / v1.0 Phase-0 — proofs for BASEffortPlan (the squeeze-intensity controller).
// Requested/applied/override semantics, the deterministic level→budget mapping (intensity rises,
// guarded maximizes safety, auto = balanced), and Codable round-trip.

import XCTest
@testable import BASRuntimeCore

final class BASEffortPlanTests: XCTestCase {

    func testGrantedHasNoOverride() {
        let p = BASEffortPlan.granted(.deep)
        XCTAssertEqual(p.requested, .deep)
        XCTAssertEqual(p.applied, .deep)
        XCTAssertNil(p.overrideReason)
        XCTAssertFalse(p.wasOverridden)
        XCTAssertEqual(p.budget, BASEffortBudget.forLevel(.deep))
    }

    func testDowngradeRecordsReasonAndUsesAppliedBudget() {
        let p = BASEffortPlan.downgraded(requested: .max, to: .balanced, reason: "thermal=serious")
        XCTAssertEqual(p.requested, .max)
        XCTAssertEqual(p.applied, .balanced)
        XCTAssertEqual(p.overrideReason, "thermal=serious")
        XCTAssertTrue(p.wasOverridden)
        // budget derives from APPLIED (balanced), not requested (max)
        XCTAssertEqual(p.budget, BASEffortBudget.forLevel(.balanced))
        XCTAssertNotEqual(p.budget, BASEffortBudget.forLevel(.max))
    }

    func testBudgetIntensityIsMonotonic() {
        let fast = BASEffortBudget.forLevel(.fast)
        let balanced = BASEffortBudget.forLevel(.balanced)
        let deep = BASEffortBudget.forLevel(.deep)
        let mx = BASEffortBudget.forLevel(.max)
        XCTAssertLessThan(fast.candidateCount, balanced.candidateCount)
        XCTAssertLessThan(balanced.candidateCount, deep.candidateCount)
        XCTAssertLessThan(deep.candidateCount, mx.candidateCount)
        XCTAssertLessThan(fast.memoryDepth, deep.memoryDepth)
        XCTAssertLessThanOrEqual(fast.agentCount, mx.agentCount)
    }

    func testGuardedMaximizesSafetyDials() {
        let g = BASEffortBudget.forLevel(.guarded)
        XCTAssertEqual(g.criticStrength, 3)
        XCTAssertEqual(g.riskCalibration, 3)
        XCTAssertEqual(g.toolVerificationStrength, 3)
        // but breadth stays modest (safety-first, not max-breadth)
        XCTAssertLessThan(g.candidateCount, BASEffortBudget.forLevel(.max).candidateCount)
    }

    func testAutoFallsBackToBalancedBudget() {
        XCTAssertEqual(BASEffortBudget.forLevel(.auto), BASEffortBudget.forLevel(.balanced))
    }

    func testStrengthDialsClampToZeroThree() {
        let b = BASEffortBudget(
            candidateCount: -5, agentCount: -1, memoryDepth: -2,
            criticStrength: 9, riskCalibration: -1, outputDetail: 7, toolVerificationStrength: 4)
        XCTAssertEqual(b.candidateCount, 0)
        XCTAssertEqual(b.criticStrength, 3)
        XCTAssertEqual(b.riskCalibration, 0)
        XCTAssertEqual(b.toolVerificationStrength, 3)
    }

    func testCodableRoundTrip() throws {
        let p = BASEffortPlan.downgraded(requested: .max, to: .guarded, reason: "guarded_floor")
        let data = try JSONEncoder().encode(p)
        let back = try JSONDecoder().decode(BASEffortPlan.self, from: data)
        XCTAssertEqual(p, back)
        XCTAssertEqual(back.budget, BASEffortBudget.forLevel(.guarded))
    }
}
