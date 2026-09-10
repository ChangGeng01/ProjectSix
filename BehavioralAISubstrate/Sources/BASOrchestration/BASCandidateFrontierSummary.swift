import Foundation

/// L9 / M283 — high-level summary of a `BASCandidateObservationBundle`.
///
/// ## Why this exists
///
/// `BASCandidateObservationBundle` carries every per-signal observation
/// from the dream-cycle (candidate, dominance, reversibility, guardian
/// branch, diversity, delay). Audit walkers and observability layers
/// don't need every individual reading — they need to know "did the
/// dream-cycle settle on a winner, or did guardian branches block it?"
///
/// `BASCandidateFrontierSummary` is the distillation. Pure value type;
/// derived from the bundle by `summarize()`. Mirror of M276's pattern
/// for L4 bridge: bundle has the raw signals, summary has the audit-
/// friendly overview.
public struct BASCandidateFrontierSummary:
    Sendable, Equatable, Hashable, Codable
{
    /// Total number of distinct candidates the frontier surfaced.
    public let candidateCount: Int

    /// Top-ranked candidate by `dominanceSignal` salience, or `nil`
    /// if no dominance observations exist.
    public let dominantCandidateID: String?

    /// Number of candidates flagged as `reversibilitySignal` —
    /// reversible-path observations from the dream-cycle.
    public let reversibleCandidateCount: Int

    /// Number of `guardianBranch` observations — paths the dream-
    /// cycle escalated to L11 risk gate or L14 sovereign for review.
    public let guardianBranchCount: Int

    /// Number of `delayRecommendation` observations — paths the
    /// dream-cycle suggested deferring to a later window.
    public let delayedCandidateCount: Int

    /// Whether the dream-cycle emitted at least one diversity
    /// signal (every non-empty turn does, per M142 emission order).
    public let emittedDiversitySignal: Bool

    /// Stable summary status string for audit grouping:
    /// - `"empty"` — bundle had no observations
    /// - `"diversity-only"` — only the baseline diversity signal
    /// - `"dominant-clear"` — at least one dominance signal AND no
    ///   guardian branches (host can act on the winner)
    /// - `"guardian-held"` — guardian branches present (escalation
    ///   needed before any commit)
    public let statusCode: String

    public init(
        candidateCount: Int,
        dominantCandidateID: String?,
        reversibleCandidateCount: Int,
        guardianBranchCount: Int,
        delayedCandidateCount: Int,
        emittedDiversitySignal: Bool,
        statusCode: String
    ) {
        self.candidateCount = candidateCount
        self.dominantCandidateID = dominantCandidateID
        self.reversibleCandidateCount = reversibleCandidateCount
        self.guardianBranchCount = guardianBranchCount
        self.delayedCandidateCount = delayedCandidateCount
        self.emittedDiversitySignal = emittedDiversitySignal
        self.statusCode = statusCode
    }
}

extension BASCandidateObservationBundle {
    /// L9 / M283 — derive the high-level summary. Pure function,
    /// deterministic for the same bundle. No I/O, no actor hop.
    public func summarize() -> BASCandidateFrontierSummary {
        let candidates = candidateIDs
        let dominant = dominantObservation(of: .dominanceSignal)
        let reversibleObs = observations(
            of: .reversibilitySignal)
        let reversibleCandidates = Set(
            reversibleObs.map { $0.candidateID })
        let guardianObs = observations(of: .guardianBranch)
        let delayObs = observations(of: .delayRecommendation)
        let diversityObs = observations(of: .diversitySignal)

        let status: String
        if observations.isEmpty {
            status = "empty"
        } else if !guardianObs.isEmpty {
            status = "guardian-held"
        } else if dominant != nil {
            status = "dominant-clear"
        } else if !diversityObs.isEmpty {
            status = "diversity-only"
        } else {
            status = "empty"
        }

        return BASCandidateFrontierSummary(
            candidateCount: candidates.count,
            dominantCandidateID: dominant?.candidateID,
            reversibleCandidateCount:
                reversibleCandidates.count,
            guardianBranchCount: guardianObs.count,
            delayedCandidateCount: delayObs.count,
            emittedDiversitySignal: !diversityObs.isEmpty,
            statusCode: status)
    }
}
