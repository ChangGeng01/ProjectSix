// MARK: - BAS14LayerMeshAssemblerTests — chapter 三百一七 / M804
//
// Phase Epsilon 第四刀 测试覆盖:end-to-end mesh assembly。Verifies
// the full Phase Beta + Delta + Epsilon stack composes into a
// usable mesh in one line。

import XCTest
@testable import BASRuntimeCore

final class BAS14LayerMeshAssemblerTests: XCTestCase {

    // MARK: - Assembly produces complete registry

    func testAssemblyPopulatesAll41Slots() async throws {
        let (registry, report) = try await BAS14LayerMeshAssembler
            .assembleCanonicalRulesPlaceholder()
        XCTAssertEqual(report.registeredHeadCount, 41)
        XCTAssertEqual(report.totalCanonicalSlots, 41)
        XCTAssertTrue(report.isComplete)
        let registryCount = await registry.totalHeadCount
        XCTAssertEqual(registryCount, 41)
    }

    func testPerLayerCountMatchesCanonicalShape() async throws {
        let (_, report) = try await BAS14LayerMeshAssembler
            .assembleCanonicalRulesPlaceholder()
        // L1=3 / L2=0 / L3=0 / L4=3 / L5=3 / L6=3 / L7=3 / L8=4
        // / L9=3 / L10=3 / L11=4 / L12=4 / L13=3 / L14=5
        XCTAssertEqual(report.perLayerCounts[.l1], 3)
        XCTAssertEqual(report.perLayerCounts[.l4], 3)
        XCTAssertEqual(report.perLayerCounts[.l8], 4)
        XCTAssertEqual(report.perLayerCounts[.l11], 4)
        XCTAssertEqual(report.perLayerCounts[.l12], 4)
        XCTAssertEqual(report.perLayerCounts[.l14], 5)
        // L2/L3 have no model-layer heads
        XCTAssertNil(report.perLayerCounts[.l2])
        XCTAssertNil(report.perLayerCounts[.l3])
    }

    // MARK: - Registered heads have canonical IDs

    func testRegisteredHeadIDsUseCanonicalNamingPattern()
        async throws
    {
        let (registry, _) = try await BAS14LayerMeshAssembler
            .assembleCanonicalRulesPlaceholder()
        let allSlots = await registry.allSlots
        for slot in allSlots {
            // Pattern: rules.<layerID>.<headRole>
            XCTAssertTrue(
                slot.headID.hasPrefix("rules.\(slot.layerID.rawValue)."),
                "registered head ID '\(slot.headID)' should " +
                "start with 'rules.\(slot.layerID.rawValue).'")
        }
    }

    func testL14HasMetaCalibrationHeadAfterAssembly()
        async throws
    {
        let (registry, _) = try await BAS14LayerMeshAssembler
            .assembleCanonicalRulesPlaceholder()
        let l14Slots = await registry.slots(forLayer: .l14)
        let metaCalSlot = l14Slots.first {
            $0.headID == "rules.l14.meta-calibration-head"
        }
        XCTAssertNotNil(metaCalSlot,
            "L14 meta-calibration-head must be registered after " +
            "canonical assembly (chapter 一百七十七 vision keystone)")
    }

    // MARK: - End-to-end: cascade runs against assembled mesh

    func testCascadeOnAssembledMeshFallsThroughForAllLayers()
        async throws
    {
        let (registry, _) = try await BAS14LayerMeshAssembler
            .assembleCanonicalRulesPlaceholder()
        // Every placeholder is .makeAlwaysFallthrough → cascade
        // for every layer should result in .fallenThrough
        for layer in [
            BASMotherboardLayer14.l4,
            .l8, .l11, .l14
        ] {
            let input = BASLayerInferenceInput(
                layerID: layer,
                featureRef: "test")
            let result = try await BASLayerCascadeRunner.run(
                input: input, registry: registry, layerID: layer)
            XCTAssertEqual(
                result.outcome, .fallenThrough,
                "all rules-tier placeholders return .unknown → " +
                "cascade falls through for every layer")
            XCTAssertGreaterThan(
                result.triedHeads.count, 0,
                "audit trail must include all placeholder heads " +
                "for layer \(layer)")
        }
    }

    // MARK: - End-to-end: reference actor runs against mesh

    func testReferenceActorRunsAgainstAssembledMesh()
        async throws
    {
        let (registry, _) = try await BAS14LayerMeshAssembler
            .assembleCanonicalRulesPlaceholder()
        let config = BASLayerReferenceActorConfig(
            layerID: .l11,
            budget: BASLayerSlice(
                layerID: .l11,
                allocatedMs: 50,
                hardCapMs: 200),
            registry: registry,
            killSwitchLookup: { _ in nil })
        let actor = BASLayerReferenceActor(config: config)
        let input = BASLayerActorInput(
            layerID: .l11,
            turnID: "mesh-test-turn",
            payloadRef: "mesh-test-payload",
            arrivedAt: Date(timeIntervalSince1970: 1_700_000_000))
        let output = try await actor.process(input: input)
        // L11 has 4 placeholder heads, all .unknown → cascade
        // falls through → reference actor maps to .mlHeadFallthrough
        XCTAssertEqual(output.status, .mlHeadFallthrough)
        XCTAssertTrue(
            output.reasonCodes.contains(
                "cascade-attempts:4"),
            "L11 has 4 canonical heads — actor's cascade audit " +
            "trail must reflect all 4 attempts")
        XCTAssertTrue(
            output.reasonCodes.contains(
                "cascade-outcome:fallen-through"))
    }

    // MARK: - Reason codes

    func testReasonCodesContainAssemblyMetadata() async throws {
        let (_, report) = try await BAS14LayerMeshAssembler
            .assembleCanonicalRulesPlaceholder()
        let codes = BAS14LayerMeshAssembler.reasonCodes(
            for: report)
        XCTAssertTrue(
            codes.contains("mesh-assembly:registered:41"))
        XCTAssertTrue(
            codes.contains("mesh-assembly:canonical-total:41"))
        XCTAssertTrue(
            codes.contains("mesh-assembly:complete:true"))
        XCTAssertTrue(
            codes.contains("mesh-assembly:layer-l14:5"),
            "L14 has 5 heads in canonical map")
    }

    // MARK: - Idempotence: assembly produces fresh registries

    func testAssemblyProducesIndependentRegistries() async throws {
        let (r1, _) = try await BAS14LayerMeshAssembler
            .assembleCanonicalRulesPlaceholder()
        let (r2, _) = try await BAS14LayerMeshAssembler
            .assembleCanonicalRulesPlaceholder()
        let count1 = await r1.totalHeadCount
        let count2 = await r2.totalHeadCount
        XCTAssertEqual(count1, 41)
        XCTAssertEqual(count2, 41)
        // r1 and r2 are distinct registries — unregistering from
        // one doesn't affect the other.
        let removed = await r1.unregister(
            headID: "rules.l11.risk-scorer")
        XCTAssertTrue(removed)
        let r1AfterCount = await r1.totalHeadCount
        let r2AfterCount = await r2.totalHeadCount
        XCTAssertEqual(r1AfterCount, 40)
        XCTAssertEqual(r2AfterCount, 41,
            "second registry must be independent — chapter " +
            "三百一〇 actor isolation invariant")
    }
}
