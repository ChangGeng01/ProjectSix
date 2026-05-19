// MARK: - BASChapter723RecordBatchMultiRowInsertTests
// chapter 七百二十三 第四刀 / M2289
//
// Byte-equality + perf measurement for the multi-row INSERT
// optimization in `BASMemoryUsageTracker.recordBatch`。
//
// Per chapter 七百十六 byte-equality discipline:both paths
// (legacy `insertBatchInTransaction` vs new
// `insertBatchMultiRow`) must produce IDENTICAL row state in
// the database (same recordIDs minted,same row values,same
// fetchAllRecords output)。 Flip default ONLY if measurement
// shows ≥ 1.5× speedup。

import XCTest
import Foundation
@testable import BASRuntimeCore
@testable import BASMemory

final class BASChapter723RecordBatchMultiRowInsertTests:
    XCTestCase
{

    // MARK: - Fixture

    private func makeEntries(count: Int) ->
        [BASMemoryUsageTracker.BatchEntry]
    {
        var entries: [BASMemoryUsageTracker.BatchEntry] = []
        entries.reserveCapacity(count)
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        for i in 0..<count {
            entries.append(
                BASMemoryUsageTracker.BatchEntry(
                    atomID: "atom_\(i % 100)",
                    sessionRef: "session_\(i % 10)",
                    turnRef: "turn_\(i)",
                    permitMode: i % 2 == 0
                        ? "immediate" : "deferred",
                    retrievedAt: base.addingTimeInterval(
                        Double(i))))
        }
        return entries
    }

    private func makeTrackerOnDisk(label: String) async throws ->
        BASMemoryUsageTracker
    {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "bas_chapter723_\(label)_"
                + UUID().uuidString
                + ".sqlite")
        return try await BASMemoryUsageTracker(
            databaseURL: tmp)
    }

    // MARK: - Byte-equality

    func testLegacyAndMultiRowProduceIdenticalRows() async throws {
        // Same batch routed through both paths → same fetched
        // state (modulo recordIDs which are UUIDs)。 Compare
        // row-level fields excluding recordID。
        let entries = makeEntries(count: 250)

        BASMemoryUsageTracker.useMultiRowInsertBatch = false
        let trackerLegacy = try await makeTrackerOnDisk(
            label: "legacy")
        _ = try await trackerLegacy.recordBatch(entries)
        let legacyRecords = await trackerLegacy.allRecords()

        BASMemoryUsageTracker.useMultiRowInsertBatch = true
        let trackerMulti = try await makeTrackerOnDisk(
            label: "multi")
        _ = try await trackerMulti.recordBatch(entries)
        let multiRecords = await trackerMulti.allRecords()

        // Reset flag for other tests in the same process
        BASMemoryUsageTracker.useMultiRowInsertBatch = false

        XCTAssertEqual(legacyRecords.count, multiRecords.count)
        XCTAssertEqual(legacyRecords.count, entries.count)

        // Compare field-by-field (excluding recordID — UUIDs differ)
        // Both paths sort allRecords() by retrievedAt ASC,so the
        // ordering should match。
        for i in 0..<legacyRecords.count {
            let l = legacyRecords[i]
            let m = multiRecords[i]
            XCTAssertEqual(l.atomID, m.atomID,
                "atomID @ \(i)")
            XCTAssertEqual(l.retrievedAt, m.retrievedAt,
                "retrievedAt @ \(i)")
            XCTAssertEqual(l.sessionRef, m.sessionRef,
                "sessionRef @ \(i)")
            XCTAssertEqual(l.turnRef, m.turnRef,
                "turnRef @ \(i)")
            XCTAssertEqual(l.permitMode, m.permitMode,
                "permitMode @ \(i)")
            XCTAssertEqual(l.helpedFlag, m.helpedFlag,
                "helpedFlag @ \(i)")
        }
    }

    func testEmptyBatchHandledIdenticallyByBothPaths()
        async throws
    {
        BASMemoryUsageTracker.useMultiRowInsertBatch = false
        let trackerLegacy = try await makeTrackerOnDisk(
            label: "empty_legacy")
        let legacyIDs = try await trackerLegacy.recordBatch([])
        XCTAssertEqual(legacyIDs, [])

        BASMemoryUsageTracker.useMultiRowInsertBatch = true
        let trackerMulti = try await makeTrackerOnDisk(
            label: "empty_multi")
        let multiIDs = try await trackerMulti.recordBatch([])
        XCTAssertEqual(multiIDs, [])

        BASMemoryUsageTracker.useMultiRowInsertBatch = false
    }

    func testChunkBoundarySplitsCorrectly() async throws {
        // 250 rows spans 2.5 chunks (chunk size = 100)。
        // Verifies the chunking loop doesn't drop or duplicate
        // rows at the boundary。
        let entries = makeEntries(count: 250)

        BASMemoryUsageTracker.useMultiRowInsertBatch = true
        let tracker = try await makeTrackerOnDisk(
            label: "chunk")
        let ids = try await tracker.recordBatch(entries)
        XCTAssertEqual(ids.count, 250)
        let records = await tracker.allRecords()
        XCTAssertEqual(records.count, 250)
        // Verify distinct recordIDs (no collisions across chunks)
        let uniqueIDs = Set(ids)
        XCTAssertEqual(uniqueIDs.count, 250)

        BASMemoryUsageTracker.useMultiRowInsertBatch = false
    }

    // MARK: - Perf

    func testPerfMultiRowVsLegacy() async throws {
        // Plan-agent expected speedup 4-8×。 Gate on ≥ 1.5× to
        // flip default per measurement-first discipline。
        let entries = makeEntries(count: 500)
        let iterations = 30

        // Warm both paths
        BASMemoryUsageTracker.useMultiRowInsertBatch = false
        let warmLegacy = try await makeTrackerOnDisk(
            label: "warm_legacy")
        _ = try await warmLegacy.recordBatch(entries)
        BASMemoryUsageTracker.useMultiRowInsertBatch = true
        let warmMulti = try await makeTrackerOnDisk(
            label: "warm_multi")
        _ = try await warmMulti.recordBatch(entries)

        // Time legacy
        BASMemoryUsageTracker.useMultiRowInsertBatch = false
        var legacyTotal: Double = 0
        for _ in 0..<iterations {
            let tracker = try await makeTrackerOnDisk(
                label: "perf_legacy")
            let t0 = CFAbsoluteTimeGetCurrent()
            _ = try await tracker.recordBatch(entries)
            legacyTotal +=
                CFAbsoluteTimeGetCurrent() - t0
        }

        // Time multi-row
        BASMemoryUsageTracker.useMultiRowInsertBatch = true
        var multiTotal: Double = 0
        for _ in 0..<iterations {
            let tracker = try await makeTrackerOnDisk(
                label: "perf_multi")
            let t0 = CFAbsoluteTimeGetCurrent()
            _ = try await tracker.recordBatch(entries)
            multiTotal +=
                CFAbsoluteTimeGetCurrent() - t0
        }
        BASMemoryUsageTracker.useMultiRowInsertBatch = false

        let legacyMsPerBatch =
            legacyTotal / Double(iterations) * 1000
        let multiMsPerBatch =
            multiTotal / Double(iterations) * 1000
        let speedup = legacyTotal / multiTotal

        print("")
        print(
            "## chapter 七百二十三 第四刀 — recordBatch multi-row INSERT perf")
        print("")
        print(String(
            format: "  legacy (per-row prepared):  %.3f ms/batch",
            legacyMsPerBatch))
        print(String(
            format: "  multi-row INSERT:           %.3f ms/batch",
            multiMsPerBatch))
        print(String(
            format: "  speedup:                    %.2f×",
            speedup))
        print(String(
            format: "  decision threshold:         1.5× (flip default if exceeded)"))
        print("")

        // No XCTAssert on speedup — measurement-first means we
        // SHIP the perf number,then the close-out decides the
        // default flip。 Knife 5 will set
        // useMultiRowInsertBatch = (speedup ≥ 1.5)。
    }
}
