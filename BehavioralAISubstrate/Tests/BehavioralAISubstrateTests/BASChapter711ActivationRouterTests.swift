// MARK: - BASChapter711ActivationRouterTests
// chapter 七百十一 第四刀 / M2229
//
// Verifies BASAutoRouteRanker.gelu / geluTanhApprox / silu +
// BASCognitiveBrain.geluAuto / geluTanhAuto / siluAuto:
//
//   1. routing decision matches the measured-thresholds policy
//   2. numerical output matches torch.nn.functional reference
//   3. dual-mode parity:auto-router matches direct call
//   4. empty-input edge case returns []

import XCTest
import Foundation
@testable import BASRuntimeCore
@testable import BASHostKit

final class BASChapter711ActivationRouterTests: XCTestCase {

    // MARK: - Routing decisions

    func testGeluAlwaysRustExact() {
        // gelu_exact has no SIMD route — Rust scalar at every
        // dim (per tournament 七百十一 第三刀)。
        for dim in [8, 64, 256, 1024, 4096] {
            let x = [Float](repeating: 0.5, count: dim)
            let r = BASAutoRouteRanker.gelu(x)
            #if os(iOS) || os(macOS)
            XCTAssertEqual(r.choice, .rustGeluExact,
                "dim=\(dim) must route to rustGeluExact")
            #endif
            XCTAssertEqual(r.value.count, dim)
        }
    }

    func testGeluTanhRoutesBelowAndAboveThreshold() {
        // Below default geluTanhSIMDMinDim=256 → scalar
        let small = [Float](repeating: 0.5, count: 64)
        let rSmall = BASAutoRouteRanker.geluTanhApprox(small)
        #if os(iOS) || os(macOS)
        XCTAssertEqual(rSmall.choice, .rustGeluTanhScalar)
        #endif
        // At or above → SIMD
        let large = [Float](repeating: 0.5, count: 512)
        let rLarge = BASAutoRouteRanker.geluTanhApprox(large)
        #if os(iOS) || os(macOS)
        XCTAssertEqual(rLarge.choice, .rustGeluTanhSIMD)
        #endif
    }

    func testSiluAlwaysRustScalar() {
        for dim in [8, 64, 256, 1024, 4096] {
            let x = [Float](repeating: 0.5, count: dim)
            let r = BASAutoRouteRanker.silu(x)
            #if os(iOS) || os(macOS)
            XCTAssertEqual(r.choice, .rustSilu,
                "dim=\(dim) must route to rustSilu")
            #endif
            XCTAssertEqual(r.value.count, dim)
        }
    }

    // MARK: - Numerical correctness (torch.nn.functional refs)

    func testGeluNumericalReference() {
        let x: [Float] = [0.0, 1.0, 2.0, -1.0]
        let r = BASAutoRouteRanker.gelu(x)
        XCTAssertEqual(r.value[0], 0.0, accuracy: 1e-6)
        XCTAssertEqual(r.value[1], 0.8413447,
            accuracy: 5e-5)
        XCTAssertEqual(r.value[2], 1.9544997,
            accuracy: 5e-5)
        XCTAssertEqual(r.value[3], -0.15865529,
            accuracy: 5e-5)
    }

    func testGeluTanhNumericalReference() {
        let x: [Float] = [0.0, 1.0, 2.0, -1.0]
        let r = BASAutoRouteRanker.geluTanhApprox(x)
        XCTAssertEqual(r.value[0], 0.0, accuracy: 1e-6)
        XCTAssertEqual(r.value[1], 0.84119, accuracy: 5e-4)
        XCTAssertEqual(r.value[2], 1.95459, accuracy: 5e-4)
        XCTAssertEqual(r.value[3], -0.15881, accuracy: 5e-4)
    }

    func testSiluNumericalReference() {
        let x: [Float] = [0.0, 1.0, 2.0, -1.0]
        let r = BASAutoRouteRanker.silu(x)
        XCTAssertEqual(r.value[0], 0.0, accuracy: 1e-6)
        XCTAssertEqual(r.value[1], 0.7310586, accuracy: 5e-5)
        XCTAssertEqual(r.value[2], 1.7615942, accuracy: 5e-5)
        XCTAssertEqual(r.value[3], -0.2689414,
            accuracy: 5e-5)
    }

