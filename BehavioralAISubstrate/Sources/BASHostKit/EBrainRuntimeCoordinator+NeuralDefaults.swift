import CryptoKit
import Foundation
import BASMemory
import BASObservability
import BASOrchestration
import BASPolicy
import BASRuntimeCore

// MARK: - M71 split — BASEBrainRuntimeCoordinator — neural default-frame fallbacks.
// defaultNeuralCoreFrame / defaultMorph / defaultActiveOrgans / defaultRoutingPolicy /
// defaultHeadGuarantees / defaultPrecisionMap / defaultPrecisionTier.  Provide L2/L3
// skeleton frames when the neural core service is unavailable or under-provisioned.
// Extracted from the 6099-line monolith during the M71 cohesion split.

extension BASEBrainRuntimeCoordinator {
    func defaultNeuralCoreFrame(
        budgetFrame: BASBudgetFrame,
        contextFrame: BASContextFrame,
        decomposeFrame: BASDecomposeFrame,
        memoryBundle: BASMemoryBundle,
        hostProfile: BASHostProfile,
        activeKillSwitches: [BASKillSwitchID]
    ) -> BASNeuralCoreFrame {
        let morph = defaultMorph(
            budgetFrame: budgetFrame,
            contextFrame: contextFrame
        )
        let organMap = BASNeuralOrganMap(
            morph: morph,
            activeOrgans: defaultActiveOrgans(for: morph),
            precisionMap: defaultPrecisionMap(for: morph, budgetFrame: budgetFrame),
            routingPolicy: defaultRoutingPolicy(for: morph),
            leaseRef: budgetFrame.leaseID,
            sovereignConstraints: activeKillSwitches.map(\.rawValue),
            headGuarantees: defaultHeadGuarantees(for: morph)
        )
        let tissueState = BASLatentTissueState(
            scoutState: organMap.activeOrgans.contains(.scoutStrip) ? "risk:\(contextFrame.taskType.rawValue)" : nil,
            cortexState: organMap.activeOrgans.contains(.coreCortex) ? "facts:\(decomposeFrame.facts.count)" : nil,
            simuState: organMap.activeOrgans.contains(.simuRing) ? "forecasts:pending" : nil,
            criticState: organMap.activeOrgans.contains(.criticBlade) ? "contradictions:\(decomposeFrame.contradictions.count)" : nil,
            riskState: organMap.activeOrgans.contains(.riskSpine) ? "risk:\(contextFrame.consequenceLevel)" : nil,
            permitState: organMap.activeOrgans.contains(.permitKnot) ? "kills:\(activeKillSwitches.count)" : nil,
            memoryCodecState: organMap.activeOrgans.contains(.memoryCodecRidge) ? "atoms:\(memoryBundle.atoms.count)" : nil,
            hostModState: organMap.activeOrgans.contains(.hostModulationMesh) ? "style:\(hostProfile.tonePreference)" : nil,
            toolIntentState: organMap.activeOrgans.contains(.toolIntentMesh) ? "tool:intent_only" : nil,
            consistencyState: organMap.activeOrgans.contains(.consistencyLattice) ? "stable" : nil,
            stubState: organMap.activeOrgans.contains(.stubCore) ? "stub_ready" : nil
        )
        var degradedReasonCodes: [String] = []
        if budgetFrame.runMode == .lockdown {
            degradedReasonCodes.append("runtime.stub_only")
        }
        if budgetFrame.runMode == .quarantine {
            degradedReasonCodes.append("runtime.quarantine")
        }
        return BASNeuralCoreFrame(
            organMap: organMap,
            tissueState: tissueState,
            degradedReasonCodes: unique(degradedReasonCodes)
        )
    }

    func defaultMorph(
        budgetFrame: BASBudgetFrame,
        contextFrame: BASContextFrame
    ) -> BASNeuralMorph {
        switch budgetFrame.runMode {
        case .dormant, .pulse, .sentinel:
            return .scout
        case .engage, .reflect:
            if contextFrame.taskType == .choice, budgetFrame.maxCandidates > 1 {
                return .compare
            }
            return .engage
        case .deepLoop:
            return .deepLoop
        case .guard:
            return .guard
        case .recovery:
            return .rollbackRebuild
        case .quarantine:
            return .quarantine
        case .lockdown:
            return .stub
        }
    }

