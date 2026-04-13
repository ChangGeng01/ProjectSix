import XCTest
import BASHostKit
@testable import Before

final class DecisionIntelligenceProviderPipelineTests: XCTestCase {
    @MainActor
    override func setUp() async throws {
        try await super.setUp()
        await DecisionIntelligenceResponseCache.shared.clear()
        await DecisionIntelligenceTelemetryStore.shared.clear()
        DecisionIntelligenceDebugStore.shared.clear()
    }

    func testOrderedKindsPreferGemmaFirst() {
        XCTAssertEqual(
            DecisionIntelligenceProviderPipeline.orderedKinds(for: .gemmaE4B),
            [.gemmaE4B, .foundationModels]
        )
    }

    func testOrderedKindsPreferFoundationFirst() {
        XCTAssertEqual(
            DecisionIntelligenceProviderPipeline.orderedKinds(for: .foundationModels),
            [.foundationModels, .gemmaE4B]
        )
    }

    func testOrderedKindsPreferOpenModelSlotFirst() {
        XCTAssertEqual(
            DecisionIntelligenceProviderPipeline.orderedKinds(for: .openModel),
            [.openModel, .gemmaE4B, .foundationModels]
        )
    }

    func testOrderedKindsCanPinTemplateOnly() {
        XCTAssertEqual(
            DecisionIntelligenceProviderPipeline.orderedKinds(for: .template),
            [.template]
        )
    }

    func testOrderedKindsCanDisableFallbacks() {
        XCTAssertEqual(
            DecisionIntelligenceProviderPipeline.orderedKinds(for: .foundationModels, allowFallbacks: false),
            [.foundationModels]
        )
    }

    func testOrderedKindsExcludeProvidersUnderRuntimeCooldown() {
        XCTAssertEqual(
            DecisionIntelligenceProviderPipeline.orderedKinds(
                for: .gemmaE4B,
                allowFallbacks: true,
                excluding: [.gemmaE4B]
            ),
            [.foundationModels]
        )
    }

    func testRuntimeStatusFallsBackToGemmaWhenFoundationPreferenceIsUnavailable() {
        let preferences = BeforePreferences(
            homePromptAction: .autoRoute,
            quickBufferDuration: .ninetySeconds,
            restoreInProgressWorkspaces: true,
            showReviewInsights: true,
            onDeviceIntelligenceMode: .assistive,
            preferredIntelligenceProvider: .foundationModels,
            allowModelFallbacks: true
        )

        let status = DecisionIntelligenceProviderPipeline.runtimeStatus(
            preferences: preferences,
            statusesByKind: [
                .foundationModels: DecisionModelProviderStatus(
                    kind: .foundationModels,
                    isAvailable: false,
                    title: "Unavailable",
                    detail: "Apple is unavailable."
                ),
                .gemmaE4B: DecisionModelProviderStatus(
                    kind: .gemmaE4B,
                    isAvailable: true,
                    title: "Bundle detected",
                    detail: "Gemma is ready."
                )
            ]
        )

        XCTAssertEqual(status.preferred, .foundationModels)
        XCTAssertEqual(status.active, .gemmaE4B)
        XCTAssertEqual(status.fallback, .gemmaE4B)
    }

    func testRuntimeStatusPinsDeterministicWhenTemplateIsSelected() {
        let preferences = BeforePreferences(
            homePromptAction: .autoRoute,
            quickBufferDuration: .ninetySeconds,
            restoreInProgressWorkspaces: true,
            showReviewInsights: true,
            onDeviceIntelligenceMode: .assistive,
            preferredIntelligenceProvider: .template,
            allowModelFallbacks: true
        )

        let status = DecisionIntelligenceProviderPipeline.runtimeStatus(
            preferences: preferences,
            statusesByKind: [:]
        )

        XCTAssertEqual(status.preferred, .template)
        XCTAssertEqual(status.active, .template)
        XCTAssertNil(status.fallback)
    }

    func testRuntimeStatusFallsStraightToTemplateWhenFallbacksAreOff() {
        let preferences = BeforePreferences(
            homePromptAction: .autoRoute,
            quickBufferDuration: .ninetySeconds,
            restoreInProgressWorkspaces: true,
            showReviewInsights: true,
            onDeviceIntelligenceMode: .assistive,
            preferredIntelligenceProvider: .foundationModels,
            allowModelFallbacks: false
        )

        let status = DecisionIntelligenceProviderPipeline.runtimeStatus(
            preferences: preferences,
            statusesByKind: [
                .foundationModels: DecisionModelProviderStatus(
                    kind: .foundationModels,
                    isAvailable: false,
                    title: "Unavailable",
                    detail: "Apple is unavailable."
                ),
                .gemmaE4B: DecisionModelProviderStatus(
                    kind: .gemmaE4B,
                    isAvailable: true,
                    title: "Bundle detected",
                    detail: "Gemma is ready."
                )
            ]
        )

        XCTAssertEqual(status.preferred, .foundationModels)
        XCTAssertEqual(status.active, .template)
        XCTAssertEqual(status.fallback, .template)
    }

