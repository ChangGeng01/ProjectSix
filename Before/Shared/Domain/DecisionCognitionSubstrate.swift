import Foundation

enum DecisionIdentityRole: String, CaseIterable, Codable, Sendable {
    case pauseCompanion = "pause_companion"
    case tradeoffGuide = "tradeoff_guide"
    case mirrorWitness = "mirror_witness"
    case predictiveSentinel = "predictive_sentinel"

    var title: String {
        switch self {
        case .pauseCompanion:
            "Pause Companion"
        case .tradeoffGuide:
            "Trade-off Guide"
        case .mirrorWitness:
            "Mirror Witness"
        case .predictiveSentinel:
            "Predictive Sentinel"
        }
    }
}

enum DecisionIdentityPosture: String, CaseIterable, Codable, Sendable {
    case reflective
    case coaching
    case protective
}

enum DecisionIdentityInitiative: String, CaseIterable, Codable, Sendable {
    case passive
    case guided
    case assertive
}

struct DecisionIdentityProfile: Codable, Equatable, Sendable {
    let role: DecisionIdentityRole
    let posture: DecisionIdentityPosture
    let initiative: DecisionIdentityInitiative
    let confidenceCeiling: Double
    let canAdvise: Bool
    let canExecuteActions: Bool
    let canEscalateToCloud: Bool
    let relationshipBoundary: String

    static func `default`(for mode: DecisionMode) -> DecisionIdentityProfile {
        switch mode {
        case .quick:
            DecisionIdentityProfile(
                role: .pauseCompanion,
                posture: .coaching,
                initiative: .guided,
                confidenceCeiling: 0.72,
                canAdvise: true,
                canExecuteActions: false,
                canEscalateToCloud: false,
                relationshipBoundary: "Interrupt speed, do not impersonate certainty."
            )
        case .balance:
            DecisionIdentityProfile(
                role: .tradeoffGuide,
                posture: .reflective,
                initiative: .guided,
                confidenceCeiling: 0.76,
                canAdvise: true,
                canExecuteActions: false,
                canEscalateToCloud: false,
                relationshipBoundary: "Clarify trade-offs without taking control of the decision."
            )
        case .mirror:
            DecisionIdentityProfile(
                role: .mirrorWitness,
                posture: .reflective,
                initiative: .passive,
                confidenceCeiling: 0.68,
                canAdvise: true,
                canExecuteActions: false,
                canEscalateToCloud: false,
                relationshipBoundary: "Reflect the pattern without becoming the protagonist."
            )
        }
    }
}

enum DecisionBoundaryPolicyMode: String, CaseIterable, Codable, Sendable {
    case localOnlyReflective = "local_only_reflective"
    case localOnlyAdvisory = "local_only_advisory"
    case localOnlyProtective = "local_only_protective"

    var isPureLocal: Bool { true }
}

enum DecisionBoundaryConstraint: String, CaseIterable, Codable, Sendable {
    case noCloudEscalation = "no_cloud_escalation"
    case noAutonomousExternalAction = "no_autonomous_external_action"
    case confirmIrreversibleAction = "confirm_irreversible_action"
    case lockSensitiveMemory = "lock_sensitive_memory"
    case watchSurfaceLightweight = "watch_surface_lightweight"
    case notificationRequiresEvidence = "notification_requires_evidence"
    case roleLimitedAdvice = "role_limited_advice"

    var title: String {
        rawValue.replacingOccurrences(of: "_", with: " ")
    }
}

struct DecisionBoundaryPolicyState: Codable, Equatable, Sendable {
    let mode: DecisionBoundaryPolicyMode
    let riskLevel: InterventionRiskLevel
    let allowedActionClasses: [String]
    let blockedActionClasses: [String]
    let requiredConfirmations: [String]
    let activeConstraints: [DecisionBoundaryConstraint]
    let auditHeadline: String

    static func `default`(riskLevel: InterventionRiskLevel) -> DecisionBoundaryPolicyState {
        DecisionBoundaryPolicyState(
            mode: riskLevel == .high ? .localOnlyProtective : .localOnlyAdvisory,
            riskLevel: riskLevel,
            allowedActionClasses: ["render_local_guidance", "load_governed_memory"],
            blockedActionClasses: ["cloud_escalation", "autonomous_external_action"],
            requiredConfirmations: riskLevel == .high ? ["irreversible_decision"] : [],
            activeConstraints: [.noCloudEscalation, .noAutonomousExternalAction, .lockSensitiveMemory],
            auditHeadline: "Stay local, stay bounded, and avoid irreversible momentum."
        )
    }
}

enum DecisionCalibrationStatus: String, CaseIterable, Codable, Sendable {
    case stable
    case watch
    case drifting
}

enum DecisionCalibrationAlert: String, CaseIterable, Codable, Sendable {
    case highPendingInfluence = "high_pending_influence"
    case lowTrustLoad = "low_trust_load"
    case aggressiveInitiative = "aggressive_initiative"
    case underConstrainedHighRisk = "under_constrained_high_risk"
    case templateCoverageGap = "template_coverage_gap"
}

struct DecisionCalibrationState: Codable, Equatable, Sendable {
    let status: DecisionCalibrationStatus
    let alerts: [DecisionCalibrationAlert]
    let suggestedAdjustments: [String]
    let driftScore: Double
    let generatedAt: Date

    static func stable(at date: Date = .now) -> DecisionCalibrationState {
        DecisionCalibrationState(
            status: .stable,
            alerts: [],
            suggestedAdjustments: [],
            driftScore: 0,
            generatedAt: date
        )
    }
}

enum DecisionEvolutionApprovalState: String, CaseIterable, Codable, Sendable {
    case automatic
    case reviewSuggested
}

struct DecisionEvolutionCheckpointSummary: Codable, Equatable, Sendable {
    let id: String
    let previousCheckpointID: String?
    let createdAt: Date
    let diffSummary: [String]
    let rollbackReady: Bool
    let approvalState: DecisionEvolutionApprovalState
}

struct DecisionEvolutionState: Codable, Equatable, Sendable {
    let latestCheckpoint: DecisionEvolutionCheckpointSummary?
    let checkpointCount: Int
    let rollbackReady: Bool
    let pendingReviewCount: Int
    let recentDiffSummary: [String]

    static let empty = DecisionEvolutionState(
        latestCheckpoint: nil,
        checkpointCount: 0,
        rollbackReady: false,
        pendingReviewCount: 0,
        recentDiffSummary: []
    )
}
