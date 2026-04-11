import Testing
@testable import BASAppleAdapters
@testable import BASObservability
@testable import BASOrchestration
@testable import BASPolicy
@testable import BASRuntimeCore

@Suite("BASApple Provider Outcome Observer")
struct BASAppleProviderOutcomeObserverTests {
    private struct MockProvider: Sendable {
        let id: String
    }

    private struct MockDescriptor: Sendable {
        let id: String
        let title: String
        let detail: String?
        let backendID: String?
    }

    private enum MockTraceKind: String, Sendable {
        case quick
    }

    private enum MockProviderKind: String, Sendable {
        case foundationModels
        case gemmaE4B
    }

    @Test("observer owns provider narrative variants and consistency rejection details")
    func observerBuildsNarratives() {
        let live = BASAppleProviderOutcomeObserver.providerDetail(
            preferredTitle: "Foundation",
            activeTitle: "Gemma",
            allowFallbacks: true,
            activeResolutionDetail: "Core ML: on-device"
        )
        let cached = BASAppleProviderOutcomeObserver.cachedProviderDetail(
            preferredTitle: "Foundation",
            activeTitle: "Gemma",
            allowFallbacks: true
        )
        let fallback = BASAppleProviderOutcomeObserver.deterministicFallbackDetail(
            base: "All compatible providers were unavailable.",
            suspendedProviderTitles: ["Foundation"]
        )
        let rejected = BASAppleProviderOutcomeObserver.rejectedConsistencyDetail(
            base: live,
            result: BASConsistencyCheckResult(
                violations: [
                    BASConsistencyViolation(
                        kind: .modeMismatch,
                        message: "Response drifted away from quick mode."
                    )
                ]
            ),
            source: "provider quick refinement"
        )

        #expect(live.contains("Foundation"))
        #expect(live.contains("Gemma"))
        #expect(live.contains("Core ML"))
        #expect(cached.contains("structured prompt cache"))
        #expect(fallback.contains("Foundation"))
        #expect(rejected.contains("provider quick refinement"))
    }

    @Test("observation context builder owns task-specific narrative presets")
    func observationContextBuilderOwnsNarrativePresets() {
        let quick = BASAppleProviderObservationContextBuilder.build(
            from: BASAppleProviderObservationSourceInput(
                kind: "quick",
                preferredProviderID: "foundationModels",
                allowFallbacks: true,
                providerProfilesByID: [:],
                prompt: "quick prompt",
                baselineOutputPreview: "quick preview",
                deterministicFallbackOutputPreview: "quick fallback",
                recordsTemplatePinnedTrace: true
            )
        )
        let reminder = BASAppleProviderObservationContextBuilder.build(
            from: BASAppleProviderObservationSourceInput(
                kind: "reminder",
                preferredProviderID: "foundationModels",
                allowFallbacks: true,
                providerProfilesByID: [:],
                prompt: "reminder prompt",
                baselineOutputPreview: "keep ordering",
                deterministicFallbackOutputPreview: "no reminder",
                recordsTemplatePinnedTrace: false
            )
        )

        #expect(quick.templatePinnedDetail.contains("quick refinement"))
        #expect(quick.admissionSkippedOutputPreview == "quick preview")
        #expect(quick.cachedConsistencySource == "cached quick refinement")
        #expect(reminder.templatePinnedDetail.contains("reminder selection"))
        #expect(reminder.providerConsistencySource == "provider reminder selection")
        #expect(reminder.deterministicFallbackOutputPreview == "no reminder")
    }

    @Test("host observation bridge builds host context while keeping substrate narrative compilation package-owned")
    func hostObservationBridgeBuildsHostContext() {
        let context = BASAppleHostProviderObservationBridge.context(
            kind: MockTraceKind.quick,
            frontstageState: "frontstage",
            contextState: "scoped",
            neuralState: "neural",
            brainState: "brain",
            runtimeStrategy: "runtime",
            promptBudget: "budget",
            admissionDecision: "admission",
            sourceInput: BASAppleProviderObservationSourceInput(
                kind: "quick",
                preferredProviderID: "foundationModels",
                allowFallbacks: true,
                providerProfilesByID: [:],
                prompt: "quick prompt",
                baselineOutputPreview: "quick preview",
                deterministicFallbackOutputPreview: "fallback preview",
                recordsTemplatePinnedTrace: true
            )
        )

        #expect(context.kind == .quick)
        #expect(context.frontstageState == "frontstage")
        #expect(context.brainState == "brain")
        #expect(context.substrateContext.templatePinnedDetail.contains("quick refinement"))
        #expect(context.substrateContext.cachedConsistencySource == "cached quick refinement")
    }

