import XCTest
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
        XCTAssertTrue(latestTrace.detail.contains("Admission controller skipped quick refinement"))
    }

    @MainActor
    func testQuickAdmissionCanSkipModelInvocationWhenPromptBecomesTooLarge() async {
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

        let refined = await DecisionIntelligenceProviderPipeline.refineQuickResult(
            base: base,
            input: input,
            neuralState: neuralState,
            preference: .gemmaE4B,
            allowFallbacks: true,
            testingStubProfile: nil
        )

        XCTAssertNil(refined)

        let snapshot = await DecisionIntelligenceTelemetryStore.shared.snapshot()
        XCTAssertEqual(snapshot.outcomeCount[.admissionSkipped], 1)
        XCTAssertEqual(snapshot.admissionSkipCountByReason[.budgetExceeded], 1)
        XCTAssertEqual(snapshot.requestCountByKind[.quick], 1)
        XCTAssertNil(snapshot.activeProviderCount[.testingStub])

        guard let latestTrace = DecisionIntelligenceDebugStore.shared.traces.first else {
            return XCTFail("Expected an admission-skip trace.")
        }

        XCTAssertEqual(latestTrace.kind, .quick)
        XCTAssertEqual(latestTrace.admissionDecision?.skipReason, .budgetExceeded)
        XCTAssertEqual(latestTrace.promptBudget?.isWithinTarget, false)
        XCTAssertTrue(latestTrace.detail.contains("Admission controller skipped quick refinement"))
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
        XCTAssertEqual(snapshot.admissionSkipCountByReason[.insufficientReminderChoice], 1)
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
        XCTAssertEqual(snapshot.reminderControlOnlyRate, 1, accuracy: 0.0001)
        XCTAssertEqual(snapshot.reminderRetrievalBypassRate, 1, accuracy: 0.0001)

        guard let latestTrace = DecisionIntelligenceDebugStore.shared.traces.first else {
            return XCTFail("Expected an admission-skip trace.")
        }

        XCTAssertEqual(latestTrace.kind, .reminder)
        XCTAssertEqual(latestTrace.admissionDecision?.skipReason, .retrievalNotNeeded)
        XCTAssertEqual(latestTrace.admissionDecision?.reminderSelectionNeed, .control)
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
}
