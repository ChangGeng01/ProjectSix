// MARK: - BASChapter726Int8QuantizationTests
// chapter 七百二十六 第二刀 / M2302
//
// Anti-drift suite for the int8 quantization Swift bridge。
// Validates:
//   1. Round-trip quantize → dequantize stays within scale/2
//   2. int8 matmul matches Float32 reference within drift bound
//   3. Empty / zero inputs handled gracefully
//   4. 4× memory savings verified at Swift array level
//   5. Shape mismatch returns nil

import XCTest
import Foundation
@testable import BASRuntimeCore

final class BASChapter726Int8QuantizationTests: XCTestCase {

    func testQuantizeEmptyReturnsEmpty() {
        #if os(iOS) || os(macOS)
        let r = BASAutoRouteRanker.quantizeInt8([])
        XCTAssertNotNil(r)
        XCTAssertTrue(r?.quantized.isEmpty ?? false)
        XCTAssertEqual(r?.scale, 0)
        #endif
    }

    func testQuantizeAllZerosReturnsAllZeros() {
        #if os(iOS) || os(macOS)
        let r = BASAutoRouteRanker.quantizeInt8(
            [Float](repeating: 0, count: 100))
        XCTAssertNotNil(r)
        XCTAssertEqual(r!.quantized,
            [Int8](repeating: 0, count: 100))
        XCTAssertEqual(r!.scale, 0)
        #endif
    }

    func testQuantizeSingleValueRoundTrip() {
        #if os(iOS) || os(macOS)
        let r = BASAutoRouteRanker.quantizeInt8([1.0])!
        XCTAssertEqual(r.quantized[0], 127)
        let back = BASAutoRouteRanker.dequantizeInt8(
            r.quantized, scale: r.scale)!
        XCTAssertEqual(back[0], 1.0, accuracy: 1e-6)
        #endif
    }

    func testRoundTripTypicalEmbeddingValues() {
        #if os(iOS) || os(macOS)
        // 384-dim embedding-style values in [-1, 1]
        let x: [Float] = (0..<384).map {
            Float($0) / 192.0 - 1.0
        }
        let q = BASAutoRouteRanker.quantizeInt8(x)!
        let y = BASAutoRouteRanker.dequantizeInt8(
            q.quantized, scale: q.scale)!
        XCTAssertEqual(x.count, y.count)
        // Error ≤ scale/2 = 1/254 ≈ 0.004
        for i in 0..<x.count {
            XCTAssertEqual(
                x[i], y[i], accuracy: 0.005,
                "drift at i=\(i):x=\(x[i]) y=\(y[i])")
        }
        #endif
    }

    func testMatmulInt8MatchesFloat32Reference() {
        #if os(iOS) || os(macOS)
        // 4×3 × 3×2 = 4×2
        let af: [Float] = [
            0.5, 0.1, 0.3,
            0.2, 0.7, 0.4,
            0.6, 0.5, 0.1,
            0.3, 0.8, 0.2,
        ]
        let bf: [Float] = [
            0.4, 0.2,
            0.1, 0.6,
            0.3, 0.5,
        ]
        let m = 4, k = 3, n = 2
        // Float32 reference
        var cRef = [Float](repeating: 0, count: m * n)
        for i in 0..<m {
            for j in 0..<n {
                var acc: Float = 0
                for kk in 0..<k {
                    acc += af[i * k + kk] * bf[kk * n + j]
                }
                cRef[i * n + j] = acc
            }
        }
        // int8 matmul
        let aQ = BASAutoRouteRanker.quantizeInt8(af)!
        let bQ = BASAutoRouteRanker.quantizeInt8(bf)!
        let c = BASAutoRouteRanker.matmulInt8(
            a: aQ.quantized, scaleA: aQ.scale,
            b: bQ.quantized, scaleB: bQ.scale,
            m: m, k: k, n: n)!
        for i in 0..<(m * n) {
            XCTAssertEqual(
                c[i], cRef[i], accuracy: 0.01,
                "drift at i=\(i):int8 \(c[i]) f32 \(cRef[i])")
        }
        #endif
    }

    func testMatmulShapeMismatchReturnsNil() {
        #if os(iOS) || os(macOS)
        let a = [Int8](repeating: 1, count: 4)
        let b = [Int8](repeating: 1, count: 4)
        // a.count = 4 ≠ 2 * 3
        let c = BASAutoRouteRanker.matmulInt8(
            a: a, scaleA: 1,
            b: b, scaleB: 1,
            m: 2, k: 3, n: 2)
        XCTAssertNil(c)
        #endif
    }

    func test4xMemorySavingsVerified() {
        #if os(iOS) || os(macOS)
        let x = [Float](repeating: 0.5, count: 1024)
        let q = BASAutoRouteRanker.quantizeInt8(x)!
        // Float32 = 4 bytes * 1024 = 4096 bytes
        // int8 = 1 byte * 1024 + 4 bytes scale = 1028 bytes
        let f32Bytes = x.count * MemoryLayout<Float>.size
        let int8Bytes = q.quantized.count
            * MemoryLayout<Int8>.size
            + MemoryLayout<Float>.size
        let ratio = Double(f32Bytes) / Double(int8Bytes)
        XCTAssertGreaterThan(ratio, 3.9)
        XCTAssertLessThan(ratio, 4.1)
        print(String(
            format: "  int8 memory savings: %.2f×",
            ratio))
        #endif
    }
}
