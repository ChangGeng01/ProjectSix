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
}
