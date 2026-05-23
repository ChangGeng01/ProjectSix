// MARK: - BASChapter902_5MemoryUsageLogsByteEqTests
// chapter 九百二.5 / M3205 — replay_log + audit_log byte-eq pin
//
// Sub-chapter 2 of MemoryUsageTracker migration。 Covers:
//   - replay_log append + count + latest-time parity
//   - audit_log append + count + latest-time parity
//   - dup-PK behaviour (both stores reject)
//   - Mixed-table independence (replay and audit don't bleed)

import XCTest
import Foundation
@testable import BASMemory
@testable import BASRuntimeCore
#if os(iOS) || os(macOS)
import BASRustMemoryTrackerBinary
#endif

#if os(iOS) || os(macOS)
final class BASChapter902_5MemoryUsageLogsByteEqTests:
    XCTestCase
{

    private func makeTempDBURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "ch902-5-\(UUID().uuidString).db")
    }

    private func cleanup(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
        try? FileManager.default.removeItem(
            at: URL(fileURLWithPath: url.path + "-wal"))
        try? FileManager.default.removeItem(
            at: URL(fileURLWithPath: url.path + "-shm"))
    }

    // MARK: - Native replay log

    func testReplayLogAppendAndCount() async throws {
        let url = makeTempDBURL()
        defer { cleanup(url) }
        let routed = try BASRoutedMemoryUsageLogsStore(
            databaseURL: url)
        _ = try await routed.appendReplayLog(
            eventID: "e1", eventType: "txt",
            payload: "p1",
            recordedAt: Date(timeIntervalSince1970: 100))
        _ = try await routed.appendReplayLog(
            eventID: "e2", eventType: "act",
            payload: "p2",
            recordedAt: Date(timeIntervalSince1970: 500))
        _ = try await routed.appendReplayLog(
            eventID: "e3", eventType: "txt",
            payload: "p3",
            recordedAt: Date(timeIntervalSince1970: 300))
        let count = await routed.replayLogCount
        XCTAssertEqual(count, 3)
        let latest = await routed.latestReplayLogTimeMs
        // Apple boundary multiplies seconds × 1000 → max=500_000 ms。
        XCTAssertEqual(latest, 500_000,
            "Latest time = MAX(recorded_at_ms)")
    }

    func testReplayLogDuplicateEventIDThrows() async throws {
        let url = makeTempDBURL()
        defer { cleanup(url) }
        let routed = try BASRoutedMemoryUsageLogsStore(
            databaseURL: url)
        _ = try await routed.appendReplayLog(
            eventID: "dup", eventType: "t",
            payload: "p",
            recordedAt: Date(timeIntervalSince1970: 100))
        do {
            _ = try await routed.appendReplayLog(
                eventID: "dup", eventType: "t",
                payload: "p2",
                recordedAt: Date(timeIntervalSince1970: 200))
            XCTFail("Duplicate eventID must throw")
        } catch let e as BASRoutedMemoryUsageLogsStore
            .StoreError
        {
            switch e {
            case .appendFailed(let table, let code):
                XCTAssertEqual(table, "replay_log")
                XCTAssertEqual(code, -2,
                    "SQLite UNIQUE error → -2")
            default:
                XCTFail("Wrong error case: \(e)")
            }
        }
        // Count unchanged
        let count = await routed.replayLogCount
        XCTAssertEqual(count, 1)
    }

    // MARK: - Native audit log

    func testAuditLogAppendAndCount() async throws {
        let url = makeTempDBURL()
        defer { cleanup(url) }
        let routed = try BASRoutedMemoryUsageLogsStore(
            databaseURL: url)
        _ = try await routed.appendAuditLog(
            entryID: "a1", actor: "actor1",
            action: "view", detail: "d1",
            recordedAt: Date(timeIntervalSince1970: 100))
        _ = try await routed.appendAuditLog(
            entryID: "a2", actor: "actor2",
            action: "edit", detail: "d2",
            recordedAt: Date(timeIntervalSince1970: 400))
        let count = await routed.auditLogCount
        XCTAssertEqual(count, 2)
        let latest = await routed.latestAuditLogTimeMs
        // Apple boundary multiplies seconds × 1000 → 400 → 400_000 ms。
        XCTAssertEqual(latest, 400_000)
    }

    // MARK: - Independence

    func testReplayAndAuditAreIndependentTables() async throws {
        let url = makeTempDBURL()
        defer { cleanup(url) }
        let routed = try BASRoutedMemoryUsageLogsStore(
            databaseURL: url)
        _ = try await routed.appendReplayLog(
            eventID: "r1", eventType: "t", payload: "p",
            recordedAt: Date(timeIntervalSince1970: 100))
        _ = try await routed.appendReplayLog(
            eventID: "r2", eventType: "t", payload: "p",
            recordedAt: Date(timeIntervalSince1970: 200))
        _ = try await routed.appendAuditLog(
            entryID: "a1", actor: "x", action: "y",
            detail: "z",
            recordedAt: Date(timeIntervalSince1970: 300))
        let rc = await routed.replayLogCount
        let ac = await routed.auditLogCount
        XCTAssertEqual(rc, 2)
        XCTAssertEqual(ac, 1)
    }

    // MARK: - Byte-equality vs Swift BASMemoryUsageTracker

    func testByteEqReplayLogCountVsSwift() async throws {
        // Both stores must agree on the row count after the
        // same insert pattern。 The Swift actor mints its own
        // eventID,but COUNT is independent of the ID,so we
        // drive both with N records and compare totals。
        let routedURL = makeTempDBURL()
        let swiftURL = makeTempDBURL()
        defer { cleanup(routedURL); cleanup(swiftURL) }
        let routed = try BASRoutedMemoryUsageLogsStore(
            databaseURL: routedURL)
        let swiftActor = try BASMemoryUsageTracker(
            databaseURL: swiftURL)
        for i in 0..<8 {
            let date = Date(
                timeIntervalSince1970: Double(100 + i * 50))
            _ = try await routed.appendReplayLog(
                eventID: "be-r-\(i)",
                eventType: "kind-\(i % 3)",
                payload: "payload-\(i)",
                recordedAt: date)
            _ = try await swiftActor.appendReplayLog(
                eventType: "kind-\(i % 3)",
                payload: "payload-\(i)",
                recordedAt: date)
        }
        let rTotal = await routed.replayLogCount
        let sTotal = try await swiftActor
            .replayLogEntriesViaSQL().count
        XCTAssertEqual(rTotal, sTotal)
        XCTAssertEqual(rTotal, 8)
        // Latest time parity (Rust = max, Swift returns ASC
        // sorted array → last element's timestamp)
        let rLatest = await routed.latestReplayLogTimeMs
        let sLatest = (try await swiftActor
            .replayLogEntriesViaSQL()).last?.recordedAtMs
        XCTAssertEqual(rLatest, sLatest)
    }

    func testByteEqAuditLogCountVsSwift() async throws {
        let routedURL = makeTempDBURL()
        let swiftURL = makeTempDBURL()
        defer { cleanup(routedURL); cleanup(swiftURL) }
        let routed = try BASRoutedMemoryUsageLogsStore(
            databaseURL: routedURL)
        let swiftActor = try BASMemoryUsageTracker(
            databaseURL: swiftURL)
        for i in 0..<5 {
            let date = Date(
                timeIntervalSince1970: Double(1000 + i * 200))
            _ = try await routed.appendAuditLog(
                entryID: "be-a-\(i)",
                actor: "actor-\(i % 2)",
                action: "do-\(i)",
                detail: "det-\(i)",
                recordedAt: date)
            _ = try await swiftActor.appendAuditLog(
                actor: "actor-\(i % 2)",
                action: "do-\(i)",
                detail: "det-\(i)",
                recordedAt: date)
        }
        let rTotal = await routed.auditLogCount
        let sTotal = try await swiftActor
            .auditLogEntriesViaSQL().count
        XCTAssertEqual(rTotal, sTotal)
        XCTAssertEqual(rTotal, 5)
        let rLatest = await routed.latestAuditLogTimeMs
        let sLatest = (try await swiftActor
            .auditLogEntriesViaSQL()).last?.recordedAtMs
        XCTAssertEqual(rLatest, sLatest)
    }
}
#endif
