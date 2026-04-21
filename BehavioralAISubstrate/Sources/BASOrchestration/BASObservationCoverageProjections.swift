import Foundation
import BASRuntimeCore

// MARK: - L6 / L7 / L9 / L10 / L12 coverage projections
//
// M32 — additive edge projections from the five BASOrchestration-
// resident observation bundles to the neutral
// `BASObservationCoverageSummary` defined in BASRuntimeCore (M31).
// Each extension carries its `BASCognitiveLayer` tag implicitly so
// callers never pass the layer by hand.
//
// For L6 (presence) and L7 (mirror blade) the bundles are
// channel/kind-addressed rather than subject-addressed, so
// `distinctSubjectCount` maps to the count of distinct
// channels/kinds covered this turn — the closest semantic analog
// and still a meaningful "how many distinct things did this layer
// notice" signal.

// MARK: - L6 presence

extension BASPresenceObservationBundle {
    /// Neutral coverage summary for L6. `distinctSubjectCount` maps
    /// to the number of distinct channels touched this turn.
    public var coverageSummary: BASObservationCoverageSummary {
        let distinctChannels = Set(observations.map { $0.channel })
        return BASObservationCoverageSummary(
            layer: .presenceEye,
            turnID: turnID,
            sessionID: sessionID,
            totalObservations: observations.count,
            distinctSubjectCount: distinctChannels.count,
            hasCoreSignalCoverage: hasCoreChannelCoverage,
            budgetTotalCost:
                BASPresenceObservationBudget.totalCost(for: self),
            emittedAt: emittedAt)
    }
}

// MARK: - L7 mirror blade

extension BASDecompositionObservationBundle {
    /// Neutral coverage summary for L7. `distinctSubjectCount` maps
    /// to the number of distinct decomposition kinds observed this
    /// turn.
    public var coverageSummary: BASObservationCoverageSummary {
        let distinctKinds = Set(observations.map { $0.kind })
        return BASObservationCoverageSummary(
            layer: .mirrorBlade,
            turnID: turnID,
            sessionID: sessionID,
            totalObservations: observations.count,
            distinctSubjectCount: distinctKinds.count,
            hasCoreSignalCoverage: hasCoreSignalCoverage,
            budgetTotalCost:
                BASDecompositionObservationBudget.totalCost(for: self),
            emittedAt: emittedAt)
    }
}

// MARK: - L9 dream loop

extension BASCandidateObservationBundle {
    /// Neutral coverage summary for L9. `distinctSubjectCount` maps
    /// to the number of distinct candidates observed this turn.
    public var coverageSummary: BASObservationCoverageSummary {
        BASObservationCoverageSummary(
            layer: .dreamLoop,
            turnID: turnID,
            sessionID: sessionID,
            totalObservations: observations.count,
            distinctSubjectCount: candidateIDs.count,
            hasCoreSignalCoverage: hasCoreSignalCoverage,
            budgetTotalCost:
                BASCandidateObservationBudget.totalCost(for: self),
            emittedAt: emittedAt)
    }
}

// MARK: - L10 tri-self tribunal

extension BASTribunalObservationBundle {
    /// Neutral coverage summary for L10. `distinctSubjectCount`
    /// maps to the number of distinct subjects the tribunal
    /// deliberated on this turn; `hasCoreSignalCoverage` maps to
    /// `allVoicesSpoke` — the tribunal-specific health heuristic
    /// (all three voices recorded at least one vote).
    public var coverageSummary: BASObservationCoverageSummary {
        BASObservationCoverageSummary(
            layer: .triSelfTribunal,
            turnID: turnID,
            sessionID: sessionID,
            totalObservations: observations.count,
            distinctSubjectCount: subjectIDs.count,
            hasCoreSignalCoverage: allVoicesSpoke,
            budgetTotalCost:
                BASTribunalObservationBudget.totalCost(for: self),
            emittedAt: emittedAt)
    }
}

// MARK: - L12 gentle hand

extension BASSoftHandObservationBundle {
    /// Neutral coverage summary for L12. `distinctSubjectCount`
    /// maps to the number of distinct render subjects observed this
    /// turn.
    public var coverageSummary: BASObservationCoverageSummary {
        BASObservationCoverageSummary(
            layer: .gentleHand,
            turnID: turnID,
            sessionID: sessionID,
            totalObservations: observations.count,
            distinctSubjectCount: subjectIDs.count,
            hasCoreSignalCoverage: hasCoreSignalCoverage,
            budgetTotalCost:
                BASSoftHandObservationBudget.totalCost(for: self),
            emittedAt: emittedAt)
    }
}
