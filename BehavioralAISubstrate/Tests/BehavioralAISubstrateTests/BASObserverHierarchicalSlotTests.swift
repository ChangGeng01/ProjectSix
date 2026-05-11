// MARK: - BASObserverHierarchicalSlotTests
// chapter 四百七十 / M1258 PROOF tests
//
// Verifies the 4th slot integration:hierarchical
// predictive coding wired into BASBiomimeticTurnObserver。

import XCTest
@testable import BASMetalSubstrate

final class BASObserverHierarchicalSlotTests: XCTestCase
{

    func testObserverWith4PopulatedSlotsReports4() async
        throws
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
        let observer = BASBiomimeticTurnObserver(
            mamba: mamba,
            predictive: probe,
            plasticity: fold,
            hierarchical: hier)
        XCTAssertEqual(
            observer.populatedPrimitiveCount, 4,
            "chapter 470 extends to 4 slots")
        XCTAssertNotNil(observer.hierarchical)
    }

    func testHierarchicalDispatchProducesResult()
        async throws
    {
        let hierShape = try
            BASHierarchicalPredictiveCodingShape(
                layers: [
                    BASPredictiveCodingProbeShape(
                        dim: 1,
                        learningRate: 0.5,
                        initialPrediction: [0])
                ])
        let hier = BASHierarchicalPredictiveCoding(
            shape: hierShape)
        let observer = BASBiomimeticTurnObserver(
            hierarchical: hier)
        let signal = BASBiomimeticTurnSignal(
            hierarchicalObservation: [1.0])
        let result = try await observer.observe(signal)
        XCTAssertNotNil(result.hierarchical,
            "hierarchical primitive must produce result" +
            " when signal carries observation")
        XCTAssertEqual(result.producedResultCount, 1)
    }

    func testHierarchicalSlotSkippedWhenNotPopulated()
        async throws
    {
        let observer = BASBiomimeticTurnObserver()
        let signal = BASBiomimeticTurnSignal(
            hierarchicalObservation: [1.0, 2.0])
        let result = try await observer.observe(signal)
        XCTAssertNil(result.hierarchical)
        XCTAssertEqual(result.producedResultCount, 0)
    }

    func testSignalPopulatedDriveCountTracksHierarchical()
    {
        let s = BASBiomimeticTurnSignal(
            hierarchicalObservation: [1.0])
        XCTAssertEqual(s.populatedDriveCount, 1,
            "hierarchical observation must count as" +
            " populated drive")
    }

    func testResetCascadesToHierarchical() async throws
    {
        let hierShape = try
            BASHierarchicalPredictiveCodingShape(
                layers: [
                    BASPredictiveCodingProbeShape(
                        dim: 1,
                        learningRate: 0.5,
                        initialPrediction: [0])
                ])
        let hier = BASHierarchicalPredictiveCoding(
            shape: hierShape)
        let observer = BASBiomimeticTurnObserver(
            hierarchical: hier)
        _ = try await observer.observe(
            BASBiomimeticTurnSignal(
                hierarchicalObservation: [1.0]))
        let countBefore = await hier
            .observationCount()
        XCTAssertEqual(countBefore, 1)
        await observer.reset()
        let countAfter = await hier.observationCount()
        XCTAssertEqual(countAfter, 0,
            "reset must cascade to hierarchical primitive")
    }
}
