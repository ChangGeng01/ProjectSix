import SwiftUI

struct DecisionSessionEngineImportPreviewSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appModel: BeforeAppModel

    let draft: DecisionSessionEnginePendingImportDraft
    let onImported: (DecisionSession) -> Void

    @State private var isImporting = false

    private var presentation: DecisionSessionEngineImportPreviewPresentation {
        DecisionSessionEngineImportPreviewPresentation.build(
            from: preview,
            sourceFileName: draft.sourceFileName
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                PanelCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(presentation.title)
                            .font(.title3.bold())
                            .foregroundStyle(BeforeTheme.ink)

                        Text(presentation.headline)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        DecisionSessionEngineImportPreviewDigestView(presentation: presentation)
                    }
                }

                if presentation.branchPresentations.isEmpty == false {
                    PanelCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Exported branches")
                                .font(.headline)

                            ForEach(presentation.branchPresentations) { branch in
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                                        Text(branch.name)
                                            .font(.subheadline.weight(.semibold))
                                        if branch.isHead {
                                            Text("Head")
                                                .font(.caption2.weight(.bold))
                                                .foregroundStyle(BeforeTheme.ember)
                                        }
                                    }

                                    Text(branch.statusLine)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)

                                    Text(branch.detailLine)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 2)
                            }
                        }
                    }
                }

                VStack(spacing: 12) {
                    BeforeActionButton("Import as paused session", style: .primary) {
                        Task { await importBundle() }
                    }
                    .disabled(isImporting)

                    BeforeActionButton("Cancel", style: .tertiary) {
                        appModel.clearPendingSessionEngineImportDraft()
                        dismiss()
                    }
                    .disabled(isImporting)
                }
            }
            .padding(20)
        }
        .navigationTitle("Bundle Preview")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if isImporting {
                    ProgressView()
                        .controlSize(.small)
                }
            }
        }
    }

    private func importBundle() async {
        isImporting = true
        let importedSession = await appModel.importStagedSessionEngineBundle()
        isImporting = false
        guard let importedSession else { return }
        dismiss()
        onImported(importedSession)
    }
}

private extension DecisionSessionEngineImportPreviewSheetView {
    var preview: DecisionSessionImportBundlePreview { draft.preview }
}

struct DecisionSessionEngineImportPreviewDigestView: View {
    let presentation: DecisionSessionEngineImportPreviewPresentation
    let showsSourceLine: Bool
    let showsIntegrityLine: Bool

    init(
        presentation: DecisionSessionEngineImportPreviewPresentation,
        showsSourceLine: Bool = true,
        showsIntegrityLine: Bool = true
    ) {
        self.presentation = presentation
        self.showsSourceLine = showsSourceLine
        self.showsIntegrityLine = showsIntegrityLine
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(presentation.importedLine)
                .font(.caption)
                .foregroundStyle(BeforeTheme.ember)

            Text(presentation.bundleLine)
                .font(.caption2)
                .foregroundStyle(.secondary)

            if showsSourceLine {
                Text(presentation.sourceLine)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Text(presentation.countsLine)
                .font(.caption2)
                .foregroundStyle(.secondary)

            if showsIntegrityLine {
                Text(presentation.integrityLine)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            DecisionSessionEngineHealthSummaryView(
                summary: presentation.unfinishedWorkSummary
            )

            DecisionSessionEngineReviewDetailListView(
                rows: presentation.detailRows.filter {
                    switch $0.id {
                    case "checkpoint", "branch":
                        return true
                    default:
                        return false
                    }
                }
            )
        }
    }
}
