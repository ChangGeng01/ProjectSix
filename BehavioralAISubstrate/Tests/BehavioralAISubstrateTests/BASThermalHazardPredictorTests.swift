import XCTest
@testable import BASRuntimeCore

/// B4 预测式热控 — the pure duty-budget hazard predictor (no device, no clock).
/// Semantics under test (FRONTIER_2026H2 B4, EnerInfer pattern):
///  • decode duty accumulates ONLY inside the current nominal window
///  • idle refunds duty at recoveryCredit (heat sheds) with a floor at 0
///  • hazard fires when duty ≥ learnedBudget × safetyFraction, ONLY while still nominal
///    (once fair actually arrives, the REACTIVE layer owns the response)
///  • a nominal→fair transition LEARNS the budget (EMA toward the observed duty)
///  • recovery to nominal resets the window
final class BASThermalHazardPredictorTests: XCTestCase {

    private var cfg: BASThermalHazardPredictor.Config {
        var c = BASThermalHazardPredictor.Config()
        c.priorNominalDutyBudget = 100
        c.safetyFraction = 0.8
        c.recoveryCredit = 0.5
        c.emaAlpha = 0.4
        c.cooldownSeconds = 4
        return c
    }

    func testNoHazardFreshAndBelowLine() {
        var p = BASThermalHazardPredictor(config: cfg)
        p.recordTier(0)
        p.recordDecode(seconds: 50)
        XCTAssertFalse(p.hazard, "50 < 80 (100×0.8) — no hazard")
        XCTAssertNil(p.recommendedCooldown)
    }

    func testHazardAtSafetyLineWhileNominal() {
        var p = BASThermalHazardPredictor(config: cfg)
        p.recordTier(0)
        p.recordDecode(seconds: 80)
        XCTAssertTrue(p.hazard, "duty 80 ≥ 100×0.8 while nominal ⇒ pre-throttle")
        XCTAssertEqual(p.recommendedCooldown, 4)
    }

    func testNoHazardOnceActuallyFair() {
        var p = BASThermalHazardPredictor(config: cfg)
        p.recordTier(0)
        p.recordDecode(seconds: 90)
        p.recordTier(1)                       // fair arrived — reactive layer owns it now
        XCTAssertFalse(p.hazard, "prediction is a NOMINAL-zone instrument only")
    }

    func testIdleRefundsDutyWithFloor() {
        var p = BASThermalHazardPredictor(config: cfg)
        p.recordTier(0)
        p.recordDecode(seconds: 80)
        XCTAssertTrue(p.hazard)
        p.recordIdle(seconds: 20)             // −20×0.5 = −10 → duty 70 < 80
        XCTAssertFalse(p.hazard, "cooldown gaps must shed duty (the shaping mechanism)")
        p.recordIdle(seconds: 1_000)
        XCTAssertEqual(p.dutyInWindow, 0, accuracy: 1e-9, "refund floors at zero")
    }

    func testTransitionLearnsBudgetByEMA() {
        var p = BASThermalHazardPredictor(config: cfg)
        p.recordTier(0)
        p.recordDecode(seconds: 60)
        p.recordTier(1)                       // observed: nominal absorbed only 60 before fair
        // EMA: 0.6×100 + 0.4×60 = 84
        XCTAssertEqual(p.learnedBudget, 84, accuracy: 1e-9)
        XCTAssertEqual(p.observedTransitions, 1)
        // recovery resets the window; the tighter budget now trips earlier
        p.recordTier(0)
        XCTAssertEqual(p.dutyInWindow, 0, accuracy: 1e-9)
        p.recordDecode(seconds: 68)
        XCTAssertTrue(p.hazard, "67.2 (84×0.8) ≤ 68 under the learned budget")
    }

    func testDutyFrozenWhileHot() {
        var p = BASThermalHazardPredictor(config: cfg)
        p.recordTier(0)
        p.recordDecode(seconds: 30)
        p.recordTier(2)                       // straight to serious — learns budget = 0.6×100+0.4×30 = 72
        p.recordDecode(seconds: 500)          // decode while hot must NOT count into the window
        p.recordTier(0)                       // recovery
        XCTAssertEqual(p.dutyInWindow, 0, accuracy: 1e-9)
        p.recordDecode(seconds: 50)
        XCTAssertEqual(p.dutyInWindow, 50, accuracy: 1e-9, "hot-zone decode never leaked into the window")
        XCTAssertFalse(p.hazard, "50 < 72×0.8=57.6 under the learned budget")
    }

    func testSkipLevelTransitionStillLearns() {
        var p = BASThermalHazardPredictor(config: cfg)
        p.recordTier(0)
        p.recordDecode(seconds: 50)
        p.recordTier(2)                       // nominal → serious directly (fast ramp)
        XCTAssertEqual(p.learnedBudget, 80, accuracy: 1e-9,
                       "0.6×100+0.4×50 — any nominal→hot exit is a budget observation")
        XCTAssertEqual(p.observedTransitions, 1)
    }
}
