import Foundation
import BASMemory
import BASObservability
import BASPolicy
import BASRuntimeCore

public struct BASAppleRuntimeInspectionAdaptiveStrategySourceInput: Codable, Sendable, Equatable {
    public var kindID: String
    public var entropyID: String
    public var runtimeGearID: String
    public var contextBudget: Int
    public var outputCharacterBudget: Int
    public var timeBudgetMs: Int
    public var toolCallBudget: Int
    public var retrievalItemBudget: Int
    public var retrievalModeID: String
    public var thinkingModeID: String
    public var outputModeID: String
    public var toneID: String
    public var actionSpace: [String]
    public var responseLanguageID: String
    public var allowsModelInvocation: Bool

    public init(
        kindID: String,
        entropyID: String,
        runtimeGearID: String,
        contextBudget: Int,
        outputCharacterBudget: Int,
        timeBudgetMs: Int,
        toolCallBudget: Int,
        retrievalItemBudget: Int,
        retrievalModeID: String,
        thinkingModeID: String,
        outputModeID: String,
        toneID: String,
        actionSpace: [String],
        responseLanguageID: String,
        allowsModelInvocation: Bool
    ) {
        self.kindID = kindID
        self.entropyID = entropyID
        self.runtimeGearID = runtimeGearID
        self.contextBudget = contextBudget
        self.outputCharacterBudget = outputCharacterBudget
        self.timeBudgetMs = timeBudgetMs
        self.toolCallBudget = toolCallBudget
        self.retrievalItemBudget = retrievalItemBudget
        self.retrievalModeID = retrievalModeID
        self.thinkingModeID = thinkingModeID
        self.outputModeID = outputModeID
        self.toneID = toneID
        self.actionSpace = actionSpace
        self.responseLanguageID = responseLanguageID
        self.allowsModelInvocation = allowsModelInvocation
    }
}

public struct BASAppleRuntimeInspectionTraceSourceRecordInput: Codable, Sendable, Equatable {
    public var kindID: String
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
    public var dominantActionID: String?
    public var strongestSignalID: String?
    public var dominantReactionWeightID: String?
    public var profileCoreCount: Int?
    public var activeGoalCount: Int?
    public var relevantMemoryCount: Int?
    public var loadedPromotedMemoryCount: Int?
    public var loadedPendingMemoryCount: Int?
    public var pendingCandidateCount: Int?
    public var promotedRecordCount: Int?
    public var screenedOutMemoryCount: Int?
    public var loadedEligibilityReasonCounts: [String: Int]
    public var screenedOutEligibilityReasonCounts: [String: Int]
    public var snapshotFingerprint: String?
    public var constitutionVersion: String?
    public var constitutionPhase: String?
    public var constitutionValueAxisCount: Int?
    public var forgetRequestID: String?
    public var forgetVerified: Bool?
    public var forgetRevokesCheckpoints: Bool?
    public var vaultConsistencyState: String?
    public var vaultSyncRevocationCount: Int?
    public var vaultOutOfSyncDeviceIDs: [String]
    public var vaultMigrationTargetDeviceID: String?
    public var lowTrustMemoryLoadRate: Double?
    public var riskFlagIDs: [String]
    public var identityRoleID: String?
    public var boundaryModeID: String?
    public var activeConstraintIDs: [String]
    public var calibrationStatusID: String?
    public var calibrationAlertIDs: [String]
    public var evolutionCheckpointCount: Int?
    public var evolutionPendingReviewCount: Int?
    public var evolutionRollbackReady: Bool?
    public var attemptedProviderIDs: [String]
    public var runtimeStrategy: BASAppleRuntimeInspectionAdaptiveStrategySourceInput?
    public var semanticPromptFingerprint: String?
    public var stablePrefixFingerprint: String?
    public var consistencyChecked: Bool
    public var consistencyRejected: Bool
    public var consistencyViolationKindIDs: [String]

