import Foundation
import BASRuntimeCore

// MARK: - L11 risk coverage projection
//
// M32 — additive edge projection from `BASRiskObservationBundle` to
// the neutral `BASObservationCoverageSummary` defined in
// BASRuntimeCore (M31). Carries the `BASCognitiveLayer.riskClimate`
// tag implicitly.

extension BASRiskObservationBundle {
    /// Neutral coverage summary for L11. `distinctSubjectCount`
    /// maps to the number of distinct intents scored this turn.
    public var coverageSummary: BASObservationCoverageSummary {
        BASObservationCoverageSummary(
            layer: .riskClimate,
            turnID: turnID,
            sessionID: sessionID,
            totalObservations: observations.count,
            distinctSubjectCount: intentIDs.count,
            hasCoreSignalCoverage: hasCoreSignalCoverage,
            budgetTotalCost:
                BASRiskObservationBudget.totalCost(for: self),
            emittedAt: emittedAt)
    }
}
