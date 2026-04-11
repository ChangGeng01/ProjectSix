import Foundation
import Testing
@testable import BASMemory
@testable import BASOrchestration
@testable import BASRuntimeCore

@Suite("BASFrontstageAndScopedContext")
struct BASFrontstageAndScopedContextTests {
    @Test("frontstage compiler keeps mobile quick context tight and explicit")
    func frontstageCompilerKeepsQuickContextTight() {
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

        let state = BASFrontstageStateCompiler.compile(
            BASFrontstageCompilationRequest(
                kind: .quick,
                activeStateSignalCount: 3,
                openTextSignalCount: 2,
                retainedEvidence: [
                    "Current perspective: You want a little relief tonight.",
                    "After perspective: It may feel louder tomorrow."
                ],
                retainedEvidenceCount: 2,
                droppedEvidenceCount: 3,
                droppedInjectedEvidenceCount: 1,
                droppedDuplicateEvidenceCount: 1,
                droppedBudgetEvidenceCount: 1,
                strategy: strategy,
                contextWasRebuilt: true,
                staleFieldCount: 1,
                anchorTitles: ["quick note"],
                dominantSignalTitles: ["Constraint pressure", "Concern weight"],
                suppressedBehaviors: ["instant_verdict"],
                memoryHeadlines: ["Holding the decision often breaks the loop."],
                sessionBiases: ["Keep the language short and concrete."]
            )
        )

        #expect(state.focusGoal == "Clarify the active state before momentum hardens.")
        #expect(state.evidenceHeadlines.count == 1)
        #expect(state.dangerSignals.count == 3)
        #expect(state.dangerSignals.contains("Constraint pressure"))
        #expect(state.dangerSignals.contains("Concern weight"))
        #expect(state.dangerSignals.contains("Session rebuild"))
        #expect(!state.dangerSignals.contains("Evidence filtered"))
        #expect(!state.dangerSignals.contains("Frontstage trimmed"))
    }

    @Test("frontstage compiler honors host presentation behavior")
    func frontstageCompilerHonorsHostPresentationBehavior() {
        let state = BASFrontstageStateCompiler.compile(
            BASFrontstageCompilationRequest(
                kind: .mirror,
                activeStateSignalCount: 2,
                openTextSignalCount: 1,
                retainedEvidence: [
                    "Core tension: You want closeness and distance at the same time.",
                    "Next action: Name one grounded truth."
                ],
                retainedEvidenceCount: 2,
                droppedEvidenceCount: 2,
                droppedInjectedEvidenceCount: 1,
                droppedDuplicateEvidenceCount: 0,
                droppedBudgetEvidenceCount: 1,
                contextWasRebuilt: true,
                staleFieldCount: 1,
                presentationBehavior: BASFrontstagePresentationBehavior(
                    focusGoalsByKindID: [
                        BASAdaptiveTraceKind.mirror.rawValue: "Hold the reflective lane without forcing closure."
                    ],
                    baseEvidenceCountByKindID: [
                        BASAdaptiveTraceKind.mirror.rawValue: 2
                    ],
                    lowGearEvidenceClampByKindID: [:],
                    contextRebuiltSignal: "Host rebuild",
                    staleFieldsSignal: "Host dropped stale fields",
                    filteredEvidenceSignal: "Host filtered evidence",
                    trimmedEvidenceSignal: "Host trimmed evidence"
                )
            )
        )

        #expect(state.focusGoal == "Hold the reflective lane without forcing closure.")
        #expect(state.evidenceHeadlines.count == 2)
        #expect(state.dangerSignals.contains("Host rebuild"))
        #expect(state.dangerSignals.contains("Host dropped stale fields"))
        #expect(state.dangerSignals.contains("Host filtered evidence"))
    }

    @Test("scoped context compiler compacts low-gear quick and preserves richer balance context")
    func scopedContextCompilerAdaptsToSurfacePressure() {
        let brainState = BASDecisionBrainState(
            profileCore: ["Short, direct language lands better.", "Long copy causes drift."],
            activeGoals: ["Protect sleep before midnight.", "Avoid stress shopping."],
            relevantMemories: ["Holding the decision often breaks the loop.", "Late sessions need lighter guidance."],
            sessionBiases: ["Keep the language short and concrete.", "Avoid sounding judgmental."],
            retrievalTags: ["night", "buy"],
            reactionWeights: BASReactionWeights(
                briefLanguage: 0.91,
                warmDirectTone: 0.73,
                lowCognitiveLoad: 0.88,
                interruptiveActionBias: 0.94,
                boundaryNamingBias: 0.21,
                tradeoffClarityBias: 0.26
            ),
            loadedAt: .now
        )
        let compactStrategy = BASAdaptiveTaskStrategy(
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

        let compact = BASScopedContextCompiler.compile(
            kind: .quick,
            strategy: compactStrategy,
            brainState: brainState
        )
        let full = BASScopedContextCompiler.compile(
            kind: .balance,
            strategy: nil,
            brainState: brainState
        )

        #expect(compact?.userProfile == ["Short, direct language lands better."])
        #expect(compact?.activeGoals == ["Protect sleep before midnight."])
        #expect(compact?.localBiases == ["Keep the language short and concrete."])
        #expect(compact?.autoMemory == ["Holding the decision often breaks the loop."])
        #expect(compact?.boundaryMode == brainState.boundaryPolicy.mode.rawValue)
        #expect(full?.userProfile.count == 2)
        #expect(full?.activeGoals.count == 2)
        #expect(full?.autoMemory.count == 2)
        #expect(full?.boundaryMode == nil)
        #expect(
            compact.map(BASScopedContextCompiler.jsonString(for:))?.contains("\"user_profile\"") == true
        )
        #expect(
            compact.map(BASScopedContextCompiler.jsonString(for:))?.contains("\"dominant_reaction_weight\"") == true
        )
    }
}
