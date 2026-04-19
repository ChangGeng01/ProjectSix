import Foundation
import Testing
@testable import BASHostKit
@testable import BASOrchestration
@testable import BASOrchestration

@Suite("BASEBrain schemas")
struct BASEBrainSchemaCoreTests {
    @Test("update ticket prioritizes structured constitution host change candidates and decodes legacy payloads")
    func updateTicketPrefersStructuredHostChangeCandidateAndDecodesLegacyPayload() throws {
        let candidate = BASHostChangeCandidate(
            candidateID: "candidate.host_gate",
            changeType: "review_host_gate_strength",
            proposedDelta: ["host_gate_strength"],
            evidenceRefs: ["calibration:drifting"],
            cooldownUntil: Date(timeIntervalSince1970: 1_700_000_123),
            confidence: 0.84,
            previewState: "review_only",
            approvalState: "pending"
        )
        let ticket = BASUpdateTicket(
            ticketID: "ticket-host-change",
            sessionRef: "session-host-change",
            summary: "Review host governance before promotion.",
            memoryWriteSuggestion: "Persist as warm memory.",
            hostChangeCandidate: candidate,
            hostProfileChangeSuggestion: "Always use the hardest tone.",
            confidence: 0.84,
            conflictFlag: true
        )

        #expect(ticket.hasPersistentMutationSuggestion)
        #expect(
            ticket.reviewDirectiveLine
            == "Review host change: review_host_gate_strength • host_gate_strength • conflict flagged"
        )
        #expect(ticket.actionDigestParts.contains("candidate.host_gate"))
        #expect(ticket.actionDigestParts.contains("review_host_gate_strength"))

