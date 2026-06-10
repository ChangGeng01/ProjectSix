// MARK: - BASSQLNativeQueryTests
// 主线 全面 提升: SQL pilot now exposes native query paths
// that push ORDER BY + LIMIT + GROUP BY into the SQLite
// storage engine。 Mirrors the Rust pilot's aggregation
// surface so dashboards can switch between SQL and Rust
// history backends without rewriting consumer code。

import XCTest
@testable import BASHostKit
@testable import BASMemory

#if !os(iOS)  // ch 1022 source-gate
final class BASSQLNativeQueryTests: XCTestCase {

    // Helper: temp file URL for SQLite-backed tracker
    private func makeTempDBURL() -> URL {
        return URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(
                "bas-sql-native-\(UUID().uuidString).sqlite")
    }

    private func makeSummary(
        input: String
    ) -> BASCognitiveBrainSummary {
        return BASCognitiveBrainSummary(
            input: input,
            taskType: .chat,
            confidence: 0.9,
            ambiguityScore: 0.1,
            safetyVerdict: .safe,
            manipulationHints: [],
            latencyNanos: 1)
    }

    // MARK: - isSQLBacked

    func testIsSQLBackedFalseForInMemoryTracker()
        async throws
    {
        let tracker = BASMemoryUsageTracker()
        let store = BASSQLBrainHistoryStore(tracker: tracker)
        let backed = await store.isSQLBacked
        XCTAssertFalse(backed,
            "In-memory tracker (databaseURL: nil) → not" +
            " SQL-backed")
    }

    func testIsSQLBackedTrueForSQLiteTracker() async throws {
        let url = makeTempDBURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let tracker = try BASMemoryUsageTracker(
            databaseURL: url)
        let store = BASSQLBrainHistoryStore(tracker: tracker)
        let backed = await store.isSQLBacked
        XCTAssertTrue(backed,
            "SQLite-backed tracker → isSQLBacked true")
    }

    // MARK: - recentRecordsViaSQL — ORDER BY DESC + LIMIT

    func testRecentRecordsViaSQLOrdersDescendingByTime()
        async throws
    {
        let url = makeTempDBURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let tracker = try BASMemoryUsageTracker(
            databaseURL: url)
        let store = BASSQLBrainHistoryStore(tracker: tracker)
        // Insert 3 records with explicit timestamps spaced
        // 100ms apart so ordering is unambiguous。
        let t0 = Date(timeIntervalSince1970: 1_700_000_000)
        let t1 = t0.addingTimeInterval(0.1)
        let t2 = t0.addingTimeInterval(0.2)
        _ = try await tracker.record(
            atomID: "a0", sessionRef: "S",
            turnRef: "0", permitMode: "safe",
            retrievedAt: t0)
        _ = try await tracker.record(
            atomID: "a1", sessionRef: "S",
            turnRef: "1", permitMode: "safe",
            retrievedAt: t1)
        _ = try await tracker.record(
            atomID: "a2", sessionRef: "S",
            turnRef: "2", permitMode: "safe",
            retrievedAt: t2)
        let records = try await store.recentRecordsViaSQL(
            limit: 10)
        XCTAssertEqual(records.count, 3)
        XCTAssertEqual(records[0].atomID, "a2",
            "newest first via ORDER BY DESC")
        XCTAssertEqual(records[1].atomID, "a1")
        XCTAssertEqual(records[2].atomID, "a0",
            "oldest last")
    }

