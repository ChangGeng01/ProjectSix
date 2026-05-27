import Testing
@testable import BASAppleAdapters
@testable import BASMemory
@testable import BASObservability
@testable import BASOrchestration
@testable import BASPolicy
@testable import BASRuntimeCore

#if !os(iOS)  // ch 1022 source-gate: SwiftTesting iOS bundle discovery quirk
@Suite("BASApple Observability Adapter")
struct BASAppleObservabilityAdapterTests {
    @Test("trace compilation redacts live payloads outside testing context and builds canonical execution trace")
    func traceCompilationSanitizesAndBuildsExecutionTrace() {
        let compilation = BASAppleObservabilityAdapter.compileProviderTrace(
            from: BASAppleProviderTraceInput(
                environment: [:],
                considerRuntimeTestingContext: false,
                runtimeTestingContextDetected: false,
                testingOverridePresent: false,
                kind: "primary",
                preferredProviderID: "gemmaE4B",
                activeProviderID: "foundationModels",
                attemptedProviderIDs: ["gemmaE4B", "foundationModels"],
                allowFallbacks: true,
                prompt: "Sensitive runtime prompt",
                outputPreview: "Sensitive preview",
                detail: "Provider succeeded without fallback.",
                semanticPromptFingerprint: "semantic-1",
                stablePrefixFingerprint: "prefix-1",
                promptBudget: BASPromptBudget(
                    targetCharacters: 640,
                    prefixCharacters: 180,
                    suffixCharacters: 220
                ),
                lifecycleMetrics: BASRequestLifecycleMetrics(
                    promptAssemblyMs: 40,
                    admissionEvaluationMs: 20,
                    providerSelectionMs: 30,
                    firstPresentableMs: 180,
                    executionMs: 90
                ),
                brainState: BASDecisionBrainState(
                    profileCore: ["Gentle tone"],
                    activeGoals: ["Protect sleep"],
                    relevantMemories: ["Holding the decision helped before"],
                    sessionBiases: [],
                    retrievalTags: [],
                    reactionWeights: .defaults(for: "primary"),
                    identityProfile: .default(modeName: "primary"),
                    boundaryPolicy: .default(riskLevel: .medium)
                ),
                consistencyRejected: true,
                consistencyViolationKinds: ["role_boundary"]
            )
        )

        #expect(compilation.allowsSensitivePayload == false)
        #expect(compilation.storedPrompt.contains("[REDACTED LIVE PROMPT]"))
        #expect(compilation.storedOutputPreview.contains("[REDACTED LIVE OUTPUT PREVIEW]"))
        #expect(compilation.executionTrace.selectedRoute.preferredModelID == "foundationModels")
        #expect(compilation.executionTrace.selectedRoute.fallbackModelIDs == ["foundationModels"])
        #expect(compilation.executionTrace.memoriesRecalled == ["Protect sleep", "Holding the decision helped before"])
        #expect(compilation.executionTrace.latency.routeSelectionMs == 30)
        #expect(compilation.executionTrace.latency.retrievalMs == 60)
        #expect(compilation.executionTrace.latency.generationMs == 90)
        #expect(compilation.executionTrace.auditEvents.contains { $0.category == "consistency.rejected" })
    }

    @Test("testing contexts keep sensitive payloads available")
    func traceCompilationPreservesPayloadInTestingContext() {
        let compilation = BASAppleObservabilityAdapter.compileProviderTrace(
            from: BASAppleProviderTraceInput(
                environment: ["XCTestConfigurationFilePath": "/tmp/test.xctestconfiguration"],
                considerRuntimeTestingContext: true,
                runtimeTestingContextDetected: true,
                testingOverridePresent: false,
                kind: BASAdaptiveTraceKind.reflectiveID,
                preferredProviderID: "foundationModels",
                activeProviderID: "foundationModels",
                attemptedProviderIDs: ["foundationModels"],
                allowFallbacks: false,
                prompt: "Sensitive runtime prompt",
                outputPreview: "Sensitive preview",
                detail: "Provider stayed on the primary route."
            )
        )

        #expect(compilation.allowsSensitivePayload == true)
        #expect(compilation.storedPrompt == "Sensitive runtime prompt")
        #expect(compilation.storedOutputPreview == "Sensitive preview")
    }

