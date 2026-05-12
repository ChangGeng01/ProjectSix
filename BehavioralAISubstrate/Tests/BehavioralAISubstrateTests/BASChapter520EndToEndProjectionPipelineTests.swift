// MARK: - BASChapter520EndToEndProjectionPipelineTests
// chapter 五百二十 / M1458 — end-to-end pipeline PROOF
//
// PROOF tests for the complete chapter 511-520 typed
// projection-block pipeline,exercised end-to-end via
// real V1 monolith turns:
//
//   1. Coordinator with adapter-wired handler →
//      observer receives observations per turn
//   2. snapshotAsBundle returns typed batch ready for
//      audit emission record (M1430 5th pipeline)
//   3. Multi-turn batch has expected coverage metrics
//   4. Observer survives coordinator destruction
//      (observer outlives the coordinator)
//   5. Empty turn-set produces empty bundle

import XCTest
@testable import BASHostKit
@testable import BASOrchestration
@testable import BASRuntimeCore

final class BASChapter520EndToEndProjectionPipelineTests:
    XCTestCase
{

    // MARK: - 1) Coordinator+adapter+observer pipeline

    func testCoordinatorAdapterObserverPipeline() async {
        let observer =
            BASAuditObservationProjectionsBundleObserver()
        let adapter =
            BASAuditObservationProjectionsBundleObserverHostAdapter(
                observer: observer)
        let coord = BASEBrainRuntimeCoordinator(
            powerClockService: StubPowerClock(),
            hostProfileService: StubHost(),
            contextService: StubContext(),
            decomposeService: StubDecompose(),
            memoryService: StubMemory(),
            loopService: StubLoop(),
            triSelfService: StubTriSelf(),
            riskService: StubRisk(),
            actionService: StubAction(),
            evolutionService: StubEvolution(),
            projectionBlockEmissionHandler:
                adapter.handler)
        _ = coord.runTurn(
            BASCoordinatorTestStubs.makeStubRequest(
                userInput: "turn-1"))
        // Wait for Task.detached to deliver
        try? await Task.sleep(nanoseconds: 200_000_000)
        let count = await observer.emissionCount
        XCTAssertEqual(count, 1,
            "1 turn through V1 monolith → 1 emission" +
            " at observer")
    }

    // MARK: - 2) snapshotAsBundle ready for M1430

    func testSnapshotAsBundleReadyForAuditEmission()
        async
    {
        let observer =
            BASAuditObservationProjectionsBundleObserver()
        let adapter =
            BASAuditObservationProjectionsBundleObserverHostAdapter(
                observer: observer)
        let coord = BASEBrainRuntimeCoordinator(
            powerClockService: StubPowerClock(),
            hostProfileService: StubHost(),
            contextService: StubContext(),
            decomposeService: StubDecompose(),
            memoryService: StubMemory(),
            loopService: StubLoop(),
            triSelfService: StubTriSelf(),
            riskService: StubRisk(),
            actionService: StubAction(),
            evolutionService: StubEvolution(),
            projectionBlockEmissionHandler:
                adapter.handler)
        for i in 0..<3 {
            _ = coord.runTurn(
                BASCoordinatorTestStubs.makeStubRequest(
                    userInput: "turn-\(i)"))
        }
        try? await Task.sleep(nanoseconds: 500_000_000)
        let bundle = await observer.snapshotAsBundle()
        XCTAssertEqual(bundle.count, 3)
        XCTAssertEqual(bundle.fullyCoveredTurnCount, 3,
            "V1 monolith always uses fullyCovered" +
            " (chapter 519 splice)")
        XCTAssertEqual(
            bundle.coldTurnCount, 0,
            "no cold turns when handler wired")
        XCTAssertEqual(
            bundle.cumulativePopulatedBlockCount, 6,
            "3 turns × 2 blocks = 6 populated blocks")
    }

    // MARK: - 3) Multi-turn coverage metrics

    func testMultiTurnBundleCoverageMetrics() async {
        let observer =
            BASAuditObservationProjectionsBundleObserver()
        let adapter =
            BASAuditObservationProjectionsBundleObserverHostAdapter(
                observer: observer)
        let coord = BASEBrainRuntimeCoordinator(
            powerClockService: StubPowerClock(),
            hostProfileService: StubHost(),
            contextService: StubContext(),
            decomposeService: StubDecompose(),
            memoryService: StubMemory(),
            loopService: StubLoop(),
            triSelfService: StubTriSelf(),
            riskService: StubRisk(),
            actionService: StubAction(),
            evolutionService: StubEvolution(),
            projectionBlockEmissionHandler:
                adapter.handler)
        for i in 0..<10 {
            _ = coord.runTurn(
                BASCoordinatorTestStubs.makeStubRequest(
                    userInput: "input-\(i)"))
        }
        try? await Task.sleep(nanoseconds: 700_000_000)
        let bundle = await observer.snapshotAsBundle()
        XCTAssertEqual(bundle.count, 10)
        XCTAssertEqual(
            bundle.fullyCoveredTurnRatio, 1.0,
            accuracy: 1e-6,
            "all 10 turns fully covered")
    }

    // MARK: - 4) Observer survives coordinator destruction

    func testObserverSurvivesCoordinatorDestruction()
        async
    {
        let observer =
            BASAuditObservationProjectionsBundleObserver()
        let adapter =
            BASAuditObservationProjectionsBundleObserverHostAdapter(
                observer: observer)
        // Construct coordinator inside scope, let it
        // go out of scope after running a turn
        do {
            let coord = BASEBrainRuntimeCoordinator(
                powerClockService: StubPowerClock(),
                hostProfileService: StubHost(),
                contextService: StubContext(),
                decomposeService: StubDecompose(),
                memoryService: StubMemory(),
                loopService: StubLoop(),
                triSelfService: StubTriSelf(),
                riskService: StubRisk(),
                actionService: StubAction(),
                evolutionService: StubEvolution(),
                projectionBlockEmissionHandler:
                    adapter.handler)
            _ = coord.runTurn(
                BASCoordinatorTestStubs.makeStubRequest())
        }
        // Coordinator deallocated. Observer + adapter
        // outlive it。 The emission Task already
        // scheduled before dealloc must still arrive.
        try? await Task.sleep(nanoseconds: 200_000_000)
        let count = await observer.emissionCount
        XCTAssertEqual(count, 1,
            "observer outlives coordinator")
    }

    // MARK: - 5) Zero turns → empty bundle

    func testZeroTurnsProduceEmptyBundle() async {
        let observer =
            BASAuditObservationProjectionsBundleObserver()
        // No coordinator constructed, no turns run
        let bundle = await observer.snapshotAsBundle()
        XCTAssertEqual(bundle.count, 0)
        XCTAssertEqual(bundle.fullyCoveredTurnCount, 0)
        XCTAssertEqual(
            bundle.cumulativePopulatedBlockCount, 0)
    }
}
