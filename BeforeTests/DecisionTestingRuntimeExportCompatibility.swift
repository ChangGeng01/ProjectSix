import Foundation
import BASObservability
import BASPolicy
import BASRuntimeCore
@testable import Before

extension DecisionTestingRuntimeExport {
    var lifecycleSummary: DecisionTestingLifecycleSummary {
        DecisionTestingLifecycleSummary(basSummary: basLifecycleSummary)
    }

    var neuralSummary: DecisionTestingNeuralSummary {
        DecisionTestingNeuralSummary(basSummary: basNeuralSummary)
    }

    var brainSummary: DecisionTestingBrainSummary {
        DecisionTestingBrainSummary(basSummary: basBrainSummary)
    }

    var summary: DecisionTestingRuntimeSummary {
        DecisionTestingRuntimeSummary(basSummary: basRuntimeInspectionSummary)
    }
}

struct DecisionTestingLifecycleSummary: Equatable, Sendable {
    let contextAwareTraceCount: Int
    let rebuildCount: Int
    let rebuildCountByKind: [DecisionIntelligenceTraceKind: Int]
    let staleFieldDropCount: Int
    let staleFieldDropCountByKind: [DecisionIntelligenceTraceKind: Int]
    let retainedEvidenceCount: Int
    let droppedEvidenceCount: Int
    let droppedEvidenceCountByKind: [DecisionIntelligenceTraceKind: Int]
    let droppedInjectedEvidenceCount: Int
    let droppedInjectedEvidenceCountByKind: [DecisionIntelligenceTraceKind: Int]
    let droppedDuplicateEvidenceCount: Int
    let droppedDuplicateEvidenceCountByKind: [DecisionIntelligenceTraceKind: Int]
    let droppedBudgetEvidenceCount: Int
    let droppedBudgetEvidenceCountByKind: [DecisionIntelligenceTraceKind: Int]
    let averageRetainedEvidenceCountByKind: [DecisionIntelligenceTraceKind: Double]
    let averageAnchorFieldCountByKind: [DecisionIntelligenceTraceKind: Double]
    let latestGenerationByKind: [DecisionIntelligenceTraceKind: Int]
}

struct DecisionTestingNeuralSummary: Equatable, Sendable {
    let neuralTraceCount: Int
    let suppressedBehaviorCount: Int
    let dominantActionByKind: [DecisionIntelligenceTraceKind: DecisionActionRoute]
    let strongestSignalByKind: [DecisionIntelligenceTraceKind: DecisionNeuralSignal]
}

struct DecisionTestingBrainSummary: Equatable, Sendable {
    let brainTraceCount: Int
    let dominantReactionWeightByKind: [DecisionIntelligenceTraceKind: DecisionReactionWeightKey]
    let averageProfileCoreCountByKind: [DecisionIntelligenceTraceKind: Double]
    let averageActiveGoalCountByKind: [DecisionIntelligenceTraceKind: Double]
    let averageRelevantMemoryCountByKind: [DecisionIntelligenceTraceKind: Double]
    let averageLoadedPromotedMemoryCountByKind: [DecisionIntelligenceTraceKind: Double]
    let averageLoadedPendingMemoryCountByKind: [DecisionIntelligenceTraceKind: Double]
    let averagePendingCandidateCountByKind: [DecisionIntelligenceTraceKind: Double]
    let averagePromotedRecordCountByKind: [DecisionIntelligenceTraceKind: Double]
    let averageScreenedOutMemoryCountByKind: [DecisionIntelligenceTraceKind: Double]
    let loadedEligibilityReasonCountsByKind: [DecisionIntelligenceTraceKind: [DecisionMemoryEligibilityReason: Int]]
    let screenedOutEligibilityReasonCountsByKind: [DecisionIntelligenceTraceKind: [DecisionMemoryEligibilityReason: Int]]
    let pendingMemoryLoadRateByKind: [DecisionIntelligenceTraceKind: Double]
    let retrievalRejectionRateByKind: [DecisionIntelligenceTraceKind: Double]
    let latestSnapshotFingerprintByKind: [DecisionIntelligenceTraceKind: String]
    let snapshotVariantCountByKind: [DecisionIntelligenceTraceKind: Int]
    let lowTrustMemoryLoadRateByKind: [DecisionIntelligenceTraceKind: Double]
    let riskFlagCountsByKind: [DecisionIntelligenceTraceKind: [DecisionBrainStateRiskFlag: Int]]
    let identityRoleByKind: [DecisionIntelligenceTraceKind: DecisionIdentityRole]
    let boundaryModeByKind: [DecisionIntelligenceTraceKind: DecisionBoundaryPolicyMode]
    let boundaryConstraintCountsByKind: [DecisionIntelligenceTraceKind: [DecisionBoundaryConstraint: Int]]
    let calibrationStatusByKind: [DecisionIntelligenceTraceKind: DecisionCalibrationStatus]
    let calibrationAlertCountsByKind: [DecisionIntelligenceTraceKind: [DecisionCalibrationAlert: Int]]
    let evolutionCheckpointCountByKind: [DecisionIntelligenceTraceKind: Double]
    let evolutionPendingReviewCountByKind: [DecisionIntelligenceTraceKind: Double]
    let evolutionRollbackReadyByKind: [DecisionIntelligenceTraceKind: Bool]
}

