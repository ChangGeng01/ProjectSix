import XCTest
@testable import Before

final class GemmaE4BIntelligenceServiceTests: XCTestCase {
    func testBackendResolutionDefaultsToCpuOnSimulatorLikeSnapshot() {
        let resolution = GemmaE4BIntelligenceService.backendResolution(
            policy: .auto,
            device: DeviceCapabilitySnapshot(
                isSimulator: true,
                supportsMetal: true,
                supportsCoreMLAcceleration: false
            )
        )

        XCTAssertEqual(resolution.policy, .auto)
        XCTAssertEqual(resolution.effectiveBackend, .cpu)
        XCTAssertFalse(resolution.isHardwareAccelerated)
    }

    func testBackendResolutionPrefersCoreMLOnPhysicalDeviceSnapshot() {
        let resolution = GemmaE4BIntelligenceService.backendResolution(
            policy: .auto,
            device: DeviceCapabilitySnapshot(
                isSimulator: false,
                supportsMetal: true,
                supportsCoreMLAcceleration: true
            )
        )

        XCTAssertEqual(resolution.effectiveBackend, .coreML)
        XCTAssertTrue(resolution.isHardwareAccelerated)
    }

    func testProviderStatusTracksMissingBundleBeforeRuntime() {
        let status = GemmaE4BIntelligenceService.providerStatus(
            asset: nil,
            runtime: MockGemmaLocalRuntimeBridge(
                status: GemmaLocalRuntimeStatus(
                    canRunInference: true,
                    title: "Ready",
                    detail: "Runtime is ready."
                )
            )
        )

        XCTAssertFalse(status.isAvailable)
        XCTAssertEqual(status.title, "Missing")
    }

    func testProviderStatusUsesRuntimeWhenBundleIsReady() {
        let asset = GemmaModelAsset(
            fileName: "gemma-4-E4B-it.litertlm",
            fileSizeBytes: 3_654_467_584,
            expectedSizeBytes: 3_654_467_584
        )
        let status = GemmaE4BIntelligenceService.providerStatus(
            asset: asset,
            runtime: MockGemmaLocalRuntimeBridge(
                status: GemmaLocalRuntimeStatus(
                    canRunInference: false,
                    title: "Not linked",
                    detail: "Runtime is not linked."
                )
            )
        )

        XCTAssertFalse(status.isAvailable)
        XCTAssertEqual(status.title, "Not linked")
        XCTAssertEqual(status.detail, "Runtime is not linked.")
    }

    func testProviderStatusBecomesAvailableWhenBundleAndRuntimeAreReady() {
        let asset = GemmaModelAsset(
            fileName: "gemma-4-E4B-it.litertlm",
            fileSizeBytes: 3_654_467_584,
            expectedSizeBytes: 3_654_467_584
        )
        let status = GemmaE4BIntelligenceService.providerStatus(
            asset: asset,
            runtime: MockGemmaLocalRuntimeBridge(
                status: GemmaLocalRuntimeStatus(
                    canRunInference: true,
                    title: "Ready",
                    detail: "Gemma can run locally."
                )
            )
        )

        XCTAssertTrue(status.isAvailable)
        XCTAssertEqual(status.title, "Ready")
    }
}

private struct MockGemmaLocalRuntimeBridge: GemmaLocalRuntimeBridging {
    let status: GemmaLocalRuntimeStatus

    func refineQuickResult(
        base: QuickCheckResult,
        input: QuickCheckInput,
        contextState: DecisionContextPreparedState?,
        neuralState: DecisionNeuralState?,
        brainState: DecisionBrainState?
    ) async -> QuickCheckResult? {
        nil
    }

    func refineBalanceResult(
        base: BalanceBoardResult,
        input: BalanceBoardInput,
        contextState: DecisionContextPreparedState?,
        neuralState: DecisionNeuralState?,
        brainState: DecisionBrainState?
    ) async -> BalanceBoardResult? {
        nil
    }

    func refineMirrorResult(
        base: MirrorResult,
        input: MirrorInput,
        contextState: DecisionContextPreparedState?,
        neuralState: DecisionNeuralState?,
        brainState: DecisionBrainState?
    ) async -> MirrorResult? {
        nil
    }

    func pickReminder(
        from candidates: [ReminderSelectionCandidate],
        scenario: ScenarioType,
        prompt: String,
        mode: DecisionMode?
    ) async -> ReminderSelectionCandidate? {
        nil
    }
}
