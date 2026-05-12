// MARK: - BASTurnAuditProjectionsKunlunTrioTwo
// chapter 四百八十五 / M1318 — V1 cluster A trio #2

import Foundation
import BASOrchestration
import BASPolicy
import BASRuntimeCore

public struct BASTurnAuditProjectionsKunlunTrioTwo:
    Codable, Hashable, Sendable
{
    public let jadeCasket: BASJadeCasketSnapshot
    public let jadeRefinementTickets:
        [BASJadeRefinementTicket]
    public let jadeFidelityMap: BASJadeFidelityMap

    public static func compute(
        runMode: BASEBrainRunMode,
        riskLevel: BASBrainRiskLevel,
        candidates: [BASCandidatePath],
        organRefMorph: String,
        turnID: String,
        sessionID: String
    ) -> BASTurnAuditProjectionsKunlunTrioTwo {
        let casket = BASKunlunLayerProjections
            .JadeCasketSnapshot.derive(
                turnID: turnID,
                sessionID: sessionID)
        let tickets = candidates.compactMap { c in
            BASKunlunLayerProjections
                .JadeRefinementTicket.derive(
                    from: c, turnID: turnID)
        }
        let fidelity = BASKunlunLayerProjections
            .JadeFidelityMap.derive(
                from: runMode,
                riskLevel: riskLevel,
                organRef: "neural-organ:\(organRefMorph)",
                turnID: turnID)
        return BASTurnAuditProjectionsKunlunTrioTwo(
            jadeCasket: casket,
            jadeRefinementTickets: tickets,
            jadeFidelityMap: fidelity)
    }
}
