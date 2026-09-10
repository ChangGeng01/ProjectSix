// MARK: - BASChapter799L7MirrorBladeRecordingActivationTests
// chapter 七百九十九 / M2646-M2650
//
// Verifies the L7 unknown + contradiction recorder activation
// against the L7 storage adapters (chapter 七百九十四)。 Five
// invariants pinned:
//
//   1. Unknown-set flattening produces N records,one per non-
//      empty string across the 5 typed arrays,in fact → role →
//      constraint → permission → ambiguity order。
//   2. Per-category confidence defaults match the doctrine
//      (1.0 for 4 missing-* categories,0.5 for ambiguity)。
//   3. Contradiction recording maps `severity → salience`,
//      `!unresolved → resolved`,kind into text prefix,refs
//      inlined when present。
//   4. Both recorders survive SQLite cold-restart with all
//      records intact in insertion order。
//   5. Empty inputs (empty unknown set / empty contradiction
//      array) write zero records,no spurious side effects。

import XCTest
@testable import BASOrchestration
@testable import BASSovereign

final class BASChapter799L7MirrorBladeRecordingActivationTests: XCTestCase {

    private var unknownDB: URL!
    private var contradictionDB: URL!

    override func setUp() async throws {
        try await super.setUp()
        let tmp = FileManager.default.temporaryDirectory
        let token = UUID().uuidString
        unknownDB = tmp.appendingPathComponent(
            "bas-test-unknown-\(token).sqlite")
        contradictionDB = tmp.appendingPathComponent(
            "bas-test-contradiction-\(token).sqlite")
    }

    override func tearDown() async throws {
        for url in [unknownDB, contradictionDB] {
            if let url = url,
               FileManager.default.fileExists(atPath: url.path) {
                try? FileManager.default.removeItem(at: url)
            }
        }
        try await super.tearDown()
    }

    // MARK: - Unknown ledger recorder

    func testRecordUnknownSetEmitsOneRecordPerString() async throws {
        let store = BASInMemoryUnknownLedgerStore()
        let set = BASUnknownSet(
            missingFacts: ["F1", "F2"],
            missingRoles: ["R1"],
            missingConstraints: ["C1", "C2", "C3"],
            unresolvedPermissions: ["P1"],
            ambiguityNotes: ["A1", "A2"])
        let written = try await BASRoutedMirrorBladeRecording
            .recordUnknownSet(
                set,
                sessionID: "sess",
                turnID: "turn",
                store: store,
                eventIDPrefix: "u",
                nowMs: 1_000)

        // 2 + 1 + 3 + 1 + 2 = 9 records
        XCTAssertEqual(written.count, 9)
        let totalCount = await store.count()
        XCTAssertEqual(totalCount, 9)

        // Insertion order: facts → roles → constraints → permissions → ambiguities
        XCTAssertEqual(written.map { $0.unknownText }, [
            "fact: F1", "fact: F2",
            "role: R1",
            "constraint: C1", "constraint: C2", "constraint: C3",
            "permission: P1",
            "ambiguity: A1", "ambiguity: A2",
        ])
        XCTAssertEqual(written.map { $0.eventID },
            (0..<9).map { "u-\($0)" })

        // Doctrine-pinned per-category confidence
        XCTAssertEqual(written[0].confidence, 1.0)  // fact
        XCTAssertEqual(written[2].confidence, 1.0)  // role
        XCTAssertEqual(written[3].confidence, 1.0)  // constraint
        XCTAssertEqual(written[6].confidence, 1.0)  // permission
        XCTAssertEqual(written[7].confidence, 0.5)  // ambiguity
        XCTAssertEqual(written[8].confidence, 0.5)  // ambiguity

        // All records share the supplied timestamp
        XCTAssertEqual(Set(written.map { $0.discoveredAtMs }),
                       Set([1_000]))
    }

