// MARK: - BASChapter900VectorIndexByteEqTests
// chapter 九百 / M3190 — MED-risk migration #5 byte-eq pin

import XCTest
import Foundation
@testable import BASMemory
@testable import BASRuntimeCore
#if os(iOS) || os(macOS)
import BASRustMemoryTrackerBinary
#endif

#if os(iOS) || os(macOS)
final class BASChapter900VectorIndexByteEqTests: XCTestCase {

    private func makeTempDBURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("ch900-\(UUID().uuidString).db")
    }

    private func cleanup(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
        try? FileManager.default.removeItem(
            at: URL(fileURLWithPath: url.path + "-wal"))
        try? FileManager.default.removeItem(
            at: URL(fileURLWithPath: url.path + "-shm"))
    }

    private func makeEntry(
        id: String,
        dim: Int = 4,
        provider: String = "test-provider-v1",
        seed: Float = 0.1,
        domain: String = "domain-default",
        metadata: [String: String] = [:]
    ) -> BASVectorIndexEntry {
        let vector = (0..<dim).map { i in
            seed + Float(i) * 0.1
        }
        let embedding = BASEmbedding(
            vector: vector,
            dimension: dim,
            providerVersion: provider)
        return BASVectorIndexEntry(
            atomID: id,
            normalizedEmbedding: embedding,
            domain: domain,
            metadata: metadata)
    }

    func testRoutedActorUpsertAndCount() async throws {
        let url = makeTempDBURL()
        defer { cleanup(url) }
        let routed = try BASRoutedVectorIndexStorage(
            databaseURL: url)
        let initial = await routed.totalCount
        XCTAssertEqual(initial, 0)
        let r1 = try await routed.upsert(
            makeEntry(id: "atom-1", domain: "dA"))
        XCTAssertTrue(r1, "First insert returns true")
        let r2 = try await routed.upsert(
            makeEntry(id: "atom-1", seed: 0.5, domain: "dA"))
        XCTAssertFalse(r2, "Replace returns false")
        let total1 = await routed.totalCount
        XCTAssertEqual(total1, 1)
        _ = try await routed.upsert(
            makeEntry(id: "atom-2", domain: "dB"))
        let total2 = await routed.totalCount
        XCTAssertEqual(total2, 2)
        let cA = await routed.countForDomain("dA")
        let cB = await routed.countForDomain("dB")
        let cC = await routed.countForDomain("dC")
        XCTAssertEqual(cA, 1)
        XCTAssertEqual(cB, 1)
        XCTAssertEqual(cC, 0)
    }

    func testRemoveReturnsCorrectBool() async throws {
        let url = makeTempDBURL()
        defer { cleanup(url) }
        let routed = try BASRoutedVectorIndexStorage(
            databaseURL: url)
        _ = try await routed.upsert(
            makeEntry(id: "rm-1"))
        let removed1 = try await routed.remove(atomID: "rm-1")
        XCTAssertTrue(removed1)
        let removed2 = try await routed.remove(atomID: "rm-1")
        XCTAssertFalse(removed2,
            "Re-remove returns false (already gone)")
        let total = await routed.totalCount
        XCTAssertEqual(total, 0)
    }

    /// CRITICAL byte-eq vs BASSQLiteVectorIndexStorage。
    func testByteEqUpsertVsSwiftSQLite() async throws {
        let routedURL = makeTempDBURL()
        let swiftURL = makeTempDBURL()
        defer { cleanup(routedURL); cleanup(swiftURL) }
        let routed = try BASRoutedVectorIndexStorage(
            databaseURL: routedURL)
        let swiftActor = try BASSQLiteVectorIndexStorage(
            databaseURL: swiftURL)
        let entries: [BASVectorIndexEntry] = [
            makeEntry(id: "be-1", dim: 4, seed: 0.1,
                domain: "dX",
                metadata: ["tier": "hot"]),
            makeEntry(id: "be-2", dim: 4, seed: 0.2,
                domain: "dX",
                metadata: ["tier": "warm"]),
            makeEntry(id: "be-3", dim: 8,
                provider: "alt-provider-v2",
                seed: 0.3, domain: "dY",
                metadata: ["tier": "cold", "extra": "value"]),
        ]
        for e in entries {
            let r = try await routed.upsert(e)
            let s = try await swiftActor.upsert(e)
            XCTAssertEqual(r, s,
                "upsert return byte-eq for atom=\(e.atomID)")
        }
        // Replace one entry, both must return false
        let replace = makeEntry(id: "be-1", seed: 0.9,
            domain: "dX",
            metadata: ["tier": "frozen"])
        let rRep = try await routed.upsert(replace)
        let sRep = try await swiftActor.upsert(replace)
        XCTAssertEqual(rRep, sRep)
        XCTAssertFalse(rRep)
        // Counts byte-eq
        let rTotal = await routed.totalCount
        let sTotal = await swiftActor.totalCount
        XCTAssertEqual(rTotal, sTotal)
        XCTAssertEqual(rTotal, 3)
        // Per-domain byte-eq
        for domain in ["dX", "dY", "dMissing"] {
            let r = await routed.countForDomain(domain)
            let s = await swiftActor.allEntries()
                .filter { $0.domain == domain }.count
            XCTAssertEqual(r, s,
                "Per-domain count byte-eq for d=\(domain)")
        }
        // Per-provider byte-eq
        for pv in ["test-provider-v1", "alt-provider-v2"] {
            let r = await routed.countForProvider(pv)
            let s = await swiftActor.allEntries()
                .filter {
                    $0.normalizedEmbedding
                        .providerVersion == pv
                }.count
            XCTAssertEqual(r, s,
                "Per-provider count byte-eq for pv=\(pv)")
        }
    }
}
#endif
