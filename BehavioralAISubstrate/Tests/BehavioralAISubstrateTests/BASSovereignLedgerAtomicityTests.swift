import XCTest
import CryptoKit
import SQLite3
@testable import BASRuntimeCore
@testable import BASSovereign

/// audit F3 + F4 (2026-07-12) — sovereign-ledger disk atomicity and fail-closed reads.
final class BASSovereignLedgerAtomicityTests: XCTestCase {

    private func tmpPath(_ label: String = #function) -> String {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("ledger-atomic-\(label)-\(UUID().uuidString).sqlite").path
    }
    private func removeFile(_ path: String) {
        for s in ["", "-wal", "-shm"] { try? FileManager.default.removeItem(atPath: path + s) }
    }
    private func key() -> SymmetricKey {
        SymmetricKey(data: SHA256.hash(data: Data("atomic-seed".utf8)))
    }
    private func makeEntry(_ id: String, session: String = "s1", turn: String = "t1")
        -> BASSovereignAuditEntry {
        BASSovereignAuditEntry(
            auditID: id, sessionID: session, turnID: turn, verdictRef: "v",
            ruleIDs: ["BR-001"], signalRefs: ["sig"], actionRefs: [], snapshotRef: "snap",
            actor: .system, signature: "", appendedAt: Date(timeIntervalSince1970: 1_700_000_000))
    }

    // MARK: - F3: entry+segment persist atomically (no durable orphan)

    /// Inject a failure on the SEGMENT write (drop the segments table via a 2nd connection)
    /// after the first entry commits. The atomic transaction must ROLL BACK the entry insert
    /// too — so the reopened ledger holds ONLY the first entry and is NOT quarantined.
    /// Pre-fix (two autocommits): the entry row survives as an orphan, segmentSum != count,
    /// and cold-start quarantines the whole ledger.
    func testEntryAndSegmentPersistAtomically() async throws {
        let path = tmpPath()
        defer { removeFile(path) }

        do {
            let storage = try BASSovereignLedgerSQLiteStorage(path: path)
            let ledger = BASSovereignAuditLedger(signingSecret: key(), storage: storage)
            _ = try await ledger.append(makeEntry("a-1"))
            let c1 = await ledger.count()
            XCTAssertEqual(c1, 1)

            // Break the segment write: drop the segments table via a second connection.
            var raw: OpaquePointer?
            XCTAssertEqual(sqlite3_open_v2(path, &raw, SQLITE_OPEN_READWRITE, nil), SQLITE_OK)
            _ = sqlite3_exec(raw, "DROP TABLE segments;", nil, nil, nil)
            sqlite3_close_v2(raw)

            // The 2nd append: entry INSERT would succeed but the segment INSERT fails →
            // the whole transaction must roll back → append throws → NO orphan on disk.
            var threw = false
            do { _ = try await ledger.append(makeEntry("a-2", turn: "t2")) }
            catch { threw = true }
            XCTAssertTrue(threw, "append must throw when the segment write fails")
        }

        // Recreate the segments table so reopen can read (empty) segments, then verify the
        // orphan entry never committed: exactly ONE entry, chain intact, NOT quarantined.
        var raw: OpaquePointer?
        XCTAssertEqual(sqlite3_open_v2(path, &raw, SQLITE_OPEN_READWRITE, nil), SQLITE_OK)
        _ = sqlite3_exec(raw, """
            CREATE TABLE IF NOT EXISTS segments (
                segment_id TEXT PRIMARY KEY, segment_index INTEGER, session_id TEXT,
                start_anchor TEXT, tail_hash TEXT, entry_count INTEGER,
                opened_at_ms INTEGER, closed_at_ms INTEGER, closed_by TEXT,
                closing_rotation_id TEXT);
            """, nil, nil, nil)
        // reinsert the segment row for the surviving entry (count 1) so the cross-check matches
        _ = sqlite3_exec(raw, """
            INSERT INTO segments (segment_id, segment_index, session_id, start_anchor,
                tail_hash, entry_count, opened_at_ms, closed_at_ms, closed_by, closing_rotation_id)
            SELECT 'seg-0', 0, 's1', 'GENESIS', NULL, COUNT(*), 0, NULL, NULL, NULL
              FROM audit_entries;
            """, nil, nil, nil)
        sqlite3_close_v2(raw)

        let storage2 = try BASSovereignLedgerSQLiteStorage(path: path)
        let ledger2 = BASSovereignAuditLedger(signingSecret: key(), storage: storage2)
        let count2 = await ledger2.count()
        XCTAssertEqual(count2, 1, "the failed 2nd append left NO orphan entry — atomic rollback")
        let quarantined = await ledger2.isIntegrityQuarantined
        XCTAssertFalse(quarantined,
            "one entry + one segment(count 1) reconcile — ledger is healthy, not quarantined")
    }

    // MARK: - F4: empty-entries-with-segments quarantines (fail-closed reorder)

    /// A storage that returns ZERO entries while segments record a positive count is the
    /// tamper/errored-read signal. The reload cross-check must now catch it (pre-fix the
    /// `guard !entries.isEmpty` returned first and skipped the cross-check → fail-open).
    func testEmptyEntriesWithNonEmptySegmentsQuarantines() async {
        let storage = StubStorage(
            entries: [],
            segments: [BASSovereignLedgerSegment(
                segmentID: "seg-0", segmentIndex: 0, sessionID: "s1",
                startAnchor: "GENESIS", tailHash: nil, entryCount: 3,
                openedAt: Date(timeIntervalSince1970: 1_700_000_000),
                closedAt: nil, closedBy: nil, closingRotationID: nil)])
        let ledger = BASSovereignAuditLedger(signingSecret: key(), storage: storage)
        let quarantined = await ledger.isIntegrityQuarantined
        XCTAssertTrue(quarantined,
            "0 entries but segments claim 3 ⇒ truncation/error ⇒ fail-closed quarantine")
    }

    /// Control: a genuinely fresh store (empty entries AND empty segments) stays healthy.
    func testFreshStoreIsNotQuarantined() async {
        let storage = StubStorage(entries: [], segments: [])
        let ledger = BASSovereignAuditLedger(signingSecret: key(), storage: storage)
        let quarantined = await ledger.isIntegrityQuarantined
        XCTAssertFalse(quarantined, "fresh store is healthy")
    }

    private struct StubStorage: BASSovereignLedgerStorage {
        let entries: [BASSovereignAuditLedger.AppendedEntry]
        let segments: [BASSovereignLedgerSegment]
        func loadState() throws
            -> (entries: [BASSovereignAuditLedger.AppendedEntry],
                segments: [BASSovereignLedgerSegment]) { (entries, segments) }
        func persistAppended(_ entry: BASSovereignAuditLedger.AppendedEntry) throws {}
        func persistSegment(_ segment: BASSovereignLedgerSegment) throws {}
    }
}