    @Test("observer compiles sanitized traces and telemetry observations")
    func observerCompilesTraceAndTelemetry() {
        let trace = BASAppleProviderOutcomeObserver.traceObservation(
            from: BASAppleProviderTraceInput(
                environment: [:],
                considerRuntimeTestingContext: false,
                runtimeTestingContextDetected: false,
                testingOverridePresent: false,
                kind: "quick",
                preferredProviderID: "foundationModels",
                activeProviderID: "gemmaE4B",
                attemptedProviderIDs: ["foundationModels", "gemmaE4B"],
                allowFallbacks: true,
                prompt: "live prompt",
                outputPreview: "live output",
                detail: "Gemma handled quick refinement.",
                semanticPromptFingerprint: "semantic-1",
                stablePrefixFingerprint: "prefix-1",
                promptBudget: BASPromptBudget(
                    targetCharacters: 220,
                    prefixCharacters: 80,
                    suffixCharacters: 60
                ),
                lifecycleMetrics: BASRequestLifecycleMetrics(
                    promptAssemblyMs: 20,
                    admissionEvaluationMs: 10,
                    providerSelectionMs: 15,
                    firstPresentableMs: 100,
                    executionMs: 55
                )
            )
        )
        let telemetry = BASAppleProviderOutcomeObserver.telemetryObservation(
            from: BASAppleTelemetryRecordInput(
                kind: "mirror",
                outcome: .providerSuccess,
                activeProviderID: "gemmaE4B",
                attemptedProviderIDs: ["foundationModels", "gemmaE4B"],
                usedFallback: true,
                durationMs: 1_650,
                lifecycleMetrics: BASAppleProviderOutcomeObserver.lifecycleMetrics(
                    promptPreparedMs: 25,
                    admissionEvaluatedMs: 40,
                    providerSelectionMs: 70,
                    firstPresentableMs: 160
                ),
                promptBudget: BASPromptBudget(
                    targetCharacters: 420,
                    prefixCharacters: 180,
                    suffixCharacters: 120
                ),
                runtimeTimeBudgetMs: 1_400,
                admissionPressureID: "low",
                activeBackendID: "coreML"
            )
        )

        #expect(trace.compilation.allowsSensitivePayload == false)
        #expect(trace.compilation.storedPrompt.contains("[REDACTED LIVE PROMPT]"))
        #expect(trace.compilation.executionTrace.selectedRoute.preferredModelID == "gemmaE4B")
        #expect(telemetry.compilation.isSlowRequest)
        #expect(telemetry.compilation.exceedsTimeBudget)
        #expect(telemetry.compilation.lowPressureModelCall)
        #expect(telemetry.compilation.usedFallback)
    }

