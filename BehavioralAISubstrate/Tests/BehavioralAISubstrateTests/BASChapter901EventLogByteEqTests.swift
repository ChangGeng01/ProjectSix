// MARK: - BASChapter901EventLogByteEqTests
// chapter 九百一 / M3195 — HIGH-risk migration #1 byte-eq pin
//
// More thorough than ch 895-900 per 「细心开发」 discipline。
// EventLog is the per-turn hot path — every turn lifecycle event
// flows through here。 Test coverage prioritizes:
//   - Auto-sequence number ordering (critical for replay)
//   - Idempotent dup append semantics (turn-loop retry tolerance)
//   - Per-session sequence isolation
//   - Prune-before row count + semantic correctness
//   - Full byte-equality vs BASSQLiteEventLogStorage

import XCTest
import Foundation
@testable import BASMemory
@testable import BASRuntimeCore
#if os(iOS) || os(macOS)
import BASRustMemoryTrackerBinary
#endif

#if os(iOS) || os(macOS)
final class BASChapter901EventLogByteEqTests: XCTestCase {

    private func makeTempDBURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "ch901-\(UUID().uuidString).db")
    }

    private func cleanup(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
        try? FileManager.default.removeItem(
            at: URL(fileURLWithPath: url.path + "-wal"))
        try? FileManager.default.removeItem(
            at: URL(fileURLWithPath: url.path + "-shm"))
    }

    private func makeEvent(
        id: String,
        session: String = "sess-default",
        at: Int64 = 1_700_000_000_000,
        kind: BASEventLogKind = .chat,
        risk: BASEventLogRiskBand = .low
    ) -> BASEventLogEntry {
        BASEventLogEntry(
            eventID: id,
            timestampMs: at,
            kind: kind,
            sessionID: session,
            sequenceNumber: 0,  // overwritten by store
            source: "user",
            riskBand: risk,
            confidence: 0.5)
    }

    // MARK: - Auto-sequence semantics

    func testAutoSequenceStartsAtZeroForFreshSession() async throws {
        let url = makeTempDBURL()
        defer { cleanup(url) }
        let routed = try BASRoutedEventLogStorage(
            databaseURL: url)
        let next = await routed.nextSequence(
            forSession: "fresh")
        XCTAssertEqual(next, 0,
            "Fresh session's next sequence must be 0")
    }

    func testAutoSequenceIncrementsPerSession() async throws {
        let url = makeTempDBURL()
        defer { cleanup(url) }
        let routed = try BASRoutedEventLogStorage(
            databaseURL: url)
        let r1 = try await routed.append(
            makeEvent(id: "e1", session: "sA"))
        let r2 = try await routed.append(
            makeEvent(id: "e2", session: "sA"))
        let r3 = try await routed.append(
            makeEvent(id: "e3", session: "sB"))
        XCTAssertEqual(r1.assignedSequenceNumber, 0)
        XCTAssertEqual(r2.assignedSequenceNumber, 1,
            "Second event in same session increments")
        XCTAssertEqual(r3.assignedSequenceNumber, 0,
            "Different session resets to 0")
        XCTAssertTrue(r1.wasNew)
        XCTAssertTrue(r2.wasNew)
        XCTAssertTrue(r3.wasNew)
    }

    // MARK: - Idempotent dup semantics

    func testDuplicateEventIDReturnsExistingSequence() async throws {
        let url = makeTempDBURL()
        defer { cleanup(url) }
        let routed = try BASRoutedEventLogStorage(
            databaseURL: url)
        let r1 = try await routed.append(
            makeEvent(id: "dup-e", at: 100))
        XCTAssertTrue(r1.wasNew)
        XCTAssertEqual(r1.assignedSequenceNumber, 0)
        // Re-append with same event_id but different fields
        // (should be no-op, return original sequence)
        let r2 = try await routed.append(
            makeEvent(id: "dup-e", at: 999,
                kind: .appBehavior))
        XCTAssertFalse(r2.wasNew,
            "Duplicate event_id must return wasNew=false")
        XCTAssertEqual(r2.assignedSequenceNumber, 0,
            "Returned sequence must be the ORIGINAL value")
        let total = await routed.totalCount
        XCTAssertEqual(total, 1,
            "Still only 1 row after dup")
    }

    // MARK: - Prune semantics

    func testPruneBeforeReturnsRowCount() async throws {
        let url = makeTempDBURL()
        defer { cleanup(url) }
        let routed = try BASRoutedEventLogStorage(
            databaseURL: url)
        for i in 0..<5 {
            _ = try await routed.append(
                makeEvent(
                    id: "p\(i)",
                    at: Int64(100 + i * 100)))
        }
        let total = await routed.totalCount
        XCTAssertEqual(total, 5)
        // Prune events with ts < 300 → deletes p0(100) + p1(200)
        let deleted = try await routed.pruneEventsBefore(
            timestampMs: 300)
        XCTAssertEqual(deleted, 2)
        let totalAfter = await routed.totalCount
        XCTAssertEqual(totalAfter, 3)
        // Prune-again returns 0
        let deleted2 = try await routed.pruneEventsBefore(
            timestampMs: 300)
        XCTAssertEqual(deleted2, 0)
    }

    // MARK: - CRITICAL byte-eq vs Swift SQLite actor

    func testByteEqAppendVsSwiftSQLite() async throws {
        let routedURL = makeTempDBURL()
        let swiftURL = makeTempDBURL()
        defer { cleanup(routedURL); cleanup(swiftURL) }
        let routed = try BASRoutedEventLogStorage(
            databaseURL: routedURL)
        let swiftActor = try BASSQLiteEventLogStorage(
            databaseURL: swiftURL)
        let events: [BASEventLogEntry] = [
            makeEvent(id: "be-1", session: "sX", at: 100,
                kind: .chat),
            makeEvent(id: "be-2", session: "sX", at: 200,
                kind: .appBehavior,
                risk: .medium),
            makeEvent(id: "be-3", session: "sY", at: 300,
                kind: .chat),
            makeEvent(id: "be-4", session: "sX", at: 400,
                kind: .substrateAudit,
                risk: .high),
        ]
        for e in events {
            let r = try await routed.append(e)
            let s = try await swiftActor.append(e)
            XCTAssertEqual(r.wasNew, s.wasNew,
                "wasNew byte-eq for event=\(e.eventID)")
            XCTAssertEqual(
                r.assignedSequenceNumber,
                s.assignedSequenceNumber,
                "Assigned sequence byte-eq for event=" +
                e.eventID)
        }
        // Dup append: both must return (false, originalSeq)
        let dupR = try await routed.append(
            makeEvent(id: "be-1", at: 999))
        let dupS = try await swiftActor.append(
            makeEvent(id: "be-1", at: 999))
        XCTAssertEqual(dupR.wasNew, dupS.wasNew)
        XCTAssertFalse(dupR.wasNew)
        XCTAssertEqual(
            dupR.assignedSequenceNumber,
            dupS.assignedSequenceNumber)
        // Total + per-session counts byte-eq
        let rTotal = await routed.totalCount
        let sTotal = await swiftActor.totalCount
        XCTAssertEqual(rTotal, sTotal)
        XCTAssertEqual(rTotal, 4)
        for session in ["sX", "sY", "sMissing"] {
            let r = await routed.countForSession(session)
            let s = await swiftActor.events(
                forSession: session).count
            XCTAssertEqual(r, s,
                "Per-session count byte-eq for s=\(session)")
        }
    }

    func testPruneBeforeByteEqVsSwift() async throws {
        let routedURL = makeTempDBURL()
        let swiftURL = makeTempDBURL()
        defer { cleanup(routedURL); cleanup(swiftURL) }
        let routed = try BASRoutedEventLogStorage(
            databaseURL: routedURL)
        let swiftActor = try BASSQLiteEventLogStorage(
            databaseURL: swiftURL)
        for i in 0..<10 {
            let e = makeEvent(
                id: "pp\(i)",
                at: Int64(100 + i * 100))
            _ = try await routed.append(e)
            _ = try await swiftActor.append(e)
        }
        // Prune at boundary
        let rDel = try await routed.pruneEventsBefore(
            timestampMs: 500)
        let sDel = try await swiftActor.pruneEventsBefore(
            timestampMs: 500)
        XCTAssertEqual(rDel, sDel,
            "Prune row count byte-eq")
        XCTAssertEqual(rDel, 4)  // pp0..pp3 deleted
        // Remaining counts byte-eq
        let rTotal = await routed.totalCount
        let sTotal = await swiftActor.totalCount
        XCTAssertEqual(rTotal, sTotal)
        XCTAssertEqual(rTotal, 6)
    }
}
#endif
