// MARK: - BASChapter965EvolutionShadowSeatTests
// chapter 九百六十五 / M3530 — Phase 3 close tests:EvolutionShadow seat
//
// Test scope:
//   1. Empty input → 0 deltas (no proposal noise on quiet turns)
//   2. UpdateTicket emission (1 delta per ticket, .add deltaType)
//   3. RuleCandidate emission
//   4. HostChangeCandidate emission (with sovereign-adjacent marker)
//   5. Confidence ladder per cluster matches plan
//   6. Multi-cluster turn emits expected delta count
//   7. CRITICAL Single-Writer invariants:
//        a. EvolutionShadow CAN write .evolutionProposal
//        b. EvolutionShadow CANNOT write .hostVersion (sovereign-locked)
//        c. EvolutionShadow CANNOT write any other domain
//        d. No other seat agent (Planner, Risk, Memory, etc.) can write
//           .evolutionProposal
//   8. NEVER-effective-same-turn invariant:no in-turn seat consumes
//      `.evolutionProposal` — verified by inspecting dispatcher
//      apply outcomes
//   9. Sovereign-adjacent marker present on host-change candidate payloads
//   10. Reason codes include `evolution.deferred=shadow-trial` audit marker
//   11. 9-seat dispatcher integration (all seats wired)
//   12. 8-seat backward compat (no evolution shadow → no evolution deltas)
//   13. Deterministic payload encoding (byte-equal for same input)
//   14. Coexistence: SovereignSentinel still sole writer of .sovereignVerdict
//       even when EvolutionShadow active

import XCTest
import Foundation
@testable import BASMemory

final class BASChapter965EvolutionShadowSeatTests: XCTestCase {

    // MARK: - Helpers

    private func evolutionAgent() -> BASAgentSpec {
        BASAgentSpec(
            agentID: "evolution.1",
            role: .evolutionShadow,
            writeDomains: [.evolutionProposal],
            forbiddenDomains: [
                // CRITICAL: evolution shadow MUST NOT touch host-version
                // or sovereign-verdict — these are sovereign-locked per
                // Single-Writer table
                .hostVersion,
                .sovereignVerdict,
            ],
            defaultLeaseProfile: .coldSeat,
            visibility: .medium)  // MED tier per plan
    }

    // MARK: - 1. Empty input

    func testEvolution_EmptyEmitsZero() {
        var seq = 0
        let d = BASEvolutionShadowSeat.emit(
            from: BASEvolutionShadowInput(),
            turnID: "t1",
            agentSpec: evolutionAgent(),
            seq: &seq)
        XCTAssertEqual(d.count, 0,
            "ch 965: empty input → no deltas (quiet turns " +
            "stay quiet)")
        XCTAssertEqual(seq, 0,
            "ch 965: seq counter unchanged on no-emit")
    }

    func testEvolution_InputIsEmptyHelper() {
        XCTAssertTrue(BASEvolutionShadowInput().isEmpty)
        XCTAssertFalse(BASEvolutionShadowInput(
            updateTickets: [BASEvolutionUpdateTicket(
                ticketID: "t1",
                targetRef: "rule.x",
                summary: "tweak")]).isEmpty)
    }

    // MARK: - 2. UpdateTicket emission

