import Foundation

enum GemmaE4BIntelligenceService {
    static var availabilityStatus: DecisionModelProviderStatus {
        if let asset = bundledModel {
            return DecisionModelProviderStatus(
                kind: .gemmaE4B,
                isAvailable: false,
                title: "Bundle detected",
                detail: "Found \(asset.fileName) (\(asset.displaySize)) in the app bundle, but the LiteRT-LM iOS runtime is not linked into this build yet."
            )
        }

        return DecisionModelProviderStatus(
            kind: .gemmaE4B,
            isAvailable: false,
            title: "Unavailable",
            detail: "No bundled Gemma model was found. Add a .litertlm file under Before/Resources/Models to prepare this build for Gemma."
        )
    }

    static var bundledModel: GemmaModelAsset? {
        GemmaModelAssetCatalog.preferredAsset()
    }

    static func refineQuickResult(
        base: QuickCheckResult,
        input: QuickCheckInput
    ) async -> QuickCheckResult? {
        nil
    }

    static func refineBalanceResult(
        base: BalanceBoardResult,
        input: BalanceBoardInput
    ) async -> BalanceBoardResult? {
        nil
    }

    static func refineMirrorResult(
        base: MirrorResult,
        input: MirrorInput
    ) async -> MirrorResult? {
        nil
    }
}
