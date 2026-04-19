import Foundation
import SwiftData
import BASHostKit

enum DecisionMemorySystem {
    static let projectionRefreshLimits = BeforeProductCompatibility.projectionRefreshLimits
    static let projectionRecordLimit = projectionRefreshLimits.recordLimit
    static let projectionCandidateLimit = projectionRefreshLimits.candidateLimit
    static let projectionCheckEventLimit = projectionRefreshLimits.checkEventLimit

    typealias BrainStateProjection = BASAppleMemoryProjectionRefreshResult
    typealias BrainStateCompiler = @Sendable (
        _ mode: DecisionMode,
        _ prompt: String,
        _ projection: BrainStateProjection,
        _ retrievalMode: DecisionRetrievalMode,
        _ now: Date,
        _ preferredLanguages: [String]
    ) throws -> DecisionBrainState

    static func refreshStoredMemories(
        in context: ModelContext,
        executionCapabilityFrame: DecisionEBrainExecutionCapabilityFrame? = nil,
        now: Date = .now
    ) -> [DecisionMemoryRecord] {
        let persistencePolicy = BeforeProductCompatibility.horizonAwareMemoryPersistencePolicy(
            for: executionCapabilityFrame
        )
        let result: BASAppleMemoryReconciliationWriteResult<
            DecisionMemoryRecord,
            DecisionMemoryCandidateRecord
        > = BASAppleMemoryGovernanceAdapter.refreshStoredMemories(
            in: context,
            now: now,
            cueType: SelfReminder.self,
            checkEventType: CheckEvent.self,
            comparativeRecordType: BalanceDecisionRecord.self,
            reflectiveRecordType: MirrorDecisionRecord.self,
            behavior: BeforeProductCompatibility.memoryDerivationBehavior,
            memoryTrustBehavior: BeforeProductCompatibility.memoryTrustBehavior,
            persistencePolicy: persistencePolicy,
            onSaveError: { error in
                PersistenceIssueRecorder.record(
                    error: error,
                    operation: "reconciling governed memory records"
                )
            }
        )
        return result.orderedRecords
    }

    static func refreshProjection(
        in context: ModelContext,
        executionCapabilityFrame: DecisionEBrainExecutionCapabilityFrame? = nil,
        now: Date = .now
    ) -> BrainStateProjection {
        let persistencePolicy = BeforeProductCompatibility.horizonAwareMemoryPersistencePolicy(
            for: executionCapabilityFrame
        )
        return BASAppleMemoryProjectionRuntime.refresh(
            in: context,
            now: now,
            limits: projectionRefreshLimits,
            recordType: DecisionMemoryRecord.self,
            candidateType: DecisionMemoryCandidateRecord.self,
            cueType: SelfReminder.self,
            checkEventType: CheckEvent.self,
            comparativeRecordType: BalanceDecisionRecord.self,
            reflectiveRecordType: MirrorDecisionRecord.self,
            behavior: BeforeProductCompatibility.memoryDerivationBehavior,
            memoryTrustBehavior: BeforeProductCompatibility.memoryTrustBehavior,
            persistencePolicy: persistencePolicy,
            rebuildEmbeddings: { records, candidates, checkEvents, comparativeRecords, reflectiveRecords in
                EmbeddingMemoryStore.rebuildIndex(
                    records: records,
                    candidates: candidates,
                    checkEvents: checkEvents,
                    balance: comparativeRecords,
                    mirror: reflectiveRecords
                )
            },
            onSaveError: { error in
                PersistenceIssueRecorder.record(
                    error: error,
                    operation: "reconciling governed memory records"
                )
            }
        )
    }

    static func loadBrainState(
        mode: DecisionMode,
        prompt: String,
        context: ModelContext,
        retrievalMode: DecisionRetrievalMode = .filtered,
        executionCapabilityFrame: DecisionEBrainExecutionCapabilityFrame? = nil,
        now: Date = .now
    ) -> DecisionBrainState {
        loadBrainState(
            mode: mode,
            prompt: prompt,
            projection: refreshProjection(
                in: context,
                executionCapabilityFrame: executionCapabilityFrame,
                now: now
            ),
            retrievalMode: retrievalMode,
            executionCapabilityFrame: executionCapabilityFrame,
            now: now
        )
    }

