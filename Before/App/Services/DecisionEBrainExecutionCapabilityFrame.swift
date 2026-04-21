import Foundation
import BASHostKit

enum DecisionEBrainFoundationTier: String, Codable, Equatable, Sendable {
    case deterministicOnly
    case systemManaged
    case gemmaLocal
    case openModelHeuristic
    case openModelDedicated
    case testingOverride
}

enum DecisionEBrainFoundationPosture: String, Codable, Equatable, Sendable {
    case trustedProduction
    case compatiblePreview
    case heuristicPreview
    case deterministicFallback
    case testingOnly
}

enum DecisionEBrainHorizonStabilityTier: String, Codable, Equatable, Sendable {
    case invariant
    case semiStable
    case volatile
}

enum DecisionEBrainEvidenceGradient: String, Codable, Equatable, Sendable {
    case grounded
    case supported
    case heuristic
    case ruleBound
    case synthetic
}

enum DecisionEBrainTemporalRefreshRequirement: String, Codable, Equatable, Sendable {
    case embedded
    case scheduled
    case perUse
    case testingOnly
}

enum DecisionEBrainTemporalDecayPolicy: String, Codable, Equatable, Sendable {
    case none
    case checkpointRefresh
    case sessionRecompute
    case explicitReset
}

enum DecisionEBrainTemporalTimeScope: String, Codable, Equatable, Sendable {
    case crossSession
    case runtimeWindow
    case currentSession
}

enum DecisionEBrainEvidenceClaimType: String, Codable, Equatable, Sendable {
    case worldStructure
    case boundedGeneralization
    case heuristicEstimate
    case ruleFallback
    case syntheticFixture
}

struct DecisionEBrainWorldPriorContract: Codable, Equatable, Sendable {
    let priorID: String
    let posture: DecisionEBrainFoundationPosture
    let boundaryID: String
    let hostIsolationID: String
    let sessionIsolationID: String
    let toolTruthModeID: String
}

struct DecisionEBrainTemporalKnowledgeContract: Codable, Equatable, Sendable {
    let tier: DecisionEBrainHorizonStabilityTier
    let refreshRequirement: DecisionEBrainTemporalRefreshRequirement
    let decayPolicy: DecisionEBrainTemporalDecayPolicy
    let timeScope: DecisionEBrainTemporalTimeScope
}

struct DecisionEBrainEvidenceContract: Codable, Equatable, Sendable {
    let gradient: DecisionEBrainEvidenceGradient
    let claimType: DecisionEBrainEvidenceClaimType
    let requiresCaveat: Bool
    let requiresExternalRefresh: Bool
}

struct DecisionEBrainPersistenceContract: Codable, Equatable, Sendable {
    let volatileClaimWriteModeID: String
    let contaminatedWriteModeID: String
    let minimumDurableEvidenceCount: Int
    let forceStageNonContinuityDrafts: Bool
    let evidencePendingTagIDs: [String]
}

struct DecisionEBrainExecutionCapabilityFrame: Equatable, Sendable {
    let activeProvider: DecisionModelProviderKind
    let preferredProvider: DecisionModelProviderPreference
    let fallbackProvider: DecisionModelProviderKind?
    let providerTrack: DecisionModelProviderTrack
    let executionTier: DecisionIntelligenceExecutionTier
    let foundationTier: DecisionEBrainFoundationTier
    let reasonCodes: [String]
    let worldPriorContractOverride: DecisionEBrainWorldPriorContract?
    let temporalKnowledgeContractOverride: DecisionEBrainTemporalKnowledgeContract?
    let evidenceContractOverride: DecisionEBrainEvidenceContract?

    init(
        activeProvider: DecisionModelProviderKind,
        preferredProvider: DecisionModelProviderPreference,
        fallbackProvider: DecisionModelProviderKind?,
        providerTrack: DecisionModelProviderTrack,
        executionTier: DecisionIntelligenceExecutionTier,
        foundationTier: DecisionEBrainFoundationTier,
        reasonCodes: [String],
        worldPriorContractOverride: DecisionEBrainWorldPriorContract? = nil,
        temporalKnowledgeContractOverride: DecisionEBrainTemporalKnowledgeContract? = nil,
        evidenceContractOverride: DecisionEBrainEvidenceContract? = nil
    ) {
        self.activeProvider = activeProvider
        self.preferredProvider = preferredProvider
        self.fallbackProvider = fallbackProvider
        self.providerTrack = providerTrack
        self.executionTier = executionTier
        self.foundationTier = foundationTier
        self.reasonCodes = reasonCodes
        self.worldPriorContractOverride = worldPriorContractOverride
        self.temporalKnowledgeContractOverride = temporalKnowledgeContractOverride
        self.evidenceContractOverride = evidenceContractOverride
    }

