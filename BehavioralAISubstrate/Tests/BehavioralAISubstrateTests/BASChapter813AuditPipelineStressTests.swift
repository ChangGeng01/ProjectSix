// MARK: - BASChapter813AuditPipelineStressTests
// chapter 八百十三 / M2716-M2720
//
// Realistic per-session high-volume load test that exercises the
// ENTIRE audit pipeline shipped by chapters 七百九十八 → 八百十二:
//
//   record → batch-append → query → replay → aggregate → time-window
//
// Workload: 100 turns × {5 presence observations + 3 unknowns +
// 1 contradiction} = 500 + 300 + 100 records persisted through
// SQLite。 Verifies the pipeline holds shape under realistic load。
//
// Five invariants pinned:
//
//   1. 100-turn write completes without throwing。
//   2. Per-store record counts match (500 / 300 / 100)。
//   3. Aggregation primitives produce the right roll-up across
//      the full session (avg salience,unknown-kind counts,
//      contradiction-resolved split)。
//   4. Time-window filter slices into the middle 50 turns
//      correctly。
//   5. Replay reconstructs the BASUnknownSet from a single
//      arbitrary turn back to the original input。

import XCTest
@testable import BASMemory
@testable import BASSovereign
@testable import BASOrchestration

#if os(iOS) || os(macOS)

final class BASChapter813AuditPipelineStressTests: XCTestCase {

    private var presenceDB: URL!
    private var unknownDB: URL!
    private var contradictionDB: URL!

    override func setUp() async throws {
        try await super.setUp()
        let tmp = FileManager.default.temporaryDirectory
        let token = UUID().uuidString
        presenceDB = tmp.appendingPathComponent(
            "bas-stress-presence-\(token).sqlite")
        unknownDB = tmp.appendingPathComponent(
            "bas-stress-unknown-\(token).sqlite")
        contradictionDB = tmp.appendingPathComponent(
            "bas-stress-contradiction-\(token).sqlite")
    }

    override func tearDown() async throws {
        for url in [presenceDB, unknownDB, contradictionDB] {
            if let url = url,
               FileManager.default.fileExists(atPath: url.path) {
                try? FileManager.default.removeItem(at: url)
            }
        }
        try await super.tearDown()
    }

    // MARK: - The full pipeline stress test

