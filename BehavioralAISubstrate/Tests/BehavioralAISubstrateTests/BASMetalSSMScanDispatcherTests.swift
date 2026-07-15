// MARK: - BASMetalSSMScanDispatcherTests
// 主线 全面 开发: Metal pilot graduates from "load +
// memoize" to "actually DISPATCH the SSMScan kernel on
// GPU"。 Tests verify GPU output matches CPU reference
// within IEEE float32 + sequential-reduction tolerance
// (MAE ≤ 1e-5 per chapter 392 replay-determinism)。

import XCTest
@testable import BASHostKit
@testable import BASMetalSubstrate

final class BASMetalSSMScanDispatcherTests: XCTestCase {

    // MARK: - Minimal smoke dispatch

    func testMinimalDispatchProducesNonZeroOutput()
        async throws
    {
        // Tiny shape:B=1, L=2, D=2 = 4 elements
        let loader = BASMetalKernelLibraryLoader(
            useMetalKernelV2: true)
        let dispatcher = BASMetalSSMScanDispatcher(
            loader: loader)
        let shape = BASSSMScanShape(B: 1, L: 2, D: 2)
        let elementCount = shape.elementCount
        // Non-trivial inputs so output != 0
        let x = [Float](repeating: 1.0,
            count: elementCount)
        let delta = [Float](repeating: 0.5,
            count: elementCount)
        let A = [Float](repeating: -0.5,
            count: Int(shape.D))
        let B = [Float](repeating: 1.0,
            count: elementCount)
        let C = [Float](repeating: 1.0,
            count: elementCount)
        let y = try await dispatcher.dispatch(
            x: x, delta: delta, A: A, B: B, C: C,
            shape: shape)
        XCTAssertEqual(y.count, elementCount)
        // Verify the GPU actually wrote something — every
        // element should be non-zero with these inputs。
        for value in y {
            XCTAssertNotEqual(value, 0.0,
                "GPU output must reflect the kernel work")
        }
    }

    // MARK: - GPU == CPU reference parity

    func testGPUMatchesCPUReferenceAtMAE_1e_5()
        async throws
    {
        // Small but non-trivial shape exercising both
        // batch + time + channel iteration
        let loader = BASMetalKernelLibraryLoader(
            useMetalKernelV2: true)
        let dispatcher = BASMetalSSMScanDispatcher(
            loader: loader)
        let shape = BASSSMScanShape(B: 2, L: 4, D: 3)
        let bld = shape.elementCount
        let dCount = Int(shape.D)
        // Deterministic pseudo-random inputs (LCG)
        var seed: UInt32 = 0x600D5EED
        func next() -> Float {
            seed = seed &* 1664525 &+ 1013904223
            return Float(seed & 0xFFFF) / Float(0xFFFF)
                - 0.5  // [-0.5, 0.5)
        }
        let x     = (0..<bld).map { _ in next() }
        let delta = (0..<bld).map { _ in next() * 0.5 + 0.5 }
        let A     = (0..<dCount).map { _ in next() - 1.0 }
        let B     = (0..<bld).map { _ in next() }
        let C     = (0..<bld).map { _ in next() }
        // GPU
        let gpuY = try await dispatcher.dispatch(
            x: x, delta: delta, A: A, B: B, C: C,
            shape: shape)
        // CPU reference
        let cpuY = try BASSSMScanCPUReference.scan(
            x: x, delta: delta, A: A, B: B, C: C,
            shape: shape)
        // Compute MAE
        XCTAssertEqual(gpuY.count, cpuY.count)
        var maxErr: Float = 0
        var sumErr: Float = 0
        for i in 0..<gpuY.count {
            let err = abs(gpuY[i] - cpuY[i])
            maxErr = max(maxErr, err)
            sumErr += err
        }
        let mae = sumErr / Float(gpuY.count)
        XCTAssertLessThan(mae, 1e-5,
            "GPU vs CPU MAE must be ≤ 1e-5。 Got mae=" +
            "\(mae),maxErr=\(maxErr)")
    }

    // MARK: - Pipeline memoization

    func testPipelineMemoizedAcrossDispatches() async throws {
        let loader = BASMetalKernelLibraryLoader(
            useMetalKernelV2: true)
        let dispatcher = BASMetalSSMScanDispatcher(
            loader: loader)
        let initiallyMemoized = await dispatcher
            .hasMemoizedPipeline
        XCTAssertFalse(initiallyMemoized)
        let shape = BASSSMScanShape(B: 1, L: 1, D: 1)
        let one = [Float](repeating: 1, count: 1)
        _ = try await dispatcher.dispatch(
            x: one, delta: one, A: one,
            B: one, C: one, shape: shape)
        let memoizedAfterFirst = await dispatcher
            .hasMemoizedPipeline
        XCTAssertTrue(memoizedAfterFirst,
            "First dispatch builds + memoizes pipeline")
        _ = try await dispatcher.dispatch(
            x: one, delta: one, A: one,
            B: one, C: one, shape: shape)
        let memoizedAfterSecond = await dispatcher
            .hasMemoizedPipeline
        XCTAssertTrue(memoizedAfterSecond,
            "Pipeline stays memoized across dispatches")
    }

    // MARK: - Input validation

    func testPayloadCountMismatchThrows() async throws {
        let loader = BASMetalKernelLibraryLoader(
            useMetalKernelV2: true)
        let dispatcher = BASMetalSSMScanDispatcher(
            loader: loader)
        let shape = BASSSMScanShape(B: 2, L: 2, D: 2)
        // x has wrong size
        let badX = [Float](repeating: 0, count: 5)
        let goodArray = [Float](
            repeating: 0, count: shape.elementCount)
        let aArray = [Float](
            repeating: 0, count: Int(shape.D))
        do {
            _ = try await dispatcher.dispatch(
                x: badX, delta: goodArray,
                A: aArray, B: goodArray, C: goodArray,
                shape: shape)
            XCTFail("Expected payloadCountMismatch")
        } catch
            BASMetalSSMScanDispatcherError
                .payloadCountMismatch(let name, _, _)
        {
            XCTAssertEqual(name, "x")
        }
    }

    // MARK: - V1 path

    func testV1LoaderProducesLibraryError() async throws {
        let loader = BASMetalKernelLibraryLoader(
            useMetalKernelV2: false)
        let dispatcher = BASMetalSSMScanDispatcher(
            loader: loader)
        let shape = BASSSMScanShape(B: 1, L: 1, D: 1)
        let one = [Float](repeating: 1, count: 1)
        do {
            _ = try await dispatcher.dispatch(
                x: one, delta: one, A: one,
                B: one, C: one, shape: shape)
            XCTFail("V1 loader must surface library error")
        } catch BASMetalSSMScanDispatcherError
            .libraryUnavailable
        {
            // expected
        }
    }
}
