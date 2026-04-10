import Testing
@testable import BASAppleAdapters
@testable import BASMemory
@testable import BASObservability
@testable import BASOrchestration
@testable import BASPolicy
@testable import BASRuntimeCore

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
                kind: "quick",
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
                    relevantMemories: ["Tomorrow Box helped before"],
                    sessionBiases: [],
                    retrievalTags: [],
                    reactionWeights: .defaults(for: "quick"),
                    identityProfile: .default(modeName: "quick"),
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
        #expect(compilation.executionTrace.memoriesRecalled == ["Protect sleep", "Tomorrow Box helped before"])
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
                kind: "mirror",
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
                kind: "mirror",
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
                reminderSelectionNeedID: nil,
                activeBackendID: "coreML"
            )
        )

        #expect(compilation.slowRequestThresholdMs == 1_500)
        #expect(compilation.isSlowRequest == true)
        #expect(compilation.exceedsTimeBudget == true)
        #expect(compilation.lowPressureModelCall == true)
        #expect(compilation.overTargetPromptBudget == true)
    }

    @Test("telemetry compilation keeps reminder thresholds and non-provider outcomes conservative")
    func telemetryCompilationHandlesReminderAndSkippedAdmission() {
        let compilation = BASAppleObservabilityAdapter.compileTelemetryRecord(
            from: BASAppleTelemetryRecordInput(
                kind: "reminder",
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
                reminderSelectionNeedID: "control",
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
            base: "Before rejected the result.",
            result: BASConsistencyCheckResult(
                violations: [
                    BASConsistencyViolation(kind: .forbiddenAction, message: "Action drifted outside the allowed space.")
                ]
            ),
            source: "provider quick refinement"
        )

        #expect(detail.contains("provider quick refinement"))
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
            taskEntropyByKind: ["quick": .low],
            preferredProviderRawValueByKind: ["quick": "gemmaE4B"],
            strategyByKind: [
                "quick": BASAdaptiveTaskStrategy(
                    kind: .quick,
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
            effectivePreferredProviderRawValueByKind: ["quick": "gemmaE4B"],
            traceInputs: [],
            telemetrySummary: BASTelemetrySummary(
                input: BASTelemetrySummaryInput(
                    requestCountByKind: ["quick": 1],
                    outcomeCount: [.providerSuccess: 1],
                    outcomeCountByKind: [.providerSuccess: ["quick": 1]],
                    activeProviderCount: ["gemmaE4B": 1],
                    attemptedProviderCount: ["gemmaE4B": 1],
                    fallbackActivations: 0,
                    backendCount: [:],
                    slowRequestCountByKind: [:],
                    overTimeBudgetCountByKind: [:],
                    requestDurationTotalMsByKind: ["quick": 120],
                    firstPresentableTotalMsByKind: ["quick": 60],
                    promptAssemblyTotalMsByKind: ["quick": 20],
                    admissionEvaluationTotalMsByKind: ["quick": 10],
                    providerSelectionTotalMsByKind: ["quick": 10],
                    executionTotalMsByKind: ["quick": 20],
                    activeProviderDurationTotalMs: ["gemmaE4B": 120],
                    backendDurationTotalMs: [:],
                    admissionSkipCountByReason: [:],
                    admissionSkipCountByReasonAndKind: [:],
                    reminderSelectionNeedCount: [:],
                    promptCharactersTotalByKind: ["quick": 240],
                    prefixCharactersTotalByKind: ["quick": 120],
                    immutablePrefixCharactersTotalByKind: ["quick": 80],
                    adaptivePrefixCharactersTotalByKind: ["quick": 40],
                    suffixCharactersTotalByKind: ["quick": 120],
                    overTargetBudgetCountByKind: [:],
                    lowPressureModelCallCountByKind: [:],
                    reminderKindRawValue: "reminder",
                    reminderKnowledgeNeedRawValue: "knowledge",
                    reminderControlNeedRawValue: "control",
                    reminderRetrievalBypassReasonRawValues: [],
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
        #expect(compilation.strategyByKind["quick"]?.kind == .quick)
        #expect(compilation.preferredProviderRawValueByKind["quick"] == "gemmaE4B")
    }

    @Test("runtime inspection builder compiles lifecycle neural brain and inspection summaries from raw trace inputs")
    func runtimeInspectionBuilderCompilesFromTraceInputs() {
        let telemetrySummary = BASTelemetrySummary(
            input: BASTelemetrySummaryInput(
                requestCountByKind: ["quick": 1],
                outcomeCount: [.providerSuccess: 1],
                outcomeCountByKind: [.providerSuccess: ["quick": 1]],
                activeProviderCount: ["gemmaE4B": 1],
                attemptedProviderCount: ["gemmaE4B": 1],
                fallbackActivations: 0,
                backendCount: [:],
                slowRequestCountByKind: [:],
                overTimeBudgetCountByKind: [:],
                requestDurationTotalMsByKind: ["quick": 120],
                firstPresentableTotalMsByKind: ["quick": 60],
                promptAssemblyTotalMsByKind: ["quick": 20],
                admissionEvaluationTotalMsByKind: ["quick": 10],
                providerSelectionTotalMsByKind: ["quick": 10],
                executionTotalMsByKind: ["quick": 20],
                activeProviderDurationTotalMs: ["gemmaE4B": 120],
                backendDurationTotalMs: [:],
                admissionSkipCountByReason: [:],
                admissionSkipCountByReasonAndKind: [:],
                reminderSelectionNeedCount: [:],
                promptCharactersTotalByKind: ["quick": 240],
                prefixCharactersTotalByKind: ["quick": 120],
                immutablePrefixCharactersTotalByKind: ["quick": 80],
                adaptivePrefixCharactersTotalByKind: ["quick": 40],
                suffixCharactersTotalByKind: ["quick": 120],
                overTargetBudgetCountByKind: [:],
                lowPressureModelCallCountByKind: [:],
                reminderKindRawValue: "reminder",
                reminderKnowledgeNeedRawValue: "knowledge",
                reminderControlNeedRawValue: "control",
                reminderRetrievalBypassReasonRawValues: [],
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
                taskEntropyByKind: ["quick": .low],
                preferredProviderRawValueByKind: ["quick": "gemmaE4B"],
                strategyByKind: [
                    "quick": BASAdaptiveTaskStrategy(
                        kind: .quick,
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
                effectivePreferredProviderRawValueByKind: ["quick": "gemmaE4B"],
                traceSources: [
                    BASAppleRuntimeInspectionTraceSourceInput(
                        lifecycle: BASLifecycleTraceInput(
                            kind: "quick",
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
                            kind: "quick",
                            suppressedBehaviorCount: 1,
                            dominantActionRawValue: "encourage",
                            strongestSignalRawValue: "urgency"
                        ),
                        brain: BASBrainTraceInput(
                            kind: "quick",
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
                            kind: "quick",
                            attemptedProviderIDs: ["gemmaE4B"],
                            runtimeStrategy: BASAdaptiveTaskStrategy(
                                kind: .quick,
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

    @Test("runtime inspection trace source builder owns flat record expansion")
    func runtimeInspectionTraceSourceBuilderExpandsFlatRecord() {
        let source = BASAppleRuntimeInspectionBuilder.traceSource(
            from: BASAppleRuntimeInspectionTraceRecordInput(
                kind: "quick",
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
                snapshotFingerprint: "brain_fp",
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
                    kind: .quick,
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
        #expect(source.brain?.snapshotFingerprint == "brain_fp")
        #expect(source.brain?.calibrationStatus == .watch)
        #expect(source.runtimeInspection.attemptedProviderIDs == ["gemmaE4B", "foundationModels"])
        #expect(source.runtimeInspection.runtimeStrategy?.kind == .quick)
        #expect(source.runtimeInspection.semanticPromptFingerprint == "semantic_fp")
    }
}
