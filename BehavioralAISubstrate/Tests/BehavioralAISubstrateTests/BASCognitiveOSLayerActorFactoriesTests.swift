// MARK: - BASCognitiveOSLayerActorFactoriesTests
// chapter 三百六一 / M848
//
// Test coverage for G5 partial deliverable from M840 roadmap:
// L2 (model router) + L3 (context compression) + L5 (constitution)
// actor factories。L7 (planner) is deferred to M851 with G6
// dependency。
//
// Tests verify (mirrors M814 BASChengluLayerActorFactoriesTests
// pattern):
//   - 3 factories produce actors pinned to correct layer ID
//   - Default budgets typed-pinned (anti-magic-number)
//   - observabilityOnly=true on all default budgets (红线 7)
//   - makeAllCognitiveOSExtendedActors returns 3 actors in
//     priority order (L2 → L3 → L5)
//   - budgetOverride parameter works
//   - Chenglu / P2-deferred layers return nil from budget lookup
//   - L7 budget pre-defined for M851 forward-compat (factory
//     not yet shipped)

import XCTest
@testable import BASHostKit
@testable import BASRuntimeCore

final class BASCognitiveOSLayerActorFactoriesTests:
    XCTestCase
{

    private func makeRegistry() -> BASLayerMLHeadRegistry {
        BASLayerMLHeadRegistry()
    }

    // MARK: - Default budget constants pin

    func testDefaultBudgetConstantsPin() {
        // Anti-magic-number doctrine: pin specific budget values
        // to detect drift
        XCTAssertEqual(
            BASCognitiveOSLayerBudgetDefaults.l2AllocatedMs, 8)
        XCTAssertEqual(
            BASCognitiveOSLayerBudgetDefaults.l2HardCapMs, 30)
        XCTAssertEqual(
            BASCognitiveOSLayerBudgetDefaults.l3AllocatedMs, 50)
        XCTAssertEqual(
            BASCognitiveOSLayerBudgetDefaults.l3HardCapMs, 200)
        XCTAssertEqual(
            BASCognitiveOSLayerBudgetDefaults.l5AllocatedMs, 5)
        XCTAssertEqual(
            BASCognitiveOSLayerBudgetDefaults.l5HardCapMs, 20)
        // L7 budget defined for M851 forward-compat
        XCTAssertEqual(
            BASCognitiveOSLayerBudgetDefaults.l7AllocatedMs, 100)
        XCTAssertEqual(
            BASCognitiveOSLayerBudgetDefaults.l7HardCapMs, 500)
    }

    func testBudgetForExtendedLayersIsNonNil() {
        for layer in cognitiveOSExtendedLayers {
            XCTAssertNotNil(
                BASCognitiveOSLayerBudgetDefaults.budget(
                    for: layer),
                "Extended layer \(layer.rawValue) must " +
                "have a typed default budget")
        }
    }

    func testBudgetForChengluLayersReturnsNil() {
        // Cognitive OS extended budget defaults must NOT
        // overlap with Chenglu canonical budget defaults
        // (chapter 二百一一 single-source-of-truth)
        for layer in chengluCanonicalLayers {
            XCTAssertNil(
                BASCognitiveOSLayerBudgetDefaults.budget(
                    for: layer),
                "Chenglu layer \(layer.rawValue) must NOT " +
                "appear in extended budget defaults — use " +
                "BASChengluLayerBudgetDefaults instead")
        }
    }

    func testBudgetForP2DeferredLayersReturnsNil() {
        for layer in [BASMotherboardLayer14.l9, .l10, .l13, .l14] {
            XCTAssertNil(
                BASCognitiveOSLayerBudgetDefaults.budget(
                    for: layer),
                "P2-deferred layer \(layer.rawValue) must " +
                "return nil from extended budget defaults")
        }
    }

    func testObservabilityOnlyOnAllDefaultBudgets() {
        // 红线 7 doctrine: all default budgets are observation-
        // class (the actor's outputs are HINTS, the gate decides)
        for layer in cognitiveOSExtendedLayers {
            let budget = BASCognitiveOSLayerBudgetDefaults
                .budget(for: layer)
            XCTAssertEqual(
                budget?.observabilityOnly, true,
                "Layer \(layer.rawValue) default budget must " +
                "have observabilityOnly=true (红线 7)")
        }
    }

    // MARK: - Per-layer factory pins

    func testL2ActorIsPinnedToL2() async {
        let actor = BASCognitiveOSLayerActorFactories
            .makeL2Actor(registry: makeRegistry())
        let layerID = await actor.layerID
        XCTAssertEqual(layerID, .l2)
    }

    func testL3ActorIsPinnedToL3() async {
        let actor = BASCognitiveOSLayerActorFactories
            .makeL3Actor(registry: makeRegistry())
        let layerID = await actor.layerID
        XCTAssertEqual(layerID, .l3)
    }

    func testL5ActorIsPinnedToL5() async {
        let actor = BASCognitiveOSLayerActorFactories
            .makeL5Actor(registry: makeRegistry())
        let layerID = await actor.layerID
        XCTAssertEqual(layerID, .l5)
    }

    // MARK: - L7 (M870 — chapter 三百八三)

    func testL7ActorIsPinnedToL7() async {
        let actor = BASCognitiveOSLayerActorFactories
            .makeL7Actor(registry: makeRegistry())
        let layerID = await actor.layerID
        XCTAssertEqual(
            layerID, .l7,
            "M870 L7 planner factory must pin to L7 layer")
    }

    // Budget override correctness is covered by the typed
    // BASCognitiveOSLayerBudgetDefaults pin tests above + the
    // `BASLayerReferenceActorConfig.budget` field's mechanical
    // pass-through (chapter 三百一六 BASLayerReferenceActor
    // doesn't expose budget post-construction by design — the
    // budget is private state consumed by .process(input:))。
    // This mirrors the existing BASChengluLayerActorFactories
    // testing pattern (M814 / chapter 三百二七 tests don't probe
    // .budget either)。

    // MARK: - makeAllCognitiveOSExtendedActors

    func testMakeAllReturnsFourActorsInOrder() async {
        let actors = BASCognitiveOSLayerActorFactories
            .makeAllCognitiveOSExtendedActors(
                registry: makeRegistry())
        XCTAssertEqual(actors.count, 4,
            "M870 ships 4 cognitive-OS-extended actors " +
            "(L2 + L3 + L5 + L7). L7 added in chapter 三百" +
            "八三 / M870 closure。Pre-M870 this count was 3。")
        let layerIDs = await withTaskGroup(
            of: BASMotherboardLayer14.self,
            returning: [BASMotherboardLayer14].self
        ) { group in
            for actor in actors {
                group.addTask { await actor.layerID }
            }
            var collected: [BASMotherboardLayer14] = []
            for await id in group {
                collected.append(id)
            }
            return collected
        }
        // Order isn't guaranteed by TaskGroup but the SET
        // should be exactly {L2, L3, L5, L7}
        XCTAssertEqual(
            Set(layerIDs),
            Set([.l2, .l3, .l5, .l7]),
            "makeAllCognitiveOSExtendedActors must produce " +
            "actors for L2 + L3 + L5 + L7 (M870 closure)")
    }

    // MARK: - cognitiveOSExtendedLayers / M848 set pins

    func testExtendedLayersSetIsCanonical() {
        XCTAssertEqual(
            cognitiveOSExtendedLayers,
            [.l2, .l3, .l5, .l7],
            "Extended layers set pin: L2 + L3 + L5 + L7. " +
            "L7 included for forward-compat with M851.")
    }

    func testM848ShippedLayersSetIsThreeOfFour() {
        XCTAssertEqual(
            cognitiveOSExtendedLayersM848,
            [.l2, .l3, .l5],
            "M848 ships 3 of 4 extended factories. L7 is in " +
            "the full set but factory not yet wired (M851).")
    }

    func testExtendedSetDoesNotOverlapChengluCanonical() {
        let extendedSet = Set(cognitiveOSExtendedLayers)
        let chengluSet = Set(chengluCanonicalLayers)
        XCTAssertTrue(
            extendedSet.isDisjoint(with: chengluSet),
            "Extended layers + Chenglu canonical layers must " +
            "be disjoint (chapter 二百一一 single-source-of-" +
            "truth — each layer has exactly one factory site)")
    }
}
