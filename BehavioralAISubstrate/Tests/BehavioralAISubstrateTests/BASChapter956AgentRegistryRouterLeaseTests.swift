// MARK: - BASChapter956AgentRegistryRouterLeaseTests
// chapter 九百五十六 / M3485 (Phase 1 / ch1)
//
// Tests for the 3 Phase 1 ch1 sub-systems:
//   1. BASAgentRegistry actor — register / discover agents
//   2. BASAgentRouter pure-fn — per-turn activation decision
//   3. BASAgentLeaseManager pure-fn — lease materialization
//
// Per plan: LOW risk — wiring only,no per-turn touch yet。
//
// Coverage:
//   Registry: register / unregister / strict-role / by-role lookup
//   Router: low / med / high band activation + watchers always-on +
//           sovereign always-on + effort=deep wakes cold + caller overrides
//   LeaseManager: per-profile multipliers + per-effort multipliers +
//                 token/state-read/delta-write ceilings + allowed-domains
//                 = (read + write) − forbidden

import XCTest
@testable import BASMemory

final class BASChapter956AgentRegistryRouterLeaseTests:
    XCTestCase
{

    // MARK: - Helpers

    private func mkSpec(
        _ id: String,
        role: BASAgentRole,
        write: [BASStateDomain] = [],
        read: [BASStateDomain] = [],
        forbidden: [BASStateDomain] = [],
        profile: BASAgentLeaseProfile = .hotSeat,
        visibility: BASAgentVisibility = .high
    ) -> BASAgentSpec {
        BASAgentSpec(
            agentID: id, role: role,
            readDomains: read,
            writeDomains: write,
            forbiddenDomains: forbidden,
            defaultLeaseProfile: profile,
            visibility: visibility)
    }

    // MARK: - 1. Registry

    func testRegistryAppendAndLookup() async throws {
        let reg = BASAgentRegistry()
        try await reg.register(mkSpec("p1", role: .planner))
        try await reg.register(mkSpec("c1", role: .critic))
        let plannerSpec = try await reg.spec(forAgent: "p1")
        XCTAssertEqual(plannerSpec.agentID, "p1")
        XCTAssertEqual(plannerSpec.role, .planner)
        let allPlanners = await reg.specs(forRole: .planner)
        XCTAssertEqual(allPlanners.count, 1)
        let count = await reg.count()
        let hasPlanner = await reg.hasRole(.planner)
        let hasMemory = await reg.hasRole(.memory)
        XCTAssertEqual(count, 2)
        XCTAssertTrue(hasPlanner)
        XCTAssertFalse(hasMemory)
    }

    func testRegistryReRegisterOverwrites() async throws {
        let reg = BASAgentRegistry()
        try await reg.register(mkSpec("p1", role: .planner))
        try await reg.register(mkSpec("p1", role: .planner))
        // Same ID re-registered → count stays 1, registration
        // order has no duplicate
        let count = await reg.count()
        XCTAssertEqual(count, 1)
    }

    func testRegistryUnregisterUnknownThrows() async {
        let reg = BASAgentRegistry()
        do {
            try await reg.unregister(agentID: "nonexistent")
            XCTFail("unknown agent unregister should throw")
        } catch BASAgentRegistry.RegistryError.unknownAgent {
            // expected
        } catch {
            XCTFail("wrong error: \(error)")
        }
    }

    func testRegistryStrictRoleUniqueness() async throws {
        let reg = BASAgentRegistry(strictRoleUniqueness: true)
        try await reg.register(mkSpec("p1", role: .planner))
        do {
            try await reg.register(mkSpec("p2", role: .planner))
            XCTFail("strict mode should reject duplicate role")
        } catch BASAgentRegistry.RegistryError
            .duplicateRoleInStrictMode(
                let role, let existing, let new)
        {
            XCTAssertEqual(role, .planner)
            XCTAssertEqual(existing, "p1")
            XCTAssertEqual(new, "p2")
        } catch {
            XCTFail("wrong error: \(error)")
        }
    }

    func testRegistryNonStrictAllowsMultipleWatchers() async throws {
        let reg = BASAgentRegistry(strictRoleUniqueness: false)
        try await reg.register(
            mkSpec("w1", role: .anomalyWatcher))
        try await reg.register(
            mkSpec("w2", role: .anomalyWatcher))
        let watchers = await reg.specs(
            forRole: .anomalyWatcher)
        XCTAssertEqual(watchers.count, 2)
    }

    // MARK: - 2. Router activation

    private func makeFullPool() -> [BASAgentSpec] {
        [
            mkSpec("scout-1", role: .scout, profile: .hotSeat),
            mkSpec("planner-1", role: .planner,
                   profile: .coldSeat),
            mkSpec("critic-1", role: .critic, profile: .coldSeat),
            mkSpec("memory-1", role: .memory, profile: .coldSeat),
            mkSpec("risk-1", role: .risk, profile: .hotSeat),
            mkSpec("surface-1", role: .surface, profile: .hotSeat),
            mkSpec("hostAlign-1", role: .hostAlignment,
                   profile: .hotSeat, visibility: .medium),
            mkSpec("sovereign-1", role: .sovereignSentinel,
                   profile: .sovereign, visibility: .low),
            mkSpec("seal-1", role: .deleteRollbackSeal,
                   profile: .sovereign, visibility: .low),
            mkSpec("watcher-anomaly-1",
                   role: .anomalyWatcher,
                   profile: .watcher,
                   visibility: .medium),
            mkSpec("watcher-gaslight-1",
                   role: .gaslightWatcher,
                   profile: .watcher,
                   visibility: .medium),
        ]
    }

    func testRouterLowBandActivatesMinimalSet() {
        let pool = makeFullPool()
        let ctx = BASAgentRouterContext(riskBand: .low)
        let plan = BASAgentRouter.route(
            allSpecs: pool, context: ctx)
        let activeIDs = Set(plan.activeAgentIDs)
        // Low band: scout + surface
        XCTAssertTrue(activeIDs.contains("scout-1"))
        XCTAssertTrue(activeIDs.contains("surface-1"))
        // Always-on: sovereign-LOW + watchers
        XCTAssertTrue(activeIDs.contains("sovereign-1"))
        XCTAssertTrue(activeIDs.contains("seal-1"))
        XCTAssertTrue(activeIDs.contains("watcher-anomaly-1"))
        XCTAssertTrue(activeIDs.contains("watcher-gaslight-1"))
        // NOT activated at low band
        XCTAssertFalse(activeIDs.contains("planner-1"))
        XCTAssertFalse(activeIDs.contains("critic-1"))
        XCTAssertFalse(activeIDs.contains("memory-1"))
    }

    func testRouterMedBandAddsPlannerAndRisk() {
        let pool = makeFullPool()
        let ctx = BASAgentRouterContext(riskBand: .medium)
        let plan = BASAgentRouter.route(
            allSpecs: pool, context: ctx)
        let activeIDs = Set(plan.activeAgentIDs)
        XCTAssertTrue(activeIDs.contains("planner-1"))
        XCTAssertTrue(activeIDs.contains("risk-1"))
        // Memory + Critic still NOT activated until high band
        XCTAssertFalse(activeIDs.contains("memory-1"))
        XCTAssertFalse(activeIDs.contains("critic-1"))
    }

    func testRouterHighBandActivatesAll() {
        let pool = makeFullPool()
        let ctx = BASAgentRouterContext(riskBand: .high)
        let plan = BASAgentRouter.route(
            allSpecs: pool, context: ctx)
        let activeIDs = Set(plan.activeAgentIDs)
        XCTAssertTrue(activeIDs.contains("scout-1"))
        XCTAssertTrue(activeIDs.contains("surface-1"))
        XCTAssertTrue(activeIDs.contains("planner-1"))
        XCTAssertTrue(activeIDs.contains("risk-1"))
        XCTAssertTrue(activeIDs.contains("memory-1"))
        XCTAssertTrue(activeIDs.contains("critic-1"))
        XCTAssertTrue(activeIDs.contains("hostAlign-1"))
        XCTAssertTrue(activeIDs.contains("sovereign-1"))
    }

    func testRouterDeepEffortWakesColdSeats() {
        let pool = makeFullPool()
        let lowDeep = BASAgentRouterContext(
            riskBand: .low, effortPreference: .deep)
        let plan = BASAgentRouter.route(
            allSpecs: pool, context: lowDeep)
        let activeIDs = Set(plan.activeAgentIDs)
        // Deep at low band wakes cold seats: planner / critic / memory
        XCTAssertTrue(activeIDs.contains("planner-1"))
        XCTAssertTrue(activeIDs.contains("critic-1"))
        XCTAssertTrue(activeIDs.contains("memory-1"))
        XCTAssertEqual(
            plan.activationReasons["planner-1"],
            "effort.deep-cold-wake")
    }

    func testRouterCallerOverrideAlwaysActivates() {
        let pool = makeFullPool()
        // Low band normally excludes critic, but caller insists
        let ctx = BASAgentRouterContext(
            riskBand: .low,
            requestedAgentIDs: ["critic-1"])
        let plan = BASAgentRouter.route(
            allSpecs: pool, context: ctx)
        XCTAssertTrue(plan.activeAgentIDs.contains("critic-1"))
        XCTAssertEqual(
            plan.activationReasons["critic-1"],
            "requested.user-override")
    }

    func testRouterIgnoresUnknownOverride() {
        let pool = makeFullPool()
        let ctx = BASAgentRouterContext(
            riskBand: .low,
            requestedAgentIDs: ["nonexistent-id"])
        let plan = BASAgentRouter.route(
            allSpecs: pool, context: ctx)
        XCTAssertFalse(
            plan.activeAgentIDs.contains("nonexistent-id"))
    }

    func testRouterEmptyPoolEmptyPlan() {
        let plan = BASAgentRouter.route(
            allSpecs: [],
            context: BASAgentRouterContext(riskBand: .high))
        XCTAssertTrue(plan.activeAgentIDs.isEmpty)
    }

    // MARK: - 3. Lease manager

    func testLeaseManagerHotSeatStandardEffort() {
        let spec = mkSpec(
            "p1", role: .planner,
            write: [.candidateFrontier],
            read: [.situationField],
            profile: .hotSeat)
        let lease = BASAgentLeaseManager.materialize(
            spec: spec,
            turnID: "t-1",
            effort: .standard,
            turnStartMs: 1_700_000_000_000)
        XCTAssertEqual(lease.agentID, "p1")
        XCTAssertEqual(lease.turnID, "t-1")
        XCTAssertEqual(lease.maxMs, 200)   // hot × standard × 1.0
        XCTAssertEqual(lease.maxTokens, 1024)
        XCTAssertEqual(lease.maxStateReads, 50)
        XCTAssertEqual(lease.maxDeltaWrites, 10)
        XCTAssertEqual(
            lease.expiresAtMs, 1_700_000_000_200)
        XCTAssertEqual(lease.priority, 5)
        // Allowed = read ∪ write,sorted by raw value
        XCTAssertEqual(lease.allowedDomains.count, 2)
        XCTAssertTrue(lease.allowedDomains
            .contains(.candidateFrontier))
        XCTAssertTrue(lease.allowedDomains
            .contains(.situationField))
    }

    func testLeaseManagerDeepEffortScalesUp() {
        let spec = mkSpec(
            "p1", role: .planner,
            write: [.candidateFrontier],
            profile: .hotSeat)
        let lease = BASAgentLeaseManager.materialize(
            spec: spec,
            turnID: "t-1",
            effort: .deep,
            turnStartMs: 1_700_000_000_000)
        // Deep multiplier 3.0 → 200 × 3.0 × hot=1.0 = 600
        XCTAssertEqual(lease.maxMs, 600)
        XCTAssertEqual(lease.maxTokens, 1024 * 3)
    }

    func testLeaseManagerColdSeatGetsLargerBudget() {
        let spec = mkSpec(
            "p1", role: .planner,
            write: [.candidateFrontier],
            profile: .coldSeat)
        let lease = BASAgentLeaseManager.materialize(
            spec: spec, turnID: "t-1", effort: .standard,
            turnStartMs: 1_700_000_000_000)
        // Cold profile mul = 5.0 → 200 × 1.0 × 5.0 = 1000
        XCTAssertEqual(lease.maxMs, 1000)
        XCTAssertEqual(lease.maxStateReads, 500)
        XCTAssertEqual(lease.maxDeltaWrites, 50)
    }

    func testLeaseManagerWatcherGetsTinyBudget() {
        let spec = mkSpec(
            "w1", role: .anomalyWatcher,
            read: [.situationField],
            profile: .watcher)
        let lease = BASAgentLeaseManager.materialize(
            spec: spec, turnID: "t-1", effort: .standard,
            turnStartMs: 1_700_000_000_000)
        // Watcher profile mul 0.1 → 200 × 1.0 × 0.1 = 20
        XCTAssertEqual(lease.maxMs, 20)
        XCTAssertEqual(lease.maxTokens, 0)  // watchers no tokens
        XCTAssertEqual(lease.maxDeltaWrites, 0)  // no writes
    }

    func testLeaseManagerSovereignGetsHeadroom() {
        let spec = mkSpec(
            "s1", role: .sovereignSentinel,
            read: BASStateDomain.allCases,
            profile: .sovereign,
            visibility: .low)
        let lease = BASAgentLeaseManager.materialize(
            spec: spec, turnID: "t-1", effort: .standard,
            turnStartMs: 1_700_000_000_000)
        // Sovereign profile mul 10.0 → 200 × 1.0 × 10.0 = 2000
        XCTAssertEqual(lease.maxMs, 2000)
        XCTAssertEqual(lease.priority, Int.max)
        XCTAssertEqual(lease.maxTokens, 0)  // sovereign no LLM tokens
    }

    func testLeaseManagerForbiddenDomainsExcludedFromAllowed() {
        let spec = mkSpec(
            "buggy", role: .planner,
            write: [.candidateFrontier, .hostVersion],
            read: [.situationField, .memoryBundle],
            forbidden: [.hostVersion, .memoryBundle])
        let lease = BASAgentLeaseManager.materialize(
            spec: spec, turnID: "t-1", effort: .standard,
            turnStartMs: 1_700_000_000_000)
        // Forbidden wins:hostVersion + memoryBundle excluded
        XCTAssertFalse(lease.allowedDomains.contains(.hostVersion))
        XCTAssertFalse(lease.allowedDomains.contains(.memoryBundle))
        XCTAssertTrue(lease.allowedDomains
            .contains(.candidateFrontier))
        XCTAssertTrue(lease.allowedDomains
            .contains(.situationField))
    }

    func testMaterializeAllProducesLeasesForActivePlan() {
        let pool = makeFullPool()
        let ctx = BASAgentRouterContext(
            riskBand: .high, effortPreference: .standard)
        let plan = BASAgentRouter.route(
            allSpecs: pool, context: ctx)
        let leases = BASAgentLeaseManager.materializeAll(
            plan: plan,
            registry: pool,
            turnID: "t-1",
            effort: .standard,
            turnStartMs: 1_700_000_000_000)
        // One lease per active agent
        XCTAssertEqual(leases.count, plan.activeAgentIDs.count)
        // Each lease's agentID is in the active plan
        let activeSet = Set(plan.activeAgentIDs)
        for lease in leases {
            XCTAssertTrue(activeSet.contains(lease.agentID))
        }
        // Lease IDs are unique
        let leaseIDs = Set(leases.map { $0.leaseID })
        XCTAssertEqual(leaseIDs.count, leases.count)
    }
}
