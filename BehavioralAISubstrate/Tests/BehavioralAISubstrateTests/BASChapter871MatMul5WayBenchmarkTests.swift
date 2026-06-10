// MARK: - BASChapter871MatMul5WayBenchmarkTests
// chapter 八百七十一 第一刀 / M3021 — capture LIVE 5-way matMul
// baseline + correct the「.metalMatMulMPSGraph」 misnaming
// discovered while scoping this chapter。
//
// CONTEXT — naming legacy discovery:
//
// `BASAutoRouteChoice.metalMatMulMPSGraph` exists since chapter
// 七百八 but the actual brain.matmul(...) call routes to the
// MSL kernel `matmul_float32` via BASMetalMatMulDispatcher,NOT
// to BASMPSGraphMatMulKernel actor。 The enum-name implies
// MPSGraph but the work is done by custom MSL。 Same false-naming
// pattern chapter 八百六十八 caught for FlashAttention's
// 「1.24-1.62× faster」 doc claim。
//
// This chapter:
//   1. Pin the actual MSL behavior with one set of measurements
//   2. Run BASMPSGraphMatMulKernel actor as TRUE 5th contestant
//      (chapter 870 attention pattern proved MPSGraph wins at
//      production shapes via 30× cache speedup — replicate for
//      matMul)
//   3. Print 5-way data + weak assertions
//   4. If MPSGraph wins → chapter 八百七十一 knife 2-5 wire it
//      through Brain。 If MSL wins → audit + DECLINE-WITH-TRIGGER
//      (the existing brain.matmul stays as-is,we document
//      that MSL beat MPSGraph at the measured shapes)
//
// 5 contestants:
//   - Rust naive (bas_ranker_matmul_naive)
//   - Rust blocked (bas_ranker_matmul_blocked)
//   - Metal MSL custom (brain.matmul → BASMetalMatMulDispatcher
//     → matmul_float32)
//   - MPSGraph actor cold (per-call new kernel,no cache)
//   - MPSGraph actor warm (shared kernel + executable cache —
//     chapter 870 pattern measured 30.48× speedup for attention)
//
// Production shapes:
//   - 128×128×128 (small)
//   - 512×512×512 (medium — chapter 七百八 comment said Metal wins
//     here by 18× over Rust blocked,verify)
//   - 1024×1024×1024 (large)

import XCTest
@testable import BASRuntimeCore
@testable import BASHostKit
@testable import BASMetalSubstrate

#if os(iOS) || os(macOS)
import BASRustMemoryTrackerBinary
#endif

#if !os(iOS)  // ch 1022 source-gate
final class BASChapter871MatMul5WayBenchmarkTests: XCTestCase {

    // MARK: - Fixture

    private func makeMatrices(
        M: Int, N: Int, K: Int
    ) -> (a: [Float], b: [Float]) {
        var seed: UInt32 = 0xCAFEBABE
        func next() -> Float {
            seed = seed &* 1664525 &+ 1013904223
            return Float(seed & 0xFFFF)
                / Float(0xFFFF) - 0.5
        }
        let a = (0..<(M * K)).map { _ in next() }
        let b = (0..<(K * N)).map { _ in next() }
        return (a, b)
    }

    private func timeMedianNs(
        warmup: Int,
        iterations: Int,
        op: () async throws -> Void
    ) async rethrows -> Double {
        for _ in 0..<warmup { try await op() }
        var samples: [Double] = []
        samples.reserveCapacity(iterations)
        for _ in 0..<iterations {
            let s = DispatchTime.now().uptimeNanoseconds
            try await op()
            let e = DispatchTime.now().uptimeNanoseconds
            samples.append(Double(e - s))
        }
        samples.sort()
        return samples[samples.count / 2]
    }

    // MARK: - MPSGraph kernel helper (matches chapter 869 pattern)

    private func mpsGraphMatMul(
        _ kernel: BASMPSGraphMatMulKernel,
        a: [Float], M: Int, K: Int,
        b: [Float], N: Int
    ) async throws -> [Float] {
        let inputs = BASCanonicalKernelInputBuilders
            .matMul(a: a, b: b, M: M, K: K, N: N)
        let out = try await kernel.evaluate(inputs: inputs)
        return BASCanonicalKernelInputBuilders
            .dataToFloatArray(
                out.payloads[0],
                elementCount: M * N)
    }

    // MARK: - Knife 1A: numerical correctness pin

