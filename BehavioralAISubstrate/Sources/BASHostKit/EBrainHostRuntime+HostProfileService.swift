import Foundation
import BASMemory
import BASObservability
import BASOrchestration
import BASPolicy
import BASRuntimeCore

// MARK: - M72 split — BASHostRuntimeEBrainHostProfileService extracted from the 5039-line
// EBrainHostRuntimeSynthesis.swift.  Previously file-scope `private`, now
// default-internal so sibling files in BASHostKit (the reduced main
// `makeEBrainTurn` orchestrator and any cross-struct helpers) can reference
// it.  None of these members surface through the Qinao public API.

struct BASHostRuntimeEBrainHostProfileService: BASHostProfileServicing {
    let request: BASHostSessionRequest
    let currentBrain: BASHostCurrentBrain
    let tuning: BASEBrainRuntimeSynthesisPolicy
    let constitutionService: any BASHostConstitutionServicing

    func resolveHost(
        hostID: String,
        contextFrame: BASContextFrame?,
        riskCard: BASRiskCard?
    ) -> BASHostProfile {
        let constitution = constitutionService.resolveConstitution(
            hostID: hostID,
            contextFrame: contextFrame,
            riskCard: riskCard
        )
        return constitutionService.projectProfile(
            from: constitution,
            riskThresholds: BASHostRiskThresholds(
                caution: tuning.hostThresholds.caution,
                protective: tuning.hostThresholds.protective,
                block: tuning.hostThresholds.block
            )
        )
    }

    func applyHostGate(
        profile: BASHostProfile,
        taskType: BASContextTaskType,
        riskCard: BASRiskCard?,
        confidence: Double
    ) -> Double {
        let baseCap = min(confidence, currentBrain.confidenceCeiling)
        guard let riskCard else { return baseCap }

        let modeCap: Double = switch riskCard.riskLevel {
        case .low: 1.0
        case .medium: 0.72
        case .high: 0.42
        case .extreme: 0.20
        }
        let calibrationCap: Double = switch currentBrain.calibrationStatus {
        case .stable: 1.0
        case .watch: 0.85
        case .drifting: 0.70
        }
        let taskCap: Double = switch taskType {
        case .highConsequence, .highPressure, .manipulationRisk:
            0.78
        default:
            1.0
        }
        let constitutionCap = constitutionGateCap(
            profile: profile,
            taskType: taskType,
            riskCard: riskCard
        )

        return min(
            baseCap,
            modeCap,
            calibrationCap,
            taskCap,
            constitutionCap,
            max(0.20, 1 - currentBrain.hostGuardrailPressure(using: tuning))
        )
    }

    func rollbackHostVersion(
        profile: BASHostProfile,
        to versionID: String
    ) -> BASHostVersion {
        BASHostVersion(
            versionID: versionID,
            changedFields: ["tonePreference", "longTermGoals"],
            reason: "host runtime rollback",
            rollbackRef: profile.activeVersion,
            approvedByPolicy: true
        )
    }

    private func constitutionGateCap(
        profile: BASHostProfile,
        taskType: BASContextTaskType,
        riskCard: BASRiskCard?
    ) -> Double {
        let constitution = constitutionService.resolveConstitution(
            hostID: profile.hostID,
            contextFrame: nil,
            riskCard: riskCard
        )
        let isPressureTask: Bool = switch taskType {
        case .highConsequence, .highPressure, .manipulationRisk:
            true
        default:
            false
        }

        var cap = 1.0
        if constitution.boundaryVeil.confirmRequired.isEmpty == false {
            cap = min(cap, isPressureTask ? 0.64 : 0.82)
        }
        if constitution.relationGravity.highConsequenceLinks.isEmpty == false && isPressureTask {
            cap = min(cap, 0.72)
        }
        if constitutionPrioritizesStabilityOrPrivacy(constitution) {
            cap = min(cap, isPressureTask ? 0.76 : 0.88)
        }
        return cap
    }

    private func constitutionPrioritizesStabilityOrPrivacy(
        _ constitution: BASHostConstitution
    ) -> Bool {
        let pairedAxes = zip(
            constitution.valueAxes.axes.map { $0.lowercased() },
            constitution.valueAxes.relativeWeights
        )
        let hasStrongAxis = pairedAxes.contains { axis, weight in
            (axis == "stability" || axis == "privacy") && weight >= 0.85
        }
        let hasOverSpeedRule = constitution.valueAxes.conflictRules.contains { rule in
            let normalized = rule.lowercased()
            return normalized.contains("stability_over_speed")
                || normalized.contains("privacy_over_speed")
        }
        return hasStrongAxis && hasOverSpeedRule
    }
}
