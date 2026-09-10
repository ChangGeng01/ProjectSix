// MARK: - BASDeliberationBias
// chapter 一千零三十九 / ADR-018 P1 — shared deliberation-loop bias
//
// The unified deliberation loop (ch 1039, `runTurn`) feeds each pass
// the prior pass's surviving candidate IDs via the
// `iterate(…:priorCandidateIDs:)` contract. A candidate carried over
// earns a small bounded confidence reinforcement — it survived the
// prior scrutiny. This is the single source of that bias so every
// loop service applies it identically (BASMLLoopService +
// BASHostRuntimeEBrainLoopService). Empty / unmatched prior set →
// byte-equal with the single-pass frame (红线 7 identity).

import Foundation
import BASOrchestration

enum BASDeliberationBias {

    /// Bounded confidence reinforcement granted to a candidate that
    /// persisted from the prior deliberation iteration. Small +
    /// capped so the loop refines (raises confidence on survivors)
    /// without runaway entrenchment — the ±0.05 bias-cap discipline
    /// used elsewhere in the substrate.
    static let priorPersistenceConfidenceBonus = 0.05

    /// Return a copy of `frame` whose candidates present in
    /// `priorCandidateIDs` have their confidence reinforced by
    /// `priorPersistenceConfidenceBonus` (capped at 1.0). All other
    /// fields, forecasts, and critiques are untouched. An empty or
    /// fully-unmatched prior set returns a byte-equal frame.
    static func reinforce(
        _ frame: BASThoughtFrame,
        priorCandidateIDs: [String]
    ) -> BASThoughtFrame {
        guard !priorCandidateIDs.isEmpty else { return frame }
        let priorSet = Set(priorCandidateIDs)
        // Immutable rebuild: matched candidates get a new copy with
        // reinforced confidence; unmatched return as-is, so a
        // non-empty set with no match stays byte-equal too.
        let reinforced = frame.candidates.map {
            c -> BASCandidatePath in
            guard priorSet.contains(c.candidateID) else { return c }
            return BASCandidatePath(
                schemaVersion: c.schemaVersion,
                candidateID: c.candidateID,
                title: c.title,
                actionSummary: c.actionSummary,
                requiredEvidence: c.requiredEvidence,
                expectedBenefit: c.expectedBenefit,
                expectedCost: c.expectedCost,
                reversibility: c.reversibility,
                confidence: min(1.0, c.confidence
                    + priorPersistenceConfidenceBonus))
        }
        var refined = frame
        refined.candidates = reinforced
        return refined
    }
}

// MARK: - BASDeliberationCaution
// chapter 一千零四十 / ADR-019 P1.5a — consequential deliberation caution
//
// The ch1039 loop is decision-inert (ADR-019 §9 clamp-domination); a
// calibrateRisk-level factor is halved + loop-offset by the binding
// re-derivation (§10). This injects on the FINAL bound risk card
// (post-binding, in runTurn) so the increment is NOT halved and NOT
// offset — when the opt-in loop runs on a genuinely-uncertain matter,
// raise caution enough to cross a risk band. Caution-INCREASING only →
// no sovereign gate. Flag-off → no injection → byte-equal.

enum BASDeliberationCaution {

    /// Bounded caution added to the FINAL bound `totalRisk` when the
    /// opt-in deliberation loop runs AND the matter is genuinely
    /// uncertain. Sized to cross one risk band from a borderline value
    /// (bands at 0.35 / 0.65 / 0.85). One-shot, bounded, caution-only.
    static let uncertainDeliberationRiskIncrement = 0.06

    /// chapter 一千零四十一 / ADR-019 — reversibility-tilt near-tie
    /// window. When the opt-in loop runs on a genuinely-uncertain turn,
    /// the selection prefers a STRICTLY-more-reversible non-vetoed
    /// candidate if it is within this `mergedScore` distance of the
    /// score-winner (a near-tie → break toward the safer/more-reversible
    /// option). Small enough to fire only on genuine near-ties; the
    /// canonical high-risk bounded↔reflective gap is ~0.003, well within.
    /// Monotonic-toward-conservative (only ever picks a MORE-reversible
    /// option), so widening it can only make the host safer, never less.
    static let reversibilityTiltCap = 0.05

    /// Genuine-uncertainty predicate reusing the signals the dream-loop
    /// already trusts (confidenceFloor < 0.55 OR maxEvidenceDebt >= 0.5
    /// OR stoppingMode == .leaseEnd; cf. RiskService court signals).
    static func isGenuinelyUncertain(
        confidenceFloor: Double?,
        maxEvidenceDebt: Double?,
        leaseEnded: Bool
    ) -> Bool {
        (confidenceFloor.map { $0 < 0.55 } ?? false)
            || (maxEvidenceDebt.map { $0 >= 0.5 } ?? false)
            || leaseEnded
    }
}
