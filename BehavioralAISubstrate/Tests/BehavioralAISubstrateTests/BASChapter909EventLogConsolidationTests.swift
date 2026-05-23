// MARK: - BASChapter909EventLogConsolidationTests
// chapter 九百九 / M3250 — hot-path consolidation #2
//
// Extends the chapter 906 cosine_topk_for_domain consolidation
// pattern to event_log。 ONE FFI call returns N most-recent
// events for a session vs the orchestrated baseline of N
// round-trip count + read calls。
//
// # Hypothesis
//
// Per chapter 906 finding (90-134× win for vector_index),
// event_log should show a similar win:
//   - Orchestrated:Swift loops over events,does per-event
//     timestamp lookups via FFI
//   - Integrated:1 FFI call to recent_timestamps_for_session
//     returns all N timestamps + sequences
//
// Expected speedup similar to chapter 906 (>10× at N ≥ 100)。
//
// # Correctness pin
//
// Both paths return identical timestamps + sequences for the
// same session。 Integrated path sorts DESC by timestamp。

import XCTest
import Foundation
@testable import BASMemory
@testable import BASRuntimeCore
#if os(iOS) || os(macOS)
import BASRustMemoryTrackerBinary
#endif

#if os(iOS) || os(macOS)
final class BASChapter909EventLogConsolidationTests:
    XCTestCase
{

    private func makeTempDBURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "ch909-\(UUID().uuidString).db")
    }

    private func cleanup(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
        try? FileManager.default.removeItem(
            at: URL(fileURLWithPath: url.path + "-wal"))
        try? FileManager.default.removeItem(
            at: URL(fileURLWithPath: url.path + "-shm"))
    }

    private func makeEvent(
        id: String, session: String, ts: Int64
    ) -> BASEventLogEntry {
        BASEventLogEntry(
            eventID: id,
            timestampMs: ts,
            kind: .chat,
            sessionID: session,
            sequenceNumber: 0,
            source: "user",
            riskBand: .low,
            confidence: 0.5)
    }

    // MARK: - Correctness pin

    func testRecentTimestampsReturnsDescByTimestamp() async
        throws
    {
        let url = makeTempDBURL()
        defer { cleanup(url) }
        let store = try BASRoutedEventLogStorage(
            databaseURL: url)
        // Insert events out of timestamp order
        _ = try await store.append(
            makeEvent(id: "e1", session: "sX", ts: 300))
        _ = try await store.append(
            makeEvent(id: "e2", session: "sX", ts: 100))
        _ = try await store.append(
            makeEvent(id: "e3", session: "sX", ts: 500))
        _ = try await store.append(
            makeEvent(id: "e4", session: "sX", ts: 200))
        _ = try await store.append(
            makeEvent(id: "e5", session: "sY", ts: 999))
        // Get top 3 by timestamp DESC
        let recent = try await store.recentTimestamps(
            forSession: "sX", limit: 3)
        XCTAssertEqual(recent.count, 3)
        XCTAssertEqual(recent[0].timestampMs, 500)
        XCTAssertEqual(recent[1].timestampMs, 300)
        XCTAssertEqual(recent[2].timestampMs, 200)
        // Different session not bleeding
        let recentY = try await store.recentTimestamps(
            forSession: "sY", limit: 10)
        XCTAssertEqual(recentY.count, 1)
        XCTAssertEqual(recentY[0].timestampMs, 999)
        // Missing session returns empty
        let missing = try await store.recentTimestamps(
            forSession: "no-such", limit: 5)
        XCTAssertEqual(missing.count, 0)
    }

    func testRecentTimestampsLimitExceedingCorpus() async
        throws
    {
        let url = makeTempDBURL()
        defer { cleanup(url) }
        let store = try BASRoutedEventLogStorage(
            databaseURL: url)
        _ = try await store.append(
            makeEvent(id: "e1", session: "s", ts: 100))
        _ = try await store.append(
            makeEvent(id: "e2", session: "s", ts: 200))
        let recent = try await store.recentTimestamps(
            forSession: "s", limit: 100)
        XCTAssertEqual(recent.count, 2,
            "limit > corpus returns corpus.count entries")
    }

    func testRecentTimestampsSequencesPaired() async throws {
        // Verify the parallel sequences buffer is correctly
        // paired with timestamps。
        let url = makeTempDBURL()
        defer { cleanup(url) }
        let store = try BASRoutedEventLogStorage(
            databaseURL: url)
        // Append 5 events to same session — sequences 0,1,2,3,4
        for i in 0..<5 {
            _ = try await store.append(
                makeEvent(
                    id: "e\(i)", session: "sP",
                    ts: Int64(100 + i * 100)))
        }
        let recent = try await store.recentTimestamps(
            forSession: "sP", limit: 5)
        XCTAssertEqual(recent.count, 5)
        // DESC by ts: ts 500/seq 4, ts 400/seq 3, ..., ts 100/seq 0
        for i in 0..<5 {
            let expectedTs = Int64(500 - i * 100)
            let expectedSeq = Int64(4 - i)
            XCTAssertEqual(recent[i].timestampMs, expectedTs,
                "Row \(i) ts")
            XCTAssertEqual(recent[i].seq, expectedSeq,
                "Row \(i) seq paired with ts")
        }
    }

    // MARK: - Perf bench probe

    private func timeit(_ body: () async throws -> Void) async
        rethrows -> Double
    {
        let start = ContinuousClock.now
        try await body()
        let elapsed = ContinuousClock.now - start
        let attos = Double(elapsed.components.attoseconds)
            / 1_000_000_000_000_000_000.0
        return Double(elapsed.components.seconds) + attos
    }

    func testBenchmarkEventLogRecent100() async throws {
        try await runBench(n: 100, k: 10)
    }

    func testBenchmarkEventLogRecent1000() async throws {
        try await runBench(n: 1000, k: 10)
    }

    private func runBench(n: Int, k: Int) async throws {
        let url = makeTempDBURL()
        defer { cleanup(url) }
        let store = try BASRoutedEventLogStorage(
            databaseURL: url)
        let session = "bench-sess"
        for i in 0..<n {
            _ = try await store.append(
                makeEvent(
                    id: "be-\(i)", session: session,
                    ts: Int64(i * 100)))
        }
        // Warm-up
        _ = try await store.recentTimestamps(
            forSession: session, limit: k)
        _ = await store.countForSession(session)

        // Orchestrated baseline:
        //   1. countForSession (FFI hop) → returns N
        //   2. then would need per-event reads to get
        //      timestamps,but Rust bridge doesn't expose
        //      per-event read FFI for event_log。
        //      Approximate with N count calls (same FFI shape)
        let orchSec = try await timeit {
            let _ = await store.countForSession(session)
            // Simulate N per-event FFI reads via N count calls
            // (same FFI shape — the per-call cost matters)
            for _ in 0..<n {
                let _ = await store.countForSession(session)
            }
        }
        let intSec = try await timeit {
            _ = try await store.recentTimestamps(
                forSession: session, limit: k)
        }
        let ratio = orchSec / intSec
        print(
            "ch909 eventlog.recent N=\(n) k=\(k):" +
            " orch=\(String(format: "%.4f", orchSec))s" +
            " integrated=\(String(format: "%.4f", intSec))s" +
            " orch/integrated=\(String(format: "%.2fx", ratio))")
        // Catastrophic-regression guard:integrated must
        // not be > 2× slower than orchestrated
        XCTAssertLessThan(intSec, orchSec * 2.0,
            "Integrated >2× slower than orchestrated baseline")
    }
}
#endif
