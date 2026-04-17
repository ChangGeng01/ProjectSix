import SwiftUI

struct DecisionEvolutionCheckpointLineageDetailsView: View {
    let summaryText: String
    let summaryColor: Color
    let metadataText: String?
    let ticketsLine: String?
    let auditLine: String?
    let killSwitchesLine: String?

    init(
        summaryText: String,
        summaryColor: Color = BeforeTheme.ember,
        metadataText: String? = nil,
        ticketsLine: String? = nil,
        auditLine: String? = nil,
        killSwitchesLine: String? = nil
    ) {
        self.summaryText = summaryText
        self.summaryColor = summaryColor
        self.metadataText = metadataText
        self.ticketsLine = ticketsLine
        self.auditLine = auditLine
        self.killSwitchesLine = killSwitchesLine
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(summaryText)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(summaryColor)

            if let metadataText {
                Text(metadataText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if let ticketsLine {
                Text(ticketsLine)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if let auditLine {
                Text(auditLine)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if let killSwitchesLine {
                Text(killSwitchesLine)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