    @Test("telemetry compilation derives slow, overtime, and low-pressure model call flags")
    func telemetryCompilationDerivesExecutionFlags() {
        let compilation = BASAppleObservabilityAdapter.compileTelemetryRecord(
            from: BASAppleTelemetryRecordInput(
                kind: BASAdaptiveTraceKind.reflectiveID,
                outcome: .providerSuccess,
                activeProviderID: "gemmaE4B",
                attemptedProviderIDs: ["foundationModels", "gemmaE4B"],
                usedFallback: true,
                durationMs: 1_620,
                lifecycleMetrics: BASRequestLifecycleMetrics(
                    promptAssemblyMs: 60,
                    admissionEvaluationMs: 30,
                    providerSelectionMs: 40,
                    firstPresentableMs: 320,
                    executionMs: 180
                ),
                promptBudget: BASPromptBudget(
                    targetCharacters: 240,
                    prefixCharacters: 150,
                    suffixCharacters: 120
                ),
                runtimeTimeBudgetMs: 900,
                admissionPressureID: "low",
                admissionSkipReasonID: nil,
                selectionNeedID: nil,
                activeBackendID: "coreML"
            )
        )

        #expect(compilation.slowRequestThresholdMs == 1_500)
        #expect(compilation.isSlowRequest == true)
        #expect(compilation.exceedsTimeBudget == true)
        #expect(compilation.lowPressureModelCall == true)
        #expect(compilation.overTargetPromptBudget == true)
    }

    @Test("telemetry compilation keeps selection thresholds and non-provider outcomes conservative")
    func telemetryCompilationHandlesReminderAndSkippedAdmission() {
        let compilation = BASAppleObservabilityAdapter.compileTelemetryRecord(
            from: BASAppleTelemetryRecordInput(
                kind: BASAdaptiveTraceKind.selectionID,
                outcome: .admissionSkipped,
                activeProviderID: nil,
                attemptedProviderIDs: [],
                usedFallback: false,
                durationMs: 420,
                promptBudget: BASPromptBudget(
                    targetCharacters: 240,
                    prefixCharacters: 80,
                    suffixCharacters: 60
                ),
                runtimeTimeBudgetMs: 900,
                admissionPressureID: "low",
                admissionSkipReasonID: "retrievalNotNeeded",
                selectionNeedID: "control",
                activeBackendID: nil
            )
        )

        #expect(compilation.slowRequestThresholdMs == 450)
        #expect(compilation.isSlowRequest == false)
        #expect(compilation.exceedsTimeBudget == false)
        #expect(compilation.lowPressureModelCall == false)
        #expect(compilation.overTargetPromptBudget == false)
    }

    @Test("provider detail helpers stay package-owned")
    func providerDetailHelpersStayPackageOwned() {
        let detail = BASAppleObservabilityAdapter.providerDetail(
            preferredTitle: "Gemma E4B",
            activeTitle: "Foundation Models",
            allowFallbacks: true,
            activeResolutionDetail: "Core ML backend is active."
        )
        let cached = BASAppleObservabilityAdapter.cachedProviderDetail(
            preferredTitle: "Gemma E4B",
            activeTitle: "Foundation Models",
            allowFallbacks: true,
            activeResolutionDetail: "Core ML backend is active."
        )
        let fallback = BASAppleObservabilityAdapter.deterministicFallbackDetail(
            base: "No provider returned a refined response.",
            suspendedProviderTitles: ["Foundation Models"]
        )

        #expect(detail.contains("Foundation Models"))
        #expect(cached.contains("structured prompt cache"))
        #expect(fallback.contains("Active runtime cooldown: Foundation Models"))
    }

    @Test("consistency detail helper carries source and violations")
    func rejectedConsistencyDetailHelperCarriesSourceAndViolations() {
        let detail = BASAppleObservabilityAdapter.rejectedConsistencyDetail(
            base: "The host rejected the result.",
            result: BASConsistencyCheckResult(
                violations: [
                    BASConsistencyViolation(kind: .forbiddenAction, message: "Action drifted outside the allowed space.")
                ]
            ),
            source: "provider primary refinement"
        )

        #expect(detail.contains("provider primary refinement"))
        #expect(detail.contains("Action drifted outside the allowed space."))
    }