    func testEvolution_UpdateTicketEmission() {
        var seq = 0
        let ticket = BASEvolutionUpdateTicket(
            ticketID: "tk1",
            targetRef: "rule.risk.escalate",
            summary: "raise threshold by 0.05",
            scopeImpact: 0.4)
        let d = BASEvolutionShadowSeat.emit(
            from: BASEvolutionShadowInput(
                updateTickets: [ticket]),
            turnID: "t1",
            agentSpec: evolutionAgent(),
            seq: &seq)
        XCTAssertEqual(d.count, 1)
        let delta = d[0]
        XCTAssertEqual(delta.agentID, "evolution.1")
        XCTAssertEqual(delta.deltaType, .add,
            "ch 965: tickets use .add (new proposal doc, " +
            "never overwrite prior turn's)")
        XCTAssertTrue(
            delta.targetObjectRef.hasPrefix(
                "evolutionProposal#ticket-t1-"))
        XCTAssertTrue(
            delta.targetObjectRef.contains("tk1"))
        // Confidence: 0.5 + 0.3 * 0.4 = 0.62
        XCTAssertEqual(
            delta.confidence, 0.62, accuracy: 0.0001)
        XCTAssertTrue(
            delta.patchJson.contains("\"ticket_id\":\"tk1\""))
        XCTAssertTrue(
            delta.patchJson.contains(
                "\"target_ref\":\"rule.risk.escalate\""))
        XCTAssertTrue(
            delta.reasonCodes.contains(
                "evolution.update-ticket"))
        XCTAssertTrue(
            delta.reasonCodes.contains(
                "evolution.deferred=shadow-trial"))
    }

    // MARK: - 3. RuleCandidate emission

    func testEvolution_RuleCandidateEmission() {
        var seq = 0
        let cand = BASEvolutionRuleCandidate(
            candidateID: "r1",
            ruleBody: "IF pressure_signals > 5 THEN escalate",
            supportStrength: 0.8)
        let d = BASEvolutionShadowSeat.emit(
            from: BASEvolutionShadowInput(
                ruleCandidates: [cand]),
            turnID: "t1",
            agentSpec: evolutionAgent(),
            seq: &seq)
        XCTAssertEqual(d.count, 1)
        let delta = d[0]
        XCTAssertTrue(
            delta.targetObjectRef.hasPrefix(
                "evolutionProposal#rule-t1-"))
        // Confidence: 0.4 + 0.5 * 0.8 = 0.8
        XCTAssertEqual(
            delta.confidence, 0.8, accuracy: 0.0001)
        XCTAssertTrue(
            delta.patchJson.contains(
                "\"candidate_id\":\"r1\""))
        XCTAssertTrue(
            delta.reasonCodes.contains(
                "evolution.rule-candidate"))
    }

    // MARK: - 4. HostChangeCandidate emission + sovereign-adjacent

    func testEvolution_HostChangeCandidateEmission() {
        var seq = 0
        let cand = BASEvolutionHostChangeCandidate(
            candidateID: "hc1",
            targetAxis: "tone.warmth",
            proposedSummary: "soften default cool tone",
            directionScore: 0.6)
        let d = BASEvolutionShadowSeat.emit(
            from: BASEvolutionShadowInput(
                hostChangeCandidates: [cand]),
            turnID: "t1",
            agentSpec: evolutionAgent(),
            seq: &seq)
        XCTAssertEqual(d.count, 1)
        let delta = d[0]
        XCTAssertTrue(
            delta.targetObjectRef.hasPrefix(
                "evolutionProposal#hostchange-t1-"))
        // Confidence: 0.3 + 0.5 * 0.6 = 0.6 (lowest base —
        // sovereign-adjacent gets most ShadowTrial scrutiny)
        XCTAssertEqual(
            delta.confidence, 0.6, accuracy: 0.0001)
        // CRITICAL sovereign-adjacent marker
        XCTAssertTrue(
            delta.patchJson.contains(
                "\"sovereign_adjacent\":true"),
            "ch 965 CRITICAL: host-change candidate MUST " +
            "carry sovereign_adjacent marker in payload")
        XCTAssertTrue(
            delta.patchJson.contains(
                "\"deferred\":\"shadow-trial\""))
        XCTAssertTrue(
            delta.reasonCodes.contains(
                "evolution.sovereign-adjacent=true"),
            "ch 965 CRITICAL: host-change candidate MUST " +
            "carry sovereign-adjacent reason code")
    }

    // MARK: - 5. Confidence ladder

