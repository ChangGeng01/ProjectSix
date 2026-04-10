import Foundation
import Testing
@testable import BASMemory
@testable import BASPolicy
@testable import BASRuntimeCore

@Suite("BAS cognition core")
struct BASCognitionCoreTests {
    @Test("brain state snapshot surfaces pending and low-trust risk flags")
    func brainStateSnapshotSurfacesRiskFlags() {
        let state = BASDecisionBrainState(
            memorySlices: [
                BASGovernedMemorySlice(
                    id: "pending",
                    role: .relevant,
                    type: "semantic",
                    headline: "Night texting pattern",
                    source: "history",
                    confidence: 0.72,
                    priority: 0.9,
                    lifecycleState: "warming",
                    governanceStatus: .pending,
                    eligibility: .allowed(.pendingGraceWindow),
                    sourceTrustScore: 0.28,
                    sourceTrustTier: .low,
                    retrievalTags: ["night"],
                    isPending: true,
                    provenanceSummary: "Recent unconfirmed pattern."
                ),
                BASGovernedMemorySlice(
                    id: "stable",
                    role: .goal,
                    type: "goal",
                    headline: "Sleep before midnight",
                    source: "user",
                    confidence: 0.95,
                    priority: 1.0,
                    lifecycleState: "active",
                    governanceStatus: .admitted,
                    eligibility: .allowed(.goalOverride),
                    sourceTrustScore: 0.96,
                    sourceTrustTier: .high,
                    retrievalTags: ["sleep"],
                    isPending: false,
                    provenanceSummary: "User-confirmed goal."
                )
            ],
            sessionBiases: ["night"],
            retrievalTags: ["mirror", "night"],
            reactionWeights: .defaults(for: "mirror"),
            identityProfile: .default(modeName: "mirror"),
            boundaryPolicy: .default(riskLevel: .high),
            loadedAt: .now
        )

        let snapshot = state.verificationSnapshot

        #expect(snapshot.loadedMemoryCount == 2)
        #expect(snapshot.pendingMemoryLoadRate > 0.3)
        #expect(snapshot.lowTrustMemoryLoadRate > 0.2)
        #expect(snapshot.riskFlags.contains(.highPendingInfluence))
        #expect(snapshot.riskFlags.contains(.lowTrustLoad))
    }

    @Test("identity evaluator switches to predictive sentinel for high-risk notifications")
    func identityEvaluatorSwitchesToPredictiveSentinel() {
        let profile = BASIdentityRoleResolver.resolve(
            mode: .quick,
            sourceSurface: .notification,
            riskLevel: .high
        )

        #expect(profile.role == .predictiveSentinel)
        #expect(profile.posture == .protective)
        #expect(profile.initiative == .assertive)
        #expect(profile.canExecuteActions == false)
        #expect(profile.canEscalateToCloud == false)
    }

    @Test("boundary evaluator keeps watch flow local lightweight and confirmable")
    func boundaryEvaluatorKeepsWatchFlowLocalLightweight() {
        let identity = BASIdentityRoleResolver.resolve(
            mode: .mirror,
            sourceSurface: .watch,
            riskLevel: .high
        )
        let brainState = BASDecisionBrainState(
            profileCore: [],
            activeGoals: ["Sleep before midnight"],
            relevantMemories: [],
            sessionBiases: [],
            retrievalTags: ["mirror"],
            reactionWeights: .defaults(for: "mirror"),
            failureGuardIDs: ["night_fast_path_failure"],
            loadedAt: .now
        )

        let policy = BASBoundaryPolicyEvaluator.evaluate(
            mode: .mirror,
            sourceSurface: .watch,
            riskLevel: .high,
            identityProfile: identity,
            brainState: brainState,
            taskGraphHint: BASBrainTaskGraphHint(
                headline: "Reopen tomorrow",
                activeNodeCount: 1,
                hasResumeCandidate: true,
                resumeHint: "Reopen tomorrow"
            )
        )

        #expect(policy.mode == .localOnlyProtective)
        #expect(policy.activeConstraints.contains(.noCloudEscalation))
        #expect(policy.activeConstraints.contains(.watchSurfaceLightweight))
        #expect(policy.requiredConfirmations.contains("irreversible_decision"))
        #expect(policy.allowedActionClasses.contains("quick_capture"))
        #expect(policy.allowedActionClasses.contains("checkpoint_reopen"))
        #expect(policy.blockedActionClasses.contains("deep_editor_surface"))
    }

    @Test("calibration evaluator flags drift when high-risk flow is under-constrained")
    func calibrationEvaluatorFlagsDriftWhenHighRiskFlowIsUnderConstrained() {
        let brainState = BASDecisionBrainState(
            memorySlices: [],
            sessionBiases: [],
            retrievalTags: [],
            reactionWeights: .defaults(for: "quick"),
            identityProfile: .default(modeName: "quick"),
            boundaryPolicy: BASBoundaryPolicyState(
                mode: .localOnlyAdvisory,
                riskLevel: .high,
                allowedActionClasses: ["render_local_guidance"],
                blockedActionClasses: ["cloud_escalation"],
                requiredConfirmations: [],
                activeConstraints: [.noCloudEscalation],
                auditHeadline: "Thin policy."
            ),
            activeInterventionTemplateIDs: [],
            loadedAt: .now
        )

        let calibration = BASCalibrationEvaluator.evaluate(
            brainState: brainState,
            riskLevel: .high,
            identityProfile: .default(modeName: "quick"),
            boundaryPolicy: brainState.boundaryPolicy,
            now: .now
        )

        #expect(calibration.status != .stable)
        #expect(calibration.alerts.contains(.underConstrainedHighRisk))
        #expect(calibration.alerts.contains(.templateCoverageGap))
        #expect(calibration.driftScore > 0.3)
    }
}
