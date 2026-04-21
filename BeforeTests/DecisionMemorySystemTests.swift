import XCTest
import SwiftData
import BASAppleAdapters
import BASMemory
import BASRuntimeCore
@testable import Before

final class DecisionMemorySystemTests: XCTestCase {
    @MainActor
    func testRefreshStoredMemoriesDerivesStructuredRecordsFromHistory() throws {
        let container = try makeContainer()
        let context = container.mainContext

        seedHistory(into: context)

        let memories = DecisionMemorySystem.refreshStoredMemories(in: context)

        XCTAssertTrue(memories.contains(where: { $0.id == "preference.communication.concise" }))
        XCTAssertTrue(memories.contains(where: { $0.id == "semantic.scenario.buy" }))
        XCTAssertTrue(memories.contains(where: { $0.id == "support.action.decideTomorrow" }))
        XCTAssertTrue(memories.contains(where: { $0.type == .goal }))
    }

    @MainActor
    func testRefreshStoredMemoriesStagesSituationalCandidatesWithoutPromotingThem() throws {
        let container = try makeContainer()
        let context = container.mainContext

        seedHistory(into: context)

        _ = DecisionMemorySystem.refreshStoredMemories(in: context)
        let candidates = try context.fetch(FetchDescriptor<DecisionMemoryCandidateRecord>())

        let quickCandidate = try XCTUnwrap(candidates.first(where: { $0.id == "situational.quick.latest" }))
        XCTAssertEqual(quickCandidate.status, .pending)
        XCTAssertEqual(quickCandidate.lastWriteOperation, .noop)
        XCTAssertFalse(
            DecisionMemorySystem.fetchMemoryRecords(in: context)
                .contains(where: { $0.id == "situational.quick.latest" })
        )
    }

    @MainActor
    func testRefreshStoredMemoriesUsesExplicitMemoryWriteOperations() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let stableNow = date("2026-04-09T23:10:00Z")

        seedHistory(into: context)

        _ = DecisionMemorySystem.refreshStoredMemories(in: context, now: stableNow)
        var candidates = try context.fetch(FetchDescriptor<DecisionMemoryCandidateRecord>())

        let supportCandidate = try XCTUnwrap(candidates.first(where: { $0.id == "support.action.decideTomorrow" }))
        XCTAssertEqual(supportCandidate.status, .promoted)
        XCTAssertEqual(supportCandidate.lastWriteOperation, .add)

        _ = DecisionMemorySystem.refreshStoredMemories(in: context, now: stableNow)
        candidates = try context.fetch(FetchDescriptor<DecisionMemoryCandidateRecord>())

