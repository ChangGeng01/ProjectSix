import Foundation
import BASMemory
import BASObservability
import BASPolicy
import BASRuntimeCore

public struct BASAppleRuntimeInspectionAdapterInput: Codable, Sendable, Equatable {
    public var activeProviderID: String
    public var fallbackProviderID: String?
    public var runtimeGear: BASRuntimeGear
    public var environmentClass: BASEnvironmentClass
    public var deviceClass: BASDevicePerformanceClass
    public var languageMode: BASLanguageMode
    public var taskEntropyByKind: [String: BASTaskEntropyClass]
    public var preferredProviderRawValueByKind: [String: String]
    public var strategyByKind: [String: BASAdaptiveTaskStrategy]
    public var effectivePreferredProviderRawValueByKind: [String: String]
    public var traceInputs: [BASRuntimeInspectionTraceInput]
    public var telemetrySummary: BASTelemetrySummary
    public var lifecycleSummary: BASLifecycleSummary
    public var neuralSummary: BASNeuralSummary
    public var brainSummary: BASBrainSummary
    public var totalCacheEntries: Int
    public var totalCacheLookupCount: Int
    public var totalCacheRejectedStores: Int
    public var totalCacheQuarantinedHits: Int
    public var dominantBackendID: String?
    public var registeredProviderCount: Int
    public var registeredOpenModelProviderCount: Int
    public var activeCircuitProviderIDs: [String]
    public var circuitTripCount: Int
    public var circuitTripCountByProvider: [String: Int]
    public var circuitTripCountByReason: [String: Int]
    public var traceCount: Int
    public var replayCount: Int

    public init(
        activeProviderID: String,
        fallbackProviderID: String?,
        runtimeGear: BASRuntimeGear,
        environmentClass: BASEnvironmentClass,
        deviceClass: BASDevicePerformanceClass,
        languageMode: BASLanguageMode,
        taskEntropyByKind: [String: BASTaskEntropyClass],
        preferredProviderRawValueByKind: [String: String],
        strategyByKind: [String: BASAdaptiveTaskStrategy],
        effectivePreferredProviderRawValueByKind: [String: String],
        traceInputs: [BASRuntimeInspectionTraceInput],
        telemetrySummary: BASTelemetrySummary,
        lifecycleSummary: BASLifecycleSummary,
        neuralSummary: BASNeuralSummary,
        brainSummary: BASBrainSummary,
        totalCacheEntries: Int,
        totalCacheLookupCount: Int,
        totalCacheRejectedStores: Int,
        totalCacheQuarantinedHits: Int,
        dominantBackendID: String?,
        registeredProviderCount: Int,
        registeredOpenModelProviderCount: Int,
        activeCircuitProviderIDs: [String],
        circuitTripCount: Int,
        circuitTripCountByProvider: [String: Int],
        circuitTripCountByReason: [String: Int],
        traceCount: Int,
        replayCount: Int
    ) {
        self.activeProviderID = activeProviderID
        self.fallbackProviderID = fallbackProviderID
        self.runtimeGear = runtimeGear
        self.environmentClass = environmentClass
        self.deviceClass = deviceClass
        self.languageMode = languageMode
        self.taskEntropyByKind = taskEntropyByKind
        self.preferredProviderRawValueByKind = preferredProviderRawValueByKind
        self.strategyByKind = strategyByKind
        self.effectivePreferredProviderRawValueByKind = effectivePreferredProviderRawValueByKind
        self.traceInputs = traceInputs
        self.telemetrySummary = telemetrySummary
        self.lifecycleSummary = lifecycleSummary
        self.neuralSummary = neuralSummary
        self.brainSummary = brainSummary
        self.totalCacheEntries = totalCacheEntries
        self.totalCacheLookupCount = totalCacheLookupCount
        self.totalCacheRejectedStores = totalCacheRejectedStores
        self.totalCacheQuarantinedHits = totalCacheQuarantinedHits
        self.dominantBackendID = dominantBackendID
        self.registeredProviderCount = registeredProviderCount
        self.registeredOpenModelProviderCount = registeredOpenModelProviderCount
        self.activeCircuitProviderIDs = activeCircuitProviderIDs
        self.circuitTripCount = circuitTripCount
        self.circuitTripCountByProvider = circuitTripCountByProvider
        self.circuitTripCountByReason = circuitTripCountByReason
        self.traceCount = traceCount
        self.replayCount = replayCount
    }
}

