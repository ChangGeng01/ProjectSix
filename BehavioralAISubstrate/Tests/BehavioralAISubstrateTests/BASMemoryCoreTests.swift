import Foundation
import Testing
@testable import BASMemory
import BASRuntimeCore

@Suite("BASMemory")
struct BASMemoryCoreTests {
    @Test("tier filter keeps frontstage memories only")
    func tierFilterKeepsFrontstageMemoriesOnly() {
        let hot = BASGovernedMemory(
            kind: .semantic,
            content: "hot",
            scope: .user,
            sensitivity: .low,
            tier: .hot,
            confidence: 0.8,
            sourceType: "user",
            governanceStatus: .governed,
            provenanceSummary: "hot"
        )
        let warm = BASGovernedMemory(
            kind: .template,
            content: "warm",
            scope: .task,
            sensitivity: .medium,
            tier: .warm,
            confidence: 0.7,
            sourceType: "system",
            governanceStatus: .governed,
            provenanceSummary: "warm"
        )
        let cold = BASGovernedMemory(
            kind: .failurePattern,
            content: "cold",
            scope: .session,
            sensitivity: .high,
            tier: .cold,
            confidence: 0.9,
            sourceType: "system",
            governanceStatus: .governed,
            provenanceSummary: "cold"
        )
        let quarantined = BASGovernedMemory(
            kind: .semantic,
            content: "quarantined",
            scope: .user,
            sensitivity: .low,
            tier: .hot,
            confidence: 0.6,
            sourceType: "user",
            governanceStatus: .quarantined,
            provenanceSummary: "quarantined"
        )

        let filtered = BASMemoryTierFilter.frontstageEligibleMemories([hot, warm, cold, quarantined])

        #expect(filtered == [hot, warm])
        #expect(BASMemoryTierFilter.isFrontstageEligible(.hot))
        #expect(!BASMemoryTierFilter.isFrontstageEligible(.cold))
    }

    @Test("candidate promotion preserves governed fields")
    func candidatePromotionPreservesGovernedFields() {
        let event = BASEventRecord(kind: .profile, content: "user prefers brief answers", tags: ["preference"])
        let candidate = BASMemoryCandidate(
            event: event,
            scope: .user,
            sensitivity: .medium,
            confidence: 0.92,
            sourceType: "user",
            preferredTier: .warm
        )

        #expect(BASMemoryGovernance.shouldAdmit(candidate: candidate))

        let governed = BASMemoryGovernance.promote(candidate: candidate, lastConfirmedAt: Date(timeIntervalSince1970: 1_700_000_000))

        #expect(governed.kind == .profile)
        #expect(governed.tier == .warm)
        #expect(governed.confidence == 0.92)
        #expect(governed.governanceStatus == .governed)
        #expect(governed.provenanceSummary.contains("promoted from candidate:user"))
    }

    @Test("constitution-aware promotion keeps restricted memory in candidate review instead of cold admission")
    func constitutionAwarePromotionDefersRestrictedMemory() {
        let candidate = BASMemoryCandidate(
            event: BASEventRecord(
                kind: .profile,
                content: "private journal details",
                tags: ["private_journal", "identity"]
            ),
            scope: .user,
            sensitivity: .high,
            confidence: 0.93,
            sourceType: "user",
            preferredTier: .cold
        )
        let constitution = BASHostConstitution(
            hostID: "host.memory",
            activeVersion: "constitution.v4",
            boundaryVeil: BASBoundaryVeil(
                restrictedMemoryDomains: ["private_journal"]
            ),
            consentLattice: BASConsentLattice(
                memoryWriteScope: "warm_only",
                memoryPromotionScope: "review_required"
            ),
            narrativeLoom: BASNarrativeLoom(
                currentPhase: "recovery"
            ),
            protectionRing: BASProtectionRing(
                sensitiveDomains: ["identity"]
            )
        )

        let governed = BASMemoryGovernance.promote(
            candidate: candidate,
            under: constitution,
            lastConfirmedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )

        #expect(governed.tier == .warm)
        #expect(governed.governanceStatus == .candidate)
        #expect(governed.provenanceSummary.contains("constitution.v4"))
        #expect(governed.provenanceSummary.contains("review_required"))
        #expect(BASMemoryGovernance.shouldAdmit(candidate: candidate, under: constitution))
    }

