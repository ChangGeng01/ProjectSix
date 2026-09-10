// MARK: - BASChapter473CleanupTests
// chapter 四百七十三 / fix-batch — closes 5 gaps
// surfaced by chapter 466 self-audit。
//
// This file batches the test additions for fixes
// #2 (e2e hierarchical),#3 (chapter 472 backward-
// compat decoder),#6b (BCM observer integration),
// and #7 (production-scale Mamba benchmark)。
//
// Fix #1 lives in BASRegistryFrozenHashTests;
// Fix #4 (commit scripts) + #5 (audit) need no test;
// Fix #6 (BCM wired into observer) has the wire-up
// in BASBiomimeticTurnObserver.swift + tests below;
// Fix #8 (prose) is in BASChapterDoctrineRegistry。

import XCTest
@testable import BASHostKit
@testable import BASMetalSubstrate
@testable import BASRuntimeCore

final class BASChapter473CleanupTests: XCTestCase {

    // MARK: - Fix #6b: 5-slot observer + BCM dispatch

    func testObserverWith5PopulatedSlotsReports5()
        async throws
    {
        let mamba = BASMambaSSMState(
            shape: BASMambaSSMShape(
                batch: 1, hiddenDim: 1, stateDim: 1))
        let probe = BASPredictiveCodingProbe(
            shape: BASPredictiveCodingProbeShape(
                dim: 1, learningRate: 0.1,
                initialPrediction: [0]))
        let fold = BASPlasticityFold(
            shape: BASPlasticityFoldShape(
                preDim: 1, postDim: 1))
        let hier = BASHierarchicalPredictiveCoding(
            shape: try
                BASHierarchicalPredictiveCodingShape(
                    layers: [
                        BASPredictiveCodingProbeShape(
                            dim: 1,
                            learningRate: 0.1,
                            initialPrediction: [0])
                    ]))
        let bcm = BASBCMMetaPlasticity(
            shape: BASBCMMetaPlasticityShape(
                preDim: 1, postDim: 1))
        let observer = BASBiomimeticTurnObserver(
            mamba: mamba,
            predictive: probe,
            plasticity: fold,
            hierarchical: hier,
            bcm: bcm)
        XCTAssertEqual(
            observer.populatedPrimitiveCount, 5,
            "chapter 473 fix #6 extends to 5 slots")
        XCTAssertNotNil(observer.bcm)
    }

    func testBCMDispatchProducesResult() async throws {
        let bcm = BASBCMMetaPlasticity(
            shape: BASBCMMetaPlasticityShape(
                preDim: 2, postDim: 2,
                learningRate: 0.5,
                thresholdTimeConstant: 0.0,
                initialThreshold: 0.3))
        let observer = BASBiomimeticTurnObserver(
            bcm: bcm)
        let signal = BASBiomimeticTurnSignal(
            bcmPre: [1.0, 1.0],
            bcmPost: [0.8, 0.2])
        let result = try await observer.observe(signal)
        XCTAssertNotNil(result.bcm,
            "BCM slot must produce result when signal" +
            " carries pre+post")
        XCTAssertEqual(result.producedResultCount, 1)
    }

    func testBCMSlotSkippedWhenIncompleteSignal()
        async throws
    {
        let bcm = BASBCMMetaPlasticity(
            shape: BASBCMMetaPlasticityShape(
                preDim: 1, postDim: 1))
        let observer = BASBiomimeticTurnObserver(
            bcm: bcm)
        // Signal carries pre but NO post → BCM should
        // be skipped
        let signal = BASBiomimeticTurnSignal(
            bcmPre: [1.0])
        let result = try await observer.observe(signal)
        XCTAssertNil(result.bcm,
            "incomplete BCM drive → no dispatch")
    }

    func testResetCascadesToBCM() async throws {
        let bcm = BASBCMMetaPlasticity(
            shape: BASBCMMetaPlasticityShape(
                preDim: 1, postDim: 1,
                learningRate: 1.0,
                thresholdTimeConstant: 0.5,
                initialThreshold: 0.0))
        let observer = BASBiomimeticTurnObserver(
            bcm: bcm)
        _ = try await observer.observe(
            BASBiomimeticTurnSignal(
                bcmPre: [1.0], bcmPost: [1.0]))
        let countBefore = await bcm.updateCount()
        XCTAssertEqual(countBefore, 1)
        let thetaBefore = await bcm.currentThreshold()
        XCTAssertGreaterThan(thetaBefore, 0,
            "BCM threshold should have risen from 0")
        await observer.reset()
        let countAfter = await bcm.updateCount()
        XCTAssertEqual(countAfter, 0,
            "reset must cascade to BCM primitive")
        let thetaAfter = await bcm.currentThreshold()
        XCTAssertEqual(thetaAfter, 0,
            "BCM threshold must restore to initial 0")
    }

    func testSignalPopulatedDriveCountTracksBCM() {
        let s = BASBiomimeticTurnSignal(
            bcmPre: [1.0], bcmPost: [1.0])
        XCTAssertEqual(s.populatedDriveCount, 1,
            "BCM pre+post pair must count as one drive")
    }

    // MARK: - Fix #2: E2E hierarchical through engine

