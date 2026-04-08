import XCTest
@testable import Before

final class DecisionIntelligenceExecutionProfileTests: XCTestCase {
    func testSixGigDeviceFallsBackToConservativeDeterministicProfile() {
        let profile = DecisionIntelligenceExecutionProfileResolver.resolve(
            preferences: assistivePreferences,
            device: DeviceCapabilitySnapshot(
                isSimulator: false,
                supportsMetal: true,
                supportsCoreMLAcceleration: true,
                physicalMemoryBytes: 6 * 1_073_741_824,
                isLowPowerModeEnabled: false
            ),
            foundationStatus: unavailableFoundation,
            gemmaStatus: availableGemma
        )

        XCTAssertEqual(profile.tier, .conservativeDeterministic)
        XCTAssertEqual(profile.effectiveProviderPreference, .template)
        XCTAssertFalse(profile.allowsQuickRefinement)
        XCTAssertFalse(profile.allowsBalanceRefinement)
        XCTAssertFalse(profile.allowsMirrorRefinement)
        XCTAssertFalse(profile.allowsReminderSelection)
        XCTAssertTrue(profile.detail.contains("iPhone 14"))
    }

    func testSevenGigDeviceKeepsGemmaForHeavierWorkButSkipsQuickRefinement() {
        let profile = DecisionIntelligenceExecutionProfileResolver.resolve(
            preferences: assistivePreferences,
            device: DeviceCapabilitySnapshot(
                isSimulator: false,
                supportsMetal: true,
                supportsCoreMLAcceleration: true,
                physicalMemoryBytes: 7 * 1_073_741_824,
                isLowPowerModeEnabled: false
            ),
            foundationStatus: unavailableFoundation,
            gemmaStatus: availableGemma
        )

        XCTAssertEqual(profile.tier, .balancedGemma)
        XCTAssertEqual(profile.effectiveProviderPreference, .gemmaE4B)
        XCTAssertFalse(profile.allowsQuickRefinement)
        XCTAssertTrue(profile.allowsBalanceRefinement)
        XCTAssertTrue(profile.allowsMirrorRefinement)
        XCTAssertTrue(profile.allowsReminderSelection)
    }

    func testFoundationAvailabilityWinsOnDevice() {
        let profile = DecisionIntelligenceExecutionProfileResolver.resolve(
            preferences: assistivePreferences,
            device: DeviceCapabilitySnapshot(
                isSimulator: false,
                supportsMetal: true,
                supportsCoreMLAcceleration: true,
                physicalMemoryBytes: 6 * 1_073_741_824,
                isLowPowerModeEnabled: false
            ),
            foundationStatus: DecisionModelProviderStatus(
                kind: .foundationModels,
                isAvailable: true,
                title: "Available",
                detail: "Apple is ready."
            ),
            gemmaStatus: availableGemma
        )

        XCTAssertEqual(profile.tier, .systemManaged)
        XCTAssertEqual(profile.effectiveProviderPreference, .foundationModels)
        XCTAssertTrue(profile.allowsQuickRefinement)
        XCTAssertTrue(profile.allowsBalanceRefinement)
        XCTAssertTrue(profile.allowsMirrorRefinement)
        XCTAssertTrue(profile.allowsReminderSelection)
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

    private var availableGemma: DecisionModelProviderStatus {
        DecisionModelProviderStatus(
            kind: .gemmaE4B,
            isAvailable: true,
            title: "Ready",
            detail: "Gemma is ready."
        )
    }

    private var unavailableFoundation: DecisionModelProviderStatus {
        DecisionModelProviderStatus(
            kind: .foundationModels,
            isAvailable: false,
            title: "Unavailable",
            detail: "Apple is not ready."
        )
    }
}
