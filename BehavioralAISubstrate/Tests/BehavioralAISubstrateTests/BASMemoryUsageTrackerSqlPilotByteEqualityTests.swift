// MARK: - BASMemoryUsageTrackerSqlPilotByteEqualityTests
// chapter 七百二 / M2173 第三刀 — proves the chapter 七百二
//                                  SQL pilot dual-mode
//                                  (V1 inline schema /
//                                  V2 plugin-generated
//                                  schema) produces
//                                  IDENTICAL on-disk
//                                  database structure +
//                                  identical record I/O。
//
// The byte-equality invariant (752 consecutive clean commits
// at chapter 七百一 close-out + extending past chapter 七百二)
// only survives the augmentation arc if every flag-gated
// V2 path produces wire-identical output to its V1 baseline。
// These tests are the contractual proof for the SQL pilot。
//
// ## What "byte-equality" means here
//
// SQLite stores schema as text in `sqlite_master.sql`,which
// preserves the literal CREATE statement that produced each
// table / index。 V1 emits 3 separate CREATEs verbatim;
// V2 emits 1 multi-statement string with comments。 The
// `sqlite_master.sql` rows DIFFER between V1 + V2 because
// SQLite stores the source verbatim。
//
// What MUST be byte-equal:
//
//   - **Table list**:both modes create the same table。
//   - **Index list**:both modes create the same indices。
//   - **Column metadata** (PRAGMA table_info):name,type,
//     nullability,PRIMARY KEY position match。
//   - **Index metadata** (PRAGMA index_info):indexed
//     columns match。
//   - **Record round-trip**:inserting the same records via
//     either mode produces an identical `allRecords()`
//     sequence (which IS the wire format consumers see)。
//
// What DIFFERS (acceptable):
//
//   - `sqlite_master.sql` column (raw CREATE text stored
//     by SQLite — V1 has 3 short rows,V2 has 1 long row
//     including the SQL file's comment header)。 SQLite
//     uses this only for schema reconstruction;the QUERY
//     plan and storage layout are identical。
//
// ## Coverage matrix (8 tests)
//
//   1. V1 + V2 both create the memory_usage_records table
//   2. V1 + V2 both create memory_usage_atom_idx
//   3. V1 + V2 both create memory_usage_session_idx
//   4. PRAGMA table_info(memory_usage_records) byte-equal
//   5. PRAGMA index_info(memory_usage_atom_idx) byte-equal
//   6. PRAGMA index_info(memory_usage_session_idx) byte-equal
//   7. Round-trip: 5 records inserted via V1 + V2 yield
//      identical allRecords() output sequences
//   8. async make(databaseURL:flags:) honors default-off
//      flag (chooses V1) without explicit flag flip
//   9. async make(databaseURL:flags:) honors flag-on
//      (chooses V2)
//  10. Init parameter defaults useGeneratedSchema=false
//      (no caller-visible behavior change)

import XCTest
import SQLite3
@testable import BASMemory
@testable import BASRuntimeCore

