// MARK: - BASChapter905StorePerfBenchmarkTests
// chapter 九百五 / M3225 — LIVE perf benchmark of Swift vs Rust
//
// Per the L8 unification RFC's flip-or-decline discipline,this
// chapter captures LIVE per-store throughput at production-shape
// workloads so chapter 906 can make a data-driven flip decision
// rather than ship a hope-based default flip。
//
// # What's measured
//
// Per-store comparison Swift SQLite actor vs Rust-routed bridge:
//   - BASMemoryUsageTracker.record() vs BASRoutedMemoryUsage-
//     TrackerStore.record() (per-retrieval write hot path)
//   - BASSQLiteEventLogStorage.append() vs BASRoutedEventLog-
//     Storage.append() (per-turn event log hot path)
//   - BASHostConstitutionSQLiteStorage.save() vs BASRouted-
//     HostConstitutionVaultStorage.save() (per-vault snapshot)
//
// At each workload N ∈ {100, 1000} the test prints a perf
// scorecard and asserts the result is NOT silently regressed
// (Rust within 5× of Swift either way is considered OK for
// chapter 905 — we only DECLINE-WITH-TRIGGER if Rust is
// catastrophically slower)。 Chapter 906 uses these numbers
// to make the flip-or-decline decision per the chapter 870
// 整体 性能 一定要 更好 discipline。
//
// # Discipline pins
//
// - Tests are MARKED as benchmark via testBenchmark prefix;
//   skipped by default in fast-loop CI per existing convention
// - Uses ContinuousClock for monotonic wall-clock timing
// - Per-store cold start excluded from measurement (init time
//   = first 2 inserts are warm-up)

import XCTest
import Foundation
@testable import BASMemory
@testable import BASRuntimeCore
#if os(iOS) || os(macOS)
import BASRustMemoryTrackerBinary
#endif

#if os(iOS) || os(macOS)
final class BASChapter905StorePerfBenchmarkTests: XCTestCase {