    @Test("runtime inspection adapter compiles package input without host-owned assembly")
    func runtimeInspectionInputCompilationBuildsCanonicalInspectionInput() {
        let input = BASAppleRuntimeInspectionAdapterInput(
            activeProviderID: "gemmaE4B",
            fallbackProviderID: "template",
            runtimeGear: .low,
            environmentClass: .lowPower,
            deviceClass: .balancedPhone,
            languageMode: .english,
            taskEntropyByKind: ["primary": .low],
            preferredProviderRawValueByKind: ["primary": "gemmaE4B"],
            strategyByKind: [
                "primary": BASAdaptiveTaskStrategy(
                    kind: .primary,
                    entropy: .low,
                    runtimeGear: .low,
                    contextBudget: 220,
                    outputCharacterBudget: 120,
                    timeBudgetMs: 600,
                    toolCallBudget: 0,
                    retrievalItemBudget: 1,
                    retrievalMode: .off,
                    thinkingMode: .off,
                    outputMode: .guidedShort,
                    tone: .briefWarm,
                    actionSpace: ["encourage"],
                    responseLanguage: .english,
                    allowsModelInvocation: true
                )
            ],
            effectivePreferredProviderRawValueByKind: ["primary": "gemmaE4B"],
            traceInputs: [],
            telemetrySummary: BASTelemetrySummary(
                input: BASTelemetrySummaryInput(
                    requestCountByKind: ["primary": 1],
                    outcomeCount: [.providerSuccess: 1],
                    outcomeCountByKind: [.providerSuccess: ["primary": 1]],
                    activeProviderCount: ["gemmaE4B": 1],
                    attemptedProviderCount: ["gemmaE4B": 1],
                    fallbackActivations: 0,
                    backendCount: [:],
                    slowRequestCountByKind: [:],
                    overTimeBudgetCountByKind: [:],
                    requestDurationTotalMsByKind: ["primary": 120],
                    firstPresentableTotalMsByKind: ["primary": 60],
                    promptAssemblyTotalMsByKind: ["primary": 20],
                    admissionEvaluationTotalMsByKind: ["primary": 10],
                    providerSelectionTotalMsByKind: ["primary": 10],
                    executionTotalMsByKind: ["primary": 20],
                    activeProviderDurationTotalMs: ["gemmaE4B": 120],
                    backendDurationTotalMs: [:],
                    admissionSkipCountByReason: [:],
                    admissionSkipCountByReasonAndKind: [:],
                    selectionNeedCount: [:],
                    promptCharactersTotalByKind: ["primary": 240],
                    prefixCharactersTotalByKind: ["primary": 120],
                    immutablePrefixCharactersTotalByKind: ["primary": 80],
                    adaptivePrefixCharactersTotalByKind: ["primary": 40],
                    suffixCharactersTotalByKind: ["primary": 120],
                    overTargetBudgetCountByKind: [:],
                    lowPressureModelCallCountByKind: [:],
                    selectionKindRawValue: "selection",
                    selectionKnowledgeNeedRawValue: "knowledge",
                    selectionControlNeedRawValue: "control",
                    selectionRetrievalBypassReasonRawValues: [],
                    avoidableSkipReasonRawValues: []
                )
            ),
            lifecycleSummary: BASLifecycleSummaryBuilder.build(from: []),
            neuralSummary: BASNeuralSummaryBuilder.build(from: []),
            brainSummary: BASBrainSummaryBuilder.build(from: []),
            totalCacheEntries: 2,
            totalCacheLookupCount: 3,
            totalCacheRejectedStores: 1,
            totalCacheQuarantinedHits: 1,
            dominantBackendID: "coreML",
            registeredProviderCount: 4,
            registeredOpenModelProviderCount: 1,
            activeCircuitProviderIDs: ["gemmaE4B"],
            circuitTripCount: 2,
            circuitTripCountByProvider: ["gemmaE4B": 2],
            circuitTripCountByReason: ["timeout": 2],
            traceCount: 5,
            replayCount: 2
        )

        let compilation = BASAppleObservabilityAdapter.compileRuntimeInspectionInput(from: input)

        #expect(compilation.activeProviderID == "gemmaE4B")
        #expect(compilation.fallbackProviderID == "template")
        #expect(compilation.runtimeGear == .low)
        #expect(compilation.totalCacheEntries == 2)
        #expect(compilation.traceCount == 5)
        #expect(compilation.replayCount == 2)
        #expect(compilation.strategyByKind["primary"]?.kind == .primary)
        #expect(compilation.preferredProviderRawValueByKind["primary"] == "gemmaE4B")
    }

