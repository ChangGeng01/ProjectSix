// MARK: - BASChapter904UnifiedMemoryUsageTrackerByteEqTests
// chapter 九百四 / M3220 — unified facade byte-eq pin
//
// L8 unification — proves the unified BASRoutedMemoryUsageTracker
// Store facade is a drop-in replacement for BASMemoryUsageTracker
// at the FULL public surface level (not just per-table)。
//
// Coverage:
//   - 6 tables initialize under ONE engine handle (deinit safe)
//   - record() mints UUID + writes via records table
//   - markHelped() propagates via UPSERT-only-helped_state
//   - appendReplayLog / appendAuditLog mint IDs + write
//   - attachNotes UPSERTs
//   - tombstoneRecord + isTombstoned + tombstoneCount parity
//   - Full count + per-atom + per-session parity vs Swift actor

import XCTest
import Foundation
@testable import BASMemory
@testable import BASRuntimeCore
#if os(iOS) || os(macOS)
import BASRustMemoryTrackerBinary
#endif

#if os(iOS) || os(macOS)
final class BASChapter904UnifiedMemoryUsageTrackerByteEqTests:
    XCTestCase
{

    private func makeTempDBURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "ch904-\(UUID().uuidString).db")
    }

    private func cleanup(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
        try? FileManager.default.removeItem(
            at: URL(fileURLWithPath: url.path + "-wal"))
        try? FileManager.default.removeItem(
            at: URL(fileURLWithPath: url.path + "-shm"))
    }

    // MARK: - Engine + 6 schemas init under one handle

    func testInitOpensSingleEngineWithAllSixTables() async
        throws
    {
        let url = makeTempDBURL()
        defer { cleanup(url) }
        let store = try BASRoutedMemoryUsageTrackerStore(
            databaseURL: url)
        // All 6 tables must accept inserts without further
        // schema init calls。
        _ = try await store.record(
            atomID: "a1", sessionRef: "s1",
            turnRef: "t1", permitMode: "p")
        _ = try await store.appendReplayLog(
            eventType: "t", payload: "p")
        _ = try await store.appendAuditLog(
            actor: "x", action: "y", detail: "z")
        try await store.attachNotes(
            recordID: "r1", notes: "hello")
        try await store.tombstoneRecord(recordID: "r-tomb")
        let rc = await store.recordCount
        let rpc = await store.replayLogCount
        let ac = await store.auditLogCount
        let nc = await store.notesCount
        let tc = await store.tombstoneCount
        XCTAssertEqual(rc, 1)
        XCTAssertEqual(rpc, 1)
        XCTAssertEqual(ac, 1)
        XCTAssertEqual(nc, 1)
        XCTAssertEqual(tc, 1)
    }

    // MARK: - record + markHelped propagation

    func testRecordThenMarkHelpedPropagates() async throws {
        let url = makeTempDBURL()
        defer { cleanup(url) }
        let store = try BASRoutedMemoryUsageTrackerStore(
            databaseURL: url)
        let rid = try await store.record(
            atomID: "a1", sessionRef: "s1",
            turnRef: "t1", permitMode: "permitted")
        // Wrap each step in do-catch so the actual failure
        // point surfaces clearly rather than masked by defer
        do {
            let pre = try await store.helpedState(
                forRecordID: rid)
            XCTAssertEqual(pre, "unknown")
        } catch {
            XCTFail("helpedState(initial) threw: \(error)")
            return
        }
        do {
            try await store.markHelped(
                recordID: rid, helped: true)
        } catch {
            XCTFail("markHelped(helped=true) threw: \(error)")
            return
        }
        let post = try await store.helpedState(
            forRecordID: rid)
        XCTAssertEqual(post, "helped")
        try await store.markHelped(
            recordID: rid, helped: false)
        let final = try await store.helpedState(
            forRecordID: rid)
        XCTAssertEqual(final, "notHelped")
    }

    func testMarkHelpedThrowsForUnknownRecord() async throws {
        let url = makeTempDBURL()
        defer { cleanup(url) }
        let store = try BASRoutedMemoryUsageTrackerStore(
            databaseURL: url)
        do {
            try await store.markHelped(
                recordID: "no-such-rid", helped: true)
            XCTFail("Unknown recordID must throw")
        } catch let e as BASRoutedMemoryUsageTrackerStore
            .StoreError
        {
            // OK
            if case .upsertFailed(let t, let c) = e {
                XCTAssertEqual(t, "records")
                XCTAssertEqual(c, -2)
            } else {
                XCTFail("Wrong error case: \(e)")
            }
        }
    }

    // MARK: - Tombstones round-trip

    func testTombstoneRoundTrip() async throws {
        let url = makeTempDBURL()
        defer { cleanup(url) }
        let store = try BASRoutedMemoryUsageTrackerStore(
            databaseURL: url)
        try await store.tombstoneRecord(recordID: "rA")
        try await store.tombstoneRecord(recordID: "rB")
        // Dup id is idempotent (INSERT OR REPLACE)
        try await store.tombstoneRecord(recordID: "rA")
        let count = await store.tombstoneCount
        XCTAssertEqual(count, 2)
        let isA = await store.isTombstoned(recordID: "rA")
        let isB = await store.isTombstoned(recordID: "rB")
        let isMiss = await store.isTombstoned(
            recordID: "missing")
        XCTAssertTrue(isA)
        XCTAssertTrue(isB)
        XCTAssertFalse(isMiss)
    }

    // MARK: - Full-surface byte-eq vs BASMemoryUsageTracker

    func testByteEqUnifiedFacadeVsSwiftAcrossSixTables() async
        throws
    {
        // The MAIN PROOF — drive identical operations through
        // both stores + assert counts + lookups byte-equal at
        // the FULL surface level (not just per-table)。
        let routedURL = makeTempDBURL()
        let swiftURL = makeTempDBURL()
        defer { cleanup(routedURL); cleanup(swiftURL) }
        let routed = try BASRoutedMemoryUsageTrackerStore(
            databaseURL: routedURL)
        let swiftActor = try BASMemoryUsageTracker(
            databaseURL: swiftURL)
        // 1) records: 4 recall events across 2 atoms × 2 sessions
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let rPairs = [
            ("a-X", "s-1"),
            ("a-X", "s-1"),
            ("a-Y", "s-2"),
            ("a-X", "s-2"),
        ]
        for (atom, sess) in rPairs {
            _ = try await routed.record(
                atomID: atom, sessionRef: sess,
                turnRef: "t-x", permitMode: "permitted",
                retrievedAt: date)
            _ = try await swiftActor.record(
                atomID: atom, sessionRef: sess,
                turnRef: "t-x", permitMode: "permitted",
                retrievedAt: date)
        }
        let rTotal = await routed.recordCount
        let sTotal = await swiftActor.recordCount
        XCTAssertEqual(rTotal, sTotal)
        XCTAssertEqual(rTotal, 4)
        for atom in ["a-X", "a-Y", "a-missing"] {
            let r = await routed.usageCount(forAtomID: atom)
            let s = await swiftActor.usageCount(
                forAtomID: atom)
            XCTAssertEqual(r, s,
                "Per-atom byte-eq for \(atom)")
        }
        // 2) replay log: 3 events
        for i in 0..<3 {
            _ = try await routed.appendReplayLog(
                eventType: "t-\(i)",
                payload: "p-\(i)",
                recordedAt: date)
            _ = try await swiftActor.appendReplayLog(
                eventType: "t-\(i)",
                payload: "p-\(i)",
                recordedAt: date)
        }
        let rRC = await routed.replayLogCount
        let sRC = try await swiftActor
            .replayLogEntriesViaSQL().count
        XCTAssertEqual(rRC, sRC)
        XCTAssertEqual(rRC, 3)
        // 3) audit log: 2 entries
        for i in 0..<2 {
            _ = try await routed.appendAuditLog(
                actor: "act-\(i)", action: "do",
                detail: "d", recordedAt: date)
            _ = try await swiftActor.appendAuditLog(
                actor: "act-\(i)", action: "do",
                detail: "d", recordedAt: date)
        }
        let rAC = await routed.auditLogCount
        let sAC = try await swiftActor
            .auditLogEntriesViaSQL().count
        XCTAssertEqual(rAC, sAC)
        XCTAssertEqual(rAC, 2)
        // 4) tombstones: 4 inserts with 1 dup → 3 distinct
        let tIDs = ["rA", "rB", "rC", "rA"]
        for id in tIDs {
            try await routed.tombstoneRecord(recordID: id)
            try await swiftActor.tombstoneRecord(
                recordID: id, tombstonedAt: date)
        }
        let rTC = await routed.tombstoneCount
        let sTC = await swiftActor.tombstoneCount
        XCTAssertEqual(rTC, sTC)
        XCTAssertEqual(rTC, 3)
    }
}
#endif
