// 先稳 P1 — durability + corruption-surfacing proofs for the Rust+SQL L8 spine stores.
//
// Covers the gaps the P0 audit named:
//   • reopen-durability (WAL crash-like close → reopen → rows present) for all 3 stores,
//   • corruption-at-init is SURFACED (a non-sqlite file ⇒ init throws — integrity > availability, M91),
//   • a read failure on a live store fires `onSilentFailure` AND throws from the `…OrThrow` sibling, so a
//     host can tell "not found" from "DB broken" (the whole point of the P0 surfacing).
//
// NOTE: real ENOSPC / SIGKILL-mid-write injection needs a tmpfs mount or a process harness and is a
// manual/CI-only check — out of scope for this unit test. These cover the deterministic, portable cases.

import XCTest
import Foundation
import SQLite3
@testable import BASMemory
@testable import BASRuntimeCore

final class BASSQLiteStoreCrashRecoveryTests: XCTestCase {

    private var base: URL!

    override func setUpWithError() throws {
        base = FileManager.default.temporaryDirectory
            .appendingPathComponent("bas-crash-rec-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: base, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let base { try? FileManager.default.removeItem(at: base) }
    }

    private func url(_ name: String) -> URL { base.appendingPathComponent(name) }

    private func governed(id: UUID, content: String) -> BASGovernedMemory {
        BASGovernedMemory(
            id: id, kind: .semantic, content: content, scope: .user,
            sensitivity: .low, tier: .warm, confidence: 0.7,
            sourceType: "general", governanceStatus: .candidate, provenanceSummary: "crashrec")
    }

    private func entry(_ atomID: String) -> BASVectorIndexEntry {
        BASVectorIndexEntry(
            atomID: atomID,
            normalizedEmbedding: BASEmbedding(
                vector: [1, 0, 0, 0], dimension: 4, providerVersion: "p").normalized,
            domain: "d")
    }

    // MARK: - Reopen-durability (WAL survives a clean-but-uncheckpointed close = crash-like)

    func testVectorIndexSurvivesReopen() async throws {
        let u = url("vec.sqlite")
        do {
            let s = try BASSQLiteVectorIndexStorage(databaseURL: u)
            _ = try await s.upsert(entry("a1"))
            _ = try await s.upsert(entry("a2"))
        }  // store dropped → deinit closes the handle without an explicit checkpoint (crash-like)
        let s2 = try BASSQLiteVectorIndexStorage(databaseURL: u)
        let all = try await s2.allEntriesOrThrow()
        XCTAssertEqual(Set(all.map(\.atomID)), ["a1", "a2"],
            "WAL-persisted vector entries survive a close+reopen")
    }

    func testMemoryAtomSurvivesReopen() async throws {
        let u = url("mem.sqlite")
        let id = UUID()
        do {
            let s = try BASSQLiteMemoryAtomStore(databaseURL: u)
            _ = try await s.admit(governed(id: id, content: "durable"))
        }
        let s2 = try BASSQLiteMemoryAtomStore(databaseURL: u)
        let n = try await s2.countOrThrow()
        XCTAssertEqual(n, 1, "admitted atom survives a close+reopen")
        let got = await s2.atom(forID: id.uuidString)
        XCTAssertEqual(got?.id, id)
    }

    func testEventLogSurvivesReopen() async throws {
        let u = url("evt.sqlite")
        let session = "sess-1"
        do {
            let s = try BASSQLiteEventLogStorage(databaseURL: u)
            _ = try await s.append(BASEventLogEntry(
                eventID: "e1", timestampMs: 1_700_000_000_000, kind: .substrateAudit,
                sessionID: session, sequenceNumber: 0, actions: ["x"]))
        }
        let s2 = try BASSQLiteEventLogStorage(databaseURL: u)
        let events = try await s2.eventsOrThrow(forSession: session)
        XCTAssertEqual(events.map(\.eventID), ["e1"], "appended event survives a close+reopen")
    }

    // MARK: - Corruption at init is SURFACED, not silently truncated

    func testCorruptFileAtInitThrows() throws {
        let u = url("corrupt.sqlite")
        // A file that exists but is NOT a valid SQLite database → first PRAGMA/schema access fails
        // (SQLITE_NOTADB). init() is `throws` and must surface it rather than create a fresh empty store.
        try Data(repeating: 0xFF, count: 4096).write(to: u)
        XCTAssertThrowsError(try BASSQLiteVectorIndexStorage(databaseURL: u),
            "a corrupt (non-sqlite) file must surface at init, not be silently truncated") { err in
            XCTAssertTrue(err is BASSQLiteVectorIndexStorage.StorageError,
                "the surfaced error is the store's typed StorageError, got \(err)")
        }
    }

    // MARK: - A read failure fires onSilentFailure AND throws from the OrThrow sibling

    func testReadFailureFiresHookAndOrThrowThrows() async throws {
        let u = url("droptable.sqlite")
        let store = try BASSQLiteMemoryAtomStore(databaseURL: u)
        _ = try await store.admit(governed(id: UUID(), content: "x"))

        // Drop the table out from under the store via a SECOND connection. In WAL mode the store's
        // connection sees the committed DROP on its next read → its SELECT fails.
        var raw: OpaquePointer?
        XCTAssertEqual(sqlite3_open_v2(u.path, &raw, SQLITE_OPEN_READWRITE, nil), SQLITE_OK)
        XCTAssertEqual(sqlite3_exec(raw, "DROP TABLE memory_atoms;", nil, nil, nil), SQLITE_OK)
        sqlite3_close_v2(raw)

        final class Box: @unchecked Sendable { let lock = NSLock(); var fired = 0 }
        let box = Box()
        await store.setOnSilentFailure { _ in box.lock.lock(); box.fired += 1; box.lock.unlock() }

        // The non-throwing accessor returns its default (0) AND fires the diagnostic hook...
        let n = await store.count
        XCTAssertEqual(n, 0, "the swallowing accessor still returns its default on a read failure")
        XCTAssertGreaterThan(box.fired, 0,
            "onSilentFailure fires on a read failure (host can tell 'broken' from 'empty')")
        // ...while the OrThrow sibling SURFACES the error.
        do {
            _ = try await store.countOrThrow()
            XCTFail("countOrThrow must throw when the table is gone (not return 0)")
        } catch {
            XCTAssertTrue(error is BASSQLiteMemoryAtomStore.StorageError,
                "OrThrow surfaces the typed StorageError, got \(error)")
        }
    }

    // MARK: - integrity_check opt-in (P2) — passes on a healthy DB

    func testIntegrityCheckOpenPassesOnHealthyDB() async throws {
        let prior = BASSQLiteVectorIndexStorage.runIntegrityCheckOnOpen
        defer { BASSQLiteVectorIndexStorage.runIntegrityCheckOnOpen = prior }
        BASSQLiteVectorIndexStorage.runIntegrityCheckOnOpen = true
        let u = url("integ.sqlite")
        let s = try BASSQLiteVectorIndexStorage(databaseURL: u)   // opens cleanly with the scan ON
        _ = try await s.upsert(entry("ok1"))
        let n1 = try await s.totalCountOrThrow()
        XCTAssertEqual(n1, 1)
        let s2 = try BASSQLiteVectorIndexStorage(databaseURL: u)  // reopen, scan still ON, still healthy
        let n2 = try await s2.totalCountOrThrow()
        XCTAssertEqual(n2, 1,
            "integrity_check passes on a healthy DB (opt-in proactive scan adds no false positives)")
    }
}
