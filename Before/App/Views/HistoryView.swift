import SwiftData
import SwiftUI

struct HistoryView: View {
    @Query(sort: \CheckEvent.createdAt, order: .reverse) private var events: [CheckEvent]

    var body: some View {
        NavigationStack {
            ZStack {
                BeforeBackground()

                if events.isEmpty {
                    ContentUnavailableView(
                        "No checks yet",
                        systemImage: "clock.arrow.trianglehead.counterclockwise.rotate.90",
                        description: Text("Your flow history will stay light and readable here.")
                    )
                } else {
                    ScrollView {
                        LazyVStack(spacing: 14) {
                            ForEach(events) { event in
                                PanelCard {
                                    VStack(alignment: .leading, spacing: 10) {
                                        HStack {
                                            Label(event.scenario.title, systemImage: event.scenario.symbolName)
                                            Spacer()
                                            Text(event.verdict.title)
                                                .font(.caption.weight(.semibold))
                                                .padding(.horizontal, 10)
                                                .padding(.vertical, 6)
                                                .background(
                                                    Capsule()
                                                        .fill(BeforeTheme.ember.opacity(0.18))
                                                )
                                        }

                                        Text(event.currentPerspective)
                                            .font(.headline)
                                            .foregroundStyle(BeforeTheme.ink)

                                        Text(event.afterPerspective)
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)

                                        HStack {
                                            Text(event.createdAt, style: .relative)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                            Spacer()
                                            if let reflection = event.reflectionOutcome {
                                                Text(reflection.title)
                                                    .font(.caption.weight(.medium))
                                                    .foregroundStyle(BeforeTheme.moss)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .padding(20)
                    }
                }
            }
            .navigationTitle("History")
        }
    }
}
