// MARK: - BASBiomimeticStateSnapshotTests
// chapter 四百五十五 / M1198 PROOF tests
//
// Verifies the cross-turn state persistence
// primitives shipped in chapter 455:
//   - Per-primitive snapshot Codable round-trip
//   - exportSnapshot() returns current actor state
//   - importSnapshot(_:) restores exact prior state
//   - Shape mismatch on import throws typed error
//   - Aggregate BASBiomimeticStateSnapshot round-trip
//   - End-to-end checkpoint → mutate → restore proves
//     subsequent state evolution from restored point
//     matches state evolution had we never mutated

import XCTest
@testable import BASMetalSubstrate

final class BASBiomimeticStateSnapshotTests: XCTestCase {

    // MARK: - BASMambaSSMSnapshot Codable round-trip

    func testMambaSnapshotCodableRoundTrip() throws {
        let shape = BASMambaSSMShape(
            batch: 1, hiddenDim: 2, stateDim: 3)
        let snap = BASMambaSSMSnapshot(
            shape: shape,
            hiddenState: [0.1, 0.2, 0.3, 0.4, 0.5, 0.6],
            processedScanCalls: 7)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(snap)
        let decoded = try JSONDecoder()
            .decode(BASMambaSSMSnapshot.self, from: data)
        XCTAssertEqual(decoded, snap)
        XCTAssertEqual(decoded.shape, shape)
        XCTAssertEqual(
            decoded.hiddenState,
            [0.1, 0.2, 0.3, 0.4, 0.5, 0.6])
        XCTAssertEqual(decoded.processedScanCalls, 7)
    }

    func testPredictiveCodingSnapshotCodableRoundTrip()
        throws
    {
        let shape = BASPredictiveCodingProbeShape(
            dim: 3,
            learningRate: 0.2,
            initialPrediction: [0.0, 0.0, 0.0])
        let snap = BASPredictiveCodingSnapshot(
            shape: shape,
            prediction: [0.5, 0.6, 0.7],
            observationsProcessed: 4,
            sumSquaredError: 1.25)
        let data = try JSONEncoder().encode(snap)
        let decoded = try JSONDecoder()
            .decode(
                BASPredictiveCodingSnapshot.self,
                from: data)
        XCTAssertEqual(decoded, snap)
        XCTAssertEqual(decoded.shape.dim, 3)
        XCTAssertEqual(decoded.shape.learningRate, 0.2)
        XCTAssertEqual(decoded.prediction.count, 3)
        XCTAssertEqual(decoded.observationsProcessed, 4)
        XCTAssertEqual(decoded.sumSquaredError, 1.25)
    }

    func testPlasticitySnapshotCodableRoundTrip()
        throws
    {
        let shape = BASPlasticityFoldShape(
            preDim: 2,
            postDim: 3,
            learningRate: 0.05,
            rule: .outcomeModulatedHebbian)
        let snap = BASPlasticitySnapshot(
            shape: shape,
            weights: [
                0.1, 0.2, 0.3,
                0.4, 0.5, 0.6,
            ],
            updatesProcessed: 9)
        let data = try JSONEncoder().encode(snap)
        let decoded = try JSONDecoder()
            .decode(
                BASPlasticitySnapshot.self,
                from: data)
        XCTAssertEqual(decoded, snap)
        XCTAssertEqual(decoded.shape.preDim, 2)
        XCTAssertEqual(decoded.shape.postDim, 3)
        XCTAssertEqual(decoded.shape.learningRate, 0.05)
        XCTAssertEqual(
            decoded.shape.rule,
            .outcomeModulatedHebbian)
        XCTAssertEqual(decoded.weights.count, 6)
        XCTAssertEqual(decoded.updatesProcessed, 9)
    }

