// MARK: - BASNativeStageDispatchEventPayloadTests
// chapter 四百三十九 / M1132-M1133

import XCTest
@testable import BASHostKit
@testable import BASMetalSubstrate
@testable import BASRuntimeCore

final class BASNativeStageDispatchEventPayloadTests:
    XCTestCase
{

    // MARK: - Direct init

    func testEventRecordDirectInit() {
        let r = BASNativeStageDispatchEventRecord(
            stageRawValue: "stage-h-risk-l11",
            selectedBackingKindRawValue: "mlx-array",
            selectedKernelKeyDescriptor:
                "mat-mul|float16|mlx-array",
            durationMs: 5,
            honoredAssignment: true)
        XCTAssertEqual(
            r.stageRawValue, "stage-h-risk-l11")
        XCTAssertEqual(
            r.selectedBackingKindRawValue, "mlx-array")
        XCTAssertEqual(r.durationMs, 5)
        XCTAssertTrue(r.honoredAssignment)
    }

    func testPayloadDirectInit() {
        let r = BASNativeStageDispatchEventRecord(
            stageRawValue: "stage-a",
            selectedBackingKindRawValue: "",
            selectedKernelKeyDescriptor: "",
            durationMs: 0,
            honoredAssignment: false)
        let payload =
            BASNativeStageDispatchEventPayload(
                turnID: "turn-1",
                records: [r],
                executionCount: 1,
                honoredAssignmentCount: 0,
                unhonoredAssignmentCount: 1,
                totalDurationMs: 0)
        XCTAssertEqual(payload.turnID, "turn-1")
        XCTAssertEqual(payload.executionCount, 1)
        XCTAssertEqual(
            payload.honoredAssignmentCount, 0)
        XCTAssertEqual(
            payload.unhonoredAssignmentCount, 1)
    }

    // MARK: - .from(ledger:turnID:) factory

    func testFromLedgerEmpty() {
        let payload =
            BASNativeStageDispatchEventPayload.from(
                ledger: .empty,
                turnID: "t1")
        XCTAssertEqual(payload.executionCount, 0)
        XCTAssertEqual(
            payload.honoredAssignmentCount, 0)
        XCTAssertEqual(
            payload.unhonoredAssignmentCount, 0)
        XCTAssertEqual(payload.totalDurationMs, 0)
        XCTAssertTrue(payload.records.isEmpty)
    }

    func testFromLedgerHonoredRecord() {
        let assignment = BASStageAcceleratorAssignment(
            selectedBackingKind: .mlxArray,
            selectedKernelKey: BASKernelKey(
                operation: .matMul,
                dataType: .float16,
                backingKind: .mlxArray),
            costScore: 1.0,
            thermalSnapshot: .nominal,
            assignmentRationale: .aneSupported)
        let r = BASNativeStageExecutionRecord(
            stageRawValue: "stage-m1",
            assignment: assignment,
            durationMs: 7,
            sequenceIndex: 0,
            honoredAssignment: true)
        let ledger = BASNativeStageDispatchLedger.empty
            .appending(r)
        let payload =
            BASNativeStageDispatchEventPayload.from(
                ledger: ledger,
                turnID: "t1")
        XCTAssertEqual(payload.executionCount, 1)
        XCTAssertEqual(
            payload.honoredAssignmentCount, 1)
        XCTAssertEqual(
            payload.totalDurationMs, 7)
        let firstRecord = payload.records.first
        XCTAssertEqual(
            firstRecord?.stageRawValue, "stage-m1")
        XCTAssertEqual(
            firstRecord?.selectedBackingKindRawValue,
            "mlx-array",
            "honored assignment must encode backing" +
            " rawvalue verbatim")
        XCTAssertEqual(
            firstRecord?.selectedKernelKeyDescriptor,
            "mat-mul|float16|mlx-array")
    }

    func testFromLedgerUnhoredRecord() {
        let r = BASNativeStageExecutionRecord(
            stageRawValue: "stage-fallback",
            assignment: nil,
            durationMs: 3,
            sequenceIndex: 0,
            honoredAssignment: false)
        let ledger = BASNativeStageDispatchLedger.empty
            .appending(r)
        let payload =
            BASNativeStageDispatchEventPayload.from(
                ledger: ledger,
                turnID: "t1")
        XCTAssertEqual(
            payload.unhonoredAssignmentCount, 1)
        let firstRecord = payload.records.first
        XCTAssertEqual(
            firstRecord?.selectedBackingKindRawValue,
            "",
            "unhonored fallback → empty string for" +
            " backing rawvalue")
        XCTAssertEqual(
            firstRecord?.selectedKernelKeyDescriptor,
            "",
            "unhonored fallback → empty string for" +
            " kernel key descriptor")
    }

    // MARK: - Codable round-trip

    func testCodableRoundTrip() throws {
        let r = BASNativeStageDispatchEventRecord(
            stageRawValue: "stage-attention",
            selectedBackingKindRawValue: "metal-buffer",
            selectedKernelKeyDescriptor:
                "attention|float16|metal-buffer",
            durationMs: 12,
            honoredAssignment: true)
        let payload =
            BASNativeStageDispatchEventPayload(
                turnID: "t1",
                records: [r],
                executionCount: 1,
                honoredAssignmentCount: 1,
                unhonoredAssignmentCount: 0,
                totalDurationMs: 12)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(payload)
        let decoded = try JSONDecoder().decode(
            BASNativeStageDispatchEventPayload.self,
            from: data)
        XCTAssertEqual(decoded, payload)
    }

    // MARK: - BASEventLogEntry round-trip

    func testEventLogEntryRoundTrip() {
        let payload =
            BASNativeStageDispatchEventPayload(
                turnID: "turn-Z",
                records: [],
                executionCount: 0,
                honoredAssignmentCount: 0,
                unhonoredAssignmentCount: 0,
                totalDurationMs: 0)
        let entry = BASEventLogEntry
            .nativeStageDispatchEvent(
                eventID: "evt-1",
                timestampMs: 100,
                sessionID: "session-Z",
                payload: payload)
        XCTAssertEqual(
            entry.payloadKind, .nativeStageDispatch)
        let recovered = entry
            .nativeStageDispatchEventPayload
        XCTAssertEqual(recovered, payload)
    }

    func testReverseAccessorReturnsNilForWrongKind() {
        let entry = BASEventLogEntry(
            eventID: "x",
            timestampMs: 0,
            kind: .substrateAudit,
            sessionID: "s",
            sequenceNumber: 0,
            source: nil,
            turnRef: nil,
            rawInputDigest: nil,
            intent: nil,
            emotion: nil,
            riskBand: .unknown,
            project: nil,
            memoryRefs: [],
            stateBeforeID: nil,
            stateAfterID: nil,
            actions: ["turn-lifecycle-event"],
            confidence: 0,
            payloadJson: nil)
        XCTAssertNil(
            entry.nativeStageDispatchEventPayload)
    }

    // MARK: - Byte stability (chapter 三百九二)

    func testPayloadJsonIsByteStable() {
        let payload =
            BASNativeStageDispatchEventPayload(
                turnID: "t1",
                records: [],
                executionCount: 0,
                honoredAssignmentCount: 0,
                unhonoredAssignmentCount: 0,
                totalDurationMs: 0)
        let e1 = BASEventLogEntry
            .nativeStageDispatchEvent(
                eventID: "id-a",
                timestampMs: 100,
                sessionID: "s",
                payload: payload)
        let e2 = BASEventLogEntry
            .nativeStageDispatchEvent(
                eventID: "id-b",
                timestampMs: 200,
                sessionID: "s",
                payload: payload)
        XCTAssertEqual(
            e1.payloadJson, e2.payloadJson)
    }

    // MARK: - Projector

    func testProjectorEmptyInput() {
        let result = BASEventLogProjectors
            .projectNativeStageDispatchEvents([])
        XCTAssertTrue(result.isEmpty)
    }

    func testProjectorFiltersByKind() {
        let dispatchPayload =
            BASNativeStageDispatchEventPayload(
                turnID: "t1",
                records: [],
                executionCount: 0,
                honoredAssignmentCount: 0,
                unhonoredAssignmentCount: 0,
                totalDurationMs: 0)
        let lifecyclePayload =
            BASTurnLifecycleEventPayload(
                phase: .start,
                turnID: "t1",
                sessionID: "s1",
                sequenceNumber: 1)
        let entries = [
            BASEventLogEntry
                .nativeStageDispatchEvent(
                    eventID: "e1",
                    timestampMs: 100,
                    sessionID: "s1",
                    sequenceNumber: 1,
                    payload: dispatchPayload),
            BASEventLogEntry.turnLifecycleEvent(
                eventID: "e2",
                timestampMs: 101,
                sessionID: "s1",
                sequenceNumber: 2,
                payload: lifecyclePayload)
        ]
        let projected = BASEventLogProjectors
            .projectNativeStageDispatchEvents(entries)
        XCTAssertEqual(
            projected.count, 1,
            "projector picks only its kind")
    }

    func testProjectorSortsBySequenceNumber() {
        let p1 = BASNativeStageDispatchEventPayload(
            turnID: "t1",
            records: [],
            executionCount: 0,
            honoredAssignmentCount: 0,
            unhonoredAssignmentCount: 0,
            totalDurationMs: 0)
        let p2 = BASNativeStageDispatchEventPayload(
            turnID: "t2",
            records: [],
            executionCount: 0,
            honoredAssignmentCount: 0,
            unhonoredAssignmentCount: 0,
            totalDurationMs: 0)
        // OUT-OF-ORDER input
        let entries = [
            BASEventLogEntry
                .nativeStageDispatchEvent(
                    eventID: "e2",
                    timestampMs: 200,
                    sessionID: "s1",
                    sequenceNumber: 2,
                    payload: p2),
            BASEventLogEntry
                .nativeStageDispatchEvent(
                    eventID: "e1",
                    timestampMs: 100,
                    sessionID: "s1",
                    sequenceNumber: 1,
                    payload: p1)
        ]
        let projected = BASEventLogProjectors
            .projectNativeStageDispatchEvents(entries)
        XCTAssertEqual(
            projected.map { $0.turnID },
            ["t1", "t2"],
            "projector must sort by sequenceNumber" +
            " (chapter 三百九二)")
    }
}
