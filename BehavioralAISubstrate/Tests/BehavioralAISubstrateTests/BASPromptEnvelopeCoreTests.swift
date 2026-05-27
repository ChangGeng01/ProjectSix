import Testing
@testable import BASOrchestration

#if !os(iOS)  // ch 1022 source-gate: SwiftTesting iOS bundle discovery quirk
@Suite("BASPromptEnvelopeCore")
struct BASPromptEnvelopeCoreTests {
    @Test("prompt envelope compiler preserves layered prompt budget and compaction trace")
    func promptEnvelopeCompilerBuildsStableLayers() {
        let retainedBlock = BASSemanticPromptBlock(
            kind: .frontstageState,
            body: #"{"focus_goal":"interrupt"}"#,
            retention: .required,
            priority: 100
        )
        let droppedBlock = BASSemanticPromptBlock(
            kind: .evidenceSnippets,
            body: "- lower value evidence",
            retention: .optional,
            priority: 40
        )

        let assembly = BASSemanticContextAssembly(
            allBlocks: [retainedBlock, droppedBlock],
            retainedBlocks: [retainedBlock],
            droppedBlocks: [droppedBlock],
            compactionPolicy: BASSemanticCompactionPolicy(
                preservedKinds: [.frontstageState, .outputGuard],
                preferredKinds: [.runtimeStrategy],
                dropOrder: [.evidenceSnippets],
                guidance: ["Keep the interruption state in front."],
                suffixTargetCharacters: 140
            ),
            suffixTargetCharacters: 140,
            kernelSnapshot: dummyKernelSnapshot()
        )

        let envelope = BASPromptEnvelopeCompiler.compile(
            BASPromptEnvelopeRequest(
                kind: "primary",
                immutablePrefix: "Kernel identity.",
                adaptivePrefix: "Primary mode rules.",
                assembly: assembly,
                frontstageState: "frontstage",
                openTextSignalCount: 2,
                targetCharacters: 320
            )
        )

        #expect(envelope.instructions == "Kernel identity.\n\nPrimary mode rules.")
        #expect(envelope.payload == retainedBlock.rendered)
        #expect(envelope.layers.stablePrefix == "Kernel identity.\n\nPrimary mode rules.")
        #expect(envelope.runtimePrompt == "Kernel identity.\n\nPrimary mode rules.\n\n\(retainedBlock.rendered)")
        #expect(envelope.budget.isWithinTarget)
        #expect(envelope.budget.immutablePrefixCharacters == "Kernel identity.".count)
        #expect(envelope.budget.adaptivePrefixCharacters == "Primary mode rules.".count)
        #expect(envelope.budget.promptPressureSnapshot.prefixCharacters == envelope.budget.prefixCharacters)
        #expect(envelope.debugPrompt.contains("[COMPACTION]"))
        #expect(envelope.debugPrompt.contains("evidence_snippets"))
    }

    @Test("semantic assembly exposes retained and dropped block kinds")
    func semanticAssemblyExposesBlockKinds() {
        let assembly = BASSemanticContextAssembly(
            allBlocks: [
                BASSemanticPromptBlock(
                    kind: .frontstageState,
                    body: "{}",
                    retention: .required,
                    priority: 100
                ),
                BASSemanticPromptBlock(
                    kind: .brainState,
                    body: "{}",
                    retention: .optional,
                    priority: 10
                )
            ],
            retainedBlocks: [
                BASSemanticPromptBlock(
                    kind: .frontstageState,
                    body: "{}",
                    retention: .required,
                    priority: 100
                )
            ],
            droppedBlocks: [
                BASSemanticPromptBlock(
                    kind: .brainState,
                    body: "{}",
                    retention: .optional,
                    priority: 10
                )
            ],
            compactionPolicy: BASSemanticCompactionPolicy(
                preservedKinds: [.frontstageState],
                preferredKinds: [],
                dropOrder: [.brainState],
                guidance: [],
                suffixTargetCharacters: 100
            ),
            suffixTargetCharacters: 100,
            kernelSnapshot: dummyKernelSnapshot()
        )

        #expect(assembly.retainedBlockKinds == [.frontstageState])
        #expect(assembly.droppedBlockKinds == [.brainState])
    }
}

private func dummyKernelSnapshot() -> BASCognitionKernelSnapshot {
    BASCognitionKernelSnapshot(
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
}
#endif
