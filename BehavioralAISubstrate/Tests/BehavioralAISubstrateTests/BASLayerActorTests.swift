// MARK: - BASLayerActorTests — chapter 二百九十九 / M786
//
// Phase Beta 第一刀的测试覆盖:per-layer concurrency foundation
// 的 typed value-types + protocol contract。
//
// Test groups:
//   - cardinality + raw-value pin (BASLayerInferenceConfidence,
//     BASLayerActorStatus enums)
//   - Codable round-trip (BASLayerActorInput, BASLayerActorOutput)
//   - clamping invariants (latencyMs ≥ 0, reasonCodes empty filter)
//   - protocol conformance (mock actor)
//   - error boundary equality (BASLayerActorError 5 cases)

import XCTest
@testable import BASRuntimeCore

final class BASLayerActorTests: XCTestCase {

    // MARK: - Confidence enum

    func testConfidenceEnumCardinality() {
        XCTAssertEqual(
            BASLayerInferenceConfidence.allCases.count, 4,
            "confidence enum 必须 4 cases (high/medium/low/unknown);" +
            "if you add a case 也要 update cascading inference policy")
    }

    func testConfidenceRawValueStability() {
        XCTAssertEqual(
            BASLayerInferenceConfidence.high.rawValue, "high")
        XCTAssertEqual(
            BASLayerInferenceConfidence.medium.rawValue, "medium")
        XCTAssertEqual(
            BASLayerInferenceConfidence.low.rawValue, "low")
        XCTAssertEqual(
            BASLayerInferenceConfidence.unknown.rawValue, "unknown")
    }

    func testConfidenceCodableRoundTrip() throws {
        for c in BASLayerInferenceConfidence.allCases {
            let data = try JSONEncoder().encode(c)
            let decoded = try JSONDecoder().decode(
                BASLayerInferenceConfidence.self, from: data)
            XCTAssertEqual(decoded, c)
        }
    }

    // MARK: - Status enum

    func testStatusEnumCardinality() {
        XCTAssertEqual(
            BASLayerActorStatus.allCases.count, 8,
            "status enum 必须 8 cases (chapter 二百九十九 ship state);" +
            "8 cases match doctrine: completed / 4 skipped + " +
            "errored variants / partial / quarantined")
    }

    func testStatusRawValueStability() {
        // kebab-case for compound names per chapter 一百三十 doctrine
        XCTAssertEqual(
            BASLayerActorStatus.completed.rawValue, "completed")
        XCTAssertEqual(
            BASLayerActorStatus.skippedByGate.rawValue,
            "skipped-by-gate")
        XCTAssertEqual(
            BASLayerActorStatus.skippedByKill.rawValue,
            "skipped-by-kill")
        XCTAssertEqual(
            BASLayerActorStatus.errorBoundaryHandled.rawValue,
            "error-boundary-handled")
        XCTAssertEqual(
            BASLayerActorStatus.budgetExceeded.rawValue,
            "budget-exceeded")
        XCTAssertEqual(
            BASLayerActorStatus.mlHeadFallthrough.rawValue,
            "ml-head-fallthrough")
        XCTAssertEqual(
            BASLayerActorStatus.partial.rawValue, "partial")
        XCTAssertEqual(
            BASLayerActorStatus.quarantined.rawValue, "quarantined")
    }

    func testStatusCodableRoundTrip() throws {
        for s in BASLayerActorStatus.allCases {
            let data = try JSONEncoder().encode(s)
            let decoded = try JSONDecoder().decode(
                BASLayerActorStatus.self, from: data)
            XCTAssertEqual(decoded, s)
        }
    }

    // MARK: - Input frame

    private let referenceDate = Date(
        timeIntervalSince1970: 1_700_000_000)

    func testInputFrameDefaultSchemaVersion() {
        let input = BASLayerActorInput(
            layerID: .l11,
            turnID: "turn-1",
            payloadRef: "payload-1",
            arrivedAt: referenceDate)
        XCTAssertEqual(input.schemaVersion, "1.0.0")
        XCTAssertNil(input.parentLayerID)
        XCTAssertNil(input.correlationID)
    }

    func testInputFrameTrimsStrings() {
        let input = BASLayerActorInput(
            layerID: .l9,
            turnID: "  turn-2  \n",
            payloadRef: "  pay-2  ",
            arrivedAt: referenceDate,
            correlationID: " corr-3 ")
        XCTAssertEqual(input.turnID, "turn-2")
        XCTAssertEqual(input.payloadRef, "pay-2")
        XCTAssertEqual(input.correlationID, "corr-3")
    }

