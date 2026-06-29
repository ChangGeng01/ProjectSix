import XCTest
@testable import BASHostKit
@testable import BASRuntimeCore
import BASOrgan

/// TDD for the host-side plumbing that feeds REAL governance signals (stakes estimator + thermal + ε MSE) into
/// the allocator. Producers are injected for determinism; one case exercises the REAL stakes estimator
/// end-to-end to prove the wiring is not a stub.
final class BASEffortGovernorTests: XCTestCase {

    private func req(_ s: String) -> BASOrganRequest {
        BASOrganRequest(requestID: "r", role: .core, preset: .core, instruction: s, context: [])
    }

    func testHighStakesHighSurpriseFullHeadroomGoesMax() {
        let p = BASEffortGovernor.plan(
            for: req("anything"),
            runningMSE: 4.0,                                   // surprise = 4/5 = 0.8
            thermalState: { .nominal },                       // headroom 1.0
            estimateStakes: { _, _ in 0.9 })                  // demand 0.8×0.9 = 0.72 → max
        XCTAssertEqual(p.applied, .max)
    }

    func testCasualTurnGoesFast() {
        let p = BASEffortGovernor.plan(
            for: req("lol nice"),
            runningMSE: nil,                                  // cold start ⇒ neutral 0.5 surprise
            thermalState: { .nominal },
            estimateStakes: { _, _ in 0.05 })                 // demand 0.5×0.05 = 0.025 → fast
        XCTAssertEqual(p.applied, .fast)
    }

    func testNilMSEUsesNeutralSurpriseNotZero() {
        // Proves cold-start does NOT collapse to reflex: high stakes alone (× neutral 0.5) earns deep.
        let p = BASEffortGovernor.plan(
            for: req("anything"),
            runningMSE: nil,
            thermalState: { .nominal },
            estimateStakes: { _, _ in 0.9 })                  // demand 0.5×0.9 = 0.45 → deep
        XCTAssertEqual(p.applied, .deep)
    }

    func testThermalCriticalCapsRegardlessOfDemand() {
        let p = BASEffortGovernor.plan(
            for: req("anything"),
            runningMSE: 10.0,                                 // surprise ≈ 0.91
            thermalState: { .critical },                      // headroom 0 ⇒ cap fast
            estimateStakes: { _, _ in 1.0 })
        XCTAssertEqual(p.applied, .fast)
        XCTAssertTrue(p.overrideReason?.contains("thermal-lease") ?? false)
    }

    func testRealStakesEstimatorEndToEnd() {
        // No injected stakes ⇒ the REAL BASStakesEstimator runs. A health-safety advice turn is high-stakes;
        // with cold-start neutral surprise (0.5) it must escalate ABOVE the reflex tier — proving the live
        // BASStakesEstimator is genuinely wired into the allocator (not a stub).
        let p = BASEffortGovernor.plan(
            for: req("Is it safe to mix ibuprofen with my blood pressure medication?"),
            runningMSE: nil,
            thermalState: { .nominal })
        XCTAssertNotEqual(p.applied, .fast, "a high-stakes health/safety turn must not resolve to reflex")
    }
}
