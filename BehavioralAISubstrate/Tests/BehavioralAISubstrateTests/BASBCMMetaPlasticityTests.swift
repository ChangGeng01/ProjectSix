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

    // MARK: - Snapshot persistence (chapter 467/468 gap fix)

    func testBCMSnapshotCodableRoundTrip() throws {
        let shape = BASBCMMetaPlasticityShape(
            preDim: 2, postDim: 3,
            learningRate: 0.05,
            thresholdTimeConstant: 0.1,
            initialThreshold: 0.4)
        let snap = BASBCMMetaPlasticitySnapshot(
            shape: shape,
            weights: [
                0.1, 0.2, 0.3,
                0.4, 0.5, 0.6,
            ],
            threshold: 0.73,
            updatesProcessed: 9)
        let data = try JSONEncoder().encode(snap)
        let decoded = try JSONDecoder().decode(
            BASBCMMetaPlasticitySnapshot.self, from: data)
        XCTAssertEqual(decoded, snap)
        XCTAssertEqual(decoded.shape, shape)
        XCTAssertEqual(decoded.weights.count, 6)
        XCTAssertEqual(decoded.threshold, 0.73)
        XCTAssertEqual(decoded.updatesProcessed, 9)
    }

    func testBCMExportReturnsCurrentState() async throws {
        let shape = BASBCMMetaPlasticityShape(
            preDim: 2, postDim: 2,
            learningRate: 1.0,
            thresholdTimeConstant: 0.0,
            initialThreshold: 0.3)
        let bcm = BASBCMMetaPlasticity(shape: shape)
        let snap0 = await bcm.exportSnapshot()
        XCTAssertEqual(snap0.shape, shape)
        XCTAssertEqual(snap0.weights.count, 4)
        XCTAssertEqual(snap0.weights, [0, 0, 0, 0])
        XCTAssertEqual(snap0.threshold, 0.3)
        XCTAssertEqual(snap0.updatesProcessed, 0)
    }

    /// Export→import round-trip restores BOTH weights and
    /// the sliding threshold θ (the field uniquely at risk
    /// of being dropped in the checkpoint→replay loop)。
    func testBCMImportRestoresWeightsAndThreshold()
        async throws
    {
        let shape = BASBCMMetaPlasticityShape(
            preDim: 1, postDim: 1,
            learningRate: 1.0,
            thresholdTimeConstant: 0.5,
            initialThreshold: 0.2)
        let bcm = BASBCMMetaPlasticity(shape: shape)
        _ = try await bcm.apply(pre: [1.0], post: [1.0])
        let snap1 = await bcm.exportSnapshot()
        XCTAssertEqual(snap1.updatesProcessed, 1)
        let savedWeights = snap1.weights
        let savedThreshold = snap1.threshold
        XCTAssertNotEqual(savedThreshold, 0.2,
            "θ must have drifted from initial")
        // Mutate further (drift weights + θ)
        _ = try await bcm.apply(pre: [1.0], post: [1.0])
        let snap2 = await bcm.exportSnapshot()
        XCTAssertEqual(snap2.updatesProcessed, 2)
        XCTAssertNotEqual(snap2.weights, savedWeights)
        XCTAssertNotEqual(snap2.threshold, savedThreshold)
        // Restore back to snap1
        try await bcm.importSnapshot(snap1)
        let snap3 = await bcm.exportSnapshot()
        XCTAssertEqual(snap3, snap1)
        XCTAssertEqual(snap3.weights, savedWeights)
        XCTAssertEqual(snap3.threshold, savedThreshold)
        XCTAssertEqual(snap3.updatesProcessed, 1)
        let liveTheta = await bcm.currentThreshold()
        XCTAssertEqual(liveTheta, savedThreshold,
            "live actor θ must match restored snapshot θ")
    }

    func testBCMImportShapeMismatchThrows()
        async throws
    {
        let shape = BASBCMMetaPlasticityShape(
            preDim: 2, postDim: 2)
        let bcm = BASBCMMetaPlasticity(shape: shape)
        let wrongShape = BASBCMMetaPlasticityShape(
            preDim: 3, postDim: 3)
        let badSnap = BASBCMMetaPlasticitySnapshot(
            shape: wrongShape,
            weights: Array(repeating: 0, count: 9),
            threshold: 0.5,
            updatesProcessed: 0)
        do {
            try await bcm.importSnapshot(badSnap)
            XCTFail("expected shapeMismatch throw")
        } catch let err as BASBCMMetaPlasticityError {
            switch err {
            case .shapeMismatch(let reason):
                XCTAssertTrue(
                    reason.contains("snapshot.shape"))
            }
        }
    }

    /// validate-before-mutate:a weight-count mismatch
    /// must throw AND leave the actor's state untouched。
    func testBCMImportWeightCountMismatchThrowsNoMutation()
        async throws
    {
        let shape = BASBCMMetaPlasticityShape(
            preDim: 2, postDim: 2,
            learningRate: 1.0,
            thresholdTimeConstant: 0.5,
            initialThreshold: 0.3)
        let bcm = BASBCMMetaPlasticity(shape: shape)
        _ = try await bcm.apply(
            pre: [1.0, 0.0], post: [1.0, 1.0])
        let before = await bcm.exportSnapshot()
        // Correct shape but wrong weight length (3 not 4)
        let badSnap = BASBCMMetaPlasticitySnapshot(
            shape: shape,
            weights: [0, 0, 0],
            threshold: 99.0,
            updatesProcessed: 42)
        do {
            try await bcm.importSnapshot(badSnap)
            XCTFail("expected shapeMismatch throw")
        } catch let err as BASBCMMetaPlasticityError {
            switch err {
            case .shapeMismatch(let reason):
                XCTAssertTrue(
                    reason.contains("weights"))
            }
        }
        // State must be exactly as before the failed import
        let after = await bcm.exportSnapshot()
        XCTAssertEqual(after, before,
            "failed import must not partially mutate state")
    }

    /// Checkpoint→corrupt→restore→resume trajectory parity
    /// (mirrors the plasticity-fold evolution-parity proof)。
    func testBCMCheckpointRestoreEvolutionParity()
        async throws
    {
        let shape = BASBCMMetaPlasticityShape(
            preDim: 2, postDim: 2,
            learningRate: 0.1,
            thresholdTimeConstant: 0.3,
            initialThreshold: 0.4)
        let bcmA = BASBCMMetaPlasticity(shape: shape)
        _ = try await bcmA.apply(
            pre: [1.0, 0.5], post: [0.2, 0.8])
        let checkpoint = await bcmA.exportSnapshot()
        _ = try await bcmA.apply(
            pre: [0.3, 0.4], post: [0.5, 0.5])
        let evolvedA = await bcmA.exportSnapshot()

        let bcmB = BASBCMMetaPlasticity(shape: shape)
        _ = try await bcmB.apply(
            pre: [1.0, 0.5], post: [0.2, 0.8])
        // Corrupt
        _ = try await bcmB.apply(
            pre: [99.0, -99.0], post: [99.0, -99.0])
        // Restore
        try await bcmB.importSnapshot(checkpoint)
        // Resume evolution from restored state
        _ = try await bcmB.apply(
            pre: [0.3, 0.4], post: [0.5, 0.5])
        let evolvedB = await bcmB.exportSnapshot()

        XCTAssertEqual(
            evolvedA.updatesProcessed,
            evolvedB.updatesProcessed)
        XCTAssertEqual(
            evolvedA.threshold,
            evolvedB.threshold,
            accuracy: 1e-6,
            "θ trajectory diverged after restore")
        for i in 0..<evolvedA.weights.count {
            XCTAssertEqual(
                evolvedA.weights[i],
                evolvedB.weights[i],
                accuracy: 1e-6,
                "weights[\(i)] divergence after restore")
        }
    }
}
