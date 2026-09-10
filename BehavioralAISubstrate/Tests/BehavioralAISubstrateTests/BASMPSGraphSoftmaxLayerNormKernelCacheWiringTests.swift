// MARK: - BASMPSGraphSoftmaxLayerNormKernelCacheWiringTests
// chapter 六百六十六 / M2042 — combined byte-equality
//                              PROOF tests for softmax +
//                              layerNorm kernels cache
//                              wiring (4 of 6 Phase J
//                              kernels done after this)

import XCTest
@testable import BASMetalSubstrate
@testable import BASRuntimeCore

final class BASMPSGraphSoftmaxLayerNormKernelCacheWiringTests:
    XCTestCase
{
    // MARK: - Softmax tests

    func testSoftmaxCacheOnIsByteEqualToCacheOff()
        async throws
    {
        let off = try BASMPSGraphSoftmaxKernel()
        let cache = BASMPSGraphExecutableCache()
        let on = try BASMPSGraphSoftmaxKernel(cache: cache)

        let inputs = makeSoftmaxInput(
            rows: 4, cols: 8, seed: 23)
        let oOut = try await off.evaluate(inputs: inputs)
        let cOut = try await on.evaluate(inputs: inputs)
        XCTAssertEqual(oOut.payloads[0], cOut.payloads[0])
    }

    func testSoftmaxRepeatedDispatchesHit() async throws {
        let cache = BASMPSGraphExecutableCache()
        let kernel = try BASMPSGraphSoftmaxKernel(cache: cache)
        let inputs = makeSoftmaxInput(
            rows: 4, cols: 8, seed: 23)
        for _ in 0..<5 {
            _ = try await kernel.evaluate(inputs: inputs)
        }
        let h = await cache.hitCount
        let m = await cache.missCount
        XCTAssertEqual(m, 1)
        XCTAssertEqual(h, 4)
    }

    // MARK: - LayerNorm tests

    func testLayerNormCacheOnIsByteEqualToCacheOff()
        async throws
    {
        let off = try BASMPSGraphLayerNormKernel(
            epsilon: 1e-5)
        let cache = BASMPSGraphExecutableCache()
        let on = try BASMPSGraphLayerNormKernel(
            epsilon: 1e-5, cache: cache)

        let inputs = makeLayerNormInput(
            batch: 3, hidden: 6, seed: 42)
        let oOut = try await off.evaluate(inputs: inputs)
        let cOut = try await on.evaluate(inputs: inputs)
        XCTAssertEqual(oOut.payloads[0], cOut.payloads[0])
    }

    func testLayerNormRepeatedDispatchesHit() async throws {
        let cache = BASMPSGraphExecutableCache()
        let kernel = try BASMPSGraphLayerNormKernel(
            cache: cache)
        let inputs = makeLayerNormInput(
            batch: 3, hidden: 6, seed: 42)
        for _ in 0..<6 {
            _ = try await kernel.evaluate(inputs: inputs)
        }
        let h = await cache.hitCount
        let m = await cache.missCount
        XCTAssertEqual(m, 1)
        XCTAssertEqual(h, 5)
    }

    // MARK: - Helpers

    private func makeSoftmaxInput(
        rows: Int, cols: Int, seed: UInt32
    ) -> BASKernelInputs {
        var rng = SeededFloatRNG(seed: seed)
        let x: [Float] = (0..<(rows * cols)).map { _ in rng.next() }
        let xD = x.withUnsafeBufferPointer { Data(buffer: $0) }
        return BASKernelInputs(
            descriptors: [
                BASTensorDescriptor.contiguous(
                    shape: [rows, cols], dataType: .float32,
                    backingKind: .metalBuffer,
                    rankTag: _2D.rankTag)
            ],
            payloads: [xD])
    }

    private func makeLayerNormInput(
        batch: Int, hidden: Int, seed: UInt32
    ) -> BASKernelInputs {
        var rng = SeededFloatRNG(seed: seed)
        let x: [Float] = (0..<(batch * hidden)).map { _ in rng.next() }
        let g: [Float] = (0..<hidden).map { _ in rng.next() }
        let b: [Float] = (0..<hidden).map { _ in rng.next() }
        let xD = x.withUnsafeBufferPointer { Data(buffer: $0) }
        let gD = g.withUnsafeBufferPointer { Data(buffer: $0) }
        let bD = b.withUnsafeBufferPointer { Data(buffer: $0) }
        return BASKernelInputs(
            descriptors: [
                BASTensorDescriptor.contiguous(
                    shape: [batch, hidden], dataType: .float32,
                    backingKind: .metalBuffer,
                    rankTag: _2D.rankTag),
                BASTensorDescriptor.contiguous(
                    shape: [hidden], dataType: .float32,
                    backingKind: .metalBuffer,
                    rankTag: _1D.rankTag),
                BASTensorDescriptor.contiguous(
                    shape: [hidden], dataType: .float32,
                    backingKind: .metalBuffer,
                    rankTag: _1D.rankTag)
            ],
            payloads: [xD, gD, bD])
    }
}

private struct SeededFloatRNG {
    private var state: UInt32
    init(seed: UInt32) { self.state = seed }
    mutating func next() -> Float {
        state = state &* 1_664_525 &+ 1_013_904_223
        let normalized = Float(state) / Float(UInt32.max)
        return (normalized - 0.5) * 2.0
    }
}