    var activeProviderID: String { activeProvider.rawValue }
    var preferredProviderID: String { preferredProvider.rawValue }
    var fallbackProviderID: String? { fallbackProvider?.rawValue }
    var providerTrackID: String { providerTrack.rawValue }
    var executionTierID: String { executionTier.rawValue }
    var foundationTierID: String { foundationTier.rawValue }
    var foundationPosture: DecisionEBrainFoundationPosture {
        worldPriorContract.posture
    }
    var foundationPostureID: String { foundationPosture.rawValue }
    var worldPriorID: String { worldPriorContract.priorID }
    var worldPriorContract: DecisionEBrainWorldPriorContract {
        worldPriorContractOverride ?? Self.defaultWorldPriorContract(for: foundationTier)
    }
    var stabilityTier: DecisionEBrainHorizonStabilityTier {
        temporalKnowledgeContract.tier
    }
    var stabilityTierID: String { stabilityTier.rawValue }
    var evidenceGradient: DecisionEBrainEvidenceGradient {
        evidenceContract.gradient
    }
    var evidenceGradientID: String { evidenceGradient.rawValue }
    var temporalKnowledgeContract: DecisionEBrainTemporalKnowledgeContract {
        temporalKnowledgeContractOverride ?? Self.defaultTemporalKnowledgeContract(for: foundationTier)
    }
    var evidenceContract: DecisionEBrainEvidenceContract {
        evidenceContractOverride ?? Self.defaultEvidenceContract(for: foundationTier)
    }
    var persistenceContract: DecisionEBrainPersistenceContract {
        Self.persistenceContract(
            from: memoryPersistencePolicy
        )
    }
    var repositoryBoundaryID: String { worldPriorContract.boundaryID }
    var hostIsolationID: String { worldPriorContract.hostIsolationID }
    var sessionIsolationID: String { worldPriorContract.sessionIsolationID }
    var toolTruthModeID: String { worldPriorContract.toolTruthModeID }
    var memoryPersistencePolicy: BASMemoryHorizonPersistencePolicy {
        BASMemoryHorizonPersistencePolicy.unrestricted.applying(
            executionCapabilityFrame: self
        )
    }

    var detailLine: String {
        DecisionEvolutionNarrativeFormattingSupport.joined(
            [
                "Capability \(executionTierID)",
                "Foundation \(foundationTierID)",
                "Posture \(foundationPostureID)",
                "Boundary \(repositoryBoundaryID)",
                "Active \(activeProvider.title)",
                "Preferred \(preferredProvider.title)",
                "Track \(providerTrackID)",
                fallbackProvider.map { "Fallback \($0.title)" }
            ].compactMap { $0 }
        )
    }

    var horizonLine: String {
        DecisionEvolutionNarrativeFormattingSupport.joined(
            [
                "Horizon \(worldPriorID)",
                "Stability \(stabilityTierID)",
                "Evidence \(evidenceGradientID)",
                "Host \(hostIsolationID)",
                "Session \(sessionIsolationID)",
                "Tool \(toolTruthModeID)"
            ]
        )
    }

    var temporalLine: String {
        DecisionEvolutionNarrativeFormattingSupport.joined(
            [
                "Temporal \(temporalKnowledgeContract.tier.rawValue)",
                "Refresh \(temporalKnowledgeContract.refreshRequirement.rawValue)",
                "Decay \(temporalKnowledgeContract.decayPolicy.rawValue)",
                "Scope \(temporalKnowledgeContract.timeScope.rawValue)"
            ]
        )
    }

    var evidenceLine: String {
        DecisionEvolutionNarrativeFormattingSupport.joined(
            [
                "Evidence \(evidenceContract.gradient.rawValue)",
                "Claim \(evidenceContract.claimType.rawValue)",
                "Caveat \(evidenceContract.requiresCaveat ? "yes" : "no")",
                "External refresh \(evidenceContract.requiresExternalRefresh ? "yes" : "no")"
            ]
        )
    }

    var persistenceLine: String {
        let persistenceContract = persistenceContract
        let pendingTags = persistenceContract.evidencePendingTagIDs.isEmpty
            ? "none"
            : persistenceContract.evidencePendingTagIDs.joined(separator: ",")

        return DecisionEvolutionNarrativeFormattingSupport.joined(
            [
                "Persistence volatile \(persistenceContract.volatileClaimWriteModeID)",
                "contaminated \(persistenceContract.contaminatedWriteModeID)",
                "min durable evidence \(persistenceContract.minimumDurableEvidenceCount)",
                "force stage \(persistenceContract.forceStageNonContinuityDrafts ? "yes" : "no")",
                "pending tags \(pendingTags)"
            ]
        )
    }
}

