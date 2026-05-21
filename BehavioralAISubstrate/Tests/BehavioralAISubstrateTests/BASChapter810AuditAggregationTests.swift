// MARK: - BASChapter810AuditAggregationTests
// chapter 八百十 / M2701-M2705
//
// Verifies the per-session audit aggregation helpers (chapter
// 八百十)。 Pure-fn analyzers that close the consumer side of
// the recording loop。
//
// Six invariants pinned:
//
//   1. L6 aggregatePresence empty input returns a zero summary。
//   2. L6 aggregatePresence multi-turn input computes correct
//      total / turnCount / avg salience+confidence。
//   3. L6 aggregatePresence per-channel count is keyed by the
//      raw channelKind string,never bucketizes unknown channels。
//   4. L7 aggregateUnknowns bucketizes by prefix kind,counts
//      unparseable rows separately。
//   5. L7 aggregateContradictions computes resolved/unresolved
//      split + max + avg salience across the session。
//   6. End-to-end through SQLite store + replay + aggregate
//      preserves correctness against the original recorded input。

import XCTest
@testable import BASOrchestration
@testable import BASSovereign

final class BASChapter810AuditAggregationTests: XCTestCase {

    // MARK: - L6 presence

    func testAggregatePresenceEmptyReturnsZeros() {
        let summary = BASRoutedAuditAggregation.aggregatePresence(
            records: [], sessionID: "s")
        XCTAssertEqual(summary.totalObservations, 0)
        XCTAssertEqual(summary.turnCount, 0)
        XCTAssertEqual(summary.avgSalience, 0)
        XCTAssertEqual(summary.avgConfidence, 0)
        XCTAssertTrue(summary.observationCountByChannel.isEmpty)
    }

    func testAggregatePresenceMultiTurnComputesAverages() {
        let records = [
            makePresenceRecord(
                turn: "t1", channelKind: "task",
                salience: 0.6, confidence: 0.8),
            makePresenceRecord(
                turn: "t1", channelKind: "risk",
                salience: 0.4, confidence: 0.6),
            makePresenceRecord(
                turn: "t2", channelKind: "task",
                salience: 0.8, confidence: 1.0),
        ]
        let summary = BASRoutedAuditAggregation.aggregatePresence(
            records: records, sessionID: "s")
        XCTAssertEqual(summary.totalObservations, 3)
        XCTAssertEqual(summary.turnCount, 2,
            "Two distinct turnIDs in input")
        XCTAssertEqual(summary.avgSalience,
                       (0.6 + 0.4 + 0.8) / 3.0,
                       accuracy: 1e-12)
        XCTAssertEqual(summary.avgConfidence,
                       (0.8 + 0.6 + 1.0) / 3.0,
                       accuracy: 1e-12)
        XCTAssertEqual(summary.observationCountByChannel["task"], 2)
        XCTAssertEqual(summary.observationCountByChannel["risk"], 1)
        XCTAssertNil(
            summary.observationCountByChannel["manipulation"],
            "Channels with zero rows are omitted from the dict")
    }

    func testAggregatePresenceUnknownChannelKindStillCounted() {
        // Defensive: if a row sneaks through with a non-CHECK
        // string,it still gets counted under its raw kind so the
        // operator can spot the anomaly。
        let records = [
            makePresenceRecord(
                turn: "t", channelKind: "bogus",
                salience: 0.5, confidence: 0.5),
        ]
        let summary = BASRoutedAuditAggregation.aggregatePresence(
            records: records, sessionID: "s")
        XCTAssertEqual(
            summary.observationCountByChannel["bogus"], 1,
            "Anomalous channelKind still counted under its raw name")
    }

    // MARK: - L7 unknown

    func testAggregateUnknownsBucketsByPrefixKind() {
        let records = [
            makeUnknownRecord(turn: "t1", text: "fact: F1"),
            makeUnknownRecord(turn: "t1", text: "fact: F2"),
            makeUnknownRecord(turn: "t2", text: "role: R1"),
            makeUnknownRecord(turn: "t2", text: "constraint: C1"),
            makeUnknownRecord(turn: "t2", text: "permission: P1"),
            makeUnknownRecord(turn: "t2", text: "ambiguity: A1"),
        ]
        let summary = BASRoutedAuditAggregation.aggregateUnknowns(
            records: records, sessionID: "s")
        XCTAssertEqual(summary.totalRecords, 6)
        XCTAssertEqual(summary.turnCount, 2)
        XCTAssertEqual(summary.factCount, 2)
        XCTAssertEqual(summary.roleCount, 1)
        XCTAssertEqual(summary.constraintCount, 1)
        XCTAssertEqual(summary.permissionCount, 1)
        XCTAssertEqual(summary.ambiguityCount, 1)
        XCTAssertEqual(summary.unparseableCount, 0)
    }

