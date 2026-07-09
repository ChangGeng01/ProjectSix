import XCTest
import Foundation
import SQLite3
@testable import BASMemory

/// audit memory-a F6 — upsertNotesRow's main-table UPSERT + FTS DELETE + FTS INSERT used to run as
/// three separate autocommits (despite a "wrap in a transaction" comment). A failure after the main
/// UPSERT left the FTS index diverged from the main table. They now run in one transaction that rolls
/// the whole sequence back on any failure.
#if os(iOS) || os(macOS)
final class BASMemoryUsageTrackerNotesAtomicityTests: XCTestCase {

    private func url() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("notes-\(UUID().uuidString).sqlite")
    }
    private func cleanup(_ u: URL) {
        for s in ["", "-wal", "-shm"] {
            try? FileManager.default.removeItem(at: URL(fileURLWithPath: u.path + s))
        }
    }
    private func mainNotes(_ u: URL, _ recordID: String) -> String? {
        var raw: OpaquePointer?
        guard sqlite3_open_v2(u.path, &raw, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_close_v2(raw) }
        var stmt: OpaquePointer?
        let sql = "SELECT notes FROM memory_usage_record_notes WHERE record_id=?;"
        guard sqlite3_prepare_v2(raw, sql, -1, &stmt, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_finalize(stmt) }
        _ = recordID.withCString { sqlite3_bind_text(stmt, 1, $0, -1, nil) }
        guard sqlite3_step(stmt) == SQLITE_ROW, let c = sqlite3_column_text(stmt, 0) else { return nil }
        return String(cString: c)
    }

    func testFTSWriteFailureRollsBackMainTableUpsert() async throws {
        let u = url(); defer { cleanup(u) }
        let tracker = try BASMemoryUsageTracker(databaseURL: u)
        try await tracker.attachNotes(recordID: "r1", notes: "v1")
        XCTAssertEqual(mainNotes(u, "r1"), "v1")

        // Break the FTS INSERT: drop an FTS5 SHADOW table via a 2nd connection. The
        // `CREATE VIRTUAL TABLE IF NOT EXISTS` in ensureSchema sees the FTS vtable still exists so it
        // won't recreate the shadow — the next FTS write therefore fails.
        var raw: OpaquePointer?
        XCTAssertEqual(sqlite3_open_v2(u.path, &raw, SQLITE_OPEN_READWRITE, nil), SQLITE_OK)
        _ = sqlite3_exec(raw, "DROP TABLE IF EXISTS memory_usage_record_notes_fts_data;", nil, nil, nil)
        sqlite3_close_v2(raw)

        // Re-attach with new content — the FTS write fails, so the whole transaction (including the
        // main-table UPSERT to "v2") must roll back.
        var threw = false
        do {
            try await tracker.attachNotes(recordID: "r1", notes: "v2")
        } catch {
            threw = true
        }
        XCTAssertTrue(threw, "attachNotes must throw when the FTS write fails")
        XCTAssertEqual(mainNotes(u, "r1"), "v1",
            "the main-table UPSERT must roll back with the failed FTS write (F6 atomicity) — not commit v2")
    }
}
#endif
