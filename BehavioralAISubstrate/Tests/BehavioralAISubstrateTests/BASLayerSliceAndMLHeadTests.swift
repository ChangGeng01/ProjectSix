// MARK: - BASLayerSliceAndMLHeadTests — chapter 三百 / M787
//
// Phase Beta 第二刀的测试覆盖:LayerSlice budget + MLHead protocol
// contract。

import XCTest
@testable import BASRuntimeCore

final class BASLayerSliceAndMLHeadTests: XCTestCase {

    // MARK: - LayerSlice budget invariants

    func testLayerSliceDefaultSchemaVersion() {
        let slice = BASLayerSlice(
            layerID: .l11,
            allocatedMs: 5,
            hardCapMs: 10)
        XCTAssertEqual(slice.schemaVersion, "1.0.0")
        XCTAssertEqual(slice.allocatedMs, 5)
        XCTAssertEqual(slice.hardCapMs, 10)
        XCTAssertEqual(slice.decodeTokenAllowance, 0)
        XCTAssertEqual(slice.loopAllowance, 1)
        XCTAssertFalse(slice.observabilityOnly)
    }

    func testLayerSliceClampsAllocatedToZero() {
        let slice = BASLayerSlice(
            layerID: .l9,
            allocatedMs: -3,
            hardCapMs: 5)
        XCTAssertEqual(slice.allocatedMs, 0,
            "negative allocated must clamp to 0")
    }

    func testLayerSliceClampsHardCapToAtLeastAllocated() {
        // hardCap 低于 allocated 时,clamp 到 allocated
        let slice = BASLayerSlice(
            layerID: .l11,
            allocatedMs: 20,
            hardCapMs: 5)
        XCTAssertEqual(slice.allocatedMs, 20)
        XCTAssertEqual(slice.hardCapMs, 20,
            "hardCap < allocated 是矛盾;必须 clamp 到 allocated")
    }

    func testLayerSliceClampsLoopAllowanceToAtLeastOne() {
        let slice = BASLayerSlice(
            layerID: .l9,
            allocatedMs: 1,
            hardCapMs: 1,
            loopAllowance: 0)
        XCTAssertEqual(slice.loopAllowance, 1,
            "loopAllowance must be ≥ 1 (process must run at " +
            "least once)")
    }

    func testLayerSliceClampsDecodeTokenAllowanceToZero() {
        let slice = BASLayerSlice(
            layerID: .l2,
            allocatedMs: 1,
            hardCapMs: 1,
            decodeTokenAllowance: -10)
        XCTAssertEqual(slice.decodeTokenAllowance, 0)
    }

    func testLayerSliceObservabilityOnlyFlag() {
        let slice = BASLayerSlice(
            layerID: .l7,
            allocatedMs: 0.5,
            hardCapMs: 1,
            observabilityOnly: true)
        XCTAssertTrue(slice.observabilityOnly,
            "watcher / hint-only layers must declare " +
            "observabilityOnly=true per 红线 7 doctrine")
    }

