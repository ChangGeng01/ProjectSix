import SwiftUI

struct DecisionSessionEngineSessionSummaryView<Header: View, Footer: View>: View {
    let title: String
    let healthSummary: DecisionSessionEngineHealthSummary?
    let checkpointLine: String
    let checkpointBudgetLine: String?
    let checkpointDecisionLine: String?
    let checkpointTaskLine: String?
    let checkpointActionLine: String?
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
        checkpointActionLine: String? = nil,
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
        self.checkpointActionLine = checkpointActionLine
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
                checkpointActionLine: checkpointActionLine,
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
