// MARK: - BASHostKitConstitutionTests — chapter 二百九十六 / M783
//
// Phase Alpha 第二十二刀(BASHostKitTests god file 1st cut):从
// `BASHostKitTests.swift` (5626 LOC) 抽出 host constitution 相关
// tests — Phase Alpha 第五个 god file 拆分启动。
//
// 抽出 11 个 test methods (Swift extension on BASHostKitTests):
//   - testHostConstitutionProjectsIntoRuntimeHostContext
//   - testExplicitHostConstitutionDirectlyInfluencesTriSelfRiskAndAction
//   - testConstitutionFacetsTightenHostGateValue
//   - testGoalSpineAndRelationGravityCanPromoteBoundedChoice
//   - testConstitutionFacetsShapeRenderedOutputGuidance
//   - testConstitutionFacetsShapeContextDecomposeAndCritiqueFrames
//   - testConstitutionFacetsShapeMemoryRetrievalTagsAndForecastRelations
//   - testRuntimeMemoryBundleTemporalFieldProjectsSealedAndRetiredStructures
//   - testConstitutionFacetsRestrictToolIntentDomainsAndRequireSecondCheck
//   - testExplicitConstitutionShapesEvolutionHostChangeCandidate
//
// **0 behavior change**:test methods literal-identical to
// pre-extraction versions,只是改成了 `extension BASHostKitTests`
// in a new file。XCTest discovery via Swift's class extension
// works — XCTest finds tests on `BASHostKitTests` regardless of
// which file the methods are defined in.
//
// Doctrine pins:
//   - 不变量 #1 / #2 / #3 全保
//   - chapter 二百一一 single-source-of-truth
//   - chapter 二百一(架构 guardrail)+ chapter 一百八十五 anti-magic-number 全保
//   - host constitution invariants 行为不变

import XCTest
@testable import BASAdmin
@testable import BASHostKit
@testable import BASMemory
@testable import BASOrchestration
@testable import BASPolicy
@testable import BASRuntimeCore