    func testLayerSliceCodableRoundTrip() throws {
        let original = BASLayerSlice(
            layerID: .l9,
            allocatedMs: 12.5,
            hardCapMs: 40,
            decodeTokenAllowance: 256,
            loopAllowance: 8,
            observabilityOnly: false)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(
            BASLayerSlice.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func testLayerSliceAcceptsAll14LayerIDs() {
        for layer in BASMotherboardLayer14.allCases {
            let slice = BASLayerSlice(
                layerID: layer,
                allocatedMs: 1,
                hardCapMs: 2)
            XCTAssertEqual(slice.layerID, layer)
        }
    }

    // MARK: - MLHeadKind enum

    func testMLHeadKindCardinality() {
        XCTAssertEqual(
            BASLayerMLHeadKind.allCases.count, 5,
            "5 cases match chapter 一百七十七 cascading inference: " +
            "rules → coreml → mlx → AFM → external")
    }

    func testMLHeadKindRawValueStability() {
        XCTAssertEqual(
            BASLayerMLHeadKind.rules.rawValue, "rules")
        XCTAssertEqual(
            BASLayerMLHeadKind.coremlOnDevice.rawValue,
            "coreml-on-device")
        XCTAssertEqual(
            BASLayerMLHeadKind.mlxLocal.rawValue, "mlx-local")
        XCTAssertEqual(
            BASLayerMLHeadKind.appleFoundationModel.rawValue,
            "apple-foundation-model")
        XCTAssertEqual(
            BASLayerMLHeadKind.externalProvider.rawValue,
            "external-provider")
    }

    func testMLHeadKindCodableRoundTrip() throws {
        for k in BASLayerMLHeadKind.allCases {
            let data = try JSONEncoder().encode(k)
            let decoded = try JSONDecoder().decode(
                BASLayerMLHeadKind.self, from: data)
            XCTAssertEqual(decoded, k)
        }
    }

    // MARK: - InferenceInput

    func testInferenceInputDefaults() {
        let input = BASLayerInferenceInput(
            layerID: .l4,
            featureRef: "feat-1")
        XCTAssertEqual(input.schemaVersion, "1.0.0")
        XCTAssertEqual(input.confidenceFloor, .medium)
        XCTAssertNil(input.correlationID)
    }

    func testInferenceInputTrimsStrings() {
        let input = BASLayerInferenceInput(
            layerID: .l4,
            featureRef: "  feat-2  ",
            correlationID: "  corr  \n")
        XCTAssertEqual(input.featureRef, "feat-2")
        XCTAssertEqual(input.correlationID, "corr")
    }

    func testInferenceInputCodableRoundTrip() throws {
        let original = BASLayerInferenceInput(
            layerID: .l11,
            featureRef: "feat-rt",
            confidenceFloor: .high,
            correlationID: "corr-rt")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(
            BASLayerInferenceInput.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    // MARK: - InferenceOutput

    func testInferenceOutputDefaults() {
        let output = BASLayerInferenceOutput(layerID: .l11)
        XCTAssertEqual(output.schemaVersion, "1.0.0")
        XCTAssertEqual(output.scores, [:])
        XCTAssertEqual(output.confidence, .unknown)
        XCTAssertNil(output.recommendedAction)
        XCTAssertEqual(output.reasonCodes, [])
        XCTAssertEqual(output.inferenceLatencyMs, 0)
    }

    func testInferenceOutputClampsLatencyToZero() {
        let output = BASLayerInferenceOutput(
            layerID: .l9,
            inferenceLatencyMs: -2.7)
        XCTAssertEqual(output.inferenceLatencyMs, 0)
    }

    func testInferenceOutputFiltersEmptyReasonCodes() {
        let output = BASLayerInferenceOutput(
            layerID: .l4,
            reasonCodes: [
                "intent.score:0.8",
                "",
                "  ",
                "  permit.hint:.compare  "
            ])
        XCTAssertEqual(
            output.reasonCodes,
            ["intent.score:0.8", "permit.hint:.compare"])
    }

    func testInferenceOutputCodableRoundTrip() throws {
        let original = BASLayerInferenceOutput(
            layerID: .l11,
            scores: ["risk": 0.7, "intent": 0.4],
            confidence: .medium,
            recommendedAction: "compare",
            reasonCodes: ["risk.high"],
            inferenceLatencyMs: 8.2)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(
            BASLayerInferenceOutput.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    // MARK: - MLHead protocol conformance via stub

    private struct StubMLHead: BASLayerMLHead {
        let headID: String
        let kind: BASLayerMLHeadKind
        let returnedConfidence: BASLayerInferenceConfidence

        func infer(
            input: BASLayerInferenceInput
        ) async throws -> BASLayerInferenceOutput {
            BASLayerInferenceOutput(
                layerID: input.layerID,
                scores: ["stub-score": 0.5],
                confidence: returnedConfidence,
                recommendedAction: "hint-from-\(headID)",
                reasonCodes: [
                    "stub-head:processed:" +
                    input.layerID.rawValue
                ],
                inferenceLatencyMs: 0.1)
        }
    }

    func testStubMLHeadConformanceAndInferRoundTrip() async throws {
        let head = StubMLHead(
            headID: "test-head",
            kind: .rules,
            returnedConfidence: .high)
        XCTAssertEqual(head.headID, "test-head")
        XCTAssertEqual(head.kind, .rules)

        let input = BASLayerInferenceInput(
            layerID: .l4,
            featureRef: "feat-stub")
        let output = try await head.infer(input: input)
        XCTAssertEqual(output.layerID, .l4)
        XCTAssertEqual(output.confidence, .high)
        XCTAssertEqual(
            output.recommendedAction, "hint-from-test-head")
        XCTAssertEqual(
            output.reasonCodes,
            ["stub-head:processed:l4"])
    }

    func testStubMLHeadCascadeFallthroughCheck() async throws {
        // confidence < floor → caller should cascade
        let lowConfHead = StubMLHead(
            headID: "low-conf",
            kind: .coremlOnDevice,
            returnedConfidence: .low)
        let input = BASLayerInferenceInput(
            layerID: .l11,
            featureRef: "feat",
            confidenceFloor: .high)
        let output = try await lowConfHead.infer(input: input)
        XCTAssertEqual(output.confidence, .low,
            "head returned .low; caller will see " +
            "output.confidence < input.confidenceFloor and " +
            "trigger BASLayerActorStatus.mlHeadFallthrough")
    }
}