        let legacyPayload = """
        {
          "schemaVersion":"1.0.0",
          "ticketID":"ticket-legacy",
          "sessionRef":"session-legacy",
          "summary":"Legacy host profile suggestion.",
          "memoryWriteSuggestion":null,
          "hostProfileChangeSuggestion":"Always use the hardest tone.",
          "ruleCandidateRef":null,
          "confidence":0.73,
          "conflictFlag":false,
          "requiresReview":true
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(BASUpdateTicket.self, from: legacyPayload)
        #expect(decoded.hostChangeCandidate == nil)
        #expect(decoded.hostProfileChangeSuggestion == "Always use the hardest tone.")
        #expect(decoded.reviewDirectiveLine == "Review host change: Always use the hardest tone.")
    }

    @Test("new control, knowledge, cognition, and observation schemas publish stable current versions")
    func schemasExposeStableCurrentVersion() {
        let device = BASDeviceState(
            batteryLevel: 0.62,
            thermalLevel: .warm,
            memoryFreeMB: 2048,
            networkState: .online,
            foregroundState: .foreground,
            cpuLoad: 0.41,
            gpuLoad: 0.12,
            npuAvailable: true,
            latencyBudgetMs: 1200
        )
        let budget = BASBudgetFrame.guardedLocal()
        let host = BASHostProfile(hostID: "host.primary")
        let atom = BASMemoryAtom(
            memoryID: "mem-1",
            summary: "Protect long-term boundaries.",
            contentType: .warm,
            source: "ticket",
            confidence: 0.81,
            conflictFingerprint: "fp-1"
        )
        let thought = BASThoughtFrame(stepIndex: 1, decomposeRef: "decomp-1")
        let risk = BASRiskCard(
            totalRisk: 0.83,
            riskLevel: .high,
            factors: ["irreversible", "manipulation"],
            uncertainty: 0.42,
            irreversibility: 0.88,
            manipulationStrength: 0.61,
            gsiScore: 0.57,
            recommendedMode: .delay
        )
        let ticket = BASUpdateTicket(
            ticketID: "ticket-1",
            sessionRef: "session-1",
            summary: "Delay and gather evidence before acting.",
            confidence: 0.76
        )
        let wakeIntent = BASWakeIntent(
            intentLevel: .guard,
            estimatedValue: 0.84,
            estimatedRisk: 0.91,
            estimatedCost: 0.44,
            preferredMode: .guard
        )
        let vitalState = BASVitalState(
            wakeState: .guard,
            survivalMargin: 0.62,
            thermalMargin: 0.48,
            powerMargin: 0.56,
            continuityScore: 0.71,
            stabilityScore: 0.69
        )
        let runLease = BASRunLease(
            leaseID: "lease-1",
            sessionID: "session-1",
            turnID: "turn-1",
            allowedMode: .deepLoop,
            maxLoops: 3,
            maxMs: 1_600,
            maxEnergyQuota: 0.72,
            validHeads: ["risk_gate", "render"],
            expiresAt: Date(timeIntervalSince1970: 1_705_000_000)
        )
        let emergencyBrake = BASEmergencyBrake(
            brakeLevel: .guard,
            reasonCodes: ["risk.high"],
            forcedMode: .guard
        )
        let sovereign = BASSovereignActuationCommand(
            commandID: "sovereign-1",
            kind: .guardShift,
            reasonCodes: ["risk.high"],
            issuedAt: Date(timeIntervalSince1970: 1_705_000_000),
            forcedMode: .guard
        )
        let sovereignReceipt = BASSovereignExecutionReceipt(
            commandID: sovereign.commandID,
            kind: sovereign.kind,
            status: .executed,
            executedAt: Date(timeIntervalSince1970: 1_705_000_012),
            latencyMs: 12,
            enforcedMode: .guard,
            reasonCodes: sovereign.reasonCodes
        )
        let policyLineage = BASRuntimePolicyLineage(
            bundleVersion: "policy.bundle.v1",
            providerRoutingRegistryVersion: "provider.registry.v1",
            providerRoutingPolicyID: "provider.default",
            runtimeTuningRegistryVersion: "runtime.registry.v1",
            runtimeTuningPolicyID: "runtime.default",
            resolutionSourceID: "bundled_default"
        )
        let sovereignVerdict = BASSovereignVerdict(
            verdictID: "verdict-1",
            verdictLevel: .memoryFreeze,
            latched: true,
            forcedMode: .guard,
            reasonCodes: ["writes.review_required"],
            revokedPermissions: [.memoryWriteHot, .memoryWriteWarm, .memoryWriteCold],
            quarantineRefs: ["session-1"],
            rollbackRef: "snapshot-1",
            userStubMode: .minimalReceipt,
            auditRef: "audit-1",
            policyHash: "policy-hash-1",
            expiresAt: Date(timeIntervalSince1970: 1_705_000_060)
        )
        let sovereignToken = BASSovereignCommitToken(
            tokenID: "token-1",
            sessionID: "session-1",
            turnID: "turn-1",
            scope: .memoryWrite,
            allowedTargets: ["ticket-1"],
            actionDigest: "digest-1",
            snapshotRef: "snapshot-1",
            policyHash: "policy-hash-1",
            ttlMs: 30_000,
            nonce: "nonce-1",
            singleUse: true,
            signature: "signature-1"
        )
        let sovereignLock = BASSovereignLock(
            lockID: "lock-1",
            scope: .session,
            lockLevel: .memoryFreeze,
            createdAt: Date(timeIntervalSince1970: 1_705_000_030),
            releaseCondition: "governance_review_required"
        )
        let quarantineRecord = BASQuarantineRecord(
            quarantineID: "quarantine-1",
            zone: .memory,
            sourceRef: "memory-1",
            reasonCodes: ["writes.review_required"],
            isolatedAt: Date(timeIntervalSince1970: 1_705_000_040),
            releasePolicy: "manual_review",
            reviewState: .held
        )
        let sovereignAuditEntry = BASSovereignAuditEntry(
            auditID: "audit-1",
            sessionID: "session-1",
            turnID: "turn-1",
            verdictRef: sovereignVerdict.verdictID,
            ruleIDs: ["BR-SOV-003"],
            signalRefs: ["writes.review_required"],
            actionRefs: [sovereignToken.tokenID],
            snapshotRef: "snapshot-1",
            actor: .system,
            signature: "audit-signature-1",
            appendedAt: Date(timeIntervalSince1970: 1_705_000_050)
        )
        let hostRhythm = BASHostRhythmProfile(
            activeWindows: ["morning_focus"],
            highFocusWindows: ["afternoon_deep_work"],
            lowEnergyWindows: ["late_evening"],
            preferredInteractionStyle: "bounded_reflective",
            sensitivityPeriods: ["sleep_boundary"]
        )
        let constitution = BASHostConstitution(
            hostID: "host.primary",
            activeVersion: "constitution.v2",
            identityLattice: BASIdentityLattice(
                coreTags: ["writer", "founder"],
                stageTags: ["rebuild"],
                continuityScore: 0.88,
                conflictPoints: ["speed_vs_stability"],
                stableCenter: "protect the long arc"
            ),
            valueAxes: BASValueAxisSet(
                axes: ["stability", "privacy", "craft"],
                relativeWeights: [0.92, 0.87, 0.75],
                conflictRules: ["stability_over_speed"],
                updateThreshold: 0.72
            ),
            goalSpine: BASGoalSpine(
                goals: ["ship_l5", "preserve_sovereignty"],
                hierarchy: ["ship_l5": ["preserve_sovereignty"]],
                priorityOrder: ["preserve_sovereignty", "ship_l5"],
                conflictPairs: ["speed|safety"],
                stageState: "active"
            ),
            boundaryVeil: BASBoundaryVeil(
                hardNoGo: ["unsafe_override"],
                softCaution: ["high_pressure"],
                confirmRequired: ["cross_device_sync"],
                restrictedMemoryDomains: ["private_journal"],
                restrictedToolDomains: ["tool.write.external"]
            ),
            relationGravity: BASRelationGravityMap(
                nodes: ["cofounder", "family"],
                edgeTypes: ["critical", "anchor"],
                gravityWeights: [0.92, 0.89],
                communicationModes: ["direct", "gentle"],
                highConsequenceLinks: ["cofounder"]
            ),
            rhythmCanopy: BASRhythmCanopy(
                activeWindows: ["morning"],
                focusWindows: ["deep_work"],
                lowEnergyWindows: ["late_night"],
                reminderTolerance: "gentle",
                cadencePreferences: ["batching"]
            ),
            styleGenome: BASStyleGenome(
                density: "dense",
                warmth: "warm",
                structureBias: 0.91,
                brevityBias: 0.42,
                metaphorBias: 0.38,
                comparisonBias: 0.84,
                revisionStyle: "iterative"
            ),
            routineSkeleton: BASRoutineSkeleton(
                workflowTemplates: ["triage", "two-path compare"],
                taskDecompositionModes: ["outline_first"],
                reminderPatterns: ["soft_nudge"],
                planningCadences: ["weekly_reset"]
            ),
            consentLattice: BASConsentLattice(
                memoryWriteScope: "warm_only",
                memoryPromotionScope: "review_required",
                hostMutationScope: "candidate_only",
                toolReadScope: "local_only",
                toolWriteScope: "confirm_required",
                syncScope: "disabled",
                sensitiveDomainRules: ["health.manual_only"]
            ),
            narrativeLoom: BASNarrativeLoom(
                longFormSummary: "A host rebuilding slowly without surrendering boundaries.",
                currentPhase: "rebuild",
                continuityLinks: ["phase.rebuild->phase.launch"],
                unresolvedTensions: ["speed_vs_reliability"]
            ),
            protectionRing: BASProtectionRing(
                sensitiveDomains: ["identity", "relationship"],
                emotionalPollutionZones: ["burnout"],
                escalationRules: ["high_emotion_requires_cooldown"],
                exploitationShields: ["no_dependency_loops"]
            )
        )
        let constitutionVersionTree = BASHostVersionTree(
            activeVersionID: constitution.activeVersion,
            versions: [
                BASHostVersion(
                    versionID: "constitution.v1",
                    changedFields: ["styleGenome"],
                    reason: "bootstrap",
                    approvedByPolicy: true
                ),
                BASHostVersion(
                    versionID: "constitution.v2",
                    changedFields: ["goalSpine", "boundaryVeil"],
                    reason: "reviewed update",
                    rollbackRef: "constitution.v1",
                    approvedByPolicy: true
                )
            ],
            pendingCandidateIDs: ["candidate-1"],
            frozenVersionIDs: ["constitution.v1"]
        )
        let changeCandidate = BASHostChangeCandidate(
            candidateID: "candidate-1",
            changeType: "goal_spine.update",
            proposedDelta: ["add_goal:ship_l5"],
            evidenceRefs: ["turn.12", "turn.13"],
            cooldownUntil: Date(timeIntervalSince1970: 1_705_000_120),
            confidence: 0.81,
            conflictRefs: ["boundary.review"],
            previewState: "previewing",
            approvalState: "pending"
        )
        let forgetRequest = BASForgetRequest(
            requestID: "forget-1",
            targetRefs: ["memory.private_journal"],
            cascadeScope: ["active_version", "projection_cache"],
            executedSteps: ["active_version_removed"],
            verified: false
        )
        let deletionManifest = BASHostDeletionManifest(
            requestID: "forget-1",
            targetRefs: ["memory.private_journal"],
            revokedProjectionRefs: ["projection.private_journal"],
            invalidatedExportRefs: ["sync_exports:forget-1"],
            pendingPropagationRefs: ["sync_exports:forget-1"],
            verified: false
        )
        let syncRevocationLedger = BASHostSyncRevocationLedger(
            revokedRequestIDs: ["forget-1"],
            revokedDeviceIDs: ["device.secondary"],
            revokedExportRefs: ["sync_exports:forget-1"],
            localOnlyPreferred: true
        )
        let deviceConsistencyReport = BASHostDeviceConsistencyReport(
            sourceDeviceID: "device.primary",
            trustedDeviceIDs: ["device.primary", "device.secondary"],
            revokedDeviceIDs: ["device.secondary"],
            consistencyState: "revocation_pending",
            requiresExplicitApproval: true
        )
        let migrationContract = BASHostDeviceMigrationContract(
            sourceDeviceID: "device.primary",
            targetDeviceID: "device.secondary",
            allowedScopes: ["constitution_snapshot"],
            requiresExplicitApproval: true,
            rollbackVersionID: "constitution.v1",
            exportInvalidationRefs: ["sync_exports:forget-1"]
        )
        let constitutionVault = BASHostConstitutionVault(
            constitutionSnapshot: constitution,
            deletionManifest: deletionManifest,
            rollbackLineage: ["constitution.v1", "constitution.v2"],
            exportInvalidationManifest: ["sync_exports:forget-1"],
            syncRevocationLedger: syncRevocationLedger,
            deviceConsistencyReport: deviceConsistencyReport,
            migrationContract: migrationContract
        )
        let recoveryDisposition = BASRecoveryDisposition(
            kind: .recovery,
            summary: "Bootstrap fallback forced the turn into recovery.",
            reasonCodes: ["runtime.recovery"],
            remediationRequired: true,
            restrictedLease: true,
            toolWriteAllowed: false,
            memoryWriteAllowed: false
        )

        #expect(device.schemaVersion == BASDeviceState.currentSchemaVersion)
        #expect(budget.schemaVersion == BASBudgetFrame.currentSchemaVersion)
        #expect(wakeIntent.schemaVersion == BASWakeIntent.currentSchemaVersion)
        #expect(vitalState.schemaVersion == BASVitalState.currentSchemaVersion)
        #expect(runLease.schemaVersion == BASRunLease.currentSchemaVersion)
        #expect(emergencyBrake.schemaVersion == BASEmergencyBrake.currentSchemaVersion)
        #expect(sovereign.schemaVersion == BASSovereignActuationCommand.currentSchemaVersion)
        #expect(sovereignReceipt.schemaVersion == BASSovereignExecutionReceipt.currentSchemaVersion)
        #expect(policyLineage.schemaVersion == BASRuntimePolicyLineage.currentSchemaVersion)
        #expect(sovereignVerdict.schemaVersion == BASSovereignVerdict.currentSchemaVersion)
        #expect(sovereignToken.schemaVersion == BASSovereignCommitToken.currentSchemaVersion)
        #expect(sovereignLock.schemaVersion == BASSovereignLock.currentSchemaVersion)
        #expect(quarantineRecord.schemaVersion == BASQuarantineRecord.currentSchemaVersion)
        #expect(sovereignAuditEntry.schemaVersion == BASSovereignAuditEntry.currentSchemaVersion)
        #expect(hostRhythm.schemaVersion == BASHostRhythmProfile.currentSchemaVersion)
        #expect(constitution.schemaVersion == BASHostConstitution.currentSchemaVersion)
        #expect(constitution.identityLattice.schemaVersion == BASIdentityLattice.currentSchemaVersion)
        #expect(constitution.valueAxes.schemaVersion == BASValueAxisSet.currentSchemaVersion)
        #expect(constitution.goalSpine.schemaVersion == BASGoalSpine.currentSchemaVersion)
        #expect(constitution.boundaryVeil.schemaVersion == BASBoundaryVeil.currentSchemaVersion)
        #expect(constitution.relationGravity.schemaVersion == BASRelationGravityMap.currentSchemaVersion)
        #expect(constitution.rhythmCanopy.schemaVersion == BASRhythmCanopy.currentSchemaVersion)
        #expect(constitution.styleGenome.schemaVersion == BASStyleGenome.currentSchemaVersion)
        #expect(constitution.routineSkeleton.schemaVersion == BASRoutineSkeleton.currentSchemaVersion)
        #expect(constitution.consentLattice.schemaVersion == BASConsentLattice.currentSchemaVersion)
        #expect(constitution.narrativeLoom.schemaVersion == BASNarrativeLoom.currentSchemaVersion)
        #expect(constitution.protectionRing.schemaVersion == BASProtectionRing.currentSchemaVersion)
        #expect(constitutionVersionTree.schemaVersion == BASHostVersionTree.currentSchemaVersion)
        #expect(changeCandidate.schemaVersion == BASHostChangeCandidate.currentSchemaVersion)
        #expect(forgetRequest.schemaVersion == BASForgetRequest.currentSchemaVersion)
        #expect(deletionManifest.schemaVersion == BASHostDeletionManifest.currentSchemaVersion)
        #expect(syncRevocationLedger.schemaVersion == BASHostSyncRevocationLedger.currentSchemaVersion)
        #expect(deviceConsistencyReport.schemaVersion == BASHostDeviceConsistencyReport.currentSchemaVersion)
        #expect(migrationContract.schemaVersion == BASHostDeviceMigrationContract.currentSchemaVersion)
        #expect(constitutionVault.schemaVersion == BASHostConstitutionVault.currentSchemaVersion)
        #expect(recoveryDisposition.schemaVersion == BASRecoveryDisposition.currentSchemaVersion)
        #expect(host.schemaVersion == BASHostProfile.currentSchemaVersion)
        #expect(atom.schemaVersion == BASMemoryAtom.currentSchemaVersion)
        #expect(thought.schemaVersion == BASThoughtFrame.currentSchemaVersion)
        #expect(risk.schemaVersion == BASRiskCard.currentSchemaVersion)
        #expect(ticket.schemaVersion == BASUpdateTicket.currentSchemaVersion)
    }

    @Test("host constitution safely projects into runtime host profile and rhythm profile")
    func hostConstitutionProjectsIntoCompatibilityProfiles() {
        let constitution = BASHostConstitution(
            hostID: "host.l5",
            activeVersion: "constitution.v3",
            identityLattice: BASIdentityLattice(
                coreTags: ["builder", "guardian"],
                stageTags: ["migration"],
                continuityScore: 0.93,
                conflictPoints: ["speed_vs_safety"],
                stableCenter: "preserve agency"
            ),
            valueAxes: BASValueAxisSet(
                axes: ["privacy", "stability", "craft"],
                relativeWeights: [0.95, 0.91, 0.77],
                conflictRules: ["privacy_over_speed"],
                updateThreshold: 0.74
            ),
            goalSpine: BASGoalSpine(
                goals: ["evolve_l5", "protect_boundary"],
                hierarchy: ["evolve_l5": ["protect_boundary"]],
                priorityOrder: ["protect_boundary", "evolve_l5"],
                conflictPairs: ["speed|safety"],
                stageState: "migration"
            ),
            boundaryVeil: BASBoundaryVeil(
                hardNoGo: ["unsafe_override"],
                softCaution: ["high_pressure_request"],
                confirmRequired: ["tool.write.external"],
                restrictedMemoryDomains: ["private_notes"],
                restrictedToolDomains: ["remote_write"]
            ),
            relationGravity: BASRelationGravityMap(
                nodes: ["partner", "team"],
                edgeTypes: ["anchor", "critical"],
                gravityWeights: [0.97, 0.83],
                communicationModes: ["gentle", "direct"],
                highConsequenceLinks: ["partner"]
            ),
            rhythmCanopy: BASRhythmCanopy(
                activeWindows: ["morning_focus"],
                focusWindows: ["afternoon_deep_work"],
                lowEnergyWindows: ["late_evening"],
                reminderTolerance: "soft",
                cadencePreferences: ["weekly_review", "paired_paths"]
            ),
            styleGenome: BASStyleGenome(
                density: "high",
                warmth: "warm",
                structureBias: 0.94,
                brevityBias: 0.31,
                metaphorBias: 0.41,
                comparisonBias: 0.88,
                revisionStyle: "layered"
            ),
            routineSkeleton: BASRoutineSkeleton(
                workflowTemplates: ["compare_then_commit", "audit_before_ship"],
                taskDecompositionModes: ["structure_first"],
                reminderPatterns: ["gentle_escalation"],
                planningCadences: ["weekly_reset"]
            ),
            consentLattice: BASConsentLattice(
                memoryWriteScope: "warm_only",
                memoryPromotionScope: "review_required",
                hostMutationScope: "constitution_candidate_only",
                toolReadScope: "local_confirmed",
                toolWriteScope: "manual_confirm",
                syncScope: "local_only",
                sensitiveDomainRules: ["relationship.no_autoinfer"]
            ),
            narrativeLoom: BASNarrativeLoom(
                longFormSummary: "This host wants a stable but still evolving electronic brain.",
                currentPhase: "migration",
                continuityLinks: ["v2->v3"],
                unresolvedTensions: ["speed_vs_depth"]
            ),
            protectionRing: BASProtectionRing(
                sensitiveDomains: ["identity", "attachment"],
                emotionalPollutionZones: ["crash_state"],
                escalationRules: ["cooldown_before_major_update"],
                exploitationShields: ["never_intensify_dependency"]
            )
        )

        let projectedHost = constitution.projectedHostProfile(
            riskThresholds: BASHostRiskThresholds(caution: 0.37, protective: 0.63, block: 0.85)
        )
        let projectedRhythm = constitution.projectedHostRhythmProfile()

        #expect(projectedHost.hostID == "host.l5")
        #expect(projectedHost.activeVersion == "constitution.v3")
        #expect(projectedHost.identityTags == ["builder", "guardian", "migration"])
        #expect(projectedHost.tonePreference == "warm_high")
        #expect(projectedHost.longTermGoals == ["evolve_l5", "protect_boundary"])
        #expect(projectedHost.noGoZones.contains("unsafe_override"))
        #expect(projectedHost.noGoZones.contains("high_pressure_request"))
        #expect(projectedHost.noGoZones.contains("tool.write.external"))
        #expect(projectedHost.relationshipRefs == ["partner", "team"])
        #expect(projectedHost.workRoutines == ["compare_then_commit", "audit_before_ship"])
        #expect(projectedHost.styleConstraints.contains("structure_bias:0.94"))
        #expect(projectedHost.styleConstraints.contains("revision:layered"))
        #expect(projectedHost.memoryPermissions.allowHotWrites == true)
        #expect(projectedHost.memoryPermissions.allowWarmWrites == true)
        #expect(projectedHost.memoryPermissions.allowColdWrites == false)
        #expect(projectedHost.memoryPermissions.requireReviewForColdWrites == true)
        #expect(projectedHost.updatePolicy.requiresReview == true)
        #expect(projectedHost.updatePolicy.allowsRollback == true)
        #expect(projectedHost.updatePolicy.allowsDelete == true)
        #expect(projectedHost.updatePolicy.allowsFreeze == true)
        #expect(projectedHost.riskThresholds == BASHostRiskThresholds(caution: 0.37, protective: 0.63, block: 0.85))

        #expect(projectedRhythm.activeWindows == ["morning_focus"])
        #expect(projectedRhythm.highFocusWindows == ["afternoon_deep_work"])
        #expect(projectedRhythm.lowEnergyWindows == ["late_evening"])
        #expect(projectedRhythm.preferredInteractionStyle == "soft")
        #expect(projectedRhythm.sensitivityPeriods == ["crash_state"])
    }

    @Test("neural fabric schemas publish stable current versions")
    func neuralFabricSchemasExposeStableCurrentVersion() {
        let organMap = BASNeuralOrganMap(
            morph: .guard,
            activeOrgans: [.riskSpine, .permitKnot, .consistencyLattice, .stubCore, .tissueRouter],
            precisionMap: [
                BASNeuralOrganPrecision(organ: .riskSpine, tier: .protected),
                BASNeuralOrganPrecision(organ: .permitKnot, tier: .protected),
                BASNeuralOrganPrecision(organ: .stubCore, tier: .full)
            ],
            routingPolicy: .protectiveThrottle,
            leaseRef: "lease-1",
            sovereignConstraints: ["memory_freeze", "tool_cut"],
            headGuarantees: ["risk_binding", "stub_ready"]
        )
        let frontier = BASCandidateFrontier(
            candidateIDs: ["c-1", "c-2"],
            dominanceOrder: ["c-1", "c-2"],
            reversiblePaths: ["c-1"],
            guardPaths: ["c-2"],
            frontierWidth: 2
        )
        let counterfactual = BASCounterfactualBundle(
            candidateID: "c-1",
            shortTerm: "Short-term stabilization.",
            midTerm: "Mid-term bounded recovery.",
            worstCase: "Temporary friction remains.",
            uncertainty: 0.28,
            affectedDomains: ["relationship", "energy"]
        )
        let critiqueBundle = BASCritiqueBundle(
            candidateID: "c-1",
            evidenceGap: 0.32,
            manipulationRisk: 0.24,
            emotionalBias: 0.18,
            boundaryConflict: 0.41,
            critiqueStrength: 0.41
        )
        let binding = BASRiskPermitBinding(
            candidateID: "c-1",
            riskLevel: .high,
            totalRisk: 0.74,
            uncertainty: 0.33,
            irreversibility: 0.61,
            manipulationStrength: 0.42,
            gsiScore: 0.55,
            recommendedMode: .delay,
            permitMode: .delay,
            requireSecondCheck: true,
            outputLengthCap: 160,
            tonePolicy: "calm_guarded",
            templatePolicy: "delay_with_alternative",
            reasonCodes: ["risk.high"],
            allowedDomains: ["bounded_reply"],
            forbiddenDomains: ["tool_commit"]
        )
        let leaseReceipt = BASNeuralLeaseReceipt(
            leaseID: "lease-1",
            organsUsed: [.riskSpine, .permitKnot, .stubCore],
            loopsUsed: 1,
            energyUsed: 0.14,
            decodeTokensUsed: 96,
            degraded: false
        )
        let toolIntent = BASToolIntentEnvelope(
            intentID: "tool-intent.c-1.answer",
            candidateID: "c-1",
            permitMode: .answer,
            summary: "Send a short reply.",
            requestedDomains: ["bounded_reply", "plain_language"],
            blockedDomains: [],
            requireSecondCheck: false,
            tonePolicy: "steady",
            templatePolicy: "answer",
            reasonCodes: ["binding.primary_candidate"],
            sovereignBound: false
        )

        #expect(organMap.schemaVersion == BASNeuralOrganMap.currentSchemaVersion)
        #expect(frontier.schemaVersion == BASCandidateFrontier.currentSchemaVersion)
        #expect(counterfactual.schemaVersion == BASCounterfactualBundle.currentSchemaVersion)
        #expect(critiqueBundle.schemaVersion == BASCritiqueBundle.currentSchemaVersion)
        #expect(binding.schemaVersion == BASRiskPermitBinding.currentSchemaVersion)
        #expect(toolIntent.schemaVersion == BASToolIntentEnvelope.currentSchemaVersion)
        #expect(leaseReceipt.schemaVersion == BASNeuralLeaseReceipt.currentSchemaVersion)
    }

    @Test("folded lung v2 schemas publish stable current versions")
    func foldedLungSchemasExposeStableCurrentVersion() {
        let morphGraph = BASMorphGraph(
            graphID: "graph-1",
            activeOrgans: [.riskSpine, .permitKnot, .stubCore],
            executionOrder: ["riskSpine", "permitKnot", "stubCore"],
            precisionMap: [
                BASNeuralOrganPrecision(organ: .riskSpine, tier: .protected),
                BASNeuralOrganPrecision(organ: .permitKnot, tier: .protected),
                BASNeuralOrganPrecision(organ: .stubCore, tier: .full)
            ],
            deviceRouteMap: [
                "riskSpine": "guarded",
                "permitKnot": "guarded",
                "stubCore": "guarded"
            ],
            thermalProfile: ["warm", "watch"],
            sovereignConstraints: ["tool_cut", "memory_freeze"]
        )
        let precisionProfile = BASPrecisionProfile(
            organPrecisions: [
                BASNeuralOrganPrecision(organ: .riskSpine, tier: .protected),
                BASNeuralOrganPrecision(organ: .permitKnot, tier: .protected),
                BASNeuralOrganPrecision(organ: .stubCore, tier: .full)
            ],
            lockedPrecisions: [.riskSpine, .permitKnot, .stubCore],
            degradationOrder: [.full, .protected, .balanced, .minimal],
            guardSafeFloor: .protected
        )
        let hotColdMap = BASHotColdMap(
            hotOrgans: [.stubCore, .riskSpine, .permitKnot],
            warmOrgans: [.memoryCodecRidge, .hostModulationMesh],
            coldOrgans: [.simuRing, .criticBlade, .toolIntentMesh],
            preloadPolicy: "guard_preload",
            evictionPolicy: "protective_retain"
        )
        let resumeFrame = BASResumeFrame(
            resumeID: "resume-1",
            sourceFoldID: "fold-1",
            resumeDepth: 2,
            requiredOrgans: [.riskSpine, .permitKnot, .stubCore],
            consistencyChecks: ["fold_checksum", "risk_permit", "host_gate"],
            fallbackMode: .rollbackAnchor
        )
        let rollbackAnchor = BASRollbackAnchor(
            anchorID: "anchor-1",
            safeSnapshotRef: "snapshot-1",
            foldRefs: ["fold-1"],
            hostVersionRef: "host.v1",
            cacheStateRef: "cache-1",
            integrityHash: "hash-1"
        )
        let lungState = BASLungState(
            breathMode: .guard,
            breathPhase: .resume,
            thermalPressure: 72,
            cachePressure: 46,
            restoreReadiness: 0.91,
            rollbackAnchorRef: rollbackAnchor.anchorID
        )
        #expect(morphGraph.schemaVersion == BASMorphGraph.currentSchemaVersion)
        #expect(hotColdMap.schemaVersion == BASHotColdMap.currentSchemaVersion)
        #expect(precisionProfile.schemaVersion == BASPrecisionProfile.currentSchemaVersion)
        #expect(resumeFrame.schemaVersion == BASResumeFrame.currentSchemaVersion)
        #expect(rollbackAnchor.schemaVersion == BASRollbackAnchor.currentSchemaVersion)
        #expect(lungState.schemaVersion == BASLungState.currentSchemaVersion)
    }

    @Test("thought frame and fold decode legacy payloads without neural fabric fields")
    func thoughtSchemasBackwardDecodeWithoutNeuralFabricFields() throws {
        let legacyThoughtJSON = """
        {
          "schemaVersion": "1.0.0",
          "stepIndex": 1,
          "decomposeRef": "decomp-1",
          "memoryRefs": ["m-1"],
          "candidates": [],
          "forecasts": [],
          "critiques": [],
          "triScores": [],
          "stabilityScore": 0.64,
          "stopReason": "candidateStable"
        }
        """.data(using: .utf8)!
        let legacyFoldJSON = """
        {
          "schemaVersion": "1.0.0",
          "foldID": "fold-1",
          "compactSlots": {
            "task_type": "conflict"
          },
          "candidateSignatures": ["path.direct"],
          "hostEffectSummary": "Host aligned.",
          "restorePointer": "restore-1",
          "checksum": "checksum-1"
        }
        """.data(using: .utf8)!

        let decodedThought = try JSONDecoder().decode(BASThoughtFrame.self, from: legacyThoughtJSON)
        let decodedFold = try JSONDecoder().decode(BASThoughtFold.self, from: legacyFoldJSON)

        #expect(decodedThought.organMap == nil)
        #expect(decodedThought.candidateFrontier == nil)
        #expect(decodedThought.counterfactualBundles == nil)
        #expect(decodedThought.critiqueBundles == nil)
        #expect(decodedThought.riskBindings == nil)
        #expect(decodedThought.toolIntentEnvelope == nil)
        #expect(decodedThought.neuralLeaseReceipt == nil)
        #expect(decodedFold.morphID == nil)
        #expect(decodedFold.organChecksum == nil)
        #expect(decodedFold.frontierChecksum == nil)
        #expect(decodedFold.bindingChecksum == nil)
        #expect(decodedFold.degradedReasonCodes.isEmpty)
        #expect(decodedFold.tissueSignature == nil)
        #expect(decodedFold.snapshotRef == nil)
        #expect(decodedFold.resumeFrameRef == nil)
        #expect(decodedFold.rollbackAnchorRef == nil)
        #expect(decodedFold.morphGraphRef == nil)
        #expect(decodedFold.hotColdMapRef == nil)
        #expect(decodedFold.precisionProfileRef == nil)
        #expect(decodedFold.lungStateRef == nil)
        #expect(decodedFold.breathSchedulerRef == nil)
    }

    @Test("decompose frame decodes legacy payloads and backfills structured mirror-blade fields")
    func decomposeFrameBackwardDecodeBackfillsStructuredMirrorBladeFields() throws {
        let legacyJSON = """
        {
          "schemaVersion": "1.0.0",
          "facts": ["Host request: Compare safer paths before acting."],
          "goals": ["Keep the next move bounded."],
          "emotions": ["focused"],
          "unknowns": ["Need more evidence before any irreversible move."],
          "contradictions": ["history conflict"],
          "pressureSignals": ["time_pressure"],
          "manipulationSignals": ["authority_pressure"],
          "mirrorText": "Compare bounded paths before acting."
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(BASDecomposeFrame.self, from: legacyJSON)

        #expect(decoded.facts == ["Host request: Compare safer paths before acting."])
        #expect(decoded.goals == ["Keep the next move bounded."])
        #expect(decoded.emotions == ["focused"])
        #expect(decoded.unknowns == ["Need more evidence before any irreversible move."])
        #expect(decoded.contradictions == ["history conflict"])
        #expect(decoded.pressureSignals == ["time_pressure"])
        #expect(decoded.manipulationSignals == ["authority_pressure"])
        #expect(decoded.mirrorText == "Compare bounded paths before acting.")
    }

