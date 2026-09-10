// MARK: - BASChapter706AutoRouteTests
// chapter 七百六 第四刀 / M2204
//
// Validates the auto-router picks the expected implementation
// per input size + produces results byte-equivalent to manual
// path selection。

import XCTest
@testable import BASRuntimeCore
@testable import BASHostKit

final class BASChapter706AutoRouteTests: XCTestCase {

    // MARK: - Cosine — picks correct path per dim

    func testCosineSmallDimPicksScalar() {
        let a: [Float] = (0..<8).map { Float($0) * 0.1 }
        let b: [Float] = (0..<8).map { Float(7 - $0) * 0.1 }
        let r = BASCognitiveBrain.cosineSimilarityAuto(a, b)
        XCTAssertEqual(r.choice, .rustScalar)
        XCTAssertGreaterThanOrEqual(r.value, -1.0)
        XCTAssertLessThanOrEqual(r.value, 1.0)
    }

    func testCosineLargeDimPicksSIMD() {
        let dim = 256
        let a: [Float] = (0..<dim).map { Float($0) * 0.01 }
        let b: [Float] = (0..<dim).map {
            Float(dim - $0) * 0.01 }
        let r = BASCognitiveBrain.cosineSimilarityAuto(a, b)
        XCTAssertEqual(r.choice, .rustSIMD)
        XCTAssertGreaterThanOrEqual(r.value, -1.0)
        XCTAssertLessThanOrEqual(r.value, 1.0)
    }

    func testCosineExactlyAtThresholdPicksSIMD() {
        // Default cosineSIMDMinDim is 64
        let dim = 64
        let a: [Float] = (0..<dim).map { Float($0) * 0.01 }
        let b: [Float] = (0..<dim).map {
            Float(dim - $0) * 0.01 }
        let r = BASCognitiveBrain.cosineSimilarityAuto(a, b)
        XCTAssertEqual(r.choice, .rustSIMD)
    }

    func testCosineJustBelowThresholdPicksScalar() {
        // 63 < 64 → scalar
        let dim = 63
        let a: [Float] = (0..<dim).map { Float($0) * 0.01 }
        let b: [Float] = (0..<dim).map {
            Float(dim - $0) * 0.01 }
        let r = BASCognitiveBrain.cosineSimilarityAuto(a, b)
        XCTAssertEqual(r.choice, .rustScalar)
    }

    // MARK: - Custom threshold override

    func testCustomThresholdMovesCrossover() {
        let dim = 16
        let a: [Float] = (0..<dim).map { Float($0) * 0.1 }
        let b: [Float] = (0..<dim).map { Float($0) * 0.1 }
        // Force SIMD even for dim=16
        let t = BASAutoRouteThresholds(
            cosineSIMDMinDim: 8,
            sha256CryptoKitMinBytes: 1024)
        let r = BASCognitiveBrain.cosineSimilarityAuto(
            a, b, thresholds: t)
        XCTAssertEqual(r.choice, .rustSIMD)
    }

    // MARK: - Self-similarity invariant

    func testAutoRouteSelfSimilarityEqualsOne() {
        for dim in [8, 32, 64, 256, 1024] {
            let v: [Float] = (0..<dim).map {
                Float($0) * 0.01 + 0.5 }
            let r = BASCognitiveBrain
                .cosineSimilarityAuto(v, v)
            XCTAssertEqual(
                r.value, 1.0, accuracy: 1e-4,
                "dim=\(dim) self-similarity must be 1")
        }
    }

    // MARK: - Empty + mismatched inputs

    func testEmptyInputReturnsZero() {
        let r = BASCognitiveBrain
            .cosineSimilarityAuto([], [])
        XCTAssertEqual(r.value, 0.0)
        XCTAssertEqual(r.choice, .swiftNaive)
    }

    func testMismatchedLengthsReturnsZero() {
        let r = BASCognitiveBrain.cosineSimilarityAuto(
            [1, 2, 3], [1, 2])
        XCTAssertEqual(r.value, 0.0)
        XCTAssertEqual(r.choice, .swiftNaive)
    }

    // MARK: - L2 norm always picks SIMD

    func testL2NormAlwaysPicksSIMD() {
        let v: [Float] = [3, 4]
        let r = BASAutoRouteRanker.l2Norm(v)
        XCTAssertEqual(r.choice, .rustSIMD)
        XCTAssertEqual(r.value, 5.0, accuracy: 1e-5)
    }

    func testL2NormLargeVector() {
        let v: [Float] = (0..<1024).map { Float($0) * 0.01 }
        let r = BASAutoRouteRanker.l2Norm(v)
        XCTAssertEqual(r.choice, .rustSIMD)
        XCTAssertGreaterThan(r.value, 0)
    }

    // MARK: - SHA256 crossover

    func testSha256SmallPicksRust() {
        let payload = Array("hi".utf8)
        let r = BASAutoRouteRanker.sha256(payload)
        XCTAssertEqual(r.choice, .rustPureSHA256)
        XCTAssertEqual(r.value.count, 32)
    }

    func testSha256LargePicksCryptoKit() {
        let payload = [UInt8](repeating: 0xAB, count: 4096)
        let r = BASAutoRouteRanker.sha256(payload)
        XCTAssertEqual(r.choice, .swiftCryptoKit)
        XCTAssertEqual(r.value.count, 32)
    }

    func testSha256BothImplsAgreeOnSmallPayload() {
        let payload = Array("the quick brown fox".utf8)
        let smallResult =
            BASAutoRouteRanker.sha256(payload)
        // Force CryptoKit by setting a tiny threshold
        let t = BASAutoRouteThresholds(
            cosineSIMDMinDim: 64,
            sha256CryptoKitMinBytes: 1)
        let ckResult = BASAutoRouteRanker.sha256(
            payload, thresholds: t)
        XCTAssertEqual(smallResult.value, ckResult.value,
            "Rust pure SHA256 + CryptoKit must produce" +
            " byte-identical digests")
    }
}
