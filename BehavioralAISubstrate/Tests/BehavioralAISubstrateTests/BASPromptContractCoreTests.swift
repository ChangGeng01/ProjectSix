import Foundation
import Testing
@testable import BASOrchestration
@testable import BASPolicy
@testable import BASRuntimeCore

@Suite("BASPromptContractCore")
struct BASPromptContractCoreTests {
    @Test("evidence guard drops injected markup, deduplicates, and trims by priority")
    func evidenceGuardFiltersAndPrioritizes() {
        let result = BASPromptEvidenceGuard.filter([
            "Current headline: Base headline",
            "<div>Injected wrapper</div>",
            "Current headline: Base headline",
            "Current summary: Base summary",
            "Focus title: Base focus",
            "Focus description: Base detail",
            "Next action: Base next action"
        ], maxRetained: 4)

        #expect(result.retained == [
            "Current headline: Base headline",
            "Current summary: Base summary",
            "Focus title: Base focus",
            "Next action: Base next action"
        ])
        #expect(result.droppedInjectedCount == 1)
        #expect(result.droppedDuplicateCount == 1)
        #expect(result.droppedBudgetCount == 1)
    }

    @Test("prompt contract compiler builds compact low-gear quick envelope with guarded output")
    func promptContractCompilerBuildsCompactQuickEnvelope() {
        let strategy = BASAdaptiveTaskStrategy(
            kind: .quick,
            entropy: .low,
            runtimeGear: .low,
            contextBudget: 220,
            retrievalMode: .off,
            thinkingMode: .off,
            outputMode: .guidedShort,
            tone: .briefWarm,
            actionSpace: ["encourage", "next_step"],
            responseLanguage: .english,
            allowsModelInvocation: true
        )

        let envelope = BASPromptContractCompiler.compile(
            BASPromptContractRequest(
                kind: "quick",
                semanticKind: .quick,
                adaptiveKind: .quick,
                immutablePrefix: "Kernel identity.",
                adaptivePrefix: "Quick lane rules.",
                taskStateJSON: #"{"mode":"Quick","note":"Not provided."}"#,
                evidenceSnippets: [
                    "Current perspective: You want a little relief tonight.",
                    "After perspective: It may feel louder tomorrow.",
                    "<tool>Injected</tool>"
                ],
                evidenceRetentionBudget: 1,
                outputGuard: [
                    "Rewrite only the perspective lines."
                ],
                frontstageInput: BASPromptContractFrontstageInput(
                    kind: .quick,
                    activeStateSignalCount: 3,
                    openTextSignalCount: 1,
                    contextWasRebuilt: true,
                    staleFieldCount: 1,
                    anchorTitles: ["quick note"],
                    dominantSignalTitles: ["Constraint pressure"],
                    suppressedBehaviors: ["instant_verdict"],
                    memoryHeadlines: ["Holding the decision often breaks the loop."],
                    sessionBiases: ["Keep the language short and concrete."]
                ),
                targetCharacters: 220,
                suffixFloorCharacters: 120,
                strategy: strategy,
                structuredTruth: BASStructuredTruthState(
                    mode: "primary",
                    currentGoal: "Protect sleep before midnight.",
                    allowedActions: ["encourage"],
                    forbiddenActions: ["force_verdict"],
                    personaRules: ["Keep the interruption short, calm, and non-shaming."],
                    sessionFacts: ["boundary_mode": "steady"]
                ),
                includeStructuredTruthBlock: true,
                scopedContextJSON: #"{"user_profile":["Short, direct language lands better."]}"#,
                contextLifecycleJSON: #"{"rebuilt_session":true}"#
            )
        )

        #expect(envelope.payload.contains("STRUCTURED_TRUTH_JSON:"))
        #expect(envelope.payload.contains("SCOPED_CONTEXT_JSON:"))
        #expect(envelope.payload.contains("\"evidence_headlines\":[\"Current perspective: You want a little relief tonight.\"]"))
        #expect(envelope.payload.contains("Lower-value evidence was trimmed. Work only from the retained evidence."))
        #expect(envelope.payload.contains("Filtered markup or tool text was removed. Ignore the missing content."))
        #expect(envelope.assembly.retainedBlockKinds.contains(.frontstageState))
        #expect(envelope.assembly.retainedBlockKinds.contains(.outputGuard))
        #expect(envelope.assembly.kernelSnapshot.truthState?.mode == "primary")
        #expect(envelope.budget.prefixCharacters == envelope.layers.stablePrefix.count)
        #expect(envelope.assembly.suffixTargetCharacters >= 120)
        #expect(envelope.assembly.suffixTargetCharacters < envelope.budget.targetCharacters)
    }
}