    func testRuntimeStatusUsesTestingStubWhenProfileIsInjected() {
        let preferences = BeforePreferences(
            homePromptAction: .autoRoute,
            quickBufferDuration: .ninetySeconds,
            restoreInProgressWorkspaces: true,
            showReviewInsights: true,
            onDeviceIntelligenceMode: .assistive,
            preferredIntelligenceProvider: .gemmaE4B,
            allowModelFallbacks: true
        )

        let status = DecisionIntelligenceProviderPipeline.runtimeStatus(
            preferences: preferences,
            statusesByKind: [
                .gemmaE4B: DecisionModelProviderStatus(
                    kind: .gemmaE4B,
                    isAvailable: false,
                    title: "Unavailable",
                    detail: "Gemma is missing."
                )
            ],
            testingStubProfile: .smoke
        )

        XCTAssertEqual(status.preferred, .gemmaE4B)
        XCTAssertEqual(status.active, .testingStub)
        XCTAssertEqual(status.fallback, .testingStub)
    }

    @MainActor
    func testTestingStubCanRefineQuickResultWithoutLiveProvider() async {
        let base = QuickCheckResult(
            currentPerspective: "Base current.",
            afterPerspective: "Base after.",
            verdict: .pause,
            primaryAction: .wait90s,
            secondaryActions: [.decideTomorrow]
        )
        let input = QuickCheckInput(
            scenario: .buy,
            motivation: .reward,
            expectedOutcome: .temporaryRelief,
            controlLevel: .maybe,
            note: "Today was rough."
        )

        let refined = await DecisionIntelligenceProviderPipeline.refineQuickResult(
            base: base,
            input: input,
            preference: .gemmaE4B,
            allowFallbacks: true,
            testingStubProfile: .smoke
        )

        XCTAssertEqual(refined?.verdict, base.verdict)
        XCTAssertTrue(refined?.currentPerspective.contains("Stub current:") == true)
        XCTAssertTrue(refined?.afterPerspective.contains("Stub after:") == true)
    }

    @MainActor
    func testTemplatePinnedQuickRefinementRecordsTemplatePinnedTelemetryAndTrace() async {
        let base = QuickCheckResult(
            currentPerspective: "Base current.",
            afterPerspective: "Base after.",
            verdict: .pause,
            primaryAction: .wait90s,
            secondaryActions: [.decideTomorrow]
        )
        let input = QuickCheckInput(
            scenario: .buy,
            motivation: .reward,
            expectedOutcome: .temporaryRelief,
            controlLevel: .maybe,
            note: "Today was rough."
        )

        let refined = await DecisionIntelligenceProviderPipeline.refineQuickResult(
            base: base,
            input: input,
            preference: .template,
            allowFallbacks: true,
            testingStubProfile: nil
        )

        XCTAssertNil(refined)

        let snapshot = await DecisionIntelligenceTelemetryStore.shared.snapshot()
        XCTAssertEqual(snapshot.outcomeCount[.templatePinned], 1)

        guard let latestTrace = DecisionIntelligenceDebugStore.shared.traces.first else {
            return XCTFail("Expected a template-pinned quick trace.")
        }

        XCTAssertEqual(latestTrace.kind, .quick)
        XCTAssertEqual(latestTrace.activeProvider, nil)
        XCTAssertEqual(latestTrace.attemptedProviders, [.template])
        XCTAssertTrue(latestTrace.detail.contains("Template mode is pinned"))
    }

    @MainActor
    func testRefinementTraceCarriesContextLifecycleState() async {
        let base = BalanceBoardResult(
            headline: "Base headline",
            summary: "Base summary",
            focusTitle: "Base focus",
            focusDescription: "Base description",
            nextAction: "Base next action"
        )
        let input = BalanceBoardInput(
            prompt: "Should I take this side project?",
            desire: "Momentum",
            concern: "Burn out",
            constraint: "",
            longTerm: ""
        )
        let contextState = DecisionContextPreparedState(
            rebuiltSession: true,
            generation: 3,
            anchorFields: [.balancePrompt],
            activeFields: [.balancePrompt, .balanceConcern],
            staleFields: [.balanceDesire]
        )
        let neuralState = DecisionNeuralState(
            mode: .balance,
            dominantActivations: [
                DecisionActivation(signal: .constraintPressure, strength: 0.82)
            ],
            candidateActions: [
                DecisionActionCandidate(route: .setBoundary, score: 0.82)
            ],
            suppressedBehaviors: ["instant_verdict"],
            detail: "Structured routing is active."
        )

        _ = await DecisionIntelligenceProviderPipeline.refineBalanceResult(
            base: base,
            input: input,
            contextState: contextState,
            neuralState: neuralState,
            preference: .gemmaE4B,
            allowFallbacks: true,
            testingStubProfile: .smoke
        )

        guard let latestTrace = DecisionIntelligenceDebugStore.shared.traces.first else {
            return XCTFail("Expected a recorded balance trace.")
        }

        XCTAssertEqual(latestTrace.kind, .balance)
        XCTAssertEqual(latestTrace.frontstageState?.anchorHeadlines, ["Balance prompt"])
        XCTAssertEqual(latestTrace.contextState, contextState)
        XCTAssertEqual(latestTrace.neuralState, neuralState)
        XCTAssertTrue(latestTrace.prompt.contains("CONTEXT_LIFECYCLE_JSON:"))
        XCTAssertTrue(latestTrace.prompt.contains("NEURAL_STATE_JSON:"))
    }

