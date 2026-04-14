import SwiftUI

struct DecisionSessionEngineSessionDigestView: View {
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

    init(
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
        detailLine: String? = nil
    ) {
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
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let healthSummary {
                DecisionSessionEngineHealthSummaryView(summary: healthSummary)
            }

            Text(checkpointLine)
                .font(.caption2)
                .foregroundStyle(.secondary)

            if let checkpointBudgetLine {
                Text(checkpointBudgetLine)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            if let checkpointDecisionLine {
                Text(checkpointDecisionLine)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            if let checkpointTaskLine {
                Text(checkpointTaskLine)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            if let checkpointActionLine {
                Text(checkpointActionLine)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            if let activityLine {
                Text(activityLine)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Text(branchLine)
                .font(.caption2)
                .foregroundStyle(.secondary)

            if let mergeReviewLine {
                Text(mergeReviewLine)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Text(recoveryLine)
                .font(.caption2)
                .foregroundStyle(.secondary)

            if let faultLine,
               healthSummary?.detail != faultLine {
                Text(faultLine)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(BeforeTheme.ember)
            }

            if let stepFreshnessLine,
               healthSummary?.detail != stepFreshnessLine {
                Text(stepFreshnessLine)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if let stepAlertLine,
               healthSummary?.detail != stepAlertLine {
                Text(stepAlertLine)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(BeforeTheme.ember)
            }

            if let detailLine {
                Text(detailLine)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
    }
}
