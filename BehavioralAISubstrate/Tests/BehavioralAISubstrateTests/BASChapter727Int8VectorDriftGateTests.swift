// MARK: - BASChapter727Int8VectorDriftGateTests
// chapter 七百二十七 第三刀 / M2308
//
// NEW exit criterion (replaces byte-equality for quantization
// paths):cosine-drift gate。 Across 100 random 384-dim queries
// × 1000-row corpus,max |cos_int8 - cos_f32| ≤ 0.01。
//
// Plus recall@10 sanity:int8 top-10 must share ≥ 70% of the
// Float32 top-10 IDs (looser than the 95% gate planned for PQ
// in chapter 七百二十九 since per-pair cosine drift can swap
// adjacent ranks at low-margin entries)。

import XCTest
import Foundation
@testable import BASRuntimeCore
@testable import BASMemory

final class BASChapter727Int8VectorDriftGateTests: XCTestCase {

    override func tearDown() async throws {
        // Chapter 八百七十八 / M3070 — 9th-pass review HIGH-1 caught
        // that this THIRD chapter-727 file has the same tearDown
        // leakage pattern as the Perf + PQ tests (chapters 727 +
        // 729) that chapter 877 fixed。 In-body reset at line ~213
        // only runs on success path — if any XCTAssert in lines
        // 185-209 fails,useInt8VectorStorage stays true and
        // contaminates subsequent test files。 Same chapter 876.5
        // discipline applies: always restore production default
        // in tearDown,not in-body。
        BASVectorIndex.useInt8VectorStorage = false
        try await super.tearDown()
    }

    // MARK: - Deterministic generator