struct DecisionTestingRuntimeSummary: Equatable, Sendable {
    let activeProvider: DecisionModelProviderKind
    let fallbackProvider: DecisionModelProviderKind?
    let runtimeGear: DecisionRuntimeGear
    let environmentClass: DecisionEnvironmentClass
    let deviceClass: DecisionDevicePerformanceClass
    let languageMode: DecisionLanguageMode
    let taskEntropyByKind: [DecisionIntelligenceTraceKind: DecisionTaskEntropyClass]
    let runtimeGearByKind: [DecisionIntelligenceTraceKind: DecisionRuntimeGear]
    let preferredProviderByKind: [DecisionIntelligenceTraceKind: DecisionModelProviderPreference]
    let allowsModelInvocationByKind: [DecisionIntelligenceTraceKind: Bool]
    let contextBudgetByKind: [DecisionIntelligenceTraceKind: Int]
    let outputCharacterBudgetByKind: [DecisionIntelligenceTraceKind: Int]
    let timeBudgetMsByKind: [DecisionIntelligenceTraceKind: Int]
    let toolCallBudgetByKind: [DecisionIntelligenceTraceKind: Int]
    let retrievalItemBudgetByKind: [DecisionIntelligenceTraceKind: Int]
    let retrievalModeByKind: [DecisionIntelligenceTraceKind: DecisionRetrievalMode]
    let thinkingModeByKind: [DecisionIntelligenceTraceKind: DecisionThinkingMode]
    let outputModeByKind: [DecisionIntelligenceTraceKind: DecisionOutputMode]
    let toneByKind: [DecisionIntelligenceTraceKind: DecisionToneProfile]
    let actionSpaceByKind: [DecisionIntelligenceTraceKind: [String]]
    let responseLanguageByKind: [DecisionIntelligenceTraceKind: DecisionAdaptiveResponseLanguage]
    let effectiveRuntimeGearByKind: [DecisionIntelligenceTraceKind: DecisionRuntimeGear]
    let effectivePreferredProviderByKind: [DecisionIntelligenceTraceKind: DecisionModelProviderPreference]
    let effectiveContextBudgetByKind: [DecisionIntelligenceTraceKind: Int]
    let effectiveOutputCharacterBudgetByKind: [DecisionIntelligenceTraceKind: Int]
    let effectiveTimeBudgetMsByKind: [DecisionIntelligenceTraceKind: Int]
    let effectiveToolCallBudgetByKind: [DecisionIntelligenceTraceKind: Int]
    let effectiveRetrievalItemBudgetByKind: [DecisionIntelligenceTraceKind: Int]
    let effectiveRetrievalModeByKind: [DecisionIntelligenceTraceKind: DecisionRetrievalMode]
    let effectiveThinkingModeByKind: [DecisionIntelligenceTraceKind: DecisionThinkingMode]
    let effectiveOutputModeByKind: [DecisionIntelligenceTraceKind: DecisionOutputMode]
    let effectiveToneByKind: [DecisionIntelligenceTraceKind: DecisionToneProfile]
    let effectiveActionSpaceByKind: [DecisionIntelligenceTraceKind: [String]]
    let effectiveResponseLanguageByKind: [DecisionIntelligenceTraceKind: DecisionAdaptiveResponseLanguage]
    let firstAttemptedProviderByKind: [DecisionIntelligenceTraceKind: DecisionModelProviderKind]
    let effectiveProviderOrderByKind: [DecisionIntelligenceTraceKind: [DecisionModelProviderKind]]
    let totalRequests: Int
    let totalProviderAttempts: Int
    let cacheHitRate: Double
    let admissionSkipRate: Double
    let providerBypassRate: Double
    let providerBypassRateByKind: [DecisionIntelligenceTraceKind: Double]
    let lowPressureModelCallRate: Double
    let lowPressureModelCallRateByKind: [DecisionIntelligenceTraceKind: Double]
    let avoidableModelCallRate: Double
    let avoidableModelCallRateByKind: [DecisionIntelligenceTraceKind: Double]
    let reminderRequestCount: Int
    let reminderKnowledgeNeedRate: Double
    let reminderControlOnlyRate: Double
    let reminderRetrievalBypassRate: Double
    let deterministicFallbackRate: Double
    let averageRequestDurationMs: Double
    let averageRequestDurationMsByKind: [DecisionIntelligenceTraceKind: Double]
    let averageFirstPresentableMs: Double
    let averageFirstPresentableMsByKind: [DecisionIntelligenceTraceKind: Double]
    let averagePromptAssemblyMsByKind: [DecisionIntelligenceTraceKind: Double]
    let averageAdmissionEvaluationMsByKind: [DecisionIntelligenceTraceKind: Double]
    let averageProviderSelectionMsByKind: [DecisionIntelligenceTraceKind: Double]
    let averageExecutionMsByKind: [DecisionIntelligenceTraceKind: Double]
    let averagePrefillEquivalentShareByKind: [DecisionIntelligenceTraceKind: Double]
    let averageRequestDurationMsByProvider: [DecisionModelProviderKind: Double]
    let averageRequestDurationMsByGemmaBackend: [InferenceBackendKind: Double]
    let averagePromptCharactersByKind: [DecisionIntelligenceTraceKind: Double]
    let averagePrefixCharactersByKind: [DecisionIntelligenceTraceKind: Double]
    let averageImmutablePrefixCharactersByKind: [DecisionIntelligenceTraceKind: Double]
    let averageAdaptivePrefixCharactersByKind: [DecisionIntelligenceTraceKind: Double]
    let averageSuffixCharactersByKind: [DecisionIntelligenceTraceKind: Double]
    let averageStablePrefixShareByKind: [DecisionIntelligenceTraceKind: Double]
    let semanticPromptVariantCountByKind: [DecisionIntelligenceTraceKind: Int]
    let semanticPromptReuseRateByKind: [DecisionIntelligenceTraceKind: Double]
    let stablePrefixVariantCountByKind: [DecisionIntelligenceTraceKind: Int]
    let stablePrefixReuseRateByKind: [DecisionIntelligenceTraceKind: Double]
    let stablePrefixPollutionRateByKind: [DecisionIntelligenceTraceKind: Double]
    let slowRequestRate: Double
    let slowRequestRateByKind: [DecisionIntelligenceTraceKind: Double]
    let overTimeBudgetRate: Double
    let overTimeBudgetRateByKind: [DecisionIntelligenceTraceKind: Double]
    let overTargetBudgetRate: Double
    let fallbackActivations: Int
    let admissionSkipCount: Int
    let contextAwareTraceCount: Int
    let lifecycleRebuildCount: Int
    let staleFieldDropCount: Int
    let retainedEvidenceCount: Int
    let evidenceRetentionRatio: Double
    let droppedEvidenceCount: Int
    let droppedInjectedEvidenceCount: Int
    let droppedDuplicateEvidenceCount: Int
    let droppedBudgetEvidenceCount: Int
    let evidencePollutionRate: Double
    let evidencePollutionRateByKind: [DecisionIntelligenceTraceKind: Double]
    let duplicateEvidenceDropRate: Double
    let duplicateEvidenceDropRateByKind: [DecisionIntelligenceTraceKind: Double]
    let budgetTrimRate: Double
    let budgetTrimRateByKind: [DecisionIntelligenceTraceKind: Double]
    let neuralTraceCount: Int
    let suppressedBehaviorCount: Int
    let brainTraceCount: Int
    let dominantReactionWeightByKind: [DecisionIntelligenceTraceKind: DecisionReactionWeightKey]
    let loadedEligibilityReasonCountsByKind: [DecisionIntelligenceTraceKind: [DecisionMemoryEligibilityReason: Int]]
    let screenedOutEligibilityReasonCountsByKind: [DecisionIntelligenceTraceKind: [DecisionMemoryEligibilityReason: Int]]
    let pendingMemoryLoadRateByKind: [DecisionIntelligenceTraceKind: Double]
    let retrievalRejectionRateByKind: [DecisionIntelligenceTraceKind: Double]
    let brainSnapshotFingerprintByKind: [DecisionIntelligenceTraceKind: String]
    let brainSnapshotVariantCountByKind: [DecisionIntelligenceTraceKind: Int]
    let lowTrustMemoryLoadRateByKind: [DecisionIntelligenceTraceKind: Double]
    let brainRiskFlagCountsByKind: [DecisionIntelligenceTraceKind: [DecisionBrainStateRiskFlag: Int]]
    let identityRoleByKind: [DecisionIntelligenceTraceKind: DecisionIdentityRole]
    let boundaryModeByKind: [DecisionIntelligenceTraceKind: DecisionBoundaryPolicyMode]
    let boundaryConstraintCountsByKind: [DecisionIntelligenceTraceKind: [DecisionBoundaryConstraint: Int]]
    let calibrationStatusByKind: [DecisionIntelligenceTraceKind: DecisionCalibrationStatus]
    let calibrationAlertCountsByKind: [DecisionIntelligenceTraceKind: [DecisionCalibrationAlert: Int]]
    let evolutionCheckpointCountByKind: [DecisionIntelligenceTraceKind: Double]
    let evolutionPendingReviewCountByKind: [DecisionIntelligenceTraceKind: Double]
    let evolutionRollbackReadyByKind: [DecisionIntelligenceTraceKind: Bool]
    let traceCount: Int
    let replayCount: Int
    let totalCacheEntries: Int
    let totalCacheRejectedStores: Int
    let totalCacheQuarantinedHits: Int
    let cacheQuarantineRate: Double
    let dominantGemmaBackend: InferenceBackendKind?
    let registeredProviderCount: Int
    let registeredOpenModelProviderCount: Int
    let circuitOpenProviderCount: Int
    let activeCircuitProviders: [DecisionModelProviderKind]
    let circuitTripCount: Int
    let circuitTripCountByProvider: [DecisionModelProviderKind: Int]
    let circuitTripCountByReason: [DecisionIntelligenceCircuitTripReason: Int]
    let consistencyCheckedTraceCount: Int
    let consistencyRejectedTraceCount: Int
    let consistencyCheckCoverageRate: Double
    let consistencyRejectRate: Double
    let consistencyRejectedCountByKind: [DecisionIntelligenceTraceKind: Int]
    let consistencyViolationCounts: [BASConsistencyViolationKind: Int]
}

