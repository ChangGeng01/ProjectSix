import XCTest
@testable import Before

final class DecisionIntelligenceCoordinatorTests: XCTestCase {
    func testAssistiveQuickResultKeepsVerdictAndActionsWhileTighteningCopy() {
        let input = QuickCheckInput(
            scenario: .buy,
            motivation: .stressed,
            expectedOutcome: .temporaryRelief,
            controlLevel: .maybe,
            note: "today was rough after work"
        )

        let deterministic = CheckRuleEngine.evaluate(input)
        let assistive = DecisionIntelligenceCoordinator.quickResult(
            for: input,
            preferences: assistivePreferences
        )

        XCTAssertEqual(assistive.verdict, deterministic.verdict)
        XCTAssertEqual(assistive.primaryAction, deterministic.primaryAction)
        XCTAssertEqual(assistive.secondaryActions, deterministic.secondaryActions)
        XCTAssertNotEqual(assistive.currentPerspective, deterministic.currentPerspective)
    }

    func testOffModeFallsBackToDeterministicRouting() {
        let prompt = "Should I leave this relationship or keep trying?"

        let assistive = DecisionIntelligenceCoordinator.route(
            prompt: prompt,
            preferences: assistivePreferences
        )
        let deterministic = DecisionIntelligenceCoordinator.route(
            prompt: prompt,
            preferences: offPreferences
        )

        XCTAssertEqual(deterministic, DecisionModeRouter.route(prompt: prompt))
        XCTAssertEqual(assistive.mode, .mirror)
    }

    func testAssistiveReminderSelectionCanPreferPromptMatchInsideRankedCandidates() {
        let reminders = [
            SelfReminder(
                content: "This is just stress shopping again.",
                scenario: .buy,
                source: .userWritten,
                createdAt: .now.addingTimeInterval(-20),
                lastUsedAt: .now.addingTimeInterval(-20)
            ),
            SelfReminder(
                content: "You actually needed the charger.",
                scenario: .buy,
                source: .userWritten,
                createdAt: .now.addingTimeInterval(-10),
                lastUsedAt: .now.addingTimeInterval(-10)
            )
        ]

        let selected = DecisionIntelligenceCoordinator.bestReminder(
            from: reminders,
            scenario: .buy,
            prompt: "I want to buy these shoes because today was rough",
            mode: .quick,
            preferences: assistivePreferences
        )

        XCTAssertEqual(selected?.content, "This is just stress shopping again.")
    }

    private var assistivePreferences: BeforePreferences {
        BeforePreferences(
            homePromptAction: .autoRoute,
            quickBufferDuration: .ninetySeconds,
            restoreInProgressWorkspaces: true,
            showReviewInsights: true,
            onDeviceIntelligenceMode: .assistive,
            preferredIntelligenceProvider: .gemmaE4B,
            allowModelFallbacks: true
        )
    }

    private var offPreferences: BeforePreferences {
        BeforePreferences(
            homePromptAction: .autoRoute,
            quickBufferDuration: .ninetySeconds,
            restoreInProgressWorkspaces: true,
            showReviewInsights: true,
            onDeviceIntelligenceMode: .off,
            preferredIntelligenceProvider: .gemmaE4B,
            allowModelFallbacks: true
        )
    }

    func testRuntimeStatusFallsBackToFoundationWhenGemmaIsUnavailable() {
        let status = DecisionIntelligenceCoordinator.runtimeStatus(
            preferences: assistivePreferences,
            gemmaStatus: DecisionModelProviderStatus(
                kind: .gemmaE4B,
                isAvailable: false,
                title: "Unavailable",
                detail: "Gemma is missing."
            ),
            foundationStatus: DecisionModelProviderStatus(
                kind: .foundationModels,
                isAvailable: true,
                title: "Available",
                detail: "Apple is ready."
            )
        )

        XCTAssertEqual(status.preferred, .gemmaE4B)
        XCTAssertEqual(status.active, .foundationModels)
        XCTAssertEqual(status.fallback, .foundationModels)
    }

    func testRuntimeStatusFallsBackToTemplateWhenNoAssistiveProviderIsAvailable() {
        let status = DecisionIntelligenceCoordinator.runtimeStatus(
            preferences: assistivePreferences,
            gemmaStatus: DecisionModelProviderStatus(
                kind: .gemmaE4B,
                isAvailable: false,
                title: "Unavailable",
                detail: "Gemma is missing."
            ),
            foundationStatus: DecisionModelProviderStatus(
                kind: .foundationModels,
                isAvailable: false,
                title: "Unavailable",
                detail: "Apple is off."
            )
        )

        XCTAssertEqual(status.preferred, .gemmaE4B)
        XCTAssertEqual(status.active, .template)
        XCTAssertEqual(status.fallback, .template)
    }
}
