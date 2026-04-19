import Testing
@testable import BASAppleAdapters
@testable import BASRuntimeCore

@Suite("BASApple Provider Request Runtime")
struct BASAppleProviderRequestRuntimeTests {
    private struct MockProvider: Sendable {
        let id: String
        let available: Bool
    }

    private func providerDescriptor(
        id: String,
        bestFor: [BASAdaptiveTraceKind],
        strengths: [BASProviderCapability],
        latencyClass: BASProviderLatencyClass,
        memoryClass: BASProviderMemoryClass,
        languages: [BASAdaptiveResponseLanguage],
        supportsThinking: Bool
    ) -> BASProviderDescriptor {
        BASProviderDescriptor(
            providerID: id,
            taskAffinities: Dictionary(
                uniqueKeysWithValues: bestFor.map { ($0, 100) }
            ),
            capabilityProfile: BASProviderCapabilityProfile(
                strengths: strengths,
                latencyClass: latencyClass,
                memoryClass: memoryClass,
                supportedResponseLanguages: languages,
                supportsThinking: supportsThinking,
                supportsStructuredOutput: strengths.contains(.structuredOutput),
                supportsToolUse: strengths.contains(.lightToolUse),
                bestFor: bestFor
            )
        )
    }

    @Test("runtime executor short-circuits template-pinned and admission-skipped requests")
    func runtimeExecutorShortCircuits() async {
        let providers = [
            "local-fast": MockProvider(id: "local-fast", available: true)
        ]

        let templatePinned = await BASAppleProviderRequestRuntimeExecutor.executeObserved(
            input: BASAppleProviderRequestRuntimeInput(
                task: .primary,
                preferredProviderID: BASReferenceProviderRuntime.templateProviderID,
                allowFallbacks: true,
                descriptors: [],
                routingPolicy: BASReferenceProviderRuntime.fixtureRoutingPolicy,
                admissionAllowed: true
            ),
            providerID: \.id,
            providerForID: { providers[$0] },
            isAvailable: \.available,
            loadCachedResult: { _ in nil as String? },
            assessCachedResult: { _ in .allow("unused") },
            quarantineCachedResult: { _ in },
            invokeProvider: { _ in nil as String? },
            assessProviderResult: { _ in .allow("unused") }
        )

        switch templatePinned {
        case .templatePinned:
            break
        default:
            Issue.record("Expected template-pinned requests to short-circuit in the Apple runtime executor.")
        }

        let admissionSkipped = await BASAppleProviderRequestRuntimeExecutor.executeObserved(
            input: BASAppleProviderRequestRuntimeInput(
                task: .primary,
                preferredProviderID: "local-fast",
                allowFallbacks: true,
                descriptors: [],
                routingPolicy: BASReferenceProviderRuntime.fixtureRoutingPolicy,
                admissionAllowed: false
            ),
            providerID: \.id,
            providerForID: { providers[$0] },
            isAvailable: \.available,
            loadCachedResult: { _ in nil as String? },
            assessCachedResult: { _ in .allow("unused") },
            quarantineCachedResult: { _ in },
            invokeProvider: { _ in nil as String? },
            assessProviderResult: { _ in .allow("unused") }
        )

        switch admissionSkipped {
        case .admissionSkipped:
            break
        default:
            Issue.record("Expected admission-skipped requests to short-circuit in the Apple runtime executor.")
        }
    }

