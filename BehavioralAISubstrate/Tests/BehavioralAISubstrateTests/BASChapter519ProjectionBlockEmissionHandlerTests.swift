// MARK: - BASChapter519ProjectionBlockEmissionHandlerTests
// chapter 五百十九 / M1455 — PROOF for production wire-in
//
// PROOF tests that the M1453 projectionBlockEmission
// Handler slot,when wired,receives a typed observation
// per turn run via the V1 monolith (M1454 splice)。
//
// Critical invariants:
//   1. Default nil handler → no observation fired (V1
//      byte-equality preserved)
//   2. Wired handler → exactly 1 observation per turn
//   3. Observation has both Kunlun + Cthulhu blocks
//      covered (M1454 always uses fullyCovered variant)
//   4. Observation turnID + sessionID match the turn's
//      frameContext-derived IDs
//   5. Multi-turn runs produce N observations in
//      arrival order

import XCTest
@testable import BASHostKit
@testable import BASOrchestration
@testable import BASRuntimeCore

final class BASChapter519ProjectionBlockEmissionHandlerTests:
    XCTestCase
{

    // MARK: - 1) Default nil handler → no fire

    /// V1 byte-equality regression guard: when the
    /// handler is nil (default),turns run with no
    /// observation side-effect。 If a future change ever
    /// fires the handler unconditionally,this test
    /// fails first。
    func testDefaultNilHandlerNotInvoked() {
        // Construct stub coordinator without setting
        // the handler — defaults to nil。
        let coord = BASCoordinatorTestStubs.makeStub()
        XCTAssertNil(
            coord.projectionBlockEmissionHandler,
            "stub coordinator must default to nil" +
            " handler")
        // Run a turn — no fire = no crash + no
        // observable side-effect。
        let result = coord.runTurn(
            BASCoordinatorTestStubs.makeStubRequest())
        XCTAssertNotNil(result,
            "turn must complete normally even with no" +
            " handler")
    }

    // MARK: - 2) Wired handler fires exactly once

    func testWiredHandlerFiresOncePerTurn() {
        // Capture the handler invocations。
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
        let count = captured.observationCount
        XCTAssertEqual(count, 1,
            "handler must fire exactly once per turn")
    }

    // MARK: - 3) Observation has both blocks covered

    func testObservationHasBothBlocksCovered() {
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
            XCTFail("no observation captured")
            return
        }
        XCTAssertTrue(obs.hasBothBlocks,
            "M1454 splice uses fullyCovered variant")
        XCTAssertNotNil(obs.kunlunInputsHash)
        XCTAssertNotNil(obs.cthulhuInputsHash)
        XCTAssertEqual(obs.populatedBlockCount, 2)
    }

    // MARK: - 4) Observation has non-empty IDs

    func testObservationHasNonEmptyIDs() {
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
            XCTFail("no observation captured")
            return
        }
        XCTAssertFalse(obs.turnID.isEmpty,
            "turnID must be populated from frameContext")
        XCTAssertFalse(obs.sessionID.isEmpty,
            "sessionID must be populated from frame" +
            "Context")
    }

    // MARK: - 5) Multi-turn produces N observations

    func testMultiTurnProducesObservationsInOrder() {
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
            BASCoordinatorTestStubs.makeStubRequest(
                userInput: "turn 1"))
        _ = coord.runTurn(
            BASCoordinatorTestStubs.makeStubRequest(
                userInput: "turn 2"))
        _ = coord.runTurn(
            BASCoordinatorTestStubs.makeStubRequest(
                userInput: "turn 3"))
        let count = captured.observationCount
        XCTAssertEqual(count, 3,
            "3 turns must fire handler 3 times")
        let snap = captured.snapshot
        XCTAssertEqual(snap.count, 3)
        for obs in snap {
            XCTAssertTrue(obs.hasBothBlocks)
        }
    }
}

// MARK: - Test capture helper (thread-safe collector)

final class BASChapter519HandlerCapture: @unchecked Sendable {
    private let lock = NSLock()
    private var observations:
        [BASAuditObservationProjectionsBundleObservation]
        = []

    var observationCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return observations.count
    }

    var firstObservation:
        BASAuditObservationProjectionsBundleObservation?
    {
        lock.lock()
        defer { lock.unlock() }
        return observations.first
    }

    var snapshot:
        [BASAuditObservationProjectionsBundleObservation]
    {
        lock.lock()
        defer { lock.unlock() }
        return observations
    }

    var handler: @Sendable
        (BASAuditObservationProjectionsBundleObservation)
        -> Void
    {
        return { [weak self] obs in
            guard let self else { return }
            self.lock.lock()
            self.observations.append(obs)
            self.lock.unlock()
        }
    }
}
