import Foundation
import Testing
@testable import BASHostKit
@testable import BASObservability
@testable import BASMemory
@testable import BASOrchestration
@testable import BASOrchestration

/// @MainActor — retained as belt-and-braces (historically a SIGBUS guard, 27e0fcb2e):
/// the debug turn pipeline once needed ~550KB (runTurn 127KB frame + the 6-deep
/// BASEBrainTurnResult init delegation chain) and overflowed swift-testing's 512KB
/// cooperative-pool threads. The 2026-07-12 CoW box (12,200B value → 1 pointer, flat
/// inits) fixed that component — PROBE-PROVEN: this suite ran green on the cooperative
/// pool with @MainActor removed. The guard stays because runTurn's own frame is still
/// ~127KB and deeper pipeline stacks give little margin; main-thread is also the thread
/// class every sync XCTest turn test and production host uses。
@Suite("BASEBrain schemas")
@MainActor
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
            hostVersionRef: "host.v3",
            rollbackRef: "host.v2",
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
            derivedCandidateRefs: ["experience.ticket-host-change", "candidate.host_gate"],
            governanceRefs: ["trial.host_gate", "seal.host_gate"],
            confidence: 0.84,
            conflictFlag: true
        )

        #expect(ticket.hasPersistentMutationSuggestion)
        #expect(ticket.resolvedHostChangeCandidate == candidate)
        #expect(
            ticket.reviewDirectiveLine
            == "Review constitution change: review_host_gate_strength • host_gate_strength • conflict flagged"
        )
        #expect(ticket.actionDigestParts.contains("candidate.host_gate"))
        #expect(ticket.actionDigestParts.contains("review_host_gate_strength"))
        #expect(ticket.actionDigestParts.contains("experience.ticket-host-change"))
        #expect(ticket.actionDigestParts.contains("seal.host_gate"))

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
        #expect(
            decoded.resolvedHostChangeCandidate
            == BASHostChangeCandidate(
                candidateID: "legacy.ticket-legacy.host-mutation",
                changeType: "review_legacy_host_mutation",
                proposedDelta: ["legacy_host_profile_suggestion"],
                evidenceRefs: ["legacy:Always use the hardest tone."],
                cooldownUntil: Date(timeIntervalSince1970: 0),
                confidence: 0.73,
                conflictRefs: [],
                previewState: "legacy_bridge",
                approvalState: "pending_legacy_review"
            )
        )
        #expect(decoded.derivedCandidateRefs == [])
        #expect(decoded.governanceRefs == [])
        #expect(decoded.actionDigestParts.contains("legacy.ticket-legacy.host-mutation"))
        #expect(decoded.actionDigestParts.contains("review_legacy_host_mutation"))
        #expect(
            decoded.reviewDirectiveLine
            == "Review constitution change: review_legacy_host_mutation • legacy_host_profile_suggestion"
        )
    }

    @Test("rule candidate and host change candidate round trip governance metadata")
    func ruleCandidateAndHostChangeCandidateRoundTripGovernanceMetadata() throws {
        let ruleCandidate = BASRuleCandidate(
            ruleID: "rule.guard.block",
            summary: "Promote the bounded protective block pattern only after shadow trial.",
            sourceTicketIDs: ["ticket.guard.block"],
            scope: "protective_response",
            positiveCases: ["high_pressure.block"],
            negativeCases: ["low_risk.answer"],
            conflictRefs: ["triself.superego_veto"],
            outOfScope: ["routine chit-chat"],
            confidence: 0.78,
            shadowTrialState: "pending",
            rollbackRef: "checkpoint.previous",
            approvalState: .candidate
        )
        let changeCandidate = BASHostChangeCandidate(
            candidateID: "candidate.host.style",
            changeType: "preview_style_shift",
            proposedDelta: ["style:clearer_boundaries"],
            evidenceRefs: ["ticket.guard.block"],
            cooldownUntil: Date(timeIntervalSince1970: 1_701_000_000),
            confidence: 0.66,
            conflictRefs: ["style_conflict"],
            hostVersionRef: "host.v4",
            rollbackRef: "host.v3",
            previewState: "review_only",
            approvalState: "pending"
        )

        let ruleData = try JSONEncoder().encode(ruleCandidate)
        let changeData = try JSONEncoder().encode(changeCandidate)
        let decodedRule = try JSONDecoder().decode(BASRuleCandidate.self, from: ruleData)
        let decodedChange = try JSONDecoder().decode(BASHostChangeCandidate.self, from: changeData)

        #expect(decodedRule.outOfScope == ["routine chit-chat"])
        #expect(decodedRule.shadowTrialState == "pending")
        #expect(decodedRule.rollbackRef == "checkpoint.previous")
        #expect(decodedChange.hostVersionRef == "host.v4")
        #expect(decodedChange.rollbackRef == "host.v3")
    }

    @Test("stage-2 nursery schemas round trip with risk-pattern coverage")
    func stageTwoNurserySchemasRoundTrip() throws {
        let workflow = BASWorkflowCandidate(
            workflowID: "workflow.compare.review",
            taskDomain: "compare",
            steps: ["capture", "compare", "hold"],
            observedGain: 0.71,
            safetyNotes: ["host confirmation before send"],
            hostSpecific: true,
            shadowTrialState: "pending"
        )
        let guardTemplate = BASGuardTemplateCandidate(
            templateID: "guard.boundary.delay",
            sceneType: "high_pressure",
            boundaryScriptRef: "boundary.delay.v1",
            delayPacketRef: "delay.packet.v2",
            substituteRef: "substitute.compare.v1",
            protectiveGain: 0.82,
            overreachRisk: 0.24
        )
        let biasRecord = BASBiasRecord(
            biasID: "bias.soft_overreach",
            biasType: "soft_overreach",
            sourceRefs: ["turn.1", "turn.2"],
            severity: 0.63,
            recurrenceScore: 0.58,
            affectedLayers: ["L10", "L12", "L13"]
        )
        let exportBundle = BASLearningExportBundle(
            bundleID: "bundle.l13.1",
            candidateRefs: ["candidate.guard.1", "candidate.workflow.1"],
            scrubbed: true,
            privacySafe: true,
            sovereignSafe: true,
            evaluationTags: ["l13", "shadow_trial"]
        )
        let riskPattern = BASRiskPatternCandidate(
            patternID: "risk.pattern.high_pressure",
            sourceRefs: ["turn.1"],
            riskDomain: "high_pressure",
            triggerSignals: ["manipulation", "delay"],
            severity: 0.81,
            recurrenceScore: 0.52,
            sovereignReviewRequired: true,
            shadowTrialState: "pending"
        )

        let workflowData = try JSONEncoder().encode(workflow)
        let guardTemplateData = try JSONEncoder().encode(guardTemplate)
        let biasRecordData = try JSONEncoder().encode(biasRecord)
        let exportBundleData = try JSONEncoder().encode(exportBundle)
        let riskPatternData = try JSONEncoder().encode(riskPattern)

        let decodedWorkflow = try JSONDecoder().decode(BASWorkflowCandidate.self, from: workflowData)
        let decodedGuardTemplate = try JSONDecoder().decode(BASGuardTemplateCandidate.self, from: guardTemplateData)
        let decodedBiasRecord = try JSONDecoder().decode(BASBiasRecord.self, from: biasRecordData)
        let decodedExportBundle = try JSONDecoder().decode(BASLearningExportBundle.self, from: exportBundleData)
        let decodedRiskPattern = try JSONDecoder().decode(BASRiskPatternCandidate.self, from: riskPatternData)

        #expect(decodedWorkflow.shadowTrialState == "pending")
        #expect(decodedWorkflow.hostSpecific)
        #expect(decodedGuardTemplate.substituteRef == "substitute.compare.v1")
        #expect(decodedBiasRecord.affectedLayers == ["L10", "L12", "L13"])
        #expect(decodedExportBundle.scrubbed)
        #expect(decodedExportBundle.privacySafe)
        #expect(decodedExportBundle.sovereignSafe)
        #expect(decodedRiskPattern.riskDomain == "high_pressure")
        #expect(decodedRiskPattern.sovereignReviewRequired)
        #expect(decodedRiskPattern.shadowTrialState == "pending")
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
        let sovereignWarrant = BASSovereignWarrant(
            warrantID: "warrant-1",
            scope: .memoryWrite,
            actionDigest: sovereignToken.actionDigest,
            commitTokenRef: sovereignToken.tokenID,
            jurisdictionRef: "jurisdiction.memoryWrite",
            snapshotRef: "snapshot-1",
            timeLockRef: "timelock.turn-1.memoryWrite.ttl_30000",
            policyHash: "policy-hash-1",
            issuedAt: Date(timeIntervalSince1970: 1_705_000_000),
            expiresAt: Date(timeIntervalSince1970: 1_705_000_030),
            witnessRefs: [
                "permit.turn-1.memoryWrite",
                "integrity.snapshot-1",
                "continuity.turn-1",
                "policy.policy-hash-1",
                "mutation.memory.turn-1",
                "memory_target.ticket-1"
            ],
            singleUse: true,
            signature: "warrant-signature-1"
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
            memoryWriteAllowed: false,
            operatorReviewRequired: true,
            requiredConfirmations: ["operator_recovery_review"],
            allowedActionClasses: ["render_local_guidance", "inspect_state"],
            blockedActionClasses: ["tool_write", "memory_write"],
            remediationActions: ["recompile_current_brain_state", "review_bootstrap_diagnostics"]
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
        #expect(sovereignWarrant.schemaVersion == BASSovereignWarrant.currentSchemaVersion)
        #expect(sovereignWarrant.commitTokenRef == sovereignToken.tokenID)
        #expect(sovereignWarrant.policyHash == sovereignToken.policyHash)
        #expect(sovereignWarrant.witnessRefs.contains("mutation.memory.turn-1"))
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
        #expect(recoveryDisposition.operatorReviewRequired)
        #expect(recoveryDisposition.requiredConfirmations == ["operator_recovery_review"])
        #expect(recoveryDisposition.allowedActionClasses == ["render_local_guidance", "inspect_state"])
        #expect(recoveryDisposition.blockedActionClasses == ["tool_write", "memory_write"])
        #expect(recoveryDisposition.remediationActions == ["recompile_current_brain_state", "review_bootstrap_diagnostics"])
        #expect(host.schemaVersion == BASHostProfile.currentSchemaVersion)
        #expect(atom.schemaVersion == BASMemoryAtom.currentSchemaVersion)
        #expect(thought.schemaVersion == BASThoughtFrame.currentSchemaVersion)
        #expect(risk.schemaVersion == BASRiskCard.currentSchemaVersion)
        #expect(ticket.schemaVersion == BASUpdateTicket.currentSchemaVersion)
    }

    @Test("recovery disposition decodes legacy payloads without operator contract fields")
    func recoveryDispositionBackwardDecodeUsesSafeOperatorContractDefaults() throws {
        let legacyObject: [String: Any] = [
            "schemaVersion": "1.0.0",
            "kind": "recovery",
            "summary": "Bootstrap fallback forced the turn into recovery.",
            "reasonCodes": ["runtime.recovery"],
            "remediationRequired": true,
            "restrictedLease": true,
            "toolWriteAllowed": false,
            "memoryWriteAllowed": false
        ]

        let data = try JSONSerialization.data(withJSONObject: legacyObject)
        let decoded = try JSONDecoder().decode(BASRecoveryDisposition.self, from: data)

        #expect(decoded.kind == .recovery)
        #expect(decoded.operatorReviewRequired)
        #expect(decoded.requiredConfirmations.isEmpty)
        #expect(decoded.allowedActionClasses.isEmpty)
        #expect(decoded.blockedActionClasses.isEmpty)
        #expect(decoded.remediationActions.isEmpty)
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
            frontierWidth: 2,
            diversityScore: 0.58,
            delayedPaths: ["c-2"]
        )
        let counterfactual = BASCounterfactualBundle(
            candidateID: "c-1",
            shortTerm: "Short-term stabilization.",
            midTerm: "Mid-term bounded recovery.",
            worstCase: "Temporary friction remains.",
            uncertainty: 0.28,
            affectedDomains: ["relationship", "energy"]
        )
        let uncertaintyLedger = BASUncertaintyLedger(
            ledgerID: "uncertainty-1",
            unresolvedUnknowns: ["timing.confirmation"],
            weakPredictions: ["c-2"],
            highSensitivityPoints: ["c-1"],
            confidenceFloor: 0.44
        )
        let evidenceDebt = BASEvidenceDebt(
            debtID: "debt-1",
            candidateID: "c-1",
            missingEvidence: ["timing.confirmation"],
            validationActions: ["Validate: timing.confirmation"],
            debtWeight: 0.52
        )
        let convergence = BASConvergenceCertificate(
            certID: "cert-1",
            frontierID: "frontier.step-1",
            stabilityScore: 0.73,
            stoppingMode: .converged,
            recommendedNextStep: "Use the bounded path."
        )
        let loopLeaseReceipt = BASLoopLeaseReceipt(
            receiptID: "loop-receipt-1",
            leaseID: "lease-1",
            loopsUsed: 2,
            candidatesUsed: 2,
            projectionsUsed: 1,
            degraded: false
        )
        let sovereignBreakpointHint = BASSovereignBreakpointHint(
            hintID: "hint-1",
            sourceRef: "candidate.c-1",
            reasonCodes: ["boundary_conflict", "tool_cut"],
            affectedCandidates: ["c-1"],
            suggestedAction: .cut
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
        #expect(uncertaintyLedger.schemaVersion == BASUncertaintyLedger.currentSchemaVersion)
        #expect(evidenceDebt.schemaVersion == BASEvidenceDebt.currentSchemaVersion)
        #expect(convergence.schemaVersion == BASConvergenceCertificate.currentSchemaVersion)
        #expect(loopLeaseReceipt.schemaVersion == BASLoopLeaseReceipt.currentSchemaVersion)
        #expect(sovereignBreakpointHint.schemaVersion == BASSovereignBreakpointHint.currentSchemaVersion)
        #expect(critiqueBundle.schemaVersion == BASCritiqueBundle.currentSchemaVersion)
        #expect(binding.schemaVersion == BASRiskPermitBinding.currentSchemaVersion)
        #expect(toolIntent.schemaVersion == BASToolIntentEnvelope.currentSchemaVersion)
        #expect(leaseReceipt.schemaVersion == BASNeuralLeaseReceipt.currentSchemaVersion)
    }

    @Test("risk climate schemas publish stable current versions")
    func riskClimateSchemasExposeStableCurrentVersion() {
        let hazardVector = BASHazardVector(
            harmSeverity: 0.74,
            harmScope: 0.63,
            irreversibility: 0.66,
            uncertainty: 0.48,
            evidenceDebt: 0.41,
            manipulationIntensity: 0.58,
            pressureAuthenticity: 0.22,
            vulnerabilityCoupling: 0.52,
            sideEffectScope: 0.61
        )
        let harmRadius = BASHarmRadiusMap(
            radiusID: "radius-1",
            privateImpact: 0.44,
            relationImpact: 0.78,
            workflowImpact: 0.32,
            publicImpact: 0.09,
            longTermTrace: 0.69
        )
        let reversibility = BASReversibilityProfile(
            profileID: "rev-1",
            reversible: false,
            rollbackCost: 0.83,
            confirmNodes: ["external_send"],
            draftSafe: true,
            smallStepPossible: true
        )
        let evidence = BASEvidenceSufficiency(
            sufficiencyID: "evidence-1",
            supportLevel: 0.38,
            missingEvidence: ["timeline.confirmation"],
            allowedAssertionLevel: "guarded",
            allowedActionLevel: "draft_only"
        )
        let gsiTrace = BASGSITrace(
            traceID: "gsi-1",
            gaslightSignals: ["urgency.masked"],
            coerciveUrgency: 0.72,
            shamePressure: 0.34,
            authorityMask: 0.28,
            relationLeverage: 0.62,
            susceptibilityBand: "elevated"
        )
        let vulnerability = BASVulnerabilityCoupling(
            couplingID: "vulnerability-1",
            touchedBoundaries: ["relationship"],
            lowEnergyResonance: 0.55,
            sensitivityWindow: 0.71,
            protectionBias: 0.68
        )
        let escalation = BASSovereignEscalationHint(
            hintID: "hint-1",
            sourceRefs: ["candidate.direct"],
            reasonCodes: ["l11.high_irreversibility"],
            urgency: "high",
            suggestedScope: "tool"
        )
        let riskField = BASRiskField(
            fieldID: "field-1",
            candidateRef: "candidate.direct",
            hazardVector: hazardVector,
            harmRadius: harmRadius,
            reversibilityProfile: reversibility,
            evidenceSufficiency: evidence,
            gsiTrace: gsiTrace,
            vulnerabilityCoupling: vulnerability,
            confidenceBand: "guarded"
        )
        let substitute = BASProtectiveSubstitute(
            substituteID: "sub-1",
            sourceCandidateRef: "candidate.direct",
            substituteType: "draft",
            description: "Keep the response in draft form.",
            safetyGain: 0.61
        )
        let delayReservation = BASDelayReservation(
            reservationID: "delay-1",
            delayType: "cool_down",
            minDelay: 900,
            maxDelay: 3600,
            allowedIntermediateActions: ["compare", "draft_only"]
        )
        let modeDecision = BASActionModeDecision(
            decisionID: "mode-1",
            primaryMode: .delay,
            stackedModes: [.draftOnly],
            reasonCodes: ["risk.high", "irreversible"],
            confidence: 0.82
        )
        let permit = BASActionPermit(
            mode: .delay,
            stackedModes: [.draftOnly],
            reasonCodes: ["risk.high"],
            allowedDomains: ["bounded_reply", "draft_workspace"],
            blockedDomains: ["tool_commit", "memory_commit"],
            assertionCeiling: "guarded",
            toolScope: "read_only",
            memoryScope: "review_required",
            requireMirror: true,
            requireCompare: true,
            requireSecondCheck: true,
            outputLengthCap: 160,
            tonePolicy: "calm_protective",
            templatePolicy: "delay_with_draft",
            delayWindow: "cool_down",
            substituteRequired: true,
            escalationHintRef: escalation.hintID
        )
        let riskCard = BASRiskCard(
            totalRisk: 0.81,
            riskLevel: .high,
            factors: ["risk.high", "gsi.elevated"],
            uncertainty: 0.48,
            irreversibility: 0.66,
            manipulationStrength: 0.58,
            gsiScore: 0.74,
            recommendedMode: .delay,
            stackedModes: [.draftOnly],
            assertionCeiling: "guarded",
            delayType: "cool_down",
            substituteType: "draft",
            sovereignHintLevel: "high"
        )
        let package = BASRiskDecisionPackage(
            packageID: "package-1",
            riskCard: riskCard,
            riskField: riskField,
            actionModeDecision: modeDecision,
            actionPermit: permit,
            delayReservation: delayReservation,
            protectiveSubstitute: substitute,
            sovereignEscalationHint: escalation
        )

        #expect(hazardVector.schemaVersion == BASHazardVector.currentSchemaVersion)
        #expect(harmRadius.schemaVersion == BASHarmRadiusMap.currentSchemaVersion)
        #expect(reversibility.schemaVersion == BASReversibilityProfile.currentSchemaVersion)
        #expect(evidence.schemaVersion == BASEvidenceSufficiency.currentSchemaVersion)
        #expect(gsiTrace.schemaVersion == BASGSITrace.currentSchemaVersion)
        #expect(vulnerability.schemaVersion == BASVulnerabilityCoupling.currentSchemaVersion)
        #expect(riskField.schemaVersion == BASRiskField.currentSchemaVersion)
        #expect(modeDecision.schemaVersion == BASActionModeDecision.currentSchemaVersion)
        #expect(delayReservation.schemaVersion == BASDelayReservation.currentSchemaVersion)
        #expect(substitute.schemaVersion == BASProtectiveSubstitute.currentSchemaVersion)
        #expect(escalation.schemaVersion == BASSovereignEscalationHint.currentSchemaVersion)
        #expect(package.schemaVersion == BASRiskDecisionPackage.currentSchemaVersion)
        #expect(permit.stackedModes == [.draftOnly])
        #expect(riskCard.stackedModes == [.draftOnly])
    }

    @Test("risk permit schemas decode legacy payloads into safe defaults")
    func riskPermitSchemasDecodeLegacyPayloadsIntoSafeDefaults() throws {
        let legacyPermitPayload = """
        {
          "schemaVersion":"1.0.0",
          "mode":"delay",
          "reasonCodes":["risk.high"],
          "requireSecondCheck":true,
          "outputLengthCap":180,
          "tonePolicy":"calm_protective",
          "templatePolicy":"delay_with_alternative"
        }
        """.data(using: .utf8)!

        let legacyRiskCardPayload = """
        {
          "schemaVersion":"1.0.0",
          "totalRisk":0.82,
          "riskLevel":"high",
          "factors":["risk.high"],
          "uncertainty":0.44,
          "irreversibility":0.71,
          "manipulationStrength":0.55,
          "gsiScore":0.69,
          "recommendedMode":"delay"
        }
        """.data(using: .utf8)!

        let decodedPermit = try JSONDecoder().decode(BASActionPermit.self, from: legacyPermitPayload)
        let decodedRiskCard = try JSONDecoder().decode(BASRiskCard.self, from: legacyRiskCardPayload)

        #expect(decodedPermit.stackedModes.isEmpty)
        #expect(decodedPermit.allowedDomains.isEmpty)
        #expect(decodedPermit.blockedDomains.isEmpty)
        #expect(decodedPermit.assertionCeiling == "guarded")
        #expect(decodedPermit.toolScope == "bounded")
        #expect(decodedPermit.memoryScope == "standard")
        #expect(decodedPermit.requireMirror == false)
        #expect(decodedPermit.requireCompare == false)
        #expect(decodedPermit.delayWindow == nil)
        #expect(decodedPermit.substituteRequired == false)
        #expect(decodedPermit.escalationHintRef == nil)

        #expect(decodedRiskCard.stackedModes.isEmpty)
        #expect(decodedRiskCard.assertionCeiling == "standard")
        #expect(decodedRiskCard.delayType == nil)
        #expect(decodedRiskCard.substituteType == nil)
        #expect(decodedRiskCard.sovereignHintLevel == nil)
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
        let thermalExchange = BASThermalExchangeFrame(
            exchangeID: "thermal.guard",
            exchangeMode: "protective_exchange",
            predictedThermalBand: "hot",
            coolingActions: ["delay_cold_organs", "trim_noncritical_precision"],
            suppressedOrgans: [.criticBlade, .simuRing],
            reroutedOrgans: [.permitKnot],
            rerouteTargets: ["permitKnot": "scoutCPU"],
            precisionDowngradePlan: [
                BASNeuralOrganPrecision(organ: .hostModulationMesh, tier: .balanced)
            ],
            exchangeReasonCodes: ["thermal.hot", "guard.watch"]
        )
        #expect(morphGraph.schemaVersion == BASMorphGraph.currentSchemaVersion)
        #expect(hotColdMap.schemaVersion == BASHotColdMap.currentSchemaVersion)
        #expect(precisionProfile.schemaVersion == BASPrecisionProfile.currentSchemaVersion)
        #expect(resumeFrame.schemaVersion == BASResumeFrame.currentSchemaVersion)
        #expect(rollbackAnchor.schemaVersion == BASRollbackAnchor.currentSchemaVersion)
        #expect(lungState.schemaVersion == BASLungState.currentSchemaVersion)
        #expect(thermalExchange.schemaVersion == BASThermalExchangeFrame.currentSchemaVersion)
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
        #expect(decodedFold.thermalExchangeRef == nil)
        #expect(decodedFold.integrityWeaveRef == nil)
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
        let runtime = BASHostRuntime(configuration: .fixtureGeneric)
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

    @Test("sovereign warrant decodes legacy payloads without witness metadata")
    func sovereignWarrantDecodesLegacyPayload() throws {
        let legacyPayload = """
        {
          "schemaVersion":"1.0.0",
          "warrantID":"warrant-legacy",
          "scope":"memoryWrite",
          "actionDigest":"digest-legacy",
          "jurisdictionRef":"jurisdiction.memoryWrite",
          "snapshotRef":"snapshot-legacy",
          "timeLockRef":"timelock.turn-legacy.memoryWrite.ttl_30000",
          "singleUse":true,
          "signature":"warrant-signature-legacy"
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(BASSovereignWarrant.self, from: legacyPayload)

        #expect(decoded.schemaVersion == "1.0.0")
        #expect(decoded.commitTokenRef == nil)
        #expect(decoded.policyHash.isEmpty)
        #expect(decoded.issuedAt == nil)
        #expect(decoded.expiresAt == nil)
        #expect(decoded.witnessRefs == [])
        #expect(decoded.singleUse)
    }

    /// M581 chapter 一百五十六 — verify substrate populates the 3
    /// newly-wired typed schema-mode projection fields
    /// (`kunlunHeavenGatePermit` / `kunlunRiverOriginTrace` /
    /// `yaochiSanctumEntry`) on each turn AND that they round-trip
    /// cleanly through Codable.
    @Test("turn result populates 3 new typed schema fields and round-trips")
    func turnResultThreeNewSchemaFieldsPopulatedAndRoundTrip() throws {
        let runtime = BASHostRuntime(configuration: .fixtureGeneric)
        let turn = try #require(
            runtime.startSession(
                BASHostSessionRequest(
                    kind: .interactive,
                    workflowProfile: .reflective,
                    surface: .application,
                    prompt: "Help me think this through.",
                    riskLevel: .medium
                )
            ).eBrainTurn
        )

        // All 3 new fields populated from substrate (chapter 156
        // empirical: 200/200 across 200-session synthetic).
        let permit = try #require(turn.kunlunHeavenGatePermit)
        let trace = try #require(turn.kunlunRiverOriginTrace)
        let sanctum = try #require(turn.yaochiSanctumEntry)

        // Schema versions pinned (regression guard against schema
        // drift breaking serialization).
        #expect(BASHeavenGatePermit.currentSchemaVersion == "1.0.0")
        #expect(BASRiverOriginTrace.currentSchemaVersion == "1.0.0")
        #expect(BASYaochiSanctumEntry.currentSchemaVersion == "1.0.0")

        // Pin substrate emission shape: gate has gateID with
        // tianmen prefix (deriveHeavenGateAuditProjection),
        // trace has river prefix (kunlunRiverTraceForAudit
        // construction), sanctum has yaochi prefix
        // (deriveYaochiAuditProjection).
        #expect(permit.gateID.hasPrefix("tianmen-"))
        #expect(trace.traceID.hasPrefix("river-"))
        #expect(sanctum.entryID.hasPrefix("yaochi-"))

        // Round-trip: encode whole turn → decode → 3 fields
        // preserved byte-equal.
        let data = try JSONEncoder().encode(turn)
        let decoded = try JSONDecoder().decode(
            BASEBrainTurnResult.self, from: data)
        #expect(decoded.kunlunHeavenGatePermit == permit)
        #expect(decoded.kunlunRiverOriginTrace == trace)
        #expect(decoded.yaochiSanctumEntry == sanctum)
    }

    /// M581 chapter 一百五十六 — backward-compat: legacy turn JSON
    /// without the 3 new fields decodes successfully with `nil`
    /// for the absent fields.
    @Test("turn result decodes legacy payloads without M581 schema fields")
    func turnResultBackwardDecodeWithoutM581Fields() throws {
        let runtime = BASHostRuntime(configuration: .fixtureGeneric)
        let turn = try #require(
            runtime.startSession(
                BASHostSessionRequest(
                    kind: .interactive,
                    workflowProfile: .primary,
                    surface: .application,
                    prompt: "ok",
                    riskLevel: .low
                )
            ).eBrainTurn
        )

        var turnObject = try #require(
            JSONSerialization.jsonObject(
                with: try JSONEncoder().encode(turn)
            ) as? [String: Any]
        )
        turnObject.removeValue(forKey: "kunlunHeavenGatePermit")
        turnObject.removeValue(forKey: "kunlunRiverOriginTrace")
        turnObject.removeValue(forKey: "yaochiSanctumEntry")

        let legacyData = try JSONSerialization.data(
            withJSONObject: turnObject)
        let decoded = try JSONDecoder().decode(
            BASEBrainTurnResult.self, from: legacyData)

        #expect(decoded.kunlunHeavenGatePermit == nil)
        #expect(decoded.kunlunRiverOriginTrace == nil)
        #expect(decoded.yaochiSanctumEntry == nil)
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
            && $0.detail.contains("constitution changes 1")
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
        runtimeTuning.stateTransitions.runModeRules = runtimeTuning.stateTransitions.synthesizedRunModeRules(
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
                defaultDeviceState: BASHostConfiguration.fixtureDefaultDeviceState,
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
        #expect(turn.sovereignExecutionReceipts.map { $0.kind } == turn.sovereignActuationCommands.map { $0.kind })
        #expect(turn.sovereignExecutionReceipts.allSatisfy { $0.status == BASSovereignExecutionStatus.executed })
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
            turn.evolutionLineageSummary.sovereignExecutionReceipts.map { $0.kind }
                == turn.sovereignExecutionReceipts.map { $0.kind }
        )
    }

    @Test("runtime coordinator carries the expanded L11 mode lattice through the turn result")
    func runtimeCoordinatorCarriesExpandedL11ModeLattice() {
        let scenarios: [L11Scenario] = [
            L11Scenario(
                name: "compare+mirror",
                package: makeL11RiskDecisionPackage(
                    primaryMode: .compare,
                    stackedModes: [.mirror],
                    riskLevel: .medium,
                    totalRisk: 0.44,
                    blockedDomains: ["tool_commit"]
                )
            ),
            L11Scenario(
                name: "delay+draftOnly",
                package: makeL11RiskDecisionPackage(
                    primaryMode: .delay,
                    stackedModes: [.draftOnly],
                    riskLevel: .high,
                    totalRisk: 0.74,
                    blockedDomains: ["tool_commit", "memory_commit"],
                    delayReservation: BASDelayReservation(
                        reservationID: "delay.c1",
                        delayType: "cool_down",
                        minDelay: 15,
                        maxDelay: 1_440,
                        allowedIntermediateActions: ["compare", "draft_only"]
                    )
                )
            ),
            L11Scenario(
                name: "replace+localOnly",
                package: makeL11RiskDecisionPackage(
                    primaryMode: .replace,
                    stackedModes: [.localOnly],
                    riskLevel: .high,
                    totalRisk: 0.79,
                    blockedDomains: ["tool_commit", "memory_commit", "host_commit"],
                    protectiveSubstitute: BASProtectiveSubstitute(
                        substituteID: "substitute.c1",
                        sourceCandidateRef: "c1",
                        substituteType: "local_only_action",
                        description: "Keep the action local and reversible first.",
                        safetyGain: 0.82
                    )
                )
            ),
            L11Scenario(
                name: "block+escalate",
                package: makeL11RiskDecisionPackage(
                    primaryMode: .block,
                    stackedModes: [.escalate],
                    riskLevel: .extreme,
                    totalRisk: 0.96,
                    blockedDomains: ["tool_commit", "memory_commit", "host_commit", "high_consequence_decode"],
                    sovereignEscalationHint: BASSovereignEscalationHint(
                        hintID: "hint.c1",
                        sourceRefs: ["risk-field.c1"],
                        reasonCodes: ["risk.sovereign_boundary"],
                        urgency: "high",
                        suggestedScope: "tool"
                    )
                )
            )
        ]

        for scenario in scenarios {
            let coordinator = BASEBrainRuntimeCoordinator(
                powerClockService: L11PowerClock(),
                hostProfileService: L11Host(),
                contextService: L11Context(),
                decomposeService: L11Decompose(),
                memoryService: L11Memory(),
                loopService: L11Loop(),
                triSelfService: L11TriSelf(),
                riskService: L11Risk(package: scenario.package),
                actionService: L11Action(),
                evolutionService: L11Evolution()
            )

            let result = coordinator.runTurn(
                BASEBrainTurnRequest(
                    userInput: "Stress-test \(scenario.name).",
                    deviceState: BASDeviceState(
                        batteryLevel: 0.61,
                        thermalLevel: .nominal,
                        memoryFreeMB: 2_048,
                        networkState: .online,
                        foregroundState: .foreground,
                        cpuLoad: 0.18,
                        gpuLoad: 0.06,
                        npuAvailable: true,
                        latencyBudgetMs: 1_200
                    ),
                    hostID: "host.l11"
                )
            )

            let package = try! #require(result.riskDecisionPackage)
            #expect(result.actionPermit.mode == scenario.package.actionPermit.mode)
            // M406 — Kunlun axis-deviation escalation is additive
            // (`.compare` may be appended to stackedModes when the
            // turn's axis-alignment requires a gate). The L11
            // contract is "every L11-decided mode flows through to
            // the result" — express that as subset containment so
            // that M406's additive doctrine and any future additive
            // escalation wires don't break the regression test.
            // The pre-escalation snapshot is still strictly equal
            // to the L11 lattice via `riskBindings.first.stackedModes`
            // below (line +5).
            for expectedMode in scenario.package.actionPermit.stackedModes {
                #expect(
                    result.actionPermit.stackedModes.contains(expectedMode),
                    "L11 stackedMode \(expectedMode) must flow through to result")
            }
            #expect(result.renderedOutput.mode == scenario.package.actionPermit.mode)
            #expect(result.thoughtFrame.riskDecisionPackage?.actionPermit.mode == scenario.package.actionPermit.mode)
            #expect(package.actionModeDecision.primaryMode == scenario.package.actionModeDecision.primaryMode)
            #expect(package.actionModeDecision.stackedModes == scenario.package.actionModeDecision.stackedModes)
            #expect(result.thoughtFrame.riskBindings?.first?.stackedModes == scenario.package.actionPermit.stackedModes)

            switch scenario.name {
            case "delay+draftOnly":
                #expect(package.delayReservation?.delayType == "cool_down")
                #expect(package.delayReservation?.allowedIntermediateActions.contains("draft_only") == true)
            case "replace+localOnly":
                #expect(package.protectiveSubstitute?.substituteType == "local_only_action")
                #expect(result.actionPermit.stackedModes.contains(.localOnly))
            case "block+escalate":
                #expect(package.sovereignEscalationHint?.urgency == "high")
                #expect(result.actionPermit.stackedModes.contains(.escalate))
            default:
                #expect(package.delayReservation == nil)
            }
        }
    }

    @Test("runtime coordinator projects L11 package controls into rendered surface metadata")
    func runtimeCoordinatorProjectsL11PackageControlsIntoRenderedSurfaceMetadata() {
        let scenarios: [L11Scenario] = [
            L11Scenario(
                name: "delay+draftOnly",
                package: makeL11RiskDecisionPackage(
                    primaryMode: .delay,
                    stackedModes: [.draftOnly],
                    riskLevel: .high,
                    totalRisk: 0.74,
                    blockedDomains: ["tool_commit", "memory_commit"],
                    delayReservation: BASDelayReservation(
                        reservationID: "delay.surface",
                        delayType: "cool_down",
                        minDelay: 15,
                        maxDelay: 1_440,
                        allowedIntermediateActions: ["compare", "draft_only"]
                    )
                )
            ),
            L11Scenario(
                name: "replace+localOnly",
                package: makeL11RiskDecisionPackage(
                    primaryMode: .replace,
                    stackedModes: [.localOnly],
                    riskLevel: .high,
                    totalRisk: 0.79,
                    blockedDomains: ["tool_commit", "memory_commit", "host_commit"],
                    protectiveSubstitute: BASProtectiveSubstitute(
                        substituteID: "substitute.surface",
                        sourceCandidateRef: "c1",
                        substituteType: "local_only_action",
                        description: "Keep the action local and reversible first.",
                        safetyGain: 0.82
                    )
                )
            ),
            L11Scenario(
                name: "block+escalate",
                package: makeL11RiskDecisionPackage(
                    primaryMode: .block,
                    stackedModes: [.escalate],
                    riskLevel: .extreme,
                    totalRisk: 0.96,
                    blockedDomains: ["tool_commit", "memory_commit", "host_commit", "high_consequence_decode"],
                    sovereignEscalationHint: BASSovereignEscalationHint(
                        hintID: "hint.surface",
                        sourceRefs: ["risk-field.c1"],
                        reasonCodes: ["risk.sovereign_boundary"],
                        urgency: "high",
                        suggestedScope: "tool"
                    )
                )
            )
        ]

        for scenario in scenarios {
            let coordinator = BASEBrainRuntimeCoordinator(
                powerClockService: L11PowerClock(),
                hostProfileService: L11Host(),
                contextService: L11Context(),
                decomposeService: L11Decompose(),
                memoryService: L11Memory(),
                loopService: L11Loop(),
                triSelfService: L11TriSelf(),
                riskService: L11Risk(package: scenario.package),
                actionService: L11Action(),
                evolutionService: L11Evolution()
            )

            let result = coordinator.runTurn(
                BASEBrainTurnRequest(
                    userInput: "Surface-test \(scenario.name).",
                    deviceState: BASDeviceState(
                        batteryLevel: 0.61,
                        thermalLevel: .nominal,
                        memoryFreeMB: 2_048,
                        networkState: .online,
                        foregroundState: .foreground,
                        cpuLoad: 0.18,
                        gpuLoad: 0.06,
                        npuAvailable: true,
                        latencyBudgetMs: 1_200
                    ),
                    hostID: "host.surface"
                )
            )

            let surface = try! #require(result.renderedOutput.surfaceGuide)
            #expect(surface.stackedModes == result.actionPermit.stackedModes)
            #expect(surface.tonePolicy == result.actionPermit.tonePolicy)
            #expect(surface.templatePolicy == result.actionPermit.templatePolicy)
            #expect(surface.outputLengthCap == result.actionPermit.outputLengthCap)
            #expect(surface.boundary.allowedDomains == result.actionPermit.allowedDomains)
            #expect(surface.boundary.blockedDomains == result.actionPermit.blockedDomains)
            #expect(surface.boundary.toolScope == result.actionPermit.toolScope)
            #expect(surface.boundary.memoryScope == result.actionPermit.memoryScope)
            #expect(surface.boundary.escalationHintRef == result.actionPermit.escalationHintRef)
            #expect(surface.agency.requiresCompare == result.actionPermit.requireCompare)
            #expect(surface.agency.requiresSecondCheck == result.actionPermit.requireSecondCheck)
            #expect(surface.disclosure.assertionCeiling == result.actionPermit.assertionCeiling)
            #expect(surface.disclosure.explanationCodes == result.renderedOutput.explanationCodes)

            switch scenario.name {
            case "delay+draftOnly":
                #expect(surface.agency.delayAvailable)
                #expect(surface.agency.chooseLaterAllowed)
                #expect(surface.agency.prefersDraftOnly)
                #expect(surface.delayReservation?.reservationID == "delay.surface")
                #expect(surface.delayReservation?.allowedIntermediateActions.contains("draft_only") == true)
                #expect(surface.protectiveSubstitute == nil)
                #expect(surface.sovereignEscalationHint == nil)
            case "replace+localOnly":
                #expect(surface.agency.localOnlyPreferred)
                #expect(surface.agency.chooseLaterAllowed)
                #expect(surface.protectiveSubstitute?.substituteID == "substitute.surface")
                #expect(surface.protectiveSubstitute?.description == "Keep the action local and reversible first.")
                #expect(surface.delayReservation == nil)
                #expect(surface.sovereignEscalationHint == nil)
            case "block+escalate":
                #expect(surface.agency.chooseLaterAllowed)
                #expect(surface.sovereignEscalationHint?.hintID == "hint.surface")
                #expect(surface.sovereignEscalationHint?.urgency == "high")
                #expect(surface.delayReservation == nil)
                #expect(surface.protectiveSubstitute == nil)
            default:
                Issue.record("Unhandled L11 scenario \(scenario.name)")
            }
        }
    }

    @Test("risk bindings keep tool, memory, and host domains independently gated")
    func riskBindingsKeepDomainsIndependentlyGated() {
        let thoughtFrame = BASThoughtFrame(
            stepIndex: 1,
            decomposeRef: "decomp-l11",
            candidates: [
                BASCandidatePath(
                    candidateID: "c1",
                    title: "Primary path",
                    actionSummary: "Use a bounded next step.",
                    expectedBenefit: 0.6,
                    expectedCost: 0.2,
                    reversibility: 0.8,
                    confidence: 0.72
                )
            ],
            forecasts: [
                BASForecastItem(
                    candidateID: "c1",
                    shortTermOutcome: "Contained move",
                    midTermOutcome: "Lower fallout",
                    worstCase: "Small delay",
                    uncertainty: 0.22
                )
            ],
            critiques: [
                BASCritiqueItem(
                    candidateID: "c1",
                    critiqueType: .boundaryConflict,
                    critiqueText: "Needs bounded release.",
                    severity: 0.4
                )
            ],
            organMap: BASNeuralOrganMap(
                morph: .deepLoop,
                activeOrgans: [.toolIntentMesh, .riskSpine, .permitKnot, .stubCore],
                precisionMap: [],
                routingPolicy: .deepLoopConvergence,
                sovereignConstraints: [],
                headGuarantees: ["tool_intent"]
            )
        )
        let mergedChoice = BASMergedChoice(candidateID: "c1", title: "Primary path", actionSummary: "Use a bounded next step.")
        let compareRisk = BASRiskCard(
            totalRisk: 0.41,
            riskLevel: .medium,
            factors: ["risk.medium"],
            uncertainty: 0.18,
            irreversibility: 0.24,
            manipulationStrength: 0.12,
            gsiScore: 0.16,
            recommendedMode: .compare
        )
        let comparePermit = BASActionPermit(
            mode: .compare,
            stackedModes: [.mirror],
            reasonCodes: ["risk.medium"],
            allowedDomains: ["bounded_reply", "comparison"],
            blockedDomains: ["tool_commit"],
            assertionCeiling: "guarded",
            toolScope: "none",
            memoryScope: "standard",
            requireMirror: true,
            requireCompare: true,
            requireSecondCheck: false,
            outputLengthCap: 220,
            tonePolicy: "structured_compare",
            templatePolicy: "two_path_compare"
        )
        let compareBindings = BASNeuralMaterializationCompiler.materializeRiskBindings(
            thoughtFrame: thoughtFrame,
            mergedChoice: mergedChoice,
            riskCard: compareRisk,
            actionPermit: comparePermit,
            riskLevelResolver: { _ in .medium }
        )
        let compareBinding = try! #require(compareBindings.first)
        #expect(compareBinding.allowedDomains.contains("comparison"))
        #expect(compareBinding.forbiddenDomains.contains("tool_commit"))
        #expect(compareBinding.forbiddenDomains.contains("memory_commit") == false)
        #expect(compareBinding.forbiddenDomains.contains("host_commit") == false)

        let localOnlyPermit = BASActionPermit(
            mode: .localOnly,
            stackedModes: [.replace],
            reasonCodes: ["risk.high"],
            allowedDomains: ["bounded_reply", "local_action"],
            blockedDomains: ["memory_commit", "host_commit", "public_release"],
            assertionCeiling: "guarded",
            toolScope: "local_only",
            memoryScope: "review_only",
            requireMirror: true,
            requireCompare: true,
            requireSecondCheck: true,
            outputLengthCap: 180,
            tonePolicy: "clear_firm",
            templatePolicy: "local_only_action",
            substituteRequired: true
        )
        let localBindings = BASNeuralMaterializationCompiler.materializeRiskBindings(
            thoughtFrame: thoughtFrame,
            mergedChoice: mergedChoice,
            riskCard: compareRisk,
            actionPermit: localOnlyPermit,
            riskLevelResolver: { _ in .high }
        )
        let localBinding = try! #require(localBindings.first)
        #expect(localBinding.allowedDomains.contains("local_action"))
        #expect(localBinding.forbiddenDomains.contains("memory_commit"))
        #expect(localBinding.forbiddenDomains.contains("host_commit"))
        #expect(localBinding.forbiddenDomains.contains("public_release"))
        #expect(localBinding.forbiddenDomains.contains("tool_commit") == false)

        let toolIntent = BASNeuralMaterializationCompiler.materializeToolIntent(
            thoughtFrame: thoughtFrame,
            mergedChoice: mergedChoice,
            actionPermit: localOnlyPermit
        )
        #expect(toolIntent?.blockedDomains.contains("memory_commit") == true)
        #expect(toolIntent?.blockedDomains.contains("host_commit") == true)
        #expect(toolIntent?.blockedDomains.contains("public_release") == true)
    }

    @Test("neural materialization derives phase1 dream-loop artifacts")
    func neuralMaterializationDerivesPhase1DreamLoopArtifacts() {
        let thoughtFrame = BASThoughtFrame(
            stepIndex: 2,
            decomposeRef: "decomp-l9-phase1",
            candidates: [
                BASCandidatePath(
                    candidateID: "c1",
                    title: "Reply with a bounded next step",
                    actionSummary: "Send a short bounded reply.",
                    requiredEvidence: ["Confirm the scope of the ask."],
                    expectedBenefit: 0.68,
                    expectedCost: 0.22,
                    reversibility: 0.82,
                    confidence: 0.76
                ),
                BASCandidatePath(
                    candidateID: "c2",
                    title: "Pause and gather one fact",
                    actionSummary: "Wait briefly and verify one missing fact.",
                    requiredEvidence: ["Need reply evidence."],
                    expectedBenefit: 0.55,
                    expectedCost: 0.16,
                    reversibility: 0.91,
                    confidence: 0.58
                )
            ],
            forecasts: [
                BASForecastItem(
                    candidateID: "c1",
                    shortTermOutcome: "Short-term calming.",
                    midTermOutcome: "Lower fallout.",
                    worstCase: "Small friction remains.",
                    uncertainty: 0.18
                ),
                BASForecastItem(
                    candidateID: "c2",
                    shortTermOutcome: "More certainty later.",
                    midTermOutcome: "Better timing.",
                    worstCase: "Delay discomfort.",
                    uncertainty: 0.61
                )
            ],
            critiques: [
                BASCritiqueItem(
                    candidateID: "c1",
                    critiqueType: .boundaryConflict,
                    critiqueText: "Needs tighter release radius.",
                    severity: 0.81
                ),
                BASCritiqueItem(
                    candidateID: "c2",
                    critiqueType: .evidenceGap,
                    critiqueText: "Still missing one key fact.",
                    severity: 0.67
                )
            ],
            organMap: BASNeuralOrganMap(
                morph: .deepLoop,
                activeOrgans: [.criticBlade, .riskSpine, .permitKnot, .tissueRouter],
                precisionMap: [],
                routingPolicy: .deepLoopConvergence,
                leaseRef: "lease-l9-phase1",
                sovereignConstraints: ["tool_cut"],
                headGuarantees: ["phase1_l9"]
            ),
            stabilityScore: 0.76,
            stopReason: .candidateStable
        )

        let artifacts = BASNeuralMaterializationCompiler.materializeThoughtArtifacts(
            thoughtFrame: thoughtFrame
        )

        let frontier = try! #require(artifacts.candidateFrontier)
        #expect(frontier.frontierWidth == 2)
        #expect(frontier.dominanceOrder == ["c1", "c2"])
        #expect(frontier.reversiblePaths == ["c1", "c2"])
        #expect(frontier.guardPaths == ["c1", "c2"])
        #expect(frontier.diversityScore > 0.40)
        #expect(frontier.delayedPaths == ["c2"])

        let counterfactualBundles = try! #require(artifacts.counterfactualBundles)
        #expect(counterfactualBundles.count == 2)
        let secondaryCounterfactual = counterfactualBundles.first(where: { $0.candidateID == "c2" })
        #expect(secondaryCounterfactual?.uncertainty == 0.61)

        let critiqueBundles = try! #require(artifacts.critiqueBundles)
        #expect(critiqueBundles.count == 2)
        let containsPrimaryCritique = critiqueBundles.contains { bundle in
            bundle.candidateID == "c1"
                && bundle.boundaryConflict == 0.81
                && bundle.critiqueStrength == 0.81
        }
        let containsSecondaryCritique = critiqueBundles.contains { bundle in
            bundle.candidateID == "c2"
                && bundle.evidenceGap == 0.67
                && bundle.critiqueStrength == 0.67
        }
        #expect(containsPrimaryCritique)
        #expect(containsSecondaryCritique)

        let uncertaintyLedger = try! #require(artifacts.uncertaintyLedger)
        #expect(uncertaintyLedger.weakPredictions.contains("c2"))
        #expect(uncertaintyLedger.confidenceFloor < 0.76)

        let evidenceDebts = try! #require(artifacts.evidenceDebts)
        #expect(evidenceDebts.count == 2)
        #expect(
            evidenceDebts.contains(where: {
                $0.candidateID == "c2" && $0.missingEvidence.contains("Need reply evidence.")
            })
        )

        let convergence = try! #require(artifacts.convergenceCertificate)
        #expect(convergence.stoppingMode == .converged)
        #expect(convergence.frontierID == "frontier.step-2")

        let loopLeaseReceipt = try! #require(artifacts.loopLeaseReceipt)
        #expect(loopLeaseReceipt.leaseID == "lease-l9-phase1")
        #expect(loopLeaseReceipt.candidatesUsed == 2)
        #expect(loopLeaseReceipt.projectionsUsed == 2)

        let breakpointHints = try! #require(artifacts.sovereignBreakpointHints)
        #expect(breakpointHints.count == 1)
        #expect(breakpointHints.first?.reasonCodes.contains("boundary_conflict") == true)
        #expect(breakpointHints.first?.suggestedAction == .cut)
    }

    @Test("convergence certificates preserve explicit guard-takeover stop reasons")
    func convergenceCertificatesPreserveGuardTakeoverStopReasons() {
        let thoughtFrame = BASThoughtFrame(
            stepIndex: 1,
            decomposeRef: "decomp-l9-guard",
            candidates: [
                BASCandidatePath(
                    candidateID: "guard-1",
                    title: "Delay and hold the boundary",
                    actionSummary: "Keep the next move reversible while the guard branch leads.",
                    requiredEvidence: ["Confirm one missing fact."],
                    expectedBenefit: 0.72,
                    expectedCost: 0.28,
                    reversibility: 0.92,
                    confidence: 0.74
                )
            ],
            forecasts: [
                BASForecastItem(
                    candidateID: "guard-1",
                    shortTermOutcome: "Protection stays intact.",
                    midTermOutcome: "The safer lane remains open.",
                    worstCase: "The decision stays delayed longer than wanted.",
                    uncertainty: 0.33
                )
            ],
            critiques: [
                BASCritiqueItem(
                    candidateID: "guard-1",
                    critiqueType: .evidenceGap,
                    critiqueText: "One fact is still missing.",
                    severity: 0.52
                )
            ],
            stabilityScore: 0.69,
            stopReason: .guardTakeover
        )

        let frontier = BASNeuralMaterializationCompiler.buildCandidateFrontier(
            from: thoughtFrame
        )
        let critiqueBundles = BASNeuralMaterializationCompiler.buildCritiqueBundles(
            from: thoughtFrame.critiques,
            candidates: thoughtFrame.candidates
        )
        let convergence = BASNeuralMaterializationCompiler.buildConvergenceCertificate(
            from: thoughtFrame,
            frontier: frontier,
            critiqueBundles: critiqueBundles
        )

        #expect(convergence?.stoppingMode == .guardTakeover)
    }

    @Test("convergence certificates preserve explicit lease-end stop reasons")
    func convergenceCertificatesPreserveLeaseEndStopReasons() {
        let thoughtFrame = BASThoughtFrame(
            stepIndex: 2,
            decomposeRef: "decomp-l9-lease",
            candidates: [
                BASCandidatePath(
                    candidateID: "lease-1",
                    title: "Wait for one more loop",
                    actionSummary: "Keep the path open until the next loop would add value.",
                    requiredEvidence: ["Need one more checkpoint."],
                    expectedBenefit: 0.63,
                    expectedCost: 0.31,
                    reversibility: 0.88,
                    confidence: 0.68
                )
            ],
            forecasts: [
                BASForecastItem(
                    candidateID: "lease-1",
                    shortTermOutcome: "A little more time.",
                    midTermOutcome: "Potentially cleaner decision.",
                    worstCase: "Lease expires before certainty improves.",
                    uncertainty: 0.41
                )
            ],
            critiques: [
                BASCritiqueItem(
                    candidateID: "lease-1",
                    critiqueType: .evidenceGap,
                    critiqueText: "The next loop still needs one checkpoint.",
                    severity: 0.49
                )
            ],
            stabilityScore: 0.61,
            stopReason: .maxLoopsReached
        )

        let frontier = BASNeuralMaterializationCompiler.buildCandidateFrontier(
            from: thoughtFrame
        )
        let critiqueBundles = BASNeuralMaterializationCompiler.buildCritiqueBundles(
            from: thoughtFrame.critiques,
            candidates: thoughtFrame.candidates
        )
        let convergence = BASNeuralMaterializationCompiler.buildConvergenceCertificate(
            from: thoughtFrame,
            frontier: frontier,
            critiqueBundles: critiqueBundles
        )

        #expect(convergence?.stoppingMode == .leaseEnd)
    }

    @Test("convergence certificates preserve explicit sovereign-cut stop reasons")
    func convergenceCertificatesPreserveSovereignCutStopReasons() {
        let thoughtFrame = BASThoughtFrame(
            stepIndex: 1,
            decomposeRef: "decomp-l9-cut",
            candidates: [
                BASCandidatePath(
                    candidateID: "cut-1",
                    title: "Direct release into a blocked zone",
                    actionSummary: "Push the direct path even though the sovereign cut has fired.",
                    requiredEvidence: ["Blocked domain review."],
                    expectedBenefit: 0.52,
                    expectedCost: 0.66,
                    reversibility: 0.34,
                    confidence: 0.42
                )
            ],
            forecasts: [
                BASForecastItem(
                    candidateID: "cut-1",
                    shortTermOutcome: "Fast movement.",
                    midTermOutcome: "Boundary debt rises.",
                    worstCase: "The path should not continue.",
                    uncertainty: 0.55
                )
            ],
            critiques: [
                BASCritiqueItem(
                    candidateID: "cut-1",
                    critiqueType: .boundaryConflict,
                    critiqueText: "This path no longer has sovereign clearance.",
                    severity: 0.91
                )
            ],
            stabilityScore: 0.44,
            stopReason: .blocked
        )

        let frontier = BASNeuralMaterializationCompiler.buildCandidateFrontier(
            from: thoughtFrame
        )
        let critiqueBundles = BASNeuralMaterializationCompiler.buildCritiqueBundles(
            from: thoughtFrame.critiques,
            candidates: thoughtFrame.candidates
        )
        let convergence = BASNeuralMaterializationCompiler.buildConvergenceCertificate(
            from: thoughtFrame,
            frontier: frontier,
            critiqueBundles: critiqueBundles
        )

        #expect(convergence?.stoppingMode == .sovereignCut)
    }

    @Test("generic host runtime carries dream-loop artifacts into tri-self court and risk outputs")
    func genericHostRuntimeCarriesDreamLoopArtifactsIntoDownstreamOutputs() throws {
        let runtime = BASHostRuntime(configuration: .fixtureGeneric)
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

        let frontier = try #require(turn.thoughtFrame.candidateFrontier)
        let uncertaintyLedger = try #require(turn.thoughtFrame.uncertaintyLedger)
        let evidenceDebts = try #require(turn.thoughtFrame.evidenceDebts)
        let convergence = try #require(turn.thoughtFrame.convergenceCertificate)
        let agencyReservation = try #require(turn.mergedChoice.agencyReservation)
        let remandOrders = try #require(turn.mergedChoice.remandOrders)
        let courtDecisionDraft = try #require(turn.mergedChoice.courtDecisionDraft)
        let riskPackage = try #require(turn.riskDecisionPackage)
        let updateTicket = try #require(turn.updateTickets.first)
        let loopTrace = try #require(turn.runtimeTrace.layerEvents.first(where: { $0.layerID == "L9" }))
        let renderTrace = try #require(turn.runtimeTrace.layerEvents.first(where: { $0.layerID == "L12" }))
        let evolutionTrace = try #require(turn.runtimeTrace.layerEvents.first(where: { $0.layerID == "L13" }))

        let selectedCandidateID = turn.mergedChoice.candidateID
        let selectedEvidenceDebt = try #require(
            evidenceDebts.first(where: { $0.candidateID == selectedCandidateID })
        )
        let l9Remand = try #require(
            remandOrders.first(where: { $0.targetLayer == "L9" })
        )
        let selectedMissingEvidence = try #require(selectedEvidenceDebt.missingEvidence.first)

        #expect(frontier.frontierWidth == turn.thoughtFrame.candidates.count)
        #expect(uncertaintyLedger.unresolvedUnknowns.isEmpty == false)
        #expect(selectedEvidenceDebt.debtWeight >= 0.5)
        #expect(agencyReservation.mode == .delayRight)
        #expect(agencyReservation.expiresWith == "guard_release")
        #expect(l9Remand.reasonCodes.contains("court.evidence_debt"))
        #expect(l9Remand.requiredWork.contains("Expand the guard branch before acting."))
        #expect(l9Remand.requiredWork.contains(selectedMissingEvidence))
        #expect(
            l9Remand.requiredWork.contains(where: { $0.contains("Validate:") })
        )
        #expect(convergence.stoppingMode == .guardTakeover)
        #expect(courtDecisionDraft.preferredCandidateID == selectedCandidateID)
        #expect(courtDecisionDraft.agencyMode == .delayRight)
        #expect(courtDecisionDraft.readinessLevel == "remand_pending")
        #expect(
            courtDecisionDraft.requiredDisclosures.contains(where: { disclosure in
                disclosure == selectedMissingEvidence
                    || disclosure.contains("delay-preferring")
            })
        )
        #expect(
            courtDecisionDraft.unresolvedCosts.contains("A guard branch took over the convergence path.")
        )
        #expect(riskPackage.riskField.candidateRef == selectedCandidateID)
        #expect(riskPackage.riskField.evidenceSufficiency.missingEvidence.contains(selectedMissingEvidence))
        #expect(
            riskPackage.riskField.hazardVector.evidenceDebt >= selectedEvidenceDebt.debtWeight
        )
        #expect(
            riskPackage.riskField.evidenceSufficiency.allowedActionLevel
                == turn.actionPermit.mode.rawValue
        )
        #expect(turn.actionPermit.reasonCodes.contains("dream_loop.guard_takeover"))
        #expect(turn.renderedOutput.headline == "Let the guard branch lead before release")
        #expect(
            turn.renderedOutput.body.contains(
                "The dream loop stopped because the guard branch became the safer lead."
            )
        )
        #expect(
            turn.renderedOutput.alternativeActions.first
                == "Follow the guard branch and keep the move reversible."
        )
        #expect(updateTicket.governanceRefs.contains("dream_loop:guardTakeover"))
        #expect(updateTicket.governanceRefs.contains("dream_loop:evidence_debt"))
        #expect(updateTicket.governanceRefs.contains("dream_loop:delay_branch"))
        #expect(loopTrace.detail.contains("convergence guardTakeover"))
        #expect(loopTrace.detail.contains("weak predictions 1"))
        #expect(renderTrace.detail.contains("dream loop guardTakeover"))
        #expect(renderTrace.detail.contains("agency delayRight"))
        #expect(evolutionTrace.detail.contains("dream loop guardTakeover"))
        #expect(evolutionTrace.detail.contains("evidence_debt"))
    }

    @Test("generic host runtime carries dream-loop sovereign cuts into tri-self court and risk outputs")
    func genericHostRuntimeCarriesDreamLoopSovereignCutsIntoDownstreamOutputs() throws {
        var runtimeTuning = BASEBrainRuntimeSynthesisPolicy.generic.withSchemaVersion(
            "host.runtime-synthesis.policy-owned.single-candidate.v1"
        )
        runtimeTuning.wakeIntent.highRiskGuardThreshold = 0.69
        runtimeTuning.stateTransitions.quarantineFailureGuardThreshold = 3
        runtimeTuning.stateTransitions.runModeRules = runtimeTuning.stateTransitions.synthesizedRunModeRules(
            wakeIntent: runtimeTuning.wakeIntent
        )
        runtimeTuning.lease.restrictedEnergyQuota = 0.46
        runtimeTuning.maintenance.standardBatteryFloor = 0.36
        runtimeTuning.sovereignExecution.deadStopOnExtremeBlockedPermit = false
        runtimeTuning.context.emotionalLoadDriftingIncrement = 0.09
        runtimeTuning.triSelf.directPathSuperegoPenalty = 0.46
        runtimeTuning.risk.defaultForecastUncertainty = 0.24
        runtimeTuning.budget.highRiskCandidates = 1
        runtimeTuning.budget.extremeRiskCandidates = 1
        runtimeTuning.budget.maxCandidateCount = 1
        runtimeTuning.budget.standardCandidateFloor = 1
        runtimeTuning.budget.protectedCandidateFloor = 1
        for mode in [BASEBrainRunMode.guard, .reflect, .engage, .deepLoop] {
            if var modeProfile = runtimeTuning.budget.runModeProfilesByID?[mode.rawValue] {
                modeProfile.maxCandidates = 1
                modeProfile.candidateCountCap = 1
                modeProfile.standardCandidateFloor = 1
                modeProfile.protectedCandidateFloor = 1
                runtimeTuning.budget.runModeProfilesByID?[mode.rawValue] = modeProfile
            }
        }

        var configuration = BASHostConfiguration.fixtureGeneric
        configuration.runtimeProfileID = "host.runtime.single-candidate-guard"
        configuration.policyProfileID = "host.policy.single-candidate-guard"
        configuration.runtimeTuning = runtimeTuning
        configuration.runtimePolicyLineage = BASRuntimePolicyLineage(
            bundleVersion: "policy.bundle.v1",
            providerRoutingRegistryVersion: "provider.registry.v1",
            providerRoutingPolicyID: "provider.rollout",
            runtimeTuningRegistryVersion: "runtime.registry.v1",
            runtimeTuningPolicyID: "runtime.single-candidate-guard",
            resolutionSourceID: "bundled_default"
        )
        configuration.hostRhythmProfile = BASHostRhythmProfile(
            activeWindows: ["focus_window"],
            highFocusWindows: ["deep_work"],
            lowEnergyWindows: ["sleep_window"],
            preferredInteractionStyle: "bounded_reflective",
            sensitivityPeriods: ["late_night"]
        )
        configuration.hostConstitution = BASHostConstitution(
            hostID: "host.runtime",
            goalSpine: BASGoalSpine(
                goals: ["Protect long-term trust."],
                priorityOrder: ["Protect before speed."]
            ),
            boundaryVeil: BASBoundaryVeil(
                hardNoGo: ["Do not send under coercion."],
                confirmRequired: ["Pause before high-consequence replies."]
            ),
            relationGravity: BASRelationGravityMap(
                nodes: ["relationship.partner"],
                highConsequenceLinks: ["relationship.partner"]
            )
        )

        let runtime = BASHostRuntime(configuration: configuration)
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

        let frontier = try #require(turn.thoughtFrame.candidateFrontier)
        let convergence = try #require(turn.thoughtFrame.convergenceCertificate)
        let agencyReservation = try #require(turn.mergedChoice.agencyReservation)
        let remandOrders = try #require(turn.mergedChoice.remandOrders)
        let courtDecisionDraft = try #require(turn.mergedChoice.courtDecisionDraft)
        let riskPackage = try #require(turn.riskDecisionPackage)
        let breakpointHint = try #require(turn.thoughtFrame.sovereignBreakpointHints?.first)
        let updateTicket = try #require(turn.updateTickets.first)
        let loopTrace = try #require(turn.runtimeTrace.layerEvents.first(where: { $0.layerID == "L9" }))
        let renderTrace = try #require(turn.runtimeTrace.layerEvents.first(where: { $0.layerID == "L12" }))
        let evolutionTrace = try #require(turn.runtimeTrace.layerEvents.first(where: { $0.layerID == "L13" }))

        #expect(frontier.frontierWidth == 1)
        #expect(turn.mergedChoice.candidateID == "path.direct")
        #expect(turn.thoughtFrame.stopReason == .blocked)
        #expect(breakpointHint.suggestedAction == .cut)
        #expect(breakpointHint.reasonCodes.contains("boundary_conflict"))
        #expect(convergence.stoppingMode == .sovereignCut)
        #expect(agencyReservation.mode == .noAutoMerge)
        #expect(agencyReservation.expiresWith == "sovereign_clearance")
        #expect(
            agencyReservation.reasons.contains(
                "A sovereign breakpoint invalidated the leading path before merge."
            )
        )
        let sovereignRemand = remandOrders.first(where: { $0.targetLayer == "L14" })
        #expect(sovereignRemand != nil)
        #expect(sovereignRemand?.reasonCodes.contains("court.sovereign_breakpoint") == true)
        #expect(sovereignRemand?.reasonCodes.contains("boundary_conflict") == true)
        #expect(courtDecisionDraft.readinessLevel == "remand_pending")
        #expect(
            courtDecisionDraft.unresolvedCosts.contains(
                "A sovereign breakpoint interrupted the convergence path."
            )
        )
        #expect(riskPackage.riskField.candidateRef == "path.direct")
        #expect(turn.actionPermit.reasonCodes.contains("dream_loop.sovereign_cut"))
        #expect(turn.actionPermit.reasonCodes.contains("dream_loop.sovereign_breakpoint"))
        #expect(turn.renderedOutput.headline == "Stop the move and honor the sovereign cut")
        #expect(
            turn.renderedOutput.body.contains(
                "The dream loop stopped because a sovereign breakpoint cut the lead path."
            )
        )
        #expect(
            turn.renderedOutput.alternativeActions.first
                == "Do not resume this path until sovereign clearance is restored."
        )
        #expect(updateTicket.governanceRefs.contains("dream_loop:sovereignCut"))
        #expect(updateTicket.governanceRefs.contains("dream_loop:breakpoint"))
        #expect(loopTrace.detail.contains("convergence sovereignCut"))
        #expect(loopTrace.detail.contains("breakpoints 1"))
        #expect(renderTrace.detail.contains("dream loop sovereignCut"))
        #expect(renderTrace.detail.contains("agency noAutoMerge"))
        #expect(evolutionTrace.detail.contains("dream loop sovereignCut"))
        #expect(evolutionTrace.detail.contains("breakpoint"))
    }

    @Test("policy-owned host runtime carries dream-loop lease endings into tri-self court and risk outputs")
    func policyOwnedHostRuntimeCarriesDreamLoopLeaseEndingsIntoDownstreamOutputs() throws {
        var runtimeTuning = BASEBrainRuntimeSynthesisPolicy.generic.withSchemaVersion(
            "host.runtime-synthesis.policy-owned.single-loop.v1"
        )
        runtimeTuning.wakeIntent.highRiskGuardThreshold = 0.69
        runtimeTuning.stateTransitions.quarantineFailureGuardThreshold = 3
        runtimeTuning.stateTransitions.runModeRules = runtimeTuning.stateTransitions.synthesizedRunModeRules(
            wakeIntent: runtimeTuning.wakeIntent
        )
        runtimeTuning.lease.restrictedEnergyQuota = 0.46
        runtimeTuning.maintenance.standardBatteryFloor = 0.36
        runtimeTuning.sovereignExecution.deadStopOnExtremeBlockedPermit = false
        runtimeTuning.context.emotionalLoadDriftingIncrement = 0.09
        runtimeTuning.triSelf.directPathSuperegoPenalty = 0.46
        runtimeTuning.risk.defaultForecastUncertainty = 0.24
        runtimeTuning.budget.lowRiskLoops = 1
        runtimeTuning.budget.mediumRiskLoops = 1
        runtimeTuning.budget.highRiskLoops = 1
        runtimeTuning.budget.extremeRiskLoops = 1
        runtimeTuning.budget.unstableLoopIncrement = 0
        runtimeTuning.budget.standardLoopFloor = 1
        runtimeTuning.budget.protectedLoopFloor = 1
        for mode in [
            BASEBrainRunMode.guard,
            .reflect,
            .engage,
            .deepLoop,
            .recovery,
            .quarantine
        ] {
            if var modeProfile = runtimeTuning.budget.runModeProfilesByID?[mode.rawValue] {
                modeProfile.maxLoops = 1
                modeProfile.unstableLoopIncrement = 0
                modeProfile.standardLoopFloor = 1
                modeProfile.protectedLoopFloor = 1
                runtimeTuning.budget.runModeProfilesByID?[mode.rawValue] = modeProfile
            }
        }

        var configuration = BASHostConfiguration.fixtureGeneric
        configuration.runtimeProfileID = "host.runtime.single-loop"
        configuration.policyProfileID = "host.policy.single-loop"
        configuration.runtimeTuning = runtimeTuning
        configuration.runtimePolicyLineage = BASRuntimePolicyLineage(
            bundleVersion: "policy.bundle.v1",
            providerRoutingRegistryVersion: "provider.registry.v1",
            providerRoutingPolicyID: "provider.rollout",
            runtimeTuningRegistryVersion: "runtime.registry.v1",
            runtimeTuningPolicyID: "runtime.single-loop",
            resolutionSourceID: "bundled_default"
        )
        configuration.hostRhythmProfile = BASHostRhythmProfile(
            activeWindows: ["focus_window"],
            highFocusWindows: ["deep_work"],
            lowEnergyWindows: ["sleep_window"],
            preferredInteractionStyle: "bounded_reflective",
            sensitivityPeriods: ["late_night"]
        )

        let runtime = BASHostRuntime(configuration: configuration)
        let request = BASHostSessionRequest(
            kind: .interactive,
            workflowProfile: .reflective,
            surface: .application,
            prompt: "Keep this bounded while I cool down.",
            riskLevel: .low
        )
        let seed = try runtime.startSession(request)
        var currentBrain = seed.currentBrain
        currentBrain.calibrationStatus = .watch

        let turn = runtime.buildEBrainTurn(
            request: request,
            currentBrain: currentBrain,
            projection: BASBrainProjection(records: [], candidates: [], recentEvents: []),
            deviceStateOverride: BASDeviceState(
                batteryLevel: 0.74,
                thermalLevel: .nominal,
                memoryFreeMB: 2_048,
                networkState: .online,
                foregroundState: .foreground,
                cpuLoad: 0.14,
                gpuLoad: 0.08,
                npuAvailable: true,
                latencyBudgetMs: 1_000
            )
        )

        let convergence = try #require(turn.thoughtFrame.convergenceCertificate)
        let agencyReservation = try #require(turn.mergedChoice.agencyReservation)
        let remandOrders = try #require(turn.mergedChoice.remandOrders)
        let leaseRemand = remandOrders.first(where: { $0.targetLayer == "L1" })
        let updateTicket = try #require(turn.updateTickets.first)
        let loopTrace = try #require(turn.runtimeTrace.layerEvents.first(where: { $0.layerID == "L9" }))
        let renderTrace = try #require(turn.runtimeTrace.layerEvents.first(where: { $0.layerID == "L12" }))
        let evolutionTrace = try #require(turn.runtimeTrace.layerEvents.first(where: { $0.layerID == "L13" }))

        #expect(turn.budgetFrame.maxLoops == 2)
        #expect(turn.thoughtFrame.stepIndex == turn.budgetFrame.maxLoops)
        #expect(turn.thoughtFrame.stopReason == .maxLoopsReached)
        #expect(convergence.stoppingMode == .leaseEnd)
        #expect(agencyReservation.mode == .noAutoMerge)
        #expect(agencyReservation.expiresWith == "fresh_lease")
        #expect(
            agencyReservation.reasons.contains(
                "The dream loop lease ended before the leading path stabilized enough for auto-merge."
            )
        )
        #expect(leaseRemand != nil)
        #expect(leaseRemand?.reasonCodes.contains("court.lease_end") == true)
        #expect(turn.actionPermit.reasonCodes.contains("dream_loop.lease_end"))
        #expect(
            turn.mergedChoice.courtDecisionDraft?.unresolvedCosts.contains(
                "The loop lease ended before full convergence."
            ) == true
        )
        #expect(turn.renderedOutput.headline == "Hold the move until a fresh loop lease is available")
        #expect(
            turn.renderedOutput.body.contains(
                "The dream loop stopped because the current lease ended before the lead path stabilized."
            )
        )
        #expect(
            turn.renderedOutput.alternativeActions.first
                == "Get a fresh loop lease before trying to merge this path."
        )
        #expect(updateTicket.governanceRefs.contains("dream_loop:leaseEnd"))
        #expect(loopTrace.detail.contains("convergence leaseEnd"))
        #expect(renderTrace.detail.contains("dream loop leaseEnd"))
        #expect(renderTrace.detail.contains("agency noAutoMerge"))
        #expect(evolutionTrace.detail.contains("dream loop leaseEnd"))
    }

    @Test("risk decision packages can raise sovereign escalation hints without replacing the primary permit")
    func riskDecisionPackagesRaiseSovereignHintsWithoutReplacingPrimaryPermit() {
        let package = makeL11RiskDecisionPackage(
            primaryMode: .block,
            stackedModes: [.escalate],
            riskLevel: .extreme,
            totalRisk: 0.98,
            blockedDomains: ["tool_commit", "memory_commit", "host_commit", "high_consequence_decode"],
            sovereignEscalationHint: BASSovereignEscalationHint(
                hintID: "hint.sovereign",
                sourceRefs: ["risk-field.c1"],
                reasonCodes: ["risk.sovereign_boundary"],
                urgency: "high",
                suggestedScope: "host"
            )
        )
        let coordinator = BASEBrainRuntimeCoordinator(
            powerClockService: L11PowerClock(),
            hostProfileService: L11Host(),
            contextService: L11Context(),
            decomposeService: L11Decompose(),
            memoryService: L11Memory(),
            loopService: L11Loop(),
            triSelfService: L11TriSelf(),
            riskService: L11Risk(package: package),
            actionService: L11Action(),
            evolutionService: L11Evolution()
        )

        let result = coordinator.runTurn(
            BASEBrainTurnRequest(
                userInput: "Push into an irreversible public move.",
                deviceState: BASDeviceState(
                    batteryLevel: 0.58,
                    thermalLevel: .nominal,
                    memoryFreeMB: 2_048,
                    networkState: .online,
                    foregroundState: .foreground,
                    cpuLoad: 0.22,
                    gpuLoad: 0.08,
                    npuAvailable: true,
                    latencyBudgetMs: 1_100
                ),
                hostID: "host.sovereign"
            )
        )

        let resolvedPackage = try! #require(result.riskDecisionPackage)
        #expect(resolvedPackage.actionPermit.mode == .block)
        #expect(resolvedPackage.actionPermit.stackedModes == [.escalate])
        #expect(resolvedPackage.sovereignEscalationHint?.urgency == "high")
        #expect(resolvedPackage.sovereignEscalationHint?.suggestedScope == "host")
        #expect(result.actionPermit.mode == .block)
        #expect(result.actionPermit.stackedModes.contains(.escalate))
    }
}

private struct L11Scenario {
    let name: String
    let package: BASRiskDecisionPackage
}

private struct L11PowerClock: BASPowerClockServicing {
    func planBudget(deviceState: BASDeviceState, taskPing: String, riskHint: BASBrainRiskLevel?) -> BASBudgetFrame {
        BASBudgetFrame(
            runMode: .deepLoop,
            maxLoops: 2,
            maxCandidates: 2,
            maxDecodeTokens: 240,
            retrievalDepth: 2,
            precisionProfile: .full,
            deviceRoute: .coreNPU,
            thermalGuardLevel: .nominal,
            maintenanceAllowed: false
        )
    }

    func routeDevice(deviceState: BASDeviceState, budget: BASBudgetFrame) -> BASDeviceRoute { budget.deviceRoute }
    func scheduleMaintenance(deviceState: BASDeviceState, budget: BASBudgetFrame) -> Bool { false }
}

private struct L11Host: BASHostProfileServicing {
    func resolveHost(hostID: String, contextFrame: BASContextFrame?, riskCard: BASRiskCard?) -> BASHostProfile {
        BASHostProfile(hostID: hostID, longTermGoals: ["Stay bounded"], noGoZones: ["host_commit"])
    }

    func applyHostGate(profile: BASHostProfile, taskType: BASContextTaskType, riskCard: BASRiskCard?, confidence: Double) -> Double {
        confidence
    }

    func rollbackHostVersion(profile: BASHostProfile, to versionID: String) -> BASHostVersion {
        BASHostVersion(versionID: versionID, changedFields: [], reason: "rollback", approvedByPolicy: true)
    }
}

private struct L11Context: BASContextServicing {
    func analyzeContext(userInput: String, hostContext: BASHostProfile, budget: BASBudgetFrame) -> BASContextFrame {
        BASContextFrame(
            utterance: userInput,
            taskType: .task,
            emotionalLoad: 0.34,
            timePressure: 0.41,
            relationPattern: "peer",
            ambiguityScore: 0.22,
            consequenceLevel: 0.54,
            manipulationHints: [],
            hostRelevance: 0.68
        )
    }
}

private struct L11Decompose: BASDecomposeServicing {
    func decompose(contextFrame: BASContextFrame, memoryHints: [String]) -> BASDecomposeFrame {
        BASDecomposeFrame(
            facts: ["A bounded next step is needed."],
            goals: ["Preserve reversibility"],
            emotions: ["concern"],
            unknowns: ["Need one more fact"],
            contradictions: [],
            pressureSignals: [],
            manipulationSignals: [],
            mirrorText: "Slow the move down before it leaves the room."
        )
    }

    func mirror(contextFrame: BASContextFrame, decomposeFrame: BASDecomposeFrame) -> String {
        decomposeFrame.mirrorText
    }

    func checkContradiction(contextFrame: BASContextFrame, decomposeFrame: BASDecomposeFrame) -> [String] {
        []
    }
}

private struct L11Memory: BASMemoryServicing {
    func retrieve(decomposeFrame: BASDecomposeFrame, hostContext: BASHostProfile, budget: BASBudgetFrame) -> BASMemoryBundle {
        BASMemoryBundle(
            atoms: [
                BASMemoryAtom(
                    memoryID: "m-l11",
                    summary: "Bounded steps outperform impulsive release.",
                    contentType: .warm,
                    source: "ticket",
                    confidence: 0.8,
                    conflictFingerprint: "m-l11"
                )
            ],
            retrievalTags: ["l11"],
            activeHostVersion: hostContext.activeVersion
        )
    }

    func promote(atom: BASMemoryAtom, hostContext: BASHostProfile) -> BASPromotionState { .candidate }
    func freeze(memoryID: String) -> Bool { true }
}

private struct L11Loop: BASLoopServicing {
    func proposePaths(decomposeFrame: BASDecomposeFrame, memoryBundle: BASMemoryBundle, budget: BASBudgetFrame) -> [BASCandidatePath] {
        [
            BASCandidatePath(candidateID: "c1", title: "Primary path", actionSummary: "Use a bounded next step.", expectedBenefit: 0.6, expectedCost: 0.2, reversibility: 0.84, confidence: 0.74),
            BASCandidatePath(candidateID: "c2", title: "Fallback path", actionSummary: "Wait and gather one more fact.", expectedBenefit: 0.55, expectedCost: 0.18, reversibility: 0.92, confidence: 0.69)
        ]
    }

    func forecast(candidates: [BASCandidatePath], decomposeFrame: BASDecomposeFrame, memoryBundle: BASMemoryBundle) -> [BASForecastItem] {
        [
            BASForecastItem(candidateID: "c1", shortTermOutcome: "Bounded move", midTermOutcome: "Less fallout", worstCase: "Small delay", uncertainty: 0.24),
            BASForecastItem(candidateID: "c2", shortTermOutcome: "More evidence", midTermOutcome: "Better timing", worstCase: "Delay discomfort", uncertainty: 0.18)
        ]
    }

    func critique(candidates: [BASCandidatePath], forecasts: [BASForecastItem], hostContext: BASHostProfile) -> [BASCritiqueItem] {
        [
            BASCritiqueItem(candidateID: "c1", critiqueType: .boundaryConflict, critiqueText: "Needs a bounded release radius.", severity: 0.32),
            BASCritiqueItem(candidateID: "c2", critiqueType: .evidenceGap, critiqueText: "One more fact would help.", severity: 0.24)
        ]
    }

    func iterate(decomposeFrame: BASDecomposeFrame, memoryBundle: BASMemoryBundle, budget: BASBudgetFrame) -> BASThoughtFrame {
        BASThoughtFrame(
            stepIndex: 2,
            decomposeRef: "decomp-l11",
            memoryRefs: memoryBundle.atoms.map(\.memoryID),
            candidates: proposePaths(decomposeFrame: decomposeFrame, memoryBundle: memoryBundle, budget: budget),
            forecasts: forecast(candidates: [], decomposeFrame: decomposeFrame, memoryBundle: memoryBundle),
            critiques: critique(candidates: [], forecasts: [], hostContext: BASHostProfile(hostID: "unused")),
            stabilityScore: 0.72,
            stopReason: .candidateStable
        )
    }
}

private struct L11TriSelf: BASTriSelfServicing {
    func mergeChoice(thoughtFrame: BASThoughtFrame, hostContext: BASHostProfile) -> ([BASTriSelfScore], BASMergedChoice) {
        (
            [
                BASTriSelfScore(candidateID: "c1", idScore: 0.48, egoScore: 0.72, superegoScore: 0.86, mergedScore: 0.76, veto: false),
                BASTriSelfScore(candidateID: "c2", idScore: 0.31, egoScore: 0.61, superegoScore: 0.82, mergedScore: 0.67, veto: false)
            ],
            BASMergedChoice(candidateID: "c1", title: "Primary path", actionSummary: "Use a bounded next step.")
        )
    }
}

private struct L11Risk: BASRiskServicing {
    let package: BASRiskDecisionPackage

    func calibrateRisk(contextFrame: BASContextFrame, thoughtFrame: BASThoughtFrame, triScores: [BASTriSelfScore], budget: BASBudgetFrame) -> BASRiskCard {
        package.riskCard
    }

    func computeGSI(contextFrame: BASContextFrame, thoughtFrame: BASThoughtFrame) -> Double {
        package.riskCard.gsiScore
    }

    func gateAction(contextFrame: BASContextFrame, thoughtFrame: BASThoughtFrame, triScores: [BASTriSelfScore], budget: BASBudgetFrame) -> (BASRiskCard, BASActionPermit) {
        (package.riskCard, package.actionPermit)
    }

    func buildRiskDecisionPackage(contextFrame: BASContextFrame, thoughtFrame: BASThoughtFrame, triScores: [BASTriSelfScore], budget: BASBudgetFrame) -> BASRiskDecisionPackage {
        package
    }

    func riskLevel(for score: Double) -> BASBrainRiskLevel {
        package.riskCard.riskLevel
    }
}

private struct L11Action: BASActionServicing {
    func render(choice: BASMergedChoice, riskCard: BASRiskCard, permit: BASActionPermit, hostContext: BASHostProfile) -> BASRenderedOutput {
        BASRenderedOutput(
            mode: permit.mode,
            headline: choice.title,
            body: choice.actionSummary,
            alternativeActions: ["Use the bounded next step."],
            explanationCodes: permit.reasonCodes
        )
    }
}

private struct L11Evolution: BASEvolutionServicing {
    func buildTickets(thoughtFrame: BASThoughtFrame, output: BASRenderedOutput, feedbackEvent: BASFeedbackEvent?) -> [BASUpdateTicket] {
        []
    }
}

private func makeL11RiskDecisionPackage(
    primaryMode: BASActionPermitMode,
    stackedModes: [BASActionPermitMode],
    riskLevel: BASBrainRiskLevel,
    totalRisk: Double,
    blockedDomains: [String],
    delayReservation: BASDelayReservation? = nil,
    protectiveSubstitute: BASProtectiveSubstitute? = nil,
    sovereignEscalationHint: BASSovereignEscalationHint? = nil
) -> BASRiskDecisionPackage {
    let riskCard = BASRiskCard(
        totalRisk: totalRisk,
        riskLevel: riskLevel,
        factors: ["risk.\(riskLevel.rawValue)"],
        uncertainty: riskLevel >= .high ? 0.42 : 0.24,
        irreversibility: riskLevel >= .high ? 0.81 : 0.32,
        manipulationStrength: riskLevel == .extreme ? 0.72 : 0.18,
        gsiScore: riskLevel == .extreme ? 0.84 : 0.26,
        recommendedMode: primaryMode,
        stackedModes: stackedModes,
        assertionCeiling: riskLevel >= .high ? "guarded" : "standard",
        delayType: delayReservation?.delayType,
        substituteType: protectiveSubstitute?.substituteType,
        sovereignHintLevel: sovereignEscalationHint?.urgency
    )
    let permit = BASActionPermit(
        mode: primaryMode,
        stackedModes: stackedModes,
        reasonCodes: ["risk.\(riskLevel.rawValue)"],
        allowedDomains: primaryMode == .compare ? ["bounded_reply", "comparison"] : ["bounded_reply", "local_action"],
        blockedDomains: blockedDomains,
        assertionCeiling: riskCard.assertionCeiling,
        toolScope: primaryMode == .localOnly ? "local_only" : "none",
        memoryScope: riskLevel >= .high ? "review_only" : "standard",
        requireMirror: stackedModes.contains(.mirror),
        requireCompare: primaryMode == .compare || stackedModes.contains(.mirror),
        requireSecondCheck: riskLevel >= .high,
        outputLengthCap: 220,
        tonePolicy: "l11_test",
        templatePolicy: "l11_test",
        delayWindow: delayReservation?.delayType,
        substituteRequired: protectiveSubstitute != nil,
        escalationHintRef: sovereignEscalationHint?.hintID
    )
    return BASRiskDecisionPackage(
        packageID: "risk-package.c1.\(primaryMode.rawValue)",
        riskCard: riskCard,
        riskField: BASRiskField(
            fieldID: "risk-field.c1.\(primaryMode.rawValue)",
            candidateRef: "c1",
            hazardVector: BASHazardVector(
                harmSeverity: totalRisk,
                harmScope: totalRisk,
                irreversibility: riskCard.irreversibility,
                uncertainty: riskCard.uncertainty,
                evidenceDebt: riskCard.uncertainty,
                manipulationIntensity: riskCard.manipulationStrength,
                pressureAuthenticity: 0.5,
                vulnerabilityCoupling: 0.5,
                sideEffectScope: totalRisk
            ),
            harmRadius: BASHarmRadiusMap(
                radiusID: "harm-radius.c1.\(primaryMode.rawValue)",
                privateImpact: 0.4,
                relationImpact: 0.5,
                workflowImpact: 0.3,
                publicImpact: 0.2,
                longTermTrace: riskCard.irreversibility
            ),
            reversibilityProfile: BASReversibilityProfile(
                profileID: "reversibility.c1.\(primaryMode.rawValue)",
                reversible: riskCard.irreversibility < 0.5,
                rollbackCost: riskCard.irreversibility,
                confirmNodes: riskLevel >= .high ? ["second_check"] : [],
                draftSafe: true,
                smallStepPossible: riskLevel < .extreme
            ),
            evidenceSufficiency: BASEvidenceSufficiency(
                sufficiencyID: "evidence.c1.\(primaryMode.rawValue)",
                supportLevel: 0.74,
                missingEvidence: riskLevel >= .high ? ["follow_up_evidence"] : [],
                allowedAssertionLevel: riskCard.assertionCeiling,
                allowedActionLevel: primaryMode.rawValue
            ),
            gsiTrace: BASGSITrace(
                traceID: "gsi.c1.\(primaryMode.rawValue)",
                gaslightSignals: [],
                coerciveUrgency: 0.2,
                shamePressure: 0,
                authorityMask: 0,
                relationLeverage: 0.1,
                susceptibilityBand: riskLevel >= .high ? "guarded" : "stable"
            ),
            vulnerabilityCoupling: BASVulnerabilityCoupling(
                couplingID: "vulnerability.c1.\(primaryMode.rawValue)",
                touchedBoundaries: [],
                lowEnergyResonance: 0.2,
                sensitivityWindow: 0.3,
                protectionBias: riskLevel >= .high ? 0.8 : 0.3
            ),
            confidenceBand: riskLevel >= .high ? "guarded" : "open"
        ),
        actionModeDecision: BASActionModeDecision(
            decisionID: "mode.c1.\(primaryMode.rawValue)",
            primaryMode: primaryMode,
            stackedModes: stackedModes,
            reasonCodes: ["risk.\(riskLevel.rawValue)"],
            confidence: 0.81
        ),
        actionPermit: permit,
        delayReservation: delayReservation,
        protectiveSubstitute: protectiveSubstitute,
        sovereignEscalationHint: sovereignEscalationHint
    )
}
