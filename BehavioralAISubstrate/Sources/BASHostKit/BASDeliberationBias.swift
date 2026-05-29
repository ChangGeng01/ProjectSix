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
