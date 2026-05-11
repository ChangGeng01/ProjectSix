// MARK: - BASTurnAuditProjectionsLateClusterC
// chapter 四百八十九 / M1332 — V1 cluster B continuation
//
// Folds 6 late projections (anomalyTrace + abyssalBranches
// + ontologyShiftMark + narrativeDistortionMap + hostFragility
// + abyssalPressureWithFragility)。 Cluster B: 12 → 18 folded。

import Foundation
import BASOrchestration
import BASRuntimeCore

public struct BASTurnAuditProjectionsLateClusterC: Sendable {
    public let anomalyTrace: BASAnomalyTrace?
    public let abyssalBranches: [BASAbyssalBranch]
    public let ontologyShiftMark: BASOntologyShiftMark
    public let narrativeDistortionMap: BASNarrativeDistortionMap?
    public let hostFragility: Double
    public let abyssalPressureWithFragility:
        BASAbyssalPressure

    public static func compute(
        sessionID: String,
        turnID: String,
        narrativeDistortion: BASNarrativeDistortion,
        abyssalPressure: BASAbyssalPressure,
        humanAnchorSignal: BASHumanAnchorSignal,
        candidates: [BASCandidatePath]
    ) -> BASTurnAuditProjectionsLateClusterC {
        let candidateIDs = candidates.map(\.candidateID)
        let anomaly = BASAnomalyTrace.deriveOrNil(
            traceID: "anomaly-\(sessionID)",
            distortion: narrativeDistortion,
            relationShift: "",
            sourceRefs: [sessionID],
            pressureVector: abyssalPressure)
        let branches = BASAbyssalBranch.deriveAll(
            candidateIDs: candidateIDs,
            pressure: abyssalPressure)
        let shiftMark = BASCthulhuLayerProjections
            .OntologyShiftMark.derive(
                from: narrativeDistortion,
                turnID: turnID,
                targetSubjectRef: candidates.first?
                    .candidateID ?? "no-candidate")
        let distortionMap = BASCthulhuLeftoverProjections
            .NarrativeDistortionMap.derive(
                from: narrativeDistortion,
                candidateIDs: candidateIDs,
                turnID: turnID)
        let fragility = BASCthulhuLeftoverProjections
            .HostFragilityProjection.derive(
                from: humanAnchorSignal)
        let withFragility = BASCthulhuLeftoverProjections
            .HostFragilityProjection.apply(
                fragility: fragility,
                to: abyssalPressure)
        return BASTurnAuditProjectionsLateClusterC(
            anomalyTrace: anomaly,
            abyssalBranches: branches,
            ontologyShiftMark: shiftMark,
            narrativeDistortionMap: distortionMap,
            hostFragility: fragility,
            abyssalPressureWithFragility: withFragility)
    }
}
