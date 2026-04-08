import SwiftData
import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var appModel: BeforeAppModel
    @Query(sort: \TomorrowBoxItem.createdAt, order: .reverse) private var tomorrowItems: [TomorrowBoxItem]
    @State private var decisionPrompt = ""

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
                            eyebrow: "Decision OS",
                            title: "Help me see this clearly.",
                            subtitle: "Quick calls, trade-offs, and heavier questions can all start from one clean entry."
                        )

                        GuidedInputCard(
                            title: "What are you deciding?",
                            subtitle: "Write it once. Before will start at the right depth.",
                            placeholder: "Buy this? Go there? Reply now? Stay or leave?",
                            text: $decisionPrompt
                        )

                        if let preview = homePromptPreview {
                            DecisionRoutePreviewCard(
                                mode: preview.mode,
                                title: preview.title,
                                detail: preview.detail,
                                isPinned: preview.isPinned
                            )
                        }

                        PanelCard {
                            StarterPromptRow(
                                title: "Need a cleaner starting point?",
                                suggestions: DecisionStarterLibrary.homeFeatured
                            ) { suggestion in
                                appModel.startDecisionMode(suggestion.mode, entrySource: .app, prompt: suggestion.prompt)
                            }
                        }

                        BeforeActionButton(appModel.preferences.homePromptAction.buttonTitle, isEnabled: !trimmedPrompt.isEmpty) {
                            _ = appModel.submitHomePrompt(trimmedPrompt, entrySource: .app)
                            decisionPrompt = ""
                        }
                        .disabled(trimmedPrompt.isEmpty)

                        VStack(spacing: 14) {
                            ForEach(DecisionMode.allCases) { mode in
                                DecisionModeCard(mode: mode) {
                                    appModel.startDecisionMode(mode, entrySource: .app, prompt: trimmedPrompt)
                                    decisionPrompt = ""
                                }
                            }
                        }

                        SectionHeader(
                            eyebrow: "Quick surfaces",
                            title: "Named impulses still stay one tap away.",
                            subtitle: "When the shape is obvious, open the fast mode directly."
                        )

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

                                if let signal = appModel.latestSignal() {
                                    Text(signal.eyebrow.uppercased())
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(BeforeTheme.ember)
                                    Text(signal.title)
                                        .font(.title3.bold())
                                        .foregroundStyle(BeforeTheme.ink)
                                        .lineLimit(3)
                                    Text(signal.detail)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(4)
                                } else {
                                    Text("Your first judgment, balance board, or mirror will start building signal here.")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }

                        PanelCard {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Need distance, not denial?")
                                    .font(.headline)
                                Text("Move it into Tomorrow Box when the call matters, but not from peak blur.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)

                                if tomorrowBoxCount > 0 {
                                    Text("\(tomorrowBoxCount) \(tomorrowBoxCount == 1 ? "item is" : "items are") waiting for a clearer read.")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(BeforeTheme.ember)
                                }

                                BeforeActionButton("Open Tomorrow Box", style: .secondary) {
                                    appModel.selectedTab = .box
                                }
                            }
                        }

                        PanelCard {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Need another perspective?")
                                    .font(.headline)
                                Text("Buddy keeps it personal. Shared Life keeps recurring household decisions from resetting every time.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)

                                if supportPendingCount > 0 || sharedLifePendingCount > 0 {
                                    Text("\(supportPendingCount) buddy \(supportPendingCount == 1 ? "thread" : "threads"), \(sharedLifePendingCount) shared \(sharedLifePendingCount == 1 ? "item" : "items") still active.")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(BeforeTheme.ember)
                                }

                                BeforeActionButton("Open Support Space", style: .secondary) {
                                    appModel.supportSurface = .buddy
                                    appModel.selectedTab = .support
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

    private var trimmedPrompt: String {
        decisionPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var homePromptPreview: HomePromptPreview? {
        guard !trimmedPrompt.isEmpty else { return nil }

        if let preferredMode = appModel.preferences.homePromptAction.preferredMode {
            return HomePromptPreview(
                mode: preferredMode,
                title: "This prompt will open in \(preferredMode.title).",
                detail: "Your home prompt preference is pinned to \(preferredMode.title.lowercased()). You can still open a different mode below when you want to.",
                isPinned: true
            )
        }

        let routed = DecisionIntelligenceCoordinator.route(
            prompt: trimmedPrompt,
            preferences: appModel.preferences
        )
        return HomePromptPreview(
            mode: routed.mode,
            title: "This looks like a \(routed.mode.title.lowercased()) question.",
            detail: routed.reason,
            isPinned: false
        )
    }

    private var tomorrowBoxCount: Int {
        tomorrowItems.count
    }

    private var supportPendingCount: Int {
        appModel.supportInbox.activeRequests.count
    }

    private var sharedLifePendingCount: Int {
        appModel.sharedLifeStore.pendingItems.count
    }
}

private struct HomePromptPreview {
    let mode: DecisionMode
    let title: String
    let detail: String
    let isPinned: Bool
}
