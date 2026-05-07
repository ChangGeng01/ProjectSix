// MARK: - BASHostRuntimeMeshSweepTests — chapter 三百二五 / M812
//
// Phase F (附录 X) 第五刀 测试覆盖:multi-layer mesh sweep API +
// Chenglu canonical sweep convenience。
//
// Doctrine pins verified:
//   - 0 default behavior change: `runMeshSweep` on no-registry
//     runtime returns empty sweep
//   - Multi-layer cascade composition: per-layer entries + aggregated
//     reason codes
//   - 单提交口 preserved (hint-class only)
//   - Chenglu canonical layer set matches附录 X §X.2 doctrine

import XCTest
@testable import BASAppleAdapters
@testable import BASHostKit
@testable import BASRuntimeCore

final class BASHostRuntimeMeshSweepTests: XCTestCase {

    // MARK: - Helpers

    private func makeStubClosure(
        scoreMap: [String: Double]
    ) -> @Sendable (BASCoreMLFeatureFrame) async throws
        -> BASCoreMLPredictionFrame
    {
        return { _ in
            BASCoreMLPredictionFrame(
                scores: scoreMap, inferenceLatencyMs: 0.5)
        }
    }

    private func makeMinimalConfiguration()
        -> BASHostConfiguration
    {
        BASHostConfiguration.fixtureGeneric
    }

    private func makePopulatedRegistry() async throws
        -> BASLayerMLHeadRegistry
    {
        let registry = BASLayerMLHeadRegistry()
        let options = BASChengluMeshRegistration
            .ClosureRegistrationOptions(
                preflightClosure: makeStubClosure(
                    scoreMap: [
                        "afm_success_probability": 0.95
                    ]),
                multiHeadClosure: makeStubClosure(scoreMap: [
                    "intent": 0.95,
                    "emotion": 0.95,
                    "risk": 0.95,
                    "memory_importance": 0.95
                ]),
                permitPredictClosure: makeStubClosure(
                    scoreMap: ["block_probability": 0.90]),
                lengthHeadClosure: makeStubClosure(
                    scoreMap: ["body_length": 850]),
                latencyHeadClosure: makeStubClosure(
                    scoreMap: ["duration_ms": 1200]))
        _ = try await BASChengluMeshRegistration
            .assembleFromClosures(
                into: registry, options: options)
        return registry
    }

    private func makeInput() throws -> BASLayerInferenceInput {
        let ref = try BASChengluFeatureRefBuilder.build(
            tone: "anxious", domain: "medical",
            stake: "critical", timeframe: "today",
            confidant: "trusted-ai", askShape: "question",
            mutationSeed: 2)
        return BASLayerInferenceInput(
            layerID: .l1,
            featureRef: ref,
            confidenceFloor: .high)
    }

    // MARK: - Canonical layer set doctrine pin

    func testChengluCanonicalLayersMatchAppendixXDoctrine() {
        // 附录 X §X.2: 8 slots distributed across 6 unique layers
        // (l1 has 2 slots, l11 has 2 slots, the others 1 each)
        XCTAssertEqual(
            chengluCanonicalLayers,
            [.l1, .l4, .l6, .l8, .l11, .l12],
            "Canonical layer order must match附录 X §X.2 " +
            "doctrine (l1 → l4 → l6 → l8 → l11 → l12)")
        XCTAssertEqual(chengluCanonicalLayers.count, 6)
    }

    // MARK: - 0 default behavior change

    func testSweepReturnsEmptyWhenNoRegistry() async throws {
        let runtime = BASHostRuntime(
            configuration: makeMinimalConfiguration())
        let result = try await runtime.runMeshSweep(
            input: try makeInput(),
            layers: chengluCanonicalLayers)
        XCTAssertTrue(result.layerEntries.isEmpty,
            "No registry → empty sweep (opt-in doctrine)")
        XCTAssertTrue(result.aggregatedReasonCodes.isEmpty)
        XCTAssertEqual(result.layerCount, 0)
        XCTAssertEqual(result.matchedLayerCount, 0)
    }

    func testSweepReturnsEmptyForEmptyLayerList() async throws {
        let registry = try await makePopulatedRegistry()
        let runtime = BASHostRuntime(
            configuration: makeMinimalConfiguration(),
            meshRegistry: registry)
        let result = try await runtime.runMeshSweep(
            input: try makeInput(),
            layers: [])
        XCTAssertTrue(result.layerEntries.isEmpty)
        XCTAssertTrue(result.aggregatedReasonCodes.isEmpty)
    }

    // MARK: - Wired sweep path

    func testSweepConsultsAllRequestedLayers() async throws {
        let registry = try await makePopulatedRegistry()
        let runtime = BASHostRuntime(
            configuration: makeMinimalConfiguration(),
            meshRegistry: registry)
        let result = try await runtime.runMeshSweep(
            input: try makeInput(),
            layers: [.l1, .l4, .l11])
        XCTAssertEqual(
            result.layerEntries.count, 3,
            "All 3 requested layers must be consulted")
        XCTAssertEqual(
            result.layerEntries.map { $0.layerID },
            [.l1, .l4, .l11],
            "Layer order must preserve caller-supplied order")
    }

