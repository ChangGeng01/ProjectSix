// MARK: - BASChapter871BrainMPSGraphMatMulParityTests
// chapter 八百七十一 第五刀 / M3021 — Brain-level MPSGraph matMul
// wiring + split-flip routing (MSL at small, MPSGraph at large)
// + shared kernel cache reuse pin。
//
// Chapter 八百七十一 knife 1 captured 5-way live data:
//   - 128³: MSL beats MPSGraph 1.89×
//   - 256³: MPSGraph warm beats MSL 1.07× (~tie)
//   - 512³: MPSGraph warm beats MSL 1.38×
//
// Per 「亏的不要硬上」 — chapter 八百七十一 ships a SPLIT-FLIP
// (not wholesale) — small shapes keep MSL,large shapes flip
// to true MPSGraph actor。 Threshold cut at workProduct ≥ 16M
// (matches 256³ where MPSGraph starts winning)。
//
// Tests:
//   - Parity: brain.mpsGraphMatMul ≡ brain.matmul within 1e-3
//   - Cache reuse: same brain instance reuses kernel across calls
//   - Routing: matMulAuto correctly dispatches new case at large
//   - Threshold: 128³ stays MSL, 256³+ goes MPSGraph actor
//   - Shape constraints: error path when aCols ≠ bRows

import XCTest
@testable import BASRuntimeCore
@testable import BASHostKit
@testable import BASMetalSubstrate

final class BASChapter871BrainMPSGraphMatMulParityTests: XCTestCase {

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

    // MARK: - Parity at split-flip threshold + above

    /// brain.mpsGraphMatMul ≡ brain.matmul within 1e-3 at the
    /// split-flip crossover shape (256³)。 Both should produce
    /// numerically-equivalent output even though one is MSL
    /// and the other is MPSGraph。
    func testBrainMPSGraphMatchesMSLAtCrossoverShape()
        async throws
    {
        let brain = try await BASCognitiveBrain
            .makeWithAllPilots()
        let (M, N, K) = (256, 256, 256)
        let (a, b) = makeMatrices(M: M, N: N, K: K)
        let mpsOut: [Float]
        do {
            mpsOut = try await brain.mpsGraphMatMul(
                a: a, aRows: M, aCols: K,
                b: b, bRows: K, bCols: N)
        } catch BASKernelError.frameworkUnavailable {
            throw XCTSkip("Metal unavailable")
        }
        let mslOut = try await brain.matmul(
            a: a, aRows: M, aCols: K,
            b: b, bRows: K, bCols: N)
        XCTAssertEqual(mpsOut.count, mslOut.count)
        XCTAssertEqual(mpsOut.count, M * N)
        for i in 0..<mpsOut.count {
            XCTAssertEqual(mpsOut[i], mslOut[i],
                accuracy: 1e-3,
                "idx \(i): MPSGraph and MSL must agree " +
                "at crossover shape (\(M),\(N),\(K))")
        }
    }

    /// Same parity at larger shape (512³) where MPSGraph is
    /// the clear winner per chapter 八百七十一 data。
    func testBrainMPSGraphMatchesMSLAtLargeShape() async throws {
        let brain = try await BASCognitiveBrain
            .makeWithAllPilots()
        let (M, N, K) = (512, 512, 512)
        let (a, b) = makeMatrices(M: M, N: N, K: K)
        let mpsOut: [Float]
        do {
            mpsOut = try await brain.mpsGraphMatMul(
                a: a, aRows: M, aCols: K,
                b: b, bRows: K, bCols: N)
        } catch BASKernelError.frameworkUnavailable {
            throw XCTSkip("Metal unavailable")
        }
        let mslOut = try await brain.matmul(
            a: a, aRows: M, aCols: K,
            b: b, bRows: K, bCols: N)
        for i in 0..<mpsOut.count {
            XCTAssertEqual(mpsOut[i], mslOut[i],
                accuracy: 1e-3,
                "idx \(i): MPSGraph ≡ MSL at large shape " +
                "(\(M),\(N),\(K))")
        }
    }

    // MARK: - Cache reuse pin