    @MainActor
    func testQuickRefinementTracePersistsEffectiveRuntimeStrategy() async {
        let base = QuickCheckResult(
            currentPerspective: "Base current.",
            afterPerspective: "Base after.",
            verdict: .pause,
            primaryAction: .wait90s,
            secondaryActions: [.decideTomorrow]
        )
        let input = QuickCheckInput(
            scenario: .buy,
            motivation: .reward,
            expectedOutcome: .temporaryRelief,
            controlLevel: .maybe,
            note: "Today was rough."
        )
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
            actionSpace: ["encourage", "next_step", "fallback_to_template"],
            responseLanguage: .english,
            allowsModelInvocation: true
        )

        _ = await DecisionIntelligenceProviderPipeline.refineQuickResult(
            base: base,
            input: input,
            strategy: strategy,
            preference: .gemmaE4B,
            allowFallbacks: true,
            testingStubProfile: .smoke
        )

        guard let latestTrace = DecisionIntelligenceDebugStore.shared.traces.first else {
            return XCTFail("Expected a recorded quick trace.")
        }

        XCTAssertEqual(latestTrace.kind, .quick)
        XCTAssertEqual(latestTrace.runtimeStrategy, strategy)
        XCTAssertEqual(latestTrace.promptBudget?.targetCharacters, 520)
        XCTAssertEqual(latestTrace.runtimeStrategy?.runtimeGear, .low)
        XCTAssertEqual(latestTrace.runtimeStrategy?.responseLanguage, .english)
    }

    @MainActor
    func testTestingStubCanSelectReminderWithoutLiveProvider() async {
        let selected = await DecisionIntelligenceProviderPipeline.pickReminder(
            from: [
                ReminderSelectionCandidate(id: UUID(), content: "First"),
                ReminderSelectionCandidate(id: UUID(), content: "Last")
            ],
            scenario: .buy,
            prompt: "Rough day",
            mode: .quick,
            preference: .gemmaE4B,
            allowFallbacks: true,
            testingStubProfile: .smoke
        )

        XCTAssertEqual(selected?.content, "Last")
    }

    @MainActor
    func testTemplatePinnedReminderSelectionRecordsTelemetryWithoutTrace() async {
        let selected = await DecisionIntelligenceProviderPipeline.pickReminder(
            from: [
                ReminderSelectionCandidate(id: UUID(), content: "First"),
                ReminderSelectionCandidate(id: UUID(), content: "Last")
            ],
            scenario: .buy,
            prompt: "Rough day",
            mode: .quick,
            preference: .template,
            allowFallbacks: true,
            testingStubProfile: nil
        )

        XCTAssertNil(selected)

        let snapshot = await DecisionIntelligenceTelemetryStore.shared.snapshot()
        XCTAssertEqual(snapshot.outcomeCount[.templatePinned], 1)
        XCTAssertTrue(DecisionIntelligenceDebugStore.shared.traces.isEmpty)
    }

    @MainActor
    func testSecondQuickRefinementCanBeServedFromResponseCache() async {
        let base = QuickCheckResult(
            currentPerspective: "Base current.",
            afterPerspective: "Base after.",
            verdict: .pause,
            primaryAction: .wait90s,
            secondaryActions: [.decideTomorrow]
        )
        let input = QuickCheckInput(
            scenario: .buy,
            motivation: .reward,
            expectedOutcome: .temporaryRelief,
            controlLevel: .maybe,
            note: "Today was rough."
        )

        _ = await DecisionIntelligenceProviderPipeline.refineQuickResult(
            base: base,
            input: input,
            preference: .gemmaE4B,
            allowFallbacks: true,
            testingStubProfile: .smoke
        )

        _ = await DecisionIntelligenceProviderPipeline.refineQuickResult(
            base: base,
            input: input,
            preference: .gemmaE4B,
            allowFallbacks: true,
            testingStubProfile: .smoke
        )

        guard let latestTrace = DecisionIntelligenceDebugStore.shared.traces.first else {
            return XCTFail("Expected a recorded trace.")
        }

        XCTAssertEqual(latestTrace.kind, .quick)
        XCTAssertTrue(latestTrace.detail.contains("structured prompt cache"))
    }

    @MainActor
    func testTelemetryCapturesProviderSuccessThenCacheHit() async {
        let base = QuickCheckResult(
            currentPerspective: "Base current.",
            afterPerspective: "Base after.",
            verdict: .pause,
            primaryAction: .wait90s,
            secondaryActions: [.decideTomorrow]
        )
        let input = QuickCheckInput(
            scenario: .buy,
            motivation: .reward,
            expectedOutcome: .temporaryRelief,
            controlLevel: .maybe,
            note: "Today was rough."
        )

        _ = await DecisionIntelligenceProviderPipeline.refineQuickResult(
            base: base,
            input: input,
            preference: .gemmaE4B,
            allowFallbacks: true,
            testingStubProfile: .smoke
        )
        _ = await DecisionIntelligenceProviderPipeline.refineQuickResult(
            base: base,
            input: input,
            preference: .gemmaE4B,
            allowFallbacks: true,
            testingStubProfile: .smoke
        )

        let snapshot = await DecisionIntelligenceTelemetryStore.shared.snapshot()

        XCTAssertEqual(snapshot.requestCountByKind[.quick], 2)
        XCTAssertEqual(snapshot.outcomeCount[.providerSuccess], 1)
        XCTAssertEqual(snapshot.outcomeCount[.cacheHit], 1)
        XCTAssertEqual(snapshot.activeProviderCount[.testingStub], 2)
        XCTAssertEqual(snapshot.attemptedProviderCount[.testingStub], 2)
        XCTAssertEqual(snapshot.fallbackActivations, 2)
    }

    @MainActor
    func testQuickAdmissionSkipsWhenStructuredTemplateAlreadyCoversTheTurn() async {
        let base = QuickCheckResult(
            currentPerspective: "Base current.",
            afterPerspective: "Base after.",
            verdict: .pause,
            primaryAction: .wait90s,
            secondaryActions: []
        )
        let input = QuickCheckInput(
            scenario: .buy,
            motivation: .reward,
            expectedOutcome: .temporaryRelief,
            controlLevel: .maybe,
            note: ""
        )

        let refined = await DecisionIntelligenceProviderPipeline.refineQuickResult(
            base: base,
            input: input,
            preference: .gemmaE4B,
            allowFallbacks: true,
            testingStubProfile: nil
        )

        XCTAssertNil(refined)

        let snapshot = await DecisionIntelligenceTelemetryStore.shared.snapshot()
        XCTAssertEqual(snapshot.outcomeCount[.admissionSkipped], 1)
        XCTAssertEqual(snapshot.admissionSkipCountByReason[.templateAlreadySufficient], 1)
        XCTAssertEqual(snapshot.avoidableModelCallRate, 1, accuracy: 0.0001)
        XCTAssertEqual(snapshot.avoidableModelCallRateByKind[.quick] ?? 0, 1, accuracy: 0.0001)

        guard let latestTrace = DecisionIntelligenceDebugStore.shared.traces.first else {
            return XCTFail("Expected an admission-skip trace.")
        }

        XCTAssertEqual(latestTrace.kind, .quick)
        XCTAssertEqual(latestTrace.admissionDecision?.skipReason, .templateAlreadySufficient)
        XCTAssertTrue(latestTrace.detail.contains("Admission controller skipped primary refinement"))
    }

    @MainActor
    func testQuickPromptCompactionCanAvoidAdmissionSkipWhenOptionalContextExplodes() async {
        let base = QuickCheckResult(
            currentPerspective: "Base current.",
            afterPerspective: "Base after.",
            verdict: .pause,
            primaryAction: .wait90s,
            secondaryActions: [.decideTomorrow]
        )
        let input = QuickCheckInput(
            scenario: .buy,
            motivation: .reward,
            expectedOutcome: .temporaryRelief,
            controlLevel: .maybe,
            note: "Today was rough."
        )
        let neuralState = DecisionNeuralState(
            mode: .quick,
            dominantActivations: [
                DecisionActivation(signal: .urgency, strength: 0.96)
            ],
            candidateActions: [
                DecisionActionCandidate(route: .waitBuffer, score: 0.96)
            ],
            suppressedBehaviors: Array(repeating: "long_explanation", count: 120),
            detail: String(repeating: "pressure-", count: 220)
        )

        _ = await DecisionIntelligenceProviderPipeline.refineQuickResult(
            base: base,
            input: input,
            neuralState: neuralState,
            preference: .gemmaE4B,
            allowFallbacks: true,
            testingStubProfile: nil
        )

        let snapshot = await DecisionIntelligenceTelemetryStore.shared.snapshot()
        XCTAssertNil(snapshot.outcomeCount[.admissionSkipped])
        XCTAssertNil(snapshot.admissionSkipCountByReason[.budgetExceeded])
        XCTAssertEqual(snapshot.requestCountByKind[.quick], 1)
        XCTAssertNil(snapshot.activeProviderCount[.testingStub])

        guard let latestTrace = DecisionIntelligenceDebugStore.shared.traces.first else {
            return XCTFail("Expected a recorded quick trace.")
        }

        XCTAssertEqual(latestTrace.kind, .quick)
        XCTAssertNil(latestTrace.admissionDecision?.skipReason)
        XCTAssertEqual(latestTrace.promptBudget?.isWithinTarget, true)
        XCTAssertTrue(latestTrace.prompt.contains("[COMPACTION]"))
        XCTAssertTrue(latestTrace.prompt.contains("Dropped blocks:"))
    }

    @MainActor
    func testBalanceAdmissionSkipsWhenThereIsNotEnoughOpenTextSignal() async {
        let base = BalanceBoardResult(
            headline: "Base headline",
            summary: "Base summary",
            focusTitle: "Base focus",
            focusDescription: "Base description",
            nextAction: "Base next action"
        )
        let input = BalanceBoardInput(
            prompt: "Should I take the side project?",
            desire: "",
            concern: "",
            constraint: "My week is already full.",
            longTerm: ""
        )

        let refined = await DecisionIntelligenceProviderPipeline.refineBalanceResult(
            base: base,
            input: input,
            preference: .gemmaE4B,
            allowFallbacks: true,
            testingStubProfile: nil
        )

        XCTAssertNil(refined)

        let snapshot = await DecisionIntelligenceTelemetryStore.shared.snapshot()
        XCTAssertEqual(snapshot.outcomeCount[.admissionSkipped], 1)
        XCTAssertEqual(snapshot.admissionSkipCountByReason[.insufficientSourceMaterial], 1)
        XCTAssertEqual(snapshot.avoidableModelCallRate, 1, accuracy: 0.0001)
        XCTAssertEqual(snapshot.avoidableModelCallRateByKind[.balance] ?? 0, 1, accuracy: 0.0001)
    }

    @MainActor
    func testBalanceRefinementUsesProtectiveEBrianTurnWithoutInvokingProvider() async {
        let base = BalanceBoardResult(
            headline: "Base headline",
            summary: "Base summary",
            focusTitle: "Base focus",
            focusDescription: "Base description",
            nextAction: "Base next action"
        )
        let input = BalanceBoardInput(
            prompt: "Should I take the side project?",
            desire: "Momentum",
            concern: "Burn out",
            constraint: "My week is already full.",
            longTerm: "I want steadier energy next month."
        )
        let turn = protectiveTurn(
            mode: .block,
            headline: "Hold the boundary",
            body: "Pause and protect the boundary first.",
            alternativeActions: ["Leave the stimulus", "Decide tomorrow"]
        )

        let refined = await DecisionIntelligenceProviderPipeline.refineBalanceResult(
            base: base,
            input: input,
            eBrainTurn: turn,
            preference: .gemmaE4B,
            allowFallbacks: true,
            testingStubProfile: nil
        )

        XCTAssertEqual(refined?.headline, turn.renderedOutput.headline)
        XCTAssertEqual(refined?.summary, turn.renderedOutput.body)
        XCTAssertEqual(refined?.nextAction, "Leave the stimulus")
        XCTAssertEqual(refined?.focusTitle, base.focusTitle)
        XCTAssertEqual(refined?.focusDescription, base.focusDescription)

        let snapshot = await DecisionIntelligenceTelemetryStore.shared.snapshot()
        XCTAssertNil(snapshot.requestCountByKind[.balance])
        XCTAssertNil(snapshot.outcomeCount[.providerSuccess])
    }

    @MainActor
    func testMirrorRefinementUsesProtectiveEBrianTurnWithoutInvokingProvider() async {
        let base = MirrorResult(
            headline: "Base headline",
            coreTension: "Base tension",
            nextActionTitle: "Base next action title",
            nextAction: "Base next action"
        )
        let input = MirrorInput(
            prompt: "Should I stay in this relationship?",
            emotion: "I feel tired and sad.",
            relationship: "We keep repeating the same argument.",
            reality: "We live far apart and avoid hard conversations.",
            longTerm: "I want steadier relationships.",
            selfLens: "I feel pulled between hope and exhaustion."
        )
        let turn = protectiveTurn(
            mode: .replace,
            headline: "Take the safer step",
            body: "Use the safer path instead of forcing the current one.",
            alternativeActions: ["Use the safer step", "Continue mindfully"]
        )

        let refined = await DecisionIntelligenceProviderPipeline.refineMirrorResult(
            base: base,
            input: input,
            eBrainTurn: turn,
            preference: .gemmaE4B,
            allowFallbacks: true,
            testingStubProfile: nil
        )

        XCTAssertEqual(refined?.headline, turn.renderedOutput.headline)
        XCTAssertEqual(refined?.coreTension, turn.renderedOutput.body)
        XCTAssertEqual(refined?.nextActionTitle, "Use the safer step")
        XCTAssertEqual(refined?.nextAction, "Use the safer step")

        let snapshot = await DecisionIntelligenceTelemetryStore.shared.snapshot()
        XCTAssertNil(snapshot.requestCountByKind[.mirror])
        XCTAssertNil(snapshot.outcomeCount[.providerSuccess])
    }

    @MainActor
    func testReminderAdmissionSkipsWhenOnlyOneCandidateExists() async {
        let selected = await DecisionIntelligenceProviderPipeline.pickReminder(
            from: [
                ReminderSelectionCandidate(id: UUID(), content: "Only candidate")
            ],
            scenario: .buy,
            prompt: "I still want it.",
            mode: .quick,
            preference: .gemmaE4B,
            allowFallbacks: true,
            testingStubProfile: nil
        )

        XCTAssertNil(selected)

        let snapshot = await DecisionIntelligenceTelemetryStore.shared.snapshot()
        XCTAssertEqual(snapshot.outcomeCount[.admissionSkipped], 1)
        XCTAssertEqual(snapshot.admissionSkipCountByReason[.insufficientChoiceSpread], 1)
    }

    @MainActor
    func testReminderAdmissionSkipsWhenDeterministicLeaderIsAlreadyClear() async {
        let selected = await DecisionIntelligenceProviderPipeline.pickReminder(
            from: [
                ReminderSelectionCandidate(id: UUID(), content: "This is stress shopping again."),
                ReminderSelectionCandidate(id: UUID(), content: "You already knew this was a real replacement.", rank: 1)
            ],
            scenario: .buy,
            prompt: "This is stress shopping again tonight.",
            mode: .quick,
            preference: .gemmaE4B,
            allowFallbacks: true,
            testingStubProfile: nil
        )

        XCTAssertNil(selected)

        let snapshot = await DecisionIntelligenceTelemetryStore.shared.snapshot()
        XCTAssertEqual(snapshot.outcomeCount[.admissionSkipped], 1)
        XCTAssertEqual(snapshot.admissionSkipCountByReason[.retrievalNotNeeded], 1)
        XCTAssertEqual(snapshot.selectionControlOnlyRate, 1, accuracy: 0.0001)
        XCTAssertEqual(snapshot.selectionRetrievalBypassRate, 1, accuracy: 0.0001)

        guard let latestTrace = DecisionIntelligenceDebugStore.shared.traces.first else {
            return XCTFail("Expected an admission-skip trace.")
        }

        XCTAssertEqual(latestTrace.kind, .reminder)
        XCTAssertEqual(latestTrace.admissionDecision?.skipReason, .retrievalNotNeeded)
        XCTAssertEqual(latestTrace.admissionDecision?.selectionNeed, .control)
    }

    @MainActor
    func testTestingStubBypassesAdmissionSkipForBalanceRefinement() async {
        let base = BalanceBoardResult(
            headline: "Base headline",
            summary: "Base summary",
            focusTitle: "Base focus",
            focusDescription: "Base description",
            nextAction: "Base next action"
        )
        let input = BalanceBoardInput(
            prompt: "Should I take this side project?",
            desire: "Momentum",
            concern: "Burnout",
            constraint: String(repeating: "constraint-", count: 80),
            longTerm: String(repeating: "future-", count: 80)
        )
        let contextState = DecisionContextPreparedState(
            rebuiltSession: false,
            generation: 1,
            anchorFields: [.balancePrompt],
            activeFields: [.balancePrompt, .balanceDesire, .balanceConcern, .balanceConstraint, .balanceLongTerm],
            staleFields: []
        )
        let neuralState = DecisionNeuralState(
            mode: .balance,
            dominantActivations: [
                DecisionActivation(signal: .constraintPressure, strength: 0.95)
            ],
            candidateActions: [
                DecisionActionCandidate(route: .setBoundary, score: 0.95)
            ],
            suppressedBehaviors: Array(repeating: "long_explanation", count: 80),
            detail: String(repeating: "pressure-", count: 120)
        )

        let refined = await DecisionIntelligenceProviderPipeline.refineBalanceResult(
            base: base,
            input: input,
            contextState: contextState,
            neuralState: neuralState,
            preference: .gemmaE4B,
            allowFallbacks: true,
            testingStubProfile: .smoke
        )

        XCTAssertEqual(refined?.headline, "Stub balance board")

        let snapshot = await DecisionIntelligenceTelemetryStore.shared.snapshot()
        XCTAssertEqual(snapshot.outcomeCount[.providerSuccess], 1)
        XCTAssertNil(snapshot.outcomeCount[.admissionSkipped])

        guard let latestTrace = DecisionIntelligenceDebugStore.shared.traces.first else {
            return XCTFail("Expected a balance trace.")
        }

        XCTAssertEqual(latestTrace.kind, .balance)
        XCTAssertEqual(latestTrace.activeProvider, .testingStub)
        XCTAssertTrue(latestTrace.admissionDecision?.isAllowed == true)
    }

    @MainActor
    func testQuickConsistencyHarnessRejectsProviderResultOutsideBoundaryActionSpace() async {
        let base = QuickCheckResult(
            currentPerspective: "Base current.",
            afterPerspective: "Base after.",
            verdict: .pause,
            primaryAction: .wait90s,
            secondaryActions: [.decideTomorrow]
        )
        let input = QuickCheckInput(
            scenario: .buy,
            motivation: .reward,
            expectedOutcome: .temporaryRelief,
            controlLevel: .maybe,
            note: "Today was rough."
        )

        let refined = await DecisionIntelligenceProviderPipeline.refineQuickResult(
            base: base,
            input: input,
            brainState: blockedGuidanceBrainState(mode: .quick),
            preference: .gemmaE4B,
            allowFallbacks: true,
            testingStubProfile: .smoke
        )

        XCTAssertNil(refined)

        guard let rejectionTrace = DecisionIntelligenceDebugStore.shared.traces.first(where: \.consistencyRejected) else {
            return XCTFail("Expected a consistency rejection trace.")
        }

        XCTAssertEqual(rejectionTrace.kind, .quick)
        XCTAssertEqual(rejectionTrace.activeProvider, .testingStub)
        XCTAssertEqual(rejectionTrace.consistencyCheck?.violations.first?.kind, .forbiddenAction)
        XCTAssertTrue(rejectionTrace.detail.contains("Consistency harness rejected"))
    }

    @MainActor
    func testQuickConsistencyHarnessQuarantinesCachedResultBeforeServingIt() async {
        let base = QuickCheckResult(
            currentPerspective: "Base current.",
            afterPerspective: "Base after.",
            verdict: .pause,
            primaryAction: .wait90s,
            secondaryActions: [.decideTomorrow]
        )
        let input = QuickCheckInput(
            scenario: .buy,
            motivation: .reward,
            expectedOutcome: .temporaryRelief,
            controlLevel: .maybe,
            note: "Today was rough."
        )
        let brainState = blockedGuidanceBrainState(mode: .quick)
        let cached = QuickCheckResult(
            currentPerspective: "Stub current: cached version",
            afterPerspective: "Stub after: cached version",
            verdict: .pause,
            primaryAction: .wait90s,
            secondaryActions: [.decideTomorrow]
        )
        let envelope = DecisionIntelligencePromptContract.quickRefinementEnvelope(
            base: base,
            input: input,
            brainState: brainState
        )
        let cacheKey = DecisionIntelligencePromptContract.cacheFingerprint(
            provider: .testingStub,
            envelope: envelope
        )
        await DecisionIntelligenceResponseCache.shared.storeQuickResult(cached, for: cacheKey)

        let refined = await DecisionIntelligenceProviderPipeline.refineQuickResult(
            base: base,
            input: input,
            brainState: brainState,
            preference: .gemmaE4B,
            allowFallbacks: true,
            testingStubProfile: .smoke
        )

        XCTAssertNil(refined)

        let cacheSnapshot = await DecisionIntelligenceResponseCache.shared.telemetrySnapshot()
        XCTAssertEqual(cacheSnapshot.totalQuarantinedHits, 1)
        XCTAssertTrue(
            DecisionIntelligenceDebugStore.shared.traces.contains {
                $0.consistencyRejected && $0.detail.contains("cached primary refinement")
            }
        )
    }

    @MainActor
    func testBalanceTraceIncludesPassingConsistencyCheckWhenBrainStateIsAvailable() async {
        let base = BalanceBoardResult(
            headline: "Base headline",
            summary: "Base summary",
            focusTitle: "Base focus",
            focusDescription: "Base description",
            nextAction: "Base next action"
        )
        let input = BalanceBoardInput(
            prompt: "Should I take this side project?",
            desire: "Momentum",
            concern: "Burnout",
            constraint: "My week is already full.",
            longTerm: "I want steadier energy next month."
        )

        let refined = await DecisionIntelligenceProviderPipeline.refineBalanceResult(
            base: base,
            input: input,
            brainState: permissiveBrainState(mode: .balance),
            preference: .gemmaE4B,
            allowFallbacks: true,
            testingStubProfile: .smoke
        )

        XCTAssertEqual(refined?.headline, "Stub balance board")

        guard let latestTrace = DecisionIntelligenceDebugStore.shared.traces.first else {
            return XCTFail("Expected a recorded balance trace.")
        }

        XCTAssertEqual(latestTrace.kind, .balance)
        XCTAssertFalse(latestTrace.consistencyRejected)
        XCTAssertNotNil(latestTrace.consistencyCheck)
        XCTAssertTrue(latestTrace.consistencyCheck?.isConsistent == true)
    }

    private func protectiveTurn(
        mode: BASActionPermitMode,
        headline: String,
        body: String,
        alternativeActions: [String]
    ) -> BASEBrainTurnResult {
        let deviceState = BASDeviceState(
            batteryLevel: 0.66,
            thermalLevel: .warm,
            memoryFreeMB: 2_048,
            networkState: .online,
            foregroundState: .foreground,
            cpuLoad: 0.31,
            gpuLoad: 0.12,
            npuAvailable: true,
            latencyBudgetMs: 1_400
        )
        let budgetFrame = BASBudgetFrame.guardedLocal(maxLoops: 2, maxCandidates: 2, maxDecodeTokens: 160, retrievalDepth: 2)
        let hostContext = BASHostProfile(hostID: "host.primary", longTermGoals: ["Stay calm"], noGoZones: ["unsafe"])
        let contextFrame = BASContextFrame(
            utterance: body,
            taskType: .highPressure,
            emotionalLoad: 0.82,
            timePressure: 0.74,
            relationPattern: "self",
            ambiguityScore: 0.63,
            consequenceLevel: 0.81,
            manipulationHints: ["time_pressure"],
            hostRelevance: 0.91
        )
        let decomposeFrame = BASDecomposeFrame(
            facts: [headline],
            goals: ["Keep the boundary"],
            emotions: ["alert"],
            unknowns: ["best next step"],
            contradictions: [],
            pressureSignals: ["urgency"],
            manipulationSignals: ["forced-now"],
            mirrorText: body
        )
        let memoryAtom = BASMemoryAtom(
            memoryID: "mem-1",
            summary: "Protect the boundary first.",
            contentType: .warm,
            source: "session",
            confidence: 0.86,
            conflictFingerprint: "fp-1"
        )
        let memoryBundle = BASMemoryBundle(
            atoms: [memoryAtom],
            retrievalTags: ["boundary"],
            conflictRefs: [],
            activeHostVersion: hostContext.activeVersion
        )
        let candidate = BASCandidatePath(
            candidateID: "cand-1",
            title: "Pause and protect",
            actionSummary: "Hold for a moment before acting.",
            requiredEvidence: ["high pressure"],
            expectedBenefit: 0.9,
            expectedCost: 0.2,
            reversibility: 0.8,
            confidence: 0.87
        )
        let forecast = BASForecastItem(
            candidateID: candidate.candidateID,
            shortTermOutcome: "Less immediate pressure",
            midTermOutcome: "Better boundary clarity",
            worstCase: "Minor delay",
            uncertainty: 0.2,
            affectedRelations: ["self"]
        )
        let critique = BASCritiqueItem(
            candidateID: candidate.candidateID,
            critiqueType: .boundaryConflict,
            critiqueText: "The safer route avoids forcing the choice too early.",
            severity: 0.74
        )
        let triScore = BASTriSelfScore(
            candidateID: candidate.candidateID,
            idScore: 0.42,
            egoScore: 0.81,
            superegoScore: 0.91,
            mergedScore: 0.83,
            veto: false
        )
        let mergedChoice = BASMergedChoice(
            candidateID: candidate.candidateID,
            title: "Pause first",
            actionSummary: "Use the safer next step."
        )
        let riskCard = BASRiskCard(
            totalRisk: 0.88,
            riskLevel: .high,
            factors: ["pressure", "uncertainty"],
            uncertainty: 0.56,
            irreversibility: 0.79,
            manipulationStrength: 0.73,
            gsiScore: 0.68,
            recommendedMode: mode
        )
        let actionPermit = BASActionPermit(
            mode: mode,
            reasonCodes: ["risk.high", "gsi.elevated"],
            requireSecondCheck: true,
            outputLengthCap: 120,
            tonePolicy: "clear_firm",
            templatePolicy: "protective_alternative"
        )
        let thoughtFrame = BASThoughtFrame(
            stepIndex: 1,
            decomposeRef: "decomp-1",
            memoryRefs: [memoryAtom.memoryID],
            candidates: [candidate],
            forecasts: [forecast],
            critiques: [critique],
            triScores: [triScore],
            riskCard: riskCard,
            actionPermit: actionPermit,
            stabilityScore: 0.91,
            stopReason: .blocked
        )
        let thoughtFold = BASThoughtFold(
            foldID: "fold-1",
            compactSlots: ["headline": headline, "body": body],
            candidateSignatures: [candidate.candidateID],
            riskSnapshot: riskCard,
            hostEffectSummary: "Host boundary remains primary.",
            restorePointer: "restore-1",
            checksum: "checksum-1"
        )
        let updateTicket = BASUpdateTicket(
            ticketID: "ticket-1",
            sessionRef: "session-1",
            summary: "Record a protective turn.",
            memoryWriteSuggestion: "Keep the boundary signal in warm memory.",
            hostProfileChangeSuggestion: nil,
            ruleCandidateRef: "rule-1",
            confidence: 0.84,
            conflictFlag: false,
            requiresReview: true
        )
        let runtimeTrace = BASRuntimeTrace(
            sessionID: "session-1",
            layerEvents: [
                BASRuntimeTraceEvent(layerID: "L11", event: "gate", detail: "Protective mode short-circuited refinement.")
            ],
            latencyBreakdownMs: ["guard": 3],
            powerEstimate: 0.12,
            thermalTrace: ["cool"],
            modelRoute: "guarded",
            loopCount: 1,
            cacheHitRate: 0,
            guardrailFindings: [
                BASRuntimeAuditFinding(
                    code: "budget.high_risk_fast_path",
                    layerID: "L1",
                    summary: "Protective short-circuit requested.",
                    severity: .high,
                    enforced: true
                )
            ],
            recommendedKillSwitches: [.forceGuardMode]
        )

        return BASEBrainTurnResult(
            deviceState: deviceState,
            budgetFrame: budgetFrame,
            hostContext: hostContext,
            contextFrame: contextFrame,
            decomposeFrame: decomposeFrame,
            memoryBundle: memoryBundle,
            thoughtFrame: thoughtFrame,
            thoughtFold: thoughtFold,
            triScores: [triScore],
            mergedChoice: mergedChoice,
            riskCard: riskCard,
            actionPermit: actionPermit,
            hostGateValue: 0.37,
            renderedOutput: BASRenderedOutput(
                mode: mode,
                headline: headline,
                body: body,
                alternativeActions: alternativeActions,
                explanationCodes: ["risk.high", "gsi.elevated"]
            ),
            updateTickets: [updateTicket],
            runtimeTrace: runtimeTrace
        )
    }

    private func permissiveBrainState(mode: DecisionMode) -> DecisionBrainState {
        let boundaryPolicy = DecisionBoundaryPolicyState(
            mode: .localOnlyAdvisory,
            riskLevel: .low,
            allowedActionClasses: ["render_local_guidance", "load_governed_memory"],
            blockedActionClasses: ["cloud_escalation"],
            requiredConfirmations: [],
            activeConstraints: [.noCloudEscalation],
            auditHeadline: "Stay local."
        )
        return DecisionBrainState(
            profileCore: ["Values clarity over speed."],
            activeGoals: ["Protect tomorrow's judgment."],
            relevantMemories: ["Waiting overnight usually helps."],
            sessionBiases: ["句子短"],
            retrievalTags: ["cooldown"],
            reactionWeights: .defaults(for: mode),
            boundaryPolicy: boundaryPolicy,
            loadedAt: .now
        )
    }

    private func blockedGuidanceBrainState(mode: DecisionMode) -> DecisionBrainState {
        let boundaryPolicy = DecisionBoundaryPolicyState(
            mode: .localOnlyProtective,
            riskLevel: .high,
            allowedActionClasses: ["load_governed_memory"],
            blockedActionClasses: ["render_local_guidance", "cloud_escalation"],
            requiredConfirmations: ["irreversible_decision"],
            activeConstraints: [.noCloudEscalation, .lockSensitiveMemory],
            auditHeadline: "Hold the line."
        )
        return DecisionBrainState(
            profileCore: ["Protect the boundary first."],
            activeGoals: ["Do not turn signal into action yet."],
            relevantMemories: ["Fast guidance is not allowed here."],
            sessionBiases: ["句子短"],
            retrievalTags: ["protective"],
            reactionWeights: .defaults(for: mode),
            boundaryPolicy: boundaryPolicy,
            loadedAt: .now
        )
    }
}