    public init(
        kindID: String,
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
        dominantActionID: String? = nil,
        strongestSignalID: String? = nil,
        dominantReactionWeightID: String? = nil,
        profileCoreCount: Int? = nil,
        activeGoalCount: Int? = nil,
        relevantMemoryCount: Int? = nil,
        loadedPromotedMemoryCount: Int? = nil,
        loadedPendingMemoryCount: Int? = nil,
        pendingCandidateCount: Int? = nil,
        promotedRecordCount: Int? = nil,
        screenedOutMemoryCount: Int? = nil,
        loadedEligibilityReasonCounts: [String: Int] = [:],
        screenedOutEligibilityReasonCounts: [String: Int] = [:],
        snapshotFingerprint: String? = nil,
        constitutionVersion: String? = nil,
        constitutionPhase: String? = nil,
        constitutionValueAxisCount: Int? = nil,
        forgetRequestID: String? = nil,
        forgetVerified: Bool? = nil,
        forgetRevokesCheckpoints: Bool? = nil,
        vaultConsistencyState: String? = nil,
        vaultSyncRevocationCount: Int? = nil,
        vaultOutOfSyncDeviceIDs: [String] = [],
        vaultMigrationTargetDeviceID: String? = nil,
        lowTrustMemoryLoadRate: Double? = nil,
        riskFlagIDs: [String] = [],
        identityRoleID: String? = nil,
        boundaryModeID: String? = nil,
        activeConstraintIDs: [String] = [],
        calibrationStatusID: String? = nil,
        calibrationAlertIDs: [String] = [],
        evolutionCheckpointCount: Int? = nil,
        evolutionPendingReviewCount: Int? = nil,
        evolutionRollbackReady: Bool? = nil,
        attemptedProviderIDs: [String],
        runtimeStrategy: BASAppleRuntimeInspectionAdaptiveStrategySourceInput? = nil,
        semanticPromptFingerprint: String? = nil,
        stablePrefixFingerprint: String? = nil,
        consistencyChecked: Bool,
        consistencyRejected: Bool,
        consistencyViolationKindIDs: [String] = []
    ) {
        self.kindID = kindID
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
        self.dominantActionID = dominantActionID
        self.strongestSignalID = strongestSignalID
        self.dominantReactionWeightID = dominantReactionWeightID
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
        self.constitutionVersion = constitutionVersion
        self.constitutionPhase = constitutionPhase
        self.constitutionValueAxisCount = constitutionValueAxisCount
        self.forgetRequestID = forgetRequestID
        self.forgetVerified = forgetVerified
        self.forgetRevokesCheckpoints = forgetRevokesCheckpoints
        self.vaultConsistencyState = vaultConsistencyState
        self.vaultSyncRevocationCount = vaultSyncRevocationCount
        self.vaultOutOfSyncDeviceIDs = vaultOutOfSyncDeviceIDs
        self.vaultMigrationTargetDeviceID = vaultMigrationTargetDeviceID
        self.lowTrustMemoryLoadRate = lowTrustMemoryLoadRate
        self.riskFlagIDs = riskFlagIDs
        self.identityRoleID = identityRoleID
        self.boundaryModeID = boundaryModeID
        self.activeConstraintIDs = activeConstraintIDs
        self.calibrationStatusID = calibrationStatusID
        self.calibrationAlertIDs = calibrationAlertIDs
        self.evolutionCheckpointCount = evolutionCheckpointCount
        self.evolutionPendingReviewCount = evolutionPendingReviewCount
        self.evolutionRollbackReady = evolutionRollbackReady
        self.attemptedProviderIDs = attemptedProviderIDs
        self.runtimeStrategy = runtimeStrategy
        self.semanticPromptFingerprint = semanticPromptFingerprint
        self.stablePrefixFingerprint = stablePrefixFingerprint
        self.consistencyChecked = consistencyChecked
        self.consistencyRejected = consistencyRejected
        self.consistencyViolationKindIDs = consistencyViolationKindIDs
    }
}