extension BASHostKitTests {
    func testHostConstitutionProjectsIntoRuntimeHostContext() throws {
        let constitution = BASHostConstitution(
            hostID: "host.constitution",
            activeVersion: "constitution.v9",
            identityLattice: BASIdentityLattice(
                coreTags: ["architect", "guardian"],
                stageTags: ["l5-evolution"],
                continuityScore: 0.95,
                conflictPoints: ["speed_vs_boundary"],
                stableCenter: "protect long-term agency"
            ),
            valueAxes: BASValueAxisSet(
                axes: ["privacy", "stability", "craft"],
                relativeWeights: [0.96, 0.9, 0.78],
                conflictRules: ["privacy_over_speed"],
                updateThreshold: 0.76
            ),
            goalSpine: BASGoalSpine(
                goals: ["evolve_l5", "stay_bounded"],
                hierarchy: ["evolve_l5": ["stay_bounded"]],
                priorityOrder: ["stay_bounded", "evolve_l5"],
                conflictPairs: ["speed|safety"],
                stageState: "active"
            ),
            boundaryVeil: BASBoundaryVeil(
                hardNoGo: ["unsafe_override"],
                softCaution: ["emotional_spike"],
                confirmRequired: ["remote_write"],
                restrictedMemoryDomains: ["private_notes"],
                restrictedToolDomains: ["tool.write.remote"]
            ),
            relationGravity: BASRelationGravityMap(
                nodes: ["partner", "team"],
                edgeTypes: ["anchor", "critical"],
                gravityWeights: [0.98, 0.84],
                communicationModes: ["gentle", "direct"],
                highConsequenceLinks: ["partner"]
            ),
            rhythmCanopy: BASRhythmCanopy(
                activeWindows: ["morning_focus"],
                focusWindows: ["afternoon_deep_work"],
                lowEnergyWindows: ["late_evening"],
                reminderTolerance: "soft",
                cadencePreferences: ["weekly_review"]
            ),
            styleGenome: BASStyleGenome(
                density: "high",
                warmth: "warm",
                structureBias: 0.97,
                brevityBias: 0.34,
                metaphorBias: 0.29,
                comparisonBias: 0.92,
                revisionStyle: "layered"
            ),
            routineSkeleton: BASRoutineSkeleton(
                workflowTemplates: ["compare_then_commit", "audit_before_ship"],
                taskDecompositionModes: ["structure_first"],
                reminderPatterns: ["soft_nudge"],
                planningCadences: ["weekly_reset"]
            ),
            consentLattice: BASConsentLattice(
                memoryWriteScope: "warm_only",
                memoryPromotionScope: "review_required",
                hostMutationScope: "candidate_only",
                toolReadScope: "local_confirmed",
                toolWriteScope: "manual_confirm",
                syncScope: "local_only",
                sensitiveDomainRules: ["relationship.no_autoinfer"]
            ),
            narrativeLoom: BASNarrativeLoom(
                longFormSummary: "The host wants a precise but bounded companion brain.",
                currentPhase: "evolution",
                continuityLinks: ["constitution.v8->constitution.v9"],
                unresolvedTensions: ["speed_vs_depth"]
            ),
            protectionRing: BASProtectionRing(
                sensitiveDomains: ["identity", "attachment"],
                emotionalPollutionZones: ["crash_state"],
                escalationRules: ["cooldown_before_major_update"],
                exploitationShields: ["never_amplify_dependency"]
            )
        )
        let versionTree = BASHostVersionTree(
            activeVersionID: constitution.activeVersion,
            versions: [
                BASHostVersion(
                    versionID: "constitution.v8",
                    changedFields: ["identityLattice", "styleGenome"],
                    reason: "stable baseline",
                    approvedByPolicy: true
                ),
                BASHostVersion(
                    versionID: "constitution.v9",
                    changedFields: ["goalSpine", "boundaryVeil"],
                    reason: "reviewed evolution",
                    rollbackRef: "constitution.v8",
                    approvedByPolicy: true
                )
            ],
            pendingCandidateIDs: ["candidate.goal.v10"],
            frozenVersionIDs: ["constitution.v8"]
        )
        let forgetRequest = BASForgetRequest(
            requestID: "forget.private_notes",
            targetRefs: ["memory.private_notes", "projection.private_notes"],
            cascadeScope: ["active_version", "projection_cache", "memory_reference_chain"],
            executedSteps: [
                "active_version_removed",
                "projection_cache_invalidated",
                "checkpoint_exports_revoked",
                "sync_exports_revoked"
            ],
            verified: false
        )
        let vault = constitution
            .vaultSnapshot(
                versionTree: versionTree,
                forgetRequest: forgetRequest,
                sourceDeviceID: "device.primary",
                trustedDeviceIDs: ["device.primary", "device.review"]
            )
            .recordingConsistency(
                BASHostDeviceConsistencyReport(
                    sourceDeviceID: "device.primary",
                    trustedDeviceIDs: ["device.primary", "device.review"],
                    revokedDeviceIDs: ["sync.revocation.pending"],
                    consistencyState: "revocation_pending",
                    requiresExplicitApproval: true
                ),
                migrationContract: BASHostDeviceMigrationContract(
                    sourceDeviceID: "device.primary",
                    targetDeviceID: "device.review",
                    allowedScopes: ["constitution_snapshot", "rollback_lineage"],
                    requiresExplicitApproval: true,
                    rollbackVersionID: "constitution.v8",
                    exportInvalidationRefs: ["sync_exports:forget.private_notes"]
                )
            )
        var tuning = makePolicyOwnedRuntimeTuning(
            schemaVersion: "host.runtime-synthesis.constitution.v1"
        )
        tuning.guardrailPressure = .init(
            protectiveBoundaryIncrement: 0.08,
            calibrationWatchIncrement: 0.05,
            calibrationDriftingIncrement: 0.09,
            boundaryConstraintUnit: 0.02,
            boundaryConstraintCap: 0.10,
            calibrationAlertUnit: 0.02,
            calibrationAlertCap: 0.08,
            failureGuardUnit: 0.01,
            failureGuardCap: 0.06,
            riskFlagUnit: 0.02,
            riskFlagCap: 0.09,
            maximumPressure: 0.44
        )
        tuning.budget.standardDecodeTokens = 144
        tuning.budget.unstableDecodeTokens = 176
        tuning.budget.guardedDecodeTokens = 208
        tuning.budget.maintenanceBatteryFloor = 0.55
        tuning.hostThresholds = .init(
            caution: 0.39,
            protective: 0.66,
            block: 0.86
        )
        let runtime = BASHostRuntime(
            configuration: makeConfiguration(
                runtimeTuning: tuning,
                hostConstitution: constitution,
                hostConstitutionVault: vault,
                hostVersionTree: versionTree,
                hostForgetRequest: forgetRequest
            )
        )

        let result = try runtime.startSession(
            BASHostSessionRequest(
                kind: .interactive,
                workflowProfile: .comparative,
                surface: .application,
                prompt: "Compare both paths and keep the boundary intact.",
                title: "Constitution-driven L5",
                riskLevel: .medium
            )
        )

        XCTAssertEqual(result.eBrainTurn?.hostContext.hostID, "host.constitution")
        XCTAssertEqual(result.eBrainTurn?.hostContext.activeVersion, "constitution.v9")
        XCTAssertEqual(result.eBrainTurn?.hostConstitution?.activeVersion, "constitution.v9")
        XCTAssertEqual(result.eBrainTurn?.hostConstitutionVault?.versionSignature, vault.versionSignature)
        XCTAssertEqual(result.eBrainTurn?.hostConstitutionVault?.deviceConsistencyReport.consistencyState, "revocation_pending")
        XCTAssertEqual(result.eBrainTurn?.hostConstitutionVault?.syncRevocationLedger.revokedRequestIDs, ["forget.private_notes"])
        XCTAssertEqual(result.eBrainTurn?.hostVersionTree?.activeVersionID, "constitution.v9")
        XCTAssertEqual(result.eBrainTurn?.hostVersionTree?.pendingCandidateIDs, ["candidate.goal.v10"])
        XCTAssertEqual(result.eBrainTurn?.hostVersionTree?.frozenVersionIDs, ["constitution.v8"])
        XCTAssertEqual(result.eBrainTurn?.hostForgetRequest?.requestID, "forget.private_notes")
        XCTAssertEqual(result.eBrainTurn?.hostForgetRequest?.targetRefs, ["memory.private_notes", "projection.private_notes"])
        XCTAssertEqual(result.eBrainTurn?.hostConstitution?.narrativeLoom.currentPhase, "evolution")
        XCTAssertEqual(result.eBrainTurn?.hostContext.identityTags, ["architect", "guardian", "l5-evolution"])
        XCTAssertEqual(result.eBrainTurn?.hostContext.longTermGoals, ["evolve_l5", "stay_bounded"])
        XCTAssertEqual(result.eBrainTurn?.hostContext.relationshipRefs, ["partner", "team"])
        XCTAssertEqual(result.eBrainTurn?.hostContext.workRoutines, ["compare_then_commit", "audit_before_ship"])
        XCTAssertTrue(result.eBrainTurn?.hostContext.noGoZones.contains("unsafe_override") == true)
        XCTAssertTrue(result.eBrainTurn?.hostContext.noGoZones.contains("remote_write") == true)
        XCTAssertTrue(result.eBrainTurn?.hostContext.styleConstraints.contains("structure_bias:0.97") == true)
        XCTAssertEqual(result.eBrainTurn?.thoughtFold.compactSlots["constitution_version"], "constitution.v9")
        XCTAssertEqual(result.eBrainTurn?.thoughtFold.compactSlots["constitution_phase"], "evolution")
        XCTAssertTrue(result.eBrainTurn?.thoughtFold.compactSlots["host_mod"]?.contains("tone:warm_high") == true)
        XCTAssertTrue(result.eBrainTurn?.thoughtFold.compactSlots["host_mod"]?.contains("phase:evolution") == true)
        XCTAssertTrue(result.eBrainTurn?.thoughtFold.compactSlots["host_mod"]?.contains("goal:stay_bounded") == true)
        XCTAssertTrue(result.eBrainTurn?.thoughtFold.compactSlots["host_mod"]?.contains("relation:partner") == true)
        XCTAssertTrue(result.eBrainTurn?.thoughtFold.compactSlots["host_mod"]?.contains("memory:review_required") == true)
        XCTAssertEqual(result.eBrainTurn?.thoughtFold.compactSlots["vault_signature"], vault.versionSignature)
        XCTAssertEqual(result.eBrainTurn?.thoughtFold.compactSlots["vault_sync_revocations"], "1")
        XCTAssertEqual(result.eBrainTurn?.thoughtFold.compactSlots["vault_consistency_state"], "revocation_pending")
        XCTAssertEqual(result.eBrainTurn?.thoughtFold.compactSlots["vault_out_of_sync_devices"], "0")
        XCTAssertEqual(result.eBrainTurn?.thoughtFold.compactSlots["vault_migration_target"], "device.review")
        XCTAssertEqual(result.eBrainTurn?.thoughtFold.compactSlots["vault_deletion_manifest"], "forget.private_notes")
        XCTAssertEqual(result.eBrainTurn?.thoughtFold.compactSlots["constitution_pending_candidates"], "1")
        XCTAssertEqual(result.eBrainTurn?.thoughtFold.compactSlots["constitution_frozen_versions"], "1")
        XCTAssertEqual(result.eBrainTurn?.thoughtFold.compactSlots["forget_request_id"], "forget.private_notes")
        XCTAssertEqual(result.eBrainTurn?.thoughtFold.compactSlots["forget_verified"], "false")
        XCTAssertEqual(result.eBrainTurn?.thoughtFold.compactSlots["forget_checkpoints_revoked"], "true")
        XCTAssertEqual(result.eBrainTurn?.thoughtFold.compactSlots["forget_sync_exports_revoked"], "true")
        XCTAssertEqual(
            result.eBrainTurn?.hostContext.riskThresholds,
            BASHostRiskThresholds(caution: 0.39, protective: 0.66, block: 0.86)
        )
        XCTAssertFalse(result.eBrainTurn?.hostContext.memoryPermissions.allowColdWrites ?? true)
        XCTAssertTrue(result.eBrainTurn?.hostContext.memoryPermissions.requireReviewForColdWrites ?? false)
        XCTAssertTrue(result.currentBrain.retrievalTags.contains("constitution:constitution.v9"))
        XCTAssertTrue(result.currentBrain.retrievalTags.contains("constitution_phase:evolution"))
        XCTAssertTrue(result.currentBrain.retrievalTags.contains("vault_signature:\(vault.versionSignature)"))
        XCTAssertTrue(result.currentBrain.retrievalTags.contains("vault_consistency:revocation_pending"))
        XCTAssertTrue(result.currentBrain.retrievalTags.contains("vault_sync_revocations:1"))
        XCTAssertTrue(result.currentBrain.retrievalTags.contains("vault_out_of_sync_devices:0"))
        XCTAssertTrue(result.currentBrain.retrievalTags.contains("vault_migration_target:device.review"))
        XCTAssertTrue(result.currentBrain.retrievalTags.contains("vault_deletion_manifest:forget.private_notes"))
        XCTAssertTrue(result.currentBrain.retrievalTags.contains("constitution_pending:1"))
        XCTAssertTrue(result.currentBrain.retrievalTags.contains("constitution_frozen:1"))
        XCTAssertTrue(result.currentBrain.retrievalTags.contains("forget_request:forget.private_notes"))
        XCTAssertTrue(result.currentBrain.retrievalTags.contains("forget_verified:false"))
        XCTAssertTrue(result.currentBrain.retrievalTags.contains("forget_checkpoints_revoked:true"))
        XCTAssertTrue(result.currentBrain.retrievalTags.contains("forget_sync_exports_revoked:true"))
        XCTAssertEqual(Array(result.currentBrain.dominantGoals.prefix(2)), ["stay_bounded", "evolve_l5"])
        XCTAssertEqual(result.currentBrain.relationshipBoundary, "partner")
        XCTAssertTrue(result.currentBrain.boundaryHeadline.contains("stable center protect long-term agency"))
        XCTAssertTrue(result.currentBrain.boundaryHeadline.contains("confirm remote_write"))
        XCTAssertTrue(result.currentBrain.boundaryHeadline.contains("no-go unsafe_override"))
        XCTAssertTrue(result.currentBrain.activeConstraints.contains("constitution_goal:stay_bounded"))
        XCTAssertTrue(result.currentBrain.activeConstraints.contains("constitution_confirm_required:remote_write"))
        XCTAssertTrue(result.currentBrain.activeConstraints.contains("constitution_no_go:unsafe_override"))
        XCTAssertTrue(result.currentBrain.activeConstraints.contains("constitution_relation:partner"))
        XCTAssertTrue(result.currentBrain.activeConstraints.contains("constitution_phase:evolution"))
        XCTAssertTrue(result.currentBrain.activeConstraints.contains("constitution_memory_promotion:review_required"))
        XCTAssertTrue(result.currentBrain.activeConstraints.contains("constitution_tool_write_scope:manual_confirm"))
        XCTAssertTrue(result.currentBrain.verificationSummary.contains("constitution:constitution.v9"))
        XCTAssertTrue(result.currentBrain.verificationSummary.contains("phase:evolution"))
        XCTAssertTrue(result.currentBrain.verificationSummary.contains("vault_signature:\(vault.versionSignature)"))
        XCTAssertTrue(result.currentBrain.verificationSummary.contains("vault_consistency:revocation_pending"))
        XCTAssertTrue(result.currentBrain.verificationSummary.contains("vault_sync_revocations:1"))
        XCTAssertTrue(result.currentBrain.verificationSummary.contains("vault_out_of_sync_devices:0"))
        XCTAssertTrue(result.currentBrain.verificationSummary.contains("vault_migration_target:device.review"))
        XCTAssertTrue(result.currentBrain.verificationSummary.contains("vault_deletion_manifest:forget.private_notes"))
        XCTAssertTrue(result.currentBrain.verificationSummary.contains("pending:1"))
        XCTAssertTrue(result.currentBrain.verificationSummary.contains("frozen:1"))
        XCTAssertTrue(result.currentBrain.verificationSummary.contains("forget:forget.private_notes"))
        XCTAssertTrue(result.currentBrain.verificationSummary.contains("forget_checkpoints_revoked:true"))
        XCTAssertTrue(result.currentBrain.verificationSummary.contains("forget_sync_exports_revoked:true"))
        XCTAssertTrue(result.eBrainTurn?.thoughtFold.hostEffectSummary.contains("phase:evolution") == true)
        XCTAssertTrue(result.eBrainTurn?.thoughtFold.hostEffectSummary.contains("goal:stay_bounded") == true)
        XCTAssertTrue(result.eBrainTurn?.thoughtFold.hostEffectSummary.contains("relation:partner") == true)
        XCTAssertTrue(result.eBrainTurn?.thoughtFold.hostEffectSummary.contains("memory:review_required") == true)
        XCTAssertTrue(result.consoleSnapshot.brainSummary?.contains("phase evolution") == true)
        XCTAssertTrue(result.consoleSnapshot.brainSummary?.contains("constitution constitution.v9") == true)
        XCTAssertTrue(result.consoleSnapshot.brainSummary?.contains("modulation tone:warm_high") == true)
        XCTAssertTrue(result.consoleSnapshot.brainSummary?.contains("goal:stay_bounded") == true)
        XCTAssertTrue(result.consoleSnapshot.brainSummary?.contains("vault \(vault.versionSignature)") == true)
        XCTAssertTrue(result.consoleSnapshot.brainSummary?.contains("consistency revocation_pending") == true)
        XCTAssertTrue(result.consoleSnapshot.brainSummary?.contains("target device.review") == true)
        XCTAssertTrue(result.consoleSnapshot.brainSummary?.contains("pending 1") == true)
        XCTAssertTrue(result.consoleSnapshot.brainSummary?.contains("frozen 1") == true)
        XCTAssertTrue(result.consoleSnapshot.brainSummary?.contains("forget forget.private_notes") == true)
        XCTAssertTrue(
            result.consoleSnapshot.reports.first(where: { $0.kind == .data })?.summary.contains("modulation tone:warm_high") == true
        )
        XCTAssertTrue(
            result.consoleSnapshot.reports.first(where: { $0.kind == .data })?.summary.contains("goal:stay_bounded") == true
        )
        XCTAssertTrue(result.consoleSnapshot.inspectionBundle?.trace.auditEvents.contains(where: {
            $0.category == "L5" && $0.message.contains("constitution constitution.v9")
        }) ?? false)
        XCTAssertTrue(result.consoleSnapshot.inspectionBundle?.trace.auditEvents.contains(where: {
            $0.category == "L5" && $0.message.contains("pending 1")
        }) ?? false)
        XCTAssertTrue(result.consoleSnapshot.inspectionBundle?.trace.auditEvents.contains(where: {
            $0.category == "L5" && $0.message.contains("forget request forget.private_notes")
        }) ?? false)
        XCTAssertTrue(result.eBrainTurn?.runtimeTrace.layerEvents.contains(where: {
            $0.layerID == "L5" && $0.detail.contains("constitution constitution.v9")
        }) ?? false)
        XCTAssertTrue(result.eBrainTurn?.runtimeTrace.layerEvents.contains(where: {
            $0.layerID == "L5" && $0.detail.contains("vault \(vault.versionSignature)")
        }) ?? false)
        XCTAssertTrue(result.eBrainTurn?.runtimeTrace.layerEvents.contains(where: {
            $0.layerID == "L5" && $0.detail.contains("modulation tone:warm_high")
        }) ?? false)
        XCTAssertTrue(result.eBrainTurn?.runtimeTrace.layerEvents.contains(where: {
            $0.layerID == "L5" && $0.detail.contains("phase:evolution")
        }) ?? false)
        XCTAssertTrue(result.eBrainTurn?.runtimeTrace.layerEvents.contains(where: {
            $0.layerID == "L5" && $0.detail.contains("goal:stay_bounded")
        }) ?? false)
        XCTAssertTrue(result.eBrainTurn?.runtimeTrace.layerEvents.contains(where: {
            $0.layerID == "L5" && $0.detail.contains("relation:partner")
        }) ?? false)
        XCTAssertTrue(result.eBrainTurn?.runtimeTrace.layerEvents.contains(where: {
            $0.layerID == "L5" && $0.detail.contains("target device.review")
        }) ?? false)
        XCTAssertTrue(result.eBrainTurn?.runtimeTrace.layerEvents.contains(where: {
            $0.layerID == "L5" && $0.detail.contains("pending 1")
        }) ?? false)
        XCTAssertTrue(result.eBrainTurn?.runtimeTrace.layerEvents.contains(where: {
            $0.layerID == "L5" && $0.detail.contains("forget request forget.private_notes")
        }) ?? false)
    }

