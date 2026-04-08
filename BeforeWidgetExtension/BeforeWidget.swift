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
            Button(intent: OpenQuickCheckIntent(entrySource: .homeWidgetSmall)) {
                Text("Worth it?")
                    .font(.headline.weight(.bold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.white)
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
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Before")
                    .font(.headline)
                    .foregroundStyle(.white)
                Text(entry.snapshot.messageBody)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.82))
                    .lineLimit(4)
                Spacer()
            }

            Button(intent: OpenQuickCheckIntent(entrySource: .homeWidgetMedium)) {
                Text("Open")
                    .font(.headline)
                    .frame(maxHeight: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.white)
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
        Button(intent: OpenQuickCheckIntent(entrySource: .lockScreenWidget)) {
            HStack {
                Image(systemName: "pause.circle.fill")
                Text("Open Before")
                    .lineLimit(1)
            }
        }
    }

    private var circular: some View {
        Button(intent: OpenQuickCheckIntent(entrySource: .lockScreenWidget)) {
            Image(systemName: "pause.circle.fill")
                .font(.title3)
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
        .description("A one-tap buffer before acting on impulse.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryCircular])
    }
}

@main
struct BeforeWidgetBundle: WidgetBundle {
    var body: some Widget {
        BeforeWidget()
    }
}
