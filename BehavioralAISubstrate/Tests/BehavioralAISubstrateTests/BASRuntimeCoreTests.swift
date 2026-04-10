import Foundation
import Testing
@testable import BASRuntimeCore

@Suite("BASRuntimeCore")
struct BASRuntimeCoreTests {
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
