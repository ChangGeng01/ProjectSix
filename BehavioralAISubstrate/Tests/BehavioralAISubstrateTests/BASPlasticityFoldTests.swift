// MARK: - BASPlasticityFoldTests
// chapter 四百五十四 / M1194 — POST-SWEEP BIOMIMETIC

import XCTest
import Foundation
@testable import BASMetalSubstrate

final class BASPlasticityFoldTests: XCTestCase {

    // MARK: - Construction

    func testConstructionZeroesWeights() async {
        let shape = BASPlasticityFoldShape(
            preDim: 2, postDim: 3)
        let fold = BASPlasticityFold(shape: shape)
        let initial =
            await fold.currentWeightsSnapshot()
        XCTAssertEqual(initial.count, 6)
        XCTAssertTrue(
            initial.allSatisfy { $0 == 0 })
        let count = await fold.updateCount()
        XCTAssertEqual(count, 0)
    }

    func testShapeClampsToValidRange() async {
        let shape = BASPlasticityFoldShape(
            preDim: -2,
            postDim: 0,
            learningRate: -0.5)
        XCTAssertEqual(shape.preDim, 1)
        XCTAssertEqual(shape.postDim, 1)
        XCTAssertEqual(shape.learningRate, 0,
            "negative learning rate clamps to 0")
    }

    func testRuleEnumHasFourCases() {
        XCTAssertEqual(
            BASPlasticityRule.allCases.count, 4,
            "4 plasticity rules: hebbian +" +
            " antiHebbian + outcomeModulatedHebbian" +
            " + stdpTemporal (chapter 457)")
    }

    // MARK: - Hebbian rule

    /// pre = [1, 2], post = [3, 4], α = 0.1
    /// Δ = 0.1 · pre ⊗ post = 0.1 · [[3, 4],
    ///                                [6, 8]]
    ///   = [[0.3, 0.4],
    ///      [0.6, 0.8]]
    func testHebbianCanonicalUpdate() async throws {
        let shape = BASPlasticityFoldShape(
            preDim: 2, postDim: 2,
            learningRate: 0.1,
            rule: .hebbian)
        let fold = BASPlasticityFold(shape: shape)
        let result = try await fold.apply(
            pre: [1, 2], post: [3, 4])
        XCTAssertEqual(
            result.weightDelta,
            [0.3, 0.4, 0.6, 0.8],
            "Hebbian delta = α · (pre ⊗ post)")
        XCTAssertEqual(
            result.updatedWeightSnapshot,
            [0.3, 0.4, 0.6, 0.8])
        XCTAssertEqual(result.updateIndex, 0)
    }

    /// Hebbian accumulates correlations across multiple
    /// updates。 Same pair applied 5 times = 5× single
    /// update。
    func testHebbianAccumulatesAcrossUpdates() async throws {
        let shape = BASPlasticityFoldShape(
            preDim: 2, postDim: 1,
            learningRate: 0.5,
            rule: .hebbian)
        let fold = BASPlasticityFold(shape: shape)
        for _ in 0..<5 {
            _ = try await fold.apply(
                pre: [1, 2], post: [3])
        }
        let w = await fold.currentWeightsSnapshot()
        // Single update: Δ = 0.5 · [1·3, 2·3] = [1.5, 3]
        // 5 updates: [7.5, 15]
        XCTAssertEqual(w[0], 7.5, accuracy: 1e-5)
        XCTAssertEqual(w[1], 15.0, accuracy: 1e-5)
    }

    // MARK: - Anti-Hebbian rule

    /// Anti-Hebbian: W -= α · (pre ⊗ post)
    func testAntiHebbianCanonical() async throws {
        let shape = BASPlasticityFoldShape(
            preDim: 2, postDim: 2,
            learningRate: 0.1,
            rule: .antiHebbian)
        let fold = BASPlasticityFold(shape: shape)
        let result = try await fold.apply(
            pre: [1, 2], post: [3, 4])
        // delta = -0.1 · [[3,4],[6,8]] = [[-0.3,-0.4],[-0.6,-0.8]]
        XCTAssertEqual(
            result.weightDelta,
            [-0.3, -0.4, -0.6, -0.8])
        XCTAssertEqual(
            result.updatedWeightSnapshot,
            [-0.3, -0.4, -0.6, -0.8])
    }

    // MARK: - Outcome-modulated Hebbian

    /// outcome=0 → zero update (no learning)
    func testOutcomeZeroFreezesLearning() async throws {
        let shape = BASPlasticityFoldShape(
            preDim: 2, postDim: 2,
            learningRate: 0.5,
            rule: .outcomeModulatedHebbian)
        let fold = BASPlasticityFold(shape: shape)
        let result = try await fold.apply(
            pre: [1, 2], post: [3, 4],
            outcome: 0)
        XCTAssertEqual(
            result.weightDelta,
            [0, 0, 0, 0],
            "outcome=0 must zero the update")
        XCTAssertEqual(
            result.updatedWeightSnapshot,
            [0, 0, 0, 0])
    }