struct DecisionEBrainKernelFrame: Equatable, Sendable {
    let runModeID: String
    let runModeTitle: String
    let riskLevelID: String
    let permitModeID: String
    let wakeIntentLevelID: String?
    let wakeIntentPreferredModeID: String?
    let vitalWakeStateID: String?
    let maintenanceClassID: String?
    let leaseID: String?
    let leaseExpiresAt: Date?
    let emergencyBrakeLevelID: String?
    let emergencyBrakeReasonCodes: [String]
    let sovereignVerdictLevelID: String?
    let sovereignReasonCodes: [String]
    let sovereignCommitScopeIDs: [String]
    let sovereignLockScopeID: String?
    let sovereignQuarantineZoneIDs: [String]
    let sovereignAuditRuleIDs: [String]
    let sovereignAuditRef: String?
    let sovereignCommandKinds: [String]
    let sovereignExecutionKinds: [String]
    let sovereignExecutionLatencyMs: [Int]
    let policyBundleVersion: String?
    let policyDecisionIDs: [String]
    let recoveryDispositionKindID: String?
    let recoveryDispositionSummary: String?
    let diagnosticsPresentation: DecisionEvolutionTurnDiagnosticsPresentation
    let executionCapabilityFrame: DecisionEBrainExecutionCapabilityFrame?
    let morphGraph: BASMorphGraph?
    let hotColdMap: BASHotColdMap?
    let precisionProfile: BASPrecisionProfile?
    let lungState: BASLungState?
    let thermalExchange: BASThermalExchangeFrame?
    let breathScheduler: BASBreathSchedulerFrame?
    let integrityWeave: BASIntegrityWeaveFrame?
    let organPackages: [BASOrganPackage]
    let organDeltaPlan: BASOrganDeltaPlan?
    let resumeFrame: BASResumeFrame?
    let rollbackAnchor: BASRollbackAnchor?
    let sovereignBridgeResult: DecisionFoldedLungSovereignBridgeResult?

    var layerStackLines: [String] {
        diagnosticsPresentation.layerStackLines
    }
}

struct DecisionEBrainPresentationFrame: Equatable, Sendable {
    let sourceDescriptor: DecisionEvolutionSourceDescriptor
    let runModeTitle: String
    let taskTitle: String
    let riskTitle: String
    let permitTitle: String
    let riskLevelID: String
    let mirrorText: String
    let routeText: String
    let hostText: String
    let replayText: String
    let auditLines: [String]
    let activeKillSwitchesLine: String?
    let recommendedKillSwitchesLine: String?
    let layerStackLines: [String]
    let candidateTitles: [String]
    let memorySummaries: [String]
    let triScoreLines: [String]
    let riskFactorsLine: String?
    let reasonCodesLine: String?
    let alternativeActions: [String]
    let thoughtFoldLines: [String]
    let replayTraceLines: [String]
    let ticketSummary: String?
    let executionCapabilityLine: String?
    let horizonLine: String?
    let temporalLine: String?
    let evidenceLine: String?
    let worldPriorContract: DecisionEBrainWorldPriorContract?
    let temporalKnowledgeContract: DecisionEBrainTemporalKnowledgeContract?
    let evidenceContract: DecisionEBrainEvidenceContract?
    let persistenceLine: String?
    let persistenceContract: DecisionEBrainPersistenceContract?
    let neuralPostureLine: String?
    let sovereignVerdictLine: String?
    let sovereignAuthorityLine: String?
    let sovereignAuditLine: String?
    let policyLine: String?
    let recoveryLine: String?
    let sovereignExecutionLine: String?
    let morphLine: String?
    let hotColdLine: String?
    let precisionLine: String?
    let organPackageLine: String?
    let lungLine: String?
    let organDeltaLine: String?
    let thermalExchangeLine: String?
    let schedulerLine: String?
    let integrityWeaveLine: String?
    let resumeLine: String?
    let rollbackLine: String?
    let sovereignBridgeLine: String?
    let sovereignBridgeDetailLines: [String]
}