private extension DecisionTestingLifecycleSummary {
    init(basSummary: BASLifecycleSummary) {
        self.init(
            contextAwareTraceCount: basSummary.contextAwareTraceCount,
            rebuildCount: basSummary.rebuildCount,
            rebuildCountByKind: mapTraceKindDictionary(basSummary.rebuildCountByKind),
            staleFieldDropCount: basSummary.staleFieldDropCount,
            staleFieldDropCountByKind: mapTraceKindDictionary(basSummary.staleFieldDropCountByKind),
            retainedEvidenceCount: basSummary.retainedEvidenceCount,
            droppedEvidenceCount: basSummary.droppedEvidenceCount,
            droppedEvidenceCountByKind: mapTraceKindDictionary(basSummary.droppedEvidenceCountByKind),
            droppedInjectedEvidenceCount: basSummary.droppedInjectedEvidenceCount,
            droppedInjectedEvidenceCountByKind: mapTraceKindDictionary(basSummary.droppedInjectedEvidenceCountByKind),
            droppedDuplicateEvidenceCount: basSummary.droppedDuplicateEvidenceCount,
            droppedDuplicateEvidenceCountByKind: mapTraceKindDictionary(basSummary.droppedDuplicateEvidenceCountByKind),
            droppedBudgetEvidenceCount: basSummary.droppedBudgetEvidenceCount,
            droppedBudgetEvidenceCountByKind: mapTraceKindDictionary(basSummary.droppedBudgetEvidenceCountByKind),
            averageRetainedEvidenceCountByKind: mapTraceKindDictionary(basSummary.averageRetainedEvidenceCountByKind),
            averageAnchorFieldCountByKind: mapTraceKindDictionary(basSummary.averageAnchorFieldCountByKind),
            latestGenerationByKind: mapTraceKindDictionary(basSummary.latestGenerationByKind)
        )
    }
}