    func testEvolution_ConfidenceLadderTicket() {
        for impact in [0.0, 0.5, 1.0] {
            var seq = 0
            let d = BASEvolutionShadowSeat.emit(
                from: BASEvolutionShadowInput(
                    updateTickets: [BASEvolutionUpdateTicket(
                        ticketID: "t",
                        targetRef: "r",
                        summary: "s",
                        scopeImpact: impact)]),
                turnID: "t1",
                agentSpec: evolutionAgent(),
                seq: &seq)
            let expected = 0.5 + 0.3 * impact
            XCTAssertEqual(
                d[0].confidence, expected, accuracy: 0.0001,
                "ch 965: ticket confidence ladder at " +
                "impact=\(impact)")
        }
    }

    func testEvolution_ConfidenceCappedAtOne() {
        // Ticket at impact=10.0 should still cap at 1.0
        var seq = 0
        let d = BASEvolutionShadowSeat.emit(
            from: BASEvolutionShadowInput(
                updateTickets: [BASEvolutionUpdateTicket(
                    ticketID: "t",
                    targetRef: "r",
                    summary: "s",
                    scopeImpact: 10.0)]),
            turnID: "t1",
            agentSpec: evolutionAgent(),
            seq: &seq)
        XCTAssertEqual(d[0].confidence, 1.0,
            "ch 965: confidence MUST be clamped at 1.0")
    }

    func testEvolution_ConfidenceFloorAtZero() {
        // Rule at supportStrength=-10 → 0.4 + 0.5 * -10 = -4.6
        // clamped to 0
        var seq = 0
        let d = BASEvolutionShadowSeat.emit(
            from: BASEvolutionShadowInput(
                ruleCandidates: [BASEvolutionRuleCandidate(
                    candidateID: "r",
                    ruleBody: "x",
                    supportStrength: -10.0)]),
            turnID: "t1",
            agentSpec: evolutionAgent(),
            seq: &seq)
        XCTAssertEqual(d[0].confidence, 0.0,
            "ch 965: confidence MUST be clamped at 0.0")
    }

    // MARK: - 6. Multi-cluster turn

    func testEvolution_MultiClusterTurn() {
        var seq = 0
        let d = BASEvolutionShadowSeat.emit(
            from: BASEvolutionShadowInput(
                updateTickets: [
                    BASEvolutionUpdateTicket(
                        ticketID: "tk1",
                        targetRef: "r1",
                        summary: "s1"),
                    BASEvolutionUpdateTicket(
                        ticketID: "tk2",
                        targetRef: "r2",
                        summary: "s2"),
                ],
                ruleCandidates: [BASEvolutionRuleCandidate(
                    candidateID: "r1", ruleBody: "x")],
                hostChangeCandidates: [
                    BASEvolutionHostChangeCandidate(
                        candidateID: "hc1",
                        targetAxis: "ax",
                        proposedSummary: "ps")]),
            turnID: "t1",
            agentSpec: evolutionAgent(),
            seq: &seq)
        XCTAssertEqual(d.count, 4,
            "ch 965: 2 tickets + 1 rule + 1 host = 4 deltas")
        XCTAssertEqual(seq, 4)
        // All deltas have evolution agent + .add type
        for delta in d {
            XCTAssertEqual(delta.agentID, "evolution.1")
            XCTAssertEqual(delta.deltaType, .add)
            XCTAssertTrue(
                delta.targetObjectRef.hasPrefix(
                    "evolutionProposal#"))
        }
    }

    // MARK: - 7. CRITICAL Single-Writer invariants

    func testCRITICAL_EvolutionShadowCanWriteEvolutionProposal() async {
        let evo = evolutionAgent()
        XCTAssertTrue(evo.writeDomains.contains(
            .evolutionProposal))
        let graph = BASSharedStateGraph()
        let obj = try? await graph.writeObject(
            domain: .evolutionProposal,
            objectID: "ep-test",
            payloadJson: "{}",
            byAgent: evo)
        XCTAssertNotNil(obj,
            "ch 965 CRITICAL: EvolutionShadow MUST be able " +
            "to write .evolutionProposal")
    }

