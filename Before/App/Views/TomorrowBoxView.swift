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
                        LazyVStack(spacing: 14) {
                            ForEach(items) { item in
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

                                        VStack(spacing: 10) {
                                            BeforeActionButton(item.isReadyForRecheck ? "Reopen this now" : "Reopen it anyway") {
                                                appModel.reopenTomorrowBoxItem(item)
                                            }

                                            BeforeActionButton("Remove from box", style: .secondary) {
                                                appModel.removeTomorrowBoxItem(item)
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
            .navigationTitle("Tomorrow Box")
        }
    }
}
