import Foundation
import BASMemory
import BASRuntimeCore

public typealias BASTaskGraphHint = BASBrainTaskGraphHint

public enum BASCognitionBootstrapper {
    public static func bootstrap(
        request: BASBrainBootstrapRequest,
        projection: BASBrainProjection
    ) -> BASBootstrappedBrainState {
        let compiled = BASBrainCompiler.bootstrap(request: request, projection: projection)
        return enrich(
            brainState: compiled.brainState,
            mode: request.mode,
            sourceSurface: request.sourceSurface,
            riskLevel: request.riskLevel,
            taskGraphHint: compiled.taskGraphHint,
            dominantGoal: compiled.dominantGoal,
            activeConstraints: compiled.activeConstraints,
            activeTemplateIDs: compiled.activeTemplateIDs,
            failureGuardIDs: compiled.failureGuardIDs,
            now: request.now
        )
    }

    public static func enrich(
        brainState: BASDecisionBrainState,
        mode: BASDecisionMode,
        sourceSurface: BASInteractionSurface,
        riskLevel: BASRiskLevel,
        taskGraphHint: BASTaskGraphHint? = nil,
        dominantGoal: String? = nil,
        activeConstraints seedConstraints: [String] = [],
        activeTemplateIDs: [String]? = nil,
        failureGuardIDs: [String]? = nil,
        now: Date = .now
    ) -> BASBootstrappedBrainState {
        var enrichedBrainState = brainState
        if let activeTemplateIDs {
            enrichedBrainState.activeInterventionTemplateIDs = activeTemplateIDs
        }
        if let failureGuardIDs {
            enrichedBrainState.failureGuardIDs = failureGuardIDs
        }

        let identityProfile = BASIdentityRoleResolver.resolve(
            mode: mode,
            sourceSurface: sourceSurface,
            riskLevel: riskLevel,
            baseProfile: enrichedBrainState.identityProfile
        )
        let boundaryPolicy = BASBoundaryPolicyEvaluator.evaluate(
            mode: mode,
            sourceSurface: sourceSurface,
            riskLevel: riskLevel,
            identityProfile: identityProfile,
            brainState: enrichedBrainState,
            taskGraphHint: taskGraphHint
        )
        let calibrationState = BASCalibrationEvaluator.evaluate(
            brainState: enrichedBrainState,
            riskLevel: riskLevel,
            identityProfile: identityProfile,
            boundaryPolicy: boundaryPolicy,
            now: now
        )

        enrichedBrainState.identityProfile = identityProfile
        enrichedBrainState.boundaryPolicy = boundaryPolicy
        enrichedBrainState.calibrationState = calibrationState

        let resolvedConstraints = Array(
            orderedUnique(
                seedConstraints +
                    boundaryPolicy.activeConstraints.map(\.title) +
                    enrichedBrainState.sessionBiases
            )
            .prefix(4)
        )

        return BASBootstrappedBrainState(
            brainState: enrichedBrainState,
            dominantGoal: dominantGoal ?? enrichedBrainState.activeGoals.first,
            activeConstraints: resolvedConstraints,
            activeTemplateIDs: enrichedBrainState.activeInterventionTemplateIDs,
            failureGuardIDs: enrichedBrainState.failureGuardIDs,
            taskGraphHint: taskGraphHint
        )
    }

    private static func orderedUnique(_ values: [String]) -> [String] {
        var seen = Set<String>()
        var ordered: [String] = []
        for value in values where seen.insert(value).inserted {
            ordered.append(value)
        }
        return ordered
    }
}

public enum BASIdentityRoleResolver {
    public static func resolve(
        mode: BASDecisionMode,
        sourceSurface: BASInteractionSurface,
        riskLevel: BASRiskLevel,
        baseProfile: BASIdentityProfile? = nil
    ) -> BASIdentityProfile {
        var profile = baseProfile ?? BASIdentityProfile.default(modeName: mode.rawValue)

        if sourceSurface == .notification {
            profile = BASIdentityProfile(
                role: .predictiveSentinel,
                posture: riskLevel == .high ? .protective : .coaching,
                initiative: riskLevel == .high ? .assertive : .guided,
                confidenceCeiling: riskLevel == .high ? 0.62 : 0.58,
                canAdvise: true,
                canExecuteActions: false,
                canEscalateToCloud: false,
                relationshipBoundary: "Interrupt momentum, but do not overtake the user's agency."
            )
        }

        if sourceSurface == .watch {
            return BASIdentityProfile(
                role: .pauseCompanion,
                posture: riskLevel == .high ? .protective : profile.posture,
                initiative: .guided,
                confidenceCeiling: min(profile.confidenceCeiling, 0.64),
                canAdvise: profile.canAdvise,
                canExecuteActions: false,
                canEscalateToCloud: false,
                relationshipBoundary: "Keep the watch surface lightweight, interruptive, and local."
            )
        }

        if riskLevel == .high {
            return BASIdentityProfile(
                role: profile.role,
                posture: .protective,
                initiative: profile.role == .mirrorWitness ? .guided : .assertive,
                confidenceCeiling: min(profile.confidenceCeiling, 0.66),
                canAdvise: true,
                canExecuteActions: false,
                canEscalateToCloud: false,
                relationshipBoundary: "Slow the decision down before offering any stronger interpretation."
            )
        }

        return profile
    }
}

