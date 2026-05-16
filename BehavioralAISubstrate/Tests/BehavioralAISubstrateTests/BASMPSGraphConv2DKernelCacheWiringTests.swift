// MARK: - BASMPSGraphConv2DKernelCacheWiringTests
// chapter 六百六十七 / M2045 — byte-equality PROOF tests
//                              for the FINAL Phase J kernel
//                              wiring (conv2D — 6 of 6 done)

import XCTest
@testable import BASMetalSubstrate
@testable import BASRuntimeCore

final class BASMPSGraphConv2DKernelCacheWiringTests:
    XCTestCase
{
    private func makeInput(
        n: Int, h: Int, w: Int, cin: Int,
        hk: Int, wk: Int, cout: Int,
        seed: UInt32
    ) -> BASKernelInputs {
        var rng = SeededFloatRNG(seed: seed)
        let inCount = n * h * w * cin
        let wCount = hk * wk * cin * cout
        let inArr: [Float] = (0..<inCount).map { _ in
            rng.next()
        }
        let wArr: [Float] = (0..<wCount).map { _ in
            rng.next()
        }
        let inD = inArr.withUnsafeBufferPointer {
            Data(buffer: $0)
        }
        let wD = wArr.withUnsafeBufferPointer {
            Data(buffer: $0)
        }
        return BASKernelInputs(
            descriptors: [
                BASTensorDescriptor.contiguous(
                    shape: [n, h, w, cin],
                    dataType: .float32,
                    backingKind: .metalBuffer,
                    rankTag: _4D.rankTag),
                BASTensorDescriptor.contiguous(
                    shape: [hk, wk, cin, cout],
                    dataType: .float32,
                    backingKind: .metalBuffer,
                    rankTag: _4D.rankTag)
            ],
            payloads: [inD, wD])
    }

    func testCacheOnIsByteEqualToCacheOff() async throws {
        let off = try BASMPSGraphConv2DKernel()
        let cache = BASMPSGraphExecutableCache()
        let on = try BASMPSGraphConv2DKernel(cache: cache)
        let inputs = makeInput(
            n: 1, h: 4, w: 4, cin: 2,
            hk: 3, wk: 3, cout: 3,
            seed: 71)
        let oOut = try await off.evaluate(inputs: inputs)
        let cOut = try await on.evaluate(inputs: inputs)
        XCTAssertEqual(oOut.payloads[0], cOut.payloads[0])
    }

    func testRepeatedDispatchesHit() async throws {
        let cache = BASMPSGraphExecutableCache()
        let kernel = try BASMPSGraphConv2DKernel(cache: cache)
        let inputs = makeInput(
            n: 1, h: 4, w: 4, cin: 2,
            hk: 3, wk: 3, cout: 3,
            seed: 71)
        for _ in 0..<3 {
            _ = try await kernel.evaluate(inputs: inputs)
        }
        let h = await cache.hitCount
        let m = await cache.missCount
        XCTAssertEqual(m, 1)
        XCTAssertEqual(h, 2)
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