public struct BASAppleRuntimeInspectionExportSourceInput: Codable, Sendable, Equatable {
    public var activeProviderID: String
    public var fallbackProviderID: String?
    public var runtimeGearID: String
    public var environmentClassID: String
    public var deviceClassID: String
    public var languageModeID: String
    public var taskEntropyIDByKind: [String: String]
    public var preferredProviderIDByKind: [String: String]
    public var strategyByKind: [String: BASAppleRuntimeInspectionAdaptiveStrategySourceInput]
    public var effectivePreferredProviderIDByKind: [String: String]
    public var traceRecords: [BASAppleRuntimeInspectionTraceSourceRecordInput]
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
        runtimeGearID: String,
        environmentClassID: String,
        deviceClassID: String,
        languageModeID: String,
        taskEntropyIDByKind: [String: String],
        preferredProviderIDByKind: [String: String],
        strategyByKind: [String: BASAppleRuntimeInspectionAdaptiveStrategySourceInput],
        effectivePreferredProviderIDByKind: [String: String],
        traceRecords: [BASAppleRuntimeInspectionTraceSourceRecordInput],
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
        self.runtimeGearID = runtimeGearID
        self.environmentClassID = environmentClassID
        self.deviceClassID = deviceClassID
        self.languageModeID = languageModeID
        self.taskEntropyIDByKind = taskEntropyIDByKind
        self.preferredProviderIDByKind = preferredProviderIDByKind
        self.strategyByKind = strategyByKind
        self.effectivePreferredProviderIDByKind = effectivePreferredProviderIDByKind
        self.traceRecords = traceRecords
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

public enum BASAppleRuntimeExportBuilder {
    public static func compileRuntimeInspection(
        from input: BASAppleRuntimeInspectionExportSourceInput
    ) -> BASAppleRuntimeInspectionCompilation {
        BASAppleRuntimeInspectionBuilder.build(
            from: BASAppleRuntimeInspectionSourceInput(
                activeProviderID: input.activeProviderID,
                fallbackProviderID: input.fallbackProviderID,
                runtimeGear: BASRuntimeGear(rawValue: input.runtimeGearID) ?? .balanced,
                environmentClass: BASEnvironmentClass(rawValue: input.environmentClassID) ?? .normal,
                deviceClass: BASDevicePerformanceClass(rawValue: input.deviceClassID) ?? .balancedPhone,
                languageMode: BASLanguageMode(rawValue: input.languageModeID) ?? .unknown,
                taskEntropyByKind: input.taskEntropyIDByKind.reduce(into: [:]) { partialResult, item in
                    partialResult[item.key] = BASTaskEntropyClass(rawValue: item.value) ?? .medium
                },
                preferredProviderRawValueByKind: input.preferredProviderIDByKind,
                strategyByKind: input.strategyByKind.reduce(into: [:]) { partialResult, item in
                    partialResult[item.key] = strategy(from: item.value)
                },
                effectivePreferredProviderRawValueByKind: input.effectivePreferredProviderIDByKind,
                traceSources: input.traceRecords.map(traceSource(from:)),
                telemetrySummary: input.telemetrySummary,
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
    }

    public static func strategy(
        from input: BASAppleRuntimeInspectionAdaptiveStrategySourceInput
    ) -> BASAdaptiveTaskStrategy {
        BASAdaptiveTaskStrategy(
            kind: BASAdaptiveTraceKind(identifier: input.kindID) ?? .primary,
            entropy: BASTaskEntropyClass(rawValue: input.entropyID) ?? .medium,
            runtimeGear: BASRuntimeGear(rawValue: input.runtimeGearID) ?? .balanced,
            contextBudget: input.contextBudget,
            outputCharacterBudget: input.outputCharacterBudget,
            timeBudgetMs: input.timeBudgetMs,
            toolCallBudget: input.toolCallBudget,
            retrievalItemBudget: input.retrievalItemBudget,
            retrievalMode: BASRetrievalMode(rawValue: input.retrievalModeID) ?? .adaptive,
            thinkingMode: BASThinkingMode(rawValue: input.thinkingModeID) ?? .off,
            outputMode: BASOutputMode(rawValue: input.outputModeID) ?? .guidedShort,
            tone: BASToneProfile(rawValue: input.toneID) ?? .neutral,
            actionSpace: input.actionSpace,
            responseLanguage: BASAdaptiveResponseLanguage(rawValue: input.responseLanguageID) ?? .english,
            allowsModelInvocation: input.allowsModelInvocation
        )
    }

    public static func traceSource(
        from input: BASAppleRuntimeInspectionTraceSourceRecordInput
    ) -> BASAppleRuntimeInspectionTraceSourceInput {
        return BASAppleRuntimeInspectionBuilder.traceSource(
            from: BASAppleRuntimeInspectionTraceRecordInput(
                kind: input.kindID,
                hasContextState: input.hasContextState,
                generation: input.generation,
                rebuiltSession: input.rebuiltSession,
                staleFieldCount: input.staleFieldCount,
                anchorFieldCount: input.anchorFieldCount,
                hasFrontstageState: input.hasFrontstageState,
                retainedEvidenceCount: input.retainedEvidenceCount,
                droppedEvidenceCount: input.droppedEvidenceCount,
                droppedInjectedEvidenceCount: input.droppedInjectedEvidenceCount,
                droppedDuplicateEvidenceCount: input.droppedDuplicateEvidenceCount,
                droppedBudgetEvidenceCount: input.droppedBudgetEvidenceCount,
                suppressedBehaviorCount: input.suppressedBehaviorCount,
                dominantActionRawValue: input.dominantActionID,
                strongestSignalRawValue: input.strongestSignalID,
                dominantReactionWeight: input.dominantReactionWeightID.flatMap(BASReactionWeightKey.init(rawValue:)),
                profileCoreCount: input.profileCoreCount,
                activeGoalCount: input.activeGoalCount,
                relevantMemoryCount: input.relevantMemoryCount,
                loadedPromotedMemoryCount: input.loadedPromotedMemoryCount,
                loadedPendingMemoryCount: input.loadedPendingMemoryCount,
                pendingCandidateCount: input.pendingCandidateCount,
                promotedRecordCount: input.promotedRecordCount,
                screenedOutMemoryCount: input.screenedOutMemoryCount,
                loadedEligibilityReasonCounts: eligibilityReasonCounts(from: input.loadedEligibilityReasonCounts),
                screenedOutEligibilityReasonCounts: eligibilityReasonCounts(from: input.screenedOutEligibilityReasonCounts),
                snapshotFingerprint: input.snapshotFingerprint,
                constitutionVersion: input.constitutionVersion,
                constitutionPhase: input.constitutionPhase,
                constitutionValueAxisCount: input.constitutionValueAxisCount,
                forgetRequestID: input.forgetRequestID,
                forgetVerified: input.forgetVerified,
                forgetRevokesCheckpoints: input.forgetRevokesCheckpoints,
                vaultConsistencyState: input.vaultConsistencyState,
                vaultSyncRevocationCount: input.vaultSyncRevocationCount,
                vaultOutOfSyncDeviceIDs: input.vaultOutOfSyncDeviceIDs,
                vaultMigrationTargetDeviceID: input.vaultMigrationTargetDeviceID,
                lowTrustMemoryLoadRate: input.lowTrustMemoryLoadRate,
                riskFlags: input.riskFlagIDs.compactMap(BASBrainStateRiskFlag.init(rawValue:)),
                identityRole: input.identityRoleID.flatMap(BASIdentityRole.init(rawValue:)),
                boundaryMode: input.boundaryModeID.flatMap(BASBoundaryPolicyMode.init(rawValue:)),
                activeConstraints: input.activeConstraintIDs.compactMap(BASBoundaryConstraint.init(rawValue:)),
                calibrationStatus: input.calibrationStatusID.flatMap(BASCalibrationStatus.init(rawValue:)),
                calibrationAlerts: input.calibrationAlertIDs.compactMap(BASCalibrationAlert.init(rawValue:)),
                evolutionCheckpointCount: input.evolutionCheckpointCount,
                evolutionPendingReviewCount: input.evolutionPendingReviewCount,
                evolutionRollbackReady: input.evolutionRollbackReady,
                attemptedProviderIDs: input.attemptedProviderIDs,
                runtimeStrategy: input.runtimeStrategy.map(strategy(from:)),
                semanticPromptFingerprint: input.semanticPromptFingerprint,
                stablePrefixFingerprint: input.stablePrefixFingerprint,
                consistencyChecked: input.consistencyChecked,
                consistencyRejected: input.consistencyRejected,
                consistencyViolationKinds: input.consistencyViolationKindIDs.compactMap(BASConsistencyViolationKind.init(rawValue:))
            )
        )
    }

    private static func eligibilityReasonCounts(
        from raw: [String: Int]
    ) -> [BASMemoryEligibilityReason: Int] {
        raw.reduce(into: [:]) { partialResult, item in
            guard let reason = BASMemoryEligibilityReason(rawValue: item.key) else { return }
            partialResult[reason] = item.value
        }
    }
}
