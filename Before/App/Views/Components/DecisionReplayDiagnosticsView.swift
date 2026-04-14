import SwiftUI

struct DecisionReplayDiagnosticsView: View {
    let presentation: DecisionEvolutionReplayEntryPresentation

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(presentation.sourceTitle)
                .font(.caption.weight(.semibold))
                .foregroundStyle(BeforeTheme.ember)

            Text(presentation.summaryLine)
                .font(.subheadline)
                .foregroundStyle(BeforeTheme.ink)

            if let budgetLine = presentation.budgetLine {
                Text(budgetLine)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let eBrainLine = presentation.eBrainLine {
                Text(eBrainLine)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let taskLine = presentation.taskLine {
                Text(taskLine)
                    .font(.caption)
                    .foregroundStyle(BeforeTheme.ember)
            }

            if let actionLine = presentation.actionLine {
                Text(actionLine)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if let auditLine = presentation.auditLine {
                Text(auditLine)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if let activeKillSwitchesLine = presentation.activeKillSwitchesLine {
                Text(activeKillSwitchesLine)
                    .font(.caption2)
                    .foregroundStyle(BeforeTheme.ember)
            }

            if let killSwitchesLine = presentation.killSwitchesLine {
                Text(killSwitchesLine)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if let traceLine = presentation.traceLine {
                Text(traceLine)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
