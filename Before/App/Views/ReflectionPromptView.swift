import SwiftUI

struct ReflectionPromptView: View {
    @EnvironmentObject private var appModel: BeforeAppModel
    let context: ReflectionContext

    @State private var outcome: ReflectionOutcome?
    @State private var note = ""
    @State private var reminderDraft = ""
    @State private var selectedTemplate: String?

    var body: some View {
        NavigationStack {
            ZStack {
                BeforeBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        SectionHeader(
                            eyebrow: "Afterward",
                            title: "How did it actually feel?",
                            subtitle: "This is about signal, not guilt."
                        )

                        PanelCard {
                            VStack(alignment: .leading, spacing: 12) {
                                ForEach(ReflectionOutcome.allCases) { option in
                                    Button {
                                        outcome = option
                                        if reminderDraft.isEmpty {
                                            selectedTemplate = reminderTemplates.first
                                            reminderDraft = selectedTemplate ?? ""
                                        }
                                    } label: {
                                        HStack {
                                            Image(systemName: outcome == option ? "checkmark.circle.fill" : "circle")
                                            Text(option.title)
                                            Spacer()
                                        }
                                        .padding(12)
                                        .background(
                                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                                .fill(outcome == option ? BeforeTheme.ember.opacity(0.14) : Color.white.opacity(0.68))
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }

                        if shouldOfferReminderComposer {
                            PanelCard {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Leave a line for next time")
                                        .font(.headline)
                                    Text("Short, sharp, and true.")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)

                                    ForEach(reminderTemplates, id: \.self) { template in
                                        Button {
                                            selectedTemplate = template
                                            reminderDraft = template
                                        } label: {
                                            Text(template)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                .padding(12)
                                                .background(
                                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                                        .fill(selectedTemplate == template ? BeforeTheme.ember.opacity(0.14) : Color.white.opacity(0.68))
                                                )
                                        }
                                        .buttonStyle(.plain)
                                    }

                                    TextField("Your own line", text: $reminderDraft, axis: .vertical)
                                        .textFieldStyle(.roundedBorder)
                                        .lineLimit(2...3)
                                }
                            }
                        }

                        PanelCard {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Optional note")
                                    .font(.headline)
                                TextField("Anything you want future-you to remember about this moment?", text: $note, axis: .vertical)
                                    .textFieldStyle(.roundedBorder)
                                    .lineLimit(2...4)
                            }
                        }

                        Button {
                            submit()
                        } label: {
                            Text("Save reflection")
                                .font(.headline)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 18)
                                .background(
                                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                                        .fill(outcome == nil ? Color.gray : BeforeTheme.ink)
                                )
                        }
                        .disabled(outcome == nil)
                        .buttonStyle(.plain)

                        Button("Skip for now") {
                            appModel.skipReflection()
                        }
                        .font(.headline)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Reflection")
        }
    }

    private var shouldOfferReminderComposer: Bool {
        guard let outcome else { return false }
        switch outcome {
        case .betterThanExpected, .notNeeded, .regrettedIt, .feltEmptier:
            return true
        case .okay:
            return false
        }
    }

    private var reminderTemplates: [String] {
        ReminderTemplateLibrary.templates(for: context.scenario, outcome: outcome)
    }

    private func submit() {
        guard let outcome else { return }
        let trimmedReminder = reminderDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        let reminder = shouldOfferReminderComposer && !trimmedReminder.isEmpty
            ? String(trimmedReminder.prefix(BeforePolicy.Reflection.reminderMaxCharacters))
            : nil

        let source: ReminderSourceType = selectedTemplate == reminder ? .template : .userWritten
        appModel.submitReflection(
            outcome: outcome,
            note: note,
            reminderText: reminder,
            reminderSource: source,
            scenario: context.scenario,
            for: context.eventID
        )
    }
}