public struct BASAppleRuntimeInspectionTraceSourceInput: Codable, Sendable, Equatable {
    public var lifecycle: BASLifecycleTraceInput?
    public var neural: BASNeuralTraceInput?
    public var brain: BASBrainTraceInput?
    public var runtimeInspection: BASRuntimeInspectionTraceInput

    public init(
        lifecycle: BASLifecycleTraceInput? = nil,
        neural: BASNeuralTraceInput? = nil,
        brain: BASBrainTraceInput? = nil,
        runtimeInspection: BASRuntimeInspectionTraceInput
    ) {
        self.lifecycle = lifecycle
        self.neural = neural
        self.brain = brain
        self.runtimeInspection = runtimeInspection
    }
}

public struct BASAppleRuntimeInspectionTraceRecordInput: Codable, Sendable, Equatable {
    public var kind: String
    public var hasContextState: Bool
    public var generation: Int?
    public var rebuiltSession: Bool
    public var staleFieldCount: Int
    public var anchorFieldCount: Int
    public var hasFrontstageState: Bool
    public var retainedEvidenceCount: Int
    public var droppedEvidenceCount: Int
    public var droppedInjectedEvidenceCount: Int
    public var droppedDuplicateEvidenceCount: Int
    public var droppedBudgetEvidenceCount: Int
    public var suppressedBehaviorCount: Int?
    public var dominantActionRawValue: String?
    public var strongestSignalRawValue: String?
    public var dominantReactionWeight: BASReactionWeightKey?
    public var profileCoreCount: Int?
    public var activeGoalCount: Int?
    public var relevantMemoryCount: Int?
    public var loadedPromotedMemoryCount: Int?
    public var loadedPendingMemoryCount: Int?
    public var pendingCandidateCount: Int?
    public var promotedRecordCount: Int?
    public var screenedOutMemoryCount: Int?
    public var loadedEligibilityReasonCounts: [BASMemoryEligibilityReason: Int]
    public var screenedOutEligibilityReasonCounts: [BASMemoryEligibilityReason: Int]
    public var snapshotFingerprint: String?
    public var lowTrustMemoryLoadRate: Double?
    public var riskFlags: [BASBrainStateRiskFlag]
    public var identityRole: BASIdentityRole?
    public var boundaryMode: BASBoundaryPolicyMode?
    public var activeConstraints: [BASBoundaryConstraint]
    public var calibrationStatus: BASCalibrationStatus?
    public var calibrationAlerts: [BASCalibrationAlert]
    public var evolutionCheckpointCount: Int?
    public var evolutionPendingReviewCount: Int?
    public var evolutionRollbackReady: Bool?
    public var attemptedProviderIDs: [String]
    public var runtimeStrategy: BASAdaptiveTaskStrategy?
    public var semanticPromptFingerprint: String?
    public var stablePrefixFingerprint: String?
    public var consistencyChecked: Bool
    public var consistencyRejected: Bool
    public var consistencyViolationKinds: [BASConsistencyViolationKind]

