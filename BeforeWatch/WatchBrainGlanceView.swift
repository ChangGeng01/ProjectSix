import SwiftUI

struct WatchBrainGlanceView: View {
    private var snapshot: WidgetSnapshot {
        WidgetSnapshotStore.load()
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 10) {
                Text("Brain Glance")
                    .font(.headline)
                Text(snapshot.messageHeadline)
                    .font(.subheadline.bold())
                Text(snapshot.messageBody)
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                if snapshot.evolution != nil {
                    Divider()
                    WatchEvolutionStatusSection(
                        snapshot: snapshot,
                        style: .expanded
                    )
                }

                Text("Updated \(snapshot.updatedAt.formatted(date: .omitted, time: .shortened))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .navigationTitle("Glance")
        }
    }
}

enum WatchEvolutionStatusDisplayStyle {
    case compact
    case expanded
}

struct WatchEvolutionStatusSection: View {
    private let snapshot: WidgetSnapshot
    private let style: WatchEvolutionStatusDisplayStyle

    init(
        snapshot: WidgetSnapshot = WidgetSnapshotStore.load(),
        style: WatchEvolutionStatusDisplayStyle = .compact
    ) {
        self.snapshot = snapshot
        self.style = style
    }

    private var evolution: WidgetEvolutionSnapshot? {
        snapshot.evolution
    }

    var body: some View {
        if let evolution {
            VStack(alignment: .leading, spacing: style == .expanded ? 8 : 6) {
                HStack(spacing: 6) {
                    statusBadge(
                        evolution.releaseStateTitle,
                        tint: releaseTint(evolution.releaseStateID)
                    )

                    if evolution.pendingReviewCount > 0 {
                        statusBadge("P\(evolution.pendingReviewCount)", tint: .orange)
                    }

                    if evolution.rollbackReadyCount > 0 {
                        statusBadge("R\(evolution.rollbackReadyCount)", tint: .green)
                    }

                    if evolution.activeKillSwitchCount > 0 {
                        statusBadge("K\(evolution.activeKillSwitchCount)", tint: .red)
                    }
                }

                Text(evolution.displayHeadline)
                    .font(style == .expanded ? .footnote.weight(.semibold) : .caption.weight(.semibold))
                    .lineLimit(style == .expanded ? 3 : 2)

                if style == .expanded, let detail = evolution.displayDetail {
                    Text(detail)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }

                Text(evolution.compactStatusLine)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(style == .expanded ? 3 : 2)

                if let activeSource = evolution.activeCheckpointSourceTitle,
                   evolution.hasActiveCheckpoint {
                    Text(activeSource)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.orange)
                }

                if evolution.surfacesAttention {
                    Text(evolution.attentionInstruction)
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Button(evolution.controlEntryTitle) {
                        WatchHandoffCoordinator.enqueueOpenEvolutionControl(
                            headline: evolution.controlEntryPrompt,
                            reason: evolution.displayDetail
                        )
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
    }

    private func releaseTint(_ releaseStateID: String?) -> Color {
        switch releaseStateID {
        case "ready":
            .green
        case "blocked":
            .red
        default:
            .orange
        }
    }

    @ViewBuilder
    private func statusBadge(_ title: String, tint: Color) -> some View {
        Text(title)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .foregroundStyle(tint)
            .background(
                Capsule()
                    .fill(tint.opacity(0.16))
            )
    }
}
