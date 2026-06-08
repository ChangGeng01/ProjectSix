// Concurrency arc M1.2 — does the L8 retrieval read path actually SCALE with concurrency, and where does
// the actor serialize? Two scenarios on the Rust L8 engine:
//   A) NONISOLATED read scaling: 1/4/8/16 concurrent readers on `cosineTopKAtomIDsSync` (the hot retrieve
//      path that bypasses the actor), NO concurrent writer (the turn-phase contract forbids that). Measures
//      whether the fast read path scales near-linearly with cores.
//   B) ACTOR-ISOLATED mixed read+write ceiling: N async readers (`cosineTopK`) + 1 async writer (`upsert`),
//      ALL serialized through the actor. Measures the serialized throughput ceiling + the "writes queue"
//      effect the operator flagged.
//
// This is a BENCHMARK (prints a scorecard); assertions are soft non-regression checks, not exact equality.

import XCTest
import Foundation
@testable import BASMemory
import BASRuntimeCore

#if os(iOS) || os(macOS)
import BASRustMemoryTrackerBinary

final class BASL8RetrievalConcurrentReadBenchmarkTests: XCTestCase {

    private let domainName = "g"
    private let featureDim = 64
    private let corpusCount = 2000

    private func seed(_ engine: BASRoutedVectorIndexStorage, dim: Int, domain: String, count: Int) async throws {
        for i in 0..<count {
            var v = [Float](repeating: 0, count: dim)
            for d in 0..<dim { v[d] = Float((i * 7 + d * 3) % 101) / 101.0 }
            _ = try await engine.upsert(BASVectorIndexEntry(
                atomID: "atom-\(i)",
                normalizedEmbedding: BASEmbedding(
                    vector: v, dimension: dim, providerVersion: "p").normalized,
                domain: domain))
        }
    }

    private func makeQuery(dim: Int) -> [Float] { (0..<dim).map { Float(($0 * 5) % 97) / 97.0 } }

    private func elapsedSec(_ body: () async -> Void) async -> Double {
        let t0 = DispatchTime.now().uptimeNanoseconds
        await body()
        return Double(DispatchTime.now().uptimeNanoseconds &- t0) / 1_000_000_000
    }

    // MARK: - Scenario A: nonisolated read scaling (no concurrent writer)

    func testNonisolatedReadScaling() async throws {
        let dim = featureDim, dom = domainName
        let engine = try BASRoutedVectorIndexStorage(inMemory: ())
        try await seed(engine, dim: dim, domain: dom, count: corpusCount)
        let q = makeQuery(dim: dim)
        let readsPerWorker = 400
        var baseline = 0.0

        print("📊 M1.2-A nonisolated cosineTopKAtomIDsSync read scaling (corpus=\(corpusCount) dim=\(dim))")
        for readers in [1, 4, 8, 16] {
            let sec = await elapsedSec {
                await withTaskGroup(of: Void.self) { group in
                    for _ in 0..<readers {
                        group.addTask {
                            for _ in 0..<readsPerWorker {
                                _ = try? engine.cosineTopKAtomIDsSync(forDomain: dom, query: q, k: 5)
                            }
                        }
                    }
                }
            }
            let totalReads = readers * readsPerWorker
            let rps = Double(totalReads) / sec
            if readers == 1 { baseline = rps }
            let speedup = baseline > 0 ? rps / baseline : 0
            print(String(format: "  readers=%2d  reads/s=%9.0f  speedup=%.2fx  (%.3fs for %d reads)",
                         readers, rps, speedup, sec, totalReads))
            XCTAssertGreaterThan(rps, 0, "reads complete")
        }

        // Soft scaling check: the nonisolated path must not SERIALIZE — 4 readers should beat 1 by a clear
        // margin on a multi-core machine. Modest threshold to avoid CI flakiness; the scorecard is the point.
        let sec1 = await elapsedSec {
            await withTaskGroup(of: Void.self) { group in
                group.addTask {
                    for _ in 0..<readsPerWorker { _ = try? engine.cosineTopKAtomIDsSync(forDomain: dom, query: q, k: 5) }
                }
            }
        }
        let rps1 = Double(readsPerWorker) / sec1
        let sec4 = await elapsedSec {
            await withTaskGroup(of: Void.self) { group in
                for _ in 0..<4 { group.addTask {
                    for _ in 0..<readsPerWorker { _ = try? engine.cosineTopKAtomIDsSync(forDomain: dom, query: q, k: 5) }
                } }
            }
        }
        let rps4 = Double(4 * readsPerWorker) / sec4
        print(String(format: "  scaling check: 1-reader=%.0f r/s, 4-reader=%.0f r/s (%.2fx)", rps1, rps4, rps4 / rps1))
        XCTAssertGreaterThan(rps4, rps1 * 1.3,
            "the NONISOLATED read scales with concurrency (≥1.3x at 4 readers) — it does not serialize")
    }

    // MARK: - Scenario B: actor-isolated mixed read+write ceiling (everything queues)

    func testActorSerializedMixedCeiling() async throws {
        let dim = featureDim, dom = domainName
        let engine = try BASRoutedVectorIndexStorage(inMemory: ())
        try await seed(engine, dim: dim, domain: dom, count: corpusCount)
        let q = makeQuery(dim: dim)
        let opsPerWorker = 100

        print("📊 M1.2-B actor-isolated async read(cosineTopK)+write(upsert) ceiling (all serialized)")
        for readers in [1, 4, 8] {
            let sec = await elapsedSec {
                await withTaskGroup(of: Void.self) { group in
                    for _ in 0..<readers {
                        group.addTask {
                            for _ in 0..<opsPerWorker {
                                _ = try? await engine.cosineTopK(forDomain: dom, query: q, k: 5)
                            }
                        }
                    }
                    group.addTask {
                        for i in 0..<opsPerWorker {
                            var v = [Float](repeating: 0, count: dim)
                            for d in 0..<dim { v[d] = Float((i + d) % 53) / 53.0 }
                            _ = try? await engine.upsert(BASVectorIndexEntry(
                                atomID: "w-\(i)",
                                normalizedEmbedding: BASEmbedding(
                                    vector: v, dimension: dim, providerVersion: "p").normalized,
                                domain: dom))
                        }
                    }
                }
            }
            let totalOps = readers * opsPerWorker + opsPerWorker
            print(String(format: "  readers=%d+1writer  ops/s=%8.0f  (%.3fs for %d async actor ops)",
                         readers, Double(totalOps) / sec, sec, totalOps))
        }
        // No scaling assertion — the point is the CONTRAST vs Scenario A: actor ops serialize (ops/s ~flat
        // across reader counts). The scorecard documents the ceiling.
        XCTAssertTrue(true)
    }
}
#endif
