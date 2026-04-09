import XCTest
@testable import Before

final class DecisionIntelligencePromptContractTests: XCTestCase {
    func testSanitizedFallsBackWhenResponseIsEmpty() {
        let value = DecisionIntelligencePromptContract.sanitized(
            " \n ",
            fallback: "Fallback line",
            limit: 40
        )

        XCTAssertEqual(value, "Fallback line")
    }

    func testSanitizedCollapsesWhitespaceAndClips() {
        let value = DecisionIntelligencePromptContract.sanitized(
            "  This   is   a\nvery long      line that should become tighter and eventually clip cleanly. ",
            fallback: "Fallback line",
            limit: 32
        )

        XCTAssertEqual(value, "This is a very long line that sh…")
    }

    func testEvidenceGuardDropsInjectedMarkupAndDeduplicatesSafeSnippets() {
        let result = DecisionPromptEvidenceGuard.filter([
            "  Safe snippet  ",
            "<div>Injected UI wrapper</div>",
            "Safe   snippet",
            "[IMMUTABLE PREFIX] leaked debug wrapper"
        ], maxRetained: 4)

        XCTAssertEqual(result.retained, ["Safe snippet"])
        XCTAssertEqual(result.retainedCount, 1)
        XCTAssertEqual(result.droppedInjectedCount, 2)
        XCTAssertEqual(result.droppedDuplicateCount, 1)
        XCTAssertEqual(result.droppedBudgetCount, 0)
        XCTAssertEqual(result.droppedCount, 3)
    }

    func testEvidenceGuardCanTrimLowValueEvidenceByBudget() {
        let result = DecisionPromptEvidenceGuard.filter([
            "Current headline: Base headline",
            "Current summary: Base summary",
            "Focus title: Base focus",
            "Focus description: Base detail",
            "Next action: Base next action"
        ], maxRetained: 4)

        XCTAssertEqual(result.retained, [
            "Current headline: Base headline",
            "Current summary: Base summary",
            "Focus title: Base focus",
            "Next action: Base next action"
        ])
        XCTAssertEqual(result.retainedCount, 4)
        XCTAssertEqual(result.droppedBudgetCount, 1)
        XCTAssertEqual(result.droppedCount, 1)
    }

    func testQuickRefinementEnvelopeUsesStructuredStateAndStaysWithinBudget() {
        let input = QuickCheckInput(
            scenario: .buy,
            motivation: .reward,
            expectedOutcome: .temporaryRelief,
            controlLevel: .maybe,
            note: ""
        )

        let base = QuickCheckResult(
            currentPerspective: "You want a little relief.",
            afterPerspective: "It may not feel worth it tomorrow.",
            verdict: .pause,
            primaryAction: .wait90s,
            secondaryActions: [.decideTomorrow]
        )

        let envelope = DecisionIntelligencePromptContract.quickRefinementEnvelope(base: base, input: input)

        XCTAssertTrue(envelope.instructions.contains("language rendering layer"))
        XCTAssertTrue(envelope.debugPrompt.contains("[IMMUTABLE PREFIX]"))
        XCTAssertTrue(envelope.debugPrompt.contains("[ADAPTIVE PREFIX]"))
        XCTAssertTrue(envelope.debugPrompt.contains("[VOLATILE SUFFIX]"))
        XCTAssertTrue(envelope.payload.contains("FRONTSTAGE_STATE_JSON:"))
        XCTAssertTrue(envelope.payload.contains("COMPACTION_POLICY_JSON:"))
        XCTAssertTrue(envelope.payload.contains("TASK_STATE_JSON:"))
        XCTAssertTrue(envelope.payload.contains("\"focus_goal\":\"Interrupt the automatic reaction before it locks in.\""))
        XCTAssertTrue(envelope.payload.contains("\"danger_signals\":[]"))
        XCTAssertTrue(envelope.payload.contains("\"evidence_headlines\":[\"Current perspective: You want a little relief.\",\"After perspective: It may not feel worth it tomorrow.\"]"))
        XCTAssertTrue(envelope.payload.contains("\"mode\":\"Quick\""))
        XCTAssertTrue(envelope.payload.contains("\"scenario\":\"\(input.scenario.title)\""))
        XCTAssertTrue(envelope.payload.contains("\"motivation\":\"\(input.motivation.title)\""))
        XCTAssertTrue(envelope.payload.contains("\"note\":\"Not provided.\""))
        XCTAssertTrue(envelope.payload.contains("Current perspective: \(base.currentPerspective)"))
        XCTAssertTrue(envelope.payload.contains("After perspective: \(base.afterPerspective)"))
        XCTAssertTrue(envelope.payload.contains("OUTPUT_GUARD:"))
        XCTAssertTrue(envelope.budget.isWithinTarget)
        XCTAssertGreaterThan(envelope.budget.immutablePrefixCharacters, 0)
        XCTAssertGreaterThan(envelope.budget.adaptivePrefixCharacters, 0)
        XCTAssertEqual(
            envelope.budget.prefixCharacters,
            envelope.layers.stablePrefix.count
        )
        XCTAssertLessThanOrEqual(
            envelope.budget.prefixCharacters - (
                envelope.budget.immutablePrefixCharacters + envelope.budget.adaptivePrefixCharacters
            ),
            2
        )
    }