extension DecisionEBrainKernelFrame {
    static func build(
        from turn: BASEBrainTurnResult,
        executionCapabilityFrame: DecisionEBrainExecutionCapabilityFrame? = nil
    ) -> DecisionEBrainKernelFrame {
        let foldedLung = DecisionFoldedLungCoordinator.snapshot(for: turn)

        return DecisionEBrainKernelFrame(
            runModeID: turn.budgetFrame.runMode.rawValue,
            runModeTitle: turn.budgetFrame.runMode.displayTitle,
            riskLevelID: turn.riskCard.riskLevel.rawValue,
            permitModeID: turn.actionPermit.mode.rawValue,
            wakeIntentLevelID: turn.wakeIntent.intentLevel.rawValue,
            wakeIntentPreferredModeID: turn.wakeIntent.preferredMode.rawValue,
            vitalWakeStateID: turn.vitalState.wakeState.rawValue,
            maintenanceClassID: turn.budgetFrame.maintenanceClass.rawValue,
            leaseID: turn.runLease?.leaseID ?? turn.budgetFrame.leaseID,
            leaseExpiresAt: turn.runLease?.expiresAt ?? turn.budgetFrame.leaseExpiresAt,
            emergencyBrakeLevelID: turn.emergencyBrake.brakeLevel.rawValue,
            emergencyBrakeReasonCodes: turn.emergencyBrake.reasonCodes,
            sovereignVerdictLevelID: turn.sovereignVerdict?.verdictLevel.rawValue,
            sovereignReasonCodes: turn.sovereignVerdict?.reasonCodes ?? [],
            sovereignCommitScopeIDs: turn.sovereignCommitTokens.map(\.scope.rawValue),
            sovereignLockScopeID: turn.sovereignLock?.scope.rawValue,
            sovereignQuarantineZoneIDs: turn.quarantineRecords.map(\.zone.rawValue),
            sovereignAuditRuleIDs: turn.sovereignAuditEntry?.ruleIDs ?? [],
            sovereignAuditRef: turn.sovereignAuditEntry?.auditID ?? turn.sovereignVerdict?.auditRef,
            sovereignCommandKinds: turn.sovereignActuationCommands.map(\.kind.rawValue),
            sovereignExecutionKinds: turn.sovereignExecutionReceipts.map(\.kind.rawValue),
            sovereignExecutionLatencyMs: turn.sovereignExecutionReceipts.map(\.latencyMs),
            policyBundleVersion: turn.policyLineage?.bundleVersion ?? turn.budgetFrame.policyBundleVersion,
            policyDecisionIDs: turn.policyLineage?.policyDecisionIDs ?? turn.budgetFrame.policyDecisionIDs,
            recoveryDispositionKindID: turn.recoveryDisposition?.kind.rawValue,
            recoveryDispositionSummary: turn.recoveryDisposition?.summary,
            diagnosticsPresentation: turn.diagnosticsPresentation,
            executionCapabilityFrame: executionCapabilityFrame,
            morphGraph: foldedLung.morphGraph,
            hotColdMap: foldedLung.hotColdMap,
            precisionProfile: foldedLung.precisionProfile,
            lungState: foldedLung.lungState,
            thermalExchange: foldedLung.thermalExchange,
            breathScheduler: foldedLung.breathScheduler,
            integrityWeave: foldedLung.integrityWeave,
            organPackages: foldedLung.organPackages,
            organDeltaPlan: foldedLung.organDeltaPlan,
            resumeFrame: foldedLung.resumeFrame,
            rollbackAnchor: foldedLung.rollbackAnchor,
            sovereignBridgeResult: foldedLung.sovereignBridgeResult
        )
    }
}

extension DecisionEBrainPresentationFrame {
    static func build(
        from turn: BASEBrainTurnResult,
        executionCapabilityFrame: DecisionEBrainExecutionCapabilityFrame? = nil
    ) -> DecisionEBrainPresentationFrame {
        let diagnostics = turn.diagnosticsPresentation
        let foldedLung = DecisionFoldedLungCoordinator.snapshot(for: turn)

        return DecisionEBrainPresentationFrame(
            sourceDescriptor: diagnostics.sourceDescriptor,
            runModeTitle: diagnostics.runModeTitle,
            taskTitle: diagnostics.taskTitle,
            riskTitle: diagnostics.riskTitle,
            permitTitle: diagnostics.permitTitle,
            riskLevelID: turn.riskCard.riskLevel.rawValue,
            mirrorText: diagnostics.mirrorText,
            routeText: diagnostics.routeText,
            hostText: diagnostics.hostText,
            replayText: diagnostics.replayText,
            auditLines: diagnostics.auditLines,
            activeKillSwitchesLine: diagnostics.activeKillSwitchesLine,
            recommendedKillSwitchesLine: diagnostics.recommendedKillSwitchesLine,
            layerStackLines: diagnostics.layerStackLines,
            candidateTitles: diagnostics.candidateTitles,
            memorySummaries: diagnostics.memorySummaries,
            triScoreLines: diagnostics.triScoreLines,
            riskFactorsLine: diagnostics.riskFactorsLine,
            reasonCodesLine: diagnostics.reasonCodesLine,
            alternativeActions: diagnostics.alternativeActions,
            thoughtFoldLines: diagnostics.thoughtFoldLines,
            replayTraceLines: diagnostics.replayTraceLines,
            ticketSummary: diagnostics.ticketSummary,
            executionCapabilityLine: executionCapabilityFrame?.detailLine,
            horizonLine: executionCapabilityFrame?.horizonLine,
            temporalLine: executionCapabilityFrame?.temporalLine,
            evidenceLine: executionCapabilityFrame?.evidenceLine,
            worldPriorContract: executionCapabilityFrame?.worldPriorContract,
            temporalKnowledgeContract: executionCapabilityFrame?.temporalKnowledgeContract,
            evidenceContract: executionCapabilityFrame?.evidenceContract,
            persistenceLine: executionCapabilityFrame?.persistenceLine,
            persistenceContract: executionCapabilityFrame?.persistenceContract,
            neuralPostureLine: neuralPostureLine(from: turn),
            sovereignVerdictLine: sovereignVerdictLine(from: turn),
            sovereignAuthorityLine: sovereignAuthorityLine(from: turn),
            sovereignAuditLine: sovereignAuditLine(from: turn),
            policyLine: policyLine(from: turn),
            recoveryLine: recoveryLine(from: turn),
            sovereignExecutionLine: sovereignExecutionLine(from: turn),
            morphLine: foldedLung.morphLine,
            hotColdLine: foldedLung.hotColdLine,
            precisionLine: foldedLung.precisionLine,
            organPackageLine: foldedLung.organPackageLine,
            lungLine: foldedLung.breathLine,
            organDeltaLine: foldedLung.organDeltaLine,
            thermalExchangeLine: foldedLung.thermalExchangeLine,
            schedulerLine: foldedLung.schedulerLine,
            integrityWeaveLine: foldedLung.integrityWeaveLine,
            resumeLine: foldedLung.resumeLine,
            rollbackLine: foldedLung.rollbackLine,
            sovereignBridgeLine: foldedLung.sovereignBridgeLine,
            sovereignBridgeDetailLines: foldedLung.sovereignBridgeSupplementalLines
        )
    }