    func testBiomimeticAggregateSnapshotCodableRoundTrip()
        throws
    {
        let mambaShape = BASMambaSSMShape(
            batch: 1, hiddenDim: 1, stateDim: 2)
        let mamba = BASMambaSSMSnapshot(
            shape: mambaShape,
            hiddenState: [0.1, 0.2],
            processedScanCalls: 1)
        let probeShape = BASPredictiveCodingProbeShape(
            dim: 2,
            learningRate: 0.1,
            initialPrediction: [0.0, 0.0])
        let probe = BASPredictiveCodingSnapshot(
            shape: probeShape,
            prediction: [0.3, 0.4],
            observationsProcessed: 2,
            sumSquaredError: 0.05)
        let foldShape = BASPlasticityFoldShape(
            preDim: 2,
            postDim: 2,
            learningRate: 0.01,
            rule: .hebbian)
        let fold = BASPlasticitySnapshot(
            shape: foldShape,
            weights: [0.0, 0.1, 0.2, 0.3],
            updatesProcessed: 3)
        let aggregate = BASBiomimeticStateSnapshot(
            mamba: mamba,
            predictive: probe,
            plasticity: fold,
            snapshotVersion: "biomimetic-snapshot-v1",
            timestampMs: 1_700_000_000_000)
        let data = try JSONEncoder().encode(aggregate)
        let decoded = try JSONDecoder()
            .decode(
                BASBiomimeticStateSnapshot.self,
                from: data)
        XCTAssertEqual(decoded, aggregate)
        XCTAssertEqual(decoded.populatedPrimitiveCount, 3)
        XCTAssertEqual(
            decoded.snapshotVersion,
            "biomimetic-snapshot-v1")
        XCTAssertEqual(
            decoded.timestampMs, 1_700_000_000_000)
    }

    func testAggregateSnapshotWithSomePrimitivesNil()
        throws
    {
        let probeShape = BASPredictiveCodingProbeShape(
            dim: 1,
            learningRate: 0.1,
            initialPrediction: [0.0])
        let aggregate = BASBiomimeticStateSnapshot(
            mamba: nil,
            predictive: BASPredictiveCodingSnapshot(
                shape: probeShape,
                prediction: [0.5],
                observationsProcessed: 1,
                sumSquaredError: 0.01),
            plasticity: nil,
            snapshotVersion: "biomimetic-snapshot-v1",
            timestampMs: 0)
        XCTAssertEqual(aggregate.populatedPrimitiveCount, 1)
        XCTAssertNil(aggregate.mamba)
        XCTAssertNotNil(aggregate.predictive)
        XCTAssertNil(aggregate.plasticity)
        let data = try JSONEncoder().encode(aggregate)
        let decoded = try JSONDecoder()
            .decode(
                BASBiomimeticStateSnapshot.self,
                from: data)
        XCTAssertEqual(decoded, aggregate)
    }

    // MARK: - BASMambaSSMState export/import

    func testMambaExportReturnsCurrentState() async throws {
        let shape = BASMambaSSMShape(
            batch: 1, hiddenDim: 2, stateDim: 2)
        let actor = BASMambaSSMState(shape: shape)
        let snap0 = await actor.exportSnapshot()
        XCTAssertEqual(snap0.shape, shape)
        XCTAssertEqual(snap0.hiddenState.count, 4)
        XCTAssertEqual(snap0.processedScanCalls, 0)
        // All zeros at init
        XCTAssertEqual(snap0.hiddenState, [0, 0, 0, 0])
    }

    func testMambaImportRestoresPriorState() async throws {
        let shape = BASMambaSSMShape(
            batch: 1, hiddenDim: 1, stateDim: 1)
        let actor = BASMambaSSMState(shape: shape)
        // Drive the scan to evolve hidden state
        let inputs = BASMambaSSMScanInputs(
            x: [0.5, 0.6],
            delta: [0.1, 0.1],
            a: [-1.0],
            b: [0.2, 0.2],
            c: [0.3, 0.3],
            sequenceLength: 2)
        _ = try await actor.selectiveScan(inputs: inputs)
        let snap1 = await actor.exportSnapshot()
        XCTAssertEqual(snap1.processedScanCalls, 1)
        XCTAssertNotEqual(snap1.hiddenState, [0])
        let evolvedHidden = snap1.hiddenState
        // Mutate further (drift the state)
        _ = try await actor.selectiveScan(inputs: inputs)
        let snap2 = await actor.exportSnapshot()
        XCTAssertEqual(snap2.processedScanCalls, 2)
        XCTAssertNotEqual(
            snap2.hiddenState, evolvedHidden)
        // Restore back to snap1
        try await actor.importSnapshot(snap1)
        let snap3 = await actor.exportSnapshot()
        XCTAssertEqual(snap3, snap1)
        XCTAssertEqual(
            snap3.hiddenState, evolvedHidden)
        XCTAssertEqual(snap3.processedScanCalls, 1)
    }

