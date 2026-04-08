import XCTest
@testable import Before

final class DecisionIntelligenceProviderPipelineTests: XCTestCase {
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
}