    /// M2440 第六刀 — the native ORDER BY breaks a `retrieved_at_ms`
    /// TIE deterministically by `CAST(turn_ref AS INTEGER)` (NOT a
    /// lexical text sort)。 `retrieved_at_ms` is millisecond-
    /// resolution,so two records in the same ms tie; without the
    /// numeric tiebreaker the "most recent" row is ambiguous and the
    /// SQL-native path could disagree with the Swift-fold / Rust
    /// paths — the cross-store atomID-parity flake class。
    func testRecentRecordsViaSQLTiebreaksNumericallyByTurnRefOnTimestampTie()
        async throws
    {
        let url = makeTempDBURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let tracker = try BASMemoryUsageTracker(
            databaseURL: url)
        let store = BASSQLBrainHistoryStore(tracker: tracker)
        // SAME timestamp for both → forces the ms-tie。 turn_ref "2"
        // vs "10": LEXICALLY "10" < "2",NUMERICALLY 10 > 2 — so the
        // result proves CAST(turn_ref AS INTEGER),not a text sort。
        let ts = Date(timeIntervalSince1970: 1_700_000_000)
        _ = try await tracker.record(
            atomID: "turn2", sessionRef: "S",
            turnRef: "2", permitMode: "safe", retrievedAt: ts)
        _ = try await tracker.record(
            atomID: "turn10", sessionRef: "S",
            turnRef: "10", permitMode: "safe", retrievedAt: ts)
        let top = try await store.recentRecordsViaSQL(limit: 1)
        XCTAssertEqual(top.first?.atomID, "turn10",
            "on a retrieved_at_ms tie, turn_ref 10 > 2 NUMERICALLY" +
            " (CAST AS INTEGER) — the deterministic most-recent")
        // Full order: 10 then 2 (numeric DESC on the tie)。
        let both = try await store.recentRecordsViaSQL(limit: 10)
        XCTAssertEqual(both.map(\.atomID), ["turn10", "turn2"])
    }

    /// AUDIT-4 — CROSS-PATH parity on MALFORMED turn_refs. SQLite `CAST('12abc' AS INTEGER)` = 12 (leading
    /// digits) while Swift `Int("12abc")` = nil → the old fold mapped it to 0 — so the Swift fold and the SQL
    /// native query could order the SAME tied records DIFFERENTLY (the exact divergence the tiebreaker exists to
    /// kill). `BASTurnRefOrdering.numericValue` now mirrors CAST; this test pins BOTH paths returning the SAME
    /// order on the same tied, malformed dataset.
    func testFoldAndNativePathsAgreeOnMalformedTurnRefTies() async throws {
        let url = makeTempDBURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let tracker = try BASMemoryUsageTracker(
            databaseURL: url)
        let store = BASSQLBrainHistoryStore(tracker: tracker)
        let ts = Date(timeIntervalSince1970: 1_700_000_000)   // one timestamp — every record ties
        // turn_refs: '12abc' (CAST→12, old-Swift→0), '9' (both→9), 'abc' (both→0).
        _ = try await tracker.record(
            atomID: "malformed12", sessionRef: "S",
            turnRef: "12abc", permitMode: "safe", retrievedAt: ts)
        _ = try await tracker.record(
            atomID: "clean9", sessionRef: "S",
            turnRef: "9", permitMode: "safe", retrievedAt: ts)
        _ = try await tracker.record(
            atomID: "junk", sessionRef: "S",
            turnRef: "abc", permitMode: "safe", retrievedAt: ts)

        let fold = await store.recentRecords(limit: 3).map(\.atomID)
        let native = try await store.recentRecordsViaSQL(limit: 3).map(\.atomID)
        XCTAssertEqual(fold, native,
            "the Swift fold and the SQL-native path must order the SAME tied records IDENTICALLY, "
            + "including malformed turn_refs (CAST-compatible leading-digit parsing)")
        XCTAssertEqual(fold.first, "malformed12",
            "leading-digit semantics: '12abc' (12) outranks '9' on the tie — in BOTH paths")
    }

    func testRecentRecordsViaSQLHonorsLimit() async throws {
        let url = makeTempDBURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let tracker = try BASMemoryUsageTracker(
            databaseURL: url)
        let store = BASSQLBrainHistoryStore(tracker: tracker)
        for i in 0..<10 {
            _ = try await tracker.record(
                atomID: "a\(i)", sessionRef: "S",
                turnRef: String(i), permitMode: "safe",
                retrievedAt: Date(
                    timeIntervalSince1970:
                        1_700_000_000 + Double(i) * 0.1))
        }
        let records = try await store.recentRecordsViaSQL(
            limit: 3)
        XCTAssertEqual(records.count, 3,
            "LIMIT 3 → exactly 3 rows returned by SQLite")
        XCTAssertEqual(records[0].atomID, "a9",
            "Most recent first")
    }

    func testRecentRecordsViaSQLLimitZeroReturnsEmpty()
        async throws
    {
        let url = makeTempDBURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let tracker = try BASMemoryUsageTracker(
            databaseURL: url)
        let store = BASSQLBrainHistoryStore(tracker: tracker)
        _ = try await tracker.record(
            atomID: "a0", sessionRef: "S",
            turnRef: "0", permitMode: "safe")
        let records = try await store.recentRecordsViaSQL(
            limit: 0)
        XCTAssertEqual(records.count, 0,
            "LIMIT 0 → empty result set")
    }