    public init(
        kind: String,
        hasContextState: Bool,
        generation: Int? = nil,
        rebuiltSession: Bool = false,
        staleFieldCount: Int = 0,
        anchorFieldCount: Int = 0,
        hasFrontstageState: Bool,
        retainedEvidenceCount: Int = 0,
        droppedEvidenceCount: Int = 0,
        droppedInjectedEvidenceCount: Int = 0,
        droppedDuplicateEvidenceCount: Int = 0,
        droppedBudgetEvidenceCount: Int = 0,
        suppressedBehaviorCount: Int? = nil,
        dominantActionRawValue: String? = nil,
        strongestSignalRawValue: String? = nil,
        dominantReactionWeight: BASReactionWeightKey? = nil,
        profileCoreCount: Int? = nil,
        activeGoalCount: Int? = nil,
        relevantMemoryCount: Int? = nil,
        loadedPromotedMemoryCount: Int? = nil,
        loadedPendingMemoryCount: Int? = nil,
        pendingCandidateCount: Int? = nil,
        promotedRecordCount: Int? = nil,
        screenedOutMemoryCount: Int? = nil,
        loadedEligibilityReasonCounts: [BASMemoryEligibilityReason: Int] = [:],
        screenedOutEligibilityReasonCounts: [BASMemoryEligibilityReason: Int] = [:],
        snapshotFingerprint: String? = nil,
        lowTrustMemoryLoadRate: Double? = nil,
        riskFlags: [BASBrainStateRiskFlag] = [],
        identityRole: BASIdentityRole? = nil,
        boundaryMode: BASBoundaryPolicyMode? = nil,
        activeConstraints: [BASBoundaryConstraint] = [],
        calibrationStatus: BASCalibrationStatus? = nil,
        calibrationAlerts: [BASCalibrationAlert] = [],
        evolutionCheckpointCount: Int? = nil,
        evolutionPendingReviewCount: Int? = nil,
        evolutionRollbackReady: Bool? = nil,
        attemptedProviderIDs: [String],
        runtimeStrategy: BASAdaptiveTaskStrategy? = nil,
        semanticPromptFingerprint: String? = nil,
        stablePrefixFingerprint: String? = nil,
        consistencyChecked: Bool,
        consistencyRejected: Bool,
        consistencyViolationKinds: [BASConsistencyViolationKind] = []
    ) {
        self.kind = kind
        self.hasContextState = hasContextState
        self.generation = generation
        self.rebuiltSession = rebuiltSession
        self.staleFieldCount = staleFieldCount
        self.anchorFieldCount = anchorFieldCount
        self.hasFrontstageState = hasFrontstageState
        self.retainedEvidenceCount = retainedEvidenceCount
        self.droppedEvidenceCount = droppedEvidenceCount
        self.droppedInjectedEvidenceCount = droppedInjectedEvidenceCount
        self.droppedDuplicateEvidenceCount = droppedDuplicateEvidenceCount
        self.droppedBudgetEvidenceCount = droppedBudgetEvidenceCount
        self.suppressedBehaviorCount = suppressedBehaviorCount
        self.dominantActionRawValue = dominantActionRawValue
        self.strongestSignalRawValue = strongestSignalRawValue
        self.dominantReactionWeight = dominantReactionWeight
        self.profileCoreCount = profileCoreCount
        self.activeGoalCount = activeGoalCount
        self.relevantMemoryCount = relevantMemoryCount
        self.loadedPromotedMemoryCount = loadedPromotedMemoryCount
        self.loadedPendingMemoryCount = loadedPendingMemoryCount
        self.pendingCandidateCount = pendingCandidateCount
        self.promotedRecordCount = promotedRecordCount
        self.screenedOutMemoryCount = screenedOutMemoryCount
        self.loadedEligibilityReasonCounts = loadedEligibilityReasonCounts
        self.screenedOutEligibilityReasonCounts = screenedOutEligibilityReasonCounts
        self.snapshotFingerprint = snapshotFingerprint
        self.lowTrustMemoryLoadRate = lowTrustMemoryLoadRate
        self.riskFlags = riskFlags
        self.identityRole = identityRole
        self.boundaryMode = boundaryMode
        self.activeConstraints = activeConstraints
        self.calibrationStatus = calibrationStatus
        self.calibrationAlerts = calibrationAlerts
        self.evolutionCheckpointCount = evolutionCheckpointCount
        self.evolutionPendingReviewCount = evolutionPendingReviewCount
        self.evolutionRollbackReady = evolutionRollbackReady
        self.attemptedProviderIDs = attemptedProviderIDs
        self.runtimeStrategy = runtimeStrategy
        self.semanticPromptFingerprint = semanticPromptFingerprint
        self.stablePrefixFingerprint = stablePrefixFingerprint
        self.consistencyChecked = consistencyChecked
        self.consistencyRejected = consistencyRejected
        self.consistencyViolationKinds = consistencyViolationKinds
    }
}