    static func loadBrainState(
        mode: DecisionMode,
        prompt: String,
        projection: BrainStateProjection,
        retrievalMode: DecisionRetrievalMode = .filtered,
        executionCapabilityFrame: DecisionEBrainExecutionCapabilityFrame? = nil,
        now: Date = .now,
        compileBrainState: BrainStateCompiler? = nil
    ) -> DecisionBrainState {
        let resolvedCognitionBehavior = BeforeProductCompatibility.horizonAwareCognitionBehavior(
            for: executionCapabilityFrame
        )
        let compiler = compileBrainState ?? defaultBrainStateCompiler(
            cognitionBehavior: resolvedCognitionBehavior
        )
        do {
            let compiledState = try compiler(
                mode,
                prompt,
                projection,
                retrievalMode,
                now,
                Locale.preferredLanguages
            )
            return applyHorizonGovernanceOverlay(
                to: compiledState,
                projection: projection
            )
        } catch {
            let recoveryContract = BeforeProductCompatibility.currentBrainBootstrapRecoveryContract
            let fallbackAttempt = PersistenceIssueRecorder.currentStreak(for: .brainBootstrapFallback) + 1
            let shouldQuarantine = fallbackAttempt >= recoveryContract.quarantineEscalationThreshold
            let issueSeverity = shouldQuarantine
                ? recoveryContract.quarantineIssueSeverity
                : recoveryContract.recoveryIssueSeverity
            let issueSummary = shouldQuarantine
                ? recoveryContract.quarantineIssueSummary
                : recoveryContract.recoveryIssueSummary
            let issueRemediation = shouldQuarantine
                ? recoveryContract.quarantineIssueRemediation
                : recoveryContract.recoveryIssueRemediation
            _ = PersistenceIssueRecorder.record(
                category: .brainBootstrapFallback,
                severity: issueSeverity == .critical ? .critical : .warning,
                operation: "bootstrapping current brain state from projection",
                summary: issueSummary,
                detail: error.localizedDescription,
                remediation: issueRemediation,
                recordedAt: now
            )
            let relevantMemories = projection.baseProjection.records
                .prefix(3)
                .map(\.content)
            let trimmedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
            let fallbackLoadedAt = now
            let sessionBiases = shouldQuarantine
                ? recoveryContract.quarantineSessionBiases
                : recoveryContract.recoverySessionBiases
            let retrievalTags = shouldQuarantine
                ? recoveryContract.quarantineRetrievalTags
                : recoveryContract.recoveryRetrievalTags
            let restrictionTags = shouldQuarantine
                ? recoveryContract.quarantineRestrictionTags
                : recoveryContract.recoveryRestrictionTags
            let calibrationStatus = shouldQuarantine
                ? recoveryContract.quarantineCalibrationStatus
                : recoveryContract.recoveryCalibrationStatus
            let calibrationAlertIDs = shouldQuarantine
                ? recoveryContract.quarantineCalibrationAlertIDs
                : recoveryContract.recoveryCalibrationAlertIDs
            let calibrationAlerts = calibrationAlertIDs.compactMap(BASCalibrationAlert.init(rawValue:))
            let contractFailureGuardIDs = shouldQuarantine
                ? recoveryContract.quarantineFailureGuardIDs
                : recoveryContract.recoveryFailureGuardIDs
            let suggestedAdjustments = shouldQuarantine
                ? recoveryContract.quarantineSuggestedAdjustments
                : recoveryContract.recoverySuggestedAdjustments
            let driftScore = shouldQuarantine
                ? recoveryContract.quarantineDriftScore
                : recoveryContract.recoveryDriftScore
            let pendingReviewCount = shouldQuarantine
                ? recoveryContract.quarantinePendingReviewCount
                : recoveryContract.recoveryPendingReviewCount
            let diffSummary = shouldQuarantine
                ? recoveryContract.quarantineDiffSummary
                : recoveryContract.recoveryDiffSummary
            let reactionWeights = shouldQuarantine
                ? recoveryContract.quarantineReactionWeightsByMode?[mode.rawValue]
                    ?? BeforeProductCompatibility.reactionWeights(for: mode)
                : recoveryContract.recoveryReactionWeightsByMode?[mode.rawValue]
                    ?? BeforeProductCompatibility.reactionWeights(for: mode)
            let identityProfile = shouldQuarantine
                ? recoveryContract.quarantineIdentityProfilesByMode?[mode.rawValue]
                    ?? BeforeProductCompatibility.identityProfile(for: mode)
                : recoveryContract.recoveryIdentityProfilesByMode?[mode.rawValue]
                    ?? BeforeProductCompatibility.identityProfile(for: mode)
            let memoryGovernance = fallbackMemoryGovernance(from: projection)
            let boundaryPolicy = fallbackBoundaryPolicy(
                from: recoveryContract,
                shouldQuarantine: shouldQuarantine
            )
            let failureGuardIDs = orderedUnique(
                contractFailureGuardIDs + projection.baseProjection.failureGuardIDs
            )
            let activeTemplateIDs = orderedUnique(
                fallbackActiveTemplateIDs(
                    from: recoveryContract,
                    shouldQuarantine: shouldQuarantine
                ) + projection.baseProjection.activeTemplateIDs
            )
            return DecisionBrainState(
                profileCore: [],
                activeGoals: trimmedPrompt.isEmpty ? [] : [trimmedPrompt],
                relevantMemories: relevantMemories,
                sessionBiases: orderedUnique(
                    sessionBiases + ["retrieval:\(retrievalMode.rawValue)"]
                ),
                retrievalTags: orderedUnique(
                    retrievalTags + restrictionTags + ["retrieval:\(retrievalMode.rawValue)"]
                ),
                reactionWeights: reactionWeights,
                identityProfile: identityProfile,
                boundaryPolicy: boundaryPolicy,
                calibrationState: BASCalibrationState(
                    status: calibrationStatus,
                    alerts: calibrationAlerts,
                    suggestedAdjustments: suggestedAdjustments,
                    driftScore: driftScore,
                    generatedAt: fallbackLoadedAt
                ),
                evolutionState: BASEvolutionState(
                    latestCheckpoint: nil,
                    checkpointCount: 0,
                    rollbackReady: false,
                    pendingReviewCount: pendingReviewCount,
                    recentDiffSummary: diffSummary
                ),
                activeInterventionTemplateIDs: activeTemplateIDs,
                failureGuardIDs: failureGuardIDs,
                memoryGovernance: memoryGovernance,
                loadedAt: fallbackLoadedAt
            )
        }
    }