    func testCRITICAL_EvolutionShadowCannotWriteHostVersion() async {
        // The most important invariant of this seat —
        // EvolutionShadow MUST NOT bypass L5+L14 sovereign
        // lock on host constitution mutation
        let evo = evolutionAgent()
        XCTAssertFalse(evo.writeDomains.contains(.hostVersion),
            "ch 965 CRITICAL: EvolutionShadow writeDomains " +
            "MUST NOT contain .hostVersion (sovereign-locked)")
        let graph = BASSharedStateGraph()
        do {
            _ = try await graph.writeObject(
                domain: .hostVersion,
                objectID: "hv-attempt",
                payloadJson: "{}",
                byAgent: evo)
            XCTFail("ch 965 CRITICAL: EvolutionShadow MUST " +
                "NOT be able to write .hostVersion (only " +
                "L5+L14 own this — L13 proposes only)")
        } catch let e as BASSharedStateGraphError {
            // Either forbiddenDomains OR unauthorizedWriter
            // is acceptable — both block the write
            switch e {
            case .forbiddenDomain, .unauthorizedWriter:
                break  // expected
            default:
                XCTFail("ch 965 CRITICAL: expected " +
                    "forbiddenDomain or unauthorizedWriter, " +
                    "got \(e)")
            }
        } catch {
            XCTFail("unexpected: \(error)")
        }
    }

    func testCRITICAL_EvolutionShadowCannotWriteSovereignVerdict() async {
        // Same protection — sovereign verdict belongs to L14
        // SovereignSentinel exclusively
        let evo = evolutionAgent()
        XCTAssertFalse(evo.writeDomains.contains(
            .sovereignVerdict))
        let graph = BASSharedStateGraph()
        do {
            _ = try await graph.writeObject(
                domain: .sovereignVerdict,
                objectID: "sv-attempt",
                payloadJson: "{}",
                byAgent: evo)
            XCTFail("ch 965 CRITICAL: EvolutionShadow MUST " +
                "NOT be able to write .sovereignVerdict")
        } catch let e as BASSharedStateGraphError {
            switch e {
            case .forbiddenDomain, .unauthorizedWriter:
                break  // expected
            default:
                XCTFail("expected block, got \(e)")
            }
        } catch {
            XCTFail("unexpected: \(error)")
        }
    }

    func testCRITICAL_EvolutionShadowCannotWriteAnyOtherDomain() async {
        // Sweep ALL other domains except .evolutionProposal —
        // EvolutionShadow MUST fail to write each one
        let evo = evolutionAgent()
        let otherDomains = BASStateDomain.allCases.filter {
            $0 != .evolutionProposal
        }
        XCTAssertEqual(otherDomains.count, 11,
            "ch 965: 12 total domains - 1 (evolutionProposal) = 11")
        for domain in otherDomains {
            let graph = BASSharedStateGraph()
            do {
                _ = try await graph.writeObject(
                    domain: domain,
                    objectID: "test",
                    payloadJson: "{}",
                    byAgent: evo)
                XCTFail("ch 965 CRITICAL: EvolutionShadow " +
                    "MUST NOT write \(domain) (only " +
                    ".evolutionProposal allowed)")
            } catch is BASSharedStateGraphError {
                // expected
            } catch {
                XCTFail("ch 965 unexpected error for " +
                    "\(domain): \(error)")
            }
        }
    }

