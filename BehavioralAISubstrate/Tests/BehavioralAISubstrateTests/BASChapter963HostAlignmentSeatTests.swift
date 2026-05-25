// MARK: - BASChapter963HostAlignmentSeatTests
// chapter 九百六十三 / M3520 — Phase 3 ch1 tests:HostAlignment seat
//
// Tests for:
//   - BASHostAlignmentSeat (4-rule alignment ladder)
//   - 7-seat dispatcher (Scout/Planner/Memory/Critic/HostAlign/Risk/Surface)
//   - Backward compat (6-seat callers still work)
//   - Single-Writer-Per-Domain:HostAlignment owns .alignmentField,
//     CANNOT write .hostVersion (sovereign-locked critical invariant)
//   - .alignmentField domain enum addition pins

import XCTest
import Foundation
@testable import BASMemory

final class BASChapter963HostAlignmentSeatTests: XCTestCase {

    // MARK: - Helpers

    private func hostAlignAgent() -> BASAgentSpec {
        BASAgentSpec(
            agentID: "hostalign.1",
            role: .hostAlignment,
            writeDomains: [.alignmentField],
            defaultLeaseProfile: .hotSeat,
            visibility: .medium)
    }

    private func makeCandidate(
        id: String,
        touchesAxes: [String] = []
    ) -> BASHostAlignmentCandidate {
        BASHostAlignmentCandidate(
            candidateID: id,
            title: "candidate \(id)",
            touchesAxes: touchesAxes)
    }

    // MARK: - Alignment seat basics

    func testHostAlign_EmptyEmitsZero() {
        var seq = 0
        let d = BASHostAlignmentSeat.emit(
            from: BASHostAlignmentInput(),
            turnID: "t1",
            agentSpec: hostAlignAgent(),
            seq: &seq)
        XCTAssertEqual(d.count, 0)
    }

    func testHostAlign_NoBoundaryAxesAlignedEmitsZero() {
        // Candidate touches axes but host has no protected axes
        // → no concern → no delta
        var seq = 0
        let d = BASHostAlignmentSeat.emit(
            from: BASHostAlignmentInput(
                candidates: [makeCandidate(
                    id: "c1",
                    touchesAxes: ["financial"])],
                hostBoundaryAxes: []),
            turnID: "t1",
            agentSpec: hostAlignAgent(),
            seq: &seq)
        XCTAssertEqual(d.count, 0)
    }

    func testHostAlign_SingleAxisTouchIsAxisTouch() {
        var seq = 0
        let d = BASHostAlignmentSeat.emit(
            from: BASHostAlignmentInput(
                candidates: [makeCandidate(
                    id: "c1",
                    touchesAxes: ["financial"])],
                hostBoundaryAxes: [
                    "financial", "relational",
                ]),
            turnID: "t1",
            agentSpec: hostAlignAgent(),
            seq: &seq)
        XCTAssertEqual(d.count, 1)
        XCTAssertEqual(d[0].confidence, 0.80)
        XCTAssertEqual(
            d[0].targetObjectRef,
            "alignmentField#af-t1-c1")
        XCTAssertTrue(d[0].reasonCodes.contains(
            "hostalign.axis-touch"))
        XCTAssertTrue(d[0].patchJson.contains(
            "\"severity\":\"axisTouch\""))
        XCTAssertTrue(d[0].patchJson.contains(
            "\"touched_axes\":[\"financial\"]"))
    }

    func testHostAlign_MultiAxisTouchIsSevere() {
        var seq = 0
        let d = BASHostAlignmentSeat.emit(
            from: BASHostAlignmentInput(
                candidates: [makeCandidate(
                    id: "c1",
                    touchesAxes: [
                        "financial",
                        "relational",
                        "privacy",
                    ])],
                hostBoundaryAxes: [
                    "financial",
                    "relational",
                    "privacy",
                ]),
            turnID: "t1",
            agentSpec: hostAlignAgent(),
            seq: &seq)
        XCTAssertEqual(d[0].confidence, 0.95)
        XCTAssertTrue(d[0].patchJson.contains(
            "\"severity\":\"multiAxisTouch\""))
        XCTAssertTrue(d[0].reasonCodes.contains {
            $0.hasPrefix("hostalign.touched-count=")
        })
    }

