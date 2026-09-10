import SwiftUI

struct QuickCheckView: View {
    @EnvironmentObject private var appModel: BeforeAppModel
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var session: QuickCheckSession
    @State private var displayedReminder: String?

    var body: some View {
        NavigationStack {
            ZStack {
                BeforeBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        SectionHeader(
                            eyebrow: session.entrySource.label,
                            title: "Take five clean seconds.",
                            subtitle: "Choose the shape of the urge before you obey it."
                        )

                        if let displayedReminder {
                            PanelCard {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("From a previous moment")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(BeforeTheme.ember)
                                    Text("“\(displayedReminder)”")
                                        .font(.headline)
                                }
                            }
                        }

                        PanelCard {
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Scenario")
                                    .font(.headline)
                                Picker("Scenario", selection: $session.scenario) {
                                    ForEach(ScenarioType.allCases) { scenario in
                                        Text(scenario.title).tag(scenario)
                                    }
                                }
                                .pickerStyle(.segmented)
                            }
                        }

                        QuestionCard(
                            title: "Why now?",
                            accessibilityIdentifierPrefix: "quick.motivation",
                            selection: $session.motivation,
                            values: MotivationChoice.allCases
                        ) { $0.title }

                        QuestionCard(
                            title: "What usually happens after?",
                            accessibilityIdentifierPrefix: "quick.outcome",
                            selection: $session.expectedOutcome,
                            values: OutcomeChoice.allCases
                        ) { $0.title }

                        QuestionCard(
                            title: "Can you still pull back?",
                            accessibilityIdentifierPrefix: "quick.control",
                            selection: $session.controlLevel,
                            values: ControlChoice.allCases
                        ) { $0.title }

                        PanelCard {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Optional note")
                                    .font(.headline)
                                TextField("What feels true right now?", text: $session.note, axis: .vertical)
                                    .textFieldStyle(.roundedBorder)
                                    .lineLimit(2...4)
                                    .accessibilityIdentifier("quick.note.input")
                            }
                        }

                        DecisionSessionEngineResultActionsCard(
                            sessionID: session.sessionEngineSessionID,
                            headline: "Session Engine workspace line",
                            detail: "Open the local recovery line for this draft, or split a correction branch before you evaluate.",
                            correctionTitle: "Branch this quick check from here",
                            correctionPlaceholder: "Correction: continue this quick check from a new requirement line without rewriting the old path.",
                            correctionReason: "quick workspace correction branch"
                        )

                        BeforeActionButton("Show me the call", isEnabled: session.canEvaluate, accessibilityIdentifier: "quick.evaluate") {
                            Task {
                                await appModel.evaluateQuickSessionWithIntelligence(session)
                            }
                        }
                        .disabled(!session.canEvaluate)

                        if session.isRefiningWithModel {
                            refiningHint
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Quick Check")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
            .task(id: session.scenario) {
                displayedReminder = await appModel.bestReminder(
                    for: session.scenario,
                    prompt: session.note,
                    mode: .quick
                )
            }
            .sheet(
                isPresented: Binding(
                    get: { session.result != nil },
                    set: { if !$0 { session.result = nil } }
                )
            ) {
                if let result = session.result {
                    ResultView(session: session, result: result)
                        .environmentObject(appModel)
                }
            }
        }
    }

    private var refiningHint: some View {
        HStack(spacing: 10) {
            ProgressView()
                .tint(BeforeTheme.ember)
            Text("Refining the language locally…")
                .font(.footnote.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 4)
    }
}

private struct QuestionCard<Value: Identifiable & Hashable>: View {
    let title: String
    let accessibilityIdentifierPrefix: String?
    @Binding var selection: Value?
    let values: [Value]
    let label: (Value) -> String

    var body: some View {
        PanelCard {
            VStack(alignment: .leading, spacing: 14) {
                Text(title)
                    .font(.headline)

                VStack(spacing: 10) {
                    ForEach(values) { value in
                        Button {
                            selection = value
                        } label: {
                            HStack(alignment: .center, spacing: 12) {
                                Image(systemName: selection == value ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(selection == value ? BeforeTheme.ember : .secondary)
                                Text(label(value))
                                    .multilineTextAlignment(.leading)
                                    .foregroundStyle(BeforeTheme.ink)
                                Spacer()
                            }
                            .padding(14)
                            .background(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(selection == value ? BeforeTheme.ember.opacity(0.12) : Color.white.opacity(0.65))
                            )
                        }
                        .buttonStyle(.plain)
                        .beforeAccessibilityIdentifier(optionIdentifier(for: value))
                    }
                }
            }
        }
    }

    private func optionIdentifier(for value: Value) -> String? {
        guard let accessibilityIdentifierPrefix else { return nil }
        return "\(accessibilityIdentifierPrefix).\(String(describing: value.id))"
    }
}
