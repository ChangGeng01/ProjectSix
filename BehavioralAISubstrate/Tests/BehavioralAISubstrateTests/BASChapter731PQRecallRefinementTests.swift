// MARK: - BASChapter731PQRecallRefinementTests
// chapter 七百三十一 第二刀 / M2327
//
// Addresses the chapter 七百二十九 PQ recall scope-gap with two
// new measurements:
//   1. K-parameter sweep (K=16/64/256) on uniform random
//      → quantify recall vs memory trade-off
//   2. CLUSTERED corpus recall (simulates realistic embeddings)
//      → demonstrate PQ works as advertised on production-like
//        data

import XCTest
import Foundation
@testable import BASRuntimeCore

final class BASChapter731PQRecallRefinementTests: XCTestCase {

    private func unitVector(
        seed: UInt64, dim: Int
    ) -> [Float] {
        var s = seed
        var v = [Float](repeating: 0, count: dim)
        for i in 0..<dim {
            s &+= 0x9E37_79B9_7F4A_7C15
            var z = s
            z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
            z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
            z = z ^ (z >> 31)
            v[i] = (Float(z & 0xFFFF_FFFF)
                / Float(UInt32.max)) * 2 - 1
        }
        var sumSq: Float = 0
        for x in v { sumSq += x * x }
        let mag = sqrt(sumSq)
        if mag > 0 {
            for i in 0..<dim { v[i] /= mag }
        }
        return v
    }

    /// Generate a clustered vector:start from one of `nCenters`
    /// random centers + add a small random perturbation, then
    /// renormalize。 Simulates realistic embedding distributions
    /// where similar concepts cluster in vector space。
    private func clusteredVector(
        seed: UInt64,
        centerSeed: UInt64,
        dim: Int,
        perturbation: Float
    ) -> [Float] {
        let center = unitVector(
            seed: centerSeed, dim: dim)
        let noise = unitVector(seed: seed, dim: dim)
        var v = [Float](repeating: 0, count: dim)
        for i in 0..<dim {
            v[i] = center[i] + perturbation * noise[i]
        }
        var sumSq: Float = 0
        for x in v { sumSq += x * x }
        let mag = sqrt(sumSq)
        if mag > 0 {
            for i in 0..<dim { v[i] /= mag }
        }
        return v
    }

    private func cosine(_ a: [Float], _ b: [Float]) -> Float {
        var dot: Float = 0
        for i in 0..<a.count { dot += a[i] * b[i] }
        return dot
    }

    // MARK: - K-parameter sweep on uniform random

    func testRecallVsKParameterSweep() throws {
        #if os(iOS) || os(macOS)
        let dim = 128
        let nCorpus = 2000
        let nQueries = 20
        let kTop = 10
        let m = 8

        // Generate same uniform-random corpus once
        var corpus: [[Float]] = []
        for i in 0..<nCorpus {
            corpus.append(unitVector(
                seed: UInt64(i * 7867 + 31), dim: dim))
        }
        var queries: [[Float]] = []
        for i in 0..<nQueries {
            queries.append(unitVector(
                seed: UInt64(i * 7919), dim: dim))
        }
        // Compute Float32 ground truth top-K for each query
        var groundTruth: [[Int]] = []
        for q in queries {
            var scored: [(Int, Float)] = []
            for (ci, c) in corpus.enumerated() {
                scored.append((ci, cosine(q, c)))
            }
            scored.sort { $0.1 > $1.1 }
            groundTruth.append(scored.prefix(kTop)
                .map { $0.0 })
        }

        print("")
        print(
            "## chapter 七百三十一 第二刀 — PQ K-parameter sweep (uniform random)")
        print("")
        print(
            "  K   | bits/code | bytes/vec | recall@10 | PQ KB | memory ratio")
        print(
            "  ----+-----------+-----------+-----------+-------+-------------")

        // Sweep K = 16 (4-bit), 64 (6-bit), 256 (8-bit)
        // (Substrate stores codes as u8 so 8-bit max。 Encoding
        // multiple codes per byte for K=16/64 would need
        // additional packing logic — deferred to future arc。)
        for kVal in [16, 64, 256] {
            let pq = BASPQIndex(
                dim: dim, m: m, k: kVal)
            guard let pq = pq else {
                XCTFail("PQ init failed for K=\(kVal)")
                return
            }
            // Use first 1024 corpus rows as training set
            let trainRows = min(nCorpus, 1024)
            var trainingFlat: [Float] = []
            for i in 0..<trainRows {
                trainingFlat.append(
                    contentsOf: corpus[i])
            }
            try pq.train(
                trainingSet: trainingFlat,
                nTrain: trainRows,
                iters: 8)
            for v in corpus {
                try pq.add(v)
            }
            // Measure recall
            var overlap = 0
            for (qi, q) in queries.enumerated() {
                let pqRes = try pq.topK(query: q, k: kTop)
                let pqSet = Set(pqRes.map { $0.rowID })
                overlap += Set(groundTruth[qi])
                    .intersection(pqSet).count
            }
            let recall = Double(overlap)
                / Double(nQueries * kTop)
            let bitsPerCode = Int(
                ceil(log2(Double(kVal))))
            let bytesPerVec = m  // always 1 byte per
                                 // subquantizer in
                                 // substrate's PQ
            let pqBytes = pq.byteSize
            let f32Bytes = nCorpus * dim * 4
            let memRatio =
                Double(f32Bytes) / Double(pqBytes)
            print(String(
                format: "  %3d | %5d-bit | %5d bytes | %6.1f%%   | %5.1f | %6.2f×",
                kVal, bitsPerCode, bytesPerVec,
                recall * 100,
                Double(pqBytes) / 1024.0,
                memRatio))
        }
        print("")
        #endif
    }

