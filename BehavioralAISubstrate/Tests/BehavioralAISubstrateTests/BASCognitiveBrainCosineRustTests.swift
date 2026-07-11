// MARK: - BASCognitiveBrainCosineRustTests
// chapter 七百四 第三刀 / M2193
//
// Verifies brain.cosineSimilarityRust(_:_:) — the Rust-backed
// CPU cosine path — produces results byte-equivalent to
// brain.cosineSimilarity (Metal GPU path) within float32
// tolerance + matches reference cases (self == 1, orthogonal
// == 0, opposite == -1)。

import XCTest
@testable import BASHostKit
@testable import BASMetalSubstrate

final class BASCognitiveBrainCosineRustTests: XCTestCase {

    func testSelfSimilarityEqualsOne() async throws {
        let brain = try await BASCognitiveBrain
            .makeWithAllPilots()
        let v: [Float] = [1, 2, 3, 4, 5]
        let r = try await brain.cosineSimilarityRust(v, v)
        XCTAssertEqual(r, 1.0, accuracy: 1e-5)
    }

    func testOrthogonalEqualsZero() async throws {
        let brain = try await BASCognitiveBrain
            .makeWithAllPilots()
        let a: [Float] = [1, 0, 0]
        let b: [Float] = [0, 1, 0]
        let r = try await brain.cosineSimilarityRust(a, b)
        XCTAssertEqual(r, 0.0, accuracy: 1e-5)
    }

    func testOppositeEqualsMinusOne() async throws {
        let brain = try await BASCognitiveBrain
            .makeWithAllPilots()
        let a: [Float] = [1, 0]
        let b: [Float] = [-1, 0]
        let r = try await brain.cosineSimilarityRust(a, b)
        XCTAssertEqual(r, -1.0, accuracy: 1e-5)
    }

    func testEmptyVectorThrows() async throws {
        let brain = try await BASCognitiveBrain
            .makeWithAllPilots()
        do {
            _ = try await brain.cosineSimilarityRust(
                [], [])
            XCTFail("empty input must throw")
        } catch BASMetalCosineSimilarityDispatcherError
            .zeroLengthVectors
        {
            // expected
        }
    }

    func testLengthMismatchThrows() async throws {
        let brain = try await BASCognitiveBrain
            .makeWithAllPilots()
        do {
            _ = try await brain.cosineSimilarityRust(
                [1, 2], [1, 2, 3])
            XCTFail("length mismatch must throw")
        } catch BASMetalCosineSimilarityDispatcherError
            .payloadCountMismatch
        {
            // expected
        }
    }

    /// Rust CPU cosine should match Metal GPU cosine within
    /// float32 tolerance for the same inputs。 Demonstrates
    /// 「术业有专攻」: both paths agree but the Rust path is
    /// the cheap CPU-side option for small dim。
    func testRustMatchesMetalWithinTolerance() async throws {
        let brain = try await BASCognitiveBrain
            .makeWithAllPilots()
        let a: [Float] = [
            0.1, 0.2, 0.3, 0.4, 0.5,
            0.6, 0.7, 0.8, 0.9, 1.0,
        ]
        let b: [Float] = [
            -0.5, 0.5, -0.5, 0.5, -0.5,
            0.5, -0.5, 0.5, -0.5, 0.5,
        ]
        let rustResult =
            try await brain.cosineSimilarityRust(a, b)
        let metalResult =
            try await brain.cosineSimilarity(a, b)
        XCTAssertEqual(
            rustResult, metalResult.similarity,
            accuracy: 1e-4,
            "Rust CPU cosine + Metal GPU cosine must" +
            " agree within float32 tolerance")
    }
}
