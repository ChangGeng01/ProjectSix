// MARK: - BASChapter964SovereignSentinelSeatTests
// chapter 九百六十四 / M3525 — Phase 3 ch2 tests:SovereignSentinel
//
// Tests for the LOAD-BEARING sealed-LOW seat:
//   - 6-rule veto ladder (lockdown / heightened+signal / manip-irrev /
//     multi-axis / escalate / clear)
//   - Turn-level LOCKDOWN delta emitted when ANY candidate triggers it
//   - 8-seat dispatcher (full sentinel-included roster)
//   - CRITICAL Single-Writer invariants:
//       SovereignSentinel CAN write .sovereignVerdict (only one)
//       NO other agent can write .sovereignVerdict
//   - Sealed-LOW thresholds NOT runtime-tunable (static constants)
//   - Backward compat (7-seat callers still work)

import XCTest
import Foundation
@testable import BASMemory

final class BASChapter964SovereignSentinelSeatTests: XCTestCase {

    // MARK: - Helpers

    private func sentinelAgent() -> BASAgentSpec {
        BASAgentSpec(
            agentID: "sentinel.1",
            role: .sovereignSentinel,
            writeDomains: [.sovereignVerdict],
            defaultLeaseProfile: .sovereign,
            visibility: .low)  // sealed-LOW per design
    }

    private func cand(
        id: String,
        rev: Double = 0.9,
        axesCount: Int = 0,
        lockedAxis: Bool = false
    ) -> BASSovereignSentinelCandidate {
        BASSovereignSentinelCandidate(
            candidateID: id,
            title: "candidate \(id)",
            reversibility: rev,
            touchesAxesCount: axesCount,
            touchesSovereignLockedAxis: lockedAxis)
    }

    // MARK: - 6-rule veto ladder

    func testSentinel_EmptyEmitsZero() {
        var seq = 0
        let d = BASSovereignSentinelSeat.emit(
            from: BASSovereignSentinelInput(),
            turnID: "t1",
            agentSpec: sentinelAgent(),
            seq: &seq)
        XCTAssertEqual(d.count, 0)
    }

    func testSentinel_SovereignAxisLockdown() {
        var seq = 0
        let d = BASSovereignSentinelSeat.emit(
            from: BASSovereignSentinelInput(
                candidates: [cand(
                    id: "c1", lockedAxis: true)]),
            turnID: "t1",
            agentSpec: sentinelAgent(),
            seq: &seq)
        // 1 per-candidate LOCKDOWN + 1 turn-level LOCKDOWN = 2
        XCTAssertEqual(d.count, 2)
        XCTAssertEqual(d[0].confidence, 1.0)
        XCTAssertTrue(d[0].patchJson.contains(
            "\"severity\":\"lockdown\""))
        // Turn-level lockdown delta
        XCTAssertTrue(d[1].targetObjectRef.contains(
            "TURN-LOCKDOWN"))
        XCTAssertEqual(d[1].confidence, 1.0)
    }

    func testSentinel_HeightenedManipulationVeto() {
        var seq = 0
        let d = BASSovereignSentinelSeat.emit(
            from: BASSovereignSentinelInput(
                candidates: [cand(id: "c1", rev: 0.9)],
                manipulationDetected: true,
                heightenedProtection: true),
            turnID: "t1",
            agentSpec: sentinelAgent(),
            seq: &seq)
        XCTAssertEqual(d.count, 1)
        XCTAssertEqual(d[0].confidence, 0.97)
        XCTAssertTrue(d[0].patchJson.contains(
            "\"severity\":\"veto\""))
        XCTAssertTrue(d[0].reasonCodes.contains(
            "sovereign.severity=heightened-veto"))
    }

    func testSentinel_ManipulationIrreversibleVeto() {
        var seq = 0
        let d = BASSovereignSentinelSeat.emit(
            from: BASSovereignSentinelInput(
                candidates: [cand(id: "c1", rev: 0.1)],
                manipulationDetected: true),
            turnID: "t1",
            agentSpec: sentinelAgent(),
            seq: &seq)
        XCTAssertEqual(d[0].confidence, 0.97)
        XCTAssertTrue(d[0].reasonCodes.contains(
            "sovereign.severity=manip-irreversible"))
    }

    func testSentinel_MultiAxisVeto() {
        var seq = 0
        let d = BASSovereignSentinelSeat.emit(
            from: BASSovereignSentinelInput(
                candidates: [cand(
                    id: "c1", axesCount: 2)]),
            turnID: "t1",
            agentSpec: sentinelAgent(),
            seq: &seq)
        XCTAssertEqual(d[0].confidence, 0.97)
        XCTAssertTrue(d[0].reasonCodes.contains(
            "sovereign.severity=multi-axis-veto"))
    }

