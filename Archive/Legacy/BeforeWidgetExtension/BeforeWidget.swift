import AppIntents
import SwiftUI
import WidgetKit

struct BeforeWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

struct BeforeWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> BeforeWidgetEntry {
        BeforeWidgetEntry(date: .now, snapshot: .empty)
    }

    func getSnapshot(in context: Context, completion: @escaping (BeforeWidgetEntry) -> Void) {
        completion(BeforeWidgetEntry(date: .now, snapshot: WidgetSnapshotStore.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<BeforeWidgetEntry>) -> Void) {
        let entry = BeforeWidgetEntry(date: .now, snapshot: WidgetSnapshotStore.load())
        completion(
            Timeline(
                entries: [entry],
                policy: .after(.now.addingTimeInterval(BeforePolicy.Widget.timelineRefreshInterval))
            )
        )
    }
}

struct BeforeWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: BeforeWidgetEntry

    var body: some View {
        switch family {
        case .systemMedium:
            medium
        case .accessoryRectangular:
            lockScreen
        case .accessoryCircular:
            circular
        default:
            small
        }
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Before")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.7))

            if let controlEntry = entry.snapshot.evolution?.surfacePresentation.controlEntry {
                widgetIntentButton(
                    title: controlEntry.title,
                    systemImage: controlEntry.systemImage,
                    intent: OpenEvolutionControlIntent(
                        entrySource: .homeWidgetSmall,
                        controlEntry: controlEntry
                    )
                )
            }

            Spacer()
            widgetIntentButton(
                title: "Worth it?",
                systemImage: "bolt.circle",
                prominent: true,
                intent: OpenDecisionModeIntent(mode: .quick, entrySource: .homeWidgetSmall)
            )
        }
        .padding()
        .containerBackground(for: .widget) {
            LinearGradient(
                colors: [BeforeTheme.ink, BeforeTheme.ember.opacity(0.85)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var medium: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Before")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.7))
                Text(entry.snapshot.messageHeadline)
                    .font(.headline)
                    .foregroundStyle(.white)
                if let verdict = entry.snapshot.latestVerdict {
                    Text(verdict.title.uppercased())
                        .font(.caption2.weight(.bold))
                        .tracking(1.0)
                        .foregroundStyle(.white.opacity(0.7))
                }
                Text(entry.snapshot.messageBody)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.82))
                    .lineLimit(3)

                if let presentation = entry.snapshot.evolution?.surfacePresentation,
                   presentation.controlEntry != nil {
                    Text(presentation.compactStatusLine)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.72))
                        .lineLimit(2)
                }
            }

            HStack(spacing: 8) {
                widgetIntentButton(
                    title: "Quick",
                    systemImage: DecisionMode.quick.symbolName,
                    intent: OpenDecisionModeIntent(mode: .quick, entrySource: .homeWidgetMedium)
                )
                widgetIntentButton(
                    title: "Balance",
                    systemImage: DecisionMode.balance.symbolName,
                    intent: OpenDecisionModeIntent(mode: .balance, entrySource: .homeWidgetMedium)
                )
                widgetIntentButton(
                    title: "Mirror",
                    systemImage: DecisionMode.mirror.symbolName,
                    intent: OpenDecisionModeIntent(mode: .mirror, entrySource: .homeWidgetMedium)
                )
            }

            if let controlEntry = entry.snapshot.evolution?.surfacePresentation.controlEntry {
                widgetIntentButton(
                    title: controlEntry.title,
                    systemImage: controlEntry.systemImage,
                    intent: OpenEvolutionControlIntent(
                        entrySource: .homeWidgetMedium,
                        controlEntry: controlEntry
                    )
                )
            }
        }
        .padding()
        .containerBackground(for: .widget) {
            LinearGradient(
                colors: [BeforeTheme.ink, BeforeTheme.ember.opacity(0.78)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var lockScreen: some View {
        widgetPrimaryAction(entrySource: .lockScreenWidget) { title, systemImage in
            HStack {
                Image(systemName: systemImage)
                Text(title)
                    .lineLimit(1)
            }
        }
    }

    private var circular: some View {
        widgetPrimaryAction(entrySource: .lockScreenWidget) { _, systemImage in
            Image(systemName: systemImage)
                .font(.title3)
        }
    }

    private func widgetIntentButton<IntentType: AppIntent>(
        title: String,
        systemImage: String,
        prominent: Bool = false,
        intent: IntentType
    ) -> some View {
        Button(intent: intent) {
            Label(title, systemImage: systemImage)
                .font(prominent ? .headline.weight(.bold) : .caption.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .allowsTightening(true)
                .frame(maxWidth: .infinity)
                .padding(.vertical, prominent ? 10 : 8)
                .padding(.horizontal, 10)
                .background(
                    RoundedRectangle(cornerRadius: prominent ? 16 : 14, style: .continuous)
                        .fill(prominent ? .white : .white.opacity(0.18))
                )
                .foregroundStyle(prominent ? BeforeTheme.ink : .white)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func widgetPrimaryAction<LabelContent: View>(
        entrySource: EntrySource,
        @ViewBuilder label: (String, String) -> LabelContent
    ) -> some View {
        let action = entry.snapshot.primaryActionPresentation

        switch action.kind {
        case .quick:
            Button(
                intent: OpenDecisionModeIntent(
                    mode: .quick,
                    prompt: action.prompt,
                    entrySource: entrySource
                )
            ) {
                label(action.title, action.systemImage)
            }
        case .evolutionControl:
            Button(
                intent: OpenEvolutionControlIntent(
                    entrySource: entrySource,
                    primaryAction: action
                )
            ) {
                label(action.title, action.systemImage)
            }
        }
    }
}

struct BeforeWidget: Widget {
    let kind = "BeforeWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BeforeWidgetProvider()) { entry in
            BeforeWidgetView(entry: entry)
        }
        .configurationDisplayName("Before")
        .description("Quick, balance, or mirror entry points for seeing a decision more clearly.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryCircular])
    }
}

@main
struct BeforeWidgetBundle: WidgetBundle {
    var body: some Widget {
        BeforeWidget()
    }
}
