import Foundation
import BASHostKit

enum DecisionCalibrationEngine {
    static func evaluate(
        brainState: DecisionBrainState,
        riskLevel: InterventionRiskLevel,
        identityProfile: DecisionIdentityProfile,
        boundaryPolicy: DecisionBoundaryPolicyState,
        now: Date = .now
    ) -> DecisionCalibrationState {
        BASCalibrationEvaluator.evaluate(
            brainState: brainState,
            riskLevel: substrateRiskLevel(from: riskLevel),
            identityProfile: identityProfile,
            boundaryPolicy: boundaryPolicy,
            now: now
        )
    }
}

extension DecisionCalibrationState {
    var packageCalibrationReport: BASEvaluation.BASCalibrationReport {
        let status: BASEvaluation.BASRegressionStatus = switch self.status {
        case .stable:
            .pass
        case .watch:
            .warn
        case .drifting:
            .fail
        }

        let alertModels = alerts.map { alert in
            BASEvaluation.BASCalibrationAlert(
                reason: alert.rawValue,
                severity: status.rawValue
            )
        }

        let summary: String = {
            if suggestedAdjustments.isEmpty {
                return "Calibration is \(self.status.rawValue) with drift score \(String(format: "%.2f", driftScore))."
            }

            return suggestedAdjustments.joined(separator: " ")
        }()

        return BASEvaluation.BASCalibrationReport(
            score: max(0, 1 - driftScore),
            status: status,
            alerts: alertModels,
            summary: summary
        )
    }
}
