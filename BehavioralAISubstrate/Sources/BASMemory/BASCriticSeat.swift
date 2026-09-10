// MARK: - BASCriticSeat
// chapter 九百六十一 / M3510 — Phase 2 ch2:Critic seat wrapper
//
// User design Section 9.4-9.5:Critic is a CORE agent (HIGH
// visibility — user-customizable skepticism + challenge intensity
// per the 3-tier table)。 Per Single-Writer-Per-Domain (ch 956.5
// USER-PASS gap #1) Critic is the SOLE writer for `.critiqueField`
// (NEW domain landed this chapter)。
//
// Why `.critiqueField` instead of writing to `.candidateFrontier`:
// the original plan said Critic emits "CritiqueDelta against
// Planner's CandidateFrontier" — but only Planner can write to
// candidateFrontier per Single-Writer。 Phase 2 ch2 picks the
// cleanest fix:Critic owns its own domain;Planner (next-turn)
// reads critiques back when re-proposing。 No merge-engine
// proposal-routing complexity needed。
//
// Critic wraps `triSelfService.superego` conceptually — its job
// is to flag concerns with proposed candidates。 In Phase 2 ch2
// the rules are heuristic;Phase 3+ wires the real L7 矛盾晶格
// (decompose-frame contradictions) for richer critique。

import Foundation

/// Per-candidate input for Critic — mirrors Risk's shape but
/// distinct type so the two seats can evolve independently。
public struct BASCriticCandidate:
    Sendable, Equatable, Hashable, Codable
{
    public let candidateID: String
    public let title: String
    public let expectedBenefit: Double
    public let expectedCost: Double
    public let reversibility: Double

    public init(
        candidateID: String,
        title: String,
        expectedBenefit: Double,
        expectedCost: Double,
        reversibility: Double
    ) {
        self.candidateID = candidateID
        self.title = title
        self.expectedBenefit = expectedBenefit
        self.expectedCost = expectedCost
        self.reversibility = reversibility
    }
}

/// Slim DTO carrying candidates + the superego activation level
/// (how strict Critic should be this turn)。 Higher level →
/// Critic emits critique deltas for marginal concerns;lower
/// level → only flags concrete benefit/cost issues。
public struct BASCriticSeatInput:
    Sendable, Equatable, Hashable, Codable
{
    public let candidates: [BASCriticCandidate]
    /// Strictness level ∈ [0.0, 1.0]。 At ≥0.7 Critic emits even
    /// for borderline candidates;below 0.4 only clear concerns。
    public let superegoActiveLevel: Double

    public init(
        candidates: [BASCriticCandidate] = [],
        superegoActiveLevel: Double = 0.5
    ) {
        self.candidates = candidates
        self.superegoActiveLevel = superegoActiveLevel
    }
}

/// Concern severity per candidate per critique rule。
public enum BASCriticConcernSeverity: String,
    Sendable, Equatable, Hashable, Codable, CaseIterable
{
    case none       // No concern, no delta emitted
    case mild       // Worth noting, soft critique
    case strong     // Significant concern
    case severe     // Block-level concern (cost/irreversibility)
}

public enum BASCriticSeat {

