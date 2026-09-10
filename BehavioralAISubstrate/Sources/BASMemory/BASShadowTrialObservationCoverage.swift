import Foundation
import BASRuntimeCore

// MARK: - L13 shadow-trial coverage projection
//
// M32 — additive edge projection from
// `BASShadowTrialObservationBundle` to the neutral
// `BASObservationCoverageSummary` defined in BASRuntimeCore (M31).
// Carries the `BASCognitiveLayer.evolutionFurnace` tag implicitly.

extension BASShadowTrialObservationBundle {
    /// Neutral coverage summary for L13. `distinctSubjectCount`
    /// maps to the number of distinct update tickets observed this
    /// turn.
    public var coverageSummary: BASObservationCoverageSummary {
        BASObservationCoverageSummary(
            layer: .evolutionFurnace,
            turnID: turnID,
            sessionID: sessionID,
            totalObservations: observations.count,
            distinctSubjectCount: ticketIDs.count,
            hasCoreSignalCoverage: hasCoreSignalCoverage,
            budgetTotalCost:
                BASShadowTrialObservationBudget.totalCost(for: self),
            emittedAt: emittedAt)
    }
}
