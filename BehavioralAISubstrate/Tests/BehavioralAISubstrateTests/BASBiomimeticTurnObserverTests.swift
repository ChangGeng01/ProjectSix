// MARK: - BASBiomimeticTurnObserverTests
// chapter 四百五十六 / M1202 PROOF tests
//
// Verifies the cross-primitive orchestrator shipped
// in chapter 456:
//   - Population accessors mirror chapter 455 aggregate
//   - observe() dispatches to populated primitives +
//     skips nil ones
//   - Turn counter increments per observe call
//     regardless of populated-primitive count
//   - exportAggregate() builds chapter 455 snapshot
//     covering populated slots + nil for unpopulated
//   - importAggregate() restores populated primitives +
//     silently ignores snapshot slots for unpopulated
//   - reset() cascades to all populated primitives +
//     zeros turn counter
//   - Cross-turn evolution parity:checkpoint via
//     observer → corrupt → restore via observer →
//     subsequent evolution byte-equals reference

import XCTest
@testable import BASMetalSubstrate

final class BASBiomimeticTurnObserverTests: XCTestCase {

    // MARK: - Construction / population accessors

    func testEmptyObserverReportsZeroPopulated() async
    {
        let observer = BASBiomimeticTurnObserver()
        XCTAssertEqual(
            observer.populatedPrimitiveCount, 0)
        XCTAssertNil(observer.mamba)
        XCTAssertNil(observer.predictive)
        XCTAssertNil(observer.plasticity)
        let count = await observer.turnsObservedCount()
        XCTAssertEqual(count, 0)
    }

    func testThreePopulatedObserverReportsCount3() async
    {
        let mamba = BASMambaSSMState(
            shape: BASMambaSSMShape(
                batch: 1, hiddenDim: 1, stateDim: 1))
        let probe = BASPredictiveCodingProbe(
            shape: BASPredictiveCodingProbeShape(
                dim: 1,
                learningRate: 0.1,
                initialPrediction: [0]))
        let fold = BASPlasticityFold(
            shape: BASPlasticityFoldShape(
                preDim: 1, postDim: 1))
        let observer = BASBiomimeticTurnObserver(
            mamba: mamba,
            predictive: probe,
            plasticity: fold)
        XCTAssertEqual(
            observer.populatedPrimitiveCount, 3)
        XCTAssertNotNil(observer.mamba)
        XCTAssertNotNil(observer.predictive)
        XCTAssertNotNil(observer.plasticity)
    }

    // MARK: - Signal population count

    func testSignalPopulationCount() {
        let empty = BASBiomimeticTurnSignal()
        XCTAssertEqual(empty.populatedDriveCount, 0)
        let onlyPredictive = BASBiomimeticTurnSignal(
            predictiveObservation: [1.0])
        XCTAssertEqual(
            onlyPredictive.populatedDriveCount, 1)
        let plasticityOnly = BASBiomimeticTurnSignal(
            plasticityPre: [1.0],
            plasticityPost: [1.0])
        XCTAssertEqual(
            plasticityOnly.populatedDriveCount, 1)
        let plasticityIncomplete =
            BASBiomimeticTurnSignal(
                plasticityPre: [1.0])
        XCTAssertEqual(
            plasticityIncomplete.populatedDriveCount,
            0,
            "plasticity needs BOTH pre and post to" +
            " count as populated drive")
        let all = BASBiomimeticTurnSignal(
            predictiveObservation: [1.0],
            plasticityPre: [1.0],
            plasticityPost: [1.0],
            plasticityOutcome: 1.0,
            mambaInputs: BASMambaSSMScanInputs(
                x: [1.0],
                delta: [0.1],
                a: [-1.0],
                b: [0.2],
                c: [0.3],
                sequenceLength: 1))
        XCTAssertEqual(all.populatedDriveCount, 3)
    }

    // MARK: - observe() dispatches only populated

