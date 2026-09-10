// MARK: - BASMPSGraphCacheBenchmarkTests
// chapter 六百六十七 / M2046 — wallclock benchmark
//                              asserting Phase J cache
//                              amortization delivers ≥5×
//                              speedup on 1000-dispatch
//                              loop。
//
// ## Why this benchmark exists
//
// wild-rolling-meerkat Phase J's promise:caching MPSGraph
// executables across dispatches eliminates per-call build
// overhead。 chapter 476 / M1280 doctrine baseline:1-3 ms
// per kernel invoke。 amortized:dispatch dominates,build
// pre-amortized → ≤1/5 wallclock。
//
// ## What this asserts
//
// For the simplest MPSGraph kernel (softmax,row-wise on
// (4×8) tensor):
//   - cache-OFF wallclock for 1000 dispatches: t_cold
//   - cache-ON wallclock for 1000 dispatches:  t_amortized
//   - Assertion: t_amortized < t_cold / 5.0
//
// ## Honest scope acknowledgment
//
// Wallclock benchmarks are inherently noisy on shared
// hardware。 The assertion uses a 5× ratio (vs. 10× or
// stricter) to absorb expected GPU + scheduler jitter
// while still capturing the order-of-magnitude
// improvement Phase J was designed to deliver。 If this
// test flakes on M-series silicon under load,the
// improvement is real but the assertion threshold may
// need re-tuning per-host (mark as XCTSkip + open
// follow-up)。

import XCTest
@testable import BASMetalSubstrate
@testable import BASRuntimeCore

final class BASMPSGraphCacheBenchmarkTests: XCTestCase {

    /// 5× speedup target from wild-rolling-meerkat plan
    /// Phase J chapter 667。
    private static let speedupMultipleTarget: Double = 5.0

    /// 1000 dispatches per loop — large enough that per-
    /// call overhead amortizes;small enough to complete
    /// in CI budget。
    private static let dispatchCount: Int = 1000

    private func makeSoftmaxInput(
        rows: Int, cols: Int
    ) -> BASKernelInputs {
        var state: UInt32 = 1
        let x: [Float] = (0..<(rows * cols)).map { _ in
            state = state &* 1_664_525 &+ 1_013_904_223
            return (Float(state) / Float(UInt32.max)
                    - 0.5) * 2.0
        }
        let xD = x.withUnsafeBufferPointer { Data(buffer: $0) }
        return BASKernelInputs(
            descriptors: [
                BASTensorDescriptor.contiguous(
                    shape: [rows, cols],
                    dataType: .float32,
                    backingKind: .metalBuffer,
                    rankTag: _2D.rankTag)
            ],
            payloads: [xD])
    }

    /// Phase J 5× speedup assertion。 NOT a microbenchmark
    /// — runs full 1000-dispatch loop on real GPU。 If
    /// flaky under shared CI hardware,investigate;don't
    /// just bump the threshold。
    func testCacheOnDispatchIsAt5XSpeedupVsCacheOff()
        async throws
    {
        let inputs = makeSoftmaxInput(rows: 4, cols: 8)
        let count = Self.dispatchCount
        let target = Self.speedupMultipleTarget

        // Cache OFF baseline
        let off = try BASMPSGraphSoftmaxKernel()
        // Warm up GPU
        _ = try await off.evaluate(inputs: inputs)
        let coldStart = DispatchTime.now()
            .uptimeNanoseconds
        for _ in 0..<count {
            _ = try await off.evaluate(inputs: inputs)
        }
        let coldEnd = DispatchTime.now().uptimeNanoseconds
        let tCold = Double(coldEnd &- coldStart)

        // Cache ON amortized
        let cache = BASMPSGraphExecutableCache()
        let on = try BASMPSGraphSoftmaxKernel(cache: cache)
        // Warm up + populate cache
        _ = try await on.evaluate(inputs: inputs)
        let warmStart = DispatchTime.now()
            .uptimeNanoseconds
        for _ in 0..<count {
            _ = try await on.evaluate(inputs: inputs)
        }
        let warmEnd = DispatchTime.now().uptimeNanoseconds
        let tAmortized = Double(warmEnd &- warmStart)

        // Assertion:cache-on is ≥5× faster than cache-off
        let speedup = tCold / tAmortized
        XCTAssertGreaterThanOrEqual(
            speedup, target,
            "Phase J cache amortization speedup " +
            "\(String(format: "%.2f", speedup))× failed " +
            "to meet \(target)× target。 " +
            "t_cold=\(tCold)ns, t_amortized=\(tAmortized)ns " +
            "for \(count) dispatches。")

        // Verify cache reached steady-state (hits >> misses)
        let hits = await cache.hitCount
        let misses = await cache.missCount
        let ratio = await cache.hitRatio
        XCTAssertGreaterThan(hits, misses * 10,
            "Cache should have far more hits than misses " +
            "after \(count + 1) dispatches。 hits=\(hits), " +
            "misses=\(misses), ratio=\(ratio)")
    }
}