    func testBalanceRefinementEnvelopeIncludesContextLifecycleWhenProvided() {
        let contextState = DecisionContextPreparedState(
            rebuiltSession: true,
            generation: 2,
            anchorFields: [.balancePrompt],
            activeFields: [.balancePrompt, .balanceConcern],
            staleFields: [.balanceDesire]
        )
        let neuralState = DecisionNeuralState(
            mode: .balance,
            dominantActivations: [
                DecisionActivation(signal: .constraintPressure, strength: 0.82),
                DecisionActivation(signal: .concernWeight, strength: 0.74)
            ],
            candidateActions: [
                DecisionActionCandidate(route: .setBoundary, score: 0.82),
                DecisionActionCandidate(route: .clarifyPriority, score: 0.68)
            ],
            suppressedBehaviors: ["instant_verdict"],
            detail: "Use structured trade-off routing."
        )
        let brainState = DecisionBrainState(
            profileCore: ["Short, direct language lands better."],
            activeGoals: ["Protect sleep and energy."],
            relevantMemories: ["Late sessions need lighter, shorter guidance."],
            sessionBiases: ["Keep the language short and concrete."],
            retrievalTags: ["sleep", "night", "tradeoff"],
            reactionWeights: DecisionReactionWeights(
                briefLanguage: 0.86,
                warmDirectTone: 0.74,
                lowCognitiveLoad: 0.79,
                interruptiveActionBias: 0.42,
                boundaryNamingBias: 0.38,
                tradeoffClarityBias: 0.81
            ),
            loadedAt: .now
        )

        let envelope = DecisionIntelligencePromptContract.balanceRefinementEnvelope(
            base: BalanceBoardResult(
                headline: "Base headline",
                summary: "Base summary",
                focusTitle: "Base focus",
                focusDescription: "Base focus description",
                nextAction: "Base next action"
            ),
            input: BalanceBoardInput(
                prompt: "Should I take this side project?",
                desire: "Extra momentum",
                concern: "Burn out",
                constraint: "",
                longTerm: ""
            ),
            contextState: contextState,
            neuralState: neuralState,
            brainState: brainState
        )

        XCTAssertTrue(envelope.payload.contains("CONTEXT_LIFECYCLE_JSON:"))
        XCTAssertTrue(envelope.payload.contains("SCOPED_CONTEXT_JSON:"))
        XCTAssertTrue(envelope.payload.contains("\"rebuilt_session\":true"))
        XCTAssertTrue(envelope.payload.contains("\"generation\":2"))
        XCTAssertTrue(envelope.payload.contains("\"anchor_fields\":[\"balancePrompt\"]"))
        XCTAssertTrue(envelope.payload.contains("\"active_fields\":[\"balancePrompt\",\"balanceConcern\"]"))
        XCTAssertTrue(envelope.payload.contains("\"stale_fields\":[\"balanceDesire\"]"))
        XCTAssertTrue(
            envelope.assembly.allBlocks.map(\.kind).contains(
                DecisionIntelligencePromptContract.PromptBlockKind.neuralState
            )
        )
        XCTAssertTrue(envelope.payload.contains("\"focus_goal\":\"Surface the real trade-off before choosing a side.\""))
        XCTAssertTrue(envelope.payload.contains("\"danger_signals\":[\"Constraint pressure\",\"Concern weight\",\"Session rebuild\"]"))
        XCTAssertTrue(envelope.payload.contains("\"evidence_headlines\":[\"Current headline: Base headline\"]"))
        XCTAssertTrue(envelope.payload.contains("\"anchor_headlines\":[\"Balance prompt\"]"))
        XCTAssertTrue(envelope.payload.contains("\"dropped_budget_evidence_count\":1"))
        XCTAssertTrue(envelope.payload.contains("\"suppression_hints\":[\"instant_verdict\"]"))
        XCTAssertEqual(envelope.frontstageState.retainedEvidenceCount, 4)
        XCTAssertEqual(envelope.frontstageState.memoryHeadlines, ["Late sessions need lighter, shorter guidance."])
        XCTAssertEqual(envelope.frontstageState.sessionBiases, ["Keep the language short and concrete."])
        XCTAssertTrue(
            envelope.assembly.allBlocks.map(\.kind).contains(
                DecisionIntelligencePromptContract.PromptBlockKind.brainState
            )
        )
        XCTAssertTrue(envelope.payload.contains("\"user_profile\":[\"Short, direct language lands better.\"]"))
        XCTAssertTrue(envelope.payload.contains("\"local_biases\":[\"Keep the language short and concrete.\"]"))
        XCTAssertTrue(envelope.payload.contains("\"auto_memory\":[\"Late sessions need lighter, shorter guidance.\"]"))
        XCTAssertTrue(envelope.payload.contains("\"dominant_reaction_weight\":\"brief_language\""))
        XCTAssertTrue(envelope.assembly.droppedBlockKinds.contains(.neuralState))
        XCTAssertTrue(envelope.assembly.droppedBlockKinds.contains(.brainState))
        XCTAssertFalse(envelope.payload.contains("Focus description: Base focus description"))
        XCTAssertTrue(envelope.payload.contains("Lower-value evidence was trimmed. Work only from the retained evidence."))
        XCTAssertTrue(envelope.budget.isWithinTarget)
        XCTAssertGreaterThan(envelope.budget.stablePrefixShare, 0)
        XCTAssertGreaterThan(envelope.budget.volatileSuffixShare, 0)
    }

