// MARK: - BASChapter809ReplayHelpersTests
// chapter 八百九 / M2696-M2700
//
// Verifies the replay helpers (chapter 八百九) — pure inverse
// functions of the recorder encoding。 Closes the recording loop
// for hosts that need to resume audit state on cold restart。
//
// Five invariants pinned:
//
//   1. L6 channelKind ↔ channelByte mapping is exhaustively
//      invertible (forByte(forKind(byte)) == byte for all 5 cases)。
//   2. L6 `observationInput(from:)` reconstructs the runtime form
//      with byte-equal salience + confidence。
//   3. L7 `reconstructUnknownSet(from:)` bucketizes records back
//      into the 5 typed arrays in the original insertion order。
//   4. L7 `reconstructContradictions(from:)` parses "<kind>:
//      <summary>" + optional "(refs: ...)" encoding and rebuilds
//      `BASContradictionRecord` with severity / unresolved
//      preserved。
//   5. Round-trip end-to-end:record → store → query → replay
//      produces the same logical input as was originally recorded。

import XCTest
@testable import BASOrchestration
@testable import BASSovereign

final class BASChapter809ReplayHelpersTests: XCTestCase {

    // MARK: - L6 channel byte ↔ kind invertibility

    func testL6ChannelByteKindRoundTripAllFiveCases() {
        for byte: UInt8 in 0...4 {
            let kind = BASRoutedPresenceFusion.channelKind(
                forByte: byte)
            XCTAssertNotNil(kind, "byte \(byte) must map to a kind")
            let backByte = BASRoutedPresenceFusion.channelByte(
                forKind: kind!)
            XCTAssertEqual(backByte, byte,
                "Round trip byte -> kind -> byte must be identity")
        }
    }

    func testL6ChannelByteUnknownKindIsNil() {
        XCTAssertNil(BASRoutedPresenceFusion.channelByte(
            forKind: "unknown_channel"))
        XCTAssertNil(BASRoutedPresenceFusion.channelByte(
            forKind: ""))
    }

    func testL6ObservationInputFromRecordReconstructsBytewise() {
        let record = BASPresenceObservationRecord(
            eventID: "p",
            sessionID: "s", turnID: "t",
            channelKind: "manipulation",
            salience: 0.42, confidence: 0.84,
            observedAtMs: 1)
        let input = BASRoutedPresenceFusion.observationInput(
            from: record)
        XCTAssertEqual(input?.channelByte, 2)
        XCTAssertEqual(input?.salience, 0.42)
        XCTAssertEqual(input?.confidence, 0.84)
    }

    func testL6ObservationInputUnknownChannelKindIsNil() {
        let record = BASPresenceObservationRecord(
            eventID: "p", sessionID: "s", turnID: "t",
            channelKind: "bogus",  // not in schema-013
            salience: 0.5, confidence: 0.5, observedAtMs: 0)
        XCTAssertNil(BASRoutedPresenceFusion.observationInput(
            from: record))
    }

    // MARK: - L7 reconstruct unknown set

    func testL7ReconstructUnknownSetBucketsByKindPrefix() {
        let records = [
            BASUnknownLedgerRecord(eventID: "u-0",
                sessionID: "s", turnID: "t",
                unknownText: "fact: F1",
                confidence: 1.0, discoveredAtMs: 0),
            BASUnknownLedgerRecord(eventID: "u-1",
                sessionID: "s", turnID: "t",
                unknownText: "fact: F2",
                confidence: 1.0, discoveredAtMs: 1),
            BASUnknownLedgerRecord(eventID: "u-2",
                sessionID: "s", turnID: "t",
                unknownText: "role: R1",
                confidence: 1.0, discoveredAtMs: 2),
            BASUnknownLedgerRecord(eventID: "u-3",
                sessionID: "s", turnID: "t",
                unknownText: "constraint: C1",
                confidence: 1.0, discoveredAtMs: 3),
            BASUnknownLedgerRecord(eventID: "u-4",
                sessionID: "s", turnID: "t",
                unknownText: "permission: P1",
                confidence: 1.0, discoveredAtMs: 4),
            BASUnknownLedgerRecord(eventID: "u-5",
                sessionID: "s", turnID: "t",
                unknownText: "ambiguity: A1",
                confidence: 0.5, discoveredAtMs: 5),
        ]
        let recovered = BASRoutedMirrorBladeRecording
            .reconstructUnknownSet(from: records)
        XCTAssertEqual(recovered.missingFacts, ["F1", "F2"])
        XCTAssertEqual(recovered.missingRoles, ["R1"])
        XCTAssertEqual(recovered.missingConstraints, ["C1"])
        XCTAssertEqual(recovered.unresolvedPermissions, ["P1"])
        XCTAssertEqual(recovered.ambiguityNotes, ["A1"])
    }

    func testL7ReconstructUnknownSetDropsRecordsWithoutValidPrefix() {
        let records = [
            BASUnknownLedgerRecord(eventID: "u-0",
                sessionID: "s", turnID: "t",
                unknownText: "fact: F1",
                confidence: 1.0, discoveredAtMs: 0),
            BASUnknownLedgerRecord(eventID: "u-1",
                sessionID: "s", turnID: "t",
                unknownText: "no-prefix",  // dropped
                confidence: 1.0, discoveredAtMs: 1),
        ]
        let recovered = BASRoutedMirrorBladeRecording
            .reconstructUnknownSet(from: records)
        XCTAssertEqual(recovered.missingFacts, ["F1"])
        XCTAssertFalse(recovered.hasAny == false,
            "Recovered set must have facts even though one row dropped")
    }