    @Test("current brain bootstrap inherits constitution goals constraints and verification markers")
    func currentBrainBootstrapInheritsConstitutionMarkers() {
        let memories = [
            BASGovernedMemory(
                kind: .profile,
                content: "keep the long arc intact",
                scope: .user,
                sensitivity: .medium,
                tier: .warm,
                confidence: 0.83,
                sourceType: "user",
                governanceStatus: .governed,
                provenanceSummary: "profile"
            )
        ]
        let constitution = BASHostConstitution(
            hostID: "host.bootstrap",
            activeVersion: "constitution.v7",
            valueAxes: BASValueAxisSet(
                axes: ["privacy", "stability", "craft"]
            ),
            goalSpine: BASGoalSpine(
                goals: ["ship_l5", "protect_agency"]
            ),
            boundaryVeil: BASBoundaryVeil(
                hardNoGo: ["unsafe_override"],
                softCaution: ["high_pressure"]
            ),
            narrativeLoom: BASNarrativeLoom(
                currentPhase: "migration"
            )
        )

        let brain = BASCurrentBrainBootstrap.bootstrap(
            from: memories,
            constitution: constitution,
            goalHints: ["preserve_locality"],
            constraintHints: ["manual_review"],
            mode: "primary",
            verificationSnapshot: "brain_fp"
        )

        #expect(brain.dominantGoals == ["preserve_locality", "ship_l5", "protect_agency", "keep the long arc intact"])
        #expect(brain.activeConstraints.contains("unsafe_override"))
        #expect(brain.activeConstraints.contains("high_pressure"))
        #expect(brain.retrievalTags.contains("constitution:constitution.v7"))
        #expect(brain.retrievalTags.contains("constitution_phase:migration"))
        #expect(brain.retrievalTags.contains("constitution_value_axes:3"))
        #expect(brain.verificationSnapshot.contains("constitution:constitution.v7"))
        #expect(brain.verificationSnapshot.contains("phase:migration"))
    }

    @Test("governance rejects low confidence singleton drafts")
    func governanceRejectsLowConfidenceSingletonDrafts() {
        let assessment = BASMemoryGovernance.assess(
            draft: BASMemoryGovernanceDraftInput(
                id: "semantic.noisy.singleton",
                typeID: "semantic",
                topic: "noise",
                headline: "Noisy singleton",
                value: "noisy",
                confidence: 0.42,
                priority: 0.41,
                source: .archive,
                lastConfirmedAt: .now,
                decayPolicy: .fast,
                retrievalTags: ["noise"],
                evidenceCount: 1,
                provenanceSummary: "One-off event",
                promotionPolicy: .repeated(minConfirmationCount: 2, minEvidenceCount: 2),
                tierID: "warm"
            )
        )

        #expect(assessment.decision == .reject)
    }

    @Test("governance blocks contaminated provenance drafts")
    func governanceBlocksContaminatedDrafts() {
        let assessment = BASMemoryGovernance.assess(
            draft: BASMemoryGovernanceDraftInput(
                id: "semantic.injected.payload",
                typeID: "semantic",
                topic: "buy",
                headline: "Injected",
                value: "payload",
                confidence: 0.84,
                priority: 0.82,
                source: .pattern,
                lastConfirmedAt: .now,
                decayPolicy: .slow,
                retrievalTags: ["buy", "pattern"],
                evidenceCount: 3,
                provenanceSummary: "tool call returned <script>alert(1)</script>",
                promotionPolicy: .repeated(minConfirmationCount: 2, minEvidenceCount: 3),
                tierID: "warm"
            )
        )

        #expect(assessment.decision == .reject)
        #expect(assessment.reason.localizedCaseInsensitiveContains("contaminated"))
    }