    func testReminderSelectionEnvelopeClipsCandidatesAndUsesStructuredState() {
        let envelope = DecisionIntelligencePromptContract.reminderSelectionEnvelope(
            candidates: [
                ReminderSelectionCandidate(id: UUID(), content: "This is stress shopping again."),
                ReminderSelectionCandidate(id: UUID(), content: "You already knew this was a real replacement."),
                ReminderSelectionCandidate(id: UUID(), content: "This is discomfort, not a need."),
                ReminderSelectionCandidate(id: UUID(), content: "This fourth option should be clipped away.")
            ],
            scenario: .buy,
            prompt: "Today was rough and I want these shoes.",
            mode: .quick
        )

        XCTAssertEqual(envelope.candidates.count, 3)
        XCTAssertTrue(envelope.prompt.payload.contains("\"scenario\":\"Buy\""))
        XCTAssertTrue(envelope.prompt.payload.contains("\"mode\":\"Quick\""))
        XCTAssertTrue(envelope.prompt.payload.contains("\"candidate_count\":3"))
        XCTAssertTrue(envelope.prompt.payload.contains("\"evidence_headlines\":[]"))
        XCTAssertTrue(envelope.prompt.payload.contains("0: This is stress shopping again."))
        XCTAssertTrue(envelope.prompt.payload.contains("1: You already knew this was a real replacement."))
        XCTAssertTrue(envelope.prompt.payload.contains("2: This is discomfort, not a need."))
        XCTAssertFalse(envelope.prompt.payload.contains("This fourth option should be clipped away."))
        XCTAssertTrue(
            envelope.prompt.assembly.allBlocks.map(\.kind).contains(
                DecisionIntelligencePromptContract.PromptBlockKind.compactionPolicy
            )
        )
        XCTAssertTrue(envelope.prompt.budget.isWithinTarget)
    }

