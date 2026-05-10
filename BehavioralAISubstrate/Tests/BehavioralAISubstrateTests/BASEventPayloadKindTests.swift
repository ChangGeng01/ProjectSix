// MARK: - BASEventPayloadKindTests — chapter 四百二十八 / M1084

import XCTest
@testable import BASRuntimeCore

final class BASEventPayloadKindTests: XCTestCase {

    // MARK: - 4 cases shipped

    func testFourPayloadKindsShipped() {
        XCTAssertEqual(
            BASEventPayloadKind.allCases.count, 4,
            "M1084 ships 4 payload kinds:memoryAtom" +
            " / turnLifecycle / permitEscalation /" +
            " parallelStage")
    }

    // MARK: - Raw values byte-stable + match action tags

    func testMemoryAtomRawMatchesExistingActionTag() {
        // chapter 八十七 raw value stability: M1084 must
        // not change the M941 memory-atom-event action
        // tag。 New enum case must mirror the existing
        // string verbatim。
        XCTAssertEqual(
            BASEventPayloadKind.memoryAtom.rawValue,
            "memory-atom-event")
    }

    func testTurnLifecycleRawValue() {
        XCTAssertEqual(
            BASEventPayloadKind.turnLifecycle.rawValue,
            "turn-lifecycle-event")
    }

    func testPermitEscalationRawValue() {
        XCTAssertEqual(
            BASEventPayloadKind.permitEscalation.rawValue,
            "permit-escalation-event")
    }

    func testParallelStageRawValue() {
        XCTAssertEqual(
            BASEventPayloadKind.parallelStage.rawValue,
            "parallel-stage-event")
    }

    // MARK: - Codable round-trip

    func testCodableRoundTrip() throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        for kind in BASEventPayloadKind.allCases {
            let encoded = try encoder.encode(kind)
            let decoded = try JSONDecoder()
                .decode(
                    BASEventPayloadKind.self,
                    from: encoded)
            XCTAssertEqual(decoded, kind)
        }
    }

    // MARK: - BASEventLogEntry.payloadKind accessor

    func testPayloadKindReturnsNilForEmptyActions() {
        let entry = BASEventLogEntry(
            eventID: "id1",
            timestampMs: 1000,
            kind: .internalSignal,
            sessionID: "s1",
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
            actions: [],
            confidence: 0,
            payloadJson: nil)
        XCTAssertNil(entry.payloadKind,
            "empty actions → no payload kind")
    }

    func testPayloadKindFindsMemoryAtomTag() {
        let entry = makeEntry(
            actions: ["memory-atom-event"])
        XCTAssertEqual(
            entry.payloadKind, .memoryAtom)
    }

    func testPayloadKindFindsTurnLifecycleTag() {
        let entry = makeEntry(
            actions: ["turn-lifecycle-event"])
        XCTAssertEqual(
            entry.payloadKind, .turnLifecycle)
    }

    func testPayloadKindFindsPermitEscalationTag() {
        let entry = makeEntry(
            actions: ["permit-escalation-event"])
        XCTAssertEqual(
            entry.payloadKind, .permitEscalation)
    }

    func testPayloadKindFindsParallelStageTag() {
        let entry = makeEntry(
            actions: ["parallel-stage-event"])
        XCTAssertEqual(
            entry.payloadKind, .parallelStage)
    }

    func testPayloadKindIgnoresUnknownActionTags() {
        let entry = makeEntry(
            actions: [
                "permit:answer",
                "tool:searchMemory",
                "skip:thermal-pause"
            ])
        XCTAssertNil(entry.payloadKind,
            "non-payload action tags → nil payload kind")
    }

    func testPayloadKindFindsTagAmongOthers() {
        let entry = makeEntry(
            actions: [
                "permit:answer",
                "memory-atom-event",
                "tool:searchMemory"
            ])
        XCTAssertEqual(
            entry.payloadKind, .memoryAtom,
            "scan must find payload kind tag mixed in" +
            " with other actions")
    }

    // MARK: - hasPayloadKind convenience

    func testHasPayloadKindTrueWhenPresent() {
        let entry = makeEntry(
            actions: [
                "permit-escalation-event",
                "audit-extra"
            ])
        XCTAssertTrue(
            entry.hasPayloadKind(.permitEscalation))
        XCTAssertFalse(
            entry.hasPayloadKind(.memoryAtom))
    }

    // MARK: - Helper

    private func makeEntry(
        actions: [String]
    ) -> BASEventLogEntry {
        return BASEventLogEntry(
            eventID: "id-" + actions.joined(),
            timestampMs: 1000,
            kind: .internalSignal,
            sessionID: "s1",
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
            actions: actions,
            confidence: 0,
            payloadJson: nil)
    }
}