    private static func policyLine(from turn: BASEBrainTurnResult) -> String? {
        guard let policyLineage = turn.policyLineage else {
            return nil
        }

        return DecisionEvolutionNarrativeFormattingSupport.joined([
            "Policy \(policyLineage.bundleVersion)",
            "routing \(policyLineage.providerRoutingPolicyID)",
            "tuning \(policyLineage.runtimeTuningPolicyID)"
        ])
    }

    private static func sovereignVerdictLine(from turn: BASEBrainTurnResult) -> String? {
        guard let sovereignVerdict = turn.sovereignVerdict else {
            return nil
        }

        let reasonSummary = sovereignVerdict.reasonCodes
            .prefix(2)
            .joined(separator: ", ")

        return DecisionEvolutionNarrativeFormattingSupport.joined(
            [
                "Sovereign verdict \(sovereignVerdict.verdictLevel.rawValue)",
                sovereignVerdict.latched ? "latched" : nil,
                sovereignVerdict.forcedMode.map { "mode \($0.rawValue)" },
                reasonSummary.isEmpty ? nil : "reasons \(reasonSummary)"
            ].compactMap { $0 }
        )
    }

    private static func sovereignAuthorityLine(from turn: BASEBrainTurnResult) -> String? {
        let tokenScopeSummary = turn.sovereignCommitTokens.map(\.scope.rawValue)
        let quarantineZones = turn.quarantineRecords.map(\.zone.rawValue)

        guard
            tokenScopeSummary.isEmpty == false
                || turn.sovereignLock != nil
                || quarantineZones.isEmpty == false
        else {
            return nil
        }

        return DecisionEvolutionNarrativeFormattingSupport.joined(
            [
                tokenScopeSummary.isEmpty ? nil : "tokens \(tokenScopeSummary.joined(separator: ", "))",
                turn.sovereignLock.map { "lock \($0.scope.rawValue)" },
                quarantineZones.isEmpty ? nil : "quarantine \(quarantineZones.joined(separator: ", "))"
            ].compactMap { $0 }
        )
    }

    private static func sovereignAuditLine(from turn: BASEBrainTurnResult) -> String? {
        guard let sovereignAuditEntry = turn.sovereignAuditEntry else {
            return nil
        }

        let ruleSummary = sovereignAuditEntry.ruleIDs
            .prefix(3)
            .joined(separator: ", ")

        return DecisionEvolutionNarrativeFormattingSupport.joined(
            [
                "Sovereign audit",
                ruleSummary.isEmpty ? nil : ruleSummary,
                "ref \(sovereignAuditEntry.auditID)"
            ].compactMap { $0 }
        )
    }

    private static func recoveryLine(from turn: BASEBrainTurnResult) -> String? {
        guard let recoveryDisposition = turn.recoveryDisposition else {
            return nil
        }

        return DecisionEvolutionNarrativeFormattingSupport.joined([
            recoveryDisposition.kind.rawValue.uppercased(),
            recoveryDisposition.summary
        ])
    }

    private static func sovereignExecutionLine(from turn: BASEBrainTurnResult) -> String? {
        guard turn.sovereignExecutionReceipts.isEmpty == false else {
            return nil
        }

        let receiptSummary = turn.sovereignExecutionReceipts.map { receipt in
            "\(receipt.kind.rawValue) \(receipt.latencyMs)ms"
        }.joined(separator: ", ")

        return DecisionEvolutionNarrativeFormattingSupport.joined([
            "Sovereign execution",
            receiptSummary
        ])
    }

    private static func neuralPostureLine(from turn: BASEBrainTurnResult) -> String? {
        guard let organMap = turn.thoughtFrame.organMap else {
            return nil
        }

        let organSummary = organMap.activeOrgans
            .map(\.rawValue)
            .prefix(4)
            .joined(separator: ", ")
        let headSummary = organMap.headGuarantees
            .prefix(3)
            .joined(separator: ", ")

        return DecisionEvolutionNarrativeFormattingSupport.joined([
            "Neural posture \(organMap.morph.rawValue)",
            organSummary.isEmpty ? nil : "organs \(organSummary)",
            headSummary.isEmpty ? nil : "heads \(headSummary)",
            turn.thoughtFrame.neuralLeaseReceipt?.degraded == true ? "stub ready" : nil
        ].compactMap { $0 })
    }
}

extension BeforeProductCompatibility {
    static func resolvedExecutionCapabilityFrame(
        for preferences: BeforePreferences,
        runtimePolicyResolution: BeforeRuntimePolicyResolution? = nil
    ) -> DecisionEBrainExecutionCapabilityFrame {
        DecisionTestingInterface.runtimeSnapshot(
            preferences: preferences,
            runtimePolicyResolution: runtimePolicyResolution
        ).executionCapabilityFrame
    }

