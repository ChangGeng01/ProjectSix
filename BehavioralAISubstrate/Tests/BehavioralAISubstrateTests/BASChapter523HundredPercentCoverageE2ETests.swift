// MARK: - BASChapter523HundredPercentCoverageE2ETests
// chapter 五百二十三 / M1471 — end-to-end PROOF for the
//                              100% V1 packaging
//                              coverage milestone
//
// Verifies that running a real V1 monolith turn
// produces an observation whose Kunlun + Cthulhu input
// blocks contain ALL the projection-block coverage
// expected after the chapter 522 milestone。

import XCTest
@testable import BASHostKit
@testable import BASOrchestration
@testable import BASRuntimeCore

final class BASChapter523HundredPercentCoverageE2ETests:
    XCTestCase
{

    // MARK: - 1) V1 turn produces both-block observation

    /// PROOF: a single V1 monolith turn fires the
    /// emission handler with a hasBothBlocks=true
    /// observation。 This validates that the M1454 V1
    /// splice always uses the fullyCovered factory
    /// variant after the chapter 522 milestone。
    func testV1TurnProducesBothBlockObservation()
        async
    {
        let captured =
            BASChapter519HandlerCapture()
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
                captured.handler)
        _ = coord.runTurn(
            BASCoordinatorTestStubs.makeStubRequest())
        guard let obs = captured.firstObservation else {
            XCTFail("V1 monolith did not fire handler")
            return
        }
        XCTAssertTrue(obs.hasBothBlocks,
            "V1 monolith must use fullyCovered" +
            " (chapter 519 splice; chapter 522 100%" +
            " coverage milestone)")
        XCTAssertEqual(obs.populatedBlockCount, 2,
            "both Kunlun + Cthulhu blocks populate")
    }

    // MARK: - 2) Adapter-routed observation reaches observer

    /// PROOF: when the V1 turn's emission flows through
    /// the M1457 host adapter into the M1426 actor
    /// observer,the observer's accumulated bundle
    /// reflects 100% block coverage。
    func testAdapterRoutedObservationReachesObserver()
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
            "every turn after chapter 522 milestone" +
            " must be fully covered")
        XCTAssertEqual(bundle.coldTurnCount, 0)
        XCTAssertEqual(
            bundle.fullyCoveredTurnRatio, 1.0,
            accuracy: 1e-6)
    }

    // MARK: - 3) Observations have stable Kunlun + Cthulhu hashes

    /// PROOF: 2 V1 turns with the SAME request produce
    /// observations with the SAME Kunlun + Cthulhu
    /// input-block hashes (replay determinism)。 If a
    /// future change broke determinism,this test fails。
    func testObservationsHaveStableHashesForSameInput()
        async
    {
        let captured1 =
            BASChapter519HandlerCapture()
        let coord1 = BASEBrainRuntimeCoordinator(
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
                captured1.handler)
        let captured2 =
            BASChapter519HandlerCapture()
        let coord2 = BASEBrainRuntimeCoordinator(
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
                captured2.handler)
        let req =
            BASCoordinatorTestStubs.makeStubRequest(
                userInput: "deterministic-input")
        _ = coord1.runTurn(req)
        _ = coord2.runTurn(req)
        guard let obs1 = captured1.firstObservation,
              let obs2 = captured2.firstObservation
        else {
            XCTFail("missing observations")
            return
        }
        // Note: turnID + sessionID + emittedAt differ
        // per coord (UUID + current Date), so full obs
        // equality is NOT guaranteed. Block-input
        // hashes ARE deterministic given same request.
        XCTAssertEqual(
            obs1.kunlunInputsHash,
            obs2.kunlunInputsHash,
            "Kunlun inputs block hash must be replay-" +
            "deterministic for identical request")
        XCTAssertEqual(
            obs1.cthulhuInputsHash,
            obs2.cthulhuInputsHash,
            "Cthulhu inputs block hash must be replay-" +
            "deterministic for identical request")
    }
}
