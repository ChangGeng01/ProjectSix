import SwiftUI

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
}