    /// Positive outcome reinforces;negative outcome
    /// anti-reinforces。
    func testOutcomePositiveReinforces() async throws {
        let shape = BASPlasticityFoldShape(
            preDim: 1, postDim: 1,
            learningRate: 0.1,
            rule: .outcomeModulatedHebbian)
        let fold = BASPlasticityFold(shape: shape)
        let pos = try await fold.apply(
            pre: [2], post: [3], outcome: 5)
        // Δ = 0.1 · 5 · 2 · 3 = 3.0
        XCTAssertEqual(pos.weightDelta.count, 1)
        XCTAssertEqual(
            pos.weightDelta[0], 3.0, accuracy: 1e-5)
        await fold.reset()
        let neg = try await fold.apply(
            pre: [2], post: [3], outcome: -2)
        // Δ = 0.1 · -2 · 2 · 3 = -1.2
        XCTAssertEqual(neg.weightDelta.count, 1)
        XCTAssertEqual(
            neg.weightDelta[0], -1.2, accuracy: 1e-5)
    }

    // MARK: - Forward pass uses current weights

    /// After training W with one Hebbian update,
    /// forward(pre) should produce the expected
    /// projection。
    func testForwardUsesCurrentWeights() async throws {
        let shape = BASPlasticityFoldShape(
            preDim: 2, postDim: 2,
            learningRate: 0.1,
            rule: .hebbian)
        let fold = BASPlasticityFold(shape: shape)
        _ = try await fold.apply(
            pre: [1, 2], post: [3, 4])
        // W = [[0.3, 0.4], [0.6, 0.8]]
        // forward([1, 0]) = [1·0.3 + 0·0.6, 1·0.4 + 0·0.8]
        //                 = [0.3, 0.4]
        let out = try await fold.forward(pre: [1, 0])
        let expected1: [Float] = [0.3, 0.4]
        XCTAssertEqual(out.count, expected1.count)
        for i in 0..<expected1.count {
            XCTAssertEqual(
                out[i], expected1[i], accuracy: 1e-5,
                "forward([1,0])[\(i)]")
        }
        // forward([0, 1]) = [0·0.3 + 1·0.6, 0·0.4 + 1·0.8]
        //                 = [0.6, 0.8]
        let out2 = try await fold.forward(pre: [0, 1])
        let expected2: [Float] = [0.6, 0.8]
        for i in 0..<expected2.count {
            XCTAssertEqual(
                out2[i], expected2[i], accuracy: 1e-5,
                "forward([0,1])[\(i)]")
        }
    }

    // MARK: - reset()

    func testResetZeroesWeights() async throws {
        let shape = BASPlasticityFoldShape(
            preDim: 2, postDim: 2,
            learningRate: 0.5,
            rule: .hebbian)
        let fold = BASPlasticityFold(shape: shape)
        _ = try await fold.apply(
            pre: [1, 1], post: [1, 1])
        let beforeReset =
            await fold.currentWeightsSnapshot()
        XCTAssertFalse(
            beforeReset.allSatisfy { $0 == 0 })
        await fold.reset()
        let afterReset =
            await fold.currentWeightsSnapshot()
        XCTAssertTrue(
            afterReset.allSatisfy { $0 == 0 })
        let count = await fold.updateCount()
        XCTAssertEqual(count, 0)
    }

    // MARK: - Learning convergence (Hebbian)

    /// **HEBBIAN LEARNING PROOF**: repeatedly apply
    /// the same (pre, post) pair → weights grow
    /// proportionally to the number of updates。
    /// forward(pre) becomes increasingly aligned with
    /// post (up to scaling)。
    func testHebbianLearnsAssociation() async throws {
        let shape = BASPlasticityFoldShape(
            preDim: 3, postDim: 3,
            learningRate: 0.1,
            rule: .hebbian)
        let fold = BASPlasticityFold(shape: shape)
        let pre: [Float] = [1, 0, 0]
        let post: [Float] = [0, 1, 0]
        // Apply 10 times
        for _ in 0..<10 {
            _ = try await fold.apply(
                pre: pre, post: post)
        }
        // forward(pre) should now point heavily at
        // post (output[1] dominates other dims)
        let projection = try await fold.forward(
            pre: pre)
        XCTAssertEqual(
            projection[0], 0, accuracy: 1e-5,
            "output[0] = 1 · W[0,0] = 1·0 = 0")
        XCTAssertEqual(
            projection[1], 1.0, accuracy: 1e-5,
            "output[1] = 1 · W[0,1] = 1 · 10·0.1·1·1 = 1")
        XCTAssertEqual(
            projection[2], 0, accuracy: 1e-5,
            "output[2] = 1 · W[0,2] = 0")
    }

    // MARK: - Shape validation

    func testShapeMismatchThrows() async {
        let shape = BASPlasticityFoldShape(
            preDim: 2, postDim: 3)
        let fold = BASPlasticityFold(shape: shape)
        do {
            _ = try await fold.apply(
                pre: [1],         // wrong: 1 vs preDim=2
                post: [1, 1, 1])
            XCTFail("expected shape mismatch")
        } catch BASPlasticityError
            .shapeMismatch(let reason)
        {
            XCTAssertTrue(reason.contains("pre.count"))
        } catch {
            XCTFail("wrong error type: \(error)")
        }
    }
}