    @Test("governance delays support patterns until they repeat")
    func governanceDelaysSparseSupportPatterns() {
        let assessment = BASMemoryGovernance.assess(
            draft: BASMemoryGovernanceDraftInput(
                id: "support.late_night.reflective",
                typeID: "support",
                topic: "night_support",
                headline: "Late-night reflection pattern.",
                value: "night_support",
                confidence: 0.8,
                priority: 0.72,
                source: .reflection,
                lastConfirmedAt: .now,
                decayPolicy: .medium,
                retrievalTags: ["night", "support"],
                evidenceCount: 1,
                provenanceSummary: "Single reflective pattern inferred from prior sessions.",
                promotionPolicy: .repeated(minConfirmationCount: 2, minEvidenceCount: 3),
                tierID: "warm"
            )
        )

        #expect(assessment.decision == .deferred)
    }

    @Test("horizon descriptor marks external refresh and evidence caveat requirements")
    func governancePrepareBuildsHorizonDescriptor() {
        let prepared = BASMemoryGovernance.prepare(
            draft: BASMemoryGovernanceDraftInput(
                id: "semantic.current.policy",
                typeID: "semantic",
                topic: "policy_update",
                headline: "Current policy changed today.",
                value: "Current policy changed today.",
                confidence: 0.84,
                priority: 0.8,
                source: .archive,
                lastConfirmedAt: .now,
                decayPolicy: .medium,
                retrievalTags: ["policy", "external_refresh"],
                evidenceCount: 1,
                provenanceSummary: "Fresh policy observation.",
                promotionPolicy: .immediate,
                tierID: "warm"
            ),
            persistencePolicy: BASMemoryHorizonPersistencePolicy(
                volatileClaimWriteMode: .stageCandidate,
                contaminatedWriteMode: .quarantineCandidate,
                minimumDurableEvidenceCount: 2
            )
        )

        #expect(prepared.horizonDescriptor.stability == .volatile)
        #expect(prepared.horizonDescriptor.requiresExternalRefresh)
        #expect(prepared.horizonDescriptor.contaminationState == .isolated)
        #expect(prepared.horizonDescriptor.evidenceState == .caveated)
        #expect(prepared.horizonDescriptor.minimumDurableEvidenceCount == 2)
        #expect(prepared.horizonDescriptor.releaseRequirements.contains("external refresh completes"))
        #expect(
            prepared.horizonDescriptor.releaseRequirements.contains(
                "at least 2 corroborating evidence signals are available"
            )
        )
    }

    @Test("lifecycle review retires reflection before cue at same age")
    func lifecycleReviewRetiresReflectionBeforeReminder() {
        let reviewNow = Date(timeIntervalSince1970: 1_744_156_800)
        let oldDate = Date(timeIntervalSince1970: 1_739_836_800)

        let cueState = BASMemoryGovernance.nextLifecycleState(
            for: BASMemoryLifecycleReviewInput(
                source: .cue,
                evidenceCount: 3,
                decayPolicy: .medium,
                provenanceSummary: "Repeated cue completions confirmed this goal.",
                lastConfirmedAt: oldDate,
                reviewNow: reviewNow
            )
        )
        let reflectionState = BASMemoryGovernance.nextLifecycleState(
            for: BASMemoryLifecycleReviewInput(
                source: .reflection,
                evidenceCount: 3,
                decayPolicy: .medium,
                provenanceSummary: "Single reflective pattern inferred from prior sessions.",
                lastConfirmedAt: oldDate,
                reviewNow: reviewNow
            )
        )

        #expect(cueState != .retired)
        #expect(reflectionState == .retired)
    }

    @Test("brain bootstrap composes current state from governed memories")
    func brainBootstrapComposesCurrentState() {
        let template = BASGovernedMemory(
            kind: .template,
            content: "night cooling",
            scope: .task,
            sensitivity: .low,
            tier: .hot,
            confidence: 0.8,
            sourceType: "system",
            governanceStatus: .governed,
            provenanceSummary: "template"
        )
        let failure = BASGovernedMemory(
            kind: .failurePattern,
            content: "long explanations fail at night",
            scope: .user,
            sensitivity: .high,
            tier: .warm,
            confidence: 0.9,
            sourceType: "reflection",
            governanceStatus: .governed,
            provenanceSummary: "failure"
        )
        let profile = BASGovernedMemory(
            kind: .profile,
            content: "prefer concise answers",
            scope: .user,
            sensitivity: .medium,
            tier: .warm,
            confidence: 0.85,
            sourceType: "user",
            governanceStatus: .governed,
            provenanceSummary: "profile"
        )

        let state = BASCurrentBrainBootstrap.bootstrap(
            from: [template, failure, profile],
            goalHints: ["finish current decision"],
            constraintHints: ["keep it brief"],
            mode: "night",
            verificationSnapshot: "brain-001"
        )

        #expect(state.mode == "night")
        #expect(state.dominantGoals == ["finish current decision", "prefer concise answers"])
        #expect(state.activeConstraints.contains("keep it brief"))
        #expect(state.activeConstraints.contains("sensitive:user"))
        #expect(state.activeTemplateIDs == [template.id])
        #expect(state.recentFailurePatternIDs == [failure.id])
        #expect(state.verificationSnapshot == "brain-001")
        #expect(state.retrievalTags.contains("tier:hot"))
        #expect(state.retrievalTags.contains("kind:template"))
    }

    @Test("host constitution staging records candidate governance markers")
    func hostConstitutionStagingRecordsCandidateGovernanceMarkers() {
        let constitution = BASHostConstitution(
            hostID: "host.constitution",
            activeVersion: "constitution.v1",
            narrativeLoom: BASNarrativeLoom(
                longFormSummary: "Stable but evolving.",
                currentPhase: "stable",
                continuityLinks: ["constitution.v0->constitution.v1"],
                unresolvedTensions: ["existing_tension"]
            )
        )
        let candidate = BASHostChangeCandidate(
            candidateID: "candidate.goal.v2",
            changeType: "goal_spine",
            proposedDelta: ["goal_spine", "boundary_veil"],
            evidenceRefs: ["memory.turn.12"],
            cooldownUntil: Date(timeIntervalSince1970: 1_700_000_000),
            confidence: 0.91,
            conflictRefs: ["boundary.review"],
            previewState: "preview",
            approvalState: "candidate"
        )

        let staged = constitution.staged(with: candidate)

        #expect(staged.narrativeLoom.currentPhase == "preview")
        #expect(
            staged.narrativeLoom.continuityLinks
                == ["constitution.v0->constitution.v1", "constitution.v1->candidate.goal.v2"]
        )
        #expect(
            staged.narrativeLoom.unresolvedTensions
                == [
                    "existing_tension",
                    "candidate:candidate.goal.v2",
                    "candidate_type:goal_spine",
                    "candidate_preview:preview",
                    "candidate_conflict:boundary.review"
                ]
        )
    }

    @Test("host version approval upserts once and preserves rollback reference")
    func hostVersionApprovalUpsertsOnceAndPreservesRollbackReference() {
        let initialTree = BASHostVersionTree(
            activeVersionID: "constitution.v1",
            versions: [
                BASHostVersion(
                    versionID: "constitution.v1",
                    createdAt: Date(timeIntervalSince1970: 1_600_000_000),
                    changedFields: ["identity_lattice"],
                    reason: "bootstrap",
                    approvedByPolicy: true
                )
            ],
            pendingCandidateIDs: ["candidate.goal.v2"]
        )
        let candidate = BASHostChangeCandidate(
            candidateID: "candidate.goal.v2",
            changeType: "goal_spine",
            proposedDelta: ["goal_spine", "goal_spine", "boundary_veil"],
            evidenceRefs: ["memory.turn.12"],
            cooldownUntil: Date(timeIntervalSince1970: 1_700_000_000),
            confidence: 0.91,
            conflictRefs: ["boundary.review"],
            previewState: "preview",
            approvalState: "approved"
        )

        let approved = initialTree.approving(candidate)
        let approvedVersion = approved.versions.first { $0.versionID == "candidate.goal.v2" }

        #expect(approved.activeVersionID == "candidate.goal.v2")
        #expect(approved.pendingCandidateIDs.isEmpty)
        #expect(approved.versions.count == 2)
        #expect(approvedVersion?.changedFields == ["goal_spine", "boundary_veil"])
        #expect(approvedVersion?.rollbackRef == "constitution.v1")
        #expect(approvedVersion?.reason == "goal_spine")
        #expect(approvedVersion?.approvedByPolicy == true)

        let reapproved = approved.approving(candidate)
        #expect(reapproved.versions.count == 2)
    }

    @Test("host version rollback only activates known non-frozen versions")
    func hostVersionRollbackOnlyActivatesKnownNonFrozenVersions() {
        let versionTree = BASHostVersionTree(
            activeVersionID: "constitution.v2",
            versions: [
                BASHostVersion(
                    versionID: "constitution.v1",
                    createdAt: Date(timeIntervalSince1970: 1_600_000_000),
                    changedFields: ["identity_lattice"],
                    reason: "bootstrap",
                    approvedByPolicy: true
                ),
                BASHostVersion(
                    versionID: "constitution.v2",
                    createdAt: Date(timeIntervalSince1970: 1_700_000_000),
                    changedFields: ["goal_spine"],
                    reason: "goal_spine",
                    rollbackRef: "constitution.v1",
                    approvedByPolicy: true
                )
            ],
            frozenVersionIDs: ["constitution.v1"]
        )

        #expect(versionTree.rollingBack(to: "missing.version").activeVersionID == "constitution.v2")
        #expect(versionTree.rollingBack(to: "constitution.v1").activeVersionID == "constitution.v2")
        #expect(versionTree.rollingBack(to: "constitution.v2").activeVersionID == "constitution.v2")
    }

    @Test("host version tree can freeze and thaw inactive versions without duplicating markers")
    func hostVersionTreeCanFreezeAndThawInactiveVersionsWithoutDuplicatingMarkers() {
        let versionTree = BASHostVersionTree(
            activeVersionID: "constitution.v2",
            versions: [
                BASHostVersion(
                    versionID: "constitution.v1",
                    createdAt: Date(timeIntervalSince1970: 1_600_000_000),
                    changedFields: ["identity_lattice"],
                    reason: "bootstrap",
                    approvedByPolicy: true
                ),
                BASHostVersion(
                    versionID: "constitution.v2",
                    createdAt: Date(timeIntervalSince1970: 1_700_000_000),
                    changedFields: ["goal_spine"],
                    reason: "goal_spine",
                    rollbackRef: "constitution.v1",
                    approvedByPolicy: true
                )
            ]
        )

        let frozen = versionTree.freezing(versionID: "constitution.v1")
        let duplicateFreeze = frozen.freezing(versionID: "constitution.v1")
        let missingFreeze = frozen.freezing(versionID: "missing.version")
        let activeFreeze = frozen.freezing(versionID: "constitution.v2")
        let thawed = frozen.thawing(versionID: "constitution.v1")

        #expect(frozen.frozenVersionIDs == ["constitution.v1"])
        #expect(duplicateFreeze.frozenVersionIDs == ["constitution.v1"])
        #expect(missingFreeze.frozenVersionIDs == ["constitution.v1"])
        #expect(activeFreeze.frozenVersionIDs == ["constitution.v1"])
        #expect(thawed.frozenVersionIDs.isEmpty)
        #expect(thawed.rollingBack(to: "constitution.v1").activeVersionID == "constitution.v1")
    }

    @Test("forget request executes the canonical five-stage cascade once")
    func forgetRequestExecutesTheCanonicalFiveStageCascadeOnce() {
        let request = BASForgetRequest(
            requestID: "forget.v1",
            targetRefs: ["memory.turn.12"],
            cascadeScope: ["active_version", "projection_cache", "memory_refs", "checkpoints", "sync"],
            executedSteps: ["active_version_removed", "operator_logged"],
            verified: false
        )

        let executed = request.executingCanonicalCascade()

        #expect(
            executed.executedSteps
                == [
                    "active_version_removed",
                    "operator_logged",
                    "projection_cache_cleared",
                    "memory_refs_detached",
                    "checkpoint_exports_revoked",
                    "sync_exports_revoked"
                ]
        )
        #expect(executed.verified)

        let executedTwice = executed.executingCanonicalCascade()
        #expect(executedTwice.executedSteps == executed.executedSteps)
    }

    @Test("host constitution vault stages migration and settles once device sync completes")
    func hostConstitutionVaultStagesMigrationAndSettlesOnceDeviceSyncCompletes() {
        let constitution = BASHostConstitution(
            hostID: "host.constitution",
            activeVersion: "constitution.v2",
            consentLattice: BASConsentLattice(
                syncScope: "approved_sync"
            )
        )
        let forgetRequest = BASForgetRequest(
            requestID: "forget.v2",
            targetRefs: ["memory.private_notes"],
            cascadeScope: ["sync"],
            executedSteps: ["sync_exports_revoked"],
            verified: true
        )
        let baseVault = constitution
            .vaultSnapshot(
                sourceDeviceID: "device.primary",
                trustedDeviceIDs: ["device.primary"]
            )
            .applyingForget(forgetRequest)
        let migrationContract = BASHostDeviceMigrationContract(
            sourceDeviceID: "device.primary",
            targetDeviceID: "device.secondary",
            allowedScopes: ["constitution_snapshot", "goal_spine"],
            requiresExplicitApproval: true,
            rollbackVersionID: "constitution.v1",
            exportInvalidationRefs: ["sync_exports:forget.v2"]
        )

        let staged = baseVault.stagingMigration(migrationContract)
        let approved = staged.approvingMigration(targetDeviceID: "device.secondary")
        let synchronized = approved.synchronizingDevice(
            "device.secondary",
            propagatedRequestIDs: ["forget.v2"],
            synchronizedAt: Date(timeIntervalSince1970: 1_710_000_000)
        )

        #expect(staged.deviceConsistencyReport.consistencyState == "migration_pending")
        #expect(staged.deviceConsistencyReport.outOfSyncDeviceIDs == ["device.secondary"])
        #expect(staged.verificationMarkers.contains("vault_migration_target:device.secondary"))
        #expect(staged.verificationMarkers.contains("vault_out_of_sync_devices:1"))

        #expect(approved.deviceConsistencyReport.consistencyState == "out_of_sync")
        #expect(approved.migrationContract?.requiresExplicitApproval == false)

        #expect(synchronized.deviceConsistencyReport.consistencyState == "consistent")
        #expect(synchronized.deviceConsistencyReport.trustedDeviceIDs == ["device.primary", "device.secondary"])
        #expect(synchronized.deviceConsistencyReport.outOfSyncDeviceIDs.isEmpty)
        #expect(synchronized.syncRevocationLedger.revokedDeviceIDs == ["device.secondary"])
        #expect(synchronized.deletionManifest?.pendingPropagationRefs.isEmpty == true)
        #expect(synchronized.migrationContract == nil)
        #expect(synchronized.verificationMarkers.contains("vault_migration_target:device.secondary") == false)
    }
}
