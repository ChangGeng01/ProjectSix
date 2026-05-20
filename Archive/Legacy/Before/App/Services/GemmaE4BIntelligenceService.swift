import Foundation

struct GemmaModelBundleStatus: Equatable, Sendable {
    let isReady: Bool
    let title: String
    let detail: String
}

enum GemmaE4BIntelligenceService {
    private static var storedPreferredAssetID: String? {
        BeforePreferencesStore.load().preferredGemmaAssetID
    }

    static var availabilityStatus: DecisionModelProviderStatus {
        providerStatus()
    }

    static var modelBundleStatus: GemmaModelBundleStatus {
        bundleStatus()
    }

    static var localRuntimeStatus: GemmaLocalRuntimeStatus {
        runtimeStatus()
    }

    static var preferredModel: GemmaModelAsset? {
        preferredModel(preferredAssetID: storedPreferredAssetID)
    }

    static var bundledModel: GemmaModelAsset? {
        GemmaModelAssetCatalog.bundledAssets().first
    }

    static var importedModels: [GemmaModelAsset] {
        GemmaModelAssetCatalog.importedAssets()
    }

    static func preferredModel(preferredAssetID: String?) -> GemmaModelAsset? {
        GemmaModelAssetCatalog.preferredAsset(preferredAssetID: preferredAssetID)
    }

    static func backendResolution(
        policy: InferenceBackendPolicy = DecisionTestingInterface.effectiveInferenceBackendPolicy(),
        device: DeviceCapabilitySnapshot = .current
    ) -> InferenceBackendResolution {
        InferenceBackendResolver.resolve(policy: policy, device: device)
    }

    static func bundleStatus(asset: GemmaModelAsset? = preferredModel) -> GemmaModelBundleStatus {
        guard let asset else {
            return GemmaModelBundleStatus(
                isReady: false,
                title: "Missing",
                detail: "No local Gemma model was found. Import a previously-downloaded .litertlm file or bundle one under Before/Resources/Models."
            )
        }

        guard asset.isComplete else {
            let expected = asset.expectedDisplaySize.map { " of \($0)" } ?? ""
            let progress = asset.progressDescription.map { " (\($0))" } ?? ""
            return GemmaModelBundleStatus(
                isReady: false,
                title: "Incomplete",
                detail: "Found \(asset.sourceTitle.lowercased()) model \(asset.fileName) at \(asset.displaySize)\(expected)\(progress), but the asset is still downloading or incomplete."
            )
        }

        return GemmaModelBundleStatus(
            isReady: true,
            title: "Ready",
            detail: "Using \(asset.sourceTitle.lowercased()) model \(asset.fileName) (\(asset.displaySize)). The model file is complete and ready for the local Gemma runtime."
        )
    }

    static func runtimeStatus(
        runtime: any GemmaLocalRuntimeBridging = GemmaLocalRuntimeBridge.shared
    ) -> GemmaLocalRuntimeStatus {
        runtime.status
    }

    static func providerStatus(
        asset: GemmaModelAsset? = preferredModel,
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
        strategy: DecisionAdaptiveTaskStrategy? = nil,
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
            strategy: strategy,
            contextState: contextState,
            neuralState: neuralState,
            brainState: brainState
        )
    }

    static func refineBalanceResult(
        base: BalanceBoardResult,
        input: BalanceBoardInput,
        strategy: DecisionAdaptiveTaskStrategy? = nil,
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
            strategy: strategy,
            contextState: contextState,
            neuralState: neuralState,
            brainState: brainState
        )
    }

    static func refineMirrorResult(
        base: MirrorResult,
        input: MirrorInput,
        strategy: DecisionAdaptiveTaskStrategy? = nil,
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
            strategy: strategy,
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
        strategy: DecisionAdaptiveTaskStrategy? = nil,
        backendPolicy: InferenceBackendPolicy = DecisionTestingInterface.effectiveInferenceBackendPolicy(),
        runtime: any GemmaLocalRuntimeBridging = GemmaLocalRuntimeBridge.shared
    ) async -> ReminderSelectionCandidate? {
        guard bundleStatus().isReady else { return nil }
        _ = backendResolution(policy: backendPolicy)
        return await runtime.pickReminder(
            from: candidates,
            scenario: scenario,
            prompt: prompt,
            mode: mode,
            strategy: strategy
        )
    }
}
