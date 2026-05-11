// MARK: - BASTurnAuditProjectionsKunlunHexa
// chapter 四百八十五 / M1316 — V1 cluster A continuation
//
// Folds 6 more ForAudit declarations (yaochiMemoryLayer +
// tianhengProfile + jadePermitGrade + ascentBranches +
// restSteps + returnPaths) at coordinator lines 1258-1289。
// Sibling of the M1288 BASTurnAuditProjectionsKunlunTrio
// (which folded the first 3 declarations)。
//
// V1 fold progress: 3 (M1289) + 6 (M1317) = 9 of 18
// cluster-A ForAudit declarations folded into typed bundles。
//
// Byte-equality preserved by construction:factory dispatches
// the same 6 derive calls in the same order as monolith。
// Stress-sweep dual mode (M1290) is the regression guard。

import Foundation
import BASOrchestration
import BASPolicy
import BASRuntimeCore

public struct BASTurnAuditProjectionsKunlunHexa:
    Hashable, Sendable
{
    public let yaochiMemoryLayer:
        BASYaochiMemoryLayer
    public let tianhengProfile: BASTianhengProfile
    public let jadePermitGrade: BASJadePermitGrade
    public let ascentBranches: [BASAscentBranch]
    public let restSteps: [BASRestStep]
    public let returnPaths: [BASReturnPath]

    public init(
        yaochiMemoryLayer: BASYaochiMemoryLayer,
        tianhengProfile: BASTianhengProfile,
        jadePermitGrade: BASJadePermitGrade,
        ascentBranches: [BASAscentBranch],
        restSteps: [BASRestStep],
        returnPaths: [BASReturnPath]
    ) {
        self.yaochiMemoryLayer = yaochiMemoryLayer
        self.tianhengProfile = tianhengProfile
        self.jadePermitGrade = jadePermitGrade
        self.ascentBranches = ascentBranches
        self.restSteps = restSteps
        self.returnPaths = returnPaths
    }

    /// Compute all 6 projections in the SAME ORDER as
    /// coordinator monolith lines 1258-1289。
    public static func compute(
        runMode: BASEBrainRunMode,
        riskLevel: BASBrainRiskLevel,
        permit: BASActionPermit,
        candidates: [BASCandidatePath],
        turnID: String
    ) -> BASTurnAuditProjectionsKunlunHexa {
        let yaochi = BASKunlunLayerProjections
            .YaochiMemoryLayer.derive(
                from: runMode, turnID: turnID)
        let tianheng = BASKunlunLayerProjections
            .TianhengProfile.derive(
                from: riskLevel,
                permitMode: permit.mode,
                turnID: turnID)
        let jadePermit = BASKunlunLayerProjections
            .JadePermitGrade.derive(
                from: permit, turnID: turnID)
        let ascent = candidates.map { c in
            BASKunlunLayerProjections.AscentBranch
                .derive(from: c, turnID: turnID)
        }
        let rest = candidates.compactMap { c in
            BASKunlunLayerProjections.RestStep
                .derive(from: c, turnID: turnID)
        }
        let returns = candidates.map { c in
            BASKunlunLayerProjections.ReturnPath
                .derive(from: c, turnID: turnID)
        }
        return BASTurnAuditProjectionsKunlunHexa(
            yaochiMemoryLayer: yaochi,
            tianhengProfile: tianheng,
            jadePermitGrade: jadePermit,
            ascentBranches: ascent,
            restSteps: rest,
            returnPaths: returns)
    }
}
