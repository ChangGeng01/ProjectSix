import SwiftUI

struct DecisionSessionEngineSessionSummaryView<Header: View, Footer: View>: View {
    let title: String
    let healthSummary: DecisionSessionEngineHealthSummary?
    let checkpointLine: String
    let checkpointBudgetLine: String?
    let checkpointDecisionLine: String?
    let checkpointTaskLine: String?
    let checkpointPressureLine: String?
    let checkpointRiskFactorsLine: String?
    let checkpointReasonCodesLine: String?
    let checkpointAuditLine: String?
    let checkpointSovereignVerdictLine: String?
    let checkpointSovereignAuthorityLine: String?
    let checkpointSovereignAuditLine: String?
    let checkpointKillSwitchesLine: String?
    let checkpointActionLine: String?
    let checkpointLungLine: String?
    let checkpointHotColdLine: String?
    let checkpointResumeLine: String?
    let checkpointRollbackLine: String?
    let checkpointSovereignBridgeLine: String?
    let checkpointSovereignBridgeDetailLines: [String]
    let activityLine: String?
    let branchLine: String
    let mergeReviewLine: String?
    let recoveryLine: String
    let faultLine: String?
    let stepFreshnessLine: String?
    let stepAlertLine: String?
    let detailLine: String?
    @ViewBuilder let header: () -> Header
    @ViewBuilder let footer: () -> Footer

    init(
        title: String,
        healthSummary: DecisionSessionEngineHealthSummary?,
        checkpointLine: String,
        checkpointBudgetLine: String? = nil,
        checkpointDecisionLine: String? = nil,
        checkpointTaskLine: String? = nil,
        checkpointPressureLine: String? = nil,
        checkpointRiskFactorsLine: String? = nil,
        checkpointReasonCodesLine: String? = nil,
        checkpointAuditLine: String? = nil,
        checkpointSovereignVerdictLine: String? = nil,
        checkpointSovereignAuthorityLine: String? = nil,
        checkpointSovereignAuditLine: String? = nil,
        checkpointKillSwitchesLine: String? = nil,
        checkpointActionLine: String? = nil,
        checkpointLungLine: String? = nil,
        checkpointHotColdLine: String? = nil,
        checkpointResumeLine: String? = nil,
        checkpointRollbackLine: String? = nil,
        checkpointSovereignBridgeLine: String? = nil,
        checkpointSovereignBridgeDetailLines: [String] = [],
        activityLine: String? = nil,
        branchLine: String,
        mergeReviewLine: String? = nil,
        recoveryLine: String,
        faultLine: String? = nil,
        stepFreshnessLine: String? = nil,
        stepAlertLine: String? = nil,
        detailLine: String? = nil,
        @ViewBuilder header: @escaping () -> Header,
        @ViewBuilder footer: @escaping () -> Footer = { EmptyView() }
    ) {
        self.title = title
        self.healthSummary = healthSummary
        self.checkpointLine = checkpointLine
        self.checkpointBudgetLine = checkpointBudgetLine
        self.checkpointDecisionLine = checkpointDecisionLine
        self.checkpointTaskLine = checkpointTaskLine
        self.checkpointPressureLine = checkpointPressureLine
        self.checkpointRiskFactorsLine = checkpointRiskFactorsLine
        self.checkpointReasonCodesLine = checkpointReasonCodesLine
        self.checkpointAuditLine = checkpointAuditLine
        self.checkpointSovereignVerdictLine = checkpointSovereignVerdictLine
        self.checkpointSovereignAuthorityLine = checkpointSovereignAuthorityLine
        self.checkpointSovereignAuditLine = checkpointSovereignAuditLine
        self.checkpointKillSwitchesLine = checkpointKillSwitchesLine
        self.checkpointActionLine = checkpointActionLine
        self.checkpointLungLine = checkpointLungLine
        self.checkpointHotColdLine = checkpointHotColdLine
        self.checkpointResumeLine = checkpointResumeLine
        self.checkpointRollbackLine = checkpointRollbackLine
        self.checkpointSovereignBridgeLine = checkpointSovereignBridgeLine
        self.checkpointSovereignBridgeDetailLines = checkpointSovereignBridgeDetailLines
        self.activityLine = activityLine
        self.branchLine = branchLine
        self.mergeReviewLine = mergeReviewLine
        self.recoveryLine = recoveryLine
        self.faultLine = faultLine
        self.stepFreshnessLine = stepFreshnessLine
        self.stepAlertLine = stepAlertLine
        self.detailLine = detailLine
        self.header = header
        self.footer = footer
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            header()

            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(BeforeTheme.ink)

            DecisionSessionEngineSessionDigestView(
                healthSummary: healthSummary,
                checkpointLine: checkpointLine,
                checkpointBudgetLine: checkpointBudgetLine,
                checkpointDecisionLine: checkpointDecisionLine,
                checkpointTaskLine: checkpointTaskLine,
                checkpointPressureLine: checkpointPressureLine,
                checkpointRiskFactorsLine: checkpointRiskFactorsLine,
                checkpointReasonCodesLine: checkpointReasonCodesLine,
                checkpointAuditLine: checkpointAuditLine,
                checkpointSovereignVerdictLine: checkpointSovereignVerdictLine,
                checkpointSovereignAuthorityLine: checkpointSovereignAuthorityLine,
                checkpointSovereignAuditLine: checkpointSovereignAuditLine,
                checkpointKillSwitchesLine: checkpointKillSwitchesLine,
                checkpointActionLine: checkpointActionLine,
                checkpointLungLine: checkpointLungLine,
                checkpointHotColdLine: checkpointHotColdLine,
                checkpointResumeLine: checkpointResumeLine,
                checkpointRollbackLine: checkpointRollbackLine,
                checkpointSovereignBridgeLine: checkpointSovereignBridgeLine,
                checkpointSovereignBridgeDetailLines: checkpointSovereignBridgeDetailLines,
                activityLine: activityLine,
                branchLine: branchLine,
                mergeReviewLine: mergeReviewLine,
                recoveryLine: recoveryLine,
                faultLine: faultLine,
                stepFreshnessLine: stepFreshnessLine,
                stepAlertLine: stepAlertLine,
                detailLine: detailLine
            )

            footer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