    /// SplitMix64 + L2 normalize → reproducible unit vectors。
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
            // Map to [-1, 1]
            let u = (Float(z & 0xFFFF_FFFF)
                    / Float(UInt32.max)) * 2 - 1
            v[i] = u
        }
        // L2 normalize
        var sumSquares: Float = 0
        for x in v { sumSquares += x * x }
        let mag = sqrt(sumSquares)
        if mag > 0 {
            for i in 0..<dim { v[i] /= mag }
        }
        return v
    }

    private func f32Cosine(
        _ a: [Float], _ b: [Float]
    ) -> Float {
        var dot: Float = 0
        for i in 0..<a.count {
            dot += a[i] * b[i]
        }
        return dot
    }

    // MARK: - Drift gate

    func testCosineDriftAcross100QueriesBy1000CorpusAt384Dim() {
        #if os(iOS) || os(macOS)
        let dim = 384
        let queryCount = 100
        let corpusCount = 1000

        var queries: [[Float]] = []
        queries.reserveCapacity(queryCount)
        for qi in 0..<queryCount {
            queries.append(unitVector(
                seed: UInt64(qi * 7919),
                dim: dim))
        }
        var corpus: [[Float]] = []
        corpus.reserveCapacity(corpusCount)
        for ci in 0..<corpusCount {
            corpus.append(unitVector(
                seed: UInt64(ci * 7867 + 31),
                dim: dim))
        }

        // Quantize entire corpus + queries
        var corpusInt8: [[Int8]] = []
        var corpusScales: [Float] = []
        corpusInt8.reserveCapacity(corpusCount)
        for v in corpus {
            let r = BASAutoRouteRanker.quantizeInt8(v)!
            corpusInt8.append(r.quantized)
            corpusScales.append(r.scale)
        }

        var maxDrift: Float = 0
        var driftSum: Double = 0
        var driftCount = 0

        for qi in 0..<queryCount {
            let q = queries[qi]
            let qq = BASAutoRouteRanker.quantizeInt8(q)!
            for ci in 0..<corpusCount {
                let cF32 = f32Cosine(q, corpus[ci])
                let cI8 = BASAutoRouteRanker.cosineInt8(
                    a: qq.quantized,
                    scaleA: qq.scale,
                    b: corpusInt8[ci],
                    scaleB: corpusScales[ci])!
                let drift = abs(cF32 - cI8)
                if drift > maxDrift { maxDrift = drift }
                driftSum += Double(drift)
                driftCount += 1
            }
        }
        let avgDrift = driftSum / Double(driftCount)

        print("")
        print(
            "## chapter 七百二十七 第三刀 — cosine-drift gate")
        print("")
        print(String(
            format: "  Grid: %d queries × %d corpus × %d dim",
            queryCount, corpusCount, dim))
        print(String(
            format: "  Total comparisons: %d", driftCount))
        print(String(
            format: "  Max drift: %.6f", maxDrift))
        print(String(
            format: "  Avg drift: %.6f", avgDrift))
        print(String(
            format: "  Gate:      ≤ 0.01 (%@)",
            maxDrift <= 0.01 ? "PASS ✅" : "FAIL ❌"))
        print("")

        XCTAssertLessThanOrEqual(
            maxDrift, 0.01,
            "max cosine drift \(maxDrift) exceeds 0.01 gate")
        #endif
    }

    func testInt8VectorIndexTopKRecallAtTen() async throws {
        #if os(iOS) || os(macOS)
        let dim = 384
        let corpusCount = 1000

        // Build both Float32 and int8 indices with same corpus
        BASVectorIndex.useInt8VectorStorage = true
        let f32Index = BASVectorIndex()
        let i8Index = BASVectorIndex()

        for ci in 0..<corpusCount {
            let v = unitVector(
                seed: UInt64(ci * 7867 + 31),
                dim: dim)
            let f32Entry = BASVectorIndexEntry(
                atomID: "atom_\(ci)",
                normalizedEmbedding: BASEmbedding(
                    vector: v,
                    dimension: v.count,
                    providerVersion: "drift-gate-test"),
                domain: "",
                metadata: [:])
            try await f32Index.insert(f32Entry)
            let i8Entry = BASInt8VectorIndexEntry(
                atomID: "atom_\(ci)",
                normalizedEmbedding: v)!
            try await i8Index.insertInt8(i8Entry)
        }

        // Run 20 queries,measure recall@10 (int8 top-10
        // overlaps with f32 top-10)
        var totalOverlap = 0
        var totalK = 0
        for qi in 0..<20 {
            let q = unitVector(
                seed: UInt64(qi * 7919),
                dim: dim)
            let f32Top = await f32Index.topK(
                query: BASEmbedding(
                    vector: q,
                    dimension: q.count,
                    providerVersion: "drift-gate-test"), k: 10)
            let i8Top = await i8Index.topKInt8(
                query: BASEmbedding(
                    vector: q,
                    dimension: q.count,
                    providerVersion: "drift-gate-test"), k: 10)
            XCTAssertEqual(f32Top.count, 10)
            XCTAssertEqual(i8Top.count, 10)
            let f32Set = Set(f32Top.map { $0.atomID })
            let i8Set = Set(i8Top.map { $0.atomID })
            let overlap = f32Set.intersection(i8Set).count
            totalOverlap += overlap
            totalK += 10
        }
        let recall = Double(totalOverlap)
            / Double(totalK)
        print("")
        print(
            "## chapter 七百二十七 第三刀 — recall@10 sanity")
        print("")
        print(String(
            format: "  20 queries × top-10 = 200 total slots")
        )
        print(String(
            format: "  int8 ∩ f32 overlap: %d / %d (%.1f%%)",
            totalOverlap, totalK, recall * 100))
        print(String(
            format: "  Gate:               ≥ 70%% (%@)",
            recall >= 0.7 ? "PASS ✅" : "FAIL ❌"))
        print("")
        XCTAssertGreaterThanOrEqual(
            recall, 0.7,
            "int8 vs f32 top-10 recall \(recall) below 70%")

        BASVectorIndex.useInt8VectorStorage = false
        #endif
    }
}
