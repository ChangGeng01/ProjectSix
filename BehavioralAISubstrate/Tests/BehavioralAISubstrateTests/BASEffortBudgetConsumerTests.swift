import XCTest
@testable import BASHostKit
@testable import BASRuntimeCore
@testable import BASMemory

/// TDD for the loop-closing consumer: the effort plan drives the EXISTING BASAgentRouter, so a deeper tier
/// actually wakes MORE agents (more compute) and a shallow tier keeps the roster lean (avoided compute).
final class BASEffortBudgetConsumerTests: XCTestCase {

    // MARK: - Level → EffortPreference mapping

    func testLevelMapsToRouterEffort() {
        XCTAssertEqual(BASEffortBudgetConsumer.agentRouterEffort(for: .fast), .shallow)
        XCTAssertEqual(BASEffortBudgetConsumer.agentRouterEffort(for: .balanced), .standard)
        XCTAssertEqual(BASEffortBudgetConsumer.agentRouterEffort(for: .auto), .standard)
        XCTAssertEqual(BASEffortBudgetConsumer.agentRouterEffort(for: .guarded), .standard)
        XCTAssertEqual(BASEffortBudgetConsumer.agentRouterEffort(for: .deep), .deep)
        XCTAssertEqual(BASEffortBudgetConsumer.agentRouterEffort(for: .max), .deep)
    }

    // MARK: - End-to-end: the plan sizes real agent work through BASAgentRouter

    /// A cold-seat planner is OUT-OF-BAND for a low-risk turn, so it stays asleep under shallow/standard — but a
    /// `.deep` plan pulls it awake ("effort.deep-cold-wake"). This is genuine compute-sizing by the tier.
    private let coldPlanner = BASAgentSpec(
        agentID: "test.coldplanner", role: .planner, writeDomains: [.candidateFrontier],
        defaultLeaseProfile: .coldSeat, visibility: .medium)

    private func activeCount(forApplied applied: BASEffortLevel) -> Int {
        let plan = BASEffortPlan.granted(applied)
        let ctx = BASEffortBudgetConsumer.routerContext(for: plan, riskBand: .low)
        return BASAgentRouter.route(allSpecs: [coldPlanner], context: ctx).activeAgentIDs.count
    }

    func testHighDemandPlanWakesMoreAgentsThanLowDemand() {
        let lean = activeCount(forApplied: .fast)    // → shallow ⇒ cold planner stays out-of-band
        let deep = activeCount(forApplied: .max)     // → deep   ⇒ cold planner woken
        XCTAssertGreaterThan(deep, lean, "a deeper effort tier must wake MORE agents (more compute)")
    }

    func testDeepPlanActivatesTheColdAgentExplicitly() {
        let plan = BASEffortPlan.granted(.deep)
        let ctx = BASEffortBudgetConsumer.routerContext(for: plan, riskBand: .low)
        let result = BASAgentRouter.route(allSpecs: [coldPlanner], context: ctx)
        XCTAssertTrue(result.activeAgentIDs.contains("test.coldplanner"))
        XCTAssertEqual(result.activationReasons["test.coldplanner"], "effort.deep-cold-wake")
    }

    func testFastPlanLeavesColdAgentAsleep() {
        let plan = BASEffortPlan.granted(.fast)
        let ctx = BASEffortBudgetConsumer.routerContext(for: plan, riskBand: .low)
        let result = BASAgentRouter.route(allSpecs: [coldPlanner], context: ctx)
        XCTAssertFalse(result.activeAgentIDs.contains("test.coldplanner"), "fast tier keeps the roster lean")
    }

    func testBudgetCountsRideOnThePlanForFinerSizers() {
        // The finer L8/L9/L10 dials are available off plan.budget for consumers that read them.
        XCTAssertGreaterThan(BASEffortPlan.granted(.max).budget.candidateCount,
                             BASEffortPlan.granted(.fast).budget.candidateCount)
        XCTAssertGreaterThan(BASEffortPlan.granted(.max).budget.criticStrength,
                             BASEffortPlan.granted(.fast).budget.criticStrength)
    }

    // MARK: - runTurn deliberation floor (the LIVE compute consumer)

    func testDeliberationPassesScalesWithTier() {
        XCTAssertEqual(BASEffortBudgetConsumer.deliberationPasses(for: .fast), 1)
        XCTAssertEqual(BASEffortBudgetConsumer.deliberationPasses(for: .balanced), 2)
        XCTAssertEqual(BASEffortBudgetConsumer.deliberationPasses(for: .auto), 2)
        XCTAssertEqual(BASEffortBudgetConsumer.deliberationPasses(for: .guarded), 2)
        XCTAssertEqual(BASEffortBudgetConsumer.deliberationPasses(for: .deep), 4)
        XCTAssertEqual(BASEffortBudgetConsumer.deliberationPasses(for: .max), 6)
    }

    func testFlooredMaxLoopsNilIsPassthrough() {
        XCTAssertEqual(BASEffortBudgetConsumer.flooredMaxLoops(5, effortPlan: nil), 5,
                       "nil plan ⇒ byte-equal passthrough (no effort sizing)")
    }

    func testFlooredMaxLoopsLowTierTightens() {
        // fast (1 pass) floors a routed budget of 5 to 1 — avoided compute.
        XCTAssertEqual(BASEffortBudgetConsumer.flooredMaxLoops(5, effortPlan: .granted(.fast)), 1)
        XCTAssertEqual(BASEffortBudgetConsumer.flooredMaxLoops(5, effortPlan: .granted(.deep)), 4)
    }

    func testFlooredMaxLoopsHighTierNeverRaisesTheRoutedCeiling() {
        // max (6) can only TIGHTEN within the routed ceiling, never exceed it.
        XCTAssertEqual(BASEffortBudgetConsumer.flooredMaxLoops(3, effortPlan: .granted(.max)), 3)
        XCTAssertEqual(BASEffortBudgetConsumer.flooredMaxLoops(8, effortPlan: .granted(.max)), 6)
    }
}
