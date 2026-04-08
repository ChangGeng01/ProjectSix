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
        Button(intent: OpenDecisionModeIntent(mode: .quick, entrySource: .lockScreenWidget)) {
            HStack {
                Image(systemName: "pause.circle.fill")
                Text("Open Before")
                    .lineLimit(1)
            }
        }
    }

    private var circular: some View {
        Button(intent: OpenDecisionModeIntent(mode: .quick, entrySource: .lockScreenWidget)) {
            Image(systemName: "pause.circle.fill")
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
