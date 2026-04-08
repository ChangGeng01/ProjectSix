import SwiftUI

struct BalanceBoardView: View {
    @EnvironmentObject private var appModel: BeforeAppModel
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var session: BalanceBoardSession

    var body: some View {
        NavigationStack {
            ZStack {
                BeforeBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        SectionHeader(
                            eyebrow: session.entrySource.label,
                            title: "Balance the trade-off before you choose.",
                            subtitle: "Want, concern, reality, and long-term cost do not need to blur together."
                        )

                        GuidedInputCard(
                            title: "What are you deciding?",
                            subtitle: "Name the real question in one clean line.",
                            placeholder: "Should I go? Which option fits? Is this spend worth it?",
                            accessibilityIdentifier: "balance.prompt.input",
                            text: $session.prompt
                        )

                        if session.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            PanelCard {
                                StarterPromptRow(
                                    title: "Try a balance starter",
                                    suggestions: DecisionStarterLibrary.suggestions(for: .balance)
                                ) { suggestion in
                                    session.prompt = suggestion.prompt
                                }
                            }
                        }

                        GuidedInputCard(
                            title: "What do you want?",
                            subtitle: "Your subjective pull, without apologizing for it.",
                            placeholder: "Convenience, relief, fun, closeness, momentum...",
                            suggestions: DecisionFieldSuggestionLibrary.suggestions(for: .desire),
                            accessibilityIdentifier: "balance.desire.input",
                            text: $session.desire
                        )

                        GuidedInputCard(
                            title: "What are you protecting?",
                            subtitle: "What feels risky, costly, or easy to lose here?",
                            placeholder: "Time, money, energy, respect, clarity...",
                            suggestions: DecisionFieldSuggestionLibrary.suggestions(for: .concern),
                            accessibilityIdentifier: "balance.concern.input",
                            text: $session.concern
                        )

                        GuidedInputCard(
                            title: "What does reality allow?",
                            subtitle: "The concrete constraints, not the story around them.",
                            placeholder: "Budget, schedule, distance, work, family...",
                            suggestions: DecisionFieldSuggestionLibrary.suggestions(for: .constraint),
                            accessibilityIdentifier: "balance.constraint.input",
                            text: $session.constraint
                        )

                        GuidedInputCard(
                            title: "What matters longer-term?",
                            subtitle: "What will future-you have to live with after the moment passes?",
                            placeholder: "Regret, drift, debt, resentment, lost momentum...",
                            suggestions: DecisionFieldSuggestionLibrary.suggestions(for: BalanceField.longTerm),
                            accessibilityIdentifier: "balance.longTerm.input",
                            text: $session.longTerm
                        )

                        BeforeActionButton("Show the board", isEnabled: session.canEvaluate, accessibilityIdentifier: "balance.evaluate") {
                            Task {
                                await session.evaluateWithIntelligence(preferences: appModel.preferences)
                            }
                        }
                        .disabled(!session.canEvaluate)

                        if let result = session.result {
                            if session.isRefiningWithModel {
                                HStack(spacing: 10) {
                                    ProgressView()
                                        .tint(BeforeTheme.ember)
                                    Text("Refining the board on-device…")
                                        .font(.footnote.weight(.medium))
                                        .foregroundStyle(.secondary)
                                }
                            }

                            PanelCard {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text(result.headline)
                                        .font(.title3.bold())
                                        .accessibilityIdentifier("balance.result.headline")
                                    Text(result.summary)
                                        .foregroundStyle(.secondary)
                                        .accessibilityIdentifier("balance.result.summary")
                                }
                            }

                            PanelCard {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text(result.focusTitle)
                                        .font(.headline)
                                        .foregroundStyle(BeforeTheme.ink)
                                        .accessibilityIdentifier("balance.result.focusTitle")
                                    Text(result.focusDescription)
                                        .foregroundStyle(.secondary)
                                        .accessibilityIdentifier("balance.result.focusDescription")
                                    Divider()
                                    Text(result.nextAction)
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(BeforeTheme.moss)
                                        .accessibilityIdentifier("balance.result.nextAction")
                                }
                            }

                            VStack(spacing: 12) {
                                BeforeActionButton("Save this board") {
                                    appModel.saveBalanceBoard(session)
                                    dismiss()
                                }

                                BeforeActionButton("Ask for a second read", style: .secondary) {
                                    appModel.sendBalanceSessionToSupport(session)
                                    dismiss()
                                }

                                BeforeActionButton("Move this to Shared Life", style: .secondary) {
                                    appModel.sendBalanceSessionToSharedLife(session)
                                    dismiss()
                                }

                                BeforeActionButton("Move this to tomorrow", style: .secondary) {
                                    appModel.moveBalanceBoardToTomorrow(session)
                                    dismiss()
                                }

                                BeforeActionButton("Keep editing", style: .tertiary) {
                                    session.result = nil
                                }
                            }
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Balance Board")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}