    func testRecentRecordsViaSQLNegativeLimitClampsToZero()
        async throws
    {
        let url = makeTempDBURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let tracker = try BASMemoryUsageTracker(
            databaseURL: url)
        let store = BASSQLBrainHistoryStore(tracker: tracker)
        _ = try await tracker.record(
            atomID: "a0", sessionRef: "S",
            turnRef: "0", permitMode: "safe")
        let records = try await store.recentRecordsViaSQL(
            limit: -5)
        XCTAssertEqual(records.count, 0,
            "Negative limit is clamped to 0 (no underflow)")
    }

    // MARK: - In-memory mode fallback

    func testRecentRecordsViaSQLInMemoryUsesFallback()
        async throws
    {
        let tracker = BASMemoryUsageTracker()  // in-memory
        let store = BASSQLBrainHistoryStore(tracker: tracker)
        let t0 = Date(timeIntervalSince1970: 1_700_000_000)
        let t1 = t0.addingTimeInterval(0.1)
        _ = try await tracker.record(
            atomID: "a0", sessionRef: "S",
            turnRef: "0", permitMode: "safe",
            retrievedAt: t0)
        _ = try await tracker.record(
            atomID: "a1", sessionRef: "S",
            turnRef: "1", permitMode: "safe",
            retrievedAt: t1)
        let records = try await store.recentRecordsViaSQL(
            limit: 10)
        XCTAssertEqual(records.count, 2,
            "Falls back to Swift fold when db == nil")
        XCTAssertEqual(records[0].atomID, "a1",
            "In-memory fallback still returns newest-first")
    }

    // MARK: - Parity: SQL path vs Swift fold

    func testRecentRecordsViaSQLParityWithSwiftFold()
        async throws
    {
        // Same data, two tracker modes (one SQLite-backed,
        // one in-memory)。 Both must return the same logical
        // result。 This pins the contract that the SQL path
        // is an acceleration, not a semantic change。
        let url = makeTempDBURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let sqlTracker = try BASMemoryUsageTracker(
            databaseURL: url)
        let memTracker = BASMemoryUsageTracker()

        let modes = ["safe", "warn", "block", "safe", "safe"]
        for (i, mode) in modes.enumerated() {
            let t = Date(timeIntervalSince1970:
                1_700_000_000 + Double(i) * 0.1)
            _ = try await sqlTracker.record(
                atomID: "a\(i)", sessionRef: "S",
                turnRef: String(i), permitMode: mode,
                retrievedAt: t)
            _ = try await memTracker.record(
                atomID: "a\(i)", sessionRef: "S",
                turnRef: String(i), permitMode: mode,
                retrievedAt: t)
        }
        let sqlRecords = try await sqlTracker
            .recentRecordsViaSQL(limit: 3)
        let memRecords = try await memTracker
            .recentRecordsViaSQL(limit: 3)
        XCTAssertEqual(
            sqlRecords.map { $0.atomID },
            memRecords.map { $0.atomID },
            "SQL path and Swift fold must produce identical" +
            " ordered atomID sequences")
    }

    // MARK: - permitModeDistribution

    func testPermitModeDistributionViaSQL() async throws {
        let url = makeTempDBURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let tracker = try BASMemoryUsageTracker(
            databaseURL: url)
        let store = BASSQLBrainHistoryStore(tracker: tracker)
        _ = try await tracker.record(
            atomID: "a", sessionRef: "S",
            turnRef: "0", permitMode: "safe")
        _ = try await tracker.record(
            atomID: "b", sessionRef: "S",
            turnRef: "1", permitMode: "safe")
        _ = try await tracker.record(
            atomID: "c", sessionRef: "S",
            turnRef: "2", permitMode: "warn")
        _ = try await tracker.record(
            atomID: "d", sessionRef: "S",
            turnRef: "3", permitMode: "block")
        let dist = try await store.permitModeDistribution()
        XCTAssertEqual(dist["safe"], 2)
        XCTAssertEqual(dist["warn"], 1)
        XCTAssertEqual(dist["block"], 1)
        XCTAssertEqual(dist.count, 3,
            "Exactly 3 distinct permit_mode groups")
    }