    func testMambaImportShapeMismatchThrows()
        async throws
    {
        let shape = BASMambaSSMShape(
            batch: 1, hiddenDim: 2, stateDim: 2)
        let actor = BASMambaSSMState(shape: shape)
        let wrongShape = BASMambaSSMShape(
            batch: 2, hiddenDim: 2, stateDim: 2)
        let badSnap = BASMambaSSMSnapshot(
            shape: wrongShape,
            hiddenState: Array(
                repeating: 0, count: 8),
            processedScanCalls: 0)
        do {
            try await actor.importSnapshot(badSnap)
            XCTFail("expected shapeMismatch throw")
        } catch let err as BASBiomimeticSnapshotError {
            switch err {
            case .shapeMismatch(let reason):
                XCTAssertTrue(
                    reason.contains("snapshot.shape"))
            }
        }
    }

    func testMambaImportFlatLengthMismatchThrows()
        async throws
    {
        let shape = BASMambaSSMShape(
            batch: 1, hiddenDim: 2, stateDim: 2)
        let actor = BASMambaSSMState(shape: shape)
        // Correct shape but wrong hidden state length
        let badSnap = BASMambaSSMSnapshot(
            shape: shape,
            hiddenState: [0.1, 0.2, 0.3],  // 3 not 4
            processedScanCalls: 0)
        do {
            try await actor.importSnapshot(badSnap)
            XCTFail("expected shapeMismatch throw")
        } catch let err as BASBiomimeticSnapshotError {
            switch err {
            case .shapeMismatch(let reason):
                XCTAssertTrue(
                    reason.contains("hiddenState"))
            }
        }
    }

    // MARK: - BASPredictiveCodingProbe export/import

    func testPredictiveCodingExportReturnsCurrentState()
        async throws
    {
        let shape = BASPredictiveCodingProbeShape(
            dim: 2,
            learningRate: 0.5,
            initialPrediction: [0.0, 0.0])
        let probe = BASPredictiveCodingProbe(
            shape: shape)
        let snap0 = await probe.exportSnapshot()
        XCTAssertEqual(snap0.shape, shape)
        XCTAssertEqual(snap0.prediction, [0.0, 0.0])
        XCTAssertEqual(snap0.observationsProcessed, 0)
        XCTAssertEqual(snap0.sumSquaredError, 0)
    }

    func testPredictiveCodingImportRestoresState()
        async throws
    {
        let shape = BASPredictiveCodingProbeShape(
            dim: 2,
            learningRate: 0.5,
            initialPrediction: [0.0, 0.0])
        let probe = BASPredictiveCodingProbe(
            shape: shape)
        _ = try await probe.observe([1.0, 2.0])
        let snap1 = await probe.exportSnapshot()
        XCTAssertEqual(snap1.observationsProcessed, 1)
        XCTAssertEqual(
            snap1.prediction, [0.5, 1.0])
        XCTAssertGreaterThan(
            snap1.sumSquaredError, 0)
        let originalSSE = snap1.sumSquaredError
        // Mutate state further
        _ = try await probe.observe([5.0, 5.0])
        let snap2 = await probe.exportSnapshot()
        XCTAssertEqual(snap2.observationsProcessed, 2)
        XCTAssertNotEqual(snap2.prediction, snap1.prediction)
        // Restore back to snap1
        try await probe.importSnapshot(snap1)
        let snap3 = await probe.exportSnapshot()
        XCTAssertEqual(snap3, snap1)
        XCTAssertEqual(snap3.observationsProcessed, 1)
        XCTAssertEqual(snap3.prediction, [0.5, 1.0])
        XCTAssertEqual(snap3.sumSquaredError, originalSSE)
    }

    func testPredictiveCodingImportShapeMismatchThrows()
        async throws
    {
        let shape = BASPredictiveCodingProbeShape(
            dim: 2,
            learningRate: 0.1,
            initialPrediction: [0.0, 0.0])
        let probe = BASPredictiveCodingProbe(
            shape: shape)
        let wrongShape = BASPredictiveCodingProbeShape(
            dim: 3,
            learningRate: 0.1,
            initialPrediction: [0.0, 0.0, 0.0])
        let badSnap = BASPredictiveCodingSnapshot(
            shape: wrongShape,
            prediction: [0.0, 0.0, 0.0],
            observationsProcessed: 0,
            sumSquaredError: 0)
        do {
            try await probe.importSnapshot(badSnap)
            XCTFail("expected shapeMismatch throw")
        } catch let err as BASBiomimeticSnapshotError {
            switch err {
            case .shapeMismatch(let reason):
                XCTAssertTrue(
                    reason.contains("snapshot.shape"))
            }
        }
    }

