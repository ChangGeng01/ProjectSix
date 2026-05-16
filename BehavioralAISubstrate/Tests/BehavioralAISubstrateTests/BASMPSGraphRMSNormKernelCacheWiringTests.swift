// MARK: - BASMPSGraphRMSNormKernelCacheWiringTests
// chapter 六百六十五 / M2037 — byte-equality PROOF tests
//                              verifying the cache-on
//                              fast path produces IDENTICAL
//                              outputs to the cache-off
//                              baseline path

import XCTest
@testable import BASMetalSubstrate
@testable import BASRuntimeCore

final class BASMPSGraphRMSNormKernelCacheWiringTests:
    XCTestCase
{
    // MARK: - Helpers

    private func makeInput(
        batch: Int, hidden: Int, seed: UInt32
    ) -> BASKernelInputs {
        var rng = SeededFloatRNG(seed: seed)
        let x: [Float] = (0..<(batch * hidden)).map { _ in
            rng.next()
        }
        let w: [Float] = (0..<hidden).map { _ in rng.next() }
        let xData = x.withUnsafeBufferPointer {
            Data(buffer: $0)
        }
        let wData = w.withUnsafeBufferPointer {
            Data(buffer: $0)
        }
        return BASKernelInputs(
            descriptors: [
                BASTensorDescriptor.contiguous(
                    shape: [batch, hidden],
                    dataType: .float32,
                    backingKind: .metalBuffer,
                    rankTag: _2D.rankTag),
                BASTensorDescriptor.contiguous(
                    shape: [hidden],
                    dataType: .float32,
                    backingKind: .metalBuffer,
                    rankTag: _1D.rankTag)
            ],
            payloads: [xData, wData])
    }

    // MARK: - Cache-off baseline preservation

    func testCacheOffPathProducesValidOutput() async throws {
        let baseline = try BASMPSGraphRMSNormKernel(
            epsilon: 1e-6)
        let inputs = makeInput(
            batch: 2, hidden: 8, seed: 42)
        let outputs = try await baseline.evaluate(
            inputs: inputs)
        XCTAssertEqual(outputs.descriptors.count, 1)
        XCTAssertEqual(outputs.payloads.count, 1)
        XCTAssertEqual(outputs.payloads[0].count, 2 * 8 * 4)
    }

    // MARK: - Cache-on produces byte-equal output

    func testCacheOnFastPathIsByteEqualToCacheOffBaseline()
        async throws
    {
        let cacheOff = try BASMPSGraphRMSNormKernel(
            epsilon: 1e-6)
        let cache = BASMPSGraphExecutableCache()
        let cacheOn = try BASMPSGraphRMSNormKernel(
            epsilon: 1e-6, cache: cache)

        let inputs = makeInput(
            batch: 2, hidden: 8, seed: 42)

        let baselineOut = try await cacheOff.evaluate(
            inputs: inputs)
        let cacheOnOut = try await cacheOn.evaluate(
            inputs: inputs)

        XCTAssertEqual(
            baselineOut.payloads[0],
            cacheOnOut.payloads[0],
            "Cache-on output must be byte-equal to cache-off baseline")
    }

    // MARK: - Repeated dispatches hit the cache

    func testRepeatedDispatchesHitTheCache() async throws {
        let cache = BASMPSGraphExecutableCache()
        let kernel = try BASMPSGraphRMSNormKernel(
            epsilon: 1e-6, cache: cache)

        let inputs = makeInput(
            batch: 2, hidden: 8, seed: 42)

        // 4 dispatches with same shape → 1 miss + 3 hits
        for _ in 0..<4 {
            _ = try await kernel.evaluate(inputs: inputs)
        }

        let hits = await cache.hitCount
        let misses = await cache.missCount
        let execCount = await cache.executableCount

        XCTAssertEqual(misses, 1,
            "First dispatch must miss + compile fresh")
        XCTAssertEqual(hits, 3,
            "Subsequent 3 dispatches must hit")
        XCTAssertEqual(execCount, 1,
            "Only 1 unique shape → 1 executable stored")
    }

    // MARK: - Distinct shapes get distinct cache entries

    func testDistinctShapesGetDistinctCacheEntries()
        async throws
    {
        let cache = BASMPSGraphExecutableCache()
        let kernel = try BASMPSGraphRMSNormKernel(
            epsilon: 1e-6, cache: cache)

        let inputs2x8 = makeInput(
            batch: 2, hidden: 8, seed: 42)
        let inputs4x16 = makeInput(
            batch: 4, hidden: 16, seed: 42)

        _ = try await kernel.evaluate(inputs: inputs2x8)
        _ = try await kernel.evaluate(inputs: inputs4x16)
        _ = try await kernel.evaluate(inputs: inputs2x8)
        _ = try await kernel.evaluate(inputs: inputs4x16)

        let hits = await cache.hitCount
        let misses = await cache.missCount
        let execCount = await cache.executableCount

        XCTAssertEqual(misses, 2,
            "2 unique shapes → 2 cache misses")
        XCTAssertEqual(hits, 2,
            "Each shape revisited once → 2 hits")
        XCTAssertEqual(execCount, 2,
            "2 unique shapes → 2 executables stored")
    }

    // MARK: - Hit-ratio accessor

    func testHitRatioAfterTenDispatches() async throws {
        let cache = BASMPSGraphExecutableCache()
        let kernel = try BASMPSGraphRMSNormKernel(
            epsilon: 1e-6, cache: cache)

        let inputs = makeInput(
            batch: 3, hidden: 4, seed: 99)
        for _ in 0..<10 {
            _ = try await kernel.evaluate(inputs: inputs)
        }
        let ratio = await cache.hitRatio
        XCTAssertEqual(ratio, 9.0 / 10.0, accuracy: 1e-6,
            "10 dispatches with 1 unique shape = 9 hits / 10 total")
    }
}

// MARK: - Helpers

/// Seeded deterministic Float RNG for byte-equality tests
/// across kernel paths。 Linear congruential generator —
/// not cryptographically strong but deterministic across
/// runs。 chapter 三百九二 replay-determinism。
private struct SeededFloatRNG {
    private var state: UInt32

    init(seed: UInt32) { self.state = seed }

    mutating func next() -> Float {
        state = state &* 1_664_525 &+ 1_013_904_223
        let normalized = Float(state) / Float(UInt32.max)
        return (normalized - 0.5) * 2.0
    }
}
