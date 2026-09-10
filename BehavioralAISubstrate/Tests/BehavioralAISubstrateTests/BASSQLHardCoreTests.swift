// MARK: - BASSQLHardCoreTests
// 主线 SQL 硬核 — give SQL real business work:
//   1. Composite covering index (atom_id, retrieved_at_ms DESC)
//   2. EXPLAIN QUERY PLAN surface
//   3. WAL checkpoint primitive
//   4. Bundle table + summary

import XCTest
@testable import BASHostKit
@testable import BASMemory

final class BASSQLHardCoreTests: XCTestCase {

    private func makeTempDBURL() -> URL {
        return URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(
                "bas-sql-hardcore-\(UUID().uuidString).sqlite")
    }

    // MARK: - 1. Composite covering index

    func testCompositeIndexCreated() async throws {
        let url = makeTempDBURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let tracker = try BASMemoryUsageTracker(
            databaseURL: url)
        try await tracker.ensureCoveringIndex()
        // EXPLAIN QUERY PLAN should now reference the
        // new index for the atom + recency hot path
        let plan = try await tracker.explainQueryPlan(
            forSQL: """
                SELECT * FROM memory_usage_records
                WHERE atom_id = 'foo'
                ORDER BY retrieved_at_ms DESC LIMIT 5
                """)
        XCTAssertFalse(plan.isEmpty)
        let usesNewIndex = plan.contains {
            $0.detail.contains("memory_usage_atom_time_idx")
        }
        XCTAssertTrue(usesNewIndex,
            "Composite index should be picked by the" +
            " optimizer for atom+recency lookup。 Got: " +
            "\(plan.map { $0.detail })")
    }

    func testEnsureIndexIdempotent() async throws {
        let url = makeTempDBURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let tracker = try BASMemoryUsageTracker(
            databaseURL: url)
        try await tracker.ensureCoveringIndex()
        // Calling twice should be safe (CREATE INDEX
        // IF NOT EXISTS)
        try await tracker.ensureCoveringIndex()
        try await tracker.ensureCoveringIndex()
    }

    func testEnsureIndexInMemoryNoOp() async throws {
        let tracker = BASMemoryUsageTracker()
        // No DB handle → no-op,doesn't throw
        try await tracker.ensureCoveringIndex()
    }

    // MARK: - 2. EXPLAIN QUERY PLAN surface

    func testExplainEmitsTypedRows() async throws {
        let url = makeTempDBURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let tracker = try BASMemoryUsageTracker(
            databaseURL: url)
        // Simple SELECT
        let plan = try await tracker.explainQueryPlan(
            forSQL: "SELECT * FROM memory_usage_records")
        XCTAssertFalse(plan.isEmpty,
            "EXPLAIN QUERY PLAN returns at least one row")
        // First row's detail mentions the table
        let firstDetail = plan[0].detail
        XCTAssertTrue(
            firstDetail.contains("memory_usage_records"),
            "Detail must reference the table being" +
            " scanned: \(firstDetail)")
    }

    func testExplainDetectsTableScan() async throws {
        let url = makeTempDBURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let tracker = try BASMemoryUsageTracker(
            databaseURL: url)
        // Query with no WHERE → full scan
        let plan = try await tracker.explainQueryPlan(
            forSQL: "SELECT * FROM memory_usage_records")
        let anyScan = plan.contains { $0.doesTableScan }
        XCTAssertTrue(anyScan,
            "SELECT * without WHERE → at least one SCAN" +
            " step。 Got: \(plan.map { $0.detail })")
    }

    func testExplainDetectsIndexUse() async throws {
        let url = makeTempDBURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let tracker = try BASMemoryUsageTracker(
            databaseURL: url)
        // Query that hits the existing atom_id index
        let plan = try await tracker.explainQueryPlan(
            forSQL: """
                SELECT * FROM memory_usage_records
                WHERE atom_id = 'x'
                """)
        let anyIndex = plan.contains { $0.usesIndex }
        XCTAssertTrue(anyIndex,
            "WHERE atom_id = ? → optimizer should USE" +
            " INDEX。 Got: \(plan.map { $0.detail })")
    }

    func testExplainInMemoryReturnsEmpty() async throws {
        let tracker = BASMemoryUsageTracker()
        let plan = try await tracker.explainQueryPlan(
            forSQL: "SELECT 1")
        XCTAssertTrue(plan.isEmpty)
    }

    func testExplainQueryPlanRowCodable() throws {
        let row = BASMemoryUsageTracker
            .ExplainQueryPlanRow(
                id: 2, parent: 0,
                detail: "SEARCH memory_usage_records" +
                    " USING INDEX foo (atom_id=?)")
        let data = try JSONEncoder().encode(row)
        let decoded = try JSONDecoder().decode(
            BASMemoryUsageTracker.ExplainQueryPlanRow.self,
            from: data)
        XCTAssertEqual(decoded, row)
        XCTAssertTrue(decoded.usesIndex)
        XCTAssertFalse(decoded.doesTableScan)
    }

    // MARK: - 3. WAL checkpoint

    func testCheckpointSQLiteBacked() async throws {
        let url = makeTempDBURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let tracker = try BASMemoryUsageTracker(
            databaseURL: url)
        // Generate some WAL pages by writing records
        for i in 0..<10 {
            _ = try await tracker.record(
                atomID: "atom-\(i)", sessionRef: "S",
                turnRef: String(i), permitMode: "safe")
        }
        let result = try await tracker.checkpointWAL()
        // busy must be 0 (no other readers in test)
        XCTAssertEqual(result.busy, 0)
        // logPages and checkpointed are non-negative
        XCTAssertGreaterThanOrEqual(result.logPages, 0)
        XCTAssertGreaterThanOrEqual(
            result.checkpointed, 0)
    }