    // MARK: - BASPlasticityFold export/import

    func testPlasticityExportReturnsCurrentState()
        async throws
    {
        let shape = BASPlasticityFoldShape(
            preDim: 2,
            postDim: 2,
            learningRate: 1.0,
            rule: .hebbian)
        let fold = BASPlasticityFold(shape: shape)
        let snap0 = await fold.exportSnapshot()
        XCTAssertEqual(snap0.shape, shape)
        XCTAssertEqual(snap0.weights.count, 4)
        XCTAssertEqual(snap0.weights, [0, 0, 0, 0])
        XCTAssertEqual(snap0.updatesProcessed, 0)
    }

    func testPlasticityImportRestoresState() async throws {
        let shape = BASPlasticityFoldShape(
            preDim: 2,
            postDim: 2,
            learningRate: 1.0,
            rule: .hebbian)
        let fold = BASPlasticityFold(shape: shape)
        _ = try await fold.apply(
            pre: [1.0, 0.0],
            post: [0.5, 0.5])
        let snap1 = await fold.exportSnapshot()
        XCTAssertEqual(snap1.updatesProcessed, 1)
        XCTAssertEqual(snap1.weights[0], 0.5)
        XCTAssertEqual(snap1.weights[1], 0.5)
        XCTAssertEqual(snap1.weights[2], 0)
        XCTAssertEqual(snap1.weights[3], 0)
        let savedWeights = snap1.weights
        // Mutate further
        _ = try await fold.apply(
            pre: [0.0, 1.0],
            post: [1.0, 1.0])
        let snap2 = await fold.exportSnapshot()
        XCTAssertEqual(snap2.updatesProcessed, 2)
        XCTAssertNotEqual(snap2.weights, savedWeights)
        // Restore
        try await fold.importSnapshot(snap1)
        let snap3 = await fold.exportSnapshot()
        XCTAssertEqual(snap3, snap1)
        XCTAssertEqual(snap3.weights, savedWeights)
        XCTAssertEqual(snap3.updatesProcessed, 1)
    }

    func testPlasticityImportShapeMismatchThrows()
        async throws
    {
        let shape = BASPlasticityFoldShape(
            preDim: 2, postDim: 2,
            learningRate: 0.1, rule: .hebbian)
        let fold = BASPlasticityFold(shape: shape)
        let wrongShape = BASPlasticityFoldShape(
            preDim: 3, postDim: 3,
            learningRate: 0.1, rule: .hebbian)
        let badSnap = BASPlasticitySnapshot(
            shape: wrongShape,
            weights: Array(repeating: 0, count: 9),
            updatesProcessed: 0)
        do {
            try await fold.importSnapshot(badSnap)
            XCTFail("expected shapeMismatch throw")
        } catch let err as BASBiomimeticSnapshotError {
            switch err {
            case .shapeMismatch(let reason):
                XCTAssertTrue(
                    reason.contains("snapshot.shape"))
            }
        }
    }

    func testPlasticityImportWeightCountMismatchThrows()
        async throws
    {
        let shape = BASPlasticityFoldShape(
            preDim: 2, postDim: 2,
            learningRate: 0.1, rule: .hebbian)
        let fold = BASPlasticityFold(shape: shape)
        let badSnap = BASPlasticitySnapshot(
            shape: shape,
            weights: [0, 0, 0],  // 3 not 4
            updatesProcessed: 0)
        do {
            try await fold.importSnapshot(badSnap)
            XCTFail("expected shapeMismatch throw")
        } catch let err as BASBiomimeticSnapshotError {
            switch err {
            case .shapeMismatch(let reason):
                XCTAssertTrue(
                    reason.contains("weights"))
            }
        }
    }

    // MARK: - End-to-end checkpoint → mutate → restore

