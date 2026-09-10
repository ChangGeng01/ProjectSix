import Foundation

struct DecisionLocalModelLibraryAssetPresentation: Identifiable, Equatable, Sendable {
    let asset: GemmaModelAsset
    let isPreferred: Bool
    let isExplicitlySelected: Bool
    let canRemove: Bool
    let detail: String

    var id: String { asset.assetID }
}

struct DecisionLocalOpenModelAssetPresentation: Identifiable, Equatable, Sendable {
    let asset: OpenModelAsset
    let isPreferred: Bool
    let isExplicitlySelected: Bool
    let canRemove: Bool
    let detail: String

    var id: String { asset.assetID }
}

struct DecisionLocalModelLibraryPresentation: Equatable, Sendable {
    let title: String
    let supportedRuntimeHeadline: String
    let supportedRuntimeValue: String
    let supportedRuntimeDetail: String
    let openModelSlotTitle: String?
    let openModelSlotStableID: String?
    let openModelSlotDetail: String?
    let openModelRuntimeTitle: String?
    let openModelRuntimeDetail: String?
    let preferredGemmaAssetID: String?
    let preferredGemmaSelectionDetail: String?
    let gemmaAssets: [DecisionLocalModelLibraryAssetPresentation]
    let emptyGemmaLibraryMessage: String?
    let preferredOpenModelAssetID: String?
    let preferredOpenModelSelectionDetail: String?
    let openModelAssets: [DecisionLocalOpenModelAssetPresentation]
    let emptyOpenModelLibraryMessage: String?

    static func build(from snapshot: DecisionLocalModelLibrarySnapshot) -> DecisionLocalModelLibraryPresentation {
        let gemmaAssets = snapshot.allGemmaAssets.map { asset in
            DecisionLocalModelLibraryAssetPresentation(
                asset: asset,
                isPreferred: snapshot.preferredGemmaAsset?.assetID == asset.assetID,
                isExplicitlySelected: snapshot.preferredGemmaAssetID == asset.assetID,
                canRemove: asset.isImported,
                detail: gemmaAssetDetail(asset)
            )
        }

        let preferredGemmaSelectionDetail: String?
        if let preferredAsset = snapshot.preferredGemmaAsset {
            preferredGemmaSelectionDetail = "Gemma will currently use \(preferredAsset.sourceTitle.lowercased()) asset \(preferredAsset.fileName)."
        } else if snapshot.hasAnyGemmaAsset {
            preferredGemmaSelectionDetail = "Gemma asset selection is currently automatic."
        } else {
            preferredGemmaSelectionDetail = nil
        }

        let openModelAssets = snapshot.importedOpenModelAssets.map { asset in
            DecisionLocalOpenModelAssetPresentation(
                asset: asset,
                isPreferred: snapshot.preferredOpenModelAsset?.assetID == asset.assetID,
                isExplicitlySelected: snapshot.preferredOpenModelAssetID == asset.assetID,
                canRemove: asset.isImported,
                detail: openModelAssetDetail(asset)
            )
        }

        let preferredOpenModelSelectionDetail: String?
        if let preferredAsset = snapshot.preferredOpenModelAsset,
           let runtimeStatus = snapshot.openModelRuntimeStatus {
            preferredOpenModelSelectionDetail = "Open model runtime is currently pinned to imported asset \(preferredAsset.fileName) and running in \(runtimeStatus.title.lowercased()) mode."
        } else if snapshot.hasAnyOpenModelAsset {
            preferredOpenModelSelectionDetail = "Open-model asset selection is currently automatic."
        } else {
            preferredOpenModelSelectionDetail = nil
        }

        let waitingRuntimeTitle =
            snapshot.openModelSlot != nil && snapshot.openModelRuntimeStatus == nil
            ? "Waiting for import"
            : nil
        let waitingRuntimeDetail =
            snapshot.openModelSlot != nil && snapshot.openModelRuntimeStatus == nil
            ? "The generic open-model slot is reserved but not active yet. Import or download a GGUF, ONNX, SafeTensors, LiteRTLM, or BIN asset to light up the local runtime path."
            : nil

        return DecisionLocalModelLibraryPresentation(
            title: "Local model library",
            supportedRuntimeHeadline: snapshot.supportedRuntimeHeadline,
            supportedRuntimeValue: "Gemma 4 E4B (.litertlm)",
            supportedRuntimeDetail: snapshot.supportedRuntimeDetail,
            openModelSlotTitle: snapshot.openModelSlot?.title,
            openModelSlotStableID: snapshot.openModelSlot?.stableID,
            openModelSlotDetail: snapshot.openModelSlot?.detail,
            openModelRuntimeTitle: snapshot.openModelRuntimeStatus?.title ?? waitingRuntimeTitle,
            openModelRuntimeDetail: snapshot.openModelRuntimeStatus.map { status in
                let assetLine = snapshot.openModelRuntimeAssetFileName.map { "\($0) • " } ?? ""
                return "\(assetLine)\(status.detail)"
            } ?? waitingRuntimeDetail,
            preferredGemmaAssetID: snapshot.preferredGemmaAssetID,
            preferredGemmaSelectionDetail: preferredGemmaSelectionDetail,
            gemmaAssets: gemmaAssets,
            emptyGemmaLibraryMessage: snapshot.hasAnyGemmaAsset ? nil : "No local Gemma asset is available yet.",
            preferredOpenModelAssetID: snapshot.preferredOpenModelAssetID,
            preferredOpenModelSelectionDetail: preferredOpenModelSelectionDetail,
            openModelAssets: openModelAssets,
            emptyOpenModelLibraryMessage: snapshot.hasAnyOpenModelAsset ? nil : "No imported open-model asset is available yet."
        )
    }

    private static func gemmaAssetDetail(_ asset: GemmaModelAsset) -> String {
        let expected = asset.expectedDisplaySize.map { " of \($0)" } ?? ""
        let progress = asset.progressDescription.map { " (\($0))" } ?? ""
        let readiness = asset.isComplete ? "ready" : "incomplete"
        return "\(asset.displaySize)\(expected)\(progress) • \(readiness)"
    }

    private static func openModelAssetDetail(_ asset: OpenModelAsset) -> String {
        let runtimeStatus = OpenModelLocalRuntimeBridge.shared.status(for: asset)
        let slotState = runtimeStatus.mode == .dedicatedRuntime ? "dedicated runtime" : "heuristic preview bridge"
        return "\(asset.displaySize) • \(asset.fileExtension.uppercased()) • \(slotState)"
    }
}
