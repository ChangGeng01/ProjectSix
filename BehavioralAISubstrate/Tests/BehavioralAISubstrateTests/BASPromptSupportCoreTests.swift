import Testing
@testable import BASOrchestration
@testable import BASRuntimeCore

@Suite("BASPromptSupportCore")
struct BASPromptSupportCoreTests {
    @Test("prefix catalog splits immutable and adaptive prompt layers by task kind")
    func prefixCatalogSeparatesStableAndAdaptiveLayers() {
        let immutable = BASPromptPrefixCatalog.immutablePrefix(for: .quick)
        let adaptive = BASPromptPrefixCatalog.adaptivePrefix(for: .quick)
        let instructions = BASPromptPrefixCatalog.instructions(for: .quick)

        #expect(immutable.contains("host-owned cognition system"))
        #expect(adaptive.contains("Refine only the supplied primary guidance fields."))
        #expect(instructions == immutable + "\n" + adaptive)
    }

    @Test("prompt presentation behavior lets hosts override prefixes and retention policy")
    func promptPresentationBehaviorHonorsHostOverrides() {
        let behavior = BASPromptPresentationBehavior(
            sharedPrelude: "Host immutable shell.",
            adaptivePrefixByKindID: [
                BASSemanticTaskKind.quick.rawValue: "Host quick framing."
            ],
            baseEvidenceRetentionBudgetByKindID: [
                BASSemanticTaskKind.quick.rawValue: 6
            ],
            lowGearClampKindIDs: [
                BASSemanticTaskKind.quick.rawValue
            ],
            lowGearClampMaximumBudget: 4
        )
        let strategy = BASAdaptiveTaskStrategy(
            kind: .quick,
            entropy: .low,
            runtimeGear: .low,
            contextBudget: 220,
            retrievalItemBudget: 7,
            retrievalMode: .adaptive,
            thinkingMode: .off,
            outputMode: .guidedShort,
            tone: .briefWarm,
            actionSpace: ["encourage"],
            responseLanguage: .english,
            allowsModelInvocation: true
        )

        #expect(BASPromptPrefixCatalog.immutablePrefix(for: .quick, behavior: behavior) == "Host immutable shell.")
        #expect(BASPromptPrefixCatalog.adaptivePrefix(for: .quick, behavior: behavior) == "Host quick framing.")
        #expect(
            BASPromptRetentionAdvisor.evidenceRetentionBudget(
                for: .quick,
                strategy: strategy,
                behavior: behavior
            ) == 4
        )
    }

    @Test("text sanitizer collapses whitespace and clips deterministically")
    func sanitizerCollapsesAndClips() {
        let value = BASPromptTextSanitizer.sanitized(
            "  This   is   a\nvery long      line that should become tighter and eventually clip cleanly. ",
            fallback: "Fallback line",
            limit: 32
        )

        #expect(value == "This is a very long line that sh…")
    }

    @Test("fingerprints stay stable for identical prompts and change across runtime/stable layers")
    func fingerprintsReflectPromptIdentity() {
        let envelope = BASPromptEnvelopeCompiler.compile(
            BASPromptEnvelopeRequest(
                kind: "quick",
                immutablePrefix: "Kernel identity.",
                adaptivePrefix: "Quick rules.",
                assembly: dummyAssembly(payload: #"{"mode":"Quick"}"#),
                frontstageState: "frontstage",
                openTextSignalCount: 1,
                targetCharacters: 320
            )
        )

        let firstCache = BASPromptFingerprinting.cacheFingerprint(
            providerIdentifier: "gemma",
            envelope: envelope
        )
        let secondCache = BASPromptFingerprinting.cacheFingerprint(
            providerIdentifier: "gemma",
            semanticPrompt: envelope.runtimePrompt
        )

        #expect(firstCache == secondCache)
        #expect(BASPromptFingerprinting.semanticFingerprint(for: envelope).count == 64)
        #expect(BASPromptFingerprinting.stablePrefixFingerprint(for: envelope).count == 64)
        #expect(
            BASPromptFingerprinting.semanticFingerprint(for: envelope) !=
            BASPromptFingerprinting.stablePrefixFingerprint(for: envelope)
        )
    }

    @Test("retention advisor clamps low gear quick and reminder retrieval budgets")
    func retentionAdvisorHonorsStrategyAndLowGearClamp() {
        let lowQuickStrategy = BASAdaptiveTaskStrategy(
            kind: .quick,
            entropy: .low,
            runtimeGear: .low,
            contextBudget: 220,
            retrievalItemBudget: 7,
            retrievalMode: .adaptive,
            thinkingMode: .off,
            outputMode: .guidedShort,
            tone: .briefWarm,
            actionSpace: ["encourage"],
            responseLanguage: .english,
            allowsModelInvocation: true
        )
        let normalMirrorStrategy = BASAdaptiveTaskStrategy(
            kind: .mirror,
            entropy: .medium,
            runtimeGear: .balanced,
            contextBudget: 600,
            retrievalItemBudget: 3,
            retrievalMode: .adaptive,
            thinkingMode: .gated,
            outputMode: .reflectiveStructured,
            tone: .reflectiveClear,
            actionSpace: ["reflect"],
            responseLanguage: .english,
            allowsModelInvocation: true
        )

        #expect(
            BASPromptRetentionAdvisor.evidenceRetentionBudget(for: .quick, strategy: lowQuickStrategy) == 3
        )
        #expect(
            BASPromptRetentionAdvisor.evidenceRetentionBudget(for: .reminder, strategy: lowQuickStrategy) == 3
        )
        #expect(
            BASPromptRetentionAdvisor.evidenceRetentionBudget(for: .mirror, strategy: normalMirrorStrategy) == 3
        )
    }
}

private func dummyAssembly(payload: String) -> BASSemanticContextAssembly {
    let retainedBlock = BASSemanticPromptBlock(
        kind: .frontstageState,
        body: payload,
        retention: .required,
        priority: 100
    )

    return BASSemanticContextAssembly(
        allBlocks: [retainedBlock],
        retainedBlocks: [retainedBlock],
        droppedBlocks: [],
        compactionPolicy: BASSemanticCompactionPolicy(
            preservedKinds: [.frontstageState],
            preferredKinds: [],
            dropOrder: [],
            guidance: [],
            suffixTargetCharacters: 100
        ),
        suffixTargetCharacters: 100,
        kernelSnapshot: BASCognitionKernelSnapshot(
            compiledPrompt: BASCompiledPrompt(
                policy: BASContextCompilationPolicy(targetCharacters: 120),
                retainedBlocks: [],
                stablePrefixBlocks: [],
                volatileSuffixBlocks: [],
                droppedBlocks: [],
                stablePrefixPrompt: "",
                volatileSuffixPrompt: "",
                renderedPrompt: "",
                stablePrefixFingerprint: "stable",
                semanticFingerprint: "semantic"
            ),
            truthState: nil,
            kernelPolicy: BASContextKernelPolicy(),
            kernelBlockCount: 0,
            activeBlockCount: 0,
            summaryBlockCount: 0,
            retrievalBlockCount: 0
        )
    )
}
