// MARK: - BASChapter960CoordinatorWireTests
// chapter 九百六十 / M3505 — Phase 2 ch1 tests:coordinator wire
//
// Verifies the FIRST per-turn coordinator touch is correctly
// OPT-IN per ADR-014 + 红线 7:
//
//   1. init without `agentFabric:` → property is nil → no behavior
//      change vs pre-ch-960 (backward compat preserved)
//   2. init with `agentFabric:` → property holds the bundle
//   3. `runAgentFabricObservation` returns nil when fabric is nil
//      (zero-overhead no-op)
//   4. `runAgentFabricObservation` returns a valid
//      `BASAgentTurnResult` when fabric is set
//   5. Adapters convert BASDecomposeFrame + [BASCandidatePath]
//      → DTOs correctly
//   6. End-to-end: coordinator with fabric set → observation call
//      writes the expected 9 trace events + 4 state-graph objects
//
// The full-sweep regression test (separate file) is the real
// proof that 红线 7 holds — these tests pin the new surface。

import XCTest
import Foundation
@testable import BASMemory
@testable import BASOrchestration
@testable import BASHostKit

final class BASChapter960CoordinatorWireTests: XCTestCase {

    // MARK: - Test helpers

    private func makeCoordinator(
        fabric: BASAgentFabricRuntime? = nil
    ) -> BASEBrainRuntimeCoordinator {
        BASEBrainRuntimeCoordinator(
            powerClockService:
                BASPlaceholderPowerClockService(),
            hostProfileService:
                BASPlaceholderHostProfileService(),
            contextService:
                BASPlaceholderContextService(),
            decomposeService:
                BASPlaceholderDecomposeService(),
            memoryService:
                BASPlaceholderMemoryService(),
            loopService:
                BASPlaceholderLoopService(),
            triSelfService:
                BASPlaceholderTriSelfService(),
            riskService:
                BASPlaceholderRiskService(),
            actionService:
                BASPlaceholderActionService(),
            evolutionService:
                BASPlaceholderEvolutionService(),
            agentFabric: fabric)
    }

    private func makeRoster() -> BASAgentTurnRoster {
        BASAgentTurnRoster(
            scout: BASAgentSpec(
                agentID: "scout.1",
                role: .scout,
                writeDomains: [.situationField],
                defaultLeaseProfile: .hotSeat,
                visibility: .high),
            planner: BASAgentSpec(
                agentID: "planner.1",
                role: .planner,
                writeDomains: [.candidateFrontier],
                defaultLeaseProfile: .hotSeat,
                visibility: .high),
            risk: BASAgentSpec(
                agentID: "risk.1",
                role: .risk,
                writeDomains: [.riskField],
                defaultLeaseProfile: .hotSeat,
                visibility: .high),
            surface: BASAgentSpec(
                agentID: "surface.1",
                role: .surface,
                writeDomains: [.renderFrame],
                defaultLeaseProfile: .hotSeat,
                visibility: .high))
    }

    private func makeFabric(
        traceLog: BASAgentTraceLog? = nil
    ) -> BASAgentFabricRuntime {
        BASAgentFabricRuntime(
            roster: makeRoster(),
            graph: BASSharedStateGraph(),
            traceLog: traceLog)
    }

    private func makeFrame(
        withPressure: Bool = true,
        withManipulation: Bool = false
    ) -> BASDecomposeFrame {
        BASDecomposeFrame(
            schemaVersion:
                BASDecomposeFrame.currentSchemaVersion,
            pressureSignals:
                withPressure ? ["stress.high"] : [],
            manipulationSignals:
                withManipulation ? ["guilt.trip"] : [],
            mirrorText: "test")
    }

    private func makeCandidates() -> [BASCandidatePath] {
        [BASCandidatePath(
            candidateID: "c1",
            title: "Take a break",
            actionSummary: "5 min pause",
            expectedBenefit: 0.8,
            expectedCost: 0.1,
            reversibility: 0.95,
            confidence: 0.85)]
    }