    private static func fallbackMemoryGovernance(
        from projection: BrainStateProjection
    ) -> BASMemoryGovernanceState {
        if let governance = projection.baseProjection.governanceSnapshot {
            return governance
        }

        let promotedRecordCount = projection.baseProjection.records.count
        let pendingMemoryCount = projection.baseProjection.candidates.filter(\.isPending).count
        let governanceSnapshot = projection.governanceSnapshot
        return BASMemoryGovernanceState(
            totalRecordCount: governanceSnapshot.totalRecordCount,
            totalCandidateCount: governanceSnapshot.totalCandidateCount,
            pendingCandidateCount: governanceSnapshot.pendingCandidateCount,
            promotedCandidateCount: governanceSnapshot.promotedCandidateCount,
            loadedPromotedMemoryCount: promotedRecordCount,
            loadedPendingMemoryCount: pendingMemoryCount,
            deferredCandidateCount: governanceSnapshot.deferredCandidateCount,
            admittedCandidateCount: governanceSnapshot.admittedCandidateCount
        )
    }

    private static func fallbackBoundaryPolicy(
        from contract: BeforeBrainBootstrapRecoveryContract,
        shouldQuarantine: Bool
    ) -> BASBoundaryPolicyState {
        let riskLevel = shouldQuarantine
            ? contract.quarantineBoundaryRiskLevel
            : contract.recoveryBoundaryRiskLevel
        let allowedActionClasses = shouldQuarantine
            ? contract.quarantineAllowedActionClasses
            : contract.recoveryAllowedActionClasses
        let blockedActionClasses = shouldQuarantine
            ? contract.quarantineBlockedActionClasses
            : contract.recoveryBlockedActionClasses
        let requiredConfirmations = shouldQuarantine
            ? contract.quarantineRequiredConfirmations
            : contract.recoveryRequiredConfirmations
        let activeConstraints = shouldQuarantine
            ? contract.quarantineBoundaryConstraints
            : contract.recoveryBoundaryConstraints
        let auditHeadline = shouldQuarantine
            ? contract.quarantineBoundaryAuditHeadline
            : contract.recoveryBoundaryAuditHeadline

        return BASBoundaryPolicyState(
            mode: .localOnlyProtective,
            riskLevel: substrateRiskLevel(from: riskLevel),
            allowedActionClasses: orderedUnique(allowedActionClasses),
            blockedActionClasses: orderedUnique(blockedActionClasses),
            requiredConfirmations: orderedUnique(requiredConfirmations),
            activeConstraints: orderedUniqueConstraints(activeConstraints),
            auditHeadline: auditHeadline
        )
    }

    private static func fallbackActiveTemplateIDs(
        from contract: BeforeBrainBootstrapRecoveryContract,
        shouldQuarantine: Bool
    ) -> [String] {
        shouldQuarantine
            ? contract.quarantineActiveTemplateIDs
            : contract.recoveryActiveTemplateIDs
    }