    func testExplicitHostConstitutionDirectlyInfluencesTriSelfRiskAndAction() throws {
        let request = BASHostSessionRequest(
            kind: .interactive,
            workflowProfile: .primary,
            surface: .application,
            prompt: "Answer this cleanly right now.",
            title: "Constitution-guided answer",
            riskLevel: .low
        )
        let baselineTurn = try XCTUnwrap(
            BASHostRuntime(
                configuration: makeConfiguration()
            ).startSession(request).eBrainTurn
        )
        let constitution = BASHostConstitution(
            hostID: "host.constitution",
            activeVersion: "constitution.v11",
            valueAxes: BASValueAxisSet(
                axes: ["stability", "privacy", "speed"],
                relativeWeights: [0.97, 0.92, 0.18],
                conflictRules: ["stability_over_speed", "privacy_over_speed"],
                updateThreshold: 0.76
            ),
            boundaryVeil: BASBoundaryVeil(
                hardNoGo: ["unsafe_override"],
                confirmRequired: ["external_send"]
            ),
            narrativeLoom: BASNarrativeLoom(
                longFormSummary: "Prefer stable, bounded, privacy-preserving action.",
                currentPhase: "active"
            )
        )

        let constitutionTurn = try XCTUnwrap(
            BASHostRuntime(
                configuration: makeConfiguration(hostConstitution: constitution)
            ).startSession(request).eBrainTurn
        )

        let baselineDirect = try XCTUnwrap(
            baselineTurn.triScores.first(where: { $0.candidateID == "path.direct" })
        )
        let constitutionDirect = try XCTUnwrap(
            constitutionTurn.triScores.first(where: { $0.candidateID == "path.direct" })
        )

        XCTAssertLessThan(constitutionDirect.mergedScore, baselineDirect.mergedScore)
        XCTAssertTrue(baselineTurn.riskCard.factors.contains("constitution_value_axis_stability"))
        XCTAssertTrue(baselineTurn.actionPermit.reasonCodes.contains("constitution.value_axis.stability"))
        XCTAssertTrue(baselineTurn.renderedOutput.explanationCodes.contains("constitution.value_axis.stability"))
        XCTAssertFalse(baselineTurn.riskCard.factors.contains("constitution_confirm_required"))
        XCTAssertTrue(constitutionTurn.riskCard.factors.contains("constitution_confirm_required"))
        XCTAssertTrue(constitutionTurn.riskCard.factors.contains("constitution_value_axis_stability"))
        XCTAssertTrue(constitutionTurn.actionPermit.reasonCodes.contains("constitution.confirm_required"))
        XCTAssertTrue(constitutionTurn.actionPermit.reasonCodes.contains("constitution.value_axis.stability"))
        XCTAssertTrue(constitutionTurn.renderedOutput.explanationCodes.contains("constitution.confirm_required"))
        XCTAssertTrue(constitutionTurn.renderedOutput.explanationCodes.contains("constitution.value_axis.stability"))
    }

