import Foundation

enum DecisionBoundaryPolicyEngine {
    static func evaluate(
        mode: DecisionMode,
        source: BrainStateUpdateSource,
        sourceSurface: DecisionIntentSourceSurface,
        riskLevel: InterventionRiskLevel,
        identityProfile: DecisionIdentityProfile,
        brainState: DecisionBrainState,
        taskGraph: DecisionTaskGraphSnapshot?
    ) -> DecisionBoundaryPolicyState {
        var constraints: [DecisionBoundaryConstraint] = [
            .noCloudEscalation,
            .noAutonomousExternalAction,
            .lockSensitiveMemory,
            .roleLimitedAdvice
        ]
        var requiredConfirmations: [String] = []
        var blocked = ["cloud_escalation", "autonomous_external_action"]
        var allowed = ["render_local_guidance", "load_governed_memory", "resume_checkpoint"]

        if sourceSurface == .watch {
            constraints.append(.watchSurfaceLightweight)
            blocked.append("deep_editor_surface")
            allowed.append("quick_capture")
        }

        if source == .notification || sourceSurface == .notification {
            constraints.append(.notificationRequiresEvidence)
            blocked.append("high_frequency_nudge")
        }

        if riskLevel == .high {
            requiredConfirmations.append("irreversible_decision")
            blocked.append("fast_commit_action")
        }

        if !brainState.failureGuardIDs.isEmpty || taskGraph != nil {
            allowed.append("checkpoint_reopen")
        }

        let modeValue: DecisionBoundaryPolicyMode = {
            if riskLevel == .high { return .localOnlyProtective }
            if identityProfile.posture == .reflective { return .localOnlyReflective }
            return .localOnlyAdvisory
        }()

        let headline: String = {
            switch modeValue {
            case .localOnlyReflective:
                "Reflect locally and avoid pushing the decision over the line."
            case .localOnlyAdvisory:
                "Guide locally with bounded advice and no autonomous moves."
            case .localOnlyProtective:
                "Stay local, add friction, and require confirmation before irreversible movement."
            }
        }()

        return DecisionBoundaryPolicyState(
            mode: modeValue,
            riskLevel: riskLevel,
            allowedActionClasses: Array(Set(allowed)).sorted(),
            blockedActionClasses: Array(Set(blocked)).sorted(),
            requiredConfirmations: Array(Set(requiredConfirmations)).sorted(),
            activeConstraints: Array(Set(constraints)).sorted { $0.rawValue < $1.rawValue },
            auditHeadline: headline
        )
    }
}
