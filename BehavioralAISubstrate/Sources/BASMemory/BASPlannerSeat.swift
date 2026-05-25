// MARK: - BASPlannerSeat
// chapter 九百五十七 / M3490 — Phase 1 ch2:Planner seat wrapper
//
// User design Section 9.4-9.5:Planner is a CORE agent (HIGH
// visibility,hot-seat profile) sitting at L9 (loop service)。
// Per Single-Writer-Per-Domain (ch 956.5 USER-PASS gap #1)
// Planner is the SOLE writer for `.candidateFrontier` — Critic
// agent (ch 961) proposes critique deltas which Planner merges in。
//
// ## Why a pure function,not an actor
//
// Same rationale as `BASScoutSeat`:per-turn hot path needs the
// least possible coordination overhead。 The seat is a pure
// `[BASAgentDelta]`-emitting function taking a slim DTO built by
// the coordinator from the existing L9 `loopService.proposePaths`
// output。 No actor isolation hop;no I/O。
//
// ## What it emits
//
// One delta per candidate path in the frontier (`type=.add` since
// these are new proposals,not updates)。 The delta's
// `targetObjectRef` is namespaced per turn so different turns'
// frontiers do not collide。 Confidence flows directly from the
// candidate's `confidence` field — Planner is just a translator
// from `[BASCandidatePath]` → `[BASAgentDelta]`,not a re-ranker。
//
// Empty frontier produces NO delta (zero-candidate turns are valid
// for low-effort modes per the Agent Fabric router activation
// table in ch 956)。
//
// ## DTO not Type
//
// Per same module-dep rationale as `BASScoutInput`,this seat
// takes `BASPlannerCandidate` (slim DTO) rather than
// `BASCandidatePath` from BASOrchestration。 Coordinator adapter
// (ch 958+) builds the DTO from the live L9 output。

import Foundation

/// Slim DTO mirroring the loop-service's `BASCandidatePath`
/// without the BASOrchestration module dep。 Carries only the
/// fields Planner needs to construct deltas。
public struct BASPlannerCandidate:
    Sendable, Equatable, Hashable, Codable
{
    /// Stable per-turn candidate ID (Planner uses as objectID)
    public let candidateID: String
    /// Short human-readable title
    public let title: String
    /// 1-line action summary (goes into the delta payload)
    public let actionSummary: String
    /// Confidence ∈ [0.0, 1.0] flowing into the delta
    public let confidence: Double
    /// Expected benefit (audit signal in payload)
    public let expectedBenefit: Double
    /// Expected cost (audit signal in payload)
    public let expectedCost: Double
    /// Reversibility ∈ [0.0, 1.0] (audit signal in payload —
    /// HIGH-reversibility candidates can be proposed more
    /// aggressively per the Risk gate ch 958+)
    public let reversibility: Double

    public init(
        candidateID: String,
        title: String,
        actionSummary: String,
        confidence: Double,
        expectedBenefit: Double = 0.0,
        expectedCost: Double = 0.0,
        reversibility: Double = 0.5
    ) {
        self.candidateID = candidateID
        self.title = title
        self.actionSummary = actionSummary
        self.confidence = confidence
        self.expectedBenefit = expectedBenefit
        self.expectedCost = expectedCost
        self.reversibility = reversibility
    }
}

public enum BASPlannerSeat {

    /// Pure-function:read candidate frontier,emit deltas for
    /// `.candidateFrontier`。 Caller MUST pass `agentSpec.writeDomains`
    /// containing `.candidateFrontier` (apply step enforces)。
    ///
    /// - Parameters:
    ///   - candidates: slim DTO list built from L9 `loopService
    ///     .proposePaths` output
    ///   - turnID: per-turn ID for ref namespacing + reasonCodes
    ///   - agentSpec: Planner's registry spec (used for `agentID`)
    ///   - seq: per-turn delta sequence counter (inout — bumped
    ///     by each emitted delta)
    ///   - nowNanos: monotonic timestamp for ch 956.5 gap #5
    ///     real-recency tie-break。 0 = unknown (falls back to
    ///     lex deltaID per merge engine)
    /// - Returns: one delta per candidate (may be empty)
    public static func emit(
        from candidates: [BASPlannerCandidate],
        turnID: String,
        agentSpec: BASAgentSpec,
        seq: inout Int,
        nowNanos: Int64 = 0
    ) -> [BASAgentDelta] {
        var out: [BASAgentDelta] = []
        for candidate in candidates {
            seq += 1
            let payload = encodeCandidatePayload(candidate)
            // Confidence clamped to [0, 1] defensively — caller
            // may have un-clamped values from heuristics
            let conf = max(0.0, min(1.0, candidate.confidence))
            // Reason codes accumulate evidence prefixes for the
            // audit ledger (ch 953 design Section 7.4)。
            // High-reversibility candidates get an explicit code
            // so Risk agent can identify safer flips downstream。
            var reasons = ["planner.propose"]
            if candidate.reversibility >= 0.7 {
                reasons.append("planner.reversible-high")
            }
            if candidate.expectedBenefit > candidate.expectedCost {
                reasons.append("planner.net-positive")
            }
            out.append(BASAgentDelta(
                deltaID: "delta.\(turnID).planner.\(seq)",
                agentID: agentSpec.agentID,
                targetObjectRef:
                    "candidateFrontier#cf-\(turnID)" +
                    "-\(candidate.candidateID)",
                deltaType: .add,
                patchJson: payload,
                confidence: conf,
                createdAtNanos: nowNanos,
                reasonCodes: reasons))
        }
        return out
    }

    // MARK: - Payload encoder (deterministic minimal JSON)

    private static func encodeCandidatePayload(
        _ c: BASPlannerCandidate
    ) -> String {
        // Deterministic field order:title,action,benefit,cost,
        // reversibility,confidence。 Alphabetical NOT used — we
        // pick a stable order that reads naturally for audits。
        var parts: [String] = []
        parts.append(
            "\"candidate_id\":\"" +
            "\(c.candidateID.escapeForJSON())\"")
        parts.append(
            ",\"title\":\"\(c.title.escapeForJSON())\"")
        parts.append(
            ",\"action\":\"" +
            "\(c.actionSummary.escapeForJSON())\"")
        parts.append(
            ",\"benefit\":\(formatDouble(c.expectedBenefit))")
        parts.append(
            ",\"cost\":\(formatDouble(c.expectedCost))")
        parts.append(
            ",\"reversibility\":" +
            "\(formatDouble(c.reversibility))")
        parts.append(
            ",\"confidence\":\(formatDouble(c.confidence))")
        return "{\(parts.joined())}"
    }

    /// Stable double formatting — 6 fractional digits,no trailing
    /// scientific notation,deterministic across runs。 Critical
    /// for the ch 956.5 strong-mergeID hash invariance:two turns
    /// producing the same candidates must produce byte-equal
    /// payloads。
    private static func formatDouble(_ v: Double) -> String {
        return String(format: "%.6f", v)
    }
}

// MARK: - JSON escape helper (private to this file — duplicate of
// BASScoutSeat's to avoid an internal-visibility helper that
// could leak)

private extension String {
    func escapeForJSON() -> String {
        var out = ""
        out.reserveCapacity(self.count)
        for ch in self {
            switch ch {
            case "\\": out.append("\\\\")
            case "\"": out.append("\\\"")
            case "\n": out.append("\\n")
            case "\r": out.append("\\r")
            case "\t": out.append("\\t")
            default: out.append(ch)
            }
        }
        return out
    }
}
