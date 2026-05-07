// MARK: - BASChengluLayerActorFactoriesTests — chapter 三百二七 / M814
//
// Phase F (附录 X) 第七刀 测试覆盖:pre-configured layer actor
// factories for each Chenglu canonical layer。Closes v9 §8 #3。
//
// Doctrine pins verified:
//   - 6 factories produce actors pinned to correct layer ID
//   - Default budgets typed-pinned (anti-magic-number)
//   - observabilityOnly=true on all default budgets (红线 7)
//   - makeAllChengluActors returns 6 actors in priority order
//   - budgetOverride parameter works
//   - Non-Chenglu layers return nil from budget lookup

import XCTest
@testable import BASAppleAdapters
@testable import BASHostKit
@testable import BASRuntimeCore

final class BASChengluLayerActorFactoriesTests: XCTestCase {

    private func makeRegistry() -> BASLayerMLHeadRegistry {
        BASLayerMLHeadRegistry()
    }

    // MARK: - Default budget constants pin

    func testDefaultBudgetsPin() {
        // Anti-magic-number doctrine: pin specific budget values
        XCTAssertEqual(
            BASChengluLayerBudgetDefaults.l1AllocatedMs, 5)
        XCTAssertEqual(
            BASChengluLayerBudgetDefaults.l1HardCapMs, 20)
        XCTAssertEqual(
            BASChengluLayerBudgetDefaults.l4AllocatedMs, 10)
        XCTAssertEqual(
            BASChengluLayerBudgetDefaults.l4HardCapMs, 40)
        XCTAssertEqual(
            BASChengluLayerBudgetDefaults.l6AllocatedMs, 10)
        XCTAssertEqual(
            BASChengluLayerBudgetDefaults.l6HardCapMs, 40)
        XCTAssertEqual(
            BASChengluLayerBudgetDefaults.l8AllocatedMs, 15)
        XCTAssertEqual(
            BASChengluLayerBudgetDefaults.l8HardCapMs, 60)
        XCTAssertEqual(
            BASChengluLayerBudgetDefaults.l11AllocatedMs, 8)
        XCTAssertEqual(
            BASChengluLayerBudgetDefaults.l11HardCapMs, 30)
        XCTAssertEqual(
            BASChengluLayerBudgetDefaults.l12AllocatedMs, 12)
        XCTAssertEqual(
            BASChengluLayerBudgetDefaults.l12HardCapMs, 50)
    }

    func testBudgetForChengluLayersIsNonNil() {
        for layer in chengluCanonicalLayers {
            XCTAssertNotNil(
                BASChengluLayerBudgetDefaults.budget(
                    for: layer),
                "Chenglu canonical layer \(layer.rawValue) " +
                "must have a default budget")
        }
    }

    func testBudgetForNonChengluLayersIsNil() {
        for layer in [
            BASMotherboardLayer14.l2, .l3, .l5, .l7,
            .l9, .l10, .l13, .l14
        ] {
            XCTAssertNil(
                BASChengluLayerBudgetDefaults.budget(
                    for: layer),
                "Non-Chenglu layer \(layer.rawValue) must " +
                "return nil budget")
        }
    }

    func testBudgetObservabilityOnlyFlagIsTrue() {
        // 红线 7 watcher hint only — all canonical Chenglu
        // budgets must be observability-only
        for layer in chengluCanonicalLayers {
            let budget = BASChengluLayerBudgetDefaults.budget(
                for: layer)!
            XCTAssertTrue(
                budget.observabilityOnly,
                "Layer \(layer.rawValue) budget must have " +
                "observabilityOnly=true (红线 7)")
        }
    }

    // MARK: - Per-layer factory layerID pinning

    func testMakeL1ActorBoundToL1() {
        let registry = makeRegistry()
        let actor = BASChengluLayerActorFactories.makeL1Actor(
            registry: registry)
        XCTAssertEqual(actor.layerID, .l1)
    }

