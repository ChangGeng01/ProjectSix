// MARK: - BASCognitiveOSP2LayerActorFactoriesTests
// chapter 三百六八 / M855
//
// Test coverage for the L9/L10/L13/L14 actor factory completion。
// Combined with M814 (Chenglu set: L1/L4/L6/L8/L11/L12) + M848
// (extended set: L2/L3/L5/L7), all 14 motherboard layers now
// have typed actor factories。

import XCTest
@testable import BASHostKit
@testable import BASRuntimeCore

final class BASCognitiveOSP2LayerActorFactoriesTests:
    XCTestCase
{

    private func makeRegistry() -> BASLayerMLHeadRegistry {
        BASLayerMLHeadRegistry()
    }

    // MARK: - Default budget pin

    func testDefaultBudgetConstantsPin() {
        XCTAssertEqual(
            BASCognitiveOSP2LayerBudgetDefaults
                .l9AllocatedMs, 80)
        XCTAssertEqual(
            BASCognitiveOSP2LayerBudgetDefaults
                .l9HardCapMs, 400)
        XCTAssertEqual(
            BASCognitiveOSP2LayerBudgetDefaults
                .l10AllocatedMs, 6)
        XCTAssertEqual(
            BASCognitiveOSP2LayerBudgetDefaults
                .l10HardCapMs, 25)
        XCTAssertEqual(
            BASCognitiveOSP2LayerBudgetDefaults
                .l13AllocatedMs, 200)
        XCTAssertEqual(
            BASCognitiveOSP2LayerBudgetDefaults
                .l13HardCapMs, 1000)
        XCTAssertEqual(
            BASCognitiveOSP2LayerBudgetDefaults
                .l14AllocatedMs, 10)
        XCTAssertEqual(
            BASCognitiveOSP2LayerBudgetDefaults
                .l14HardCapMs, 40)
    }

    func testBudgetForP2LayersIsNonNil() {
        for layer in cognitiveOSP2Layers {
            XCTAssertNotNil(
                BASCognitiveOSP2LayerBudgetDefaults
                    .budget(for: layer),
                "P2 advanced layer \(layer.rawValue) must " +
                "have a typed default budget")
        }
    }

    func testBudgetForChengluLayersReturnsNil() {
        for layer in chengluCanonicalLayers {
            XCTAssertNil(
                BASCognitiveOSP2LayerBudgetDefaults
                    .budget(for: layer),
                "Chenglu canonical layer must NOT appear in " +
                "P2 budget defaults — chapter 二百一一 single-" +
                "source-of-truth")
        }
    }

    func testBudgetForExtendedLayersReturnsNil() {
        for layer in cognitiveOSExtendedLayers {
            XCTAssertNil(
                BASCognitiveOSP2LayerBudgetDefaults
                    .budget(for: layer),
                "Extended (M848) layer must NOT appear in " +
                "P2 budget defaults")
        }
    }

    func testObservabilityOnlyOnAllDefaultBudgets() {
        for layer in cognitiveOSP2Layers {
            let budget = BASCognitiveOSP2LayerBudgetDefaults
                .budget(for: layer)
            XCTAssertEqual(
                budget?.observabilityOnly, true,
                "Layer \(layer.rawValue) default budget must " +
                "have observabilityOnly=true (红线 7)")
        }
    }

    // MARK: - Per-layer factory pins

    func testL9ActorIsPinnedToL9() async {
        let actor = BASCognitiveOSP2LayerActorFactories
            .makeL9Actor(registry: makeRegistry())
        let layerID = await actor.layerID
        XCTAssertEqual(layerID, .l9)
    }

    func testL10ActorIsPinnedToL10() async {
        let actor = BASCognitiveOSP2LayerActorFactories
            .makeL10Actor(registry: makeRegistry())
        let layerID = await actor.layerID
        XCTAssertEqual(layerID, .l10)
    }

    func testL13ActorIsPinnedToL13() async {
        let actor = BASCognitiveOSP2LayerActorFactories
            .makeL13Actor(registry: makeRegistry())
        let layerID = await actor.layerID
        XCTAssertEqual(layerID, .l13)
    }

    func testL14ActorIsPinnedToL14() async {
        let actor = BASCognitiveOSP2LayerActorFactories
            .makeL14Actor(registry: makeRegistry())
        let layerID = await actor.layerID
        XCTAssertEqual(layerID, .l14)
    }

    // MARK: - makeAllP2Actors

    func testMakeAllP2ReturnsFourActors() async {
        let actors = BASCognitiveOSP2LayerActorFactories
            .makeAllP2Actors(
                registry: makeRegistry())
        XCTAssertEqual(actors.count, 4,
            "M855 ships 4 P2 advanced actors (L9 + L10 + " +
            "L13 + L14). Combined with M814 + M848, all 14 " +
            "motherboard layers now have typed factories.")
    }

    // MARK: - cognitiveOSP2Layers set pin

    func testP2LayersSetIsCanonical() {
        XCTAssertEqual(
            cognitiveOSP2Layers,
            [.l9, .l10, .l13, .l14],
            "P2 advanced layer set pin")
    }

    // MARK: - Disjoint sets pin (chapter 二百一一)

    func testP2DisjointFromChenglu() {
        let p2Set = Set(cognitiveOSP2Layers)
        let chengluSet = Set(chengluCanonicalLayers)
        XCTAssertTrue(
            p2Set.isDisjoint(with: chengluSet),
            "P2 layers must be disjoint from Chenglu canonical " +
            "(no double-factory)")
    }

    func testP2DisjointFromExtended() {
        let p2Set = Set(cognitiveOSP2Layers)
        let extendedSet = Set(cognitiveOSExtendedLayers)
        XCTAssertTrue(
            p2Set.isDisjoint(with: extendedSet),
            "P2 layers must be disjoint from extended (M848)")
    }

    // MARK: - All-14 coverage pin (architectural)

    /// **Architectural pin** — combining the 3 factory namespaces
    /// (Chenglu canonical M814 + extended M848 + P2 M855)
    /// covers all 14 motherboard layers exactly once。
    func testAllFourteenLayersHaveExactlyOneFactorySite() {
        let chenglu = Set(chengluCanonicalLayers)
        let extended = Set(cognitiveOSExtendedLayers)
        let p2 = Set(cognitiveOSP2Layers)
        let union = chenglu.union(extended).union(p2)
        XCTAssertEqual(
            union.count, 14,
            "Union of 3 factory namespaces must cover all 14 " +
            "motherboard layers (M814 + M848 + M855 = 6+4+4=14)")
        for layer in BASMotherboardLayer14.allCases {
            XCTAssertTrue(
                union.contains(layer),
                "Layer \(layer.rawValue) must be covered by " +
                "exactly one factory namespace")
        }
        // Verify no overlap (each layer in exactly ONE set)
        XCTAssertEqual(
            chenglu.count + extended.count + p2.count,
            14,
            "Sum of cardinalities must equal 14 (no overlap)")
    }
}