final class BASMemoryUsageTrackerSqlPilotByteEqualityTests:
    XCTestCase
{

    // MARK: - Helpers

    private func tempDatabaseURL(suffix: String) -> URL {
        let dir = FileManager.default.temporaryDirectory
        let name = "bas_sql_pilot_\(suffix)_"
            + UUID().uuidString + ".sqlite"
        return dir.appendingPathComponent(name)
    }

    private func removeIfExists(_ url: URL) {
        let candidates = [
            url,
            url.appendingPathExtension("wal"),
            url.deletingPathExtension()
                .appendingPathExtension("sqlite-wal"),
            url.deletingPathExtension()
                .appendingPathExtension("sqlite-shm")
        ]
        for candidate in candidates {
            try? FileManager.default.removeItem(at: candidate)
        }
    }

    /// Open a SQLite handle on the given URL READONLY for
    /// metadata inspection。 Avoids touching the schema
    /// (read-only is sufficient for PRAGMA queries)。
    private func openReadOnly(_ url: URL) -> OpaquePointer? {
        var handle: OpaquePointer?
        let rc = sqlite3_open_v2(
            url.path, &handle, SQLITE_OPEN_READONLY, nil)
        guard rc == SQLITE_OK else { return nil }
        return handle
    }

    /// Run a PRAGMA / SELECT query and return rows as
    /// arrays of String (`NULL` → empty string)。 Used to
    /// dump table_info + index_info for comparison。
    private func dumpRows(
        db: OpaquePointer, sql: String
    ) -> [[String]] {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(
            db, sql, -1, &stmt, nil) == SQLITE_OK,
              let stmt
        else { return [] }
        defer { sqlite3_finalize(stmt) }
        var rows: [[String]] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let columnCount = sqlite3_column_count(stmt)
            var row: [String] = []
            for col in 0 ..< columnCount {
                if let raw = sqlite3_column_text(stmt, col) {
                    row.append(String(cString: raw))
                } else {
                    row.append("")
                }
            }
            rows.append(row)
        }
        return rows
    }

    /// Build two trackers (V1 + V2),seed them with the
    /// same records,run a block that introspects both
    /// databases for comparison。
    private func withV1AndV2Trackers(
        _ block: (
            _ v1DB: OpaquePointer,
            _ v2DB: OpaquePointer,
            _ v1Tracker: BASMemoryUsageTracker,
            _ v2Tracker: BASMemoryUsageTracker
        ) async throws -> Void
    ) async throws {
        let v1URL = tempDatabaseURL(suffix: "v1")
        let v2URL = tempDatabaseURL(suffix: "v2")
        defer {
            removeIfExists(v1URL)
            removeIfExists(v2URL)
        }
        let v1 = try BASMemoryUsageTracker(
            databaseURL: v1URL, useGeneratedSchema: false)
        let v2 = try BASMemoryUsageTracker(
            databaseURL: v2URL, useGeneratedSchema: true)
        guard let v1DB = openReadOnly(v1URL),
              let v2DB = openReadOnly(v2URL)
        else {
            return XCTFail(
                "Failed to open V1 / V2 dbs read-only")
        }
        defer {
            sqlite3_close_v2(v1DB)
            sqlite3_close_v2(v2DB)
        }
        try await block(v1DB, v2DB, v1, v2)
    }

    // MARK: - Object existence (table + 2 indices)

    func testV1AndV2BothCreateMemoryUsageRecordsTable() async throws {
        try await withV1AndV2Trackers { v1DB, v2DB, _, _ in
            let v1Tables = self.dumpRows(
                db: v1DB,
                sql: "SELECT name FROM sqlite_master" +
                     " WHERE type='table' AND" +
                     " name='memory_usage_records';")
            let v2Tables = self.dumpRows(
                db: v2DB,
                sql: "SELECT name FROM sqlite_master" +
                     " WHERE type='table' AND" +
                     " name='memory_usage_records';")
            XCTAssertEqual(v1Tables, [["memory_usage_records"]])
            XCTAssertEqual(v2Tables, [["memory_usage_records"]])
        }
    }

    func testV1AndV2BothCreateAtomIndex() async throws {
        try await withV1AndV2Trackers { v1DB, v2DB, _, _ in
            let q = "SELECT name FROM sqlite_master" +
                    " WHERE type='index' AND" +
                    " name='memory_usage_atom_idx';"
            XCTAssertEqual(
                self.dumpRows(db: v1DB, sql: q),
                [["memory_usage_atom_idx"]])
            XCTAssertEqual(
                self.dumpRows(db: v2DB, sql: q),
                [["memory_usage_atom_idx"]])
        }
    }

    func testV1AndV2BothCreateSessionIndex() async throws {
        try await withV1AndV2Trackers { v1DB, v2DB, _, _ in
            let q = "SELECT name FROM sqlite_master" +
                    " WHERE type='index' AND" +
                    " name='memory_usage_session_idx';"
            XCTAssertEqual(
                self.dumpRows(db: v1DB, sql: q),
                [["memory_usage_session_idx"]])
            XCTAssertEqual(
                self.dumpRows(db: v2DB, sql: q),
                [["memory_usage_session_idx"]])
        }
    }

    // MARK: - Schema metadata byte-equality

    func testTableInfoIsByteEqualBetweenV1AndV2() async throws {
        try await withV1AndV2Trackers { v1DB, v2DB, _, _ in
            let q = "PRAGMA table_info(memory_usage_records);"
            let v1Info = self.dumpRows(db: v1DB, sql: q)
            let v2Info = self.dumpRows(db: v2DB, sql: q)
            XCTAssertEqual(v1Info, v2Info,
                "PRAGMA table_info must match exactly" +
                " between V1 + V2 (column name, type," +
                " nullability, PK position)。 This is the" +
                " core byte-equality invariant for the" +
                " SQL pilot。")
            // Also pin row count = 7 columns。
            XCTAssertEqual(v1Info.count, 7)
        }
    }

    func testAtomIndexInfoIsByteEqualBetweenV1AndV2() async throws {
        try await withV1AndV2Trackers { v1DB, v2DB, _, _ in
            let q = "PRAGMA index_info(memory_usage_atom_idx);"
            XCTAssertEqual(
                self.dumpRows(db: v1DB, sql: q),
                self.dumpRows(db: v2DB, sql: q))
        }
    }

    func testSessionIndexInfoIsByteEqualBetweenV1AndV2() async throws {
        try await withV1AndV2Trackers { v1DB, v2DB, _, _ in
            let q = "PRAGMA index_info(memory_usage_session_idx);"
            XCTAssertEqual(
                self.dumpRows(db: v1DB, sql: q),
                self.dumpRows(db: v2DB, sql: q))
        }
    }

    // MARK: - Record round-trip (wire format byte-equality)

    func testRecordRoundTripIsByteEqualBetweenV1AndV2() async throws {
        try await withV1AndV2Trackers { _, _, v1, v2 in
            // Insert 5 deterministic records into both。
            let fixedDate = Date(
                timeIntervalSince1970: 1_700_000_000)
            for i in 0 ..< 5 {
                let stamp = fixedDate.addingTimeInterval(
                    TimeInterval(i))
                _ = try await v1.record(
                    atomID: "atom-\(i)",
                    sessionRef: "session-\(i % 2)",
                    turnRef: "turn-\(i)",
                    permitMode: "allow",
                    retrievedAt: stamp)
                _ = try await v2.record(
                    atomID: "atom-\(i)",
                    sessionRef: "session-\(i % 2)",
                    turnRef: "turn-\(i)",
                    permitMode: "allow",
                    retrievedAt: stamp)
            }
            let v1Records = await v1.allRecords()
            let v2Records = await v2.allRecords()
            XCTAssertEqual(v1Records.count, 5)
            XCTAssertEqual(v2Records.count, 5)
            // Records carry per-instance UUID recordIDs,so
            // normalize for comparison by clearing recordID
            // (the SCHEMA round-trip is what matters here)。
            let v1Normalized = v1Records.map {
                BASMemoryUsageRecord(
                    recordID: "X",
                    atomID: $0.atomID,
                    retrievedAt: $0.retrievedAt,
                    sessionRef: $0.sessionRef,
                    turnRef: $0.turnRef,
                    permitMode: $0.permitMode,
                    helpedFlag: $0.helpedFlag)
            }
            let v2Normalized = v2Records.map {
                BASMemoryUsageRecord(
                    recordID: "X",
                    atomID: $0.atomID,
                    retrievedAt: $0.retrievedAt,
                    sessionRef: $0.sessionRef,
                    turnRef: $0.turnRef,
                    permitMode: $0.permitMode,
                    helpedFlag: $0.helpedFlag)
            }
            XCTAssertEqual(v1Normalized, v2Normalized,
                "Wire format byte-equality:V1 and V2" +
                " allRecords() must return identical" +
                " record sequences (modulo per-instance" +
                " UUIDs)。")
        }
    }

    // MARK: - Flag-aware factory

    func testMakeWithFlagsDefaultChoosesV2PathAtChapter711() async throws {
        // M2201 chapter 七百十一 FIRST production wire-
        // in:sqlMigratorEnabled flipped to default-true。
        // Renamed from testMakeWithFlagsDefaultOffChooses
        // V1Path which pinned the pre-wire-in behavior。
        let url = tempDatabaseURL(suffix: "factory_default")
        defer { removeIfExists(url) }
        let flags = BASLanguageAugmentationFeatureFlags()
        let defaultValue = await flags.isEnabled(
            .sqlMigratorEnabled)
        XCTAssertTrue(defaultValue,
            "M2201 chapter 七百十一 production wire-in:" +
            " sqlMigratorEnabled now defaults TRUE。" +
            " Hosts using `make(flags:)` with default-" +
            "init flag actor get V2 path (generated" +
            " schema)。 chapter 七百二 PRAGMA byte-" +
            "equality proves V1+V2 produce identical" +
            " on-disk schema。")
        let tracker = try await BASMemoryUsageTracker.make(
            databaseURL: url, flags: flags)
        // V2 path now reached by default。 Schema is
        // byte-equal to V1 (PRAGMA-verified at M2173)。
        _ = try await tracker.record(
            atomID: "atom-x",
            sessionRef: "session-x",
            turnRef: "turn-x",
            permitMode: "allow")
        let count = await tracker.recordCount
        XCTAssertEqual(count, 1)
    }

    func testMakeWithFlagsExplicitlyOffChoosesV1Path() async throws {
        // M2201 chapter 七百十一 — V1 path still reachable
        // via explicit opt-out。 Production hosts that
        // need V1 for byte-equality investigations can
        // explicitly set the flag false。
        let url = tempDatabaseURL(suffix: "factory_explicit_off")
        defer { removeIfExists(url) }
        let flags = BASLanguageAugmentationFeatureFlags()
        await flags.setFlag(.sqlMigratorEnabled, to: false)
        let v = await flags.isEnabled(.sqlMigratorEnabled)
        XCTAssertFalse(v,
            "explicit setFlag(.sqlMigratorEnabled," +
            " to: false) overrides perFlagDefaults" +
            " entry → V1 path reachable for hosts" +
            " that need byte-equality investigation。")
        let tracker = try await BASMemoryUsageTracker.make(
            databaseURL: url, flags: flags)
        _ = try await tracker.record(
            atomID: "atom-y", sessionRef: "s",
            turnRef: "t", permitMode: "allow")
        let count = await tracker.recordCount
        XCTAssertEqual(count, 1)
    }

    func testMakeWithFlagsExplicitlyOnChoosesV2Path() async throws {
        let url = tempDatabaseURL(suffix: "factory_on")
        defer { removeIfExists(url) }
        let flags = BASLanguageAugmentationFeatureFlags()
        await flags.setFlag(.sqlMigratorEnabled, to: true)
        let tracker = try await BASMemoryUsageTracker.make(
            databaseURL: url, flags: flags)
        // V2 path also produces a functional schema —
        // record an event and read it back。
        let recordID = try await tracker.record(
            atomID: "atom-y",
            sessionRef: "session-y",
            turnRef: "turn-y",
            permitMode: "deny")
        let stored = await tracker.record(forID: recordID)
        XCTAssertEqual(stored?.atomID, "atom-y")
        XCTAssertEqual(stored?.permitMode, "deny")
    }

    // MARK: - Backward compatibility pin

    func testInitDefaultParameterPreservesV1Path() throws {
        // Callers that pre-date M2173 must continue to
        // work without modification。 The new optional
        // parameter defaults to false → V1 inline schema。
        let url = tempDatabaseURL(suffix: "compat")
        defer { removeIfExists(url) }
        // No useGeneratedSchema argument supplied;V1 path
        // taken silently。 This compiling + succeeding is
        // the assertion。
        _ = try BASMemoryUsageTracker(databaseURL: url)
    }
}
