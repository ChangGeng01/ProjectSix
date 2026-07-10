import XCTest
@testable import BASRuntimeCore

/// TDD for the surprise-gated effort/tier allocator (ε × stakes within a thermal-lease headroom cap) and its
/// pure signal normalizers.
final class BASEffortAllocatorTests: XCTestCase {

    // MARK: - Signals

    func testSurpriseFromMSESaturates() {
        XCTAssertEqual(BASEffortSignals.surprise(fromMSE: 0), 0, accuracy: 1e-9)        // no error ⇒ no surprise
        XCTAssertEqual(BASEffortSignals.surprise(fromMSE: -3), 0, accuracy: 1e-9)       // negative ⇒ 0 (guard)
        XCTAssertEqual(BASEffortSignals.surprise(fromMSE: 1, scale: 1), 0.5, accuracy: 1e-9) // knee at mse==scale
        XCTAssertGreaterThan(BASEffortSignals.surprise(fromMSE: 100), 0.95)             // large ⇒ →1
        // monotonic + scale-tunable
        XCTAssertLessThan(BASEffortSignals.surprise(fromMSE: 1, scale: 4),
                          BASEffortSignals.surprise(fromMSE: 1, scale: 1))
    }

    func testHeadroomForThermalState() {
        XCTAssertEqual(BASEffortSignals.headroom(for: ProcessInfo.ThermalState.nominal), 1.0, accuracy: 1e-9)
        XCTAssertEqual(BASEffortSignals.headroom(for: ProcessInfo.ThermalState.fair), 0.6, accuracy: 1e-9)
        XCTAssertEqual(BASEffortSignals.headroom(for: ProcessInfo.ThermalState.serious), 0.3, accuracy: 1e-9)
        XCTAssertEqual(BASEffortSignals.headroom(for: ProcessInfo.ThermalState.critical), 0.0, accuracy: 1e-9)
    }

    func testHeadroomForBASThermalLevel() {
        XCTAssertEqual(BASEffortSignals.headroom(for: BASThermalLevel.nominal), 1.0, accuracy: 1e-9)
        XCTAssertEqual(BASEffortSignals.headroom(for: BASThermalLevel.warm), 0.6, accuracy: 1e-9)
        XCTAssertEqual(BASEffortSignals.headroom(for: BASThermalLevel.hot), 0.3, accuracy: 1e-9)
        XCTAssertEqual(BASEffortSignals.headroom(for: BASThermalLevel.critical), 0.0, accuracy: 1e-9)
    }

    // MARK: - Allocator: auto resolution from demand (surprise × stakes)

    func testAutoHighSurpriseHighStakesFullHeadroomGoesMax() {
        let p = BASEffortAllocator.resolve(surprise: 0.9, stakes: 0.9, headroom: 1.0) // demand 0.81 ≥ 0.60
        XCTAssertEqual(p.applied, .max)
        XCTAssertNotNil(p.overrideReason)                         // auto-resolution must be logged
        XCTAssertTrue(p.overrideReason!.contains("auto"))
    }

    func testAutoLowStakesGoesFastReflex() {
        let p = BASEffortAllocator.resolve(surprise: 0.9, stakes: 0.05, headroom: 1.0) // demand 0.045 < 0.10
        XCTAssertEqual(p.applied, .fast)                          // avoided-compute: reflex tier
    }

    func testAutoModerateDemandGoesDeepThenBalanced() {
        XCTAssertEqual(BASEffortAllocator.resolve(surprise: 0.7, stakes: 0.6, headroom: 1.0).applied, .deep)     // 0.42
        XCTAssertEqual(BASEffortAllocator.resolve(surprise: 0.5, stakes: 0.3, headroom: 1.0).applied, .balanced) // 0.15
    }

    func testLowSurpriseSuppressesEffortEvenAtHighStakes() {
        // a CONFIDENT (low-ε) high-stakes turn needs little COMPUTE here (verify is the gate's separate job).
        let p = BASEffortAllocator.resolve(surprise: 0.05, stakes: 1.0, headroom: 1.0) // demand 0.05 < 0.10
        XCTAssertEqual(p.applied, .fast)
    }

