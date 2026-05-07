// MARK: - BASHostRuntimeMeshHookTests — chapter 三百二三 / M810
//
// Phase F (附录 X) 第四刀 测试覆盖:opt-in mesh registry hook
// on BASHostRuntime + reason code synthesis + 0 default behavior
// change invariant。
//
// Doctrine pins verified:
//   - 不变量 #1 / #2 / #3 全保 (no permit/verdict mutation)
//   - chapter 二百一一 single-source-of-truth (BASHostRuntime
//     is sole entry point;mesh accessor lives on it)
//   - chapter 三百二〇/三百二一/三百二二 compose end-to-end
//     through this hook
//   - 0 default behavior change pinned by `testMeshRegistryNilByDefault`

import XCTest
@testable import BASAppleAdapters
@testable import BASHostKit
@testable import BASRuntimeCore

final class BASHostRuntimeMeshHookTests: XCTestCase {

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
                    "intent": 0.85,
                    "emotion": 0.75,
                    "risk": 0.65,
                    "memory_importance": 0.80
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

    // MARK: - 0 default behavior change invariant

    func testMeshRegistryNilByDefault() {
        let runtime = BASHostRuntime(
            configuration: makeMinimalConfiguration())
        XCTAssertNil(
            runtime.meshRegistry,
            "Default BASHostRuntime construction must NOT " +
            "wire a mesh — preserves 0 behavior change for " +
            "existing call sites")
        XCTAssertFalse(runtime.hasMeshRegistry)
    }

    func testRunMeshCascadeReturnsNilWhenNoRegistry()
        async throws
    {
        let runtime = BASHostRuntime(
            configuration: makeMinimalConfiguration())
        let input = BASLayerInferenceInput(
            layerID: .l1,
            featureRef:
                "anxious|medical|critical|today|trusted-ai|" +
                "question|2",
            confidenceFloor: .high)
        let result = try await runtime.runMeshCascade(
            input: input, layerID: .l1)
        XCTAssertNil(
            result,
            "runMeshCascade must return nil when no registry " +
            "wired (opt-in doctrine)")
    }

    // MARK: - Wired path

    func testHasMeshRegistryWhenWired() async throws {
        let registry = try await makePopulatedRegistry()
        let runtime = BASHostRuntime(
            configuration: makeMinimalConfiguration(),
            meshRegistry: registry)
        XCTAssertTrue(runtime.hasMeshRegistry)
        XCTAssertNotNil(runtime.meshRegistry)
    }

    func testRunMeshCascadeFiresPreflightAtL1() async throws {
        let registry = try await makePopulatedRegistry()
        let runtime = BASHostRuntime(
            configuration: makeMinimalConfiguration(),
            meshRegistry: registry)
        let ref = try BASChengluFeatureRefBuilder.build(
            tone: "anxious", domain: "medical",
            stake: "critical", timeframe: "today",
            confidant: "trusted-ai", askShape: "question",
            mutationSeed: 2)
        let input = BASLayerInferenceInput(
            layerID: .l1,
            featureRef: ref,
            confidenceFloor: .high)
        let result = try await runtime.runMeshCascade(
            input: input, layerID: .l1)
        XCTAssertNotNil(result)
        XCTAssertEqual(
            result?.cascadeResult.matchedHeadID,
            "chenglu.l1.wake-policy")
        XCTAssertEqual(
            result?.cascadeResult.matchedOutput?
                .recommendedAction,
            "afm-route")
    }

    // MARK: - Audit reason codes

    func testReasonCodesIncludeCascadeOutcome() async throws {
        let registry = try await makePopulatedRegistry()
        let runtime = BASHostRuntime(
            configuration: makeMinimalConfiguration(),
            meshRegistry: registry)
        let input = BASLayerInferenceInput(
            layerID: .l1,
            featureRef:
                "anxious|medical|critical|today|trusted-ai|" +
                "question|2",
            confidenceFloor: .high)
        let result = try await runtime.runMeshCascade(
            input: input, layerID: .l1)
        XCTAssertNotNil(result)
        let codes = result?.reasonCodes ?? []
        // outcome will be .floorMet (high == high) or .headMatched
        XCTAssertTrue(
            codes.contains("mesh-coreml:cascade:floor-met")
            || codes.contains(
                "mesh-coreml:cascade:head-matched"))
        XCTAssertTrue(
            codes.contains("mesh-coreml:layer:l1"))
        XCTAssertTrue(
            codes.contains(
                "mesh-coreml:matched-head:" +
                "chenglu.l1.wake-policy"))
    }

