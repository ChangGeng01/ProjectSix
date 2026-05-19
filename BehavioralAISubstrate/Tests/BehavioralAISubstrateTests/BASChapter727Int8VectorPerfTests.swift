// MARK: - BASChapter727Int8VectorPerfTests
// chapter 七百二十七 第四刀 / M2309
//
// Perf grid + RAM footprint comparison for int8 vector storage
// vs the chapter 七百十八 Float32 batched-cosine baseline。

import XCTest
import Foundation
@testable import BASRuntimeCore
@testable import BASMemory

final class BASChapter727Int8VectorPerfTests: XCTestCase {

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

    private func now() -> Double {
        return CFAbsoluteTimeGetCurrent()
    }

    func testPerfTopKInt8VsFloat32() async throws {
        #if os(iOS) || os(macOS)
        let dim = 384

        let cells: [(label: String, n: Int)] = [
            ("1K rows",  1000),
            ("5K rows",  5000),
            ("10K rows", 10000),
        ]

        BASVectorIndex.useInt8VectorStorage = true
        // Chapter 七百十八 batched-cosine is the Float32 baseline
        BASVectorIndex.useBatchedTopK = true

        print("")
        print(
            "## chapter 七百二十七 第四刀 — int8 vs Float32 topK perf")
        print("")
        print(
            "  size     | f32 µs/op | i8 µs/op | speedup | i8 RAM | f32 RAM")
        print(
            "  ---------+-----------+----------+---------+--------+--------")

        for cell in cells {
            let f32Index = BASVectorIndex()
            let i8Index = BASVectorIndex()
            var int8RAMBytes = 0
            for ci in 0..<cell.n {
                let v = unitVector(
                    seed: UInt64(ci * 7867 + 31),
                    dim: dim)
                try await f32Index.insert(
                    BASVectorIndexEntry(
                        atomID: "atom_\(ci)",
                        normalizedEmbedding: BASEmbedding(
                            vector: v,
                            dimension: dim,
                            providerVersion: "perf"),
                        domain: "",
                        metadata: [:]))
                let i8e = BASInt8VectorIndexEntry(
                    atomID: "atom_\(ci)",
                    normalizedEmbedding: v)!
                int8RAMBytes += i8e.embeddingByteSize
                try await i8Index.insertInt8(i8e)
            }
            let f32RAMBytes = cell.n * dim * 4 // f32

            // Same query across iterations
            let q = unitVector(seed: 999, dim: dim)
            let qEmb = BASEmbedding(
                vector: q, dimension: dim,
                providerVersion: "perf")
            let iterations = cell.n > 5000 ? 50 : 100
            // Warm
            _ = await f32Index.topK(query: qEmb, k: 10)
            _ = await i8Index.topKInt8(query: qEmb, k: 10)

            // Float32
            let f32Start = now()
            for _ in 0..<iterations {
                _ = await f32Index.topK(query: qEmb, k: 10)
            }
            let f32Elapsed = now() - f32Start

            // int8
            let i8Start = now()
            for _ in 0..<iterations {
                _ = await i8Index.topKInt8(
                    query: qEmb, k: 10)
            }
            let i8Elapsed = now() - i8Start

            let f32Us = f32Elapsed / Double(iterations) * 1e6
            let i8Us = i8Elapsed / Double(iterations) * 1e6
            let speedup = f32Elapsed / i8Elapsed
            let i8MB = Double(int8RAMBytes) / 1024.0 / 1024.0
            let f32MB = Double(f32RAMBytes) / 1024.0 / 1024.0

            print(String(
                format: "  %@ | %9.2f | %8.2f | %5.2f×  | %5.2f MB | %5.2f MB",
                cell.label.padding(
                    toLength: 8,
                    withPad: " ",
                    startingAt: 0),
                f32Us, i8Us, speedup, i8MB, f32MB))
        }

        BASVectorIndex.useInt8VectorStorage = false
        print("")
        print(
            "  RAM shrink: int8 stores corpus at ~25% of Float32 size")
        print(
            "  (the ratio approaches 4× for very large corpora since")
        print(
            "  the per-entry scale + shape overhead amortizes away)。")
        print("")
        #endif
    }
}
