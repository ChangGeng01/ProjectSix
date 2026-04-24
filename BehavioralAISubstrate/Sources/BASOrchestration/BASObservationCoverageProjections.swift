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

// MARK: - L1 lease & life (M97)
//
// Added M97 to close the "three bundles exist but no coverage-summary
// projection" gap found while auditing the M95 observation streaming
// hook. Pre-M97 the L1/L2/L5 bundles were first-class types derived
// every turn (M60/M55/M65) but could not be fed through
// `QinaoSovereignControlPlane.recordTurnCoverage(additionalSummaries:)`
// because they had no `BASObservationCoverageSummary` edge. M97 lands
// the three projections so hosts can stream L1/L2/L5 alongside the
// L3/L4/L6/L7/L9/L10/L11/L12/L13 projections that were already present.

extension BASLeaseLifeObservationBundle {
    /// Neutral coverage summary for L1. `distinctSubjectCount` maps
    /// to the number of distinct kernel-subject IDs (leaseID / run
    /// mode / thermal level / guard level / maintenance class /
    /// device route) the bundle carries this turn.
    /// `hasCoreSignalCoverage` surfaces the existing bundle-level
    /// "kernel baseline fired" predicate (lease grant + runMode +
    /// thermal reading + device route).
    public var coverageSummary: BASObservationCoverageSummary {
        BASObservationCoverageSummary(
            layer: .leaseLife,
            turnID: turnID,
            sessionID: sessionID,
            totalObservations: observations.count,
            distinctSubjectCount: subjectIDs.count,
            hasCoreSignalCoverage: hasCoreSignalCoverage,
            budgetTotalCost:
                BASLeaseLifeSignalBudget.totalCost(for: self),
            emittedAt: emittedAt)
    }
}

// MARK: - L2 neural organ (M97)

extension BASNeuralOrganObservationBundle {
    /// Neutral coverage summary for L2. `distinctSubjectCount`
    /// maps to the distinct L2 subjects (morph-graph refs / head
    /// IDs / organ package refs) the bundle touched this turn.
    /// `hasCoreSignalCoverage` surfaces the existing `hasMapSealed`
    /// predicate — L2 is "healthy" when the neural-organ map was
    /// sealed for the turn.
    public var coverageSummary: BASObservationCoverageSummary {
        BASObservationCoverageSummary(
            layer: .neuralOrgan,
            turnID: turnID,
            sessionID: sessionID,
            totalObservations: observations.count,
            distinctSubjectCount: subjectIDs.count,
            hasCoreSignalCoverage: hasCoreSignalCoverage,
            budgetTotalCost:
                BASNeuralOrganSignalBudget.totalCost(for: self),
            emittedAt: emittedAt)
    }
}

// MARK: - L5 host constitution (M97)

extension BASHostConstitutionObservationBundle {
    /// Neutral coverage summary for L5. `distinctSubjectCount`
    /// maps to the distinct host-constitution subjects (domain
    /// refs / anchor refs / candidate refs / version refs) touched
    /// this turn. `hasCoreSignalCoverage` surfaces the existing
    /// `hasAnyAnchor` predicate — L5 is "healthy" when at least one
    /// anchor was observed in the turn.
    public var coverageSummary: BASObservationCoverageSummary {
        BASObservationCoverageSummary(
            layer: .hostConstitution,
            turnID: turnID,
            sessionID: sessionID,
            totalObservations: observations.count,
            distinctSubjectCount: subjectIDs.count,
            hasCoreSignalCoverage: hasCoreSignalCoverage,
            budgetTotalCost:
                BASHostConstitutionSignalBudget.totalCost(for: self),
            emittedAt: emittedAt)
    }
}

// MARK: - L8 hippocampal well (M98)
//
// Completes the 14-layer coverage projection matrix. L8 is the
// hippocampal memory layer — retrieval events + pinning events +
// forgetting events per turn. `hasCoreSignalCoverage` surfaces the
// `hasBundleRetrieval` predicate (L8 is "healthy" when at least
// one retrieval was observed in the turn). Closes the remaining
// cognitive-layer gap identified in the M97 post-mortem; every
// per-turn observation bundle type that exists as a substrate
// first-class type now has a matching `coverageSummary` edge that
// hosts can stream through QinaoRuntime.sendSession's
// `additionalCoverageSummaries:` parameter (M95).

extension BASHippocampalMemoryObservationBundle {
    /// Neutral coverage summary for L8. `distinctSubjectCount`
    /// maps to the distinct memory subjects touched this turn
    /// (retrieval refs / pin refs / forget refs). `hasCoreSignalCoverage`
    /// surfaces the existing `hasBundleRetrieval` predicate — L8 is
    /// "healthy" when at least one retrieval event was observed.
    public var coverageSummary: BASObservationCoverageSummary {
        BASObservationCoverageSummary(
            layer: .hippocampalWell,
            turnID: turnID,
            sessionID: sessionID,
            totalObservations: observations.count,
            distinctSubjectCount: subjectIDs.count,
            hasCoreSignalCoverage: hasCoreSignalCoverage,
            budgetTotalCost:
                BASHippocampalMemorySignalBudget.totalCost(for: self),
            emittedAt: emittedAt)
    }
}

// MARK: - L13 evolution furnace (M138)
//
// Closes the 14-layer coverage projection matrix: L13
// `BASUpdateTicketObservationBundle` gets the same neutral
// coverageSummary edge that L1-L12 already have, so sendSession's
// M138 shadow-trial path can stream the summary into L14 ledger
// alongside the other layers.

extension BASUpdateTicketObservationBundle {
    /// Neutral coverage summary for L13. `distinctSubjectCount`
    /// maps to the distinct ticketIDs observed this turn.
    /// `hasCoreSignalCoverage` surfaces the existing
    /// `hasAnySubmission` predicate — L13 is "healthy" when at
    /// least one ticket submission was observed in the turn.
    public var coverageSummary: BASObservationCoverageSummary {
        BASObservationCoverageSummary(
            layer: .evolutionFurnace,
            turnID: turnID,
            sessionID: sessionID,
            totalObservations: observations.count,
            distinctSubjectCount: subjectIDs.count,
            hasCoreSignalCoverage: hasCoreSignalCoverage,
            budgetTotalCost:
                BASUpdateTicketObservationBudget
                    .totalCost(for: self),
            emittedAt: emittedAt)
    }
}
