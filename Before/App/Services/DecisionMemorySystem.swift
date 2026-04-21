import CryptoKit
import Foundation
import SwiftData
import BASHostKit
import BASMemory
import BASRuntimeCore

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
        _ = reconcileTemporalFieldStage(in: context, now: now)
        return result.orderedRecords
    }

    static func refreshProjection(
        in context: ModelContext,
        executionCapabilityFrame: DecisionEBrainExecutionCapabilityFrame? = nil,
        now: Date = .now
    ) -> BrainStateProjection {
        flushPendingContextChanges(
            in: context,
            operation: "preparing memory projection refresh inputs"
        )
        let persistencePolicy = BeforeProductCompatibility.horizonAwareMemoryPersistencePolicy(
            for: executionCapabilityFrame
        )
        let projection = BASAppleMemoryProjectionRuntime.refresh(
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
        let temporalResult = reconcileTemporalFieldStage(in: context, now: now)
        return filteredProjection(projection, temporalResult: temporalResult)
    }

    static func temporalField(
        in context: ModelContext,
        now: Date = .now
    ) -> BASTemporalMemoryField {
        flushPendingContextChanges(
            in: context,
            operation: "preparing temporal memory field inputs"
        )
        let result = buildTemporalField(
            records: fetchMemoryRecords(in: context),
            candidates: fetchTemporalCandidateRecords(in: context),
            now: now
        )
        return result.field
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
            let requiredConfirmations = shouldQuarantine
                ? recoveryContract.quarantineRequiredConfirmations
                : recoveryContract.recoveryRequiredConfirmations
            let allowedActionClasses = shouldQuarantine
                ? recoveryContract.quarantineAllowedActionClasses
                : recoveryContract.recoveryAllowedActionClasses
            let blockedActionClasses = shouldQuarantine
                ? recoveryContract.quarantineBlockedActionClasses
                : recoveryContract.recoveryBlockedActionClasses
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
            let checkpointDiffSummary = orderedUnique(
                diffSummary + fallbackOperatorContractDiffSummary(
                    requiredConfirmations: requiredConfirmations,
                    blockedActionClasses: blockedActionClasses
                )
            )
            return DecisionBrainState(
                profileCore: [],
                activeGoals: trimmedPrompt.isEmpty ? [] : [trimmedPrompt],
                relevantMemories: orderedUnique(
                    relevantMemories + fallbackOperatorContractMemories(
                        from: recoveryContract,
                        shouldQuarantine: shouldQuarantine,
                        requiredConfirmations: requiredConfirmations,
                        allowedActionClasses: allowedActionClasses,
                        blockedActionClasses: blockedActionClasses
                    )
                ),
                sessionBiases: orderedUnique(
                    sessionBiases + fallbackOperatorContractBiases(
                        shouldQuarantine: shouldQuarantine,
                        restrictionTags: restrictionTags,
                        requiredConfirmations: requiredConfirmations
                    ) + ["retrieval:\(retrievalMode.rawValue)"]
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
                    latestCheckpoint: fallbackCheckpointSummary(
                        loadedAt: fallbackLoadedAt,
                        mode: mode,
                        shouldQuarantine: shouldQuarantine,
                        issueSummary: issueSummary,
                        boundaryPolicy: boundaryPolicy,
                        retrievalTags: retrievalTags,
                        restrictionTags: restrictionTags,
                        requiredConfirmations: requiredConfirmations,
                        blockedActionClasses: blockedActionClasses,
                        diffSummary: checkpointDiffSummary
                    ),
                    checkpointCount: 1,
                    rollbackReady: false,
                    pendingReviewCount: pendingReviewCount,
                    recentDiffSummary: checkpointDiffSummary
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

    private static func fallbackOperatorContractMemories(
        from contract: BeforeBrainBootstrapRecoveryContract,
        shouldQuarantine: Bool,
        requiredConfirmations: [String],
        allowedActionClasses: [String],
        blockedActionClasses: [String]
    ) -> [String] {
        let issueSummary = shouldQuarantine
            ? contract.quarantineIssueSummary
            : contract.recoveryIssueSummary
        let issueRemediation = shouldQuarantine
            ? contract.quarantineIssueRemediation
            : contract.recoveryIssueRemediation

        var memories = [issueSummary, issueRemediation]
        if requiredConfirmations.isEmpty == false {
            memories.append("Required confirmations: \(requiredConfirmations.joined(separator: ", "))")
        }
        if blockedActionClasses.isEmpty == false {
            memories.append("Blocked actions: \(blockedActionClasses.joined(separator: ", "))")
        }
        if allowedActionClasses.isEmpty == false {
            memories.append("Allowed actions: \(allowedActionClasses.joined(separator: ", "))")
        }
        return memories
    }

    private static func fallbackOperatorContractBiases(
        shouldQuarantine: Bool,
        restrictionTags: [String],
        requiredConfirmations: [String]
    ) -> [String] {
        var biases = [
            "release-lane:\(shouldQuarantine ? "quarantine" : "recovery")"
        ]
        if restrictionTags.contains("restricted-lease") {
            biases.append("lease:restricted")
        }
        if requiredConfirmations.isEmpty == false {
            biases.append("operator-review-required")
            biases.append(contentsOf: requiredConfirmations.map { "confirmation:\($0)" })
        }
        return biases
    }

    private static func fallbackOperatorContractDiffSummary(
        requiredConfirmations: [String],
        blockedActionClasses: [String]
    ) -> [String] {
        var summary: [String] = []
        if requiredConfirmations.isEmpty == false {
            summary.append("Operator confirmations required before release: \(requiredConfirmations.joined(separator: ", "))")
        }
        if blockedActionClasses.isEmpty == false {
            summary.append("Blocked action classes remain frozen: \(blockedActionClasses.joined(separator: ", "))")
        }
        return summary
    }

    private static func fallbackCheckpointSummary(
        loadedAt: Date,
        mode: DecisionMode,
        shouldQuarantine: Bool,
        issueSummary: String,
        boundaryPolicy: BASBoundaryPolicyState,
        retrievalTags: [String],
        restrictionTags: [String],
        requiredConfirmations: [String],
        blockedActionClasses: [String],
        diffSummary: [String]
    ) -> BASEvolutionCheckpointSummary {
        let recoveryDisposition = fallbackRecoveryDisposition(
            shouldQuarantine: shouldQuarantine,
            issueSummary: issueSummary,
            restrictionTags: restrictionTags,
            requiredConfirmations: requiredConfirmations
        )
        let lineageSummary = BASEvolutionLineageSummary(
            recordedAt: loadedAt,
            sessionID: "brain-bootstrap-fallback.\(mode.rawValue)",
            runMode: shouldQuarantine ? .quarantine : .recovery,
            taskType: "brain-bootstrap-fallback",
            riskLevel: String(describing: boundaryPolicy.riskLevel),
            permitMode: String(describing: boundaryPolicy.mode),
            hostGatePercent: 100,
            thoughtFoldChecksum: "brain-bootstrap-\(shouldQuarantine ? "quarantine" : "recovery")",
            updateTicketSummaries: diffSummary,
            reviewDirectiveLine: requiredConfirmations.isEmpty
                ? nil
                : "operator confirmations: \(requiredConfirmations.joined(separator: ", "))",
            hostChangeCandidateIDs: blockedActionClasses,
            hostChangeTypes: [shouldQuarantine ? "quarantine" : "recovery"],
            guardrailFindings: [issueSummary] + blockedActionClasses.map { "blocked_action:\($0)" },
            recommendedKillSwitches: [],
            stackedModes: [mode.rawValue, shouldQuarantine ? "quarantine" : "recovery"],
            quarantineRecords: fallbackQuarantineRecords(
                loadedAt: loadedAt,
                shouldQuarantine: shouldQuarantine,
                restrictionTags: restrictionTags
            ),
            recoveryDisposition: recoveryDisposition,
            degradedReasonCodes: orderedUnique(
                recoveryDisposition.reasonCodes + retrievalTags + restrictionTags
            )
        )
        return BASEvolutionCheckpointSummary(
            id: "brain-bootstrap-\(shouldQuarantine ? "quarantine" : "recovery")-\(Int(loadedAt.timeIntervalSince1970 * 1_000))",
            previousCheckpointID: nil,
            createdAt: loadedAt,
            diffSummary: diffSummary,
            rollbackReady: false,
            approvalState: .reviewSuggested,
            lineageSummary: lineageSummary
        )
    }

    private static func fallbackRecoveryDisposition(
        shouldQuarantine: Bool,
        issueSummary: String,
        restrictionTags: [String],
        requiredConfirmations: [String]
    ) -> BASRecoveryDisposition {
        let restrictionTagSet = Set(restrictionTags)
        let kind: BASRecoveryDispositionKind = shouldQuarantine ? .quarantine : .recovery
        let reasonCodes = orderedUnique(
            ["brain-bootstrap-\(kind.rawValue)"]
                + restrictionTags
                + requiredConfirmations.map { "confirmation:\($0)" }
        )
        return BASRecoveryDisposition(
            kind: kind,
            summary: issueSummary,
            reasonCodes: reasonCodes,
            remediationRequired: true,
            restrictedLease: restrictionTagSet.contains("restricted-lease"),
            toolWriteAllowed: restrictionTagSet.contains("tool-write-blocked") == false,
            memoryWriteAllowed: restrictionTagSet.contains("memory-write-blocked") == false
        )
    }

    private static func fallbackQuarantineRecords(
        loadedAt: Date,
        shouldQuarantine: Bool,
        restrictionTags: [String]
    ) -> [BASQuarantineRecord] {
        guard shouldQuarantine else {
            return []
        }

        var zones: [BASQuarantineZone] = [.session]
        if restrictionTags.contains("tool-write-blocked") {
            zones.append(.tool)
        }
        if restrictionTags.contains("memory-write-blocked") {
            zones.append(.memory)
        }

        return zones.enumerated().map { index, zone in
            BASQuarantineRecord(
                quarantineID: "brain-bootstrap-quarantine-\(index)",
                zone: zone,
                sourceRef: "brain-bootstrap-fallback",
                reasonCodes: orderedUnique(restrictionTags + ["brain-bootstrap-quarantine"]),
                isolatedAt: loadedAt,
                releasePolicy: "operator confirmation required"
            )
        }
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

    static func fetchTemporalCandidateRecords(
        in context: ModelContext,
        limit: Int? = nil
    ) -> [DecisionMemoryCandidateRecord] {
        let candidates = (try? context.fetch(FetchDescriptor<DecisionMemoryCandidateRecord>())) ?? []
        let ordered = candidates.sorted { lhs, rhs in
            if lhs.lastObservedAt == rhs.lastObservedAt {
                if lhs.priority == rhs.priority {
                    return lhs.id < rhs.id
                }
                return lhs.priority > rhs.priority
            }
            return lhs.lastObservedAt > rhs.lastObservedAt
        }
        guard let limit else { return ordered }
        return Array(ordered.prefix(limit))
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

    static func flushPendingContextChanges(
        in context: ModelContext,
        operation: String
    ) {
        guard context.hasChanges else { return }

        do {
            try context.save()
        } catch {
            PersistenceIssueRecorder.record(
                error: error,
                operation: operation
            )
        }
    }

}

extension DecisionMemorySystem {
    struct TemporalFieldBuildResult {
        let field: BASTemporalMemoryField
        let projectionsByID: [String: DecisionTemporalProjection]
    }

    struct TemporalObservation {
        let id: String
        let topic: String
        let headline: String
        let value: String
        let sourceClass: String
        let timestamp: Date
        let certainty: Double
        let evidenceStrength: Double
        let emotionalWeight: Double
        let retrievalTags: [String]
        let provenanceSummary: String
        let tier: DecisionMemoryTier
        let hostScope: String
        let sovereignScope: String
        let memoryType: BASTemporalMemoryType
        let isCandidate: Bool
        let lifecycleState: DecisionMemoryLifecycleState?
        let lastWriteOperation: DecisionMemoryWriteOperation?
        let lastGovernanceDecision: DecisionMemoryGovernanceDecision?

        var topicKey: String {
            let normalized = topic.temporalIdentifierComponent
            return normalized.isEmpty ? id.temporalIdentifierComponent : normalized
        }

        var conflictSignature: String {
            "\(headline.lowercased())|\(value.lowercased())"
        }

        var summary: String {
            headline.isEmpty ? value : headline
        }
    }

    static func reconcileTemporalFieldStage(
        in context: ModelContext,
        now: Date
    ) -> TemporalFieldBuildResult {
        let records = fetchMemoryRecords(in: context)
        let candidates = fetchTemporalCandidateRecords(in: context)
        let result = buildTemporalField(records: records, candidates: candidates, now: now)
        applyTemporalProjections(
            result.projectionsByID,
            to: records,
            candidates: candidates,
            in: context
        )
        return result
    }

    static func filteredProjection(
        _ projection: BrainStateProjection,
        temporalResult: TemporalFieldBuildResult
    ) -> BrainStateProjection {
        var filtered = projection
        let screenedOutRecords = projection.baseProjection.records.filter { record in
            let temporalProjection = temporalProjection(
                for: record,
                projectionsByID: temporalResult.projectionsByID
            )
            return temporalProjection?.sieveDisposition == .quarantine
                || temporalProjection?.sanctumEntryID != nil
        }
        let screenedOutCandidates = projection.baseProjection.candidates.filter { candidate in
            let temporalProjection = temporalResult.projectionsByID[candidate.id]
            return temporalProjection?.sieveDisposition == .quarantine
                || temporalProjection?.sanctumEntryID != nil
        }
        filtered.baseProjection.records = projection.baseProjection.records.filter { record in
            let temporalProjection = temporalProjection(
                for: record,
                projectionsByID: temporalResult.projectionsByID
            )
            return temporalProjection?.sieveDisposition != .quarantine
                && temporalProjection?.sanctumEntryID == nil
        }
        filtered.baseProjection.candidates = projection.baseProjection.candidates.filter { candidate in
            let temporalProjection = temporalResult.projectionsByID[candidate.id]
            return temporalProjection?.sieveDisposition != .quarantine
                && temporalProjection?.sanctumEntryID == nil
        }

        if !screenedOutRecords.isEmpty || !screenedOutCandidates.isEmpty {
            var governance = filtered.baseProjection.governanceSnapshot ?? .empty
            governance.screenedOutMemoryCount += screenedOutRecords.count + screenedOutCandidates.count
            governance.screenedOutPendingMemoryCount += screenedOutCandidates.filter(\.isPending).count
            governance.quarantinedObservationCount = max(
                governance.quarantinedObservationCount,
                screenedOutCandidates.filter {
                    temporalResult.projectionsByID[$0.id]?.sieveDisposition == .quarantine
                }.count
            )

            for candidate in screenedOutCandidates where candidate.provenanceRisk {
                governance.screenedOutReasonCounts[.provenanceContamination, default: 0] += 1
            }

            filtered.baseProjection.governanceSnapshot = governance
        }
        filtered.diagnostics = BASAppleMemoryProjectionDiagnostics(
            recordCount: filtered.baseProjection.records.count,
            candidateCount: filtered.baseProjection.candidates.count,
            allCandidatesPending: filtered.baseProjection.candidates.allSatisfy(\.isPending)
        )
        return filtered
    }

    private static func temporalProjection(
        for record: BASGovernedMemory,
        projectionsByID: [String: DecisionTemporalProjection]
    ) -> DecisionTemporalProjection? {
        if let projection = projectionsByID[record.id.uuidString] {
            return projection
        }

        return projectionsByID.first { projectionID, _ in
            stableProjectionUUID(for: projectionID) == record.id
        }?.value
    }

    private static func stableProjectionUUID(
        for value: String
    ) -> UUID {
        if let uuid = UUID(uuidString: value) {
            return uuid
        }

        let digest = SHA256.hash(data: Data(value.utf8))
        let bytes = Array(digest.prefix(16))
        let encoded = bytes.enumerated().map { index, byte in
            let separator: String = switch index {
            case 4, 6, 8, 10:
                "-"
            default:
                ""
            }
            return separator + String(format: "%02x", byte)
        }.joined()

        return UUID(uuidString: encoded) ?? UUID()
    }

    static func buildTemporalField(
        records: [DecisionMemoryRecord],
        candidates: [DecisionMemoryCandidateRecord],
        now: Date
    ) -> TemporalFieldBuildResult {
        let observations = (
            records.map(temporalObservation(from:))
            + candidates.map(temporalObservation(from:))
        ).sorted { lhs, rhs in
            if lhs.timestamp == rhs.timestamp {
                return lhs.id < rhs.id
            }
            return lhs.timestamp < rhs.timestamp
        }

        let fieldEligibleObservations = observations.filter {
            provenanceIsStructured($0.provenanceSummary) || shouldQuarantine($0)
        }

        let groupedByTopic = Dictionary(grouping: fieldEligibleObservations, by: \.topicKey)
        let sortedTopicKeys = groupedByTopic.keys.sorted()

        var episodeArcs: [BASMemoryEpisodeArc] = []
        var episodeArcIDsByMemoryID: [String: [String]] = [:]

        for topicKey in sortedTopicKeys {
            guard let group = groupedByTopic[topicKey]?.sorted(by: {
                if $0.timestamp == $1.timestamp {
                    return $0.id < $1.id
                }
                return $0.timestamp < $1.timestamp
            }) else {
                continue
            }

            let arcID = "arc.\(topicKey)"
            episodeArcs.append(
                BASMemoryEpisodeArc(
                    arcID: arcID,
                    title: arcTitle(for: group),
                    linkedMemoryRefs: group.map(\.id),
                    startTime: group.first?.timestamp ?? now,
                    currentState: group.count > 1 ? "tracking" : "observed",
                    escalationPattern: escalationPattern(for: group),
                    unresolvedThreads: group.filter(\.isCandidate).map(\.id),
                    stability: min(0.95, 0.42 + (Double(group.count) * 0.12) + (averageCertainty(for: group) * 0.18))
                )
            )
            for observation in group {
                episodeArcIDsByMemoryID[observation.id, default: []].append(arcID)
            }
        }

        var conflictClusters: [BASMemoryConflictCluster] = []
        var conflictClusterIDsByMemoryID: [String: [String]] = [:]

        for topicKey in sortedTopicKeys {
            guard let group = groupedByTopic[topicKey],
                  Set(group.map(\.conflictSignature)).count > 1 else {
                continue
            }

            let preferred = group.max { lhs, rhs in
                if lhs.certainty == rhs.certainty {
                    return lhs.id < rhs.id
                }
                return lhs.certainty < rhs.certainty
            }
            let clusterID = "conflict.\(topicKey)"
            conflictClusters.append(
                BASMemoryConflictCluster(
                    clusterID: clusterID,
                    memoryRefs: group.map(\.id),
                    conflictType: .interpretation,
                    severity: min(0.95, 0.4 + (Double(Set(group.map(\.conflictSignature)).count - 1) * 0.18)),
                    preferredRef: preferred?.id,
                    unresolved: true
                )
            )
            for observation in group {
                conflictClusterIDsByMemoryID[observation.id, default: []].append(clusterID)
            }
        }

        var replayFrames: [BASMemoryReplayFrame] = []
        var replayFrameIDByMemoryID: [String: String] = [:]

        for arc in episodeArcs {
            let replayID = "replay.\(arc.arcID)"
            replayFrames.append(
                BASMemoryReplayFrame(
                    replayID: replayID,
                    targetRefs: arc.linkedMemoryRefs,
                    replayScope: .arc,
                    timeline: arc.linkedMemoryRefs.map { "arc-observation:\($0)" },
                    integrityHash: replayID
                )
            )
            for ref in arc.linkedMemoryRefs where replayFrameIDByMemoryID[ref] == nil {
                replayFrameIDByMemoryID[ref] = replayID
            }
        }

        for cluster in conflictClusters {
            let replayID = "replay.\(cluster.clusterID)"
            replayFrames.append(
                BASMemoryReplayFrame(
                    replayID: replayID,
                    targetRefs: cluster.memoryRefs,
                    replayScope: .conflict,
                    timeline: cluster.memoryRefs.map { "conflict-branch:\($0)" },
                    integrityHash: replayID
                )
            )
            for ref in cluster.memoryRefs {
                replayFrameIDByMemoryID[ref] = replayID
            }
        }

        let continuityAnchor = fieldEligibleObservations.isEmpty
            ? nil
            : BASMemoryContinuityAnchor(
                anchorID: "anchor.host.active",
                hostVersionRef: "host.active",
                activeGoalRefs: fieldEligibleObservations
                    .filter { $0.memoryType == .unresolved }
                    .map(\.id),
                activeRelationRefs: fieldEligibleObservations
                    .filter { $0.memoryType == .relation }
                    .map(\.id),
                activeArcRefs: episodeArcs.map(\.arcID),
                samenessWeight: min(0.98, 0.52 + (Double(fieldEligibleObservations.count) * 0.05))
            )

        var temperatureProfiles: [BASMemoryTemperatureProfile] = []
        var provenanceSeals: [BASMemoryProvenanceSeal] = []
        var temporalRecords: [BASTemporalMemoryRecord] = []
        var quarantineRecords: [BASMemoryQuarantineRecord] = []
        var sanctumEntries: [BASMemorySanctumEntry] = []
        var forgetCascades: [BASMemoryForgetCascade] = []
        var projectionsByID: [String: DecisionTemporalProjection] = [:]

        for observation in observations {
            let quarantined = shouldQuarantine(observation)
            let structuredProvenance = provenanceIsStructured(observation.provenanceSummary)
            let canEnterField = structuredProvenance || quarantined
            let sealed = canEnterField && shouldSeal(observation)
            let profileID = canEnterField ? "temp.\(observation.id.temporalIdentifierComponent)" : nil
            let sealID = structuredProvenance ? "seal.\(observation.id.temporalIdentifierComponent)" : nil
            let quarantineID = quarantined ? "quarantine.\(observation.id.temporalIdentifierComponent)" : nil
            let sanctumID = sealed ? "sanctum.\(observation.id.temporalIdentifierComponent)" : nil
            let conflictIDs = conflictClusterIDsByMemoryID[observation.id] ?? []
            let arcIDs = episodeArcIDsByMemoryID[observation.id] ?? []
            let forgetState = forgetCascadeExecutionState(for: observation)
            let forgetCascadeID = forgetState.map { _ in
                "forget.\(observation.id.temporalIdentifierComponent)"
            }
            var replayID = replayFrameIDByMemoryID[observation.id]
            let disposition: DecisionTemporalSieveDisposition

            if quarantined {
                disposition = .quarantine
            } else if !structuredProvenance {
                disposition = .reject
            } else if !conflictIDs.isEmpty {
                disposition = .conflictCluster
            } else {
                disposition = .admitHotWarm
            }

            if let profileID {
                let band = quarantined
                    ? BASMemoryTemperatureBand.quarantine
                    : sealed
                    ? BASMemoryTemperatureBand.sealed
                    : temperatureBand(for: observation)
                temperatureProfiles.append(
                    BASMemoryTemperatureProfile(
                        profileID: profileID,
                        currentBand: band,
                        halfLifeHours: halfLifeHours(for: band),
                        promotionRules: promotionRules(for: observation, band: band),
                        decayRules: decayRules(for: observation, band: band),
                        accessRules: accessRules(for: observation, band: band),
                        lastShiftAt: now
                    )
                )
            }

            if let sealID {
                provenanceSeals.append(
                    BASMemoryProvenanceSeal(
                        sealID: sealID,
                        sourceClass: observation.sourceClass,
                        consentRef: "host.memory.default",
                        riskStateRef: quarantined ? "risk.quarantine" : "risk.standard",
                        sovereignStateRef: observation.sovereignScope,
                        creationTurnRef: "turn.\(observation.id.temporalIdentifierComponent)",
                        verificationState: verificationState(for: observation, quarantined: quarantined)
                    )
                )
            }

            if let sanctumID {
                sanctumEntries.append(
                    BASMemorySanctumEntry(
                        entryID: sanctumID,
                        memoryRef: observation.id,
                        accessPolicy: "revealed_only_by_policy",
                        revealConditions: [
                            "host_authorized_recall",
                            "l12_gentle_hand",
                            "l14_policy_override"
                        ]
                    )
                )
            }

            if let quarantineID {
                quarantineRecords.append(
                    BASMemoryQuarantineRecord(
                        quarantineID: quarantineID,
                        memoryRef: observation.id,
                        reasonCodes: quarantineReasonCodes(for: observation),
                        lineageCutRef: "cut.\(observation.id.temporalIdentifierComponent)",
                        releaseConditions: ["manual_review", "clear_provenance"]
                    )
                )
            }

            if let forgetState,
               replayID == nil {
                let generatedReplayID = "replay.forget.\(observation.id.temporalIdentifierComponent)"
                replayFrames.append(
                    BASMemoryReplayFrame(
                        replayID: generatedReplayID,
                        targetRefs: [observation.id],
                        replayScope: forgetReplayScope(for: forgetState),
                        timeline: [
                            "forget-root:\(observation.id)",
                            "execution:\(forgetState)"
                        ],
                        integrityHash: generatedReplayID
                    )
                )
                replayFrameIDByMemoryID[observation.id] = generatedReplayID
                replayID = generatedReplayID
            }

            if let forgetCascadeID,
               let forgetState {
                forgetCascades.append(
                    BASMemoryForgetCascade(
                        cascadeID: forgetCascadeID,
                        rootTargets: [observation.id],
                        dependentRefs: orderedUnique(
                            arcIDs
                                + conflictIDs
                                + [
                                    profileID,
                                    sealID,
                                    sanctumID,
                                    replayID
                                ].compactMap { $0 }
                        ),
                        cacheRefs: [observation.isCandidate ? "projection.candidates" : "projection.records"],
                        foldRefs: ["fold.\(observation.topicKey)"],
                        syncRefs: orderedUnique(["swiftdata.memory", observation.hostScope]),
                        executionState: forgetState
                    )
                )
            }

            if canEnterField {
                temporalRecords.append(
                    BASTemporalMemoryRecord(
                        memoryID: observation.id,
                        summary: observation.summary,
                        memoryType: observation.memoryType,
                        sourceClass: observation.sourceClass,
                        sourceRefs: [observation.id],
                        timestamp: observation.timestamp,
                        certainty: observation.certainty,
                        evidenceStrength: observation.evidenceStrength,
                        emotionalWeight: observation.emotionalWeight,
                        hostScope: observation.hostScope,
                        sovereignScope: observation.sovereignScope,
                        sanctumFlag: sealed,
                        quarantineFlag: quarantined,
                        lineageRefs: [observation.id],
                        temperatureProfileRef: profileID,
                        provenanceSealRef: sealID
                    )
                )
            }

            projectionsByID[observation.id] = DecisionTemporalProjection(
                temporalMemoryID: canEnterField ? observation.id : nil,
                sieveDisposition: disposition,
                temperatureProfileID: profileID,
                provenanceSealID: sealID,
                sanctumEntryID: sanctumID,
                episodeArcIDs: arcIDs,
                conflictClusterIDs: conflictIDs,
                continuityAnchorID: canEnterField ? continuityAnchor?.anchorID : nil,
                replayFrameID: replayID,
                quarantineRecordID: quarantineID,
                forgetCascadeIDs: forgetCascadeID.map { [$0] } ?? []
            )
        }

        return TemporalFieldBuildResult(
            field: BASTemporalMemoryField(
                records: temporalRecords,
                temperatureProfiles: temperatureProfiles.sorted { $0.profileID < $1.profileID },
                provenanceSeals: provenanceSeals.sorted { $0.sealID < $1.sealID },
                episodeArcs: episodeArcs.sorted { $0.arcID < $1.arcID },
                conflictClusters: conflictClusters.sorted { $0.clusterID < $1.clusterID },
                continuityAnchors: continuityAnchor.map { [$0] } ?? [],
                replayFrames: replayFrames.sorted { $0.replayID < $1.replayID },
                quarantineRecords: quarantineRecords.sorted { $0.quarantineID < $1.quarantineID },
                sanctumEntries: sanctumEntries.sorted { $0.entryID < $1.entryID },
                forgetCascades: forgetCascades.sorted { $0.cascadeID < $1.cascadeID }
            ),
            projectionsByID: projectionsByID
        )
    }

    static func applyTemporalProjections(
        _ projectionsByID: [String: DecisionTemporalProjection],
        to records: [DecisionMemoryRecord],
        candidates: [DecisionMemoryCandidateRecord],
        in context: ModelContext
    ) {
        var didMutate = false

        for record in records {
            let projection = projectionsByID[record.id]
            if record.temporalProjection != projection {
                record.temporalProjection = projection
                didMutate = true
            }
        }

        for candidate in candidates {
            let projection = projectionsByID[candidate.id]
            if candidate.temporalProjection != projection {
                candidate.temporalProjection = projection
                didMutate = true
            }
        }

        guard didMutate else { return }

        do {
            try context.save()
        } catch {
            PersistenceIssueRecorder.record(
                error: error,
                operation: "writing temporal memory field projections"
            )
        }
    }

    static func temporalObservation(from record: DecisionMemoryRecord) -> TemporalObservation {
        TemporalObservation(
            id: record.id,
            topic: record.topic,
            headline: record.headline,
            value: record.value,
            sourceClass: record.sourceRaw,
            timestamp: record.lastConfirmedAt,
            certainty: record.confidence,
            evidenceStrength: min(1, Double(max(record.evidenceCount, record.observationCount)) / 4),
            emotionalWeight: min(1, (record.priority * 0.55) + (record.confidence * 0.2)),
            retrievalTags: record.retrievalTags,
            provenanceSummary: record.provenanceSummary,
            tier: record.tier,
            hostScope: "host.active",
            sovereignScope: record.tier == .cold ? "reviewed_long_term" : "standard",
            memoryType: temporalMemoryType(for: record.type),
            isCandidate: false,
            lifecycleState: record.lifecycleState,
            lastWriteOperation: nil,
            lastGovernanceDecision: nil
        )
    }

    static func temporalObservation(from candidate: DecisionMemoryCandidateRecord) -> TemporalObservation {
        TemporalObservation(
            id: candidate.id,
            topic: candidate.topic,
            headline: candidate.headline,
            value: candidate.value,
            sourceClass: candidate.sourceRaw,
            timestamp: candidate.lastObservedAt,
            certainty: candidate.confidence,
            evidenceStrength: min(1, Double(max(candidate.evidenceCount, candidate.confirmationCount)) / 4),
            emotionalWeight: min(1, (candidate.priority * 0.6) + (candidate.confidence * 0.18)),
            retrievalTags: candidate.retrievalTags,
            provenanceSummary: candidate.provenanceSummary,
            tier: candidate.tier,
            hostScope: "host.candidate",
            sovereignScope: candidate.tier == .cold ? "pending_review" : "standard",
            memoryType: temporalMemoryType(for: candidate.type),
            isCandidate: true,
            lifecycleState: nil,
            lastWriteOperation: candidate.lastWriteOperation,
            lastGovernanceDecision: candidate.lastGovernanceDecision
        )
    }

    static func temporalMemoryType(for type: DecisionMemoryType) -> BASTemporalMemoryType {
        switch type {
        case .identity:
            .relation
        case .preference:
            .routine
        case .goal:
            .unresolved
        case .situational:
            .episode
        case .semantic:
            .warning
        case .support:
            .temporary
        }
    }

    static func averageCertainty(for observations: [TemporalObservation]) -> Double {
        guard !observations.isEmpty else { return 0 }
        let total = observations.reduce(0) { partial, observation in
            partial + observation.certainty
        }
        return total / Double(observations.count)
    }

    static func arcTitle(for observations: [TemporalObservation]) -> String {
        guard let first = observations.first else {
            return "Temporal arc"
        }
        return "\(first.topic.replacingOccurrences(of: "_", with: " ").capitalized) arc"
    }

    static func escalationPattern(for observations: [TemporalObservation]) -> String {
        let tags = observations.flatMap(\.retrievalTags).map { $0.lowercased() }
        if tags.contains("repeat") {
            return "repeat-tracking"
        }
        if tags.contains("boundary") {
            return "boundary-guard"
        }
        if tags.contains("buy") {
            return "recurring-buy-pressure"
        }
        return observations.count > 1 ? "multi-turn" : "single-turn"
    }

    static func provenanceIsStructured(_ provenanceSummary: String) -> Bool {
        !provenanceSummary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    static func shouldQuarantine(_ observation: TemporalObservation) -> Bool {
        let tags = Set(observation.retrievalTags.map { $0.lowercased() })
        let normalizedProvenance = observation.provenanceSummary.lowercased()
        return tags.contains("quarantined")
            || tags.contains("tool_observation")
            || tags.contains("contaminated")
            || normalizedProvenance.contains("contaminated")
            || normalizedProvenance.contains("quarantined")
            || normalizedProvenance.contains("tool observation")
            || normalizedProvenance.contains("<script")
            || normalizedProvenance.contains("unsafe-tool")
            || normalizedProvenance.contains("prompt injection")
    }

    static func shouldSeal(_ observation: TemporalObservation) -> Bool {
        guard !shouldQuarantine(observation) else {
            return false
        }

        let tags = Set(observation.retrievalTags.map { $0.lowercased() })
        let normalizedProvenance = observation.provenanceSummary.lowercased()
        let sealSignals = [
            "sealed",
            "sensitive",
            "private",
            "high_sensitivity",
            "vault_only",
            "frozen"
        ]
        let provenanceSignals = [
            "sealed",
            "sensitive",
            "private",
            "vault-only",
            "frozen"
        ]

        return sealSignals.contains(where: tags.contains)
            || provenanceSignals.contains(where: normalizedProvenance.contains)
    }

    static func quarantineReasonCodes(for observation: TemporalObservation) -> [String] {
        var codes: [String] = []
        let tags = Set(observation.retrievalTags.map { $0.lowercased() })
        if tags.contains("tool_observation") {
            codes.append("tool_observation")
        }
        if tags.contains("quarantined") || observation.provenanceSummary.lowercased().contains("quarantined") {
            codes.append("quarantined")
        }
        if observation.provenanceSummary.lowercased().contains("contaminated")
            || observation.provenanceSummary.lowercased().contains("<script")
            || observation.provenanceSummary.lowercased().contains("prompt injection") {
            codes.append("provenance_contamination")
        }
        return codes.isEmpty ? ["manual_review"] : codes
    }

    static func verificationState(
        for observation: TemporalObservation,
        quarantined: Bool
    ) -> BASMemoryVerificationState {
        if quarantined {
            return .conflicted
        }
        if observation.evidenceStrength >= 0.66 {
            return .verified
        }
        return .pending
    }

    static func forgetCascadeExecutionState(for observation: TemporalObservation) -> String? {
        let tags = Set(observation.retrievalTags.map { $0.lowercased() })
        let normalizedProvenance = observation.provenanceSummary.lowercased()

        if observation.lastWriteOperation == .delete {
            return "delete_requested"
        }
        if observation.lastGovernanceDecision == .reject {
            return "rejected_candidate"
        }
        if tags.contains("rollback") || normalizedProvenance.contains("rollback") {
            return "rollback_pending"
        }
        if tags.contains("deleted")
            || tags.contains("delete")
            || normalizedProvenance.contains("deleted")
            || normalizedProvenance.contains("delete") {
            return "delete_pending"
        }
        if tags.contains("not_me")
            || tags.contains("not me")
            || normalizedProvenance.contains("not_me")
            || normalizedProvenance.contains("not me") {
            return "host_revoked"
        }
        if tags.contains("frozen") || normalizedProvenance.contains("frozen") {
            return "freeze_pending"
        }
        if observation.lifecycleState == .retired {
            return "retired"
        }
        return nil
    }

    static func forgetReplayScope(for executionState: String) -> BASMemoryReplayScope {
        if executionState == "rollback_pending" {
            return .rollback
        }
        return .deletion
    }

    static func temperatureBand(for observation: TemporalObservation) -> BASMemoryTemperatureBand {
        switch observation.tier {
        case .hot:
            .hot
        case .warm:
            .warm
        case .cold:
            observation.isCandidate ? .warm : .cold
        case .volatile:
            .hot
        }
    }

    static func halfLifeHours(for band: BASMemoryTemperatureBand) -> Double {
        switch band {
        case .hot:
            24
        case .warm:
            72
        case .cold:
            720
        case .sealed:
            1440
        case .quarantine:
            240
        }
    }

    static func promotionRules(
        for observation: TemporalObservation,
        band: BASMemoryTemperatureBand
    ) -> [String] {
        var rules = ["require_provenance_seal"]
        if band == .cold {
            rules.append("review_gated_cold_only")
        }
        if observation.isCandidate {
            rules.append("candidate_repetition_gate")
        }
        return rules
    }

    static func decayRules(
        for observation: TemporalObservation,
        band: BASMemoryTemperatureBand
    ) -> [String] {
        switch band {
        case .hot:
            return ["rapid_decay"]
        case .warm:
            return ["stage_decay"]
        case .cold:
            return ["long_tail_decay"]
        case .sealed:
            return ["frozen_until_revealed"]
        case .quarantine:
            return observation.isCandidate ? ["blocked_until_review"] : ["blocked_until_clear"]
        }
    }

    static func accessRules(
        for observation: TemporalObservation,
        band: BASMemoryTemperatureBand
    ) -> [String] {
        switch band {
        case .quarantine:
            ["blocked_from_normal_retrieval"]
        case .sealed:
            ["revealed_only_by_policy"]
        case .cold:
            ["stable_recall", "reviewed_long_term"]
        case .hot, .warm:
            ["default_recall"]
        }
    }
}

private extension String {
    var temporalIdentifierComponent: String {
        let mapped = unicodeScalars.map { scalar -> String in
            CharacterSet.alphanumerics.contains(scalar)
                ? String(Character(scalar))
                : "."
        }.joined()
        let collapsed = mapped
            .replacingOccurrences(of: "\\.+", with: ".", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "."))
        return collapsed.isEmpty ? "memory" : collapsed.lowercased()
    }
}