    func testConstitutionFacetsTightenHostGateValue() throws {
        let request = BASHostSessionRequest(
            kind: .interactive,
            workflowProfile: .primary,
            surface: .application,
            prompt: "I must send this to my partner right now.",
            title: "Host gate constitution pressure",
            riskLevel: .low
        )
        let baselineTurn = try XCTUnwrap(
            BASHostRuntime(
                configuration: makeConfiguration()
            ).startSession(request).eBrainTurn
        )
        let constitution = BASHostConstitution(
            hostID: "host.constitution",
            activeVersion: "constitution.v11b",
            valueAxes: BASValueAxisSet(
                axes: ["stability", "privacy", "speed"],
                relativeWeights: [0.98, 0.94, 0.12],
                conflictRules: ["stability_over_speed", "privacy_over_speed"],
                updateThreshold: 0.80
            ),
            boundaryVeil: BASBoundaryVeil(
                confirmRequired: ["external_send"]
            ),
            relationGravity: BASRelationGravityMap(
                nodes: ["partner"],
                edgeTypes: ["anchor"],
                gravityWeights: [0.99],
                communicationModes: ["gentle"],
                highConsequenceLinks: ["partner"]
            ),
            narrativeLoom: BASNarrativeLoom(
                longFormSummary: "Tighten host gating before direct partner-facing sends.",
                currentPhase: "care"
            )
        )

        let constitutionTurn = try XCTUnwrap(
            BASHostRuntime(
                configuration: makeConfiguration(hostConstitution: constitution)
            ).startSession(request).eBrainTurn
        )

        XCTAssertEqual(baselineTurn.contextFrame.taskType, .manipulationRisk)
        XCTAssertEqual(constitutionTurn.contextFrame.taskType, .manipulationRisk)
        XCTAssertLessThan(constitutionTurn.hostGateValue, baselineTurn.hostGateValue)
        XCTAssertLessThanOrEqual(constitutionTurn.hostGateValue, 0.72)
    }