    func defaultActiveOrgans(
        for morph: BASNeuralMorph
    ) -> [BASNeuralOrgan] {
        switch morph {
        case .scout:
            return [.scoutStrip, .riskSpine, .permitKnot, .stubCore, .tissueRouter]
        case .engage:
            return [.coreCortex, .hostModulationMesh, .consistencyLattice, .stubCore, .tissueRouter]
        case .compare:
            return [.coreCortex, .simuRing, .riskSpine, .permitKnot, .consistencyLattice, .stubCore, .tissueRouter]
        case .deepLoop:
            return [.coreCortex, .simuRing, .criticBlade, .riskSpine, .permitKnot, .memoryCodecRidge, .hostModulationMesh, .toolIntentMesh, .consistencyLattice, .stubCore, .tissueRouter]
        case .guard:
            return [.coreCortex, .criticBlade, .riskSpine, .permitKnot, .consistencyLattice, .stubCore, .tissueRouter]
        case .stub:
            return [.riskSpine, .permitKnot, .stubCore, .tissueRouter]
        case .quarantine:
            return [.coreCortex, .riskSpine, .permitKnot, .memoryCodecRidge, .consistencyLattice, .stubCore, .tissueRouter]
        case .rollbackRebuild:
            return [.coreCortex, .riskSpine, .permitKnot, .memoryCodecRidge, .consistencyLattice, .stubCore, .tissueRouter]
        }
    }

    func defaultRoutingPolicy(
        for morph: BASNeuralMorph
    ) -> BASNeuralRoutingPolicy {
        switch morph {
        case .scout:
            return .scoutProbe
        case .engage:
            return .conversationalBalance
        case .compare:
            return .comparativeFanout
        case .deepLoop:
            return .deepLoopConvergence
        case .guard:
            return .protectiveThrottle
        case .stub:
            return .stubOnly
        case .quarantine:
            return .quarantineIsolation
        case .rollbackRebuild:
            return .rollbackRecovery
        }
    }

    func defaultHeadGuarantees(
        for morph: BASNeuralMorph
    ) -> [String] {
        switch morph {
        case .scout:
            return ["risk_binding", "stub_ready"]
        case .engage:
            return ["host_modulation", "stub_ready"]
        case .compare:
            return ["frontier_projection", "risk_binding", "stub_ready"]
        case .deepLoop:
            return ["frontier_projection", "counterfactual_projection", "critique_projection", "risk_binding", "stub_ready"]
        case .guard:
            return ["risk_binding", "permit_gate", "stub_ready"]
        case .stub:
            return ["risk_binding", "stub_ready"]
        case .quarantine:
            return ["risk_binding", "memory_isolation", "stub_ready"]
        case .rollbackRebuild:
            return ["recovery_rebuild", "risk_binding", "stub_ready"]
        }
    }

    func defaultPrecisionMap(
        for morph: BASNeuralMorph,
        budgetFrame: BASBudgetFrame
    ) -> [BASNeuralOrganPrecision] {
        defaultActiveOrgans(for: morph).map { organ in
            BASNeuralOrganPrecision(
                organ: organ,
                tier: defaultPrecisionTier(
                    for: organ,
                    morph: morph,
                    budgetFrame: budgetFrame
                )
            )
        }
    }

    func defaultPrecisionTier(
        for organ: BASNeuralOrgan,
        morph: BASNeuralMorph,
        budgetFrame: BASBudgetFrame
    ) -> BASNeuralPrecisionTier {
        switch organ {
        case .stubCore:
            return BASNeuralPrecisionTier.full
        case .riskSpine, .permitKnot:
            return budgetFrame.precisionProfile == .full
                ? BASNeuralPrecisionTier.full
                : BASNeuralPrecisionTier.protected
        case .tissueRouter, .consistencyLattice:
            return morph == .stub || morph == .guard || morph == .quarantine
                ? BASNeuralPrecisionTier.protected
                : BASNeuralPrecisionTier.balanced
        case .simuRing, .criticBlade:
            return morph == .deepLoop
                ? BASNeuralPrecisionTier.protected
                : BASNeuralPrecisionTier.balanced
        case .hostModulationMesh, .memoryCodecRidge:
            return BASNeuralPrecisionTier.balanced
        case .toolIntentMesh:
            return morph == .deepLoop
                ? BASNeuralPrecisionTier.balanced
                : BASNeuralPrecisionTier.minimal
        case .scoutStrip:
            return BASNeuralPrecisionTier.minimal
        case .coreCortex:
            switch budgetFrame.precisionProfile {
            case .minimal:
                return BASNeuralPrecisionTier.minimal
            case .balanced:
                return BASNeuralPrecisionTier.balanced
            case .protected:
                return BASNeuralPrecisionTier.protected
            case .full:
                return BASNeuralPrecisionTier.full
            }
        }
    }

}
