import Foundation
import BASRuntimeCore

// MARK: - L4 world-prior coverage projection
//
// M32 — additive edge projection from `BASWorldPriorObservationBundle`
// to the neutral `BASObservationCoverageSummary` defined in
// BASRuntimeCore (M31). Lets an L14 reconciler reason over L4
// observations in the same shape as L6/L7/L9/L10/L11/L12/L13
// without knowing about the concrete bundle type.
//
// Pure extension — does not touch the bundle itself, and carries the
// `BASCognitiveLayer.worldPrior` tag implicitly so callers never
// need to pass the layer by hand.

extension BASWorldPriorObservationBundle {
    /// Neutral coverage summary for L4. `distinctSubjectCount` maps
    /// to the number of distinct templates touched this turn.
    public var coverageSummary: BASObservationCoverageSummary {
        BASObservationCoverageSummary(
            layer: .worldPrior,
            turnID: turnID,
            sessionID: sessionID,
            totalObservations: observations.count,
            distinctSubjectCount: templateIDs.count,
            hasCoreSignalCoverage: hasCoreSignalCoverage,
            budgetTotalCost:
                BASWorldPriorObservationBudget.totalCost(for: self),
            emittedAt: emittedAt)
    }
}
