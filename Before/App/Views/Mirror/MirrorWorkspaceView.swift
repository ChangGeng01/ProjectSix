import SwiftUI

struct MirrorWorkspaceView: View {
    @EnvironmentObject private var appModel: BeforeAppModel
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var session: MirrorWorkspaceSession

    var body: some View {
        NavigationStack {
            ZStack {
                BeforeBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        SectionHeader(
                            eyebrow: session.entrySource.label,
                            title: "Do not force a verdict on a heavy question.",
                            subtitle: "Name the feeling, the pattern, the reality, the future, and the self you are trying not to lose."
                        )

                        GuidedInputCard(
                            title: "What are you facing?",
                            subtitle: "Ask the question honestly before you try to solve it.",
                            placeholder: "Should I stay? Should I leave? Do I still fit here?",
                            text: $session.prompt
                        )

                        if session.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            PanelCard {
                                StarterPromptRow(
                                    title: "Try a mirror starter",
                                    suggestions: DecisionStarterLibrary.suggestions(for: .mirror)
                                ) { suggestion in
                                    session.prompt = suggestion.prompt
                                }
                            }
                        }

                        GuidedInputCard(
                            title: "Emotion",
                            subtitle: "What is strongest right now: hurt, anger, fear, loneliness, grief, relief?",
                            placeholder: "Name the feeling without defending it.",
                            suggestions: DecisionFieldSuggestionLibrary.suggestions(for: .emotion),
                            text: $session.emotion
                        )

                        GuidedInputCard(
                            title: "Relationship or structure",
                            subtitle: "What keeps going wrong underneath the latest moment?",
                            placeholder: "Boundary, trust, respect, communication, pattern...",
                            suggestions: DecisionFieldSuggestionLibrary.suggestions(for: .relationship),
                            text: $session.relationship
                        )

                        GuidedInputCard(
                            title: "Reality",
                            subtitle: "What concrete constraints are in the room?",
                            placeholder: "Work, money, family, distance, home, timing...",
                            suggestions: DecisionFieldSuggestionLibrary.suggestions(for: .reality),
                            text: $session.reality
                        )

                        GuidedInputCard(
                            title: "Long-term",
                            subtitle: "If this keeps going the same way, what shape does life start taking?",
                            placeholder: "Drift, regret, shrinking, repair, rebuilding...",
                            suggestions: DecisionFieldSuggestionLibrary.suggestions(for: MirrorField.longTerm),
                            text: $session.longTerm
                        )

                        GuidedInputCard(
                            title: "Self",
                            subtitle: "What happens to your sense of self if this continues?",
                            placeholder: "I feel smaller, more split, calmer, freer...",
                            suggestions: DecisionFieldSuggestionLibrary.suggestions(for: .selfLens),
                            text: $session.selfLens
                        )

                        BeforeActionButton("Reflect it back", isEnabled: session.canEvaluate) {
                            session.evaluate()
                        }
                        .disabled(!session.canEvaluate)

                        if let result = session.result {
                            PanelCard {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text(result.headline)
                                        .font(.title3.bold())
                                    Text(result.coreTension)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            PanelCard {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text(result.nextActionTitle)
                                        .font(.headline)
                                    Text(result.nextAction)
                                        .foregroundStyle(BeforeTheme.moss)
                                }
                            }

                            VStack(spacing: 12) {
                                BeforeActionButton("Save this mirror") {
                                    appModel.saveMirrorWorkspace(session)
                                    dismiss()
                                }

                                BeforeActionButton("Move this to tomorrow", style: .secondary) {
                                    appModel.moveMirrorWorkspaceToTomorrow(session)
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
            .navigationTitle("Mirror")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}
