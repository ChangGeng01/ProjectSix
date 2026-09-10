import Foundation
import Testing
@testable import BASOrchestration
@testable import BASRuntimeCore

@Suite("BASContextCompiler")
struct BASContextCompilerTests {
    @Test("required blocks survive compaction and stay in the stable prefix")
    func requiredBlocksSurviveCompactionAndStayInStablePrefix() {
        let compiled = BASContextCompiler.compile(
            BASContextCompilationRequest(
                blocks: [
                    block(
                        id: "kernel.identity",
                        layer: .kernel,
                        title: "Kernel",
                        content: "Keep",
                        retention: .required,
                        priority: 100
                    ),
                    block(
                        id: "active.intent",
                        layer: .active,
                        title: "Active",
                        content: "Keep",
                        retention: .required,
                        priority: 90
                    ),
                    block(
                        id: "summary.goal",
                        layer: .summary,
                        title: "Summary",
                        content: "Optional",
                        retention: .preferred,
                        priority: 70
                    ),
                    block(
                        id: "retrieval.archive",
                        layer: .retrieval,
                        title: "Retrieval",
                        content: "Extra",
                        retention: .onDemand,
                        priority: 60
                    )
                ],
                policy: BASContextCompilationPolicy(targetCharacters: 35, maximumRetrievalBlocks: 1)
            )
        )

        #expect(compiled.stablePrefixBlocks.map(\.id) == ["kernel.identity", "active.intent"])
        #expect(compiled.retainedBlocks.map(\.id) == ["kernel.identity", "active.intent"])
        #expect(compiled.droppedBlocks.map(\.id) == ["summary.goal", "retrieval.archive"])
        #expect(compiled.stablePrefixPrompt == "Kernel: Keep\nActive: Keep")
        #expect(compiled.volatileSuffixPrompt.isEmpty)
        #expect(compiled.renderedPrompt == compiled.stablePrefixPrompt)
        #expect(compiled.stablePrefixFingerprint.isEmpty == false)
        #expect(compiled.semanticFingerprint.isEmpty == false)
    }

    @Test("fingerprints remain stable for the prefix and change with the volatile suffix")
    func fingerprintsRemainStableForPrefixAndChangeWithVolatileSuffix() {
        let stableBlocks = [
            block(
                id: "kernel.identity",
                layer: .kernel,
                title: "Kernel",
                content: "Keep",
                retention: .required,
                priority: 100
            ),
            block(
                id: "active.intent",
                layer: .active,
                title: "Active",
                content: "Keep",
                retention: .preferred,
                priority: 90
            )
        ]

        let first = BASContextCompiler.compile(
            BASContextCompilationRequest(
                blocks: stableBlocks + [
                    block(
                        id: "retrieval.archive-a",
                        layer: .retrieval,
                        title: "Retrieval",
                        content: "First extra detail",
                        retention: .onDemand,
                        priority: 60
                    )
                ],
                policy: BASContextCompilationPolicy(targetCharacters: 120, maximumRetrievalBlocks: 2)
            )
        )

        let second = BASContextCompiler.compile(
            BASContextCompilationRequest(
                blocks: stableBlocks + [
                    block(
                        id: "retrieval.archive-b",
                        layer: .retrieval,
                        title: "Retrieval",
                        content: "A different extra detail",
                        retention: .onDemand,
                        priority: 60
                    )
                ],
                policy: BASContextCompilationPolicy(targetCharacters: 120, maximumRetrievalBlocks: 2)
            )
        )

        #expect(first.stablePrefixFingerprint == second.stablePrefixFingerprint)
        #expect(first.semanticFingerprint != second.semanticFingerprint)
        #expect(first.renderedPrompt != second.renderedPrompt)
        #expect(first.stablePrefixPrompt == second.stablePrefixPrompt)
    }

    @Test("dropped blocks preserve deterministic ordering")
    func droppedBlocksPreserveDeterministicOrdering() {
        let compiled = BASContextCompiler.compile(
            BASContextCompilationRequest(
                blocks: [
                    block(
                        id: "kernel.identity",
                        layer: .kernel,
                        title: "Kernel",
                        content: "Keep",
                        retention: .required,
                        priority: 100
                    ),
                    block(
                        id: "active.intent",
                        layer: .active,
                        title: "Active",
                        content: "Keep",
                        retention: .required,
                        priority: 90
                    ),
                    block(
                        id: "summary.goal",
                        layer: .summary,
                        title: "Summary",
                        content: "Drop first",
                        retention: .preferred,
                        priority: 80
                    ),
                    block(
                        id: "retrieval.archive-a",
                        layer: .retrieval,
                        title: "Retrieval",
                        content: "Drop second",
                        retention: .onDemand,
                        priority: 70
                    ),
                    block(
                        id: "retrieval.archive-b",
                        layer: .retrieval,
                        title: "Retrieval",
                        content: "Drop third",
                        retention: .onDemand,
                        priority: 60
                    )
                ],
                policy: BASContextCompilationPolicy(targetCharacters: 35, maximumRetrievalBlocks: 1)
            )
        )

        #expect(compiled.droppedBlocks.map(\.id) == [
            "summary.goal",
            "retrieval.archive-a",
            "retrieval.archive-b"
        ])
        #expect(compiled.retainedBlocks.map(\.id) == ["kernel.identity", "active.intent"])
    }

    @Test("default output guard carries response language discipline")
    func defaultOutputGuardCarriesResponseLanguageDiscipline() {
        let chinese = BASSemanticContextCompiler.defaultOutputGuard(
            for: BASAdaptiveTaskStrategy(
                kind: .primary,
                entropy: .low,
                runtimeGear: .low,
                contextBudget: 1_200,
                retrievalMode: .off,
                thinkingMode: .off,
                outputMode: .guidedShort,
                tone: .briefWarm,
                actionSpace: ["encourage"],
                responseLanguage: .chinese,
                allowsModelInvocation: true
            )
        )
        let english = BASSemanticContextCompiler.defaultOutputGuard(
            for: BASAdaptiveTaskStrategy(
                kind: .primary,
                entropy: .low,
                runtimeGear: .balanced,
                contextBudget: 1_200,
                retrievalMode: .off,
                thinkingMode: .off,
                outputMode: .guidedShort,
                tone: .neutral,
                actionSpace: ["encourage"],
                responseLanguage: .english,
                allowsModelInvocation: true
            )
        )

        #expect(chinese.contains("Keep the user-facing output in Chinese unless the structured format says otherwise."))
        #expect(english.contains("Keep the user-facing output in English unless the structured format says otherwise."))
    }

    private func block(
        id: String,
        layer: BASContextLayerKind,
        title: String,
        content: String,
        retention: BASContextLayerRetention,
        priority: Int
    ) -> BASContextBlock {
        BASContextBlock(
            id: id,
            layer: layer,
            title: title,
            content: content,
            retention: retention,
            priority: priority
        )
    }
}
