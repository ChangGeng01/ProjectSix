import SwiftUI

struct DecisionEvolutionCheckpointLineageDetailsView: View {
    let summaryText: String
    let summaryColor: Color
    let metadataText: String?
    let ticketSummaries: [String]
    let auditFindings: [String]
    let killSwitches: [String]

    init(
        summaryText: String,
        summaryColor: Color = BeforeTheme.ember,
        metadataText: String? = nil,
        ticketSummaries: [String] = [],
        auditFindings: [String] = [],
        killSwitches: [String] = []
    ) {
        self.summaryText = summaryText
        self.summaryColor = summaryColor
        self.metadataText = metadataText
        self.ticketSummaries = ticketSummaries
        self.auditFindings = auditFindings
        self.killSwitches = killSwitches
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

            if !ticketSummaries.isEmpty {
                Text("Tickets: \(ticketSummaries.joined(separator: " • "))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if !auditFindings.isEmpty {
                Text("Audit: \(auditFindings.joined(separator: " • "))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if !killSwitches.isEmpty {
                Text("Kill switches: \(killSwitches.joined(separator: " • "))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
