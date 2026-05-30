// MARK: - BASHostKitRunModeLaneTests — chapter 二百九十八 / M785
//
// Phase Alpha 第二十四刀(BASHostKitTests god file 3rd cut, FINAL):
// 从 `BASHostKitTests.swift` 抽出 run mode lane / quarantine /
// recovery / sovereign warrant / evidence caveat / state transition
// test cluster — Phase Alpha 第五个 god file 完结。
//
// 抽出 18 个 test methods (Swift extension on BASHostKitTests):
//   - testRecoveryMarkerForcesRecoveryRunMode
//   - testGenericHostRuntimeFallsIntoQuarantineRestrictedLane
//   - testCustomHostRuntimeMissingLineageFallsIntoRecoveryRestrictedLane
//   - testHostRuntimeWithExplicitLineageButCompiledGenericTuningFallsIntoQuarantineRestrictedLane
//   - testHostRuntimeWithExplicitLineageAndSchemaDistinctRuntimeTuningFallsIntoQuarantineWhenFamiliesStillUseCompiledGenericValues
//   - testHostRuntimeWithExplicitLineageAndMissingRunModeBudgetProfilesFallsIntoQuarantineRestrictedLane
//   - testHostRuntimeWithExplicitLineageAndMissingRunModeRulesFallsIntoQuarantineRestrictedLane
//   - testHostRuntimeWithExplicitLineageAndIncompleteRunModeProfilePlannerInputsFallsIntoQuarantineRestrictedLane
//   - testQuarantineRestrictedLaneEmitsLatchedSovereignKernelArtifacts
//   - testHealthyTurnProjectsSingleUseSovereignWarrantsFromCommitTokens
//   - testMissingLineageRecoveryEscalatesIntoMemoryFreezeWhenWritesNeedReview
//   - testEvidenceCaveatLoadTriggersGuardedBudgetRunMode
//   - testStateTransitionPolicyCanChooseRetrievalTagsThatTriggerGuardedBudgetMode
//   - testWakeIntentPolicyCanChooseUrgencyCuePhrasesThatTriggerUrgentRunMode
//   - testEvidenceCaveatLoadSurfacesInUnknownsRiskFactorsAndExplanationCodes
//   - testCustomRuntimeTuningGovernsLoopCandidateRetrievalAndPrecision
//   - testCustomRuntimeTuningGovernsTransitionProfilesAndMaintenanceClass
//
// **0 behavior change**:test methods literal-identical to
// pre-extraction versions,只是改成了 `extension BASHostKitTests`
// in a new file。
//
// Doctrine pins:
//   - 不变量 #1 / #2 / #3 全保
//   - chapter 二百一一 single-source-of-truth
//   - run mode lane invariants 行为不变
//   - sovereign warrant + commit token doctrine 不变
//
// **Phase Alpha milestone**: BASHostKitTests god file 拆完 —
// 5626 → ~3400 LOC across 3 cuts (Constitution / RuntimeTuning /
// RunModeLane)。Phase Alpha 5/5 god files now CLOSED.

import XCTest
@testable import BASAdmin
@testable import BASHostKit
@testable import BASMemory
@testable import BASOrchestration
@testable import BASPolicy
@testable import BASRuntimeCore

extension BASHostKitTests {
    func testRecoveryMarkerForcesRecoveryRunMode() throws {
        let runtime = makeGenericRuntime()
        let seedResult = try runtime.startSession(
            BASHostSessionRequest(
                kind: .interactive,
                workflowProfile: .primary,
                surface: .application,
                prompt: "Need a recovery lane.",
                title: "Recovery lane",
                riskLevel: .low
            )
        )
        var recoveryBrain = seedResult.currentBrain
        recoveryBrain.activeConstraints.append("brain-bootstrap-recovery")
        recoveryBrain.retrievalTags.append("recovery")

        let turn = runtime.buildEBrainTurn(
            request: BASHostSessionRequest(
                kind: .interactive,
                workflowProfile: .primary,
                surface: .application,
                prompt: "Need a recovery lane.",
                title: "Recovery lane",
                riskLevel: .low
            ),
            currentBrain: recoveryBrain,
            projection: BASBrainProjection(records: [], candidates: [], recentEvents: [])
        )

        XCTAssertEqual(turn.budgetFrame.runMode, .recovery)
    }

    func testGenericHostRuntimeFallsIntoQuarantineRestrictedLane() throws {
        let runtime = BASHostRuntime(configuration: .fixtureGeneric)

        let result = try runtime.startSession(
            BASHostSessionRequest(
                kind: .interactive,
                workflowProfile: .primary,
                surface: .application,
                prompt: "Keep this local and stable.",
                title: "Generic quarantine lane",
                riskLevel: .low
            )
        )

        let turn = try XCTUnwrap(result.eBrainTurn)
        XCTAssertEqual(turn.budgetFrame.runMode, .quarantine)
        XCTAssertEqual(turn.recoveryDisposition?.kind, .quarantine)
        XCTAssertEqual(turn.recoveryDisposition?.restrictedLease, true)
        XCTAssertEqual(turn.recoveryDisposition?.toolWriteAllowed, false)
        XCTAssertEqual(turn.recoveryDisposition?.memoryWriteAllowed, false)
        XCTAssertEqual(turn.recoveryDisposition?.operatorReviewRequired, true)
        XCTAssertEqual(turn.recoveryDisposition?.requiredConfirmations, ["operator_quarantine_release"])
        XCTAssertEqual(
            turn.recoveryDisposition?.allowedActionClasses,
            ["render_local_guidance", "load_governed_memory"]
        )
        XCTAssertEqual(turn.recoveryDisposition?.blockedActionClasses, ["tool_write", "memory_write"])
        XCTAssertEqual(
            turn.recoveryDisposition?.remediationActions,
            [
                "review_runtime_diagnostics",
                "preserve_quarantine_evidence",
                "rebuild_trusted_state",
                "collect_confirmation:operator_quarantine_release"
            ]
        )
    }