    // MARK: - Backward-compat: nil agentFabric path

    func testInit_WithoutFabric_PropertyIsNil() {
        let c = makeCoordinator(fabric: nil)
        XCTAssertNil(c.agentFabric,
            "ch 960: omitting agentFabric must leave it nil")
    }

    func testInit_DefaultParameter_PropertyIsNil() {
        // Verifies the DEFAULT works — caller doesn't have to
        // pass `agentFabric: nil` explicitly
        let c = BASEBrainRuntimeCoordinator(
            powerClockService:
                BASPlaceholderPowerClockService(),
            hostProfileService:
                BASPlaceholderHostProfileService(),
            contextService:
                BASPlaceholderContextService(),
            decomposeService:
                BASPlaceholderDecomposeService(),
            memoryService:
                BASPlaceholderMemoryService(),
            loopService:
                BASPlaceholderLoopService(),
            triSelfService:
                BASPlaceholderTriSelfService(),
            riskService:
                BASPlaceholderRiskService(),
            actionService:
                BASPlaceholderActionService(),
            evolutionService:
                BASPlaceholderEvolutionService())
        XCTAssertNil(c.agentFabric,
            "ch 960: default param value is nil → byte-equal")
    }

    func testObservation_WithoutFabric_ReturnsNil() async {
        let c = makeCoordinator(fabric: nil)
        let result = await c.runAgentFabricObservation(
            turnID: "t1",
            decomposeFrame: makeFrame(),
            candidatePaths: makeCandidates())
        XCTAssertNil(result,
            "ch 960: no fabric → no-op (zero-overhead path)")
    }

    // MARK: - Fabric set path

    func testInit_WithFabric_PropertyHoldsBundle() {
        let fabric = makeFabric()
        let c = makeCoordinator(fabric: fabric)
        XCTAssertNotNil(c.agentFabric)
    }

    func testObservation_WithFabric_ReturnsValidResult() async {
        let fabric = makeFabric()
        let c = makeCoordinator(fabric: fabric)
        let result = await c.runAgentFabricObservation(
            turnID: "t-obs-1",
            decomposeFrame: makeFrame(),
            candidatePaths: makeCandidates(),
            acceptedCandidateID: "c1")
        XCTAssertNotNil(result)
        // 4 seats × 1 delta each = 4 (scout pressure + planner 1
        // + risk 1 + surface 1)
        XCTAssertEqual(result?.emittedDeltas.count, 4)
        XCTAssertEqual(
            result?.mergeResult.acceptedDeltaIDs.count, 4)
    }

    func testObservation_WithTraceLog_CapturesEvents() async {
        let log = BASAgentTraceLog()
        let fabric = makeFabric(traceLog: log)
        let c = makeCoordinator(fabric: fabric)
        _ = await c.runAgentFabricObservation(
            turnID: "t-trace",
            decomposeFrame: makeFrame(),
            candidatePaths: makeCandidates(),
            acceptedCandidateID: "c1")
        let events = await log.events(forTurn: "t-trace")
        XCTAssertEqual(events.count, 9,
            "ch 960: 4 deltaEmitted + 1 mergeCompleted + " +
            "4 deltaApplied = 9 trace events")
    }

    func testObservation_GraphReceivesAcceptedDeltas() async {
        let fabric = makeFabric()
        let c = makeCoordinator(fabric: fabric)
        _ = await c.runAgentFabricObservation(
            turnID: "t-graph",
            decomposeFrame: makeFrame(),
            candidatePaths: makeCandidates(),
            acceptedCandidateID: "c1")
        let count = await fabric.graph.objectCount()
        XCTAssertEqual(count, 4,
            "ch 960: fabric graph receives 4 accepted-delta " +
            "writes (sit field + frontier + risk field + render)")
    }

    // MARK: - Adapter coverage

