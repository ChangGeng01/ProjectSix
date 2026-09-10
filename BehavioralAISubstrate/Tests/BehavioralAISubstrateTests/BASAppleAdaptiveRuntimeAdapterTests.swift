import Testing
@testable import BASAppleAdapters
@testable import BASRuntimeCore

@Suite("BASApple Adaptive Runtime Adapter")
struct BASAppleAdaptiveRuntimeAdapterTests {
    @Test("matrix compilation keeps tier, device, and provider preference policy package-owned")
    func matrixCompilationKeepsTierAndProviderPolicyPackageOwned() {
        let compilation = BASAppleAdaptiveRuntimeAdapter.compileMatrix(
            request: BASAppleAdaptiveMatrixRequest(
                executionTierID: "balancedGemma",
                preferredProviderID: "foundationModels",
                allowFallbacks: true,
                isSimulator: false,
                physicalMemoryGB: 7,
                isLowPowerModeEnabled: false,
                preferredLanguages: ["en-AU"]
            )
        )

        #expect(compilation.matrix.runtimeGear == .balanced)
        #expect(compilation.matrix.environmentClass == .normal)
        #expect(compilation.matrix.deviceClass == .balancedPhone)
        #expect(compilation.matrix.languageMode == .english)
        #expect(compilation.preferredProviderIDByKind[BASAdaptiveTraceKind.primaryID] == "template")
        #expect(compilation.preferredProviderIDByKind[BASAdaptiveTraceKind.comparativeID] == "foundationModels")
        #expect(compilation.matrix.strategy(for: .primary).allowsModelInvocation == false)
        #expect(compilation.matrix.strategy(for: .reflective).allowsModelInvocation == true)
    }

    @Test("adapter compiles brief session signals and adapts strategy inside the package")
    func adapterCompilesBriefSignalsAndAdaptsStrategy() {
        let base = BASAdaptiveTaskStrategy(
            kind: .primary,
            entropy: .medium,
            runtimeGear: .balanced,
            contextBudget: 220,
            retrievalMode: .adaptive,
            thinkingMode: .gated,
            outputMode: .guidedShort,
            tone: .neutral,
            actionSpace: ["encourage"],
            responseLanguage: .english,
            allowsModelInvocation: true
        )

        let adapted = BASAppleAdaptiveRuntimeAdapter.adapt(
            strategy: base,
            with: BASAppleAdaptiveRuntimeInput(
                briefLanguageWeight: 0.81,
                lowCognitiveLoadWeight: 0.65,
                fatigueStrength: 0.72,
                emotionLoadStrength: 0.31,
                sessionBiases: ["Keep it brief", "avoid heavy analysis"],
                interruptiveActionBias: 0.84,
                urgencyStrength: 0.76,
                boundaryNamingBias: 0.22,
                boundaryRiskStrength: 0.15,
                tradeoffClarityBias: 0.2,
                rebuiltSession: false,
                staleFieldCount: 0,
                screenedOutMemoryCount: 0,
                lowTrustLoad: false,
                retrievalInstability: false,
                retrievalTags: ["lang:english"]
            )
        )

        #expect(adapted.runtimeGear == .low)
        #expect(adapted.thinkingMode == .off)
        #expect(adapted.tone == .briefWarm)
        #expect(adapted.actionSpace.contains("stay_brief"))
        #expect(adapted.actionSpace.contains("save_state"))
    }

    @Test("adapter guards retrieval when memory trust is unstable")
    func adapterGuardsRetrievalWhenSignalsAreUnstable() {
        let base = BASAdaptiveTaskStrategy(
            kind: .reflective,
            entropy: .high,
            runtimeGear: .balanced,
            contextBudget: 440,
            retrievalMode: .adaptive,
            thinkingMode: .gated,
            outputMode: .reflectiveStructured,
            tone: .reflectiveClear,
            actionSpace: ["name_pattern"],
            responseLanguage: .english,
            allowsModelInvocation: true
        )

        let adapted = BASAppleAdaptiveRuntimeAdapter.adapt(
            strategy: base,
            with: BASAppleAdaptiveRuntimeInput(
                briefLanguageWeight: 0.2,
                lowCognitiveLoadWeight: 0.3,
                fatigueStrength: 0.25,
                emotionLoadStrength: 0.2,
                sessionBiases: [],
                interruptiveActionBias: 0.18,
                urgencyStrength: 0.15,
                boundaryNamingBias: 0.9,
                boundaryRiskStrength: 0.92,
                tradeoffClarityBias: 0.25,
                rebuiltSession: true,
                staleFieldCount: 2,
                screenedOutMemoryCount: 4,
                lowTrustLoad: true,
                retrievalInstability: true,
                retrievalTags: ["lang:chinese"]
            )
        )

        #expect(adapted.retrievalMode == .filtered)
        #expect(adapted.retrievalItemBudget <= 3)
        #expect(adapted.actionSpace.contains("name_boundary"))
        #expect(adapted.responseLanguage == .chinese)
    }

    @Test("adapter guards retrieval when horizon quarantine and evidence caveat load are present")
    func adapterGuardsRetrievalWhenHorizonPressureIsPresent() {
        let base = BASAdaptiveTaskStrategy(
            kind: .reflective,
            entropy: .high,
            runtimeGear: .balanced,
            contextBudget: 440,
            retrievalMode: .adaptive,
            thinkingMode: .gated,
            outputMode: .reflectiveStructured,
            tone: .reflectiveClear,
            actionSpace: ["name_pattern"],
            responseLanguage: .english,
            allowsModelInvocation: true
        )

        let adapted = BASAppleAdaptiveRuntimeAdapter.adapt(
            strategy: base,
            with: BASAppleAdaptiveRuntimeInput(
                briefLanguageWeight: 0.2,
                lowCognitiveLoadWeight: 0.3,
                fatigueStrength: 0.25,
                emotionLoadStrength: 0.2,
                sessionBiases: [],
                interruptiveActionBias: 0.18,
                urgencyStrength: 0.15,
                boundaryNamingBias: 0.55,
                boundaryRiskStrength: 0.52,
                tradeoffClarityBias: 0.25,
                rebuiltSession: false,
                staleFieldCount: 0,
                screenedOutMemoryCount: 0,
                lowTrustLoad: false,
                retrievalInstability: false,
                retrievalTags: ["mirror"],
                externallyRefreshedCandidateCount: 1,
                quarantinedObservationCount: 1,
                evidenceCaveatedCandidateCount: 1,
                externalRefreshGuardTriggered: true,
                observationOnlyQuarantine: true,
                evidenceCaveatLoad: true
            )
        )

        #expect(adapted.retrievalMode == .filtered)
        #expect(adapted.retrievalItemBudget <= 2)
    }
}