    // MARK: - L7 reconstruct contradictions

    func testL7ReconstructContradictionsWithoutRefs() {
        let records = [
            BASContradictionLedgerRecord(
                eventID: "c-0", sessionID: "s", turnID: "t",
                contradictionText: "textual: claim A vs claim B",
                salience: 0.5, confidence: 1.0,
                resolved: false, resolvedAtMs: nil),
        ]
        let nodes = BASRoutedMirrorBladeRecording
            .reconstructContradictions(from: records)
        XCTAssertEqual(nodes.count, 1)
        XCTAssertEqual(nodes[0].kind, .textual)
        XCTAssertEqual(nodes[0].summary, "claim A vs claim B")
        XCTAssertEqual(nodes[0].refs, [])
        XCTAssertEqual(nodes[0].severity, 0.5, accuracy: 1e-12)
        XCTAssertTrue(nodes[0].unresolved)
    }

    func testL7ReconstructContradictionsWithRefs() {
        let records = [
            BASContradictionLedgerRecord(
                eventID: "c-0", sessionID: "s", turnID: "t",
                contradictionText: "historical: earlier vs later turn (refs: t-5, t-9)",
                salience: 0.9, confidence: 1.0,
                resolved: true, resolvedAtMs: 100),
        ]
        let nodes = BASRoutedMirrorBladeRecording
            .reconstructContradictions(from: records)
        XCTAssertEqual(nodes.count, 1)
        XCTAssertEqual(nodes[0].kind, .historical)
        XCTAssertEqual(nodes[0].summary,
            "earlier vs later turn")
        XCTAssertEqual(nodes[0].refs, ["t-5", "t-9"])
        XCTAssertFalse(nodes[0].unresolved,
            "Resolved record reverses to unresolved=false")
    }

    func testL7ReconstructContradictionsDropsUnparseable() {
        let records = [
            BASContradictionLedgerRecord(
                eventID: "c-0", sessionID: "s", turnID: "t",
                contradictionText: "no-kind-prefix",
                salience: 0.5, confidence: 1.0,
                resolved: false, resolvedAtMs: nil),
            BASContradictionLedgerRecord(
                eventID: "c-1", sessionID: "s", turnID: "t",
                contradictionText: "role: legit",
                salience: 0.5, confidence: 1.0,
                resolved: false, resolvedAtMs: nil),
        ]
        let nodes = BASRoutedMirrorBladeRecording
            .reconstructContradictions(from: records)
        XCTAssertEqual(nodes.count, 1)
        XCTAssertEqual(nodes[0].kind, .role)
    }

    // MARK: - End-to-end round trip

    func testEndToEndUnknownSetRoundTripPreservesAllKinds() async throws {
        let original = BASUnknownSet(
            missingFacts: ["F1", "F2"],
            missingRoles: ["R1"],
            missingConstraints: ["C1", "C2"],
            unresolvedPermissions: ["P1"],
            ambiguityNotes: ["A1", "A2", "A3"])
        let store = BASInMemoryUnknownLedgerStore()
        _ = try await BASRoutedMirrorBladeRecording.recordUnknownSet(
            original,
            sessionID: "s", turnID: "t",
            store: store,
            eventIDPrefix: "u",
            nowMs: 0)
        let read = await store.records(forSession: "s")
        let restored = BASRoutedMirrorBladeRecording
            .reconstructUnknownSet(from: read)
        XCTAssertEqual(restored, original,
            "End-to-end record→store→query→replay is identity")
    }

    func testEndToEndContradictionRoundTripPreservesAllFields() async throws {
        let originals = [
            BASContradictionRecord(
                nodeID: "n1", kind: .evidential,
                summary: "evidence missing",
                refs: ["e-1", "e-2"],
                severity: 0.7, unresolved: true),
            BASContradictionRecord(
                nodeID: "n2", kind: .role,
                summary: "ambiguous binding",
                refs: [],
                severity: 0.4, unresolved: false),
        ]
        let store = BASInMemoryContradictionLedgerStore()
        _ = try await BASRoutedMirrorBladeRecording
            .recordContradictions(
                originals,
                sessionID: "s", turnID: "t",
                store: store,
                eventIDPrefix: "c",
                nowMs: 1)
        let read = await store.records(forSession: "s")
        let restored = BASRoutedMirrorBladeRecording
            .reconstructContradictions(from: read)
        XCTAssertEqual(restored.count, 2)
        XCTAssertEqual(restored[0].kind, .evidential)
        XCTAssertEqual(restored[0].summary, "evidence missing")
        XCTAssertEqual(restored[0].refs, ["e-1", "e-2"])
        XCTAssertEqual(restored[0].severity, 0.7, accuracy: 1e-12)
        XCTAssertTrue(restored[0].unresolved)
        XCTAssertEqual(restored[1].kind, .role)
        XCTAssertEqual(restored[1].summary, "ambiguous binding")
        XCTAssertEqual(restored[1].refs, [])
        XCTAssertEqual(restored[1].severity, 0.4, accuracy: 1e-12)
        XCTAssertFalse(restored[1].unresolved)
    }
}
