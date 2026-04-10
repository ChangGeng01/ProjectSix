import Foundation
import BASMemory
import BASRuntimeCore

typealias DecisionIdentityRole = BASIdentityRole
typealias DecisionIdentityPosture = BASIdentityPosture
typealias DecisionIdentityInitiative = BASIdentityInitiative
typealias DecisionIdentityProfile = BASIdentityProfile

typealias DecisionBoundaryPolicyMode = BASBoundaryPolicyMode
typealias DecisionBoundaryConstraint = BASBoundaryConstraint
typealias DecisionBoundaryPolicyState = BASBoundaryPolicyState

typealias DecisionCalibrationStatus = BASCalibrationStatus
typealias DecisionCalibrationAlert = BASCalibrationAlert
typealias DecisionCalibrationState = BASCalibrationState

typealias DecisionEvolutionApprovalState = BASEvolutionApprovalState
typealias DecisionEvolutionCheckpointSummary = BASEvolutionCheckpointSummary
typealias DecisionEvolutionState = BASEvolutionState

extension DecisionIdentityProfile {
    static func `default`(for mode: DecisionMode) -> DecisionIdentityProfile {
        BASIdentityProfile.default(modeName: substrateModeName(from: mode))
    }
}

extension DecisionBoundaryPolicyState {
    static func `default`(riskLevel: InterventionRiskLevel) -> DecisionBoundaryPolicyState {
        BASBoundaryPolicyState.default(riskLevel: substrateRiskLevel(from: riskLevel))
    }
}

@inline(__always)
func substrateModeName(from mode: DecisionMode) -> String {
    mode.rawValue
}

@inline(__always)
func substrateMode(from mode: DecisionMode) -> BASDecisionMode {
    BASDecisionMode(rawValue: mode.rawValue) ?? .quick
}

@inline(__always)
func substrateRiskLevel(from riskLevel: InterventionRiskLevel) -> BASRiskLevel {
    switch riskLevel {
    case .low:
        .low
    case .medium:
        .medium
    case .high:
        .high
    }
}

@inline(__always)
func substrateSourceSurfaceName(from sourceSurface: DecisionIntentSourceSurface) -> String {
    sourceSurface.rawValue
}
