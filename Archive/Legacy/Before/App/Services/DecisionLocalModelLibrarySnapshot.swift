import Foundation

struct DecisionLocalModelRuntimeSlotSummary: Equatable, Sendable {
    let title: String
    let stableID: String?
    let detail: String
}

struct DecisionLocalOpenModelAssetSummary: Equatable, Sendable {
    let asset: OpenModelAsset
    let isPreferred: Bool
    let isExplicitlySelected: Bool
}

struct DecisionLocalModelLibrarySnapshot: Equatable, Sendable {
    let preferredProvider: DecisionModelProviderPreference
    let preferredGemmaAssetID: String?
    let preferredGemmaAsset: GemmaModelAsset?
    let importedGemmaAssets: [GemmaModelAsset]
    let bundledGemmaAsset: GemmaModelAsset?
    let preferredOpenModelAssetID: String?
    let preferredOpenModelAsset: OpenModelAsset?
    let importedOpenModelAssets: [OpenModelAsset]
    let openModelSlot: DecisionLocalModelRuntimeSlotSummary?
    let openModelRuntimeAssetFileName: String?
    let openModelRuntimeStatus: OpenModelLocalRuntimeStatus?

    var allGemmaAssets: [GemmaModelAsset] {
        importedGemmaAssets + (bundledGemmaAsset.map { [$0] } ?? [])
    }

    var hasAnyGemmaAsset: Bool {
        !allGemmaAssets.isEmpty
    }

    var hasAnyOpenModelAsset: Bool {
        !importedOpenModelAssets.isEmpty
    }

    var supportedRuntimeHeadline: String {
        "Current downloadable runtime"
    }

    var supportedRuntimeDetail: String {
        "Gemma 4 E4B (`.litertlm`) is the currently managed local-model format. The open-model slot stays visible here so future local runtimes can land in the same library surface."
    }

    static func current(
        preferredProvider: DecisionModelProviderPreference,
        preferredGemmaAssetID: String?,
        preferredGemmaAsset: GemmaModelAsset?,
        importedGemmaAssets: [GemmaModelAsset],
        bundledGemmaAsset: GemmaModelAsset?,
        preferredOpenModelAssetID: String?,
        preferredOpenModelAsset: OpenModelAsset?,
        importedOpenModelAssets: [OpenModelAsset],
        openModelDescriptor: DecisionModelProviderDescriptor?
    ) -> DecisionLocalModelLibrarySnapshot {
        let openModelRuntimeAsset = preferredOpenModelAsset ?? importedOpenModelAssets.first
        return DecisionLocalModelLibrarySnapshot(
            preferredProvider: preferredProvider,
            preferredGemmaAssetID: preferredGemmaAssetID,
            preferredGemmaAsset: preferredGemmaAsset,
            importedGemmaAssets: importedGemmaAssets,
            bundledGemmaAsset: bundledGemmaAsset,
            preferredOpenModelAssetID: preferredOpenModelAssetID,
            preferredOpenModelAsset: preferredOpenModelAsset,
            importedOpenModelAssets: importedOpenModelAssets,
            openModelSlot: openModelDescriptor.map {
                DecisionLocalModelRuntimeSlotSummary(
                    title: $0.title,
                    stableID: $0.openModel?.stableID,
                    detail: $0.detail
                )
            },
            openModelRuntimeAssetFileName: openModelRuntimeAsset?.fileName,
            openModelRuntimeStatus: openModelRuntimeAsset.map {
                OpenModelLocalRuntimeBridge.shared.status(for: $0)
            }
        )
    }
}
