import Foundation

struct GemmaModelBundleStatus: Equatable, Sendable {
    let isReady: Bool
    let title: String
    let detail: String
}

enum GemmaE4BIntelligenceService {
    static var availabilityStatus: DecisionModelProviderStatus {
        providerStatus()
    }

    static var modelBundleStatus: GemmaModelBundleStatus {
        bundleStatus()
    }

    static var localRuntimeStatus: GemmaLocalRuntimeStatus {
        runtimeStatus()
    }

    static var bundledModel: GemmaModelAsset? {
        GemmaModelAssetCatalog.preferredAsset()
    }

    static func backendResolution(
        policy: InferenceBackendPolicy = DecisionTestingInterface.effectiveInferenceBackendPolicy(),
        device: DeviceCapabilitySnapshot = .current
    ) -> InferenceBackendResolution {
        InferenceBackendResolver.resolve(policy: policy, device: device)
    }

    static func bundleStatus(asset: GemmaModelAsset? = bundledModel) -> GemmaModelBundleStatus {
        guard let asset else {
            return GemmaModelBundleStatus(
                isReady: false,
                title: "Missing",
                detail: "No bundled Gemma model was found. Add a .litertlm file under Before/Resources/Models to prepare this build for Gemma."
            )
        }

        guard asset.isComplete else {
            let expected = asset.expectedDisplaySize.map { " of \($0)" } ?? ""
            let progress = asset.progressDescription.map { " (\($0))" } ?? ""
            return GemmaModelBundleStatus(
                isReady: false,
                title: "Incomplete",
                detail: "Found \(asset.fileName) at \(asset.displaySize)\(expected)\(progress), but the model asset is still downloading or incomplete."
            )
        }

        return GemmaModelBundleStatus(
            isReady: true,
            title: "Ready",
            detail: "Found \(asset.fileName) (\(asset.displaySize)) in the app bundle. The model file is complete and ready for a local runtime bridge."
        )
    }

    static func runtimeStatus(
        runtime: any GemmaLocalRuntimeBridging = GemmaLocalRuntimeBridge.shared
    ) -> GemmaLocalRuntimeStatus {
        runtime.status
    }

    static func providerStatus(
        asset: GemmaModelAsset? = bundledModel,
        runtime: any GemmaLocalRuntimeBridging = GemmaLocalRuntimeBridge.shared
    ) -> DecisionModelProviderStatus {
        let bundleStatus = bundleStatus(asset: asset)

        guard bundleStatus.isReady else {
            return DecisionModelProviderStatus(
                kind: .gemmaE4B,
                isAvailable: false,
                title: bundleStatus.title,
                detail: bundleStatus.detail
            )
        }

        let runtimeStatus = runtimeStatus(runtime: runtime)
        return DecisionModelProviderStatus(
            kind: .gemmaE4B,
            isAvailable: runtimeStatus.canRunInference,
            title: runtimeStatus.title,
            detail: runtimeStatus.detail
        )
    }

    static func refineQuickResult(
        base: QuickCheckResult,
        input: QuickCheckInput,
        contextState: DecisionContextPreparedState? = nil,
        neuralState: DecisionNeuralState? = nil,
        brainState: DecisionBrainState? = nil,
        backendPolicy: InferenceBackendPolicy = DecisionTestingInterface.effectiveInferenceBackendPolicy(),
        runtime: any GemmaLocalRuntimeBridging = GemmaLocalRuntimeBridge.shared
    ) async -> QuickCheckResult? {
        guard bundleStatus().isReady else { return nil }
        _ = backendResolution(policy: backendPolicy)
        return await runtime.refineQuickResult(
            base: base,
            input: input,
            contextState: contextState,
            neuralState: neuralState,
            brainState: brainState
        )
    }

    static func refineBalanceResult(
        base: BalanceBoardResult,
        input: BalanceBoardInput,
        contextState: DecisionContextPreparedState? = nil,
        neuralState: DecisionNeuralState? = nil,
        brainState: DecisionBrainState? = nil,
        backendPolicy: InferenceBackendPolicy = DecisionTestingInterface.effectiveInferenceBackendPolicy(),
        runtime: any GemmaLocalRuntimeBridging = GemmaLocalRuntimeBridge.shared
    ) async -> BalanceBoardResult? {
        guard bundleStatus().isReady else { return nil }
        _ = backendResolution(policy: backendPolicy)
        return await runtime.refineBalanceResult(
            base: base,
            input: input,
            contextState: contextState,
            neuralState: neuralState,
            brainState: brainState
        )
    }

    static func refineMirrorResult(
        base: MirrorResult,
        input: MirrorInput,
        contextState: DecisionContextPreparedState? = nil,
        neuralState: DecisionNeuralState? = nil,
        brainState: DecisionBrainState? = nil,
        backendPolicy: InferenceBackendPolicy = DecisionTestingInterface.effectiveInferenceBackendPolicy(),
        runtime: any GemmaLocalRuntimeBridging = GemmaLocalRuntimeBridge.shared
    ) async -> MirrorResult? {
        guard bundleStatus().isReady else { return nil }
        _ = backendResolution(policy: backendPolicy)
        return await runtime.refineMirrorResult(
            base: base,
            input: input,
            contextState: contextState,
            neuralState: neuralState,
            brainState: brainState
        )
    }

    static func pickReminder(
        from candidates: [ReminderSelectionCandidate],
        scenario: ScenarioType,
        prompt: String,
        mode: DecisionMode?,
        backendPolicy: InferenceBackendPolicy = DecisionTestingInterface.effectiveInferenceBackendPolicy(),
        runtime: any GemmaLocalRuntimeBridging = GemmaLocalRuntimeBridge.shared
    ) async -> ReminderSelectionCandidate? {
        guard bundleStatus().isReady else { return nil }
        _ = backendResolution(policy: backendPolicy)
        return await runtime.pickReminder(
            from: candidates,
            scenario: scenario,
            prompt: prompt,
            mode: mode
        )
    }
}