    private static func defaultBrainStateCompiler(
        cognitionBehavior: BASCognitionBehavior
    ) -> BrainStateCompiler {
        { mode, prompt, projection, retrievalMode, now, preferredLanguages in
            try BASAppleCurrentBrainProjectionStateCompiler.appSessionBrainState(
                modeID: mode.substrateModeID,
                prompt: prompt,
                projection: projection.baseProjection,
                retrievalMode: retrievalMode.rawValue,
                reactionWeightSeed: BeforeProductCompatibility.reactionWeights(for: mode),
                identityProfileOverride: BeforeProductCompatibility.identityProfile(for: mode),
                cognitionBehavior: cognitionBehavior,
                preferredLanguages: preferredLanguages,
                now: now
            )
        }
    }

    private static func applyHorizonGovernanceOverlay(
        to brainState: DecisionBrainState,
        projection: BrainStateProjection
    ) -> DecisionBrainState {
        let riskFlags = brainState.verificationSnapshot.riskFlags
        let projectionCandidates = projection.baseProjection.candidates

        let requiresExternalRefresh = riskFlags.contains(.externalRefreshGuardTriggered) ||
            projectionCandidates.contains { candidate in
                let tagSet = Set(candidate.retrievalTags)
                return tagSet.contains("external_refresh") || tagSet.contains("volatile")
            }

        let requiresToolQuarantine = riskFlags.contains(.observationOnlyQuarantine) ||
            projectionCandidates.contains { candidate in
                let tagSet = Set(candidate.retrievalTags)
                return tagSet.contains("quarantined") || tagSet.contains("tool_observation")
            }

        guard requiresExternalRefresh || requiresToolQuarantine else {
            return brainState
        }

        var sessionBiases = brainState.sessionBiases
        var retrievalTags = brainState.retrievalTags

        if requiresExternalRefresh {
            sessionBiases.append("horizon-external-refresh")
            sessionBiases.append("Keep uncertainty visible until fresh evidence arrives.")
            retrievalTags.append(contentsOf: ["external_refresh", "volatile"])
        }

        if requiresToolQuarantine {
            sessionBiases.append("horizon-tool-quarantine")
            sessionBiases.append("Treat tool observations as provisional until corroborated.")
            retrievalTags.append(contentsOf: ["quarantine", "tool_observation"])
        }

        var updated = brainState
        updated.sessionBiases = orderedUnique(sessionBiases)
        updated.retrievalTags = orderedUnique(retrievalTags)
        return updated
    }

    private static func orderedUnique(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.filter { seen.insert($0).inserted }
    }

    private static func orderedUniqueConstraints(
        _ values: [BASBoundaryConstraint]
    ) -> [BASBoundaryConstraint] {
        var seen = Set<String>()
        return values.filter { seen.insert($0.rawValue).inserted }
    }

    static func fetchMemoryRecords(
        in context: ModelContext,
        limit: Int? = nil
    ) -> [DecisionMemoryRecord] {
        BASAppleMemoryProjectionSelectionAdapter.fetchProjectionRecords(
            in: context,
            recordType: DecisionMemoryRecord.self,
            limit: limit
        )
    }

    static func fetchCandidateRecords(
        in context: ModelContext,
        limit: Int? = nil
    ) -> [DecisionMemoryCandidateRecord] {
        BASAppleMemoryProjectionSelectionAdapter.fetchPendingProjectionCandidates(
            in: context,
            candidateType: DecisionMemoryCandidateRecord.self,
            limit: limit
        )
    }

    static func fetchCheckEvents(
        in context: ModelContext,
        limit: Int = projectionCheckEventLimit
    ) -> [CheckEvent] {
        BASAppleMemoryProjectionSelectionAdapter.fetchProjectionCheckEvents(
            in: context,
            eventType: CheckEvent.self,
            limit: limit
        )
    }

    static func fetchBalanceRecords(
        in context: ModelContext,
        limit: Int = projectionRefreshLimits.comparativeRecordLimit
    ) -> [BalanceDecisionRecord] {
        BASAppleMemoryProjectionSelectionAdapter.fetchProjectionComparativeRecords(
            in: context,
            comparativeType: BalanceDecisionRecord.self,
            limit: limit
        )
    }

    static func fetchMirrorRecords(
        in context: ModelContext,
        limit: Int = projectionRefreshLimits.reflectiveRecordLimit
    ) -> [MirrorDecisionRecord] {
        BASAppleMemoryProjectionSelectionAdapter.fetchProjectionReflectiveRecords(
            in: context,
            reflectiveType: MirrorDecisionRecord.self,
            limit: limit
        )
    }

}
