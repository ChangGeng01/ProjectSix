// MARK: - BASChapter912VectorIndexWithSkippedWrapperTests
// chapter 九百十二 / M3265 — Swift wrapper for ch 910 with_skipped
//
// Chapter 九百十 (arc seal) added Rust + FFI for the
// `cosine_topk_for_domain_with_skipped` variant that surfaces
// dim-mismatched row count, but no Swift bridge wrapper
// exposed it。 Chapter 九百十二 closes that gap with
// `BASRoutedVectorIndexStorage.cosineTopKWithSkipped`。
//
// Pin the contract:
//   - Same top-k results as the base variant (chapter 906)
//   - Plus the count of dim-mismatched rows that were silently
//     skipped during the scan
//   - Production consumers can detect provider upgrades that
//     left mixed-dim corpora behind

import XCTest
import Foundation
@testable import BASMemory
@testable import BASRuntimeCore
#if os(iOS) || os(macOS)
import BASRustMemoryTrackerBinary
#endif

#if os(iOS) || os(macOS)
final class BASChapter912VectorIndexWithSkippedWrapperTests:
    XCTestCase
{

    private func makeTempDBURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "ch912-\(UUID().uuidString).db")
    }

    private func cleanup(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
        try? FileManager.default.removeItem(
            at: URL(fileURLWithPath: url.path + "-wal"))
        try? FileManager.default.removeItem(
            at: URL(fileURLWithPath: url.path + "-shm"))
    }

    private func packF32LE(_ values: [Float]) -> [UInt8] {
        var bytes: [UInt8] = []
        bytes.reserveCapacity(values.count * 4)
        for v in values {
            var x = v
            withUnsafeBytes(of: &x) { raw in
                bytes.append(contentsOf: raw)
            }
        }
        return bytes
    }

    func testWithSkippedReturnsZeroForClean() async throws {
        let url = makeTempDBURL()
        defer { cleanup(url) }
        let store = try BASRoutedVectorIndexStorage(
            databaseURL: url)
        // All embeddings dim=2 — no mismatches
        for i in 0..<3 {
            let entry = BASVectorIndexEntry(
                atomID: "a-\(i)",
                normalizedEmbedding: BASEmbedding(
                    vector: [Float(i) / 3.0, 0.0],
                    dimension: 2,
                    providerVersion: "p"),
                domain: "clean",
                metadata: [:])
            _ = try await store.upsert(entry)
        }
        let q = packF32LE([1.0, 0.0])
        let (results, skipped) = try await store
            .cosineTopKWithSkipped(
                forDomain: "clean",
                queryBytes: q,
                k: 3)
        XCTAssertEqual(results.count, 3)
        XCTAssertEqual(skipped, 0,
            "Clean corpus must return skipped=0")
    }

    func testWithSkippedReturnsCountForMixed() async throws {
        let url = makeTempDBURL()
        defer { cleanup(url) }
        let store = try BASRoutedVectorIndexStorage(
            databaseURL: url)
        // 1 dim=2 (matches) + 2 dim=3 (mismatch) embeddings
        let good = BASVectorIndexEntry(
            atomID: "good",
            normalizedEmbedding: BASEmbedding(
                vector: [1.0, 0.0],
                dimension: 2,
                providerVersion: "p"),
            domain: "mixed",
            metadata: [:])
        let bad1 = BASVectorIndexEntry(
            atomID: "bad1",
            normalizedEmbedding: BASEmbedding(
                vector: [1.0, 0.0, 0.0],
                dimension: 3,
                providerVersion: "p"),
            domain: "mixed",
            metadata: [:])
        let bad2 = BASVectorIndexEntry(
            atomID: "bad2",
            normalizedEmbedding: BASEmbedding(
                vector: [0.5, 0.5, 0.5],
                dimension: 3,
                providerVersion: "p"),
            domain: "mixed",
            metadata: [:])
        _ = try await store.upsert(good)
        _ = try await store.upsert(bad1)
        _ = try await store.upsert(bad2)
        let q = packF32LE([1.0, 0.0])
        let (results, skipped) = try await store
            .cosineTopKWithSkipped(
                forDomain: "mixed",
                queryBytes: q,
                k: 5)
        XCTAssertEqual(results.count, 1,
            "Only the dim-matched row scored")
        XCTAssertEqual(skipped, 2,
            "Both dim-3 rows reported as skipped")
        XCTAssertEqual(results[0].score, 1.0,
            accuracy: 1e-5)
    }

    func testWithSkippedParityWithBaseVariant() async throws {
        // Pin:cosineTopK and cosineTopKWithSkipped produce
        // IDENTICAL results array — only diff is the skipped
        // counter (which the base variant doesn't expose)。
        let url = makeTempDBURL()
        defer { cleanup(url) }
        let store = try BASRoutedVectorIndexStorage(
            databaseURL: url)
        for i in 0..<5 {
            let entry = BASVectorIndexEntry(
                atomID: "p-\(i)",
                normalizedEmbedding: BASEmbedding(
                    vector: [Float(i + 1) / 10.0, 0.0],
                    dimension: 2,
                    providerVersion: "p"),
                domain: "parity",
                metadata: [:])
            _ = try await store.upsert(entry)
        }
        let q = packF32LE([1.0, 0.0])
        let base = try await store.cosineTopK(
            forDomain: "parity",
            queryBytes: q, k: 3)
        let (withSkipped, skipped) = try await store
            .cosineTopKWithSkipped(
                forDomain: "parity",
                queryBytes: q, k: 3)
        XCTAssertEqual(base.count, withSkipped.count)
        XCTAssertEqual(skipped, 0)
        for i in 0..<base.count {
            XCTAssertEqual(base[i].rowid, withSkipped[i].rowid)
            XCTAssertEqual(base[i].score, withSkipped[i].score,
                accuracy: 1e-5)
        }
    }
}
#endif
