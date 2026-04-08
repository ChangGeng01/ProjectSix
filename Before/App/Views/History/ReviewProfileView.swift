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
    @Environment(\.dismiss) private var dismiss

    let profile: ReviewProfile

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
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Profile")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}
