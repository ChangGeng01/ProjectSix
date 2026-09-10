// MARK: - BASEvolutionShadowSeat
// chapter 九百六十五 / M3530 — Phase 3 close:EvolutionShadow seat
//
// User design Section 9.5 + Single-Writer table + plan PHASE 3 ch3:
// EvolutionShadow wraps `evolutionService` and emits proposals for
// the NEW `.evolutionProposal` domain — UpdateTicket / RuleCandidate /
// HostChangeCandidate。 Per plan invariant + Root Law 4 (单主权):
//
//   *** NEVER EFFECTIVE SAME TURN ***
//
// EvolutionShadow's proposals are CONSUMED by the future async
// ShadowTrial pipeline,NOT by any in-turn seat。 No other seat in
// the canonical 9-seat order reads `.evolutionProposal` — the
// dispatcher's apply step just persists the deltas;ShadowTrial
// picks them up across turns。 This invariant is verified in the
// ch 965 test suite via dispatcher-level inspection。
//
// ## CRITICAL Single-Writer invariants
//
// Per plan Single-Writer table:
//   `hostVersion → L5 + L14 (L13 proposes only)`
//
// EvolutionShadow CANNOT write `.hostVersion` — its `writeDomains`
// MUST contain ONLY `.evolutionProposal`。 Any attempt to write
// `.hostVersion` from EvolutionShadow MUST be rejected by the
// graph actor (per ch 956.5 USER-PASS gap #1 / ch 956.11 CR2
// global writer registry)。 The ch 965 test suite has 2 dedicated
// CRITICAL tests for this:
//   1. testCRITICAL_EvolutionShadowCannotWriteHostVersion
//   2. testCRITICAL_EvolutionShadowIsSoleWriterOfEvolutionProposal
//
// ## MED visibility tier
//
// Per the plan's 3-tier visibility table:
//   - MED tier:partial customization (style + cadence only)
//
// EvolutionShadow agents SHOULD have `.medium` visibility — Phase 4
// Persona Studio will let users tune the cadence (proposal frequency
// / boldness) but NOT the proposal SELECTION logic itself。
//
// ## Design discipline
//
// Same pure-fn + slim-DTO pattern as ch 957-964 seats。 EvolutionShadow
// does NOT directly import any L5/L13/L14 evolution service — the
// coordinator adapter builds the slim DTO from the live evolution
// service output。 Keeps BASMemory independent of BASHostKit。

import Foundation

// MARK: - Proposal cluster DTOs

/// One UpdateTicket — incremental update proposal for an existing
/// rule / threshold / template。 Driven by the future evolution
/// service's drift detector。
public struct BASEvolutionUpdateTicket:
    Sendable, Equatable, Hashable, Codable
{
    public let ticketID: String
    /// Target rule / threshold / template being updated
    public let targetRef: String
    /// Short human-readable summary (audit trail)
    public let summary: String
    /// 0.0 = trivial cosmetic, 1.0 = major behavior shift
    public let scopeImpact: Double

    public init(
        ticketID: String,
        targetRef: String,
        summary: String,
        scopeImpact: Double = 0.5
    ) {
        self.ticketID = ticketID
        self.targetRef = targetRef
        self.summary = summary
        self.scopeImpact = scopeImpact
    }
}

/// One RuleCandidate — proposal for a NEW rule / heuristic the
/// evolution service derived from recent turns。
public struct BASEvolutionRuleCandidate:
    Sendable, Equatable, Hashable, Codable
{
    public let candidateID: String
    /// Symbolic rule body (audit trail — no execution semantics
    /// at this layer)
    public let ruleBody: String
    /// 0.0 = weak signal, 1.0 = strong observed support
    public let supportStrength: Double

    public init(
        candidateID: String,
        ruleBody: String,
        supportStrength: Double = 0.0
    ) {
        self.candidateID = candidateID
        self.ruleBody = ruleBody
        self.supportStrength = supportStrength
    }
}

/// One HostChangeCandidate — proposal to amend the host
/// constitution。 Per plan invariant L13 proposes only;the
/// actual write happens at L5 + L14。 EvolutionShadow emits the
/// CANDIDATE to `.evolutionProposal`,never to `.hostVersion`。
public struct BASEvolutionHostChangeCandidate:
    Sendable, Equatable, Hashable, Codable
{
    public let candidateID: String
    /// Which axis / field of the host constitution is being
    /// proposed for change
    public let targetAxis: String
    /// Proposed new value summary (audit trail)
    public let proposedSummary: String
    /// 0.0 = tightening / safer, 1.0 = loosening / riskier
    public let directionScore: Double

    public init(
        candidateID: String,
        targetAxis: String,
        proposedSummary: String,
        directionScore: Double = 0.0
    ) {
        self.candidateID = candidateID
        self.targetAxis = targetAxis
        self.proposedSummary = proposedSummary
        self.directionScore = directionScore
    }
}

