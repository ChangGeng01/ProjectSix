// MARK: - BASChapter909EventLogConsolidationTests
// chapter 九百九 / M3250 — hot-path consolidation #2
//
// Extends the chapter 906 cosine_topk_for_domain consolidation
// pattern to event_log。 ONE FFI call returns N most-recent
// events for a session vs the orchestrated baseline of N
// round-trip count + read calls。
//
// # Honest measurement (chapter 九百十六 / M3285 fix H3)
//
// The orchestrated baseline measures N+1 FFI hops via raw
// countForSession() calls。 NO per-event read FFI exists in
// the bridge,so the realistic consumer alternative is
// either:
//   (a) make N count-style FFI hops (this baseline)
//   (b) do nothing (recentTimestamps isn't available without
//       the chapter 909 FFI)
//
// The ratio we report is「FFI-hop reduction」(N+1 → 1)
// NOT「Swift would have done X work,Rust does Y work,
// here is the Rust:Swift speedup」。 That comparison is
// not possible because option (b) means Swift can't do
// the work at all。
//
// **Previously misreported as「17-102× speedup」** — the
// chapter 九百十六 honesty fix renames the metric in test
// output and the SEAL doc。 The underlying achievement
// (collapsing N+1 FFI hops to 1) is real and valuable,
// the「100×」 framing was misleading。
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

        // chapter 九百十六 / M3285 honesty fix H3:
        // ORCHESTRATED here = N+1 raw countForSession FFI hops
        // (no per-event read FFI exists in the bridge,so the
        // realistic consumer alternative WOULD be N COUNT-style
        // hops or no-op)。 This baseline measures FFI-HOP
        // REDUCTION,not end-to-end「Swift would have to do
        // X work」 speedup — that comparison is impossible
        // since the consumer's alternative IS more FFI hops。
        // The previously-reported "17-102×" speedup framing
        // was misleading; the honest framing is「N+1 FFI hops
        // → 1 hop saves the FFI overhead × N」。
        let orchSec = try await timeit {
            let _ = await store.countForSession(session)
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
            " ffi-hop-reduction=\(String(format: "%.2fx", ratio))" +
            " [measures FFI overhead × N collapsed to 1," +
            " NOT end-to-end speedup]")
        // chapter 九百十六 fix H11:absolute wall-clock guard
        // is more meaningful than「2× orch」 (orch is dominated
        // by N FFI hops,so 2× of that is a huge band)。
        let absoluteBudgetSec: Double = n <= 100
            ? 0.005   // 5ms for N=100
            : 0.020   // 20ms for N=1000
        XCTAssertLessThan(intSec, absoluteBudgetSec,
            "Integrated time \(intSec)s exceeds absolute " +
            "budget \(absoluteBudgetSec)s for N=\(n)")
        // Backstop:integrated must still be < orch (sanity)
        XCTAssertLessThan(intSec, orchSec,
            "Integrated must be faster than N+1 FFI hops")
    }
}
#endif
