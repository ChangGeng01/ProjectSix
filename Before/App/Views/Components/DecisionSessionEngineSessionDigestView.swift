import SwiftUI

struct DecisionSessionEngineSessionDigestView: View {
    let healthSummary: DecisionSessionEngineHealthSummary?
    let checkpointLine: String
    let checkpointBudgetLine: String?
    let checkpointDecisionLine: String?
    let checkpointTaskLine: String?
    let checkpointWindGateLine: String?
    let checkpointPresenceLine: String?
    let checkpointPressureLine: String?
    let checkpointRiskFactorsLine: String?
    let checkpointReasonCodesLine: String?
    let checkpointCourtLine: String?
    let checkpointAuditLine: String?
    let checkpointSovereignVerdictLine: String?
    let checkpointSovereignAuthorityLine: String?
    let checkpointSovereignAuditLine: String?
    let checkpointKillSwitchesLine: String?
    let checkpointActionLine: String?
    let checkpointMorphLine: String?
    let checkpointLungLine: String?
    let checkpointHotColdLine: String?
    let checkpointPrecisionLine: String?
    let checkpointOrganPackageLine: String?
    let checkpointOrganDeltaLine: String?
    let checkpointSchedulerLine: String?
    let checkpointThermalExchangeLine: String?
    let checkpointIntegrityWeaveLine: String?
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

    init(
        healthSummary: DecisionSessionEngineHealthSummary?,
        checkpointLine: String,
        checkpointBudgetLine: String? = nil,
        checkpointDecisionLine: String? = nil,
        checkpointTaskLine: String? = nil,
        checkpointWindGateLine: String? = nil,
        checkpointPresenceLine: String? = nil,
        checkpointPressureLine: String? = nil,
        checkpointRiskFactorsLine: String? = nil,
        checkpointReasonCodesLine: String? = nil,
        checkpointCourtLine: String? = nil,
        checkpointAuditLine: String? = nil,
        checkpointSovereignVerdictLine: String? = nil,
        checkpointSovereignAuthorityLine: String? = nil,
        checkpointSovereignAuditLine: String? = nil,
        checkpointKillSwitchesLine: String? = nil,
        checkpointActionLine: String? = nil,
        checkpointMorphLine: String? = nil,
        checkpointLungLine: String? = nil,
        checkpointHotColdLine: String? = nil,
        checkpointPrecisionLine: String? = nil,
        checkpointOrganPackageLine: String? = nil,
        checkpointOrganDeltaLine: String? = nil,
        checkpointSchedulerLine: String? = nil,
        checkpointThermalExchangeLine: String? = nil,
        checkpointIntegrityWeaveLine: String? = nil,
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
        detailLine: String? = nil
    ) {
        self.healthSummary = healthSummary
        self.checkpointLine = checkpointLine
        self.checkpointBudgetLine = checkpointBudgetLine
        self.checkpointDecisionLine = checkpointDecisionLine
        self.checkpointTaskLine = checkpointTaskLine
        self.checkpointWindGateLine = checkpointWindGateLine
        self.checkpointPresenceLine = checkpointPresenceLine
        self.checkpointPressureLine = checkpointPressureLine
        self.checkpointRiskFactorsLine = checkpointRiskFactorsLine
        self.checkpointReasonCodesLine = checkpointReasonCodesLine
        self.checkpointCourtLine = checkpointCourtLine
        self.checkpointAuditLine = checkpointAuditLine
        self.checkpointSovereignVerdictLine = checkpointSovereignVerdictLine
        self.checkpointSovereignAuthorityLine = checkpointSovereignAuthorityLine
        self.checkpointSovereignAuditLine = checkpointSovereignAuditLine
        self.checkpointKillSwitchesLine = checkpointKillSwitchesLine
        self.checkpointActionLine = checkpointActionLine
        self.checkpointMorphLine = checkpointMorphLine
        self.checkpointLungLine = checkpointLungLine
        self.checkpointHotColdLine = checkpointHotColdLine
        self.checkpointPrecisionLine = checkpointPrecisionLine
        self.checkpointOrganPackageLine = checkpointOrganPackageLine
        self.checkpointOrganDeltaLine = checkpointOrganDeltaLine
        self.checkpointSchedulerLine = checkpointSchedulerLine
        self.checkpointThermalExchangeLine = checkpointThermalExchangeLine
        self.checkpointIntegrityWeaveLine = checkpointIntegrityWeaveLine
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

            if let checkpointWindGateLine {
                Text(checkpointWindGateLine)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            if let checkpointPresenceLine {
                Text(checkpointPresenceLine)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            if let checkpointPressureLine {
                Text(checkpointPressureLine)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            if let checkpointRiskFactorsLine {
                Text(checkpointRiskFactorsLine)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            if let checkpointReasonCodesLine {
                Text(checkpointReasonCodesLine)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            if let checkpointCourtLine {
                Text(checkpointCourtLine)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            if let checkpointAuditLine {
                Text(checkpointAuditLine)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            if let checkpointSovereignVerdictLine {
                Text(checkpointSovereignVerdictLine)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            if let checkpointSovereignAuthorityLine {
                Text(checkpointSovereignAuthorityLine)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            if let checkpointSovereignAuditLine {
                Text(checkpointSovereignAuditLine)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            if let checkpointKillSwitchesLine {
                Text(checkpointKillSwitchesLine)
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

            if let checkpointMorphLine {
                Text(checkpointMorphLine)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            if let checkpointLungLine {
                Text(checkpointLungLine)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            if let checkpointHotColdLine {
                Text(checkpointHotColdLine)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            if let checkpointPrecisionLine {
                Text(checkpointPrecisionLine)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            if let checkpointOrganPackageLine {
                Text(checkpointOrganPackageLine)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            if let checkpointOrganDeltaLine {
                Text(checkpointOrganDeltaLine)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            if let checkpointSchedulerLine {
                Text(checkpointSchedulerLine)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            if let checkpointThermalExchangeLine {
                Text(checkpointThermalExchangeLine)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            if let checkpointIntegrityWeaveLine {
                Text(checkpointIntegrityWeaveLine)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            if let checkpointResumeLine {
                Text(checkpointResumeLine)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            if let checkpointRollbackLine {
                Text(checkpointRollbackLine)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            if let checkpointSovereignBridgeLine {
                Text(checkpointSovereignBridgeLine)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            ForEach(checkpointSovereignBridgeDetailLines, id: \.self) { detailLine in
                Text(detailLine)
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