// MARK: - Input bundle

/// Slim DTO carrying the 3 proposal-cluster inputs for the
/// EvolutionShadow seat。 Built by the coordinator adapter from
/// the live `evolutionService` output。 Empty input = zero deltas
/// (most turns,actually — evolution is slow / debounced)。
public struct BASEvolutionShadowInput:
    Sendable, Equatable, Hashable, Codable
{
    public let updateTickets: [BASEvolutionUpdateTicket]
    public let ruleCandidates: [BASEvolutionRuleCandidate]
    public let hostChangeCandidates:
        [BASEvolutionHostChangeCandidate]

    public init(
        updateTickets: [BASEvolutionUpdateTicket] = [],
        ruleCandidates: [BASEvolutionRuleCandidate] = [],
        hostChangeCandidates:
            [BASEvolutionHostChangeCandidate] = []
    ) {
        self.updateTickets = updateTickets
        self.ruleCandidates = ruleCandidates
        self.hostChangeCandidates = hostChangeCandidates
    }

    /// True when no proposal cluster has any content — emit will
    /// return [] without any work。
    public var isEmpty: Bool {
        updateTickets.isEmpty &&
        ruleCandidates.isEmpty &&
        hostChangeCandidates.isEmpty
    }
}

// MARK: - Seat

public enum BASEvolutionShadowSeat {

    /// Pure-function:emit one delta per proposal item across all
    /// 3 clusters。 Caller MUST pass `agentSpec.writeDomains`
    /// containing `.evolutionProposal` (apply step enforces)。
    /// CRITICAL:caller MUST NOT include `.hostVersion` in
    /// `writeDomains` — graph actor rejects any such attempt
    /// at write time。
    ///
    /// Emission shape (one delta per item — order is stable for
    /// trace reproducibility):
    ///   - tickets:   `evolutionProposal#ticket-<turnID>-<ticketID>`
    ///   - rules:     `evolutionProposal#rule-<turnID>-<candidateID>`
    ///   - hostChange:`evolutionProposal#hostchange-<turnID>-<candidateID>`
    ///
    /// All deltas use `.add` deltaType (each is a new proposal
    /// document — never overwrites prior turn's proposals)。
    /// Confidence:
    ///   - tickets: 0.5 + 0.3 * scopeImpact (capped 1.0)
    ///   - rules:   0.4 + 0.5 * supportStrength (capped 1.0)
    ///   - host:    0.3 + 0.5 * directionScore (capped 1.0;
    ///              host-change candidates have the lowest base
    ///              confidence because they touch sovereign-locked
    ///              axes and need the most ShadowTrial scrutiny)
    public static func emit(
        from input: BASEvolutionShadowInput,
        turnID: String,
        agentSpec: BASAgentSpec,
        seq: inout Int,
        nowNanos: Int64 = 0
    ) -> [BASAgentDelta] {
        var out: [BASAgentDelta] = []
        // Cluster 1: incremental update tickets
        for ticket in input.updateTickets {
            seq += 1
            let conf = clampConfidence(
                0.5 + 0.3 * ticket.scopeImpact)
            out.append(BASAgentDelta(
                deltaID:
                    "delta.\(turnID).evolution.\(seq)",
                agentID: agentSpec.agentID,
                targetObjectRef:
                    "evolutionProposal#ticket-\(turnID)" +
                    "-\(ticket.ticketID)",
                deltaType: .add,
                patchJson: encodeTicketPayload(ticket),
                confidence: conf,
                createdAtNanos: nowNanos,
                reasonCodes: [
                    "evolution.update-ticket",
                    "evolution.scope=" +
                        "\(String(format: "%.3f", ticket.scopeImpact))",
                    // chapter 九百六十五 — never-effective-same-turn
                    // marker for trace audit (ShadowTrial consumer
                    // filters on this prefix)
                    "evolution.deferred=shadow-trial",
                ]))
        }
        // Cluster 2: new rule candidates
        for cand in input.ruleCandidates {
            seq += 1
            let conf = clampConfidence(
                0.4 + 0.5 * cand.supportStrength)
            out.append(BASAgentDelta(
                deltaID:
                    "delta.\(turnID).evolution.\(seq)",
                agentID: agentSpec.agentID,
                targetObjectRef:
                    "evolutionProposal#rule-\(turnID)" +
                    "-\(cand.candidateID)",
                deltaType: .add,
                patchJson: encodeRulePayload(cand),
                confidence: conf,
                createdAtNanos: nowNanos,
                reasonCodes: [
                    "evolution.rule-candidate",
                    "evolution.support=" +
                        "\(String(format: "%.3f", cand.supportStrength))",
                    "evolution.deferred=shadow-trial",
                ]))
        }
        // Cluster 3: host-change candidates (sovereign-adjacent)
        for cand in input.hostChangeCandidates {
            seq += 1
            let conf = clampConfidence(
                0.3 + 0.5 * cand.directionScore)
            out.append(BASAgentDelta(
                deltaID:
                    "delta.\(turnID).evolution.\(seq)",
                agentID: agentSpec.agentID,
                targetObjectRef:
                    "evolutionProposal#hostchange-\(turnID)" +
                    "-\(cand.candidateID)",
                deltaType: .add,
                patchJson: encodeHostChangePayload(cand),
                confidence: conf,
                createdAtNanos: nowNanos,
                reasonCodes: [
                    "evolution.host-change-candidate",
                    "evolution.target-axis=" +
                        "\(cand.targetAxis.escapeForJSONES())",
                    "evolution.direction=" +
                        "\(String(format: "%.3f", cand.directionScore))",
                    // CRITICAL marker:host-change candidates are
                    // sovereign-adjacent — ShadowTrial MUST gate
                    // these through L5+L14 before any effective
                    // mutation。 The marker is here as an audit
                    // trail for the trace-replay engine。
                    "evolution.deferred=shadow-trial",
                    "evolution.sovereign-adjacent=true",
                ]))
        }
        return out
    }