    /// THE KEY BIOMIMETIC TEST:after checkpoint +
    /// mutation + restore,subsequent state evolution
    /// from the restored point must match state
    /// evolution that would have occurred had we never
    /// mutated between checkpoint and restore。 This
    /// proves the snapshot truly preserves the
    /// biomimetic state's evolution trajectory。
    func testMambaCheckpointRestoreEvolutionParity()
        async throws
    {
        let shape = BASMambaSSMShape(
            batch: 1, hiddenDim: 2, stateDim: 2)
        // Actor A:scan once,checkpoint,scan twice more
        let actorA = BASMambaSSMState(shape: shape)
        let inputs1 = BASMambaSSMScanInputs(
            x: [0.5, 0.3],
            delta: [0.1, 0.1],
            a: [-1.0, -0.5, -0.5, -1.0],
            b: [0.2, 0.4],
            c: [0.6, 0.7],
            sequenceLength: 1)
        let inputs2 = BASMambaSSMScanInputs(
            x: [0.1, 0.2],
            delta: [0.05, 0.05],
            a: [-1.0, -0.5, -0.5, -1.0],
            b: [0.3, 0.3],
            c: [0.5, 0.5],
            sequenceLength: 1)
        _ = try await actorA.selectiveScan(
            inputs: inputs1)
        let checkpoint = await actorA.exportSnapshot()
        _ = try await actorA.selectiveScan(
            inputs: inputs2)
        let evolvedA = await actorA.exportSnapshot()
        // Actor B:start fresh,scan inputs1,then
        // CORRUPT state with random stuff,then RESTORE
        // from checkpoint,then scan inputs2
        let actorB = BASMambaSSMState(shape: shape)
        _ = try await actorB.selectiveScan(
            inputs: inputs1)
        // Corrupt:run more scans to drift state
        let corruptInputs = BASMambaSSMScanInputs(
            x: [99.0, -99.0],
            delta: [10.0, 10.0],
            a: [1.0, 1.0, 1.0, 1.0],
            b: [99.0, -99.0],
            c: [99.0, -99.0],
            sequenceLength: 1)
        _ = try await actorB.selectiveScan(
            inputs: corruptInputs)
        _ = try await actorB.selectiveScan(
            inputs: corruptInputs)
        // Now restore to checkpoint
        try await actorB.importSnapshot(checkpoint)
        // Re-run inputs2 from restored state
        _ = try await actorB.selectiveScan(
            inputs: inputs2)
        let evolvedB = await actorB.exportSnapshot()
        // The two evolved states MUST be identical
        XCTAssertEqual(
            evolvedA.processedScanCalls,
            evolvedB.processedScanCalls)
        XCTAssertEqual(
            evolvedA.hiddenState.count,
            evolvedB.hiddenState.count)
        for i in 0..<evolvedA.hiddenState.count {
            XCTAssertEqual(
                evolvedA.hiddenState[i],
                evolvedB.hiddenState[i],
                accuracy: 1e-6,
                "hidden[\(i)] divergence after restore")
        }
    }

    func testPlasticityCheckpointRestoreEvolutionParity()
        async throws
    {
        let shape = BASPlasticityFoldShape(
            preDim: 2, postDim: 2,
            learningRate: 0.1, rule: .hebbian)
        let foldA = BASPlasticityFold(shape: shape)
        _ = try await foldA.apply(
            pre: [1.0, 0.5], post: [0.2, 0.8])
        let checkpoint = await foldA.exportSnapshot()
        _ = try await foldA.apply(
            pre: [0.3, 0.4], post: [0.5, 0.5])
        let evolvedA = await foldA.exportSnapshot()

        let foldB = BASPlasticityFold(shape: shape)
        _ = try await foldB.apply(
            pre: [1.0, 0.5], post: [0.2, 0.8])
        // Corrupt
        _ = try await foldB.apply(
            pre: [99.0, -99.0], post: [99.0, -99.0])
        // Restore
        try await foldB.importSnapshot(checkpoint)
        // Resume evolution
        _ = try await foldB.apply(
            pre: [0.3, 0.4], post: [0.5, 0.5])
        let evolvedB = await foldB.exportSnapshot()

        XCTAssertEqual(
            evolvedA.updatesProcessed,
            evolvedB.updatesProcessed)
        for i in 0..<evolvedA.weights.count {
            XCTAssertEqual(
                evolvedA.weights[i],
                evolvedB.weights[i],
                accuracy: 1e-6,
                "weights[\(i)] divergence after restore")
        }
    }

