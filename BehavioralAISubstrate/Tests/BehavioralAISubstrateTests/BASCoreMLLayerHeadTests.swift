// MARK: - BASCoreMLLayerHeadTests — chapter 三百二〇 / M807
//
// Phase F (附录 X) 第一刀 测试覆盖:typed CoreML adapter +
// Sendable feature/prediction frames + factory namespace。
//
// Tests use parametric closure init throughout so no real
// `.mlpackage` binary is required in BAS test target — keeps
// BAS cross-platform clean。

import XCTest
@testable import BASAppleAdapters
@testable import BASRuntimeCore

final class BASCoreMLLayerHeadTests: XCTestCase {

    private let referenceDate = Date(
        timeIntervalSince1970: 1_700_000_000)

    private func makeInput(
        layerID: BASMotherboardLayer14 = .l4,
        featureRef: String = "test-feature"
    ) -> BASLayerInferenceInput {
        BASLayerInferenceInput(
            layerID: layerID,
            featureRef: featureRef,
            confidenceFloor: .medium)
    }

    // MARK: - BASCoreMLFeatureFrame

    func testFeatureFrameDefaults() {
        let frame = BASCoreMLFeatureFrame()
        XCTAssertTrue(frame.featureValues.isEmpty)
    }

    func testFeatureFrameSendableConformance() {
        // Compile-time check: BASCoreMLFeatureFrame is Sendable
        let frame = BASCoreMLFeatureFrame(
            featureValues: ["a": 1.0, "b": 2.0])
        let _: any Sendable = frame
        XCTAssertEqual(frame.featureValues["a"], 1.0)
        XCTAssertEqual(frame.featureValues["b"], 2.0)
    }

    // MARK: - BASCoreMLPredictionFrame

    func testPredictionFrameDefaults() {
        let frame = BASCoreMLPredictionFrame()
        XCTAssertEqual(frame.schemaVersion, "1.0.0")
        XCTAssertTrue(frame.scores.isEmpty)
        XCTAssertEqual(frame.modelDescription, "")
        XCTAssertEqual(frame.inferenceLatencyMs, 0)
    }

    func testPredictionFrameClampsLatencyToZero() {
        let frame = BASCoreMLPredictionFrame(
            inferenceLatencyMs: -5.5)
        XCTAssertEqual(
            frame.inferenceLatencyMs, 0,
            "negative latency must clamp to 0 per " +
            "BASLayerInferenceOutput invariant")
    }

    func testPredictionFrameTrimsModelDescription() {
        let frame = BASCoreMLPredictionFrame(
            modelDescription: "  trimmed  \n")
        XCTAssertEqual(frame.modelDescription, "trimmed")
    }