    func testHostAlign_StrictModeStyleNote() {
        // Candidate doesn't touch any axes,but strictness ≥ 0.7
        // → MILD style note for audit
        var seq = 0
        let d = BASHostAlignmentSeat.emit(
            from: BASHostAlignmentInput(
                candidates: [makeCandidate(
                    id: "c1",
                    touchesAxes: ["benign"])],
                hostBoundaryAxes: ["financial"],
                styleStrictness: 0.85),
            turnID: "t1",
            agentSpec: hostAlignAgent(),
            seq: &seq)
        XCTAssertEqual(d.count, 1)
        XCTAssertEqual(d[0].confidence, 0.50)
        XCTAssertTrue(d[0].patchJson.contains(
            "\"severity\":\"styleNote\""))
    }

    func testHostAlign_NonStrictNonTouchEmitsZero() {
        var seq = 0
        let d = BASHostAlignmentSeat.emit(
            from: BASHostAlignmentInput(
                candidates: [makeCandidate(
                    id: "c1",
                    touchesAxes: ["benign"])],
                hostBoundaryAxes: ["financial"],
                styleStrictness: 0.3),
            turnID: "t1",
            agentSpec: hostAlignAgent(),
            seq: &seq)
        XCTAssertEqual(d.count, 0,
            "ch 963: no boundary touch + non-strict → no delta")
    }

    func testHostAlign_OnlyConcerningCandidatesGetDelta() {
        // 3 candidates: clean / single-axis / multi-axis
        var seq = 100
        let d = BASHostAlignmentSeat.emit(
            from: BASHostAlignmentInput(
                candidates: [
                    makeCandidate(id: "clean"),
                    makeCandidate(
                        id: "single",
                        touchesAxes: ["financial"]),
                    makeCandidate(
                        id: "multi",
                        touchesAxes: [
                            "financial", "privacy",
                        ]),
                ],
                hostBoundaryAxes: [
                    "financial", "privacy",
                ]),
            turnID: "t1",
            agentSpec: hostAlignAgent(),
            seq: &seq)
        // 2 of 3 emit (clean has no concern)
        XCTAssertEqual(d.count, 2)
        XCTAssertEqual(seq, 102)
        XCTAssertFalse(d.contains {
            $0.targetObjectRef.contains("clean")
        })
    }

    func testHostAlign_DeterministicSortedAxes() {
        var seq = 0
        // Touched axes in input out of order; payload should
        // emit them sorted for byte-equal hash invariance
        let d = BASHostAlignmentSeat.emit(
            from: BASHostAlignmentInput(
                candidates: [makeCandidate(
                    id: "c1",
                    touchesAxes: [
                        "privacy", "financial",
                    ])],
                hostBoundaryAxes: [
                    "privacy", "financial", "other",
                ]),
            turnID: "t1",
            agentSpec: hostAlignAgent(),
            seq: &seq)
        XCTAssertTrue(d[0].patchJson.contains(
            "\"touched_axes\":[\"financial\",\"privacy\"]"),
            "ch 963: touched_axes sorted in payload for " +
            "byte-equal determinism")
    }

    // MARK: - 7-seat dispatcher

    func testDispatcher_AllSevenSeatsEmit() async {
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
        let input = BASAgentTurnInput(
            turnID: "t1",
            scout: BASScoutInput(
                pressureSignals: ["a"]),
            plannerCandidates: [BASPlannerCandidate(
                candidateID: "c1",
                title: "t",
                actionSummary: "a",
                confidence: 0.8,
                reversibility: 0.9)],
            risk: BASRiskInput(
                candidates: [BASRiskCandidate(
                    candidateID: "c1",
                    reversibility: 0.9)]),
            surface: BASSurfaceInput(
                acceptedCandidateID: "c1",
                riskBand: .low),
            memory: BASMemorySeatInput(
                episodeArcs: ["arc-1"],
                recallStrength: 0.6),
            critic: BASCriticSeatInput(
                candidates: [BASCriticCandidate(
                    candidateID: "c1",
                    title: "t",
                    expectedBenefit: 0.3,
                    expectedCost: 0.5,  // concern
                    reversibility: 0.5)]),
            hostAlignment: BASHostAlignmentInput(
                candidates: [BASHostAlignmentCandidate(
                    candidateID: "c1",
                    title: "t",
                    touchesAxes: ["financial"])],
                hostBoundaryAxes: ["financial"]))
        let graph = BASSharedStateGraph()
        let result = await BASAgentTurnDispatcher.dispatch(
            input: input, roster: roster, graph: graph)
        // Scout 1 + Planner 1 + Memory 1 + Critic 1 +
        // HostAlign 1 + Risk 1 + Surface 1 = 7
        XCTAssertEqual(result.emittedDeltas.count, 7,
            "ch 963: 7-seat dispatcher emits 7 deltas")
        XCTAssertEqual(
            result.mergeResult.acceptedDeltaIDs.count, 7)
        // Verify HostAlign claimed its expected domain
        let alignWriter = await graph.writerForDomain(
            .alignmentField)
        XCTAssertEqual(alignWriter, "h",
            "ch 963: HostAlignment sole writer of .alignmentField")
    }

