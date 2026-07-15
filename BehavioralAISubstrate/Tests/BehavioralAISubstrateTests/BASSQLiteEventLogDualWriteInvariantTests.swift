// 先稳 P1 — the event-log payload columns hold the dual-write invariant + round-trip across both formats.
//
// Wire layout (per insertEntry): v1 ⇒ payload_format=1, payload_json populated, payload_blob NULL;
// v2 ⇒ payload_format=2, payload_blob populated, payload_json="" (empty, NOT NULL). A row must never be
// both/neither. The read path must decode either format back to the same stable fields.

import XCTest
import Foundation
import SQLite3
@testable import BASRuntimeCore

final class BASSQLiteEventLogDualWriteInvariantTests: XCTestCase {

    private var u: URL!

    override func setUpWithError() throws {
        u = FileManager.default.temporaryDirectory
            .appendingPathComponent("bas-evt-dualwrite-\(UUID().uuidString).sqlite")
    }

    override func tearDownWithError() throws {
        if let u {
            try? FileManager.default.removeItem(at: u)
            try? FileManager.default.removeItem(at: URL(fileURLWithPath: u.path + "-wal"))
            try? FileManager.default.removeItem(at: URL(fileURLWithPath: u.path + "-shm"))
        }
    }

    private func entry(_ id: String, seq: Int64) -> BASEventLogEntry {
        BASEventLogEntry(
            eventID: id, timestampMs: 1_700_000_000_000 + seq, kind: .substrateAudit,
            sessionID: "sess", sequenceNumber: seq, actions: ["a"])
    }

    /// Raw read-only probe of the three payload columns for one event_id.
    private func rawColumns(eventID: String) -> (format: Int, jsonLen: Int, blobIsNull: Bool)? {
        var db: OpaquePointer?
        guard sqlite3_open_v2(u.path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_close_v2(db) }
        var stmt: OpaquePointer?
        let sql = "SELECT payload_format, payload_json, payload_blob FROM event_log WHERE event_id = ?;"
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else { return nil }
        defer { sqlite3_finalize(stmt) }
        let TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        sqlite3_bind_text(stmt, 1, eventID, -1, TRANSIENT)
        guard sqlite3_step(stmt) == SQLITE_ROW else { return nil }
        let format = Int(sqlite3_column_int(stmt, 0))
        let jsonLen = Int(sqlite3_column_bytes(stmt, 1))
        let blobIsNull = sqlite3_column_type(stmt, 2) == SQLITE_NULL
        return (format, jsonLen, blobIsNull)
    }

    func testV1JsonOnlyColumns() async throws {
        let prior = BASSQLiteEventLogStorage.useBinaryPayload
        defer { BASSQLiteEventLogStorage.useBinaryPayload = prior }
        BASSQLiteEventLogStorage.useBinaryPayload = false

        let store = try BASSQLiteEventLogStorage(databaseURL: u)
        _ = try await store.append(entry("v1", seq: 0))

        let cols = try XCTUnwrap(rawColumns(eventID: "v1"))
        XCTAssertEqual(cols.format, 1, "v1 ⇒ payload_format=1")
        XCTAssertGreaterThan(cols.jsonLen, 0, "v1 ⇒ payload_json populated")
        XCTAssertTrue(cols.blobIsNull, "v1 ⇒ payload_blob NULL (never both populated)")
    }

    func testV2BlobOnlyColumns() async throws {
        let prior = BASSQLiteEventLogStorage.useBinaryPayload
        defer { BASSQLiteEventLogStorage.useBinaryPayload = prior }
        BASSQLiteEventLogStorage.useBinaryPayload = true

        let store = try BASSQLiteEventLogStorage(databaseURL: u)
        _ = try await store.append(entry("v2", seq: 0))

        let cols = try XCTUnwrap(rawColumns(eventID: "v2"))
        XCTAssertEqual(cols.format, 2, "v2 ⇒ payload_format=2 (binary path taken)")
        XCTAssertEqual(cols.jsonLen, 0, "v2 ⇒ payload_json empty (never both populated)")
        XCTAssertFalse(cols.blobIsNull, "v2 ⇒ payload_blob populated")
    }

    func testRoundTripBothFormats() async throws {
        let prior = BASSQLiteEventLogStorage.useBinaryPayload
        defer { BASSQLiteEventLogStorage.useBinaryPayload = prior }

        let store = try BASSQLiteEventLogStorage(databaseURL: u)
        BASSQLiteEventLogStorage.useBinaryPayload = false
        _ = try await store.append(entry("json", seq: 0))
        BASSQLiteEventLogStorage.useBinaryPayload = true
        _ = try await store.append(entry("bin", seq: 1))

        let events = try await store.eventsOrThrow(forSession: "sess")
        let byID = Dictionary(uniqueKeysWithValues: events.map { ($0.eventID, $0) })
        // Both formats decode back to the same STABLE column-bound fields.
        for (id, seq) in [("json", Int64(0)), ("bin", Int64(1))] {
            let e = try XCTUnwrap(byID[id], "\(id) round-trips through the read path")
            XCTAssertEqual(e.eventID, id)
            XCTAssertEqual(e.sessionID, "sess")
            XCTAssertEqual(e.kind, .substrateAudit)
            XCTAssertEqual(e.sequenceNumber, seq)
            XCTAssertEqual(e.timestampMs, 1_700_000_000_000 + seq)
        }
    }

    // audit runtimecore-b #8: the binary-vs-JSON decision is `useBinaryPayload && !chainEnabled` — a
    // chained row FORCES the faithful JSON path (so its integrity hash domain is unambiguous). append
    // now snapshots both flags once and threads this pure decision, so a concurrent flip can't produce
    // a binary row that ALSO gets a chain row. Pin the decision truth table.
    func testShouldWriteBinaryPayloadDecision() {
        typealias S = BASSQLiteEventLogStorage
        XCTAssertTrue(S.shouldWriteBinaryPayload(useBinaryPayload: true, chainEnabled: false),
            "binary on + chain off ⇒ binary")
        XCTAssertFalse(S.shouldWriteBinaryPayload(useBinaryPayload: true, chainEnabled: true),
            "chain on FORCES JSON even when binary is on (unambiguous hash domain)")
        XCTAssertFalse(S.shouldWriteBinaryPayload(useBinaryPayload: false, chainEnabled: false))
        XCTAssertFalse(S.shouldWriteBinaryPayload(useBinaryPayload: false, chainEnabled: true))
    }
}