    func testGoalSpineAndRelationGravityCanPromoteBoundedChoice() throws {
        let request = BASHostSessionRequest(
            kind: .interactive,
            workflowProfile: .primary,
            surface: .application,
            prompt: "Draft the reply now.",
            title: "Goal and relation guided answer",
            riskLevel: .low
        )
        let baselineTurn = try XCTUnwrap(
            BASHostRuntime(
                configuration: makeConfiguration()
            ).startSession(request).eBrainTurn
        )
        let constitution = BASHostConstitution(
            hostID: "host.constitution",
            activeVersion: "constitution.v12",
            goalSpine: BASGoalSpine(
                goals: ["stay_bounded", "protect_partner_context"],
                hierarchy: ["protect_partner_context": ["stay_bounded"]],
                priorityOrder: ["stay_bounded", "protect_partner_context"],
                stageState: "active"
            ),
            relationGravity: BASRelationGravityMap(
                nodes: ["partner"],
                edgeTypes: ["anchor"],
                gravityWeights: [0.99],
                communicationModes: ["gentle"],
                highConsequenceLinks: ["partner"]
            ),
            narrativeLoom: BASNarrativeLoom(
                longFormSummary: "Prefer bounded moves when partner context matters.",
                currentPhase: "active"
            )
        )

        let constitutionTurn = try XCTUnwrap(
            BASHostRuntime(
                configuration: makeConfiguration(hostConstitution: constitution)
            ).startSession(request).eBrainTurn
        )

        let baselineBounded = try XCTUnwrap(
            baselineTurn.triScores.first(where: { $0.candidateID == "path.bounded" })
        )
        let constitutionBounded = try XCTUnwrap(
            constitutionTurn.triScores.first(where: { $0.candidateID == "path.bounded" })
        )
        let constitutionWinningCandidate = constitutionTurn.triScores.max { lhs, rhs in
            lhs.mergedScore < rhs.mergedScore
        }?.candidateID

        XCTAssertGreaterThan(constitutionBounded.mergedScore, baselineBounded.mergedScore)
        XCTAssertEqual(constitutionWinningCandidate, "path.bounded")
        XCTAssertFalse(baselineTurn.riskCard.factors.contains("constitution_relation_high_consequence"))
        XCTAssertTrue(constitutionTurn.riskCard.factors.contains("constitution_goal_priority_bounded"))
        XCTAssertTrue(constitutionTurn.riskCard.factors.contains("constitution_relation_high_consequence"))
        XCTAssertFalse(baselineTurn.actionPermit.reasonCodes.contains("constitution.relation_high_consequence"))
        XCTAssertTrue(constitutionTurn.actionPermit.reasonCodes.contains("constitution.goal_priority.bounded"))
        XCTAssertTrue(constitutionTurn.actionPermit.reasonCodes.contains("constitution.relation_high_consequence"))
        XCTAssertFalse(baselineTurn.renderedOutput.explanationCodes.contains("constitution.relation_high_consequence"))
        XCTAssertTrue(constitutionTurn.renderedOutput.explanationCodes.contains("constitution.goal_priority.bounded"))
        XCTAssertTrue(constitutionTurn.renderedOutput.explanationCodes.contains("constitution.relation_high_consequence"))
    }