    func testPredictionFrameCodableRoundTrip() throws {
        let original = BASCoreMLPredictionFrame(
            scores: ["intent": 0.83, "emotion": 0.42],
            modelDescription: "ChengluMultiHead_v0",
            inferenceLatencyMs: 1.5)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(
            BASCoreMLPredictionFrame.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    // MARK: - Parametric closure init + protocol conformance

    func testParametricInitAndProtocolConformance() {
        let head = BASCoreMLLayerHead(
            headID: "stub-head",
            layerIDPin: .l4,
            featureExtractor: { _ in
                BASCoreMLFeatureFrame(featureValues: ["x": 1.0])
            },
            outputTransformer: { frame, input in
                BASLayerInferenceOutput(
                    layerID: input.layerID,
                    confidence: .high)
            },
            inferenceClosure: { _ in
                BASCoreMLPredictionFrame(
                    scores: ["y": 0.5])
            })
        XCTAssertEqual(head.headID, "stub-head")
        XCTAssertEqual(head.kind, .coremlOnDevice,
            "kind must always be .coremlOnDevice — chapter " +
            "一百七十七 cascading inference tier 10 doctrine")
        XCTAssertEqual(head.layerIDPin, .l4)
        let _: any BASLayerMLHead = head
    }

    func testHeadIDIsTrimmed() {
        let head = BASCoreMLLayerHead(
            headID: "  trimmed  \n",
            layerIDPin: .l11,
            featureExtractor: { _ in BASCoreMLFeatureFrame() },
            outputTransformer: { _, input in
                BASLayerInferenceOutput(
                    layerID: input.layerID,
                    confidence: .unknown)
            },
            inferenceClosure: { _ in BASCoreMLPredictionFrame() })
        XCTAssertEqual(head.headID, "trimmed")
    }

    // MARK: - infer() flow: featureExtractor → inferenceClosure → outputTransformer

    /// Actor for tracking stage invocation order in async tests.
    actor StageRecorder {
        private(set) var stages: [String] = []
        func record(_ stage: String) { stages.append(stage) }
        func snapshot() -> [String] { stages }
    }

    func testInferFlowsAllThreeStages() async throws {
        let recorder = StageRecorder()
        let head = BASCoreMLLayerHead(
            headID: "flow-test",
            layerIDPin: .l9,
            featureExtractor: { _ in
                BASCoreMLFeatureFrame(
                    featureValues: ["a": 1.0])
            },
            outputTransformer: { frame, input in
                BASLayerInferenceOutput(
                    layerID: input.layerID,
                    scores: frame.scores,
                    confidence: .high,
                    reasonCodes: ["transformed"],
                    inferenceLatencyMs: frame.inferenceLatencyMs)
            },
            inferenceClosure: { frame in
                await recorder.record("infer")
                XCTAssertEqual(frame.featureValues["a"], 1.0)
                return BASCoreMLPredictionFrame(
                    scores: ["score": 0.83],
                    modelDescription: "test",
                    inferenceLatencyMs: 2.5)
            })
        let output = try await head.infer(input: makeInput(
            layerID: .l9))
        let recorded = await recorder.snapshot()
        // featureExtractor + outputTransformer aren't async so
        // they don't write to the actor. We verify infer fired
        // (proves middle stage ran) + output proves transform
        // ran (it built the BASLayerInferenceOutput).
        XCTAssertEqual(recorded, ["infer"],
            "inference closure invoked once via async actor recorder")
        XCTAssertEqual(output.confidence, .high)
        XCTAssertEqual(output.scores["score"], 0.83)
        XCTAssertEqual(output.inferenceLatencyMs, 2.5)
        XCTAssertTrue(output.reasonCodes.contains("transformed"),
            "outputTransformer ran (built output with transformed code)")
    }

    func testInferLayerIDPropagates() async throws {
        let head = BASCoreMLLayerHead(
            headID: "propagate",
            layerIDPin: .l11,
            featureExtractor: { _ in BASCoreMLFeatureFrame() },
            outputTransformer: { _, input in
                BASLayerInferenceOutput(
                    layerID: input.layerID,
                    confidence: .high)
            },
            inferenceClosure: { _ in
                BASCoreMLPredictionFrame()
            })
        let output = try await head.infer(input: makeInput(
            layerID: .l11))
        XCTAssertEqual(output.layerID, .l11,
            "audit chain: input.layerID must propagate to " +
            "output.layerID")
    }

    // MARK: - Throws path

    func testInferRethrowsClosureError() async {
        struct CustomError: Error {}
        let head = BASCoreMLLayerHead(
            headID: "throwing",
            layerIDPin: .l4,
            featureExtractor: { _ in BASCoreMLFeatureFrame() },
            outputTransformer: { _, input in
                BASLayerInferenceOutput(
                    layerID: input.layerID,
                    confidence: .unknown)
            },
            inferenceClosure: { _ in throw CustomError() })
        do {
            _ = try await head.infer(input: makeInput())
            XCTFail("expected error rethrow")
        } catch is CustomError {
            // expected — no silent swallowing
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    // MARK: - Factory: makeStubSingleOutput

    func testFactoryStubSingleOutputHighConfidence()
        async throws
    {
        let head = BASCoreMLLayerHeadFactory
            .makeStubSingleOutput(
                headID: "stub-high",
                layerIDPin: .l4,
                scoreKey: "afm_success_probability",
                stubScore: 0.95,
                confidenceFromScore: BASCoreMLLayerHeadFactory
                    .defaultProbabilityConfidence,
                recommendedAction: "afm-route")
        let output = try await head.infer(input: makeInput())
        XCTAssertEqual(output.confidence, .high,
            "score 0.95 → far from 0.5 → .high confidence")
        XCTAssertEqual(output.recommendedAction, "afm-route")
        XCTAssertTrue(output.reasonCodes.contains(
            "coreml-head:stub-high"))
        XCTAssertTrue(output.reasonCodes.contains {
            $0.hasPrefix("coreml-score:afm_success_probability:")
        })
    }

    func testFactoryStubSingleOutputLowConfidenceUncertainZone()
        async throws
    {
        let head = BASCoreMLLayerHeadFactory
            .makeStubSingleOutput(
                headID: "stub-uncertain",
                layerIDPin: .l4,
                scoreKey: "prob",
                stubScore: 0.50,
                confidenceFromScore: BASCoreMLLayerHeadFactory
                    .defaultProbabilityConfidence)
        let output = try await head.infer(input: makeInput())
        XCTAssertEqual(output.confidence, .low,
            "score 0.50 = uncertain zone → .low confidence " +
            "(chapter 一百七十七 v0.4 doctrine)")
    }

    // MARK: - defaultProbabilityConfidence boundaries

    func testDefaultProbabilityConfidenceMatchesV04Doctrine() {
        // chapter 一百七十七 v0.4 boundaries:
        //   high: |score - 0.5| > 0.20  (score < 0.30 or > 0.70)
        //   medium: 0.10 < |score - 0.5| ≤ 0.20  (0.30..0.40 or 0.60..0.70)
        //   low: |score - 0.5| ≤ 0.10  (0.40..0.60)
        //   unknown: out of [0, 1]
        XCTAssertEqual(
            BASCoreMLLayerHeadFactory
                .defaultProbabilityConfidence(0.05),
            .high)
        XCTAssertEqual(
            BASCoreMLLayerHeadFactory
                .defaultProbabilityConfidence(0.95),
            .high)
        XCTAssertEqual(
            BASCoreMLLayerHeadFactory
                .defaultProbabilityConfidence(0.35),
            .medium)
        XCTAssertEqual(
            BASCoreMLLayerHeadFactory
                .defaultProbabilityConfidence(0.65),
            .medium)
        XCTAssertEqual(
            BASCoreMLLayerHeadFactory
                .defaultProbabilityConfidence(0.5),
            .low)
        XCTAssertEqual(
            BASCoreMLLayerHeadFactory
                .defaultProbabilityConfidence(-0.1),
            .unknown,
            "out-of-range scores → .unknown")
        XCTAssertEqual(
            BASCoreMLLayerHeadFactory
                .defaultProbabilityConfidence(1.5),
            .unknown)
    }

    // MARK: - Cascade integration

    func testCascadeRunnerInvokesCoreMLHead() async throws {
        let registry = BASLayerMLHeadRegistry()
        let head = BASCoreMLLayerHeadFactory
            .makeStubSingleOutput(
                headID: "cascade-test",
                layerIDPin: .l4,
                scoreKey: "p",
                stubScore: 0.9,
                confidenceFromScore: BASCoreMLLayerHeadFactory
                    .defaultProbabilityConfidence,
                recommendedAction: "test-action")
        try await registry.register(
            head: head, layerID: .l4,
            priority: BAS14LayerMeshMap
                .coremlOnDeviceTierPriority)
        let input = BASLayerInferenceInput(
            layerID: .l4,
            featureRef: "x",
            confidenceFloor: .medium)
        let result = try await BASLayerCascadeRunner.run(
            input: input, registry: registry, layerID: .l4)
        XCTAssertEqual(result.outcome, .headMatched,
            "real CoreML-tier head returns .high → cascade " +
            "matches floor")
        XCTAssertEqual(result.matchedHeadID, "cascade-test")
    }

    func testCascadeRunnerWalksRulesTierBeforeCoreMLTier()
        async throws
    {
        let registry = BASLayerMLHeadRegistry()
        // priority 0: rules-tier always-fallthrough
        let rulesHead = BASRulesBasedLayerMLHeadFactory
            .makeAlwaysFallthrough(
                headID: "rules-p0",
                layerIDPin: .l4)
        try await registry.register(
            head: rulesHead, layerID: .l4,
            priority: BAS14LayerMeshMap.rulesTierPriority)
        // priority 10: coreml-tier with high score
        let coremlHead = BASCoreMLLayerHeadFactory
            .makeStubSingleOutput(
                headID: "coreml-p10",
                layerIDPin: .l4,
                scoreKey: "p",
                stubScore: 0.85,
                confidenceFromScore: BASCoreMLLayerHeadFactory
                    .defaultProbabilityConfidence)
        try await registry.register(
            head: coremlHead, layerID: .l4,
            priority: BAS14LayerMeshMap
                .coremlOnDeviceTierPriority)
        let input = BASLayerInferenceInput(
            layerID: .l4, featureRef: "x",
            confidenceFloor: .medium)
        let result = try await BASLayerCascadeRunner.run(
            input: input, registry: registry, layerID: .l4)
        XCTAssertEqual(result.outcome, .headMatched)
        XCTAssertEqual(result.matchedHeadID, "coreml-p10",
            "cascade walks rules tier 0 first (falls through), " +
            "then coreml tier 10 (matches floor)")
        XCTAssertEqual(
            result.triedHeads.count, 2,
            "audit trail shows BOTH attempts: rules p0 + coreml p10")
    }

    // MARK: - Sendable conformance

    func testHeadIsSendable() {
        let head = BASCoreMLLayerHead(
            headID: "sendable-check",
            layerIDPin: .l11,
            featureExtractor: { _ in BASCoreMLFeatureFrame() },
            outputTransformer: { _, input in
                BASLayerInferenceOutput(
                    layerID: input.layerID,
                    confidence: .high)
            },
            inferenceClosure: { _ in
                BASCoreMLPredictionFrame()
            })
        let _: any BASLayerMLHead = head
        let _: any Sendable = head
    }
}
