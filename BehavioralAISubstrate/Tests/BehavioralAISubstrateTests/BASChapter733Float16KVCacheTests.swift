// MARK: - BASChapter733Float16KVCacheTests
// chapter 七百三十三 第三/四刀 / M2338-M2339
//
// 3-way quality + memory comparison between Float32 (baseline),
// int8 (chapter 七百二十八),and Float16 (this chapter)。 The
// quality eval mirrors the chapter 七百二十八 cosine-drift gate
// methodology。

import XCTest
import Foundation
@testable import BASRuntimeCore

final class BASChapter733Float16KVCacheTests: XCTestCase {

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

    private func float32Cosine(
        _ a: [Float], _ b: [Float]
    ) -> Float {
        var dot: Float = 0
        for i in 0..<a.count {
            dot += a[i] * b[i]
        }
        return dot
    }

    private func bytesToFloatArray(
        _ d: Data
    ) -> [Float] {
        return d.withUnsafeBytes { rb in
            let p = rb.bindMemory(to: Float.self)
            return Array(p)
        }
    }

    // MARK: - Single-token round-trip

    func testSingleTokenFloat16RoundTrip() {
        #if os(iOS) || os(macOS)
        let dim = 128
        let token = makeToken(seed: 7, dim: dim)
        let f16 = token.toFloat16Token()
        XCTAssertNotNil(f16)
        let recovered = f16?.toFloat32Token()
        XCTAssertNotNil(recovered)
        let origK = bytesToFloatArray(token.keyBytes)
        let recK = bytesToFloatArray(recovered!.keyBytes)
        let origV = bytesToFloatArray(token.valueBytes)
        let recV = bytesToFloatArray(recovered!.valueBytes)
        // Float16 round-trip is near-lossless:cosine ≈ 1
        let cK = float32Cosine(origK, recK)
            / sqrt(float32Cosine(origK, origK)
                * float32Cosine(recK, recK))
        let cV = float32Cosine(origV, recV)
            / sqrt(float32Cosine(origV, origV)
                * float32Cosine(recV, recV))
        XCTAssertGreaterThan(cK, 0.9999)
        XCTAssertGreaterThan(cV, 0.9999)
        #endif
    }

    // MARK: - 3-way drift comparison (Float32 vs Float16 vs int8)

    func test3WayDriftFloat32VsFloat16VsInt8() {
        #if os(iOS) || os(macOS)
        let dim = 128
        let turns = 100

        var maxF16Drift: Float = 0
        var maxI8Drift: Float = 0
        var sumF16: Double = 0
        var sumI8: Double = 0

        for turn in 0..<turns {
            let token = makeToken(
                seed: UInt64(turn * 31 + 1), dim: dim)
            let query = unitVector(
                seed: UInt64(turn * 7 + 13), dim: dim)

            // Float32 reference
            let kF = bytesToFloatArray(token.keyBytes)
            let f32Score = float32Cosine(query, kF)

            // Float16 path
            guard let f16 = token.toFloat16Token(),
                  let recF16 = f16.toFloat32Token()
            else {
                XCTFail("Float16 round-trip failed")
                return
            }
            let kF16Recovered = bytesToFloatArray(
                recF16.keyBytes)
            let f16Score = float32Cosine(
                query, kF16Recovered)

            // int8 path (chapter 七百二十八)
            guard let i8 = token.toQuantizedInt8(),
                  let recI8 = i8.toFloat32Token()
            else {
                XCTFail("int8 round-trip failed")
                return
            }
            let kI8Recovered = bytesToFloatArray(
                recI8.keyBytes)
            let i8Score = float32Cosine(
                query, kI8Recovered)

            let f16Drift = abs(f32Score - f16Score)
            let i8Drift  = abs(f32Score - i8Score)
            if f16Drift > maxF16Drift { maxF16Drift = f16Drift }
            if i8Drift  > maxI8Drift  { maxI8Drift  = i8Drift }
            sumF16 += Double(f16Drift)
            sumI8  += Double(i8Drift)
        }

        let avgF16 = sumF16 / Double(turns)
        let avgI8  = sumI8  / Double(turns)
        let precisionAdvantage =
            avgI8 / max(avgF16, 1e-12)

        print("")
        print(
            "## chapter 七百三十三 第三刀 — 3-way drift comparison")
        print("")
        print(String(
            format: "  Grid: %d turns × dim %d",
            turns, dim))
        print(String(
            format: "  Float16 max drift: %.6f", maxF16Drift))
        print(String(
            format: "  Float16 avg drift: %.6f", avgF16))
        print(String(
            format: "  int8 max drift:    %.6f", maxI8Drift))
        print(String(
            format: "  int8 avg drift:    %.6f", avgI8))
        print(String(
            format: "  Precision advantage (avg): Float16 is %.1f×",
            precisionAdvantage))
        print(String(
            format: "    more precise than int8"))
        print("")

        // Float16 should be MUCH more precise than int8
        // (avg drift typically 10-100× lower)
        XCTAssertLessThan(
            maxF16Drift, 0.001,
            "Float16 max drift \(maxF16Drift) should be ≤ 0.001")
        XCTAssertGreaterThan(
            precisionAdvantage, 5.0,
            "Float16 should be ≥ 5× more precise than int8")
        #endif
    }

