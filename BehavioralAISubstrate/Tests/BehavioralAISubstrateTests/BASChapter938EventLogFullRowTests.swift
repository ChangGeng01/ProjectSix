// MARK: - BASChapter938EventLogFullRowTests
// chapter 九百三十八 / M3395
//
// FINAL SUBSTANCE chapter post-USER-PASS (ch 933) — EventLog
// bridge had events(forSession:) + events(sinceTimestampMs:
// limit:) as `return []` stubs since chapter 901。 This is the
// 5th and last bridge that needed full-row implementation per
// the ch 933 stub list。
//
// Simplest variant of the recipe:append stores the entire
// BASEventLogEntry as payload_json (format=1),so read-back just
// concatenates payload_json values into a JSON array。 No
// per-column reconstruction,no base64 encoding。 Format=2 BLOB
// rows are filtered out (can't Codable-decode binary)。

import XCTest
import BASRuntimeCore
@testable import BASMemory

final class BASChapter938EventLogFullRowTests: XCTestCase {

    private func makeTempDBURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "ch938-\(UUID().uuidString).sqlite")
    }

    private func cleanup(_ url: URL) {
        let fm = FileManager.default
        for suffix in ["", "-wal", "-shm"] {
            let p = url.path + suffix
            if fm.fileExists(atPath: p) {
                try? fm.removeItem(atPath: p)
            }
        }
    }

    private func makeEntry(
        _ eid: String,
        sessionID: String = "s1",
        timestampMs: Int64 = 1_000,
        kind: BASEventLogKind = .chat
    ) -> BASEventLogEntry {
        BASEventLogEntry(
            eventID: eid,
            timestampMs: timestampMs,
            kind: kind,
            sessionID: sessionID,
            sequenceNumber: 0,  // storage assigns
            source: "test",
            intent: "ask_question",
            riskBand: .low,
            memoryRefs: ["atom-1", "atom-2"],
            actions: ["permit:answer"],
            confidence: 0.85)
    }

    /// events(forSession:) round-trip — if reverted to stub,
    /// fails on count assertion。 chapter 九百四十一 / M3410 fix
    /// HIGH:added sequenceNumber assertions to catch the
    /// cross-actor seq divergence (Rust assigns seq column,
    /// payload_json had「sequenceNumber:0」 baked in → without
    /// the ch 941 splice fix,read-back would return seq=0 for
    /// every event)。
    func testEventsForSessionRoundTrip() async throws {
        let url = makeTempDBURL()
        defer { cleanup(url) }
        let store = try BASRoutedEventLogStorage(
            databaseURL: url)
        let e1 = makeEntry("rt-1",
            sessionID: "sess-A", timestampMs: 1_000)
        let e2 = makeEntry("rt-2",
            sessionID: "sess-A", timestampMs: 2_000)
        let r1 = try await store.append(e1)
        let r2 = try await store.append(e2)
        // Append return assigns Rust-side seqs 0 and 1
        XCTAssertEqual(r1.assignedSequenceNumber, 0)
        XCTAssertEqual(r2.assignedSequenceNumber, 1)

        let read = await store.events(forSession: "sess-A")
        XCTAssertEqual(read.count, 2,
            "events(forSession:) must return both " +
            "(REGRESSION: if 0, ch 938 fix reverted to stub)")
        XCTAssertEqual(read[0].eventID, "rt-1")
        XCTAssertEqual(read[1].eventID, "rt-2")
        XCTAssertEqual(read[0].source, "test")
        XCTAssertEqual(read[0].intent, "ask_question")
        XCTAssertEqual(read[0].memoryRefs, ["atom-1", "atom-2"])
        XCTAssertEqual(read[0].actions, ["permit:answer"])
        XCTAssertEqual(read[0].confidence, 0.85, accuracy: 0.001)
        // chapter 九百四十一 / M3410 — splice-correctness
        // assertions。 Without the ch 941 splice fix,both
        // entries would have sequenceNumber=0 (baked in at
        // encode time)。
        XCTAssertEqual(read[0].sequenceNumber, 0,
            "rt-1 must report its Rust-assigned seq=0 " +
            "(REGRESSION: ch 941 splice missing)")
        XCTAssertEqual(read[1].sequenceNumber, 1,
            "rt-2 must report its Rust-assigned seq=1 " +
            "(REGRESSION: ch 941 splice missing — payload_json " +
            "still has sequenceNumber:0 baked in at encode time)")
    }

    func testEventsForSessionEmpty() async throws {
        let url = makeTempDBURL()
        defer { cleanup(url) }
        let store = try BASRoutedEventLogStorage(
            databaseURL: url)
        let read = await store.events(forSession: "no-sess")
        XCTAssertEqual(read.count, 0)
    }

    /// events(sinceTimestampMs:limit:) filtering + ordering +
    /// limit enforcement
    func testEventsSinceTimestampLimitAndOrder() async throws {
        let url = makeTempDBURL()
        defer { cleanup(url) }
        let store = try BASRoutedEventLogStorage(
            databaseURL: url)
        for i in 0..<5 {
            _ = try await store.append(makeEntry(
                "ts-\(i)",
                sessionID: "ts-sess",
                timestampMs: Int64(1_000 + i * 100)))
        }
        // since=1200 → expect 3 entries (ts-2, ts-3, ts-4)
        let read = await store.events(
            sinceTimestampMs: 1_200, limit: 100)
        XCTAssertEqual(read.count, 3)
        XCTAssertEqual(read.map { $0.eventID },
                       ["ts-2", "ts-3", "ts-4"])

        // limit=2 → only first 2
        let limited = await store.events(
            sinceTimestampMs: 1_200, limit: 2)
        XCTAssertEqual(limited.count, 2)
        XCTAssertEqual(limited.map { $0.eventID },
                       ["ts-2", "ts-3"])
    }

    /// Session-isolation: events(forSession:) for A doesn't
    /// see B
    func testEventsForSessionIsolation() async throws {
        let url = makeTempDBURL()
        defer { cleanup(url) }
        let store = try BASRoutedEventLogStorage(
            databaseURL: url)
        _ = try await store.append(makeEntry(
            "iso-A1", sessionID: "iso-sess-A"))
        _ = try await store.append(makeEntry(
            "iso-B1", sessionID: "iso-sess-B"))
        let a = await store.events(forSession: "iso-sess-A")
        let b = await store.events(forSession: "iso-sess-B")
        XCTAssertEqual(a.map { $0.eventID }, ["iso-A1"])
        XCTAssertEqual(b.map { $0.eventID }, ["iso-B1"])
    }

    /// limit cap discipline:Int.max should not abort,clamps
    /// to MAX_HOTPATH_LIMIT (100_000)
    func testEventsSinceTimestampLimitCapEnforced() async throws {
        let url = makeTempDBURL()
        defer { cleanup(url) }
        let store = try BASRoutedEventLogStorage(
            databaseURL: url)
        _ = try await store.append(makeEntry(
            "cap-1", timestampMs: 100))
        // Int.max limit must not abort the Rust Vec allocation
        let read = await store.events(
            sinceTimestampMs: 0, limit: Int.max)
        XCTAssertEqual(read.count, 1)
        XCTAssertEqual(read[0].eventID, "cap-1")
    }
}