    func testRecordUnknownSetEmptyWritesNoRecords() async throws {
        let store = BASInMemoryUnknownLedgerStore()
        let written = try await BASRoutedMirrorBladeRecording
            .recordUnknownSet(
                .empty,
                sessionID: "sess",
                turnID: "turn",
                store: store,
                eventIDPrefix: "u",
                nowMs: 5)
        XCTAssertEqual(written, [])
        let zeroCount = await store.count()
        XCTAssertEqual(zeroCount, 0)
    }

    func testRecordUnknownSetConfidenceOverride() async throws {
        let store = BASInMemoryUnknownLedgerStore()
        let custom = BASRoutedMirrorBladeRecording
            .UnknownRecordingConfig(
                factConfidence: 0.9,
                ambiguityConfidence: 0.25)
        let set = BASUnknownSet(
            missingFacts: ["F"],
            ambiguityNotes: ["A"])
        let written = try await BASRoutedMirrorBladeRecording
            .recordUnknownSet(
                set,
                sessionID: "sess",
                turnID: "turn",
                store: store,
                eventIDPrefix: "u",
                nowMs: 0,
                config: custom)
        XCTAssertEqual(written[0].confidence, 0.9)
        XCTAssertEqual(written[1].confidence, 0.25)
    }

    func testRecordUnknownSetClampsOutOfRangeConfidence() throws {
        // Config initializer clamps to [0, 1]
        let config = BASRoutedMirrorBladeRecording
            .UnknownRecordingConfig(
                factConfidence: 2.5,
                ambiguityConfidence: -0.4)
        XCTAssertEqual(config.factConfidence, 1.0)
        XCTAssertEqual(config.ambiguityConfidence, 0.0)
    }

    // MARK: - Contradiction ledger recorder

    func testRecordContradictionsMapsSeverityAndResolvedFlag() async throws {
        let store = BASInMemoryContradictionLedgerStore()
        let nodes = [
            BASContradictionRecord(
                nodeID: "n1",
                kind: .textual,
                summary: "claim A vs claim B",
                refs: [],
                severity: 0.42,
                unresolved: true),
            BASContradictionRecord(
                nodeID: "n2",
                kind: .historical,
                summary: "earlier vs later turn",
                refs: ["t-5", "t-9"],
                severity: 0.9,
                unresolved: false),
        ]
        let written = try await BASRoutedMirrorBladeRecording
            .recordContradictions(
                nodes,
                sessionID: "sess",
                turnID: "turn",
                store: store,
                eventIDPrefix: "c",
                nowMs: 2_000)

        XCTAssertEqual(written.count, 2)
        let total = await store.count()
        XCTAssertEqual(total, 2)

        XCTAssertEqual(written[0].contradictionText,
            "textual: claim A vs claim B")
        XCTAssertEqual(written[0].salience, 0.42, accuracy: 1e-12)
        XCTAssertFalse(written[0].resolved,
            "unresolved=true → ledger.resolved=false")
        XCTAssertNil(written[0].resolvedAtMs)

        XCTAssertEqual(written[1].contradictionText,
            // chapter 八百四十六 / M2881 — refs joiner switched from
            // "; " to "\u{1F}" (ASCII Unit Separator) to eliminate
            // the bug class entirely (chapter 八百三十四 "; " still
            // collided with refs containing literal semicolons)。
            // \u{1F} is unprintable and cannot appear in any
            // legitimate ref encoding。 Parser still accepts the
            // chapter 八百三十四 "; " joiner for backward compat。
            "historical: earlier vs later turn (refs: t-5\u{1F}t-9)")
        XCTAssertEqual(written[1].salience, 0.9, accuracy: 1e-12)
        XCTAssertTrue(written[1].resolved,
            "unresolved=false → ledger.resolved=true")
        XCTAssertEqual(written[1].resolvedAtMs, 2_000,
            "resolved-at-recording uses nowMs as resolvedAtMs")
    }

