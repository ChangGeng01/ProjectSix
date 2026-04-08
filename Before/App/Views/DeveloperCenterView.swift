import SwiftData
import SwiftUI

struct DeveloperCenterView: View {
    @EnvironmentObject private var appModel: BeforeAppModel
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var debugStore = DecisionIntelligenceDebugStore.shared
    @Query(sort: \CheckEvent.createdAt, order: .reverse) private var events: [CheckEvent]
    @Query(sort: \BalanceDecisionRecord.updatedAt, order: .reverse) private var balanceBoards: [BalanceDecisionRecord]
    @Query(sort: \MirrorDecisionRecord.updatedAt, order: .reverse) private var mirrorRecords: [MirrorDecisionRecord]

    var body: some View {
        NavigationStack {
            List {
                Section("Model routing") {
                    Picker("Preferred model", selection: preferredProviderBinding) {
                        ForEach(DecisionModelProviderPreference.allCases) { provider in
                            Text(provider.title).tag(provider)
                        }
                    }

                    Text(appModel.preferences.preferredIntelligenceProvider.subtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    Toggle("Allow automatic fallback", isOn: modelFallbackBinding)

                    Text(
                        appModel.preferences.allowModelFallbacks
                        ? "If the selected model is unavailable, Before can fall back to another local provider before dropping to deterministic copy."
                        : "If the selected model is unavailable, Before will skip other model providers and go straight to deterministic local copy."
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }

                Section("Runtime") {
                    LabeledContent("Preferred provider", value: appModel.intelligenceRuntimeStatus.preferred.title)
                    LabeledContent("Active provider", value: appModel.intelligenceRuntimeStatus.active.title)

                    if let fallback = appModel.intelligenceRuntimeStatus.fallback {
                        LabeledContent("Fallback provider", value: fallback.title)
                    }

                    Text(appModel.intelligenceRuntimeStatus.detail)
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    LabeledContent("Gemma provider", value: appModel.gemmaModelStatus.title)
                    Text(appModel.gemmaModelStatus.detail)
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    LabeledContent("Gemma bundle", value: appModel.gemmaBundleStatus.title)
                    Text(appModel.gemmaBundleStatus.detail)
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    LabeledContent("Gemma runtime", value: appModel.gemmaRuntimeStatus.title)
                    Text(appModel.gemmaRuntimeStatus.detail)
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    if let gemmaAsset = appModel.gemmaBundledAsset {
                        LabeledContent("Bundled asset", value: gemmaAsset.fileName)
                        LabeledContent("Bundled size", value: gemmaAsset.displaySize)
                    }

                    LabeledContent("Apple model", value: appModel.foundationModelStatus.title)
                    Text(appModel.foundationModelStatus.detail)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Developer actions") {
                    Button("Preview Let Go finish-state") {
                        appModel.presentDeveloperLetGoPreview()
                    }
                }

                Section("Decision Replay") {
                    if replayEntries.isEmpty {
                        Text("No saved decisions yet. Once you complete a quick, balance, or mirror flow, the latest entries will show up here with any linked model trace.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(replayEntries) { entry in
                            NavigationLink {
                                DeveloperDecisionReplayDetailView(entry: entry)
                                    .environmentObject(appModel)
                            } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Label(entry.mode.shortTitle, systemImage: entry.mode.symbolName)
                                            .font(.subheadline.weight(.semibold))
                                        Spacer()
                                        Text(entry.timestamp, style: .relative)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }

                                    Text(entry.title)
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(BeforeTheme.ink)
                                        .lineLimit(2)

                                    Text(entry.subtitle)
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)

                                    HStack(spacing: 10) {
                                        Text(entry.statusTitle)
                                            .font(.caption.weight(.medium))
                                            .foregroundStyle(BeforeTheme.ember)
                                        Text(entry.trace?.activeProvider?.title ?? "No linked model trace")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }

                Section("Prompt Inspector") {
                    if debugStore.traces.isEmpty {
                        Text("No model refinement traces yet. Run a quick, balance, or mirror flow to inspect the latest prompt and provider path.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(debugStore.traces) { trace in
                            NavigationLink {
                                DecisionTraceDetailView(trace: trace)
                            } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Text(trace.kind.title)
                                            .font(.subheadline.weight(.semibold))
                                        Spacer()
                                        Text(trace.activeProvider?.title ?? "Deterministic")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }

                                    Text(trace.detail)
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)

                                    Text(trace.outputPreview)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                                .padding(.vertical, 4)
                            }
                        }

                        Button("Clear traces", role: .destructive) {
                            debugStore.clear()
                        }
                    }
                }

                Section("Notes") {
                    Text("This window keeps model routing and runtime diagnostics out of the main user-facing settings flow.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .scrollContentBackground(.hidden)
            .background(BeforeBackground())
            .navigationTitle("Developer Center")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var preferredProviderBinding: Binding<DecisionModelProviderPreference> {
        Binding(
            get: { appModel.preferences.preferredIntelligenceProvider },
            set: { newValue in
                appModel.updatePreferences { $0.preferredIntelligenceProvider = newValue }
            }
        )
    }

    private var modelFallbackBinding: Binding<Bool> {
        Binding(
            get: { appModel.preferences.allowModelFallbacks },
            set: { newValue in
                appModel.updatePreferences { $0.allowModelFallbacks = newValue }
            }
        )
    }

    private var replayEntries: [DeveloperDecisionReplayEntry] {
        DeveloperDecisionReplayBuilder.build(
            quick: events,
            balance: balanceBoards,
            mirror: mirrorRecords,
            traces: debugStore.traces
        )
    }
}