    func testObserverWithOnlyPredictivePopulated()
        async throws
    {
        let probe = BASPredictiveCodingProbe(
            shape: BASPredictiveCodingProbeShape(
                dim: 2,
                learningRate: 0.5,
                initialPrediction: [0, 0]))
        let observer = BASBiomimeticTurnObserver(
            predictive: probe)
        let signal = BASBiomimeticTurnSignal(
            predictiveObservation: [1.0, 1.0],
            plasticityPre: [1.0, 1.0],  // will be ignored
            plasticityPost: [1.0, 1.0],
            mambaInputs: BASMambaSSMScanInputs(
                x: [1.0],
                delta: [0.1],
                a: [-1.0],
                b: [0.2],
                c: [0.3],
                sequenceLength: 1))  // will be ignored
        let result = try await observer.observe(signal)
        XCTAssertNotNil(result.predictive,
            "predictive primitive must produce result")
        XCTAssertNil(result.plasticity,
            "plasticity nil → no result even though" +
            " signal carried plasticity drive")
        XCTAssertNil(result.mamba,
            "mamba nil → no result")
        XCTAssertEqual(result.producedResultCount, 1)
        XCTAssertEqual(result.turnIndex, 0)
        let observed = await
            probe.observationCount()
        XCTAssertEqual(observed, 1,
            "probe state must reflect the observe call")
    }

    func testObserverWithOnlyPlasticityPopulated()
        async throws
    {
        let fold = BASPlasticityFold(
            shape: BASPlasticityFoldShape(
                preDim: 2,
                postDim: 2,
                learningRate: 1.0,
                rule: .hebbian))
        let observer = BASBiomimeticTurnObserver(
            plasticity: fold)
        let signal = BASBiomimeticTurnSignal(
            predictiveObservation: [1.0, 1.0],  // ignored
            plasticityPre: [1.0, 0.0],
            plasticityPost: [0.5, 0.5])
        let result = try await observer.observe(signal)
        XCTAssertNil(result.predictive)
        XCTAssertNotNil(result.plasticity)
        XCTAssertNil(result.mamba)
        XCTAssertEqual(result.producedResultCount, 1)
        let weights = await fold.currentWeightsSnapshot()
        XCTAssertEqual(weights[0], 0.5)
        XCTAssertEqual(weights[1], 0.5)
    }

    func testObserverWithOnlyMambaPopulated()
        async throws
    {
        let state = BASMambaSSMState(
            shape: BASMambaSSMShape(
                batch: 1, hiddenDim: 1, stateDim: 1))
        let observer = BASBiomimeticTurnObserver(
            mamba: state)
        let signal = BASBiomimeticTurnSignal(
            mambaInputs: BASMambaSSMScanInputs(
                x: [0.5],
                delta: [0.1],
                a: [-1.0],
                b: [0.2],
                c: [0.3],
                sequenceLength: 1))
        let result = try await observer.observe(signal)
        XCTAssertNil(result.predictive)
        XCTAssertNil(result.plasticity)
        XCTAssertNotNil(result.mamba)
        XCTAssertEqual(result.producedResultCount, 1)
        let scanCount = await state.scanCallCount()
        XCTAssertEqual(scanCount, 1)
    }

    func testObserverWithAllThreePopulated() async throws
    {
        let state = BASMambaSSMState(
            shape: BASMambaSSMShape(
                batch: 1, hiddenDim: 1, stateDim: 1))
        let probe = BASPredictiveCodingProbe(
            shape: BASPredictiveCodingProbeShape(
                dim: 1,
                learningRate: 0.5,
                initialPrediction: [0]))
        let fold = BASPlasticityFold(
            shape: BASPlasticityFoldShape(
                preDim: 1, postDim: 1,
                learningRate: 0.5, rule: .hebbian))
        let observer = BASBiomimeticTurnObserver(
            mamba: state,
            predictive: probe,
            plasticity: fold)
        let signal = BASBiomimeticTurnSignal(
            predictiveObservation: [1.0],
            plasticityPre: [1.0],
            plasticityPost: [1.0],
            mambaInputs: BASMambaSSMScanInputs(
                x: [0.5],
                delta: [0.1],
                a: [-1.0],
                b: [0.2],
                c: [0.3],
                sequenceLength: 1))
        let result = try await observer.observe(signal)
        XCTAssertNotNil(result.predictive)
        XCTAssertNotNil(result.plasticity)
        XCTAssertNotNil(result.mamba)
        XCTAssertEqual(result.producedResultCount, 3)
    }

    // MARK: - Turn counter increments

