// MARK: - BASChapter709AutoRouteTests
// chapter 七百九 第四刀 / M2219
//
// Verifies brain.softmaxAuto + brain.layerNormAuto pick
// correctly per dim + produce numerically valid output。

import XCTest
import Foundation
@testable import BASRuntimeCore
@testable import BASHostKit

final class BASChapter709AutoRouteTests: XCTestCase {

    // MARK: - Softmax

    func testSoftmaxAlwaysPicksRustScalar() {
        for dim in [4, 16, 64, 256, 1024] {
            let v: [Float] = (0..<dim).map {
                Float($0) * 0.01 }
            let r = BASCognitiveBrain.softmaxAuto(v)
            XCTAssertEqual(r.choice, .rustSoftmaxScalar)
            XCTAssertEqual(r.value.count, dim)
        }
    }

    func testSoftmaxSumsToOne() {
        let v: [Float] = (0..<16).map {
            Float($0) * 0.1 - 0.8 }
        let r = BASCognitiveBrain.softmaxAuto(v)
        let sum = r.value.reduce(0, +)
        XCTAssertEqual(sum, 1.0, accuracy: 1e-5)
    }

    func testSoftmaxHandlesLargeMagnitude() {
        // [1000, 0, 0] — without max-subtract this would
        // overflow。 Auto-router uses numerically-stable Rust impl。
        let r = BASCognitiveBrain.softmaxAuto(
            [1000.0, 0.0, 0.0])
        XCTAssertEqual(r.value[0], 1.0, accuracy: 1e-5)
        XCTAssertLessThan(r.value[1], 1e-5)
        XCTAssertLessThan(r.value[2], 1e-5)
    }

    func testSoftmaxEmptyReturnsEmpty() {
        let r = BASCognitiveBrain.softmaxAuto([])
        XCTAssertTrue(r.value.isEmpty)
    }

    // MARK: - LayerNorm

    func testLayerNormSmallDimPicksNaive() {
        // dim=64 < 128 → naive
        let v: [Float] = (0..<64).map {
            Float($0) * 0.01 - 0.3 }
        let r = BASCognitiveBrain.layerNormAuto(v)
        XCTAssertEqual(r.choice, .rustLayerNormNaive)
        XCTAssertEqual(r.value.count, 64)
    }

    func testLayerNormLargeDimPicksAffineSIMD() {
        // dim=256 ≥ 128 → affine SIMD
        let v: [Float] = (0..<256).map {
            Float($0) * 0.005 - 0.6 }
        let r = BASCognitiveBrain.layerNormAuto(v)
        XCTAssertEqual(
            r.choice, .rustLayerNormAffineSIMD)
        XCTAssertEqual(r.value.count, 256)
    }

    func testLayerNormExactlyAtThresholdPicksSIMD() {
        let v: [Float] = (0..<128).map { Float($0) * 0.01 }
        let r = BASCognitiveBrain.layerNormAuto(v)
        XCTAssertEqual(
            r.choice, .rustLayerNormAffineSIMD)
    }

    func testLayerNormOutputHasZeroMean() {
        let v: [Float] = (0..<64).map {
            Float($0) * 0.1 - 3.0 }
        let r = BASCognitiveBrain.layerNormAuto(v)
        let mean = r.value.reduce(0, +) / Float(r.value.count)
        XCTAssertEqual(mean, 0.0, accuracy: 1e-3)
    }

    func testLayerNormCustomThresholdMovesCrossover() {
        let v: [Float] = (0..<64).map {
            Float($0) * 0.1 - 3.0 }
        // Force SIMD at 64
        let t = BASAutoRouteThresholds(
            cosineSIMDMinDim: 64,
            sha256CryptoKitMinBytes: 1024,
            attentionMetalMinProduct: 64,
            matMulMetalMinProduct: 262_144,
            layerNormSIMDMinDim: 1)
        let r = BASCognitiveBrain.layerNormAuto(
            v, thresholds: t)
        XCTAssertEqual(
            r.choice, .rustLayerNormAffineSIMD)
    }

    func testLayerNormEmptyReturnsEmpty() {
        let r = BASCognitiveBrain.layerNormAuto([])
        XCTAssertTrue(r.value.isEmpty)
    }

    /// Cross-impl agreement — naive and affine SIMD produce
    /// the same output for plain (γ=1 β=0) LayerNorm。
    func testLayerNormCrossImplAgreement() {
        let v: [Float] = (0..<128).map {
            Float($0) * 0.05 - 3.0 }
        let naive = BASCognitiveBrain.layerNormAuto(
            v,
            thresholds: BASAutoRouteThresholds(
                layerNormSIMDMinDim: 999))
        let simd = BASCognitiveBrain.layerNormAuto(
            v,
            thresholds: BASAutoRouteThresholds(
                layerNormSIMDMinDim: 1))
        XCTAssertEqual(naive.choice, .rustLayerNormNaive)
        XCTAssertEqual(
            simd.choice, .rustLayerNormAffineSIMD)
        for i in 0..<v.count {
            XCTAssertEqual(
                naive.value[i], simd.value[i],
                accuracy: 1e-4)
        }
    }
}
