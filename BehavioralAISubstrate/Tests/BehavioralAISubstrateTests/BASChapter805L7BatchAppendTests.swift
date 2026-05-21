// MARK: - BASChapter805L7BatchAppendTests
// chapter 八百五 / M2676-M2680
//
// Verifies the L7 batch-append extension of the chapter 八百四
// pattern across:
//   - BASInMemoryUnknownLedgerStore        + SQLite sibling
//   - BASInMemoryContradictionLedgerStore  + SQLite sibling
//
// Five invariants pinned (mirror of chapter 八百四 contracts):
//
//   1. Empty input is a no-op on every conformer。
//   2. 100-record batch round-trips through SQLite with all
//      records preserved AND insertion order preserved。
//   3. Duplicate event-ID mid-batch ROLLS BACK the entire
//      transaction — no partial writes leak。
//   4. InMemory store behavior under batch == per-record loop
//      (API symmetry contract)。
//   5. SQLite batch throughput is measurably faster than per-
//      single call (≥3× speedup floor — same threshold as L8)。

import XCTest
@testable import BASSovereign

final class BASChapter805L7BatchAppendTests: XCTestCase {

    private var unknownDB: URL!
    private var contradictionDB: URL!

    override func setUp() async throws {
        try await super.setUp()
        let tmp = FileManager.default.temporaryDirectory
        let token = UUID().uuidString
        unknownDB = tmp.appendingPathComponent(
            "bas-test-l7-batch-u-\(token).sqlite")
        contradictionDB = tmp.appendingPathComponent(
            "bas-test-l7-batch-c-\(token).sqlite")
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

    // MARK: - Empty no-op

    func testUnknownLedgerEmptyBatchNoOp() async throws {
        let inMem = BASInMemoryUnknownLedgerStore()
        let sqlite = try BASSQLiteUnknownLedgerStore(
            databaseURL: unknownDB)
        let memEmpty = try await inMem.appendBatch([])
        let sqlEmpty = try await sqlite.appendBatch([])
        XCTAssertEqual(memEmpty, [])
        XCTAssertEqual(sqlEmpty, [])
        let memCount = await inMem.count()
        let sqlCount = await sqlite.count()
        XCTAssertEqual(memCount, 0)
        XCTAssertEqual(sqlCount, 0)
    }

    func testContradictionLedgerEmptyBatchNoOp() async throws {
        let inMem = BASInMemoryContradictionLedgerStore()
        let sqlite = try BASSQLiteContradictionLedgerStore(
            databaseURL: contradictionDB)
        let memEmpty = try await inMem.appendBatch([])
        let sqlEmpty = try await sqlite.appendBatch([])
        XCTAssertEqual(memEmpty, [])
        XCTAssertEqual(sqlEmpty, [])
        let memCount = await inMem.count()
        let sqlCount = await sqlite.count()
        XCTAssertEqual(memCount, 0)
        XCTAssertEqual(sqlCount, 0)
    }

    // MARK: - Round-trip equivalence

    func testUnknownLedgerSQLiteBatchPreservesAllRecords() async throws {
        let records = (0..<100).map {
            BASUnknownLedgerRecord(
                eventID: "u-\($0)",
                sessionID: "sess",
                turnID: "turn",
                unknownText: "fact \($0)",
                confidence: 0.8,
                discoveredAtMs: Int64($0))
        }
        let store = try BASSQLiteUnknownLedgerStore(
            databaseURL: unknownDB)
        _ = try await store.appendBatch(records)
        let count = await store.count()
        XCTAssertEqual(count, 100)
        let restored = await store.records(forSession: "sess")
        XCTAssertEqual(restored.map { $0.eventID },
            records.map { $0.eventID })
    }

    func testContradictionLedgerSQLiteBatchPreservesNullableResolvedAtMs() async throws {
        // Mix resolved + unresolved records so nullable
        // resolved_at_ms binding gets exercised mid-batch。
        let records = [
            BASContradictionLedgerRecord(
                eventID: "c-1", sessionID: "s", turnID: "t",
                contradictionText: "open",
                salience: 0.4, confidence: 0.5,
                resolved: false, resolvedAtMs: nil),
            BASContradictionLedgerRecord(
                eventID: "c-2", sessionID: "s", turnID: "t",
                contradictionText: "closed",
                salience: 0.9, confidence: 0.95,
                resolved: true, resolvedAtMs: 5_000),
            BASContradictionLedgerRecord(
                eventID: "c-3", sessionID: "s", turnID: "t",
                contradictionText: "open 2",
                salience: 0.5, confidence: 0.5,
                resolved: false, resolvedAtMs: nil),
        ]
        let store = try BASSQLiteContradictionLedgerStore(
            databaseURL: contradictionDB)
        _ = try await store.appendBatch(records)
        let restored = await store.records(forSession: "s")
        XCTAssertEqual(restored.count, 3)
        XCTAssertEqual(restored.map { $0.resolved },
                       [false, true, false])
        XCTAssertEqual(restored.map { $0.resolvedAtMs },
                       [nil, 5_000, nil],
            "Nullable resolved_at_ms binding preserved mid-batch")
    }

    func testInMemoryUnknownBatchMatchesLoop() async throws {
        let records = (0..<25).map {
            BASUnknownLedgerRecord(
                eventID: "u-\($0)", sessionID: "s", turnID: "t",
                unknownText: "x",
                confidence: 0.5, discoveredAtMs: Int64($0))
        }
        let viaBatch = BASInMemoryUnknownLedgerStore()
        _ = try await viaBatch.appendBatch(records)
        let viaLoop = BASInMemoryUnknownLedgerStore()
        for r in records { _ = try await viaLoop.appendRecord(r) }
        let bb = await viaBatch.records(forSession: "s")
        let ll = await viaLoop.records(forSession: "s")
        XCTAssertEqual(bb, ll)
    }

    // MARK: - Atomic rollback

    func testUnknownLedgerSQLiteBatchDuplicateRollsBackAll() async throws {
        let store = try BASSQLiteUnknownLedgerStore(
            databaseURL: unknownDB)
        let preExisting = BASUnknownLedgerRecord(
            eventID: "u-5", sessionID: "s", turnID: "t",
            unknownText: "pre",
            confidence: 0.5, discoveredAtMs: 0)
        _ = try await store.appendRecord(preExisting)
        let liveBefore = await store.count()
        XCTAssertEqual(liveBefore, 1)
        let batch = (0..<10).map {
            BASUnknownLedgerRecord(
                eventID: "u-\($0)", sessionID: "s", turnID: "t",
                unknownText: "batch",
                confidence: 0.5, discoveredAtMs: Int64($0))
        }
        do {
            _ = try await store.appendBatch(batch)
            XCTFail("Expected duplicate-eventID throw")
        } catch BASSQLiteUnknownLedgerStore.StorageError
            .duplicateEventID(let id) {
            XCTAssertEqual(id, "u-5")
        }
        let liveAfter = await store.count()
        XCTAssertEqual(liveAfter, 1,
            "ROLLBACK preserves pre-batch state exactly")
    }

    // MARK: - Informational perf

    func testL7UnknownBatchFasterThanPerCall() async throws {
        let iters = 200
        let perCallStore = try BASSQLiteUnknownLedgerStore(
            databaseURL: unknownDB)
        // Warmup
        _ = try await perCallStore.appendRecord(
            BASUnknownLedgerRecord(
                eventID: "warmup",
                sessionID: "s", turnID: "t",
                unknownText: "w",
                confidence: 0.5, discoveredAtMs: -1))
        let perCallStart = DispatchTime.now().uptimeNanoseconds
        for i in 0..<iters {
            _ = try await perCallStore.appendRecord(
                BASUnknownLedgerRecord(
                    eventID: "u-\(i)",
                    sessionID: "s", turnID: "t",
                    unknownText: "x",
                    confidence: 0.5, discoveredAtMs: Int64(i)))
        }
        let perCallNs = DispatchTime.now().uptimeNanoseconds
            - perCallStart

        try? FileManager.default.removeItem(at: unknownDB)
        let batchStore = try BASSQLiteUnknownLedgerStore(
            databaseURL: unknownDB)
        _ = try await batchStore.appendRecord(
            BASUnknownLedgerRecord(
                eventID: "warmup",
                sessionID: "s", turnID: "t",
                unknownText: "w",
                confidence: 0.5, discoveredAtMs: -1))
        let batch = (0..<iters).map {
            BASUnknownLedgerRecord(
                eventID: "b-\($0)",
                sessionID: "s", turnID: "t",
                unknownText: "x",
                confidence: 0.5, discoveredAtMs: Int64($0))
        }
        let batchStart = DispatchTime.now().uptimeNanoseconds
        _ = try await batchStore.appendBatch(batch)
        let batchNs = DispatchTime.now().uptimeNanoseconds
            - batchStart

        let ratio = Double(perCallNs) / Double(batchNs)
        print(String(format:
            "== L7 UNKNOWN BATCH: %d events,speedup %.1f×",
            iters, ratio))
        XCTAssertGreaterThan(ratio, 3.0,
            "L7 batch must be ≥3× faster than per-single call")
    }
}