    // MARK: - Recall on CLUSTERED corpus (realistic embedding)

    func testRecallOnClusteredCorpus() throws {
        #if os(iOS) || os(macOS)
        let dim = 128
        let nCenters = 50
        let nPerCluster = 40
        let nCorpus = nCenters * nPerCluster  // 2000
        let nQueries = 20
        let kTop = 10
        let perturbation: Float = 0.2

        // Build clustered corpus:50 centers × 40 perturbed
        // copies each = 2000 vectors with strong cluster
        // structure (simulates real embeddings)
        var corpus: [[Float]] = []
        for ci in 0..<nCenters {
            let centerSeed = UInt64(ci * 31 + 7)
            for pi in 0..<nPerCluster {
                corpus.append(clusteredVector(
                    seed: UInt64(ci * 1000 + pi),
                    centerSeed: centerSeed,
                    dim: dim,
                    perturbation: perturbation))
            }
        }
        // Queries: also clustered (near random centers)
        var queries: [[Float]] = []
        for qi in 0..<nQueries {
            let centerIdx = qi % nCenters
            let centerSeed = UInt64(centerIdx * 31 + 7)
            queries.append(clusteredVector(
                seed: UInt64(qi * 9999),
                centerSeed: centerSeed,
                dim: dim,
                perturbation: perturbation * 1.5))
        }
        // Ground truth
        var groundTruth: [[Int]] = []
        for q in queries {
            var scored: [(Int, Float)] = []
            for (ci, c) in corpus.enumerated() {
                scored.append((ci, cosine(q, c)))
            }
            scored.sort { $0.1 > $1.1 }
            groundTruth.append(scored.prefix(kTop)
                .map { $0.0 })
        }

        // Train PQ at K=16 (substrate default)
        let pq = BASPQIndex(dim: dim, m: 8, k: 16)!
        let trainRows = min(nCorpus, 1024)
        var trainingFlat: [Float] = []
        for i in 0..<trainRows {
            trainingFlat.append(contentsOf: corpus[i])
        }
        try pq.train(
            trainingSet: trainingFlat,
            nTrain: trainRows,
            iters: 8)
        for v in corpus { try pq.add(v) }

        var overlap = 0
        for (qi, q) in queries.enumerated() {
            let pqRes = try pq.topK(query: q, k: kTop)
            let pqSet = Set(pqRes.map { $0.rowID })
            overlap += Set(groundTruth[qi])
                .intersection(pqSet).count
        }
        let recall = Double(overlap)
            / Double(nQueries * kTop)

        print("")
        print(
            "## chapter 七百三十一 第二刀 — PQ recall on CLUSTERED corpus")
        print("")
        print(String(
            format: "  Corpus: %d × %d-dim (50 clusters × 40 each)",
            nCorpus, dim))
        print(String(
            format: "  Queries: %d (clustered near random centers)",
            nQueries))
        print(String(
            format: "  Perturbation σ: %.2f", perturbation))
        print(String(
            format: "  PQ:    K=16 (substrate default),M=8"))
        print("")
        print(String(
            format: "  PQ recall@10: %.1f%%", recall * 100))
        print(String(
            format: "  Improvement vs uniform random (3.5%%): %.1fx",
            recall / 0.035))
        print("")
        print(
            "  Production embeddings exhibit clustering — PQ")
        print(
            "  exploits the cluster structure effectively。 This")
        print(
            "  test simulates that structure (50 clusters × 40)")
        print(
            "  and demonstrates the recall jump vs uniform random。")
        print("")

        // Honest gate: clustered corpus should land WELL above
        // uniform random (which was 3.5%)。 Expect ≥ 20%
        // improvement (≥ 4× over uniform random)。
        XCTAssertGreaterThanOrEqual(
            recall, 0.20,
            "PQ recall on clustered corpus \(recall) " +
            "should beat uniform-random baseline")
        #endif
    }
}
