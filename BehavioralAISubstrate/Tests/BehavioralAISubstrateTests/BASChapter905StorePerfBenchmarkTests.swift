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
// scorecard and asserts the result is NOT silently regressed。
// chapter 九百十二 / M3265 review fix MED #18:tightened from
// soft 5× to harder 2× — measured ratios are 0.92×-1.05× so
// 2× is a meaningful regression band。 Chapter 906 uses these
// numbers to make the flip-or-decline decision per chapter
// 870 整体 性能 一定要 更好 discipline。
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

    /// Each side is measured this many times and the MINIMUM is compared.
    ///
    /// Single-shot wall-clock ratios make this suite a LOAD DETECTOR rather than a
    /// regression detector: measured 2026-07-14 on a machine busy with back-to-back
    /// builds, Rust came out 2.14x slower and RED the 2x guard, then passed 3/3 in
    /// isolation. Minimum-of-N is the robust estimator — noise only ever ADDS time, so the
    /// min is the closest thing to true cost, and a real regression still moves it.
    private static let benchmarkRepeats = 5


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

        var minSwiftSec = Double.greatestFiniteMagnitude
        var minRustSec = Double.greatestFiniteMagnitude
        for _ in 0..<Self.benchmarkRepeats {
            minSwiftSec = min(minSwiftSec, try await timeit {
                for i in 0..<n {
                    _ = try await swiftActor.record(
                        atomID: "atom-\(i % 50)",
                        sessionRef: "sess-\(i % 10)",
                        turnRef: "turn-\(i)",
                        permitMode: "permitted")
                }
            })
            minRustSec = min(minRustSec, try await timeit {
                for i in 0..<n {
                    _ = try await rustActor.record(
                        atomID: "atom-\(i % 50)",
                        sessionRef: "sess-\(i % 10)",
                        turnRef: "turn-\(i)",
                        permitMode: "permitted")
                }
            })
        }
        let swiftSec = minSwiftSec
        let rustSec = minRustSec
        let ratio = swiftSec / rustSec
        print(
            "ch905 record N=\(n):" +
            " swift=\(String(format: "%.4f", swiftSec))s" +
            " rust=\(String(format: "%.4f", rustSec))s" +
            " swift/rust=\(String(format: "%.2fx", ratio))")
        // Tightened guard (ch 九百十二 review fix MED #18):
        // Rust must not be >2× slower。 Measured ratios are
        // 0.92×-1.05× so 2× is a meaningful regression band。
        XCTAssertLessThan(rustSec, swiftSec * 2.0,
            "Rust >2x slower than Swift = real regression")
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

        // ch 1037.2 best-of-3(mirror ch 1024.0):assertion is
        // `rust < swift×2`,so the most-favorable trial = min(rustSec)
        // over max(swiftSec)。 Each trial uses a distinct entry-id base
        // to avoid PK collisions(DB grows but append cost is per-txn,
        // not size-bound)。 Absorbs Mac scheduling noise(endurance
        // v5/v6 flaky)。
        // MIN-vs-MIN (was min-rust vs MAX-swift, which compared Rust's best case against
        // Swift's worst — biased toward passing, so it could hide a real Rust regression).
        // Minimum is the robust estimator for both sides: noise only ever adds time.
        var minRustSec = Double.greatestFiniteMagnitude
        var minSwiftSec = Double.greatestFiniteMagnitude
        for trial in 0..<Self.benchmarkRepeats {
            let base = (trial + 1) * 100_000
            let s = try await timeit {
                for i in 0..<n {
                    _ = try await swiftActor.append(
                        makeEntry(base + i))
                }
            }
            let r = try await timeit {
                for i in 0..<n {
                    _ = try await rustActor.append(
                        makeEntry(base + n + i))
                }
            }
            minRustSec = min(minRustSec, r)
            minSwiftSec = min(minSwiftSec, s)
        }
        let swiftSec = minSwiftSec   // alias for print + assert
        let rustSec = minRustSec
        let ratio = swiftSec / rustSec
        let reps = Self.benchmarkRepeats
        print(
            "ch905 eventlog.append N=\(n) best-of-\(reps):" +
            " swift=\(String(format: "%.4f", swiftSec))s" +
            " rust=\(String(format: "%.4f", rustSec))s" +
            " swift/rust=\(String(format: "%.2fx", ratio))")
        XCTAssertLessThan(rustSec, swiftSec * 2.0,
            "Rust >2x slower than Swift = real regression")
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

        // MIN-of-N, distinct index base per trial so repeats don't collide (warm-up uses
        // 9000+). Single-shot wall-clock made this a load detector — see runRecordBenchmark.
        var minSwiftSec = Double.greatestFiniteMagnitude
        var minRustSec = Double.greatestFiniteMagnitude
        for trial in 0..<Self.benchmarkRepeats {
            let base = trial * 1_000
            minSwiftSec = min(minSwiftSec, try await timeit {
                for i in base..<(base + 100) {
                    _ = try await swiftActor.save(
                        makeVault(idx: i))
                }
            })
            minRustSec = min(minRustSec, try await timeit {
                for i in (base + 100)..<(base + 200) {
                    _ = try await rustActor.save(
                        makeVault(idx: i))
                }
            })
        }
        let swiftSec = minSwiftSec
        let rustSec = minRustSec
        let ratio = swiftSec / rustSec
        let reps = Self.benchmarkRepeats
        print(
            "ch905 vault.save N=100 best-of-\(reps):" +
            " swift=\(String(format: "%.4f", swiftSec))s" +
            " rust=\(String(format: "%.4f", rustSec))s" +
            " swift/rust=\(String(format: "%.2fx", ratio))")
        XCTAssertLessThan(rustSec, swiftSec * 2.0,
            "Rust >2x slower than Swift = real regression")
    }
}
#endif
