import Foundation
import Testing
@testable import BASRuntimeCore

@Suite("BASRuntimeCore")
struct BASRuntimeCoreTests {
    @Test("provider attempt executor can reject cached output and continue to a successful provider result")
    func providerAttemptExecutorRejectsCacheAndContinues() async {
        struct FakeProvider: Equatable {
            let id: String
        }

        struct Assessment: Sendable, Equatable {
            let label: String
        }

        let providers = [
            FakeProvider(id: "local-a"),
            FakeProvider(id: "local-b")
        ]
        let cached: [String: String] = [
            "local-a": "cached-a"
        ]
        let generated: [String: String] = [
            "local-b": "fresh-b"
        ]

        actor Recorder {
            var quarantined: [String] = []
            var events: [String] = []

            func quarantine(_ id: String) {
                quarantined.append(id)
            }

            func record(_ value: String) {
                events.append(value)
            }
        }

        let recorder = Recorder()
        let outcome = await BASProviderAttemptExecutor.execute(
            providers: providers,
            providerID: \.id,
            loadCachedResult: { provider in
                cached[provider.id]
            },
            assessCachedResult: { value in
                value == "cached-a" ? .reject(Assessment(label: "reject-cache")) : .allow(Assessment(label: "cache"))
            },
            quarantineCachedResult: { provider in
                await recorder.quarantine(provider.id)
            },
            invokeProvider: { provider in
                generated[provider.id]
            },
            assessProviderResult: { value in
                .allow(Assessment(label: "allow-\(value)"))
            },
            onCachedRejected: { provider, _, assessment, attempted in
                await recorder.record("cached-reject:\(provider.id):\(assessment.label):\(attempted.joined(separator: ","))")
            },
            onProviderSuccess: { provider, _, assessment, attempted in
                await recorder.record("provider-success:\(provider.id):\(assessment.label):\(attempted.joined(separator: ","))")
            },
            onProviderMiss: { provider, attempted in
                await recorder.record("provider-miss:\(provider.id):\(attempted.joined(separator: ","))")
            }
        )

        switch outcome {
        case .resolved(let resolution):
            #expect(resolution.source == .providerSuccess)
            #expect(resolution.providerID == "local-b")
            #expect(resolution.attemptedProviderIDs == ["local-a", "local-b"])
            #expect(resolution.result == "fresh-b")
            #expect(resolution.assessment == Assessment(label: "allow-fresh-b"))
        case .noResult:
            Issue.record("Expected provider success after rejecting cached output.")
        }

        let quarantined = await recorder.quarantined
        let events = await recorder.events
        #expect(quarantined == ["local-a"])
        #expect(events == [
            "cached-reject:local-a:reject-cache:local-a",
            "provider-success:local-b:allow-fresh-b:local-a,local-b"
        ])
    }

    @Test("provider attempt executor reports no result after misses and rejected outputs")
    func providerAttemptExecutorReportsNoResult() async {
        struct FakeProvider: Equatable {
            let id: String
        }

        struct Assessment: Sendable, Equatable {
            let label: String
        }

        let providers = [
            FakeProvider(id: "local-a"),
            FakeProvider(id: "local-b")
        ]

        actor Recorder {
            var events: [String] = []

            func record(_ value: String) {
                events.append(value)
            }
        }

        let recorder = Recorder()
        let outcome = await BASProviderAttemptExecutor.execute(
            providers: providers,
            providerID: \.id,
            loadCachedResult: { _ in nil },
            assessCachedResult: { _ in .allow(Assessment(label: "unused")) },
            quarantineCachedResult: { _ in },
            invokeProvider: { provider in
                provider.id == "local-b" ? "reject-me" : nil
            },
            assessProviderResult: { value in
                .reject(Assessment(label: value))
            },
            onProviderRejected: { provider, _, assessment, attempted in
                await recorder.record("provider-reject:\(provider.id):\(assessment.label):\(attempted.joined(separator: ","))")
            },
            onProviderMiss: { provider, attempted in
                await recorder.record("provider-miss:\(provider.id):\(attempted.joined(separator: ","))")
            }
        )

        switch outcome {
        case .resolved:
            Issue.record("Expected no result after miss and rejected provider outputs.")
        case .noResult(let attemptedProviderIDs):
            #expect(attemptedProviderIDs == ["local-a", "local-b"])
        }

        let events = await recorder.events
        #expect(events == [
            "provider-miss:local-a:local-a",
            "provider-reject:local-b:reject-me:local-a,local-b"
        ])
    }

    @Test("executable provider resolver applies testing override and availability filtering")
    func executableProviderResolverAppliesOverrideAndAvailability() {
        struct FakeProvider: Equatable {
            let id: String
            let available: Bool
        }

        let providers = [
            "local-a": FakeProvider(id: "local-a", available: true),
            "local-b": FakeProvider(id: "local-b", available: false),
            "local-c": FakeProvider(id: "local-c", available: true)
        ]

        let normal = BASExecutableProviderResolver.resolve(
            orderedProviderIDs: ["local-a", "local-b", "local-a", "local-c"],
            providerID: \.id,
            providerForID: { providers[$0] },
            isAvailable: \.available
        )
        let overridden = BASExecutableProviderResolver.resolve(
            orderedProviderIDs: ["local-a", "local-c"],
            testingOverrideProvider: FakeProvider(id: "testing-stub", available: true),
            providerID: \.id,
            providerForID: { providers[$0] },
            isAvailable: \.available
        )

        #expect(normal.providers == [FakeProvider(id: "local-a", available: true), FakeProvider(id: "local-c", available: true)])
        #expect(normal.resolvedProviderIDs == ["local-a", "local-c"])
        #expect(!normal.usedTestingOverride)

        #expect(overridden.providers == [FakeProvider(id: "testing-stub", available: true)])
        #expect(overridden.resolvedProviderIDs == ["testing-stub"])
        #expect(overridden.usedTestingOverride)
    }

    @Test("provider route resolver combines base ordering with task-aware planning")
    func providerRouteResolverCombinesBaseOrderingAndPlanning() {
        let plan = BASProviderRouteResolver.resolve(
            task: .mirror,
            preferredProviderID: "local-fast",
            allowFallbacks: true,
            deterministicProviderID: "template",
            preferenceOrderings: [
                BASProviderPreferenceOrdering(
                    preferredProviderID: "local-fast",
                    orderedProviderIDs: ["local-fast", "reflective-large", "template"]
                )
            ],
            strategy: BASAdaptiveTaskStrategy(
                kind: .mirror,
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
            descriptors: [
                providerDescriptor(
                    id: "local-fast",
                    bestFor: [.quick],
                    strengths: [.structuredOutput, .lowLatency, .lowMemory],
                    latencyClass: .low,
                    memoryClass: .low,
                    languages: [.english],
                    supportsThinking: false
                ),
                providerDescriptor(
                    id: "reflective-large",
                    bestFor: [.mirror],
                    strengths: [.structuredOutput, .deepReflection, .retrievalGrounding],
                    latencyClass: .high,
                    memoryClass: .high,
                    languages: [.english],
                    supportsThinking: true
                ),
                providerDescriptor(
                    id: "template",
                    bestFor: [.quick],
                    strengths: [.structuredOutput, .lowLatency],
                    latencyClass: .low,
                    memoryClass: .low,
                    languages: [.english],
                    supportsThinking: false
                )
            ]
        )

        #expect(plan.orderedProviderIDs.first == "reflective-large")
        #expect(plan.compatibleProviderIDs.contains("reflective-large"))
        #expect(plan.rationale.contains(where: { $0.contains("Selected reflective-large ahead of the preferred provider") }))
    }

    @Test("executable provider planner composes task-aware plan with availability filtering")
    func executableProviderPlannerComposesPlanAndResolution() {
        struct FakeProvider: Equatable {
            let id: String
            let available: Bool
        }

        let providers = [
            "local-fast": FakeProvider(id: "local-fast", available: true),
            "reflective-large": FakeProvider(id: "reflective-large", available: true),
            "template": FakeProvider(id: "template", available: true)
        ]

        let planning = BASExecutableProviderPlanner.resolve(
            task: .mirror,
            preferredProviderID: "local-fast",
            allowFallbacks: true,
            deterministicProviderID: "template",
            preferenceOrderings: [
                BASProviderPreferenceOrdering(
                    preferredProviderID: "local-fast",
                    orderedProviderIDs: ["local-fast", "reflective-large", "template"]
                )
            ],
            strategy: BASAdaptiveTaskStrategy(
                kind: .mirror,
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
            descriptors: [
                providerDescriptor(
                    id: "local-fast",
                    bestFor: [.quick],
                    strengths: [.structuredOutput, .lowLatency, .lowMemory],
                    latencyClass: .low,
                    memoryClass: .low,
                    languages: [.english],
                    supportsThinking: false
                ),
                providerDescriptor(
                    id: "reflective-large",
                    bestFor: [.mirror],
                    strengths: [.structuredOutput, .deepReflection, .retrievalGrounding],
                    latencyClass: .high,
                    memoryClass: .high,
                    languages: [.english],
                    supportsThinking: true
                ),
                providerDescriptor(
                    id: "template",
                    bestFor: [.quick],
                    strengths: [.structuredOutput, .lowLatency],
                    latencyClass: .low,
                    memoryClass: .low,
                    languages: [.english],
                    supportsThinking: false
                )
            ],
            providerID: \.id,
            providerForID: { providers[$0] },
            isAvailable: \.available
        )

        #expect(planning.plan.orderedProviderIDs.first == "reflective-large")
        #expect(planning.plan.compatibleProviderIDs == ["reflective-large"])
        #expect(planning.plan.incompatibleProviderIDs == ["local-fast", "template"])
        #expect(planning.providers == [FakeProvider(id: "reflective-large", available: true)])
        #expect(planning.resolvedProviderIDs == ["reflective-large"])
        #expect(!planning.usedTestingOverride)
    }

    @Test("provider request runner short-circuits template pin and admission skip")
    func providerRequestRunnerShortCircuitsTemplateAndAdmission() async {
        struct FakeProvider: Equatable {
            let id: String
            let available: Bool
        }

        let providers = [
            "local-fast": FakeProvider(id: "local-fast", available: true)
        ]

        let templatePinned = await BASProviderRequestRunner.execute(
            task: .quick,
            preferredProviderID: "template",
            allowFallbacks: true,
            deterministicProviderID: "template",
            preferenceOrderings: [],
            descriptors: [],
            providerID: \.id,
            providerForID: { providers[$0] },
            isAvailable: \.available,
            admissionAllowed: true,
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
            Issue.record("Expected template pin to short-circuit the request runner.")
        }

        let admissionSkipped = await BASProviderRequestRunner.execute(
            task: .quick,
            preferredProviderID: "local-fast",
            allowFallbacks: true,
            deterministicProviderID: "template",
            preferenceOrderings: [
                BASProviderPreferenceOrdering(
                    preferredProviderID: "local-fast",
                    orderedProviderIDs: ["local-fast"]
                )
            ],
            descriptors: [],
            providerID: \.id,
            providerForID: { providers[$0] },
            isAvailable: \.available,
            admissionAllowed: false,
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
            Issue.record("Expected admission denial to short-circuit the request runner.")
        }
    }

    @Test("provider request runner composes planning summary and resolved execution")
    func providerRequestRunnerComposesPlanningSummaryAndExecution() async {
        struct FakeProvider: Equatable {
            let id: String
            let available: Bool
        }

        let providers = [
            "local-fast": FakeProvider(id: "local-fast", available: true),
            "reflective-large": FakeProvider(id: "reflective-large", available: true)
        ]

        let outcome = await BASProviderRequestRunner.execute(
            task: .mirror,
            preferredProviderID: "local-fast",
            allowFallbacks: true,
            deterministicProviderID: "template",
            preferenceOrderings: [
                BASProviderPreferenceOrdering(
                    preferredProviderID: "local-fast",
                    orderedProviderIDs: ["local-fast", "reflective-large"]
                )
            ],
            strategy: BASAdaptiveTaskStrategy(
                kind: .mirror,
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
            descriptors: [
                providerDescriptor(
                    id: "local-fast",
                    bestFor: [.quick],
                    strengths: [.structuredOutput, .lowLatency, .lowMemory],
                    latencyClass: .low,
                    memoryClass: .low,
                    languages: [.english],
                    supportsThinking: false
                ),
                providerDescriptor(
                    id: "reflective-large",
                    bestFor: [.mirror],
                    strengths: [.structuredOutput, .deepReflection, .retrievalGrounding],
                    latencyClass: .high,
                    memoryClass: .high,
                    languages: [.english],
                    supportsThinking: true
                )
            ],
            providerID: \.id,
            providerForID: { providers[$0] },
            isAvailable: \.available,
            admissionAllowed: true,
            loadCachedResult: { _ in nil as String? },
            assessCachedResult: { _ in .allow("unused") },
            quarantineCachedResult: { _ in },
            invokeProvider: { provider in
                provider.id == "reflective-large" ? "refined" : nil
            },
            assessProviderResult: { value in
                .allow("allow-\(value)")
            }
        )

        switch outcome {
        case .resolved(let resolution):
            #expect(resolution.planSummary.task == .mirror)
            #expect(resolution.planSummary.preferredProviderID == "local-fast")
            #expect(resolution.planSummary.orderedProviderIDs.first == "reflective-large")
            #expect(resolution.planSummary.resolvedProviderIDs == ["reflective-large"])
            #expect(resolution.planSummary.compatibleProviderIDs == ["reflective-large"])
            #expect(resolution.planSummary.incompatibleProviderIDs == ["local-fast"])
            #expect(resolution.planSummary.providerSelectionDurationMs >= 0)
            #expect(resolution.execution.source == .providerSuccess)
            #expect(resolution.execution.providerID == "reflective-large")
            #expect(resolution.execution.result == "refined")
            #expect(resolution.execution.assessment == "allow-refined")
        default:
            Issue.record("Expected provider request runner to produce a resolved execution.")
        }
    }

    @Test("local only routing stays on device and keeps deterministic fallbacks")
    func localOnlyRoutingStaysOnDevice() {
        let registry = BASCapabilityRegistry(descriptors: [
            descriptor(
                id: "local-fast",
                route: .local,
                latency: "fast",
                cost: 0.2,
                context: 2048
            ),
            descriptor(
                id: "local-slow",
                route: .local,
                latency: "slow",
                cost: 0.8,
                context: 4096
            ),
            descriptor(
                id: "cloud-large",
                route: .cloud,
                latency: "slow",
                cost: 0.4,
                context: 8192
            )
        ])

        let advisory = BASDefaultRoutingPlanner.plan(
            context: context(privacy: .localOnly, networkAvailable: true, lowPower: true),
            registry: registry
        )

        #expect(advisory.route.routeKind == .local)
        #expect(advisory.route.preferredModelID == "local-fast")
        #expect(advisory.route.fallbackModelIDs == ["local-slow"])
        #expect(advisory.rationale.contains(where: { $0.contains("fully local") }))
    }

    @Test("cloud allowed routing can choose remote when budgets demand it")
    func cloudAllowedRoutingCanChooseRemote() {
        let registry = BASCapabilityRegistry(descriptors: [
            descriptor(
                id: "local-small",
                route: .local,
                latency: "fast",
                cost: 0.1,
                context: 512
            ),
            descriptor(
                id: "cloud-large",
                route: .cloud,
                latency: "slow",
                cost: 0.5,
                context: 8192
            )
        ])

        let advisory = BASDefaultRoutingPlanner.plan(
            context: context(
                taskKind: .plan,
                gear: .high,
                privacy: .cloudAllowed,
                networkAvailable: true,
                lowPower: false,
                contextTokens: 4096
            ),
            registry: registry
        )

        #expect(advisory.route.routeKind == .cloud)
        #expect(advisory.route.preferredModelID == "cloud-large")
        #expect(advisory.fallbackGraph.primary.timeoutMs >= 800)
    }

    @Test("thermal and low power pressure prefer cheaper fast descriptors")
    func thermalAndLowPowerPreferCheaperFastDescriptors() {
        let registry = BASCapabilityRegistry(descriptors: [
            descriptor(
                id: "local-fast",
                route: .local,
                latency: "fast",
                cost: 0.1,
                context: 2048
            ),
            descriptor(
                id: "local-rich",
                route: .local,
                latency: "slow",
                cost: 0.9,
                context: 8192
            )
        ])

        let advisory = BASDefaultRoutingPlanner.plan(
            context: BASRuntimeContext(
                taskKind: .chat,
                gear: .low,
                deviceProfile: BASDeviceProfile(
                    modelName: "iPhone",
                    memoryMB: 4096,
                    batteryLevel: 0.14,
                    lowPowerMode: true,
                    thermalState: "serious"
                ),
                privacyMode: .localFirst,
                riskLevel: .medium,
                networkAvailable: true,
                budget: BASExecutionBudget(
                    contextTokens: 1024,
                    outputTokens: 300,
                    retrievalItems: 3,
                    toolCalls: 1,
                    timeBudgetMs: 1200
                )
            ),
            registry: registry
        )

        #expect(advisory.route.preferredModelID == "local-fast")
        #expect(advisory.rationale.contains(where: { $0.contains("Thermal pressure") }))
        #expect(advisory.rationale.contains(where: { $0.contains("Low power") }))
    }

    @Test("execution lanes classify deterministic, generative, and retrieval-assisted work distinctly")
    func executionLanesClassifyDistinctly() {
        let deterministicLane = BASExecutionLanePlanner.classify(
            context: context(
                taskKind: .summarize,
                privacy: .localOnly,
                networkAvailable: false,
                lowPower: true,
                contextTokens: 384,
                outputTokens: 160,
                retrievalItems: 0
            ),
            route: .local("local-template"),
            capabilities: BASModelCapabilities(
                supportsGeneration: true,
                supportsEmbeddings: false,
                supportsTools: true,
                supportsStructuredOutput: true,
                supportsHybridRouting: false,
                latencyClass: "fast"
            )
        )
        let generativeLane = BASExecutionLanePlanner.classify(
            context: context(
                taskKind: .chat,
                privacy: .localFirst,
                networkAvailable: true,
                lowPower: false,
                contextTokens: 1536,
                outputTokens: 360,
                retrievalItems: 0
            ),
            route: .cloud("cloud-gen"),
            capabilities: BASModelCapabilities(
                supportsGeneration: true,
                supportsEmbeddings: false,
                supportsTools: true,
                supportsStructuredOutput: true,
                supportsHybridRouting: true,
                latencyClass: "slow"
            )
        )
        let retrievalLane = BASExecutionLanePlanner.classify(
            context: context(
                taskKind: .retrieve,
                privacy: .localFirst,
                networkAvailable: true,
                lowPower: false,
                contextTokens: 1536,
                outputTokens: 280,
                retrievalItems: 5
            ),
            route: .hybrid(local: "local-rag"),
            capabilities: BASModelCapabilities(
                supportsGeneration: true,
                supportsEmbeddings: true,
                supportsTools: true,
                supportsStructuredOutput: true,
                supportsHybridRouting: true,
                latencyClass: "balanced"
            )
        )

        #expect(deterministicLane.kind == .deterministic)
        #expect(deterministicLane.requiresModelInvocation == false)
        #expect(deterministicLane.traceHeadline.contains("Deterministic"))

        #expect(generativeLane.kind == .generative)
        #expect(generativeLane.requiresModelInvocation == true)
        #expect(generativeLane.preferredRouteKinds.contains(.cloud))

        #expect(retrievalLane.kind == .retrievalAssisted)
        #expect(retrievalLane.requiresRetrieval == true)
        #expect(retrievalLane.traceHeadline.contains("Retrieval"))
    }

    @Test("routing advisory carries the execution lane alongside the selected route")
    func routingAdvisoryCarriesExecutionLane() {
        let registry = BASCapabilityRegistry(descriptors: [
            descriptor(
                id: "local-rag",
                route: .local,
                latency: "fast",
                cost: 0.2,
                context: 2048,
                embeddings: true
            ),
            descriptor(
                id: "local-fallback",
                route: .local,
                latency: "fast",
                cost: 0.4,
                context: 1024
            )
        ])

        let advisory = BASDefaultRoutingPlanner.plan(
            context: context(
                taskKind: .retrieve,
                privacy: .localFirst,
                networkAvailable: true,
                lowPower: false,
                contextTokens: 1024,
                outputTokens: 220,
                retrievalItems: 3
            ),
            registry: registry
        )

        #expect(advisory.executionLane.kind == .retrievalAssisted)
        #expect(advisory.executionLane.requiresRetrieval)
        #expect(advisory.rationale.contains(where: { $0.contains("Retrieval-assisted lane") }))
    }

    @Test("adaptive matrix downgrades mixed-language mirror work to filtered retrieval")
    func adaptiveMatrixDowngradesMixedLanguageMirrorWork() {
        let matrix = BASAdaptiveRuntimeMatrixResolver.resolve(
            request: BASAdaptiveRuntimeMatrixRequest(
                runtimeGear: .balanced,
                environmentClass: .normal,
                deviceClass: .balancedPhone,
                languageMode: .mixed,
                allowFallbacks: true,
                allowsModelInvocationByKind: [
                    .quick: false,
                    .balance: true,
                    .mirror: true,
                    .reminder: true
                ]
            )
        )

        #expect(matrix.runtimeGear == .balanced)
        #expect(matrix.strategy(for: .quick).allowsModelInvocation == false)
        #expect(matrix.strategy(for: .quick).outputMode == .deterministicTemplate)
        #expect(matrix.strategy(for: .mirror).runtimeGear == .balanced)
        #expect(matrix.strategy(for: .mirror).retrievalMode == .filtered)
        #expect(matrix.strategy(for: .mirror).thinkingMode == .off)
        #expect(matrix.strategy(for: .mirror).tone == .groundedDirect)
        #expect(matrix.strategy(for: .mirror).responseLanguage == .mixed)
        #expect(matrix.strategy(for: .quick).executionLane.kind == .deterministic)
        #expect(matrix.executionLane(for: .mirror).kind == .retrievalAssisted)
    }

    @Test("adaptive matrix allows high-gear mirror thinking only on full phones in stable language mode")
    func adaptiveMatrixAllowsHighGearMirrorThinkingOnlyOnFullPhones() {
        let fullPhoneMatrix = BASAdaptiveRuntimeMatrixResolver.resolve(
            request: BASAdaptiveRuntimeMatrixRequest(
                runtimeGear: .high,
                environmentClass: .normal,
                deviceClass: .fullPhone,
                languageMode: .english,
                allowFallbacks: true,
                allowsModelInvocationByKind: [
                    .quick: true,
                    .balance: true,
                    .mirror: true,
                    .reminder: true
                ]
            )
        )
        let constrainedMatrix = BASAdaptiveRuntimeMatrixResolver.resolve(
            request: BASAdaptiveRuntimeMatrixRequest(
                runtimeGear: .high,
                environmentClass: .lowPower,
                deviceClass: .memoryConstrainedPhone,
                languageMode: .english,
                allowFallbacks: true,
                allowsModelInvocationByKind: [
                    .quick: true,
                    .balance: true,
                    .mirror: true,
                    .reminder: true
                ]
            )
        )

        #expect(fullPhoneMatrix.strategy(for: .mirror).runtimeGear == .high)
        #expect(fullPhoneMatrix.strategy(for: .mirror).thinkingMode == .gated)
        #expect(constrainedMatrix.strategy(for: .mirror).runtimeGear == .low)
        #expect(constrainedMatrix.strategy(for: .mirror).thinkingMode == .off)
        #expect(constrainedMatrix.strategy(for: .mirror).actionSpace.contains("save_state"))
        #expect(constrainedMatrix.strategy(for: .mirror).actionSpace.contains("stay_brief"))
    }

    @Test("adaptive runtime helpers classify device and language deterministically")
    func adaptiveRuntimeHelpersClassifyDeterministically() {
        let simulatorProfile = BASDeviceProfile(
            modelName: "simulator",
            memoryMB: 8192,
            batteryLevel: 1.0,
            lowPowerMode: false,
            thermalState: "nominal"
        )
        let balancedProfile = BASDeviceProfile(
            modelName: "iphone-7gb",
            memoryMB: 7 * 1024,
            batteryLevel: 0.7,
            lowPowerMode: false,
            thermalState: "nominal"
        )

        #expect(BASAdaptiveRuntimeMatrixResolver.environmentClass(for: simulatorProfile) == .simulator)
        #expect(BASAdaptiveRuntimeMatrixResolver.deviceClass(for: simulatorProfile) == .simulator)
        #expect(BASAdaptiveRuntimeMatrixResolver.environmentClass(for: balancedProfile) == .normal)
        #expect(BASAdaptiveRuntimeMatrixResolver.deviceClass(for: balancedProfile) == .balancedPhone)
        #expect(BASLanguageMode.detect(preferredLanguages: ["en-AU", "zh-Hans"]) == .mixed)
        #expect(BASLanguageMode.detect(sampleTexts: ["我今晚又想买东西"]) == .chinese)
        #expect(BASLanguageMode.detect(preferredLanguages: ["en-AU"], sampleTexts: ["我今晚又想买东西"]) == .chinese)
    }

    @Test("adaptive task strategy compacts low-load mirror work with brief-session signals")
    func adaptiveTaskStrategyCompactsLowLoadMirrorWorkWithBriefSignals() {
        let base = BASAdaptiveTaskStrategy(
            kind: .mirror,
            entropy: .high,
            runtimeGear: .high,
            contextBudget: 620,
            retrievalMode: .adaptive,
            thinkingMode: .gated,
            outputMode: .reflectiveStructured,
            tone: .reflectiveClear,
            actionSpace: ["name_pattern"],
            responseLanguage: .english,
            allowsModelInvocation: true
        )

        let adapted = base.adapting(
            signals: BASAdaptiveRuntimeSignals(
                briefBias: 0.92,
                fatigueSignal: 0.82,
                hasBriefSessionBias: true,
                interruptiveBias: 0.41,
                boundaryBias: 0.3,
                tradeoffBias: 0.22,
                rebuiltSession: false,
                staleFieldCount: 0,
                screenedOutMemoryCount: 0,
                lowTrustLoad: false,
                retrievalInstability: false,
                retrievalTags: []
            )
        )

        #expect(adapted.runtimeGear == .low)
        #expect(adapted.contextBudget < base.contextBudget)
        #expect(adapted.outputCharacterBudget < base.outputCharacterBudget)
        #expect(adapted.timeBudgetMs < base.timeBudgetMs)
        #expect(adapted.thinkingMode == .off)
        #expect(adapted.tone == .briefWarm)
        #expect(adapted.actionSpace.contains("stay_brief"))
    }

    @Test("adaptive task strategy guards retrieval and infers response language from governed tags")
    func adaptiveTaskStrategyGuardsRetrievalAndInfersResponseLanguage() {
        let base = BASAdaptiveTaskStrategy(
            kind: .mirror,
            entropy: .high,
            runtimeGear: .balanced,
            contextBudget: 520,
            retrievalMode: .adaptive,
            thinkingMode: .off,
            outputMode: .reflectiveStructured,
            tone: .reflectiveClear,
            actionSpace: ["name_pattern"],
            responseLanguage: .english,
            allowsModelInvocation: true
        )

        let adapted = base.adapting(
            signals: BASAdaptiveRuntimeSignals(
                briefBias: 0.18,
                fatigueSignal: 0.22,
                hasBriefSessionBias: false,
                interruptiveBias: 0.1,
                boundaryBias: 0.28,
                tradeoffBias: 0.24,
                rebuiltSession: true,
                staleFieldCount: 2,
                screenedOutMemoryCount: 4,
                lowTrustLoad: true,
                retrievalInstability: false,
                retrievalTags: ["mirror", "lang:chinese", "relationship"]
            )
        )

        #expect(adapted.retrievalMode == .filtered)
        #expect(adapted.retrievalItemBudget <= 3)
        #expect(adapted.responseLanguage == .chinese)
    }

    @Test("adaptive task strategy promotes boundary-first mirror work and tradeoff-first balance work")
    func adaptiveTaskStrategyPromotesBoundaryAndTradeoffWorkWhenSignalsAreStrong() {
        let mirrorBase = BASAdaptiveTaskStrategy(
            kind: .mirror,
            entropy: .high,
            runtimeGear: .balanced,
            contextBudget: 520,
            retrievalMode: .adaptive,
            thinkingMode: .off,
            outputMode: .reflectiveStructured,
            tone: .reflectiveClear,
            actionSpace: ["name_pattern"],
            responseLanguage: .english,
            allowsModelInvocation: true
        )
        let mirrorAdapted = mirrorBase.adapting(
            signals: BASAdaptiveRuntimeSignals(
                briefBias: 0.3,
                fatigueSignal: 0.2,
                hasBriefSessionBias: false,
                interruptiveBias: 0.15,
                boundaryBias: 0.92,
                tradeoffBias: 0.24,
                rebuiltSession: false,
                staleFieldCount: 0,
                screenedOutMemoryCount: 0,
                lowTrustLoad: false,
                retrievalInstability: false,
                retrievalTags: []
            )
        )

        #expect(mirrorAdapted.runtimeGear == .high)
        #expect(mirrorAdapted.thinkingMode == .gated)
        #expect(mirrorAdapted.actionSpace.contains("name_boundary"))
        #expect(mirrorAdapted.contextBudget > mirrorBase.contextBudget)

        let balanceBase = BASAdaptiveTaskStrategy(
            kind: .balance,
            entropy: .medium,
            runtimeGear: .balanced,
            contextBudget: 440,
            retrievalMode: .filtered,
            thinkingMode: .off,
            outputMode: .structuredBoard,
            tone: .groundedDirect,
            actionSpace: ["name_tradeoff"],
            responseLanguage: .english,
            allowsModelInvocation: true
        )
        let balanceAdapted = balanceBase.adapting(
            signals: BASAdaptiveRuntimeSignals(
                briefBias: 0.24,
                fatigueSignal: 0.18,
                hasBriefSessionBias: false,
                interruptiveBias: 0.12,
                boundaryBias: 0.22,
                tradeoffBias: 0.91,
                rebuiltSession: false,
                staleFieldCount: 0,
                screenedOutMemoryCount: 0,
                lowTrustLoad: false,
                retrievalInstability: false,
                retrievalTags: []
            )
        )

        #expect(balanceAdapted.runtimeGear == .high)
        #expect(balanceAdapted.thinkingMode == .gated)
        #expect(balanceAdapted.actionSpace.contains("surface_priority"))
        #expect(balanceAdapted.contextBudget > balanceBase.contextBudget)
    }

    @Test("provider planner filters incompatible providers before scoring")
    func providerPlannerFiltersIncompatibleProvidersBeforeScoring() {
        let strategy = BASAdaptiveTaskStrategy(
            kind: .mirror,
            entropy: .high,
            runtimeGear: .high,
            contextBudget: 900,
            retrievalMode: .adaptive,
            thinkingMode: .gated,
            outputMode: .reflectiveStructured,
            tone: .reflectiveClear,
            actionSpace: ["name_boundary", "stay_brief"],
            responseLanguage: .chinese,
            allowsModelInvocation: true
        )

        let plan = BASProviderPlanner.plan(
            task: .mirror,
            preferredProviderID: "open-model",
            baseOrderedProviderIDs: ["open-model", "gemma", "foundation"],
            strategy: strategy,
            descriptors: [
                providerDescriptor(
                    id: "open-model",
                    bestFor: [.quick, .reminder],
                    strengths: [.structuredOutput, .lowLatency, .lowMemory],
                    latencyClass: .low,
                    memoryClass: .low,
                    languages: [.english],
                    supportsThinking: false
                ),
                providerDescriptor(
                    id: "gemma",
                    bestFor: [.balance, .mirror, .reminder],
                    strengths: [.structuredOutput, .deepReflection, .retrievalGrounding, .multilingualChinese],
                    latencyClass: .medium,
                    memoryClass: .medium,
                    languages: [.english, .chinese, .mixed],
                    supportsThinking: true
                ),
                providerDescriptor(
                    id: "foundation",
                    bestFor: [.quick, .reminder],
                    strengths: [.structuredOutput, .lowLatency, .lowMemory, .multilingualChinese],
                    latencyClass: .low,
                    memoryClass: .low,
                    languages: [.english, .chinese, .mixed],
                    supportsThinking: false
                )
            ]
        )

        #expect(plan.compatibleProviderIDs == ["gemma"])
        #expect(plan.orderedProviderIDs == ["gemma"])
        #expect(plan.incompatibleProviderIDs == ["open-model", "foundation"])
    }

    @Test("provider planner preserves base order when scores tie")
    func providerPlannerPreservesBaseOrderWhenScoresTie() {
        let plan = BASProviderPlanner.plan(
            task: .quick,
            preferredProviderID: "foundation",
            baseOrderedProviderIDs: ["foundation", "gemma"],
            strategy: nil,
            descriptors: [
                providerDescriptor(
                    id: "foundation",
                    bestFor: [.quick],
                    strengths: [.structuredOutput, .lowLatency, .lowMemory],
                    latencyClass: .low,
                    memoryClass: .low,
                    languages: [.english],
                    supportsThinking: false
                ),
                providerDescriptor(
                    id: "gemma",
                    bestFor: [.quick],
                    strengths: [.structuredOutput, .lowLatency, .lowMemory],
                    latencyClass: .low,
                    memoryClass: .low,
                    languages: [.english],
                    supportsThinking: false
                )
            ]
        )

        #expect(plan.orderedProviderIDs == ["foundation", "gemma"])
    }

    @Test("provider planner favors brief low-gear providers when strategy is constrained")
    func providerPlannerFavorsBriefLowGearProvidersWhenStrategyIsConstrained() {
        let strategy = BASAdaptiveTaskStrategy(
            kind: .quick,
            entropy: .low,
            runtimeGear: .low,
            contextBudget: 320,
            retrievalMode: .filtered,
            thinkingMode: .off,
            outputMode: .guidedShort,
            tone: .briefWarm,
            actionSpace: ["encourage", "stay_brief"],
            responseLanguage: .english,
            allowsModelInvocation: true
        )

        let plan = BASProviderPlanner.plan(
            task: .quick,
            preferredProviderID: "gemma",
            baseOrderedProviderIDs: ["gemma", "foundation"],
            strategy: strategy,
            descriptors: [
                providerDescriptor(
                    id: "gemma",
                    bestFor: [.balance, .mirror],
                    strengths: [.structuredOutput, .deepReflection],
                    latencyClass: .high,
                    memoryClass: .high,
                    languages: [.english],
                    supportsThinking: true
                ),
                providerDescriptor(
                    id: "foundation",
                    bestFor: [.quick, .reminder],
                    strengths: [.structuredOutput, .lowLatency, .lowMemory],
                    latencyClass: .low,
                    memoryClass: .low,
                    languages: [.english],
                    supportsThinking: false
                )
            ]
        )

        #expect(plan.orderedProviderIDs.first == "foundation")
        #expect(plan.rationale.contains(where: { $0.contains("capability scoring") }))
    }

    @Test("runtime availability resolver prefers the first available provider")
    func runtimeAvailabilityResolverPrefersFirstAvailableProvider() {
        let plan = BASRuntimeAvailabilityResolver.resolve(
            preferredProviderID: "foundation",
            allowFallbacks: true,
            runtimeEnabled: true,
            deterministicProviderID: "template",
            orderedProviderIDs: ["foundation", "gemma"],
            statusesByID: [
                "foundation": BASProviderStatusRecord(
                    providerID: "foundation",
                    isAvailable: false,
                    title: "Foundation",
                    detail: "Unavailable."
                ),
                "gemma": BASProviderStatusRecord(
                    providerID: "gemma",
                    isAvailable: true,
                    title: "Gemma",
                    detail: "Ready."
                )
            ]
        )

        #expect(plan.source == .fallbackProvider)
        #expect(plan.activeProviderID == "gemma")
        #expect(plan.fallbackProviderID == "gemma")
        #expect(plan.unavailableProviderID == "foundation")
    }

    @Test("runtime availability resolver falls back to deterministic mode when runtime is disabled")
    func runtimeAvailabilityResolverFallsBackToDeterministicModeWhenDisabled() {
        let plan = BASRuntimeAvailabilityResolver.resolve(
            preferredProviderID: "foundation",
            allowFallbacks: true,
            runtimeEnabled: false,
            deterministicProviderID: "template",
            orderedProviderIDs: ["foundation", "gemma"],
            statusesByID: [:]
        )

        #expect(plan.source == .runtimeDisabled)
        #expect(plan.activeProviderID == "template")
        #expect(plan.fallbackProviderID == nil)
    }

    @Test("provider ordering resolver applies preference chain and suspended filtering")
    func providerOrderingResolverAppliesPreferenceChainAndFiltering() {
        let orderings = [
            BASProviderPreferenceOrdering(
                preferredProviderID: "open-model",
                orderedProviderIDs: ["open-model", "gemma", "foundation"]
            ),
            BASProviderPreferenceOrdering(
                preferredProviderID: "foundation",
                orderedProviderIDs: ["foundation", "gemma"]
            )
        ]

        #expect(
            BASProviderOrderingResolver.orderedProviderIDs(
                preferredProviderID: "open-model",
                allowFallbacks: true,
                deterministicProviderID: "template",
                preferenceOrderings: orderings,
                suspendedProviderIDs: ["open-model"]
            ) == ["gemma", "foundation"]
        )

        #expect(
            BASProviderOrderingResolver.orderedProviderIDs(
                preferredProviderID: "foundation",
                allowFallbacks: false,
                deterministicProviderID: "template",
                preferenceOrderings: orderings,
                suspendedProviderIDs: []
            ) == ["foundation"]
        )
    }

    @Test("runtime status resolver composes ordering availability and narration")
    func runtimeStatusResolverComposesOrderingAvailabilityAndNarration() {
        let summary = BASRuntimeStatusResolver.resolve(
            preferredProviderID: "foundation",
            allowFallbacks: true,
            runtimeEnabled: true,
            deterministicProviderID: "template",
            preferenceOrderings: [
                BASProviderPreferenceOrdering(
                    preferredProviderID: "foundation",
                    orderedProviderIDs: ["foundation", "gemma"]
                )
            ],
            statusesByID: [
                "foundation": BASProviderStatusRecord(
                    providerID: "foundation",
                    isAvailable: false,
                    title: "Foundation",
                    detail: "Foundation is unavailable."
                ),
                "gemma": BASProviderStatusRecord(
                    providerID: "gemma",
                    isAvailable: true,
                    title: "Gemma",
                    detail: "Gemma is ready."
                )
            ]
        )

        #expect(summary.orderedProviderIDs == ["foundation", "gemma"])
        #expect(summary.activeProviderID == "gemma")
        #expect(summary.fallbackProviderID == "gemma")
        #expect(summary.detail.contains("Foundation is not available"))
    }

    @Test("reference provider runtime exposes default fallback ordering")
    func referenceProviderRuntimeExposesDefaultFallbackOrdering() {
        #expect(
            BASReferenceProviderRuntime.orderedProviderIDs(
                preferredProviderID: BASReferenceProviderRuntime.openModelProviderID,
                allowFallbacks: true,
                suspendedProviderIDs: [BASReferenceProviderRuntime.openModelProviderID]
            ) == [
                BASReferenceProviderRuntime.gemmaE4BProviderID,
                BASReferenceProviderRuntime.foundationModelsProviderID
            ]
        )

        #expect(
            BASReferenceProviderRuntime.orderedProviderIDs(
                preferredProviderID: BASReferenceProviderRuntime.foundationModelsProviderID,
                allowFallbacks: false
            ) == [
                BASReferenceProviderRuntime.foundationModelsProviderID
            ]
        )
    }

    @Test("reference provider runtime composes active status with testing override")
    func referenceProviderRuntimeComposesActiveStatusWithTestingOverride() {
        let summary = BASReferenceProviderRuntime.runtimeStatusSummary(
            preferredProviderID: BASReferenceProviderRuntime.foundationModelsProviderID,
            allowFallbacks: true,
            runtimeEnabled: true,
            statusesByID: [
                BASReferenceProviderRuntime.foundationModelsProviderID: BASProviderStatusRecord(
                    providerID: BASReferenceProviderRuntime.foundationModelsProviderID,
                    isAvailable: false,
                    title: "Foundation",
                    detail: "Foundation is unavailable."
                ),
                BASReferenceProviderRuntime.gemmaE4BProviderID: BASProviderStatusRecord(
                    providerID: BASReferenceProviderRuntime.gemmaE4BProviderID,
                    isAvailable: true,
                    title: "Gemma",
                    detail: "Gemma is ready."
                )
            ],
            testingOverrideEnabled: true,
            testingOverrideTitle: "Stub runtime"
        )

        #expect(summary.activeProviderID == BASReferenceProviderRuntime.testingStubProviderID)
        #expect(summary.fallbackProviderID == BASReferenceProviderRuntime.testingStubProviderID)
        #expect(summary.detail.contains("Stub runtime"))
    }

    @Test("runtime availability narrator explains deterministic fallback when fallback is disabled")
    func runtimeAvailabilityNarratorExplainsDeterministicFallback() {
        let detail = BASRuntimeAvailabilityNarrator.detail(
            plan: BASRuntimeAvailabilityPlan(
                preferredProviderID: "foundation",
                activeProviderID: "template",
                fallbackProviderID: "template",
                source: .deterministicFallback,
                unavailableProviderID: "foundation"
            ),
            allowFallbacks: false,
            statusesByID: [
                "foundation": BASProviderStatusRecord(
                    providerID: "foundation",
                    isAvailable: false,
                    title: "Foundation",
                    detail: "Foundation is unavailable."
                )
            ],
            orderedProviderIDs: ["foundation", "gemma"]
        )

        #expect(detail.contains("Automatic model fallback is off"))
        #expect(detail.contains("deterministic local copy"))
    }

    private func context(
        taskKind: BASTaskKind = .chat,
        gear: BASRuntimeGear = .balanced,
        privacy: BASPrivacyMode,
        networkAvailable: Bool,
        lowPower: Bool,
        contextTokens: Int = 1024,
        outputTokens: Int = 300,
        retrievalItems: Int = 4
    ) -> BASRuntimeContext {
        BASRuntimeContext(
            taskKind: taskKind,
            gear: gear,
            deviceProfile: BASDeviceProfile(
                modelName: "iPhone",
                memoryMB: 6144,
                batteryLevel: 0.8,
                lowPowerMode: lowPower,
                thermalState: "nominal"
            ),
            privacyMode: privacy,
            riskLevel: .medium,
            networkAvailable: networkAvailable,
            budget: BASExecutionBudget(
                contextTokens: contextTokens,
                outputTokens: outputTokens,
                retrievalItems: retrievalItems,
                toolCalls: 2,
                timeBudgetMs: 2000
            )
        )
    }

    private func descriptor(
        id: String,
        route: BASRouteKind,
        latency: String,
        cost: Double,
        context: Int,
        embeddings: Bool = false
    ) -> BASModelDescriptor {
        BASModelDescriptor(
            modelID: id,
            routeKind: route,
            capabilities: BASModelCapabilities(
                supportsGeneration: true,
                supportsEmbeddings: embeddings,
                supportsTools: true,
                supportsStructuredOutput: true,
                supportsHybridRouting: route != .local,
                latencyClass: latency
            ),
            supportedTaskKinds: [.chat, .plan, .retrieve, .tool, .summarize],
            relativeCostScore: cost,
            maximumContextTokens: context
        )
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
}
