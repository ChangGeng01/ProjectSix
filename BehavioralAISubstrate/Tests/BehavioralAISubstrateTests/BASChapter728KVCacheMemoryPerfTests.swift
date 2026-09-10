// MARK: - BASChapter728KVCacheMemoryPerfTests
// chapter 七百二十八 第四刀 / M2314
//
// Memory footprint comparison for the int8 KV cache path vs
// the Float32 baseline at typical session-length budgets。
// Plan-agent estimate: 2-3× memory shrink。 Reality (per per-
// token measurement at Knife 3): ~3.82×。

import XCTest
import Foundation
@testable import BASRuntimeCore

final class BASChapter728KVCacheMemoryPerfTests: XCTestCase {

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

    private func makeToken(
        seed: UInt64, dim: Int
    ) -> BASTransformerKVCacheToken {
        let k = unitVector(seed: seed * 7, dim: dim)
        let v = unitVector(seed: seed * 11 + 3, dim: dim)
        let kBytes = k.withUnsafeBufferPointer {
            Data(buffer: $0)
        }
        let vBytes = v.withUnsafeBufferPointer {
            Data(buffer: $0)
        }
        return BASTransformerKVCacheToken(
            keyBytes: kBytes,
            valueBytes: vBytes,
            elementCount: dim)
    }

    func testMemoryFootprintAcrossSessionLengths() {
        #if os(iOS) || os(macOS)
        // Each cell:(turns × layers × dim) = total elements。
        // Realistic session shapes for a small model (e.g.
        // 8-layer transformer with 128-dim per-head KV state)。
        let cells: [(label: String,
                     turns: Int,
                     layers: Int,
                     dim: Int)] = [
            ("5 turns × 8 layers × 128 dim",   5, 8, 128),
            ("20 turns × 8 layers × 128 dim", 20, 8, 128),
            ("50 turns × 8 layers × 128 dim", 50, 8, 128),
            ("100 turns × 16 layers × 256 dim", 100, 16, 256),
        ]

        print("")
        print(
            "## chapter 七百二十八 第四刀 — KV cache memory footprint")
        print("")
        print(
            "  cell                              | Float32 KB | int8 KB | ratio")
        print(
            "  ----------------------------------+------------+---------+------")

        for cell in cells {
            var f32Bytes = 0
            var int8Bytes = 0
            for turn in 0..<cell.turns {
                for layer in 0..<cell.layers {
                    let seed = UInt64(
                        turn * 1000 + layer)
                    let token = makeToken(
                        seed: seed, dim: cell.dim)
                    // Float32: keyBytes + valueBytes
                    f32Bytes += token.keyBytes.count
                        + token.valueBytes.count
                    // int8 quantized
                    guard let q = token
                        .toQuantizedInt8()
                    else {
                        XCTFail(
                            "quantize failed at turn \(turn) layer \(layer)")
                        return
                    }
                    int8Bytes += q.byteSize
                }
            }
            let f32KB = Double(f32Bytes) / 1024.0
            let int8KB = Double(int8Bytes) / 1024.0
            let ratio = Double(f32Bytes)
                / Double(int8Bytes)
            print(String(
                format: "  %@ | %10.1f | %7.1f | %4.2f×",
                cell.label.padding(
                    toLength: 32,
                    withPad: " ",
                    startingAt: 0),
                f32KB, int8KB, ratio))
        }

        print("")
        print(
            "  Per-token overhead (2 scales + counts) is fixed,")
        print(
            "  so the shrink ratio asymptotes to 4× as dim grows。")
        print(
            "  At dim 128 ratio is ~3.82×;at dim 256 ratio is")
        print(
            "  ~3.9×;at dim 512+ the ratio is essentially 4×。")
        print("")
        #endif
    }
}