    @Test("runtime inspection builder compiles lifecycle neural brain and inspection summaries from raw trace inputs")
    func runtimeInspectionBuilderCompilesFromTraceInputs() {
        let telemetrySummary = BASTelemetrySummary(
            input: BASTelemetrySummaryInput(
                requestCountByKind: ["primary": 1],
                outcomeCount: [.providerSuccess: 1],
                outcomeCountByKind: [.providerSuccess: ["primary": 1]],
                activeProviderCount: ["gemmaE4B": 1],
                attemptedProviderCount: ["gemmaE4B": 1],
                fallbackActivations: 0,
                backendCount: [:],
                slowRequestCountByKind: [:],
                overTimeBudgetCountByKind: [:],
                requestDurationTotalMsByKind: ["primary": 120],
                firstPresentableTotalMsByKind: ["primary": 60],
                promptAssemblyTotalMsByKind: ["primary": 20],
                admissionEvaluationTotalMsByKind: ["primary": 10],
                providerSelectionTotalMsByKind: ["primary": 10],
                executionTotalMsByKind: ["primary": 20],
                activeProviderDurationTotalMs: ["gemmaE4B": 120],
                backendDurationTotalMs: [:],
                admissionSkipCountByReason: [:],
                admissionSkipCountByReasonAndKind: [:],
                selectionNeedCount: [:],
                promptCharactersTotalByKind: ["primary": 240],
                prefixCharactersTotalByKind: ["primary": 120],
                immutablePrefixCharactersTotalByKind: ["primary": 80],
                adaptivePrefixCharactersTotalByKind: ["primary": 40],
                suffixCharactersTotalByKind: ["primary": 120],
                overTargetBudgetCountByKind: [:],
                lowPressureModelCallCountByKind: [:],
                selectionKindRawValue: "selection",
                selectionKnowledgeNeedRawValue: "knowledge",
                selectionControlNeedRawValue: "control",
                selectionRetrievalBypassReasonRawValues: [],
                avoidableSkipReasonRawValues: []
            )
        )

        let compilation = BASAppleRuntimeInspectionBuilder.build(
            from: BASAppleRuntimeInspectionSourceInput(
                activeProviderID: "gemmaE4B",
                fallbackProviderID: "template",
                runtimeGear: .balanced,
                environmentClass: .normal,
                deviceClass: .fullPhone,
                languageMode: .english,
                taskEntropyByKind: ["primary": .low],
                preferredProviderRawValueByKind: ["primary": "gemmaE4B"],
                strategyByKind: [
                    "primary": BASAdaptiveTaskStrategy(
                        kind: .primary,
                        entropy: .low,
                        runtimeGear: .balanced,
                        contextBudget: 320,
                        outputCharacterBudget: 180,
                        timeBudgetMs: 900,
                        toolCallBudget: 0,
                        retrievalItemBudget: 2,
                        retrievalMode: .filtered,
                        thinkingMode: .off,
                        outputMode: .guidedShort,
                        tone: .briefWarm,
                        actionSpace: ["encourage"],
                        responseLanguage: .english,
                        allowsModelInvocation: true
                    )
                ],
                effectivePreferredProviderRawValueByKind: ["primary": "gemmaE4B"],
                traceSources: [
                    BASAppleRuntimeInspectionTraceSourceInput(
                        lifecycle: BASLifecycleTraceInput(
                            kind: "primary",
                            hasContextState: true,
                            generation: 3,
                            rebuiltSession: true,
                            staleFieldCount: 1,
                            anchorFieldCount: 2,
                            hasFrontstageState: true,
                            retainedEvidenceCount: 2,
                            droppedEvidenceCount: 1,
                            droppedInjectedEvidenceCount: 1,
                            droppedDuplicateEvidenceCount: 0,
                            droppedBudgetEvidenceCount: 0
                        ),
                        neural: BASNeuralTraceInput(
                            kind: "primary",
                            suppressedBehaviorCount: 1,
                            dominantActionRawValue: "encourage",
                            strongestSignalRawValue: "urgency"
                        ),
                        brain: BASBrainTraceInput(
                            kind: "primary",
                            dominantReactionWeight: .briefLanguage,
                            profileCoreCount: 1,
                            activeGoalCount: 1,
                            relevantMemoryCount: 2,
                            loadedPromotedMemoryCount: 2,
                            loadedPendingMemoryCount: 1,
                            pendingCandidateCount: 1,
                            promotedRecordCount: 4,
                            screenedOutMemoryCount: 0,
                            loadedEligibilityReasonCounts: [:],
                            screenedOutEligibilityReasonCounts: [:],
                            snapshotFingerprint: "brain_fp",
                            lowTrustMemoryLoadRate: 0.25,
                            riskFlags: [.lowTrustLoad],
                            identityRole: .pauseCompanion,
                            boundaryMode: .localOnlyAdvisory,
                            activeConstraints: [.lockSensitiveMemory],
                            calibrationStatus: .stable,
                            calibrationAlerts: [],
                            evolutionCheckpointCount: 2,
                            evolutionPendingReviewCount: 0,
                            evolutionRollbackReady: true
                        ),
                        runtimeInspection: BASRuntimeInspectionTraceInput(
                            kind: "primary",
                            attemptedProviderIDs: ["gemmaE4B"],
                            runtimeStrategy: BASAdaptiveTaskStrategy(
                                kind: .primary,
                                entropy: .low,
                                runtimeGear: .balanced,
                                contextBudget: 320,
                                outputCharacterBudget: 180,
                                timeBudgetMs: 900,
                                toolCallBudget: 0,
                                retrievalItemBudget: 2,
                                retrievalMode: .filtered,
                                thinkingMode: .off,
                                outputMode: .guidedShort,
                                tone: .briefWarm,
                                actionSpace: ["encourage"],
                                responseLanguage: .english,
                                allowsModelInvocation: true
                            ),
                            semanticPromptFingerprint: "semantic_fp",
                            stablePrefixFingerprint: "prefix_fp",
                            consistencyChecked: true,
                            consistencyRejected: false,
                            consistencyViolationKinds: []
                        )
                    )
                ],
                telemetrySummary: telemetrySummary,
                totalCacheEntries: 2,
                totalCacheLookupCount: 4,
                totalCacheRejectedStores: 0,
                totalCacheQuarantinedHits: 0,
                dominantBackendID: "coreML",
                registeredProviderCount: 3,
                registeredOpenModelProviderCount: 1,
                activeCircuitProviderIDs: [],
                circuitTripCount: 0,
                circuitTripCountByProvider: [:],
                circuitTripCountByReason: [:],
                traceCount: 1,
                replayCount: 0
            )
        )

        #expect(compilation.lifecycleSummary.contextAwareTraceCount == 1)
        #expect(compilation.neuralSummary.neuralTraceCount == 1)
        #expect(compilation.brainSummary.brainTraceCount == 1)
        #expect(compilation.runtimeInspectionInput.activeProviderID == "gemmaE4B")
        #expect(compilation.runtimeInspectionSummary.traceCount == 1)
        #expect(compilation.runtimeInspectionSummary.brainTraceCount == 1)
        #expect(compilation.runtimeInspectionSummary.consistencyCheckedTraceCount == 1)
    }