    // MARK: - GELU exact vs GELU tanh approximation

    func testGeluExactVsTanhApproxAgreeWithin1e2() {
        // The tanh-approx is purposely lossy vs erf-based exact
        // (max |diff| ≈ 0.02 around the origin)。 We only assert
        // both produce finite,similar values。
        let x: [Float] = (0..<64).map {
            Float($0 - 32) * 0.1 }
        let exact = BASAutoRouteRanker.gelu(x).value
        let approx =
            BASAutoRouteRanker.geluTanhApprox(x).value
        XCTAssertEqual(exact.count, 64)
        XCTAssertEqual(approx.count, 64)
        for i in 0..<64 {
            XCTAssertTrue(exact[i].isFinite)
            XCTAssertTrue(approx[i].isFinite)
            XCTAssertEqual(exact[i], approx[i],
                accuracy: 0.02,
                "i=\(i) exact=\(exact[i]) approx=\(approx[i])")
        }
    }

    // MARK: - Brain helpers

    func testBrainGeluAutoMatchesRanker() {
        let x: [Float] = (0..<32).map {
            Float($0) * 0.1 - 1.5 }
        let viaRanker = BASAutoRouteRanker.gelu(x)
        let viaBrain = BASCognitiveBrain.geluAuto(x)
        XCTAssertEqual(viaRanker.choice, viaBrain.choice)
        XCTAssertEqual(viaRanker.value.count,
            viaBrain.value.count)
        for i in 0..<viaRanker.value.count {
            XCTAssertEqual(viaRanker.value[i],
                viaBrain.value[i], accuracy: 1e-6)
        }
    }

    func testBrainGeluTanhAutoMatchesRanker() {
        let x: [Float] = (0..<512).map {
            Float($0) * 0.01 - 2.5 }
        let viaRanker =
            BASAutoRouteRanker.geluTanhApprox(x)
        let viaBrain = BASCognitiveBrain.geluTanhAuto(x)
        XCTAssertEqual(viaRanker.choice, viaBrain.choice)
        for i in 0..<viaRanker.value.count {
            XCTAssertEqual(viaRanker.value[i],
                viaBrain.value[i], accuracy: 1e-6)
        }
    }

    func testBrainSiluAutoMatchesRanker() {
        let x: [Float] = (0..<128).map {
            Float($0) * 0.05 - 3.0 }
        let viaRanker = BASAutoRouteRanker.silu(x)
        let viaBrain = BASCognitiveBrain.siluAuto(x)
        XCTAssertEqual(viaRanker.choice, viaBrain.choice)
        for i in 0..<viaRanker.value.count {
            XCTAssertEqual(viaRanker.value[i],
                viaBrain.value[i], accuracy: 1e-6)
        }
    }

    // MARK: - Edge cases

    func testGeluEmptyInputReturnsEmpty() {
        let r = BASAutoRouteRanker.gelu([])
        XCTAssertTrue(r.value.isEmpty)
    }

    func testSiluEmptyInputReturnsEmpty() {
        let r = BASAutoRouteRanker.silu([])
        XCTAssertTrue(r.value.isEmpty)
    }

    // MARK: - Calibrated thresholds round-trip

    func testRouterAcceptsCustomGeluTanhThreshold() {
        // Force scalar even at dim=1024 via custom threshold
        let custom = BASAutoRouteThresholds(
            geluTanhSIMDMinDim: 4096)
        let x = [Float](repeating: 0.5, count: 1024)
        let r = BASAutoRouteRanker.geluTanhApprox(
            x, thresholds: custom)
        #if os(iOS) || os(macOS)
        XCTAssertEqual(r.choice, .rustGeluTanhScalar,
            "custom threshold 4096 forces scalar at dim=1024")
        #endif
    }
}