    func testTurnCounterIncrementsPerObserve()
        async throws
    {
        let probe = BASPredictiveCodingProbe(
            shape: BASPredictiveCodingProbeShape(
                dim: 1,
                learningRate: 0.1,
                initialPrediction: [0]))
        let observer = BASBiomimeticTurnObserver(
            predictive: probe)
        let signal = BASBiomimeticTurnSignal(
            predictiveObservation: [1.0])
        for i in 0..<5 {
            let r = try await observer.observe(signal)
            XCTAssertEqual(r.turnIndex, i)
        }
        let count = await observer.turnsObservedCount()
        XCTAssertEqual(count, 5)
    }

    func testTurnCounterIncrementsEvenForNoOpSignals()
        async throws
    {
        // No primitives populated → observe is no-op
        // but turn still counts
        let observer = BASBiomimeticTurnObserver()
        let emptySignal = BASBiomimeticTurnSignal()
        for i in 0..<3 {
            let r = try await observer.observe(
                emptySignal)
            XCTAssertEqual(r.turnIndex, i)
            XCTAssertEqual(r.producedResultCount, 0)
        }
        let count = await observer.turnsObservedCount()
        XCTAssertEqual(count, 3)
    }

    // MARK: - Aggregate snapshot integration

    func testExportAggregateCoversPopulatedSlots()
        async throws
    {
        let probe = BASPredictiveCodingProbe(
            shape: BASPredictiveCodingProbeShape(
                dim: 1,
                learningRate: 0.5,
                initialPrediction: [0]))
        let fold = BASPlasticityFold(
            shape: BASPlasticityFoldShape(
                preDim: 1, postDim: 1))
        let observer = BASBiomimeticTurnObserver(
            predictive: probe,
            plasticity: fold)
        let agg = await observer.exportAggregate()
        XCTAssertNotNil(agg.predictive)
        XCTAssertNotNil(agg.plasticity)
        XCTAssertNil(agg.mamba,
            "non-populated slot must be nil on" +
            " aggregate")
        XCTAssertEqual(agg.populatedPrimitiveCount, 2)
    }

    func testImportAggregateRestoresPopulatedOnly()
        async throws
    {
        let state = BASMambaSSMState(
            shape: BASMambaSSMShape(
                batch: 1, hiddenDim: 1, stateDim: 1))
        let probe = BASPredictiveCodingProbe(
            shape: BASPredictiveCodingProbeShape(
                dim: 1,
                learningRate: 0.5,
                initialPrediction: [0]))
        let observer = BASBiomimeticTurnObserver(
            mamba: state,
            predictive: probe)
        // Build a snapshot carrying ALL 3 primitives'
        // data — observer only has 2 populated。
        // Plasticity slot must be silently ignored。
        let snap = BASBiomimeticStateSnapshot(
            mamba: BASMambaSSMSnapshot(
                shape: BASMambaSSMShape(
                    batch: 1,
                    hiddenDim: 1,
                    stateDim: 1),
                hiddenState: [0.42],
                processedScanCalls: 7),
            predictive: BASPredictiveCodingSnapshot(
                shape: BASPredictiveCodingProbeShape(
                    dim: 1,
                    learningRate: 0.5,
                    initialPrediction: [0]),
                prediction: [0.55],
                observationsProcessed: 3,
                sumSquaredError: 0.1),
            plasticity: BASPlasticitySnapshot(
                shape: BASPlasticityFoldShape(
                    preDim: 1, postDim: 1),
                weights: [0.9],
                updatesProcessed: 12))
        try await observer.importAggregate(snap)
        // Verify each populated primitive got its
        // snapshot
        let mambaCount = await state.scanCallCount()
        XCTAssertEqual(mambaCount, 7)
        let mambaState = await state
            .currentHiddenStateSnapshot()
        XCTAssertEqual(mambaState, [0.42])
        let obsCount = await probe.observationCount()
        XCTAssertEqual(obsCount, 3)
        let prediction = await probe
            .currentPredictionSnapshot()
        XCTAssertEqual(prediction, [0.55])
        // No assertion on plasticity — it wasn't
        // populated;the snapshot slot was silently
        // ignored (per chapter 456 contract)
    }