public struct BASAppleRuntimeInspectionSourceInput: Codable, Sendable, Equatable {
    public var activeProviderID: String
    public var fallbackProviderID: String?
    public var runtimeGear: BASRuntimeGear
    public var environmentClass: BASEnvironmentClass
    public var deviceClass: BASDevicePerformanceClass
    public var languageMode: BASLanguageMode
    public var taskEntropyByKind: [String: BASTaskEntropyClass]
    public var preferredProviderRawValueByKind: [String: String]
    public var strategyByKind: [String: BASAdaptiveTaskStrategy]
    public var effectivePreferredProviderRawValueByKind: [String: String]
    public var traceSources: [BASAppleRuntimeInspectionTraceSourceInput]
    public var telemetrySummary: BASTelemetrySummary
    public var totalCacheEntries: Int
    public var totalCacheLookupCount: Int
    public var totalCacheRejectedStores: Int
    public var totalCacheQuarantinedHits: Int
    public var dominantBackendID: String?
    public var registeredProviderCount: Int
    public var registeredOpenModelProviderCount: Int
    public var activeCircuitProviderIDs: [String]
    public var circuitTripCount: Int
    public var circuitTripCountByProvider: [String: Int]
    public var circuitTripCountByReason: [String: Int]
    public var traceCount: Int
    public var replayCount: Int

    public init(
        activeProviderID: String,
        fallbackProviderID: String?,
        runtimeGear: BASRuntimeGear,
        environmentClass: BASEnvironmentClass,
        deviceClass: BASDevicePerformanceClass,
        languageMode: BASLanguageMode,
        taskEntropyByKind: [String: BASTaskEntropyClass],
        preferredProviderRawValueByKind: [String: String],
        strategyByKind: [String: BASAdaptiveTaskStrategy],
        effectivePreferredProviderRawValueByKind: [String: String],
        traceSources: [BASAppleRuntimeInspectionTraceSourceInput],
        telemetrySummary: BASTelemetrySummary,
        totalCacheEntries: Int,
        totalCacheLookupCount: Int,
        totalCacheRejectedStores: Int,
        totalCacheQuarantinedHits: Int,
        dominantBackendID: String?,
        registeredProviderCount: Int,
        registeredOpenModelProviderCount: Int,
        activeCircuitProviderIDs: [String],
        circuitTripCount: Int,
        circuitTripCountByProvider: [String: Int],
        circuitTripCountByReason: [String: Int],
        traceCount: Int,
        replayCount: Int
    ) {
        self.activeProviderID = activeProviderID
        self.fallbackProviderID = fallbackProviderID
        self.runtimeGear = runtimeGear
        self.environmentClass = environmentClass
        self.deviceClass = deviceClass
        self.languageMode = languageMode
        self.taskEntropyByKind = taskEntropyByKind
        self.preferredProviderRawValueByKind = preferredProviderRawValueByKind
        self.strategyByKind = strategyByKind
        self.effectivePreferredProviderRawValueByKind = effectivePreferredProviderRawValueByKind
        self.traceSources = traceSources
        self.telemetrySummary = telemetrySummary
        self.totalCacheEntries = totalCacheEntries
        self.totalCacheLookupCount = totalCacheLookupCount
        self.totalCacheRejectedStores = totalCacheRejectedStores
        self.totalCacheQuarantinedHits = totalCacheQuarantinedHits
        self.dominantBackendID = dominantBackendID
        self.registeredProviderCount = registeredProviderCount
        self.registeredOpenModelProviderCount = registeredOpenModelProviderCount
        self.activeCircuitProviderIDs = activeCircuitProviderIDs
        self.circuitTripCount = circuitTripCount
        self.circuitTripCountByProvider = circuitTripCountByProvider
        self.circuitTripCountByReason = circuitTripCountByReason
        self.traceCount = traceCount
        self.replayCount = replayCount
    }
}

public struct BASAppleRuntimeInspectionCompilation: Codable, Sendable, Equatable {
    public var lifecycleSummary: BASLifecycleSummary
    public var neuralSummary: BASNeuralSummary
    public var brainSummary: BASBrainSummary
    public var runtimeInspectionInput: BASRuntimeInspectionInput
    public var runtimeInspectionSummary: BASRuntimeInspectionSummary

    public init(
        lifecycleSummary: BASLifecycleSummary,
        neuralSummary: BASNeuralSummary,
        brainSummary: BASBrainSummary,
        runtimeInspectionInput: BASRuntimeInspectionInput,
        runtimeInspectionSummary: BASRuntimeInspectionSummary
    ) {
        self.lifecycleSummary = lifecycleSummary
        self.neuralSummary = neuralSummary
        self.brainSummary = brainSummary
        self.runtimeInspectionInput = runtimeInspectionInput
        self.runtimeInspectionSummary = runtimeInspectionSummary
    }
}