    func testConstitutionFacetsShapeRenderedOutputGuidance() throws {
        let request = BASHostSessionRequest(
            kind: .interactive,
            workflowProfile: .primary,
            surface: .application,
            prompt: "Draft the reply now.",
            title: "Rendered constitution guidance",
            riskLevel: .low
        )
        let baselineTurn = try XCTUnwrap(
            BASHostRuntime(
                configuration: makeConfiguration()
            ).startSession(request).eBrainTurn
        )
        let constitution = BASHostConstitution(
            hostID: "host.constitution",
            activeVersion: "constitution.v12b",
            goalSpine: BASGoalSpine(
                goals: ["stay_bounded", "protect_partner_context"],
                priorityOrder: ["stay_bounded", "protect_partner_context"],
                stageState: "care"
            ),
            boundaryVeil: BASBoundaryVeil(
                confirmRequired: ["external_send"]
            ),
            relationGravity: BASRelationGravityMap(
                nodes: ["partner"],
                edgeTypes: ["anchor"],
                gravityWeights: [0.99],
                communicationModes: ["gentle"],
                highConsequenceLinks: ["partner"]
            ),
            narrativeLoom: BASNarrativeLoom(
                longFormSummary: "Keep partner context visible before release.",
                currentPhase: "care"
            )
        )

        let constitutionTurn = try XCTUnwrap(
            BASHostRuntime(
                configuration: makeConfiguration(hostConstitution: constitution)
            ).startSession(request).eBrainTurn
        )

        XCTAssertFalse(
            baselineTurn.renderedOutput.alternativeActions.contains(where: { $0.contains("partner") })
        )
        XCTAssertFalse(
            baselineTurn.renderedOutput.alternativeActions.contains(where: { $0.contains("phase care") })
        )
        XCTAssertTrue(
            constitutionTurn.renderedOutput.alternativeActions.contains("Check the impact on partner before acting.")
        )
        XCTAssertTrue(
            constitutionTurn.renderedOutput.alternativeActions.contains("Keep the next step aligned with phase care.")
        )
        XCTAssertTrue(
            constitutionTurn.renderedOutput.alternativeActions.contains("Get a second confirmation before release.")
        )
    }

    func testConstitutionFacetsShapeContextDecomposeAndCritiqueFrames() throws {
        let request = BASHostSessionRequest(
            kind: .interactive,
            workflowProfile: .primary,
            surface: .application,
            prompt: "Draft the reply now.",
            title: "Context and critique guidance",
            riskLevel: .low
        )
        let constitution = BASHostConstitution(
            hostID: "host.constitution",
            activeVersion: "constitution.v13",
            goalSpine: BASGoalSpine(
                goals: ["stay_bounded", "protect_partner_context"],
                hierarchy: ["protect_partner_context": ["stay_bounded"]],
                priorityOrder: ["stay_bounded", "protect_partner_context"],
                stageState: "care"
            ),
            relationGravity: BASRelationGravityMap(
                nodes: ["partner"],
                edgeTypes: ["anchor"],
                gravityWeights: [0.99],
                communicationModes: ["gentle"],
                highConsequenceLinks: ["partner"]
            ),
            narrativeLoom: BASNarrativeLoom(
                longFormSummary: "Keep partner context visible before direct action.",
                currentPhase: "care"
            )
        )

        let constitutionTurn = try XCTUnwrap(
            BASHostRuntime(
                configuration: makeConfiguration(hostConstitution: constitution)
            ).startSession(request).eBrainTurn
        )

        let constitutionDirectCritique = try XCTUnwrap(
            constitutionTurn.thoughtFrame.critiques.first(where: { $0.candidateID == "path.direct" })
        )

        XCTAssertGreaterThan(constitutionTurn.contextFrame.hostRelevance, 0.6)
        XCTAssertTrue(constitutionTurn.contextFrame.relationPattern.contains("partner"))
        XCTAssertTrue(
            constitutionTurn.decomposeFrame.facts.contains(where: { $0.contains("Constitution phase: care") })
        )
        XCTAssertTrue(
            constitutionTurn.decomposeFrame.facts.contains(where: { $0.contains("High-consequence relations: partner") })
        )
        XCTAssertTrue(
            constitutionTurn.decomposeFrame.goals.contains(where: {
                $0.contains("stay_bounded") || $0.contains("protect_partner_context")
            })
        )
        XCTAssertTrue(constitutionTurn.decomposeFrame.mirrorText.contains("partner"))
        XCTAssertGreaterThan(constitutionDirectCritique.severity, 0.6)
        XCTAssertTrue(constitutionDirectCritique.critiqueText.contains("partner"))
    }

