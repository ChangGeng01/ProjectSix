// MARK: - BASTurnAuditProjectionsCthulhuPenta
// chapter 四百八十六 / M1322 — V1 cluster B start

import Foundation
import BASOrchestration
import BASPolicy
import BASRuntimeCore
import BASWorldPrior

public struct BASTurnAuditProjectionsCthulhuPenta:
    Codable, Hashable, Sendable
{
    public let abyssalOrganAlias: BASAbyssalOrganAlias
    public let humanAnchorProfile: BASHumanAnchorProfile
    public let sealedMemory: BASSealedMemory?
    public let cosmicScaleView: BASCosmicScaleView
    public let ontologyFog: BASOntologyFog

    public static func compute(
        routedBudget: BASBudgetFrame,
        runMode: BASEBrainRunMode,
        hostID: String,
        riskLevel: BASBrainRiskLevel,
        memoryTemperatureLayer: BASMemoryTemperatureLayer,
        candidates: [BASCandidatePath],
        unknownRefs: [String],
        assertionCeilingRaw: String,
        turnID: String
    ) -> BASTurnAuditProjectionsCthulhuPenta {
        let abyssal = BASCthulhuLeftoverProjections
            .AbyssalOrganAlias.derive(from: runMode)
        let anchor = BASCthulhuLeftoverProjections
            .HumanAnchorProfile.derive(
                hostID: hostID,
                riskLevel: riskLevel,
                turnID: turnID)
        let sealed = BASCthulhuLeftoverProjections
            .SealedMemory.derive(
                from: memoryTemperatureLayer,
                turnID: turnID)
        let cosmic = BASCthulhuLayerProjections
            .CosmicScaleView.derive(
                from: routedBudget,
                turnID: turnID,
                observedSubjectRef: candidates
                    .first?.candidateID
                    ?? "no-candidate")
        let fog = BASCthulhuLayerProjections
            .OntologyFog.derive(
                unknownRefs: unknownRefs,
                assertionCeilingRawValue:
                    assertionCeilingRaw,
                turnID: turnID)
        return BASTurnAuditProjectionsCthulhuPenta(
            abyssalOrganAlias: abyssal,
            humanAnchorProfile: anchor,
            sealedMemory: sealed,
            cosmicScaleView: cosmic,
            ontologyFog: fog)
    }
}