public enum BASAppleRuntimeInspectionBuilder {
    public static func traceSource(
        from record: BASAppleRuntimeInspectionTraceRecordInput
    ) -> BASAppleRuntimeInspectionTraceSourceInput {
        BASAppleRuntimeInspectionTraceSourceInput(
            lifecycle: BASLifecycleTraceInput(
                kind: record.kind,
                hasContextState: record.hasContextState,
                generation: record.generation,
                rebuiltSession: record.rebuiltSession,
                staleFieldCount: record.staleFieldCount,
                anchorFieldCount: record.anchorFieldCount,
                hasFrontstageState: record.hasFrontstageState,
                retainedEvidenceCount: record.retainedEvidenceCount,
                droppedEvidenceCount: record.droppedEvidenceCount,
                droppedInjectedEvidenceCount: record.droppedInjectedEvidenceCount,
                droppedDuplicateEvidenceCount: record.droppedDuplicateEvidenceCount,
                droppedBudgetEvidenceCount: record.droppedBudgetEvidenceCount
            ),
            neural: record.suppressedBehaviorCount.map { suppressedBehaviorCount in
                BASNeuralTraceInput(
                    kind: record.kind,
                    suppressedBehaviorCount: suppressedBehaviorCount,
                    dominantActionRawValue: record.dominantActionRawValue,
                    strongestSignalRawValue: record.strongestSignalRawValue
                )
            },
            brain: record.dominantReactionWeight.map { dominantReactionWeight in
                BASBrainTraceInput(
                    kind: record.kind,
                    dominantReactionWeight: dominantReactionWeight,
                    profileCoreCount: record.profileCoreCount ?? 0,
                    activeGoalCount: record.activeGoalCount ?? 0,
                    relevantMemoryCount: record.relevantMemoryCount ?? 0,
                    loadedPromotedMemoryCount: record.loadedPromotedMemoryCount ?? 0,
                    loadedPendingMemoryCount: record.loadedPendingMemoryCount ?? 0,
                    pendingCandidateCount: record.pendingCandidateCount ?? 0,
                    promotedRecordCount: record.promotedRecordCount ?? 0,
                    screenedOutMemoryCount: record.screenedOutMemoryCount ?? 0,
                    loadedEligibilityReasonCounts: record.loadedEligibilityReasonCounts,
                    screenedOutEligibilityReasonCounts: record.screenedOutEligibilityReasonCounts,
                    snapshotFingerprint: record.snapshotFingerprint ?? "",
                    lowTrustMemoryLoadRate: record.lowTrustMemoryLoadRate ?? 0,
                    riskFlags: record.riskFlags,
                    identityRole: record.identityRole ?? .pauseCompanion,
                    boundaryMode: record.boundaryMode ?? .localOnlyAdvisory,
                    activeConstraints: record.activeConstraints,
                    calibrationStatus: record.calibrationStatus ?? .stable,
                    calibrationAlerts: record.calibrationAlerts,
                    evolutionCheckpointCount: record.evolutionCheckpointCount ?? 0,
                    evolutionPendingReviewCount: record.evolutionPendingReviewCount ?? 0,
                    evolutionRollbackReady: record.evolutionRollbackReady ?? false
                )
            },
            runtimeInspection: BASRuntimeInspectionTraceInput(
                kind: record.kind,
                attemptedProviderIDs: record.attemptedProviderIDs,
                runtimeStrategy: record.runtimeStrategy,
                semanticPromptFingerprint: record.semanticPromptFingerprint,
                stablePrefixFingerprint: record.stablePrefixFingerprint,
                consistencyChecked: record.consistencyChecked,
                consistencyRejected: record.consistencyRejected,
                consistencyViolationKinds: record.consistencyViolationKinds
            )
        )
    }

