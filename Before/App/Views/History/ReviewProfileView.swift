import SwiftUI

enum ReviewProfileSelection: Identifiable {
    case quick
    case balance
    case mirror

    var id: DecisionMode {
        switch self {
        case .quick: .quick
        case .balance: .balance
        case .mirror: .mirror
        }
    }
}

struct ReviewProfileView: View {
    @EnvironmentObject private var appModel: BeforeAppModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedDetail: HistoryDetailSelection?

    let profile: ReviewProfile
    let recentEntries: [ReviewProfileEntry]

    var body: some View {
        NavigationStack {
            ZStack {
                BeforeBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        SectionHeader(
                            eyebrow: profile.mode.title,
                            title: profile.title,
                            subtitle: profile.subtitle
                        )

                        ForEach(profile.sections) { section in
                            PanelCard {
                                VStack(alignment: .leading, spacing: 14) {
                                    Text(section.title)
                                        .font(.headline)
                                        .foregroundStyle(BeforeTheme.ink)

                                    ForEach(section.rows) { row in
                                        HStack(alignment: .top, spacing: 12) {
                                            Text("\(row.count)")
                                                .font(.title3.bold())
                                                .foregroundStyle(BeforeTheme.ember)
                                                .frame(width: 32)

                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(row.title)
                                                    .font(.subheadline.weight(.medium))
                                                    .foregroundStyle(BeforeTheme.ink)
                                                if let detail = row.detail {
                                                    Text(detail)
                                                        .font(.caption)
                                                        .foregroundStyle(.secondary)
                                                }
                                            }

                                            Spacer(minLength: 0)
                                        }
                                    }
                                }
                            }
                        }

                        DecisionReviewRecentEntriesSectionView(
                            entries: recentEntries,
                            selectAction: { entry in
                                selectedDetail = detailSelection(for: entry)
                            },
                            reopenAction: { entry in
                                reopen(entry)
                            },
                            postponeAction: { entry in
                                moveToTomorrow(entry)
                            }
                        )
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Profile")
            .sheet(item: $selectedDetail) { selection in
                HistoryDetailView(selection: selection)
                    .environmentObject(appModel)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private func detailSelection(for entry: ReviewProfileEntry) -> HistoryDetailSelection {
        switch entry {
        case .quick(let event):
            .quick(event)
        case .balance(let record):
            .balance(record)
        case .mirror(let record):
            .mirror(record)
        }
    }

    private func reopen(_ entry: ReviewProfileEntry) {
        switch entry {
        case .quick(let event):
            appModel.reopenCheckEvent(event)
        case .balance(let record):
            appModel.reopenBalanceRecord(record)
        case .mirror(let record):
            appModel.reopenMirrorRecord(record)
        }

        dismiss()
    }

    private func moveToTomorrow(_ entry: ReviewProfileEntry) {
        switch entry {
        case .quick(let event):
            appModel.moveCheckEventToTomorrow(event)
        case .balance(let record):
            appModel.moveBalanceRecordToTomorrow(record)
        case .mirror(let record):
            appModel.moveMirrorRecordToTomorrow(record)
        }

        dismiss()
    }
}
