// MARK: - BASParallelStageEventPayloadTests
// chapter 四百二十八 / M1085

import XCTest
@testable import BASHostKit
@testable import BASRuntimeCore

final class BASParallelStageEventPayloadTests:
    XCTestCase
{

    // MARK: - Group tag enum

    func testGroupTagsShipped() {
        XCTAssertEqual(
            BASParallelStageGroupTag.allCases.count, 4,
            "M1085 ships 4 fan-out tags:entryAA2," +
            " dD2, m1FourWay, generic")
    }

    func testGroupTagRawValues() {
        XCTAssertEqual(
            BASParallelStageGroupTag.entryAA2.rawValue,
            "entry-aa-2")
        XCTAssertEqual(
            BASParallelStageGroupTag.dD2.rawValue,
            "d-d-2")
        XCTAssertEqual(
            BASParallelStageGroupTag.m1FourWay.rawValue,
            "m1-four-way")
        XCTAssertEqual(
            BASParallelStageGroupTag.generic.rawValue,
            "generic")
    }

    // MARK: - Direct init

    func testDirectInitPopulatesAllFields() {
        let payload = BASParallelStageEventPayload(
            groupTag: .m1FourWay,
            turnID: "turn-1",
            memberStageCount: 4,
            observedOutputCount: 4,
            executionNanos: 250_000)
        XCTAssertEqual(
            payload.groupTag, .m1FourWay)
        XCTAssertEqual(payload.turnID, "turn-1")
        XCTAssertEqual(payload.memberStageCount, 4)
        XCTAssertEqual(
            payload.observedOutputCount, 4)
        XCTAssertEqual(
            payload.executionNanos, 250_000)
    }

    // MARK: - Codable round-trip

    func testCodableRoundTrip() throws {
        let original = BASParallelStageEventPayload(
            groupTag: .entryAA2,
            turnID: "t1",
            memberStageCount: 2,
            observedOutputCount: 2,
            executionNanos: 12_345)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let encoded = try encoder.encode(original)
        let decoded = try JSONDecoder()
            .decode(
                BASParallelStageEventPayload.self,
                from: encoded)
        XCTAssertEqual(decoded, original)
    }

    // MARK: - BASEventLogEntry round-trip

    func testEventLogEntryRoundTrip() {
        let payload = BASParallelStageEventPayload(
            groupTag: .dD2,
            turnID: "turn-X",
            memberStageCount: 2,
            observedOutputCount: 2,
            executionNanos: 50_000)
        let entry = BASEventLogEntry
            .parallelStageEvent(
                eventID: "evt-1",
                timestampMs: 100,
                sessionID: "session-X",
                payload: payload)
        XCTAssertEqual(
            entry.payloadKind, .parallelStage,
            "M1084 discriminator scan must find the" +
            " parallelStage action tag")
        XCTAssertEqual(entry.turnRef, "turn-X",
            "turnRef inherits from payload.turnID")
        let recovered = entry
            .parallelStageEventPayload
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
            actions: ["turn-lifecycle-event"],
            confidence: 0,
            payloadJson: nil)
        XCTAssertNil(
            entry.parallelStageEventPayload)
    }

    // MARK: - Byte stability (chapter 三百九二)

    func testPayloadJsonIsByteStable() {
        let payload = BASParallelStageEventPayload(
            groupTag: .entryAA2,
            turnID: "t1",
            memberStageCount: 2,
            observedOutputCount: 2,
            executionNanos: 12_345)
        let e1 = BASEventLogEntry
            .parallelStageEvent(
                eventID: "id-a",
                timestampMs: 100,
                sessionID: "s",
                payload: payload)
        let e2 = BASEventLogEntry
            .parallelStageEvent(
                eventID: "id-b",
                timestampMs: 200,
                sessionID: "s",
                payload: payload)
        XCTAssertEqual(
            e1.payloadJson, e2.payloadJson)
    }
}