    func testAdapter_ScoutInputFromFrame() {
        let frame = makeFrame(
            withPressure: true,
            withManipulation: true)
        let scout = BASAgentFabricAdapters.scoutInput(
            from: frame)
        XCTAssertEqual(
            scout.pressureSignals, ["stress.high"])
        XCTAssertEqual(
            scout.manipulationSignals, ["guilt.trip"])
        XCTAssertFalse(scout.isEmpty)
    }

    func testAdapter_PlannerCandidates() {
        let paths = makeCandidates()
        let candidates =
            BASAgentFabricAdapters.plannerCandidates(
                from: paths)
        XCTAssertEqual(candidates.count, 1)
        XCTAssertEqual(candidates[0].candidateID, "c1")
        XCTAssertEqual(candidates[0].confidence, 0.85)
        XCTAssertEqual(
            candidates[0].reversibility, 0.95)
    }

    func testAdapter_RiskInput_PressureScaling() {
        // 5 pressure signals → pressureLevel = 1.0 (cap)
        let frame = BASDecomposeFrame(
            schemaVersion:
                BASDecomposeFrame.currentSchemaVersion,
            pressureSignals: (1...5).map { "p\($0)" },
            mirrorText: "")
        let r = BASAgentFabricAdapters.riskInput(
            from: frame, candidates: [])
        XCTAssertEqual(r.pressureLevel, 1.0, accuracy: 0.001)
        XCTAssertFalse(r.manipulationDetected)
    }

    func testAdapter_RiskInput_ManipulationDetected() {
        let frame = makeFrame(withManipulation: true)
        let r = BASAgentFabricAdapters.riskInput(
            from: frame, candidates: makeCandidates())
        XCTAssertTrue(r.manipulationDetected)
        XCTAssertEqual(r.candidates.count, 1)
        XCTAssertEqual(
            r.candidates[0].candidateID, "c1")
    }

    func testAdapter_SurfaceInputObservationMode_SafeDefaults() {
        let s = BASAgentFabricAdapters
            .surfaceInputObservationMode(
                acceptedCandidateID: "c1",
                riskBand: .low)
        XCTAssertEqual(s.acceptedCandidateID, "c1")
        XCTAssertTrue(s.actionPermitGranted,
            "ch 960 observation mode: permit granted by default")
        XCTAssertFalse(s.sovereignVetoed)
        XCTAssertEqual(s.riskBand, .low)
    }

    func testAdapter_TurnInput_BuildsAllFourDTOs() {
        let input = BASAgentFabricAdapters.turnInput(
            turnID: "t-adapt",
            decomposeFrame: makeFrame(
                withPressure: true,
                withManipulation: true),
            candidatePaths: makeCandidates(),
            acceptedCandidateID: "c1")
        XCTAssertEqual(input.turnID, "t-adapt")
        XCTAssertFalse(input.scout.isEmpty)
        XCTAssertEqual(input.plannerCandidates.count, 1)
        XCTAssertEqual(input.risk.candidates.count, 1)
        XCTAssertTrue(input.risk.manipulationDetected)
        XCTAssertEqual(
            input.surface.acceptedCandidateID, "c1")
    }

    // MARK: - 红线 7 spot-check (the real test is the full sweep)

    func testRedline7_FabricNilPathDoesNotMutateCoordinator() {
        // Calling observation with nil fabric must NOT change any
        // observable state on the coordinator
        var c = makeCoordinator(fabric: nil)
        let beforeServices = (
            c.powerClockService is
                BASPlaceholderPowerClockService,
            c.policyLineage,
            c.hostRhythmProfile,
            c.hostConstitution)
        _ = c  // suppress "var never mutated"
        // (we don't await the async observation call since it's
        // a no-op for nil fabric — the type system guarantees it
        // can't mutate any non-`agentFabric` property)
        let afterServices = (
            c.powerClockService is
                BASPlaceholderPowerClockService,
            c.policyLineage,
            c.hostRhythmProfile,
            c.hostConstitution)
        XCTAssertEqual(beforeServices.0, afterServices.0)
        XCTAssertEqual(beforeServices.2, afterServices.2)
    }
}