    func testPredictiveCodingCheckpointRestoreEvolutionParity()
        async throws
    {
        let shape = BASPredictiveCodingProbeShape(
            dim: 2,
            learningRate: 0.3,
            initialPrediction: [0.0, 0.0])
        let probeA = BASPredictiveCodingProbe(
            shape: shape)
        _ = try await probeA.observe([1.0, 1.0])
        let checkpoint = await probeA.exportSnapshot()
        _ = try await probeA.observe([2.0, 2.0])
        let evolvedA = await probeA.exportSnapshot()

        let probeB = BASPredictiveCodingProbe(
            shape: shape)
        _ = try await probeB.observe([1.0, 1.0])
        // Corrupt
        _ = try await probeB.observe([100.0, -100.0])
        _ = try await probeB.observe([-100.0, 100.0])
        // Restore
        try await probeB.importSnapshot(checkpoint)
        _ = try await probeB.observe([2.0, 2.0])
        let evolvedB = await probeB.exportSnapshot()

        XCTAssertEqual(
            evolvedA.observationsProcessed,
            evolvedB.observationsProcessed)
        for i in 0..<evolvedA.prediction.count {
            XCTAssertEqual(
                evolvedA.prediction[i],
                evolvedB.prediction[i],
                accuracy: 1e-6,
                "prediction[\(i)] divergence")
        }
        XCTAssertEqual(
            evolvedA.sumSquaredError,
            evolvedB.sumSquaredError,
            accuracy: 1e-6)
    }

    // MARK: - Aggregate end-to-end

    func testAggregateSnapshotCheckpointsAll3() async throws
    {
        let mambaShape = BASMambaSSMShape(
            batch: 1, hiddenDim: 1, stateDim: 1)
        let probeShape = BASPredictiveCodingProbeShape(
            dim: 1,
            learningRate: 0.1,
            initialPrediction: [0.0])
        let foldShape = BASPlasticityFoldShape(
            preDim: 1, postDim: 1,
            learningRate: 0.1, rule: .hebbian)
        let mamba = BASMambaSSMState(shape: mambaShape)
        let probe = BASPredictiveCodingProbe(
            shape: probeShape)
        let fold = BASPlasticityFold(shape: foldShape)
        _ = try await mamba.selectiveScan(
            inputs: BASMambaSSMScanInputs(
                x: [0.5], delta: [0.1], a: [-1.0],
                b: [0.2], c: [0.3], sequenceLength: 1))
        _ = try await probe.observe([1.0])
        _ = try await fold.apply(
            pre: [1.0], post: [1.0])
        // Build aggregate
        let aggregate = BASBiomimeticStateSnapshot(
            mamba: await mamba.exportSnapshot(),
            predictive: await probe.exportSnapshot(),
            plasticity: await fold.exportSnapshot())
        XCTAssertEqual(aggregate.populatedPrimitiveCount, 3)
        // Codable round-trip
        let data = try JSONEncoder().encode(aggregate)
        let decoded = try JSONDecoder()
            .decode(
                BASBiomimeticStateSnapshot.self,
                from: data)
        XCTAssertEqual(decoded, aggregate)
        // Restore everything onto fresh actors
        let mambaB = BASMambaSSMState(shape: mambaShape)
        let probeB = BASPredictiveCodingProbe(
            shape: probeShape)
        let foldB = BASPlasticityFold(shape: foldShape)
        try await mambaB.importSnapshot(decoded.mamba!)
        try await probeB.importSnapshot(
            decoded.predictive!)
        try await foldB.importSnapshot(
            decoded.plasticity!)
        let mambaSnapA = await mamba.exportSnapshot()
        let mambaSnapB = await mambaB.exportSnapshot()
        XCTAssertEqual(mambaSnapA, mambaSnapB)
        let probeSnapA = await probe.exportSnapshot()
        let probeSnapB = await probeB.exportSnapshot()
        XCTAssertEqual(probeSnapA, probeSnapB)
        let foldSnapA = await fold.exportSnapshot()
        let foldSnapB = await foldB.exportSnapshot()
        XCTAssertEqual(foldSnapA, foldSnapB)
    }
}