    /// Multiple brain.mpsGraphMatMul calls at the same shape
    /// must reuse the lazily-initialized kernel。 If a future
    /// refactor accidentally per-call-news the kernel,the
    /// per-call cost goes up dramatically。 Measured via
    /// cold (first call) vs warm (median 20) speedup。
    func testBrainMPSGraphMatMulCacheReuse() async throws {
        let brain = try await BASCognitiveBrain
            .makeWithAllPilots()
        let (M, N, K) = (256, 256, 256)
        let (a, b) = makeMatrices(M: M, N: N, K: K)

        let coldStart = DispatchTime.now().uptimeNanoseconds
        do {
            _ = try await brain.mpsGraphMatMul(
                a: a, aRows: M, aCols: K,
                b: b, bRows: K, bCols: N)
        } catch BASKernelError.frameworkUnavailable {
            throw XCTSkip("Metal unavailable")
        }
        let coldEnd = DispatchTime.now().uptimeNanoseconds
        let coldNs = Double(coldEnd - coldStart)

        var warmSamples: [Double] = []
        for _ in 0..<20 {
            let s = DispatchTime.now().uptimeNanoseconds
            _ = try await brain.mpsGraphMatMul(
                a: a, aRows: M, aCols: K,
                b: b, bRows: K, bCols: N)
            let e = DispatchTime.now().uptimeNanoseconds
            warmSamples.append(Double(e - s))
        }
        warmSamples.sort()
        let warmNs = warmSamples[warmSamples.count / 2]

        print(String(format:
            "BENCH brain.mpsGraphMatMul cache reuse M=N=K=%d:\n" +
            "  cold (1st)  = %10.0f ns\n" +
            "  warm (med20) = %10.0f ns " +
            "(speedup=%.2fx)",
            M, coldNs, warmNs, coldNs / warmNs))

        // Warm must be at least 1.5× faster than cold (kernel
        // reuse + MPSGraph's internal exec cache amortizing
        // graph build cost)。 If close to 1.0× → kernel is
        // being recreated per-call (broken)。
        XCTAssertLessThan(warmNs, coldNs * 0.67,
            "Warm should be ≥1.5× faster than cold — " +
            "coldNs=\(coldNs) warmNs=\(warmNs)")
    }

    // MARK: - Routing pin

    /// Chapter 八百七十一 split-flip:
    ///   - workProduct < 8192 (e.g. 4³=64) → rustMatMulNaive
    ///   - 8192 ≤ workProduct < 262144 → rustMatMulBlocked
    ///   - 262144 ≤ workProduct < 16M (e.g. 128³=2M) → metalMatMulMPSGraph
    ///     (misnamed → MSL custom kernel)
    ///   - workProduct ≥ 16M (e.g. 256³=16.7M) → metalMatMulMPSGraphActor
    ///     (TRUE MPSGraph actor path,chapter 871 new case)
    func testMatMulChoiceSplitFlipAtSize256() {
        // 128³ = 2_097_152 < 16M → MSL (legacy enum case)
        let choice128 = BASAutoRouteRanker.matMulChoice(
            shape: BASMatMulShape(M: 128, N: 128, K: 128),
            thresholds: .mSeriesDefault)
        XCTAssertEqual(choice128, .metalMatMulMPSGraph,
            "128³ workProduct=2M < 16M threshold,stays " +
            "on MSL custom kernel (legacy enum name)")

        // 256³ = 16_777_216 ≥ 16M → MPSGraph actor
        let choice256 = BASAutoRouteRanker.matMulChoice(
            shape: BASMatMulShape(M: 256, N: 256, K: 256),
            thresholds: .mSeriesDefault)
        XCTAssertEqual(choice256, .metalMatMulMPSGraphActor,
            "256³ workProduct=16.7M ≥ 16M → MPSGraph actor")

        // 512³ = 134_217_728 ≥ 16M → MPSGraph actor
        let choice512 = BASAutoRouteRanker.matMulChoice(
            shape: BASMatMulShape(M: 512, N: 512, K: 512),
            thresholds: .mSeriesDefault)
        XCTAssertEqual(choice512, .metalMatMulMPSGraphActor,
            "512³ workProduct=134M → MPSGraph actor")
    }

    /// brain.matMulAuto with shape at 256³ must actually route
    /// the call through the MPSGraph actor + return matching
    /// BASAutoRouteResult choice tag。
    func testMatMulAutoDispatchesMPSGraphActorAt256()
        async throws
    {
        let brain = try await BASCognitiveBrain
            .makeWithAllPilots()
        let (M, N, K) = (256, 256, 256)
        let (a, b) = makeMatrices(M: M, N: N, K: K)
        let result: BASAutoRouteResult<[Float]>
        do {
            result = try await brain.matMulAuto(
                a: a, aRows: M, aCols: K,
                b: b, bRows: K, bCols: N)
        } catch BASKernelError.frameworkUnavailable {
            throw XCTSkip("Metal unavailable")
        }
        XCTAssertEqual(result.choice,
            .metalMatMulMPSGraphActor,
            "256³ must dispatch MPSGraph actor per chapter 871")
        XCTAssertEqual(result.value.count, M * N)
    }

    // MARK: - Shape constraint

    /// brain.mpsGraphMatMul with aCols ≠ bRows must throw
    /// .shapeMismatch (not silently produce wrong output)
    func testBrainMPSGraphMatMulThrowsOnShapeMismatch()
        async throws
    {
        let brain = try await BASCognitiveBrain
            .makeWithAllPilots()
        // aCols=4, bRows=8 → mismatch
        let a: [Float] = Array(repeating: 1.0, count: 8)  // 2x4
        let b: [Float] = Array(repeating: 1.0, count: 16)  // 8x2
        do {
            _ = try await brain.mpsGraphMatMul(
                a: a, aRows: 2, aCols: 4,
                b: b, bRows: 8, bCols: 2)
            XCTFail("Expected shapeMismatch throw")
        } catch BASMetalMatMulDispatcherError.shapeMismatch {
            // expected
        } catch BASKernelError.frameworkUnavailable {
            throw XCTSkip("Metal unavailable")
        }
    }
}
