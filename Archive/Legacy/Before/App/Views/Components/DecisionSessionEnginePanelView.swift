import SwiftUI

struct DecisionSessionEnginePanelView: View {
    let presentation: DecisionSessionEnginePresentation
    let showsTitle: Bool
    let maxRecentSessions: Int

    init(
        presentation: DecisionSessionEnginePresentation,
        showsTitle: Bool = true,
        maxRecentSessions: Int = 2
    ) {
        self.presentation = presentation
        self.showsTitle = showsTitle
        self.maxRecentSessions = maxRecentSessions
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if showsTitle {
                Text(presentation.title)
                    .font(.headline)
            }

            Text(presentation.headline)
                .font(.footnote)
                .foregroundStyle(.secondary)

            Text(presentation.countsLine)
                .font(.caption)
                .foregroundStyle(.secondary)

            if let healthSummary = presentation.healthSummary {
                DecisionSessionEngineHealthSummaryView(summary: healthSummary)
            } else if let healthLine = presentation.healthLine {
                Text(healthLine)
                    .font(.caption2)
                    .foregroundStyle(BeforeTheme.ember)
            }

            DecisionSessionEngineReviewSurfaceView(
                items: presentation.reviewItems,
                pendingImportPreview: presentation.pendingImportPreview
            )

            if let activeSession = presentation.activeSession {
                sessionBlock(
                    label: "Active session",
                    session: activeSession
                )
            } else if presentation.pendingImportPreview == nil && presentation.recentSessions.isEmpty {
                Text(presentation.emptyMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if !presentation.recentSessions.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Recent recovery line")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    ForEach(presentation.recentSessions.prefix(maxRecentSessions)) { session in
                        sessionBlock(
                            label: "Recent",
                            session: session
                        )
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func sessionBlock(
        label: String,
        session: DecisionSessionEngineSessionPresentation
    ) -> some View {
        DecisionSessionEngineSessionSummaryView(
            title: session.title,
            healthSummary: session.healthSummary,
            checkpointLine: session.checkpointLine,
            checkpointBudgetLine: session.checkpointBudgetLine,
            checkpointDecisionLine: session.checkpointDecisionLine,
            checkpointTaskLine: session.checkpointTaskLine,
            checkpointWindGateLine: session.checkpointWindGateLine,
            checkpointPresenceLine: session.checkpointPresenceLine,
            checkpointPressureLine: session.checkpointPressureLine,
            checkpointRiskFactorsLine: session.checkpointRiskFactorsLine,
            checkpointReasonCodesLine: session.checkpointReasonCodesLine,
            checkpointCourtLine: session.checkpointCourtLine,
            checkpointAuditLine: session.checkpointAuditLine,
            checkpointSovereignVerdictLine: session.checkpointSovereignVerdictLine,
            checkpointSovereignAuthorityLine: session.checkpointSovereignAuthorityLine,
            checkpointSovereignAuditLine: session.checkpointSovereignAuditLine,
            checkpointKillSwitchesLine: session.checkpointKillSwitchesLine,
            checkpointActionLine: session.checkpointActionLine,
            checkpointMorphLine: session.morphLine,
            checkpointLungLine: session.lungLine,
            checkpointHotColdLine: session.hotColdLine,
            checkpointPrecisionLine: session.precisionLine,
            checkpointOrganPackageLine: session.organPackageLine,
            checkpointOrganDeltaLine: session.organDeltaLine,
            checkpointSchedulerLine: session.schedulerLine,
            checkpointThermalExchangeLine: session.thermalExchangeLine,
            checkpointIntegrityWeaveLine: session.integrityWeaveLine,
            checkpointResumeLine: session.resumeLine,
            checkpointRollbackLine: session.rollbackLine,
            checkpointSovereignBridgeLine: session.sovereignBridgeLine,
            checkpointSovereignBridgeDetailLines: session.sovereignBridgeDetailLines,
            activityLine: session.activityLine,
            branchLine: session.branchLine,
            mergeReviewLine: session.mergeReviewLine,
            recoveryLine: session.recoveryLine,
            stepFreshnessLine: session.stepFreshnessLine,
            stepAlertLine: session.stepAlertLine,
            detailLine: session.detailLine
        ) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(label)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                if session.isActive {
                    Text("Head")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(BeforeTheme.ember)
                }
            }
        }
        .padding(.vertical, 2)
    }
}
