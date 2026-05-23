// MARK: - BASChapter918LimitValidationTests
// chapter 九百十八 / M3295 — limit validation across 4 bridges
//
// Per chapter 九百十四.5 全量 审查 MED finding,replaced
// `precondition(limit > 0)` (which aborts in release builds)
// with `guard ... else { throw StoreError.invalidArgument }`
// in all 4 hot-path consolidation primitives。 Plus a limitCap
// (100k) prevents OOM via `[Int64](repeating: 0, count: limit)`
// when caller passes pathological values like `Int.max`。
//
// This test pins the new throw behavior across all 4 bridges。

import XCTest
import Foundation
@testable import BASMemory
@testable import BASRuntimeCore
#if os(iOS) || os(macOS)
import BASRustMemoryTrackerBinary
#endif

#if os(iOS) || os(macOS)
final class BASChapter918LimitValidationTests: XCTestCase {

    private func makeTempDBURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "ch918-\(UUID().uuidString).db")
    }

    private func cleanup(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
        try? FileManager.default.removeItem(
            at: URL(fileURLWithPath: url.path + "-wal"))
        try? FileManager.default.removeItem(
            at: URL(fileURLWithPath: url.path + "-shm"))
    }

    // MARK: - vector_index cosineTopK rejects bad k

    func testVectorIndexCosineTopKThrowsOnZeroK() async
        throws
    {
        let url = makeTempDBURL()
        defer { cleanup(url) }
        let store = try BASRoutedVectorIndexStorage(
            databaseURL: url)
        do {
            _ = try await store.cosineTopK(
                forDomain: "any",
                queryBytes: [0, 0, 0, 0],
                k: 0)
            XCTFail("k=0 must throw")
        } catch let e as BASRoutedVectorIndexStorage
            .StoreError
        {
            if case .invalidArgument(let reason) = e {
                XCTAssertTrue(reason.contains("k must be in"),
                    "Reason should mention k bounds")
            } else {
                XCTFail("Wrong error case: \(e)")
            }
        }
    }

    func testVectorIndexCosineTopKThrowsOnOversizedK() async
        throws
    {
        let url = makeTempDBURL()
        defer { cleanup(url) }
        let store = try BASRoutedVectorIndexStorage(
            databaseURL: url)
        do {
            _ = try await store.cosineTopK(
                forDomain: "any",
                queryBytes: [0, 0, 0, 0],
                k: Int.max)
            XCTFail("k=Int.max must throw")
        } catch let e as BASRoutedVectorIndexStorage
            .StoreError
        {
            if case .invalidArgument(let reason) = e {
                XCTAssertTrue(reason.contains("100000"))
            } else {
                XCTFail("Wrong error case: \(e)")
            }
        }
    }

    // MARK: - event_log recentTimestamps rejects bad limit

    func testEventLogRecentTimestampsThrowsOnZeroLimit() async
        throws
    {
        let url = makeTempDBURL()
        defer { cleanup(url) }
        let store = try BASRoutedEventLogStorage(
            databaseURL: url)
        do {
            _ = try await store.recentTimestamps(
                forSession: "any", limit: 0)
            XCTFail("limit=0 must throw")
        } catch let e as BASRoutedEventLogStorage.StoreError {
            if case .invalidArgument = e {
                // OK
            } else {
                XCTFail("Wrong error case: \(e)")
            }
        }
    }

    // MARK: - records recentRecords rejects bad limit

    func testRecordsRecentRecordsThrowsOnZeroLimit() async
        throws
    {
        let url = makeTempDBURL()
        defer { cleanup(url) }
        let store = try BASRoutedMemoryUsageRecordsStore(
            databaseURL: url)
        do {
            _ = try await store.recentRecords(
                forAtomID: "any", limit: 0)
            XCTFail("limit=0 must throw")
        } catch let e as BASRoutedMemoryUsageRecordsStore
            .StoreError
        {
            if case .invalidArgument = e {
                // OK
            } else {
                XCTFail("Wrong error case: \(e)")
            }
        }
    }

    // MARK: - vault allVaultMetadata rejects bad limit

    func testVaultAllMetadataThrowsOnZeroLimit() async throws {
        let url = makeTempDBURL()
        defer { cleanup(url) }
        let store = try
            BASRoutedHostConstitutionVaultStorage(
                databaseURL: url)
        do {
            _ = try await store.allVaultMetadata(limit: 0)
            XCTFail("limit=0 must throw")
        } catch let e as
            BASRoutedHostConstitutionVaultStorage.StoreError
        {
            if case .invalidArgument = e {
                // OK
            } else {
                XCTFail("Wrong error case: \(e)")
            }
        }
    }

    func testVaultAllMetadataThrowsOnOversizedLimit() async
        throws
    {
        let url = makeTempDBURL()
        defer { cleanup(url) }
        let store = try
            BASRoutedHostConstitutionVaultStorage(
                databaseURL: url)
        do {
            _ = try await store.allVaultMetadata(
                limit: 1_000_000)
            XCTFail("limit=1M must throw (cap is 100k)")
        } catch let e as
            BASRoutedHostConstitutionVaultStorage.StoreError
        {
            if case .invalidArgument(let reason) = e {
                XCTAssertTrue(reason.contains("100000"))
            } else {
                XCTFail("Wrong error case: \(e)")
            }
        }
    }

    // MARK: - Boundary: limitCap = 100_000 is accepted

    func testVectorIndexAcceptsAtLimitCap() async throws {
        let url = makeTempDBURL()
        defer { cleanup(url) }
        let store = try BASRoutedVectorIndexStorage(
            databaseURL: url)
        // At cap = should not throw (DB is empty so returns
        // empty array,but the limit validation passes)
        let results = try await store.cosineTopK(
            forDomain: "empty",
            queryBytes: [0, 0, 0, 0],
            k: 100_000)
        XCTAssertEqual(results.count, 0)
    }
}
#endif
