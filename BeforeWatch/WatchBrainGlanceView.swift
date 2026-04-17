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
            let presentation = evolution.surfacePresentation

            VStack(alignment: .leading, spacing: style == .expanded ? 8 : 6) {
                HStack(spacing: 6) {
                    ForEach(Array(presentation.statusBadges.enumerated()), id: \.offset) { _, badge in
                        statusBadge(
                            badge.title,
                            tint: badgeTint(badge.tone)
                        )
                    }
                }

                Text(presentation.headline)
                    .font(style == .expanded ? .footnote.weight(.semibold) : .caption.weight(.semibold))
                    .lineLimit(style == .expanded ? 3 : 2)

                if style == .expanded, let detail = presentation.detail {
                    Text(detail)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }

                Text(presentation.compactStatusLine)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(style == .expanded ? 3 : 2)

                if let activeSource = presentation.activeSourceTitle {
                    Text(activeSource)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.orange)
                }

                if let controlEntry = presentation.controlEntry {
                    Text(controlEntry.instruction)
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Button(controlEntry.title) {
                        WatchHandoffCoordinator.enqueueOpenEvolutionControl(
                            headline: controlEntry.prompt,
                            reason: presentation.detail
                        )
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
    }

    private func badgeTint(_ tone: DecisionEvolutionWidgetStatusBadgeTone) -> Color {
        switch tone {
        case .green:
            .green
        case .red:
            .red
        case .orange:
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
