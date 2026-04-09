import Foundation

enum DecisionCalibrationEngine {
    static func evaluate(
        brainState: DecisionBrainState,
        riskLevel: InterventionRiskLevel,
        identityProfile: DecisionIdentityProfile,
        boundaryPolicy: DecisionBoundaryPolicyState,
        now: Date = .now
    ) -> DecisionCalibrationState {
        var alerts: [DecisionCalibrationAlert] = []
        var adjustments: [String] = []
        var driftScore = 0.0

        let snapshot = brainState.verificationSnapshot

        if snapshot.pendingMemoryLoadRate >= 0.34 {
            alerts.append(.highPendingInfluence)
            adjustments.append("Lower pending-memory influence before it hardens into guidance.")
            driftScore += 0.28
        }

        if snapshot.lowTrustMemoryLoadRate >= 0.18 {
            alerts.append(.lowTrustLoad)
            adjustments.append("Prefer higher-trust memory slices or tighten retrieval.")
            driftScore += 0.24
        }

        if identityProfile.initiative == .assertive && riskLevel != .high {
            alerts.append(.aggressiveInitiative)
            adjustments.append("Reduce initiative outside explicitly risky moments.")
            driftScore += 0.18
        }

        if riskLevel == .high && !boundaryPolicy.requiredConfirmations.contains("irreversible_decision") {
            alerts.append(.underConstrainedHighRisk)
            adjustments.append("High-risk flows should require an irreversible-decision confirmation.")
            driftScore += 0.24
        }

        if riskLevel != .low && brainState.activeInterventionTemplateIDs.isEmpty {
            alerts.append(.templateCoverageGap)
            adjustments.append("Restore a reusable intervention template before deepening guidance.")
            driftScore += 0.12
        }

        let status: DecisionCalibrationStatus = {
            switch driftScore {
            case ..<0.20:
                .stable
            case ..<0.50:
                .watch
            default:
                .drifting
            }
        }()

        return DecisionCalibrationState(
            status: status,
            alerts: alerts,
            suggestedAdjustments: adjustments,
            driftScore: driftScore,
            generatedAt: now
        )
    }
}