    @Test("runtime export builder compiles host-like raw inspection inputs")
    func runtimeExportBuilderCompilesHostLikeRawInspectionInputs() {
        let telemetrySummary = BASTelemetrySummary(
            input: BASTelemetrySummaryInput(
                requestCountByKind: ["primary": 1],
                outcomeCount: [.providerSuccess: 1],
                outcomeCountByKind: [.providerSuccess: ["primary": 1]],
                activeProviderCount: ["gemmaE4B": 1],
                attemptedProviderCount: ["gemmaE4B": 1],
                fallbackActivations: 0,
                backendCount: ["coreML": 1],
                slowRequestCountByKind: [:],
                overTimeBudgetCountByKind: [:],
                requestDurationTotalMsByKind: ["primary": 220],
                firstPresentableTotalMsByKind: ["primary": 140],
                promptAssemblyTotalMsByKind: ["primary": 20],
                admissionEvaluationTotalMsByKind: ["primary": 10],
                providerSelectionTotalMsByKind: ["primary": 15],
                executionTotalMsByKind: ["primary": 95],
                activeProviderDurationTotalMs: ["gemmaE4B": 220],
                backendDurationTotalMs: ["coreML": 220],
                admissionSkipCountByReason: [:],
                admissionSkipCountByReasonAndKind: [:],
                selectionNeedCount: [:],
                promptCharactersTotalByKind: ["primary": 420],
                prefixCharactersTotalByKind: ["primary": 220],
                immutablePrefixCharactersTotalByKind: ["primary": 120],
                adaptivePrefixCharactersTotalByKind: ["primary": 100],
                suffixCharactersTotalByKind: ["primary": 200],
                overTargetBudgetCountByKind: [:],
                lowPressureModelCallCountByKind: [:],
                selectionKindRawValue: "selection",
                selectionKnowledgeNeedRawValue: "knowledge",
                selectionControlNeedRawValue: "control",
                selectionRetrievalBypassReasonRawValues: [],
                avoidableSkipReasonRawValues: []
            )
        )

        let compilation = BASAppleRuntimeExportBuilder.compileRuntimeInspection(
            from: BASAppleRuntimeInspectionExportSourceInput(
                activeProviderID: "gemmaE4B",
                fallbackProviderID: "template",
                runtimeGearID: "balanced",
                environmentClassID: "normal",
                deviceClassID: "fullPhone",
                languageModeID: "english",
                taskEntropyIDByKind: ["primary": "low"],
                preferredProviderIDByKind: ["primary": "gemmaE4B"],
                strategyByKind: [
                    "primary": BASAppleRuntimeInspectionAdaptiveStrategySourceInput(
                        kindID: "primary",
                        entropyID: "low",
                        runtimeGearID: "balanced",
                        contextBudget: 320,
                        outputCharacterBudget: 180,
                        timeBudgetMs: 900,
                        toolCallBudget: 0,
                        retrievalItemBudget: 2,
                        retrievalModeID: "filtered",
                        thinkingModeID: "off",
                        outputModeID: "guidedShort",
                        toneID: "briefWarm",
                        actionSpace: ["encourage"],
                        responseLanguageID: "english",
                        allowsModelInvocation: true
                    )
                ],
                effectivePreferredProviderIDByKind: ["primary": "gemmaE4B"],
                traceRecords: [
                    BASAppleRuntimeInspectionTraceSourceRecordInput(
                        kindID: "primary",
                        hasContextState: true,
                        generation: 3,
                        rebuiltSession: true,
                        staleFieldCount: 1,
                        anchorFieldCount: 2,
                        hasFrontstageState: true,
                        retainedEvidenceCount: 2,
                        droppedEvidenceCount: 1,
                        droppedInjectedEvidenceCount: 1,
                        droppedDuplicateEvidenceCount: 0,
                        droppedBudgetEvidenceCount: 0,
                        suppressedBehaviorCount: 1,
                        dominantActionID: "encourage",
                        strongestSignalID: "urgency",
                        dominantReactionWeightID: BASReactionWeightKey.briefLanguage.rawValue,
                        profileCoreCount: 1,
                        activeGoalCount: 1,
                        relevantMemoryCount: 2,
                        loadedPromotedMemoryCount: 2,
                        loadedPendingMemoryCount: 1,
                        pendingCandidateCount: 1,
                        promotedRecordCount: 4,
                        screenedOutMemoryCount: 0,
                        loadedEligibilityReasonCounts: [BASMemoryEligibilityReason.goalOverride.rawValue: 1],
                        screenedOutEligibilityReasonCounts: [BASMemoryEligibilityReason.supportPriorityNoOverlap.rawValue: 1],
                        snapshotFingerprint: "brain_fp",
                        constitutionVersion: "constitution.v11",
                        constitutionPhase: "migration",
                        constitutionValueAxisCount: 4,
                        forgetRequestID: "forget.guard.anchor",
                        forgetVerified: true,
                        forgetRevokesCheckpoints: true,
                        vaultConsistencyState: "out_of_sync",
                        vaultSyncRevocationCount: 2,
                        vaultOutOfSyncDeviceIDs: ["device.secondary", "device.tablet"],
                        vaultMigrationTargetDeviceID: "device.secondary",
                        lowTrustMemoryLoadRate: 0.25,
                        riskFlagIDs: [BASBrainStateRiskFlag.lowTrustLoad.rawValue],
                        identityRoleID: BASIdentityRole.pauseCompanion.rawValue,
                        boundaryModeID: BASBoundaryPolicyMode.localOnlyAdvisory.rawValue,
                        activeConstraintIDs: [BASBoundaryConstraint.lockSensitiveMemory.rawValue],
                        calibrationStatusID: BASCalibrationStatus.stable.rawValue,
                        calibrationAlertIDs: [],
                        evolutionCheckpointCount: 2,
                        evolutionPendingReviewCount: 0,
                        evolutionRollbackReady: true,
                        attemptedProviderIDs: ["gemmaE4B"],
                        runtimeStrategy: BASAppleRuntimeInspectionAdaptiveStrategySourceInput(
                            kindID: "primary",
                            entropyID: "low",
                            runtimeGearID: "balanced",
                            contextBudget: 320,
                            outputCharacterBudget: 180,
                            timeBudgetMs: 900,
                            toolCallBudget: 0,
                            retrievalItemBudget: 2,
                            retrievalModeID: "filtered",
                            thinkingModeID: "off",
                            outputModeID: "guidedShort",
                            toneID: "briefWarm",
                            actionSpace: ["encourage"],
                            responseLanguageID: "english",
                            allowsModelInvocation: true
                        ),
                        semanticPromptFingerprint: "semantic_fp",
                        stablePrefixFingerprint: "prefix_fp",
                        consistencyChecked: true,
                        consistencyRejected: false,
                        consistencyViolationKindIDs: []
                    )
                ],
                telemetrySummary: telemetrySummary,
                totalCacheEntries: 2,
                totalCacheLookupCount: 4,
                totalCacheRejectedStores: 0,
                totalCacheQuarantinedHits: 0,
                dominantBackendID: "coreML",
                registeredProviderCount: 3,
                registeredOpenModelProviderCount: 1,
                activeCircuitProviderIDs: [],
                circuitTripCount: 0,
                circuitTripCountByProvider: [:],
                circuitTripCountByReason: [:],
                traceCount: 1,
                replayCount: 0
            )
        )

        #expect(compilation.runtimeInspectionInput.activeProviderID == "gemmaE4B")
        #expect(compilation.runtimeInspectionInput.strategyByKind["primary"]?.runtimeGear == .balanced)
        #expect(compilation.brainSummary.brainTraceCount == 1)
        #expect(compilation.brainSummary.latestSnapshotFingerprintByKind["primary"]?.contains("constitution:constitution.v11") == true)
        #expect(compilation.brainSummary.latestSnapshotFingerprintByKind["primary"]?.contains("phase:migration") == true)
        #expect(compilation.brainSummary.latestSnapshotFingerprintByKind["primary"]?.contains("value_axes:4") == true)
        #expect(compilation.brainSummary.latestSnapshotFingerprintByKind["primary"]?.contains("forget:forget.guard.anchor") == true)
        #expect(compilation.brainSummary.latestSnapshotFingerprintByKind["primary"]?.contains("forget_verified:true") == true)
        #expect(compilation.brainSummary.latestSnapshotFingerprintByKind["primary"]?.contains("forget_checkpoints_revoked:true") == true)
        #expect(compilation.brainSummary.latestSnapshotFingerprintByKind["primary"]?.contains("vault_consistency:out_of_sync") == true)
        #expect(compilation.brainSummary.latestSnapshotFingerprintByKind["primary"]?.contains("vault_sync_revocations:2") == true)
        #expect(compilation.brainSummary.latestSnapshotFingerprintByKind["primary"]?.contains("vault_out_of_sync_list:device.secondary,device.tablet") == true)
        #expect(compilation.brainSummary.latestSnapshotFingerprintByKind["primary"]?.contains("vault_migration_target:device.secondary") == true)
        #expect(compilation.runtimeInspectionSummary.consistencyCheckedTraceCount == 1)
    }

