// MARK: - BASTurnAuditProjectionsKunlunHexaTwo
// chapter 四百八十六 / M1320 — V1 cluster A final 6 declarations

import Foundation
import BASOrchestration
import BASPolicy
import BASRuntimeCore
import BASWorldPrior

public struct BASTurnAuditProjectionsKunlunHexaTwo:
    Hashable, Sendable
{
    public let hostJadeRegister: BASHostJadeRegister
    public let jadeMirrorDraft: BASJadeMirrorDraft
    public let kunlunUnnamableSet: BASKunlunUnnamableSet?
    public let returnPathRefs: [String]
    public let kunlunAscentView: BASKunlunAscentView
    public let kunlunFarWestReserve: BASKunlunFarWestReserve?

    public static func compute(
        hostID: String,
        sessionID: String,
        turnID: String,
        unknownRefs: [String],
        assertionCeiling: BASUnknownAssertionCeiling,
        riskLevel: BASBrainRiskLevel,
        candidates: [BASCandidatePath]
    ) -> BASTurnAuditProjectionsKunlunHexaTwo {
        let hostJade = BASKunlunLayerProjections
            .HostJadeRegister.derive(
                hostID: hostID,
                sessionID: sessionID,
                turnID: turnID)
        let mirror = BASKunlunLayerProjections
            .JadeMirrorDraft.derive(
                unknownRefs: unknownRefs,
                anchorRef:
                    "human-anchor-\(sessionID)",
                turnID: turnID)
        let unnamable = BASKunlunLayerProjections
            .KunlunUnnamableSet.derive(
                unknownRefs: unknownRefs,
                preservationPolicy: "await-evidence",
                turnID: turnID)
        let first = candidates.first
        let refs = candidates.map {
            "return-path:\($0.candidateID)"
        }
        let ascent = BASKunlunLayerProjections
            .AscentView.derive(
                candidateID: first?.candidateID,
                confidence: first?.confidence ?? 0,
                reversibility:
                    first?.reversibility ?? 1,
                riskLevel: riskLevel,
                returnPathRefs: refs,
                turnID: turnID)
        let farWest = BASKunlunLayerProjections
            .FarWestReserve.derive(
                unknownRefs: unknownRefs,
                assertionCeiling: assertionCeiling,
                riskLevel: riskLevel,
                turnID: turnID)
        return BASTurnAuditProjectionsKunlunHexaTwo(
            hostJadeRegister: hostJade,
            jadeMirrorDraft: mirror,
            kunlunUnnamableSet: unnamable,
            returnPathRefs: refs,
            kunlunAscentView: ascent,
            kunlunFarWestReserve: farWest)
    }
}