    func testClampsOutOfRangeInputs() {
        let p = BASEffortAllocator.resolve(surprise: 5, stakes: 5, headroom: 5)   // clamps to 1,1,1
        XCTAssertEqual(p.applied, .max)
    }

    // MARK: - Explicit request honored / downgraded

    func testExplicitRequestGrantedWhenHeadroomAllows() {
        let p = BASEffortAllocator.resolve(requested: .deep, surprise: 0, stakes: 0, headroom: 1.0)
        XCTAssertEqual(p.applied, .deep)                          // explicit base honored despite zero demand
        XCTAssertNil(p.overrideReason)                            // granted ⇒ no reason
        XCTAssertFalse(p.wasOverridden)
    }

    func testThermalCapDowngradesExplicitRequestWithHonestReason() {
        let p = BASEffortAllocator.resolve(requested: .max, surprise: 1, stakes: 1, headroom: 0.0) // critical
        XCTAssertEqual(p.applied, .fast)
        XCTAssertEqual(p.requested, .max)
        XCTAssertNotNil(p.overrideReason)
        XCTAssertTrue(p.overrideReason!.contains("thermal-lease"))
    }

    func testAutoAndThermalCapBothLogged() {
        let p = BASEffortAllocator.resolve(surprise: 1, stakes: 1, headroom: 0.3) // demand→max, headroom→balanced
        XCTAssertEqual(p.applied, .balanced)
        XCTAssertTrue(p.overrideReason!.contains("auto"))
        XCTAssertTrue(p.overrideReason!.contains("thermal-lease"))
    }

    // MARK: - guarded survives serious thermal, yields to critical

    func testGuardedPreservedUnderSeriousThermal() {
        let p = BASEffortAllocator.resolve(requested: .guarded, surprise: 0, stakes: 0, headroom: 0.3) // serious
        XCTAssertEqual(p.applied, .guarded)                      // guarded ranks at balanced rung ⇒ not capped
        XCTAssertNil(p.overrideReason)
    }

    // operator decision 1B (audit runtimecore-a #7): a DELIBERATELY-guarded turn keeps its safety
    // dials (criticStrength / toolVerificationStrength) even under critical thermal — thermal-lease
    // no longer strips verification off a guarded turn (the old behavior dropped it to .fast = 0/0).
    func testGuardedSurvivesCriticalThermal() {
        let p = BASEffortAllocator.resolve(requested: .guarded, surprise: 0, stakes: 0, headroom: 0.0) // critical
        XCTAssertEqual(p.applied, .guarded,
            "an explicit .guarded is never dropped below .guarded by the thermal cap")
        XCTAssertNil(p.overrideReason, "the guarded request takes effect unchanged")
        let fast = BASEffortBudget.forLevel(.fast)
        XCTAssertEqual(p.budget, BASEffortBudget.forLevel(.guarded))
        XCTAssertGreaterThan(p.budget.criticStrength, fast.criticStrength,
            "guarded keeps a non-zero critic strength that .fast would have zeroed")
        XCTAssertGreaterThan(p.budget.toolVerificationStrength, fast.toolVerificationStrength,
            "guarded keeps a non-zero tool-verification strength on the hottest device")
    }

    // A non-guarded base still yields to the critical thermal cap (thermal-lease unchanged for it).
    func testNonGuardedStillYieldsToCriticalThermal() {
        let p = BASEffortAllocator.resolve(requested: .deep, surprise: 0, stakes: 0, headroom: 0.0) // critical
        XCTAssertEqual(p.applied, .fast, "an explicit .deep still yields to the critical thermal cap")
        XCTAssertTrue(p.overrideReason!.contains("thermal-lease"))
    }

    // MARK: - the plan expands to a real budget

    func testAppliedLevelExpandsToBudget() {
        let p = BASEffortAllocator.resolve(surprise: 0.9, stakes: 0.9, headroom: 1.0) // max
        XCTAssertEqual(p.budget.candidateCount, BASEffortBudget.forLevel(.max).candidateCount)
        XCTAssertGreaterThan(p.budget.candidateCount, BASEffortBudget.forLevel(.fast).candidateCount)
    }
}
