// MARK: - BASChapter824MediumFixesTests
// chapter 八百二十四 / M2771-M2775
//
// Verifies the MEDIUM-severity findings from the 全量 审查 +
// 严查 reviews have been addressed:
//
//   1. JSONEncoder is now shared + pinned to .sortedKeys for
//      deterministic output (was creating a fresh encoder per
//      call with no output-format guarantees)。
//   2. Schema-023 byte values now have Swift enum mirrors
//      (Phase / Action / Outcome) — magic numbers gone from
//      the public API。
//   3. PresenceFusion eventID gap behavior PRESERVED + doctrine
//      pin documented (the「collision risk」 the agent flagged
//      doesn't actually exist;hosts must use unique prefixes
//      per call,which is the existing contract)。
//
// Note:Recorder parameter-ordering inconsistency (LOW finding)
// intentionally NOT addressed — the 4 recorders broadly follow
// 「identity → payload → store → timing」 with minor variations,
// and refactoring would touch ~20 test methods for cosmetic gain。
// Convention documented going forward。

import XCTest
@testable import BASMemory
@testable import BASSovereign
@testable import BASOrchestration

final class BASChapter824MediumFixesTests: XCTestCase {

    // MARK: - JSONEncoder .sortedKeys pin

    func testDeterministicJSONEncoderHasSortedKeys() {
        let enc = BASRoutedHostConstitutionRecording
            .deterministicJSONEncoder
        XCTAssertTrue(
            enc.outputFormatting.contains(.sortedKeys),
            "Shared encoder must pin .sortedKeys for determinism")
    }

    func testEncodeRefListProducesStableOutput() throws {
        let refs = ["c", "a", "b"]
        let out1 = try BASRoutedHostConstitutionRecording
            .encodeRefList(refs)
        let out2 = try BASRoutedHostConstitutionRecording
            .encodeRefList(refs)
        XCTAssertEqual(out1, out2,
            "Same input → identical output across two calls")
        XCTAssertEqual(out1, #"["c","a","b"]"#,
            "Array element order preserved (not sorted) — this " +
            "is correct since the refs ARE the data, not keys")
    }

    func testEncodeRefListEmptyArrayProducesEmptyJSON() throws {
        let out = try BASRoutedHostConstitutionRecording
            .encodeRefList([])
        XCTAssertEqual(out, "[]")
    }

    // MARK: - Schema-023 enum mirrors

    func testPhaseEnumByteValuesMatchRustContract() {
        XCTAssertEqual(BASRoutedAtomLifecycleRecording
            .Phase.created.byteValue, 0)
        XCTAssertEqual(BASRoutedAtomLifecycleRecording
            .Phase.admitted.byteValue, 1)
        XCTAssertEqual(BASRoutedAtomLifecycleRecording
            .Phase.linked.byteValue, 2)
        XCTAssertEqual(BASRoutedAtomLifecycleRecording
            .Phase.archived.byteValue, 3)
        XCTAssertEqual(BASRoutedAtomLifecycleRecording
            .Phase.tombstoned.byteValue, 4)
    }

    func testActionEnumByteValuesMatchRustContract() {
        XCTAssertEqual(BASRoutedAtomLifecycleRecording
            .Action.admit.byteValue, 0)
        XCTAssertEqual(BASRoutedAtomLifecycleRecording
            .Action.link.byteValue, 1)
        XCTAssertEqual(BASRoutedAtomLifecycleRecording
            .Action.archive.byteValue, 2)
        XCTAssertEqual(BASRoutedAtomLifecycleRecording
            .Action.tombstone.byteValue, 3)
    }

    func testOutcomeEnumInt32ValuesMatchRustContract() {
        XCTAssertEqual(BASRoutedAtomLifecycleRecording
            .Outcome.advanced.int32Value, 0)
        XCTAssertEqual(BASRoutedAtomLifecycleRecording
            .Outcome.rejectedIllegal.int32Value, 1)
        XCTAssertEqual(BASRoutedAtomLifecycleRecording
            .Outcome.rejectedTerminal.int32Value, 2)
    }

    func testPhaseFromByteRoundTrip() {
        for phase in BASRoutedAtomLifecycleRecording.Phase.allCases {
            let recovered = BASRoutedAtomLifecycleRecording.Phase
                .from(byte: phase.byteValue)
            XCTAssertEqual(recovered, phase)
        }
        XCTAssertNil(BASRoutedAtomLifecycleRecording.Phase
            .from(byte: 99))
    }

    func testActionFromByteRoundTrip() {
        for action in BASRoutedAtomLifecycleRecording.Action.allCases {
            let recovered = BASRoutedAtomLifecycleRecording.Action
                .from(byte: action.byteValue)
            XCTAssertEqual(recovered, action)
        }
        XCTAssertNil(BASRoutedAtomLifecycleRecording.Action
            .from(byte: 9))
    }

    func testOutcomeFromInt32RoundTrip() {
        for outcome in BASRoutedAtomLifecycleRecording.Outcome.allCases {
            let recovered = BASRoutedAtomLifecycleRecording.Outcome
                .from(int32: outcome.int32Value)
            XCTAssertEqual(recovered, outcome)
        }
        XCTAssertNil(BASRoutedAtomLifecycleRecording.Outcome
            .from(int32: -1))
    }

    func testEnumsAreCodable() throws {
        let phase = BASRoutedAtomLifecycleRecording.Phase.linked
        let action = BASRoutedAtomLifecycleRecording.Action.archive
        let outcome = BASRoutedAtomLifecycleRecording.Outcome.advanced
        // Phase + Action use UInt8 rawValue → numeric output
        XCTAssertEqual(String(data: try JSONEncoder().encode(phase),
                              encoding: .utf8), "2")
        XCTAssertEqual(String(data: try JSONEncoder().encode(action),
                              encoding: .utf8), "2")
        XCTAssertEqual(String(data: try JSONEncoder().encode(outcome),
                              encoding: .utf8), "0")
    }

    // MARK: - PresenceFusion eventID gap doctrine preserved

    func testPresenceFusionGapBehaviorIsPreservedContract() async throws {
        // chapter 八百二十四 verification:the 严查 agent flagged
        // a「collision risk」 in eventID generation when out-of-
        // range bytes are skipped。 On closer inspection,gap-
        // preserving behavior is the CORRECT contract — it
        // encodes input position into eventID for traceability。
        // This test pins that behavior。
        let store = BASInMemoryPresenceObservationStore()
        let observations = [
            BASChannelObservationInput(
                channelByte: 0, salience: 0.5, confidence: 0.8),
            BASChannelObservationInput(
                channelByte: 9, salience: 0.5, confidence: 0.8),  // skip
            BASChannelObservationInput(
                channelByte: 1, salience: 0.6, confidence: 0.7),
        ]
        _ = try await BASRoutedPresenceFusion.fuseAndRecord(
            observations: observations,
            sessionID: "s",
            turnID: "t",
            store: store,
            eventIDPrefix: "gap",
            nowMs: 0)
        let saved = await store.records(forSession: "s")
        XCTAssertEqual(saved.count, 2)
        XCTAssertEqual(saved.map { $0.eventID },
            ["gap-0", "gap-2"],
            "Skipped index 1 leaves a gap in the suffix sequence;" +
            " the eventID encodes ORIGINAL input position for traceability")
    }
}
