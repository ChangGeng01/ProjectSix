// MARK: - BASTurnLifecycleEventPayloadTests
// chapter 四百二十八 / M1085

import XCTest
@testable import BASHostKit
@testable import BASRuntimeCore

final class BASTurnLifecycleEventPayloadTests:
    XCTestCase
{

    // MARK: - Phase enum

    func testPhaseRawValues() {
        XCTAssertEqual(
            BASTurnLifecyclePhase.start.rawValue,
            "start")
        XCTAssertEqual(
            BASTurnLifecyclePhase.complete.rawValue,
            "complete")
        XCTAssertEqual(
            BASTurnLifecyclePhase.allCases.count, 2)
    }

    // MARK: - Direct init persists fields

    func testDirectInitPopulatesAllFields() {
        let payload = BASTurnLifecycleEventPayload(
            phase: .complete,
            turnID: "turn-1",
            sessionID: "session-1",
            sequenceNumber: 5,
            firedEscalationStageCount: 2,
            observedStageCount: 18,
            stagePlanStepCount: 18,
            stagePlanIsCanonical: true)
        XCTAssertEqual(payload.phase, .complete)
        XCTAssertEqual(payload.turnID, "turn-1")
        XCTAssertEqual(payload.sessionID, "session-1")
        XCTAssertEqual(payload.sequenceNumber, 5)
        XCTAssertEqual(
            payload.firedEscalationStageCount, 2)
        XCTAssertEqual(payload.observedStageCount, 18)
        XCTAssertEqual(payload.stagePlanStepCount, 18)
        XCTAssertTrue(payload.stagePlanIsCanonical)
    }

    func testDefaultsForStartPhase() {
        let payload = BASTurnLifecycleEventPayload(
            phase: .start,
            turnID: "turn-2",
            sessionID: "session-2",
            sequenceNumber: 1)
        XCTAssertEqual(
            payload.firedEscalationStageCount, 0,
            "start phase should default to 0 fired " +
            "escalations")
        XCTAssertEqual(
            payload.observedStageCount, 0)
        XCTAssertEqual(
            payload.stagePlanStepCount, 0)
        XCTAssertFalse(payload.stagePlanIsCanonical)
    }

    // MARK: - Codable round-trip

    func testCodableRoundTripStartPhase() throws {
        let original = BASTurnLifecycleEventPayload(
            phase: .start,
            turnID: "t1",
            sessionID: "s1",
            sequenceNumber: 0)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let encoded = try encoder.encode(original)
        let decoded = try JSONDecoder()
            .decode(
                BASTurnLifecycleEventPayload.self,
                from: encoded)
        XCTAssertEqual(decoded, original)
    }

    func testCodableRoundTripCompletePhase() throws {
        let original = BASTurnLifecycleEventPayload(
            phase: .complete,
            turnID: "t1",
            sessionID: "s1",
            sequenceNumber: 1,
            firedEscalationStageCount: 3,
            observedStageCount: 18,
            stagePlanStepCount: 18,
            stagePlanIsCanonical: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let encoded = try encoder.encode(original)
        let decoded = try JSONDecoder()
            .decode(
                BASTurnLifecycleEventPayload.self,
                from: encoded)
        XCTAssertEqual(decoded, original)
    }

    // MARK: - BASEventLogEntry round-trip

    func testEventLogEntryRoundTrip() {
        let payload = BASTurnLifecycleEventPayload(
            phase: .complete,
            turnID: "turn-A",
            sessionID: "session-A",
            sequenceNumber: 7,
            firedEscalationStageCount: 1,
            observedStageCount: 18,
            stagePlanStepCount: 18,
            stagePlanIsCanonical: true)
        let entry = BASEventLogEntry.turnLifecycleEvent(
            eventID: "evt-1",
            timestampMs: 100,
            sessionID: "session-A",
            payload: payload)
        XCTAssertEqual(
            entry.kind, .substrateAudit,
            "turn lifecycle entries land on the" +
            " substrateAudit channel")
        XCTAssertEqual(
            entry.payloadKind, .turnLifecycle,
            "M1084 discriminator scan must find the" +
            " turnLifecycle action tag")
        XCTAssertEqual(
            entry.turnRef, "turn-A",
            "turnRef should default to payload.turnID")
        let recovered = entry
            .turnLifecycleEventPayload
        XCTAssertEqual(recovered, payload,
            "round-trip must reconstruct typed payload")
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
            actions: ["memory-atom-event"],
            confidence: 0,
            payloadJson: nil)
        XCTAssertNil(
            entry.turnLifecycleEventPayload,
            "reverse accessor must return nil for" +
            " non-turn-lifecycle entries")
    }

    // MARK: - Wire-level byte stability (chapter 三百九二)

    func testPayloadJsonIsByteStable() throws {
        let payload = BASTurnLifecycleEventPayload(
            phase: .complete,
            turnID: "t1",
            sessionID: "s1",
            sequenceNumber: 1,
            firedEscalationStageCount: 2,
            observedStageCount: 18,
            stagePlanStepCount: 18,
            stagePlanIsCanonical: true)
        let entry1 = BASEventLogEntry
            .turnLifecycleEvent(
                eventID: "id-a",
                timestampMs: 100,
                sessionID: "s1",
                payload: payload)
        let entry2 = BASEventLogEntry
            .turnLifecycleEvent(
                eventID: "id-b",
                timestampMs: 200,
                sessionID: "s1",
                payload: payload)
        XCTAssertEqual(
            entry1.payloadJson, entry2.payloadJson,
            "payloadJson must be byte-equal for the" +
            " same typed payload (sortedKeys)")
    }
}