    func testInputFrameCodableRoundTrip() throws {
        let original = BASLayerActorInput(
            layerID: .l6,
            turnID: "turn-rt",
            payloadRef: "payload-rt",
            parentLayerID: .l5,
            arrivedAt: referenceDate,
            correlationID: "corr-rt")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(
            BASLayerActorInput.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func testInputFrameAcceptsAll14LayerIDs() {
        for layer in BASMotherboardLayer14.allCases {
            let input = BASLayerActorInput(
                layerID: layer,
                turnID: "turn-x",
                payloadRef: "payload-x",
                arrivedAt: referenceDate)
            XCTAssertEqual(input.layerID, layer)
        }
    }

    // MARK: - Output frame

    func testOutputFrameDefaultSchemaVersion() {
        let output = BASLayerActorOutput(
            layerID: .l11,
            turnID: "turn-out",
            status: .completed,
            producedAt: referenceDate)
        XCTAssertEqual(output.schemaVersion, "1.0.0")
        XCTAssertEqual(output.latencyMs, 0)
        XCTAssertEqual(output.confidence, .unknown)
        XCTAssertEqual(output.reasonCodes, [])
        XCTAssertNil(output.payloadRef)
    }

    func testOutputFrameClampsLatencyToZero() {
        let output = BASLayerActorOutput(
            layerID: .l9,
            turnID: "turn-c",
            status: .completed,
            latencyMs: -5.5,
            producedAt: referenceDate)
        XCTAssertEqual(output.latencyMs, 0,
            "negative latency must clamp to 0 per chapter 二百一一 " +
            "anti-magic-number doctrine")
    }

    func testOutputFrameFiltersEmptyReasonCodes() {
        let output = BASLayerActorOutput(
            layerID: .l10,
            turnID: "turn-rc",
            status: .partial,
            reasonCodes: [
                "permit.escalated",
                "  ",
                "axis.aligned",
                "",
                "  layer-latency:l10:42  "
            ],
            producedAt: referenceDate)
        XCTAssertEqual(
            output.reasonCodes,
            ["permit.escalated",
             "axis.aligned",
             "layer-latency:l10:42"],
            "empty/whitespace reason codes must be filtered + " +
            "trimmed (chapter 二百一一 single-source-of-truth + " +
            "chapter 一百八十五 anti-magic-number doctrine)")
    }

    func testOutputFrameCodableRoundTrip() throws {
        let original = BASLayerActorOutput(
            layerID: .l11,
            turnID: "turn-rtb",
            status: .skippedByGate,
            payloadRef: "out-rtb",
            latencyMs: 12.34,
            confidence: .medium,
            reasonCodes: ["permit.gate.cleared"],
            producedAt: referenceDate)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(
            BASLayerActorOutput.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    // MARK: - Protocol conformance via mock actor

    private actor MockLayerActor: BASLayerActor {
        nonisolated let layerID: BASMotherboardLayer14
        let response: BASLayerActorStatus

        init(
            layerID: BASMotherboardLayer14,
            response: BASLayerActorStatus
        ) {
            self.layerID = layerID
            self.response = response
        }

        func process(
            input: BASLayerActorInput
        ) async throws -> BASLayerActorOutput {
            BASLayerActorOutput(
                layerID: input.layerID,
                turnID: input.turnID,
                status: response,
                latencyMs: 1.5,
                confidence: .high,
                reasonCodes: [
                    "mock-actor:processed:\(input.layerID.rawValue)"
                ],
                producedAt: Date(
                    timeIntervalSince1970: 1_700_000_001))
        }
    }

    func testMockActorConformanceAndProcessRoundTrip() async throws {
        let actor = MockLayerActor(
            layerID: .l11, response: .completed)
        XCTAssertEqual(actor.layerID, .l11)

        let input = BASLayerActorInput(
            layerID: .l11,
            turnID: "turn-mock",
            payloadRef: "payload-mock",
            arrivedAt: referenceDate)
        let output = try await actor.process(input: input)
        XCTAssertEqual(output.layerID, .l11)
        XCTAssertEqual(output.turnID, "turn-mock")
        XCTAssertEqual(output.status, .completed)
        XCTAssertEqual(output.confidence, .high)
        XCTAssertEqual(
            output.reasonCodes,
            ["mock-actor:processed:l11"])
    }

    func testMockActorTurnIDFlowsFromInputToOutput() async throws {
        let actor = MockLayerActor(
            layerID: .l9, response: .partial)
        let input = BASLayerActorInput(
            layerID: .l9,
            turnID: "turn-flow-7",
            payloadRef: "p",
            arrivedAt: referenceDate)
        let output = try await actor.process(input: input)
        XCTAssertEqual(
            output.turnID, input.turnID,
            "audit chain doctrine: output.turnID 必须等于 " +
            "input.turnID — chapter 二百一一 audit doctrine")
    }

    // MARK: - Error boundary

    func testErrorBoundaryEquality() {
        let a = BASLayerActorError.budgetExceeded(
            layerID: .l9, allowedMs: 100.0)
        let b = BASLayerActorError.budgetExceeded(
            layerID: .l9, allowedMs: 100.0)
        XCTAssertEqual(a, b)

        let c = BASLayerActorError.killSwitchActive(
            layerID: .l11, reason: "manual override")
        let d = BASLayerActorError.killSwitchActive(
            layerID: .l11, reason: "manual override")
        XCTAssertEqual(c, d)

        // Different cases or payloads = unequal
        XCTAssertNotEqual(a, c)
        XCTAssertNotEqual(
            BASLayerActorError.budgetExceeded(
                layerID: .l9, allowedMs: 100.0),
            BASLayerActorError.budgetExceeded(
                layerID: .l9, allowedMs: 200.0))
    }

    func testErrorBoundaryAllFiveCases() {
        // Just exercise constructor + Equatable for each variant.
        let errors: [BASLayerActorError] = [
            .budgetExceeded(layerID: .l1, allowedMs: 5),
            .killSwitchActive(layerID: .l2, reason: "thermal"),
            .dependencyMissing(layerID: .l9, missingRef: "x"),
            .quarantine(layerID: .l14, reason: "sentinel"),
            .internalFailure(layerID: .l11, message: "unexpected")
        ]
        XCTAssertEqual(errors.count, 5)
        for (i, e) in errors.enumerated() {
            XCTAssertEqual(e, errors[i])
        }
    }
}