    /// Pure-function:emit one critique delta per candidate with
    /// non-none severity。 Caller MUST pass `agentSpec.writeDomains`
    /// containing `.critiqueField`。
    ///
    /// Critique rules (ordered — first match wins):
    ///   1. cost > 2× benefit → SEVERE (clear net-negative)
    ///   2. reversibility < 0.2 AND benefit < 0.5 → SEVERE
    ///      (irreversible action without strong upside)
    ///   3. cost > benefit → STRONG (net-negative)
    ///   4. reversibility < 0.4 → STRONG (irreversible)
    ///   5. superego ≥ 0.7 AND cost > 0.5 → MILD (strict mode)
    ///   6. otherwise → NONE (no delta)
    public static func emit(
        from input: BASCriticSeatInput,
        turnID: String,
        agentSpec: BASAgentSpec,
        seq: inout Int,
        nowNanos: Int64 = 0
    ) -> [BASAgentDelta] {
        var out: [BASAgentDelta] = []
        for candidate in input.candidates {
            let (severity, reasons) = critique(
                candidate: candidate, input: input)
            if severity == .none { continue }
            seq += 1
            let conf: Double
            switch severity {
            case .severe: conf = 0.95
            case .strong: conf = 0.80
            case .mild: conf = 0.60
            case .none: conf = 0.0  // unreachable
            }
            let payload = encodeCritiquePayload(
                candidate: candidate,
                severity: severity,
                superegoActiveLevel:
                    input.superegoActiveLevel)
            out.append(BASAgentDelta(
                deltaID: "delta.\(turnID).critic.\(seq)",
                agentID: agentSpec.agentID,
                targetObjectRef:
                    "critiqueField#cf-\(turnID)" +
                    "-\(candidate.candidateID)",
                deltaType: .merge,
                patchJson: payload,
                confidence: conf,
                createdAtNanos: nowNanos,
                reasonCodes:
                    ["critic.assess"] + reasons))
        }
        return out
    }

    // MARK: - Critique rule (pure function)

    private static func critique(
        candidate: BASCriticCandidate,
        input: BASCriticSeatInput
    ) -> (BASCriticConcernSeverity, [String]) {
        var reasons: [String] = []
        let cost = candidate.expectedCost
        let benefit = candidate.expectedBenefit
        let rev = candidate.reversibility
        // Rule 1: cost > 2× benefit → SEVERE (need benefit > 0
        // to avoid trivial 0×0 case)
        if benefit > 0.0 && cost > 2.0 * benefit {
            reasons.append("critic.cost-far-exceeds-benefit")
            reasons.append("critic.severity=cost-net-negative")
            return (.severe, reasons)
        }
        // Rule 2: irreversible + weak upside → SEVERE
        if rev < 0.2 && benefit < 0.5 {
            reasons.append("critic.irreversible-weak-upside")
            reasons.append(
                "critic.severity=irreversibility-block")
            return (.severe, reasons)
        }
        // Rule 3: cost > benefit (mild net-negative) → STRONG
        if cost > benefit {
            reasons.append("critic.cost-exceeds-benefit")
            reasons.append("critic.severity=net-negative")
            return (.strong, reasons)
        }
        // Rule 4: reversibility < 0.4 → STRONG
        if rev < 0.4 {
            reasons.append("critic.reversibility-low")
            reasons.append("critic.severity=irreversibility")
            return (.strong, reasons)
        }
        // Rule 5: strict-mode concern → MILD
        if input.superegoActiveLevel >= 0.7 && cost > 0.5 {
            reasons.append("critic.strict-mode-cost")
            reasons.append("critic.severity=strict-bump")
            return (.mild, reasons)
        }
        // Otherwise: no concern
        return (.none, reasons)
    }

    // MARK: - Payload encoder

    private static func encodeCritiquePayload(
        candidate: BASCriticCandidate,
        severity: BASCriticConcernSeverity,
        superegoActiveLevel: Double
    ) -> String {
        var parts: [String] = []
        parts.append(
            "\"candidate_id\":\"" +
            "\(candidate.candidateID.escapeForJSONCS())\"")
        parts.append(
            ",\"severity\":\"\(severity.rawValue)\"")
        parts.append(
            ",\"benefit\":\(fmtCS(candidate.expectedBenefit))")
        parts.append(
            ",\"cost\":\(fmtCS(candidate.expectedCost))")
        parts.append(
            ",\"reversibility\":" +
            "\(fmtCS(candidate.reversibility))")
        parts.append(
            ",\"superego_level\":" +
            "\(fmtCS(superegoActiveLevel))")
        return "{\(parts.joined())}"
    }

    private static func fmtCS(_ v: Double) -> String {
        return String(format: "%.6f", v)
    }
}

// chapter 九百八十一.9 USER-PASS-10 ARC FINALIZE item 8
// migration:delegates to shared `BASAgentFabricJSONEscape`。
private extension String {
    func escapeForJSONCS() -> String {
        BASAgentFabricJSONEscape.escape(self)
    }
}