    @Test("runtime inspection trace source builder owns flat record expansion")
    func runtimeInspectionTraceSourceBuilderExpandsFlatRecord() {
        let snapshotFingerprint = [
            "brain_fp",
            "constitution:constitution.v13",
            "phase:evolution",
            "value_axes:5",
            "forget:forget.guard.anchor",
            "forget_verified:true",
            "forget_checkpoints_revoked:true",
            "vault_consistency:out_of_sync",
            "vault_sync_revocations:3",
            "vault_out_of_sync_list:device.secondary,device.tablet",
            "vault_migration_target:device.secondary"
        ].joined(separator: "|")
        let source = BASAppleRuntimeInspectionBuilder.traceSource(
            from: BASAppleRuntimeInspectionTraceRecordInput(
                kind: "primary",
                hasContextState: true,
                generation: 4,
                rebuiltSession: true,
                staleFieldCount: 1,
                anchorFieldCount: 2,
                hasFrontstageState: true,
                retainedEvidenceCount: 3,
                droppedEvidenceCount: 1,
                droppedInjectedEvidenceCount: 1,
                droppedDuplicateEvidenceCount: 0,
                droppedBudgetEvidenceCount: 0,
                suppressedBehaviorCount: 2,
                dominantActionRawValue: "encourage",
                strongestSignalRawValue: "urgency",
                dominantReactionWeight: .briefLanguage,
                profileCoreCount: 1,
                activeGoalCount: 2,
                relevantMemoryCount: 3,
                loadedPromotedMemoryCount: 4,
                loadedPendingMemoryCount: 1,
                pendingCandidateCount: 1,
                promotedRecordCount: 5,
                screenedOutMemoryCount: 1,
                loadedEligibilityReasonCounts: [.goalOverride: 1],
                screenedOutEligibilityReasonCounts: [.supportPriorityNoOverlap: 1],
                snapshotFingerprint: snapshotFingerprint,
                constitutionVersion: "constitution.v13",
                constitutionPhase: "evolution",
                constitutionValueAxisCount: 5,
                forgetRequestID: "forget.guard.anchor",
                forgetVerified: true,
                forgetRevokesCheckpoints: true,
                vaultConsistencyState: "out_of_sync",
                vaultSyncRevocationCount: 3,
                vaultOutOfSyncDeviceIDs: ["device.secondary", "device.tablet"],
                vaultMigrationTargetDeviceID: "device.secondary",
                lowTrustMemoryLoadRate: 0.25,
                riskFlags: [.lowTrustLoad],
                identityRole: .pauseCompanion,
                boundaryMode: .localOnlyAdvisory,
                activeConstraints: [.lockSensitiveMemory],
                calibrationStatus: .watch,
                calibrationAlerts: [.lowTrustLoad],
                evolutionCheckpointCount: 2,
                evolutionPendingReviewCount: 1,
                evolutionRollbackReady: true,
                attemptedProviderIDs: ["gemmaE4B", "foundationModels"],
                runtimeStrategy: BASAdaptiveTaskStrategy(
                    kind: .primary,
                    entropy: .low,
                    runtimeGear: .balanced,
                    contextBudget: 320,
                    outputCharacterBudget: 180,
                    timeBudgetMs: 900,
                    toolCallBudget: 0,
                    retrievalItemBudget: 2,
                    retrievalMode: .filtered,
                    thinkingMode: .off,
                    outputMode: .guidedShort,
                    tone: .briefWarm,
                    actionSpace: ["encourage"],
                    responseLanguage: .english,
                    allowsModelInvocation: true
                ),
                semanticPromptFingerprint: "semantic_fp",
                stablePrefixFingerprint: "prefix_fp",
                consistencyChecked: true,
                consistencyRejected: false,
                consistencyViolationKinds: []
            )
        )

        #expect(source.lifecycle?.generation == 4)
        #expect(source.neural?.suppressedBehaviorCount == 2)
        #expect(source.brain?.snapshotFingerprint.contains("brain_fp") == true)
        #expect(source.brain?.snapshotFingerprint.contains("constitution:constitution.v13") == true)
        #expect(source.brain?.snapshotFingerprint.contains("phase:evolution") == true)
        #expect(source.brain?.snapshotFingerprint.contains("value_axes:5") == true)
        #expect(source.brain?.snapshotFingerprint.contains("forget:forget.guard.anchor") == true)
        #expect(source.brain?.snapshotFingerprint.contains("forget_verified:true") == true)
        #expect(source.brain?.snapshotFingerprint.contains("forget_checkpoints_revoked:true") == true)
        #expect(source.brain?.snapshotFingerprint.contains("vault_consistency:out_of_sync") == true)
        #expect(source.brain?.snapshotFingerprint.contains("vault_sync_revocations:3") == true)
        #expect(source.brain?.snapshotFingerprint.contains("vault_out_of_sync_list:device.secondary,device.tablet") == true)
        #expect(source.brain?.snapshotFingerprint.contains("vault_migration_target:device.secondary") == true)
        #expect(source.brain?.calibrationStatus == .watch)
        #expect(source.runtimeInspection.attemptedProviderIDs == ["gemmaE4B", "foundationModels"])
        #expect(source.runtimeInspection.runtimeStrategy?.kind == .primary)
        #expect(source.runtimeInspection.semanticPromptFingerprint == "semantic_fp")
    }
}
#endif
