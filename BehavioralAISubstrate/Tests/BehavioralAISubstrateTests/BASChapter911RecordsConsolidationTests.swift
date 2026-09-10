// MARK: - BASChapter911RecordsConsolidationTests
// chapter 九百十一 / M3260 — hot-path consolidation #3
//
// Applies the chapter 906/909 hot-path consolidation pattern
// to memory_usage_records:ONE FFI call returns the N most-
// recent records for an atom_id as parallel
// (timestampMs, helpedFlag) tuples sorted DESC by timestamp。
//
// # Hypothesis
//
// Per chapters 906 (90-134×) + 909 (17-102×),the pattern
// should generalize to records with a similar wide-band win
// at production session sizes。

import XCTest
import Foundation
@testable import BASMemory
@testable import BASRuntimeCore
#if os(iOS) || os(macOS)
import BASRustMemoryTrackerBinary
#endif

#if os(iOS) || os(macOS)
final class BASChapter911RecordsConsolidationTests: XCTestCase
{

    private func makeTempDBURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "ch911-\(UUID().uuidString).db")
    }

    private func cleanup(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
        try? FileManager.default.removeItem(
            at: URL(fileURLWithPath: url.path + "-wal"))
        try? FileManager.default.removeItem(
            at: URL(fileURLWithPath: url.path + "-shm"))
    }

    // MARK: - Correctness pin

    func testRecentRecordsReturnsDescByTimestamp() async
        throws
    {
        let url = makeTempDBURL()
        defer { cleanup(url) }
        let store = try BASRoutedMemoryUsageRecordsStore(
            databaseURL: url)
        // 4 records for atom-X with varying ts + helped flags
        let date100 = Date(timeIntervalSince1970: 100)
        let date200 = Date(timeIntervalSince1970: 200)
        let date300 = Date(timeIntervalSince1970: 300)
        let date500 = Date(timeIntervalSince1970: 500)
        _ = try await store.upsertRecord(
            recordID: "r1", atomID: "atom-X",
            retrievedAt: date100,
            sessionRef: "s", turnRef: "t",
            permitMode: "p", helpedState: "unknown")
        _ = try await store.upsertRecord(
            recordID: "r2", atomID: "atom-X",
            retrievedAt: date300,
            sessionRef: "s", turnRef: "t",
            permitMode: "p", helpedState: "helped")
        _ = try await store.upsertRecord(
            recordID: "r3", atomID: "atom-X",
            retrievedAt: date200,
            sessionRef: "s", turnRef: "t",
            permitMode: "p", helpedState: "notHelped")
        _ = try await store.upsertRecord(
            recordID: "r4", atomID: "atom-X",
            retrievedAt: date500,
            sessionRef: "s", turnRef: "t",
            permitMode: "p", helpedState: "helped")
        // Different atom (must not bleed)
        _ = try await store.upsertRecord(
            recordID: "y1", atomID: "atom-Y",
            retrievedAt: Date(timeIntervalSince1970: 999),
            sessionRef: "s", turnRef: "t",
            permitMode: "p", helpedState: "unknown")
        // Top 3 by ts DESC: 500/helped, 300/helped, 200/notHelped
        let top = try await store.recentRecords(
            forAtomID: "atom-X", limit: 3)
        XCTAssertEqual(top.count, 3)
        XCTAssertEqual(top[0].timestampMs, 500_000)
        XCTAssertEqual(top[0].helped, "helped")
        XCTAssertEqual(top[1].timestampMs, 300_000)
        XCTAssertEqual(top[1].helped, "helped")
        XCTAssertEqual(top[2].timestampMs, 200_000)
        XCTAssertEqual(top[2].helped, "notHelped")
        // atom-Y isolated
        let y = try await store.recentRecords(
            forAtomID: "atom-Y", limit: 10)
        XCTAssertEqual(y.count, 1)
        XCTAssertEqual(y[0].timestampMs, 999_000)
        XCTAssertEqual(y[0].helped, "unknown")
        // missing atom
        let m = try await store.recentRecords(
            forAtomID: "atom-missing", limit: 5)
        XCTAssertEqual(m.count, 0)
    }

    func testRecentRecordsLimitExceedingCorpus() async throws {
        let url = makeTempDBURL()
        defer { cleanup(url) }
        let store = try BASRoutedMemoryUsageRecordsStore(
            databaseURL: url)
        _ = try await store.upsertRecord(
            recordID: "r1", atomID: "a",
            retrievedAt: Date(timeIntervalSince1970: 100),
            sessionRef: "s", turnRef: "t",
            permitMode: "p", helpedState: "helped")
        let top = try await store.recentRecords(
            forAtomID: "a", limit: 100)
        XCTAssertEqual(top.count, 1)
    }

    // MARK: - Perf bench

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

    func testBenchmarkRecordsRecent100() async throws {
        try await runBench(n: 100, k: 10)
    }

    func testBenchmarkRecordsRecent1000() async throws {
        try await runBench(n: 1000, k: 10)
    }

    private func runBench(n: Int, k: Int) async throws {
        let url = makeTempDBURL()
        defer { cleanup(url) }
        let store = try BASRoutedMemoryUsageRecordsStore(
            databaseURL: url)
        let atom = "bench-atom"
        for i in 0..<n {
            _ = try await store.upsertRecord(
                recordID: "br-\(i)", atomID: atom,
                retrievedAt: Date(
                    timeIntervalSince1970: Double(i * 10)),
                sessionRef: "s", turnRef: "t",
                permitMode: "p", helpedState: "unknown")
        }
        // Warm-up
        _ = try await store.recentRecords(
            forAtomID: atom, limit: k)
        _ = await store.usageCount(forAtomID: atom)

        // chapter 九百十六 / M3285 honesty fix H3:
        // ORCHESTRATED = N usageCount FFI hops。 NOT
        // apples-to-apples with「Swift would do N per-row
        // reads + compute」 — that alternative requires per-
        // record read FFI which doesn't exist in the bridge。
        // Measures FFI-hop reduction,not end-to-end speedup。
        let orchSec = await timeit {
            for _ in 0..<n {
                let _ = await store.usageCount(
                    forAtomID: atom)
            }
        }
        let intSec = try await timeit {
            _ = try await store.recentRecords(
                forAtomID: atom, limit: k)
        }
        let ratio = orchSec / intSec
        print(
            "ch911 records.recent N=\(n) k=\(k):" +
            " orch=\(String(format: "%.4f", orchSec))s" +
            " integrated=\(String(format: "%.4f", intSec))s" +
            " ffi-hop-reduction=\(String(format: "%.2fx", ratio))" +
            " [measures FFI overhead × N collapsed to 1," +
            " NOT end-to-end speedup]")
        // chapter 九百十六 fix H11:absolute wall-clock guard
        let absoluteBudgetSec: Double = n <= 100
            ? 0.005 : 0.020
        XCTAssertLessThan(intSec, absoluteBudgetSec,
            "Integrated time \(intSec)s exceeds budget " +
            "\(absoluteBudgetSec)s for N=\(n)")
        XCTAssertLessThan(intSec, orchSec,
            "Integrated must be faster than N FFI hops")
    }
}
#endif
