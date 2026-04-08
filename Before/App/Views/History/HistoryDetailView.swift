import SwiftUI

enum HistoryDetailSelection: Identifiable {
    case quick(CheckEvent)
    case balance(BalanceDecisionRecord)
    case mirror(MirrorDecisionRecord)

    var id: String {
        switch self {
        case .quick(let event): "quick-\(event.id.uuidString)"
        case .balance(let record): "balance-\(record.id.uuidString)"
        case .mirror(let record): "mirror-\(record.id.uuidString)"
        }
    }
}

struct HistoryDetailView: View {
    @EnvironmentObject private var appModel: BeforeAppModel
    @Environment(\.dismiss) private var dismiss

    let selection: HistoryDetailSelection

    var body: some View {
        NavigationStack {
            ZStack {
                BeforeBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        switch selection {
                        case .quick(let event):
                            quickDetail(event)
                        case .balance(let record):
                            balanceDetail(record)
                        case .mirror(let record):
                            mirrorDetail(record)
                        }
                    }
                    .padding(20)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private func quickDetail(_ event: CheckEvent) -> some View {
        SectionHeader(
            eyebrow: "Quick check",
            title: event.currentPerspective,
            subtitle: event.afterPerspective
        )

        PanelCard {
            VStack(alignment: .leading, spacing: 12) {
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

                if let reflectionNote = event.reflectionNote, !trimmed(reflectionNote).isEmpty {
                    detailPair("After note", reflectionNote)
                }
            }
        }

        DecisionContinuationActions(
            reopenTitle: "Reopen this check",
            reopenAction: {
                appModel.reopenCheckEvent(event)
                dismiss()
            },
            postponeAction: {
                appModel.moveCheckEventToTomorrow(event)
                dismiss()
            }
        )
    }

    @ViewBuilder
    private func balanceDetail(_ record: BalanceDecisionRecord) -> some View {
        SectionHeader(
            eyebrow: "Balance board",
            title: record.prompt,
            subtitle: record.focusSummary
        )

        PanelCard {
            VStack(alignment: .leading, spacing: 12) {
                detailPair("What you want", record.desire)
                detailPair("What you protect", record.concern)
                detailPair("Reality", record.constraint)
                detailPair("Long-term", record.longTerm)
                detailPair("Focus", record.focusTitle)
                detailPair("Next action", record.nextAction)
            }
        }

        DecisionContinuationActions(
            reopenTitle: "Reopen this board",
            reopenAction: {
                appModel.reopenBalanceRecord(record)
                dismiss()
            },
            postponeAction: {
                appModel.moveBalanceRecordToTomorrow(record)
                dismiss()
            }
        )
    }

    @ViewBuilder
    private func mirrorDetail(_ record: MirrorDecisionRecord) -> some View {
        SectionHeader(
            eyebrow: "Mirror",
            title: record.prompt,
            subtitle: record.coreTension
        )

        PanelCard {
            VStack(alignment: .leading, spacing: 12) {
                detailPair("Emotion", record.emotion)
                detailPair("Relationship", record.relationship)
                detailPair("Reality", record.reality)
                detailPair("Long-term", record.longTerm)
                detailPair("Self", record.selfLens)
                detailPair("Mirror action", record.nextActionTitle)
                detailPair("Next step", record.nextAction)
            }
        }

        DecisionContinuationActions(
            reopenTitle: "Reopen this mirror",
            reopenAction: {
                appModel.reopenMirrorRecord(record)
                dismiss()
            },
            postponeAction: {
                appModel.moveMirrorRecordToTomorrow(record)
                dismiss()
            }
        )
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
            }
        }
    }
}

private func trimmed(_ value: String) -> String {
    value.trimmingCharacters(in: .whitespacesAndNewlines)
}