    func testEndToEndHierarchicalThroughEngine()
        async throws
    {
        let hier = BASHierarchicalPredictiveCoding(
            shape: try
                BASHierarchicalPredictiveCodingShape(
                    layers: [
                        BASPredictiveCodingProbeShape(
                            dim: 1,
                            learningRate: 1.0,
                            initialPrediction: [0])
                    ]))
        let observer = BASBiomimeticTurnObserver(
            hierarchical: hier)
        let config = BASTurnRuntimeEngineConfiguration
            .default()
            .with(biomimeticTurnObserver: observer)
            .with(biomimeticTurnSignalBuilder: {
                _ in
                BASBiomimeticTurnSignal(
                    hierarchicalObservation: [0.7])
            } as @Sendable (BASEBrainTurnResult)
                -> BASBiomimeticTurnSignal)
        let engine = BASTurnRuntimeEngine(
            coordinator: BASCoordinatorTestStubs
                .makeStub(),
            configuration: config)
        let countBefore = await hier
            .observationCount()
        XCTAssertEqual(countBefore, 0)
        _ = await engine.runWithPlan(
            BASCoordinatorTestStubs.makeStubRequest())
        let countAfter = await hier
            .observationCount()
        XCTAssertEqual(countAfter, 1,
            "hierarchical must fire through real" +
            " engine.runWithPlan hook")
    }

    // MARK: - Fix #2b: E2E BCM through engine

    func testEndToEndBCMThroughEngine() async throws {
        let bcm = BASBCMMetaPlasticity(
            shape: BASBCMMetaPlasticityShape(
                preDim: 1, postDim: 1,
                learningRate: 0.5))
        let observer = BASBiomimeticTurnObserver(
            bcm: bcm)
        let config = BASTurnRuntimeEngineConfiguration
            .default()
            .with(biomimeticTurnObserver: observer)
            .with(biomimeticTurnSignalBuilder: {
                _ in
                BASBiomimeticTurnSignal(
                    bcmPre: [1.0],
                    bcmPost: [1.0])
            } as @Sendable (BASEBrainTurnResult)
                -> BASBiomimeticTurnSignal)
        let engine = BASTurnRuntimeEngine(
            coordinator: BASCoordinatorTestStubs
                .makeStub(),
            configuration: config)
        _ = await engine.runWithPlan(
            BASCoordinatorTestStubs.makeStubRequest())
        _ = await engine.runWithPlan(
            BASCoordinatorTestStubs.makeStubRequest())
        let count = await bcm.updateCount()
        XCTAssertEqual(count, 2,
            "BCM must fire twice through real engine" +
            " hook (2 runWithPlan calls)")
    }

    // MARK: - Fix #3: chapter 472 backward-compat decoder

    func testBundleDecodesLegacyJSONWithoutCheckpointKey()
        throws
    {
        // Simulate pre-chapter-472 JSON encoding:no
        // `biomimeticCheckpointEvents` key
        let legacyJSON = """
        {
            "memoryAtomEvents": [],
            "turnLifecycleEvents": [],
            "parallelStageEvents": [],
            "permitEscalationEvents": [],
            "nativeStageDispatchEvents": [],
            "planAssignmentEvents": [],
            "nativeStagePerStepEvents": []
        }
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(
            BASEventLogReplayBundle.self,
            from: legacyJSON)
        XCTAssertEqual(
            decoded.biomimeticCheckpointEvents.count, 0,
            "legacy JSON without checkpoint key must" +
            " decode with empty array (chapter 472" +
            " backward-compat)")
        XCTAssertEqual(decoded.totalEventCount, 0)
    }

    func testBundleDecodesAlsoMissingPerStepKey() throws {
        // Even older JSON missing BOTH new keys
        let veryLegacyJSON = """
        {
            "memoryAtomEvents": [],
            "turnLifecycleEvents": [],
            "parallelStageEvents": [],
            "permitEscalationEvents": [],
            "nativeStageDispatchEvents": [],
            "planAssignmentEvents": []
        }
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(
            BASEventLogReplayBundle.self,
            from: veryLegacyJSON)
        XCTAssertEqual(
            decoded.nativeStagePerStepEvents.count, 0)
        XCTAssertEqual(
            decoded.biomimeticCheckpointEvents.count, 0)
    }

    // MARK: - Fix #7: Production-scale Mamba benchmark

    /// Runs Mamba scan at a moderate production-scale
    /// shape:B=2,D=64,N=16,L=128。 Not "huge"
    /// (would slow the test suite) but BIGGER than
    /// chapter 471's L=16/32。 Asserts structure-only;
    /// emits real measurement to test log。
    func testProductionScaleMambaBenchmarkRuns()
        async throws
    {
        let harness = BASMetalBenchmarkHarness()
        let report = try await harness.runMambaScan(
            batch: 2,
            hiddenDim: 64,
            stateDim: 16,
            sequenceLength: 128,
            warmupIterations: 1,
            timedIterations: 3)
        XCTAssertGreaterThan(
            report.cpuMicrosecondsMean, 0)
        XCTAssertEqual(
            report.cpuMicrosecondsSamples.count, 3)
        print("\n# Mamba production-scale benchmark" +
            " (chapter 473 fix #7):")
        print("  B=2 D=64 N=16 L=128")
        print("  " + report.summary)
    }
}
