// Red-team / tamper-evidence on the SQLite event log (Wall 3, GAP-3a/3b).
//
// The event log is the sovereign AUDIT TRAIL. These tests model an out-of-band attacker with raw `sqlite3`
// access to the DB file (forensic tamper / a compromised process with the app's own file handle) and probe
// exactly what such an attacker can do UNDETECTED versus what is caught.
//
// Findings made executable:
//   - GAP-3b (middle-row deletion / sequence gap): DETECTED by the new spine-safe `eventsVerifyingContiguity`
//     read-side check, while the default read silently returns the gapped sequence (the fail-OPEN baseline).
//   - GAP-3a (semantic payload edit that preserves the sequence column): UNDETECTED at read — documented as a
//     real limitation that needs per-row integrity tags / a hash chain (Docs/ADR_040, operator-gated).
//
// The verifier is read-only + Metal-free ⇒ it does not touch the byte-deterministic write path.

import XCTest
import Foundation
import SQLite3
@testable import BASRuntimeCore

final class BASEventLogTamperRedTeamTests: XCTestCase {

    private var base: URL!

    override func setUpWithError() throws {
        // These tests tamper via raw `UPDATE ... payload_json = REPLACE(...)`, which requires the JSON write
        // path. Pin the process-global `useBinaryPayload` flag OFF defensively so a sibling suite that flips
        // it true cannot leak across the shared test process and route our appends to payload_blob.
        BASSQLiteEventLogStorage.useBinaryPayload = false
        base = FileManager.default.temporaryDirectory
            .appendingPathComponent("bas-evt-tamper-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws {
        BASSQLiteEventLogStorage.useBinaryPayload = false
        if let base { try? FileManager.default.removeItem(at: base) }
    }
    private func path(_ n: String) -> String { base.appendingPathComponent(n).path }

    /// Out-of-band SQL against the DB file via a SEPARATE connection (simulates the attacker / forensic tamper).
    @discardableResult
    private func rawExec(_ dbPath: String, _ sql: String) throws -> Int {
        var db: OpaquePointer?
        guard sqlite3_open_v2(dbPath, &db, SQLITE_OPEN_READWRITE, nil) == SQLITE_OK, let db else {
            throw NSError(domain: "rawExec", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "out-of-band open failed: \(dbPath)"])
        }
        defer { sqlite3_close_v2(db) }
        var err: UnsafeMutablePointer<CChar>?
        let rc = sqlite3_exec(db, sql, nil, nil, &err)
        if rc != SQLITE_OK {
            let m = err.map { String(cString: $0) } ?? "rc=\(rc)"
            if let e = err { sqlite3_free(e) }
            throw NSError(domain: "rawExec", code: Int(rc), userInfo: [NSLocalizedDescriptionKey: m])
        }
        return Int(sqlite3_changes(db))
    }

    private func appendN(_ store: BASSQLiteEventLogStorage, session: String, n: Int) async throws {
        for j in 0..<n {
            _ = try await store.append(BASEventLogEntry(
                eventID: "\(session)-e\(j)",
                timestampMs: 1_700_000_000_000 + Int64(j),
                kind: .substrateAudit,
                sessionID: session,
                sequenceNumber: 0,
                actions: ["a\(j)"]))
        }
    }

    // MARK: - GAP-3b: middle-row deletion is DETECTED (default read is the fail-OPEN baseline)

    func testMiddleRowDeletionDetectedByContiguityVerifier() async throws {
        let p = path("evt.sqlite")
        let store = try BASSQLiteEventLogStorage(databaseURL: URL(fileURLWithPath: p))
        let session = "s"
        try await appendN(store, session: session, n: 4)   // seq 0,1,2,3

        let deleted = try rawExec(p,
            "DELETE FROM event_log WHERE session_id='\(session)' AND sequence_number=1;")
        XCTAssertEqual(deleted, 1, "the tamper removed exactly one row")

        // Baseline: the default read silently returns a non-contiguous [0,2,3] with NO signal (fail-OPEN).
        let plain = try await store.eventsOrThrow(forSession: session)
        XCTAssertEqual(plain.map(\.sequenceNumber), [0, 2, 3],
            "default read returns surviving rows with a silent gap — no tamper signal")

        // The contiguity verifier DETECTS the gap and throws corruptedRow.
        do {
            _ = try await store.eventsVerifyingContiguity(forSession: session)
            XCTFail("contiguity verifier must throw on a deleted middle row")
        } catch let err as BASSQLiteEventLogStorage.StorageError {
            guard case .corruptedRow = err else {
                return XCTFail("expected .corruptedRow, got \(err)")
            }
        }
    }

    // MARK: - GAP-3b: a duplicated sequence number is DETECTED

    func testDuplicateSequenceNumberDetected() async throws {
        let p = path("evt-dup.sqlite")
        let store = try BASSQLiteEventLogStorage(databaseURL: URL(fileURLWithPath: p))
        let session = "s"
        try await appendN(store, session: session, n: 3)   // seq 0,1,2

        // Out-of-band: forge a duplicate of seq=1 (new event_id PK, same sequence_number).
        try rawExec(p, """
            INSERT INTO event_log
              (event_id, session_id, sequence_number, timestamp_ms, kind, risk_band, payload_json, payload_format)
            SELECT 'forged-dup', session_id, sequence_number, timestamp_ms, kind, risk_band, payload_json, payload_format
            FROM event_log WHERE session_id='\(session)' AND sequence_number=1;
            """)

        do {
            _ = try await store.eventsVerifyingContiguity(forSession: session)
            XCTFail("contiguity verifier must throw on a duplicated sequence number")
        } catch let err as BASSQLiteEventLogStorage.StorageError {
            guard case .corruptedRow = err else { return XCTFail("expected .corruptedRow, got \(err)") }
        }
    }

