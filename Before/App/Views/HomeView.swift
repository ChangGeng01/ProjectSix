import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var appModel: BeforeAppModel

    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                BeforeBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        if let startupNotice = appModel.startupNotice {
                            PanelCard {
                                VStack(alignment: .leading, spacing: 12) {
                                    Label("Recovery mode", systemImage: "exclamationmark.triangle.fill")
                                        .font(.headline)
                                        .foregroundStyle(BeforeTheme.ember)
                                    Text(startupNotice)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                    Button("Dismiss") {
                                        appModel.dismissStartupNotice()
                                    }
                                    .font(.headline)
                                }
                            }
                        }

                        SectionHeader(
                            eyebrow: "Quick buffer",
                            title: "Help me judge this before I act.",
                            subtitle: "Two perspectives, one verdict, one next move."
                        )

                        Button {
                            appModel.startQuickCheck(entrySource: .app)
                        } label: {
                            HStack(spacing: 14) {
                                Image(systemName: "pause.circle.fill")
                                    .font(.system(size: 28))
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Open quick check")
                                        .font(.headline)
                                    Text("Fastest route when you already feel the pull.")
                                        .font(.subheadline)
                                        .foregroundStyle(.white.opacity(0.74))
                                }
                                Spacer()
                            }
                            .foregroundStyle(.white)
                            .padding(20)
                            .background(
                                RoundedRectangle(cornerRadius: 28, style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            colors: [BeforeTheme.ink, BeforeTheme.ember.opacity(0.88)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            )
                        }
                        .buttonStyle(.plain)

                        LazyVGrid(columns: columns, spacing: 14) {
                            ForEach(ScenarioType.allCases) { scenario in
                                Button {
                                    appModel.startQuickCheck(entrySource: .app, scenario: scenario)
                                } label: {
                                    VStack(alignment: .leading, spacing: 12) {
                                        Image(systemName: scenario.symbolName)
                                            .font(.title2.weight(.bold))
                                            .foregroundStyle(BeforeTheme.ember)
                                        Text(scenario.title)
                                            .font(.headline)
                                            .foregroundStyle(BeforeTheme.ink)
                                        Text(scenario.subtitle)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .multilineTextAlignment(.leading)
                                    }
                                    .frame(maxWidth: .infinity, minHeight: 140, alignment: .leading)
                                    .padding(18)
                                    .background(
                                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                                            .fill(.white.opacity(0.72))
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        PanelCard {
                            VStack(alignment: .leading, spacing: 14) {
                                Text("Recent signal")
                                    .font(.headline)
                                if let event = appModel.latestEvents(limit: 1).first {
                                    Text(event.verdict.title)
                                        .font(.title3.bold())
                                        .foregroundStyle(BeforeTheme.ink)
                                    Text(event.afterPerspective)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(3)
                                } else {
                                    Text("Your first check will start building a clearer picture here.")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Before")
        }
    }
}
