import SwiftData
import SwiftUI

struct TomorrowBoxView: View {
    @EnvironmentObject private var appModel: BeforeAppModel
    @Query(sort: \TomorrowBoxItem.dueAt, order: .forward) private var items: [TomorrowBoxItem]

    var body: some View {
        NavigationStack {
            ZStack {
                BeforeBackground()

                if items.isEmpty {
                    ContentUnavailableView(
                        "Nothing in Tomorrow Box",
                        systemImage: "tray",
                        description: Text("When something matters but not from peak blur, move it here and reopen it with more space.")
                    )
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 18) {
                            SectionHeader(
                                eyebrow: "Delay",
                                title: "Hold the call until it deserves daylight.",
                                subtitle: "Tomorrow Box keeps context intact, but lets timing change."
                            )

                            PanelCard {
                                HStack(spacing: 16) {
                                    countBlock(title: "Ready now", count: readyItems.count, accent: BeforeTheme.moss)
                                    countBlock(title: "Later", count: laterItems.count, accent: BeforeTheme.ember)
                                    countBlock(title: "Total", count: items.count, accent: BeforeTheme.ink)
                                }
                            }

                            if !readyItems.isEmpty {
                                boxSection(
                                    title: "Ready now",
                                    subtitle: "These already have enough distance to reopen cleanly.",
                                    items: readyItems
                                )
                            }

                            if !laterItems.isEmpty {
                                boxSection(
                                    title: "Still later",
                                    subtitle: "These are still cooling off. You can leave them, reopen anyway, or push them further out.",
                                    items: laterItems
                                )
                            }
                        }
                        .padding(20)
                    }
                }
            }
            .navigationTitle("Tomorrow Box")
        }
    }

    private var readyItems: [TomorrowBoxItem] {
        items.filter(\.isReadyForRecheck)
    }

    private var laterItems: [TomorrowBoxItem] {
        items.filter { !$0.isReadyForRecheck }
    }

    @ViewBuilder
    private func boxSection(
        title: String,
        subtitle: String,
        items: [TomorrowBoxItem]
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundStyle(BeforeTheme.ink)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            ForEach(items) { item in
                itemCard(for: item)
            }
        }
    }

    private func itemCard(for item: TomorrowBoxItem) -> some View {
        PanelCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    Label(item.mode.title, systemImage: item.mode.symbolName)
                        .font(.headline)
                    Spacer()
                    if item.isReadyForRecheck {
                        Text("Ready now")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(BeforeTheme.moss)
                    } else {
                        Text(item.dueAt, style: .relative)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(BeforeTheme.ember)
                    }
                }

                Text(item.title)
                    .font(.title3.bold())
                    .foregroundStyle(BeforeTheme.ink)

                Text(item.detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack {
                    Text(item.dueAt, style: .date)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(item.dueAt, style: .time)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 10) {
                    BeforeActionButton(item.isReadyForRecheck ? "Reopen this now" : "Reopen it anyway") {
                        appModel.reopenTomorrowBoxItem(item)
                    }

                    Menu {
                        ForEach(TomorrowBoxDelay.allCases) { delay in
                            Button(delay.title) {
                                appModel.delayTomorrowBoxItem(item, by: delay)
                            }
                        }
                    } label: {
                        Text("Give it more time")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(BeforeTheme.soft.opacity(0.86))
                            )
                            .foregroundStyle(BeforeTheme.ink)
                    }

                    BeforeActionButton("Remove from box", style: .secondary) {
                        appModel.removeTomorrowBoxItem(item)
                    }
                }
            }
        }
    }

    private func countBlock(title: String, count: Int, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(count)")
                .font(.title2.bold())
                .foregroundStyle(accent)
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