    func testHundredTurnAuditPipelineEndToEnd() async throws {
        let presenceStore = try BASSQLitePresenceObservationStore(
            databaseURL: presenceDB)
        let unknownStore = try BASSQLiteUnknownLedgerStore(
            databaseURL: unknownDB)
        let contradictionStore = try BASSQLiteContradictionLedgerStore(
            databaseURL: contradictionDB)
        let sessionID = "sess-stress"
        let turnCount = 100

        // === Write phase: 100 turns ===
        for turnIdx in 0..<turnCount {
            let turnID = "turn-\(turnIdx)"
            let turnTimeMs = Int64(turnIdx * 10)

            // L6 presence (5 observations / turn)
            let observations = (0..<5).map { i in
                BASChannelObservationInput(
                    channelByte: UInt8(i),
                    salience: 0.5 + Double(turnIdx) * 0.001,
                    confidence: 0.8)
            }
            _ = try await BASRoutedPresenceFusion.fuseAndRecord(
                observations: observations,
                sessionID: sessionID,
                turnID: turnID,
                store: presenceStore,
                eventIDPrefix: "p-t\(turnIdx)",
                nowMs: turnTimeMs)

            // L7 unknowns (3 / turn — one fact,one role,one ambiguity)
            let unknownSet = BASUnknownSet(
                missingFacts: ["fact-\(turnIdx)"],
                missingRoles: ["role-\(turnIdx)"],
                ambiguityNotes: ["amb-\(turnIdx)"])
            _ = try await BASRoutedMirrorBladeRecording.recordUnknownSet(
                unknownSet,
                sessionID: sessionID,
                turnID: turnID,
                store: unknownStore,
                eventIDPrefix: "u-t\(turnIdx)",
                nowMs: turnTimeMs)

            // L7 contradiction (1 / turn,half resolved)
            let resolved = turnIdx % 2 == 0
            let contradictions = [
                BASContradictionRecord(
                    nodeID: "n-\(turnIdx)",
                    kind: .textual,
                    summary: "c-\(turnIdx)",
                    refs: [],
                    severity: 0.5 + Double(turnIdx) * 0.002,
                    unresolved: !resolved),
            ]
            _ = try await BASRoutedMirrorBladeRecording
                .recordContradictions(
                    contradictions,
                    sessionID: sessionID,
                    turnID: turnID,
                    store: contradictionStore,
                    eventIDPrefix: "c-t\(turnIdx)",
                    nowMs: turnTimeMs)
        }

        // === Invariant 1+2: record counts ===
        let presenceCount = await presenceStore.count()
        let unknownCount = await unknownStore.count()
        let contradictionCount = await contradictionStore.count()
        XCTAssertEqual(presenceCount, turnCount * 5,
            "5 presence observations per turn × 100 turns")
        XCTAssertEqual(unknownCount, turnCount * 3,
            "3 unknown records per turn × 100 turns")
        XCTAssertEqual(contradictionCount, turnCount,
            "1 contradiction per turn × 100 turns")

        // === Invariant 3: aggregation ===
        let presenceRows = await presenceStore.records(
            forSession: sessionID)
        let unknownRows = await unknownStore.records(
            forSession: sessionID)
        let contradictionRows = await contradictionStore.records(
            forSession: sessionID)

        let presenceAgg = BASRoutedAuditAggregation.aggregatePresence(
            records: presenceRows, sessionID: sessionID)
        XCTAssertEqual(presenceAgg.totalObservations, 500)
        XCTAssertEqual(presenceAgg.turnCount, 100)
        XCTAssertEqual(presenceAgg.observationCountByChannel["task"], 100)
        XCTAssertEqual(presenceAgg.observationCountByChannel["risk"], 100)
        XCTAssertEqual(presenceAgg.observationCountByChannel["manipulation"], 100)
        XCTAssertEqual(presenceAgg.observationCountByChannel["environment"], 100)
        XCTAssertEqual(presenceAgg.observationCountByChannel["bodyRhythm"], 100)

        let unknownAgg = BASRoutedAuditAggregation.aggregateUnknowns(
            records: unknownRows, sessionID: sessionID)
        XCTAssertEqual(unknownAgg.totalRecords, 300)
        XCTAssertEqual(unknownAgg.factCount, 100)
        XCTAssertEqual(unknownAgg.roleCount, 100)
        XCTAssertEqual(unknownAgg.ambiguityCount, 100)
        XCTAssertEqual(unknownAgg.constraintCount, 0)
        XCTAssertEqual(unknownAgg.permissionCount, 0)
        XCTAssertEqual(unknownAgg.unparseableCount, 0)

        let contradictionAgg = BASRoutedAuditAggregation
            .aggregateContradictions(
                records: contradictionRows,
                sessionID: sessionID)
        XCTAssertEqual(contradictionAgg.totalRecords, 100)
        XCTAssertEqual(contradictionAgg.resolvedCount, 50,
            "Half the contradictions are resolved (even turnIdx)")
        XCTAssertEqual(contradictionAgg.unresolvedCount, 50)

        // === Invariant 4: time-window slice (middle 50 turns) ===
        // Turn N has timestamp N*10。 Window [250, 750) captures
        // turns 25..74 → 50 turns × 5 obs = 250 records。
        let windowPresence = BASRoutedAuditTimeWindow.presence(
            presenceRows, between: 250, and: 750)
        XCTAssertEqual(windowPresence.count, 250,
            "Half-open window captures exactly 50 turns")
        let firstWindowTurn = windowPresence
            .map { $0.observedAtMs }.min()
        let lastWindowTurn = windowPresence
            .map { $0.observedAtMs }.max()
        XCTAssertEqual(firstWindowTurn, 250)
        XCTAssertEqual(lastWindowTurn, 740,
            "endMs=750 excludes turn 75 (ts=750), last in-window is turn 74 (ts=740)")

        // === Invariant 5: replay reconstructs original set ===
        let turn42Records = unknownRows.filter { $0.turnID == "turn-42" }
        let restoredSet = BASRoutedMirrorBladeRecording
            .reconstructUnknownSet(from: turn42Records)
        XCTAssertEqual(restoredSet.missingFacts, ["fact-42"])
        XCTAssertEqual(restoredSet.missingRoles, ["role-42"])
        XCTAssertEqual(restoredSet.ambiguityNotes, ["amb-42"])
        XCTAssertEqual(restoredSet.missingConstraints, [])
        XCTAssertEqual(restoredSet.unresolvedPermissions, [])
    }

    // MARK: - Batch vs per-call write profile

    func testBatchPathHandlesHundredRecordWriteCleanly() async throws {
        let presenceStore = try BASSQLitePresenceObservationStore(
            databaseURL: presenceDB)
        // Build one batch of 100 records spanning all 5 channels
        var records: [BASPresenceObservationRecord] = []
        for i in 0..<100 {
            records.append(BASPresenceObservationRecord(
                eventID: "p-\(i)",
                sessionID: "sess", turnID: "turn",
                channelKind: ["task", "risk", "manipulation",
                              "environment", "bodyRhythm"][i % 5],
                salience: Double(i) / 100.0,
                confidence: 0.8,
                observedAtMs: Int64(i)))
        }
        _ = try await presenceStore.appendBatch(records)
        let count = await presenceStore.count()
        XCTAssertEqual(count, 100)
        let restored = await presenceStore.records(
            forSession: "sess")
        XCTAssertEqual(restored.count, 100)
        XCTAssertEqual(restored.map { $0.eventID },
            (0..<100).map { "p-\($0)" },
            "Batch preserves insertion order under load")
    }
}

#endif  // os(iOS) || os(macOS)