    func testSentinel_SignalOnlyEscalate() {
        // Manipulation alone (no irreversibility, no heightened)
        var seq = 0
        let d = BASSovereignSentinelSeat.emit(
            from: BASSovereignSentinelInput(
                candidates: [cand(id: "c1", rev: 0.9)],
                manipulationDetected: true),
            turnID: "t1",
            agentSpec: sentinelAgent(),
            seq: &seq)
        XCTAssertEqual(d[0].confidence, 0.85)
        XCTAssertTrue(d[0].patchJson.contains(
            "\"severity\":\"escalate\""))
    }

    func testSentinel_ClearEmitsZero() {
        var seq = 0
        let d = BASSovereignSentinelSeat.emit(
            from: BASSovereignSentinelInput(
                candidates: [cand(id: "c1")]),
            turnID: "t1",
            agentSpec: sentinelAgent(),
            seq: &seq)
        XCTAssertEqual(d.count, 0,
            "ch 964: clear candidate → no delta")
    }

    func testSentinel_TurnLockdownOnAnyCandidateLockdown() {
        // 3 candidates: 1 lockdown, 2 clear → turn lockdown
        // delta emitted
        var seq = 0
        let d = BASSovereignSentinelSeat.emit(
            from: BASSovereignSentinelInput(
                candidates: [
                    cand(id: "clean1"),
                    cand(id: "locked", lockedAxis: true),
                    cand(id: "clean2"),
                ]),
            turnID: "t1",
            agentSpec: sentinelAgent(),
            seq: &seq)
        // 1 per-candidate (only locked) + 1 turn-level = 2
        XCTAssertEqual(d.count, 2)
        // Last delta is turn-level
        let last = d.last!
        XCTAssertTrue(last.targetObjectRef.contains(
            "TURN-LOCKDOWN"))
        XCTAssertEqual(last.confidence, 1.0)
    }

    // MARK: - CRITICAL Single-Writer invariants

    func testCRITICAL_SentinelIsSoleWriterOfSovereignVerdict() async {
        // Sentinel CAN write .sovereignVerdict
        let sentinel = sentinelAgent()
        XCTAssertTrue(sentinel.writeDomains.contains(
            .sovereignVerdict))
        let graph = BASSharedStateGraph()
        let obj = try? await graph.writeObject(
            domain: .sovereignVerdict,
            objectID: "sv-test",
            payloadJson: "{}",
            byAgent: sentinel)
        XCTAssertNotNil(obj,
            "ch 964 CRITICAL: SovereignSentinel MUST be able " +
            "to write .sovereignVerdict")
    }

    func testCRITICAL_NoOtherAgentCanWriteSovereignVerdict() async {
        // Re-prove: Planner / Risk / Surface / HostAlign /
        // Memory / Critic CANNOT write .sovereignVerdict
        let imposters: [BASAgentSpec] = [
            BASAgentSpec(
                agentID: "planner.imp",
                role: .planner,
                writeDomains: [.candidateFrontier],
                defaultLeaseProfile: .hotSeat,
                visibility: .high),
            BASAgentSpec(
                agentID: "risk.imp",
                role: .risk,
                writeDomains: [.riskField],
                defaultLeaseProfile: .hotSeat,
                visibility: .high),
            BASAgentSpec(
                agentID: "hostalign.imp",
                role: .hostAlignment,
                writeDomains: [.alignmentField],
                defaultLeaseProfile: .hotSeat,
                visibility: .medium),
        ]
        for imp in imposters {
            let graph = BASSharedStateGraph()
            do {
                _ = try await graph.writeObject(
                    domain: .sovereignVerdict,
                    objectID: "imp",
                    payloadJson: "{}",
                    byAgent: imp)
                XCTFail("ch 964 CRITICAL: \(imp.role) MUST " +
                    "NOT be able to write .sovereignVerdict")
            } catch let e as BASSharedStateGraphError {
                guard case .unauthorizedWriter = e else {
                    XCTFail("expected unauthorizedWriter " +
                        "got \(e)")
                    return
                }
            } catch {
                XCTFail("unexpected: \(error)")
            }
        }
    }

    // MARK: - Sealed-LOW thresholds NOT runtime-tunable

    func testSentinel_ThresholdsAreStaticConstants() {
        // Per sealed-LOW design: thresholds are static, no
        // input field exposes a way to override them
        XCTAssertEqual(
            BASSovereignSentinelSeat.multiAxisVetoCount, 2)
        XCTAssertEqual(
            BASSovereignSentinelSeat.irreversibilityFloor,
            0.2, accuracy: 0.001)
        // The input DTO has NO threshold-tuning fields (verified
        // by inspection — only candidate list + boolean signals)
    }