    func testCheckpointInMemoryReturnsZero() async throws {
        let tracker = BASMemoryUsageTracker()
        let result = try await tracker.checkpointWAL()
        XCTAssertEqual(result.busy, 0)
        XCTAssertEqual(result.logPages, 0)
        XCTAssertEqual(result.checkpointed, 0)
    }

    func testCheckpointResultCodable() throws {
        let r = BASWALCheckpointResult(
            busy: 0, logPages: 10, checkpointed: 10)
        let data = try JSONEncoder().encode(r)
        let decoded = try JSONDecoder().decode(
            BASWALCheckpointResult.self, from: data)
        XCTAssertEqual(decoded, r)
        XCTAssertTrue(decoded.isFullyFlushed)
    }

    func testCheckpointPartialFlushNotFullyFlushed() {
        let partial = BASWALCheckpointResult(
            busy: 0, logPages: 10, checkpointed: 7)
        XCTAssertFalse(partial.isFullyFlushed)
    }

    // MARK: - 4. Bundle

    func testCreateBundleAndSummary() async throws {
        let tracker = BASMemoryUsageTracker()
        // Create 3 records,bundle them
        var recordIDs: [String] = []
        for i in 0..<3 {
            let id = try await tracker.record(
                atomID: "a\(i)", sessionRef: "S",
                turnRef: String(i), permitMode: "safe")
            recordIDs.append(id)
        }
        let bid = try await tracker.createBundle(
            recordIDs: recordIDs)
        XCTAssertEqual(bid.count, 36,
            "UUID-style bundle ID is 36 chars")
        let summaries = try await tracker
            .bundleSummariesViaSQL()
        XCTAssertEqual(summaries.count, 1)
        XCTAssertEqual(summaries[0].bundleID, bid)
        XCTAssertEqual(summaries[0].recordCount, 3)
    }

    func testCreateBundleSQLiteBacked() async throws {
        let url = makeTempDBURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let tracker = try BASMemoryUsageTracker(
            databaseURL: url)
        var recordIDs: [String] = []
        for i in 0..<5 {
            let id = try await tracker.record(
                atomID: "a\(i)", sessionRef: "S",
                turnRef: String(i), permitMode: "safe")
            recordIDs.append(id)
        }
        let bid = try await tracker.createBundle(
            recordIDs: recordIDs,
            bundleID: "custom-bundle-id")
        XCTAssertEqual(bid, "custom-bundle-id")
        let summaries = try await tracker
            .bundleSummariesViaSQL()
        XCTAssertEqual(summaries.count, 1)
        XCTAssertEqual(summaries[0].bundleID,
            "custom-bundle-id")
        XCTAssertEqual(summaries[0].recordCount, 5)
    }

    func testMultipleBundlesSortedByCreatedAt()
        async throws
    {
        let tracker = BASMemoryUsageTracker()
        let r1 = try await tracker.record(
            atomID: "a", sessionRef: "S",
            turnRef: "0", permitMode: "safe")
        let bidOld = try await tracker.createBundle(
            recordIDs: [r1],
            createdAt: Date(
                timeIntervalSince1970: 1_700_000_000))
        let bidNew = try await tracker.createBundle(
            recordIDs: [r1],
            createdAt: Date(
                timeIntervalSince1970: 1_700_000_100))
        let summaries = try await tracker
            .bundleSummariesViaSQL()
        XCTAssertEqual(summaries.count, 2)
        XCTAssertEqual(summaries[0].bundleID, bidOld,
            "Older bundle sorts first")
        XCTAssertEqual(summaries[1].bundleID, bidNew)
    }

    func testBundleSummaryCodable() throws {
        let summary = BASBundleSummary(
            bundleID: "bundle-x",
            recordCount: 7,
            createdAtMs: 1_700_000_000_000)
        let data = try JSONEncoder().encode(summary)
        let decoded = try JSONDecoder().decode(
            BASBundleSummary.self, from: data)
        XCTAssertEqual(decoded, summary)
    }

    // MARK: - Integration: composite index measurably faster
    // (characterization, not a strict performance assertion
    //  since hardware varies)

    func testCompositeIndexImprovesAtomPlan() async throws {
        let url = makeTempDBURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let tracker = try BASMemoryUsageTracker(
            databaseURL: url)
        // Insert 100 records spread across 10 atoms
        let t0 = Date(timeIntervalSince1970: 1_700_000_000)
        for i in 0..<100 {
            _ = try await tracker.record(
                atomID: "atom-\(i % 10)",
                sessionRef: "S",
                turnRef: String(i), permitMode: "safe",
                retrievedAt: t0.addingTimeInterval(
                    Double(i) * 0.01))
        }
        try await tracker.ensureCoveringIndex()
        let plan = try await tracker.explainQueryPlan(
            forSQL: """
                SELECT * FROM memory_usage_records
                WHERE atom_id = 'atom-3'
                ORDER BY retrieved_at_ms DESC
                LIMIT 5
                """)
        // Plan should reference the composite index AND
        // should NOT need a TEMP B-TREE for ORDER BY
        // (covering index means rows come pre-sorted)
        let usesComposite = plan.contains {
            $0.detail.contains(
                "memory_usage_atom_time_idx")
        }
        let needsTempSort = plan.contains {
            $0.detail.contains("USE TEMP B-TREE")
        }
        XCTAssertTrue(usesComposite,
            "Composite index picked: \(plan.map { $0.detail })")
        XCTAssertFalse(needsTempSort,
            "Composite index covers ORDER BY → no TEMP" +
            " B-TREE needed。 Got: \(plan.map { $0.detail })")
    }
}