private extension DecisionTestingNeuralSummary {
    init(basSummary: BASNeuralSummary) {
        self.init(
            neuralTraceCount: basSummary.neuralTraceCount,
            suppressedBehaviorCount: basSummary.suppressedBehaviorCount,
            dominantActionByKind: mapTraceKindDictionary(basSummary.dominantActionByKind) {
                DecisionActionRoute(rawValue: $0)
            },
            strongestSignalByKind: mapTraceKindDictionary(basSummary.strongestSignalByKind) {
                DecisionNeuralSignal(rawValue: $0)
            }
        )
    }
}

private extension DecisionTestingBrainSummary {
    init(basSummary: BASBrainSummary) {
        self.init(
            brainTraceCount: basSummary.brainTraceCount,
            dominantReactionWeightByKind: mapTraceKindDictionary(basSummary.dominantReactionWeightByKind) {
                DecisionReactionWeightKey(rawValue: $0.rawValue)
            },
            averageProfileCoreCountByKind: mapTraceKindDictionary(basSummary.averageProfileCoreCountByKind),
            averageActiveGoalCountByKind: mapTraceKindDictionary(basSummary.averageActiveGoalCountByKind),
            averageRelevantMemoryCountByKind: mapTraceKindDictionary(basSummary.averageRelevantMemoryCountByKind),
            averageLoadedPromotedMemoryCountByKind: mapTraceKindDictionary(basSummary.averageLoadedPromotedMemoryCountByKind),
            averageLoadedPendingMemoryCountByKind: mapTraceKindDictionary(basSummary.averageLoadedPendingMemoryCountByKind),
            averagePendingCandidateCountByKind: mapTraceKindDictionary(basSummary.averagePendingCandidateCountByKind),
            averagePromotedRecordCountByKind: mapTraceKindDictionary(basSummary.averagePromotedRecordCountByKind),
            averageScreenedOutMemoryCountByKind: mapTraceKindDictionary(basSummary.averageScreenedOutMemoryCountByKind),
            loadedEligibilityReasonCountsByKind: mapTraceKindDictionary(basSummary.loadedEligibilityReasonCountsByKind),
            screenedOutEligibilityReasonCountsByKind: mapTraceKindDictionary(basSummary.screenedOutEligibilityReasonCountsByKind),
            pendingMemoryLoadRateByKind: mapTraceKindDictionary(basSummary.pendingMemoryLoadRateByKind),
            retrievalRejectionRateByKind: mapTraceKindDictionary(basSummary.retrievalRejectionRateByKind),
            latestSnapshotFingerprintByKind: mapTraceKindDictionary(basSummary.latestSnapshotFingerprintByKind),
            snapshotVariantCountByKind: mapTraceKindDictionary(basSummary.snapshotVariantCountByKind),
            lowTrustMemoryLoadRateByKind: mapTraceKindDictionary(basSummary.lowTrustMemoryLoadRateByKind),
            riskFlagCountsByKind: mapTraceKindDictionary(basSummary.riskFlagCountsByKind),
            identityRoleByKind: mapTraceKindDictionary(basSummary.identityRoleByKind) {
                DecisionIdentityRole(rawValue: $0.rawValue)
            },
            boundaryModeByKind: mapTraceKindDictionary(basSummary.boundaryModeByKind) {
                DecisionBoundaryPolicyMode(rawValue: $0.rawValue)
            },
            boundaryConstraintCountsByKind: mapTraceKindDictionary(basSummary.boundaryConstraintCountsByKind),
            calibrationStatusByKind: mapTraceKindDictionary(basSummary.calibrationStatusByKind) {
                DecisionCalibrationStatus(rawValue: $0.rawValue)
            },
            calibrationAlertCountsByKind: mapTraceKindDictionary(basSummary.calibrationAlertCountsByKind),
            evolutionCheckpointCountByKind: mapTraceKindDictionary(basSummary.evolutionCheckpointCountByKind),
            evolutionPendingReviewCountByKind: mapTraceKindDictionary(basSummary.evolutionPendingReviewCountByKind),
            evolutionRollbackReadyByKind: mapTraceKindDictionary(basSummary.evolutionRollbackReadyByKind)
        )
    }
}