    func testCustomHostRuntimeMissingLineageFallsIntoRecoveryRestrictedLane() throws {
        let explicitTuning = makePolicyOwnedRuntimeTuning(
            schemaVersion: "host.runtime-synthesis.explicit-no-lineage.v1"
        )
        let explicitRhythm = BASHostRhythmProfile(
            activeWindows: ["focused_window"],
            highFocusWindows: ["review_window"],
            lowEnergyWindows: ["quiet_window"],
            preferredInteractionStyle: "structured",
            sensitivityPeriods: ["handoff"]
        )
        let explicitDeviceState = BASDeviceState(
            batteryLevel: 0.74,
            thermalLevel: .nominal,
            memoryFreeMB: 2_560,
            networkState: .constrained,
            foregroundState: .foreground,
            cpuLoad: 0.14,
            gpuLoad: 0.07,
            npuAvailable: true,
            latencyBudgetMs: 1_050
        )
        let runtime = BASHostRuntime(
            configuration: BASHostConfiguration(
                runtimeProfileID: "host.explicit-runtime",
                policyProfileID: "host.explicit-policy",
                prefersPureLocal: true,
                defaultDeviceState: explicitDeviceState,
                console: .generic,
                lifecycleBehavior: .generic,
                workflowBehavior: .generic,
                cognitionBehavior: .generic,
                presentation: .generic,
                runtimeTuning: explicitTuning,
                runtimePolicyLineage: nil,
                hostRhythmProfile: explicitRhythm
            )
        )

        let result = try runtime.startSession(
            BASHostSessionRequest(
                kind: .interactive,
                workflowProfile: .primary,
                surface: .application,
                prompt: "Keep this local and stable.",
                title: "Missing lineage recovery lane",
                riskLevel: .low
            )
        )

        let turn = try XCTUnwrap(result.eBrainTurn)
        XCTAssertEqual(turn.budgetFrame.runMode, .recovery)
        XCTAssertEqual(turn.recoveryDisposition?.kind, .recovery)
        XCTAssertEqual(turn.recoveryDisposition?.restrictedLease, true)
        XCTAssertEqual(turn.recoveryDisposition?.toolWriteAllowed, false)
        XCTAssertEqual(turn.recoveryDisposition?.memoryWriteAllowed, false)
        XCTAssertEqual(turn.recoveryDisposition?.operatorReviewRequired, true)
        XCTAssertEqual(turn.recoveryDisposition?.requiredConfirmations, ["operator_recovery_review"])
        XCTAssertEqual(
            turn.recoveryDisposition?.allowedActionClasses,
            ["render_local_guidance", "load_governed_memory"]
        )
        XCTAssertEqual(turn.recoveryDisposition?.blockedActionClasses, ["tool_write", "memory_write"])
        XCTAssertEqual(
            turn.recoveryDisposition?.remediationActions,
            [
                "review_runtime_diagnostics",
                "rebuild_trusted_state",
                "collect_confirmation:operator_recovery_review"
            ]
        )
    }

    func testHostRuntimeWithExplicitLineageButCompiledGenericTuningFallsIntoQuarantineRestrictedLane() throws {
        let runtime = BASHostRuntime(
            configuration: BASHostConfiguration(
                runtimeProfileID: "before.local-cognition",
                policyProfileID: "before.product-policy",
                prefersPureLocal: true,
                defaultDeviceState: BASHostConfiguration.fixtureDefaultDeviceState,
                console: .generic,
                lifecycleBehavior: .generic,
                workflowBehavior: .generic,
                cognitionBehavior: .generic,
                presentation: .generic,
                runtimeTuning: .generic,
                runtimePolicyLineage: makeRuntimePolicyLineage(
                    bundleVersion: "before.runtime-policy-bundle.v1",
                    providerRoutingPolicyID: "before.provider-routing.v1",
                    runtimeTuningPolicyID: "before.host.runtime-synthesis.v1",
                    resolutionSourceID: "bundled_default"
                ),
                hostRhythmProfile: .generic
            )
        )

        let result = try runtime.startSession(
            BASHostSessionRequest(
                kind: .interactive,
                workflowProfile: .primary,
                surface: .application,
                prompt: "Keep this local and stable.",
                title: "Compiled generic tuning quarantine lane",
                riskLevel: .low
            )
        )

        let turn = try XCTUnwrap(result.eBrainTurn)
        XCTAssertEqual(turn.budgetFrame.runMode, .quarantine)
        XCTAssertEqual(turn.recoveryDisposition?.kind, .quarantine)
        XCTAssertEqual(turn.recoveryDisposition?.restrictedLease, true)
        XCTAssertEqual(turn.recoveryDisposition?.toolWriteAllowed, false)
        XCTAssertEqual(turn.recoveryDisposition?.memoryWriteAllowed, false)
    }

