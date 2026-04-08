import SwiftUI

struct DeveloperDecisionReplayDetailView: View {
    @EnvironmentObject private var appModel: BeforeAppModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedHistoryDetail: HistoryDetailSelection?

    let entry: DeveloperDecisionReplayEntry

    var body: some View {
        ZStack {
            BeforeBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    SectionHeader(
                        eyebrow: "Decision Replay",
                        title: entry.title,
                        subtitle: entry.subtitle
                    )

                    PanelCard {
                        VStack(alignment: .leading, spacing: 12) {
                            detailPair("Mode", entry.mode.title)
                            detailPair("Saved", relativeTimestamp)
                            detailPair("Entry source", entry.entrySource.label)
                            detailPair("Replay status", entry.statusTitle)
                            detailPair("Summary", entry.summaryLine)
                        }
                    }

                    PanelCard {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Decision snapshot")
                                .font(.headline)
                                .foregroundStyle(BeforeTheme.ink)

                            snapshotView
                        }
                    }

                    if let trace = entry.trace {
                        PanelCard {
                            VStack(alignment: .leading, spacing: 14) {
                                Text("Linked model trace")
                                    .font(.headline)
                                    .foregroundStyle(BeforeTheme.ink)

                                detailPair("Preferred", trace.preferredProvider.title)
                                detailPair("Active", trace.activeProvider?.title ?? "Deterministic fallback")
                                detailPair("Attempted", trace.attemptedProviders.map(\.title).joined(separator: " → "))
                                detailPair("Path", trace.usedFallback ? "Used fallback path" : "Used preferred path")

                                Text(trace.outputPreview)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)

                                NavigationLink {
                                    DecisionTraceDetailView(trace: trace)
                                } label: {
                                    Label("Open full trace", systemImage: "waveform.path.ecg.text")
                                        .font(.subheadline.weight(.medium))
                                }
                            }
                        }
                    }

                    PanelCard {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Developer actions")
                                .font(.headline)
                                .foregroundStyle(BeforeTheme.ink)

                            Text("Reopened decisions will be ready in the main app as soon as you leave Developer Center.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)

                            BeforeActionButton("Inspect full detail", style: .secondary) {
                                selectedHistoryDetail = detailSelection
                            }

                            DecisionContinuationActions(
                                reopenTitle: reopenTitle,
                                reopenAction: {
                                    reopenDecision()
                                    dismiss()
                                },
                                postponeAction: {
                                    moveToTomorrow()
                                    dismiss()
                                }
                            )
                        }
                    }
                }
                .padding(20)
            }
        }
        .navigationTitle("Replay")
        .sheet(item: $selectedHistoryDetail) { selection in
            HistoryDetailView(selection: selection)
                .environmentObject(appModel)
        }
    }

    @ViewBuilder
    private var snapshotView: some View {
        switch entry.record {
        case .quick(let event):
            Group {
                detailPair("Scenario", event.scenario.title)
                detailPair("Verdict", event.verdict.title)
                detailPair("Why now", event.motivation.title)
                detailPair("Usually after", event.expectedOutcome.title)
                detailPair("Pull-back", event.controlLevel.title)
                if !trimmed(event.note).isEmpty {
                    detailPair("Note", event.note)
                }
                if let reflection = event.reflectionOutcome {
                    detailPair("Reflection", reflection.title)
                }
            }

        case .balance(let record):
            Group {
                detailPair("What you want", record.desire)
                detailPair("What you protect", record.concern)
                detailPair("Reality", record.constraint)
                detailPair("Long-term", record.longTerm)
                detailPair("Focus", record.focusTitle)
                detailPair("Next action", record.nextAction)
            }

        case .mirror(let record):
            Group {
                detailPair("Emotion", record.emotion)
                detailPair("Relationship", record.relationship)
                detailPair("Reality", record.reality)
                detailPair("Long-term", record.longTerm)
                detailPair("Self", record.selfLens)
                detailPair("Core tension", record.coreTension)
                detailPair("Mirror action", record.nextActionTitle)
                detailPair("Next step", record.nextAction)
            }
        }
    }

    @ViewBuilder
    private func detailPair(_ title: String, _ value: String) -> some View {
        if !trimmed(value).isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(BeforeTheme.ember)
                Text(value)
                    .font(.subheadline)
                    .foregroundStyle(BeforeTheme.ink)
                    .multilineTextAlignment(.leading)
            }
        }
    }

    private var relativeTimestamp: String {
        entry.timestamp.formatted(.relative(presentation: .named))
    }

    private var detailSelection: HistoryDetailSelection {
        switch entry.record {
        case .quick(let event):
            .quick(event)
        case .balance(let record):
            .balance(record)
        case .mirror(let record):
            .mirror(record)
        }
    }

    private var reopenTitle: String {
        switch entry.record.mode {
        case .quick:
            "Reopen this check"
        case .balance:
            "Reopen this board"
        case .mirror:
            "Reopen this mirror"
        }
    }

    private func reopenDecision() {
        switch entry.record {
        case .quick(let event):
            appModel.reopenCheckEvent(event)
        case .balance(let record):
            appModel.reopenBalanceRecord(record)
        case .mirror(let record):
            appModel.reopenMirrorRecord(record)
        }
    }

    private func moveToTomorrow() {
        switch entry.record {
        case .quick(let event):
            appModel.moveCheckEventToTomorrow(event)
        case .balance(let record):
            appModel.moveBalanceRecordToTomorrow(record)
        case .mirror(let record):
            appModel.moveMirrorRecordToTomorrow(record)
        }
    }
}

private func trimmed(_ value: String) -> String {
    value.trimmingCharacters(in: .whitespacesAndNewlines)
}
