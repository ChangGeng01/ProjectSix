import Foundation
import BASMemory
import BASObservability
import BASOrchestration
import BASPolicy
import BASRuntimeCore

// MARK: - M72 split — BASHostRuntimeEBrainNeuralCoreService extracted from the 5039-line
// EBrainHostRuntimeSynthesis.swift.  Previously file-scope `private`, now
// default-internal so sibling files in BASHostKit (the reduced main
// `makeEBrainTurn` orchestrator and any cross-struct helpers) can reference
// it.  None of these members surface through the Qinao public API.

struct BASHostRuntimeEBrainNeuralCoreService: BASNeuralCoreServicing {
    let request: BASHostSessionRequest
    let currentBrain: BASHostCurrentBrain
    let tuning: BASEBrainRuntimeSynthesisPolicy
    let hostConstitution: BASHostConstitution?

    func synthesize(
        budgetFrame: BASBudgetFrame,
        contextFrame: BASContextFrame,
        decomposeFrame: BASDecomposeFrame,
        memoryBundle: BASMemoryBundle,
        hostProfile: BASHostProfile,
        activeKillSwitches: [BASKillSwitchID]
    ) -> BASNeuralCoreFrame {
        let morph = resolvedMorph(
            budgetFrame: budgetFrame,
            contextFrame: contextFrame
        )
        let organMap = BASNeuralOrganMap(
            morph: morph,
            activeOrgans: activeOrgans(for: morph),
            precisionMap: activeOrgans(for: morph).map { organ in
                BASNeuralOrganPrecision(
                    organ: organ,
                    tier: precisionTier(
                        for: organ,
                        morph: morph,
                        precisionProfile: budgetFrame.precisionProfile
                    )
                )
            },
            routingPolicy: routingPolicy(for: morph),
            leaseRef: budgetFrame.leaseID,
            sovereignConstraints: activeKillSwitches.map(\.rawValue),
            headGuarantees: headGuarantees(for: morph)
        )
        let tissueState = BASLatentTissueState(
            scoutState: organMap.activeOrgans.contains(.scoutStrip) ? "task:\(contextFrame.taskType.rawValue)" : nil,
            cortexState: organMap.activeOrgans.contains(.coreCortex) ? "facts:\(decomposeFrame.facts.count)" : nil,
            simuState: organMap.activeOrgans.contains(.simuRing) ? "profile:\(request.workflowProfile.rawValue)" : nil,
            criticState: organMap.activeOrgans.contains(.criticBlade) ? "alerts:\(currentBrain.calibrationAlerts.count)" : nil,
            riskState: organMap.activeOrgans.contains(.riskSpine) ? "risk:\(request.riskLevel.rawValue)" : nil,
            permitState: organMap.activeOrgans.contains(.permitKnot) ? "kills:\(activeKillSwitches.count)" : nil,
            memoryCodecState: organMap.activeOrgans.contains(.memoryCodecRidge) ? "atoms:\(memoryBundle.atoms.count)" : nil,
            hostModState: organMap.activeOrgans.contains(.hostModulationMesh) ? "tone:\(hostProfile.tonePreference)" : nil,
            toolIntentState: organMap.activeOrgans.contains(.toolIntentMesh) ? "intent:bounded" : nil,
            consistencyState: organMap.activeOrgans.contains(.consistencyLattice) ? "stable" : nil,
            stubState: organMap.activeOrgans.contains(.stubCore) ? "stub_ready" : nil
        )
        var degradedReasonCodes: [String] = []
        if morph == .guard && currentBrain.hasProtectiveBoundary {
            degradedReasonCodes.append("host.protective_boundary")
        }
        if morph == .quarantine {
            degradedReasonCodes.append("runtime.quarantine")
        }
        if morph == .stub {
            degradedReasonCodes.append("runtime.stub_only")
        }
        return BASNeuralCoreFrame(
            organMap: organMap,
            tissueState: tissueState,
            degradedReasonCodes: degradedReasonCodes
        )
    }

    func materializeRiskBindings(
        budgetFrame: BASBudgetFrame,
        contextFrame: BASContextFrame,
        thoughtFrame: BASThoughtFrame,
        mergedChoice: BASMergedChoice,
        riskCard: BASRiskCard,
        actionPermit: BASActionPermit
    ) -> [BASRiskPermitBinding] {
        let bindings = BASNeuralMaterializationCompiler.materializeRiskBindings(
            thoughtFrame: thoughtFrame,
            mergedChoice: mergedChoice,
            riskCard: riskCard,
            actionPermit: actionPermit,
            riskLevelResolver: { score in
                let riskTuning = tuning.risk
                switch score {
                case ..<riskTuning.mediumThreshold:
                    return .low
                case ..<riskTuning.highThreshold:
                    return .medium
                case ..<riskTuning.extremeThreshold:
                    return .high
                default:
                    return .extreme
                }
            }
        )

        guard let hostConstitution else {
            return bindings
        }

        return bindings.map { applyConstitutionToolGuard(to: $0, in: hostConstitution) }
    }