    func testCacheFingerprintUsesRuntimePromptInsteadOfDebugPrompt() {
        let input = QuickCheckInput(
            scenario: .buy,
            motivation: .reward,
            expectedOutcome: .temporaryRelief,
            controlLevel: .maybe,
            note: "Today was rough."
        )
        let base = QuickCheckResult(
            currentPerspective: "You want a quick release.",
            afterPerspective: "It may feel noisier tomorrow.",
            verdict: .pause,
            primaryAction: .wait90s,
            secondaryActions: [.decideTomorrow]
        )

        let envelope = DecisionIntelligencePromptContract.quickRefinementEnvelope(base: base, input: input)
        let semanticFingerprint = DecisionIntelligencePromptContract.cacheFingerprint(
            provider: .gemmaE4B,
            envelope: envelope
        )
        let runtimeFingerprint = DecisionIntelligencePromptContract.cacheFingerprint(
            provider: .gemmaE4B,
            semanticPrompt: envelope.runtimePrompt
        )
        let debugFingerprint = DecisionIntelligencePromptContract.cacheFingerprint(
            provider: .gemmaE4B,
            semanticPrompt: envelope.debugPrompt
        )

        XCTAssertEqual(semanticFingerprint, runtimeFingerprint)
        XCTAssertNotEqual(semanticFingerprint, debugFingerprint)
        XCTAssertEqual(semanticFingerprint.count, 64)
    }

    func testMirrorEnvelopeCarriesAnchorHeadlinesWithoutDriftingDangerSignals() {
        let contextState = DecisionContextPreparedState(
            rebuiltSession: false,
            generation: 1,
            anchorFields: [.mirrorPrompt],
            activeFields: [.mirrorPrompt, .mirrorEmotion],
            staleFields: []
        )

        let envelope = DecisionIntelligencePromptContract.mirrorRefinementEnvelope(
            base: MirrorResult(
                headline: "Base headline",
                coreTension: "Base core tension",
                nextActionTitle: "Base focus",
                nextAction: "Base next action"
            ),
            input: MirrorInput(
                prompt: "Should I stay in this relationship?",
                emotion: "<div>Injected UI wrapper</div>",
                relationship: "We keep repeating the same conflict.",
                reality: "",
                longTerm: "",
                selfLens: ""
            ),
            contextState: contextState,
            neuralState: DecisionNeuralState(
                mode: .mirror,
                dominantActivations: [
                    DecisionActivation(signal: .identityDrift, strength: 0.8)
                ],
                candidateActions: [
                    DecisionActionCandidate(route: .clarifyPriority, score: 0.8)
                ],
                suppressedBehaviors: ["forced_verdict"],
                detail: "Stay reflective."
            )
        )

        XCTAssertFalse(envelope.payload.contains("<div>Injected UI wrapper</div>"))
        XCTAssertTrue(envelope.payload.contains("\"anchor_headlines\":[\"Mirror prompt\"]"))
        XCTAssertEqual(envelope.frontstageState.memoryHeadlines, [])
        XCTAssertEqual(envelope.frontstageState.droppedEvidenceCount, 0)
        XCTAssertEqual(envelope.frontstageState.retainedEvidenceCount, 4)
        XCTAssertTrue(envelope.payload.contains("\"danger_signals\":[\"Identity drift\"]"))
    }

