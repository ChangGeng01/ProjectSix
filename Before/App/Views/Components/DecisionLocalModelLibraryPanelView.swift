import SwiftUI

struct DecisionLocalModelLibraryPanelView: View {
    let presentation: DecisionLocalModelLibraryPresentation
    let showsTitle: Bool
    let preferredGemmaAssetID: Binding<String?>?
    let preferredOpenModelAssetID: Binding<String?>?
    let importButtonTitle: String?
    let downloadButtonTitle: String?
    let importOpenModelButtonTitle: String?
    let downloadOpenModelButtonTitle: String?
    let onImportGemma: (() -> Void)?
    let onDownloadGemma: (() -> Void)?
    let onImportOpenModel: (() -> Void)?
    let onDownloadOpenModel: (() -> Void)?
    let onRemoveImportedGemma: ((GemmaModelAsset) -> Void)?
    let onRemoveImportedOpenModel: ((OpenModelAsset) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if showsTitle {
                Text(presentation.title)
                    .font(.subheadline.weight(.semibold))
            }

            Text(presentation.supportedRuntimeDetail)
                .font(.footnote)
                .foregroundStyle(.secondary)

            LabeledContent(
                presentation.supportedRuntimeHeadline,
                value: presentation.supportedRuntimeValue
            )

            if let openModelSlotTitle = presentation.openModelSlotTitle {
                VStack(alignment: .leading, spacing: 4) {
                    LabeledContent("Open-model slot", value: openModelSlotTitle)

                    if let stableID = presentation.openModelSlotStableID {
                        Text(stableID)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    if let detail = presentation.openModelSlotDetail {
                        Text(detail)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if let openModelRuntimeTitle = presentation.openModelRuntimeTitle {
                VStack(alignment: .leading, spacing: 4) {
                    LabeledContent("Open-model runtime", value: openModelRuntimeTitle)

                    if let detail = presentation.openModelRuntimeDetail {
                        Text(detail)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if let preferredOpenModelAssetID {
                Picker("Preferred open-model asset", selection: preferredOpenModelAssetID) {
                    Text("Automatic").tag(String?.none)
                    ForEach(presentation.openModelAssets) { asset in
                        Text("\(asset.asset.fileName) • \(asset.asset.sourceTitle)")
                            .tag(Optional(asset.asset.assetID))
                    }
                }
            }

            if let preferredDetail = presentation.preferredOpenModelSelectionDetail {
                Text(preferredDetail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if let emptyMessage = presentation.emptyOpenModelLibraryMessage {
                Text(emptyMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(presentation.openModelAssets) { asset in
                    openModelAssetRow(asset)
                }
            }

            if let onImportOpenModel, let importOpenModelButtonTitle {
                Button(importOpenModelButtonTitle, action: onImportOpenModel)
            }

            if let onDownloadOpenModel, let downloadOpenModelButtonTitle {
                Button(downloadOpenModelButtonTitle, action: onDownloadOpenModel)
            }

            if let preferredGemmaAssetID {
                Picker("Preferred Gemma asset", selection: preferredGemmaAssetID) {
                    Text("Automatic").tag(String?.none)
                    ForEach(presentation.gemmaAssets) { asset in
                        Text("\(asset.asset.fileName) • \(asset.asset.sourceTitle)")
                            .tag(Optional(asset.asset.assetID))
                    }
                }
            }

            if let preferredDetail = presentation.preferredGemmaSelectionDetail {
                Text(preferredDetail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if let emptyMessage = presentation.emptyGemmaLibraryMessage {
                Text(emptyMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(presentation.gemmaAssets) { asset in
                    assetRow(asset)
                }
            }

            if let onImportGemma, let importButtonTitle {
                Button(importButtonTitle, action: onImportGemma)
            }

            if let onDownloadGemma, let downloadButtonTitle {
                Button(downloadButtonTitle, action: onDownloadGemma)
            }
        }
    }

    @ViewBuilder
    private func assetRow(_ asset: DecisionLocalModelLibraryAssetPresentation) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(asset.asset.fileName)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)

                Text(asset.asset.sourceTitle)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(asset.asset.isImported ? .blue : .secondary)

                if asset.isExplicitlySelected {
                    Text("Selected")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.green)
                } else if asset.isPreferred {
                    Text("Automatic")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if asset.canRemove, let onRemoveImportedGemma {
                    Button("Remove", role: .destructive) {
                        onRemoveImportedGemma(asset.asset)
                    }
                    .font(.caption.weight(.semibold))
                }
            }

            Text(asset.detail)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private func openModelAssetRow(_ asset: DecisionLocalOpenModelAssetPresentation) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(asset.asset.fileName)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)

                Text(asset.asset.sourceTitle)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.blue)

                if asset.isExplicitlySelected {
                    Text("Selected")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.green)
                } else if asset.isPreferred {
                    Text("Automatic")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if asset.canRemove, let onRemoveImportedOpenModel {
                    Button("Remove", role: .destructive) {
                        onRemoveImportedOpenModel(asset.asset)
                    }
                    .font(.caption.weight(.semibold))
                }
            }

            Text(asset.detail)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}
