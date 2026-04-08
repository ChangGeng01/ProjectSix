import SwiftUI

struct SharedLifeItemDetailView: View {
    @EnvironmentObject private var appModel: BeforeAppModel
    @EnvironmentObject private var sharedLife: SharedLifeStore
    @Environment(\.dismiss) private var dismiss

    let item: SharedLifeBoxItem

    var body: some View {
        NavigationStack {
            ZStack {
                BeforeBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        SectionHeader(
                            eyebrow: item.mode?.title ?? "Shared Life",
                            title: item.title,
                            subtitle: item.detail
                        )

                        statusCard

                        if !trimmed(item.prompt).isEmpty {
                            PanelCard {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Question")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(BeforeTheme.ember)
                                    Text(item.prompt)
                                        .font(.headline)
                                        .foregroundStyle(BeforeTheme.ink)
                                }
                            }
                        }

                        if let draft = item.draft {
                            PanelCard {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Captured context")
                                        .font(.headline)
                                        .foregroundStyle(BeforeTheme.ink)
                                    draftRows(for: draft)
                                }
                            }
                        }

                        if item.canReopen {
                            DecisionContinuationActions(
                                reopenTitle: "Reopen this decision",
                                reopenStyle: .secondary,
                                postponeTitle: "Move to Tomorrow Box",
                                postponeStyle: .secondary,
                                reopenAction: {
                                    appModel.reopenSharedLifeItem(item)
                                    dismiss()
                                },
                                postponeAction: {
                                    appModel.moveSharedLifeItemToTomorrow(item)
                                    dismiss()
                                }
                            )
                        }

                        VStack(spacing: 12) {
                            if item.status != .reviewing {
                                BeforeActionButton("Mark reviewing", style: .secondary) {
                                    sharedLife.markReviewing(item.id)
                                    dismiss()
                                }
                            }

                            HStack(spacing: 12) {
                                if item.status != .approved {
                                    BeforeActionButton("Approve", style: .secondary) {
                                        sharedLife.approve(item.id)
                                        dismiss()
                                    }
                                }

                                BeforeActionButton("Defer", style: .secondary) {
                                    sharedLife.deferItem(item.id)
                                    dismiss()
                                }
                            }

                            BeforeActionButton("Drop", style: .secondary) {
                                sharedLife.drop(item.id)
                                dismiss()
                            }

                            if item.isSeeded == false {
                                BeforeActionButton("Remove item", style: .tertiary) {
                                    sharedLife.removeItem(item.id)
                                    dismiss()
                                }
                            }
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Shared Detail")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private var statusCard: some View {
        PanelCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(item.status.title)
                        .font(.headline)
                        .foregroundStyle(statusColor)
                    Spacer()
                    if let mode = item.mode {
                        Text(mode.title)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }

                Text(item.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text("Updated \(item.updatedAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func draftRows(for draft: TomorrowBoxDraft) -> some View {
        switch item.mode {
        case .quick:
            if let scenario = draft.scenarioRaw.flatMap(ScenarioType.init(rawValue:)) {
                detailPair("Scenario", scenario.title)
            }
            detailPair("Note", draft.prompt)
        case .balance:
            detailPair("Want", draft.desire ?? "")
            detailPair("Concern", draft.concern ?? "")
            detailPair("Reality", draft.constraint ?? "")
            detailPair("Long-term", draft.longTerm ?? "")
        case .mirror:
            detailPair("Emotion", draft.emotion ?? "")
            detailPair("Relationship", draft.relationship ?? "")
            detailPair("Reality", draft.reality ?? "")
            detailPair("Long-term", draft.longTerm ?? "")
            detailPair("Self", draft.selfLens ?? "")
        case .none:
            EmptyView()
        }
    }

    @ViewBuilder
    private func detailPair(_ title: String, _ value: String) -> some View {
        if !trimmed(value).isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(BeforeTheme.ember)
                Text(value)
                    .font(.subheadline)
                    .foregroundStyle(BeforeTheme.ink)
            }
        }
    }

    private var statusColor: Color {
        switch item.status {
        case .pending:
            BeforeTheme.ember
        case .reviewing:
            BeforeTheme.moss
        case .approved:
            BeforeTheme.ink
        case .deferred:
            BeforeTheme.ink
        case .dropped:
            .secondary
        }
    }

    private func trimmed(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