    func testAggregateUnknownsCountsUnparseableSeparately() {
        let records = [
            makeUnknownRecord(turn: "t", text: "fact: F1"),
            makeUnknownRecord(turn: "t", text: "no-prefix"),
            makeUnknownRecord(turn: "t", text: "unknown: X"),
        ]
        let summary = BASRoutedAuditAggregation.aggregateUnknowns(
            records: records, sessionID: "s")
        XCTAssertEqual(summary.factCount, 1)
        XCTAssertEqual(summary.unparseableCount, 2,
            "Rows without valid prefix go to unparseable bucket")
    }

    // MARK: - L7 contradictions

    func testAggregateContradictionsEmptyReturnsZeros() {
        let summary = BASRoutedAuditAggregation
            .aggregateContradictions(records: [], sessionID: "s")
        XCTAssertEqual(summary.totalRecords, 0)
        XCTAssertEqual(summary.resolvedCount, 0)
        XCTAssertEqual(summary.unresolvedCount, 0)
        XCTAssertEqual(summary.maxSalience, 0)
        XCTAssertEqual(summary.avgSalience, 0)
    }

    func testAggregateContradictionsSplitsResolvedAndComputesStats() {
        let records = [
            makeContradictionRecord(
                text: "textual: A vs B",
                salience: 0.4, resolved: false),
            makeContradictionRecord(
                text: "textual: C vs D",
                salience: 0.9, resolved: true),
            makeContradictionRecord(
                text: "role: ambig",
                salience: 0.2, resolved: true),
        ]
        let summary = BASRoutedAuditAggregation
            .aggregateContradictions(records: records, sessionID: "s")
        XCTAssertEqual(summary.totalRecords, 3)
        XCTAssertEqual(summary.resolvedCount, 2)
        XCTAssertEqual(summary.unresolvedCount, 1)
        XCTAssertEqual(summary.maxSalience, 0.9, accuracy: 1e-12)
        XCTAssertEqual(summary.avgSalience,
                       (0.4 + 0.9 + 0.2) / 3.0,
                       accuracy: 1e-12)
    }

    // MARK: - End-to-end through store

    func testAggregationThroughSQLiteRoundTrip() async throws {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "bas-test-agg-\(UUID().uuidString).sqlite")
        defer {
            try? FileManager.default.removeItem(at: tempURL)
        }
        let store = try BASSQLiteUnknownLedgerStore(
            databaseURL: tempURL)
        let originalSet = BASUnknownSet(
            missingFacts: ["F1", "F2", "F3"],
            missingRoles: ["R1"],
            ambiguityNotes: ["A1", "A2"])
        _ = try await BASRoutedMirrorBladeRecording.recordUnknownSet(
            originalSet,
            sessionID: "s-e2e",
            turnID: "t-e2e",
            store: store,
            eventIDPrefix: "u",
            nowMs: 0)

        let stored = await store.records(forSession: "s-e2e")
        let summary = BASRoutedAuditAggregation.aggregateUnknowns(
            records: stored, sessionID: "s-e2e")
        XCTAssertEqual(summary.totalRecords, 6)
        XCTAssertEqual(summary.turnCount, 1)
        XCTAssertEqual(summary.factCount, 3,
            "End-to-end SQLite round trip preserves fact count")
        XCTAssertEqual(summary.roleCount, 1)
        XCTAssertEqual(summary.ambiguityCount, 2)
        XCTAssertEqual(summary.unparseableCount, 0)
    }

    // MARK: - Helpers

    private func makePresenceRecord(
        turn: String,
        channelKind: String,
        salience: Double,
        confidence: Double
    ) -> BASPresenceObservationRecord {
        return BASPresenceObservationRecord(
            eventID: UUID().uuidString,
            sessionID: "s",
            turnID: turn,
            channelKind: channelKind,
            salience: salience,
            confidence: confidence,
            observedAtMs: 0)
    }

    private func makeUnknownRecord(
        turn: String,
        text: String
    ) -> BASUnknownLedgerRecord {
        return BASUnknownLedgerRecord(
            eventID: UUID().uuidString,
            sessionID: "s",
            turnID: turn,
            unknownText: text,
            confidence: 1.0,
            discoveredAtMs: 0)
    }

    private func makeContradictionRecord(
        text: String,
        salience: Double,
        resolved: Bool
    ) -> BASContradictionLedgerRecord {
        return BASContradictionLedgerRecord(
            eventID: UUID().uuidString,
            sessionID: "s",
            turnID: "t",
            contradictionText: text,
            salience: salience,
            confidence: 1.0,
            resolved: resolved,
            resolvedAtMs: resolved ? 1 : nil)
    }
}