    func testHostRuntimeWithExplicitLineageAndSchemaDistinctRuntimeTuningFallsIntoQuarantineWhenFamiliesStillUseCompiledGenericValues() throws {
        var tuning = makePolicyOwnedRuntimeTuning(
            schemaVersion: "host.runtime-synthesis.partial-generic.v1"
        )
        tuning.maintenance = .generic

        let runtime = BASHostRuntime(
            configuration: BASHostConfiguration(
                runtimeProfileID: "before.local-cognition",
                policyProfileID: "before.product-policy",
                prefersPureLocal: true,
                defaultDeviceState: BASHostConfiguration.fixtureDefaultDeviceState,
                console: .generic,
                lifecycleBehavior: .generic,
                workflowBehavior: .generic,
                cognitionBehavior: .generic,
                presentation: .generic,
                runtimeTuning: tuning,
                runtimePolicyLineage: makeRuntimePolicyLineage(
                    bundleVersion: "before.runtime-policy-bundle.v1",
                    providerRoutingPolicyID: "before.provider-routing.v1",
                    runtimeTuningPolicyID: "before.host.runtime-synthesis.v1",
                    resolutionSourceID: "bundled_default"
                ),
                hostRhythmProfile: .generic
            )
        )

        let result = try runtime.startSession(
            BASHostSessionRequest(
                kind: .interactive,
                workflowProfile: .primary,
                surface: .application,
                prompt: "Keep this local and stable.",
                title: "Partially generic tuning quarantine lane",
                riskLevel: .low
            )
        )

        let turn = try XCTUnwrap(result.eBrainTurn)
        XCTAssertEqual(turn.budgetFrame.runMode, .quarantine)
        XCTAssertEqual(turn.recoveryDisposition?.kind, .quarantine)
        XCTAssertEqual(turn.recoveryDisposition?.restrictedLease, true)
    }

    func testHostRuntimeWithExplicitLineageAndMissingRunModeBudgetProfilesFallsIntoQuarantineRestrictedLane() throws {
        var tuning = makePolicyOwnedRuntimeTuning(
            schemaVersion: "host.runtime-synthesis.missing-budget-profiles.v1"
        )
        tuning.budget.runModeProfilesByID = nil

        let runtime = BASHostRuntime(
            configuration: makeConfiguration(runtimeTuning: tuning)
        )

        let result = try runtime.startSession(
            BASHostSessionRequest(
                kind: .interactive,
                workflowProfile: .primary,
                surface: .application,
                prompt: "Keep this calm and local.",
                title: "Missing budget profiles quarantine lane",
                riskLevel: .low
            )
        )

        let turn = try XCTUnwrap(result.eBrainTurn)
        XCTAssertEqual(turn.budgetFrame.runMode, .quarantine)
        XCTAssertEqual(turn.recoveryDisposition?.kind, .quarantine)
        XCTAssertEqual(turn.recoveryDisposition?.restrictedLease, true)
    }

    func testHostRuntimeWithExplicitLineageAndMissingRunModeRulesFallsIntoQuarantineRestrictedLane() throws {
        var tuning = makePolicyOwnedRuntimeTuning(
            schemaVersion: "host.runtime-synthesis.missing-transition-rules.v1"
        )
        tuning.stateTransitions.runModeRules = nil

        let runtime = BASHostRuntime(
            configuration: makeConfiguration(runtimeTuning: tuning)
        )

        let result = try runtime.startSession(
            BASHostSessionRequest(
                kind: .interactive,
                workflowProfile: .primary,
                surface: .application,
                prompt: "Keep this calm and local.",
                title: "Missing transition rules quarantine lane",
                riskLevel: .low
            )
        )

        let turn = try XCTUnwrap(result.eBrainTurn)
        XCTAssertEqual(turn.budgetFrame.runMode, .quarantine)
        XCTAssertEqual(turn.recoveryDisposition?.kind, .quarantine)
        XCTAssertEqual(turn.recoveryDisposition?.restrictedLease, true)
    }

    func testHostRuntimeWithExplicitLineageAndIncompleteRunModeProfilePlannerInputsFallsIntoQuarantineRestrictedLane() throws {
        var tuning = makePolicyOwnedRuntimeTuning(
            schemaVersion: "host.runtime-synthesis.incomplete-profile-inputs.v1"
        )
        var engageProfile = try XCTUnwrap(tuning.budget.runModeProfilesByID?[BASEBrainRunMode.engage.rawValue])
        engageProfile.unstableLoopIncrementRiskLevels = nil
        engageProfile.throttlePenaltyThermalLevels = nil
        tuning.budget.runModeProfilesByID?[BASEBrainRunMode.engage.rawValue] = engageProfile

        let runtime = BASHostRuntime(
            configuration: makeConfiguration(runtimeTuning: tuning)
        )

        let result = try runtime.startSession(
            BASHostSessionRequest(
                kind: .interactive,
                workflowProfile: .primary,
                surface: .application,
                prompt: "Keep this calm and local.",
                title: "Incomplete profile inputs quarantine lane",
                riskLevel: .low
            )
        )

        let turn = try XCTUnwrap(result.eBrainTurn)
        XCTAssertEqual(turn.budgetFrame.runMode, .quarantine)
        XCTAssertEqual(turn.recoveryDisposition?.kind, .quarantine)
        XCTAssertEqual(turn.recoveryDisposition?.restrictedLease, true)
    }

