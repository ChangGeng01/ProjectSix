// MARK: - BASChapter707AttentionAutoRouteTests
// chapter 七百七 第三刀 / M2208
//
// Verifies brain.attentionAuto picks the empirically-correct
// implementation per shape + produces output byte-equivalent
// to the underlying impl。

import XCTest
@testable import BASRuntimeCore
@testable import BASHostKit
@testable import BASMetalSubstrate

final class BASChapter707AttentionAutoRouteTests:
    XCTestCase
{

    private func sampleInputs(
        M: Int, N: Int, D: Int, Dv: Int
    ) -> (q: [Float], k: [Float], v: [Float]) {
        var seed: UInt32 = 0xABCDEF
        func next() -> Float {
            seed = seed &* 1664525 &+ 1013904223
            return Float(seed & 0xFFFF)
                / Float(0xFFFF) - 0.5
        }
        return (
            (0..<(M * D)).map { _ in next() },
            (0..<(N * D)).map { _ in next() },
            (0..<(N * Dv)).map { _ in next() })
    }

    func testTinyShapePicksCPU() async throws {
        let brain = try await BASCognitiveBrain
            .makeWithAllPilots()
        let (q, k, v) = sampleInputs(
            M: 4, N: 4, D: 8, Dv: 8)
        // 4*4 = 16 < default threshold 64 → CPU
        let r = try await brain.attentionAuto(
            q: q, qRows: 4, qCols: 8,
            k: k, kRows: 4,
            v: v, vCols: 8)
        XCTAssertEqual(r.choice, .swiftCPUAttention)
        XCTAssertEqual(r.value.count, 4 * 8)
    }

    func testMediumShapePicksFlash() async throws {
        let brain = try await BASCognitiveBrain
            .makeWithAllPilots()
        let (q, k, v) = sampleInputs(
            M: 16, N: 16, D: 16, Dv: 16)
        // 16*16 = 256 >= 64 → Metal Flash (D ≤ 64)
        let r = try await brain.attentionAuto(
            q: q, qRows: 16, qCols: 16,
            k: k, kRows: 16,
            v: v, vCols: 16)
        XCTAssertEqual(r.choice, .metalFlashAttention)
        XCTAssertEqual(r.value.count, 16 * 16)
    }

    func testLargeHeadDimFallsBackToStandard() async throws {
        let brain = try await BASCognitiveBrain
            .makeWithAllPilots()
        // D=128 exceeds FlashAttention's tile cap (64)。 Auto
        // should fall back to the standard kernel。
        let D = 128
        let (q, k, v) = sampleInputs(
            M: 4, N: 4, D: D, Dv: D)
        // 4*4 = 16 < threshold → ROUTER would pick CPU。
        // But the test wants to verify Metal-standard fallback,
        // so we override the threshold to force the Metal branch。
        let t = BASAutoRouteThresholds(
            cosineSIMDMinDim: 64,
            sha256CryptoKitMinBytes: 1024,
            attentionMetalMinProduct: 1)
        let r = try await brain.attentionAuto(
            q: q, qRows: 4, qCols: D,
            k: k, kRows: 4,
            v: v, vCols: D,
            thresholds: t)
        // Auto chose Flash but the D cap forced the standard
        // fallback path internally
        XCTAssertEqual(r.choice, .metalStandardAttention)
    }

    /// Cross-impl agreement — auto-routed output matches the
    /// CPU reference within float32 tolerance for a shape
    /// that picks Metal Flash。
    func testAutoFlashMatchesCPUWithinTolerance() async throws {
        let brain = try await BASCognitiveBrain
            .makeWithAllPilots()
        let M = 8, N = 8, D = 16, Dv = 16
        let (q, k, v) = sampleInputs(
            M: M, N: N, D: D, Dv: Dv)
        // M*N = 64 >= threshold → Metal Flash
        let auto = try await brain.attentionAuto(
            q: q, qRows: M, qCols: D,
            k: k, kRows: N,
            v: v, vCols: Dv)
        XCTAssertEqual(auto.choice, .metalFlashAttention)
        let cpu = BASAutoRouteRanker.cpuAttention(
            q: q, M: M, D: D,
            k: k, N: N,
            v: v, Dv: Dv)
        XCTAssertEqual(auto.value.count, cpu.count)
        for idx in 0..<cpu.count {
            XCTAssertEqual(
                auto.value[idx], cpu[idx],
                accuracy: 1e-3,
                "cell \(idx): auto=\(auto.value[idx]) " +
                "cpu=\(cpu[idx])")
        }
    }

    /// Cross-impl agreement — CPU path direct invocation。
    func testCpuPathMatchesItself() async throws {
        // Pure determinism check
        let M = 2, N = 3, D = 4, Dv = 2
        let q = [Float](repeating: 0.5, count: M * D)
        let k = [Float](repeating: 0.5, count: N * D)
        let v: [Float] = [
            1.0, 2.0,
            1.0, 2.0,
            1.0, 2.0]
        let out1 = BASAutoRouteRanker.cpuAttention(
            q: q, M: M, D: D, k: k, N: N, v: v, Dv: Dv)
        let out2 = BASAutoRouteRanker.cpuAttention(
            q: q, M: M, D: D, k: k, N: N, v: v, Dv: Dv)
        XCTAssertEqual(out1, out2)
        // All-uniform inputs → output rows = first row of V
        for i in 0..<M {
            XCTAssertEqual(
                out1[i * Dv + 0], 1.0, accuracy: 1e-5)
            XCTAssertEqual(
                out1[i * Dv + 1], 2.0, accuracy: 1e-5)
        }
    }

    /// Threshold customization works。
    func testCustomThresholdMovesAttentionCrossover()
        async throws
    {
        let brain = try await BASCognitiveBrain
            .makeWithAllPilots()
        let (q, k, v) = sampleInputs(
            M: 4, N: 4, D: 8, Dv: 8)
        // Force Metal path even for tiny M*N=16 < default 64
        let t = BASAutoRouteThresholds(
            cosineSIMDMinDim: 64,
            sha256CryptoKitMinBytes: 1024,
            attentionMetalMinProduct: 1)
        let r = try await brain.attentionAuto(
            q: q, qRows: 4, qCols: 8,
            k: k, kRows: 4,
            v: v, vCols: 8,
            thresholds: t)
        XCTAssertEqual(r.choice, .metalFlashAttention)
    }
}