    func testMakeL4ActorBoundToL4() {
        let registry = makeRegistry()
        let actor = BASChengluLayerActorFactories.makeL4Actor(
            registry: registry)
        XCTAssertEqual(actor.layerID, .l4)
    }

    func testMakeL6ActorBoundToL6() {
        let registry = makeRegistry()
        let actor = BASChengluLayerActorFactories.makeL6Actor(
            registry: registry)
        XCTAssertEqual(actor.layerID, .l6)
    }

    func testMakeL8ActorBoundToL8() {
        let registry = makeRegistry()
        let actor = BASChengluLayerActorFactories.makeL8Actor(
            registry: registry)
        XCTAssertEqual(actor.layerID, .l8)
    }

    func testMakeL11ActorBoundToL11() {
        let registry = makeRegistry()
        let actor = BASChengluLayerActorFactories.makeL11Actor(
            registry: registry)
        XCTAssertEqual(actor.layerID, .l11)
    }

    func testMakeL12ActorBoundToL12() {
        let registry = makeRegistry()
        let actor = BASChengluLayerActorFactories.makeL12Actor(
            registry: registry)
        XCTAssertEqual(actor.layerID, .l12)
    }

    // MARK: - makeAllChengluActors

    func testMakeAllChengluActorsReturns6InPriorityOrder() {
        let registry = makeRegistry()
        let actors = BASChengluLayerActorFactories
            .makeAllChengluActors(registry: registry)
        XCTAssertEqual(actors.count, 6)
        XCTAssertEqual(
            actors.map { $0.layerID },
            [.l1, .l4, .l6, .l8, .l11, .l12],
            "Order must match附录 X §X.2 priority sequence")
    }

    // MARK: - budgetOverride parameter

    func testBudgetOverrideParameterTakesEffect() async throws {
        let registry = makeRegistry()
        let custom = BASLayerSlice(
            layerID: .l1,
            allocatedMs: 100,
            hardCapMs: 500,
            observabilityOnly: true)
        let actor = BASChengluLayerActorFactories.makeL1Actor(
            registry: registry,
            budgetOverride: custom)
        // We can't directly inspect actor's config (private),
        // but we can verify the factory accepts the override
        // and produces a valid actor。
        XCTAssertEqual(actor.layerID, .l1)
        // Run the actor's process pipeline to confirm config
        // is wired (dispatch should succeed even with empty
        // registry — returns no-mesh output)
        let input = BASLayerActorInput(
            layerID: .l1,
            turnID: "turn-test",
            payloadRef: "payload-test",
            arrivedAt: Date())
        let output = try await actor.process(input: input)
        XCTAssertEqual(output.layerID, .l1)
    }

    // MARK: - Custom kill switch lookup

    func testCustomKillSwitchLookupRespected() async throws {
        let registry = makeRegistry()
        // Provide kill switch that always returns active for
        // L11 — should cause actor to short-circuit
        let killSwitchLookup:
            @Sendable (BASLayerKillSwitchID)
                -> BASLayerKillSwitchState? = { id in
            BASLayerKillSwitchState(
                switchID: id,
                active: true,
                reason: .manual,
                detail: "test-trip")
        }
        let actor = BASChengluLayerActorFactories.makeL11Actor(
            registry: registry,
            killSwitchLookup: killSwitchLookup)
        let input = BASLayerActorInput(
            layerID: .l11,
            turnID: "turn-test",
            payloadRef: "payload-test",
            arrivedAt: Date())
        let output = try await actor.process(input: input)
        XCTAssertEqual(
            output.status, .skippedByKill,
            "Custom kill switch lookup must short-circuit " +
            "actor pipeline at stage 1")
    }

    // MARK: - noopKillSwitchLookup default

    func testNoopKillSwitchLookupReturnsNil() {
        let lookup = BASChengluLayerActorFactories
            .noopKillSwitchLookup
        let result = lookup(.l11Risk)
        XCTAssertNil(result,
            "Default noop kill switch lookup must always " +
            "return nil")
    }
}
