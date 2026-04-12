import Testing
@testable import BASAppleAdapters
@testable import BASOrchestration
@testable import BASRuntimeCore

@Suite("BASApple Observed Provider Request")
struct BASAppleObservedProviderRequestTests {
    private struct MockProvider: Sendable {
        let id: String
        let available: Bool
    }

    private actor Recorder {
        var circuitEvents: [BASAppleProviderCircuitEvent] = []
        var telemetryKinds: [String] = []
        var traceDetails: [String] = []
        var storedResults: [String] = []

        func recordCircuit(_ event: BASAppleProviderCircuitEvent) {
            circuitEvents.append(event)
        }

        func recordTelemetry(_ kind: String) {
            telemetryKinds.append(kind)
        }

        func recordTrace(_ detail: String) {
            traceDetails.append(detail)
        }

        func recordResult(_ result: String) {
            storedResults.append(result)
        }

        func snapshot() -> (
            circuitEvents: [BASAppleProviderCircuitEvent],
            telemetryKinds: [String],
            traceDetails: [String],
            storedResults: [String]
        ) {
            (circuitEvents, telemetryKinds, traceDetails, storedResults)
        }
    }

    @Test("observed executor composes runtime execution with observation sinks")
    func observedExecutorComposesRuntimeAndObservation() async {
        let provider = MockProvider(id: "gemmaE4B", available: true)
        let descriptors = [
            BASProviderDescriptor(
                providerID: provider.id,
                taskAffinities: [.primary: 100],
                capabilityProfile: BASProviderCapabilityProfile(
                    strengths: [.structuredOutput, .lowLatency],
                    latencyClass: .low,
                    memoryClass: .low,
                    supportedResponseLanguages: [.english],
                    supportsThinking: false,
                    supportsStructuredOutput: true,
                    supportsToolUse: false,
                    bestFor: [.primary]
                )
            )
        ]
        let recorder = Recorder()

        let runtimeInput: BASAppleProviderRequestRuntimeInput<MockProvider> = BASAppleProviderRequestRuntimeInput(
            task: .primary,
            preferredProviderID: provider.id,
            allowFallbacks: true,
            descriptors: descriptors,
            admissionAllowed: true
        )
        let substrateContext = BASAppleProviderObservationContextBuilder.build(
            from: BASAppleProviderObservationSourceInput(
                kind: "primary",
                preferredProviderID: provider.id,
                allowFallbacks: true,
                providerProfilesByID: [
                    provider.id: BASAppleProviderProfile(
                        providerID: provider.id,
                        title: "Gemma"
                    )
                ],
                prompt: "primary prompt",
                baselineOutputPreview: "baseline preview",
                deterministicFallbackOutputPreview: "fallback preview",
                recordsTemplatePinnedTrace: true
            )
        )
        let observationContext: BASAppleHostProviderObservationContext<
            String,
            String,
            String,
            String,
            String,
            String,
            String,
            String
        > = BASAppleHostProviderObservationContext(
            kind: "primary",
            substrateContext: substrateContext
        )

        let outcome: BASProviderRequestOutcome<String, BASProviderReleaseAssessment> =
            await BASAppleObservedProviderRequestExecutor.execute(
            runtimeInput: runtimeInput,
            observationContext: observationContext,
            requestStart: ContinuousClock().now,
            clock: ContinuousClock(),
            promptPreparedMs: 8,
            admissionEvaluatedMs: 12,
            providerID: \.id,
            providerForID: { $0 == provider.id ? provider : nil },
            isAvailable: \.available,
            loadCachedResult: { _ in nil as String? },
            assessCachedResult: { _ in
                .allow(
                    BASProviderReleaseAssessment(
                        outputPreview: "unused",
                        consistencyCheck: nil
                    )
                )
            },
            quarantineCachedResult: { _ in },
            invokeProvider: { candidate in
                candidate.id == provider.id ? "refined primary" : nil
            },
            assessProviderResult: { value in
                .allow(
                    BASProviderReleaseAssessment(
                        outputPreview: value,
                        consistencyCheck: nil
                    )
                )
            },
            storeResolvedResult: { _, result in
                await recorder.recordResult(result)
            },
            applyCircuitEvent: { event in
                await recorder.recordCircuit(event)
            },
            recordTelemetry: { observation in
                await recorder.recordTelemetry(observation.input.kind)
            },
            recordTrace: { trace in
                await recorder.recordTrace(trace.detail)
            }
        )
        let snapshot = await recorder.snapshot()

        switch outcome {
        case .resolved(let resolution):
            #expect(resolution.execution.result == "refined primary")
            #expect(resolution.execution.providerID == provider.id)
        default:
            Issue.record("Expected observed executor to resolve the provider request.")
        }

        #expect(snapshot.storedResults == ["refined primary"])
        #expect(snapshot.telemetryKinds == ["primary"])
        #expect(snapshot.traceDetails.count == 1)
        #expect(
            snapshot.circuitEvents.contains {
                if case let .providerSuccess(providerID, kind, _) = $0 {
                    return providerID == provider.id && kind == "primary"
                }
                return false
            }
        )
    }
}