    @Test("runtime executor composes planning and execution through the substrate request runner")
    func runtimeExecutorComposesPlanningAndExecution() async {
        let providers = [
            BASReferenceProviderRuntime.foundationModelsProviderID: MockProvider(
                id: BASReferenceProviderRuntime.foundationModelsProviderID,
                available: true
            ),
            BASReferenceProviderRuntime.gemmaE4BProviderID: MockProvider(
                id: BASReferenceProviderRuntime.gemmaE4BProviderID,
                available: true
            )
        ]

        let descriptors = [
            providerDescriptor(
                id: BASReferenceProviderRuntime.foundationModelsProviderID,
                bestFor: [.primary],
                strengths: [.structuredOutput, .lowLatency, .lowMemory],
                latencyClass: .low,
                memoryClass: .low,
                languages: [.english],
                supportsThinking: false
            ),
            providerDescriptor(
                id: BASReferenceProviderRuntime.gemmaE4BProviderID,
                bestFor: [.reflective],
                strengths: [.structuredOutput, .deepReflection, .retrievalGrounding],
                latencyClass: .high,
                memoryClass: .high,
                languages: [.english],
                supportsThinking: true
            )
        ]

        let outcome = await BASAppleProviderRequestRuntimeExecutor.executeObserved(
            input: BASAppleProviderRequestRuntimeInput(
                task: .reflective,
                preferredProviderID: BASReferenceProviderRuntime.foundationModelsProviderID,
                allowFallbacks: true,
                strategy: BASAdaptiveTaskStrategy(
                    kind: .reflective,
                    entropy: .high,
                    runtimeGear: .high,
                    contextBudget: 1800,
                    retrievalMode: .adaptive,
                    thinkingMode: .gated,
                    outputMode: .reflectiveStructured,
                    tone: .reflectiveClear,
                    actionSpace: ["reflect", "stay_brief"],
                    responseLanguage: .english,
                    allowsModelInvocation: true
                ),
                descriptors: descriptors,
                routingPolicy: BASReferenceProviderRuntime.fixtureRoutingPolicy,
                admissionAllowed: true
            ),
            providerID: \.id,
            providerForID: { providers[$0] },
            isAvailable: \.available,
            loadCachedResult: { _ in nil as String? },
            assessCachedResult: { _ in .allow("unused") },
            quarantineCachedResult: { _ in },
            invokeProvider: { provider in
                provider.id == BASReferenceProviderRuntime.gemmaE4BProviderID ? "refined" : nil
            },
            assessProviderResult: { value in
                .allow("allow-\(value)")
            }
        )

        switch outcome {
        case .resolved(let resolution):
            #expect(resolution.planSummary.task == BASAdaptiveTraceKind.reflective)
            #expect(resolution.planSummary.preferredProviderID == BASReferenceProviderRuntime.foundationModelsProviderID)
            #expect(resolution.planSummary.orderedProviderIDs.first == BASReferenceProviderRuntime.gemmaE4BProviderID)
            #expect(resolution.planSummary.resolvedProviderIDs == [BASReferenceProviderRuntime.gemmaE4BProviderID])
            #expect(resolution.execution.source == BASProviderExecutionResolutionSource.providerSuccess)
            #expect(resolution.execution.providerID == BASReferenceProviderRuntime.gemmaE4BProviderID)
            #expect(resolution.execution.result == "refined")
            #expect(resolution.execution.assessment == "allow-refined")
        default:
            Issue.record("Expected the Apple runtime executor to resolve through the substrate request runner.")
        }
    }

    @Test("runtime executor carries injected routing policy provenance through plan summaries")
    func runtimeExecutorCarriesRoutingPolicyMetadata() async {
        let providers = [
            "custom-primary": MockProvider(id: "custom-primary", available: false),
            "custom-fallback": MockProvider(id: "custom-fallback", available: true)
        ]

        let descriptors = [
            providerDescriptor(
                id: "custom-primary",
                bestFor: [.primary],
                strengths: [.structuredOutput],
                latencyClass: .medium,
                memoryClass: .medium,
                languages: [.english],
                supportsThinking: false
            ),
            providerDescriptor(
                id: "custom-fallback",
                bestFor: [.primary],
                strengths: [.structuredOutput, .lowLatency],
                latencyClass: .low,
                memoryClass: .low,
                languages: [.english],
                supportsThinking: false
            )
        ]

        let policy = BASProviderRoutingPolicy(
            schemaVersion: "field-rollout.v2",
            deterministicProviderID: BASReferenceProviderRuntime.templateProviderID,
            preferenceOrderings: [
                BASProviderPreferenceOrdering(
                    preferredProviderID: "custom-primary",
                    orderedProviderIDs: ["custom-primary", "custom-fallback"]
                )
            ]
        )

        let outcome = await BASAppleProviderRequestRuntimeExecutor.executeObserved(
            input: BASAppleProviderRequestRuntimeInput(
                task: .primary,
                preferredProviderID: "custom-primary",
                allowFallbacks: true,
                descriptors: descriptors,
                routingPolicy: policy,
                routingRegistryVersion: "registry.rollout.v2",
                admissionAllowed: true
            ),
            providerID: \.id,
            providerForID: { providers[$0] },
            isAvailable: \.available,
            loadCachedResult: { _ in nil as String? },
            assessCachedResult: { _ in .allow("unused") },
            quarantineCachedResult: { _ in },
            invokeProvider: { provider in
                provider.id == "custom-fallback" ? "resolved" : nil
            },
            assessProviderResult: { value in
                .allow("allow-\(value)")
            }
        )

        switch outcome {
        case .resolved(let resolution):
            #expect(resolution.planSummary.appliedRoutingPolicyVersion == "field-rollout.v2")
            #expect(resolution.planSummary.appliedRoutingRegistryVersion == "registry.rollout.v2")
            #expect(resolution.planSummary.orderedProviderIDs == ["custom-primary", "custom-fallback"])
            #expect(resolution.execution.providerID == "custom-fallback")
        default:
            Issue.record("Expected injected routing metadata to survive provider planning and execution.")
        }
    }
}
