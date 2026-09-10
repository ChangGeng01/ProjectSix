import XCTest
@testable import BASAdmin
@testable import BASHostKit

final class BASHostKitTests: XCTestCase {
    private enum ProjectionRefreshFailure: Error { case failed }

    private struct FixedVitalMonitor: BASVitalMonitorServicing {
        let deviceState: BASDeviceState

        func currentDeviceState(now: Date) -> BASDeviceState {
            deviceState
        }
    }

    func makeRuntimePolicyLineage(
        bundleVersion: String = "test.runtime-policy-bundle.v1",
        providerRoutingPolicyID: String = "test.provider-routing.v1",
        runtimeTuningPolicyID: String = "test.runtime-tuning.v1",
        resolutionSourceID: String = "test_bundle"
    ) -> BASRuntimePolicyLineage {
        BASRuntimePolicyLineage(
            bundleVersion: bundleVersion,
            providerRoutingRegistryVersion: "test.provider-routing-registry.v1",
            providerRoutingPolicyID: providerRoutingPolicyID,
            runtimeTuningRegistryVersion: "test.runtime-tuning-registry.v1",
            runtimeTuningPolicyID: runtimeTuningPolicyID,
            resolutionSourceID: resolutionSourceID
        )
    }

    func makePolicyOwnedRuntimeTuning(
        schemaVersion: String = "host.runtime-synthesis.policy-owned.v1"
    ) -> BASEBrainRuntimeSynthesisPolicy {
        var tuning = BASEBrainRuntimeSynthesisPolicy.generic.withSchemaVersion(schemaVersion)
        tuning.wakeIntent.highRiskGuardThreshold = 0.69
        tuning.stateTransitions.quarantineFailureGuardThreshold = 3
        tuning.stateTransitions.runModeRules = tuning.stateTransitions.synthesizedRunModeRules(
            wakeIntent: tuning.wakeIntent
        )
        tuning.lease.restrictedEnergyQuota = 0.46
        tuning.maintenance.standardBatteryFloor = 0.36
        tuning.sovereignExecution.deadStopOnExtremeBlockedPermit = false
        tuning.context.emotionalLoadDriftingIncrement = 0.09
        tuning.triSelf.directPathSuperegoPenalty = 0.46
        tuning.risk.defaultForecastUncertainty = 0.24
        return tuning
    }

    func makeGenericRuntime() -> BASHostRuntime {
        BASHostRuntime(configuration: makeConfiguration())
    }

    func makeConfiguration(
        runtimeProfileID: String = "host.default-runtime",
        policyProfileID: String = "host.default-policy",
        prefersPureLocal: Bool = true,
        defaultDeviceState: BASDeviceState = BASHostConfiguration.fixtureDefaultDeviceState,
        console: BASHostConsoleConfiguration = .generic,
        lifecycleBehavior: BASHostLifecycleBehaviorConfiguration = .generic,
        workflowBehavior: BASHostWorkflowBehaviorConfiguration = .generic,
        cognitionBehavior: BASHostCognitionBehaviorConfiguration = .generic,
        presentation: BASHostPresentationConfiguration = .generic,
        runtimeTuning: BASEBrainRuntimeSynthesisPolicy? = nil,
        runtimePolicyLineage: BASRuntimePolicyLineage? = nil,
        hostRhythmProfile: BASHostRhythmProfile = .generic,
        hostConstitution: BASHostConstitution? = nil,
        hostConstitutionVault: BASHostConstitutionVault? = nil,
        hostVersionTree: BASHostVersionTree? = nil,
        hostForgetRequest: BASForgetRequest? = nil
    ) -> BASHostConfiguration {
        BASHostConfiguration(
            runtimeProfileID: runtimeProfileID,
            policyProfileID: policyProfileID,
            prefersPureLocal: prefersPureLocal,
            defaultDeviceState: defaultDeviceState,
            console: console,
            lifecycleBehavior: lifecycleBehavior,
            workflowBehavior: workflowBehavior,
            cognitionBehavior: cognitionBehavior,
            presentation: presentation,
            runtimeTuning: runtimeTuning ?? makePolicyOwnedRuntimeTuning(
                schemaVersion: "host.runtime-synthesis.policy-owned.default.v1"
            ),
            runtimePolicyLineage: runtimePolicyLineage ?? makeRuntimePolicyLineage(),
            hostRhythmProfile: hostRhythmProfile,
            hostConstitution: hostConstitution,
            hostConstitutionVault: hostConstitutionVault,
            hostVersionTree: hostVersionTree,
            hostForgetRequest: hostForgetRequest
        )
    }