    func testQuarantineRestrictedLaneEmitsLatchedSovereignKernelArtifacts() throws {
        let runtime = BASHostRuntime(configuration: .fixtureGeneric)

        let turn = try XCTUnwrap(
            runtime.startSession(
                BASHostSessionRequest(
                    kind: .interactive,
                    workflowProfile: .primary,
                    surface: .application,
                    prompt: "Keep this local and stable.",
                    title: "Generic quarantine sovereign",
                    riskLevel: .low
                )
            ).eBrainTurn
        )

        let verdict = try XCTUnwrap(turn.sovereignVerdict)
        let lock = try XCTUnwrap(turn.sovereignLock)
        let auditEntry = try XCTUnwrap(turn.sovereignAuditEntry)

        XCTAssertEqual(verdict.verdictLevel, .quarantine)
        XCTAssertTrue(verdict.latched)
        XCTAssertEqual(lock.scope, .session)
        XCTAssertEqual(lock.lockLevel, .quarantine)
        XCTAssertTrue(turn.sovereignCommitTokens.isEmpty)
        XCTAssertEqual(turn.quarantineRecords.map(\.zone), [.session, .cache])
        XCTAssertEqual(auditEntry.verdictRef, verdict.verdictID)
        XCTAssertEqual(turn.evolutionLineageSummary.sovereignVerdict, verdict)
        XCTAssertEqual(turn.evolutionLineageSummary.sovereignAuditEntry, auditEntry)
        XCTAssertTrue(turn.sovereignWarrants.isEmpty)
        XCTAssertEqual(turn.recoveryDisposition?.kind, .quarantine)
    }

    func testHealthyTurnProjectsSingleUseSovereignWarrantsFromCommitTokens() throws {
        let runtime = BASHostRuntime(
            configuration: makeConfiguration(
                hostConstitution: BASHostConstitution(
                    hostID: "host.healthy",
                    activeVersion: "constitution.healthy.v1",
                    valueAxes: BASValueAxisSet(
                        axes: ["clarity", "speed"],
                        relativeWeights: [0.52, 0.48],
                        conflictRules: [],
                        updateThreshold: 0.95
                    ),
                    goalSpine: BASGoalSpine(
                        goals: ["reply_clearly"],
                        priorityOrder: ["reply_clearly"],
                        stageState: "steady"
                    ),
                    narrativeLoom: BASNarrativeLoom(
                        longFormSummary: "Keep the turn steady and release only boundedly.",
                        currentPhase: "steady"
                    )
                )
            )
        )

        let turn = try XCTUnwrap(
            runtime.startSession(
                BASHostSessionRequest(
                    kind: .interactive,
                    workflowProfile: .primary,
                    surface: .application,
                    prompt: "Draft a bounded local reply and keep the session stable.",
                    title: "Healthy turn warrants",
                    riskLevel: .low
                )
            ).eBrainTurn
        )

        XCTAssertEqual(turn.sovereignVerdict?.verdictLevel, .memoryFreeze)
        XCTAssertEqual(turn.sovereignCommitTokens.map(\.scope), [.checkpointCommit, .renderHighRisk])
        XCTAssertEqual(turn.sovereignWarrants.map(\.scope), [.checkpointCommit, .renderHighRisk])
        XCTAssertEqual(turn.sovereignWarrants.map(\.actionDigest), turn.sovereignCommitTokens.map(\.actionDigest))
        XCTAssertTrue(turn.sovereignWarrants.allSatisfy(\.singleUse))
        XCTAssertTrue(
            zip(turn.sovereignWarrants, turn.sovereignCommitTokens).allSatisfy { warrant, token in
                warrant.jurisdictionRef == "jurisdiction.\(token.scope.rawValue)"
                    && warrant.commitTokenRef == token.tokenID
                    && warrant.snapshotRef == token.snapshotRef
                    && warrant.policyHash == token.policyHash
                    && warrant.timeLockRef.contains(token.turnID)
                    && warrant.timeLockRef.contains("ttl_\(token.ttlMs)")
                    && warrant.witnessRefs.contains("permit.\(token.turnID).\(token.scope.rawValue)")
                    && warrant.witnessRefs.contains("integrity.\(token.snapshotRef)")
                    && warrant.witnessRefs.contains("continuity.\(token.turnID)")
                    && warrant.witnessRefs.contains("policy.\(token.policyHash)")
            }
        )
        XCTAssertTrue(
            zip(turn.sovereignWarrants, turn.sovereignCommitTokens).allSatisfy { warrant, token in
                guard let issuedAt = warrant.issuedAt,
                      let expiresAt = warrant.expiresAt else {
                    return false
                }

                let ttlSeconds = Double(token.ttlMs) / 1_000
                let scopeSpecificWitness: String = switch token.scope {
                case .checkpointCommit:
                    "checkpoint.\(token.snapshotRef)"
                case .renderHighRisk:
                    "render.second_check.\(token.turnID)"
                case .memoryWrite:
                    "mutation.memory.\(token.turnID)"
                case .toolRead:
                    "tool.read.\(token.allowedTargets.first ?? "local")"
                case .toolWrite:
                    "tool.write.\(token.allowedTargets.first ?? "local")"
                case .hostMutate:
                    "mutation.host.\(token.turnID)"
                }

                return abs(expiresAt.timeIntervalSince(issuedAt) - ttlSeconds) < 0.001
                    && warrant.witnessRefs.contains(scopeSpecificWitness)
            }
        )
        XCTAssertEqual(turn.evolutionLineageSummary.sovereignCommitTokens, turn.sovereignCommitTokens)
        XCTAssertEqual(turn.evolutionLineageSummary.sovereignWarrants, turn.sovereignWarrants)
    }

