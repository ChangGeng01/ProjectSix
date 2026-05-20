import SwiftUI

private enum SharedLifeItemModeOption: String, CaseIterable, Identifiable {
    case sharedOnly
    case quick
    case balance
    case mirror

    var id: String { rawValue }

    var title: String {
        switch self {
        case .sharedOnly: "Shared only"
        case .quick: DecisionMode.quick.title
        case .balance: DecisionMode.balance.title
        case .mirror: DecisionMode.mirror.title
        }
    }

    var decisionMode: DecisionMode? {
        switch self {
        case .sharedOnly:
            nil
        case .quick:
            .quick
        case .balance:
            .balance
        case .mirror:
            .mirror
        }
    }

    static func from(mode: DecisionMode?) -> SharedLifeItemModeOption {
        switch mode {
        case .quick:
            .quick
        case .balance:
            .balance
        case .mirror:
            .mirror
        case nil:
            .sharedOnly
        }
    }
}

struct SharedLifeItemComposerView: View {
    @Environment(\.dismiss) private var dismiss

    private let onSave: (SharedLifeBoxItem) -> Void

    @State private var title: String = ""
    @State private var detail: String = ""
    @State private var selectedMode: SharedLifeItemModeOption = .sharedOnly
    @State private var prompt: String = ""

    init(onSave: @escaping (SharedLifeBoxItem) -> Void) {
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            ZStack {
                BeforeBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        SectionHeader(
                            eyebrow: "Shared Life",
                            title: "Add a shared box item",
                            subtitle: "Use this for household decisions that should not reset to zero every time."
                        )

                        GuidedInputCard(
                            title: "Shared title",
                            subtitle: "Name the decision as it would be understood by two people.",
                            placeholder: "Upgrade the desk chair this month?",
                            text: $title
                        )

                        GuidedInputCard(
                            title: "Why it belongs here",
                            subtitle: "Capture the tension, cost, or pattern you want to keep visible.",
                            placeholder: "This is not just comfort. It changes shared budget and space.",
                            text: $detail
                        )

                        PanelCard {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Related mode")
                                    .font(.headline)
                                    .foregroundStyle(BeforeTheme.ink)

                                Picker("Related mode", selection: $selectedMode) {
                                    ForEach(SharedLifeItemModeOption.allCases) { option in
                                        Text(option.title).tag(option)
                                    }
                                }
                                .pickerStyle(.segmented)
                            }
                        }

                        if selectedMode != .sharedOnly {
                            GuidedInputCard(
                                title: "Question summary",
                                subtitle: "Optional. Add the wording you would want to reopen later.",
                                placeholder: "Should we keep doing this?",
                                text: $prompt
                            )
                        }

                        BeforeActionButton("Save shared item", isEnabled: canSave) {
                            onSave(
                                SharedLifeBoxItem(
                                    title: trimmed(title),
                                    detail: trimmed(detail),
                                    mode: selectedMode.decisionMode,
                                    prompt: trimmed(prompt)
                                )
                            )
                            dismiss()
                        }
                        .disabled(!canSave)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Shared Item")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private var canSave: Bool {
        !trimmed(title).isEmpty && !trimmed(detail).isEmpty
    }

    private func trimmed(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