    func testRecordContradictionsRefsInlineOff() async throws {
        let store = BASInMemoryContradictionLedgerStore()
        let nodes = [
            BASContradictionRecord(
                nodeID: "n1",
                kind: .role,
                summary: "ambiguous role binding",
                refs: ["a", "b"],
                severity: 0.5,
                unresolved: true),
        ]
        let cfg = BASRoutedMirrorBladeRecording
            .ContradictionRecordingConfig(inlineRefs: false)
        let written = try await BASRoutedMirrorBladeRecording
            .recordContradictions(
                nodes,
                sessionID: "sess",
                turnID: "turn",
                store: store,
                eventIDPrefix: "c",
                nowMs: 1,
                config: cfg)
        XCTAssertEqual(written[0].contradictionText,
            "role: ambiguous role binding",
            "inlineRefs=false suppresses the (refs: ...) suffix")
    }

    func testRecordContradictionsEmptyWritesNoRecords() async throws {
        let store = BASInMemoryContradictionLedgerStore()
        let written = try await BASRoutedMirrorBladeRecording
            .recordContradictions(
                [],
                sessionID: "sess",
                turnID: "turn",
                store: store,
                eventIDPrefix: "c",
                nowMs: 0)
        XCTAssertEqual(written, [])
        let zeroContradictionCount = await store.count()
        XCTAssertEqual(zeroContradictionCount, 0)
    }

    // MARK: - SQLite cold-restart through both recorders

    func testRecordersSurviveSQLiteColdRestart() async throws {
        let unknownSet = BASUnknownSet(
            missingFacts: ["F1"],
            missingRoles: ["R1"],
            ambiguityNotes: ["A1"])
        let contradictions = [
            BASContradictionRecord(
                nodeID: "n1", kind: .evidential,
                summary: "evidence missing",
                refs: ["e-1"],
                severity: 0.7, unresolved: true),
        ]

        // 1. Write through fresh actors
        do {
            let uStore = try BASSQLiteUnknownLedgerStore(
                databaseURL: unknownDB)
            let cStore = try BASSQLiteContradictionLedgerStore(
                databaseURL: contradictionDB)
            _ = try await BASRoutedMirrorBladeRecording.recordUnknownSet(
                unknownSet,
                sessionID: "sess-cold",
                turnID: "turn-cold",
                store: uStore,
                eventIDPrefix: "u-cold",
                nowMs: 100)
            _ = try await BASRoutedMirrorBladeRecording.recordContradictions(
                contradictions,
                sessionID: "sess-cold",
                turnID: "turn-cold",
                store: cStore,
                eventIDPrefix: "c-cold",
                nowMs: 200)
        }

        // 2. Cold-restart: reopen both stores from disk
        let uReopen = try BASSQLiteUnknownLedgerStore(
            databaseURL: unknownDB)
        let cReopen = try BASSQLiteContradictionLedgerStore(
            databaseURL: contradictionDB)

        let restoredUnknown = await uReopen.records(
            forSession: "sess-cold")
        XCTAssertEqual(restoredUnknown.count, 3)
        XCTAssertEqual(restoredUnknown.map { $0.unknownText },
            ["fact: F1", "role: R1", "ambiguity: A1"])
        XCTAssertEqual(restoredUnknown[2].confidence, 0.5,
            "Ambiguity default confidence survives cold restart")

        let restoredContradiction = await cReopen.records(
            forSession: "sess-cold")
        XCTAssertEqual(restoredContradiction.count, 1)
        XCTAssertEqual(restoredContradiction[0].contradictionText,
            "evidential: evidence missing (refs: e-1)")
        XCTAssertEqual(restoredContradiction[0].salience, 0.7,
            accuracy: 1e-12)
        XCTAssertFalse(restoredContradiction[0].resolved)
        XCTAssertNil(restoredContradiction[0].resolvedAtMs)
    }
}