    /// ch1044 audit HIGH-1 regression guard (and the HIGH-2-scoped
    /// determinism test that was missing): the SAME healthy turn run
    /// twice with the SAME injected `now` must produce BIT-IDENTICAL
    /// sovereign commit tokens — including the `nonce` and `signature`
    /// fields. Before the fix, `makeCommitToken` minted the nonce from
    /// `UUID()` (process-random), so the token bytes differed every run
    /// even on identical inputs, silently breaking replay-determinism of
    /// `BASEBrainTurnResult`. This turn is the `testHealthyTurn…` recipe,
    /// which is known to mint [.checkpointCommit, .renderHighRisk] tokens,
    /// so the guard exercises the real commit-token path.
    func testSovereignCommitTokensAreReplayDeterministic() throws {
        func makeHealthyRuntime() -> BASHostRuntime {
            BASHostRuntime(
                configuration: makeConfiguration(
                    hostConstitution: BASHostConstitution(
                        hostID: "host.healthy",
                        activeVersion: "constitution.healthy.v1",
                        valueAxes: BASValueAxisSet(
                            axes: ["clarity", "speed"],
                            relativeWeights: [0.52, 0.48],
                            conflictRules: [],
                            updateThreshold: 0.95
                        ),
                        goalSpine: BASGoalSpine(
                            goals: ["reply_clearly"],
                            priorityOrder: ["reply_clearly"],
                            stageState: "steady"
                        ),
                        narrativeLoom: BASNarrativeLoom(
                            longFormSummary:
                                "Keep the turn steady and release only boundedly.",
                            currentPhase: "steady"
                        )
                    )
                )
            )
        }
        // A FIXED injected `now` — so the deterministic nonce (which folds
        // in `issuedAt` = runtimeTrace.recordedAt) is genuinely comparable
        // across the two runs. With the old UUID() nonce, the tokens would
        // differ here regardless of the fixed clock.
        let fixedNow = Date(timeIntervalSinceReferenceDate: 760_000_000)
        let request = BASHostSessionRequest(
            kind: .interactive,
            workflowProfile: .primary,
            surface: .application,
            prompt: "Draft a bounded local reply and keep the session stable.",
            title: "Replay determinism guard",
            riskLevel: .low
        )

        let turnA = try XCTUnwrap(
            makeHealthyRuntime().startSession(request, now: fixedNow).eBrainTurn)
        let turnB = try XCTUnwrap(
            makeHealthyRuntime().startSession(request, now: fixedNow).eBrainTurn)

        // Precondition: this turn really does mint commit tokens (else the
        // guard would be vacuous — the HIGH-2 failure mode).
        XCTAssertFalse(turnA.sovereignCommitTokens.isEmpty,
            "precondition: the healthy turn must mint commit tokens")

        // The whole point: tokens are bit-identical across runs, INCLUDING
        // the nonce + signature (the fields the UUID() bug made vary).
        XCTAssertEqual(turnA.sovereignCommitTokens, turnB.sovereignCommitTokens,
            "commit tokens must be replay-deterministic (HIGH-1)")
        XCTAssertEqual(
            turnA.sovereignCommitTokens.map(\.nonce),
            turnB.sovereignCommitTokens.map(\.nonce),
            "the nonce must be deterministic (was UUID() — HIGH-1)")
        XCTAssertEqual(
            turnA.sovereignCommitTokens.map(\.signature),
            turnB.sovereignCommitTokens.map(\.signature),
            "the signature folds in the nonce → must be deterministic too")
        // Distinct-scope tokens within ONE turn still have DISTINCT nonces
        // (the fix preserves uniqueness; it only removed randomness).
        let nonces = turnA.sovereignCommitTokens.map(\.nonce)
        XCTAssertEqual(Set(nonces).count, nonces.count,
            "distinct tokens keep distinct nonces (uniqueness preserved)")
    }

    func testMissingLineageRecoveryEscalatesIntoMemoryFreezeWhenWritesNeedReview() throws {
        let explicitTuning = makePolicyOwnedRuntimeTuning(
            schemaVersion: "host.runtime-synthesis.explicit-no-lineage.v2"
        )
        let runtime = BASHostRuntime(
            configuration: BASHostConfiguration(
                runtimeProfileID: "host.explicit-runtime",
                policyProfileID: "host.explicit-policy",
                prefersPureLocal: true,
                defaultDeviceState: BASDeviceState(
                    batteryLevel: 0.74,
                    thermalLevel: .nominal,
                    memoryFreeMB: 2_560,
                    networkState: .constrained,
                    foregroundState: .foreground,
                    cpuLoad: 0.14,
                    gpuLoad: 0.07,
                    npuAvailable: true,
                    latencyBudgetMs: 1_050
                ),
                console: .generic,
                lifecycleBehavior: .generic,
                workflowBehavior: .generic,
                cognitionBehavior: .generic,
                presentation: .generic,
                runtimeTuning: explicitTuning,
                runtimePolicyLineage: nil,
                hostRhythmProfile: BASHostRhythmProfile(
                    activeWindows: ["focused_window"],
                    highFocusWindows: ["review_window"],
                    lowEnergyWindows: ["quiet_window"],
                    preferredInteractionStyle: "structured",
                    sensitivityPeriods: ["handoff"]
                )
            )
        )

        let turn = try XCTUnwrap(
            runtime.startSession(
                BASHostSessionRequest(
                    kind: .interactive,
                    workflowProfile: .primary,
                    surface: .application,
                    prompt: "Keep this local and stable.",
                    title: "Missing lineage shadow lock",
                    riskLevel: .low
                )
            ).eBrainTurn
        )

        let verdict = try XCTUnwrap(turn.sovereignVerdict)
        let auditEntry = try XCTUnwrap(turn.sovereignAuditEntry)

        XCTAssertEqual(turn.budgetFrame.runMode, .recovery)
        XCTAssertEqual(verdict.verdictLevel, .memoryFreeze)
        XCTAssertTrue(verdict.latched)
        XCTAssertTrue(verdict.reasonCodes.contains("runtime.policy_lineage_missing"))
        XCTAssertTrue(verdict.reasonCodes.contains("writes.review_required"))
        XCTAssertTrue(verdict.revokedPermissions.contains(.checkpointCommit))
        XCTAssertTrue(verdict.revokedPermissions.contains(.memoryWriteHot))
        XCTAssertEqual(turn.recoveryDisposition?.kind, .recovery)
        XCTAssertFalse(turn.sovereignCommitTokens.contains(where: { $0.scope == .checkpointCommit }))
        XCTAssertFalse(turn.sovereignCommitTokens.contains(where: { $0.scope == .memoryWrite }))
        XCTAssertEqual(turn.sovereignWarrants.map(\.scope), turn.sovereignCommitTokens.map(\.scope))
        XCTAssertEqual(auditEntry.verdictRef, verdict.verdictID)
        XCTAssertTrue(auditEntry.ruleIDs.contains("BR-SOV-001"))
        XCTAssertTrue(auditEntry.ruleIDs.contains("BR-SOV-003"))
        XCTAssertEqual(turn.evolutionLineageSummary.sovereignCommitTokens, turn.sovereignCommitTokens)
        XCTAssertEqual(turn.evolutionLineageSummary.sovereignWarrants, turn.sovereignWarrants)
    }