    static func horizonAwareCognitionBehavior(
        for executionCapabilityFrame: DecisionEBrainExecutionCapabilityFrame?
    ) -> BASCognitionBehavior {
        substrateCognitionBehavior.applying(
            executionCapabilityFrame: executionCapabilityFrame
        )
    }

    static func horizonAwareCognitionBehavior(
        for preferences: BeforePreferences,
        runtimePolicyResolution: BeforeRuntimePolicyResolution? = nil
    ) -> BASCognitionBehavior {
        horizonAwareCognitionBehavior(
            for: resolvedExecutionCapabilityFrame(
                for: preferences,
                runtimePolicyResolution: runtimePolicyResolution
            )
        )
    }

    static func horizonAwareMemoryPersistencePolicy(
        for executionCapabilityFrame: DecisionEBrainExecutionCapabilityFrame?
    ) -> BASMemoryHorizonPersistencePolicy {
        BASMemoryHorizonPersistencePolicy.unrestricted.applying(
            executionCapabilityFrame: executionCapabilityFrame
        )
    }

    static func horizonAwareMemoryPersistencePolicy(
        for preferences: BeforePreferences,
        runtimePolicyResolution: BeforeRuntimePolicyResolution? = nil
    ) -> BASMemoryHorizonPersistencePolicy {
        horizonAwareMemoryPersistencePolicy(
            for: resolvedExecutionCapabilityFrame(
                for: preferences,
                runtimePolicyResolution: runtimePolicyResolution
            )
        )
    }
}

extension DecisionEBrainExecutionCapabilityFrame {
    static func build(
        runtimeSnapshot snapshot: DecisionTestingRuntimeSnapshot,
        registeredProviders: [DecisionModelProviderDescriptor]
    ) -> DecisionEBrainExecutionCapabilityFrame {
        let activeProvider = snapshot.runtimeStatus.active

        return DecisionEBrainExecutionCapabilityFrame(
            activeProvider: activeProvider,
            preferredProvider: snapshot.executionProfile.effectiveProviderPreference,
            fallbackProvider: snapshot.runtimeStatus.fallback,
            providerTrack: providerTrack(for: activeProvider, in: registeredProviders),
            executionTier: snapshot.executionProfile.tier,
            foundationTier: foundationTier(for: snapshot),
            reasonCodes: reasonCodes(for: snapshot)
        )
    }

    static func build(from export: DecisionTestingRuntimeExport) -> DecisionEBrainExecutionCapabilityFrame {
        build(
            runtimeSnapshot: export.runtimeSnapshot,
            registeredProviders: export.registeredProviders
        )
    }

    private static func providerTrack(
        for activeProvider: DecisionModelProviderKind,
        in providers: [DecisionModelProviderDescriptor]
    ) -> DecisionModelProviderTrack {
        providers.first(where: { $0.kind == activeProvider })?.track ?? defaultTrack(for: activeProvider)
    }

    private static func foundationTier(
        for snapshot: DecisionTestingRuntimeSnapshot
    ) -> DecisionEBrainFoundationTier {
        if snapshot.testingStubProfile != nil || snapshot.executionProfile.tier == .testingOverride {
            return .testingOverride
        }

        switch snapshot.runtimeStatus.active {
        case .foundationModels:
            return .systemManaged
        case .gemmaE4B:
            return .gemmaLocal
        case .openModel:
            return snapshot.openModelRuntimeStatus?.mode == .dedicatedRuntime
                ? .openModelDedicated
                : .openModelHeuristic
        case .testingStub:
            return .testingOverride
        case .template:
            return .deterministicOnly
        }
    }