    func testReasonCodesIncludeTriedCount() async throws {
        let registry = try await makePopulatedRegistry()
        let runtime = BASHostRuntime(
            configuration: makeMinimalConfiguration(),
            meshRegistry: registry)
        let input = BASLayerInferenceInput(
            layerID: .l11,
            featureRef:
                "anxious|medical|critical|today|trusted-ai|" +
                "question|2",
            confidenceFloor: .high)
        let result = try await runtime.runMeshCascade(
            input: input, layerID: .l11)
        XCTAssertNotNil(result)
        let codes = result?.reasonCodes ?? []
        // L11 has 2 slots; multihead.risk = 0.65 → medium →
        // cascade walks past it → permit-predict matches
        XCTAssertTrue(codes.contains("mesh-coreml:tried:2"))
    }

    // MARK: - BASHostMeshReasonCodes raw outcome stability

    func testRawOutcomeKebabCaseStability() {
        XCTAssertEqual(
            BASHostMeshReasonCodes.rawOutcome(.headMatched),
            "head-matched")
        XCTAssertEqual(
            BASHostMeshReasonCodes.rawOutcome(.floorMet),
            "floor-met")
        XCTAssertEqual(
            BASHostMeshReasonCodes.rawOutcome(.fallenThrough),
            "fallen-through")
        XCTAssertEqual(
            BASHostMeshReasonCodes.rawOutcome(
                .noHeadsRegistered),
            "no-heads-registered")
    }

    func testReasonCodesPrefix() {
        XCTAssertEqual(
            BASHostMeshReasonCodes.prefix, "mesh-coreml")
    }

    // MARK: - No-heads-registered emission

    func testReasonCodesForUnpopulatedLayer() async throws {
        let registry = try await makePopulatedRegistry()
        let runtime = BASHostRuntime(
            configuration: makeMinimalConfiguration(),
            meshRegistry: registry)
        // L2 has no Chenglu slots
        let input = BASLayerInferenceInput(
            layerID: .l2,
            featureRef:
                "calm|practical|low|today|trusted-ai|" +
                "question|0",
            confidenceFloor: .high)
        let result = try await runtime.runMeshCascade(
            input: input, layerID: .l2)
        XCTAssertNotNil(result)
        let codes = result?.reasonCodes ?? []
        XCTAssertTrue(codes.contains(
            "mesh-coreml:cascade:no-heads-registered"))
        XCTAssertTrue(codes.contains("mesh-coreml:tried:0"))
        XCTAssertFalse(codes.contains(where: {
            $0.hasPrefix("mesh-coreml:matched-head:")
        }))
    }

    // MARK: - Codes synthesis from raw cascade result

    func testCodesFromManualCascadeResult() {
        let resultMatched = BASLayerCascadeResult(
            outcome: .headMatched,
            layerID: .l4,
            matchedHeadID: "stub-head",
            triedHeads: [
                BASLayerCascadeAttempt(
                    headID: "stub-head",
                    kind: .coremlOnDevice,
                    confidence: .high, met: true)
            ])
        let codes = BASHostMeshReasonCodes.codes(
            for: resultMatched)
        XCTAssertEqual(codes.count, 4)
        XCTAssertTrue(codes.contains(
            "mesh-coreml:cascade:head-matched"))
        XCTAssertTrue(codes.contains(
            "mesh-coreml:layer:l4"))
        XCTAssertTrue(codes.contains(
            "mesh-coreml:tried:1"))
        XCTAssertTrue(codes.contains(
            "mesh-coreml:matched-head:stub-head"))
    }

    func testCodesFromFallenThroughResult() {
        let result = BASLayerCascadeResult(
            outcome: .fallenThrough,
            layerID: .l8,
            triedHeads: [
                BASLayerCascadeAttempt(
                    headID: "h1", kind: .rules,
                    confidence: .low, met: false)
            ])
        let codes = BASHostMeshReasonCodes.codes(for: result)
        XCTAssertEqual(codes.count, 3)
        XCTAssertTrue(codes.contains(
            "mesh-coreml:cascade:fallen-through"))
        XCTAssertTrue(codes.contains(
            "mesh-coreml:layer:l8"))
        XCTAssertTrue(codes.contains(
            "mesh-coreml:tried:1"))
    }