    // MARK: - Controls: an untampered log + legitimate front-pruning both PASS (no false positives)

    func testUntamperedLogPassesContiguityVerifier() async throws {
        let p = path("evt-ok.sqlite")
        let store = try BASSQLiteEventLogStorage(databaseURL: URL(fileURLWithPath: p))
        try await appendN(store, session: "s", n: 5)
        let verified = try await store.eventsVerifyingContiguity(forSession: "s")
        XCTAssertEqual(verified.map(\.sequenceNumber), [0, 1, 2, 3, 4])
    }

    func testFrontPruningStaysContiguousAndIsNotFlagged() async throws {
        let p = path("evt-prune.sqlite")
        let store = try BASSQLiteEventLogStorage(databaseURL: URL(fileURLWithPath: p))
        try await appendN(store, session: "s", n: 5)   // ts base+0..4, seq 0..4
        // Legitimate retention prune of the two oldest by timestamp.
        _ = try await store.pruneEventsBefore(timestampMs: 1_700_000_000_002)
        let verified = try await store.eventsVerifyingContiguity(forSession: "s")
        XCTAssertEqual(verified.map(\.sequenceNumber), [2, 3, 4],
            "surviving rows after a front-prune are contiguous (start > 0) — NOT flagged as tamper")
    }

    // MARK: - GAP-3a: semantic payload tamper that preserves the sequence column is UNDETECTED (documented)

    func testSemanticPayloadTamperIsUndetectedAtRead_documentsLimitation() async throws {
        let p = path("evt-semantic.sqlite")
        let store = try BASSQLiteEventLogStorage(databaseURL: URL(fileURLWithPath: p))
        let session = "s"
        _ = try await store.append(BASEventLogEntry(
            eventID: "\(session)-e0",
            timestampMs: 1_700_000_000_000,
            kind: .substrateAudit,
            sessionID: session,
            sequenceNumber: 0,
            intent: "ORIGINAL-INTENT",
            actions: ["original"]))

        // Out-of-band: rewrite the intent INSIDE payload_json, keeping the JSON well-formed and the
        // sequence_number column intact. REPLACE swaps the value substring only.
        let changed = try rawExec(p, """
            UPDATE event_log
            SET payload_json = REPLACE(payload_json, 'ORIGINAL-INTENT', 'FORGED-INTENT')
            WHERE session_id='\(session)' AND sequence_number=0;
            """)
        XCTAssertEqual(changed, 1, "the semantic tamper rewrote exactly one row")

        // FAIL-OPEN: the store decodes + returns the attacker-controlled payload with NO error.
        let events = try await store.eventsOrThrow(forSession: session)
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events[0].intent, "FORGED-INTENT",
            "DOCUMENTED LIMITATION (GAP-3a): a semantic payload edit is returned verbatim — undetected")

        // And the contiguity verifier ALSO passes (sequence column untouched) — confirming contiguity is NOT
        // sufficient for this class; full tamper-evidence needs per-row integrity tags (Docs/ADR_040).
        let verified = try await store.eventsVerifyingContiguity(forSession: session)
        XCTAssertEqual(verified[0].intent, "FORGED-INTENT",
            "contiguity check cannot catch a seq-preserving payload edit — the hash-chain follow-up would")
    }

    // MARK: - GAP-3b (column authority): a COLUMN-ONLY sequence_number tamper is DETECTED

    func testColumnOnlySequenceTamperDetected() async throws {
        // The verifier must check the authoritative `sequence_number` COLUMN, not the payload_json-decoded
        // value. Edit ONLY the column of the seq=2 row to 1 (a duplicate), leaving payload_json (which still
        // encodes seq=2) untouched. A verifier that checked the decoded JSON could be fooled; a column-based
        // verifier sees the duplicate [0,1,1] and throws.
        let p = path("evt-coltamper.sqlite")
        let store = try BASSQLiteEventLogStorage(databaseURL: URL(fileURLWithPath: p))
        let session = "s"
        try await appendN(store, session: session, n: 3)   // seq 0,1,2 in BOTH column + payload_json

        let changed = try rawExec(p,
            "UPDATE event_log SET sequence_number=1 WHERE session_id='\(session)' AND sequence_number=2;")
        XCTAssertEqual(changed, 1, "the column-only tamper rewrote exactly one row")

        do {
            _ = try await store.eventsVerifyingContiguity(forSession: session)
            XCTFail("verifier must detect a column-only sequence_number tamper (duplicate)")
        } catch let err as BASSQLiteEventLogStorage.StorageError {
            guard case .corruptedRow = err else { return XCTFail("expected .corruptedRow, got \(err)") }
        }
    }

    // MARK: - Boundary coverage: empty + single-event sessions verify without throwing

    func testEmptySessionPassesVerifier() async throws {
        let store = try BASSQLiteEventLogStorage(databaseURL: URL(fileURLWithPath: path("evt-empty.sqlite")))
        let out = try await store.eventsVerifyingContiguity(forSession: "never-written")
        XCTAssertTrue(out.isEmpty,
            "a never-written session must verify (no throw) and return [] — the common caller path")
    }

    func testSingleEventPassesVerifier() async throws {
        let store = try BASSQLiteEventLogStorage(databaseURL: URL(fileURLWithPath: path("evt-single.sqlite")))
        try await appendN(store, session: "s", n: 1)
        let out = try await store.eventsVerifyingContiguity(forSession: "s")
        XCTAssertEqual(out.map(\.sequenceNumber), [0],
            "a single-event session is trivially contiguous (no discontinuity guard fires)")
    }
}