public enum BASBoundaryPolicyEvaluator {
    public static func evaluate(
        mode: BASDecisionMode,
        sourceSurface: BASInteractionSurface,
        riskLevel: BASRiskLevel,
        identityProfile: BASIdentityProfile,
        brainState: BASDecisionBrainState,
        taskGraphHint: BASTaskGraphHint? = nil
    ) -> BASBoundaryPolicyState {
        var constraints: [BASBoundaryConstraint] = [
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

        if sourceSurface == .notification {
            constraints.append(.notificationRequiresEvidence)
            blocked.append("high_frequency_nudge")
        }

        if riskLevel == .high {
            requiredConfirmations.append("irreversible_decision")
            blocked.append("fast_commit_action")
        }

        if taskGraphHint?.hasResumeCandidate == true || !brainState.failureGuardIDs.isEmpty {
            allowed.append("checkpoint_reopen")
        }

        let modeValue: BASBoundaryPolicyMode = {
            if riskLevel == .high { return .localOnlyProtective }
            if identityProfile.posture == .reflective || mode == .balance { return .localOnlyReflective }
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

        return BASBoundaryPolicyState(
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

public enum BASCalibrationEvaluator {
    public static func evaluate(
        brainState: BASDecisionBrainState,
        riskLevel: BASRiskLevel,
        identityProfile: BASIdentityProfile,
        boundaryPolicy: BASBoundaryPolicyState,
        now: Date = .now
    ) -> BASCalibrationState {
        var alerts: [BASCalibrationAlert] = []
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

        let status: BASCalibrationStatus = {
            switch driftScore {
            case ..<0.20:
                .stable
            case ..<0.50:
                .watch
            default:
                .drifting
            }
        }()

        return BASCalibrationState(
            status: status,
            alerts: alerts,
            suggestedAdjustments: adjustments,
            driftScore: driftScore,
            generatedAt: now
        )
    }
}

public enum BASEvolutionEvaluator {
    public static func evaluate(
        previous latest: BASEvolutionCheckpointSummary? = nil,
        brainState: BASDecisionBrainState,
        boundaryPolicy: BASBoundaryPolicyState,
        calibrationState: BASCalibrationState,
        mode: BASDecisionMode,
        sourceSurface: BASInteractionSurface,
        checkpointCount: Int = 1,
        now: Date = .now
    ) -> BASEvolutionState {
        let diffSummary = buildDiffSummary(
            previous: latest,
            brainState: brainState,
            boundaryPolicy: boundaryPolicy,
            calibrationState: calibrationState,
            mode: mode,
            sourceSurface: sourceSurface
        )
        let approvalState: BASEvolutionApprovalState = calibrationState.status == .drifting ? .reviewSuggested : .automatic

        let checkpoint = BASEvolutionCheckpointSummary(
            id: UUID().uuidString,
            previousCheckpointID: latest?.id,
            createdAt: now,
            diffSummary: diffSummary,
            rollbackReady: true,
            approvalState: approvalState
        )

        return BASEvolutionState(
            latestCheckpoint: checkpoint,
            checkpointCount: max(1, checkpointCount),
            rollbackReady: checkpoint.rollbackReady,
            pendingReviewCount: calibrationState.status == .drifting ? 1 : 0,
            recentDiffSummary: diffSummary
        )
    }

    private static func buildDiffSummary(
        previous: BASEvolutionCheckpointSummary?,
        brainState: BASDecisionBrainState,
        boundaryPolicy: BASBoundaryPolicyState,
        calibrationState: BASCalibrationState,
        mode: BASDecisionMode,
        sourceSurface: BASInteractionSurface
    ) -> [String] {
        let boundaryModeLabel = boundaryPolicy.mode.rawValue.replacingOccurrences(of: "_", with: " ")

        guard let previous else {
            return [
                "Established the first local cognition checkpoint.",
                "Locked the role into \(mode.title).",
                "Started with \(boundaryModeLabel) from \(sourceSurface.title)."
            ]
        }

        var diffs: [String] = []
        if previous.approvalState == .reviewSuggested && calibrationState.status != .drifting {
            diffs.append("Calibration recovered from review-suggested drift.")
        }
        if boundaryPolicy.mode == .localOnlyProtective {
            diffs.append("Boundary mode tightened toward \(boundaryModeLabel).")
        }
        if !brainState.failureGuardIDs.isEmpty {
            diffs.append("Recent failure guards remain active.")
        }
        if diffs.isEmpty {
            diffs.append("Recorded a new safe checkpoint without changing role or boundary posture.")
        }
        return Array(diffs.prefix(3))
    }
}