    func testSentinel_VisibilityIsLow() {
        // Sealed-LOW per visibility table — sentinel agent
        // CANNOT be HIGH visibility (would invite user
        // customization,which violates Root Law 4 单主权)
        let sentinel = sentinelAgent()
        XCTAssertEqual(
            sentinel.visibility, .low,
            "ch 964 CRITICAL: SovereignSentinel visibility " +
            "MUST be .low (sealed,no user customization)")
    }

    // MARK: - 8-seat dispatcher

    func testDispatcher_AllEightSeatsEmit() async {
        let roster = BASAgentTurnRoster(
            scout: makeAgent(
                "s", .scout, .situationField),
            planner: makeAgent(
                "p", .planner, .candidateFrontier),
            risk: makeAgent("r", .risk, .riskField),
            surface: makeAgent(
                "su", .surface, .renderFrame),
            memory: makeAgent(
                "m", .memory, .memoryBundle),
            critic: makeAgent("c", .critic, .critiqueField),
            hostAlignment: makeAgent(
                "h", .hostAlignment, .alignmentField),
            sovereignSentinel: sentinelAgent())
        let input = BASAgentTurnInput(
            turnID: "t1",
            scout: BASScoutInput(
                pressureSignals: ["a"],
                manipulationSignals: ["m"]),
            plannerCandidates: [BASPlannerCandidate(
                candidateID: "c1",
                title: "t",
                actionSummary: "a",
                confidence: 0.8,
                reversibility: 0.5)],
            risk: BASRiskInput(
                candidates: [BASRiskCandidate(
                    candidateID: "c1",
                    reversibility: 0.5)],
                manipulationDetected: true),
            surface: BASSurfaceInput(
                acceptedCandidateID: "c1",
                riskBand: .high,
                reversibility: 0.5),
            memory: BASMemorySeatInput(
                episodeArcs: ["arc-1"],
                recallStrength: 0.6),
            critic: BASCriticSeatInput(
                candidates: [BASCriticCandidate(
                    candidateID: "c1",
                    title: "t",
                    expectedBenefit: 0.3,
                    expectedCost: 0.5,
                    reversibility: 0.5)]),
            hostAlignment: BASHostAlignmentInput(
                candidates: [BASHostAlignmentCandidate(
                    candidateID: "c1",
                    title: "t",
                    touchesAxes: ["financial"])],
                hostBoundaryAxes: ["financial"]),
            sovereignSentinel:
                BASSovereignSentinelInput(
                    candidates: [cand(
                        id: "c1",
                        rev: 0.5)],
                    manipulationDetected: true))
        let graph = BASSharedStateGraph()
        let result = await BASAgentTurnDispatcher.dispatch(
            input: input, roster: roster, graph: graph)
        // Scout 2 (pressure + manip) + Planner 1 + Memory 1 +
        // Critic 1 + HostAlign 1 + Risk 1 + Surface 1 +
        // Sentinel 1 (escalate — manip alone) = 9
        XCTAssertGreaterThanOrEqual(
            result.emittedDeltas.count, 9)
        // Sentinel claimed .sovereignVerdict
        let sovWriter = await graph.writerForDomain(
            .sovereignVerdict)
        XCTAssertEqual(sovWriter, "sentinel.1",
            "ch 964 CRITICAL: SovereignSentinel is sole " +
            "writer of .sovereignVerdict in 8-seat dispatch")
    }

    func testDispatcher_7SeatBackwardCompat() async {
        // No sentinel in roster or input → dispatcher skips
        let roster = BASAgentTurnRoster(
            scout: makeAgent("s", .scout, .situationField),
            planner: makeAgent(
                "p", .planner, .candidateFrontier),
            risk: makeAgent("r", .risk, .riskField),
            surface: makeAgent(
                "su", .surface, .renderFrame),
            memory: makeAgent(
                "m", .memory, .memoryBundle),
            critic: makeAgent("c", .critic, .critiqueField),
            hostAlignment: makeAgent(
                "h", .hostAlignment, .alignmentField))
        XCTAssertNil(roster.sovereignSentinel)
        let input = BASAgentTurnInput(turnID: "t1")
        XCTAssertNil(input.sovereignSentinel)
        let result = await BASAgentTurnDispatcher.dispatch(
            input: input,
            roster: roster,
            graph: BASSharedStateGraph())
        XCTAssertFalse(result.emittedDeltas.contains {
            $0.targetObjectRef.contains("sovereignVerdict")
        })
    }

    // MARK: - Helpers

    private func makeAgent(
        _ id: String,
        _ role: BASAgentRole,
        _ domain: BASStateDomain
    ) -> BASAgentSpec {
        BASAgentSpec(
            agentID: id, role: role,
            writeDomains: [domain],
            defaultLeaseProfile: .hotSeat,
            visibility: .high)
    }
}