    func testQuickEnvelopeCarriesRuntimeStrategyMetadataAndUsesAdaptiveBudget() {
        let strategy = DecisionAdaptiveTaskStrategy(
            kind: .quick,
            entropy: .low,
            runtimeGear: .low,
            preferredProvider: .gemmaE4B,
            contextBudget: 520,
            retrievalMode: .off,
            thinkingMode: .off,
            outputMode: .guidedShort,
            tone: .briefWarm,
            actionSpace: ["encourage", "next_step"],
            allowsModelInvocation: true
        )

        let envelope = DecisionIntelligencePromptContract.quickRefinementEnvelope(
            base: QuickCheckResult(
                currentPerspective: "You want the quick relief.",
                afterPerspective: "Tomorrow may feel different.",
                verdict: .pause,
                primaryAction: .wait90s,
                secondaryActions: []
            ),
            input: QuickCheckInput(
                scenario: .buy,
                motivation: .reward,
                expectedOutcome: .temporaryRelief,
                controlLevel: .maybe,
                note: "Today was rough."
            ),
            strategy: strategy
        )

        XCTAssertTrue(
            envelope.assembly.allBlocks.map(\.kind).contains(
                DecisionIntelligencePromptContract.PromptBlockKind.runtimeStrategy
            )
        )
        XCTAssertTrue(
            envelope.assembly.allBlocks.map(\.kind).contains(
                DecisionIntelligencePromptContract.PromptBlockKind.compactionPolicy
            )
        )
        guard let runtimeStrategyBlock = envelope.assembly.allBlocks.first(where: {
            $0.kind == DecisionIntelligencePromptContract.PromptBlockKind.runtimeStrategy
        }) else {
            return XCTFail("Expected a runtime strategy block in the prompt assembly.")
        }
        XCTAssertEqual(runtimeStrategyBlock.retention, .preferred)
        XCTAssertTrue(runtimeStrategyBlock.body.contains("\"provider\":\"gemmaE4B\""))
        XCTAssertTrue(runtimeStrategyBlock.body.contains("\"runtime_gear\":\"low\""))
        XCTAssertTrue(runtimeStrategyBlock.body.contains("\"output_mode\":\"guidedShort\""))
        XCTAssertTrue(runtimeStrategyBlock.body.contains("\"tone\":\"briefWarm\""))
        XCTAssertTrue(runtimeStrategyBlock.body.contains("\"response_language\":\"english\""))
        XCTAssertTrue(runtimeStrategyBlock.body.contains("\"allows_model_invocation\":true"))
        XCTAssertTrue(runtimeStrategyBlock.body.contains("\"runtime_budget\""))
        XCTAssertTrue(runtimeStrategyBlock.body.contains("\"output_character_budget\":180"))
        XCTAssertTrue(runtimeStrategyBlock.body.contains("\"tool_call_budget\":1"))
        XCTAssertTrue(envelope.payload.contains("roughly 180 characters"))
        XCTAssertTrue(
            envelope.assembly.allBlocks.contains(where: { block in
                block.kind == .compactionPolicy &&
                    block.body.contains("\"preserve_blocks\"")
            })
        )
        XCTAssertEqual(envelope.budget.targetCharacters, 520)
    }

    func testReminderEvidenceRetentionHonorsRuntimeRetrievalBudget() {
        let candidates = [
            ReminderSelectionCandidate(id: UUID(), content: "A"),
            ReminderSelectionCandidate(id: UUID(), content: "B"),
            ReminderSelectionCandidate(id: UUID(), content: "C"),
            ReminderSelectionCandidate(id: UUID(), content: "D")
        ]
        let strategy = DecisionAdaptiveTaskStrategy(
            kind: .reminder,
            entropy: .low,
            runtimeGear: .balanced,
            preferredProvider: .gemmaE4B,
            contextBudget: 220,
            retrievalItemBudget: 2,
            retrievalMode: .filtered,
            thinkingMode: .off,
            outputMode: .jsonShort,
            tone: .briefWarm,
            actionSpace: ["select_reminder"],
            responseLanguage: .english,
            allowsModelInvocation: true
        )

        let selection = DecisionIntelligencePromptContract.reminderSelectionEnvelope(
            candidates: candidates,
            scenario: .buy,
            prompt: "Pick the one that fits tonight.",
            mode: .quick,
            strategy: strategy
        )

        XCTAssertEqual(selection.candidates.count, 3)
        XCTAssertEqual(selection.prompt.frontstageState.retainedEvidenceCount, 2)
        XCTAssertEqual(selection.prompt.frontstageState.droppedBudgetEvidenceCount, 1)
    }