    func materializeToolIntent(
        budgetFrame: BASBudgetFrame,
        thoughtFrame: BASThoughtFrame,
        mergedChoice: BASMergedChoice,
        actionPermit: BASActionPermit
    ) -> BASToolIntentEnvelope? {
        guard var envelope = BASNeuralMaterializationCompiler.materializeToolIntent(
            thoughtFrame: thoughtFrame,
            mergedChoice: mergedChoice,
            actionPermit: actionPermit
        ) else {
            return nil
        }

        guard let hostConstitution else {
            return envelope
        }

        let restrictedDomains = constitutionRestrictedToolDomains(in: hostConstitution)
        if restrictedDomains.isEmpty == false {
            envelope.blockedDomains = orderedUnique(envelope.blockedDomains + restrictedDomains)
            let blocked = Set(envelope.blockedDomains)
            envelope.requestedDomains = envelope.requestedDomains.filter { blocked.contains($0) == false }
            envelope.reasonCodes = orderedUnique(
                envelope.reasonCodes + ["constitution.tool_domain_restricted"]
            )
        }

        if hostConstitution.consentLattice.toolWriteScope == "confirm_required" {
            envelope.requireSecondCheck = true
            envelope.reasonCodes = orderedUnique(
                envelope.reasonCodes + ["constitution.tool_write_scope.confirm_required"]
            )
        }

        return envelope
    }

    private func resolvedMorph(
        budgetFrame: BASBudgetFrame,
        contextFrame: BASContextFrame
    ) -> BASNeuralMorph {
        switch budgetFrame.runMode {
        case .dormant, .pulse, .sentinel:
            return .scout
        case .engage, .reflect:
            if request.workflowProfile == .comparative || (contextFrame.taskType == .choice && budgetFrame.maxCandidates > 1) {
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

    private func activeOrgans(
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

    private func routingPolicy(
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

    private func headGuarantees(
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

    private func precisionTier(
        for organ: BASNeuralOrgan,
        morph: BASNeuralMorph,
        precisionProfile: BASRuntimePrecisionProfile
    ) -> BASNeuralPrecisionTier {
        switch organ {
        case .stubCore:
            return .full
        case .riskSpine, .permitKnot:
            return precisionProfile == .full ? .full : .protected
        case .tissueRouter, .consistencyLattice:
            return morph == .guard || morph == .stub || morph == .quarantine ? .protected : .balanced
        case .simuRing, .criticBlade:
            return morph == .deepLoop ? .protected : .balanced
        case .scoutStrip:
            return .minimal
        case .coreCortex:
            switch precisionProfile {
            case .minimal:
                return .minimal
            case .balanced:
                return .balanced
            case .protected:
                return .protected
            case .full:
                return .full
            }
        case .memoryCodecRidge, .hostModulationMesh:
            return .balanced
        case .toolIntentMesh:
            return .minimal
        }
    }

    private func constitutionRestrictedToolDomains(
        in hostConstitution: BASHostConstitution
    ) -> [String] {
        orderedUnique(
            hostConstitution.boundaryVeil.restrictedToolDomains
                + hostConstitution.consentLattice.sensitiveDomainRules
        )
    }

    private func applyConstitutionToolGuard(
        to binding: BASRiskPermitBinding,
        in hostConstitution: BASHostConstitution
    ) -> BASRiskPermitBinding {
        let restrictedDomains = constitutionRestrictedToolDomains(in: hostConstitution)
        let forbiddenDomains = orderedUnique(binding.forbiddenDomains + restrictedDomains)
        let forbiddenSet = Set(forbiddenDomains)
        let allowedDomains = binding.allowedDomains.filter { forbiddenSet.contains($0) == false }

        var reasonCodes = binding.reasonCodes
        if restrictedDomains.isEmpty == false {
            reasonCodes = orderedUnique(reasonCodes + ["constitution.tool_domain_restricted"])
        }

        var requireSecondCheck = binding.requireSecondCheck
        if hostConstitution.consentLattice.toolWriteScope == "confirm_required" {
            requireSecondCheck = true
            reasonCodes = orderedUnique(
                reasonCodes + ["constitution.tool_write_scope.confirm_required"]
            )
        }

        return BASRiskPermitBinding(
            schemaVersion: binding.schemaVersion,
            candidateID: binding.candidateID,
            riskLevel: binding.riskLevel,
            totalRisk: binding.totalRisk,
            uncertainty: binding.uncertainty,
            irreversibility: binding.irreversibility,
            manipulationStrength: binding.manipulationStrength,
            gsiScore: binding.gsiScore,
            recommendedMode: binding.recommendedMode,
            permitMode: binding.permitMode,
            stackedModes: binding.stackedModes,
            assertionCeiling: binding.assertionCeiling,
            toolScope: binding.toolScope,
            memoryScope: binding.memoryScope,
            requireSecondCheck: requireSecondCheck,
            outputLengthCap: binding.outputLengthCap,
            tonePolicy: binding.tonePolicy,
            templatePolicy: binding.templatePolicy,
            reasonCodes: reasonCodes,
            allowedDomains: allowedDomains,
            forbiddenDomains: forbiddenDomains,
            delayType: binding.delayType,
            substituteType: binding.substituteType,
            sovereignHintLevel: binding.sovereignHintLevel
        )
    }

    private func orderedUnique(
        _ values: [String]
    ) -> [String] {
        var seen = Set<String>()
        return values.filter { !$0.isEmpty && seen.insert($0).inserted }
    }
}
