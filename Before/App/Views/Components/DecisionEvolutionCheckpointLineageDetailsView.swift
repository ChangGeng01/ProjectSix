import SwiftUI

struct DecisionEvolutionCheckpointLineageDetailsView: View {
    let summaryText: String
    let summaryColor: Color
    let metadataText: String?
    let foldedLungTitle: String?
    let foldedLungLines: [String]
    let ticketsLine: String?
    let auditLine: String?
    let killSwitchesLine: String?

    init(
        summaryText: String,
        summaryColor: Color = BeforeTheme.ember,
        metadataText: String? = nil,
        foldedLungTitle: String? = nil,
        foldedLungLines: [String] = [],
        ticketsLine: String? = nil,
        auditLine: String? = nil,
        killSwitchesLine: String? = nil
    ) {
        self.summaryText = summaryText
        self.summaryColor = summaryColor
        self.metadataText = metadataText
        self.foldedLungTitle = foldedLungTitle
        self.foldedLungLines = foldedLungLines
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

            if let foldedLungTitle,
               !foldedLungLines.isEmpty {
                VStack(alignment: .leading, spacing: 3) {
                    Text(foldedLungTitle)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.blue)

                    ForEach(foldedLungLines, id: \.self) { line in
                        Text(line)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
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