    func testConstitutionFacetsShapeMemoryRetrievalTagsAndForecastRelations() throws {
        let constitution = BASHostConstitution(
            hostID: "host.constitution",
            activeVersion: "constitution.v14",
            goalSpine: BASGoalSpine(
                goals: ["stay_bounded", "protect_partner_context"],
                priorityOrder: ["stay_bounded", "protect_partner_context"],
                stageState: "care"
            ),
            relationGravity: BASRelationGravityMap(
                nodes: ["partner"],
                edgeTypes: ["anchor"],
                gravityWeights: [0.99],
                communicationModes: ["gentle"],
                highConsequenceLinks: ["partner"]
            ),
            consentLattice: BASConsentLattice(
                memoryPromotionScope: "review_required"
            ),
            narrativeLoom: BASNarrativeLoom(
                longFormSummary: "Forecast with partner impact visible.",
                currentPhase: "care"
            )
        )

        let result = try XCTUnwrap(
            BASHostRuntime(
                configuration: makeConfiguration(hostConstitution: constitution)
            ).startSession(
                BASHostSessionRequest(
                    kind: .interactive,
                    workflowProfile: .primary,
                    surface: .application,
                    prompt: "Draft the reply now.",
                    title: "Retrieval and forecast guidance",
                    riskLevel: .low
                )
            ).eBrainTurn
        )

        let directForecast = try XCTUnwrap(
            result.thoughtFrame.forecasts.first(where: { $0.candidateID == "path.direct" })
        )

        XCTAssertTrue(result.memoryBundle.retrievalTags.contains("constitution_goal_stage:care"))
        XCTAssertTrue(result.memoryBundle.retrievalTags.contains("constitution_relation_high_consequence:partner"))
        XCTAssertTrue(result.memoryBundle.retrievalTags.contains("constitution_memory_promotion:review_required"))
        XCTAssertTrue(directForecast.affectedRelations.contains("partner"))
        XCTAssertTrue(directForecast.affectedRelations.contains("constitution.v14"))
        XCTAssertTrue(directForecast.worstCase.contains("partner"))
    }

    func testRuntimeMemoryBundleTemporalFieldProjectsSealedAndRetiredStructures() throws {
        let runtime = BASHostRuntime(configuration: makeConfiguration())
        let request = BASHostSessionRequest(
            kind: .interactive,
            workflowProfile: .primary,
            surface: .application,
            prompt: "Keep the retrieval bounded.",
            title: "Runtime temporal memory field",
            riskLevel: .low
        )
        let session = try runtime.startSession(request)
        let archivedID = UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEE1")!
        let retiredID = UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEE2")!
        let anchoredNow = Date(timeIntervalSince1970: 1_776_200_600)

        let turn = runtime.buildEBrainTurn(
            request: request,
            currentBrain: session.currentBrain,
            projection: BASBrainProjection(
                records: [
                    BASGovernedMemory(
                        id: archivedID,
                        kind: .profile,
                        content: "Keep the partner boundary private.",
                        scope: .user,
                        sensitivity: .high,
                        tier: .cold,
                        confidence: 0.91,
                        sourceType: "history",
                        lastConfirmedAt: anchoredNow.addingTimeInterval(-600),
                        governanceStatus: .archived,
                        provenanceSummary: "Reviewed private boundary retained for guarded recall."
                    ),
                    BASGovernedMemory(
                        id: retiredID,
                        kind: .semantic,
                        content: "Discard the contaminated tool memory.",
                        scope: .session,
                        sensitivity: .medium,
                        tier: .warm,
                        confidence: 0.63,
                        sourceType: "tool",
                        lastConfirmedAt: anchoredNow.addingTimeInterval(-300),
                        governanceStatus: .quarantined,
                        provenanceSummary: "Quarantined during runtime review after contamination."
                    )
                ],
                candidates: [],
                recentEvents: []
            ),
            now: anchoredNow
        )

        let field = try XCTUnwrap(turn.memoryBundle.temporalField)
        let archivedRef = archivedID.uuidString
        let retiredRef = retiredID.uuidString
        let archivedProfile = try XCTUnwrap(
            field.temperatureProfiles.first(where: { $0.profileID == "temp.\(archivedRef)" })
        )
        let retiredProfile = try XCTUnwrap(
            field.temperatureProfiles.first(where: { $0.profileID == "temp.\(retiredRef)" })
        )

        XCTAssertEqual(field.sanctumEntries.map(\.memoryRef), [archivedRef])
        XCTAssertEqual(field.quarantineRecords.map(\.memoryRef), [retiredRef])
        XCTAssertEqual(archivedProfile.currentBand, .sealed)
        XCTAssertEqual(retiredProfile.currentBand, .quarantine)
        XCTAssertTrue(
            field.forgetCascades.contains(where: {
                $0.rootTargets == [archivedRef] && $0.executionState == "freeze_active"
            })
        )
        XCTAssertTrue(
            field.forgetCascades.contains(where: {
                $0.rootTargets == [retiredRef] && $0.executionState == "retired_runtime"
            })
        )
        XCTAssertTrue(
            field.replayFrames.contains(where: {
                $0.replayScope == .deletion && $0.targetRefs == [retiredRef]
            })
        )
        XCTAssertTrue(
            field.records.contains(where: {
                $0.memoryID == archivedRef && $0.sanctumFlag && !$0.quarantineFlag
            })
        )
        XCTAssertTrue(
            field.records.contains(where: {
                $0.memoryID == retiredRef && !$0.sanctumFlag && $0.quarantineFlag
            })
        )
    }

