// MARK: - BASChapter913VaultMetadataConsolidationTests
// chapter 九百十三 / M3270 — hot-path consolidation #4
//
// Completes the chapter 906/909/911 hot-path consolidation
// pattern across all 4 major L8 stores:
//
//   - vector_index (ch 906, 90-134× win)
//   - event_log (ch 909, 17-102× win)
//   - memory_usage_records (ch 911, 15-112× win)
//   - host_constitution_vault (THIS chapter)
//
// Vault is the 「smallest hot path」 — there are typically
// only a handful of vaults per device (one per host)。 The
// consolidation primitive `allVaultMetadata` is the
// boot-time loadAll-metadata scan that drives「which vaults
// need refresh from server / DECline 等」 decisions。

import XCTest
import Foundation
@testable import BASMemory
@testable import BASRuntimeCore
#if os(iOS) || os(macOS)
import BASRustMemoryTrackerBinary
#endif

#if os(iOS) || os(macOS)
final class BASChapter913VaultMetadataConsolidationTests:
    XCTestCase
{

    private func makeTempDBURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "ch913-\(UUID().uuidString).db")
    }

    private func cleanup(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
        try? FileManager.default.removeItem(
            at: URL(fileURLWithPath: url.path + "-wal"))
        try? FileManager.default.removeItem(
            at: URL(fileURLWithPath: url.path + "-shm"))
    }

    private func makeVault(
        vaultID: String,
        hostID: String,
        activeVersion: String
    ) -> BASHostConstitutionVault {
        let snap = BASHostConstitution(
            hostID: hostID,
            activeVersion: activeVersion)
        let report = BASHostDeviceConsistencyReport(
            sourceDeviceID: "dev")
        return BASHostConstitutionVault(
            vaultID: vaultID,
            constitutionSnapshot: snap,
            deviceConsistencyReport: report)
    }

    // MARK: - Correctness

    func testAllVaultMetadataReturnsDescByTimestamp() async
        throws
    {
        let url = makeTempDBURL()
        defer { cleanup(url) }
        let store = try
            BASRoutedHostConstitutionVaultStorage(
                databaseURL: url)
        // Save 4 vaults with slight time delays so the
        // last_updated_at_ms differs。 The Rust upsert writes
        // `now` as the ts,so just save in order to get
        // monotonically increasing timestamps。
        for i in 0..<4 {
            let v = makeVault(
                vaultID: "v-\(i)",
                hostID: "h-\(i)",
                activeVersion: "v.1")
            _ = try await store.save(v)
            // Brief sleep to ensure distinct ms timestamps
            try await Task.sleep(nanoseconds: 2_000_000)
        }
        let meta = try await store.allVaultMetadata(
            limit: 4)
        XCTAssertEqual(meta.count, 4)
        // DESC by ts: last-saved comes first
        for i in 0..<3 {
            XCTAssertGreaterThanOrEqual(
                meta[i].lastUpdatedAtMs,
                meta[i + 1].lastUpdatedAtMs,
                "Row \(i) ts >= row \(i+1) ts (DESC ordering)")
        }
    }

    func testAllVaultMetadataLimitClamps() async throws {
        let url = makeTempDBURL()
        defer { cleanup(url) }
        let store = try
            BASRoutedHostConstitutionVaultStorage(
                databaseURL: url)
        // 2 vaults, ask for 10 → returns 2
        _ = try await store.save(makeVault(
            vaultID: "a", hostID: "h-a",
            activeVersion: "v"))
        _ = try await store.save(makeVault(
            vaultID: "b", hostID: "h-b",
            activeVersion: "v"))
        let meta = try await store.allVaultMetadata(
            limit: 10)
        XCTAssertEqual(meta.count, 2)
    }

    func testAllVaultMetadataEmptyDBReturnsEmpty() async
        throws
    {
        let url = makeTempDBURL()
        defer { cleanup(url) }
        let store = try
            BASRoutedHostConstitutionVaultStorage(
                databaseURL: url)
        let meta = try await store.allVaultMetadata(
            limit: 5)
        XCTAssertEqual(meta.count, 0)
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

    func testBenchmarkVaultMetadata50() async throws {
        try await runBench(n: 50)
    }

    func testBenchmarkVaultMetadata200() async throws {
        try await runBench(n: 200)
    }

    private func runBench(n: Int) async throws {
        let url = makeTempDBURL()
        defer { cleanup(url) }
        let store = try
            BASRoutedHostConstitutionVaultStorage(
                databaseURL: url)
        for i in 0..<n {
            _ = try await store.save(makeVault(
                vaultID: "bv-\(i)",
                hostID: "h-\(i % 5)",
                activeVersion: "v"))
        }
        // Warm-up
        _ = try await store.allVaultMetadata(limit: n)
        _ = await store.vaultCount

        // chapter 九百十六 / M3285 honesty fix H3:
        // ORCHESTRATED = N vaultCount FFI calls。 NOT
        // apples-to-apples with「Swift would do N per-vault
        // metadata reads」 — that alternative requires the
        // chapter 906/909/911/913 integrated pattern。
        // Measures FFI-hop reduction,not end-to-end speedup。
        let orchSec = try await timeit {
            for _ in 0..<n {
                let _ = await store.vaultCount
            }
        }
        let intSec = try await timeit {
            _ = try await store.allVaultMetadata(
                limit: n)
        }
        let ratio = orchSec / intSec
        print(
            "ch913 vault.metadata N=\(n):" +
            " orch=\(String(format: "%.4f", orchSec))s" +
            " integrated=\(String(format: "%.4f", intSec))s" +
            " ffi-hop-reduction=\(String(format: "%.2fx", ratio))" +
            " [measures FFI overhead × N collapsed to 1," +
            " NOT end-to-end speedup]")
        // chapter 九百十六 fix H11:absolute wall-clock guard
        let absoluteBudgetSec: Double = n <= 50
            ? 0.002 : 0.005
        XCTAssertLessThan(intSec, absoluteBudgetSec,
            "Integrated time \(intSec)s exceeds budget " +
            "\(absoluteBudgetSec)s for N=\(n)")
        XCTAssertLessThan(intSec, orchSec,
            "Integrated must be faster than N FFI hops")
    }
}
#endif
