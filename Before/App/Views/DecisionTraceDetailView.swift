import SwiftUI
import BASPolicy

struct DecisionTraceDetailView: View {
    let trace: DecisionIntelligenceTrace

    var body: some View {
        List {
            Section("Summary") {
                LabeledContent("Kind", value: trace.kind.title)
                LabeledContent("Preferred", value: trace.preferredProvider.title)
                LabeledContent("Active", value: trace.activeProvider?.title ?? "Deterministic fallback")
                LabeledContent("Fallbacks", value: trace.allowFallbacks ? "Allowed" : "Off")
                if !trace.attemptedProviders.isEmpty {
                    LabeledContent("Tried", value: trace.attemptedProviders.map(\.title).joined(separator: " → "))
                }
                LabeledContent("Result", value: trace.usedFallback ? "Used fallback path" : "Used preferred path")
                Text(trace.detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Consistency harness") {
                if let consistencyCheck = trace.consistencyCheck {
                    LabeledContent("Status", value: trace.consistencyRejected ? "Rejected" : "Passed")
                    LabeledContent("Severity", value: "\(Int((consistencyCheck.severityScore * 100).rounded()))")
                    LabeledContent("Violations", value: "\(consistencyCheck.violations.count)")

                    if consistencyCheck.violations.isEmpty {
                        Text("No consistency violations were detected against the structured truth state.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(consistencyCheck.violations) { violation in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(readableViolationTitle(violation.kind))
                                    .font(.footnote.weight(.semibold))
                                Text(violation.message)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                } else {
                    Text("No consistency audit was recorded for this trace.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            if hasContextDisciplineData {
                Section("Context discipline") {
                    if let promptBudget = trace.promptBudget {
                        LabeledContent("Prompt target", value: "\(promptBudget.targetCharacters)")
                        LabeledContent("Prompt actual", value: "\(promptBudget.totalCharacters)")
                        LabeledContent("Within target", value: yesNo(promptBudget.isWithinTarget))
                    }

                    if let semanticPromptFingerprint = trace.semanticPromptFingerprint {
                        LabeledContent("Semantic fingerprint", value: semanticPromptFingerprint)
                            .textSelection(.enabled)
                    }

                    if let stablePrefixFingerprint = trace.stablePrefixFingerprint {
                        LabeledContent("Stable prefix", value: stablePrefixFingerprint)
                            .textSelection(.enabled)
                    }

                    if let contextState = trace.contextState {
                        LabeledContent("Generation", value: "\(contextState.generation)")
                        LabeledContent("Rebuilt session", value: yesNo(contextState.rebuiltSession))
                        LabeledContent("Anchor fields", value: "\(contextState.anchorFieldCount)")
                        LabeledContent("Active fields", value: "\(contextState.activeFieldCount)")
                        LabeledContent("Stale fields", value: "\(contextState.staleFieldCount)")
                    }

                    if let frontstageState = trace.frontstageState {
                        LabeledContent("Retained evidence", value: "\(frontstageState.retainedEvidenceCount)")
                        LabeledContent("Dropped evidence", value: "\(frontstageState.droppedEvidenceCount)")
                        LabeledContent("Injected drops", value: "\(frontstageState.droppedInjectedEvidenceCount)")
                        LabeledContent("Duplicate drops", value: "\(frontstageState.droppedDuplicateEvidenceCount)")
                        LabeledContent("Budget trims", value: "\(frontstageState.droppedBudgetEvidenceCount)")
                    }
                }
            }

            if let runtimeStrategy = trace.runtimeStrategy {
                Section("Runtime strategy") {
                    LabeledContent("Gear", value: runtimeStrategy.runtimeGear.rawValue)
                    LabeledContent("Provider", value: runtimeStrategy.preferredProvider.title)
                    LabeledContent("Retrieval", value: runtimeStrategy.retrievalMode.rawValue)
                    LabeledContent("Thinking", value: runtimeStrategy.thinkingMode.rawValue)
                    LabeledContent("Output", value: runtimeStrategy.outputMode.rawValue)
                    LabeledContent("Tone", value: runtimeStrategy.tone.rawValue)
                    LabeledContent("Response language", value: runtimeStrategy.responseLanguage.rawValue)
                    LabeledContent("Model calls", value: yesNo(runtimeStrategy.allowsModelInvocation))

                    if !runtimeStrategy.actionSpace.isEmpty {
                        Text(runtimeStrategy.actionSpace.joined(separator: ", "))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("Prompt") {
                Text(trace.prompt)
                    .font(.footnote.monospaced())
                    .textSelection(.enabled)
            }

            Section("Output preview") {
                Text(trace.outputPreview)
                    .font(.footnote)
                    .textSelection(.enabled)
            }
        }
        .scrollContentBackground(.hidden)
        .background(BeforeBackground())
        .navigationTitle("Trace")
    }

    private var hasContextDisciplineData: Bool {
        trace.promptBudget != nil ||
            trace.semanticPromptFingerprint != nil ||
            trace.stablePrefixFingerprint != nil ||
            trace.contextState != nil ||
            trace.frontstageState != nil
    }

    private func yesNo(_ value: Bool) -> String {
        value ? "Yes" : "No"
    }

    private func readableViolationTitle(_ kind: BASConsistencyViolationKind) -> String {
        switch kind {
        case .modeMismatch:
            "Mode mismatch"
        case .forbiddenAction:
            "Forbidden action"
        case .unsupportedAction:
            "Unsupported action"
        case .factConflict:
            "Fact conflict"
        case .personaDrift:
            "Persona drift"
        }
    }
}
