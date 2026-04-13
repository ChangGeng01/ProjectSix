import SwiftUI

enum DecisionEvolutionReleaseSummaryPresentationMode: Equatable, Sendable {
    case surface
    case compact
    case mutationHub

    var showsCheckpointHeadlines: Bool {
        switch self {
        case .surface:
            true
        case .compact, .mutationHub:
            false
        }
    }

    var operatorHeadline: String? {
        switch self {
        case .mutationHub:
            "Mutation hub"
        case .surface, .compact:
            nil
        }
    }

    var operatorDetail: String? {
        switch self {
        case .mutationHub:
            "Release readiness is summarized once here. Apply, approve, rollback, and lineage-clearing actions live in the mutation workspace below."
        case .surface, .compact:
            nil
        }
    }
}

struct DecisionEvolutionReleaseSummaryView: View {
    let releaseSummary: DecisionSystemReleaseControlSummary
    let controlSurface: DecisionEvolutionControlSurface
    let presentationMode: DecisionEvolutionReleaseSummaryPresentationMode

    init(
        releaseSummary: DecisionSystemReleaseControlSummary,
        controlSurface: DecisionEvolutionControlSurface,
        presentationMode: DecisionEvolutionReleaseSummaryPresentationMode = .surface
    ) {
        self.releaseSummary = releaseSummary
        self.controlSurface = controlSurface
        self.presentationMode = presentationMode
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                DecisionEvolutionSummaryBadge(
                    title: releaseSummary.state.title.uppercased(),
                    tint: releaseTint(releaseSummary.state)
                )
                DecisionEvolutionSummaryBadge(
                    title: "\(releaseSummary.pendingReviewCount) PENDING",
                    tint: releaseSummary.pendingReviewCount > 0 ? .orange : .secondary
                )
                DecisionEvolutionSummaryBadge(
                    title: "\(releaseSummary.rollbackReadyCount) ROLLBACK READY",
                    tint: releaseSummary.rollbackReadyCount > 0 ? BeforeTheme.moss : .secondary
                )
            }

            Text(releaseSummary.headline)
                .font(.caption.weight(.semibold))
                .foregroundStyle(releaseTint(releaseSummary.state))

            if let reason = releaseSummary.reasons.first {
                Text(reason)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            if presentationMode.showsCheckpointHeadlines {
                if let activePresentation = controlSurface.activePresentation {
                    Text("Active: \(activePresentation.checkpointID) • \(activePresentation.approvalStateTitle) • \(activePresentation.summaryText)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                if let reviewPresentation = controlSurface.spotlightReviewPresentation {
                    Text("Review head: \(reviewPresentation.checkpointID) • \(reviewPresentation.approvalStateTitle) • \(reviewPresentation.summaryText)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            if !releaseSummary.killSwitches.isEmpty {
                Text("Kill switches: \(releaseSummary.killSwitches.joined(separator: " • "))")
                    .font(.caption2)
                    .foregroundStyle(releaseTint(releaseSummary.state))
                    .lineLimit(3)
            }

            if let operatorHeadline = presentationMode.operatorHeadline,
               let operatorDetail = presentationMode.operatorDetail {
                VStack(alignment: .leading, spacing: 4) {
                    Text(operatorHeadline)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(BeforeTheme.ember)
                    Text(operatorDetail)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func releaseTint(_ state: DecisionSystemReleaseState) -> Color {
        switch state {
        case .ready:
            BeforeTheme.moss
        case .watch:
            BeforeTheme.ember
        case .blocked:
            .red
        }
    }
}