    func testStartSessionBuildsCurrentBrainAndConsoleSnapshot() throws {
        let runtime = makeGenericRuntime()

        let result = try runtime.startSession(
            BASHostSessionRequest(
                kind: .interactive,
                workflowProfile: .reflective,
                surface: .application,
                prompt: "I need to slow down before I send this message.",
                title: "Reflect on this decision",
                riskLevel: .medium
            )
        )

        XCTAssertEqual(result.requestKind, .interactive)
        XCTAssertEqual(result.workflowProfile, .reflective)
        XCTAssertEqual(result.currentBrain.workflowProfile, .reflective)
        XCTAssertEqual(result.currentBrain.workflowTitle, "Reflective")
        XCTAssertFalse(result.currentBrain.roleID.isEmpty)
        XCTAssertFalse(result.currentBrain.relationshipBoundary.isEmpty)
        XCTAssertFalse(result.currentBrain.boundaryHeadline.isEmpty)
        XCTAssertGreaterThan(result.currentBrain.confidenceCeiling, 0)
        XCTAssertFalse(result.currentBrain.dominantGoals.isEmpty)
        XCTAssertFalse(result.currentBrain.boundaryConstraints.isEmpty)
        XCTAssertTrue(
            result.currentBrain.retrievalTags.contains(where: { $0.hasPrefix("constitution:") })
        )
        XCTAssertTrue(result.currentBrain.verificationSummary.contains("constitution:"))
        XCTAssertFalse(result.consoleSnapshot.reports.isEmpty)
        XCTAssertEqual(result.consoleSnapshot.reports.count, BASLayerKind.allCases.count)
        XCTAssertNotNil(result.consoleSnapshot.programExecutionBlueprint)
        XCTAssertEqual(result.consoleSnapshot.currentProgramExecutionBlueprint.governedSchemas.count, BASEBrainSchemaGovernanceRegistry.governedSchemas.count)
        XCTAssertNotNil(result.consoleSnapshot.inspectionBundle)
        XCTAssertTrue(result.consoleSnapshot.runtimeSummary?.contains("permit") == true)
        XCTAssertTrue(result.consoleSnapshot.brainSummary?.contains("Host") == true)
        XCTAssertTrue(result.consoleSnapshot.runtimeSummary?.contains("dream") == true)
        XCTAssertNotNil(result.eBrainTurn)
        XCTAssertNotNil(result.eBrainTurn?.hostConstitution)
        XCTAssertEqual(result.eBrainTurn?.budgetFrame.runMode, .engage)
        XCTAssertEqual(result.eBrainTurn?.contextFrame.taskType, .chat)
        XCTAssertEqual(result.eBrainTurn?.updateTickets.count, 1)
        XCTAssertFalse(result.eBrainTurn?.thoughtFold.checksum.isEmpty ?? true)
        XCTAssertEqual(result.eBrainTurn?.thoughtFold.compactSlots["task_type"], BASContextTaskType.chat.rawValue)
        XCTAssertEqual(result.eBrainTurn?.thoughtFold.compactSlots["constitution_version"], result.eBrainTurn?.hostConstitution?.activeVersion)
        XCTAssertEqual(result.eBrainTurn?.runtimeTrace.modelRoute, BASDeviceRoute.coreNPU.rawValue)
        XCTAssertGreaterThan(result.eBrainTurn?.runtimeTrace.loopCount ?? 0, 0)
        XCTAssertTrue(result.eBrainTurn?.runtimeTrace.layerEvents.contains(where: { $0.layerID == "L3" }) ?? false)
        XCTAssertTrue(result.eBrainTurn?.runtimeTrace.layerEvents.contains(where: {
            $0.layerID == "L5" && $0.detail.contains("constitution")
        }) ?? false)
        XCTAssertEqual(result.eBrainTurn?.evolutionLineageSummary.sessionID, result.eBrainTurn?.runtimeTrace.sessionID)
        XCTAssertEqual(result.eBrainTurn?.evolutionLineageSummary.permitMode, result.eBrainTurn?.actionPermit.mode.rawValue)
        XCTAssertEqual(result.eBrainTurn?.evolutionLineageSummary.riskLevel, result.eBrainTurn?.riskCard.riskLevel.rawValue)
        XCTAssertEqual(
            result.eBrainTurn?.evolutionLineageSummary.projectionLeadCandidateID,
            result.eBrainTurn?.thoughtFrame.candidates.first?.candidateID
        )
        XCTAssertEqual(
            result.eBrainTurn?.evolutionLineageSummary.projectionCandidateCount,
            result.eBrainTurn?.thoughtFrame.candidates.count
        )
        XCTAssertEqual(
            result.eBrainTurn?.evolutionLineageSummary.projectionForecastCount,
            result.eBrainTurn?.thoughtFrame.forecasts.count
        )
        XCTAssertEqual(
            result.eBrainTurn?.evolutionLineageSummary.projectionCritiqueCount,
            result.eBrainTurn?.thoughtFrame.critiques.count
        )
        XCTAssertTrue(
            result.consoleSnapshot.blockerSummary.allSatisfy {
                !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
        )
        XCTAssertTrue(result.consoleSnapshot.inspectionBundle?.trace.auditEvents.contains(where: {
            $0.category == "L5" && $0.message.contains("constitution")
        }) ?? false)
        XCTAssertNotNil(result.interventionSuggestion)
    }

    func testEvolutionLineageSummaryMirrorsSafetyReceiptsForQuarantineAndDeadStop() throws {
        let runtime = makeGenericRuntime()
        let baseTurn = try XCTUnwrap(
            runtime.startSession(
                BASHostSessionRequest(
                    kind: .interactive,
                    workflowProfile: .reflective,
                    surface: .application,
                    prompt: "Pause and keep me from doing something reckless.",
                    riskLevel: .high
                )
            ).eBrainTurn
        )

        var turn = baseTurn
        turn.sovereignActuationCommands = [
            BASSovereignActuationCommand(
                commandID: "memory-freeze-1",
                kind: .memoryFreeze,
                reasonCodes: ["runtime.write_freeze"],
                issuedAt: Date(timeIntervalSince1970: 1_776_000_010)
            ),
            BASSovereignActuationCommand(
                commandID: "quarantine-1",
                kind: .quarantine,
                reasonCodes: ["runtime.quarantine"],
                issuedAt: Date(timeIntervalSince1970: 1_776_000_011)
            ),
            BASSovereignActuationCommand(
                commandID: "dead-stop-1",
                kind: .deadStop,
                reasonCodes: ["runtime.dead_stop"],
                issuedAt: Date(timeIntervalSince1970: 1_776_000_012)
            )
        ]

        let foldedLung = try XCTUnwrap(turn.evolutionLineageSummary.foldedLungSummary)
        let expectedResumeID = foldedLung.resumeID
        let expectedPrecisionProfileID = try XCTUnwrap(foldedLung.precisionProfileID)
        let expectedCacheRef = "cache.\(turn.runtimeTrace.sessionID).\(expectedPrecisionProfileID)"

        XCTAssertEqual(foldedLung.sovereignActuationKinds, [.memoryFreeze, .quarantine, .deadStop])
        XCTAssertEqual(foldedLung.invalidatedResumeFrameIDs, [expectedResumeID])
        XCTAssertEqual(
            foldedLung.invalidatedCacheRefs,
            [expectedCacheRef, "memory-write:\(turn.runtimeTrace.sessionID)"]
        )
        XCTAssertEqual(foldedLung.invalidatedFoldRefs, [turn.thoughtFold.foldID])
        XCTAssertEqual(foldedLung.quarantinedFoldRefs, [turn.thoughtFold.foldID])
        XCTAssertEqual(foldedLung.resultingBreathMode, "lockdown")
        XCTAssertEqual(foldedLung.preservedReadOnlyRecovery, true)
        XCTAssertTrue(foldedLung.sovereignBridgeSummary?.contains("readonly recovery") == true)
        XCTAssertTrue(foldedLung.sovereignBridgeSummary?.contains("fold \(turn.thoughtFold.foldID)") == true)
    }

    func testLowRiskTurnProducesGovernedExperienceCandidateWithoutPendingShadowTrial() throws {
        let runtime = makeGenericRuntime()

        let turn = try XCTUnwrap(
            runtime.startSession(
                BASHostSessionRequest(
                    kind: .interactive,
                    workflowProfile: .primary,
                    surface: .application,
                    prompt: "Help me write a calm reply tomorrow morning.",
                    riskLevel: .low
                )
            ).eBrainTurn
        )

        XCTAssertEqual(turn.experienceCandidates.count, 1)
        XCTAssertFalse(turn.workflowCandidates.isEmpty)
        XCTAssertFalse(turn.guardTemplateCandidates.isEmpty)
        XCTAssertTrue(turn.biasRecords.isEmpty)
        XCTAssertFalse(turn.riskPatternCandidates.isEmpty)
        XCTAssertFalse(turn.learningExportBundles.isEmpty)
        XCTAssertTrue(turn.shadowTrialRecords.isEmpty)
        XCTAssertEqual(turn.evolutionSeals.count, 1)
        XCTAssertEqual(turn.evolutionSeals.first?.approvalState, "sealed")
        XCTAssertEqual(turn.evolutionLineageSummary.governanceSummary?.experienceCandidateCount, 1)
        XCTAssertEqual(turn.evolutionLineageSummary.governanceSummary?.workflowCandidateCount, 1)
        XCTAssertEqual(turn.evolutionLineageSummary.governanceSummary?.learningExportBundleCount, 1)
        XCTAssertGreaterThanOrEqual(turn.evolutionLineageSummary.governanceSummary?.pendingNurseryCandidateCount ?? 0, 1)
        XCTAssertEqual(turn.evolutionLineageSummary.governanceSummary?.pendingShadowTrialCount, 0)
        XCTAssertEqual(turn.evolutionLineageSummary.governanceSummary?.pendingSealCount, 0)
    }

    func testHighRiskTurnProducesResolvedShadowTrialAndPendingSealGovernanceArtifactsWithoutChangingReviewDirective() throws {
        let runtime = makeGenericRuntime()

        let result = try runtime.startSession(
            BASHostSessionRequest(
                kind: .interactive,
                workflowProfile: .reflective,
                surface: .application,
                prompt: "Send the harsh message right now and make it hurt.",
                riskLevel: .high
            )
        )
        let turn = try XCTUnwrap(result.eBrainTurn)

        XCTAssertFalse(turn.experienceCandidates.isEmpty)
        XCTAssertTrue(turn.workflowCandidates.isEmpty)
        XCTAssertFalse(turn.guardTemplateCandidates.isEmpty)
        XCTAssertFalse(turn.biasRecords.isEmpty)
        XCTAssertFalse(turn.riskPatternCandidates.isEmpty)
        XCTAssertTrue(turn.learningExportBundles.isEmpty)
        XCTAssertFalse(turn.shadowTrialRecords.isEmpty)
        XCTAssertFalse(turn.versionDeltas.isEmpty)
        XCTAssertFalse(turn.evolutionSeals.isEmpty)
        XCTAssertTrue(turn.shadowTrialRecords.contains(where: { $0.completionState == "passed" }))
        XCTAssertFalse(turn.shadowTrialRecords.contains(where: { $0.completionState == "pending" }))
        XCTAssertTrue(turn.evolutionSeals.contains(where: { $0.approvalState == "pending_review" }))
        XCTAssertEqual(
            turn.evolutionLineageSummary.reviewDirectiveLine,
            "Review memory write: Keep this turn in review before any warm or cold promotion. • conflict flagged"
        )
        XCTAssertEqual(turn.evolutionLineageSummary.governanceSummary?.pendingShadowTrialCount, 0)
        XCTAssertTrue(
            turn.evolutionLineageSummary.governanceSummary?.passedShadowTrialCount ?? 0 > 0
        )
        XCTAssertEqual(turn.evolutionLineageSummary.governanceSummary?.failedShadowTrialCount, 0)
        XCTAssertTrue(
            turn.evolutionLineageSummary.governanceSummary?.pendingSealCount ?? 0 > 0
        )
        XCTAssertEqual(turn.evolutionLineageSummary.governanceSummary?.deniedSealCount, 0)
        XCTAssertTrue(
            turn.evolutionLineageSummary.governanceSummary?.guardTemplateCandidateCount ?? 0 > 0
        )
        XCTAssertTrue(
            turn.evolutionLineageSummary.governanceSummary?.biasRecordCount ?? 0 > 0
        )
        XCTAssertTrue(
            turn.evolutionLineageSummary.governanceSummary?.riskPatternCandidateCount ?? 0 > 0
        )
        XCTAssertTrue(
            turn.evolutionLineageSummary.governanceSummary?.pendingNurseryCandidateCount ?? 0 > 0
        )
        XCTAssertFalse(
            turn.evolutionLineageSummary.governanceSummary?.blockedPromotionReasonCodes.contains(
                "evolution.shadow_trial_pending"
            ) ?? true
        )
        XCTAssertTrue(
            turn.evolutionLineageSummary.governanceSummary?.blockedPromotionReasonCodes.contains(
                "evolution.seal_pending"
            ) ?? false
        )
        XCTAssertTrue(result.consoleSnapshot.brainSummary?.contains("shadow ready 1/1") == true)
        XCTAssertTrue(result.consoleSnapshot.brainSummary?.contains("seal 1 pending/1") == true)
        XCTAssertTrue(result.consoleSnapshot.brainSummary?.contains("retract cleared 1") == true)
        XCTAssertTrue(
            result.consoleSnapshot.reports.first(where: { $0.kind == .data })?.summary.contains(
                "shadow ready 1/1"
            ) == true
        )
        XCTAssertTrue(
            result.consoleSnapshot.reports.first(where: { $0.kind == .evaluation })?.summary.contains(
                "seal 1 pending/1"
            ) == true
        )
    }

    func testEvolutionLineageSummaryThrottlePreservesGuardWhenCurrentTurnIsAlreadyGuarded() throws {
        let runtime = makeGenericRuntime()
        let baseTurn = try XCTUnwrap(
            runtime.startSession(
                BASHostSessionRequest(
                    kind: .interactive,
                    workflowProfile: .reflective,
                    surface: .application,
                    prompt: "Compare a few possible replies before we decide.",
                    riskLevel: .medium
                )
            ).eBrainTurn
        )

        var turn = baseTurn
        turn.budgetFrame.runMode = .deepLoop
        turn.sovereignActuationCommands = [
            BASSovereignActuationCommand(
                commandID: "throttle-1",
                kind: .throttle,
                reasonCodes: ["thermal.throttle"],
                issuedAt: Date(timeIntervalSince1970: 1_776_000_020)
            )
        ]

        let foldedLung = try XCTUnwrap(turn.evolutionLineageSummary.foldedLungSummary)

        XCTAssertEqual(foldedLung.breathMode, "guard")
        XCTAssertEqual(foldedLung.resultingBreathMode, "guard")
        XCTAssertEqual(foldedLung.invalidatedResumeFrameIDs, [])
        XCTAssertEqual(foldedLung.invalidatedCacheRefs, [])
        XCTAssertEqual(foldedLung.invalidatedFoldRefs, [])
        XCTAssertEqual(foldedLung.quarantinedFoldRefs, [])
        XCTAssertEqual(foldedLung.preservedReadOnlyRecovery, false)
        XCTAssertTrue(foldedLung.sovereignBridgeSummary?.contains("mode guard") == true)
    }

    func testCustomRuntimeTuningGovernsBudgetAndHostThresholds() throws {
        var tuning = makePolicyOwnedRuntimeTuning(
            schemaVersion: "host.runtime-synthesis.test.v1"
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
        var sentinelProfile = try XCTUnwrap(
            tuning.budget.runModeProfilesByID?[BASEBrainRunMode.sentinel.rawValue]
        )
        sentinelProfile.defaultDecodeTokens = 144
        sentinelProfile.unstableDecodeTokens = 176
        tuning.budget.runModeProfilesByID?[BASEBrainRunMode.sentinel.rawValue] = sentinelProfile
        tuning.hostThresholds = .init(
            caution: 0.33,
            protective: 0.61,
            block: 0.81
        )
        let configuration = makeConfiguration(runtimeTuning: tuning)
        XCTAssertFalse(
            tuning.usesCompiledFallbackEnvelope,
            "unexpected fallback components: \(tuning.compiledFallbackComponentIDs)"
        )
        XCTAssertTrue(
            configuration.controlPlaneIssues.isEmpty,
            "unexpected control-plane issues: \(configuration.controlPlaneIssues)"
        )

        let runtime = BASHostRuntime(
            configuration: configuration
        )

        let result = try runtime.startSession(
            BASHostSessionRequest(
                kind: .interactive,
                workflowProfile: .primary,
                surface: .application,
                prompt: "Keep this answer short and local.",
                title: "Primary decision",
                riskLevel: .low
            )
        )

        XCTAssertEqual(result.eBrainTurn?.budgetFrame.maxDecodeTokens, 144)
        XCTAssertEqual(
            result.eBrainTurn?.hostContext.riskThresholds,
            BASHostRiskThresholds(
                caution: 0.33,
                protective: 0.61,
                block: 0.81
            )
        )
    }


    // chapter 二百九十六 / M783 — Host constitution test cluster
    // (10 tests, testHostConstitutionProjectsIntoRuntimeHostContext
    // through testExplicitConstitutionShapesEvolutionHostChangeCandidate)
    // extracted to `BASHostKitConstitutionTests.swift`. Phase
    // Alpha 22nd cut. 0 behavior change.



    // chapter 二百九十七 / M784 — Runtime tuning + decoding test
    // cluster (17 tests, runtime-tuning-source / host-config
    // policy-lineage / decoding-rejection) extracted to
    // `BASHostKitRuntimeTuningTests.swift`. Phase Alpha 23rd
    // cut. 0 behavior change.


    func testCustomRuntimeTuningGovernsContextTriSelfAndRiskBiases() throws {
        let request = BASHostSessionRequest(
            kind: .interactive,
            workflowProfile: .primary,
            surface: .application,
            prompt: "Send the direct answer right now.",
            riskLevel: .medium
        )
        let cognition = BASHostCognitionBehaviorConfiguration(
            substrateBehavior: BASCognitionBehavior(
                highRiskIdentityOverlay: BASIdentityProfileOverlay(
                    posture: .protective,
                    initiative: .guided,
                    confidenceCeiling: 0.52,
                    relationshipBoundary: "Protect the boundary under high pressure."
                )
            )
        )

        let baselineTurn = try XCTUnwrap(
            BASHostRuntime(
                configuration: makeConfiguration(cognitionBehavior: cognition)
            ).startSession(request).eBrainTurn
        )

        var tuned = makePolicyOwnedRuntimeTuning(
            schemaVersion: "host.runtime-synthesis.behavioral-biases.v1"
        )
        tuned.guardrailPressure = .init(
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
        tuned.budget.standardDecodeTokens = 160
        tuned.budget.unstableDecodeTokens = 192
        tuned.budget.guardedDecodeTokens = 220
        tuned.budget.maintenanceBatteryFloor = 0.35
        tuned.hostThresholds = .init(
            caution: 0.45,
            protective: 0.72,
            block: 0.92
        )
        tuned.context = .init(
            trustInstabilityIncrement: 0.28,
            guardedPressureIncrement: 0.24,
            emotionalLoadHighRisk: 0.95,
            emotionalLoadReflective: 0.50,
            emotionalLoadDefault: 0.34,
            emotionalLoadDriftingIncrement: 0.16,
            timePressureReopen: 0.74,
            timePressureUrgent: 0.94,
            timePressureDefault: 0.30,
            ambiguityComparative: 0.52,
            ambiguityDefault: 0.36,
            consequenceHigh: 0.97,
            consequenceMedium: 0.68,
            consequenceLow: 0.32
        )
        tuned.triSelf = .init(
            assertiveInitiativeLift: 0.18,
            idCostWeight: 0.12,
            egoReversibilityWeight: 0.25,
            egoConfidenceWeight: 0.75,
            directPathSuperegoPenalty: 0.08,
            reflectiveWeights: .init(id: 0.32, ego: 0.30, superego: 0.38),
            coachingWeights: .init(id: 0.38, ego: 0.34, superego: 0.28),
            protectiveWeights: .init(id: 0.34, ego: 0.30, superego: 0.36)
        )
        tuned.risk = .init(
            directCandidateLowReversibilityThreshold: 0.65,
            directCandidatePenalty: 0.24,
            vetoPressureIncrement: 0.18,
            emotionalLoadWeight: 0.28,
            timePressureWeight: 0.22,
            consequenceWeight: 0.34,
            manipulationHintWeight: 0.12,
            critiqueSeverityWeight: 0.26,
            mediumThreshold: 0.28,
            highThreshold: 0.46,
            extremeThreshold: 0.72,
            defaultForecastUncertainty: 0.30,
            defaultCandidateReversibility: 0.45,
            manipulationStrengthUnit: 0.42,
            gsiHintWeight: 0.38,
            gsiTimePressureThreshold: 0.45,
            gsiTimePressureIncrement: 0.20,
            gsiTrustDriftIncrement: 0.26,
            gsiLowTrustAlertIncrement: 0.16
        )

        let tunedTurn = try XCTUnwrap(
            BASHostRuntime(
                configuration: makeConfiguration(
                    cognitionBehavior: cognition,
                    runtimeTuning: tuned
                )
            ).startSession(request).eBrainTurn
        )

        XCTAssertGreaterThan(tunedTurn.contextFrame.emotionalLoad, baselineTurn.contextFrame.emotionalLoad)
        XCTAssertGreaterThan(tunedTurn.contextFrame.timePressure, baselineTurn.contextFrame.timePressure)
        XCTAssertGreaterThan(tunedTurn.contextFrame.consequenceLevel, baselineTurn.contextFrame.consequenceLevel)

        let baselineDirect = try XCTUnwrap(
            baselineTurn.triScores.first(where: { $0.candidateID == "path.direct" })
        )
        let tunedDirect = try XCTUnwrap(
            tunedTurn.triScores.first(where: { $0.candidateID == "path.direct" })
        )

        XCTAssertGreaterThan(tunedDirect.mergedScore, baselineDirect.mergedScore)
        XCTAssertGreaterThan(tunedTurn.riskCard.totalRisk, baselineTurn.riskCard.totalRisk)
        XCTAssertGreaterThan(
            tunedTurn.riskCard.totalRisk,
            tuned.risk.highThreshold,
            "Expected tuned risk to cross the high threshold; totalRisk=\(tunedTurn.riskCard.totalRisk), highThreshold=\(tuned.risk.highThreshold), level=\(tunedTurn.riskCard.riskLevel.rawValue)"
        )
        XCTAssertEqual(
            [.high, .extreme].contains(tunedTurn.riskCard.riskLevel),
            true,
            "Expected tuned risk level to resolve at least high; totalRisk=\(tunedTurn.riskCard.totalRisk), gsiScore=\(tunedTurn.riskCard.gsiScore), highThreshold=\(tuned.risk.highThreshold), extremeThreshold=\(tuned.risk.extremeThreshold)"
        )
    }


    // chapter 二百九十八 / M785 — Run mode lane test cluster
    // (18 tests, recovery / quarantine / healthy / sovereign
    // warrant / evidence caveat / state transition / wake
    // intent / runtime tuning) extracted to
    // `BASHostKitRunModeLaneTests.swift`. Phase Alpha 24th cut
    // (FINAL — BASHostKitTests god file CLOSED). 0 behavior
    // change.

    func testMaintenanceThermalAllowanceIsPolicyDriven() throws {
        var tuning = makePolicyOwnedRuntimeTuning(
            schemaVersion: "host.runtime-synthesis.maintenance-thermal.v1"
        )
        tuning.stateTransitions.lowRiskDefaultMode = .engage
        tuning.stateTransitions.runModeRules = nil
        tuning.stateTransitions.runModeRules = tuning.stateTransitions.synthesizedRunModeRules(
            wakeIntent: tuning.wakeIntent
        )
        tuning.maintenance.allowedThermalLevels = [.nominal, .warm]
        tuning.maintenance.blockedForegroundStates = []
        tuning.budget.runModeProfilesByID = nil
        tuning.budget.runModeProfilesByID = tuning.budget.synthesizedRunModeProfilesByID(
            maintenance: tuning.maintenance
        )

        let runtime = BASHostRuntime(
            configuration: makeConfiguration(runtimeTuning: tuning)
        )

        let result = try runtime.startSession(
            BASHostSessionRequest(
                kind: .interactive,
                workflowProfile: .primary,
                surface: .application,
                prompt: "Keep maintenance available even when the system is warm.",
                title: "Maintenance thermal policy",
                riskLevel: .low
            ),
            now: Date(timeIntervalSince1970: 1_744_321_300)
        )

        var currentBrain = result.currentBrain
        currentBrain.boundaryMode = .localOnlyAdvisory
        currentBrain.calibrationStatus = .stable

        let turn = runtime.buildEBrainTurn(
            request: BASHostSessionRequest(
                kind: .interactive,
                workflowProfile: .primary,
                surface: .application,
                prompt: "Keep maintenance available even when the system is warm.",
                title: "Maintenance thermal policy",
                riskLevel: .low
            ),
            currentBrain: currentBrain,
            projection: BASBrainProjection(records: [], candidates: [], recentEvents: []),
            deviceStateOverride: BASDeviceState(
                batteryLevel: 0.71,
                thermalLevel: .warm,
                memoryFreeMB: 2_048,
                networkState: .online,
                foregroundState: .background,
                cpuLoad: 0.18,
                gpuLoad: 0.10,
                npuAvailable: true,
                latencyBudgetMs: 1_000
            )
        )

        XCTAssertTrue(turn.budgetFrame.maintenanceAllowed)
        XCTAssertEqual(turn.budgetFrame.maintenanceClass, .light)
    }

    func testMaintenanceForegroundBlocksArePolicyDriven() throws {
        var tuning = makePolicyOwnedRuntimeTuning(
            schemaVersion: "host.runtime-synthesis.maintenance-foreground.v1"
        )
        tuning.stateTransitions.lowRiskDefaultMode = .engage
        tuning.stateTransitions.runModeRules = tuning.stateTransitions.synthesizedRunModeRules(
            wakeIntent: tuning.wakeIntent
        )
        tuning.maintenance.allowedThermalLevels = [.nominal]
        tuning.maintenance.blockedForegroundStates = [.background]
        tuning.budget.runModeProfilesByID = tuning.budget.synthesizedRunModeProfilesByID(
            maintenance: tuning.maintenance
        )

        let runtime = BASHostRuntime(
            configuration: makeConfiguration(runtimeTuning: tuning)
        )

        let result = try runtime.startSession(
            BASHostSessionRequest(
                kind: .interactive,
                workflowProfile: .primary,
                surface: .application,
                prompt: "Block maintenance for background turns when the policy says so.",
                title: "Maintenance foreground policy",
                riskLevel: .low
            ),
            now: Date(timeIntervalSince1970: 1_744_321_300)
        )

        let turn = runtime.buildEBrainTurn(
            request: BASHostSessionRequest(
                kind: .interactive,
                workflowProfile: .primary,
                surface: .application,
                prompt: "Block maintenance for background turns when the policy says so.",
                title: "Maintenance foreground policy",
                riskLevel: .low
            ),
            currentBrain: result.currentBrain,
            projection: BASBrainProjection(records: [], candidates: [], recentEvents: []),
            deviceStateOverride: BASDeviceState(
                batteryLevel: 0.71,
                thermalLevel: .nominal,
                memoryFreeMB: 2_048,
                networkState: .online,
                foregroundState: .background,
                cpuLoad: 0.18,
                gpuLoad: 0.10,
                npuAvailable: true,
                latencyBudgetMs: 1_000
            )
        )

        XCTAssertFalse(turn.budgetFrame.maintenanceAllowed)
        XCTAssertEqual(turn.budgetFrame.maintenanceClass, .deferred)
    }

    func testConfigurationDefaultDeviceStateFeedsTurnWhenNoOverrideSupplied() throws {
        let defaultDeviceState = BASDeviceState(
            batteryLevel: 0.41,
            thermalLevel: .warm,
            memoryFreeMB: 1_536,
            networkState: .online,
            foregroundState: .background,
            cpuLoad: 0.29,
            gpuLoad: 0.21,
            npuAvailable: false,
            latencyBudgetMs: 1_900
        )
        let runtime = BASHostRuntime(
            configuration: makeConfiguration(defaultDeviceState: defaultDeviceState)
        )

        let result = try runtime.startSession(
            BASHostSessionRequest(
                kind: .interactive,
                workflowProfile: .reflective,
                surface: .application,
                prompt: "Use the configured vitals.",
                title: "Device vitals",
                riskLevel: .low
            )
        )

        XCTAssertEqual(result.eBrainTurn?.deviceState, defaultDeviceState)
    }

    func testExplicitRunModeBudgetProfilesOverrideLegacyRiskBuckets() throws {
        var tuning = makePolicyOwnedRuntimeTuning(
            schemaVersion: "host.runtime-synthesis.run-mode-profiles.v1"
        )
        tuning.stateTransitions.lowRiskDefaultMode = .engage
        tuning.stateTransitions.runModeRules = nil
        tuning.stateTransitions.runModeRules = tuning.stateTransitions.synthesizedRunModeRules(
            wakeIntent: tuning.wakeIntent
        )
        tuning.budget.maxCandidateCount = 6
        tuning.maintenance.blockedForegroundStates = []
        tuning.budget.runModeProfilesByID = Dictionary(
            uniqueKeysWithValues: BASEBrainRunMode.allCases.map { runMode in
                let profile = BASEBrainRuntimeSynthesisPolicy.BudgetTuning.RunModeBudgetProfile(
                    maxLoops: 1,
                    maxCandidates: 1,
                    retrievalDepth: 1,
                    defaultDecodeTokens: 96,
                    unstableDecodeTokens: 64,
                    precisionProfile: .minimal,
                    defaultDeviceRoute: .coreNPU,
                    npuUnavailableDeviceRoute: .coreGPU,
                    candidateCountCap: 1,
                    standardLoopFloor: 1,
                    protectedLoopFloor: 2,
                    standardCandidateFloor: 1,
                    protectedCandidateFloor: 2,
                    unstableLoopIncrement: 1,
                    unstableLoopIncrementRiskLevels: [],
                    throttleLoopPenalty: 1,
                    throttleCandidatePenalty: 1,
                    throttlePenaltyThermalLevels: [],
                    maintenanceSupported: false,
                    maintenanceBatteryFloor: 0.95,
                    scheduledMaintenanceClass: BASMaintenanceClass.none,
                    deferredMaintenanceClass: BASMaintenanceClass.none
                )
                return (runMode.rawValue, profile)
            }
        )
        tuning.budget.runModeProfilesByID?[BASEBrainRunMode.engage.rawValue] = .init(
            maxLoops: 6,
            maxCandidates: 5,
            retrievalDepth: 7,
            defaultDecodeTokens: 777,
            unstableDecodeTokens: 555,
            precisionProfile: .full,
            defaultDeviceRoute: .scoutGPU,
            npuUnavailableDeviceRoute: .hybridLocal,
            candidateCountCap: 5,
            standardLoopFloor: 1,
            protectedLoopFloor: 3,
            standardCandidateFloor: 1,
            protectedCandidateFloor: 3,
            unstableLoopIncrement: 2,
            unstableLoopIncrementRiskLevels: [],
            throttleLoopPenalty: 1,
            throttleCandidatePenalty: 1,
            throttlePenaltyThermalLevels: [],
            maintenanceSupported: true,
            maintenanceBatteryFloor: 0.20,
            scheduledMaintenanceClass: .light,
            deferredMaintenanceClass: .deferred
        )

        let runtime = BASHostRuntime(
            configuration: makeConfiguration(runtimeTuning: tuning)
        )

        let result = try runtime.startSession(
            BASHostSessionRequest(
                kind: .interactive,
                workflowProfile: .primary,
                surface: .application,
                prompt: "Stay with the explicit engage profile.",
                title: "Run-mode profile",
                riskLevel: .low
            )
        )

        let turn = try XCTUnwrap(result.eBrainTurn)
        XCTAssertEqual(turn.budgetFrame.runMode, .engage)
        XCTAssertEqual(turn.budgetFrame.maxLoops, 6)
        XCTAssertEqual(turn.budgetFrame.maxCandidates, 5)
        XCTAssertEqual(turn.budgetFrame.retrievalDepth, 7)
        XCTAssertEqual(turn.budgetFrame.maxDecodeTokens, 777)
        XCTAssertEqual(turn.budgetFrame.precisionProfile, .full)
        XCTAssertEqual(turn.budgetFrame.deviceRoute, .scoutGPU)
        XCTAssertEqual(turn.budgetFrame.maintenanceClass, .light)
    }

    func testExplicitRunModeBudgetProfilesOverrideFloorsCapsAndThrottlePenalties() throws {
        var tuning = makePolicyOwnedRuntimeTuning(
            schemaVersion: "host.runtime-synthesis.run-mode-profile-planner.v1"
        )
        tuning.stateTransitions.lowRiskProtectedMode = .engage
        tuning.stateTransitions.runModeRules = nil
        tuning.stateTransitions.runModeRules = tuning.stateTransitions.synthesizedRunModeRules(
            wakeIntent: tuning.wakeIntent
        )
        tuning.maintenance.blockedForegroundStates = []
        tuning.budget.runModeProfilesByID = Dictionary(
            uniqueKeysWithValues: BASEBrainRunMode.allCases.map { runMode in
                let profile = BASEBrainRuntimeSynthesisPolicy.BudgetTuning.RunModeBudgetProfile(
                    maxLoops: 1,
                    maxCandidates: 1,
                    retrievalDepth: 1,
                    defaultDecodeTokens: 96,
                    unstableDecodeTokens: 64,
                    precisionProfile: .minimal,
                    defaultDeviceRoute: .coreNPU,
                    npuUnavailableDeviceRoute: .coreGPU,
                    candidateCountCap: 1,
                    standardLoopFloor: 1,
                    protectedLoopFloor: 1,
                    standardCandidateFloor: 1,
                    protectedCandidateFloor: 1,
                    unstableLoopIncrement: 0,
                    unstableLoopIncrementRiskLevels: [],
                    throttleLoopPenalty: 0,
                    throttleCandidatePenalty: 0,
                    throttlePenaltyThermalLevels: [],
                    maintenanceSupported: false,
                    maintenanceBatteryFloor: 0.95,
                    scheduledMaintenanceClass: BASMaintenanceClass.none,
                    deferredMaintenanceClass: BASMaintenanceClass.none
                )
                return (runMode.rawValue, profile)
            }
        )
        tuning.budget.runModeProfilesByID?[BASEBrainRunMode.engage.rawValue] = .init(
            maxLoops: 3,
            maxCandidates: 6,
            retrievalDepth: 4,
            defaultDecodeTokens: 320,
            unstableDecodeTokens: 288,
            precisionProfile: .balanced,
            defaultDeviceRoute: .coreNPU,
            npuUnavailableDeviceRoute: .coreGPU,
            candidateCountCap: 4,
            standardLoopFloor: 2,
            protectedLoopFloor: 5,
            standardCandidateFloor: 2,
            protectedCandidateFloor: 5,
            unstableLoopIncrement: 3,
            unstableLoopIncrementRiskLevels: [],
            throttleLoopPenalty: 2,
            throttleCandidatePenalty: 1,
            throttlePenaltyThermalLevels: [],
            maintenanceSupported: true,
            maintenanceBatteryFloor: 0.20,
            scheduledMaintenanceClass: .standard,
            deferredMaintenanceClass: .deferred
        )

        let runtime = BASHostRuntime(
            configuration: makeConfiguration(runtimeTuning: tuning)
        )

        let request = BASHostSessionRequest(
            kind: .interactive,
            workflowProfile: .primary,
            surface: .application,
            prompt: "Keep this protected and adaptive.",
            title: "Planner profile",
            riskLevel: .low
        )
        let result = try runtime.startSession(request)
        var protectedBrain = result.currentBrain
        protectedBrain.boundaryMode = .localOnlyProtective
        protectedBrain.calibrationStatus = .watch

        let turn = runtime.buildEBrainTurn(
            request: request,
            currentBrain: protectedBrain,
            projection: BASBrainProjection(records: [], candidates: [], recentEvents: []),
            deviceStateOverride: BASDeviceState(
                batteryLevel: 0.71,
                thermalLevel: .hot,
                memoryFreeMB: 2_048,
                networkState: .online,
                foregroundState: .foreground,
                cpuLoad: 0.22,
                gpuLoad: 0.14,
                npuAvailable: true,
                latencyBudgetMs: 1_200
            )
        )

        XCTAssertEqual(turn.budgetFrame.runMode, .engage)
        XCTAssertEqual(turn.budgetFrame.maxLoops, 5)
        XCTAssertEqual(turn.budgetFrame.maxCandidates, 4)
    }

    func testBudgetPolicyCanChooseCalibrationStatusesThatTriggerProtectedFloors() throws {
        var tuning = makePolicyOwnedRuntimeTuning(
            schemaVersion: "host.runtime-synthesis.protected-floor-statuses.v1"
        )
        tuning.stateTransitions.backgroundPulseEnabled = false
        tuning.stateTransitions.lowRiskDefaultMode = .engage
        tuning.stateTransitions.runModeRules = nil
        tuning.stateTransitions.runModeRules = tuning.stateTransitions.synthesizedRunModeRules(
            wakeIntent: tuning.wakeIntent
        )
        tuning.maintenance.blockedForegroundStates = []
        tuning.budget.protectedFloorBoundaryModes = []
        tuning.budget.protectedFloorCalibrationStatuses = [.watch]
        tuning.budget.runModeProfilesByID = Dictionary(
            uniqueKeysWithValues: BASEBrainRunMode.allCases.map { runMode in
                let profile = BASEBrainRuntimeSynthesisPolicy.BudgetTuning.RunModeBudgetProfile(
                    maxLoops: 1,
                    maxCandidates: 1,
                    retrievalDepth: 1,
                    defaultDecodeTokens: 96,
                    unstableDecodeTokens: 64,
                    precisionProfile: .minimal,
                    defaultDeviceRoute: .coreNPU,
                    npuUnavailableDeviceRoute: .coreGPU,
                    candidateCountCap: 1,
                    standardLoopFloor: 1,
                    protectedLoopFloor: 1,
                    standardCandidateFloor: 1,
                    protectedCandidateFloor: 1,
                    unstableLoopIncrement: 0,
                    unstableLoopIncrementRiskLevels: [],
                    throttleLoopPenalty: 0,
                    throttleCandidatePenalty: 0,
                    throttlePenaltyThermalLevels: [],
                    maintenanceSupported: false,
                    maintenanceBatteryFloor: 0.95,
                    scheduledMaintenanceClass: BASMaintenanceClass.none,
                    deferredMaintenanceClass: BASMaintenanceClass.none
                )
                return (runMode.rawValue, profile)
            }
        )
        tuning.budget.runModeProfilesByID?[BASEBrainRunMode.engage.rawValue] = .init(
            maxLoops: 3,
            maxCandidates: 3,
            retrievalDepth: 4,
            defaultDecodeTokens: 320,
            unstableDecodeTokens: 288,
            precisionProfile: .balanced,
            defaultDeviceRoute: .coreNPU,
            npuUnavailableDeviceRoute: .coreGPU,
            candidateCountCap: 5,
            standardLoopFloor: 2,
            protectedLoopFloor: 5,
            standardCandidateFloor: 2,
            protectedCandidateFloor: 5,
            unstableLoopIncrement: 0,
            unstableLoopIncrementRiskLevels: [],
            throttleLoopPenalty: 0,
            throttleCandidatePenalty: 0,
            throttlePenaltyThermalLevels: [],
            maintenanceSupported: true,
            maintenanceBatteryFloor: 0.20,
            scheduledMaintenanceClass: .standard,
            deferredMaintenanceClass: .deferred
        )

        let runtime = BASHostRuntime(
            configuration: makeConfiguration(runtimeTuning: tuning)
        )

        let request = BASHostSessionRequest(
            kind: .interactive,
            workflowProfile: .primary,
            surface: .application,
            prompt: "Let watch calibration trigger protected floors when policy says so.",
            title: "Protected floor statuses",
            riskLevel: .low
        )
        let result = try runtime.startSession(request)
        var watchBrain = result.currentBrain
        watchBrain.boundaryMode = .localOnlyAdvisory
        watchBrain.calibrationStatus = .watch

        let turn = runtime.buildEBrainTurn(
            request: request,
            currentBrain: watchBrain,
            projection: BASBrainProjection(records: [], candidates: [], recentEvents: []),
            deviceStateOverride: BASDeviceState(
                batteryLevel: 0.71,
                thermalLevel: .nominal,
                memoryFreeMB: 2_048,
                networkState: .online,
                foregroundState: .foreground,
                cpuLoad: 0.22,
                gpuLoad: 0.14,
                npuAvailable: true,
                latencyBudgetMs: 1_200
            )
        )

        XCTAssertEqual(turn.budgetFrame.runMode, .engage)
        XCTAssertEqual(turn.budgetFrame.maxLoops, 5)
        XCTAssertEqual(turn.budgetFrame.maxCandidates, 5)
    }

    func testExplicitRunModeBudgetProfilesCanChooseThermalLevelsThatTriggerThrottlePenalties() throws {
        var tuning = makePolicyOwnedRuntimeTuning(
            schemaVersion: "host.runtime-synthesis.run-mode-profile-thermal-throttle.v1"
        )
        tuning.stateTransitions.backgroundPulseEnabled = false
        tuning.stateTransitions.lowRiskDefaultMode = .engage
        tuning.stateTransitions.runModeRules = nil
        tuning.stateTransitions.runModeRules = tuning.stateTransitions.synthesizedRunModeRules(
            wakeIntent: tuning.wakeIntent
        )
        tuning.maintenance.blockedForegroundStates = []
        tuning.budget.runModeProfilesByID = Dictionary(
            uniqueKeysWithValues: BASEBrainRunMode.allCases.map { runMode in
                let profile = BASEBrainRuntimeSynthesisPolicy.BudgetTuning.RunModeBudgetProfile(
                    maxLoops: 1,
                    maxCandidates: 1,
                    retrievalDepth: 1,
                    defaultDecodeTokens: 96,
                    unstableDecodeTokens: 64,
                    precisionProfile: .minimal,
                    defaultDeviceRoute: .coreNPU,
                    npuUnavailableDeviceRoute: .coreGPU,
                    candidateCountCap: 1,
                    standardLoopFloor: 1,
                    protectedLoopFloor: 1,
                    standardCandidateFloor: 1,
                    protectedCandidateFloor: 1,
                    unstableLoopIncrement: 0,
                    unstableLoopIncrementRiskLevels: [],
                    throttleLoopPenalty: 0,
                    throttleCandidatePenalty: 0,
                    throttlePenaltyThermalLevels: [],
                    maintenanceSupported: false,
                    maintenanceBatteryFloor: 0.95,
                    scheduledMaintenanceClass: BASMaintenanceClass.none,
                    deferredMaintenanceClass: BASMaintenanceClass.none
                )
                return (runMode.rawValue, profile)
            }
        )
        tuning.budget.runModeProfilesByID?[BASEBrainRunMode.engage.rawValue] = .init(
            maxLoops: 5,
            maxCandidates: 5,
            retrievalDepth: 4,
            defaultDecodeTokens: 320,
            unstableDecodeTokens: 288,
            precisionProfile: .balanced,
            defaultDeviceRoute: .coreNPU,
            npuUnavailableDeviceRoute: .coreGPU,
            candidateCountCap: 5,
            standardLoopFloor: 1,
            protectedLoopFloor: 1,
            standardCandidateFloor: 1,
            protectedCandidateFloor: 1,
            unstableLoopIncrement: 0,
            unstableLoopIncrementRiskLevels: [],
            throttleLoopPenalty: 2,
            throttleCandidatePenalty: 1,
            throttlePenaltyThermalLevels: [.warm],
            maintenanceSupported: true,
            maintenanceBatteryFloor: 0.20,
            scheduledMaintenanceClass: .standard,
            deferredMaintenanceClass: .deferred
        )

        let runtime = BASHostRuntime(
            configuration: makeConfiguration(runtimeTuning: tuning)
        )

        let request = BASHostSessionRequest(
            kind: .interactive,
            workflowProfile: .primary,
            surface: .application,
            prompt: "Apply the warm thermal throttle profile.",
            title: "Thermal throttle profile",
            riskLevel: .low
        )
        let result = try runtime.startSession(request)
        let turn = runtime.buildEBrainTurn(
            request: request,
            currentBrain: result.currentBrain,
            projection: BASBrainProjection(records: [], candidates: [], recentEvents: []),
            deviceStateOverride: BASDeviceState(
                batteryLevel: 0.71,
                thermalLevel: .warm,
                memoryFreeMB: 2_048,
                networkState: .online,
                foregroundState: .background,
                cpuLoad: 0.22,
                gpuLoad: 0.14,
                npuAvailable: true,
                latencyBudgetMs: 1_200
            )
        )

        XCTAssertEqual(turn.budgetFrame.runMode, .engage)
        XCTAssertEqual(turn.budgetFrame.maxLoops, 3)
        XCTAssertEqual(turn.budgetFrame.maxCandidates, 4)
    }

    func testBudgetPolicyCanChooseWarmThermalGuardLevel() throws {
        var tuning = makePolicyOwnedRuntimeTuning(
            schemaVersion: "host.runtime-synthesis.thermal-guard-levels.v1"
        )
        tuning.stateTransitions.backgroundPulseEnabled = false
        tuning.stateTransitions.lowRiskDefaultMode = .engage
        tuning.stateTransitions.runModeRules = nil
        tuning.stateTransitions.runModeRules = tuning.stateTransitions.synthesizedRunModeRules(
            wakeIntent: tuning.wakeIntent
        )

        let runtime = BASHostRuntime(
            configuration: makeConfiguration(runtimeTuning: tuning)
        )

        let request = BASHostSessionRequest(
            kind: .interactive,
            workflowProfile: .primary,
            surface: .application,
            prompt: "Escalate warm thermal state to a throttle guard when policy says so.",
            title: "Warm thermal guard policy",
            riskLevel: .low
        )
        let result = try runtime.startSession(request)
        let turn = runtime.buildEBrainTurn(
            request: request,
            currentBrain: result.currentBrain,
            projection: BASBrainProjection(records: [], candidates: [], recentEvents: []),
            deviceStateOverride: BASDeviceState(
                batteryLevel: 0.71,
                thermalLevel: .warm,
                memoryFreeMB: 2_048,
                networkState: .online,
                foregroundState: .background,
                cpuLoad: 0.22,
                gpuLoad: 0.14,
                npuAvailable: true,
                latencyBudgetMs: 1_200
            )
        )

        XCTAssertEqual(turn.budgetFrame.runMode, .engage)
        XCTAssertEqual(turn.budgetFrame.thermalGuardLevel, .watch)
    }

    func testExplicitRunModeBudgetProfilesCanChooseRiskLevelsThatReceiveUnstableLoopIncrement() throws {
        var tuning = makePolicyOwnedRuntimeTuning(
            schemaVersion: "host.runtime-synthesis.run-mode-profile-unstable-risk.v1"
        )
        tuning.stateTransitions.highRiskMode = .engage
        tuning.stateTransitions.runModeRules = nil
        tuning.stateTransitions.runModeRules = tuning.stateTransitions.synthesizedRunModeRules(
            wakeIntent: tuning.wakeIntent
        )
        tuning.maintenance.blockedForegroundStates = []
        tuning.budget.runModeProfilesByID = Dictionary(
            uniqueKeysWithValues: BASEBrainRunMode.allCases.map { runMode in
                let profile = BASEBrainRuntimeSynthesisPolicy.BudgetTuning.RunModeBudgetProfile(
                    maxLoops: 1,
                    maxCandidates: 1,
                    retrievalDepth: 1,
                    defaultDecodeTokens: 96,
                    unstableDecodeTokens: 64,
                    precisionProfile: .minimal,
                    defaultDeviceRoute: .coreNPU,
                    npuUnavailableDeviceRoute: .coreGPU,
                    candidateCountCap: 1,
                    standardLoopFloor: 1,
                    protectedLoopFloor: 1,
                    standardCandidateFloor: 1,
                    protectedCandidateFloor: 1,
                    unstableLoopIncrement: 0,
                    unstableLoopIncrementRiskLevels: [],
                    throttleLoopPenalty: 0,
                    throttleCandidatePenalty: 0,
                    throttlePenaltyThermalLevels: [],
                    maintenanceSupported: false,
                    maintenanceBatteryFloor: 0.95,
                    scheduledMaintenanceClass: BASMaintenanceClass.none,
                    deferredMaintenanceClass: BASMaintenanceClass.none
                )
                return (runMode.rawValue, profile)
            }
        )
        tuning.budget.runModeProfilesByID?[BASEBrainRunMode.engage.rawValue] = .init(
            maxLoops: 3,
            maxCandidates: 3,
            retrievalDepth: 4,
            defaultDecodeTokens: 320,
            unstableDecodeTokens: 288,
            precisionProfile: .balanced,
            defaultDeviceRoute: .coreNPU,
            npuUnavailableDeviceRoute: .coreGPU,
            candidateCountCap: 4,
            standardLoopFloor: 1,
            protectedLoopFloor: 1,
            standardCandidateFloor: 1,
            protectedCandidateFloor: 1,
            unstableLoopIncrement: 2,
            unstableLoopIncrementRiskLevels: [.high],
            throttleLoopPenalty: 0,
            throttleCandidatePenalty: 0,
            throttlePenaltyThermalLevels: [],
            maintenanceSupported: true,
            maintenanceBatteryFloor: 0.20,
            scheduledMaintenanceClass: .standard,
            deferredMaintenanceClass: .deferred
        )

        let runtime = BASHostRuntime(
            configuration: makeConfiguration(runtimeTuning: tuning)
        )

        let request = BASHostSessionRequest(
            kind: .interactive,
            workflowProfile: .primary,
            surface: .application,
            prompt: "Let high risk keep the unstable increment when the profile says so.",
            title: "Unstable risk profile",
            riskLevel: .high
        )
        let result = try runtime.startSession(request)
        var currentBrain = result.currentBrain
        currentBrain.calibrationStatus = .watch

        let turn = runtime.buildEBrainTurn(
            request: request,
            currentBrain: currentBrain,
            projection: BASBrainProjection(records: [], candidates: [], recentEvents: []),
            deviceStateOverride: BASDeviceState(
                batteryLevel: 0.71,
                thermalLevel: .nominal,
                memoryFreeMB: 2_048,
                networkState: .online,
                foregroundState: .background,
                cpuLoad: 0.18,
                gpuLoad: 0.10,
                npuAvailable: true,
                latencyBudgetMs: 1_000
            )
        )

        XCTAssertEqual(turn.budgetFrame.runMode, .engage)
        XCTAssertEqual(turn.budgetFrame.maxLoops, 5)
    }

    func testBudgetPolicyCanLimitUnstableAdjustmentsToDriftingCalibrationOnly() throws {
        var tuning = makePolicyOwnedRuntimeTuning(
            schemaVersion: "host.runtime-synthesis.unstable-calibration-statuses.v1"
        )
        tuning.stateTransitions.lowRiskDefaultMode = .engage
        tuning.stateTransitions.backgroundPulseEnabled = false
        tuning.stateTransitions.runModeRules = nil
        tuning.stateTransitions.runModeRules = tuning.stateTransitions.synthesizedRunModeRules(
            wakeIntent: tuning.wakeIntent
        )
        tuning.maintenance.blockedForegroundStates = []
        tuning.budget.unstableBudgetCalibrationStatuses = [.drifting]
        tuning.budget.runModeProfilesByID = Dictionary(
            uniqueKeysWithValues: BASEBrainRunMode.allCases.map { runMode in
                let profile = BASEBrainRuntimeSynthesisPolicy.BudgetTuning.RunModeBudgetProfile(
                    maxLoops: 1,
                    maxCandidates: 1,
                    retrievalDepth: 1,
                    defaultDecodeTokens: 96,
                    unstableDecodeTokens: 64,
                    precisionProfile: .minimal,
                    defaultDeviceRoute: .coreNPU,
                    npuUnavailableDeviceRoute: .coreGPU,
                    candidateCountCap: 1,
                    standardLoopFloor: 1,
                    protectedLoopFloor: 1,
                    standardCandidateFloor: 1,
                    protectedCandidateFloor: 1,
                    unstableLoopIncrement: 0,
                    unstableLoopIncrementRiskLevels: [],
                    throttleLoopPenalty: 0,
                    throttleCandidatePenalty: 0,
                    throttlePenaltyThermalLevels: [],
                    maintenanceSupported: false,
                    maintenanceBatteryFloor: 0.95,
                    scheduledMaintenanceClass: BASMaintenanceClass.none,
                    deferredMaintenanceClass: BASMaintenanceClass.none
                )
                return (runMode.rawValue, profile)
            }
        )
        tuning.budget.runModeProfilesByID?[BASEBrainRunMode.engage.rawValue] = .init(
            maxLoops: 3,
            maxCandidates: 3,
            retrievalDepth: 4,
            defaultDecodeTokens: 320,
            unstableDecodeTokens: 288,
            precisionProfile: .balanced,
            defaultDeviceRoute: .coreNPU,
            npuUnavailableDeviceRoute: .coreGPU,
            candidateCountCap: 4,
            standardLoopFloor: 1,
            protectedLoopFloor: 1,
            standardCandidateFloor: 1,
            protectedCandidateFloor: 1,
            unstableLoopIncrement: 2,
            unstableLoopIncrementRiskLevels: [.low],
            throttleLoopPenalty: 0,
            throttleCandidatePenalty: 0,
            throttlePenaltyThermalLevels: [],
            maintenanceSupported: true,
            maintenanceBatteryFloor: 0.20,
            scheduledMaintenanceClass: .standard,
            deferredMaintenanceClass: .deferred
        )

        let runtime = BASHostRuntime(
            configuration: makeConfiguration(runtimeTuning: tuning)
        )

        let request = BASHostSessionRequest(
            kind: .interactive,
            workflowProfile: .primary,
            surface: .application,
            prompt: "Keep watch calibration on the standard budget lane when the policy says drifting only.",
            title: "Unstable calibration statuses",
            riskLevel: .low
        )
        let result = try runtime.startSession(request)
        var currentBrain = result.currentBrain
        currentBrain.calibrationStatus = .watch

        let turn = runtime.buildEBrainTurn(
            request: request,
            currentBrain: currentBrain,
            projection: BASBrainProjection(records: [], candidates: [], recentEvents: []),
            deviceStateOverride: BASDeviceState(
                batteryLevel: 0.71,
                thermalLevel: .nominal,
                memoryFreeMB: 2_048,
                networkState: .online,
                foregroundState: .background,
                cpuLoad: 0.18,
                gpuLoad: 0.10,
                npuAvailable: true,
                latencyBudgetMs: 1_000
            )
        )

        XCTAssertEqual(turn.budgetFrame.runMode, .engage)
        XCTAssertEqual(turn.budgetFrame.maxLoops, 3)
        XCTAssertEqual(turn.budgetFrame.maxDecodeTokens, 320)
        XCTAssertEqual(turn.budgetFrame.precisionProfile, .balanced)
    }

    func testStateTransitionDefaultsDriveLowRiskRoutingWhenNoSpecialBranchesApply() throws {
        var tuning = makePolicyOwnedRuntimeTuning(
            schemaVersion: "host.runtime-synthesis.transition-rules.v1"
        )
        tuning.stateTransitions = .init(
            backgroundPulseEnabled: false,
            recoveryOnCriticalThermal: true,
            reflectOnTrustDrift: false,
            deepLoopOnProtectedBoundary: false,
            lockdownOnExtremeBlockedPermit: true,
            quarantineFailureGuardThreshold: 2,
            lowRiskBackgroundMode: .pulse,
            lowRiskProtectedMode: .guard,
            lowRiskUrgentMode: .guard,
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

        let result = try runtime.startSession(
            BASHostSessionRequest(
                kind: .interactive,
                workflowProfile: .primary,
                surface: .application,
                prompt: "Keep this calm and local.",
                title: "Transition rules",
                riskLevel: .low
            )
        )

        let turn = try XCTUnwrap(result.eBrainTurn)
        XCTAssertEqual(turn.budgetFrame.runMode, .sentinel)
    }

    func testExplicitTransitionRulesOverrideLegacyModeBranches() throws {
        var tuning = makePolicyOwnedRuntimeTuning(
            schemaVersion: "host.runtime-synthesis.transition-rules.override.v1"
        )
        tuning.stateTransitions = .init(
            backgroundPulseEnabled: false,
            recoveryOnCriticalThermal: true,
            reflectOnTrustDrift: false,
            deepLoopOnProtectedBoundary: false,
            lockdownOnExtremeBlockedPermit: true,
            quarantineFailureGuardThreshold: 2,
            lowRiskBackgroundMode: .pulse,
            lowRiskProtectedMode: .guard,
            lowRiskUrgentMode: .guard,
            lowRiskDefaultMode: .sentinel,
            mediumRiskProtectedDeepLoopMode: .deepLoop,
            mediumRiskReflectiveMode: .reflect,
            mediumRiskDefaultMode: .engage,
            highRiskMode: .guard,
            extremeRiskMode: .lockdown,
            recoveryMode: .recovery,
            quarantineMode: .quarantine,
            runModeRules: [
                .init(
                    ruleID: "explicit.low.default",
                    resultMode: .engage,
                    riskLevels: [.low],
                    requiresGuardedBudget: false,
                    urgencyDetected: false
                )
            ]
        )

        let runtime = BASHostRuntime(
            configuration: makeConfiguration(runtimeTuning: tuning)
        )

        let result = try runtime.startSession(
            BASHostSessionRequest(
                kind: .interactive,
                workflowProfile: .primary,
                surface: .application,
                prompt: "Keep this calm and local.",
                title: "Transition rules",
                riskLevel: .low
            )
        )

        let turn = try XCTUnwrap(result.eBrainTurn)
        XCTAssertEqual(turn.budgetFrame.runMode, .engage)
    }

    func testIncompleteExplicitTransitionRulesFailSafeToQuarantineInsteadOfLegacyRiskBuckets() throws {
        var tuning = makePolicyOwnedRuntimeTuning(
            schemaVersion: "host.runtime-synthesis.transition-rules.fail-safe.v1"
        )
        tuning.stateTransitions = .init(
            backgroundPulseEnabled: false,
            recoveryOnCriticalThermal: true,
            reflectOnTrustDrift: false,
            deepLoopOnProtectedBoundary: false,
            lockdownOnExtremeBlockedPermit: true,
            quarantineFailureGuardThreshold: 2,
            lowRiskBackgroundMode: .pulse,
            lowRiskProtectedMode: .guard,
            lowRiskUrgentMode: .guard,
            lowRiskDefaultMode: .sentinel,
            mediumRiskProtectedDeepLoopMode: .deepLoop,
            mediumRiskReflectiveMode: .reflect,
            mediumRiskDefaultMode: .engage,
            highRiskMode: .guard,
            extremeRiskMode: .lockdown,
            recoveryMode: .recovery,
            quarantineMode: .quarantine,
            runModeRules: [
                .init(
                    ruleID: "explicit.medium.only",
                    resultMode: .reflect,
                    riskLevels: [.medium]
                )
            ]
        )

        let runtime = BASHostRuntime(
            configuration: makeConfiguration(runtimeTuning: tuning)
        )

        let result = try runtime.startSession(
            BASHostSessionRequest(
                kind: .interactive,
                workflowProfile: .primary,
                surface: .application,
                prompt: "Keep this calm and local.",
                title: "Transition rules",
                riskLevel: .low
            )
        )

        let turn = try XCTUnwrap(result.eBrainTurn)
        XCTAssertEqual(turn.budgetFrame.runMode, .quarantine)
    }

    func testVitalMonitorFeedsTurnWhenNoOverrideSupplied() throws {
        let defaultDeviceState = BASDeviceState(
            batteryLevel: 0.41,
            thermalLevel: .warm,
            memoryFreeMB: 1_536,
            networkState: .online,
            foregroundState: .background,
            cpuLoad: 0.29,
            gpuLoad: 0.21,
            npuAvailable: false,
            latencyBudgetMs: 1_900
        )
        let monitoredDeviceState = BASDeviceState(
            batteryLevel: 0.88,
            thermalLevel: .hot,
            memoryFreeMB: 4_096,
            networkState: .constrained,
            foregroundState: .foreground,
            cpuLoad: 0.11,
            gpuLoad: 0.08,
            npuAvailable: true,
            latencyBudgetMs: 900
        )
        let runtime = BASHostRuntime(
            configuration: makeConfiguration(defaultDeviceState: defaultDeviceState),
            vitalMonitor: FixedVitalMonitor(deviceState: monitoredDeviceState)
        )

        let result = try runtime.startSession(
            BASHostSessionRequest(
                kind: .interactive,
                workflowProfile: .reflective,
                surface: .application,
                prompt: "Prefer live device vitals over host defaults.",
                title: "Live vitals",
                riskLevel: .low
            )
        )

        XCTAssertEqual(result.eBrainTurn?.deviceState, monitoredDeviceState)
    }

    func testExplicitDeviceStateOverrideWinsOverVitalMonitor() throws {
        let monitorState = BASDeviceState(
            batteryLevel: 0.88,
            thermalLevel: .hot,
            memoryFreeMB: 4_096,
            networkState: .constrained,
            foregroundState: .foreground,
            cpuLoad: 0.11,
            gpuLoad: 0.08,
            npuAvailable: true,
            latencyBudgetMs: 900
        )
        let overrideState = BASDeviceState(
            batteryLevel: 0.52,
            thermalLevel: .nominal,
            memoryFreeMB: 2_048,
            networkState: .online,
            foregroundState: .background,
            cpuLoad: 0.24,
            gpuLoad: 0.18,
            npuAvailable: false,
            latencyBudgetMs: 1_600
        )
        let runtime = BASHostRuntime(
            configuration: makeConfiguration(),
            vitalMonitor: FixedVitalMonitor(deviceState: monitorState)
        )
        let seedResult = try runtime.startSession(
            BASHostSessionRequest(
                kind: .interactive,
                workflowProfile: .primary,
                surface: .application,
                prompt: "Seed the host runtime before overriding vitals.",
                title: "Seed",
                riskLevel: .low
            )
        )

        let turn = runtime.buildEBrainTurn(
            request: BASHostSessionRequest(
                kind: .interactive,
                workflowProfile: .primary,
                surface: .application,
                prompt: "Override monitor vitals.",
                title: "Override",
                riskLevel: .low
            ),
            currentBrain: seedResult.currentBrain,
            projection: BASBrainProjection(records: [], candidates: [], recentEvents: []),
            deviceStateOverride: overrideState,
            now: .distantPast
        )

        XCTAssertEqual(turn.deviceState, overrideState)
    }

    func testBootstrapUsesLifecyclePlannerNotices() throws {
        let runtime = makeGenericRuntime()

        let result = try runtime.bootstrap(
            BASHostLifecycleRequest(
                phase: .initialAppearance,
                sessionKind: .ambient,
                preferredProfile: .primary,
                sourceSurface: .application,
                promptSeed: "Load the substrate before the UI asks for help.",
                riskLevel: .low
            )
        )

        XCTAssertEqual(result.activeSessionTitle, "Initial Appearance")
        XCTAssertEqual(result.requestKind, .ambient)
        XCTAssertTrue(result.notices.contains("Refresh substrate projection"))
        XCTAssertTrue(result.followUpActions.contains("Load current state for presentation"))
    }

    func testCustomLifecycleBehaviorBelongsToHost() throws {
        let runtime = BASHostRuntime(
            configuration: makeConfiguration(
                lifecycleBehavior: BASHostLifecycleBehaviorConfiguration(
                    bootstrapBehavior: BASAppleLifecycleBootstrapBehavior(
                        actionsByPhaseID: [
                            BASAppleLifecycleBootstrapPhase.initialAppearance.rawValue: [
                                BASAppleLifecycleBootstrapAction(kind: .refreshCurrentBrain, bootstrapTriggerID: "hostLaunch"),
                                BASAppleLifecycleBootstrapAction(kind: .restoreActiveWorkspace)
                            ]
                        ]
                    )
                ),
                presentation: BASHostPresentationConfiguration(
                    lifecycle: BASHostLifecyclePresentation(
                        refreshCurrentBrainNotice: "Host refresh brain",
                        restoreActiveWorkspaceNotice: "Host restore workspace",
                        loadCurrentBrainFollowUp: "Host loads first",
                        resumeStructuredWorkspaceFollowUp: "Host resumes workspace"
                    )
                )
            )
        )

        let result = try runtime.bootstrap(
            BASHostLifecycleRequest(
                phase: .initialAppearance,
                sessionKind: .ambient,
                preferredProfile: .primary,
                sourceSurface: .application,
                promptSeed: "Host bootstrap",
                riskLevel: .low
            )
        )

        XCTAssertEqual(result.notices, ["Host refresh brain", "Host restore workspace"])
        XCTAssertEqual(result.followUpActions, ["Host loads first", "Host resumes workspace"])
    }

    func testWorkflowBehaviorUsesGenericProviderObservationKeys() {
        let workflowBehavior = BASHostWorkflowBehaviorConfiguration(
            providerObservationNarrativesByKindID: [
                BASDecisionMode.primaryID: BASAppleProviderObservationNarrative(
                    templatePinnedDetail: "Host owns the rapid pass copy.",
                    admissionSkippedDetailPrefix: "Host skipped the rapid pass.",
                    deterministicFallbackBase: "Host kept the rapid draft.",
                    cachedConsistencySource: "cached rapid pass",
                    providerConsistencySource: "provider rapid pass"
                )
            ]
        )

        XCTAssertEqual(
            workflowBehavior.providerObservationNarrative(forKindID: BASDecisionMode.primaryID)?.cachedConsistencySource,
            "cached rapid pass"
        )
        XCTAssertNil(workflowBehavior.providerObservationNarrative(forKindID: "legacy-primary"))
    }

    func testReopenHighRiskProducesFollowUpSuggestion() throws {
        let runtime = makeGenericRuntime()

        let result = try runtime.reopen(
            BASHostReopenRequest(
                workflowProfile: .comparative,
                title: "Reopen this choice",
                detail: "There is enough risk here that we want more structure.",
                promptSeed: "Look at the cost of acting tonight.",
                riskLevel: .high,
                templateHint: "Use the cooling template.",
                interventionHistorySummary: "Night-time messages go worse without delay."
            )
        )

        XCTAssertEqual(result.requestKind, .reopen)
        XCTAssertEqual(result.workflowProfile, .comparative)
        XCTAssertEqual(result.currentBrain.workflowProfile, .comparative)
        XCTAssertEqual(result.currentBrain.failureGuardCount, 0)
        XCTAssertNotNil(result.interventionSuggestion)
        XCTAssertTrue(result.followUpActions.contains("Require confirmation"))
    }

    func testHostWorkflowProfilesUseGenericIdentifiers() throws {
        XCTAssertEqual(BASHostWorkflowProfile.primary.rawValue, "primary")
        XCTAssertEqual(BASHostWorkflowProfile.comparative.rawValue, "comparative")
        XCTAssertEqual(try JSONDecoder().decode(BASHostWorkflowProfile.self, from: Data(#""primary""#.utf8)), .primary)
        XCTAssertEqual(try JSONDecoder().decode(BASHostWorkflowProfile.self, from: Data(#""comparative""#.utf8)), .comparative)
    }

    func testCustomPresentationLetsHostOwnWorkflowLanguage() throws {
        let runtime = BASHostRuntime(
            configuration: makeConfiguration(
                runtimeProfileID: "atlas.field-runtime",
                presentation: BASHostPresentationConfiguration(
                    workflowTitles: BASHostWorkflowTitles(
                        primary: "Scan Lane",
                        comparative: "Fork Lane",
                        reflective: "Archive Lane"
                    ),
                    surfaceTitles: BASHostSurfaceTitles(
                        application: "App",
                        wearable: "Watch",
                        widget: "Widget",
                        shortcut: "Shortcut",
                        voiceAssistant: "Siri",
                        notification: "Notification",
                        system: "System"
                    ),
                    sessionTitles: BASHostSessionTitles(
                        primary: "Scan Lane",
                        comparative: "Fork Lane",
                        reflective: "Archive Lane",
                        initialAppearance: "Atlas Bootstrap",
                        sceneActive: "Atlas Refresh"
                    ),
                    followUpActions: BASHostFollowUpActions(
                        primary: ["Scan the active pressure", "Pick one bounded next move"],
                        comparative: ["Fork the active trade-off", "Name one constraint and one opening"],
                        reflective: ["Archive the pattern", "Keep one anchor visible"],
                        highRiskEscalation: ["Require stronger confirmation"]
                    ),
                    lifecycle: BASHostLifecyclePresentation(
                        refreshMemoryProjectionNotice: "Refresh Atlas projection",
                        refreshCurrentBrainNotice: "Refresh Atlas state",
                        presentPendingReflectionNotice: "Present the deferred archive step",
                        consumePendingLaunchRequestNotice: "Consume the deferred Atlas launch",
                        restoreActiveWorkspaceNotice: "Restore the Atlas workspace",
                        refreshPredictedInterventionNotice: "Refresh the guarded Atlas suggestion",
                        syncWidgetSnapshotNotice: "Sync the Atlas widget snapshot",
                        loadCurrentBrainFollowUp: "Load Atlas state before rendering",
                        resumeStructuredWorkspaceFollowUp: "Resume the Atlas workspace",
                        recomputeGuardedInterventionFollowUp: "Recompute the guarded Atlas suggestion"
                    ),
                    notices: BASHostNoticeTemplates(
                        enteredWorkflow: "{surface} entered {workflow} through Atlas.",
                        runtimeProfile: "Atlas runtime profile {runtimeProfile} is active.",
                        reopenFollowUpAction: "Reopen through {workflow}",
                        emptyPromptGoalFallback: "Atlas keeps the lane narrow first."
                    ),
                    predictiveIntervention: BASHostPredictiveInterventionPresentation(
                        mediumRiskTitle: "Atlas suggests a slower scan.",
                        mediumRiskDetail: "Atlas sees a context that benefits from one lower-pressure pass.",
                        highRiskTitle: "Atlas wants a stronger checkpoint.",
                        highRiskDetail: "Atlas sees elevated risk and wants stronger confirmation before the next move.",
                        reopenRiskDetail: "This reopen path is carrying risk, so Atlas is asking for more structure.",
                        fallbackReopenSuggestionDetail: "A prior Atlas hold suggests slowing this down.",
                        defaultReason: "Atlas prefers a lower-pressure path here."
                    )
                )
            )
        )

        let session = try runtime.startSession(
            BASHostSessionRequest(
                kind: .interactive,
                workflowProfile: .primary,
                surface: .application,
                prompt: "I want to move fast.",
                riskLevel: .low
            )
        )
        let bootstrap = try runtime.bootstrap(
            BASHostLifecycleRequest(
                phase: .initialAppearance,
                sessionKind: .ambient,
                preferredProfile: .primary,
                sourceSurface: .application,
                promptSeed: "Load the current brain before speaking.",
                riskLevel: .low
            )
        )

        XCTAssertEqual(session.activeSessionTitle, "Scan Lane")
        XCTAssertTrue(
            session.notices.contains { notice in
                notice.contains("Atlas runtime profile") && notice.contains("atlas.field-runtime")
            }
        )
        XCTAssertEqual(session.followUpActions, ["Scan the active pressure", "Pick one bounded next move"])
        XCTAssertEqual(bootstrap.activeSessionTitle, "Atlas Bootstrap")
        XCTAssertTrue(bootstrap.notices.contains("Refresh Atlas projection"))
        XCTAssertTrue(bootstrap.followUpActions.contains("Load Atlas state before rendering"))
    }

    func testCustomPredictiveInterventionCopyBelongsToHost() throws {
        let runtime = BASHostRuntime(
            configuration: makeConfiguration(
                lifecycleBehavior: BASHostLifecycleBehaviorConfiguration(
                    predictiveInterventionBehavior: BASApplePredictiveInterventionBehavior(
                        lowRisk: BASApplePredictiveInterventionRiskBehavior(
                            title: "Host says soften it.",
                            detail: "Host wants a lighter pass.",
                            preferredModeID: BASDecisionMode.primary.identifier
                        ),
                        mediumRisk: BASApplePredictiveInterventionRiskBehavior(
                            title: "Host says pause.",
                            detail: "Host wants one slower pass.",
                            preferredModeID: BASDecisionMode.comparative.identifier
                        ),
                        highRisk: BASApplePredictiveInterventionRiskBehavior(
                            title: "Host wants another checkpoint.",
                            detail: "Host sees elevated risk and wants stronger confirmation.",
                            preferredModeID: BASDecisionMode.reflective.identifier
                        ),
                        defaultReason: "Host policy prefers a slower workflow."
                    )
                ),
                presentation: BASHostPresentationConfiguration(
                    predictiveIntervention: BASHostPredictiveInterventionPresentation(
                        reopenRiskDetail: "Host sees risk in this reopen path and wants structure.",
                        fallbackReopenSuggestionDetail: "Host says slow this reopen down."
                    )
                )
            )
        )

        let session = try runtime.startSession(
            BASHostSessionRequest(
                kind: .interactive,
                workflowProfile: .comparative,
                surface: .application,
                prompt: "I need to compare these options carefully.",
                riskLevel: .medium
            )
        )
        let reopen = try runtime.reopen(
            BASHostReopenRequest(
                workflowProfile: .comparative,
                title: "Reopen this choice",
                promptSeed: "Look at the cost of acting tonight.",
                riskLevel: .high,
                templateHint: "Use the cooling template."
            )
        )

        XCTAssertEqual(session.interventionSuggestion?.title, "Host says pause.")
        XCTAssertEqual(session.interventionSuggestion?.detail, "Host wants one slower pass.")
        XCTAssertEqual(session.interventionSuggestion?.reason, "Host policy prefers a slower workflow.")
        XCTAssertEqual(session.interventionSuggestion?.preferredWorkflowProfile, .comparative)
        XCTAssertEqual(reopen.interventionSuggestion?.detail, "Host says slow this reopen down.")
    }

    func testPreferredPredictiveWorkflowUsesHostModeMapping() throws {
        let runtime = BASHostRuntime(
            configuration: makeConfiguration(
                lifecycleBehavior: BASHostLifecycleBehaviorConfiguration(
                    predictiveInterventionBehavior: BASApplePredictiveInterventionBehavior(
                        mediumRisk: BASApplePredictiveInterventionRiskBehavior(
                            title: "Use more structure",
                            detail: "The host wants the comparative workflow next.",
                            preferredModeID: BASDecisionMode.comparativeID
                        )
                    )
                ),
                workflowBehavior: BASHostWorkflowBehaviorConfiguration(
                    modeIDsByProfileID: [
                        BASHostWorkflowProfile.primary.rawValue: BASDecisionMode.reflectiveID,
                        BASHostWorkflowProfile.comparative.rawValue: BASDecisionMode.primaryID,
                        BASHostWorkflowProfile.reflective.rawValue: BASDecisionMode.comparativeID
                    ]
                )
            )
        )

        let session = try runtime.startSession(
            BASHostSessionRequest(
                kind: .interactive,
                workflowProfile: .primary,
                surface: .application,
                prompt: "Slow this down for one more pass.",
                riskLevel: .medium
            )
        )

        XCTAssertEqual(session.interventionSuggestion?.preferredWorkflowProfile, .reflective)
    }

    func testHostKitSupportsForeignHostVocabularyWithoutLegacyCopy() throws {
        let runtime = BASHostRuntime(
            configuration: makeConfiguration(
                runtimeProfileID: "atlas.field-runtime",
                workflowBehavior: BASHostWorkflowBehaviorConfiguration(
                    modeIDsByProfileID: [
                        BASHostWorkflowProfile.primary.rawValue: BASDecisionMode.primaryID,
                        BASHostWorkflowProfile.comparative.rawValue: BASDecisionMode.comparativeID,
                        BASHostWorkflowProfile.reflective.rawValue: BASDecisionMode.reflectiveID
                    ],
                    providerObservationNarrativesByKindID: [
                        BASDecisionMode.primaryID: BASAppleProviderObservationNarrative(
                            templatePinnedDetail: "Atlas pinned the Scan Lane draft.",
                            admissionSkippedDetailPrefix: "Atlas skipped the Scan Lane pass.",
                            deterministicFallbackBase: "Atlas kept the deterministic Scan Lane draft.",
                            cachedConsistencySource: "cached Scan Lane",
                            providerConsistencySource: "provider Scan Lane"
                        )
                    ],
                    hostNamespace: "atlas"
                ),
                presentation: BASHostPresentationConfiguration(
                    workflowTitles: BASHostWorkflowTitles(
                        primary: "Scan Lane",
                        comparative: "Fork Lane",
                        reflective: "Archive Lane"
                    ),
                    sessionTitles: BASHostSessionTitles(
                        primary: "Scan Lane",
                        comparative: "Fork Lane",
                        reflective: "Archive Lane",
                        initialAppearance: "Atlas Bootstrap",
                        sceneActive: "Atlas Refresh"
                    ),
                    notices: BASHostNoticeTemplates(
                        enteredWorkflow: "{surface} entered {workflow} through Atlas.",
                        runtimeProfile: "Atlas runtime profile {runtimeProfile} is active.",
                        reopenFollowUpAction: "Reopen through {workflow}",
                        emptyPromptGoalFallback: "Atlas keeps the lane narrow first."
                    )
                )
            )
        )

        let session = try runtime.startSession(
            BASHostSessionRequest(
                kind: .interactive,
                workflowProfile: .primary,
                surface: .application,
                prompt: "Atlas wants a first-pass scan.",
                riskLevel: .low
            )
        )

        XCTAssertEqual(session.activeSessionTitle, "Scan Lane")
        XCTAssertTrue(
            session.notices.contains { notice in
                notice.contains("Atlas") && notice.localizedCaseInsensitiveContains("Scan Lane")
            }
        )
        XCTAssertTrue(session.notices.contains("Atlas runtime profile atlas.field-runtime is active."))
        XCTAssertEqual(
            runtime.configuration.workflowBehavior.providerObservationNarrative(forKindID: BASDecisionMode.primaryID)?.providerConsistencySource,
            "provider Scan Lane"
        )
    }

    func testLifecycleBehaviorCarriesHostOwnedProjectionLimits() {
        let configuration = makeConfiguration(
            lifecycleBehavior: BASHostLifecycleBehaviorConfiguration(
                projectionRefreshLimits: BASAppleMemoryProjectionRefreshLimits(
                    recordLimit: 48,
                    candidateLimit: 20,
                    checkEventLimit: 64,
                    comparativeRecordLimit: 20,
                    reflectiveRecordLimit: 20
                )
            )
        )

        XCTAssertEqual(configuration.lifecycleBehavior.projectionRefreshLimits.recordLimit, 48)
        XCTAssertEqual(configuration.lifecycleBehavior.projectionRefreshLimits.candidateLimit, 20)
        XCTAssertEqual(configuration.lifecycleBehavior.projectionRefreshLimits.checkEventLimit, 64)
        XCTAssertEqual(configuration.lifecycleBehavior.projectionRefreshLimits.comparativeRecordLimit, 20)
        XCTAssertEqual(configuration.lifecycleBehavior.projectionRefreshLimits.reflectiveRecordLimit, 20)
    }

    func testWorkflowBehaviorCanOwnSessionKindDefaults() {
        let configuration = BASHostWorkflowBehaviorConfiguration(
            memorySourceIDsBySessionKindID: [
                BASHostSessionKind.notification.rawValue: BASMemorySource.reflection.rawValue
            ],
            retrievalModeIDsBySessionKindID: [
                BASHostSessionKind.widget.rawValue: "host-widget-compact"
            ]
        )

        XCTAssertEqual(configuration.memorySource(for: .notification), .reflection)
        XCTAssertNil(configuration.memorySource(for: .interactive))
        XCTAssertEqual(configuration.retrievalMode(for: .widget), "host-widget-compact")
        XCTAssertNil(configuration.retrievalMode(for: .interactive))
    }

    func testWorkflowBehaviorOwnsModeMappingAndUsesExplicitGenericDefaults() throws {
        let configuration = BASHostWorkflowBehaviorConfiguration(
            modeIDsByProfileID: [
                BASHostWorkflowProfile.primary.rawValue: BASDecisionMode.reflectiveID,
                BASHostWorkflowProfile.comparative.rawValue: BASDecisionMode.primaryID,
                BASHostWorkflowProfile.reflective.rawValue: BASDecisionMode.comparativeID
            ]
        )
        let genericConfiguration = BASHostWorkflowBehaviorConfiguration.generic

        XCTAssertEqual(try configuration.mode(for: .primary), .reflective)
        XCTAssertEqual(try configuration.mode(for: .comparative), .primary)
        XCTAssertEqual(configuration.workflowProfile(forModeID: BASDecisionMode.comparativeID), .reflective)
        XCTAssertEqual(try configuration.interactiveRetrievalMode(for: .primary), BASRetrievalMode.adaptive.rawValue)
        XCTAssertNil(configuration.defaultMemorySource(for: .reopen))
        XCTAssertNil(configuration.defaultRetrievalMode(for: .reopen))
        XCTAssertEqual(genericConfiguration.defaultMemorySource(for: .reopen), .archive)
        XCTAssertEqual(genericConfiguration.defaultRetrievalMode(for: .reopen), BASRetrievalMode.adaptive.rawValue)
    }

    func testCustomWorkflowBehaviorBelongsToHost() throws {
        let runtime = BASHostRuntime(
            configuration: makeConfiguration(
                workflowBehavior: BASHostWorkflowBehaviorConfiguration(
                    templateIDsByProfileID: [
                        BASHostWorkflowProfile.primary.rawValue: ["atlas.template.scan-lane"]
                    ],
                    memorySourceIDsByProfileID: [
                        BASHostWorkflowProfile.primary.rawValue: BASMemorySource.archive.rawValue
                    ],
                    interactiveRetrievalModeByProfileID: [
                        BASHostWorkflowProfile.primary.rawValue: "balanced"
                    ],
                    hostNamespace: "atlas-sdk"
                )
            )
        )

        let result = try runtime.startSession(
            BASHostSessionRequest(
                kind: .interactive,
                workflowProfile: .primary,
                surface: .application,
                prompt: "I need one cleaner pass before I act.",
                riskLevel: .low
            )
        )

        XCTAssertEqual(result.projection.activeTemplateIDs, ["atlas.template.scan-lane"])
        XCTAssertEqual(result.currentBrain.verificationSummary.split(separator: "/").first, "atlas-sdk")
    }

    func testGenericWorkflowDefaultsStayNeutralUntilHostInjectsProductSemantics() throws {
        let runtime = makeGenericRuntime()

        let result = try runtime.startSession(
            BASHostSessionRequest(
                kind: .interactive,
                workflowProfile: .primary,
                surface: .application,
                prompt: "Hold the state steady for one more pass.",
                riskLevel: .low
            )
        )

        XCTAssertTrue(result.projection.activeTemplateIDs.isEmpty)
        XCTAssertEqual(result.currentBrain.activeTemplateCount, 0)
        XCTAssertTrue(result.currentBrain.verificationSummary.hasPrefix("host/"))
        XCTAssertEqual(result.currentBrain.workflowTitle, "Primary")
        XCTAssertEqual(result.activeSessionTitle, "Primary")
    }

    func testWorkflowBehaviorLetsHostOwnFailureGuardIdentifiers() throws {
        let runtime = BASHostRuntime(
            configuration: makeConfiguration(
                workflowBehavior: BASHostWorkflowBehaviorConfiguration(
                    failureGuardIDsByRiskLevelID: [
                        BASHostRiskLevel.high.rawValue: ["samplehost.guard/elevated-risk"]
                    ],
                    hostNamespace: "samplehost"
                )
            )
        )

        let result = try runtime.startSession(
            BASHostSessionRequest(
                kind: .interactive,
                workflowProfile: .comparative,
                surface: .application,
                prompt: "This needs another checkpoint before I commit.",
                riskLevel: .high
            )
        )

        XCTAssertEqual(result.currentBrain.failureGuardCount, 1)
    }

    func testDefaultHighRiskGuardStaysEmptyUntilHostInjectsPolicy() throws {
        let runtime = makeGenericRuntime()

        let result = try runtime.startSession(
            BASHostSessionRequest(
                kind: .interactive,
                workflowProfile: .comparative,
                surface: .application,
                prompt: "This needs another checkpoint before I commit.",
                riskLevel: .high
            )
        )

        XCTAssertEqual(result.currentBrain.failureGuardCount, 0)
        XCTAssertTrue(result.currentBrain.verificationSummary.hasPrefix("host/"))
    }

    func testExecuteLifecyclePhaseDelegatesEntryConsumptionAndRefreshOrder() {
        let runtime = makeGenericRuntime()
        var actions: [String] = []

        runtime.executeLifecyclePhase(
            .initialAppearance,
            refreshMemoryProjection: { actions.append("projection") },
            refreshCurrentBrain: { actions.append("brain:\($0)") },
            presentPendingReflection: { actions.append("reflection") },
            consumeHandoff: { "handoff" },
            handleHandoff: { envelope in actions.append("handoff:\(envelope)") },
            consumePendingRequest: { nil as String? },
            handlePendingRequest: { request in actions.append("pending:\(request)") },
            restoreActiveWorkspace: { actions.append("restore") },
            refreshPredictedIntervention: { actions.append("prediction") },
            syncWidgetSnapshot: { actions.append("widget") }
        )

        XCTAssertEqual(
            actions,
            [
                "projection",
                "brain:launch",
                "handoff:handoff"
            ]
        )
    }

    func testCommitProjectionRefreshPublishesProjectionAndNotice() {
        let runtime = makeGenericRuntime()
        var committedProjection: String?
        var dirtyFlag = true
        var publishedNotice: String?

        runtime.commitProjectionRefresh(
            outcome: BASAppleProjectionRefreshResult(
                projection: "projection",
                refreshed: true,
                notice: "refresh notice"
            ),
            commitProjection: { committedProjection = $0 },
            setProjectionDirty: { dirtyFlag = $0 },
            publishNotice: { publishedNotice = $0 }
        )

        XCTAssertEqual(committedProjection, "projection")
        XCTAssertFalse(dirtyFlag)
        XCTAssertEqual(publishedNotice, "refresh notice")
    }

    func testResolveProjectionRefreshUsesResolverAndCommitsState() {
        let runtime = makeGenericRuntime()
        var committedProjection: String?
        var dirtyFlag = true
        var publishedNotice: String?

        runtime.resolveProjectionRefresh(
            using: {
                BASAppleProjectionRefreshResult(
                    projection: "resolved-projection",
                    refreshed: true,
                    notice: "resolved notice"
                )
            },
            commitProjection: { committedProjection = $0 },
            setProjectionDirty: { dirtyFlag = $0 },
            publishNotice: { publishedNotice = $0 }
        )

        XCTAssertEqual(committedProjection, "resolved-projection")
        XCTAssertFalse(dirtyFlag)
        XCTAssertEqual(publishedNotice, "resolved notice")
    }

    func testActivateSessionCommitsProjectionBrainAndSession() {
        let runtime = makeGenericRuntime()
        var loadedSession: [String] = []
        var committedProjection: String?
        var dirtyFlag = true
        var publishedNotice: String?
        var committedBrain: String?
        var committedSession: String?

        runtime.activateSession(
            session: "session",
            outcome: BASAppleCurrentBrainProjectionRuntimeResult(
                currentBrain: "brain",
                projection: "projection",
                refreshedProjection: true,
                notice: "activation notice"
            ),
            loadBrainState: { session, currentBrain in
                loadedSession = [session, currentBrain]
            },
            commitProjection: { committedProjection = $0 },
            setProjectionDirty: { dirtyFlag = $0 },
            publishNotice: { publishedNotice = $0 },
            commitCurrentBrain: { committedBrain = $0 },
            commitSession: { committedSession = $0 }
        )

        XCTAssertEqual(loadedSession, ["session", "brain"])
        XCTAssertEqual(committedProjection, "projection")
        XCTAssertFalse(dirtyFlag)
        XCTAssertEqual(publishedNotice, "activation notice")
        XCTAssertEqual(committedBrain, "brain")
        XCTAssertEqual(committedSession, "session")
    }

    func testResolveCurrentBrainProjectionUsesResolverAndCommitsBrain() {
        let runtime = makeGenericRuntime()
        var committedProjection: String?
        var dirtyFlag = true
        var publishedNotice: String?
        var committedBrain: String?

        runtime.resolveCurrentBrainProjection(
            using: {
                BASAppleCurrentBrainProjectionRuntimeResult(
                    currentBrain: "resolved-brain",
                    projection: "resolved-projection",
                    refreshedProjection: true,
                    notice: "resolved current brain"
                )
            },
            commitProjection: { committedProjection = $0 },
            setProjectionDirty: { dirtyFlag = $0 },
            publishNotice: { publishedNotice = $0 },
            commitCurrentBrain: { committedBrain = $0 }
        )

        XCTAssertEqual(committedProjection, "resolved-projection")
        XCTAssertFalse(dirtyFlag)
        XCTAssertEqual(publishedNotice, "resolved current brain")
        XCTAssertEqual(committedBrain, "resolved-brain")
    }

    func testResolveAndActivateSessionUsesResolverAndCommitsSession() {
        let runtime = makeGenericRuntime()
        var loadedSession: [String] = []
        var committedProjection: String?
        var dirtyFlag = true
        var publishedNotice: String?
        var committedBrain: String?
        var committedSession: String?

        runtime.resolveAndActivateSession(
            session: "session",
            using: {
                BASAppleCurrentBrainProjectionRuntimeResult(
                    currentBrain: "brain",
                    projection: "projection",
                    refreshedProjection: true,
                    notice: "resolved activation"
                )
            },
            loadBrainState: { session, currentBrain in
                loadedSession = [session, currentBrain]
            },
            commitProjection: { committedProjection = $0 },
            setProjectionDirty: { dirtyFlag = $0 },
            publishNotice: { publishedNotice = $0 },
            commitCurrentBrain: { committedBrain = $0 },
            commitSession: { committedSession = $0 }
        )

        XCTAssertEqual(loadedSession, ["session", "brain"])
        XCTAssertEqual(committedProjection, "projection")
        XCTAssertFalse(dirtyFlag)
        XCTAssertEqual(publishedNotice, "resolved activation")
        XCTAssertEqual(committedBrain, "brain")
        XCTAssertEqual(committedSession, "session")
    }

    func testResolveProjectionRefreshFailureDoesNotCommitProjectionOrClearDirtyState() {
        let runtime = makeGenericRuntime()
        var committedProjection: String?
        var dirtyFlag = true
        var publishedNotice: String?

        XCTAssertThrowsError(
            try runtime.resolveProjectionRefresh(
                using: { throw ProjectionRefreshFailure.failed },
                commitProjection: { (projection: String) in committedProjection = projection },
                setProjectionDirty: { dirtyFlag = $0 },
                publishNotice: { publishedNotice = $0 }
            )
        )
        XCTAssertNil(committedProjection)
        XCTAssertTrue(dirtyFlag)
        XCTAssertNil(publishedNotice)
    }

    func testResolveCurrentBrainProjectionFailureDoesNotCommitProjectionOrBrain() {
        let runtime = makeGenericRuntime()
        var committedProjection: String?
        var dirtyFlag = true
        var committedBrain: String?

        XCTAssertThrowsError(
            try runtime.resolveCurrentBrainProjection(
                using: { throw ProjectionRefreshFailure.failed },
                commitProjection: { (projection: String) in committedProjection = projection },
                setProjectionDirty: { dirtyFlag = $0 },
                publishNotice: { _ in },
                commitCurrentBrain: { (brain: String) in committedBrain = brain }
            )
        )
        XCTAssertNil(committedProjection)
        XCTAssertTrue(dirtyFlag)
        XCTAssertNil(committedBrain)
    }

    func testResolveAndActivateSessionFailureDoesNotRunActivationOrCommitState() {
        let runtime = makeGenericRuntime()
        var actions: [String] = []
        var dirtyFlag = true

        XCTAssertThrowsError(
            try runtime.resolveAndActivateSession(
                session: "session",
                using: { throw ProjectionRefreshFailure.failed },
                loadBrainState: { (_: String, _: String) in actions.append("load") },
                commitProjection: { (_: String) in actions.append("projection") },
                setProjectionDirty: { dirtyFlag = $0 },
                publishNotice: { _ in actions.append("notice") },
                commitCurrentBrain: { (_: String) in actions.append("brain") },
                commitSession: { (_: String) in actions.append("session") }
            )
        )
        XCTAssertTrue(actions.isEmpty)
        XCTAssertTrue(dirtyFlag)
    }

    func testExecuteLifecyclePhaseFailureStopsCurrentBrainAndEntryConsumption() {
        let runtime = makeGenericRuntime()
        var actions: [String] = []

        XCTAssertThrowsError(
            try runtime.executeLifecyclePhase(
                .initialAppearance,
                refreshMemoryProjection: {
                    actions.append("projection")
                    throw ProjectionRefreshFailure.failed
                },
                refreshCurrentBrain: { actions.append("brain:\($0)") },
                presentPendingReflection: { actions.append("reflection") },
                consumeHandoff: { "handoff" },
                handleHandoff: { actions.append("handoff:\($0)") },
                consumePendingRequest: { "pending" },
                handlePendingRequest: { actions.append("pending:\($0)") },
                restoreActiveWorkspace: { actions.append("restore") },
                refreshPredictedIntervention: { actions.append("prediction") }
            )
        )
        XCTAssertEqual(actions, ["projection"])
    }

    func testReopenHeldItemAppliesFollowUpSuggestion() {
        let runtime = makeGenericRuntime()
        var actions: [String] = []
        var suggestion: BASAppleReopenInterventionSuggestion?

        runtime.reopenHeldItem(
            modeID: BASDecisionMode.comparative.rawValue,
            promptSeed: "Slow this choice down.",
            hasDraft: false,
            title: "Reopen carefully",
            detail: "High-risk reopen",
            riskLevelID: BASRiskLevel.high.rawValue,
            reopenHint: "Use more structure",
            templateHint: "Cooling template",
            interventionHistorySummary: "Past nighttime choices went worse.",
            clearActiveDecisionFlows: { actions.append("clear") },
            activatePrimaryFromDraft: { actions.append("draft-primary") },
            activateComparativeFromDraft: { actions.append("draft-comparative") },
            activateReflectiveFromDraft: { actions.append("draft-reflective") },
            startPrimary: { _ in actions.append("start-primary") },
            startComparative: { _ in actions.append("start-comparative") },
            startReflective: { _ in actions.append("start-reflective") },
            removeItem: { actions.append("remove") },
            applyInterventionSuggestion: { suggestion = $0; actions.append("suggest") },
            refreshPredictedIntervention: { actions.append("refresh") },
            selectHomeTab: { actions.append("home") },
            persistActiveWorkspaceState: { actions.append("persist") },
            now: .distantPast
        )

        XCTAssertEqual(actions, ["clear", "start-comparative", "remove", "suggest", "home", "persist"])
        XCTAssertEqual(suggestion?.title, "Use more structure")
        XCTAssertEqual(suggestion?.suggestedModeID, BASDecisionMode.comparative.rawValue)
    }

    func testRestoreActiveWorkspaceIfNeededRestoresMatchingMode() {
        let runtime = makeGenericRuntime()
        var actions: [String] = []

        runtime.restoreActiveWorkspaceIfNeeded(
            restoreEnabled: true,
            hasActivePrimaryWorkflow: false,
            hasActiveComparativeWorkflow: false,
            hasActiveReflectiveWorkflow: false,
            hasReflectionContext: false,
            loadState: { BASDecisionMode.reflectiveID },
            modeID: { $0 },
            restorePrimary: { _ in actions.append("primary") },
            restoreComparative: { _ in actions.append("comparative") },
            restoreReflective: { _ in actions.append("reflective") },
            selectHomeTab: { actions.append("home") },
            afterRestore: { actions.append("after") }
        )

        XCTAssertEqual(actions, ["reflective", "home", "after"])
    }

    func testRefreshActiveTaskGraphChoosesFirstAvailableSnapshot() {
        let runtime = makeGenericRuntime()
        var savedSnapshot: String?
        var cleared = false
        let snapshotLoaders: [() -> String?] = [
            { nil },
            { "comparative-snapshot" },
            { "reflective-snapshot" }
        ]

        let snapshot = runtime.refreshActiveTaskGraph(
            snapshotsInPriorityOrder: snapshotLoaders,
            saveSnapshot: { savedSnapshot = $0 },
            clearSnapshot: { cleared = true }
        )

        XCTAssertEqual(snapshot, "comparative-snapshot")
        XCTAssertEqual(savedSnapshot, "comparative-snapshot")
        XCTAssertFalse(cleared)
    }

    func testReconcilePredictiveInterventionKeepsExistingPresentationStable() {
        let runtime = makeGenericRuntime()
        let existing = BASApplePredictiveInterventionCandidateSummary(
            id: UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!,
            riskLevelID: BASRiskLevel.medium.rawValue,
            title: "Pause",
            detail: "Slow down",
            evidenceSignalCount: 2,
            preferredModeID: BASDecisionMode.reflective.rawValue,
            reason: "Recent signals say pause.",
            createdAt: .distantPast,
            expiresAt: .distantFuture
        )
        let next = BASApplePredictiveInterventionCandidateSummary(
            id: UUID(uuidString: "11111111-2222-3333-4444-555555555555")!,
            riskLevelID: BASRiskLevel.medium.rawValue,
            title: "Pause",
            detail: "Slow down",
            evidenceSignalCount: 2,
            preferredModeID: BASDecisionMode.reflective.rawValue,
            reason: "Recent signals say pause.",
            createdAt: .now,
            expiresAt: .distantFuture
        )

        let reconciled = runtime.reconcilePredictiveIntervention(
            existing: existing,
            next: next
        )

        XCTAssertEqual(reconciled?.id, existing.id)
    }

    func testExecutePredictiveInterventionDeliverySchedulesAllowedCandidate() {
        let runtime = makeGenericRuntime()
        let candidate = BASApplePredictiveInterventionCandidateSummary(
            id: UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!,
            riskLevelID: BASRiskLevel.high.rawValue,
            title: "Pause",
            detail: "Slow down",
            evidenceSignalCount: 3,
            preferredModeID: BASDecisionMode.reflective.rawValue,
            reason: "High-risk context",
            createdAt: .now,
            expiresAt: .distantFuture
        )
        var upserts: [(UUID, Bool)] = []
        var cancelled: [UUID] = []
        var scheduled: [UUID] = []

        runtime.executePredictiveInterventionDelivery(
            candidate: candidate,
            predictiveInterventionsEnabled: true,
            policyAllowed: true,
            upsertTrigger: { summary, wasDelivered in
                upserts.append((summary.id, wasDelivered))
            },
            cancelNotification: { cancelled.append($0) },
            scheduleNotification: { scheduled.append($0.id) }
        )

        XCTAssertEqual(upserts.count, 1)
        XCTAssertEqual(upserts.first?.0, candidate.id)
        XCTAssertEqual(upserts.first?.1, true)
        XCTAssertTrue(cancelled.isEmpty)
        XCTAssertEqual(scheduled, [candidate.id])
    }

    func testCustomCognitionBehaviorBelongsToHost() throws {
        let runtime = BASHostRuntime(
            configuration: makeConfiguration(
                cognitionBehavior: BASHostCognitionBehaviorConfiguration(
                    reactionWeightsByProfileID: [
                        BASHostWorkflowProfile.primary.rawValue: BASReactionWeights(
                            briefLanguage: 0.71,
                            warmDirectTone: 0.41,
                            lowCognitiveLoad: 0.68,
                            interruptiveActionBias: 0.63,
                            boundaryNamingBias: 0.22,
                            tradeoffClarityBias: 0.31
                        )
                    ],
                    identityProfilesByProfileID: [
                        BASHostWorkflowProfile.primary.rawValue: BASIdentityProfile(
                            role: .tradeoffGuide,
                            posture: .coaching,
                            initiative: .guided,
                            confidenceCeiling: 0.67,
                            canAdvise: true,
                            canExecuteActions: false,
                            canEscalateToCloud: false,
                            relationshipBoundary: "Host rapid role."
                        )
                    ],
                    substrateBehavior: BASCognitionBehavior(
                        surfaceIdentityOverlaysBySurfaceID: [
                            BASInteractionSurface.notification.rawValue: BASIdentityProfileOverlay(
                                role: .boundedGuide,
                                posture: .coaching,
                                initiative: .passive,
                                confidenceCeiling: 0.5,
                                relationshipBoundary: "Host notification relationship."
                            )
                        ],
                        highRiskIdentityOverlay: BASIdentityProfileOverlay(
                            posture: .protective,
                            initiative: .guided,
                            confidenceCeiling: 0.52,
                            relationshipBoundary: "Host high-risk relationship."
                        ),
                        highRiskInitiativeByRoleID: [:],
                        boundary: BASBoundaryEvaluationBehavior(
                            defaultAllowedActionClasses: ["host_render"],
                            defaultBlockedActionClasses: ["host_cloud"],
                            defaultConstraints: [.lockSensitiveMemory],
                            allowedActionClassesBySurfaceID: [
                                BASInteractionSurface.notification.rawValue: ["host_notification_lane"]
                            ],
                            blockedActionClassesBySurfaceID: [
                                BASInteractionSurface.notification.rawValue: ["host_notification_spam"]
                            ],
                            constraintsBySurfaceID: [
                                BASInteractionSurface.notification.rawValue: [.notificationRequiresEvidence]
                            ],
                            highRiskRequiredConfirmations: ["host_confirm"],
                            highRiskBlockedActionClasses: ["host_fast_commit"],
                            reflectiveModeIDs: [],
                            advisoryHeadline: "Host advisory.",
                            reflectiveHeadline: "Host reflective.",
                            protectiveHeadline: "Host protective."
                        )
                    )
                )
            )
        )

        let result = try runtime.startSession(
            BASHostSessionRequest(
                kind: .notification,
                workflowProfile: .primary,
                surface: .notification,
                prompt: "Host wants a slower notification path.",
                riskLevel: .high
            )
        )

        XCTAssertEqual(result.currentBrain.workflowProfile, .primary)
        XCTAssertEqual(result.currentBrain.roleID, BASIdentityRole.boundedGuide.rawValue)
        XCTAssertEqual(result.currentBrain.identityPosture, .protective)
        XCTAssertEqual(result.currentBrain.identityInitiative, .guided)
        XCTAssertEqual(result.currentBrain.confidenceCeiling, 0.52, accuracy: 0.0001)
        XCTAssertEqual(result.currentBrain.relationshipBoundary, "Host high-risk relationship.")
        XCTAssertTrue(result.currentBrain.boundaryHeadline.contains("Host protective."))
        XCTAssertTrue(result.currentBrain.boundaryHeadline.contains("confirm high_risk_confirmation"))
        XCTAssertTrue(result.currentBrain.boundaryHeadline.contains("no-go private-sdk"))
        XCTAssertEqual(result.currentBrain.boundaryMode, .localOnlyProtective)
        XCTAssertTrue(result.currentBrain.boundaryConstraints.contains(.notificationRequiresEvidence))
        XCTAssertTrue(result.currentBrain.calibrationAlerts.isEmpty || result.currentBrain.calibrationStatus != .stable || !result.currentBrain.riskFlags.isEmpty)
        XCTAssertTrue([.replace, .block].contains(result.eBrainTurn?.actionPermit.mode))
        XCTAssertEqual(result.eBrainTurn?.thoughtFold.compactSlots["host_version"], "host.v1")
        XCTAssertNotNil(result.interventionSuggestion)
    }

    func testHighRiskTurnSurfacesStructuredTriSelfVetoReasons() throws {
        let runtime = BASHostRuntime(
            configuration: makeConfiguration(
                cognitionBehavior: BASHostCognitionBehaviorConfiguration(
                    substrateBehavior: BASCognitionBehavior(
                        highRiskIdentityOverlay: BASIdentityProfileOverlay(
                            posture: .protective,
                            initiative: .guided,
                            confidenceCeiling: 0.52,
                            relationshipBoundary: "Protect the boundary under high pressure."
                        )
                    )
                )
            )
        )

        let result = try runtime.startSession(
            BASHostSessionRequest(
                kind: .interactive,
                workflowProfile: .primary,
                surface: .application,
                prompt: "Send the direct answer right now.",
                riskLevel: .high
            )
        )
        let turn = try XCTUnwrap(result.eBrainTurn)
        let surfaceGuide = try XCTUnwrap(turn.renderedOutput.surfaceGuide)
        let courtDecisionDraft = try XCTUnwrap(turn.mergedChoice.courtDecisionDraft)
        let agencyReservation = try XCTUnwrap(turn.mergedChoice.agencyReservation)
        let remandTargets = try XCTUnwrap(turn.mergedChoice.remandOrders?.map(\.targetLayer))
        let updateTicket = try XCTUnwrap(turn.updateTickets.first)
        let orchestrationReport = try XCTUnwrap(
            result.consoleSnapshot.reports.first(where: { $0.kind == .orchestration })
        )
        let deliveryReport = try XCTUnwrap(
            result.consoleSnapshot.reports.first(where: { $0.kind == .delivery })
        )
        let evaluationReport = try XCTUnwrap(
            result.consoleSnapshot.reports.first(where: { $0.kind == .evaluation })
        )

        let encodedSurfaceGuide = try JSONEncoder().encode(surfaceGuide)
        let surfaceGuideObject = try XCTUnwrap(
            JSONSerialization.jsonObject(with: encodedSurfaceGuide) as? [String: Any]
        )
        let disclosureObject = try XCTUnwrap(surfaceGuideObject["disclosure"] as? [String: Any])
        let agencyObject = try XCTUnwrap(surfaceGuideObject["agency"] as? [String: Any])

        XCTAssertTrue(turn.mergedChoice.vetoApplied)
        XCTAssertTrue(turn.triScores.contains(where: { $0.candidateID == "path.direct" && $0.veto }))
        XCTAssertTrue(
            [
                "triself.superego_veto",
                "triself.high_risk_direct_path",
                "triself.protective_boundary"
            ].allSatisfy(turn.mergedChoice.vetoReasonCodes.contains)
        )
        XCTAssertTrue(turn.renderedOutput.explanationCodes.contains("triself.superego_veto"))
        XCTAssertTrue(turn.renderedOutput.explanationCodes.contains("triself.high_risk_direct_path"))
        XCTAssertTrue(turn.renderedOutput.explanationCodes.contains("triself.protective_boundary"))
        XCTAssertTrue(turn.renderedOutput.explanationCodes.contains("agency.delay_right"))
        XCTAssertTrue(turn.renderedOutput.explanationCodes.contains("court.remand.pending"))
        XCTAssertTrue(result.consoleSnapshot.runtimeSummary?.contains("dream guardTakeover") == true)
        XCTAssertTrue(result.consoleSnapshot.brainSummary?.contains("dream guardTakeover") == true)
        XCTAssertEqual(surfaceGuide.agency.reservationMode, .delayRight)
        XCTAssertEqual(surfaceGuide.disclosure.requiredDisclosures, courtDecisionDraft.requiredDisclosures)
        XCTAssertEqual(
            turn.renderedOutput.headline,
            "Let the guard branch lead before release"
        )
        XCTAssertTrue(
            turn.renderedOutput.body.localizedCaseInsensitiveContains("not ready")
        )
        XCTAssertTrue(
            turn.renderedOutput.body.localizedCaseInsensitiveContains("blocking direct release")
        )
        XCTAssertTrue(
            turn.renderedOutput.body.localizedCaseInsensitiveContains("guard branch became the safer lead")
        )
        XCTAssertTrue(
            turn.renderedOutput.body.localizedCaseInsensitiveContains("minimal")
        )
        XCTAssertEqual(
            turn.renderedOutput.alternativeActions.first,
            "Follow the guard branch and keep the move reversible."
        )
        XCTAssertTrue(
            turn.renderedOutput.alternativeActions.contains(where: {
                $0.localizedCaseInsensitiveContains("delayed")
            })
        )
        XCTAssertTrue(
            turn.renderedOutput.alternativeActions.contains(where: {
                $0.localizedCaseInsensitiveContains("bounded alternative")
            })
        )
        XCTAssertTrue(
            turn.renderedOutput.alternativeActions.contains(where: {
                courtDecisionDraft.requiredDisclosures.contains($0)
            })
        )
        XCTAssertEqual(
            disclosureObject["requiredDisclosures"] as? [String],
            courtDecisionDraft.requiredDisclosures
        )
        XCTAssertEqual(
            disclosureObject["unresolvedCosts"] as? [String],
            courtDecisionDraft.unresolvedCosts
        )
        XCTAssertEqual(
            disclosureObject["remandTargets"] as? [String],
            remandTargets
        )
        XCTAssertEqual(
            agencyObject["reservationMode"] as? String,
            agencyReservation.mode.rawValue
        )
        XCTAssertTrue(updateTicket.derivedCandidateRefs.contains(turn.mergedChoice.candidateID))
        XCTAssertTrue(
            courtDecisionDraft.fallbackCandidateIDs.allSatisfy { updateTicket.derivedCandidateRefs.contains($0) }
        )
        XCTAssertTrue(updateTicket.governanceRefs.contains("agency:\(agencyReservation.mode.rawValue)"))
        XCTAssertTrue(updateTicket.governanceRefs.contains("remand:L9"))
        XCTAssertTrue(updateTicket.governanceRefs.contains("court:\(courtDecisionDraft.readinessLevel)"))
        XCTAssertTrue(updateTicket.governanceRefs.contains("veto:path.direct:boundary"))
        XCTAssertTrue(updateTicket.governanceRefs.contains("dream_loop:guardTakeover"))
        XCTAssertTrue(updateTicket.governanceRefs.contains("dream_loop:evidence_debt"))
        XCTAssertTrue(updateTicket.governanceRefs.contains("dream_loop:delay_branch"))
        XCTAssertEqual(
            turn.evolutionLineageSummary.governanceSummary?.dreamLoopStoppingMode,
            "guardTakeover"
        )
        XCTAssertEqual(
            turn.evolutionLineageSummary.governanceSummary?.dreamLoopReservationMode,
            "delayRight"
        )
        XCTAssertTrue(
            turn.evolutionLineageSummary.governanceSummary?.dreamLoopSignalRefs.contains("dream_loop:guardTakeover") == true
        )
        XCTAssertTrue(
            turn.evolutionLineageSummary.governanceSummary?.dreamLoopSignalRefs.contains("dream_loop:evidence_debt") == true
        )
        XCTAssertTrue(
            turn.evolutionLineageSummary.governanceSummary?.dreamLoopRemandTargets.contains("L9") == true
        )
        XCTAssertTrue(
            (turn.evolutionLineageSummary.governanceSummary?.dreamLoopMaxEvidenceDebtPercent ?? 0) >= 50
        )
        XCTAssertTrue(orchestrationReport.summary.contains("convergence guardTakeover"))
        XCTAssertTrue(deliveryReport.summary.contains("dream guardTakeover"))
        XCTAssertTrue(evaluationReport.summary.contains("dream guardTakeover"))
        XCTAssertEqual(
            turn.evolutionLineageSummary.reviewDirectiveLine,
            "Review memory write: Keep this turn in review before any warm or cold promotion. • conflict flagged"
        )
        XCTAssertTrue(
            result.consoleSnapshot.inspectionBundle?.trace.auditEvents.contains(where: {
                $0.category == "L9"
                && $0.message.contains("convergence guardTakeover")
            }) == true
        )
        XCTAssertTrue(
            result.consoleSnapshot.inspectionBundle?.trace.auditEvents.contains(where: {
                $0.category == "L12"
                && $0.message.contains("guardTakeover")
            }) == true
        )
        XCTAssertTrue(
            result.consoleSnapshot.inspectionBundle?.trace.auditEvents.contains(where: {
                $0.category == "L13"
                && $0.message.contains("guardTakeover")
            }) == true
        )
        XCTAssertTrue(
            turn.runtimeTrace.layerEvents.contains(where: {
                $0.layerID == "L10"
                && $0.detail.contains("triself.high_risk_direct_path")
                && $0.detail.contains("triself.protective_boundary")
                && $0.detail.contains("delayRight")
                && $0.detail.contains("L9")
            })
        )
        XCTAssertTrue(
            turn.runtimeTrace.layerEvents.contains(where: {
                $0.layerID == "L11"
                && !$0.detail.isEmpty
            })
        )
        XCTAssertTrue(
            turn.runtimeTrace.layerEvents.contains(where: {
                $0.layerID == "L13"
                && $0.detail.contains("review 1")
                && $0.detail.contains("conflicts 1")
            })
        )
    }

    func testRenderedOutputDeliveryFallbackGuidanceUsesSurfaceGuideDelayWhenAlternativesAreEmpty() {
        let output = BASRenderedOutput(
            mode: .answer,
            headline: "Pause the release",
            body: "A fast answer exists, but the safer move is to cool this down first.",
            alternativeActions: [],
            explanationCodes: ["risk.high"],
            surfaceGuide: BASRenderedSurfaceGuide(
                stackedModes: [],
                tonePolicy: "clear_firm",
                templatePolicy: "protective_alternative",
                outputLengthCap: 120,
                boundary: BASRenderedBoundaryGuide(
                    allowedDomains: ["bounded_reply"],
                    blockedDomains: ["tool_commit"],
                    toolScope: "bounded",
                    memoryScope: "standard",
                    escalationHintRef: nil
                ),
                agency: BASRenderedAgencyGuide(
                    requiresCompare: false,
                    requiresSecondCheck: true,
                    delayAvailable: true,
                    chooseLaterAllowed: true,
                    prefersDraftOnly: false,
                    localOnlyPreferred: false,
                    reservationMode: nil
                ),
                disclosure: BASRenderedDisclosureGuide(
                    assertionCeiling: "guarded",
                    explanationCodes: ["risk.high"],
                    uncertaintyVisible: true,
                    requiredDisclosures: nil,
                    unresolvedCosts: nil,
                    remandTargets: nil
                ),
                delayWindow: "cool_down",
                delayReservation: BASDelayReservation(
                    reservationID: "delay.surface.only",
                    delayType: "cool_down",
                    minDelay: 15,
                    maxDelay: 120,
                    allowedIntermediateActions: ["compare", "draft_only"]
                ),
                protectiveSubstitute: nil,
                sovereignEscalationHint: nil
            )
        )

        XCTAssertEqual(
            output.deliveryFallbackGuidance,
            "Take a cool-down window before deciding."
        )
    }

    func testRenderedOutputDeliveryFallbackActionLineUsesSurfaceGuideWhenAlternativesAreEmpty() {
        let output = BASRenderedOutput(
            mode: .delay,
            headline: "Pause first",
            body: "Mirror body",
            alternativeActions: [],
            explanationCodes: ["risk.high"],
            surfaceGuide: BASRenderedSurfaceGuide(
                stackedModes: [.draftOnly],
                tonePolicy: "clear_firm",
                templatePolicy: "protective_alternative",
                outputLengthCap: 120,
                boundary: BASRenderedBoundaryGuide(
                    allowedDomains: ["draft.note"],
                    blockedDomains: ["host.write"],
                    toolScope: "bounded",
                    memoryScope: "standard",
                    escalationHintRef: nil
                ),
                agency: BASRenderedAgencyGuide(
                    requiresCompare: false,
                    requiresSecondCheck: true,
                    delayAvailable: true,
                    chooseLaterAllowed: true,
                    prefersDraftOnly: true,
                    localOnlyPreferred: false,
                    reservationMode: nil
                ),
                disclosure: BASRenderedDisclosureGuide(
                    assertionCeiling: "guarded",
                    explanationCodes: ["risk.high"],
                    uncertaintyVisible: true,
                    requiredDisclosures: nil,
                    unresolvedCosts: nil,
                    remandTargets: nil
                ),
                delayWindow: nil,
                delayReservation: nil,
                protectiveSubstitute: BASProtectiveSubstitute(
                    substituteID: "substitute.surface.only",
                    sourceCandidateRef: "cand-1",
                    substituteType: "draft",
                    description: "Draft but do not send yet.",
                    safetyGain: 0.82
                ),
                sovereignEscalationHint: nil
            )
        )

        XCTAssertEqual(
            output.deliveryFallbackActionLine,
            "action: Draft but do not send yet."
        )
    }

    func testHighRiskBlockRenderSurfacesEscalationAndAssertionGuidance() throws {
        let runtime = BASHostRuntime(configuration: makeConfiguration())
        let request = BASHostSessionRequest(
            kind: .interactive,
            workflowProfile: .primary,
            surface: .application,
            prompt: "Send the direct answer right now.",
            title: "High-risk block render",
            riskLevel: .high
        )
        let seedResult = try runtime.startSession(request)
        var currentBrain = seedResult.currentBrain
        currentBrain.boundaryMode = .localOnlyAdvisory

        let turn = runtime.buildEBrainTurn(
            request: request,
            currentBrain: currentBrain,
            projection: BASBrainProjection(records: [], candidates: [], recentEvents: [])
        )

        XCTAssertEqual(turn.actionPermit.mode, .block)
        XCTAssertTrue(turn.actionPermit.stackedModes.contains(.escalate))
        XCTAssertEqual(turn.actionPermit.assertionCeiling, "minimal")
        XCTAssertTrue(
            turn.renderedOutput.body.localizedCaseInsensitiveContains("minimal")
        )
        XCTAssertTrue(
            turn.renderedOutput.alternativeActions.contains("Pause release and request a higher-order check.")
        )
        XCTAssertTrue(
            turn.renderedOutput.alternativeActions.contains("Use the safer bounded alternative first.")
        )
        XCTAssertTrue(
            turn.renderedOutput.alternativeActions.contains("Get a second confirmation before release.")
        )
    }

    func testBootstrapThrowsTypedErrorWhenHostOmitsSessionDefaults() {
        let runtime = BASHostRuntime(
            configuration: makeConfiguration(
                workflowBehavior: BASHostWorkflowBehaviorConfiguration(
                    defaultMemorySourceIDsBySessionKindID: [:],
                    defaultRetrievalModeIDsBySessionKindID: [:]
                )
            )
        )

        XCTAssertThrowsError(
            try runtime.bootstrap(
                BASHostLifecycleRequest(
                    phase: .initialAppearance,
                    sessionKind: .ambient,
                    preferredProfile: .primary,
                    sourceSurface: .application,
                    promptSeed: "Host omitted ambient routing.",
                    riskLevel: .low
                )
            )
        ) { error in
            XCTAssertEqual(
                error as? BASHostIntegrationError,
                .missingSessionKindMemorySource(kindID: BASHostSessionKind.ambient.rawValue)
            )
        }
    }

    func testRuntimeGovernanceHelpersApplyL5ConstitutionSemantics() {
        let runtime = makeGenericRuntime()
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
            proposedDelta: ["goal_spine", "goal_spine", "boundary_veil"],
            evidenceRefs: ["memory.turn.12"],
            cooldownUntil: Date(timeIntervalSince1970: 1_700_000_000),
            confidence: 0.91,
            conflictRefs: ["boundary.review"],
            previewState: "preview",
            approvalState: "approved"
        )
        let versionTree = BASHostVersionTree(
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
            pendingCandidateIDs: ["candidate.goal.v2"],
            frozenVersionIDs: ["constitution.v0"]
        )
        let forgetRequest = BASForgetRequest(
            requestID: "forget.v1",
            targetRefs: ["memory.turn.12"],
            cascadeScope: ["active_version", "projection_cache", "memory_refs", "checkpoints", "sync"],
            executedSteps: ["active_version_removed"],
            verified: false
        )

        let staged = runtime.stageHostConstitutionChange(candidate, on: constitution)
        let approved = runtime.approveHostConstitutionChange(candidate, on: versionTree)
        let rolledBackMissing = runtime.rollbackHostConstitutionVersionTree(approved, to: "missing.version")
        let forgetExecuted = runtime.executeHostForget(forgetRequest, on: constitution)

        XCTAssertEqual(staged.narrativeLoom.currentPhase, "preview")
        XCTAssertTrue(staged.narrativeLoom.continuityLinks.contains("constitution.v1->candidate.goal.v2"))
        XCTAssertTrue(staged.narrativeLoom.unresolvedTensions.contains("candidate:candidate.goal.v2"))
        XCTAssertEqual(approved.activeVersionID, "candidate.goal.v2")
        XCTAssertTrue(approved.pendingCandidateIDs.isEmpty)
        XCTAssertEqual(
            approved.versions.first(where: { $0.versionID == "candidate.goal.v2" })?.changedFields,
            ["goal_spine", "boundary_veil"]
        )
        XCTAssertEqual(rolledBackMissing.activeVersionID, "candidate.goal.v2")
        XCTAssertTrue(forgetExecuted.verified)
        XCTAssertTrue(forgetExecuted.executedSteps.contains("sync_exports_revoked"))
    }

    func testRuntimeGovernanceHelpersCanFreezeAndThawHostVersions() {
        let runtime = makeGenericRuntime()
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

        let frozen = runtime.freezeHostConstitutionVersionTree(versionTree, versionID: "constitution.v1")
        let thawed = runtime.thawHostConstitutionVersionTree(frozen, versionID: "constitution.v1")

        XCTAssertEqual(frozen.frozenVersionIDs, ["constitution.v1"])
        XCTAssertTrue(runtime.freezeHostConstitutionVersionTree(frozen, versionID: "constitution.v2").frozenVersionIDs == ["constitution.v1"])
        XCTAssertTrue(thawed.frozenVersionIDs.isEmpty)
        XCTAssertEqual(runtime.rollbackHostConstitutionVersionTree(thawed, to: "constitution.v1").activeVersionID, "constitution.v1")
    }

    func testRuntimeGovernanceHelpersDriveVaultMigrationLifecycle() {
        let runtime = makeGenericRuntime()
        let constitution = BASHostConstitution(
            hostID: "host.constitution",
            activeVersion: "constitution.v2",
            consentLattice: BASConsentLattice(
                syncScope: "approved_sync"
            )
        )
        let vault = constitution.vaultSnapshot(
            sourceDeviceID: "device.primary",
            trustedDeviceIDs: ["device.primary"]
        )
        let contract = BASHostDeviceMigrationContract(
            sourceDeviceID: "device.primary",
            targetDeviceID: "device.secondary",
            allowedScopes: ["constitution_snapshot"],
            requiresExplicitApproval: true,
            rollbackVersionID: "constitution.v1"
        )

        let staged = runtime.stageHostConstitutionMigration(contract, on: vault)
        let approved = runtime.approveHostConstitutionMigration(staged, targetDeviceID: "device.secondary")
        let synchronized = runtime.synchronizeHostConstitutionVault(
            approved,
            deviceID: "device.secondary"
        )

        XCTAssertEqual(staged.deviceConsistencyReport.consistencyState, "migration_pending")
        XCTAssertTrue(staged.verificationMarkers.contains("vault_migration_target:device.secondary"))
        XCTAssertEqual(approved.deviceConsistencyReport.consistencyState, "out_of_sync")
        XCTAssertEqual(synchronized.deviceConsistencyReport.consistencyState, "consistent")
        XCTAssertTrue(synchronized.deviceConsistencyReport.trustedDeviceIDs.contains("device.secondary"))
        XCTAssertTrue(synchronized.deviceConsistencyReport.outOfSyncDeviceIDs.isEmpty)
        XCTAssertNil(synchronized.migrationContract)
        XCTAssertFalse(synchronized.verificationMarkers.contains("vault_migration_target:device.secondary"))
    }

    func testRuntimeSurfacedOutOfSyncVaultDevicesIntoTurnConsoleAndTrace() throws {
        let constitution = BASHostConstitution(
            hostID: "host.constitution",
            activeVersion: "constitution.v10",
            narrativeLoom: BASNarrativeLoom(
                longFormSummary: "Migration still blocked on external devices.",
                currentPhase: "migration"
            )
        )
        let vault = constitution
            .vaultSnapshot(
                sourceDeviceID: "device.primary",
                trustedDeviceIDs: ["device.primary"]
            )
            .recordingConsistency(
                BASHostDeviceConsistencyReport(
                    sourceDeviceID: "device.primary",
                    trustedDeviceIDs: ["device.primary"],
                    outOfSyncDeviceIDs: ["device.secondary", "device.tablet"],
                    consistencyState: "out_of_sync",
                    requiresExplicitApproval: false
                ),
                migrationContract: BASHostDeviceMigrationContract(
                    sourceDeviceID: "device.primary",
                    targetDeviceID: "device.secondary",
                    allowedScopes: ["constitution_snapshot"],
                    requiresExplicitApproval: false,
                    rollbackVersionID: "constitution.v9"
                )
            )
        let runtime = BASHostRuntime(
            configuration: makeConfiguration(
                hostConstitution: constitution,
                hostConstitutionVault: vault
            )
        )

        let result = try runtime.startSession(
            BASHostSessionRequest(
                kind: .interactive,
                workflowProfile: .comparative,
                surface: .application,
                prompt: "Keep the vault migration visible.",
                title: "Vault migration visibility",
                riskLevel: .medium
            )
        )

        XCTAssertEqual(
            result.eBrainTurn?.thoughtFold.compactSlots["vault_out_of_sync_list"],
            "device.secondary,device.tablet"
        )
        XCTAssertTrue(result.currentBrain.retrievalTags.contains("vault_out_of_sync_list:device.secondary,device.tablet"))
        XCTAssertTrue(result.currentBrain.verificationSummary.contains("vault_out_of_sync_list:device.secondary,device.tablet"))
        XCTAssertTrue(result.consoleSnapshot.brainSummary?.contains("device.secondary") == true)
        XCTAssertTrue(result.consoleSnapshot.brainSummary?.contains("device.tablet") == true)
        XCTAssertTrue(result.eBrainTurn?.runtimeTrace.layerEvents.contains(where: {
            $0.layerID == "L5" && $0.detail.contains("device.secondary") && $0.detail.contains("device.tablet")
        }) ?? false)
    }

    func testProvidedHostConstitutionVaultReconcilesForgetAndVersionTreeBeforeTurnBuild() throws {
        let constitution = BASHostConstitution(
            hostID: "host.constitution",
            activeVersion: "constitution.v2",
            consentLattice: BASConsentLattice(
                syncScope: "approved_sync"
            )
        )
        let staleVault = BASHostConstitution(
            hostID: "host.constitution",
            activeVersion: "constitution.v1",
            consentLattice: BASConsentLattice(
                syncScope: "approved_sync"
            )
        ).vaultSnapshot(
            sourceDeviceID: "device.primary",
            trustedDeviceIDs: ["device.primary"]
        )
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
        let forgetRequest = BASForgetRequest(
            requestID: "forget.sync.v2",
            targetRefs: ["memory.private_notes"],
            cascadeScope: ["sync"],
            executedSteps: ["sync_exports_revoked"],
            verified: true
        )
        let runtime = BASHostRuntime(
            configuration: makeConfiguration(
                hostConstitution: constitution,
                hostConstitutionVault: staleVault,
                hostVersionTree: versionTree,
                hostForgetRequest: forgetRequest
            )
        )

        let result = try runtime.startSession(
            BASHostSessionRequest(
                kind: .interactive,
                workflowProfile: .primary,
                surface: .application,
                prompt: "Keep the constitution aligned.",
                riskLevel: .low
            )
        )

        XCTAssertEqual(result.eBrainTurn?.hostConstitutionVault?.constitutionSnapshot.activeVersion, "constitution.v2")
        XCTAssertEqual(result.eBrainTurn?.hostConstitutionVault?.rollbackLineage, ["constitution.v1", "constitution.v2"])
        XCTAssertEqual(result.eBrainTurn?.hostConstitutionVault?.deletionManifest?.requestID, "forget.sync.v2")
    }

    func testContextAnalysisBuildsPresenceSpineForHighPressureManipulationScenario() throws {
        let runtime = BASHostRuntime(
            configuration: makeConfiguration(
                hostConstitution: BASHostConstitution(
                    hostID: "host.presence",
                    activeVersion: "constitution.presence.v1",
                    goalSpine: BASGoalSpine(
                        goals: ["Avoid irreversible escalation"],
                        priorityOrder: ["Protect long-term trust"],
                        stageState: "high_stakes"
                    ),
                    relationGravity: BASRelationGravityMap(
                        highConsequenceLinks: ["manager"]
                    ),
                    narrativeLoom: BASNarrativeLoom(
                        currentPhase: "work_conflict"
                    )
                )
            )
        )

        let result = try runtime.startSession(
            BASHostSessionRequest(
                kind: .reopen,
                workflowProfile: .primary,
                surface: .application,
                prompt: "My manager said send it now or explain yourself. Write the reply right now.",
                riskLevel: .high
            )
        )

        let contextFrame = try XCTUnwrap(result.eBrainTurn?.contextFrame)
        XCTAssertEqual(contextFrame.taskType, .manipulationRisk)
        XCTAssertTrue(contextFrame.relationPattern.contains("high_consequence:manager"))
        XCTAssertGreaterThan(contextFrame.timePressure, 0.6)
        XCTAssertGreaterThan(contextFrame.consequenceLevel, 0.6)
        XCTAssertTrue(contextFrame.manipulationHints.contains("time_pressure"))
        XCTAssertTrue(contextFrame.manipulationHints.contains("authority_pressure"))
        XCTAssertGreaterThan(contextFrame.hostRelevance, 0.5)
    }

    func testContextAnalysisSurfacesStructuredPresenceSidecarsForHighPressureManipulationScenario() throws {
        let runtime = BASHostRuntime(
            configuration: makeConfiguration(
                hostConstitution: BASHostConstitution(
                    hostID: "host.presence.sidecars",
                    activeVersion: "constitution.presence.sidecars.v1",
                    goalSpine: BASGoalSpine(
                        goals: ["Avoid irreversible escalation", "Protect long-term trust"],
                        priorityOrder: ["Protect long-term trust", "Avoid irreversible escalation"],
                        stageState: "high_stakes"
                    ),
                    relationGravity: BASRelationGravityMap(
                        highConsequenceLinks: ["manager"]
                    ),
                    narrativeLoom: BASNarrativeLoom(
                        currentPhase: "work_conflict"
                    )
                )
            )
        )

        let turn = try XCTUnwrap(
            runtime.startSession(
                BASHostSessionRequest(
                    kind: .reopen,
                    workflowProfile: .primary,
                    surface: .application,
                    prompt: "My manager said send it now or explain yourself. Write the reply right now.",
                    riskLevel: .high
                )
            ).eBrainTurn
        )

        let contextFrame = turn.contextFrame
        XCTAssertEqual(contextFrame.sceneType, .highPressureConflict)
        XCTAssertEqual(contextFrame.roleGeometry?.relationClass, "manager")
        XCTAssertTrue(contextFrame.roleGeometry?.asymmetryFlags.contains("high_consequence_relation") == true)
        XCTAssertEqual(contextFrame.powerGradient?.direction, "external_over_host")
        XCTAssertGreaterThan(contextFrame.powerGradient?.strength ?? 0, 0.6)
        XCTAssertGreaterThan(contextFrame.urgencyTruth?.statedUrgency ?? 0, 0.7)
        XCTAssertEqual(contextFrame.urgencyTruth?.canDelay, false)
        XCTAssertTrue(contextFrame.manipulationTrace?.signals.contains("time_pressure") == true)
        XCTAssertTrue(contextFrame.hostResonance?.highConsequenceRelationRefs.contains("manager") == true)
        XCTAssertEqual(contextFrame.routeHint?.preferredMode, "guarded")
        XCTAssertEqual(contextFrame.routeHint?.needGuard, true)
        XCTAssertGreaterThan(contextFrame.confidenceBand ?? 0, 0.5)
    }

    func testPresenceSidecarsFeedRiskCalibrationAndGSI() throws {
        let runtime = BASHostRuntime(
            configuration: makeConfiguration(
                hostConstitution: BASHostConstitution(
                    hostID: "host.presence.risk",
                    activeVersion: "constitution.presence.risk.v1",
                    goalSpine: BASGoalSpine(
                        goals: ["Avoid irreversible escalation", "Protect long-term trust"],
                        priorityOrder: ["Protect long-term trust", "Avoid irreversible escalation"],
                        stageState: "high_stakes"
                    ),
                    relationGravity: BASRelationGravityMap(
                        highConsequenceLinks: ["manager"]
                    ),
                    narrativeLoom: BASNarrativeLoom(
                        currentPhase: "work_conflict"
                    )
                )
            )
        )

        let turn = try XCTUnwrap(
            runtime.startSession(
                BASHostSessionRequest(
                    kind: .reopen,
                    workflowProfile: .primary,
                    surface: .application,
                    prompt: "My manager said send it now or explain yourself. Write the reply right now.",
                    riskLevel: .high
                )
            ).eBrainTurn
        )

        XCTAssertTrue(turn.riskCard.factors.contains("presence_power_gradient"))
        XCTAssertTrue(turn.riskCard.factors.contains("presence_urgency_locked"))
        XCTAssertTrue(turn.riskCard.factors.contains("presence_manipulation_trace"))
        XCTAssertTrue(turn.riskCard.factors.contains("presence_route_guard"))
        XCTAssertGreaterThan(turn.riskCard.gsiScore, 0.5)
        XCTAssertGreaterThan(turn.riskCard.manipulationStrength, 0.5)
    }

    func testDecomposeFramePublishesStructuredMirrorBladeSignalsToRuntimeSurfaces() throws {
        let runtime = BASHostRuntime(
            configuration: makeConfiguration(
                hostConstitution: BASHostConstitution(
                    hostID: "host.l7",
                    activeVersion: "constitution.l7.v1",
                    goalSpine: BASGoalSpine(
                        goals: ["Avoid irreversible escalation", "Protect long-term trust"],
                        priorityOrder: ["Protect long-term trust", "Avoid irreversible escalation"],
                        stageState: "high_stakes"
                    ),
                    relationGravity: BASRelationGravityMap(
                        highConsequenceLinks: ["manager"]
                    ),
                    narrativeLoom: BASNarrativeLoom(
                        currentPhase: "work_conflict"
                    )
                )
            )
        )

        let turn = try XCTUnwrap(
            runtime.startSession(
                BASHostSessionRequest(
                    kind: .reopen,
                    workflowProfile: .primary,
                    surface: .application,
                    prompt: "My manager said send it now or explain yourself. Write the reply right now.",
                    detail: "I do not know which facts are solid yet, but the pressure is immediate.",
                    riskLevel: .high
                )
            ).eBrainTurn
        )

        XCTAssertFalse(turn.decomposeFrame.facts.isEmpty)
        XCTAssertFalse(turn.decomposeFrame.goals.isEmpty)
        XCTAssertFalse(turn.decomposeFrame.unknowns.isEmpty)
        XCTAssertFalse(turn.decomposeFrame.pressureSignals.isEmpty)
        XCTAssertTrue(turn.decomposeFrame.pressureSignals.contains("time_pressure"))
        XCTAssertFalse(turn.decomposeFrame.manipulationSignals.isEmpty)
        XCTAssertTrue(turn.decomposeFrame.manipulationSignals.contains("authority_pressure"))
        XCTAssertFalse(turn.decomposeFrame.mirrorText.isEmpty)
        XCTAssertTrue(turn.runtimeTrace.layerEvents.contains(where: {
            $0.layerID == "L7"
                && $0.detail.contains("facts")
                && $0.detail.contains("unknowns")
        }))
    }

}
