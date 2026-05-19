// MARK: - BASChapter726Int8PerfTests
// chapter 七百二十六 第三刀 / M2303
//
// Perf measurement for int8 quantize + matmul vs Float32 baseline。
// Plan-agent honest estimate ~1.5× compute on M1/M2 (no AMX)。
// Memory shrink already verified at 3.98× in Knife 2 test。

import XCTest
import Foundation
@testable import BASRuntimeCore
#if os(iOS) || os(macOS)
import BASRustMemoryTrackerBinary
#endif

final class BASChapter726Int8PerfTests: XCTestCase {

    private func now() -> Double {
        return CFAbsoluteTimeGetCurrent()
    }

    private func swiftFloat32MatMul(
        a: [Float], b: [Float],
        m: Int, k: Int, n: Int
    ) -> [Float] {
        var c = [Float](repeating: 0, count: m * n)
        for i in 0..<m {
            for j in 0..<n {
                var acc: Float = 0
                for kk in 0..<k {
                    acc += a[i * k + kk] * b[kk * n + j]
                }
                c[i * n + j] = acc
            }
        }
        return c
    }

    func testPerfGridQuantizeAndMatmul() {
        #if os(iOS) || os(macOS)
        // Quantize-only timing across 3 vector sizes
        let qCells: [(label: String, n: Int)] = [
            ("256-dim",   256),
            ("1024-dim", 1024),
            ("8192-dim", 8192),
        ]

        print("")
        print(
            "## chapter 七百二十六 第三刀 — int8 quantize perf")
        print("")
        print(
            "  size      | quantize µs/op | dequantize µs/op")
        print(
            "  ----------+----------------+------------------")

        for cell in qCells {
            let x: [Float] = (0..<cell.n).map {
                Float($0) / Float(cell.n / 2) - 1.0
            }
            let iterations = 500
            // Warm
            _ = BASAutoRouteRanker.quantizeInt8(x)
            // Quantize timing
            let qStart = now()
            var lastR: BASAutoRouteRanker
                .BASQuantizeInt8Result? = nil
            for _ in 0..<iterations {
                lastR = BASAutoRouteRanker.quantizeInt8(x)
            }
            let qElapsed = now() - qStart
            // Dequantize timing
            let q = lastR!.quantized
            let s = lastR!.scale
            let dStart = now()
            for _ in 0..<iterations {
                _ = BASAutoRouteRanker.dequantizeInt8(
                    q, scale: s)
            }
            let dElapsed = now() - dStart
            let qUs =
                qElapsed / Double(iterations) * 1e6
            let dUs =
                dElapsed / Double(iterations) * 1e6
            print(String(
                format: "  %@ |  %12.2f |   %12.2f",
                cell.label.padding(
                    toLength: 8,
                    withPad: " ",
                    startingAt: 0),
                qUs, dUs))
        }

        // Matmul timing: 64×64 × 64×64 (4096 outputs)
        let m = 64, k = 64, n = 64
        let af: [Float] = (0..<m*k).map {
            Float($0 % 100) / 100.0 - 0.5
        }
        let bf: [Float] = (0..<k*n).map {
            Float(($0 * 3) % 100) / 100.0 - 0.5
        }
        let aQ = BASAutoRouteRanker.quantizeInt8(af)!
        let bQ = BASAutoRouteRanker.quantizeInt8(bf)!
        let iter = 50

        // Warm
        _ = swiftFloat32MatMul(a: af, b: bf,
            m: m, k: k, n: n)
        _ = BASAutoRouteRanker.matmulInt8(
            a: aQ.quantized, scaleA: aQ.scale,
            b: bQ.quantized, scaleB: bQ.scale,
            m: m, k: k, n: n)

        // Swift Float32
        let f32Start = now()
        for _ in 0..<iter {
            _ = swiftFloat32MatMul(
                a: af, b: bf, m: m, k: k, n: n)
        }
        let f32Elapsed = now() - f32Start

        // int8 (Rust FFI)
        let i8Start = now()
        for _ in 0..<iter {
            _ = BASAutoRouteRanker.matmulInt8(
                a: aQ.quantized, scaleA: aQ.scale,
                b: bQ.quantized, scaleB: bQ.scale,
                m: m, k: k, n: n)
        }
        let i8Elapsed = now() - i8Start

        let f32Us = f32Elapsed / Double(iter) * 1e6
        let i8Us = i8Elapsed / Double(iter) * 1e6
        let speedup = f32Elapsed / i8Elapsed
        print("")
        print(
            "## chapter 七百二十六 第三刀 — 64×64 × 64×64 matmul")
        print("")
        print(String(
            format: "  Swift Float32 (scalar):  %.2f µs/op",
            f32Us))
        print(String(
            format: "  Rust int8 (FFI):         %.2f µs/op",
            i8Us))
        print(String(
            format: "  speedup:                 %.2f×",
            speedup))
        print("")
        print(
            "  Caveat: comparison is vs SCALAR Swift triple-nested")
        print(
            "  loop。 Real Float32 baseline (Rust SIMD-blocked from")
        print(
            "  chapter 七百八 第一刀) is much faster。 See below for")
        print(
            "  the apples-to-apples Rust f32 vs Rust int8 comparison。")
        print("")

        // Apples-to-apples: Rust int8 vs Rust Float32 SIMD blocked
        // Calls bas_ranker_matmul_simd_blocked via Foundation —
        // the existing chapter 七百八 path。
        var cF32 = [Float](repeating: 0, count: m * n)
        // Note: Rust f32 matmul signature is (m, n, k) order — see
        // bas_ranker_matmul_simd_blocked declaration in header。
        let rustF32Start = now()
        for _ in 0..<iter {
            _ = af.withUnsafeBufferPointer { ap in
                bf.withUnsafeBufferPointer { bp in
                    cF32.withUnsafeMutableBufferPointer { cp in
                        bas_ranker_matmul_simd_blocked(
                            ap.baseAddress, ap.count,
                            bp.baseAddress, bp.count,
                            cp.baseAddress, cp.count,
                            m, n, k)
                    }
                }
            }
        }
        let rustF32Elapsed = now() - rustF32Start
        let rustF32Us =
            rustF32Elapsed / Double(iter) * 1e6
        let honestSpeedup =
            rustF32Elapsed / i8Elapsed

        print(
            "## chapter 七百二十六 第三刀 — APPLES-TO-APPLES")
        print("")
        print(String(
            format: "  Rust Float32 SIMD-blocked: %.2f µs/op",
            rustF32Us))
        print(String(
            format: "  Rust int8 (scalar loop):   %.2f µs/op",
            i8Us))
        print(String(
            format: "  honest speedup:            %.2f×",
            honestSpeedup))
        print("")
        print(
            "  Plan-agent honest expectation:")
        print(
            "    Plan: \"~1.5× compute on M1/M2 (no AMX,modest")
        print(
            "           perf win — but still net positive once")
        print(
            "           memory bandwidth dominates)\"")
        print(
            "    Memory: 3.98× shrink (verified Knife 2)。")
        print("")
        #endif
    }
}