    func testEvidenceCaveatLoadTriggersGuardedBudgetRunMode() throws {
        var tuning = makePolicyOwnedRuntimeTuning(
            schemaVersion: "host.runtime-synthesis.evidence-caveat-guard.v1"
        )
        tuning.stateTransitions = .init(
            backgroundPulseEnabled: false,
            recoveryOnCriticalThermal: true,
            reflectOnTrustDrift: true,
            deepLoopOnProtectedBoundary: false,
            lockdownOnExtremeBlockedPermit: true,
            quarantineFailureGuardThreshold: 2,
            lowRiskBackgroundMode: .pulse,
            lowRiskProtectedMode: .guard,
            lowRiskUrgentMode: .engage,
            lowRiskDefaultMode: .sentinel,
            mediumRiskProtectedDeepLoopMode: .deepLoop,
            mediumRiskReflectiveMode: .reflect,
            mediumRiskDefaultMode: .engage,
            highRiskMode: .guard,
            extremeRiskMode: .lockdown,
            recoveryMode: .recovery,
            quarantineMode: .quarantine
        )
        tuning.stateTransitions.runModeRules = tuning.stateTransitions.synthesizedRunModeRules(
            wakeIntent: tuning.wakeIntent
        )
        let runtime = BASHostRuntime(
            configuration: makeConfiguration(runtimeTuning: tuning)
        )
        let seedResult = try runtime.startSession(
            BASHostSessionRequest(
                kind: .interactive,
                workflowProfile: .primary,
                surface: .application,
                prompt: "Keep this calm and local.",
                title: "Evidence caveat guard",
                riskLevel: .low
            )
        )
        var evidenceGuardedBrain = seedResult.currentBrain
        evidenceGuardedBrain.riskFlags.append(.evidenceCaveatLoad)

        let turn = runtime.buildEBrainTurn(
            request: BASHostSessionRequest(
                kind: .interactive,
                workflowProfile: .primary,
                surface: .application,
                prompt: "Keep this calm and local.",
                title: "Evidence caveat guard",
                riskLevel: .low
            ),
            currentBrain: evidenceGuardedBrain,
            projection: BASBrainProjection(records: [], candidates: [], recentEvents: [])
        )

        XCTAssertEqual(turn.budgetFrame.runMode, .guard)
    }

    func testStateTransitionPolicyCanChooseRetrievalTagsThatTriggerGuardedBudgetMode() throws {
        var tuning = makePolicyOwnedRuntimeTuning(
            schemaVersion: "host.runtime-synthesis.guarded-budget-tags.v1"
        )
        tuning.stateTransitions = .init(
            backgroundPulseEnabled: false,
            recoveryOnCriticalThermal: true,
            reflectOnTrustDrift: true,
            deepLoopOnProtectedBoundary: false,
            lockdownOnExtremeBlockedPermit: true,
            quarantineFailureGuardThreshold: 2,
            lowRiskBackgroundMode: .pulse,
            lowRiskProtectedMode: .guard,
            lowRiskUrgentMode: .engage,
            lowRiskDefaultMode: .sentinel,
            mediumRiskProtectedDeepLoopMode: .deepLoop,
            mediumRiskReflectiveMode: .reflect,
            mediumRiskDefaultMode: .engage,
            highRiskMode: .guard,
            extremeRiskMode: .lockdown,
            recoveryMode: .recovery,
            quarantineMode: .quarantine
        )
        tuning.stateTransitions.guardedBudgetBoundaryModes = []
        tuning.stateTransitions.guardedBudgetCalibrationStatuses = []
        tuning.stateTransitions.guardedBudgetRiskFlags = []
        tuning.stateTransitions.guardedBudgetRetrievalTags = ["evidence_caveat"]
        tuning.stateTransitions.runModeRules = tuning.stateTransitions.synthesizedRunModeRules(
            wakeIntent: tuning.wakeIntent
        )
        let runtime = BASHostRuntime(
            configuration: makeConfiguration(runtimeTuning: tuning)
        )
        let seedResult = try runtime.startSession(
            BASHostSessionRequest(
                kind: .interactive,
                workflowProfile: .primary,
                surface: .application,
                prompt: "Keep this calm and local.",
                title: "Evidence caveat tag guard",
                riskLevel: .low
            )
        )
        var evidenceGuardedBrain = seedResult.currentBrain
        evidenceGuardedBrain.boundaryMode = .localOnlyAdvisory
        evidenceGuardedBrain.retrievalTags.append("evidence_caveat")

        let turn = runtime.buildEBrainTurn(
            request: BASHostSessionRequest(
                kind: .interactive,
                workflowProfile: .primary,
                surface: .application,
                prompt: "Keep this calm and local.",
                title: "Evidence caveat tag guard",
                riskLevel: .low
            ),
            currentBrain: evidenceGuardedBrain,
            projection: BASBrainProjection(records: [], candidates: [], recentEvents: [])
        )

        XCTAssertEqual(turn.budgetFrame.runMode, .guard)
    }