    func testPromptAssemblyDropsOptionalBlocksBeforeRequiredBlocks() {
        let strategy = DecisionAdaptiveTaskStrategy(
            kind: .balance,
            entropy: .medium,
            runtimeGear: .balanced,
            preferredProvider: .gemmaE4B,
            contextBudget: 260,
            retrievalMode: .filtered,
            thinkingMode: .off,
            outputMode: .guidedShort,
            tone: .briefWarm,
            actionSpace: ["clarify", "next_step"],
            allowsModelInvocation: true
        )
        let contextState = DecisionContextPreparedState(
            rebuiltSession: true,
            generation: 3,
            anchorFields: [.balancePrompt],
            activeFields: [.balancePrompt, .balanceConcern, .balanceLongTerm],
            staleFields: [.balanceConstraint]
        )
        let neuralState = DecisionNeuralState(
            mode: .balance,
            dominantActivations: [
                DecisionActivation(signal: .constraintPressure, strength: 0.79),
                DecisionActivation(signal: .concernWeight, strength: 0.73)
            ],
            candidateActions: [
                DecisionActionCandidate(route: .clarifyPriority, score: 0.82),
                DecisionActionCandidate(route: .setBoundary, score: 0.74)
            ],
            suppressedBehaviors: ["instant_verdict"],
            detail: "Keep the board concise."
        )
        let brainState = DecisionBrainState(
            profileCore: ["Short, direct language lands better."],
            activeGoals: ["Protect focus and sleep."],
            relevantMemories: ["Late sessions need lighter, shorter guidance."],
            sessionBiases: ["Keep the language short and concrete."],
            retrievalTags: ["sleep", "tradeoff", "night"],
            reactionWeights: DecisionReactionWeights(
                briefLanguage: 0.84,
                warmDirectTone: 0.72,
                lowCognitiveLoad: 0.81,
                interruptiveActionBias: 0.36,
                boundaryNamingBias: 0.42,
                tradeoffClarityBias: 0.88
            ),
            loadedAt: .now
        )

        let envelope = DecisionIntelligencePromptContract.balanceRefinementEnvelope(
            base: BalanceBoardResult(
                headline: "Base headline",
                summary: "Base summary",
                focusTitle: "Base focus",
                focusDescription: "Base focus description",
                nextAction: "Base next action"
            ),
            input: BalanceBoardInput(
                prompt: "Should I take this side project?",
                desire: "Extra momentum",
                concern: "Burn out",
                constraint: "Sleep is already fragile.",
                longTerm: "Protect focus and energy."
            ),
            strategy: strategy,
            contextState: contextState,
            neuralState: neuralState,
            brainState: brainState
        )

        XCTAssertFalse(envelope.assembly.droppedBlocks.isEmpty)
        XCTAssertTrue(envelope.assembly.droppedBlockKinds.contains(DecisionIntelligencePromptContract.PromptBlockKind.neuralState))
        XCTAssertTrue(envelope.assembly.droppedBlockKinds.contains(DecisionIntelligencePromptContract.PromptBlockKind.brainState))
        XCTAssertTrue(envelope.assembly.allBlocks.map(\.kind).contains(DecisionIntelligencePromptContract.PromptBlockKind.compactionPolicy))
        XCTAssertTrue(envelope.assembly.retainedBlockKinds.contains(DecisionIntelligencePromptContract.PromptBlockKind.scopedContext))
        XCTAssertTrue(envelope.assembly.retainedBlockKinds.contains(DecisionIntelligencePromptContract.PromptBlockKind.frontstageState))
        XCTAssertTrue(envelope.assembly.retainedBlockKinds.contains(DecisionIntelligencePromptContract.PromptBlockKind.taskState))
        XCTAssertTrue(envelope.assembly.retainedBlockKinds.contains(DecisionIntelligencePromptContract.PromptBlockKind.evidenceSnippets))
        XCTAssertTrue(envelope.assembly.retainedBlockKinds.contains(DecisionIntelligencePromptContract.PromptBlockKind.outputGuard))
        XCTAssertFalse(envelope.payload.contains("NEURAL_STATE_JSON:"))
        XCTAssertFalse(envelope.payload.contains("BRAIN_STATE_JSON:"))
        XCTAssertTrue(envelope.payload.contains("SCOPED_CONTEXT_JSON:"))
        XCTAssertTrue(envelope.debugPrompt.contains("[COMPACTION]"))
        XCTAssertTrue(envelope.debugPrompt.contains("Dropped blocks:"))
    }