    func testImportAggregateLeavesUnsuppliedSlotsAlone()
        async throws
    {
        let probe = BASPredictiveCodingProbe(
            shape: BASPredictiveCodingProbeShape(
                dim: 1,
                learningRate: 0.5,
                initialPrediction: [0]))
        let fold = BASPlasticityFold(
            shape: BASPlasticityFoldShape(
                preDim: 1, postDim: 1,
                learningRate: 1.0, rule: .hebbian))
        let observer = BASBiomimeticTurnObserver(
            predictive: probe,
            plasticity: fold)
        // Drive plasticity to a known state
        _ = try await fold.apply(
            pre: [1.0], post: [1.0])
        let foldBefore = await fold
            .currentWeightsSnapshot()
        XCTAssertEqual(foldBefore, [1.0])
        // Snapshot carries ONLY predictive — plasticity
        // slot nil。 importAggregate must leave
        // plasticity state untouched
        let snap = BASBiomimeticStateSnapshot(
            mamba: nil,
            predictive: BASPredictiveCodingSnapshot(
                shape: BASPredictiveCodingProbeShape(
                    dim: 1,
                    learningRate: 0.5,
                    initialPrediction: [0]),
                prediction: [0.9],
                observationsProcessed: 4,
                sumSquaredError: 0.2),
            plasticity: nil)
        try await observer.importAggregate(snap)
        let foldAfter = await fold
            .currentWeightsSnapshot()
        XCTAssertEqual(foldAfter, foldBefore,
            "plasticity state must be untouched when" +
            " snapshot slot is nil")
        let updates = await fold.updateCount()
        XCTAssertEqual(updates, 1,
            "plasticity counter must be untouched")
    }

    // MARK: - reset() cascades

    func testResetCascadesToAllPopulatedPrimitives()
        async throws
    {
        let state = BASMambaSSMState(
            shape: BASMambaSSMShape(
                batch: 1, hiddenDim: 1, stateDim: 1))
        let probe = BASPredictiveCodingProbe(
            shape: BASPredictiveCodingProbeShape(
                dim: 1,
                learningRate: 0.5,
                initialPrediction: [0]))
        let fold = BASPlasticityFold(
            shape: BASPlasticityFoldShape(
                preDim: 1, postDim: 1,
                learningRate: 1.0, rule: .hebbian))
        let observer = BASBiomimeticTurnObserver(
            mamba: state,
            predictive: probe,
            plasticity: fold)
        let signal = BASBiomimeticTurnSignal(
            predictiveObservation: [1.0],
            plasticityPre: [1.0],
            plasticityPost: [1.0],
            mambaInputs: BASMambaSSMScanInputs(
                x: [0.5],
                delta: [0.1],
                a: [-1.0],
                b: [0.2],
                c: [0.3],
                sequenceLength: 1))
        _ = try await observer.observe(signal)
        let countBefore = await observer
            .turnsObservedCount()
        XCTAssertEqual(countBefore, 1)
        await observer.reset()
        let countAfter = await observer
            .turnsObservedCount()
        XCTAssertEqual(countAfter, 0)
        let mambaState = await state
            .currentHiddenStateSnapshot()
        XCTAssertEqual(mambaState, [0])
        let mambaScans = await state.scanCallCount()
        XCTAssertEqual(mambaScans, 0)
        let obsCount = await probe.observationCount()
        XCTAssertEqual(obsCount, 0)
        let foldWeights = await fold
            .currentWeightsSnapshot()
        XCTAssertEqual(foldWeights, [0])
        let foldUpdates = await fold.updateCount()
        XCTAssertEqual(foldUpdates, 0)
    }

    // MARK: - Cross-turn evolution parity via observer