    private static func reasonCodes(
        for snapshot: DecisionTestingRuntimeSnapshot
    ) -> [String] {
        let foundationTier = foundationTier(for: snapshot)

        var codes = [
            "tier:\(snapshot.executionProfile.tier.rawValue)",
            "active:\(snapshot.runtimeStatus.active.rawValue)",
            "preferred:\(snapshot.executionProfile.effectiveProviderPreference.rawValue)"
        ]

        if let fallbackProvider = snapshot.runtimeStatus.fallback {
            codes.append("fallback:\(fallbackProvider.rawValue)")
        }
        codes.append("foundation_posture:\(foundationPosture(for: foundationTier).rawValue)")
        codes.append("world_prior:worldPriorFabric")
        codes.append("stability_tier:\(stabilityTier(for: foundationTier).rawValue)")
        codes.append("evidence_gradient:\(evidenceGradient(for: foundationTier).rawValue)")
        codes.append("temporal_refresh:\(temporalRefreshRequirement(for: foundationTier).rawValue)")
        codes.append("temporal_decay:\(temporalDecayPolicy(for: foundationTier).rawValue)")
        codes.append("temporal_scope:\(temporalTimeScope(for: foundationTier).rawValue)")
        codes.append("evidence_claim:\(evidenceClaimType(for: foundationTier).rawValue)")
        codes.append("evidence_caveat:\(requiresEvidenceCaveat(for: foundationTier) ? "yes" : "no")")
        codes.append("external_refresh:\(requiresExternalRefresh(for: foundationTier) ? "yes" : "no")")
        codes.append("repository_boundary:externalTraining")
        codes.append("host_isolation:hostIsolated")
        codes.append("session_isolation:sessionIsolated")
        codes.append("tool_truth_mode:toolRefreshRequired")
        if snapshot.preferences.allowModelFallbacks {
            codes.append("fallbacks_enabled")
        }
        if snapshot.foundationStatus.isAvailable {
            codes.append("foundation_available")
        }
        if snapshot.gemmaProviderStatus.isAvailable {
            codes.append("gemma_available")
        }
        if snapshot.openModelProviderStatus.isAvailable {
            codes.append("open_model_available")
        }
        if let openModelRuntimeStatus = snapshot.openModelRuntimeStatus {
            codes.append("open_model_runtime:\(openModelRuntimeStatus.mode.rawValue)")
        }
        if snapshot.deviceCapabilities.isSimulator {
            codes.append("simulator")
        }
        if snapshot.deviceCapabilities.isLowPowerModeEnabled {
            codes.append("low_power")
        }
        if snapshot.testingStubProfile != nil {
            codes.append("testing_override")
        }

        return orderedUnique(codes)
    }

    private static func defaultTrack(
        for provider: DecisionModelProviderKind
    ) -> DecisionModelProviderTrack {
        switch provider {
        case .foundationModels:
            return .builtInSystem
        case .gemmaE4B, .openModel:
            return .builtInOpenModel
        case .testingStub:
            return .testingOnly
        case .template:
            return .deterministic
        }
    }

    private static func orderedUnique(_ values: [String]) -> [String] {
        values.reduce(into: [String]()) { uniqueValues, value in
            guard !uniqueValues.contains(value) else { return }
            uniqueValues.append(value)
        }
    }

    private static func defaultWorldPriorContract(
        for tier: DecisionEBrainFoundationTier
    ) -> DecisionEBrainWorldPriorContract {
        DecisionEBrainWorldPriorContract(
            priorID: "worldPriorFabric",
            posture: foundationPosture(for: tier),
            boundaryID: "externalTraining",
            hostIsolationID: "hostIsolated",
            sessionIsolationID: "sessionIsolated",
            toolTruthModeID: "toolRefreshRequired"
        )
    }

    private static func foundationPosture(
        for tier: DecisionEBrainFoundationTier
    ) -> DecisionEBrainFoundationPosture {
        switch tier {
        case .systemManaged:
            .trustedProduction
        case .gemmaLocal, .openModelDedicated:
            .compatiblePreview
        case .openModelHeuristic:
            .heuristicPreview
        case .deterministicOnly:
            .deterministicFallback
        case .testingOverride:
            .testingOnly
        }
    }

    private static func stabilityTier(
        for tier: DecisionEBrainFoundationTier
    ) -> DecisionEBrainHorizonStabilityTier {
        switch tier {
        case .systemManaged, .deterministicOnly:
            .invariant
        case .gemmaLocal, .openModelDedicated:
            .semiStable
        case .openModelHeuristic, .testingOverride:
            .volatile
        }
    }

    private static func evidenceGradient(
        for tier: DecisionEBrainFoundationTier
    ) -> DecisionEBrainEvidenceGradient {
        switch tier {
        case .systemManaged:
            .grounded
        case .gemmaLocal, .openModelDedicated:
            .supported
        case .openModelHeuristic:
            .heuristic
        case .deterministicOnly:
            .ruleBound
        case .testingOverride:
            .synthetic
        }
    }

    private static func temporalRefreshRequirement(
        for tier: DecisionEBrainFoundationTier
    ) -> DecisionEBrainTemporalRefreshRequirement {
        switch tier {
        case .systemManaged, .deterministicOnly:
            .embedded
        case .gemmaLocal, .openModelDedicated:
            .scheduled
        case .openModelHeuristic:
            .perUse
        case .testingOverride:
            .testingOnly
        }
    }

    private static func temporalDecayPolicy(
        for tier: DecisionEBrainFoundationTier
    ) -> DecisionEBrainTemporalDecayPolicy {
        switch tier {
        case .systemManaged, .deterministicOnly:
            .none
        case .gemmaLocal, .openModelDedicated:
            .checkpointRefresh
        case .openModelHeuristic:
            .sessionRecompute
        case .testingOverride:
            .explicitReset
        }
    }

    private static func temporalTimeScope(
        for tier: DecisionEBrainFoundationTier
    ) -> DecisionEBrainTemporalTimeScope {
        switch tier {
        case .systemManaged, .deterministicOnly, .gemmaLocal, .openModelDedicated:
            .crossSession
        case .openModelHeuristic:
            .runtimeWindow
        case .testingOverride:
            .currentSession
        }
    }