    func testWakeIntentPolicyCanChooseUrgencyCuePhrasesThatTriggerUrgentRunMode() throws {
        var tuning = makePolicyOwnedRuntimeTuning(
            schemaVersion: "host.runtime-synthesis.wake-intent-cues.v1"
        )
        tuning.stateTransitions.lowRiskUrgentMode = .guard
        tuning.stateTransitions.lowRiskDefaultMode = .sentinel
        tuning.stateTransitions.runModeRules = nil
        tuning.stateTransitions.runModeRules = tuning.stateTransitions.synthesizedRunModeRules(
            wakeIntent: tuning.wakeIntent
        )

        let runtime = BASHostRuntime(
            configuration: makeConfiguration(runtimeTuning: tuning)
        )

        let result = try runtime.startSession(
            BASHostSessionRequest(
                kind: .interactive,
                workflowProfile: .primary,
                surface: .application,
                prompt: "Need an urgent answer before the cutoff.",
                title: "Wake intent cue",
                riskLevel: .low
            )
        )

        let turn = try XCTUnwrap(result.eBrainTurn)
        XCTAssertEqual(turn.budgetFrame.runMode, .guard)
    }

    func testEvidenceCaveatLoadSurfacesInUnknownsRiskFactorsAndExplanationCodes() throws {
        let runtime = makeGenericRuntime()
        let seedResult = try runtime.startSession(
            BASHostSessionRequest(
                kind: .interactive,
                workflowProfile: .comparative,
                surface: .application,
                prompt: "Compare the safer paths before acting.",
                title: "Evidence caveat visibility",
                riskLevel: .medium
            )
        )
        var evidenceGuardedBrain = seedResult.currentBrain
        evidenceGuardedBrain.riskFlags.append(.evidenceCaveatLoad)
        evidenceGuardedBrain.retrievalTags.append("evidence_caveat")

        let turn = runtime.buildEBrainTurn(
            request: BASHostSessionRequest(
                kind: .interactive,
                workflowProfile: .comparative,
                surface: .application,
                prompt: "Compare the safer paths before acting.",
                title: "Evidence caveat visibility",
                riskLevel: .medium
            ),
            currentBrain: evidenceGuardedBrain,
            projection: BASBrainProjection(records: [], candidates: [], recentEvents: [])
        )

        XCTAssertTrue(
            turn.decomposeFrame.unknowns.contains(
                "Evidence remains caveated, so the turn should keep uncertainty explicit."
            )
        )
        XCTAssertTrue(turn.riskCard.factors.contains("evidence_caveat_load"))
        XCTAssertTrue(turn.actionPermit.reasonCodes.contains("evidence.caveat"))
        XCTAssertTrue(turn.renderedOutput.explanationCodes.contains("evidence.caveat"))
    }

    func testCustomRuntimeTuningGovernsLoopCandidateRetrievalAndPrecision() throws {
        var tuning = makePolicyOwnedRuntimeTuning(
            schemaVersion: "host.runtime-synthesis.loop-budget.v1"
        )
        tuning.guardrailPressure = .init(
            protectiveBoundaryIncrement: 0.18,
            calibrationWatchIncrement: 0.10,
            calibrationDriftingIncrement: 0.18,
            boundaryConstraintUnit: 0.03,
            boundaryConstraintCap: 0.18,
            calibrationAlertUnit: 0.03,
            calibrationAlertCap: 0.15,
            failureGuardUnit: 0.02,
            failureGuardCap: 0.12,
            riskFlagUnit: 0.035,
            riskFlagCap: 0.14,
            maximumPressure: 0.65
        )
        tuning.budget.standardDecodeTokens = 160
        tuning.budget.unstableDecodeTokens = 192
        tuning.budget.guardedDecodeTokens = 220
        tuning.budget.maintenanceBatteryFloor = 0.35
        tuning.budget.lowRiskLoops = 3
        tuning.budget.mediumRiskLoops = 4
        tuning.budget.highRiskLoops = 5
        tuning.budget.extremeRiskLoops = 2
        tuning.budget.lowRiskCandidates = 4
        tuning.budget.mediumRiskCandidates = 5
        tuning.budget.highRiskCandidates = 3
        tuning.budget.extremeRiskCandidates = 2
        tuning.budget.lowRiskRetrievalDepth = 1
        tuning.budget.mediumRiskRetrievalDepth = 2
        tuning.budget.guardedRetrievalDepth = 6
        tuning.budget.sentinelRetrievalDepth = 1
        tuning.budget.standardLoopFloor = 1
        tuning.budget.protectedLoopFloor = 2
        tuning.budget.standardCandidateFloor = 1
        tuning.budget.protectedCandidateFloor = 2
        tuning.budget.maxCandidateCount = 5
        tuning.budget.unstableLoopIncrement = 2
        tuning.budget.throttleLoopPenalty = 1
        tuning.budget.throttleCandidatePenalty = 1
        tuning.budget.defaultPrecisionProfile = .minimal
        tuning.budget.lowRiskPrecisionProfile = .minimal
        tuning.budget.unstablePrecisionProfile = .protected
        tuning.budget.guardedPrecisionProfile = .full
        tuning.budget.runModeProfilesByID = nil
        tuning.budget.runModeProfilesByID = tuning.budget.synthesizedRunModeProfilesByID(
            maintenance: tuning.maintenance
        )
        tuning.hostThresholds = .init(
            caution: 0.45,
            protective: 0.72,
            block: 0.92
        )
        let runtime = BASHostRuntime(
            configuration: makeConfiguration(runtimeTuning: tuning)
        )

        let result = try runtime.startSession(
            BASHostSessionRequest(
                kind: .interactive,
                workflowProfile: .primary,
                surface: .application,
                prompt: "Keep this lightweight and local.",
                title: "Loop budget",
                riskLevel: .low
            )
        )

        let turn = try XCTUnwrap(result.eBrainTurn)
        XCTAssertEqual(turn.budgetFrame.maxLoops, 3)
        XCTAssertEqual(turn.budgetFrame.maxCandidates, 4)
        XCTAssertEqual(turn.budgetFrame.retrievalDepth, 1)
        XCTAssertEqual(turn.budgetFrame.precisionProfile, .minimal)
    }