    /// At a medium shape,all 5 paths must produce the same
    /// output within IEEE Float32 1e-3 tolerance (matmul
    /// accumulates,looser than attention's 1e-4)。
    func testFiveWayNumericalAgreementAtMedium() async throws {
        let kernel: BASMPSGraphMatMulKernel
        do {
            kernel = try BASMPSGraphMatMulKernel()
        } catch BASKernelError.frameworkUnavailable {
            throw XCTSkip("Metal unavailable")
        }
        let brain = try await BASCognitiveBrain
            .makeWithAllPilots()

        // 128x128x128 — large enough to exercise tile paths,
        // small enough to compute Rust naive in a reasonable time
        let (M, N, K) = (128, 128, 128)
        let (a, b) = makeMatrices(M: M, N: N, K: K)

        // Rust naive reference
        var cNaive = [Float](repeating: 0, count: M * N)
        let rcNaive = a.withUnsafeBufferPointer { ap in
            b.withUnsafeBufferPointer { bp in
                cNaive.withUnsafeMutableBufferPointer { cp in
                    bas_ranker_matmul_naive(
                        ap.baseAddress, a.count,
                        bp.baseAddress, b.count,
                        cp.baseAddress, cp.count,
                        M, N, K)
                }
            }
        }
        XCTAssertEqual(rcNaive, 0)

        // Rust blocked
        var cBlocked = [Float](repeating: 0, count: M * N)
        let rcBlocked = a.withUnsafeBufferPointer { ap in
            b.withUnsafeBufferPointer { bp in
                cBlocked.withUnsafeMutableBufferPointer { cp in
                    bas_ranker_matmul_blocked(
                        ap.baseAddress, a.count,
                        bp.baseAddress, b.count,
                        cp.baseAddress, cp.count,
                        M, N, K)
                }
            }
        }
        XCTAssertEqual(rcBlocked, 0)

        // Metal MSL (via brain — misnamed enum but real impl)
        let cMSL = try await brain.matmul(
            a: a, aRows: M, aCols: K,
            b: b, bRows: K, bCols: N)

        // MPSGraph actor (new contestant)
        let cMPS = try await mpsGraphMatMul(
            kernel, a: a, M: M, K: K, b: b, N: N)

        // All four must agree within 1e-3 — matmul accumulates
        // K terms,floating-point reorder tolerance is looser
        // than single-op attention
        XCTAssertEqual(cNaive.count, M * N)
        XCTAssertEqual(cBlocked.count, M * N)
        XCTAssertEqual(cMSL.count, M * N)
        XCTAssertEqual(cMPS.count, M * N)
        for i in 0..<cNaive.count {
            XCTAssertEqual(cNaive[i], cBlocked[i],
                accuracy: 1e-3,
                "naive ≡ blocked idx \(i)")
            XCTAssertEqual(cNaive[i], cMSL[i],
                accuracy: 1e-3,
                "naive ≡ MSL idx \(i)")
            XCTAssertEqual(cNaive[i], cMPS[i],
                accuracy: 1e-3,
                "naive ≡ MPSGraph idx \(i)")
        }
    }

    // MARK: - Knife 1B: 5-way timing at 3 production shapes

