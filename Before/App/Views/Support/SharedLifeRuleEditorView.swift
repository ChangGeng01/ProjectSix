import SwiftUI

struct SharedLifeRuleEditorView: View {
    @Environment(\.dismiss) private var dismiss

    private let customTitle: String?
    private let originalRule: SharedLifeRule?
    private let onSave: (SharedLifeRule) -> Void
    private let onDelete: (() -> Void)?

    @State private var kind: SharedLifeRuleKind
    @State private var title: String
    @State private var detail: String
    @State private var isEnabled: Bool

    init(
        title: String? = nil,
        rule: SharedLifeRule? = nil,
        onSave: @escaping (SharedLifeRule) -> Void,
        onDelete: (() -> Void)? = nil
    ) {
        self.customTitle = title
        self.originalRule = rule
        self.onSave = onSave
        self.onDelete = onDelete
        _kind = State(initialValue: rule?.kind ?? .budget)
        _title = State(initialValue: rule?.title ?? "")
        _detail = State(initialValue: rule?.detail ?? "")
        _isEnabled = State(initialValue: rule?.isEnabled ?? true)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                BeforeBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        SectionHeader(
                            eyebrow: originalRule == nil ? "Shared Life" : "Edit rule",
                            title: customTitle ?? (originalRule == nil ? "Add a shared rule" : "Refine this shared rule"),
                            subtitle: "Keep the rule short, specific, and reusable."
                        )

                        PanelCard {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Rule type")
                                    .font(.headline)
                                    .foregroundStyle(BeforeTheme.ink)

                                Picker("Rule type", selection: $kind) {
                                    ForEach(SharedLifeRuleKind.allCases) { kind in
                                        Label(kind.title, systemImage: kind.symbolName).tag(kind)
                                    }
                                }
                                .pickerStyle(.segmented)
                            }
                        }

                        GuidedInputCard(
                            title: "Rule title",
                            subtitle: "Say what the rule does, not why it sounds virtuous.",
                            placeholder: "Pause non-essential spends over the threshold",
                            text: $title
                        )

                        GuidedInputCard(
                            title: "Rule detail",
                            subtitle: "Name the trigger or shared check that should happen.",
                            placeholder: "If it is after 9pm, treat delivery as a second decision.",
                            text: $detail
                        )

                        PanelCard {
                            Toggle("Keep this rule active", isOn: $isEnabled)
                                .font(.headline)
                                .foregroundStyle(BeforeTheme.ink)
                        }

                        BeforeActionButton(
                            customTitle ?? (originalRule == nil ? "Save shared rule" : "Update shared rule"),
                            isEnabled: canSave
                        ) {
                            onSave(
                                SharedLifeRule(
                                    id: originalRule?.id ?? UUID(),
                                    createdAt: originalRule?.createdAt ?? .now,
                                    updatedAt: .now,
                                    kind: kind,
                                    title: trimmed(title),
                                    detail: trimmed(detail),
                                    isEnabled: isEnabled,
                                    isSeeded: originalRule?.isSeeded ?? false
                                )
                            )
                            dismiss()
                        }
                        .disabled(!canSave)

                        if let onDelete, originalRule?.isSeeded == false {
                            BeforeActionButton("Delete rule", style: .tertiary) {
                                onDelete()
                                dismiss()
                            }
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle(customTitle ?? "Shared Rule")
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