    private static func evidenceClaimType(
        for tier: DecisionEBrainFoundationTier
    ) -> DecisionEBrainEvidenceClaimType {
        switch tier {
        case .systemManaged:
            .worldStructure
        case .gemmaLocal, .openModelDedicated:
            .boundedGeneralization
        case .openModelHeuristic:
            .heuristicEstimate
        case .deterministicOnly:
            .ruleFallback
        case .testingOverride:
            .syntheticFixture
        }
    }

    private static func requiresEvidenceCaveat(
        for tier: DecisionEBrainFoundationTier
    ) -> Bool {
        switch tier {
        case .systemManaged:
            false
        case .gemmaLocal, .openModelDedicated, .openModelHeuristic, .deterministicOnly, .testingOverride:
            true
        }
    }

    private static func requiresExternalRefresh(
        for tier: DecisionEBrainFoundationTier
    ) -> Bool {
        switch tier {
        case .openModelHeuristic:
            true
        case .systemManaged, .gemmaLocal, .openModelDedicated, .deterministicOnly, .testingOverride:
            false
        }
    }

    private static func defaultTemporalKnowledgeContract(
        for tier: DecisionEBrainFoundationTier
    ) -> DecisionEBrainTemporalKnowledgeContract {
        DecisionEBrainTemporalKnowledgeContract(
            tier: stabilityTier(for: tier),
            refreshRequirement: temporalRefreshRequirement(for: tier),
            decayPolicy: temporalDecayPolicy(for: tier),
            timeScope: temporalTimeScope(for: tier)
        )
    }

    private static func defaultEvidenceContract(
        for tier: DecisionEBrainFoundationTier
    ) -> DecisionEBrainEvidenceContract {
        DecisionEBrainEvidenceContract(
            gradient: evidenceGradient(for: tier),
            claimType: evidenceClaimType(for: tier),
            requiresCaveat: requiresEvidenceCaveat(for: tier),
            requiresExternalRefresh: requiresExternalRefresh(for: tier)
        )
    }

    private static func persistenceContract(
        from policy: BASMemoryHorizonPersistencePolicy
    ) -> DecisionEBrainPersistenceContract {
        DecisionEBrainPersistenceContract(
            volatileClaimWriteModeID: policy.volatileClaimWriteMode.rawValue,
            contaminatedWriteModeID: policy.contaminatedWriteMode.rawValue,
            minimumDurableEvidenceCount: policy.minimumDurableEvidenceCount,
            forceStageNonContinuityDrafts: policy.forceStageNonContinuityDrafts,
            evidencePendingTagIDs: policy.evidencePendingRetrievalTags
        )
    }
}

extension BASBrainCompilationBehavior {
    func applying(
        executionCapabilityFrame: DecisionEBrainExecutionCapabilityFrame?
    ) -> BASBrainCompilationBehavior {
        guard let executionCapabilityFrame else {
            return self
        }

        var adjusted = self
        let evidenceContract = executionCapabilityFrame.evidenceContract
        let temporalContract = executionCapabilityFrame.temporalKnowledgeContract

        if evidenceContract.requiresExternalRefresh {
            adjusted.requireTagOverlapForPendingCandidatesWhenExternalRefreshRequired = true
        }

        if evidenceContract.requiresExternalRefresh,
           temporalContract.tier == .volatile || temporalContract.decayPolicy == .sessionRecompute {
            adjusted.requireTagOverlapForFastDecayCandidatesWhenExternalRefreshRequired = true
        }

        return adjusted
    }
}

extension BASCognitionBehavior {
    func applying(
        executionCapabilityFrame: DecisionEBrainExecutionCapabilityFrame?
    ) -> BASCognitionBehavior {
        guard let executionCapabilityFrame else {
            return self
        }

        var adjusted = self
        adjusted.brainCompilation = brainCompilation.applying(
            executionCapabilityFrame: executionCapabilityFrame
        )
        return adjusted
    }
}

extension BASMemoryHorizonPersistencePolicy {
    func applying(
        executionCapabilityFrame: DecisionEBrainExecutionCapabilityFrame?
    ) -> BASMemoryHorizonPersistencePolicy {
        guard let executionCapabilityFrame else {
            return self
        }

        var adjusted = self
        let evidenceContract = executionCapabilityFrame.evidenceContract

        if evidenceContract.requiresExternalRefresh {
            adjusted.volatileClaimWriteMode = .stageCandidate
            adjusted.forceStageNonContinuityDrafts = true
        }

        if executionCapabilityFrame.worldPriorContract.toolTruthModeID == "toolRefreshRequired" {
            adjusted.contaminatedWriteMode = .quarantineCandidate
        }

        if evidenceContract.requiresCaveat {
            switch evidenceContract.gradient {
            case .grounded:
                break
            case .supported, .ruleBound:
                adjusted.minimumDurableEvidenceCount = max(
                    adjusted.minimumDurableEvidenceCount,
                    2
                )
            case .heuristic, .synthetic:
                adjusted.minimumDurableEvidenceCount = max(
                    adjusted.minimumDurableEvidenceCount,
                    3
                )
            }
        }

        return adjusted
    }
}
