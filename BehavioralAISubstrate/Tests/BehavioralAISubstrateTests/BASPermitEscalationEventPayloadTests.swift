// MARK: - BASPermitEscalationEventPayloadTests
// chapter 四百二十八 / M1086

import XCTest
@testable import BASPolicy
@testable import BASRuntimeCore

final class BASPermitEscalationEventPayloadTests:
    XCTestCase
{

    // MARK: - Stage event record direct init

    func testStageRecordDirectInit() {
        let record =
            BASPermitEscalationStageEventRecord(
                stageRawValue: "abyssal",
                fired: true,
                reasonCodes: ["abyssal:risk-tip"],
                outputPermitModeRawValue: "delay",
                outputPermitReasonCodes: [
                    "init", "abyssal-fired"
                ])
        XCTAssertEqual(
            record.stageRawValue, "abyssal")
        XCTAssertTrue(record.fired)
        XCTAssertEqual(
            record.reasonCodes,
            ["abyssal:risk-tip"])
        XCTAssertEqual(
            record.outputPermitModeRawValue, "delay")
        XCTAssertEqual(
            record.outputPermitReasonCodes.count, 2)
    }

    // MARK: - Payload direct init

    func testPayloadDirectInit() {
        let record =
            BASPermitEscalationStageEventRecord(
                stageRawValue: "kunlun",
                fired: false,
                reasonCodes: [],
                outputPermitModeRawValue: "answer",
                outputPermitReasonCodes: ["init"])
        let payload = BASPermitEscalationEventPayload(
            turnID: "turn-1",
            initialPermitModeRawValue: "answer",
            initialPermitReasonCodes: ["init"],
            stageRecords: [record],
            firedStageCount: 0)
        XCTAssertEqual(payload.turnID, "turn-1")
        XCTAssertEqual(
            payload.initialPermitModeRawValue,
            "answer")
        XCTAssertEqual(
            payload.stageRecords.count, 1)
        XCTAssertEqual(payload.firedStageCount, 0)
    }

    // MARK: - .from(ledger:turnID:) factory

    func testFromLedgerProducesEquivalentPayload() {
        let initialPermit = BASActionPermit(
            mode: .answer,
            reasonCodes: ["init"])
        let bumped = BASActionPermit(
            mode: .delay,
            reasonCodes: ["init", "abyssal-fired"])
        let ledger = BASPermitEscalationLedger.build(
            initialPermit: initialPermit,
            afterAbyssal: bumped,
            afterAssertionCeiling: bumped,
            afterKunlun: bumped,
            afterCthulhuAssertionCeiling: bumped,
            afterCthulhuEscalation: bumped)
        let payload = BASPermitEscalationEventPayload
            .from(
                ledger: ledger,
                turnID: "turn-A")
        XCTAssertEqual(payload.turnID, "turn-A")
        XCTAssertEqual(
            payload.initialPermitModeRawValue,
            "answer")
        XCTAssertEqual(
            payload.stageRecords.count, 5,
            ".from(ledger:) emits all 5 escalation" +
            " stages")
        XCTAssertEqual(
            payload.firedStageCount,
            ledger.firedStageCount,
            "fired count must match the source ledger")
    }

    // MARK: - Codable round-trip

    func testCodableRoundTrip() throws {
        let record =
            BASPermitEscalationStageEventRecord(
                stageRawValue: "abyssal",
                fired: true,
                reasonCodes: ["a"],
                outputPermitModeRawValue: "delay",
                outputPermitReasonCodes: ["init", "a"])
        let payload = BASPermitEscalationEventPayload(
            turnID: "t1",
            initialPermitModeRawValue: "answer",
            initialPermitReasonCodes: ["init"],
            stageRecords: [record],
            firedStageCount: 1)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let encoded = try encoder.encode(payload)
        let decoded = try JSONDecoder()
            .decode(
                BASPermitEscalationEventPayload.self,
                from: encoded)
        XCTAssertEqual(decoded, payload)
    }

    // MARK: - BASEventLogEntry round-trip

    func testEventLogEntryRoundTrip() {
        let payload = BASPermitEscalationEventPayload(
            turnID: "turn-Y",
            initialPermitModeRawValue: "answer",
            initialPermitReasonCodes: ["init"],
            stageRecords: [],
            firedStageCount: 0)
        let entry = BASEventLogEntry
            .permitEscalationEvent(
                eventID: "evt-1",
                timestampMs: 100,
                sessionID: "session-Y",
                payload: payload)
        XCTAssertEqual(
            entry.payloadKind, .permitEscalation)
        let recovered = entry
            .permitEscalationEventPayload
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
            actions: ["parallel-stage-event"],
            confidence: 0,
            payloadJson: nil)
        XCTAssertNil(
            entry.permitEscalationEventPayload)
    }

    // MARK: - Byte stability (chapter 三百九二)

    func testPayloadJsonIsByteStable() {
        let payload = BASPermitEscalationEventPayload(
            turnID: "t1",
            initialPermitModeRawValue: "answer",
            initialPermitReasonCodes: ["init"],
            stageRecords: [],
            firedStageCount: 0)
        let e1 = BASEventLogEntry
            .permitEscalationEvent(
                eventID: "id-a",
                timestampMs: 100,
                sessionID: "s",
                payload: payload)
        let e2 = BASEventLogEntry
            .permitEscalationEvent(
                eventID: "id-b",
                timestampMs: 200,
                sessionID: "s",
                payload: payload)
        XCTAssertEqual(
            e1.payloadJson, e2.payloadJson)
    }
}