    @Test("observer can compile provider request events into trace telemetry and circuit outputs")
    func observerCompilesObservedProviderEvents() {
        let context = BASAppleProviderObservationContext(
            kind: "quick",
            preferredProviderID: "foundationModels",
            allowFallbacks: true,
            providerProfilesByID: [
                "foundationModels": BASAppleProviderProfile(
                    providerID: "foundationModels",
                    title: "Foundation"
                ),
                "gemmaE4B": BASAppleProviderProfile(
                    providerID: "gemmaE4B",
                    title: "Gemma",
                    activeResolutionDetail: "Core ML: on-device",
                    activeBackendID: "coreML"
                )
            ],
            promptBudget: BASPromptBudget(
                targetCharacters: 220,
                prefixCharacters: 80,
                suffixCharacters: 60
            ),
            brainState: nil,
            admissionPressureID: "low",
            runtimeTimeBudgetMs: 1_000,
            admissionReason: "Pressure is low.",
            semanticPromptFingerprint: "semantic-1",
            stablePrefixFingerprint: "prefix-1",
            prompt: "live prompt",
            templatePinnedOutputPreview: "template preview",
            admissionSkippedOutputPreview: "admission preview",
            deterministicFallbackOutputPreview: "fallback preview",
            templatePinnedDetail: "Template pinned.",
            admissionSkippedDetailPrefix: "Admission skipped.",
            deterministicFallbackBase: "No provider returned a result.",
            cachedConsistencySource: "cached quick refinement",
            providerConsistencySource: "provider quick refinement",
            recordsTemplatePinnedTrace: true
        )
        let event = BASProviderRequestEvent.providerSuccess(
            BASProviderRequestAttemptEvent(
                planSummary: BASProviderRequestPlanSummary(
                    task: .quick,
                    preferredProviderID: "foundationModels",
                    orderedProviderIDs: ["foundationModels", "gemmaE4B"],
                    resolvedProviderIDs: ["foundationModels", "gemmaE4B"],
                    compatibleProviderIDs: ["foundationModels", "gemmaE4B"],
                    incompatibleProviderIDs: [],
                    suspendedProviderIDs: [],
                    usedTestingOverride: false,
                    providerSelectionDurationMs: 12
                ),
                provider: MockProvider(id: "gemmaE4B"),
                result: "ignored",
                assessment: BASProviderReleaseAssessment(
                    outputPreview: "provider output",
                    consistencyCheck: nil
                ),
                attemptedProviderIDs: ["foundationModels", "gemmaE4B"]
            )
        )

        let observation = BASAppleProviderOutcomeObserver.observeEvent(
            event,
            context: context,
            durationMs: 640,
            promptPreparedMs: 30,
            admissionEvaluatedMs: 50,
            providerID: { $0.id }
        )

        #expect(observation.telemetryObservation?.input.activeProviderID == "gemmaE4B")
        #expect(observation.telemetryObservation?.compilation.activeBackendID == "coreML")
        #expect(observation.trace?.activeProviderID == "gemmaE4B")
        #expect(observation.trace?.observation.detail.contains("Foundation") == true)
        #expect(observation.trace?.observation.detail.contains("Gemma") == true)
        #expect(observation.circuitEvents == [
            BASAppleProviderCircuitEvent.providerSuccess(
                providerID: "gemmaE4B",
                kind: "quick",
                durationMs: 640
            )
        ])
    }

    @Test("host observation bridge owns provider profile catalogs and trace record compilation")
    func hostObservationBridgeCompilesProfilesAndTraceRecords() {
        let profiles = BASAppleHostProviderObservationBridge.providerProfiles(
            descriptors: [
                MockDescriptor(
                    id: "foundationModels",
                    title: "Foundation",
                    detail: nil,
                    backendID: nil
                ),
                MockDescriptor(
                    id: "gemmaE4B",
                    title: "Gemma",
                    detail: "Core ML: on-device",
                    backendID: "coreML"
                )
            ],
            providerID: \.id,
            title: \.title,
            activeResolutionDetail: \.detail,
            activeBackendID: \.backendID
        )
        let substrateContext = BASAppleProviderObservationContextBuilder.build(
            from: BASAppleProviderObservationSourceInput(
                kind: "quick",
                preferredProviderID: "foundationModels",
                allowFallbacks: true,
                providerProfilesByID: profiles,
                promptBudget: BASPromptBudget(
                    targetCharacters: 220,
                    prefixCharacters: 80,
                    suffixCharacters: 60
                ),
                prompt: "live prompt",
                baselineOutputPreview: "preview",
                deterministicFallbackOutputPreview: "fallback",
                recordsTemplatePinnedTrace: true
            )
        )
        let traceRecord = BASAppleHostProviderObservationBridge.traceRecord(
            context: BASAppleHostProviderObservationContext(
                kind: MockTraceKind.quick,
                frontstageState: "frontstage",
                contextState: "context",
                neuralState: "neural",
                brainState: "brain",
                runtimeStrategy: "strategy",
                promptBudget: BASPromptBudget(
                    targetCharacters: 220,
                    prefixCharacters: 80,
                    suffixCharacters: 60
                ),
                admissionDecision: "allowed",
                substrateContext: substrateContext
            ),
            observedTrace: BASAppleObservedProviderTrace(
                activeProviderID: "gemmaE4B",
                attemptedProviderIDs: ["foundationModels", "gemmaE4B"],
                consistencyCheck: BASConsistencyCheckResult(
                    violations: [
                        BASConsistencyViolation(
                            kind: .modeMismatch,
                            message: "Drifted away from quick mode."
                        )
                    ]
                ),
                consistencyRejected: true,
                observation: BASAppleProviderTraceObservation(
                    detail: "Gemma handled quick refinement.",
                    compilation: BASAppleProviderTraceCompilation(
                        allowsSensitivePayload: false,
                        storedPrompt: "[REDACTED LIVE PROMPT]\nsemantic-1",
                        storedOutputPreview: "[REDACTED LIVE OUTPUT]",
                        executionTrace: BASExecutionTrace(
                            inputSummary: "quick prompt",
                            selectedRoute: .local(
                                "gemmaE4B",
                                fallbackModelIDs: ["foundationModels"]
                            ),
                            memoriesRecalled: ["memory"],
                            toolsCalled: [],
                            latency: BASTraceLatencyBreakdown(
                                routeSelectionMs: 12,
                                retrievalMs: 0,
                                generationMs: 640,
                                toolMs: 0
                            ),
                            outputSummary: "provider output"
                        )
                    )
                )
            )
        )

        #expect(profiles["gemmaE4B"]?.activeBackendID == "coreML")
        #expect(traceRecord.kind == MockTraceKind.quick)
        #expect(traceRecord.preferredProviderID == "foundationModels")
        #expect(traceRecord.activeProviderID == "gemmaE4B")
        #expect(traceRecord.usedFallback)
        #expect(traceRecord.frontstageState == "frontstage")
        #expect(traceRecord.consistencyRejected)
        #expect(traceRecord.detail.contains("Gemma"))
    }

    @Test("host observation bridge applies circuit events through host closures")
    func hostObservationBridgeAppliesCircuitEvents() async {
        final class Recorder: @unchecked Sendable {
            var values: [String] = []
        }

        let recorder = Recorder()

        await BASAppleHostProviderObservationBridge.applyCircuitEvent(
            .cacheHit(providerID: "foundationModels"),
            providerForID: MockProviderKind.init(rawValue:),
            kindForID: MockTraceKind.init(rawValue:),
            onCacheHit: { provider in
                recorder.values.append("cache:\(provider.rawValue)")
            },
            onProviderFailure: { provider in
                recorder.values.append("failure:\(provider.rawValue)")
            },
            onProviderSuccess: { provider, kind, durationMs in
                recorder.values.append("success:\(provider.rawValue):\(kind.rawValue):\(Int(durationMs))")
            }
        )

        await BASAppleHostProviderObservationBridge.applyCircuitEvent(
            .providerFailure(providerID: "gemmaE4B"),
            providerForID: MockProviderKind.init(rawValue:),
            kindForID: MockTraceKind.init(rawValue:),
            onCacheHit: { provider in
                recorder.values.append("cache:\(provider.rawValue)")
            },
            onProviderFailure: { provider in
                recorder.values.append("failure:\(provider.rawValue)")
            },
            onProviderSuccess: { provider, kind, durationMs in
                recorder.values.append("success:\(provider.rawValue):\(kind.rawValue):\(Int(durationMs))")
            }
        )

        await BASAppleHostProviderObservationBridge.applyCircuitEvent(
            .providerSuccess(providerID: "gemmaE4B", kind: "quick", durationMs: 640),
            providerForID: MockProviderKind.init(rawValue:),
            kindForID: MockTraceKind.init(rawValue:),
            onCacheHit: { provider in
                recorder.values.append("cache:\(provider.rawValue)")
            },
            onProviderFailure: { provider in
                recorder.values.append("failure:\(provider.rawValue)")
            },
            onProviderSuccess: { provider, kind, durationMs in
                recorder.values.append("success:\(provider.rawValue):\(kind.rawValue):\(Int(durationMs))")
            }
        )

        #expect(recorder.values == [
            "cache:foundationModels",
            "failure:gemmaE4B",
            "success:gemmaE4B:quick:640"
        ])
    }

    @Test("host observation executor owns success storage plus circuit telemetry and trace fan-out")
    func hostObservationExecutorOwnsSuccessStoragePlusFanOut() async {
        actor Recorder {
            var stored: [String] = []
            var circuits: [String] = []
            var telemetryProviders: [String] = []
            var traceDetails: [String] = []

            func appendStored(_ value: String) { stored.append(value) }
            func appendCircuit(_ value: String) { circuits.append(value) }
            func appendTelemetry(_ value: String) { telemetryProviders.append(value) }
            func appendTrace(_ value: String) { traceDetails.append(value) }
            func snapshot() -> ([String], [String], [String], [String]) {
                (stored, circuits, telemetryProviders, traceDetails)
            }
        }

        let context: BASAppleHostProviderObservationContext<
            MockTraceKind,
            String,
            String,
            String,
            String,
            String,
            String,
            String
        > = BASAppleHostProviderObservationBridge.context(
            kind: MockTraceKind.quick,
            frontstageState: "frontstage",
            contextState: "scoped",
            neuralState: "neural",
            brainState: "brain",
            runtimeStrategy: "runtime",
            promptBudget: "budget",
            admissionDecision: "admission",
            sourceInput: BASAppleProviderObservationSourceInput(
                kind: "quick",
                preferredProviderID: "foundationModels",
                allowFallbacks: true,
                providerProfilesByID: [
                    "foundationModels": BASAppleProviderProfile(
                        providerID: "foundationModels",
                        title: "Foundation"
                    ),
                    "gemmaE4B": BASAppleProviderProfile(
                        providerID: "gemmaE4B",
                        title: "Gemma",
                        activeResolutionDetail: "Core ML: on-device",
                        activeBackendID: "coreML"
                    )
                ],
                prompt: "live prompt",
                baselineOutputPreview: "baseline preview",
                deterministicFallbackOutputPreview: "fallback preview",
                recordsTemplatePinnedTrace: true
            )
        )

        let event = BASProviderRequestEvent.providerSuccess(
            BASProviderRequestAttemptEvent(
                planSummary: BASProviderRequestPlanSummary(
                    task: .quick,
                    preferredProviderID: "foundationModels",
                    orderedProviderIDs: ["foundationModels", "gemmaE4B"],
                    resolvedProviderIDs: ["foundationModels", "gemmaE4B"],
                    compatibleProviderIDs: ["foundationModels", "gemmaE4B"],
                    incompatibleProviderIDs: [],
                    suspendedProviderIDs: [],
                    usedTestingOverride: false,
                    providerSelectionDurationMs: 12
                ),
                provider: MockProvider(id: "gemmaE4B"),
                result: "stored-result",
                assessment: BASProviderReleaseAssessment(
                    outputPreview: "provider output",
                    consistencyCheck: nil
                ),
                attemptedProviderIDs: ["foundationModels", "gemmaE4B"]
            )
        )

        let recorder = Recorder()

        await BASAppleHostProviderObservationExecutor.handleEvent(
            event,
            context: context,
            durationMs: 640,
            promptPreparedMs: 30,
            admissionEvaluatedMs: 50,
            providerID: { $0.id },
            storeResolvedResult: { _, result in
                await recorder.appendStored(result)
            },
            applyCircuitEvent: { event in
                await recorder.appendCircuit(String(describing: event))
            },
            recordTelemetry: { observation in
                await recorder.appendTelemetry(observation.input.activeProviderID ?? "none")
            },
            recordTrace: { traceRecord in
                await recorder.appendTrace(traceRecord.detail)
            }
        )

        let (stored, circuits, telemetryProviders, traceDetails) = await recorder.snapshot()

        #expect(stored == ["stored-result"])
        #expect(circuits == ["providerSuccess(providerID: \"gemmaE4B\", kind: \"quick\", durationMs: 640.0)"])
        #expect(telemetryProviders == ["gemmaE4B"])
        #expect(traceDetails.count == 1)
        #expect(traceDetails.first?.contains("Gemma") == true)
    }
}