private extension DecisionTestingRuntimeSummary {
    init(basSummary: BASRuntimeInspectionSummary) {
        self.init(
            activeProvider: DecisionModelProviderKind(rawValue: basSummary.activeProviderID) ?? .template,
            fallbackProvider: basSummary.fallbackProviderID.flatMap(DecisionModelProviderKind.init(rawValue:)),
            runtimeGear: DecisionRuntimeGear(rawValue: basSummary.runtimeGear.rawValue) ?? .balanced,
            environmentClass: DecisionEnvironmentClass(rawValue: basSummary.environmentClass.rawValue) ?? .normal,
            deviceClass: DecisionDevicePerformanceClass(rawValue: basSummary.deviceClass.rawValue) ?? .balancedPhone,
            languageMode: DecisionLanguageMode(rawValue: basSummary.languageMode.rawValue) ?? .unknown,
            taskEntropyByKind: mapTraceKindDictionary(basSummary.taskEntropyByKind) {
                DecisionTaskEntropyClass(rawValue: $0.rawValue)
            },
            runtimeGearByKind: mapTraceKindDictionary(basSummary.runtimeGearByKind) {
                DecisionRuntimeGear(rawValue: $0.rawValue)
            },
            preferredProviderByKind: mapTraceKindDictionary(basSummary.preferredProviderRawValueByKind) {
                DecisionModelProviderPreference(rawValue: $0)
            },
            allowsModelInvocationByKind: mapTraceKindDictionary(basSummary.allowsModelInvocationByKind),
            contextBudgetByKind: mapTraceKindDictionary(basSummary.contextBudgetByKind),
            outputCharacterBudgetByKind: mapTraceKindDictionary(basSummary.outputCharacterBudgetByKind),
            timeBudgetMsByKind: mapTraceKindDictionary(basSummary.timeBudgetMsByKind),
            toolCallBudgetByKind: mapTraceKindDictionary(basSummary.toolCallBudgetByKind),
            retrievalItemBudgetByKind: mapTraceKindDictionary(basSummary.retrievalItemBudgetByKind),
            retrievalModeByKind: mapTraceKindDictionary(basSummary.retrievalModeByKind) {
                DecisionRetrievalMode(rawValue: $0.rawValue)
            },
            thinkingModeByKind: mapTraceKindDictionary(basSummary.thinkingModeByKind) {
                DecisionThinkingMode(rawValue: $0.rawValue)
            },
            outputModeByKind: mapTraceKindDictionary(basSummary.outputModeByKind) {
                DecisionOutputMode(rawValue: $0.rawValue)
            },
            toneByKind: mapTraceKindDictionary(basSummary.toneByKind) {
                DecisionToneProfile(rawValue: $0.rawValue)
            },
            actionSpaceByKind: mapTraceKindDictionary(basSummary.actionSpaceByKind),
            responseLanguageByKind: mapTraceKindDictionary(basSummary.responseLanguageByKind) {
                DecisionAdaptiveResponseLanguage(rawValue: $0.rawValue)
            },
            effectiveRuntimeGearByKind: mapTraceKindDictionary(basSummary.effectiveRuntimeGearByKind) {
                DecisionRuntimeGear(rawValue: $0.rawValue)
            },
            effectivePreferredProviderByKind: mapTraceKindDictionary(basSummary.effectivePreferredProviderRawValueByKind) {
                DecisionModelProviderPreference(rawValue: $0)
            },
            effectiveContextBudgetByKind: mapTraceKindDictionary(basSummary.effectiveContextBudgetByKind),
            effectiveOutputCharacterBudgetByKind: mapTraceKindDictionary(basSummary.effectiveOutputCharacterBudgetByKind),
            effectiveTimeBudgetMsByKind: mapTraceKindDictionary(basSummary.effectiveTimeBudgetMsByKind),
            effectiveToolCallBudgetByKind: mapTraceKindDictionary(basSummary.effectiveToolCallBudgetByKind),
            effectiveRetrievalItemBudgetByKind: mapTraceKindDictionary(basSummary.effectiveRetrievalItemBudgetByKind),
            effectiveRetrievalModeByKind: mapTraceKindDictionary(basSummary.effectiveRetrievalModeByKind) {
                DecisionRetrievalMode(rawValue: $0.rawValue)
            },
            effectiveThinkingModeByKind: mapTraceKindDictionary(basSummary.effectiveThinkingModeByKind) {
                DecisionThinkingMode(rawValue: $0.rawValue)
            },
            effectiveOutputModeByKind: mapTraceKindDictionary(basSummary.effectiveOutputModeByKind) {
                DecisionOutputMode(rawValue: $0.rawValue)
            },
            effectiveToneByKind: mapTraceKindDictionary(basSummary.effectiveToneByKind) {
                DecisionToneProfile(rawValue: $0.rawValue)
            },
            effectiveActionSpaceByKind: mapTraceKindDictionary(basSummary.effectiveActionSpaceByKind),
            effectiveResponseLanguageByKind: mapTraceKindDictionary(basSummary.effectiveResponseLanguageByKind) {
                DecisionAdaptiveResponseLanguage(rawValue: $0.rawValue)
            },
            firstAttemptedProviderByKind: mapTraceKindDictionary(basSummary.firstAttemptedProviderByKind) {
                DecisionModelProviderKind(rawValue: $0)
            },
            effectiveProviderOrderByKind: mapTraceKindDictionary(basSummary.effectiveProviderOrderByKind) { values in
                let providers = values.compactMap(DecisionModelProviderKind.init(rawValue:))
                return providers.isEmpty ? nil : providers
            },
            totalRequests: basSummary.totalRequests,
            totalProviderAttempts: basSummary.totalProviderAttempts,
            cacheHitRate: basSummary.cacheHitRate,
            admissionSkipRate: basSummary.admissionSkipRate,
            providerBypassRate: basSummary.providerBypassRate,
            providerBypassRateByKind: mapTraceKindDictionary(basSummary.providerBypassRateByKind),
            lowPressureModelCallRate: basSummary.lowPressureModelCallRate,
            lowPressureModelCallRateByKind: mapTraceKindDictionary(basSummary.lowPressureModelCallRateByKind),
            avoidableModelCallRate: basSummary.avoidableModelCallRate,
            avoidableModelCallRateByKind: mapTraceKindDictionary(basSummary.avoidableModelCallRateByKind),
            reminderRequestCount: basSummary.reminderRequestCount,
            reminderKnowledgeNeedRate: basSummary.reminderKnowledgeNeedRate,
            reminderControlOnlyRate: basSummary.reminderControlOnlyRate,
            reminderRetrievalBypassRate: basSummary.reminderRetrievalBypassRate,
            deterministicFallbackRate: basSummary.deterministicFallbackRate,
            averageRequestDurationMs: basSummary.averageRequestDurationMs,
            averageRequestDurationMsByKind: mapTraceKindDictionary(basSummary.averageRequestDurationMsByKind),
            averageFirstPresentableMs: basSummary.averageFirstPresentableMs,
            averageFirstPresentableMsByKind: mapTraceKindDictionary(basSummary.averageFirstPresentableMsByKind),
            averagePromptAssemblyMsByKind: mapTraceKindDictionary(basSummary.averagePromptAssemblyMsByKind),
            averageAdmissionEvaluationMsByKind: mapTraceKindDictionary(basSummary.averageAdmissionEvaluationMsByKind),
            averageProviderSelectionMsByKind: mapTraceKindDictionary(basSummary.averageProviderSelectionMsByKind),
            averageExecutionMsByKind: mapTraceKindDictionary(basSummary.averageExecutionMsByKind),
            averagePrefillEquivalentShareByKind: mapTraceKindDictionary(basSummary.averagePrefillEquivalentShareByKind),
            averageRequestDurationMsByProvider: mapProviderKindDictionary(basSummary.averageRequestDurationMsByActiveProvider),
            averageRequestDurationMsByGemmaBackend: mapBackendKindDictionary(basSummary.averageRequestDurationMsByBackend),
            averagePromptCharactersByKind: mapTraceKindDictionary(basSummary.averagePromptCharactersByKind),
            averagePrefixCharactersByKind: mapTraceKindDictionary(basSummary.averagePrefixCharactersByKind),
            averageImmutablePrefixCharactersByKind: mapTraceKindDictionary(basSummary.averageImmutablePrefixCharactersByKind),
            averageAdaptivePrefixCharactersByKind: mapTraceKindDictionary(basSummary.averageAdaptivePrefixCharactersByKind),
            averageSuffixCharactersByKind: mapTraceKindDictionary(basSummary.averageSuffixCharactersByKind),
            averageStablePrefixShareByKind: mapTraceKindDictionary(basSummary.averageStablePrefixShareByKind),
            semanticPromptVariantCountByKind: mapTraceKindDictionary(basSummary.semanticPromptVariantCountByKind),
            semanticPromptReuseRateByKind: mapTraceKindDictionary(basSummary.semanticPromptReuseRateByKind),
            stablePrefixVariantCountByKind: mapTraceKindDictionary(basSummary.stablePrefixVariantCountByKind),
            stablePrefixReuseRateByKind: mapTraceKindDictionary(basSummary.stablePrefixReuseRateByKind),
            stablePrefixPollutionRateByKind: mapTraceKindDictionary(basSummary.stablePrefixPollutionRateByKind),
            slowRequestRate: basSummary.slowRequestRate,
            slowRequestRateByKind: mapTraceKindDictionary(basSummary.slowRequestRateByKind),
            overTimeBudgetRate: basSummary.overTimeBudgetRate,
            overTimeBudgetRateByKind: mapTraceKindDictionary(basSummary.overTimeBudgetRateByKind),
            overTargetBudgetRate: basSummary.overTargetBudgetRate,
            fallbackActivations: basSummary.fallbackActivations,
            admissionSkipCount: basSummary.admissionSkipCount,
            contextAwareTraceCount: basSummary.contextAwareTraceCount,
            lifecycleRebuildCount: basSummary.lifecycleRebuildCount,
            staleFieldDropCount: basSummary.staleFieldDropCount,
            retainedEvidenceCount: basSummary.retainedEvidenceCount,
            evidenceRetentionRatio: basSummary.evidenceRetentionRatio,
            droppedEvidenceCount: basSummary.droppedEvidenceCount,
            droppedInjectedEvidenceCount: basSummary.droppedInjectedEvidenceCount,
            droppedDuplicateEvidenceCount: basSummary.droppedDuplicateEvidenceCount,
            droppedBudgetEvidenceCount: basSummary.droppedBudgetEvidenceCount,
            evidencePollutionRate: basSummary.evidencePollutionRate,
            evidencePollutionRateByKind: mapTraceKindDictionary(basSummary.evidencePollutionRateByKind),
            duplicateEvidenceDropRate: basSummary.duplicateEvidenceDropRate,
            duplicateEvidenceDropRateByKind: mapTraceKindDictionary(basSummary.duplicateEvidenceDropRateByKind),
            budgetTrimRate: basSummary.budgetTrimRate,
            budgetTrimRateByKind: mapTraceKindDictionary(basSummary.budgetTrimRateByKind),
            neuralTraceCount: basSummary.neuralTraceCount,
            suppressedBehaviorCount: basSummary.suppressedBehaviorCount,
            brainTraceCount: basSummary.brainTraceCount,
            dominantReactionWeightByKind: mapTraceKindDictionary(basSummary.dominantReactionWeightByKind) {
                DecisionReactionWeightKey(rawValue: $0.rawValue)
            },
            loadedEligibilityReasonCountsByKind: mapTraceKindDictionary(basSummary.loadedEligibilityReasonCountsByKind),
            screenedOutEligibilityReasonCountsByKind: mapTraceKindDictionary(basSummary.screenedOutEligibilityReasonCountsByKind),
            pendingMemoryLoadRateByKind: mapTraceKindDictionary(basSummary.pendingMemoryLoadRateByKind),
            retrievalRejectionRateByKind: mapTraceKindDictionary(basSummary.retrievalRejectionRateByKind),
            brainSnapshotFingerprintByKind: mapTraceKindDictionary(basSummary.brainSnapshotFingerprintByKind),
            brainSnapshotVariantCountByKind: mapTraceKindDictionary(basSummary.brainSnapshotVariantCountByKind),
            lowTrustMemoryLoadRateByKind: mapTraceKindDictionary(basSummary.lowTrustMemoryLoadRateByKind),
            brainRiskFlagCountsByKind: mapTraceKindDictionary(basSummary.brainRiskFlagCountsByKind),
            identityRoleByKind: mapTraceKindDictionary(basSummary.identityRoleByKind) {
                DecisionIdentityRole(rawValue: $0.rawValue)
            },
            boundaryModeByKind: mapTraceKindDictionary(basSummary.boundaryModeByKind) {
                DecisionBoundaryPolicyMode(rawValue: $0.rawValue)
            },
            boundaryConstraintCountsByKind: mapTraceKindDictionary(basSummary.boundaryConstraintCountsByKind),
            calibrationStatusByKind: mapTraceKindDictionary(basSummary.calibrationStatusByKind) {
                DecisionCalibrationStatus(rawValue: $0.rawValue)
            },
            calibrationAlertCountsByKind: mapTraceKindDictionary(basSummary.calibrationAlertCountsByKind),
            evolutionCheckpointCountByKind: mapTraceKindDictionary(basSummary.evolutionCheckpointCountByKind),
            evolutionPendingReviewCountByKind: mapTraceKindDictionary(basSummary.evolutionPendingReviewCountByKind),
            evolutionRollbackReadyByKind: mapTraceKindDictionary(basSummary.evolutionRollbackReadyByKind),
            traceCount: basSummary.traceCount,
            replayCount: basSummary.replayCount,
            totalCacheEntries: basSummary.totalCacheEntries,
            totalCacheRejectedStores: basSummary.totalCacheRejectedStores,
            totalCacheQuarantinedHits: basSummary.totalCacheQuarantinedHits,
            cacheQuarantineRate: basSummary.cacheQuarantineRate,
            dominantGemmaBackend: basSummary.dominantBackendID.flatMap(InferenceBackendKind.init(rawValue:)),
            registeredProviderCount: basSummary.registeredProviderCount,
            registeredOpenModelProviderCount: basSummary.registeredOpenModelProviderCount,
            circuitOpenProviderCount: basSummary.circuitOpenProviderCount,
            activeCircuitProviders: basSummary.activeCircuitProviderIDs.compactMap(DecisionModelProviderKind.init(rawValue:)),
            circuitTripCount: basSummary.circuitTripCount,
            circuitTripCountByProvider: mapProviderKindDictionary(basSummary.circuitTripCountByProvider),
            circuitTripCountByReason: mapCircuitReasonDictionary(basSummary.circuitTripCountByReason),
            consistencyCheckedTraceCount: basSummary.consistencyCheckedTraceCount,
            consistencyRejectedTraceCount: basSummary.consistencyRejectedTraceCount,
            consistencyCheckCoverageRate: basSummary.consistencyCheckCoverageRate,
            consistencyRejectRate: basSummary.consistencyRejectRate,
            consistencyRejectedCountByKind: mapTraceKindDictionary(basSummary.consistencyRejectedCountByKind),
            consistencyViolationCounts: basSummary.consistencyViolationCounts
        )
    }
}

