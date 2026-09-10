// MARK: - BASChapter708MatMulAutoRouteTests
// chapter 七百八 第三刀 / M2213
//
// Validates brain.matMulAuto routes correctly per shape + the
// routed output matches Metal MPSGraph reference within
// float32 tolerance。

import XCTest
@testable import BASRuntimeCore
@testable import BASHostKit

final class BASChapter708MatMulAutoRouteTests: XCTestCase {

    private func makeMatrices(
        m: Int, n: Int, k: Int
    ) -> (a: [Float], b: [Float]) {
        var seed: UInt32 = 0xABCDEF01
        func next() -> Float {
            seed = seed &* 1664525 &+ 1013904223
            return Float(seed & 0xFFFF)
                / Float(0xFFFF) - 0.5
        }
        return (
            (0..<(m * k)).map { _ in next() },
            (0..<(k * n)).map { _ in next() })
    }

    func testTinyMatMulPicksRustNaive() async throws {
        let brain = try await BASCognitiveBrain
            .makeWithAllPilots()
        // 4*4*4 = 64 < 8192 → naive
        let (a, b) = makeMatrices(m: 4, n: 4, k: 4)
        let r = try await brain.matMulAuto(
            a: a, aRows: 4, aCols: 4,
            b: b, bRows: 4, bCols: 4)
        XCTAssertEqual(r.choice, .rustMatMulNaive)
        XCTAssertEqual(r.value.count, 16)
    }

    func testMediumMatMulPicksRustBlocked() async throws {
        let brain = try await BASCognitiveBrain
            .makeWithAllPilots()
        // 32*32*32 = 32768 → blocked (8192 ≤ x < 262144)
        let (a, b) = makeMatrices(m: 32, n: 32, k: 32)
        let r = try await brain.matMulAuto(
            a: a, aRows: 32, aCols: 32,
            b: b, bRows: 32, bCols: 32)
        XCTAssertEqual(r.choice, .rustMatMulBlocked)
        XCTAssertEqual(r.value.count, 32 * 32)
    }

    func testLargeMatMulPicksMetal() async throws {
        let brain = try await BASCognitiveBrain
            .makeWithAllPilots()
        // 128*128*128 = 2097152 ≥ 262144 → Metal
        let (a, b) = makeMatrices(m: 128, n: 128, k: 128)
        let r = try await brain.matMulAuto(
            a: a, aRows: 128, aCols: 128,
            b: b, bRows: 128, bCols: 128)
        XCTAssertEqual(r.choice, .metalMatMulMPSGraph)
        XCTAssertEqual(r.value.count, 128 * 128)
    }

    /// Cross-impl byte-equality:Rust auto-routed output matches
    /// Metal MPSGraph reference within float32 tolerance。
    func testAutoMatMulMatchesMetalWithinTolerance() async throws {
        let brain = try await BASCognitiveBrain
            .makeWithAllPilots()
        let M = 32; let N = 32; let K = 32
        let (a, b) = makeMatrices(m: M, n: N, k: K)
        // Default threshold routes to Rust blocked
        let auto = try await brain.matMulAuto(
            a: a, aRows: M, aCols: K,
            b: b, bRows: K, bCols: N)
        XCTAssertEqual(auto.choice, .rustMatMulBlocked)
        // Compare to Metal
        let metal = try await brain.matmul(
            a: a, aRows: M, aCols: K,
            b: b, bRows: K, bCols: N)
        XCTAssertEqual(auto.value.count, metal.count)
        for i in 0..<auto.value.count {
            XCTAssertEqual(
                auto.value[i], metal[i],
                accuracy: 1e-3,
                "cell \(i): rust=\(auto.value[i])" +
                " metal=\(metal[i])")
        }
    }

    /// Threshold override forces a different routing decision。
    func testCustomThresholdMovesCrossover() async throws {
        let brain = try await BASCognitiveBrain
            .makeWithAllPilots()
        let (a, b) = makeMatrices(m: 32, n: 32, k: 32)
        // Force Metal even for 32x32x32 = 32768
        let t = BASAutoRouteThresholds(
            cosineSIMDMinDim: 64,
            sha256CryptoKitMinBytes: 1024,
            attentionMetalMinProduct: 64,
            matMulMetalMinProduct: 1)
        let r = try await brain.matMulAuto(
            a: a, aRows: 32, aCols: 32,
            b: b, bRows: 32, bCols: 32,
            thresholds: t)
        XCTAssertEqual(r.choice, .metalMatMulMPSGraph)
    }

    /// Identity matrix → unchanged input。
    func testIdentityMatMul() async throws {
        let brain = try await BASCognitiveBrain
            .makeWithAllPilots()
        let identity: [Float] = [
            1, 0, 0,
            0, 1, 0,
            0, 0, 1,
        ]
        let a: [Float] = [
            0.1, 0.2, 0.3,
            0.4, 0.5, 0.6,
            0.7, 0.8, 0.9,
        ]
        let r = try await brain.matMulAuto(
            a: identity, aRows: 3, aCols: 3,
            b: a, bRows: 3, bCols: 3)
        // 3*3*3 = 27 < 8192 → naive
        XCTAssertEqual(r.choice, .rustMatMulNaive)
        for i in 0..<a.count {
            XCTAssertEqual(
                r.value[i], a[i], accuracy: 1e-6)
        }
    }
}
