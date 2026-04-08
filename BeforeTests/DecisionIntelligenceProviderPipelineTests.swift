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

    func testRuntimeStatusFallsBackToGemmaWhenFoundationPreferenceIsUnavailable() {
        let preferences = BeforePreferences(
            homePromptAction: .autoRoute,
            quickBufferDuration: .ninetySeconds,
            restoreInProgressWorkspaces: true,
            showReviewInsights: true,
            onDeviceIntelligenceMode: .assistive,
            preferredIntelligenceProvider: .foundationModels
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
}