    // MARK: - Backward compat (6-seat callers still work)

    func testDispatcher_6SeatBackwardCompat() async {
        // No hostAlignment in roster or input → dispatcher skips
        let roster = BASAgentTurnRoster(
            scout: makeAgent("s", .scout, .situationField),
            planner: makeAgent(
                "p", .planner, .candidateFrontier),
            risk: makeAgent("r", .risk, .riskField),
            surface: makeAgent(
                "su", .surface, .renderFrame),
            memory: makeAgent(
                "m", .memory, .memoryBundle),
            critic: makeAgent("c", .critic, .critiqueField))
        XCTAssertNil(roster.hostAlignment)
        let input = BASAgentTurnInput(turnID: "t1")
        XCTAssertNil(input.hostAlignment)
        let result = await BASAgentTurnDispatcher.dispatch(
            input: input,
            roster: roster,
            graph: BASSharedStateGraph())
        // No hostalign deltas emitted
        XCTAssertFalse(result.emittedDeltas.contains {
            $0.targetObjectRef.contains("alignmentField")
        })
    }

    // MARK: - CRITICAL Single-Writer invariant (sovereign-locked)

    func testHostAlignCannotWriteHostVersion() async {
        // Per Single-Writer table: hostVersion is sovereign-locked
        // (L5 + L14 only)。 HostAlignment MUST NOT have it in
        // writeDomains AND MUST be rejected by the graph if it
        // tries。
        let align = hostAlignAgent()
        XCTAssertFalse(
            align.writeDomains.contains(.hostVersion),
            "ch 963 CRITICAL: HostAlignment must NOT have " +
            ".hostVersion in writeDomains")
        // Graph enforcement: even if writeDomains were wrong,
        // global writer registry rejects
        let graph = BASSharedStateGraph()
        do {
            _ = try await graph.writeObject(
                domain: .hostVersion,
                objectID: "hv-1",
                payloadJson: "{}",
                byAgent: align)
            XCTFail("ch 963 CRITICAL: HostAlignment write to " +
                ".hostVersion MUST be rejected by Single-Writer")
        } catch let e as BASSharedStateGraphError {
            // unauthorizedWriter expected (writeDomains check)
            guard case .unauthorizedWriter = e else {
                XCTFail("expected unauthorizedWriter,got \(e)")
                return
            }
        } catch {
            XCTFail("unexpected: \(error)")
        }
    }

    func testHostAlignCannotWriteSovereignVerdict() async {
        // Same invariant for .sovereignVerdict (L14 NO write)
        let align = hostAlignAgent()
        XCTAssertFalse(
            align.writeDomains.contains(.sovereignVerdict))
        let graph = BASSharedStateGraph()
        do {
            _ = try await graph.writeObject(
                domain: .sovereignVerdict,
                objectID: "sv-1",
                payloadJson: "{}",
                byAgent: align)
            XCTFail("ch 963 CRITICAL: HostAlignment write to " +
                ".sovereignVerdict MUST be rejected")
        } catch let e as BASSharedStateGraphError {
            guard case .unauthorizedWriter = e else {
                XCTFail("expected unauthorizedWriter")
                return
            }
        } catch {
            XCTFail("unexpected: \(error)")
        }
    }

    func testAlignmentFieldDomainExists() {
        // Pin: ch 963 added .alignmentField
        XCTAssertTrue(
            BASStateDomain.allCases.contains(.alignmentField),
            "ch 963: .alignmentField domain must exist")
        // Count: 11 (10 from ch 961 + 1 from ch 963)
        XCTAssertEqual(
            BASStateDomain.allCases.count, 11,
            "ch 963: domain count is 11 after .alignmentField add")
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