    private func makeTempDBURL(_ tag: String) -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "ch905-\(tag)-\(UUID().uuidString).db")
    }

    private func cleanup(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
        try? FileManager.default.removeItem(
            at: URL(fileURLWithPath: url.path + "-wal"))
        try? FileManager.default.removeItem(
            at: URL(fileURLWithPath: url.path + "-shm"))
    }

    /// Generic timing helper。 Returns elapsed seconds for
    /// `body`,which is invoked synchronously。
    private func timeit(_ body: () async throws -> Void) async
        rethrows -> Double
    {
        let start = ContinuousClock.now
        try await body()
        let elapsed = ContinuousClock.now - start
        // Convert duration to seconds (microseconds / 1e6)
        let ms = Double(elapsed.components.attoseconds)
            / 1_000_000_000_000_000_000.0
        let sec = Double(elapsed.components.seconds) + ms
        return sec
    }

    // MARK: - MemoryUsageTracker.record() throughput

    func testBenchmarkRecordRoundTrip100() async throws {
        try await runRecordBenchmark(n: 100)
    }

    func testBenchmarkRecordRoundTrip1000() async throws {
        try await runRecordBenchmark(n: 1000)
    }

    private func runRecordBenchmark(n: Int) async throws {
        let swiftURL = makeTempDBURL("swift-rec")
        let rustURL = makeTempDBURL("rust-rec")
        defer { cleanup(swiftURL); cleanup(rustURL) }

        let swiftActor = try BASMemoryUsageTracker(
            databaseURL: swiftURL)
        let rustActor = try BASRoutedMemoryUsageTrackerStore(
            databaseURL: rustURL)

        // Warm-up: 2 inserts each (excludes JIT / FFI lazy init)
        for _ in 0..<2 {
            _ = try await swiftActor.record(
                atomID: "warm", sessionRef: "w",
                turnRef: "w", permitMode: "p")
            _ = try await rustActor.record(
                atomID: "warm", sessionRef: "w",
                turnRef: "w", permitMode: "p")
        }

        let swiftSec = try await timeit {
            for i in 0..<n {
                _ = try await swiftActor.record(
                    atomID: "atom-\(i % 50)",
                    sessionRef: "sess-\(i % 10)",
                    turnRef: "turn-\(i)",
                    permitMode: "permitted")
            }
        }
        let rustSec = try await timeit {
            for i in 0..<n {
                _ = try await rustActor.record(
                    atomID: "atom-\(i % 50)",
                    sessionRef: "sess-\(i % 10)",
                    turnRef: "turn-\(i)",
                    permitMode: "permitted")
            }
        }
        let ratio = swiftSec / rustSec
        print(
            "ch905 record N=\(n):" +
            " swift=\(String(format: "%.4f", swiftSec))s" +
            " rust=\(String(format: "%.4f", rustSec))s" +
            " swift/rust=\(String(format: "%.2fx", ratio))")
        // Soft assertion:Rust must not be catastrophically
        // slower (>5×) at production sizes。 If this fails,
        // DECLINE-WITH-TRIGGER doc per chapter 881 + 890 model。
        XCTAssertLessThan(rustSec, swiftSec * 5.0,
            "Rust >5x slower than Swift = catastrophic regression")
    }

    // MARK: - EventLog.append() throughput

    func testBenchmarkEventLogAppend100() async throws {
        try await runEventLogBenchmark(n: 100)
    }

    func testBenchmarkEventLogAppend1000() async throws {
        try await runEventLogBenchmark(n: 1000)
    }

    private func runEventLogBenchmark(n: Int) async throws {
        let swiftURL = makeTempDBURL("swift-evt")
        let rustURL = makeTempDBURL("rust-evt")
        defer { cleanup(swiftURL); cleanup(rustURL) }

        let swiftActor = try BASSQLiteEventLogStorage(
            databaseURL: swiftURL)
        let rustActor = try BASRoutedEventLogStorage(
            databaseURL: rustURL)

        func makeEntry(_ i: Int) -> BASEventLogEntry {
            BASEventLogEntry(
                eventID: "evt-\(i)-\(UUID().uuidString)",
                timestampMs: 1_700_000_000_000 + Int64(i),
                kind: .chat,
                sessionID: "sess-\(i % 10)",
                sequenceNumber: 0,
                source: "user",
                riskBand: .low,
                confidence: 0.5)
        }

        // Warm-up
        for i in 0..<2 {
            _ = try await swiftActor.append(makeEntry(9000+i))
            _ = try await rustActor.append(makeEntry(9100+i))
        }

        let swiftSec = try await timeit {
            for i in 0..<n {
                _ = try await swiftActor.append(makeEntry(i))
            }
        }
        let rustSec = try await timeit {
            for i in 0..<n {
                _ = try await rustActor.append(
                    makeEntry(n + i))
            }
        }
        let ratio = swiftSec / rustSec
        print(
            "ch905 eventlog.append N=\(n):" +
            " swift=\(String(format: "%.4f", swiftSec))s" +
            " rust=\(String(format: "%.4f", rustSec))s" +
            " swift/rust=\(String(format: "%.2fx", ratio))")
        XCTAssertLessThan(rustSec, swiftSec * 5.0)
    }

    // MARK: - HostConstitution.save() throughput

    func testBenchmarkVaultSave100() async throws {
        let swiftURL = makeTempDBURL("swift-vlt")
        let rustURL = makeTempDBURL("rust-vlt")
        defer { cleanup(swiftURL); cleanup(rustURL) }

        let swiftActor = try BASHostConstitutionSQLiteStorage(
            databaseURL: swiftURL)
        let rustActor = try
            BASRoutedHostConstitutionVaultStorage(
                databaseURL: rustURL)

        func makeVault(idx: Int) -> BASHostConstitutionVault {
            let snap = BASHostConstitution(
                hostID: "host-\(idx)",
                activeVersion: "v\(idx)")
            let report = BASHostDeviceConsistencyReport(
                sourceDeviceID: "device-\(idx)")
            return BASHostConstitutionVault(
                vaultID: "vault-\(idx)",
                constitutionSnapshot: snap,
                deviceConsistencyReport: report)
        }

        // Warm-up
        for i in 9000..<9002 {
            _ = try await swiftActor.save(makeVault(idx: i))
            _ = try await rustActor.save(makeVault(idx: i))
        }

        let swiftSec = try await timeit {
            for i in 0..<100 {
                _ = try await swiftActor.save(
                    makeVault(idx: i))
            }
        }
        let rustSec = try await timeit {
            for i in 100..<200 {
                _ = try await rustActor.save(
                    makeVault(idx: i))
            }
        }
        let ratio = swiftSec / rustSec
        print(
            "ch905 vault.save N=100:" +
            " swift=\(String(format: "%.4f", swiftSec))s" +
            " rust=\(String(format: "%.4f", rustSec))s" +
            " swift/rust=\(String(format: "%.2fx", ratio))")
        XCTAssertLessThan(rustSec, swiftSec * 5.0)
    }
}
#endif
