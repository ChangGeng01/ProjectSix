// MARK: - BASMPSGraphAttentionKernelCacheWiringTests
// chapter 六百六十六 / M2041 — byte-equality PROOF tests

import XCTest
@testable import BASMetalSubstrate
@testable import BASRuntimeCore

final class BASMPSGraphAttentionKernelCacheWiringTests:
    XCTestCase
{
    private func makeInput(
        seqQ: Int, seqK: Int, dim: Int, seed: UInt32
    ) -> BASKernelInputs {
        var rng = SeededFloatRNG(seed: seed)
        let q: [Float] = (0..<(seqQ * dim)).map { _ in rng.next() }
        let k: [Float] = (0..<(seqK * dim)).map { _ in rng.next() }
        let v: [Float] = (0..<(seqK * dim)).map { _ in rng.next() }
        let qD = q.withUnsafeBufferPointer { Data(buffer: $0) }
        let kD = k.withUnsafeBufferPointer { Data(buffer: $0) }
        let vD = v.withUnsafeBufferPointer { Data(buffer: $0) }
        return BASKernelInputs(
            descriptors: [
                BASTensorDescriptor.contiguous(
                    shape: [seqQ, dim], dataType: .float32,
                    backingKind: .metalBuffer,
                    rankTag: _2D.rankTag),
                BASTensorDescriptor.contiguous(
                    shape: [seqK, dim], dataType: .float32,
                    backingKind: .metalBuffer,
                    rankTag: _2D.rankTag),
                BASTensorDescriptor.contiguous(
                    shape: [seqK, dim], dataType: .float32,
                    backingKind: .metalBuffer,
                    rankTag: _2D.rankTag)
            ],
            payloads: [qD, kD, vD])
    }

    func testCacheOnIsByteEqualToCacheOff() async throws {
        let off = try BASMPSGraphAttentionKernel()
        let cache = BASMPSGraphExecutableCache()
        let on = try BASMPSGraphAttentionKernel(cache: cache)

        let inputs = makeInput(
            seqQ: 3, seqK: 5, dim: 8, seed: 31)
        let oOut = try await off.evaluate(inputs: inputs)
        let cOut = try await on.evaluate(inputs: inputs)
        XCTAssertEqual(oOut.payloads[0], cOut.payloads[0])
    }

    func testRepeatedDispatchesHit() async throws {
        let cache = BASMPSGraphExecutableCache()
        let kernel = try BASMPSGraphAttentionKernel(cache: cache)
        let inputs = makeInput(
            seqQ: 3, seqK: 5, dim: 8, seed: 31)
        for _ in 0..<4 {
            _ = try await kernel.evaluate(inputs: inputs)
        }
        let h = await cache.hitCount
        let m = await cache.missCount
        XCTAssertEqual(m, 1)
        XCTAssertEqual(h, 3)
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