    func testSweepEntriesContainCascadeResults() async throws {
        let registry = try await makePopulatedRegistry()
        let runtime = BASHostRuntime(
            configuration: makeMinimalConfiguration(),
            meshRegistry: registry)
        let result = try await runtime.runMeshSweep(
            input: try makeInput(),
            layers: [.l1])
        XCTAssertEqual(result.layerEntries.count, 1)
        let l1Entry = result.layerEntries[0]
        XCTAssertEqual(l1Entry.layerID, .l1)
        // L1 wake-policy = preflight, score 0.95 → high → match
        XCTAssertEqual(
            l1Entry.consultation.cascadeResult.matchedHeadID,
            "chenglu.l1.wake-policy")
    }

    func testSweepAggregatesReasonCodesAcrossLayers()
        async throws
    {
        let registry = try await makePopulatedRegistry()
        let runtime = BASHostRuntime(
            configuration: makeMinimalConfiguration(),
            meshRegistry: registry)
        let result = try await runtime.runMeshSweep(
            input: try makeInput(),
            layers: [.l1, .l4])
        // L1 has 2 slots (preflight + latency); cascade matches
        // first slot (preflight). L4 has 1 slot (multihead.intent).
        // Each layer emits 4 codes (cascade + layer + tried +
        // matched-head), so 2 layers × 4 = 8 total。
        XCTAssertEqual(
            result.aggregatedReasonCodes.count, 8,
            "Each layer contributes 4 codes → 2 × 4 = 8")
        // Codes for l1 must come before codes for l4
        let l1Index = result.aggregatedReasonCodes.firstIndex(
            of: "mesh-coreml:layer:l1")
        let l4Index = result.aggregatedReasonCodes.firstIndex(
            of: "mesh-coreml:layer:l4")
        XCTAssertNotNil(l1Index)
        XCTAssertNotNil(l4Index)
        XCTAssertLessThan(l1Index!, l4Index!,
            "Codes preserve sweep order")
    }

    func testMatchedLayerCountReflectsSuccessfulCascades()
        async throws
    {
        let registry = try await makePopulatedRegistry()
        let runtime = BASHostRuntime(
            configuration: makeMinimalConfiguration(),
            meshRegistry: registry)
        // L2 has no Chenglu slots → no-heads-registered (not match)
        // L1 + L4 have populated slots → match
        let result = try await runtime.runMeshSweep(
            input: try makeInput(),
            layers: [.l1, .l2, .l4])
        XCTAssertEqual(result.layerCount, 3)
        XCTAssertEqual(
            result.matchedLayerCount, 2,
            "L1 + L4 match (high stub scores); L2 has no heads " +
            "→ noHeadsRegistered (does not count as match)")
    }

    // MARK: - Chenglu canonical sweep convenience

    func testChengluCanonicalSweepWalksAll6Layers() async throws
    {
        let registry = try await makePopulatedRegistry()
        let runtime = BASHostRuntime(
            configuration: makeMinimalConfiguration(),
            meshRegistry: registry)
        let result = try await runtime
            .runChengluCanonicalSweep(input: try makeInput())
        XCTAssertEqual(
            result.layerCount, 6,
            "Canonical sweep walks 6 layers per附录 X §X.2")
        XCTAssertEqual(
            result.layerEntries.map { $0.layerID },
            chengluCanonicalLayers,
            "Sweep order matches canonical doctrine constant")
    }

    func testChengluCanonicalSweepAllLayersMatchOnHighStubs()
        async throws
    {
        let registry = try await makePopulatedRegistry()
        let runtime = BASHostRuntime(
            configuration: makeMinimalConfiguration(),
            meshRegistry: registry)
        let result = try await runtime
            .runChengluCanonicalSweep(input: try makeInput())
        // All stub scores set high (≥ 0.85) → all 6 canonical
        // layers should match。
        XCTAssertEqual(
            result.matchedLayerCount, 6,
            "All canonical layers match when stubs are high")
    }

    func testChengluCanonicalSweepNoRegistryReturnsEmpty()
        async throws
    {
        let runtime = BASHostRuntime(
            configuration: makeMinimalConfiguration())
        let result = try await runtime
            .runChengluCanonicalSweep(input: try makeInput())
        XCTAssertTrue(result.layerEntries.isEmpty)
        XCTAssertEqual(result.matchedLayerCount, 0)
    }

    // MARK: - Result wrapper invariants

    func testSweepResultLayerCountMatchesEntries() {
        let entries = [
            BASHostMeshSweepLayerEntry(
                layerID: .l1,
                consultation: BASHostMeshConsultationResult(
                    cascadeResult: BASLayerCascadeResult(
                        outcome: .noHeadsRegistered,
                        layerID: .l1),
                    reasonCodes: ["mesh-coreml:layer:l1"]))
        ]
        let result = BASHostMeshSweepResult(
            layerEntries: entries,
            aggregatedReasonCodes: ["mesh-coreml:layer:l1"])
        XCTAssertEqual(result.layerCount, 1)
    }
}