    /// THE KEY BIOMIMETIC TEST at observer level:
    /// checkpoint via observer aggregate → corrupt
    /// state via more observe calls → restore via
    /// importAggregate → subsequent observe-driven
    /// evolution byte-equals a never-corrupted
    /// reference observer's trajectory。
    func testObserverCheckpointRestoreEvolutionParity()
        async throws
    {
        func freshObserver() -> BASBiomimeticTurnObserver
        {
            let probe = BASPredictiveCodingProbe(
                shape: BASPredictiveCodingProbeShape(
                    dim: 2,
                    learningRate: 0.3,
                    initialPrediction: [0, 0]))
            let fold = BASPlasticityFold(
                shape: BASPlasticityFoldShape(
                    preDim: 2,
                    postDim: 2,
                    learningRate: 0.1,
                    rule: .hebbian))
            return BASBiomimeticTurnObserver(
                predictive: probe,
                plasticity: fold)
        }
        let signal1 = BASBiomimeticTurnSignal(
            predictiveObservation: [1.0, 1.0],
            plasticityPre: [1.0, 0.5],
            plasticityPost: [0.2, 0.8])
        let signal2 = BASBiomimeticTurnSignal(
            predictiveObservation: [2.0, 2.0],
            plasticityPre: [0.3, 0.4],
            plasticityPost: [0.5, 0.5])
        // Reference observer:signal1 → signal2
        let refObs = freshObserver()
        _ = try await refObs.observe(signal1)
        let checkpoint = await refObs.exportAggregate()
        _ = try await refObs.observe(signal2)
        let refState = await refObs.exportAggregate()
        // Test observer:signal1 → CORRUPT → restore →
        // signal2
        let testObs = freshObserver()
        _ = try await testObs.observe(signal1)
        // Corrupt:two garbage observes
        let garbage = BASBiomimeticTurnSignal(
            predictiveObservation: [99.0, -99.0],
            plasticityPre: [99.0, -99.0],
            plasticityPost: [99.0, -99.0])
        _ = try await testObs.observe(garbage)
        _ = try await testObs.observe(garbage)
        // Restore from checkpoint
        try await testObs.importAggregate(checkpoint)
        // Resume evolution with signal2
        _ = try await testObs.observe(signal2)
        let testState = await testObs.exportAggregate()
        // Each populated slot must match byte-equal
        // (predictive prediction + sum squared error,
        // plasticity weights)
        XCTAssertNotNil(refState.predictive)
        XCTAssertNotNil(testState.predictive)
        for i in 0..<refState
            .predictive!.prediction.count
        {
            XCTAssertEqual(
                refState.predictive!.prediction[i],
                testState.predictive!.prediction[i],
                accuracy: 1e-6,
                "predictive[\(i)] divergence after" +
                " observer-level restore")
        }
        XCTAssertEqual(
            refState.predictive!.observationsProcessed,
            testState.predictive!.observationsProcessed)
        XCTAssertEqual(
            refState.predictive!.sumSquaredError,
            testState.predictive!.sumSquaredError,
            accuracy: 1e-6)
        XCTAssertNotNil(refState.plasticity)
        XCTAssertNotNil(testState.plasticity)
        for i in 0..<refState.plasticity!.weights.count
        {
            XCTAssertEqual(
                refState.plasticity!.weights[i],
                testState.plasticity!.weights[i],
                accuracy: 1e-6,
                "plasticity weights[\(i)] divergence" +
                " after observer-level restore")
        }
        XCTAssertEqual(
            refState.plasticity!.updatesProcessed,
            testState.plasticity!.updatesProcessed)
    }

    // MARK: - Snapshot/import error surfacing

    func testImportAggregateShapeMismatchThrows()
        async throws
    {
        let probe = BASPredictiveCodingProbe(
            shape: BASPredictiveCodingProbeShape(
                dim: 2,
                learningRate: 0.1,
                initialPrediction: [0, 0]))
        let observer = BASBiomimeticTurnObserver(
            predictive: probe)
        // Snapshot with wrong-dim shape
        let bad = BASBiomimeticStateSnapshot(
            mamba: nil,
            predictive: BASPredictiveCodingSnapshot(
                shape: BASPredictiveCodingProbeShape(
                    dim: 3,
                    learningRate: 0.1,
                    initialPrediction: [0, 0, 0]),
                prediction: [0, 0, 0],
                observationsProcessed: 0,
                sumSquaredError: 0),
            plasticity: nil)
        do {
            try await observer.importAggregate(bad)
            XCTFail("expected shapeMismatch throw")
        } catch let err as BASBiomimeticSnapshotError {
            switch err {
            case .shapeMismatch(let reason):
                XCTAssertTrue(
                    reason.contains("snapshot.shape"))
            }
        }
    }
}