    func testCustomRuntimeTuningGovernsTransitionProfilesAndMaintenanceClass() throws {
        var tuning = makePolicyOwnedRuntimeTuning(
            schemaVersion: "host.runtime-synthesis.mode-profiles.v1"
        )
        tuning.guardrailPressure = .init(
            protectiveBoundaryIncrement: 0.18,
            calibrationWatchIncrement: 0.10,
            calibrationDriftingIncrement: 0.18,
            boundaryConstraintUnit: 0.03,
            boundaryConstraintCap: 0.18,
            calibrationAlertUnit: 0.03,
            calibrationAlertCap: 0.15,
            failureGuardUnit: 0.02,
            failureGuardCap: 0.12,
            riskFlagUnit: 0.035,
            riskFlagCap: 0.14,
            maximumPressure: 0.65
        )
        tuning.budget.standardDecodeTokens = 160
        tuning.budget.unstableDecodeTokens = 192
        tuning.budget.guardedDecodeTokens = 220
        tuning.budget.maintenanceBatteryFloor = 0.35
        tuning.budget.lowRiskLoops = 1
        tuning.budget.mediumRiskLoops = 2
        tuning.budget.highRiskLoops = 4
        tuning.budget.extremeRiskLoops = 2
        tuning.budget.lowRiskCandidates = 2
        tuning.budget.mediumRiskCandidates = 3
        tuning.budget.highRiskCandidates = 3
        tuning.budget.extremeRiskCandidates = 2
        tuning.budget.lowRiskRetrievalDepth = 1
        tuning.budget.mediumRiskRetrievalDepth = 2
        tuning.budget.guardedRetrievalDepth = 6
        tuning.budget.standardLoopFloor = 1
        tuning.budget.protectedLoopFloor = 2
        tuning.budget.standardCandidateFloor = 1
        tuning.budget.protectedCandidateFloor = 2
        tuning.budget.maxCandidateCount = 5
        tuning.budget.unstableLoopIncrement = 1
        tuning.budget.throttleLoopPenalty = 1
        tuning.budget.throttleCandidatePenalty = 1
        tuning.budget.defaultPrecisionProfile = .minimal
        tuning.budget.unstablePrecisionProfile = .protected
        tuning.budget.guardedPrecisionProfile = .full
        tuning.budget.lowRiskPrecisionProfile = .full
        tuning.budget.engageRetrievalDepth = 5
        tuning.stateTransitions = .init(
            backgroundPulseEnabled: true,
            recoveryOnCriticalThermal: true,
            reflectOnTrustDrift: true,
            deepLoopOnProtectedBoundary: true,
            lockdownOnExtremeBlockedPermit: true,
            quarantineFailureGuardThreshold: 2,
            lowRiskDefaultMode: .engage
        )
        tuning.maintenance = .init(
            lightBatteryFloor: 0.22,
            standardBatteryFloor: 0.30,
            allowedThermalLevels: [.nominal],
            blockedForegroundStates: [],
            lightweightAllowedClass: .light,
            lightweightDeferredClass: .deferred,
            activeRunModeClass: .standard,
            restrictedRunModeClass: .none
        )
        tuning.stateTransitions.runModeRules = tuning.stateTransitions.synthesizedRunModeRules(
            wakeIntent: tuning.wakeIntent
        )
        tuning.budget.runModeProfilesByID = nil
        tuning.budget.runModeProfilesByID = tuning.budget.synthesizedRunModeProfilesByID(
            maintenance: tuning.maintenance
        )
        tuning.hostThresholds = .init(
            caution: 0.45,
            protective: 0.72,
            block: 0.92
        )
        let runtime = BASHostRuntime(
            configuration: makeConfiguration(runtimeTuning: tuning)
        )

        let result = try runtime.startSession(
            BASHostSessionRequest(
                kind: .interactive,
                workflowProfile: .primary,
                surface: .application,
                prompt: "Keep this lightweight and local.",
                title: "Mode profile",
                riskLevel: .low
            )
        )

        let turn = try XCTUnwrap(result.eBrainTurn)
        XCTAssertEqual(turn.budgetFrame.runMode, .engage)
        XCTAssertEqual(turn.budgetFrame.retrievalDepth, 5)
        XCTAssertEqual(turn.budgetFrame.precisionProfile, .full)
        XCTAssertTrue(turn.budgetFrame.maintenanceAllowed)
    }


}