    // MARK: - chapter 三百四八 / M835 — runMeshCascadeRequired tests

    /// `runMeshCascadeRequired` throws typed error when no
    /// registry wired (replaces silent nil with explicit
    /// invariant signal)。
    func testRunMeshCascadeRequiredThrowsWhenNoRegistry()
        async
    {
        let runtime = BASHostRuntime(
            configuration: makeMinimalConfiguration())
        let input = BASLayerInferenceInput(
            layerID: .l1,
            featureRef:
                "anxious|medical|critical|today|trusted-ai|" +
                "question|2",
            confidenceFloor: .high)
        do {
            _ = try await runtime.runMeshCascadeRequired(
                input: input, layerID: .l1)
            XCTFail(
                "runMeshCascadeRequired must throw when no " +
                "registry is wired (typed error contract)")
        } catch let error as BASHostMeshError {
            XCTAssertEqual(
                error,
                .noRegistryWired(attemptedLayer: .l1),
                "Typed error must carry the attempted layer " +
                "for diagnostic context")
        } catch {
            XCTFail(
                "Expected BASHostMeshError, got: " +
                "\(type(of: error))")
        }
    }

    /// `runMeshCascadeRequired` returns non-Optional result when
    /// registry IS wired — same cascade output as the Optional
    /// variant,but the type signature documents the
    /// pre-checked invariant。
    func testRunMeshCascadeRequiredReturnsResultWhenWired()
        async throws
    {
        let registry = try await makePopulatedRegistry()
        let runtime = BASHostRuntime(
            configuration: makeMinimalConfiguration(),
            meshRegistry: registry)
        let ref = try BASChengluFeatureRefBuilder.build(
            tone: "anxious", domain: "medical",
            stake: "critical", timeframe: "today",
            confidant: "trusted-ai", askShape: "question",
            mutationSeed: 2)
        let input = BASLayerInferenceInput(
            layerID: .l1,
            featureRef: ref,
            confidenceFloor: .high)
        let result = try await runtime.runMeshCascadeRequired(
            input: input, layerID: .l1)
        XCTAssertEqual(
            result.cascadeResult.matchedHeadID,
            "chenglu.l1.wake-policy",
            "Required variant must return same cascade match " +
            "as Optional variant when wired")
    }

    /// Optional and Required variants must produce identical
    /// results when registry is wired (composition invariant)。
    func testRunMeshCascadeOptionalAndRequiredIdentical()
        async throws
    {
        let registry = try await makePopulatedRegistry()
        let runtime = BASHostRuntime(
            configuration: makeMinimalConfiguration(),
            meshRegistry: registry)
        let ref = try BASChengluFeatureRefBuilder.build(
            tone: "anxious", domain: "medical",
            stake: "critical", timeframe: "today",
            confidant: "trusted-ai", askShape: "question",
            mutationSeed: 2)
        let input = BASLayerInferenceInput(
            layerID: .l1,
            featureRef: ref,
            confidenceFloor: .high)
        let optionalResult = try await runtime.runMeshCascade(
            input: input, layerID: .l1)
        let requiredResult = try await runtime
            .runMeshCascadeRequired(
                input: input, layerID: .l1)
        XCTAssertNotNil(optionalResult)
        XCTAssertEqual(optionalResult, requiredResult,
            "Optional and Required variants must produce " +
            "identical results when registry is wired")
    }

    /// `BASHostMeshError` is Equatable + Sendable + carries layer
    /// for diagnostics — pin the shape to prevent drift。
    func testBASHostMeshErrorEquatable() {
        let error1 = BASHostMeshError.noRegistryWired(
            attemptedLayer: .l4)
        let error2 = BASHostMeshError.noRegistryWired(
            attemptedLayer: .l4)
        let error3 = BASHostMeshError.noRegistryWired(
            attemptedLayer: .l11)
        XCTAssertEqual(error1, error2,
            "Same layer → equal errors")
        XCTAssertNotEqual(error1, error3,
            "Different layers → distinct errors (so callers " +
            "can pattern-match on layer)")
    }
}