    private func timeAllFivePathsAt(
        M: Int, N: Int, K: Int,
        iterations: Int
    ) async throws {
        let kernelWarmCache: BASMPSGraphMatMulKernel
        do {
            _ = try BASMPSGraphMatMulKernel()
            // BASMPSGraphMatMulKernel.init() does NOT take a cache
            // parameter (unlike attention/RMS/RoPE)。 Verify via
            // the public init signature。 The "warm" measurement
            // therefore reflects MPSGraph's own internal
            // executable caching from prior calls — not
            // BASMPSGraphExecutableCache layered on top。
            kernelWarmCache = try BASMPSGraphMatMulKernel()
        } catch BASKernelError.frameworkUnavailable {
            throw XCTSkip("Metal unavailable at (\(M),\(N),\(K))")
        }
        let brain = try await BASCognitiveBrain
            .makeWithAllPilots()
        let (a, b) = makeMatrices(M: M, N: N, K: K)

        // Warm all paths
        var cNaiveSink = [Float](repeating: 0, count: M * N)
        var cBlockedSink = [Float](repeating: 0, count: M * N)
        for _ in 0..<3 {
            _ = a.withUnsafeBufferPointer { ap in
                b.withUnsafeBufferPointer { bp in
                    cNaiveSink.withUnsafeMutableBufferPointer { cp in
                        bas_ranker_matmul_naive(
                            ap.baseAddress, a.count,
                            bp.baseAddress, b.count,
                            cp.baseAddress, cp.count,
                            M, N, K)
                    }
                }
            }
            _ = try await brain.matmul(
                a: a, aRows: M, aCols: K,
                b: b, bRows: K, bCols: N)
            _ = try await mpsGraphMatMul(
                kernelWarmCache, a: a, M: M, K: K, b: b, N: N)
        }

        // Time each path
        let naiveNs = await timeMedianNs(
            warmup: 0, iterations: iterations
        ) {
            _ = a.withUnsafeBufferPointer { ap in
                b.withUnsafeBufferPointer { bp in
                    cNaiveSink.withUnsafeMutableBufferPointer { cp in
                        bas_ranker_matmul_naive(
                            ap.baseAddress, a.count,
                            bp.baseAddress, b.count,
                            cp.baseAddress, cp.count,
                            M, N, K)
                    }
                }
            }
        }
        let blockedNs = await timeMedianNs(
            warmup: 0, iterations: iterations
        ) {
            _ = a.withUnsafeBufferPointer { ap in
                b.withUnsafeBufferPointer { bp in
                    cBlockedSink.withUnsafeMutableBufferPointer { cp in
                        bas_ranker_matmul_blocked(
                            ap.baseAddress, a.count,
                            bp.baseAddress, b.count,
                            cp.baseAddress, cp.count,
                            M, N, K)
                    }
                }
            }
        }
        let mslNs = try await timeMedianNs(
            warmup: 0, iterations: iterations
        ) {
            _ = try await brain.matmul(
                a: a, aRows: M, aCols: K,
                b: b, bRows: K, bCols: N)
        }
        let mpsColdNs = try await timeMedianNs(
            warmup: 0, iterations: 3
        ) {
            // Each iteration uses a FRESH kernel — simulates
            // the per-call kernel creation pattern that would
            // happen if Brain didn't share the kernel instance
            let coldKernel = try BASMPSGraphMatMulKernel()
            _ = try await self.mpsGraphMatMul(
                coldKernel, a: a, M: M, K: K, b: b, N: N)
        }
        let mpsWarmNs = try await timeMedianNs(
            warmup: 0, iterations: iterations
        ) {
            // Reuses kernelWarmCache → MPSGraph's internal
            // executable cache amortizes
            _ = try await self.mpsGraphMatMul(
                kernelWarmCache, a: a, M: M, K: K, b: b, N: N)
        }

        print(String(format:
            "BENCH 5-way matMul M=%d N=%d K=%d (workProduct=%d):\n" +
            "  Rust naive       = %12.0f ns\n" +
            "  Rust blocked     = %12.0f ns (ratio naive=%.3fx)\n" +
            "  Metal MSL        = %12.0f ns (ratio naive=%.3fx)\n" +
            "  MPSGraph cold    = %12.0f ns (ratio naive=%.3fx)\n" +
            "  MPSGraph warm    = %12.0f ns (ratio naive=%.3fx)",
            M, N, K, M * N * K,
            naiveNs,
            blockedNs, blockedNs / naiveNs,
            mslNs, mslNs / naiveNs,
            mpsColdNs, mpsColdNs / naiveNs,
            mpsWarmNs, mpsWarmNs / naiveNs))

        // Weak bound:MPSGraph warm shouldn't be more than 5×
        // slower than MSL (which we know is fast)。 If it is,
        // something is wrong (cache disabled,kernel not
        // reusing executable)。
        XCTAssertLessThan(mpsWarmNs, mslNs * 5.0,
            "MPSGraph warm at (\(M),\(N),\(K)) shouldn't be " +
            ">5× slower than MSL — mps=\(mpsWarmNs) " +
            "msl=\(mslNs)")
    }

    func testFiveWayTimingAt128() async throws {
        try await timeAllFivePathsAt(
            M: 128, N: 128, K: 128, iterations: 30)
    }

    func testFiveWayTimingAt256() async throws {
        try await timeAllFivePathsAt(
            M: 256, N: 256, K: 256, iterations: 10)
    }

    func testFiveWayTimingAt512() async throws {
        try await timeAllFivePathsAt(
            M: 512, N: 512, K: 512, iterations: 5)
    }
}
#endif