        let unchangedSupportCandidate = try XCTUnwrap(candidates.first(where: { $0.id == "support.action.decideTomorrow" }))
        XCTAssertEqual(unchangedSupportCandidate.lastWriteOperation, .noop)
        XCTAssertEqual(unchangedSupportCandidate.confirmationCount, 1)
    }

    @MainActor
    func testRefreshStoredMemoriesStagesStableNonGoalDraftsWhenExecutionFrameRequiresExternalRefresh() throws {
        let container = try makeContainer()
        let context = container.mainContext

        seedHistory(into: context)

        let volatileFrame = DecisionEBrainExecutionCapabilityFrame(
            activeProvider: .openModel,
            preferredProvider: .openModel,
            fallbackProvider: .template,
            providerTrack: .builtInOpenModel,
            executionTier: .balancedGemma,
            foundationTier: .openModelHeuristic,
            reasonCodes: []
        )

        let memories = DecisionMemorySystem.refreshStoredMemories(
            in: context,
            executionCapabilityFrame: volatileFrame,
            now: date("2026-04-09T23:10:00Z")
        )
        let candidates = try context.fetch(FetchDescriptor<DecisionMemoryCandidateRecord>())

        XCTAssertTrue(memories.contains(where: { $0.type == .goal }))
        XCTAssertFalse(memories.contains(where: { $0.id == "semantic.scenario.buy" }))

        let semanticCandidate = try XCTUnwrap(candidates.first(where: { $0.id == "semantic.scenario.buy" }))
        XCTAssertEqual(semanticCandidate.status, .pending)
        XCTAssertEqual(semanticCandidate.lastGovernanceDecision, .deferred)
        XCTAssertEqual(semanticCandidate.decayPolicy, .fast)
        XCTAssertEqual(semanticCandidate.tierRaw, "volatile")
        XCTAssertTrue(semanticCandidate.retrievalTags.contains("external_refresh"))
        XCTAssertTrue(semanticCandidate.retrievalTags.contains("volatile"))
    }

    func testHorizonAwareMemoryPersistencePolicyRequiresCorroborationWhenExecutionFrameRequiresCaveat() {
        let supportedFrame = DecisionEBrainExecutionCapabilityFrame(
            activeProvider: .openModel,
            preferredProvider: .openModel,
            fallbackProvider: .template,
            providerTrack: .builtInOpenModel,
            executionTier: .balancedGemma,
            foundationTier: .openModelDedicated,
            reasonCodes: []
        )

        let policy = BeforeProductCompatibility.horizonAwareMemoryPersistencePolicy(
            for: supportedFrame
        )

        XCTAssertEqual(policy.minimumDurableEvidenceCount, 2)
        XCTAssertTrue(policy.evidencePendingRetrievalTags.contains("evidence_caveat"))
        XCTAssertEqual(policy.volatileClaimWriteMode, .admitDirectly)
    }

    @MainActor
    func testRefreshProjectionCarriesDurableRecordsIntoGovernedProjection() throws {
        let container = try makeContainer()
        let context = container.mainContext

        seedHistory(into: context)

        _ = DecisionMemorySystem.refreshStoredMemories(
            in: context,
            now: date("2026-04-09T23:10:00Z")
        )
        let projection = DecisionMemorySystem.refreshProjection(
            in: context,
            now: date("2026-04-09T23:10:00Z")
        )

        let record = try XCTUnwrap(
            DecisionMemorySystem.fetchMemoryRecords(in: context).first(where: { $0.id == "semantic.scenario.buy" })
        )
        let projectedRecord = try XCTUnwrap(
            projection.baseProjection.records.first(where: { $0.content == record.headline })
        )

        XCTAssertEqual(projectedRecord.kind, .semantic)
        XCTAssertEqual(projectedRecord.tier, .warm)
        XCTAssertEqual(projectedRecord.governanceStatus, .governed)
        XCTAssertEqual(projectedRecord.provenanceSummary, record.provenanceSummary)
        XCTAssertEqual(
            projection.governanceSnapshot.totalRecordCount,
            DecisionMemorySystem.fetchMemoryRecords(in: context).count
        )
        XCTAssertGreaterThanOrEqual(projection.governanceSnapshot.pendingCandidateCount, 1)
    }

    @MainActor
    func testRefreshProjectionMarksQuarantinedCandidatesWithGovernanceAndQuarantineSignals() throws {
        let container = try makeContainer()
        let context = container.mainContext

        context.insert(
            DecisionMemoryCandidateRecord(
                id: "candidate.contaminated.tool",
                type: .semantic,
                topic: "tool_observation",
                headline: "Tool said the host definitely wants this.",
                value: "unsafe-tool-observation",
                confidence: 0.93,
                priority: 0.90,
                source: .pattern,
                firstObservedAt: date("2026-04-09T10:00:00Z"),
                lastObservedAt: date("2026-04-09T10:05:00Z"),
                decayPolicy: .slow,
                retrievalTags: ["quarantined", "tool_observation", "buy"],
                evidenceCount: 1,
                confirmationCount: 1,
                lastObservationFingerprint: "tool.fp.1",
                status: .pending,
                provenanceSummary: "Contaminated tool observation captured during a quarantined pass.",
                lastWriteOperation: .add,
                lastGovernanceDecision: .deferred,
                governanceReason: "await_review",
                tier: .cold
            )
        )

        let projection = DecisionMemorySystem.refreshProjection(
            in: context,
            now: date("2026-04-09T23:10:00Z")
        )
        let contaminatedCandidate = try XCTUnwrap(
            DecisionMemorySystem.fetchCandidateRecords(in: context).first(where: { $0.id == "candidate.contaminated.tool" })
        )
        let governanceSnapshot = try XCTUnwrap(projection.baseProjection.governanceSnapshot)

        XCTAssertEqual(contaminatedCandidate.lastGovernanceDecision, .deferred)
        XCTAssertTrue(contaminatedCandidate.retrievalTags.contains("quarantined"))
        XCTAssertTrue(contaminatedCandidate.retrievalTags.contains("tool_observation"))
        XCTAssertFalse(projection.baseProjection.candidates.contains(where: { $0.id == "candidate.contaminated.tool" }))
        XCTAssertEqual(governanceSnapshot.screenedOutMemoryCount, 1)
        XCTAssertEqual(governanceSnapshot.screenedOutPendingMemoryCount, 1)
        XCTAssertEqual(governanceSnapshot.quarantinedObservationCount, 1)
        XCTAssertEqual(projection.governanceSnapshot.quarantinedObservationCount, 1)
    }

    @MainActor
    func testRefreshProjectionKeepsRepeatedTopicRecordAndCandidateVisibleInCurrentProjection() throws {
        let container = try makeContainer()
        let context = container.mainContext

        context.insert(
            DecisionMemoryRecord(
                id: "record.boundary.1",
                type: .semantic,
                topic: "boundary_topic",
                headline: "Protect the boundary first.",
                value: "protect_first",
                confidence: 0.82,
                priority: 0.74,
                source: .history,
                lastConfirmedAt: date("2026-04-09T09:00:00Z"),
                decayPolicy: .slow,
                retrievalTags: ["boundary", "repeat"],
                evidenceCount: 3,
                observationCount: 2,
                provenanceSummary: "Confirmed from repeated quick-loop history.",
                lifecycleState: .active,
                tier: .warm
            )
        )
        context.insert(
            DecisionMemoryCandidateRecord(
                id: "candidate.boundary.2",
                type: .semantic,
                topic: "boundary_topic",
                headline: "Protect the boundary after a pause.",
                value: "protect_after_pause",
                confidence: 0.77,
                priority: 0.73,
                source: .reflection,
                firstObservedAt: date("2026-04-09T10:00:00Z"),
                lastObservedAt: date("2026-04-09T10:05:00Z"),
                decayPolicy: .medium,
                retrievalTags: ["boundary", "repeat"],
                evidenceCount: 2,
                confirmationCount: 2,
                lastObservationFingerprint: "boundary.fp.2",
                status: .pending,
                provenanceSummary: "Reflected from repeated boundary rehearsal.",
                lastWriteOperation: .add,
                lastGovernanceDecision: .deferred,
                governanceReason: "pending_review",
                tier: .warm
            )
        )

        let projection = DecisionMemorySystem.refreshProjection(
            in: context,
            now: date("2026-04-09T23:10:00Z")
        )
        let projectedRecord = try XCTUnwrap(
            projection.baseProjection.records.first(where: { $0.content == "Protect the boundary first." })
        )
        let projectedCandidate = try XCTUnwrap(
            projection.baseProjection.candidates.first(where: { $0.id == "candidate.boundary.2" })
        )

        XCTAssertEqual(projectedRecord.kind, .semantic)
        XCTAssertEqual(projectedCandidate.headline, "Protect the boundary after a pause.")
        XCTAssertEqual(projectedCandidate.source, .reflection)
        XCTAssertEqual(projection.governanceSnapshot.totalRecordCount, 1)
        XCTAssertEqual(projection.governanceSnapshot.totalCandidateCount, 1)
        XCTAssertEqual(projection.governanceSnapshot.pendingCandidateCount, 1)
        XCTAssertEqual(projection.governanceSnapshot.deferredCandidateCount, 1)
    }

    @MainActor
    func testRefreshStoredMemoriesProjectsTemporalFieldAndSealMetadataIntoLegacyRecords() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let stableNow = date("2026-04-09T23:10:00Z")

        seedHistory(into: context)

        _ = DecisionMemorySystem.refreshStoredMemories(
            in: context,
            now: stableNow
        )
        let field = DecisionMemorySystem.temporalField(
            in: context,
            now: stableNow
        )

        let semanticRecord = try XCTUnwrap(
            DecisionMemorySystem.fetchMemoryRecords(in: context).first(where: { $0.id == "semantic.scenario.buy" })
        )
        let semanticProjection = try XCTUnwrap(semanticRecord.temporalProjection)

        XCTAssertEqual(semanticProjection.temporalMemoryID, semanticRecord.id)
        XCTAssertNotNil(semanticProjection.temperatureProfileID)
        XCTAssertNotNil(semanticProjection.provenanceSealID)
        XCTAssertNotNil(semanticProjection.continuityAnchorID)
        XCTAssertNotEqual(semanticProjection.sieveDisposition, .reject)
        XCTAssertNotEqual(semanticProjection.sieveDisposition, .quarantine)
        XCTAssertTrue(
            field.records.contains(where: {
                $0.memoryID == semanticRecord.id &&
                    $0.temperatureProfileRef == semanticProjection.temperatureProfileID &&
                    $0.provenanceSealRef == semanticProjection.provenanceSealID
            })
        )
        XCTAssertTrue(
            field.provenanceSeals.contains(where: { $0.sealID == semanticProjection.provenanceSealID })
        )
        XCTAssertTrue(
            field.temperatureProfiles.contains(where: { $0.profileID == semanticProjection.temperatureProfileID })
        )

        let supportCandidate = try XCTUnwrap(
            try context.fetch(FetchDescriptor<DecisionMemoryCandidateRecord>())
                .first(where: { $0.id == "support.action.decideTomorrow" })
        )
        let supportProjection = try XCTUnwrap(supportCandidate.temporalProjection)

        XCTAssertEqual(supportProjection.temporalMemoryID, supportCandidate.id)
        XCTAssertNotNil(supportProjection.temperatureProfileID)
        XCTAssertNotNil(supportProjection.provenanceSealID)
        XCTAssertNotNil(supportProjection.continuityAnchorID)
    }

    @MainActor
    func testRefreshProjectionQuarantinesContaminatedCandidatesAndBlocksThemFromNormalRetrieval() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let stableNow = date("2026-04-09T23:10:00Z")

        context.insert(
            DecisionMemoryCandidateRecord(
                id: "candidate.contaminated.tool",
                type: .semantic,
                topic: "tool_observation",
                headline: "Tool said the host definitely wants this.",
                value: "unsafe-tool-observation",
                confidence: 0.93,
                priority: 0.90,
                source: .pattern,
                firstObservedAt: date("2026-04-09T10:00:00Z"),
                lastObservedAt: date("2026-04-09T10:05:00Z"),
                decayPolicy: .slow,
                retrievalTags: ["quarantined", "tool_observation", "buy"],
                evidenceCount: 1,
                confirmationCount: 1,
                lastObservationFingerprint: "tool.fp.1",
                status: .pending,
                provenanceSummary: "Contaminated tool observation captured during a quarantined pass.",
                lastWriteOperation: .add,
                lastGovernanceDecision: .deferred,
                governanceReason: "await_review",
                tier: .cold
            )
        )

        let projection = DecisionMemorySystem.refreshProjection(
            in: context,
            now: stableNow
        )
        let field = DecisionMemorySystem.temporalField(
            in: context,
            now: stableNow
        )
        let contaminatedCandidate = try XCTUnwrap(
            try context.fetch(FetchDescriptor<DecisionMemoryCandidateRecord>())
                .first(where: { $0.id == "candidate.contaminated.tool" })
        )
        let temporalProjection = try XCTUnwrap(contaminatedCandidate.temporalProjection)
        let governanceSnapshot = try XCTUnwrap(projection.baseProjection.governanceSnapshot)
        let quarantineRecord = try XCTUnwrap(
            field.quarantineRecords.first(where: { $0.quarantineID == temporalProjection.quarantineRecordID })
        )
        let temperatureProfile = try XCTUnwrap(
            field.temperatureProfiles.first(where: { $0.profileID == temporalProjection.temperatureProfileID })
        )

        XCTAssertEqual(temporalProjection.sieveDisposition, .quarantine)
        XCTAssertNotNil(temporalProjection.quarantineRecordID)
        XCTAssertFalse(projection.baseProjection.candidates.contains(where: { $0.id == contaminatedCandidate.id }))
        XCTAssertEqual(quarantineRecord.memoryRef, contaminatedCandidate.id)
        XCTAssertEqual(temperatureProfile.currentBand, .quarantine)
        XCTAssertTrue(temperatureProfile.accessRules.contains("blocked_from_normal_retrieval"))
        XCTAssertEqual(governanceSnapshot.screenedOutMemoryCount, 1)
        XCTAssertEqual(governanceSnapshot.screenedOutPendingMemoryCount, 1)
        XCTAssertEqual(governanceSnapshot.quarantinedObservationCount, 1)
    }

    @MainActor
    func testTemporalFieldBuildsEpisodeArcConflictClusterAndReplayFrameForRepeatedTopic() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let stableNow = date("2026-04-09T23:10:00Z")

        context.insert(
            DecisionMemoryRecord(
                id: "record.boundary.seed",
                type: .semantic,
                topic: "boundary_topic",
                headline: "Protect the boundary first.",
                value: "protect_first",
                confidence: 0.82,
                priority: 0.74,
                source: .history,
                lastConfirmedAt: date("2026-04-09T09:00:00Z"),
                decayPolicy: .slow,
                retrievalTags: ["boundary", "repeat"],
                evidenceCount: 3,
                observationCount: 2,
                provenanceSummary: "Confirmed from repeated quick-loop history.",
                lifecycleState: .active,
                tier: .warm
            )
        )
        context.insert(
            DecisionMemoryCandidateRecord(
                id: "candidate.boundary.seed",
                type: .semantic,
                topic: "boundary_topic",
                headline: "Protect the boundary after a pause.",
                value: "protect_after_pause",
                confidence: 0.77,
                priority: 0.73,
                source: .reflection,
                firstObservedAt: date("2026-04-09T10:00:00Z"),
                lastObservedAt: date("2026-04-09T10:05:00Z"),
                decayPolicy: .medium,
                retrievalTags: ["boundary", "repeat"],
                evidenceCount: 2,
                confirmationCount: 2,
                lastObservationFingerprint: "boundary.fp.2",
                status: .pending,
                provenanceSummary: "Reflected from repeated boundary rehearsal.",
                lastWriteOperation: .add,
                lastGovernanceDecision: .deferred,
                governanceReason: "pending_review",
                tier: .warm
            )
        )
        try context.save()

        let field = DecisionMemorySystem.temporalField(
            in: context,
            now: stableNow
        )
        let result = DecisionMemorySystem.reconcileTemporalFieldStage(
            in: context,
            now: stableNow
        )

        let arc = try XCTUnwrap(
            field.episodeArcs.first(where: { $0.arcID == "arc.boundary.topic" })
        )
        let conflictCluster = try XCTUnwrap(
            field.conflictClusters.first(where: { $0.clusterID == "conflict.boundary.topic" })
        )
        let continuityAnchor = try XCTUnwrap(field.continuityAnchors.first)
        let record = try XCTUnwrap(
            DecisionMemorySystem.fetchMemoryRecords(in: context).first(where: { $0.id == "record.boundary.seed" })
        )
        let candidate = try XCTUnwrap(
            try context.fetch(FetchDescriptor<DecisionMemoryCandidateRecord>())
                .first(where: { $0.id == "candidate.boundary.seed" })
        )

        XCTAssertEqual(Set(arc.linkedMemoryRefs), Set(["record.boundary.seed", "candidate.boundary.seed"]))
        XCTAssertEqual(arc.currentState, "tracking")
        XCTAssertEqual(arc.escalationPattern, "repeat-tracking")
        XCTAssertEqual(Set(conflictCluster.memoryRefs), Set(["record.boundary.seed", "candidate.boundary.seed"]))
        XCTAssertTrue(conflictCluster.unresolved)
        XCTAssertTrue(continuityAnchor.activeArcRefs.contains(arc.arcID))
        XCTAssertTrue(
            field.replayFrames.contains(where: {
                $0.replayScope == .arc &&
                    Set($0.targetRefs) == Set(["record.boundary.seed", "candidate.boundary.seed"])
            })
        )
        XCTAssertTrue(
            field.replayFrames.contains(where: {
                $0.replayScope == .conflict &&
                    Set($0.targetRefs) == Set(["record.boundary.seed", "candidate.boundary.seed"])
            })
        )
        XCTAssertEqual(record.temporalProjection?.episodeArcIDs, [arc.arcID])
        XCTAssertEqual(record.temporalProjection?.conflictClusterIDs, [conflictCluster.clusterID])
        XCTAssertEqual(candidate.temporalProjection?.episodeArcIDs, [arc.arcID])
        XCTAssertEqual(candidate.temporalProjection?.conflictClusterIDs, [conflictCluster.clusterID])
        XCTAssertEqual(result.field.episodeArcs.count, 1)
        XCTAssertEqual(result.field.conflictClusters.count, 1)
    }

    @MainActor
    func testTemporalFieldBuildsSanctumEntriesAndForgetCascadesForSensitiveAndRevokedMemories() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let stableNow = date("2026-04-09T23:10:00Z")

        context.insert(
            DecisionMemoryRecord(
                id: "record.private.boundary",
                type: .semantic,
                topic: "private_boundary",
                headline: "Keep this boundary private.",
                value: "private_boundary",
                confidence: 0.88,
                priority: 0.72,
                source: .history,
                lastConfirmedAt: date("2026-04-09T08:00:00Z"),
                decayPolicy: .slow,
                retrievalTags: ["sealed", "sensitive", "private"],
                evidenceCount: 3,
                observationCount: 2,
                provenanceSummary: "Sensitive host-only boundary confirmed from direct history.",
                lifecycleState: .active,
                tier: .warm
            )
        )
        context.insert(
            DecisionMemoryCandidateRecord(
                id: "candidate.rollback.boundary",
                type: .support,
                topic: "private_boundary",
                headline: "Withdraw the stale boundary draft.",
                value: "withdraw_boundary_draft",
                confidence: 0.67,
                priority: 0.58,
                source: .reflection,
                firstObservedAt: date("2026-04-09T09:00:00Z"),
                lastObservedAt: date("2026-04-09T09:05:00Z"),
                decayPolicy: .medium,
                retrievalTags: ["rollback", "deleted"],
                evidenceCount: 1,
                confirmationCount: 1,
                lastObservationFingerprint: "rollback.fp.1",
                status: .pending,
                provenanceSummary: "Structured rollback request for a stale draft.",
                lastWriteOperation: .delete,
                lastGovernanceDecision: .deferred,
                governanceReason: "withdraw_pending",
                tier: .warm
            )
        )
        try context.save()

        let projection = DecisionMemorySystem.refreshProjection(
            in: context,
            now: stableNow
        )
        let field = DecisionMemorySystem.temporalField(
            in: context,
            now: stableNow
        )

        let sealedRecord = try XCTUnwrap(
            DecisionMemorySystem.fetchMemoryRecords(in: context).first(where: { $0.id == "record.private.boundary" })
        )
        let sealedProjection = try XCTUnwrap(sealedRecord.temporalProjection)
        let forgetCandidate = try XCTUnwrap(
            try context.fetch(FetchDescriptor<DecisionMemoryCandidateRecord>())
                .first(where: { $0.id == "candidate.rollback.boundary" })
        )
        let forgetProjection = try XCTUnwrap(forgetCandidate.temporalProjection)
        let sealedProfile = try XCTUnwrap(
            field.temperatureProfiles.first(where: { $0.profileID == sealedProjection.temperatureProfileID })
        )
        let sanctumEntry = try XCTUnwrap(
            field.sanctumEntries.first(where: { $0.entryID == sealedProjection.sanctumEntryID })
        )
        let forgetCascade = try XCTUnwrap(
            field.forgetCascades.first(where: { $0.cascadeID == forgetProjection.forgetCascadeIDs.first })
        )

        XCTAssertEqual(field.sanctumEntries.count, 1)
        XCTAssertEqual(field.forgetCascades.count, 1)
        XCTAssertEqual(sealedProfile.currentBand, .sealed)
        XCTAssertEqual(sanctumEntry.memoryRef, sealedRecord.id)
        XCTAssertNotNil(sealedProjection.sanctumEntryID)
        XCTAssertEqual(sealedProjection.sanctumAccessPolicy, "revealed_only_by_policy")
        XCTAssertTrue(sealedProjection.sanctumRevealConditions.contains("host_authorized_recall"))
        XCTAssertNil(sealedProjection.sanctumFrozenUntil)
        XCTAssertEqual(sanctumEntry.accessPolicy, "revealed_only_by_policy")
        XCTAssertTrue(sanctumEntry.revealConditions.contains("host_authorized_recall"))
        XCTAssertNil(sanctumEntry.frozenUntil)
        XCTAssertFalse(
            projection.baseProjection.records.contains(where: { $0.content == "Keep this boundary private." })
        )

        XCTAssertEqual(forgetCascade.rootTargets, [forgetCandidate.id])
        XCTAssertEqual(forgetCascade.executionState, "delete_requested")
        XCTAssertFalse(forgetProjection.forgetCascadeIDs.isEmpty)
        XCTAssertEqual(forgetProjection.forgetExecutionState, "delete_requested")
        XCTAssertTrue(forgetProjection.normalRetrievalBlocked)
        XCTAssertFalse(
            projection.baseProjection.candidates.contains(where: { $0.id == forgetCandidate.id })
        )
    }

    @MainActor
    func testRefreshProjectionAllowsAuthorizedRevealForSealedMemory() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let stableNow = date("2026-04-10T03:00:00Z")

        context.insert(
            DecisionMemoryRecord(
                id: "record.sealed.reveal",
                type: .semantic,
                topic: "sealed_reveal_topic",
                headline: "Keep this sanctum memory available only by policy.",
                value: "revealed_only_by_policy",
                confidence: 0.83,
                priority: 0.69,
                source: .history,
                lastConfirmedAt: date("2026-04-09T22:00:00Z"),
                decayPolicy: .slow,
                retrievalTags: ["private", "sealed", "frozen"],
                evidenceCount: 3,
                observationCount: 2,
                provenanceSummary: "Structured private memory retained in sanctum.",
                lifecycleState: .active,
                tier: .warm
            )
        )
        try context.save()

        let blockedProjection = DecisionMemorySystem.refreshProjection(
            in: context,
            now: stableNow
        )
        let revealedProjection = DecisionMemorySystem.refreshProjection(
            in: context,
            authorizedRevealIDs: ["record.sealed.reveal"],
            now: stableNow
        )
        let storedRecord = try XCTUnwrap(
            try context.fetch(FetchDescriptor<DecisionMemoryRecord>())
                .first(where: { $0.id == "record.sealed.reveal" })
        )
        let temporalProjection = try XCTUnwrap(storedRecord.temporalProjection)

        XCTAssertTrue(DecisionMemorySystem.isSealedInSanctum(temporalProjection))
        XCTAssertTrue(temporalProjection.normalRetrievalBlocked)
        XCTAssertFalse(
            blockedProjection.baseProjection.records.contains(where: { $0.content == storedRecord.headline })
        )
        XCTAssertTrue(
            revealedProjection.baseProjection.records.contains(where: { $0.content == storedRecord.headline })
        )
    }

    @MainActor
    func testRefreshProjectionKeepsPolicyLockedFrozenSanctumMemoryBlockedDespiteAuthorizedReveal() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let stableNow = date("2026-04-09T23:10:00Z")

        context.insert(
            DecisionMemoryRecord(
                id: "record.sealed.locked",
                type: .semantic,
                topic: "sealed_locked_topic",
                headline: "This sealed memory remains policy locked.",
                value: "l14_policy_override_only",
                confidence: 0.89,
                priority: 0.7,
                source: .history,
                lastConfirmedAt: date("2026-04-09T21:30:00Z"),
                decayPolicy: .slow,
                retrievalTags: ["sealed", "policy_override_only", "frozen_hold"],
                evidenceCount: 4,
                observationCount: 2,
                provenanceSummary: "Structured private memory with override-only sanctum policy.",
                lifecycleState: .active,
                tier: .warm
            )
        )
        try context.save()

        let projection = DecisionMemorySystem.refreshProjection(
            in: context,
            authorizedRevealIDs: ["record.sealed.locked"],
            now: stableNow
        )
        let field = DecisionMemorySystem.temporalField(
            in: context,
            now: stableNow
        )
        let storedRecord = try XCTUnwrap(
            try context.fetch(FetchDescriptor<DecisionMemoryRecord>())
                .first(where: { $0.id == "record.sealed.locked" })
        )
        let temporalProjection = try XCTUnwrap(storedRecord.temporalProjection)
        let sanctumEntry = try XCTUnwrap(
            field.sanctumEntries.first(where: { $0.entryID == temporalProjection.sanctumEntryID })
        )

        XCTAssertEqual(temporalProjection.sanctumAccessPolicy, "l14_policy_override_only")
        XCTAssertFalse(temporalProjection.sanctumRevealConditions.contains("host_authorized_recall"))
        XCTAssertNotNil(temporalProjection.sanctumFrozenUntil)
        XCTAssertFalse(
            DecisionMemorySystem.canHostRevealSanctum(
                temporalProjection,
                now: stableNow
            )
        )
        XCTAssertEqual(sanctumEntry.accessPolicy, "l14_policy_override_only")
        XCTAssertFalse(sanctumEntry.revealConditions.contains("host_authorized_recall"))
        XCTAssertNotNil(sanctumEntry.frozenUntil)
        XCTAssertFalse(
            projection.baseProjection.records.contains(where: { $0.content == storedRecord.headline })
        )
    }

    @MainActor
    func testHostDeleteActionStagesForgetCascadeAndBlocksNormalProjection() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let stableNow = date("2026-04-10T01:20:00Z")

        context.insert(
            DecisionMemoryRecord(
                id: "record.delete.host",
                type: .semantic,
                topic: "host_delete_topic",
                headline: "This memory should leave the active portrait.",
                value: "delete_this_memory",
                confidence: 0.84,
                priority: 0.78,
                source: .history,
                lastConfirmedAt: date("2026-04-09T20:00:00Z"),
                decayPolicy: .slow,
                retrievalTags: ["boundary"],
                evidenceCount: 3,
                observationCount: 2,
                provenanceSummary: "Structured host-authored boundary memory.",
                lifecycleState: .active,
                tier: .warm
            )
        )
        try context.save()

        XCTAssertTrue(
            DecisionMemorySystem.applyHostDeleteAction(
                id: "record.delete.host",
                in: context,
                now: stableNow
            )
        )

        let projection = DecisionMemorySystem.refreshProjection(
            in: context,
            now: stableNow
        )
        let field = DecisionMemorySystem.temporalField(
            in: context,
            now: stableNow
        )
        let storedRecord = try XCTUnwrap(
            try context.fetch(FetchDescriptor<DecisionMemoryRecord>())
                .first(where: { $0.id == "record.delete.host" })
        )
        let temporalProjection = try XCTUnwrap(storedRecord.temporalProjection)
        let forgetCascade = try XCTUnwrap(
            field.forgetCascades.first(where: { $0.cascadeID == temporalProjection.forgetCascadeIDs.first })
        )

        XCTAssertEqual(storedRecord.lifecycleState, .retired)
        XCTAssertTrue(storedRecord.retrievalTags.contains("deleted"))
        XCTAssertEqual(temporalProjection.forgetExecutionState, "delete_pending")
        XCTAssertTrue(temporalProjection.normalRetrievalBlocked)
        XCTAssertFalse(DecisionMemorySystem.shouldSurfaceInPortrait(storedRecord))
        XCTAssertEqual(forgetCascade.executionState, "delete_pending")
        XCTAssertFalse(
            projection.baseProjection.records.contains(where: { $0.content == storedRecord.headline })
        )
    }

    @MainActor
    func testHostNotMeActionStagesRevocationAndBlocksNormalProjection() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let stableNow = date("2026-04-10T01:45:00Z")

        context.insert(
            DecisionMemoryRecord(
                id: "record.notme.host",
                type: .identity,
                topic: "identity_topic",
                headline: "This pattern is not me anymore.",
                value: "no_longer_me",
                confidence: 0.88,
                priority: 0.71,
                source: .history,
                lastConfirmedAt: date("2026-04-09T18:00:00Z"),
                decayPolicy: .slow,
                retrievalTags: ["identity"],
                evidenceCount: 4,
                observationCount: 3,
                provenanceSummary: "Structured host identity memory.",
                lifecycleState: .active,
                tier: .cold
            )
        )
        try context.save()

        XCTAssertTrue(
            DecisionMemorySystem.applyHostNotMeAction(
                id: "record.notme.host",
                in: context,
                now: stableNow
            )
        )

        let projection = DecisionMemorySystem.refreshProjection(
            in: context,
            now: stableNow
        )
        let field = DecisionMemorySystem.temporalField(
            in: context,
            now: stableNow
        )
        let storedRecord = try XCTUnwrap(
            try context.fetch(FetchDescriptor<DecisionMemoryRecord>())
                .first(where: { $0.id == "record.notme.host" })
        )
        let temporalProjection = try XCTUnwrap(storedRecord.temporalProjection)
        let forgetCascade = try XCTUnwrap(
            field.forgetCascades.first(where: { $0.cascadeID == temporalProjection.forgetCascadeIDs.first })
        )

        XCTAssertEqual(storedRecord.lifecycleState, .retired)
        XCTAssertTrue(storedRecord.retrievalTags.contains("not_me"))
        XCTAssertEqual(temporalProjection.forgetExecutionState, "host_revoked")
        XCTAssertTrue(temporalProjection.normalRetrievalBlocked)
        XCTAssertFalse(DecisionMemorySystem.shouldSurfaceInPortrait(storedRecord))
        XCTAssertEqual(forgetCascade.executionState, "host_revoked")
        XCTAssertFalse(
            projection.baseProjection.records.contains(where: { $0.content == storedRecord.headline })
        )
    }

    @MainActor
    func testHostDowngradeActionWarmsColdMemoryWithoutBlockingNormalProjection() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let stableNow = date("2026-04-10T02:10:00Z")

        context.insert(
            DecisionMemoryRecord(
                id: "record.downgrade.host",
                type: .semantic,
                topic: "downgrade_topic",
                headline: "This memory should stay but lose permanence.",
                value: "downgrade_this_memory",
                confidence: 0.91,
                priority: 0.82,
                source: .history,
                lastConfirmedAt: date("2026-04-09T17:00:00Z"),
                decayPolicy: .slow,
                retrievalTags: ["reviewed"],
                evidenceCount: 4,
                observationCount: 4,
                provenanceSummary: "Structured reviewed long-term memory.",
                lifecycleState: .active,
                tier: .cold
            )
        )
        try context.save()

        XCTAssertTrue(
            DecisionMemorySystem.applyHostDowngradeAction(
                id: "record.downgrade.host",
                in: context,
                now: stableNow
            )
        )

        let projection = DecisionMemorySystem.refreshProjection(
            in: context,
            now: stableNow
        )
        let field = DecisionMemorySystem.temporalField(
            in: context,
            now: stableNow
        )
        let storedRecord = try XCTUnwrap(
            try context.fetch(FetchDescriptor<DecisionMemoryRecord>())
                .first(where: { $0.id == "record.downgrade.host" })
        )
        let temporalProjection = try XCTUnwrap(storedRecord.temporalProjection)
        let temperatureProfile = try XCTUnwrap(
            field.temperatureProfiles.first(where: { $0.profileID == temporalProjection.temperatureProfileID })
        )

        XCTAssertEqual(storedRecord.lifecycleState, .aging)
        XCTAssertEqual(storedRecord.tier, .warm)
        XCTAssertTrue(storedRecord.retrievalTags.contains("downgraded"))
        XCTAssertFalse(temporalProjection.normalRetrievalBlocked)
        XCTAssertTrue(DecisionMemorySystem.shouldSurfaceInPortrait(storedRecord))
        XCTAssertEqual(temperatureProfile.currentBand, .warm)
        XCTAssertTrue(
            projection.baseProjection.records.contains(where: { $0.content == storedRecord.headline })
        )
    }

    @MainActor
    func testLoadBrainStateReconstructsProfileGoalsAndRelevantMemories() throws {
        let container = try makeContainer()
        let context = container.mainContext

        seedHistory(into: context)
        _ = DecisionMemorySystem.refreshStoredMemories(in: context)

        let brainState = DecisionMemorySystem.loadBrainState(
            mode: .quick,
            prompt: "Late at night I want to buy this again.",
            context: context,
            now: date("2026-04-09T23:10:00Z")
        )

        XCTAssertTrue(brainState.profileCore.contains("Short, direct language lands better."))
        XCTAssertTrue(
            brainState.activeGoals.contains(where: { $0.contains("Sleep before midnight") }),
            "Expected sleep goal in \(brainState.activeGoals)"
        )
        XCTAssertTrue(
            brainState.relevantMemories.contains(where: { $0.contains("Buy pressure keeps recurring.") }),
            "Expected repeated buy pattern in \(brainState.relevantMemories)"
        )
        XCTAssertTrue(brainState.relevantMemories.contains(where: {
            $0.contains("Holding the decision") ||
                $0.contains("lighter, shorter guidance") ||
                $0.contains("Recently carrying") ||
                $0.contains("Recently weighing")
        }), "Expected stabilizing or context-carrying memory in \(brainState.relevantMemories)")
        XCTAssertTrue(brainState.sessionBiases.contains("Keep the language short and concrete."))
        XCTAssertTrue(brainState.sessionBiases.contains(where: { $0.localizedCaseInsensitiveContains("late at night") }))
        XCTAssertGreaterThanOrEqual(brainState.reactionWeights.briefLanguage, 0.9)
        XCTAssertGreaterThanOrEqual(brainState.reactionWeights.lowCognitiveLoad, 0.8)
        XCTAssertGreaterThanOrEqual(brainState.reactionWeights.interruptiveActionBias, 0.7)
        XCTAssertGreaterThanOrEqual(brainState.memoryGovernance.totalRecordCount, 4)
        XCTAssertGreaterThanOrEqual(brainState.memoryGovernance.pendingCandidateCount, 1)
        XCTAssertGreaterThanOrEqual(brainState.memoryGovernance.loadedPromotedMemoryCount, 1)
        XCTAssertGreaterThanOrEqual(brainState.memoryGovernance.deferredCandidateCount, 1)
        XCTAssertTrue(brainState.retrievalTags.contains("quick"))
        XCTAssertTrue(brainState.retrievalTags.contains("buy"))
        XCTAssertTrue(brainState.memorySlices.contains(where: {
            $0.role == .profile &&
                $0.governanceStatus == .admitted &&
                $0.eligibility == .allowed(.defaultAllowed)
        }))
        XCTAssertTrue(brainState.memorySlices.contains(where: {
            $0.role == .goal &&
                $0.eligibility == .allowed(.goalOverride)
        }))
    }

    @MainActor
    func testLoadBrainStateRaisesInterruptiveBiasWhenReflectionsRewardPausePaths() throws {
        let container = try makeContainer()
        let context = container.mainContext

        seedHistory(into: context)
        context.insert(
            CheckEvent(
                createdAt: date("2026-04-09T08:10:00Z"),
                scenario: .buy,
                motivation: .reward,
                expectedOutcome: .temporaryRelief,
                controlLevel: .maybe,
                note: "I almost bought it again after a stressful morning.",
                currentPerspective: "You want relief fast.",
                afterPerspective: "Tomorrow usually feels quieter.",
                verdict: .pause,
                finalAction: .wait90s,
                reflectionOutcome: .notNeeded,
                entrySource: .app
            )
        )
        context.insert(
            CheckEvent(
                createdAt: date("2026-04-09T09:10:00Z"),
                scenario: .buy,
                motivation: .reward,
                expectedOutcome: .temporaryRelief,
                controlLevel: .maybe,
                note: "I pushed through anyway and felt worse.",
                currentPerspective: "You want relief fast.",
                afterPerspective: "It usually feels noisy tomorrow.",
                verdict: .pause,
                finalAction: .goAheadAnyway,
                reflectionOutcome: .feltEmptier,
                entrySource: .app
            )
        )

        _ = DecisionMemorySystem.refreshStoredMemories(in: context)

        let brainState = DecisionMemorySystem.loadBrainState(
            mode: .quick,
            prompt: "I want to buy this again late at night.",
            context: context,
            now: date("2026-04-09T23:20:00Z")
        )

        XCTAssertGreaterThanOrEqual(brainState.reactionWeights.interruptiveActionBias, 0.85)
        XCTAssertGreaterThanOrEqual(brainState.reactionWeights.lowCognitiveLoad, 0.85)
    }

    @MainActor
    func testLoadBrainStateScreensOutStalePendingMemoriesWhenTheyAreNotRelevant() throws {
        let container = try makeContainer()
        let context = container.mainContext

        seedHistory(into: context)
        _ = DecisionMemorySystem.refreshStoredMemories(in: context)

        let brainState = DecisionMemorySystem.loadBrainState(
            mode: .quick,
            prompt: "Help me think about whether I should cook at home tonight.",
            context: context,
            now: date("2026-04-10T18:00:00Z")
        )

        XCTAssertEqual(brainState.memoryGovernance.loadedPendingMemoryCount, 0)
        XCTAssertGreaterThanOrEqual(brainState.memoryGovernance.screenedOutMemoryCount, 1)
        XCTAssertGreaterThanOrEqual(brainState.memoryGovernance.screenedOutPendingMemoryCount, 1)
        XCTAssertGreaterThanOrEqual(
            brainState.memoryGovernance.screenedOutReasonCounts[.confidenceNoOverlap] ?? 0,
            1
        )
        XCTAssertFalse(brainState.memorySlices.contains(where: \.isPending))
    }

    @MainActor
    func testLoadBrainStateScreensOutPendingCandidatesWithoutOverlapAfterGraceWindow() throws {
        let container = try makeContainer()
        let context = container.mainContext

        context.insert(
            DecisionMemoryCandidateRecord(
                id: "situational.market.latest",
                type: .situational,
                topic: "market_latest",
                headline: "Tonight's market move",
                value: "volatile market signal",
                confidence: 0.79,
                priority: 0.76,
                source: .reflection,
                firstObservedAt: date("2026-04-08T00:00:00Z"),
                lastObservedAt: date("2026-04-08T00:00:00Z"),
                decayPolicy: .medium,
                retrievalTags: ["latest", "market", "night"],
                evidenceCount: 2,
                confirmationCount: 1,
                lastObservationFingerprint: "market-fp",
                status: .pending,
                provenanceSummary: "Fresh reflection from tonight.",
                lastWriteOperation: .noop,
                lastGovernanceDecision: .deferred,
                governanceReason: "Awaiting confirmation."
            )
        )
        try context.save()

        let volatileBrainState = DecisionMemorySystem.loadBrainState(
            mode: .quick,
            prompt: "Help me decide whether to cook at home tonight.",
            context: context,
            now: date("2026-04-09T23:10:00Z")
        )

        XCTAssertEqual(volatileBrainState.memoryGovernance.loadedPendingMemoryCount, 0)
        XCTAssertEqual(
            volatileBrainState.memoryGovernance.screenedOutReasonCounts[.confidenceNoOverlap],
            1
        )
        XCTAssertFalse(
            volatileBrainState.memorySlices.contains(where: { $0.id == "situational.market.latest" })
        )
    }

    @MainActor
    func testLoadBrainStateMakesRetrievalModeExecutable() throws {
        let container = try makeContainer()
        let context = container.mainContext

        seedHistory(into: context)
        _ = DecisionMemorySystem.refreshStoredMemories(in: context)

        let filtered = DecisionMemorySystem.loadBrainState(
            mode: .quick,
            prompt: "Late at night I want to buy this again.",
            context: context,
            retrievalMode: .filtered,
            now: date("2026-04-09T23:10:00Z")
        )

        let off = DecisionMemorySystem.loadBrainState(
            mode: .quick,
            prompt: "Late at night I want to buy this again.",
            context: context,
            retrievalMode: .off,
            now: date("2026-04-09T23:10:00Z")
        )

        let adaptive = DecisionMemorySystem.loadBrainState(
            mode: .mirror,
            prompt: "Should I stay in this relationship?",
            context: context,
            retrievalMode: .adaptive,
            now: date("2026-04-09T23:10:00Z")
        )

        XCTAssertGreaterThan(filtered.memorySlices.count, off.memorySlices.count)
        XCTAssertGreaterThan(filtered.memoryGovernance.loadedPendingMemoryCount, off.memoryGovernance.loadedPendingMemoryCount)
        XCTAssertEqual(off.memoryGovernance.loadedPendingMemoryCount, 0)
        XCTAssertLessThanOrEqual(off.relevantMemories.count, 1)
        XCTAssertGreaterThanOrEqual(adaptive.relevantMemories.count, 2)
    }

    @MainActor
    func testLoadBrainStateScreensOutContaminatedCandidateBeforeFrontstageLoad() throws {
        let container = try makeContainer()
        let context = container.mainContext

        context.insert(
            DecisionMemoryCandidateRecord(
                id: "semantic.injected.buy",
                type: .semantic,
                topic: "buy",
                headline: "Buy pressure keeps recurring.",
                value: "buy",
                confidence: 0.88,
                priority: 0.84,
                source: .pattern,
                firstObservedAt: date("2026-04-09T20:00:00Z"),
                lastObservedAt: date("2026-04-09T20:00:00Z"),
                decayPolicy: .slow,
                retrievalTags: ["buy", "night", "pattern"],
                evidenceCount: 3,
                confirmationCount: 2,
                lastObservationFingerprint: "fp",
                status: .pending,
                provenanceSummary: "tool call returned <script>alert(1)</script>",
                lastWriteOperation: .noop,
                lastGovernanceDecision: .deferred,
                governanceReason: "Pending verification."
            )
        )
        try context.save()

        let brainState = DecisionMemorySystem.loadBrainState(
            mode: .quick,
            prompt: "I want to buy this late at night again.",
            context: context,
            now: date("2026-04-09T23:10:00Z")
        )

        XCTAssertEqual(brainState.memoryGovernance.loadedPendingMemoryCount, 0)
        XCTAssertEqual(
            brainState.memoryGovernance.screenedOutReasonCounts[.provenanceContamination],
            1
        )
        XCTAssertFalse(brainState.memorySlices.contains(where: { $0.id == "semantic.injected.buy" }))
        XCTAssertTrue(brainState.verificationSnapshot.riskFlags.contains(.contaminationGuardTriggered))
    }

    @MainActor
    func testLoadBrainStateAnnotatesHorizonRefreshAndQuarantineSignals() {
        let compiledState = DecisionBrainState(
            profileCore: [],
            activeGoals: ["Ship the fix safely."],
            relevantMemories: [],
            sessionBiases: ["baseline"],
            retrievalTags: ["baseline"],
            reactionWeights: .defaults(for: "quick"),
            identityProfile: .default(modeName: "quick"),
            boundaryPolicy: .default(riskLevel: BASRiskLevel.low),
            memoryGovernance: BASMemoryGovernanceState(
                totalRecordCount: 0,
                totalCandidateCount: 2,
                pendingCandidateCount: 2,
                promotedCandidateCount: 0,
                loadedPromotedMemoryCount: 0,
                loadedPendingMemoryCount: 0,
                screenedOutReasonCounts: [.externalRefreshNoOverlap: 1]
            ),
            loadedAt: date("2026-04-09T23:10:00Z")
        )

        let projection = BASAppleMemoryProjectionRefreshResult(
            baseProjection: BASBrainProjection(
                records: [],
                candidates: [
                    BASMemoryEligibilityCandidate(
                        id: "candidate.external-refresh",
                        role: .relevant,
                        kind: .semantic,
                        headline: "Latest policy note is still volatile.",
                        source: .pattern,
                        scope: .task,
                        sensitivity: .medium,
                        confidence: 0.66,
                        priority: 0.71,
                        retrievalTags: ["external_refresh", "volatile"],
                        lastConfirmedAt: date("2026-04-09T23:10:00Z"),
                        decayPolicy: .fast,
                        lifecycleState: "warming",
                        governanceStatus: .deferred,
                        isPending: true,
                        provenanceSummary: "Needs refreshed evidence.",
                        sourceTrustScore: 0.58,
                        sourceTrustTier: .medium,
                        effectiveConfidence: 0.61,
                        provenanceRisk: false
                    ),
                    BASMemoryEligibilityCandidate(
                        id: "candidate.tool-quarantine",
                        role: .relevant,
                        kind: .situational,
                        headline: "Tool observation has not been corroborated yet.",
                        source: .pattern,
                        scope: .task,
                        sensitivity: .medium,
                        confidence: 0.61,
                        priority: 0.64,
                        retrievalTags: ["quarantined", "tool_observation"],
                        lastConfirmedAt: date("2026-04-09T23:10:00Z"),
                        decayPolicy: .fast,
                        lifecycleState: "warming",
                        governanceStatus: .deferred,
                        isPending: true,
                        provenanceSummary: "Observation-only candidate.",
                        sourceTrustScore: 0.56,
                        sourceTrustTier: .medium,
                        effectiveConfidence: 0.58,
                        provenanceRisk: false
                    )
                ],
                recentEvents: [],
                governanceSnapshot: BASMemoryGovernanceState(
                    totalRecordCount: 0,
                    totalCandidateCount: 2,
                    pendingCandidateCount: 2,
                    promotedCandidateCount: 0,
                    loadedPromotedMemoryCount: 0,
                    loadedPendingMemoryCount: 0
                )
            ),
            governanceSnapshot: BASAppleProjectionGovernanceSnapshot(
                totalRecordCount: 0,
                totalCandidateCount: 2,
                pendingCandidateCount: 2,
                promotedCandidateCount: 0,
                deferredCandidateCount: 2,
                admittedCandidateCount: 0
            ),
            diagnostics: BASAppleMemoryProjectionDiagnostics(
                recordCount: 0,
                candidateCount: 2,
                allCandidatesPending: true
            ),
            refreshedAt: date("2026-04-09T23:10:00Z")
        )

        let brainState = DecisionMemorySystem.loadBrainState(
            mode: .quick,
            prompt: "Should I trust the newest tool note?",
            projection: projection,
            retrievalMode: .filtered,
            now: date("2026-04-09T23:10:00Z"),
            compileBrainState: { _, _, _, _, _, _ in
                compiledState
            }
        )

        XCTAssertTrue(brainState.sessionBiases.contains("horizon-external-refresh"))
        XCTAssertTrue(brainState.sessionBiases.contains("horizon-tool-quarantine"))
        XCTAssertTrue(
            brainState.sessionBiases.contains("Keep uncertainty visible until fresh evidence arrives.")
        )
        XCTAssertTrue(
            brainState.sessionBiases.contains("Treat tool observations as provisional until corroborated.")
        )
        XCTAssertTrue(brainState.retrievalTags.contains("external_refresh"))
        XCTAssertTrue(brainState.retrievalTags.contains("volatile"))
        XCTAssertTrue(brainState.retrievalTags.contains("quarantine"))
        XCTAssertTrue(brainState.retrievalTags.contains("tool_observation"))
    }

    @MainActor
    func testBrainStateVerificationSnapshotIsStableForSameInputs() throws {
        let container = try makeContainer()
        let context = container.mainContext

        seedHistory(into: context)
        _ = DecisionMemorySystem.refreshStoredMemories(in: context)

        let first = DecisionMemorySystem.loadBrainState(
            mode: .quick,
            prompt: "Late at night I want to buy this again.",
            context: context,
            now: date("2026-04-09T23:10:00Z")
        )
        let second = DecisionMemorySystem.loadBrainState(
            mode: .quick,
            prompt: "Late at night I want to buy this again.",
            context: context,
            now: date("2026-04-09T23:10:00Z")
        )

        XCTAssertEqual(first.verificationSnapshot.fingerprint, second.verificationSnapshot.fingerprint)
        XCTAssertEqual(
            first.verificationSnapshot.dominantReactionWeight,
            second.verificationSnapshot.dominantReactionWeight
        )
        XCTAssertGreaterThan(first.verificationSnapshot.loadedMemoryCount, 0)
    }

    @MainActor
    func testLoadBrainStateAddsLanguageAndScriptTagsForChinesePrompt() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let brainState = DecisionMemorySystem.loadBrainState(
            mode: .quick,
            prompt: "我今晚又想买这个。",
            context: context,
            now: date("2026-04-09T23:10:00Z")
        )

        XCTAssertTrue(brainState.retrievalTags.contains("lang:chinese"))
        XCTAssertTrue(brainState.retrievalTags.contains("script:han"))
        XCTAssertTrue(brainState.retrievalTags.contains(where: { $0.contains("今晚") || $0.contains("想买") }))
    }

    @MainActor
    func testLoadBrainStateFallbackRecordsAuditableNoticeAndDegradedBias() throws {
        enum SyntheticFailure: Error {
            case compilerRejected
        }

        PersistenceIssueRecorder.clear()
        defer { PersistenceIssueRecorder.clear() }
        let projection = DecisionMemorySystem.BrainStateProjection(
            baseProjection: BASBrainProjection(
                records: [],
                candidates: [],
                recentEvents: [],
                activeTemplateIDs: ["projection.template/bootstrap-rebuild"],
                failureGuardIDs: ["projection.guard/compiler-drift"]
            ),
            governanceSnapshot: BASAppleProjectionGovernanceSnapshot(
                totalRecordCount: 7,
                totalCandidateCount: 4,
                pendingCandidateCount: 2,
                promotedCandidateCount: 2,
                deferredCandidateCount: 1,
                admittedCandidateCount: 1
            ),
            diagnostics: BASAppleMemoryProjectionDiagnostics(
                recordCount: 3,
                candidateCount: 2,
                allCandidatesPending: false
            ),
            refreshedAt: date("2026-04-09T23:09:30Z")
        )

        let brainState = DecisionMemorySystem.loadBrainState(
            mode: .quick,
            prompt: "I need a fallback path.",
            projection: projection,
            retrievalMode: .filtered,
            now: date("2026-04-09T23:10:00Z"),
            compileBrainState: { _, _, _, _, _, _ in
                throw SyntheticFailure.compilerRejected
            }
        )

        XCTAssertTrue(brainState.sessionBiases.contains("brain-bootstrap-recovery"))
        XCTAssertTrue(brainState.sessionBiases.contains("brain-bootstrap-remediation-required"))
        XCTAssertTrue(brainState.sessionBiases.contains("release-lane:recovery"))
        XCTAssertTrue(brainState.sessionBiases.contains("lease:restricted"))
        XCTAssertTrue(brainState.sessionBiases.contains("confirmation:operator_recovery_review"))
        XCTAssertTrue(brainState.retrievalTags.contains("recovery"))
        XCTAssertTrue(brainState.retrievalTags.contains("restricted"))
        XCTAssertTrue(brainState.retrievalTags.contains("restricted-lease"))
        XCTAssertTrue(brainState.retrievalTags.contains("tool-write-blocked"))
        XCTAssertTrue(brainState.retrievalTags.contains("memory-write-blocked"))
        XCTAssertTrue(brainState.retrievalTags.contains("deep-loop-blocked"))
        XCTAssertTrue(
            brainState.relevantMemories.contains(
                BeforeProductCompatibility.currentBrainBootstrapRecoveryContract.recoveryIssueSummary
            )
        )
        XCTAssertTrue(
            brainState.relevantMemories.contains(
                BeforeProductCompatibility.currentBrainBootstrapRecoveryContract.recoveryIssueRemediation
            )
        )
        XCTAssertTrue(
            brainState.relevantMemories.contains(
                "Required confirmations: operator_recovery_review"
            )
        )
        XCTAssertEqual(brainState.boundaryPolicy.mode, .localOnlyProtective)
        XCTAssertEqual(
            brainState.boundaryPolicy.allowedActionClasses,
            BeforeProductCompatibility.currentBrainBootstrapRecoveryContract.recoveryAllowedActionClasses
        )
        XCTAssertEqual(
            brainState.boundaryPolicy.blockedActionClasses,
            BeforeProductCompatibility.currentBrainBootstrapRecoveryContract.recoveryBlockedActionClasses
        )
        XCTAssertEqual(
            brainState.boundaryPolicy.requiredConfirmations,
            BeforeProductCompatibility.currentBrainBootstrapRecoveryContract.recoveryRequiredConfirmations
        )
        XCTAssertEqual(
            brainState.boundaryPolicy.activeConstraints,
            BeforeProductCompatibility.currentBrainBootstrapRecoveryContract.recoveryBoundaryConstraints
        )
        XCTAssertEqual(
            brainState.boundaryPolicy.auditHeadline,
            BeforeProductCompatibility.currentBrainBootstrapRecoveryContract.recoveryBoundaryAuditHeadline
        )
        XCTAssertEqual(brainState.calibrationState.status, .drifting)
        XCTAssertTrue(brainState.calibrationState.alerts.contains(.templateCoverageGap))
        XCTAssertEqual(
            brainState.activeInterventionTemplateIDs,
            [
                "before.template/recovery-lane",
                "before.template/recovery-remediation",
                "projection.template/bootstrap-rebuild"
            ]
        )
        XCTAssertEqual(
            brainState.failureGuardIDs,
            [
                "before.guard/bootstrap-recovery",
                "before.guard/restricted-writes",
                "projection.guard/compiler-drift"
            ]
        )
        XCTAssertEqual(
            brainState.reactionWeights,
            try XCTUnwrap(
                BeforeProductCompatibility.currentBrainBootstrapRecoveryContract
                    .recoveryReactionWeightsByMode?[DecisionMode.quick.rawValue]
            )
        )
        XCTAssertEqual(
            brainState.identityProfile,
            try XCTUnwrap(
                BeforeProductCompatibility.currentBrainBootstrapRecoveryContract
                    .recoveryIdentityProfilesByMode?[DecisionMode.quick.rawValue]
            )
        )
        XCTAssertEqual(brainState.memoryGovernance.totalRecordCount, 7)
        XCTAssertEqual(brainState.memoryGovernance.totalCandidateCount, 4)
        XCTAssertEqual(brainState.memoryGovernance.pendingCandidateCount, 2)
        XCTAssertEqual(brainState.memoryGovernance.promotedCandidateCount, 2)
        XCTAssertEqual(brainState.memoryGovernance.deferredCandidateCount, 1)
        XCTAssertEqual(brainState.memoryGovernance.admittedCandidateCount, 1)
        XCTAssertEqual(brainState.evolutionState.pendingReviewCount, 2)
        XCTAssertEqual(brainState.evolutionState.checkpointCount, 1)
        XCTAssertFalse(brainState.evolutionState.rollbackReady)
        XCTAssertTrue(
            brainState.evolutionState.recentDiffSummary.contains(where: {
                $0.localizedCaseInsensitiveContains("recovery")
            })
        )
        let recoveryCheckpoint = try XCTUnwrap(brainState.evolutionState.latestCheckpoint)
        XCTAssertEqual(recoveryCheckpoint.approvalState, .reviewSuggested)
        XCTAssertFalse(recoveryCheckpoint.rollbackReady)
        XCTAssertTrue(
            recoveryCheckpoint.diffSummary.contains(where: {
                $0.localizedCaseInsensitiveContains("operator confirmations required")
            })
        )
        let recoveryLineage = try XCTUnwrap(recoveryCheckpoint.lineageSummary)
        XCTAssertEqual(recoveryLineage.runMode, .recovery)
        XCTAssertEqual(recoveryLineage.taskType, "brain-bootstrap-fallback")
        XCTAssertEqual(recoveryLineage.recoveryDisposition?.kind, .recovery)
        XCTAssertEqual(recoveryLineage.recoveryDisposition?.restrictedLease, true)
        XCTAssertEqual(recoveryLineage.recoveryDisposition?.toolWriteAllowed, false)
        XCTAssertEqual(recoveryLineage.recoveryDisposition?.memoryWriteAllowed, false)
        XCTAssertEqual(recoveryLineage.recoveryDisposition?.operatorReviewRequired, true)
        XCTAssertEqual(
            recoveryLineage.recoveryDisposition?.requiredConfirmations,
            BeforeProductCompatibility.currentBrainBootstrapRecoveryContract.recoveryRequiredConfirmations
        )
        XCTAssertEqual(
            recoveryLineage.recoveryDisposition?.allowedActionClasses,
            BeforeProductCompatibility.currentBrainBootstrapRecoveryContract.recoveryAllowedActionClasses
        )
        XCTAssertEqual(
            recoveryLineage.recoveryDisposition?.blockedActionClasses,
            BeforeProductCompatibility.currentBrainBootstrapRecoveryContract.recoveryBlockedActionClasses
        )
        XCTAssertEqual(
            recoveryLineage.recoveryDisposition?.remediationActions,
            [
                "recompile_current_brain_state",
                "review_bootstrap_diagnostics",
                "preserve_restricted_lease",
                "collect_confirmation:operator_recovery_review"
            ]
        )
        XCTAssertEqual(
            recoveryLineage.recoveryDisposition?.summary,
            BeforeProductCompatibility.currentBrainBootstrapRecoveryContract.recoveryIssueSummary
        )
        XCTAssertNotNil(PersistenceIssueRecorder.latestNotice())
        XCTAssertTrue(
            PersistenceIssueRecorder.latestNotice()?.contains("bootstrapping current brain state from projection") == true
        )
        let issue = PersistenceIssueRecorder.latestIssue()
        XCTAssertEqual(issue?.category, .brainBootstrapFallback)
        XCTAssertEqual(issue?.severity, .warning)
        XCTAssertEqual(issue?.operation, "bootstrapping current brain state from projection")
        XCTAssertTrue(issue?.remediation?.localizedCaseInsensitiveContains("restricted recovery") == true)
    }

    @MainActor
    func testRepeatedBrainBootstrapFallbackEscalatesToQuarantineContract() throws {
        enum SyntheticFailure: Error {
            case compilerRejected
        }

        PersistenceIssueRecorder.clear()
        defer { PersistenceIssueRecorder.clear() }
        let projection = DecisionMemorySystem.BrainStateProjection(
            baseProjection: BASBrainProjection(
                records: [],
                candidates: [],
                recentEvents: [],
                activeTemplateIDs: ["projection.template/bootstrap-rebuild"],
                failureGuardIDs: ["projection.guard/compiler-drift"]
            ),
            governanceSnapshot: BASAppleProjectionGovernanceSnapshot(
                totalRecordCount: 9,
                totalCandidateCount: 5,
                pendingCandidateCount: 3,
                promotedCandidateCount: 2,
                deferredCandidateCount: 2,
                admittedCandidateCount: 1
            ),
            diagnostics: BASAppleMemoryProjectionDiagnostics(
                recordCount: 4,
                candidateCount: 3,
                allCandidatesPending: false
            ),
            refreshedAt: date("2026-04-09T23:09:30Z")
        )

        _ = DecisionMemorySystem.loadBrainState(
            mode: .quick,
            prompt: "First recovery attempt.",
            projection: projection,
            retrievalMode: .filtered,
            now: date("2026-04-09T23:10:00Z"),
            compileBrainState: { _, _, _, _, _, _ in
                throw SyntheticFailure.compilerRejected
            }
        )

        let quarantinedBrainState = DecisionMemorySystem.loadBrainState(
            mode: .quick,
            prompt: "Second recovery attempt.",
            projection: projection,
            retrievalMode: .filtered,
            now: date("2026-04-09T23:11:00Z"),
            compileBrainState: { _, _, _, _, _, _ in
                throw SyntheticFailure.compilerRejected
            }
        )

        XCTAssertTrue(quarantinedBrainState.sessionBiases.contains("brain-bootstrap-quarantine"))
        XCTAssertTrue(quarantinedBrainState.sessionBiases.contains("release-lane:quarantine"))
        XCTAssertTrue(quarantinedBrainState.sessionBiases.contains("lease:restricted"))
        XCTAssertTrue(quarantinedBrainState.sessionBiases.contains("operator-review-required"))
        XCTAssertTrue(quarantinedBrainState.sessionBiases.contains("confirmation:operator_quarantine_release"))
        XCTAssertTrue(quarantinedBrainState.retrievalTags.contains("quarantine"))
        XCTAssertTrue(quarantinedBrainState.retrievalTags.contains("restricted-lease"))
        XCTAssertTrue(quarantinedBrainState.retrievalTags.contains("tool-write-blocked"))
        XCTAssertTrue(quarantinedBrainState.retrievalTags.contains("memory-write-blocked"))
        XCTAssertTrue(quarantinedBrainState.retrievalTags.contains("deep-loop-blocked"))
        XCTAssertTrue(
            quarantinedBrainState.relevantMemories.contains(
                BeforeProductCompatibility.currentBrainBootstrapRecoveryContract.quarantineIssueSummary
            )
        )
        XCTAssertTrue(
            quarantinedBrainState.relevantMemories.contains(
                BeforeProductCompatibility.currentBrainBootstrapRecoveryContract.quarantineIssueRemediation
            )
        )
        XCTAssertTrue(
            quarantinedBrainState.relevantMemories.contains(
                "Required confirmations: operator_recovery_review, operator_quarantine_release"
            )
        )
        XCTAssertEqual(quarantinedBrainState.boundaryPolicy.mode, .localOnlyProtective)
        XCTAssertEqual(
            quarantinedBrainState.boundaryPolicy.allowedActionClasses,
            BeforeProductCompatibility.currentBrainBootstrapRecoveryContract.quarantineAllowedActionClasses
        )
        XCTAssertEqual(
            quarantinedBrainState.boundaryPolicy.blockedActionClasses,
            BeforeProductCompatibility.currentBrainBootstrapRecoveryContract.quarantineBlockedActionClasses
        )
        XCTAssertEqual(
            quarantinedBrainState.boundaryPolicy.requiredConfirmations,
            BeforeProductCompatibility.currentBrainBootstrapRecoveryContract.quarantineRequiredConfirmations
        )
        XCTAssertEqual(
            quarantinedBrainState.boundaryPolicy.activeConstraints,
            BeforeProductCompatibility.currentBrainBootstrapRecoveryContract.quarantineBoundaryConstraints
        )
        XCTAssertEqual(
            quarantinedBrainState.boundaryPolicy.auditHeadline,
            BeforeProductCompatibility.currentBrainBootstrapRecoveryContract.quarantineBoundaryAuditHeadline
        )
        XCTAssertEqual(
            quarantinedBrainState.activeInterventionTemplateIDs,
            [
                "before.template/recovery-lane",
                "before.template/quarantine-lane",
                "before.template/recovery-remediation",
                "projection.template/bootstrap-rebuild"
            ]
        )
        XCTAssertEqual(
            quarantinedBrainState.failureGuardIDs,
            [
                "before.guard/bootstrap-recovery",
                "before.guard/bootstrap-quarantine",
                "before.guard/restricted-writes",
                "projection.guard/compiler-drift"
            ]
        )
        XCTAssertEqual(
            quarantinedBrainState.reactionWeights,
            try XCTUnwrap(
                BeforeProductCompatibility.currentBrainBootstrapRecoveryContract
                    .quarantineReactionWeightsByMode?[DecisionMode.quick.rawValue]
            )
        )
        XCTAssertEqual(
            quarantinedBrainState.identityProfile,
            try XCTUnwrap(
                BeforeProductCompatibility.currentBrainBootstrapRecoveryContract
                    .quarantineIdentityProfilesByMode?[DecisionMode.quick.rawValue]
            )
        )
        XCTAssertEqual(quarantinedBrainState.memoryGovernance.totalRecordCount, 9)
        XCTAssertEqual(quarantinedBrainState.memoryGovernance.pendingCandidateCount, 3)
        XCTAssertEqual(quarantinedBrainState.memoryGovernance.deferredCandidateCount, 2)
        XCTAssertEqual(quarantinedBrainState.evolutionState.pendingReviewCount, 3)
        XCTAssertEqual(quarantinedBrainState.evolutionState.checkpointCount, 1)
        let quarantineCheckpoint = try XCTUnwrap(quarantinedBrainState.evolutionState.latestCheckpoint)
        XCTAssertEqual(quarantineCheckpoint.approvalState, .reviewSuggested)
        XCTAssertFalse(quarantineCheckpoint.rollbackReady)
        let quarantineLineage = try XCTUnwrap(quarantineCheckpoint.lineageSummary)
        XCTAssertEqual(quarantineLineage.runMode, .quarantine)
        XCTAssertEqual(quarantineLineage.taskType, "brain-bootstrap-fallback")
        XCTAssertEqual(quarantineLineage.recoveryDisposition?.kind, .quarantine)
        XCTAssertEqual(quarantineLineage.recoveryDisposition?.restrictedLease, true)
        XCTAssertEqual(quarantineLineage.recoveryDisposition?.toolWriteAllowed, false)
        XCTAssertEqual(quarantineLineage.recoveryDisposition?.memoryWriteAllowed, false)
        XCTAssertEqual(quarantineLineage.recoveryDisposition?.operatorReviewRequired, true)
        XCTAssertEqual(
            quarantineLineage.recoveryDisposition?.requiredConfirmations,
            BeforeProductCompatibility.currentBrainBootstrapRecoveryContract.quarantineRequiredConfirmations
        )
        XCTAssertEqual(
            quarantineLineage.recoveryDisposition?.allowedActionClasses,
            BeforeProductCompatibility.currentBrainBootstrapRecoveryContract.quarantineAllowedActionClasses
        )
        XCTAssertEqual(
            quarantineLineage.recoveryDisposition?.blockedActionClasses,
            BeforeProductCompatibility.currentBrainBootstrapRecoveryContract.quarantineBlockedActionClasses
        )
        XCTAssertEqual(
            quarantineLineage.recoveryDisposition?.remediationActions,
            [
                "recompile_current_brain_state",
                "review_bootstrap_diagnostics",
                "preserve_restricted_lease",
                "preserve_quarantine_evidence",
                "collect_confirmation:operator_recovery_review",
                "collect_confirmation:operator_quarantine_release"
            ]
        )
        XCTAssertEqual(
            quarantineLineage.recoveryDisposition?.summary,
            BeforeProductCompatibility.currentBrainBootstrapRecoveryContract.quarantineIssueSummary
        )
        XCTAssertEqual(quarantineLineage.quarantineRecords.map(\.zone), [.session, .tool, .memory])
        XCTAssertEqual(PersistenceIssueRecorder.latestIssue()?.severity, .critical)
    }

    @MainActor
    func testRefreshProjectionUsesBoundedWorkingSetAndPreservesGovernanceCounts() throws {
        let container = try makeContainer()
        let context = container.mainContext

        for index in 0..<110 {
            context.insert(
                DecisionMemoryRecord(
                    id: "record-\(index)",
                    type: .semantic,
                    topic: "topic-\(index)",
                    headline: "Headline \(index)",
                    value: "Value \(index)",
                    confidence: 0.8,
                    priority: Double(200 - index),
                    source: .pattern,
                    lastConfirmedAt: date("2026-04-09T23:10:00Z").addingTimeInterval(Double(-index) * 60),
                    decayPolicy: .slow,
                    retrievalTags: ["tag-\(index)"],
                    evidenceCount: 2,
                    observationCount: 2,
                    provenanceSummary: "Synthetic record \(index)"
                )
            )
        }

        for index in 0..<44 {
            context.insert(
                DecisionMemoryCandidateRecord(
                    id: "candidate-\(index)",
                    type: .situational,
                    topic: "candidate-topic-\(index)",
                    headline: "Candidate \(index)",
                    value: "Candidate value \(index)",
                    confidence: 0.7,
                    priority: Double(100 - index),
                    source: .history,
                    firstObservedAt: date("2026-04-09T23:10:00Z").addingTimeInterval(Double(-index) * 120),
                    lastObservedAt: date("2026-04-09T23:10:00Z").addingTimeInterval(Double(-index) * 120),
                    decayPolicy: .fast,
                    retrievalTags: ["candidate-\(index)"],
                    evidenceCount: 1,
                    confirmationCount: 1,
                    lastObservationFingerprint: "fingerprint-\(index)",
                    status: index < 26 ? .pending : .promoted,
                    provenanceSummary: "Synthetic candidate \(index)",
                    lastWriteOperation: .add,
                    lastGovernanceDecision: index.isMultiple(of: 2) ? .admit : .deferred,
                    governanceReason: "synthetic"
                )
            )
        }
        try context.save()

        let projection = DecisionMemorySystem.refreshProjection(
            in: context,
            now: date("2026-04-09T23:10:00Z")
        )

        XCTAssertEqual(projection.governanceSnapshot.totalRecordCount, 110)
        XCTAssertEqual(projection.governanceSnapshot.totalCandidateCount, 44)
        XCTAssertEqual(projection.governanceSnapshot.pendingCandidateCount, 26)
        XCTAssertEqual(projection.governanceSnapshot.promotedCandidateCount, 18)
        XCTAssertEqual(projection.governanceSnapshot.admittedCandidateCount, 22)
        XCTAssertEqual(projection.governanceSnapshot.deferredCandidateCount, 22)
        XCTAssertLessThanOrEqual(projection.diagnostics.recordCount, DecisionMemorySystem.projectionRecordLimit)
        XCTAssertLessThanOrEqual(projection.diagnostics.candidateCount, DecisionMemorySystem.projectionCandidateLimit)
        XCTAssertTrue(projection.diagnostics.allCandidatesPending)
    }

    @MainActor
    private func makeContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: CheckEvent.self,
            SelfReminder.self,
            BalanceDecisionRecord.self,
            MirrorDecisionRecord.self,
            DecisionMemoryRecord.self,
            DecisionMemoryCandidateRecord.self,
            configurations: configuration
        )
    }

    @MainActor
    private func seedHistory(into context: ModelContext) {
        let checkDates = [
            date("2026-04-08T22:10:00Z"),
            date("2026-04-07T22:45:00Z"),
            date("2026-04-06T23:05:00Z")
        ]

        checkDates.forEach { createdAt in
            context.insert(
                CheckEvent(
                    createdAt: createdAt,
                    scenario: .buy,
                    motivation: .reward,
                    expectedOutcome: .temporaryRelief,
                    controlLevel: .maybe,
                    note: "I want these shoes after a rough day.",
                    currentPerspective: "You want a quick hit of relief.",
                    afterPerspective: "It usually feels noisy tomorrow.",
                    verdict: .pause,
                    finalAction: .decideTomorrow,
                    entrySource: .app
                )
            )
        }

        context.insert(
            BalanceDecisionRecord(
                createdAt: date("2026-04-08T09:00:00Z"),
                updatedAt: date("2026-04-08T09:05:00Z"),
                prompt: "Should I keep taking late freelance work?",
                desire: "Extra income",
                concern: "It wrecks sleep",
                constraint: "Bills are real",
                longTerm: "Sleep before midnight",
                focusTitle: "Protect sleep",
                focusSummary: "The real trade-off is cash versus recovery.",
                nextAction: "Cap late work to two nights.",
                entrySource: .app
            )
        )

        context.insert(
            MirrorDecisionRecord(
                createdAt: date("2026-04-08T12:00:00Z"),
                updatedAt: date("2026-04-08T12:10:00Z"),
                prompt: "Should I stay in this relationship?",
                emotion: "Drained",
                relationship: "I keep shrinking around them.",
                reality: "Nothing changes after the apology.",
                longTerm: "Stop shrinking myself in love",
                selfLens: "I stay because ending it feels empty.",
                coreTension: "Comfort keeps beating truth.",
                nextActionTitle: "Name the real cost",
                nextAction: "Write what staying is costing your life.",
                entrySource: .app
            )
        )

        [
            "Keep it short. I do not need a speech.",
            "This is stress shopping again.",
            "Tomorrow is still an option."
        ].forEach { content in
            context.insert(
                SelfReminder(
                    content: content,
                    scenario: .buy,
                    source: .userWritten,
                    createdAt: date("2026-04-08T08:00:00Z"),
                    lastUsedAt: date("2026-04-08T21:55:00Z"),
                    useCount: 1
                )
            )
        }

        try? context.save()
    }

    private func date(_ iso8601: String) -> Date {
        ISO8601DateFormatter().date(from: iso8601) ?? .now
    }
}