    func testConstitutionFacetsRestrictToolIntentDomainsAndRequireSecondCheck() throws {
        var tuning = makePolicyOwnedRuntimeTuning(
            schemaVersion: "host.runtime-synthesis.constitution-tool-intent.v1"
        )
        tuning.stateTransitions.lowRiskProtectedMode = .deepLoop
        tuning.stateTransitions.lowRiskDefaultMode = .deepLoop
        tuning.stateTransitions.lowRiskUrgentMode = .deepLoop
        tuning.stateTransitions.runModeRules = nil
        tuning.stateTransitions.runModeRules = tuning.stateTransitions.synthesizedRunModeRules(
            wakeIntent: tuning.wakeIntent
        )

        let constitution = BASHostConstitution(
            hostID: "host.constitution",
            activeVersion: "constitution.v15",
            boundaryVeil: BASBoundaryVeil(
                confirmRequired: ["external_send"],
                restrictedToolDomains: ["comparison"]
            ),
            consentLattice: BASConsentLattice(
                memoryWriteScope: "warm_only",
                memoryPromotionScope: "review_required",
                hostMutationScope: "review_required",
                toolReadScope: "local_only",
                toolWriteScope: "confirm_required",
                syncScope: "local_only"
            ),
            narrativeLoom: BASNarrativeLoom(
                longFormSummary: "Keep tool action bounded and explicitly reviewed.",
                currentPhase: "care"
            )
        )

        let turn = try XCTUnwrap(
            BASHostRuntime(
                configuration: makeConfiguration(
                    runtimeTuning: tuning,
                    hostConstitution: constitution
                )
            ).startSession(
                BASHostSessionRequest(
                    kind: .interactive,
                    workflowProfile: .primary,
                    surface: .application,
                    prompt: "Plan a multi-step strategy and compare the tradeoffs before acting.",
                    title: "Tool intent restriction",
                    riskLevel: .low
                )
            ).eBrainTurn
        )

        XCTAssertEqual(turn.budgetFrame.runMode, .deepLoop)
        XCTAssertNotEqual(turn.actionPermit.mode, .block)
        let toolIntent = try XCTUnwrap(turn.thoughtFrame.toolIntentEnvelope)
        let primaryBinding = try XCTUnwrap(
            turn.thoughtFrame.riskBindings?.first(where: { $0.candidateID == toolIntent.candidateID })
        )

        XCTAssertEqual(toolIntent.permitMode, .compare)
        XCTAssertTrue(toolIntent.requestedDomains.contains("bounded_reply"))
        XCTAssertFalse(toolIntent.requestedDomains.contains("comparison"))
        XCTAssertTrue(toolIntent.blockedDomains.contains("comparison"))
        XCTAssertTrue(toolIntent.requireSecondCheck)
        XCTAssertTrue(toolIntent.reasonCodes.contains("constitution.tool_domain_restricted"))
        XCTAssertTrue(toolIntent.reasonCodes.contains("constitution.tool_write_scope.confirm_required"))
        XCTAssertFalse(primaryBinding.allowedDomains.contains("comparison"))
        XCTAssertTrue(primaryBinding.forbiddenDomains.contains("comparison"))
        XCTAssertTrue(primaryBinding.requireSecondCheck)
        XCTAssertTrue(primaryBinding.reasonCodes.contains("constitution.tool_domain_restricted"))
        XCTAssertTrue(primaryBinding.reasonCodes.contains("constitution.tool_write_scope.confirm_required"))
    }

    func testExplicitConstitutionShapesEvolutionHostChangeCandidate() throws {
        let request = BASHostSessionRequest(
            kind: .interactive,
            workflowProfile: .primary,
            surface: .application,
            prompt: "Draft the reply now.",
            title: "Constitution-guided evolution review",
            riskLevel: .low
        )

        let baselineRuntime = BASHostRuntime(configuration: makeConfiguration())
        let baselineSession = try baselineRuntime.startSession(request)
        var baselineBrain = baselineSession.currentBrain
        baselineBrain.calibrationStatus = .drifting
        let baselineTurn = baselineRuntime.buildEBrainTurn(
            request: request,
            currentBrain: baselineBrain,
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

        let constitution = BASHostConstitution(
            hostID: "host.constitution",
            activeVersion: "constitution.v16",
            goalSpine: BASGoalSpine(
                goals: ["stay_bounded", "protect_partner_context"],
                priorityOrder: ["stay_bounded", "protect_partner_context"],
                stageState: "care"
            ),
            boundaryVeil: BASBoundaryVeil(
                confirmRequired: ["external_send"]
            ),
            consentLattice: BASConsentLattice(
                hostMutationScope: "review_required",
                toolWriteScope: "confirm_required"
            ),
            narrativeLoom: BASNarrativeLoom(
                longFormSummary: "Keep host evolution bounded and review-first.",
                currentPhase: "care"
            )
        )

        let constitutionRuntime = BASHostRuntime(
            configuration: makeConfiguration(hostConstitution: constitution)
        )
        let constitutionSession = try constitutionRuntime.startSession(request)
        var constitutionBrain = constitutionSession.currentBrain
        constitutionBrain.calibrationStatus = .drifting
        let constitutionTurn = constitutionRuntime.buildEBrainTurn(
            request: request,
            currentBrain: constitutionBrain,
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

        let baselineCandidate = try XCTUnwrap(baselineTurn.updateTickets.first?.hostChangeCandidate)
        let constitutionCandidate = try XCTUnwrap(constitutionTurn.updateTickets.first?.hostChangeCandidate)

        XCTAssertEqual(baselineCandidate.changeType, "review_constitution_alignment")
        XCTAssertTrue(baselineCandidate.proposedDelta.contains("goal_spine"))
        XCTAssertTrue(baselineCandidate.proposedDelta.contains("boundary_veil"))
        XCTAssertTrue(baselineCandidate.proposedDelta.contains("consent_lattice"))
        XCTAssertTrue(baselineCandidate.evidenceRefs.contains(where: { $0.hasPrefix("constitution:") }))
        XCTAssertTrue(baselineCandidate.evidenceRefs.contains(where: { $0.hasPrefix("phase:") }))

        XCTAssertEqual(constitutionCandidate.changeType, "review_constitution_alignment")
        XCTAssertTrue(constitutionCandidate.proposedDelta.contains("goal_spine"))
        XCTAssertTrue(constitutionCandidate.proposedDelta.contains("boundary_veil"))
        XCTAssertTrue(constitutionCandidate.proposedDelta.contains("consent_lattice"))
        XCTAssertTrue(constitutionCandidate.evidenceRefs.contains("constitution:constitution.v16"))
        XCTAssertTrue(constitutionCandidate.evidenceRefs.contains("phase:care"))
        XCTAssertTrue(constitutionCandidate.evidenceRefs.contains("goal:stay_bounded"))
        XCTAssertTrue(constitutionCandidate.evidenceRefs.contains("confirm_required:external_send"))
        XCTAssertTrue(constitutionCandidate.evidenceRefs.contains("host_mutation_scope:review_required"))
    }

}