    @Test("budget frame decodes legacy guarded run mode and missing kernel fields")
    func budgetFrameBackwardDecodeUsesKernelDefaults() throws {
        let legacyJSON = """
        {
          "schemaVersion": "1.0.0",
          "runMode": "guarded",
          "maxLoops": 2,
          "maxCandidates": 2,
          "maxDecodeTokens": 180,
          "retrievalDepth": 3,
          "precisionProfile": "protected",
          "deviceRoute": "hybridLocal",
          "thermalGuardLevel": "watch",
          "maintenanceAllowed": false
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(BASBudgetFrame.self, from: legacyJSON)

        #expect(decoded.runMode == .guard)
        #expect(decoded.leaseID == nil)
        #expect(decoded.leaseExpiresAt == nil)
        #expect(decoded.maintenanceClass == .none)
        #expect(decoded.wakeIntentID == nil)
        #expect(decoded.allowedHeads.isEmpty)
        #expect(decoded.policyBundleVersion == nil)
        #expect(decoded.policyDecisionIDs.isEmpty)
    }

    @Test("budget frame round-trips final kernel provenance fields")
    func budgetFrameRoundTripsFinalKernelProvenance() throws {
        let frame = BASBudgetFrame(
            runMode: .guard,
            maxLoops: 2,
            maxCandidates: 2,
            maxDecodeTokens: 180,
            retrievalDepth: 3,
            precisionProfile: .protected,
            deviceRoute: .hybridLocal,
            thermalGuardLevel: .watch,
            maintenanceAllowed: false,
            leaseID: "lease-1",
            leaseExpiresAt: Date(timeIntervalSince1970: 1_705_000_000),
            maintenanceClass: .none,
            wakeIntentID: BASWakeIntentLevel.guard.rawValue,
            allowedHeads: ["risk_gate", "permit", "protective_render"],
            policyBundleVersion: "policy.bundle.v1",
            policyDecisionIDs: ["provider.default", "runtime.default"]
        )

        let encoded = try JSONEncoder().encode(frame)
        let decoded = try JSONDecoder().decode(BASBudgetFrame.self, from: encoded)

        #expect(decoded == frame)
    }

    @Test("turn result decodes legacy payloads without final kernel fields")
    func turnResultBackwardDecodeUsesFinalKernelDefaults() throws {
        let runtime = BASHostRuntime(configuration: .generic)
        let turn = try #require(
            runtime.startSession(
                BASHostSessionRequest(
                    kind: .interactive,
                    workflowProfile: .primary,
                    surface: .application,
                    prompt: "Keep this local and bounded.",
                    riskLevel: .high
                )
            ).eBrainTurn
        )

        var turnObject = try #require(
            JSONSerialization.jsonObject(
                with: try JSONEncoder().encode(turn)
            ) as? [String: Any]
        )
        var budgetObject = try #require(turnObject["budgetFrame"] as? [String: Any])
        budgetObject.removeValue(forKey: "wakeIntentID")
        budgetObject.removeValue(forKey: "allowedHeads")
        budgetObject.removeValue(forKey: "policyBundleVersion")
        budgetObject.removeValue(forKey: "policyDecisionIDs")
        turnObject["budgetFrame"] = budgetObject
        turnObject.removeValue(forKey: "sovereignExecutionReceipts")
        turnObject.removeValue(forKey: "sovereignVerdict")
        turnObject.removeValue(forKey: "sovereignCommitTokens")
        turnObject.removeValue(forKey: "sovereignLock")
        turnObject.removeValue(forKey: "quarantineRecords")
        turnObject.removeValue(forKey: "sovereignAuditEntry")
        turnObject.removeValue(forKey: "policyLineage")
        turnObject.removeValue(forKey: "recoveryDisposition")
        turnObject.removeValue(forKey: "hostConstitution")
        turnObject.removeValue(forKey: "hostConstitutionVault")
        turnObject.removeValue(forKey: "hostVersionTree")
        turnObject.removeValue(forKey: "hostForgetRequest")

        let legacyData = try JSONSerialization.data(withJSONObject: turnObject)
        let decoded = try JSONDecoder().decode(BASEBrainTurnResult.self, from: legacyData)

        #expect(decoded.budgetFrame.wakeIntentID == nil)
        #expect(decoded.budgetFrame.allowedHeads.isEmpty)
        #expect(decoded.budgetFrame.policyBundleVersion == nil)
        #expect(decoded.budgetFrame.policyDecisionIDs.isEmpty)
        #expect(decoded.sovereignExecutionReceipts.isEmpty)
        #expect(decoded.sovereignVerdict == nil)
        #expect(decoded.sovereignCommitTokens.isEmpty)
        #expect(decoded.sovereignLock == nil)
        #expect(decoded.quarantineRecords.isEmpty)
        #expect(decoded.sovereignAuditEntry == nil)
        #expect(decoded.policyLineage == nil)
        #expect(decoded.recoveryDisposition == nil)
        #expect(decoded.hostConstitution == nil)
        #expect(decoded.hostConstitutionVault == nil)
        #expect(decoded.hostVersionTree == nil)
        #expect(decoded.hostForgetRequest == nil)
    }

    @Test("protective block action permit encodes the red-line fallback mode")
    func protectiveBlockPermitUsesBlockMode() {
        let permit = BASActionPermit.protectiveBlock(reasonCodes: ["risk.high", "gsi.elevated"])

        #expect(permit.mode == .block)
        #expect(permit.requireSecondCheck)
        #expect(permit.outputLengthCap == 120)
        #expect(permit.templatePolicy == "protective_alternative")
    }

    @Test("service contracts can compose a thin end-to-end turn without leaking layer shortcuts")
    func serviceContractsComposeBrainTurn() {
        struct PowerClock: BASPowerClockServicing {
            func planBudget(deviceState: BASDeviceState, taskPing: String, riskHint: BASBrainRiskLevel?) -> BASBudgetFrame {
                .guardedLocal(maxLoops: riskHint == .high ? 3 : 1, maxCandidates: 2, maxDecodeTokens: 180, retrievalDepth: 3)
            }

            func routeDevice(deviceState: BASDeviceState, budget: BASBudgetFrame) -> BASDeviceRoute {
                budget.deviceRoute
            }

            func scheduleMaintenance(deviceState: BASDeviceState, budget: BASBudgetFrame) -> Bool {
                budget.maintenanceAllowed
            }
        }

        struct Host: BASHostProfileServicing {
            func resolveHost(hostID: String, contextFrame: BASContextFrame?, riskCard: BASRiskCard?) -> BASHostProfile {
                BASHostProfile(hostID: hostID, longTermGoals: ["Stay bounded"], noGoZones: ["dangerous_irreversible"])
            }

            func applyHostGate(profile: BASHostProfile, taskType: BASContextTaskType, riskCard: BASRiskCard?, confidence: Double) -> Double {
                riskCard?.riskLevel == .high ? 0.35 : confidence
            }

            func rollbackHostVersion(profile: BASHostProfile, to versionID: String) -> BASHostVersion {
                BASHostVersion(versionID: versionID, changedFields: ["tonePreference"], reason: "rollback", approvedByPolicy: true)
            }
        }

        struct Context: BASContextServicing {
            func analyzeContext(userInput: String, hostContext: BASHostProfile, budget: BASBudgetFrame) -> BASContextFrame {
                BASContextFrame(
                    utterance: userInput,
                    taskType: .conflict,
                    emotionalLoad: 0.8,
                    timePressure: 0.6,
                    relationPattern: "partner",
                    ambiguityScore: 0.4,
                    consequenceLevel: 0.7,
                    manipulationHints: ["time_pressure"],
                    hostRelevance: 0.9
                )
            }
        }

        struct Decompose: BASDecomposeServicing {
            func decompose(contextFrame: BASContextFrame, memoryHints: [String]) -> BASDecomposeFrame {
                BASDecomposeFrame(
                    facts: ["Conflict exists"],
                    goals: ["Respond safely"],
                    emotions: ["angry"],
                    unknowns: ["other side intent"],
                    contradictions: [],
                    pressureSignals: contextFrame.manipulationHints,
                    manipulationSignals: contextFrame.manipulationHints,
                    mirrorText: "You want to respond, but the situation is heated."
                )
            }

            func mirror(contextFrame: BASContextFrame, decomposeFrame: BASDecomposeFrame) -> String {
                decomposeFrame.mirrorText
            }

            func checkContradiction(contextFrame: BASContextFrame, decomposeFrame: BASDecomposeFrame) -> [String] {
                decomposeFrame.contradictions
            }
        }

        struct Memory: BASMemoryServicing {
            func retrieve(decomposeFrame: BASDecomposeFrame, hostContext: BASHostProfile, budget: BASBudgetFrame) -> BASMemoryBundle {
                BASMemoryBundle(
                    atoms: [
                        BASMemoryAtom(
                            memoryID: "m-1",
                            summary: "High-risk conflict should cool down first.",
                            contentType: .warm,
                            source: "ticket",
                            confidence: 0.85,
                            conflictFingerprint: "m-1"
                        )
                    ],
                    retrievalTags: ["conflict"],
                    activeHostVersion: hostContext.activeVersion
                )
            }

            func promote(atom: BASMemoryAtom, hostContext: BASHostProfile) -> BASPromotionState {
                atom.frozen ? .frozen : .admitted
            }

            func freeze(memoryID: String) -> Bool { memoryID == "m-1" }
        }

        struct Loop: BASLoopServicing {
            func proposePaths(decomposeFrame: BASDecomposeFrame, memoryBundle: BASMemoryBundle, budget: BASBudgetFrame) -> [BASCandidatePath] {
                [
                    BASCandidatePath(
                        candidateID: "c-1",
                        title: "Delay the message",
                        actionSummary: "Wait, collect evidence, then respond.",
                        expectedBenefit: 0.8,
                        expectedCost: 0.2,
                        reversibility: 0.9,
                        confidence: 0.77
                    )
                ]
            }

            func forecast(candidates: [BASCandidatePath], decomposeFrame: BASDecomposeFrame, memoryBundle: BASMemoryBundle) -> [BASForecastItem] {
                [
                    BASForecastItem(
                        candidateID: "c-1",
                        shortTermOutcome: "Emotion cools",
                        midTermOutcome: "Better odds of a bounded reply",
                        worstCase: "Delay feels uncomfortable",
                        uncertainty: 0.32
                    )
                ]
            }

            func critique(candidates: [BASCandidatePath], forecasts: [BASForecastItem], hostContext: BASHostProfile) -> [BASCritiqueItem] {
                [
                    BASCritiqueItem(
                        candidateID: "c-1",
                        critiqueType: .evidenceGap,
                        critiqueText: "Evidence is still thin for irreversible action.",
                        severity: 0.51
                    )
                ]
            }

            func iterate(decomposeFrame: BASDecomposeFrame, memoryBundle: BASMemoryBundle, budget: BASBudgetFrame) -> BASThoughtFrame {
                BASThoughtFrame(
                    stepIndex: 1,
                    decomposeRef: "decomp-1",
                    memoryRefs: memoryBundle.atoms.map(\.memoryID),
                    candidates: proposePaths(decomposeFrame: decomposeFrame, memoryBundle: memoryBundle, budget: budget),
                    forecasts: forecast(candidates: [], decomposeFrame: decomposeFrame, memoryBundle: memoryBundle),
                    critiques: critique(candidates: [], forecasts: [], hostContext: BASHostProfile(hostID: "unused")),
                    stabilityScore: 0.74,
                    stopReason: .riskConverged
                )
            }
        }

        struct TriSelf: BASTriSelfServicing {
            func mergeChoice(thoughtFrame: BASThoughtFrame, hostContext: BASHostProfile) -> ([BASTriSelfScore], BASMergedChoice) {
                let scores = [
                    BASTriSelfScore(candidateID: "c-1", idScore: 0.4, egoScore: 0.81, superegoScore: 0.88, mergedScore: 0.82, veto: false)
                ]
                let choice = BASMergedChoice(candidateID: "c-1", title: "Delay the message", actionSummary: "Pause before acting.")
                return (scores, choice)
            }
        }

        struct Risk: BASRiskServicing {
            func calibrateRisk(contextFrame: BASContextFrame, thoughtFrame: BASThoughtFrame, triScores: [BASTriSelfScore], budget: BASBudgetFrame) -> BASRiskCard {
                BASRiskCard(
                    totalRisk: 0.78,
                    riskLevel: .high,
                    factors: ["emotion_high", "relationship_pressure"],
                    uncertainty: 0.38,
                    irreversibility: 0.72,
                    manipulationStrength: 0.44,
                    gsiScore: 0.41,
                    recommendedMode: .delay
                )
            }

            func computeGSI(contextFrame: BASContextFrame, thoughtFrame: BASThoughtFrame) -> Double {
                0.41
            }

            func gateAction(contextFrame: BASContextFrame, thoughtFrame: BASThoughtFrame, triScores: [BASTriSelfScore], budget: BASBudgetFrame) -> (BASRiskCard, BASActionPermit) {
                let card = calibrateRisk(contextFrame: contextFrame, thoughtFrame: thoughtFrame, triScores: triScores, budget: budget)
                let permit = BASActionPermit(mode: .delay, reasonCodes: ["risk.high"], requireSecondCheck: true, outputLengthCap: 200, tonePolicy: "calm", templatePolicy: "delay_with_alternative")
                return (card, permit)
            }
        }

        struct Action: BASActionServicing {
            func render(choice: BASMergedChoice, riskCard: BASRiskCard, permit: BASActionPermit, hostContext: BASHostProfile) -> BASRenderedOutput {
                BASRenderedOutput(mode: permit.mode, headline: choice.title, body: choice.actionSummary, alternativeActions: ["Collect evidence first"], explanationCodes: permit.reasonCodes)
            }
        }

        struct Evolution: BASEvolutionServicing {
            func buildTickets(thoughtFrame: BASThoughtFrame, output: BASRenderedOutput, feedbackEvent: BASFeedbackEvent?) -> [BASUpdateTicket] {
                [
                    BASUpdateTicket(
                        ticketID: "ticket-1",
                        sessionRef: "session-1",
                        summary: output.body,
                        memoryWriteSuggestion: "Conflict should cool down before action.",
                        confidence: 0.7
                    )
                ]
            }
        }

        let device = BASDeviceState(
            batteryLevel: 0.44,
            thermalLevel: .warm,
            memoryFreeMB: 1536,
            networkState: .online,
            foregroundState: .foreground,
            cpuLoad: 0.33,
            gpuLoad: 0.18,
            npuAvailable: true,
            latencyBudgetMs: 1500
        )

        let coordinator = BASEBrainRuntimeCoordinator(
            powerClockService: PowerClock(),
            hostProfileService: Host(),
            contextService: Context(),
            decomposeService: Decompose(),
            memoryService: Memory(),
            loopService: Loop(),
            triSelfService: TriSelf(),
            riskService: Risk(),
            actionService: Action(),
            evolutionService: Evolution()
        )
        let recordedAt = Date(timeIntervalSince1970: 1_705_000_000)
        let result = coordinator.runTurn(
            BASEBrainTurnRequest(
                userInput: "I want to send a harsh message right now.",
                deviceState: device,
                hostID: "host.primary",
                recordedAt: recordedAt,
                riskHint: .high
            )
        )

        #expect(result.budgetFrame.runMode == .guard)
        #expect(result.contextFrame.taskType == .conflict)
        #expect(result.memoryBundle.atoms.count == 1)
        #expect(result.thoughtFrame.candidates.count == 1)
        #expect(result.triScores.count == 1)
        #expect(result.riskCard.riskLevel == .high)
        #expect(result.actionPermit.mode == .delay)
        #expect(result.renderedOutput.mode == .delay)
        #expect(result.hostGateValue == 0.35)
        #expect(result.updateTickets.count == 1)
        #expect(!result.updateTickets[0].summary.isEmpty)
        #expect(result.thoughtFold.schemaVersion == BASThoughtFold.currentSchemaVersion)
        #expect(!result.thoughtFold.checksum.isEmpty)
        #expect(result.thoughtFold.compactSlots["task_type"] == BASContextTaskType.conflict.rawValue)
        #expect(result.runtimeTrace.loopCount == 1)
        #expect(result.runtimeTrace.modelRoute == BASDeviceRoute.hybridLocal.rawValue)
        #expect(result.runtimeTrace.recordedAt == recordedAt)
        #expect(result.runtimeTrace.layerEvents.count >= 12)
        #expect(result.runtimeTrace.layerEvents.contains { $0.layerID == "L3" && $0.event == "compression_runtime" })
        #expect(result.runtimeTrace.guardrailFindings.isEmpty)
        #expect(result.wakeIntent.intentLevel == .guard)
        #expect(result.vitalState.wakeState == .guard)
        #expect(result.runLease?.allowedMode == .guard)
        #expect(result.emergencyBrake.brakeLevel == .guard)
        #expect(result.sovereignActuationCommands.contains(where: { $0.kind == .guardShift }))
        #expect(result.thoughtFrame.organMap?.morph == .guard)
        #expect(result.thoughtFrame.organMap?.activeOrgans.contains(.riskSpine) == true)
        #expect(result.thoughtFrame.organMap?.activeOrgans.contains(.permitKnot) == true)
        #expect(result.thoughtFrame.candidateFrontier?.frontierWidth == 1)
        #expect(result.thoughtFrame.counterfactualBundles?.count == result.thoughtFrame.forecasts.count)
        #expect(result.thoughtFrame.critiqueBundles?.count == result.thoughtFrame.candidates.count)
        #expect(result.thoughtFrame.riskBindings?.first?.permitMode == .delay)
        #expect(result.thoughtFrame.toolIntentEnvelope == nil)
        #expect(result.thoughtFrame.neuralLeaseReceipt?.leaseID == result.runLease?.leaseID)
        #expect(result.thoughtFold.morphID == BASNeuralMorph.guard.rawValue)
        #expect(result.thoughtFold.organChecksum != nil)
        #expect(result.thoughtFold.frontierChecksum != nil)
        #expect(result.thoughtFold.bindingChecksum != nil)
    }

    @Test("runtime coordinator enforces hard red lines when downstream services misbehave")
    func coordinatorEnforcesHardRedLines() {
        struct PowerClock: BASPowerClockServicing {
            func planBudget(deviceState: BASDeviceState, taskPing: String, riskHint: BASBrainRiskLevel?) -> BASBudgetFrame {
                BASBudgetFrame(
                    runMode: .sentinel,
                    maxLoops: 1,
                    maxCandidates: 1,
                    maxDecodeTokens: 120,
                    retrievalDepth: 1,
                    precisionProfile: .minimal,
                    deviceRoute: .scoutCPU,
                    thermalGuardLevel: .nominal,
                    maintenanceAllowed: false
                )
            }

            func routeDevice(deviceState: BASDeviceState, budget: BASBudgetFrame) -> BASDeviceRoute {
                budget.deviceRoute
            }

            func scheduleMaintenance(deviceState: BASDeviceState, budget: BASBudgetFrame) -> Bool {
                false
            }
        }

        struct Host: BASHostProfileServicing {
            func resolveHost(hostID: String, contextFrame: BASContextFrame?, riskCard: BASRiskCard?) -> BASHostProfile {
                BASHostProfile(hostID: hostID, longTermGoals: ["Stay safe"], noGoZones: ["irreversible"])
            }

            func applyHostGate(profile: BASHostProfile, taskType: BASContextTaskType, riskCard: BASRiskCard?, confidence: Double) -> Double {
                confidence
            }

            func rollbackHostVersion(profile: BASHostProfile, to versionID: String) -> BASHostVersion {
                BASHostVersion(versionID: versionID, changedFields: ["tonePreference"], reason: "rollback", approvedByPolicy: true)
            }
        }

        struct Context: BASContextServicing {
            func analyzeContext(userInput: String, hostContext: BASHostProfile, budget: BASBudgetFrame) -> BASContextFrame {
                BASContextFrame(
                    utterance: userInput,
                    taskType: .highConsequence,
                    emotionalLoad: 0.9,
                    timePressure: 0.9,
                    relationPattern: "authority",
                    ambiguityScore: 0.5,
                    consequenceLevel: 0.9,
                    manipulationHints: ["time_pressure", "authority_pressure"],
                    hostRelevance: 0.8
                )
            }
        }

        struct Decompose: BASDecomposeServicing {
            func decompose(contextFrame: BASContextFrame, memoryHints: [String]) -> BASDecomposeFrame {
                BASDecomposeFrame(
                    facts: ["Irreversible action requested"],
                    goals: ["Act immediately"],
                    emotions: ["angry"],
                    unknowns: ["missing evidence"],
                    contradictions: [],
                    pressureSignals: contextFrame.manipulationHints,
                    manipulationSignals: contextFrame.manipulationHints,
                    mirrorText: "The request is heated and lacks evidence."
                )
            }

            func mirror(contextFrame: BASContextFrame, decomposeFrame: BASDecomposeFrame) -> String {
                decomposeFrame.mirrorText
            }

            func checkContradiction(contextFrame: BASContextFrame, decomposeFrame: BASDecomposeFrame) -> [String] {
                []
            }
        }

        struct Memory: BASMemoryServicing {
            func retrieve(decomposeFrame: BASDecomposeFrame, hostContext: BASHostProfile, budget: BASBudgetFrame) -> BASMemoryBundle {
                BASMemoryBundle(
                    atoms: [
                        BASMemoryAtom(memoryID: "m1", summary: "Slow down.", contentType: .warm, source: "ticket", confidence: 0.8, conflictFingerprint: "m1"),
                        BASMemoryAtom(memoryID: "m2", summary: "Check evidence.", contentType: .warm, source: "ticket", confidence: 0.8, conflictFingerprint: "m2"),
                        BASMemoryAtom(memoryID: "m3", summary: "Do not escalate at night.", contentType: .warm, source: "ticket", confidence: 0.8, conflictFingerprint: "m3")
                    ],
                    retrievalTags: ["high_risk", "conflict"],
                    activeHostVersion: hostContext.activeVersion
                )
            }

            func promote(atom: BASMemoryAtom, hostContext: BASHostProfile) -> BASPromotionState { .candidate }
            func freeze(memoryID: String) -> Bool { true }
        }

        struct Loop: BASLoopServicing {
            func proposePaths(decomposeFrame: BASDecomposeFrame, memoryBundle: BASMemoryBundle, budget: BASBudgetFrame) -> [BASCandidatePath] {
                [
                    BASCandidatePath(candidateID: "c1", title: "Send now", actionSummary: "Act immediately.", expectedBenefit: 0.7, expectedCost: 0.8, reversibility: 0.1, confidence: 0.8),
                    BASCandidatePath(candidateID: "c2", title: "Threaten escalation", actionSummary: "Escalate pressure.", expectedBenefit: 0.6, expectedCost: 0.9, reversibility: 0.1, confidence: 0.7),
                    BASCandidatePath(candidateID: "c3", title: "Pause", actionSummary: "Wait and review.", expectedBenefit: 0.5, expectedCost: 0.2, reversibility: 0.9, confidence: 0.65)
                ]
            }

            func forecast(candidates: [BASCandidatePath], decomposeFrame: BASDecomposeFrame, memoryBundle: BASMemoryBundle) -> [BASForecastItem] {
                [
                    BASForecastItem(candidateID: "c1", shortTermOutcome: "Immediate release", midTermOutcome: "Relationship damage", worstCase: "Irreversible escalation", uncertainty: 0.4),
                    BASForecastItem(candidateID: "c2", shortTermOutcome: "Pressure spike", midTermOutcome: "Trust collapse", worstCase: "Public fallout", uncertainty: 0.5),
                    BASForecastItem(candidateID: "c3", shortTermOutcome: "Cooling off", midTermOutcome: "Better evidence", worstCase: "Delay discomfort", uncertainty: 0.2)
                ]
            }

            func critique(candidates: [BASCandidatePath], forecasts: [BASForecastItem], hostContext: BASHostProfile) -> [BASCritiqueItem] {
                [
                    BASCritiqueItem(candidateID: "c1", critiqueType: .emotionalBias, critiqueText: "Emotion is driving urgency.", severity: 0.8),
                    BASCritiqueItem(candidateID: "c2", critiqueType: .boundaryConflict, critiqueText: "This path breaks safety boundaries.", severity: 0.9),
                    BASCritiqueItem(candidateID: "c3", critiqueType: .evidenceGap, critiqueText: "Evidence is still incomplete.", severity: 0.4)
                ]
            }

            func iterate(decomposeFrame: BASDecomposeFrame, memoryBundle: BASMemoryBundle, budget: BASBudgetFrame) -> BASThoughtFrame {
                BASThoughtFrame(
                    stepIndex: 5,
                    decomposeRef: "decomp-unsafe",
                    memoryRefs: memoryBundle.atoms.map(\.memoryID),
                    candidates: proposePaths(decomposeFrame: decomposeFrame, memoryBundle: memoryBundle, budget: budget),
                    forecasts: forecast(candidates: [], decomposeFrame: decomposeFrame, memoryBundle: memoryBundle),
                    critiques: critique(candidates: [], forecasts: [], hostContext: BASHostProfile(hostID: "unused")),
                    stabilityScore: 0.31,
                    stopReason: .candidateStable
                )
            }
        }

        struct TriSelf: BASTriSelfServicing {
            func mergeChoice(thoughtFrame: BASThoughtFrame, hostContext: BASHostProfile) -> ([BASTriSelfScore], BASMergedChoice) {
                (
                    [
                        BASTriSelfScore(candidateID: "c1", idScore: 0.9, egoScore: 0.3, superegoScore: 0.1, mergedScore: 0.6, veto: false),
                        BASTriSelfScore(candidateID: "c2", idScore: 0.8, egoScore: 0.2, superegoScore: 0.1, mergedScore: 0.5, veto: false),
                        BASTriSelfScore(candidateID: "c3", idScore: 0.2, egoScore: 0.7, superegoScore: 0.9, mergedScore: 0.75, veto: false)
                    ],
                    BASMergedChoice(candidateID: "c1", title: "Send now", actionSummary: "Send the message now.")
                )
            }
        }

        struct Risk: BASRiskServicing {
            func calibrateRisk(contextFrame: BASContextFrame, thoughtFrame: BASThoughtFrame, triScores: [BASTriSelfScore], budget: BASBudgetFrame) -> BASRiskCard {
                BASRiskCard(
                    totalRisk: 0.97,
                    riskLevel: .extreme,
                    factors: ["irreversible", "manipulation", "emotion_high"],
                    uncertainty: 0.5,
                    irreversibility: 0.95,
                    manipulationStrength: 0.8,
                    gsiScore: 0.82,
                    recommendedMode: .block
                )
            }

            func computeGSI(contextFrame: BASContextFrame, thoughtFrame: BASThoughtFrame) -> Double { 0.82 }

            func gateAction(contextFrame: BASContextFrame, thoughtFrame: BASThoughtFrame, triScores: [BASTriSelfScore], budget: BASBudgetFrame) -> (BASRiskCard, BASActionPermit) {
                (
                    calibrateRisk(contextFrame: contextFrame, thoughtFrame: thoughtFrame, triScores: triScores, budget: budget),
                    BASActionPermit(mode: .answer, reasonCodes: ["unsafe.answer"], outputLengthCap: 300, tonePolicy: "direct", templatePolicy: "default")
                )
            }
        }

        struct Action: BASActionServicing {
            func render(choice: BASMergedChoice, riskCard: BASRiskCard, permit: BASActionPermit, hostContext: BASHostProfile) -> BASRenderedOutput {
                BASRenderedOutput(mode: permit.mode, headline: choice.title, body: choice.actionSummary, alternativeActions: ["Pause and gather evidence"], explanationCodes: permit.reasonCodes)
            }
        }

        struct Evolution: BASEvolutionServicing {
            func buildTickets(thoughtFrame: BASThoughtFrame, output: BASRenderedOutput, feedbackEvent: BASFeedbackEvent?) -> [BASUpdateTicket] {
                [
                    BASUpdateTicket(
                        ticketID: "ticket-unsafe",
                        sessionRef: "session-unsafe",
                        summary: output.body,
                        memoryWriteSuggestion: "Persist as cold memory immediately.",
                        hostChangeCandidate: BASHostChangeCandidate(
                            candidateID: "candidate.tone-hardening",
                            changeType: "review_tone_hardening",
                            proposedDelta: ["tone_preference"],
                            evidenceRefs: ["output:block"],
                            cooldownUntil: Date(timeIntervalSince1970: 1_700_000_456),
                            confidence: 0.9,
                            previewState: "review_only",
                            approvalState: "pending"
                        ),
                        confidence: 0.9,
                        conflictFlag: false,
                        requiresReview: false
                    )
                ]
            }
        }

        let coordinator = BASEBrainRuntimeCoordinator(
            powerClockService: PowerClock(),
            hostProfileService: Host(),
            contextService: Context(),
            decomposeService: Decompose(),
            memoryService: Memory(),
            loopService: Loop(),
            triSelfService: TriSelf(),
            riskService: Risk(),
            actionService: Action(),
            evolutionService: Evolution()
        )

        let result = coordinator.runTurn(
            BASEBrainTurnRequest(
                userInput: "Send the irreversible escalation now.",
                deviceState: BASDeviceState(
                    batteryLevel: 0.22,
                    thermalLevel: .warm,
                    memoryFreeMB: 1024,
                    networkState: .constrained,
                    foregroundState: .foreground,
                    cpuLoad: 0.4,
                    gpuLoad: 0.2,
                    npuAvailable: false,
                    latencyBudgetMs: 1200
                ),
                hostID: "host.unsafe",
                riskHint: .high
            )
        )

        #expect(result.budgetFrame.runMode == .guard)
        #expect(result.budgetFrame.precisionProfile == .protected)
        #expect(result.memoryBundle.atoms.count == result.budgetFrame.retrievalDepth)
        #expect(result.thoughtFrame.stepIndex == result.budgetFrame.maxLoops)
        #expect(result.thoughtFrame.candidates.count == result.budgetFrame.maxCandidates)
        #expect(result.actionPermit.mode == .block)
        #expect(result.renderedOutput.mode == .block)
        #expect(result.updateTickets.allSatisfy { $0.requiresReview })
        #expect(result.updateTickets.contains(where: { $0.conflictFlag }))
        #expect(
            result.updateTickets.contains(where: {
                $0.hostChangeCandidate?.candidateID == "candidate.tone-hardening"
            })
        )
        #expect(
            result.updateTickets.contains(where: {
                $0.hostChangeCandidate?.changeType == "review_tone_hardening"
            })
        )
        #expect(result.runtimeTrace.guardrailFindings.contains(where: { $0.code == "budget.high_risk_fast_path" }))
        #expect(result.runtimeTrace.guardrailFindings.contains(where: { $0.code == "loop.max_loops_clamped" }))
        #expect(result.runtimeTrace.guardrailFindings.contains(where: { $0.code == "risk.extreme_answer_blocked" }))
        #expect(result.runtimeTrace.guardrailFindings.contains(where: { $0.code == "evolution.high_risk_review_required" }))
        #expect(result.runtimeTrace.recommendedKillSwitches.contains(.forceGuardMode))
        #expect(result.runtimeTrace.recommendedKillSwitches.contains(.forceProtectedPermit))
        #expect(result.runtimeTrace.recommendedKillSwitches.contains(.requireReviewedWrites))
        #expect(result.runtimeTrace.layerEvents.contains(where: {
            $0.layerID == "L13"
            && $0.detail.contains("host changes 1")
            && $0.detail.contains("review_tone_hardening")
        }))
        #expect(result.emergencyBrake.brakeLevel == .lockdown)
        #expect(result.sovereignActuationCommands.contains(where: { $0.kind == .deadStop }))
        #expect(result.thoughtFrame.organMap?.morph == .stub)
        #expect(result.thoughtFrame.organMap?.activeOrgans.contains(.toolIntentMesh) == false)
        #expect(result.thoughtFrame.toolIntentEnvelope == nil)
        #expect(result.thoughtFrame.organMap?.activeOrgans.contains(.hostModulationMesh) == false)
        #expect(result.thoughtFrame.organMap?.activeOrgans.contains(.stubCore) == true)
        #expect(result.thoughtFrame.neuralLeaseReceipt?.degraded == true)
        #expect(result.runtimeTrace.layerEvents.contains(where: { $0.layerID == "L14" && $0.event == "sovereign" }))
        #expect(result.thoughtFold.morphID == BASNeuralMorph.stub.rawValue)
        #expect(result.thoughtFold.degradedReasonCodes.contains("runtime.stub_only") == true)
    }

    @Test("deep-loop runtime materializes critique bundles and tool intent from neural fabric")
    func deepLoopRuntimeMaterializesNeuralFabricArtifacts() {
        struct PowerClock: BASPowerClockServicing {
            func planBudget(deviceState: BASDeviceState, taskPing: String, riskHint: BASBrainRiskLevel?) -> BASBudgetFrame {
                BASBudgetFrame(
                    runMode: .deepLoop,
                    maxLoops: 2,
                    maxCandidates: 2,
                    maxDecodeTokens: 256,
                    retrievalDepth: 2,
                    precisionProfile: .full,
                    deviceRoute: .coreNPU,
                    thermalGuardLevel: .nominal,
                    maintenanceAllowed: false
                )
            }

            func routeDevice(deviceState: BASDeviceState, budget: BASBudgetFrame) -> BASDeviceRoute { .coreNPU }
            func scheduleMaintenance(deviceState: BASDeviceState, budget: BASBudgetFrame) -> Bool { false }
        }

        struct Host: BASHostProfileServicing {
            func resolveHost(hostID: String, contextFrame: BASContextFrame?, riskCard: BASRiskCard?) -> BASHostProfile {
                BASHostProfile(hostID: hostID, longTermGoals: ["Stay clear"], noGoZones: ["tool_commit"])
            }

            func applyHostGate(profile: BASHostProfile, taskType: BASContextTaskType, riskCard: BASRiskCard?, confidence: Double) -> Double {
                confidence
            }

            func rollbackHostVersion(profile: BASHostProfile, to versionID: String) -> BASHostVersion {
                BASHostVersion(versionID: versionID, changedFields: [], reason: "rollback", approvedByPolicy: true)
            }
        }

        struct Context: BASContextServicing {
            func analyzeContext(userInput: String, hostContext: BASHostProfile, budget: BASBudgetFrame) -> BASContextFrame {
                BASContextFrame(
                    utterance: userInput,
                    taskType: .task,
                    emotionalLoad: 0.32,
                    timePressure: 0.24,
                    relationPattern: "peer",
                    ambiguityScore: 0.18,
                    consequenceLevel: 0.22,
                    manipulationHints: [],
                    hostRelevance: 0.61
                )
            }
        }

        struct Decompose: BASDecomposeServicing {
            func decompose(contextFrame: BASContextFrame, memoryHints: [String]) -> BASDecomposeFrame {
                BASDecomposeFrame(
                    facts: ["Need a calm next step."],
                    goals: ["Preserve optionality"],
                    emotions: ["concern"],
                    unknowns: ["How they will respond"],
                    contradictions: [],
                    pressureSignals: [],
                    manipulationSignals: []
                )
            }

            func mirror(contextFrame: BASContextFrame, decomposeFrame: BASDecomposeFrame) -> String {
                "Move carefully."
            }

            func checkContradiction(contextFrame: BASContextFrame, decomposeFrame: BASDecomposeFrame) -> [String] {
                []
            }
        }

        struct Memory: BASMemoryServicing {
            func retrieve(decomposeFrame: BASDecomposeFrame, hostContext: BASHostProfile, budget: BASBudgetFrame) -> BASMemoryBundle {
                BASMemoryBundle(
                    atoms: [
                        BASMemoryAtom(
                            memoryID: "m-1",
                            summary: "Prior slow replies de-escalated conflict.",
                            contentType: .warm,
                            source: "memory",
                            timestamp: .now,
                            confidence: 0.82,
                            emotionalWeight: 0.24,
                            riskRelevance: 0.30,
                            hostRelevance: 0.71,
                            conflictFingerprint: "m-1",
                            promotionState: .admitted,
                            frozen: false
                        )
                    ],
                    retrievalTags: ["deescalation"],
                    conflictRefs: [],
                    activeHostVersion: hostContext.activeVersion
                )
            }

            func promote(atom: BASMemoryAtom, hostContext: BASHostProfile) -> BASPromotionState { .admitted }
            func freeze(memoryID: String) -> Bool { false }
        }

        struct Loop: BASLoopServicing {
            func proposePaths(decomposeFrame: BASDecomposeFrame, memoryBundle: BASMemoryBundle, budget: BASBudgetFrame) -> [BASCandidatePath] {
                []
            }

            func forecast(candidates: [BASCandidatePath], decomposeFrame: BASDecomposeFrame, memoryBundle: BASMemoryBundle) -> [BASForecastItem] {
                []
            }

            func critique(candidates: [BASCandidatePath], forecasts: [BASForecastItem], hostContext: BASHostProfile) -> [BASCritiqueItem] {
                []
            }

            func iterate(decomposeFrame: BASDecomposeFrame, memoryBundle: BASMemoryBundle, budget: BASBudgetFrame) -> BASThoughtFrame {
                BASThoughtFrame(
                    stepIndex: 2,
                    decomposeRef: "decomp-deep",
                    memoryRefs: memoryBundle.atoms.map(\.memoryID),
                    candidates: [
                        BASCandidatePath(
                            candidateID: "c-1",
                            title: "Reply with a bounded summary",
                            actionSummary: "Send a short, calm reply that leaves room to revisit tomorrow.",
                            requiredEvidence: ["timing"],
                            expectedBenefit: 0.72,
                            expectedCost: 0.22,
                            reversibility: 0.81,
                            confidence: 0.78
                        ),
                        BASCandidatePath(
                            candidateID: "c-2",
                            title: "Wait until tomorrow",
                            actionSummary: "Delay the reply and check back in the morning.",
                            requiredEvidence: ["sleep"],
                            expectedBenefit: 0.66,
                            expectedCost: 0.18,
                            reversibility: 0.94,
                            confidence: 0.74
                        )
                    ],
                    forecasts: [
                        BASForecastItem(
                            candidateID: "c-1",
                            shortTermOutcome: "Immediate reduction in pressure.",
                            midTermOutcome: "Keeps dialogue open.",
                            worstCase: "They ask for more detail too soon.",
                            uncertainty: 0.21,
                            affectedRelations: ["peer"]
                        ),
                        BASForecastItem(
                            candidateID: "c-2",
                            shortTermOutcome: "No immediate conflict.",
                            midTermOutcome: "More clarity tomorrow.",
                            worstCase: "Silence is misread.",
                            uncertainty: 0.28,
                            affectedRelations: ["peer"]
                        )
                    ],
                    critiques: [
                        BASCritiqueItem(candidateID: "c-1", critiqueType: .evidenceGap, critiqueText: "Need tighter scope.", severity: 0.24),
                        BASCritiqueItem(candidateID: "c-1", critiqueType: .boundaryConflict, critiqueText: "Too much detail could reopen conflict.", severity: 0.18),
                        BASCritiqueItem(candidateID: "c-2", critiqueType: .emotionalBias, critiqueText: "Delay may reflect avoidance.", severity: 0.27),
                        BASCritiqueItem(candidateID: "c-2", critiqueType: .manipulationRisk, critiqueText: "Silence can invite pressure.", severity: 0.22)
                    ],
                    stabilityScore: 0.77,
                    stopReason: .candidateStable
                )
            }
        }

        struct TriSelf: BASTriSelfServicing {
            func mergeChoice(thoughtFrame: BASThoughtFrame, hostContext: BASHostProfile) -> ([BASTriSelfScore], BASMergedChoice) {
                (
                    [
                        BASTriSelfScore(candidateID: "c-1", idScore: 0.52, egoScore: 0.84, superegoScore: 0.80, mergedScore: 0.82, veto: false),
                        BASTriSelfScore(candidateID: "c-2", idScore: 0.36, egoScore: 0.79, superegoScore: 0.75, mergedScore: 0.73, veto: false)
                    ],
                    BASMergedChoice(
                        candidateID: "c-1",
                        title: "Reply with a bounded summary",
                        actionSummary: "Send a short, calm reply that leaves room to revisit tomorrow."
                    )
                )
            }
        }

        struct Risk: BASRiskServicing {
            func calibrateRisk(contextFrame: BASContextFrame, thoughtFrame: BASThoughtFrame, triScores: [BASTriSelfScore], budget: BASBudgetFrame) -> BASRiskCard {
                BASRiskCard(
                    totalRisk: 0.26,
                    riskLevel: .low,
                    factors: ["risk.low"],
                    uncertainty: 0.18,
                    irreversibility: 0.14,
                    manipulationStrength: 0.12,
                    gsiScore: 0.16,
                    recommendedMode: .answer
                )
            }

            func computeGSI(contextFrame: BASContextFrame, thoughtFrame: BASThoughtFrame) -> Double { 0.16 }

            func gateAction(contextFrame: BASContextFrame, thoughtFrame: BASThoughtFrame, triScores: [BASTriSelfScore], budget: BASBudgetFrame) -> (BASRiskCard, BASActionPermit) {
                (
                    calibrateRisk(contextFrame: contextFrame, thoughtFrame: thoughtFrame, triScores: triScores, budget: budget),
                    BASActionPermit(
                        mode: .answer,
                        reasonCodes: ["permit.answer"],
                        requireSecondCheck: false,
                        outputLengthCap: 180,
                        tonePolicy: "steady",
                        templatePolicy: "answer"
                    )
                )
            }
        }

        struct Action: BASActionServicing {
            func render(choice: BASMergedChoice, riskCard: BASRiskCard, permit: BASActionPermit, hostContext: BASHostProfile) -> BASRenderedOutput {
                BASRenderedOutput(mode: permit.mode, headline: choice.title, body: choice.actionSummary, explanationCodes: permit.reasonCodes)
            }
        }

        struct Evolution: BASEvolutionServicing {
            func buildTickets(thoughtFrame: BASThoughtFrame, output: BASRenderedOutput, feedbackEvent: BASFeedbackEvent?) -> [BASUpdateTicket] {
                []
            }
        }

        let coordinator = BASEBrainRuntimeCoordinator(
            powerClockService: PowerClock(),
            hostProfileService: Host(),
            contextService: Context(),
            decomposeService: Decompose(),
            memoryService: Memory(),
            loopService: Loop(),
            triSelfService: TriSelf(),
            riskService: Risk(),
            actionService: Action(),
            evolutionService: Evolution()
        )

        let result = coordinator.runTurn(
            BASEBrainTurnRequest(
                userInput: "Think through the next step before replying.",
                deviceState: BASDeviceState(
                    batteryLevel: 0.88,
                    thermalLevel: .nominal,
                    memoryFreeMB: 3072,
                    networkState: .online,
                    foregroundState: .foreground,
                    cpuLoad: 0.18,
                    gpuLoad: 0.10,
                    npuAvailable: true,
                    latencyBudgetMs: 1800
                ),
                hostID: "host.deep"
            )
        )

        #expect(result.thoughtFrame.organMap?.morph == .deepLoop)
        #expect(result.thoughtFrame.organMap?.activeOrgans.contains(.toolIntentMesh) == true)
        #expect(result.thoughtFrame.candidateFrontier?.frontierWidth == 2)
        #expect(result.thoughtFrame.counterfactualBundles?.count == 2)
        #expect(result.thoughtFrame.critiqueBundles?.count == 2)
        #expect(result.thoughtFrame.toolIntentEnvelope?.candidateID == "c-1")
        #expect(result.thoughtFrame.toolIntentEnvelope?.permitMode == .answer)
        #expect(result.thoughtFrame.toolIntentEnvelope?.requestedDomains == ["bounded_reply", "plain_language"])
        #expect(result.thoughtFrame.toolIntentEnvelope?.blockedDomains.isEmpty == true)
        #expect(result.runtimeTrace.layerEvents.contains(where: {
            $0.layerID == "L2" && $0.detail.contains("tool intent")
        }))
    }

    @Test("runtime coordinator defers second-stage neural artifacts to the neural core service")
    func coordinatorDefersSecondStageArtifactsToNeuralCoreService() {
        struct PowerClock: BASPowerClockServicing {
            func planBudget(deviceState: BASDeviceState, taskPing: String, riskHint: BASBrainRiskLevel?) -> BASBudgetFrame {
                BASBudgetFrame(
                    runMode: .deepLoop,
                    maxLoops: 2,
                    maxCandidates: 2,
                    maxDecodeTokens: 220,
                    retrievalDepth: 2,
                    precisionProfile: .full,
                    deviceRoute: .coreNPU,
                    thermalGuardLevel: .nominal,
                    maintenanceAllowed: false
                )
            }

            func routeDevice(deviceState: BASDeviceState, budget: BASBudgetFrame) -> BASDeviceRoute { .coreNPU }
            func scheduleMaintenance(deviceState: BASDeviceState, budget: BASBudgetFrame) -> Bool { false }
        }

        struct Host: BASHostProfileServicing {
            func resolveHost(hostID: String, contextFrame: BASContextFrame?, riskCard: BASRiskCard?) -> BASHostProfile {
                BASHostProfile(hostID: hostID)
            }

            func applyHostGate(profile: BASHostProfile, taskType: BASContextTaskType, riskCard: BASRiskCard?, confidence: Double) -> Double {
                confidence
            }

            func rollbackHostVersion(profile: BASHostProfile, to versionID: String) -> BASHostVersion {
                BASHostVersion(versionID: versionID, changedFields: [], reason: "rollback", approvedByPolicy: true)
            }
        }

        struct Context: BASContextServicing {
            func analyzeContext(userInput: String, hostContext: BASHostProfile, budget: BASBudgetFrame) -> BASContextFrame {
                BASContextFrame(
                    utterance: userInput,
                    taskType: .task,
                    emotionalLoad: 0.22,
                    timePressure: 0.18,
                    relationPattern: "peer",
                    ambiguityScore: 0.20,
                    consequenceLevel: 0.18,
                    manipulationHints: [],
                    hostRelevance: 0.44
                )
            }
        }

        struct Decompose: BASDecomposeServicing {
            func decompose(contextFrame: BASContextFrame, memoryHints: [String]) -> BASDecomposeFrame {
                BASDecomposeFrame(facts: ["Need a composed reply."], goals: ["Keep options open"], unknowns: ["What they need most"])
            }

            func mirror(contextFrame: BASContextFrame, decomposeFrame: BASDecomposeFrame) -> String { "Stay composed." }
            func checkContradiction(contextFrame: BASContextFrame, decomposeFrame: BASDecomposeFrame) -> [String] { [] }
        }

        struct Memory: BASMemoryServicing {
            func retrieve(decomposeFrame: BASDecomposeFrame, hostContext: BASHostProfile, budget: BASBudgetFrame) -> BASMemoryBundle {
                BASMemoryBundle(
                    atoms: [
                        BASMemoryAtom(
                            memoryID: "m-1",
                            summary: "Short replies work better.",
                            contentType: .warm,
                            source: "memory",
                            timestamp: .now,
                            confidence: 0.8,
                            emotionalWeight: 0.2,
                            riskRelevance: 0.2,
                            hostRelevance: 0.6,
                            conflictFingerprint: "m-1",
                            promotionState: .admitted,
                            frozen: false
                        )
                    ],
                    retrievalTags: ["short_reply"],
                    conflictRefs: [],
                    activeHostVersion: hostContext.activeVersion
                )
            }

            func promote(atom: BASMemoryAtom, hostContext: BASHostProfile) -> BASPromotionState { .admitted }
            func freeze(memoryID: String) -> Bool { false }
        }

        struct NeuralCore: BASNeuralCoreServicing {
            func synthesize(
                budgetFrame: BASBudgetFrame,
                contextFrame: BASContextFrame,
                decomposeFrame: BASDecomposeFrame,
                memoryBundle: BASMemoryBundle,
                hostProfile: BASHostProfile,
                activeKillSwitches: [BASKillSwitchID]
            ) -> BASNeuralCoreFrame {
                BASNeuralCoreFrame(
                    organMap: BASNeuralOrganMap(
                        morph: .deepLoop,
                        activeOrgans: [.coreCortex, .simuRing, .criticBlade, .riskSpine, .permitKnot, .toolIntentMesh, .consistencyLattice, .stubCore, .tissueRouter],
                        precisionMap: [],
                        routingPolicy: .deepLoopConvergence,
                        leaseRef: budgetFrame.leaseID,
                        sovereignConstraints: [],
                        headGuarantees: ["custom_frontier", "custom_tool_intent"]
                    )
                )
            }

            func materializeThoughtArtifacts(
                budgetFrame: BASBudgetFrame,
                contextFrame: BASContextFrame,
                decomposeFrame: BASDecomposeFrame,
                memoryBundle: BASMemoryBundle,
                hostProfile: BASHostProfile,
                thoughtFrame: BASThoughtFrame
            ) -> BASNeuralThoughtMaterialization {
                BASNeuralThoughtMaterialization(
                    candidateFrontier: BASCandidateFrontier(
                        candidateIDs: thoughtFrame.candidates.map(\.candidateID),
                        dominanceOrder: ["c-2", "c-1"],
                        reversiblePaths: ["c-2"],
                        guardPaths: ["c-1"],
                        frontierWidth: 2
                    ),
                    counterfactualBundles: [
                        BASCounterfactualBundle(
                            candidateID: "c-2",
                            shortTerm: "Custom short-term.",
                            midTerm: "Custom mid-term.",
                            worstCase: "Custom worst case.",
                            uncertainty: 0.11,
                            affectedDomains: ["peer"]
                        )
                    ],
                    critiqueBundles: [
                        BASCritiqueBundle(
                            candidateID: "c-1",
                            evidenceGap: 0.05,
                            manipulationRisk: 0.09,
                            emotionalBias: 0.13,
                            boundaryConflict: 0.91,
                            critiqueStrength: 0.91
                        )
                    ]
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
                [
                    BASRiskPermitBinding(
                        candidateID: "c-1",
                        riskLevel: .medium,
                        totalRisk: 0.42,
                        uncertainty: 0.12,
                        irreversibility: 0.09,
                        manipulationStrength: 0.08,
                        gsiScore: 0.14,
                        recommendedMode: .compare,
                        permitMode: .compare,
                        requireSecondCheck: false,
                        outputLengthCap: 144,
                        tonePolicy: "custom",
                        templatePolicy: "custom_compare",
                        reasonCodes: ["custom.binding"],
                        allowedDomains: ["comparison"],
                        forbiddenDomains: ["tool_commit"]
                    )
                ]
            }

            func materializeToolIntent(
                budgetFrame: BASBudgetFrame,
                thoughtFrame: BASThoughtFrame,
                mergedChoice: BASMergedChoice,
                actionPermit: BASActionPermit
            ) -> BASToolIntentEnvelope? {
                BASToolIntentEnvelope(
                    intentID: "custom.intent",
                    candidateID: mergedChoice.candidateID,
                    permitMode: actionPermit.mode,
                    summary: "Custom neural intent.",
                    requestedDomains: ["comparison"],
                    blockedDomains: ["tool_commit"],
                    requireSecondCheck: false,
                    tonePolicy: "custom",
                    templatePolicy: "custom_compare",
                    reasonCodes: ["custom.intent"],
                    sovereignBound: false
                )
            }
        }

        struct Loop: BASLoopServicing {
            func proposePaths(decomposeFrame: BASDecomposeFrame, memoryBundle: BASMemoryBundle, budget: BASBudgetFrame) -> [BASCandidatePath] { [] }
            func forecast(candidates: [BASCandidatePath], decomposeFrame: BASDecomposeFrame, memoryBundle: BASMemoryBundle) -> [BASForecastItem] { [] }
            func critique(candidates: [BASCandidatePath], forecasts: [BASForecastItem], hostContext: BASHostProfile) -> [BASCritiqueItem] { [] }

            func iterate(decomposeFrame: BASDecomposeFrame, memoryBundle: BASMemoryBundle, budget: BASBudgetFrame) -> BASThoughtFrame {
                BASThoughtFrame(
                    stepIndex: 2,
                    decomposeRef: "decomp-neural",
                    memoryRefs: ["m-1"],
                    candidates: [
                        BASCandidatePath(candidateID: "c-1", title: "Reply", actionSummary: "Reply calmly.", expectedBenefit: 0.6, expectedCost: 0.2, reversibility: 0.8, confidence: 0.8),
                        BASCandidatePath(candidateID: "c-2", title: "Pause", actionSummary: "Wait and reassess.", expectedBenefit: 0.5, expectedCost: 0.1, reversibility: 0.9, confidence: 0.7)
                    ],
                    forecasts: [
                        BASForecastItem(candidateID: "c-1", shortTermOutcome: "Default short-term.", midTermOutcome: "Default mid-term.", worstCase: "Default worst case.", uncertainty: 0.3),
                        BASForecastItem(candidateID: "c-2", shortTermOutcome: "Default short-term.", midTermOutcome: "Default mid-term.", worstCase: "Default worst case.", uncertainty: 0.3)
                    ],
                    critiques: [
                        BASCritiqueItem(candidateID: "c-1", critiqueType: .evidenceGap, critiqueText: "Default critique.", severity: 0.3)
                    ],
                    stabilityScore: 0.72,
                    stopReason: .candidateStable
                )
            }
        }

        struct TriSelf: BASTriSelfServicing {
            func mergeChoice(thoughtFrame: BASThoughtFrame, hostContext: BASHostProfile) -> ([BASTriSelfScore], BASMergedChoice) {
                (
                    [BASTriSelfScore(candidateID: "c-1", idScore: 0.4, egoScore: 0.8, superegoScore: 0.8, mergedScore: 0.78, veto: false)],
                    BASMergedChoice(candidateID: "c-1", title: "Reply", actionSummary: "Reply calmly.")
                )
            }
        }

        struct Risk: BASRiskServicing {
            func calibrateRisk(contextFrame: BASContextFrame, thoughtFrame: BASThoughtFrame, triScores: [BASTriSelfScore], budget: BASBudgetFrame) -> BASRiskCard {
                BASRiskCard(totalRisk: 0.2, riskLevel: .low, factors: ["risk.low"], uncertainty: 0.1, irreversibility: 0.1, manipulationStrength: 0.1, gsiScore: 0.1, recommendedMode: .answer)
            }

            func computeGSI(contextFrame: BASContextFrame, thoughtFrame: BASThoughtFrame) -> Double { 0.1 }

            func gateAction(contextFrame: BASContextFrame, thoughtFrame: BASThoughtFrame, triScores: [BASTriSelfScore], budget: BASBudgetFrame) -> (BASRiskCard, BASActionPermit) {
                (
                    calibrateRisk(contextFrame: contextFrame, thoughtFrame: thoughtFrame, triScores: triScores, budget: budget),
                    BASActionPermit(mode: .answer, reasonCodes: ["default.answer"], requireSecondCheck: false, outputLengthCap: 220, tonePolicy: "default", templatePolicy: "answer")
                )
            }
        }

        struct Action: BASActionServicing {
            func render(choice: BASMergedChoice, riskCard: BASRiskCard, permit: BASActionPermit, hostContext: BASHostProfile) -> BASRenderedOutput {
                BASRenderedOutput(mode: permit.mode, headline: choice.title, body: choice.actionSummary)
            }
        }

        struct Evolution: BASEvolutionServicing {
            func buildTickets(thoughtFrame: BASThoughtFrame, output: BASRenderedOutput, feedbackEvent: BASFeedbackEvent?) -> [BASUpdateTicket] { [] }
        }

        let coordinator = BASEBrainRuntimeCoordinator(
            powerClockService: PowerClock(),
            hostProfileService: Host(),
            contextService: Context(),
            decomposeService: Decompose(),
            memoryService: Memory(),
            neuralCoreService: NeuralCore(),
            loopService: Loop(),
            triSelfService: TriSelf(),
            riskService: Risk(),
            actionService: Action(),
            evolutionService: Evolution()
        )

        let result = coordinator.runTurn(
            BASEBrainTurnRequest(
                userInput: "Compare the next two replies.",
                deviceState: BASDeviceState(
                    batteryLevel: 0.9,
                    thermalLevel: .nominal,
                    memoryFreeMB: 2048,
                    networkState: .online,
                    foregroundState: .foreground,
                    cpuLoad: 0.15,
                    gpuLoad: 0.08,
                    npuAvailable: true,
                    latencyBudgetMs: 1600
                ),
                hostID: "host.custom-neural"
            )
        )

        #expect(result.thoughtFrame.candidateFrontier?.dominanceOrder == ["c-2", "c-1"])
        #expect(result.thoughtFrame.counterfactualBundles?.count == 1)
        #expect(result.thoughtFrame.counterfactualBundles?.first?.candidateID == "c-2")
        #expect(result.thoughtFrame.critiqueBundles?.count == 1)
        #expect(result.thoughtFrame.critiqueBundles?.first?.boundaryConflict == 0.91)
        #expect(result.thoughtFrame.riskBindings?.count == 1)
        #expect(result.actionPermit.mode == .compare)
        #expect(result.thoughtFrame.toolIntentEnvelope?.intentID == "custom.intent")
        #expect(result.thoughtFrame.toolIntentEnvelope?.requestedDomains == ["comparison"])
        #expect(result.runtimeTrace.layerEvents.contains(where: {
            $0.layerID == "L2" && $0.detail.contains("tool intent c-1:compare")
        }))
    }

    @Test("runtime coordinator defers public thought projection to the neural core service")
    func coordinatorDefersPublicThoughtProjectionToNeuralCoreService() {
        struct PowerClock: BASPowerClockServicing {
            func planBudget(deviceState: BASDeviceState, taskPing: String, riskHint: BASBrainRiskLevel?) -> BASBudgetFrame {
                BASBudgetFrame(
                    runMode: .deepLoop,
                    maxLoops: 2,
                    maxCandidates: 2,
                    maxDecodeTokens: 220,
                    retrievalDepth: 2,
                    precisionProfile: .full,
                    deviceRoute: .coreNPU,
                    thermalGuardLevel: .nominal,
                    maintenanceAllowed: false
                )
            }

            func routeDevice(deviceState: BASDeviceState, budget: BASBudgetFrame) -> BASDeviceRoute { .coreNPU }
            func scheduleMaintenance(deviceState: BASDeviceState, budget: BASBudgetFrame) -> Bool { false }
        }

        struct Host: BASHostProfileServicing {
            func resolveHost(hostID: String, contextFrame: BASContextFrame?, riskCard: BASRiskCard?) -> BASHostProfile {
                BASHostProfile(hostID: hostID)
            }

            func applyHostGate(profile: BASHostProfile, taskType: BASContextTaskType, riskCard: BASRiskCard?, confidence: Double) -> Double {
                confidence
            }

            func rollbackHostVersion(profile: BASHostProfile, to versionID: String) -> BASHostVersion {
                BASHostVersion(versionID: versionID, changedFields: [], reason: "rollback", approvedByPolicy: true)
            }
        }

        struct Context: BASContextServicing {
            func analyzeContext(userInput: String, hostContext: BASHostProfile, budget: BASBudgetFrame) -> BASContextFrame {
                BASContextFrame(
                    utterance: userInput,
                    taskType: .choice,
                    emotionalLoad: 0.18,
                    timePressure: 0.16,
                    relationPattern: "peer",
                    ambiguityScore: 0.24,
                    consequenceLevel: 0.20,
                    manipulationHints: [],
                    hostRelevance: 0.42
                )
            }
        }

        struct Decompose: BASDecomposeServicing {
            func decompose(contextFrame: BASContextFrame, memoryHints: [String]) -> BASDecomposeFrame {
                BASDecomposeFrame(facts: ["Need a next-step comparison."], goals: ["Keep the reply bounded"], unknowns: ["How much detail helps"])
            }

            func mirror(contextFrame: BASContextFrame, decomposeFrame: BASDecomposeFrame) -> String { "Compare bounded options." }
            func checkContradiction(contextFrame: BASContextFrame, decomposeFrame: BASDecomposeFrame) -> [String] { [] }
        }

        struct Memory: BASMemoryServicing {
            func retrieve(decomposeFrame: BASDecomposeFrame, hostContext: BASHostProfile, budget: BASBudgetFrame) -> BASMemoryBundle {
                BASMemoryBundle(
                    atoms: [
                        BASMemoryAtom(
                            memoryID: "m-1",
                            summary: "Short comparisons land better than long replies.",
                            contentType: .warm,
                            source: "memory",
                            timestamp: .now,
                            confidence: 0.82,
                            emotionalWeight: 0.18,
                            riskRelevance: 0.19,
                            hostRelevance: 0.64,
                            conflictFingerprint: "m-1",
                            promotionState: .admitted,
                            frozen: false
                        )
                    ],
                    retrievalTags: ["comparison"],
                    conflictRefs: [],
                    activeHostVersion: hostContext.activeVersion
                )
            }

            func promote(atom: BASMemoryAtom, hostContext: BASHostProfile) -> BASPromotionState { .admitted }
            func freeze(memoryID: String) -> Bool { false }
        }

        struct NeuralCore: BASNeuralCoreServicing {
            func synthesize(
                budgetFrame: BASBudgetFrame,
                contextFrame: BASContextFrame,
                decomposeFrame: BASDecomposeFrame,
                memoryBundle: BASMemoryBundle,
                hostProfile: BASHostProfile,
                activeKillSwitches: [BASKillSwitchID]
            ) -> BASNeuralCoreFrame {
                BASNeuralCoreFrame(
                    organMap: BASNeuralOrganMap(
                        morph: .compare,
                        activeOrgans: [.coreCortex, .simuRing, .criticBlade, .riskSpine, .permitKnot, .consistencyLattice, .stubCore, .tissueRouter],
                        precisionMap: [],
                        routingPolicy: .comparativeFanout,
                        leaseRef: budgetFrame.leaseID,
                        sovereignConstraints: [],
                        headGuarantees: ["public_projection"]
                    )
                )
            }

            func materializeThoughtArtifacts(
                budgetFrame: BASBudgetFrame,
                contextFrame: BASContextFrame,
                decomposeFrame: BASDecomposeFrame,
                memoryBundle: BASMemoryBundle,
                hostProfile: BASHostProfile,
                thoughtFrame: BASThoughtFrame
            ) -> BASNeuralThoughtMaterialization {
                BASNeuralThoughtMaterialization(
                    candidateFrontier: BASCandidateFrontier(
                        candidateIDs: thoughtFrame.candidates.map(\.candidateID),
                        dominanceOrder: ["c-2", "c-1"],
                        reversiblePaths: ["c-2"],
                        guardPaths: ["c-1"],
                        frontierWidth: 2
                    ),
                    counterfactualBundles: [
                        BASCounterfactualBundle(
                            candidateID: "c-2",
                            shortTerm: "Projected by neural fabric.",
                            midTerm: "Keeps choices open.",
                            worstCase: "Looks indecisive.",
                            uncertainty: 0.19,
                            affectedDomains: ["peer"]
                        )
                    ],
                    critiqueBundles: [
                        BASCritiqueBundle(
                            candidateID: "c-2",
                            evidenceGap: 0.07,
                            manipulationRisk: 0.08,
                            emotionalBias: 0.11,
                            boundaryConflict: 0.16,
                            critiqueStrength: 0.31
                        )
                    ]
                )
            }

            func materializePublicProjection(
                budgetFrame: BASBudgetFrame,
                contextFrame: BASContextFrame,
                hostProfile: BASHostProfile,
                thoughtFrame: BASThoughtFrame
            ) -> BASNeuralPublicThoughtProjection {
                BASNeuralPublicThoughtProjection(
                    candidates: [
                        BASCandidatePath(
                            candidateID: "c-2",
                            title: "Pause and compare",
                            actionSummary: "Hold the reply until the calmer option is clear.",
                            expectedBenefit: 0.77,
                            expectedCost: 0.12,
                            reversibility: 0.94,
                            confidence: 0.76
                        ),
                        BASCandidatePath(
                            candidateID: "c-1",
                            title: "Reply now",
                            actionSummary: "Send the shorter reply immediately.",
                            expectedBenefit: 0.64,
                            expectedCost: 0.24,
                            reversibility: 0.82,
                            confidence: 0.73
                        )
                    ],
                    forecasts: [
                        BASForecastItem(
                            candidateID: "c-2",
                            shortTermOutcome: "Projection-owned short term.",
                            midTermOutcome: "Projection-owned mid term.",
                            worstCase: "Projection-owned worst case.",
                            uncertainty: 0.14,
                            affectedRelations: ["peer"]
                        )
                    ],
                    critiques: [
                        BASCritiqueItem(
                            candidateID: "c-2",
                            critiqueType: .boundaryConflict,
                            critiqueText: "Projection-owned critique.",
                            severity: 0.17
                        )
                    ]
                )
            }
        }

        struct Loop: BASLoopServicing {
            func proposePaths(decomposeFrame: BASDecomposeFrame, memoryBundle: BASMemoryBundle, budget: BASBudgetFrame) -> [BASCandidatePath] { [] }
            func forecast(candidates: [BASCandidatePath], decomposeFrame: BASDecomposeFrame, memoryBundle: BASMemoryBundle) -> [BASForecastItem] { [] }
            func critique(candidates: [BASCandidatePath], forecasts: [BASForecastItem], hostContext: BASHostProfile) -> [BASCritiqueItem] { [] }

            func iterate(decomposeFrame: BASDecomposeFrame, memoryBundle: BASMemoryBundle, budget: BASBudgetFrame) -> BASThoughtFrame {
                BASThoughtFrame(
                    stepIndex: 2,
                    decomposeRef: "decomp-projection",
                    memoryRefs: ["m-1"],
                    candidates: [
                        BASCandidatePath(candidateID: "c-1", title: "Reply now", actionSummary: "Default reply.", expectedBenefit: 0.6, expectedCost: 0.2, reversibility: 0.8, confidence: 0.7),
                        BASCandidatePath(candidateID: "c-2", title: "Pause", actionSummary: "Default pause.", expectedBenefit: 0.5, expectedCost: 0.1, reversibility: 0.9, confidence: 0.8)
                    ],
                    forecasts: [
                        BASForecastItem(candidateID: "c-1", shortTermOutcome: "Default forecast.", midTermOutcome: "Default forecast.", worstCase: "Default forecast.", uncertainty: 0.3)
                    ],
                    critiques: [
                        BASCritiqueItem(candidateID: "c-1", critiqueType: .evidenceGap, critiqueText: "Default critique.", severity: 0.3)
                    ],
                    stabilityScore: 0.71,
                    stopReason: .candidateStable
                )
            }
        }

        struct TriSelf: BASTriSelfServicing {
            func mergeChoice(thoughtFrame: BASThoughtFrame, hostContext: BASHostProfile) -> ([BASTriSelfScore], BASMergedChoice) {
                (
                    [BASTriSelfScore(candidateID: "c-2", idScore: 0.42, egoScore: 0.79, superegoScore: 0.83, mergedScore: 0.80, veto: false)],
                    BASMergedChoice(candidateID: "c-2", title: "Pause and compare", actionSummary: "Hold the reply until the calmer option is clear.")
                )
            }
        }

        struct Risk: BASRiskServicing {
            func calibrateRisk(contextFrame: BASContextFrame, thoughtFrame: BASThoughtFrame, triScores: [BASTriSelfScore], budget: BASBudgetFrame) -> BASRiskCard {
                BASRiskCard(totalRisk: 0.22, riskLevel: .low, factors: ["risk.low"], uncertainty: 0.12, irreversibility: 0.08, manipulationStrength: 0.09, gsiScore: 0.13, recommendedMode: .compare)
            }

            func computeGSI(contextFrame: BASContextFrame, thoughtFrame: BASThoughtFrame) -> Double { 0.13 }

            func gateAction(contextFrame: BASContextFrame, thoughtFrame: BASThoughtFrame, triScores: [BASTriSelfScore], budget: BASBudgetFrame) -> (BASRiskCard, BASActionPermit) {
                (
                    calibrateRisk(contextFrame: contextFrame, thoughtFrame: thoughtFrame, triScores: triScores, budget: budget),
                    BASActionPermit(mode: .compare, reasonCodes: ["permit.compare"], requireSecondCheck: false, outputLengthCap: 180, tonePolicy: "steady", templatePolicy: "compare")
                )
            }
        }

        struct Action: BASActionServicing {
            func render(choice: BASMergedChoice, riskCard: BASRiskCard, permit: BASActionPermit, hostContext: BASHostProfile) -> BASRenderedOutput {
                BASRenderedOutput(mode: permit.mode, headline: choice.title, body: choice.actionSummary)
            }
        }

        struct Evolution: BASEvolutionServicing {
            func buildTickets(thoughtFrame: BASThoughtFrame, output: BASRenderedOutput, feedbackEvent: BASFeedbackEvent?) -> [BASUpdateTicket] { [] }
        }

        let coordinator = BASEBrainRuntimeCoordinator(
            powerClockService: PowerClock(),
            hostProfileService: Host(),
            contextService: Context(),
            decomposeService: Decompose(),
            memoryService: Memory(),
            neuralCoreService: NeuralCore(),
            loopService: Loop(),
            triSelfService: TriSelf(),
            riskService: Risk(),
            actionService: Action(),
            evolutionService: Evolution()
        )

        let result = coordinator.runTurn(
            BASEBrainTurnRequest(
                userInput: "Compare the next two replies and keep it bounded.",
                deviceState: BASDeviceState(
                    batteryLevel: 0.92,
                    thermalLevel: .nominal,
                    memoryFreeMB: 2048,
                    networkState: .online,
                    foregroundState: .foreground,
                    cpuLoad: 0.14,
                    gpuLoad: 0.09,
                    npuAvailable: true,
                    latencyBudgetMs: 1700
                ),
                hostID: "host.public-projection"
            )
        )

        #expect(result.thoughtFrame.candidates.map(\.candidateID) == ["c-2", "c-1"])
        #expect(result.thoughtFrame.candidates.first?.title == "Pause and compare")
        #expect(result.thoughtFrame.forecasts.count == 1)
        #expect(result.thoughtFrame.forecasts.first?.shortTermOutcome == "Projection-owned short term.")
        #expect(result.thoughtFrame.critiques.count == 1)
        #expect(result.thoughtFrame.critiques.first?.critiqueText == "Projection-owned critique.")
        #expect(result.renderedOutput.headline == "Pause and compare")
        #expect(result.thoughtFold.compactSlots["projection_lead_candidate"] == "c-2")
        #expect(result.thoughtFold.compactSlots["projection_candidates"] == "2")
        #expect(result.thoughtFold.compactSlots["projection_forecasts"] == "1")
        #expect(result.thoughtFold.compactSlots["projection_critiques"] == "1")
        #expect(result.runtimeTrace.layerEvents.contains(where: {
            $0.layerID == "L2" && $0.detail.contains("projection c-2/1/1")
        }))
    }

    @Test("active kill switches become executable runtime policy")
    func activeKillSwitchesAffectRuntimeExecution() {
        struct PowerClock: BASPowerClockServicing {
            func planBudget(deviceState: BASDeviceState, taskPing: String, riskHint: BASBrainRiskLevel?) -> BASBudgetFrame {
                BASBudgetFrame(
                    runMode: .sentinel,
                    maxLoops: 1,
                    maxCandidates: 1,
                    maxDecodeTokens: 120,
                    retrievalDepth: 1,
                    precisionProfile: .balanced,
                    deviceRoute: .scoutCPU,
                    thermalGuardLevel: .nominal,
                    maintenanceAllowed: false
                )
            }

            func routeDevice(deviceState: BASDeviceState, budget: BASBudgetFrame) -> BASDeviceRoute { .scoutCPU }
            func scheduleMaintenance(deviceState: BASDeviceState, budget: BASBudgetFrame) -> Bool { false }
        }

        struct Host: BASHostProfileServicing {
            func resolveHost(hostID: String, contextFrame: BASContextFrame?, riskCard: BASRiskCard?) -> BASHostProfile {
                BASHostProfile(hostID: hostID)
            }

            func applyHostGate(profile: BASHostProfile, taskType: BASContextTaskType, riskCard: BASRiskCard?, confidence: Double) -> Double { 0.8 }

            func rollbackHostVersion(profile: BASHostProfile, to versionID: String) -> BASHostVersion {
                BASHostVersion(versionID: versionID, changedFields: [], reason: "rollback", approvedByPolicy: true)
            }
        }

        struct Context: BASContextServicing {
            func analyzeContext(userInput: String, hostContext: BASHostProfile, budget: BASBudgetFrame) -> BASContextFrame {
                BASContextFrame(
                    utterance: userInput,
                    taskType: .task,
                    emotionalLoad: 0.25,
                    timePressure: 0.2,
                    relationPattern: "operator",
                    ambiguityScore: 0.1,
                    consequenceLevel: 0.3,
                    manipulationHints: [],
                    hostRelevance: 0.4
                )
            }
        }

        struct Decompose: BASDecomposeServicing {
            func decompose(contextFrame: BASContextFrame, memoryHints: [String]) -> BASDecomposeFrame {
                BASDecomposeFrame(
                    facts: ["Need an answer"],
                    goals: ["Respond"],
                    emotions: ["neutral"],
                    unknowns: [],
                    contradictions: [],
                    pressureSignals: [],
                    manipulationSignals: [],
                    mirrorText: "Need an answer."
                )
            }

            func mirror(contextFrame: BASContextFrame, decomposeFrame: BASDecomposeFrame) -> String { decomposeFrame.mirrorText }
            func checkContradiction(contextFrame: BASContextFrame, decomposeFrame: BASDecomposeFrame) -> [String] { [] }
        }

        struct Memory: BASMemoryServicing {
            func retrieve(decomposeFrame: BASDecomposeFrame, hostContext: BASHostProfile, budget: BASBudgetFrame) -> BASMemoryBundle {
                BASMemoryBundle(atoms: [], retrievalTags: [], activeHostVersion: hostContext.activeVersion)
            }

            func promote(atom: BASMemoryAtom, hostContext: BASHostProfile) -> BASPromotionState { .admitted }
            func freeze(memoryID: String) -> Bool { false }
        }

        struct Loop: BASLoopServicing {
            func proposePaths(decomposeFrame: BASDecomposeFrame, memoryBundle: BASMemoryBundle, budget: BASBudgetFrame) -> [BASCandidatePath] {
                [
                    BASCandidatePath(
                        candidateID: "candidate-1",
                        title: "Direct answer",
                        actionSummary: "Answer immediately.",
                        expectedBenefit: 0.7,
                        expectedCost: 0.1,
                        reversibility: 0.8,
                        confidence: 0.8
                    )
                ]
            }

            func forecast(candidates: [BASCandidatePath], decomposeFrame: BASDecomposeFrame, memoryBundle: BASMemoryBundle) -> [BASForecastItem] {
                candidates.map {
                    BASForecastItem(
                        candidateID: $0.candidateID,
                        shortTermOutcome: "Immediate response",
                        midTermOutcome: "Okay",
                        worstCase: "Needs review",
                        uncertainty: 0.2
                    )
                }
            }

            func critique(candidates: [BASCandidatePath], forecasts: [BASForecastItem], hostContext: BASHostProfile) -> [BASCritiqueItem] { [] }

            func iterate(decomposeFrame: BASDecomposeFrame, memoryBundle: BASMemoryBundle, budget: BASBudgetFrame) -> BASThoughtFrame {
                let candidates = proposePaths(decomposeFrame: decomposeFrame, memoryBundle: memoryBundle, budget: budget)
                return BASThoughtFrame(
                    stepIndex: 1,
                    decomposeRef: "decomp",
                    memoryRefs: [],
                    candidates: candidates,
                    forecasts: forecast(candidates: candidates, decomposeFrame: decomposeFrame, memoryBundle: memoryBundle),
                    critiques: [],
                    stabilityScore: 0.6,
                    stopReason: .candidateStable
                )
            }
        }

        struct TriSelf: BASTriSelfServicing {
            func mergeChoice(thoughtFrame: BASThoughtFrame, hostContext: BASHostProfile) -> ([BASTriSelfScore], BASMergedChoice) {
                (
                    [BASTriSelfScore(candidateID: "candidate-1", idScore: 0.7, egoScore: 0.7, superegoScore: 0.4, mergedScore: 0.75, veto: false)],
                    BASMergedChoice(candidateID: "candidate-1", title: "Direct answer", actionSummary: "Answer immediately.")
                )
            }
        }

        struct Risk: BASRiskServicing {
            func calibrateRisk(contextFrame: BASContextFrame, thoughtFrame: BASThoughtFrame, triScores: [BASTriSelfScore], budget: BASBudgetFrame) -> BASRiskCard {
                BASRiskCard(
                    totalRisk: 0.42,
                    riskLevel: .medium,
                    factors: ["watch"],
                    uncertainty: 0.2,
                    irreversibility: 0.3,
                    manipulationStrength: 0.1,
                    gsiScore: 0.2,
                    recommendedMode: .answer
                )
            }

            func computeGSI(contextFrame: BASContextFrame, thoughtFrame: BASThoughtFrame) -> Double { 0.2 }

            func gateAction(contextFrame: BASContextFrame, thoughtFrame: BASThoughtFrame, triScores: [BASTriSelfScore], budget: BASBudgetFrame) -> (BASRiskCard, BASActionPermit) {
                (
                    calibrateRisk(contextFrame: contextFrame, thoughtFrame: thoughtFrame, triScores: triScores, budget: budget),
                    BASActionPermit(
                        mode: .answer,
                        reasonCodes: ["base.answer"],
                        requireSecondCheck: false,
                        outputLengthCap: 220,
                        tonePolicy: "direct",
                        templatePolicy: "answer"
                    )
                )
            }
        }

        struct Action: BASActionServicing {
            func render(choice: BASMergedChoice, riskCard: BASRiskCard, permit: BASActionPermit, hostContext: BASHostProfile) -> BASRenderedOutput {
                BASRenderedOutput(mode: permit.mode, headline: choice.title, body: choice.actionSummary)
            }
        }

        struct Evolution: BASEvolutionServicing {
            func buildTickets(thoughtFrame: BASThoughtFrame, output: BASRenderedOutput, feedbackEvent: BASFeedbackEvent?) -> [BASUpdateTicket] {
                [
                    BASUpdateTicket(
                        ticketID: "ticket-1",
                        sessionRef: "session",
                        summary: output.body,
                        memoryWriteSuggestion: "Store as long-term memory.",
                        confidence: 0.8,
                        requiresReview: false
                    )
                ]
            }
        }

        let coordinator = BASEBrainRuntimeCoordinator(
            powerClockService: PowerClock(),
            hostProfileService: Host(),
            contextService: Context(),
            decomposeService: Decompose(),
            memoryService: Memory(),
            loopService: Loop(),
            triSelfService: TriSelf(),
            riskService: Risk(),
            actionService: Action(),
            evolutionService: Evolution()
        )

        let result = coordinator.runTurn(
            BASEBrainTurnRequest(
                userInput: "Answer quickly.",
                deviceState: BASDeviceState(
                    batteryLevel: 0.82,
                    thermalLevel: .nominal,
                    memoryFreeMB: 2048,
                    networkState: .online,
                    foregroundState: .foreground,
                    cpuLoad: 0.2,
                    gpuLoad: 0.1,
                    npuAvailable: false,
                    latencyBudgetMs: 600
                ),
                hostID: "host.policy",
                riskHint: .low,
                activeKillSwitches: [.disableFastPath, .forceGuardMode, .forceProtectedPermit, .requireReviewedWrites]
            )
        )

        #expect(result.budgetFrame.runMode == .guard)
        #expect(result.budgetFrame.precisionProfile == .protected)
        #expect(result.actionPermit.mode == .delay)
        #expect(result.updateTickets.allSatisfy { $0.requiresReview })
        #expect(result.runtimeTrace.activeKillSwitches.contains(.disableFastPath))
        #expect(result.runtimeTrace.activeKillSwitches.contains(.forceGuardMode))
        #expect(result.runtimeTrace.activeKillSwitches.contains(.forceProtectedPermit))
        #expect(result.runtimeTrace.activeKillSwitches.contains(.requireReviewedWrites))
        #expect(result.runtimeTrace.guardrailFindings.contains(where: { $0.code == "kill_switch.disable_fast_path" }))
        #expect(result.runtimeTrace.guardrailFindings.contains(where: { $0.code == "kill_switch.force_guard_mode" }))
        #expect(result.runtimeTrace.guardrailFindings.contains(where: { $0.code == "kill_switch.force_protected_permit" }))
        #expect(result.runtimeTrace.guardrailFindings.contains(where: { $0.code == "kill_switch.require_reviewed_writes" }))
        #expect(result.runLease?.allowedMode == .guard)
        #expect(result.sovereignActuationCommands.contains(where: { $0.kind == .memoryFreeze }))
    }

    @Test("host runtime emits policy lineage, lease provenance, and sovereign execution receipts")
    func hostRuntimeEmitsFinalKernelTruth() throws {
        let lineage = BASRuntimePolicyLineage(
            bundleVersion: "policy.bundle.v1",
            providerRoutingRegistryVersion: "provider.registry.v1",
            providerRoutingPolicyID: "provider.rollout",
            runtimeTuningRegistryVersion: "runtime.registry.v4",
            runtimeTuningPolicyID: "runtime.guarded",
            resolutionSourceID: "bundled_default"
        )
        var runtimeTuning = BASEBrainRuntimeSynthesisPolicy.generic.withSchemaVersion(
            "runtime.guarded.policy-owned.v1"
        )
        runtimeTuning.wakeIntent.highRiskGuardThreshold = 0.69
        runtimeTuning.stateTransitions.quarantineFailureGuardThreshold = 3
        runtimeTuning.stateTransitions.runModeRules = runtimeTuning.stateTransitions.resolvedRunModeRules(
            wakeIntent: runtimeTuning.wakeIntent
        )
        runtimeTuning.lease.restrictedEnergyQuota = 0.46
        runtimeTuning.maintenance.standardBatteryFloor = 0.36
        runtimeTuning.sovereignExecution.deadStopOnExtremeBlockedPermit = false
        runtimeTuning.context.emotionalLoadDriftingIncrement = 0.09
        runtimeTuning.triSelf.directPathSuperegoPenalty = 0.46
        runtimeTuning.risk.defaultForecastUncertainty = 0.24

        let runtime = BASHostRuntime(
            configuration: BASHostConfiguration(
                runtimeProfileID: "host.runtime.v1",
                policyProfileID: "host.policy.v1",
                prefersPureLocal: true,
                console: .generic,
                lifecycleBehavior: .generic,
                workflowBehavior: .generic,
                cognitionBehavior: .generic,
                presentation: .generic,
                runtimeTuning: runtimeTuning,
                runtimePolicyLineage: lineage,
                hostRhythmProfile: BASHostRhythmProfile(
                    activeWindows: ["focus_window"],
                    highFocusWindows: ["deep_work"],
                    lowEnergyWindows: ["sleep_window"],
                    preferredInteractionStyle: "bounded_reflective",
                    sensitivityPeriods: ["late_night"]
                )
            )
        )

        let turn = try #require(
            runtime.startSession(
                BASHostSessionRequest(
                    kind: .interactive,
                    workflowProfile: .reflective,
                    surface: .application,
                    prompt: "I want to send a harsh message tonight.",
                    riskLevel: .high
                )
            ).eBrainTurn
        )

        #expect(turn.policyLineage == lineage)
        #expect(turn.budgetFrame.wakeIntentID == turn.wakeIntent.intentLevel.rawValue)
        #expect(turn.budgetFrame.allowedHeads == (turn.runLease?.validHeads ?? []))
        #expect(turn.budgetFrame.policyBundleVersion == lineage.bundleVersion)
        #expect(
            turn.budgetFrame.policyDecisionIDs
                == [lineage.providerRoutingPolicyID, lineage.runtimeTuningPolicyID]
        )
        #expect(turn.recoveryDisposition?.kind == .recovery || turn.recoveryDisposition == nil)
        #expect(turn.sovereignExecutionReceipts.map(\.kind) == turn.sovereignActuationCommands.map(\.kind))
        #expect(turn.sovereignExecutionReceipts.allSatisfy { $0.status == .executed })
        #expect(turn.evolutionLineageSummary.policyLineage == lineage)
        #expect(turn.evolutionLineageSummary.sovereignVerdict == turn.sovereignVerdict)
        #expect(
            turn.evolutionLineageSummary.sovereignCommitTokens
                == turn.sovereignCommitTokens
        )
        #expect(turn.evolutionLineageSummary.sovereignLock == turn.sovereignLock)
        #expect(
            turn.evolutionLineageSummary.quarantineRecords
                == turn.quarantineRecords
        )
        #expect(
            turn.evolutionLineageSummary.sovereignAuditEntry
                == turn.sovereignAuditEntry
        )
        #expect(
            turn.evolutionLineageSummary.sovereignExecutionReceipts.map(\.kind)
                == turn.sovereignExecutionReceipts.map(\.kind)
        )
    }
}