    func testScopedContextSurvivesCompactionAheadOfFullBrainState() {
        let strategy = DecisionAdaptiveTaskStrategy(
            kind: .mirror,
            entropy: .high,
            runtimeGear: .high,
            preferredProvider: .gemmaE4B,
            contextBudget: 280,
            retrievalMode: .adaptive,
            thinkingMode: .gated,
            outputMode: .reflectiveStructured,
            tone: .reflectiveClear,
            actionSpace: ["name_pattern", "name_boundary"],
            responseLanguage: .english,
            allowsModelInvocation: true
        )

        let envelope = DecisionIntelligencePromptContract.mirrorRefinementEnvelope(
            base: MirrorResult(
                headline: "Base headline",
                coreTension: "Base core tension",
                nextActionTitle: "Base next action title",
                nextAction: "Base next action"
            ),
            input: MirrorInput(
                prompt: "Should I keep shrinking myself to keep this relationship alive?",
                emotion: "Tired and ashamed.",
                relationship: "It keeps collapsing into the same argument.",
                reality: "I keep minimizing what I need.",
                longTerm: "I want a life that feels bigger, not smaller.",
                selfLens: "I know what I tolerate keeps teaching people how to treat me."
            ),
            strategy: strategy,
            contextState: DecisionContextPreparedState(
                rebuiltSession: true,
                generation: 4,
                anchorFields: [.mirrorPrompt],
                activeFields: [.mirrorPrompt, .mirrorReality, .mirrorLongTerm],
                staleFields: [.mirrorSelfLens]
            ),
            neuralState: DecisionNeuralState(
                mode: .mirror,
                dominantActivations: [
                    DecisionActivation(signal: .boundaryRisk, strength: 0.92),
                    DecisionActivation(signal: .identityDrift, strength: 0.81)
                ],
                candidateActions: [
                    DecisionActionCandidate(route: .setBoundary, score: 0.91)
                ],
                suppressedBehaviors: ["forced_verdict"],
                detail: "Protect boundary clarity."
            ),
            brainState: DecisionBrainState(
                profileCore: ["Direct language helps this user stay honest."],
                activeGoals: ["Protect self-respect and future capacity."],
                relevantMemories: [
                    "When the user is exhausted, naming the pattern lands better than deep analysis.",
                    "Late relationship spirals need concise boundary language."
                ],
                sessionBiases: ["Stay brief and boundary-clear."],
                retrievalTags: ["relationship", "boundary", "night"],
                reactionWeights: DecisionReactionWeights(
                    briefLanguage: 0.72,
                    warmDirectTone: 0.78,
                    lowCognitiveLoad: 0.62,
                    interruptiveActionBias: 0.34,
                    boundaryNamingBias: 0.94,
                    tradeoffClarityBias: 0.41
                ),
                loadedAt: .now
            )
        )

        XCTAssertTrue(envelope.payload.contains("SCOPED_CONTEXT_JSON:"))
        XCTAssertTrue(envelope.payload.contains("\"user_profile\":[\"Direct language helps this user stay honest.\"]"))
        XCTAssertTrue(envelope.payload.contains("\"active_goals\":[\"Protect self-respect and future capacity.\"]"))
        XCTAssertFalse(envelope.payload.contains("BRAIN_STATE_JSON:"))
        XCTAssertTrue(envelope.assembly.droppedBlockKinds.contains(.brainState))
        XCTAssertTrue(envelope.assembly.retainedBlockKinds.contains(.scopedContext))
    }
}