    func testCRITICAL_NoOtherAgentCanWriteEvolutionProposal() async {
        // Symmetric to ch 964 sentinel test:Planner / Risk /
        // Surface / HostAlign / Memory / Critic CANNOT write
        // .evolutionProposal
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
                agentID: "memory.imp",
                role: .memory,
                writeDomains: [.memoryBundle],
                defaultLeaseProfile: .hotSeat,
                visibility: .high),
            BASAgentSpec(
                agentID: "critic.imp",
                role: .critic,
                writeDomains: [.critiqueField],
                defaultLeaseProfile: .hotSeat,
                visibility: .high),
            BASAgentSpec(
                agentID: "hostalign.imp",
                role: .hostAlignment,
                writeDomains: [.alignmentField],
                defaultLeaseProfile: .hotSeat,
                visibility: .medium),
            BASAgentSpec(
                agentID: "surface.imp",
                role: .surface,
                writeDomains: [.renderFrame],
                defaultLeaseProfile: .hotSeat,
                visibility: .high),
            BASAgentSpec(
                agentID: "sentinel.imp",
                role: .sovereignSentinel,
                writeDomains: [.sovereignVerdict],
                defaultLeaseProfile: .sovereign,
                visibility: .low),
        ]
        for imp in imposters {
            let graph = BASSharedStateGraph()
            do {
                _ = try await graph.writeObject(
                    domain: .evolutionProposal,
                    objectID: "imp",
                    payloadJson: "{}",
                    byAgent: imp)
                XCTFail("ch 965 CRITICAL: \(imp.role) MUST " +
                    "NOT be able to write .evolutionProposal " +
                    "(only EvolutionShadow owns it)")
            } catch let e as BASSharedStateGraphError {
                guard case .unauthorizedWriter = e else {
                    XCTFail("expected unauthorizedWriter " +
                        "got \(e) for \(imp.role)")
                    return
                }
            } catch {
                XCTFail("unexpected: \(error)")
            }
        }
    }

    // MARK: - 8. NEVER-effective-same-turn invariant

    func testCRITICAL_EvolutionProposalsNeverConsumedSameTurn() async {
        // Build a turn with EvolutionShadow active alongside
        // all other seats。 Verify that NO seat-emitted delta
        // OTHER than the evolution shadow's targets
        // .evolutionProposal — i.e. no in-turn consumer
        let roster = nineSeatRoster()
        let input = BASAgentTurnInput(
            turnID: "t1",
            scout: BASScoutInput(
                pressureSignals: ["a"]),
            plannerCandidates: [BASPlannerCandidate(
                candidateID: "c1",
                title: "t",
                actionSummary: "a",
                confidence: 0.8,
                reversibility: 0.7)],
            risk: BASRiskInput(
                candidates: [BASRiskCandidate(
                    candidateID: "c1",
                    reversibility: 0.7)]),
            surface: BASSurfaceInput(
                acceptedCandidateID: "c1",
                riskBand: .low,
                reversibility: 0.7),
            memory: BASMemorySeatInput(
                episodeArcs: ["arc-1"],
                recallStrength: 0.5),
            critic: BASCriticSeatInput(
                candidates: [BASCriticCandidate(
                    candidateID: "c1",
                    title: "t",
                    expectedBenefit: 0.7,
                    expectedCost: 0.2,
                    reversibility: 0.7)]),
            hostAlignment: BASHostAlignmentInput(
                candidates: [BASHostAlignmentCandidate(
                    candidateID: "c1",
                    title: "t",
                    touchesAxes: [])],
                hostBoundaryAxes: []),
            sovereignSentinel:
                BASSovereignSentinelInput(
                    candidates: [
                        BASSovereignSentinelCandidate(
                            candidateID: "c1",
                            title: "t",
                            reversibility: 0.7)]),
            evolutionShadow: BASEvolutionShadowInput(
                updateTickets: [BASEvolutionUpdateTicket(
                    ticketID: "tk1",
                    targetRef: "r1",
                    summary: "s1")]))
        let graph = BASSharedStateGraph()
        let result = await BASAgentTurnDispatcher.dispatch(
            input: input, roster: roster, graph: graph)
        // Find deltas targeting .evolutionProposal
        let evoDeltas = result.emittedDeltas.filter {
            $0.targetObjectRef.hasPrefix(
                "evolutionProposal#")
        }
        XCTAssertGreaterThanOrEqual(evoDeltas.count, 1,
            "ch 965: evolution shadow emitted at least 1 delta")
        // All evolution deltas authored by evolution agent
        for d in evoDeltas {
            XCTAssertEqual(d.agentID, "evolution.1",
                "ch 965 CRITICAL: only EvolutionShadow can " +
                "author deltas to .evolutionProposal " +
                "(observed authorship of \(d.agentID))")
        }
        // No OTHER agent emitted to .evolutionProposal
        let nonEvoToEvolution = result.emittedDeltas.filter {
            $0.targetObjectRef.hasPrefix(
                "evolutionProposal#") &&
            $0.agentID != "evolution.1"
        }
        XCTAssertEqual(nonEvoToEvolution.count, 0,
            "ch 965 CRITICAL: no non-shadow agent emitted " +
            "to .evolutionProposal this turn")
    }

    // MARK: - 9. Sovereign-adjacent marker

    func testEvolution_HostChangeAlwaysCarriesSovereignAdjacentMarker() {
        // Even at directionScore=0 (purely defensive proposal)
        // the marker MUST be present — it's not gated by
        // direction or impact
        var seq = 0
        let d = BASEvolutionShadowSeat.emit(
            from: BASEvolutionShadowInput(
                hostChangeCandidates: [
                    BASEvolutionHostChangeCandidate(
                        candidateID: "hc",
                        targetAxis: "tone",
                        proposedSummary: "tighten",
                        directionScore: 0.0)]),
            turnID: "t1",
            agentSpec: evolutionAgent(),
            seq: &seq)
        XCTAssertTrue(
            d[0].patchJson.contains(
                "\"sovereign_adjacent\":true"))
        XCTAssertTrue(
            d[0].reasonCodes.contains(
                "evolution.sovereign-adjacent=true"))
    }

    // MARK: - 10. Audit-marker reason codes

    func testEvolution_AllEmissionsCarryDeferredMarker() {
        var seq = 0
        let d = BASEvolutionShadowSeat.emit(
            from: BASEvolutionShadowInput(
                updateTickets: [BASEvolutionUpdateTicket(
                    ticketID: "tk", targetRef: "r",
                    summary: "s")],
                ruleCandidates: [BASEvolutionRuleCandidate(
                    candidateID: "rc", ruleBody: "x")],
                hostChangeCandidates: [
                    BASEvolutionHostChangeCandidate(
                        candidateID: "hc",
                        targetAxis: "ax",
                        proposedSummary: "ps")]),
            turnID: "t1",
            agentSpec: evolutionAgent(),
            seq: &seq)
        XCTAssertEqual(d.count, 3)
        // Every delta carries the never-effective-same-turn
        // audit marker for the trace replay engine
        for delta in d {
            XCTAssertTrue(
                delta.reasonCodes.contains(
                    "evolution.deferred=shadow-trial"),
                "ch 965 AUDIT: every evolution delta MUST " +
                "carry the deferred=shadow-trial marker for " +
                "replay engine attribution")
        }
    }

    // MARK: - 11. 9-seat dispatcher

    func testDispatcher_NineSeatsEmit() async {
        let roster = nineSeatRoster()
        let input = makeFullNineSeatInput()
        let graph = BASSharedStateGraph()
        let result = await BASAgentTurnDispatcher.dispatch(
            input: input, roster: roster, graph: graph)
        // Scout 2 (pressure + manip) + Planner 1 + Memory 1 +
        // Critic 1 + HostAlign 1 + Risk 1 + Surface 1 +
        // Sentinel 1 + Evolution 1 = 10 ≥ minimum
        XCTAssertGreaterThanOrEqual(
            result.emittedDeltas.count, 10,
            "ch 965: 9-seat dispatch emits at least 10 deltas")
        // Evolution shadow claimed .evolutionProposal as writer
        let evoWriter = await graph.writerForDomain(
            .evolutionProposal)
        XCTAssertEqual(evoWriter, "evolution.1",
            "ch 965 CRITICAL: EvolutionShadow is sole " +
            "writer of .evolutionProposal in 9-seat dispatch")
    }

    func testDispatcher_NineSeatRosterAgentMap() {
        let roster = nineSeatRoster()
        let m = roster.agentMap
        // 9 distinct agentIDs
        XCTAssertEqual(m.count, 9)
        XCTAssertNotNil(m["evolution.1"])
        XCTAssertEqual(
            m["evolution.1"]?.role, .evolutionShadow)
    }

    // MARK: - 12. 8-seat backward compat

    func testDispatcher_8SeatBackwardCompat() async {
        // No evolution shadow in roster or input →
        // dispatcher skips, no evolution deltas
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
                "h", .hostAlignment, .alignmentField),
            sovereignSentinel: makeAgent(
                "sov", .sovereignSentinel, .sovereignVerdict))
        XCTAssertNil(roster.evolutionShadow,
            "ch 965: 8-seat backward-compat roster has " +
            "no evolutionShadow")
        let input = BASAgentTurnInput(turnID: "t1")
        XCTAssertNil(input.evolutionShadow)
        let result = await BASAgentTurnDispatcher.dispatch(
            input: input,
            roster: roster,
            graph: BASSharedStateGraph())
        XCTAssertFalse(result.emittedDeltas.contains {
            $0.targetObjectRef.contains("evolutionProposal")
        })
    }

    func testDispatcher_PreCh965FourSeatStillCompiles() async {
        // Smallest dispatcher caller — pre-ch 961 (4 seats only)
        let roster = BASAgentTurnRoster(
            scout: makeAgent("s", .scout, .situationField),
            planner: makeAgent(
                "p", .planner, .candidateFrontier),
            risk: makeAgent("r", .risk, .riskField),
            surface: makeAgent(
                "su", .surface, .renderFrame))
        let input = BASAgentTurnInput(turnID: "t1")
        let graph = BASSharedStateGraph()
        let result = await BASAgentTurnDispatcher.dispatch(
            input: input, roster: roster, graph: graph)
        // 4-seat call still works — no evolution emitted
        XCTAssertFalse(result.emittedDeltas.contains {
            $0.targetObjectRef.contains("evolutionProposal")
        })
    }

    // MARK: - 13. Deterministic payload encoding

    func testEvolution_DeterministicPayloadByteEqual() {
        // Two calls with same input should produce
        // byte-equal payloads for trace replay
        let input = BASEvolutionShadowInput(
            updateTickets: [BASEvolutionUpdateTicket(
                ticketID: "tk",
                targetRef: "r",
                summary: "s",
                scopeImpact: 0.7)],
            ruleCandidates: [BASEvolutionRuleCandidate(
                candidateID: "rc",
                ruleBody: "body",
                supportStrength: 0.4)],
            hostChangeCandidates: [
                BASEvolutionHostChangeCandidate(
                    candidateID: "hc",
                    targetAxis: "ax",
                    proposedSummary: "ps",
                    directionScore: 0.2)])
        var seq1 = 0
        var seq2 = 0
        let d1 = BASEvolutionShadowSeat.emit(
            from: input, turnID: "t1",
            agentSpec: evolutionAgent(), seq: &seq1)
        let d2 = BASEvolutionShadowSeat.emit(
            from: input, turnID: "t1",
            agentSpec: evolutionAgent(), seq: &seq2)
        XCTAssertEqual(d1.count, d2.count)
        for (a, b) in zip(d1, d2) {
            XCTAssertEqual(a.patchJson, b.patchJson,
                "ch 965: payloads MUST be byte-equal for " +
                "same input (trace replay invariant)")
            XCTAssertEqual(a.targetObjectRef, b.targetObjectRef)
            XCTAssertEqual(a.deltaID, b.deltaID)
            XCTAssertEqual(a.reasonCodes, b.reasonCodes)
        }
    }

    // MARK: - 14. Coexistence with SovereignSentinel

    func testCoexistence_SentinelStillSoleWriterOfSovereignVerdict() async {
        // Add evolution shadow → ensure ch 964 invariant
        // (sentinel sole writer of .sovereignVerdict) holds
        let roster = nineSeatRoster()
        let input = makeFullNineSeatInput()
        let graph = BASSharedStateGraph()
        _ = await BASAgentTurnDispatcher.dispatch(
            input: input, roster: roster, graph: graph)
        let sovWriter = await graph.writerForDomain(
            .sovereignVerdict)
        XCTAssertEqual(sovWriter, "sentinel.1",
            "ch 965 CRITICAL: adding EvolutionShadow MUST " +
            "NOT disrupt ch 964 invariant — Sentinel still " +
            "sole writer of .sovereignVerdict")
    }

    // MARK: - 15. Visibility tier discipline

    func testEvolution_VisibilityIsMediumOrLow() {
        // Per plan: EvolutionShadow is MED tier (style + cadence
        // only)。 Per ch 944 audit historically:may also be LOW
        // if host wants to seal it。 NEVER HIGH (no full
        // user customization of evolution selection logic)。
        let evo = evolutionAgent()
        XCTAssertNotEqual(
            evo.visibility, .high,
            "ch 965 CRITICAL: EvolutionShadow visibility " +
            "MUST NOT be .high (no user customization of " +
            "the proposal SELECTION logic — only cadence)")
        XCTAssertTrue(
            evo.visibility == .medium ||
            evo.visibility == .low,
            "ch 965: EvolutionShadow visibility MUST be " +
            ".medium or .low (got \(evo.visibility))")
    }

    func testEvolution_LeaseProfileIsColdSeat() {
        // Per plan ch 953 lease profile mapping:evolution
        // is a coldSeat (cold-start on demand,larger budget,
        // not always-warm)
        let evo = evolutionAgent()
        XCTAssertEqual(
            evo.defaultLeaseProfile, .coldSeat,
            "ch 965: EvolutionShadow profile MUST be .coldSeat " +
            "per Section 13.3 hot/cold tier mapping")
    }

    // MARK: - Helpers

    private func makeAgent(
        _ id: String,
        _ role: BASAgentRole,
        _ domain: BASStateDomain
    ) -> BASAgentSpec {
        let visibility: BASAgentVisibility = {
            if role == .sovereignSentinel { return .low }
            if role == .evolutionShadow { return .medium }
            if role == .hostAlignment { return .medium }
            return .high
        }()
        let profile: BASAgentLeaseProfile = {
            if role == .sovereignSentinel { return .sovereign }
            if role == .evolutionShadow { return .coldSeat }
            return .hotSeat
        }()
        return BASAgentSpec(
            agentID: id, role: role,
            writeDomains: [domain],
            defaultLeaseProfile: profile,
            visibility: visibility)
    }

    private func nineSeatRoster() -> BASAgentTurnRoster {
        BASAgentTurnRoster(
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
                "h", .hostAlignment, .alignmentField),
            sovereignSentinel: BASAgentSpec(
                agentID: "sentinel.1",
                role: .sovereignSentinel,
                writeDomains: [.sovereignVerdict],
                defaultLeaseProfile: .sovereign,
                visibility: .low),
            evolutionShadow: evolutionAgent())
    }

    private func makeFullNineSeatInput() -> BASAgentTurnInput {
        BASAgentTurnInput(
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
                    candidates: [
                        BASSovereignSentinelCandidate(
                            candidateID: "c1",
                            title: "t",
                            reversibility: 0.5)],
                    manipulationDetected: true),
            evolutionShadow: BASEvolutionShadowInput(
                updateTickets: [BASEvolutionUpdateTicket(
                    ticketID: "tk1",
                    targetRef: "r1",
                    summary: "s1",
                    scopeImpact: 0.4)],
                hostChangeCandidates: [
                    BASEvolutionHostChangeCandidate(
                        candidateID: "hc1",
                        targetAxis: "tone.warmth",
                        proposedSummary: "soften default",
                        directionScore: 0.5)]))
    }
}