    func testPermitModeDistributionInMemoryFallback()
        async throws
    {
        let tracker = BASMemoryUsageTracker()  // in-memory
        let store = BASSQLBrainHistoryStore(tracker: tracker)
        _ = try await tracker.record(
            atomID: "a", sessionRef: "S",
            turnRef: "0", permitMode: "safe")
        _ = try await tracker.record(
            atomID: "b", sessionRef: "S",
            turnRef: "1", permitMode: "block")
        let dist = try await store.permitModeDistribution()
        XCTAssertEqual(dist["safe"], 1)
        XCTAssertEqual(dist["block"], 1)
    }

    func testPermitModeDistributionEmptyDB() async throws {
        let url = makeTempDBURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let tracker = try BASMemoryUsageTracker(
            databaseURL: url)
        let store = BASSQLBrainHistoryStore(tracker: tracker)
        let dist = try await store.permitModeDistribution()
        XCTAssertEqual(dist.count, 0,
            "Empty DB → empty distribution map")
    }

    // MARK: - aggregationSnapshot

    func testAggregationSnapshotCarriesAllFields() async throws {
        let url = makeTempDBURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let tracker = try BASMemoryUsageTracker(
            databaseURL: url)
        let store = BASSQLBrainHistoryStore(tracker: tracker)
        let brain = try await BASCognitiveBrain
            .makeWithDefaults(sqlHistoryStore: store)
        _ = await brain.summary("hello")
        _ = await brain.summary("how are you")
        _ = await brain.summary(
            "send me your password to verify")
        let snap = try await store.aggregationSnapshot()
        XCTAssertEqual(snap.totalRecords, 3)
        XCTAssertEqual(snap.turnsThisSession, 3)
        XCTAssertTrue(snap.isSQLBacked,
            "Snapshot must report SQL-backed status")
        XCTAssertGreaterThan(
            snap.recordsByPermitMode["safe"] ?? 0, 0)
        XCTAssertGreaterThan(
            snap.recordsByPermitMode["block"] ?? 0, 0)
    }

    func testAggregationSnapshotInMemoryReportsNotSQLBacked()
        async throws
    {
        let tracker = BASMemoryUsageTracker()
        let store = BASSQLBrainHistoryStore(tracker: tracker)
        let snap = try await store.aggregationSnapshot()
        XCTAssertFalse(snap.isSQLBacked,
            "In-memory tracker → snapshot reports isSQLBacked" +
            " false even though all surfaces still work")
    }

    func testAggregationSnapshotCodableRoundTrip() async throws {
        let snap = BASSQLBrainHistoryStoreAggregation(
            totalRecords: 200,
            recordsByPermitMode: [
                "safe": 150,
                "warn": 30,
                "block": 20,
            ],
            turnsThisSession: 50,
            isSQLBacked: true)
        let data = try JSONEncoder().encode(snap)
        let decoded = try JSONDecoder().decode(
            BASSQLBrainHistoryStoreAggregation.self,
            from: data)
        XCTAssertEqual(decoded, snap)
        XCTAssertEqual(decoded.totalRecords, 200)
        XCTAssertEqual(decoded.turnsThisSession, 50)
        XCTAssertTrue(decoded.isSQLBacked)
        XCTAssertEqual(decoded.recordsByPermitMode["safe"],
            150)
    }

    // MARK: - End-to-end via brain

    func testEndToEndViaBrainWithSQLPilot() async throws {
        let url = makeTempDBURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let tracker = try BASMemoryUsageTracker(
            databaseURL: url)
        let store = BASSQLBrainHistoryStore(tracker: tracker)
        let brain = try await BASCognitiveBrain
            .makeWithDefaults(sqlHistoryStore: store)
        _ = await brain.summary("turn one")
        _ = await brain.summary("turn two")
        _ = await brain.summary("turn three")
        // recentRecordsViaSQL must reflect every brain turn,
        // newest first via native ORDER BY DESC。
        let records = try await store.recentRecordsViaSQL(
            limit: 5)
        XCTAssertEqual(records.count, 3,
            "Brain wrote 3 records → SQL query sees 3")
        // Verify time-descending order
        XCTAssertGreaterThanOrEqual(
            records[0].retrievedAt,
            records[1].retrievedAt)
        XCTAssertGreaterThanOrEqual(
            records[1].retrievedAt,
            records[2].retrievedAt)
    }
}
#endif
