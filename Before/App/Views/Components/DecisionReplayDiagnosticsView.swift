import SwiftUI

struct DecisionReplayDiagnosticsView: View {
    enum Layout {
        case full
        case compact
    }

    let presentation: DecisionEvolutionReplayEntryPresentation
    var layout: Layout = .full
    var showsHeader: Bool = true
    var excludesOverviewSummary: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if layout == .full, showsHeader {
                headerContent
            }

            ForEach(diagnosticLines, id: \.text) { line in
                lineView(line)
            }
        }
    }

    @ViewBuilder
    private var headerContent: some View {
        let headerCopy = presentation.diagnosticsHeaderCopy

        Text(headerCopy.eyebrowLine)
            .font(.caption.weight(.semibold))
            .foregroundStyle(BeforeTheme.ember)

        if let statusLine = headerCopy.statusLine {
            Text(statusLine)
                .font(.caption.weight(.semibold))
                .foregroundStyle(BeforeTheme.ember)
        }

        Text(headerCopy.titleLine)
            .font(.subheadline)
            .foregroundStyle(BeforeTheme.ink)

        ForEach(headerCopy.detailLines, id: \.self) { line in
            Text(line)
                .font(.caption)
                .foregroundStyle(.secondary)
        }

        if !presentation.furnaceContributionLines.isEmpty {
            Text("Furnace fabric")
                .font(.caption.weight(.semibold))
                .foregroundStyle(BeforeTheme.moss)

            ForEach(presentation.furnaceContributionLines, id: \.self) { line in
                Text(line)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func lineView(_ line: DecisionEvolutionReplayDiagnosticLine) -> some View {
        switch line.kind {
        case .operations, .budget:
            Text(line.text)
                .font(.caption)
                .foregroundStyle(.secondary)
        case .pressure, .action, .audit, .killSwitches, .trace, .riskFactors, .reasonCodes, .court:
            Text(line.text)
                .font(.caption2)
                .foregroundStyle(.secondary)
        case .eBrain, .cognition, .mirrorCalibration, .foldedLung, .organDelta, .scheduler, .hotCold, .resume, .rollback, .sovereignBridge:
            Text(line.text)
                .font(.caption)
                .foregroundStyle(.secondary)
        case .task:
            Text(line.text)
                .font(.caption)
                .foregroundStyle(BeforeTheme.ember)
        case .activeKillSwitches:
            Text(line.text)
                .font(.caption2)
                .foregroundStyle(BeforeTheme.ember)
        }
    }

    private var diagnosticLines: [DecisionEvolutionReplayDiagnosticLine] {
        switch layout {
        case .full:
            presentation.fullDiagnosticsLines(
                excludingHeaderSummary: showsHeader,
                excludingOverviewSummary: excludesOverviewSummary
            )
        case .compact:
            presentation.compactDiagnosticsLines
        }
    }
}