    // MARK: - Helpers

    private static func clampConfidence(
        _ v: Double
    ) -> Double {
        max(0.0, min(1.0, v))
    }

    private static func encodeTicketPayload(
        _ ticket: BASEvolutionUpdateTicket
    ) -> String {
        let impactStr = String(
            format: "%.6f", ticket.scopeImpact)
        var parts: [String] = []
        parts.append(
            "\"ticket_id\":\"" +
            "\(ticket.ticketID.escapeForJSONES())\"")
        parts.append(
            ",\"target_ref\":\"" +
            "\(ticket.targetRef.escapeForJSONES())\"")
        parts.append(
            ",\"summary\":\"" +
            "\(ticket.summary.escapeForJSONES())\"")
        parts.append(",\"scope_impact\":\(impactStr)")
        return "{\(parts.joined())}"
    }

    private static func encodeRulePayload(
        _ cand: BASEvolutionRuleCandidate
    ) -> String {
        let supportStr = String(
            format: "%.6f", cand.supportStrength)
        var parts: [String] = []
        parts.append(
            "\"candidate_id\":\"" +
            "\(cand.candidateID.escapeForJSONES())\"")
        parts.append(
            ",\"rule_body\":\"" +
            "\(cand.ruleBody.escapeForJSONES())\"")
        parts.append(",\"support\":\(supportStr)")
        return "{\(parts.joined())}"
    }

    private static func encodeHostChangePayload(
        _ cand: BASEvolutionHostChangeCandidate
    ) -> String {
        let dirStr = String(
            format: "%.6f", cand.directionScore)
        var parts: [String] = []
        parts.append(
            "\"candidate_id\":\"" +
            "\(cand.candidateID.escapeForJSONES())\"")
        parts.append(
            ",\"target_axis\":\"" +
            "\(cand.targetAxis.escapeForJSONES())\"")
        parts.append(
            ",\"proposed_summary\":\"" +
            "\(cand.proposedSummary.escapeForJSONES())\"")
        parts.append(",\"direction\":\(dirStr)")
        // CRITICAL audit field:explicit marker that this delta
        // is sovereign-adjacent and MUST go through ShadowTrial
        parts.append(",\"sovereign_adjacent\":true")
        parts.append(",\"deferred\":\"shadow-trial\"")
        return "{\(parts.joined())}"
    }
}

// MARK: - JSON escape helper (file-scope per ch 957/958/959 pattern)

private extension String {
    /// JSON escape with ES suffix (evolution-seat) to avoid
    /// collision with other seat extensions。 Swift can't
    /// disambiguate two file-private extensions with the same
    /// method name in the same module。
    /// chapter 九百八十一.9 USER-PASS-10 ARC FINALIZE item 8
    /// migration:delegates to shared `BASAgentFabricJSONEscape`。
    func escapeForJSONES() -> String {
        BASAgentFabricJSONEscape.escape(self)
    }
}
