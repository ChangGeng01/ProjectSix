// MARK: - BASChapter707FlashAttentionTests
// chapter 七百七 第一刀 / M2206
//
// Validates the new tiled FlashAttention dispatcher produces
// output mathematically equivalent (within float32 tolerance)
// to the standard scaled_dot_product_attention kernel。

import XCTest
@testable import BASHostKit
@testable import BASMetalSubstrate

final class BASChapter707FlashAttentionTests: XCTestCase {

    /// Compare FlashAttention output to standard scaled_dot_
    /// product_attention output on the same Q/K/V tensors。
    /// Both kernels compute mathematically identical attention
    /// — agreement within float32 tolerance is the correctness
    /// proof for the tiled implementation。
    func testFlashAttentionMatchesScaledDotProductForward()
        async throws
    {
        let brain = try await BASCognitiveBrain
            .makeWithAllPilots()
        // Deterministic small inputs — M=3, N=4, D=Dv=8
        let M = 3, N = 4, D = 8, Dv = 8
        var seed: UInt32 = 0xC0FFEE
        func next() -> Float {
            seed = seed &* 1664525 &+ 1013904223
            return Float(seed & 0xFFFF)
                / Float(0xFFFF) - 0.5
        }
        let q = (0..<(M * D)).map { _ in next() }
        let k = (0..<(N * D)).map { _ in next() }
        let v = (0..<(N * Dv)).map { _ in next() }

        let standard = try await brain.attention(
            q: q, qRows: M, qCols: D,
            k: k, kRows: N,
            v: v, vCols: Dv)
        let flash = try await brain.flashAttention(
            q: q, qRows: M, qCols: D,
            k: k, kRows: N,
            v: v, vCols: Dv)
        XCTAssertEqual(standard.count, flash.count)
        for idx in 0..<standard.count {
            XCTAssertEqual(
                standard[idx], flash[idx],
                accuracy: 1e-3,
                "cell \(idx) diverges: standard=" +
                "\(standard[idx]) flash=\(flash[idx])")
        }
    }

    /// FlashAttention with all-identical inputs → all-identical
    /// outputs (uniform softmax weights × identical V)。
    func testFlashAttentionUniformOutputs() async throws {
        let brain = try await BASCognitiveBrain
            .makeWithAllPilots()
        let M = 2, N = 3, D = 4, Dv = 2
        let q = [Float](repeating: 0.5, count: M * D)
        let k = [Float](repeating: 0.5, count: N * D)
        let v: [Float] = [
            1.0, 2.0,
            1.0, 2.0,
            1.0, 2.0,
        ]
        let out = try await brain.flashAttention(
            q: q, qRows: M, qCols: D,
            k: k, kRows: N,
            v: v, vCols: Dv)
        XCTAssertEqual(out.count, M * Dv)
        for i in 0..<M {
            XCTAssertEqual(
                out[i * Dv + 0], 1.0, accuracy: 1e-4)
            XCTAssertEqual(
                out[i * Dv + 1], 2.0, accuracy: 1e-4)
        }
    }

    /// Validate shape-mismatch error。
    func testFlashAttentionShapeMismatchThrows() async throws {
        let brain = try await BASCognitiveBrain
            .makeWithAllPilots()
        do {
            _ = try await brain.flashAttention(
                q: [1, 2], qRows: 1, qCols: 4,  // q.count=2 but 1*4=4
                k: [1, 2, 3, 4], kRows: 1,
                v: [5, 6], vCols: 2)
            XCTFail("shape mismatch must throw")
        } catch BASMetalFlashAttentionDispatcherError
            .shapeMismatch
        {
            // expected
        }
    }

    /// Zero-dim should throw。
    func testFlashAttentionZeroDimThrows() async throws {
        let brain = try await BASCognitiveBrain
            .makeWithAllPilots()
        do {
            _ = try await brain.flashAttention(
                q: [], qRows: 0, qCols: 4,
                k: [1, 2, 3, 4], kRows: 1,
                v: [5, 6], vCols: 2)
            XCTFail("zero dim must throw")
        } catch BASMetalFlashAttentionDispatcherError
            .zeroDimension
        {
            // expected
        }
    }

    /// Head dim cap exceeded should throw。
    func testFlashAttentionHeadDimCapThrows() async throws {
        let brain = try await BASCognitiveBrain
            .makeWithAllPilots()
        let D = 128 // > BASMetalFlashAttentionTileConfig.dMax (64)
        let q = [Float](repeating: 0.1, count: 1 * D)
        let k = [Float](repeating: 0.1, count: 1 * D)
        let v = [Float](repeating: 0.1, count: 1 * D)
        do {
            _ = try await brain.flashAttention(
                q: q, qRows: 1, qCols: D,
                k: k, kRows: 1,
                v: v, vCols: D)
            XCTFail("head dim cap must throw")
        } catch BASMetalFlashAttentionDispatcherError
            .maxHeadDimExceeded
        {
            // expected
        }
    }
}