    // MARK: - Memory tradeoff

    func testFloat16MemoryFootprintAcrossDims() {
        #if os(iOS) || os(macOS)
        let cells: [(label: String, dim: Int)] = [
            ("dim 64",   64),
            ("dim 128", 128),
            ("dim 256", 256),
            ("dim 512", 512),
        ]

        print("")
        print(
            "## chapter 七百三十三 第四刀 — Float16 KV memory footprint")
        print("")
        print(
            "  dim      | f32 KB | f16 KB | i8 KB | f16/f32 | i8/f32")
        print(
            "  ---------+--------+--------+-------+---------+-------")

        for cell in cells {
            let token = makeToken(
                seed: 42, dim: cell.dim)
            let f16 = token.toFloat16Token()!
            let i8 = token.toQuantizedInt8()!
            let f32Bytes = cell.dim * 4 * 2  // K + V Float32
            let f16Bytes = f16.byteSize
            let i8Bytes = i8.byteSize
            let f16Ratio = Double(f16Bytes)
                / Double(f32Bytes)
            let i8Ratio = Double(i8Bytes)
                / Double(f32Bytes)
            print(String(
                format: "  %@ | %5.1f | %5.1f | %5.1f | %5.2f%%  | %5.2f%%",
                cell.label.padding(
                    toLength: 8, withPad: " ",
                    startingAt: 0),
                Double(f32Bytes) / 1024.0,
                Double(f16Bytes) / 1024.0,
                Double(i8Bytes) / 1024.0,
                f16Ratio * 100,
                i8Ratio * 100))
        }
        print("")
        print(
            "  Float16: ~50% of Float32 size (2× shrink)")
        print(
            "  int8:    ~25% of Float32 size (4× shrink)")
        print(
            "  Float16 trades 2× of int8's memory savings for")
        print(
            "  10-100× higher precision per the drift test。")
        print("")
        #endif
    }

    // MARK: - Codable round-trip

    func testFloat16TokenCodableRoundTrip() throws {
        #if os(iOS) || os(macOS)
        let token = makeToken(seed: 13, dim: 64)
        let f16 = token.toFloat16Token()!
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let data = try encoder.encode(f16)
        let back = try JSONDecoder()
            .decode(BASKVCacheFloat16Token.self, from: data)
        XCTAssertEqual(f16, back)
        // Dequantize back to f32 reproduces same values
        let recA = f16.toFloat32Token()!
        let recB = back.toFloat32Token()!
        XCTAssertEqual(recA.keyBytes, recB.keyBytes)
        XCTAssertEqual(recA.valueBytes, recB.valueBytes)
        #endif
    }

    // MARK: - Feature flag smoke

    func testFloat16FlagDefaultsOff() {
        XCTAssertFalse(
            BASKVCacheFloat16.useFloat16KVCache)
    }
}