private func mapTraceKindDictionary<Value>(
    _ values: [String: Value]
) -> [DecisionIntelligenceTraceKind: Value] {
    mapTraceKindDictionary(values) { $0 }
}

private func mapTraceKindDictionary<Input, Output>(
    _ values: [String: Input],
    transform: (Input) -> Output?
) -> [DecisionIntelligenceTraceKind: Output] {
    values.reduce(into: [:]) { partialResult, item in
        guard
            let kind = DecisionIntelligenceTraceKind(rawValue: item.key),
            let mappedValue = transform(item.value)
        else {
            return
        }
        partialResult[kind] = mappedValue
    }
}

private func mapProviderKindDictionary<Value>(
    _ values: [String: Value]
) -> [DecisionModelProviderKind: Value] {
    values.reduce(into: [:]) { partialResult, item in
        guard let provider = DecisionModelProviderKind(rawValue: item.key) else { return }
        partialResult[provider] = item.value
    }
}

private func mapBackendKindDictionary<Value>(
    _ values: [String: Value]
) -> [InferenceBackendKind: Value] {
    values.reduce(into: [:]) { partialResult, item in
        guard let backend = InferenceBackendKind(rawValue: item.key) else { return }
        partialResult[backend] = item.value
    }
}

private func mapCircuitReasonDictionary<Value>(
    _ values: [String: Value]
) -> [DecisionIntelligenceCircuitTripReason: Value] {
    values.reduce(into: [:]) { partialResult, item in
        guard let reason = DecisionIntelligenceCircuitTripReason(rawValue: item.key) else { return }
        partialResult[reason] = item.value
    }
}
