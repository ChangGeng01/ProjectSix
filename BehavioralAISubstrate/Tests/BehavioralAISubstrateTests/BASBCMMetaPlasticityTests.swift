// MARK: - BASBCMMetaPlasticityTests
// chapter 四百六十九 / M1254 PROOF tests

import XCTest
@testable import BASMetalSubstrate

final class BASBCMMetaPlasticityTests: XCTestCase {

    func testShapeClampsDims() {
        let s = BASBCMMetaPlasticityShape(
            preDim: 0, postDim: -1)
        XCTAssertEqual(s.preDim, 1)
        XCTAssertEqual(s.postDim, 1)
    }

    func testShapeClampsLearningRateNonNegative() {
        let s = BASBCMMetaPlasticityShape(
            preDim: 1, postDim: 1,
            learningRate: -0.5)
        XCTAssertEqual(s.learningRate, 0)
    }

    func testShapeClampsThresholdTimeConstantToUnit() {
        let s = BASBCMMetaPlasticityShape(
            preDim: 1, postDim: 1,
            thresholdTimeConstant: 5.0)
        XCTAssertLessThanOrEqual(
            s.thresholdTimeConstant, 1.0)
    }

    func testActorConstructionInitialState() async {
        let s = BASBCMMetaPlasticityShape(
            preDim: 2, postDim: 3,
            initialThreshold: 0.42)
        let bcm = BASBCMMetaPlasticity(shape: s)
        let w = await bcm.currentWeightsSnapshot()
        XCTAssertEqual(w.count, 6)
        XCTAssertEqual(w, [0, 0, 0, 0, 0, 0])
        let theta = await bcm.currentThreshold()
        XCTAssertEqual(theta, 0.42)
        let count = await bcm.updateCount()
        XCTAssertEqual(count, 0)
    }

    func testApplyShapeMismatchPreThrows() async throws {
        let s = BASBCMMetaPlasticityShape(
            preDim: 2, postDim: 2)
        let bcm = BASBCMMetaPlasticity(shape: s)
        do {
            _ = try await bcm.apply(
                pre: [1.0],
                post: [0.5, 0.5])
            XCTFail("expected throw")
        } catch let err as BASBCMMetaPlasticityError {
            switch err {
            case .shapeMismatch(let reason):
                XCTAssertTrue(reason.contains("pre"))
            }
        }
    }

    /// LTP regime:post[j] > θ → ΔW positive。
    func testApplyLTPRegime() async throws {
        let s = BASBCMMetaPlasticityShape(
            preDim: 1, postDim: 1,
            learningRate: 1.0,
            thresholdTimeConstant: 0.0,
            initialThreshold: 0.5)
        let bcm = BASBCMMetaPlasticity(shape: s)
        // pre = [1.0], post = [1.0], θ = 0.5
        // ΔW = 1.0 · 1.0 · 1.0 · (1.0 - 0.5) = 0.5
        let r = try await bcm.apply(
            pre: [1.0], post: [1.0])
        XCTAssertEqual(r.weightDelta[0], 0.5,
            accuracy: 1e-5)
        XCTAssertGreaterThan(r.weightDelta[0], 0,
            "post > θ → LTP")
    }

    /// LTD regime:post[j] < θ → ΔW negative。
    func testApplyLTDRegime() async throws {
        let s = BASBCMMetaPlasticityShape(
            preDim: 1, postDim: 1,
            learningRate: 1.0,
            thresholdTimeConstant: 0.0,
            initialThreshold: 0.5)
        let bcm = BASBCMMetaPlasticity(shape: s)
        // pre = [1.0], post = [0.2], θ = 0.5
        // ΔW = 1.0 · 1.0 · 0.2 · (0.2 - 0.5) = -0.06
        let r = try await bcm.apply(
            pre: [1.0], post: [0.2])
        XCTAssertLessThan(r.weightDelta[0], 0,
            "post < θ → LTD")
    }

    /// Crossover at post = θ:ΔW = 0。
    func testApplyZeroAtThreshold() async throws {
        let s = BASBCMMetaPlasticityShape(
            preDim: 1, postDim: 1,
            learningRate: 1.0,
            thresholdTimeConstant: 0.0,
            initialThreshold: 0.5)
        let bcm = BASBCMMetaPlasticity(shape: s)
        let r = try await bcm.apply(
            pre: [1.0], post: [0.5])
        XCTAssertEqual(r.weightDelta[0], 0,
            accuracy: 1e-7,
            "post == θ → no weight update")
    }

    /// THE BEDROCK META-PLASTICITY PROOF:
    /// Sustained high post activity raises θ over time。
    /// After enough updates,what was previously LTP
    /// becomes neutral or LTD — homeostatic stability。
    func testThresholdRisesWithSustainedHighActivity()
        async throws
    {
        let s = BASBCMMetaPlasticityShape(
            preDim: 1, postDim: 1,
            learningRate: 0.0,   // freeze weights
            thresholdTimeConstant: 0.5,
            initialThreshold: 0.0)
        let bcm = BASBCMMetaPlasticity(shape: s)
        var lastTheta: Float = 0
        for _ in 0..<10 {
            let r = try await bcm.apply(
                pre: [1.0], post: [1.0])
            // Threshold should monotonically rise
            // toward mean(post²) = 1.0
            XCTAssertGreaterThanOrEqual(
                r.updatedThreshold, lastTheta,
                "threshold must monotonically rise" +
                " under sustained high post activity")
            lastTheta = r.updatedThreshold
        }
        // After 10 iterations with τ=0.5,θ has
        // converged toward 1.0
        XCTAssertGreaterThan(lastTheta, 0.99,
            "θ → 1.0 (mean post²) after sustained" +
            " activity")
    }

    func testResetClearsAllState() async throws {
        let s = BASBCMMetaPlasticityShape(
            preDim: 1, postDim: 1,
            learningRate: 1.0,
            thresholdTimeConstant: 0.5,
            initialThreshold: 0.3)
        let bcm = BASBCMMetaPlasticity(shape: s)
        _ = try await bcm.apply(
            pre: [1.0], post: [1.0])
        _ = try await bcm.apply(
            pre: [1.0], post: [1.0])
        await bcm.reset()
        let w = await bcm.currentWeightsSnapshot()
        XCTAssertEqual(w, [0])
        let theta = await bcm.currentThreshold()
        XCTAssertEqual(theta, 0.3,
            "threshold must restore to initial after" +
            " reset")
        let count = await bcm.updateCount()
        XCTAssertEqual(count, 0)
    }

    func testShapeCodableRoundTrip() throws {
        let s = BASBCMMetaPlasticityShape(
            preDim: 5, postDim: 7,
            learningRate: 0.03,
            thresholdTimeConstant: 0.1,
            initialThreshold: 0.4)
        let data = try JSONEncoder().encode(s)
        let decoded = try JSONDecoder().decode(
            BASBCMMetaPlasticityShape.self, from: data)
        XCTAssertEqual(decoded, s)
    }
}