    public static func build(
        from input: BASAppleRuntimeInspectionSourceInput
    ) -> BASAppleRuntimeInspectionCompilation {
        let lifecycleTraceInputs = input.traceSources.compactMap(\.lifecycle)
        let neuralTraceInputs = input.traceSources.compactMap(\.neural)
        let brainTraceInputs = input.traceSources.compactMap(\.brain)
        let runtimeInspectionTraceInputs = input.traceSources.map(\.runtimeInspection)

        let lifecycleSummary = BASLifecycleSummaryBuilder.build(
            from: lifecycleTraceInputs
        )
        let neuralSummary = BASNeuralSummaryBuilder.build(
            from: neuralTraceInputs
        )
        let brainSummary = BASBrainSummaryBuilder.build(
            from: brainTraceInputs
        )
        let runtimeInspectionInput = BASAppleObservabilityAdapter.compileRuntimeInspectionInput(
            from: BASAppleRuntimeInspectionAdapterInput(
                activeProviderID: input.activeProviderID,
                fallbackProviderID: input.fallbackProviderID,
                runtimeGear: input.runtimeGear,
                environmentClass: input.environmentClass,
                deviceClass: input.deviceClass,
                languageMode: input.languageMode,
                taskEntropyByKind: input.taskEntropyByKind,
                preferredProviderRawValueByKind: input.preferredProviderRawValueByKind,
                strategyByKind: input.strategyByKind,
                effectivePreferredProviderRawValueByKind: input.effectivePreferredProviderRawValueByKind,
                traceInputs: runtimeInspectionTraceInputs,
                telemetrySummary: input.telemetrySummary,
                lifecycleSummary: lifecycleSummary,
                neuralSummary: neuralSummary,
                brainSummary: brainSummary,
                totalCacheEntries: input.totalCacheEntries,
                totalCacheLookupCount: input.totalCacheLookupCount,
                totalCacheRejectedStores: input.totalCacheRejectedStores,
                totalCacheQuarantinedHits: input.totalCacheQuarantinedHits,
                dominantBackendID: input.dominantBackendID,
                registeredProviderCount: input.registeredProviderCount,
                registeredOpenModelProviderCount: input.registeredOpenModelProviderCount,
                activeCircuitProviderIDs: input.activeCircuitProviderIDs,
                circuitTripCount: input.circuitTripCount,
                circuitTripCountByProvider: input.circuitTripCountByProvider,
                circuitTripCountByReason: input.circuitTripCountByReason,
                traceCount: input.traceCount,
                replayCount: input.replayCount
            )
        )

        return BASAppleRuntimeInspectionCompilation(
            lifecycleSummary: lifecycleSummary,
            neuralSummary: neuralSummary,
            brainSummary: brainSummary,
            runtimeInspectionInput: runtimeInspectionInput,
            runtimeInspectionSummary: BASRuntimeInspectionBuilder.build(from: runtimeInspectionInput)
        )
    }
}

public extension BASAppleObservabilityAdapter {
    static func compileRuntimeInspectionInput(
        from input: BASAppleRuntimeInspectionAdapterInput
    ) -> BASRuntimeInspectionInput {
        BASRuntimeInspectionInput(
            activeProviderID: input.activeProviderID,
            fallbackProviderID: input.fallbackProviderID,
            runtimeGear: input.runtimeGear,
            environmentClass: input.environmentClass,
            deviceClass: input.deviceClass,
            languageMode: input.languageMode,
            taskEntropyByKind: input.taskEntropyByKind,
            preferredProviderRawValueByKind: input.preferredProviderRawValueByKind,
            strategyByKind: input.strategyByKind,
            effectivePreferredProviderRawValueByKind: input.effectivePreferredProviderRawValueByKind,
            traceInputs: input.traceInputs,
            telemetrySummary: input.telemetrySummary,
            lifecycleSummary: input.lifecycleSummary,
            neuralSummary: input.neuralSummary,
            brainSummary: input.brainSummary,
            totalCacheEntries: input.totalCacheEntries,
            totalCacheLookupCount: input.totalCacheLookupCount,
            totalCacheRejectedStores: input.totalCacheRejectedStores,
            totalCacheQuarantinedHits: input.totalCacheQuarantinedHits,
            dominantBackendID: input.dominantBackendID,
            registeredProviderCount: input.registeredProviderCount,
            registeredOpenModelProviderCount: input.registeredOpenModelProviderCount,
            activeCircuitProviderIDs: input.activeCircuitProviderIDs,
            circuitTripCount: input.circuitTripCount,
            circuitTripCountByProvider: input.circuitTripCountByProvider,
            circuitTripCountByReason: input.circuitTripCountByReason,
            traceCount: input.traceCount,
            replayCount: input.replayCount
        )
    }
}
