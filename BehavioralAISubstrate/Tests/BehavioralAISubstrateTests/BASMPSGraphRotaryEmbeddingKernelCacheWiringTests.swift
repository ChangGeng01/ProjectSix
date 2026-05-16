// MARK: - BASMPSGraphRotaryEmbeddingKernelCacheWiringTests
// chapter 六百六十五 / M2038 — byte-equality PROOF tests
//                              for rotaryEmbedding cache
//                              wiring

import XCTest
@testable import BASMetalSubstrate
@testable import BASRuntimeCore

final class BASMPSGraphRotaryEmbeddingKernelCacheWiringTests:
    XCTestCase
{
    private func makeInput(
        seqLen: Int, headDim: Int, seed: UInt32
    ) -> BASKernelInputs {
        precondition(headDim % 2 == 0)
        let halfDim = headDim / 2
        var rng = SeededFloatRNG(seed: seed)
        let x: [Float] = (0..<(seqLen * headDim)).map { _ in
            rng.next()
        }
        let cosT: [Float] = (0..<(seqLen * halfDim))
            .map { _ in rng.next() }
        let sinT: [Float] = (0..<(seqLen * halfDim))
            .map { _ in rng.next() }
        let xData = x.withUnsafeBufferPointer {
            Data(buffer: $0)
        }
        let cosData = cosT.withUnsafeBufferPointer {
            Data(buffer: $0)
        }
        let sinData = sinT.withUnsafeBufferPointer {
            Data(buffer: $0)
        }
        return BASKernelInputs(
            descriptors: [
                BASTensorDescriptor.contiguous(
                    shape: [seqLen, headDim],
                    dataType: .float32,
                    backingKind: .metalBuffer,
                    rankTag: _2D.rankTag),
                BASTensorDescriptor.contiguous(
                    shape: [seqLen, halfDim],
                    dataType: .float32,
                    backingKind: .metalBuffer,
                    rankTag: _2D.rankTag),
                BASTensorDescriptor.contiguous(
                    shape: [seqLen, halfDim],
                    dataType: .float32,
                    backingKind: .metalBuffer,
                    rankTag: _2D.rankTag)
            ],
            payloads: [xData, cosData, sinData])
    }

    func testCacheOffPathProducesValidOutput()
        async throws
    {
        let baseline = try BASMPSGraphRotaryEmbeddingKernel()
        let inputs = makeInput(
            seqLen: 4, headDim: 8, seed: 17)
        let outputs = try await baseline.evaluate(
            inputs: inputs)
        XCTAssertEqual(outputs.payloads[0].count,
            4 * 8 * 4)
    }

    func testCacheOnIsByteEqualToCacheOffBaseline()
        async throws
    {
        let cacheOff = try BASMPSGraphRotaryEmbeddingKernel()
        let cache = BASMPSGraphExecutableCache()
        let cacheOn = try BASMPSGraphRotaryEmbeddingKernel(
            cache: cache)

        let inputs = makeInput(
            seqLen: 4, headDim: 8, seed: 17)
        let baselineOut = try await cacheOff.evaluate(
            inputs: inputs)
        let cacheOnOut = try await cacheOn.evaluate(
            inputs: inputs)

        XCTAssertEqual(
            baselineOut.payloads[0],
            cacheOnOut.payloads[0],
            "Cache-on output must byte-equal cache-off baseline")
    }

    func testRepeatedDispatchesHitTheCache() async throws {
        let cache = BASMPSGraphExecutableCache()
        let kernel = try BASMPSGraphRotaryEmbeddingKernel(
            cache: cache)
        let inputs = makeInput(
            seqLen: 4, headDim: 8, seed: 17)
        for _ in 0..<5 {
            _ = try await kernel.evaluate(inputs: inputs)
        }
        let hits = await cache.hitCount
        let misses = await cache.missCount
        let execCount = await cache.executableCount
        XCTAssertEqual(misses, 1)
        XCTAssertEqual(hits, 4)
        XCTAssertEqual(execCount, 1)
    }

    func testDistinctShapesProduceDistinctCacheEntries()
        async throws
    {
        let cache = BASMPSGraphExecutableCache()
        let kernel = try BASMPSGraphRotaryEmbeddingKernel(
            cache: cache)
        let inputs4x8 = makeInput(
            seqLen: 4, headDim: 8, seed: 17)
        let inputs8x16 = makeInput(
            seqLen: 8, headDim: 16, seed: 17)
        _ = try await kernel.evaluate(inputs: inputs4x8)
        _ = try await kernel.evaluate(inputs: inputs8x16)
        _ = try await kernel.evaluate(inputs: inputs4x8)
        _ = try await kernel.evaluate(inputs: inputs8x16)
        let execCount = await cache.executableCount
        XCTAssertEqual(execCount, 2)
        let hits = await cache.hitCount
        let misses = await cache.missCount
        XCTAssertEqual(hits, 2)
        XCTAssertEqual(misses, 2)
    }
}

/// Seeded deterministic Float RNG (same as the rmsNorm
/// kernel test) — kept private per file to avoid coupling
/// test files via shared helpers。
private struct SeededFloatRNG {
    private var state: UInt32
    init(seed: UInt32) { self.state = seed }
    mutating func next() -> Float {
        state = state &* 1_664_525 &+ 1_013_904_223
        let normalized = Float(state) / Float(UInt32.max)
        return (normalized - 0.5) * 2.0
    }
}
