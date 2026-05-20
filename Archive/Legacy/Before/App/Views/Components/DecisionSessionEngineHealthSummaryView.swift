import SwiftUI

struct DecisionSessionEngineHealthSummaryView: View {
    let summary: DecisionSessionEngineHealthSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(summary.title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(severityColor)

            Text(summary.detail)
                .font(.caption2)
                .foregroundStyle(severityColor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(severityColor.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(severityColor.opacity(0.18), lineWidth: 1)
        )
    }

    private var severityColor: Color {
        switch summary.severity {
        case .stable:
            BeforeTheme.ink
        case .watch, .critical:
            BeforeTheme.ember
        }
    }
}
