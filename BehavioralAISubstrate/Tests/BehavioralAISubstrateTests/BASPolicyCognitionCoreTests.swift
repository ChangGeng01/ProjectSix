import Foundation
import Testing
@testable import BASMemory
@testable import BASPolicy
@testable import BASRuntimeCore

#if !os(iOS)  // ch 1022 source-gate: SwiftTesting iOS bundle discovery quirk
@Suite("BASPolicy Cognition Core")
struct BASPolicyCognitionCoreTests {
    @Test("identity resolver shifts to predictive sentinel on notification and stays lightweight on watch")
    func identityResolverShiftsForSurfaceAndRisk() {
        let notificationIdentity = BASIdentityRoleResolver.resolve(
            mode: .reflective,
            sourceSurface: .notification,
            riskLevel: .high
        )
        let watchIdentity = BASIdentityRoleResolver.resolve(
            mode: .comparative,
            sourceSurface: .watch,
            riskLevel: .medium
        )

        #expect(notificationIdentity.role == .predictiveSentinel)
        #expect(notificationIdentity.posture == .protective)
        #expect(notificationIdentity.initiative == .guided)
        #expect(watchIdentity.role == .pauseCompanion)
        #expect(watchIdentity.initiative == .guided)
        #expect(watchIdentity.relationshipBoundary.contains("lightweight"))
    }

    @Test("boundary evaluator adds watch and checkpoint protections")
    func boundaryEvaluatorAddsWatchAndCheckpointProtections() {
        let brainState = makeBrainState()
        let identity = BASIdentityRoleResolver.resolve(
            mode: .reflective,
            sourceSurface: .watch,
            riskLevel: .high
        )
        let boundary = BASBoundaryPolicyEvaluator.evaluate(
            mode: .reflective,
            sourceSurface: .watch,
            riskLevel: .high,
            identityProfile: identity,
            brainState: brainState,
            taskGraphHint: BASTaskGraphHint(
                headline: "Reopen tomorrow",
                activeNodeCount: 1,
                hasResumeCandidate: true,
                resumeHint: "Reopen tomorrow"
            )
        )

        #expect(boundary.mode == .localOnlyProtective)
        #expect(boundary.activeConstraints.contains(.watchSurfaceLightweight))
        #expect(boundary.requiredConfirmations.contains("irreversible_decision"))
        #expect(boundary.allowedActionClasses.contains("checkpoint_reopen"))
        #expect(boundary.auditHeadline.contains("Keep execution local"))
    }

    @Test("host-injected cognition behavior overrides substrate defaults")
    func hostInjectedCognitionBehaviorOverridesDefaults() {
        let behavior = BASCognitionBehavior(
            surfaceIdentityOverlaysBySurfaceID: [
                BASInteractionSurface.notification.rawValue: BASIdentityProfileOverlay(
                    role: .boundedGuide,
                    posture: .reflective,
                    initiative: .passive,
                    confidenceCeiling: 0.49,
                    relationshipBoundary: "Host owns the notification relationship."
                )
            ],
            highRiskIdentityOverlay: BASIdentityProfileOverlay(
                posture: .protective,
                initiative: .guided,
                confidenceCeiling: 0.51,
                relationshipBoundary: "Host wants high risk to stay highly bounded."
            ),
            highRiskInitiativeByRoleID: [:],
            boundary: BASBoundaryEvaluationBehavior(
                defaultAllowedActionClasses: ["host_render"],
                defaultBlockedActionClasses: ["host_cloud"],
                defaultConstraints: [.lockSensitiveMemory],
                allowedActionClassesBySurfaceID: [
                    BASInteractionSurface.notification.rawValue: ["host_notification_lane"]
                ],
                blockedActionClassesBySurfaceID: [
                    BASInteractionSurface.notification.rawValue: ["host_high_frequency_nudge"]
                ],
                constraintsBySurfaceID: [
                    BASInteractionSurface.notification.rawValue: [.notificationRequiresEvidence]
                ],
                highRiskRequiredConfirmations: ["host_irreversible_confirmation"],
                highRiskBlockedActionClasses: ["host_fast_commit"],
                reflectiveModeIDs: [],
                advisoryHeadline: "Host advisory boundary.",
                reflectiveHeadline: "Host reflective boundary.",
                protectiveHeadline: "Host protective boundary."
            )
        )

        let identity = BASIdentityRoleResolver.resolve(
            mode: .reflective,
            sourceSurface: .notification,
            riskLevel: .high,
            baseProfile: BASIdentityProfile(
                role: .reflectiveWitness,
                posture: .reflective,
                initiative: .guided,
                confidenceCeiling: 0.72,
                canAdvise: true,
                canExecuteActions: false,
                canEscalateToCloud: false,
                relationshipBoundary: "Default"
            ),
            behavior: behavior
        )
        let boundary = BASBoundaryPolicyEvaluator.evaluate(
            mode: .reflective,
            sourceSurface: .notification,
            riskLevel: .high,
            identityProfile: identity,
            brainState: makeBrainState(),
            taskGraphHint: nil,
            behavior: behavior
        )

        #expect(identity.role == .boundedGuide)
        #expect(identity.initiative == .guided)
        #expect(identity.relationshipBoundary == "Host wants high risk to stay highly bounded.")
        #expect(boundary.allowedActionClasses.contains("host_render"))
        #expect(boundary.allowedActionClasses.contains("host_notification_lane"))
        #expect(boundary.blockedActionClasses.contains("host_cloud"))
        #expect(boundary.blockedActionClasses.contains("host_fast_commit"))
        #expect(boundary.requiredConfirmations == ["host_irreversible_confirmation"])
        #expect(boundary.auditHeadline == "Host protective boundary.")
    }

    @Test("calibration evaluator detects drift from pending load and missing templates")
    func calibrationEvaluatorDetectsDrift() {
        let brainState = makeBrainState(
            mode: .comparative,
            pendingRate: 0.45,
            lowTrustRate: 0.22,
            activeTemplates: []
        )
        let identity = BASIdentityProfile(
            role: .tradeoffGuide,
            posture: .coaching,
            initiative: .assertive,
            confidenceCeiling: 0.7,
            canAdvise: true,
            canExecuteActions: false,
            canEscalateToCloud: false,
            relationshipBoundary: "Keep it bounded."
        )
        let boundary = BASBoundaryPolicyState.default(riskLevel: .medium)

        let calibration = BASCalibrationEvaluator.evaluate(
            brainState: brainState,
            riskLevel: .medium,
            identityProfile: identity,
            boundaryPolicy: boundary,
            now: Date(timeIntervalSince1970: 1_700_100_000)
        )

        #expect(calibration.status == .drifting)
        #expect(calibration.alerts.contains(.highPendingInfluence))
        #expect(calibration.alerts.contains(.lowTrustLoad))
        #expect(calibration.alerts.contains(.aggressiveInitiative))
        #expect(calibration.alerts.contains(.templateCoverageGap))
    }

    @Test("evolution evaluator emits review suggested checkpoints when calibration drifts")
    func evolutionEvaluatorEmitsReviewSuggestedCheckpoints() {
        let brainState = makeBrainState(
            mode: .reflective,
            pendingRate: 0.45,
            lowTrustRate: 0.22,
            activeTemplates: []
        )
        let identity = BASIdentityRoleResolver.resolve(
            mode: .reflective,
            sourceSurface: .notification,
            riskLevel: .high
        )
        let boundary = BASBoundaryPolicyEvaluator.evaluate(
            mode: .reflective,
            sourceSurface: .notification,
            riskLevel: .high,
            identityProfile: identity,
            brainState: brainState,
            taskGraphHint: nil
        )
        let calibration = BASCalibrationState(
            status: .drifting,
            alerts: [.highPendingInfluence, .lowTrustLoad],
            suggestedAdjustments: ["tighten retrieval"],
            driftScore: 0.82,
            generatedAt: Date(timeIntervalSince1970: 1_700_100_000)
        )
        let previous = BASEvolutionCheckpointSummary(
            id: "prev-1",
            previousCheckpointID: nil,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            diffSummary: ["initial checkpoint"],
            rollbackReady: true,
            approvalState: .automatic
        )

        let evolution = BASEvolutionEvaluator.evaluate(
            previous: previous,
            brainState: brainState,
            boundaryPolicy: boundary,
            calibrationState: calibration,
            mode: .reflective,
            sourceSurface: .notification,
            checkpointCount: 3,
            now: Date(timeIntervalSince1970: 1_700_100_000)
        )

        #expect(evolution.checkpointCount == 3)
        #expect(evolution.rollbackReady)
        #expect(evolution.pendingReviewCount == 1)
        #expect(evolution.latestCheckpoint?.previousCheckpointID == "prev-1")
        #expect(evolution.latestCheckpoint?.approvalState == .reviewSuggested)
        #expect(evolution.recentDiffSummary.contains(where: { $0.contains("Boundary mode tightened") || $0.contains("failure guards") }))
    }

    @Test("cognition bootstrapper enriches brain state with identity boundary and calibration")
    func cognitionBootstrapperEnrichesBrainState() {
        let rawBrainState = makeBrainState(
            mode: .reflective,
            pendingRate: 0.45,
            lowTrustRate: 0.22,
            activeTemplates: ["template-1"],
            failureGuards: ["failure-1"]
        )

        let bootstrapped = BASCognitionBootstrapper.enrich(
            brainState: rawBrainState,
            mode: .reflective,
            sourceSurface: .notification,
            riskLevel: .high,
            taskGraphHint: BASTaskGraphHint(
                headline: "resume tomorrow",
                activeNodeCount: 2,
                hasResumeCandidate: true,
                resumeHint: "resume tomorrow"
            ),
            dominantGoal: "prefer concise answers",
            activeConstraints: ["mode:reflective"],
            activeTemplateIDs: ["template-1", "template-2"],
            failureGuardIDs: ["failure-1"],
            now: Date(timeIntervalSince1970: 1_700_100_000)
        )

        #expect(bootstrapped.dominantGoal == "prefer concise answers")
        #expect(bootstrapped.brainState.identityProfile.role == .predictiveSentinel)
        #expect(bootstrapped.brainState.boundaryPolicy.mode == .localOnlyProtective)
        #expect(bootstrapped.brainState.boundaryPolicy.activeConstraints.contains(.notificationRequiresEvidence))
        #expect(bootstrapped.brainState.calibrationState.status == .drifting)
        #expect(bootstrapped.activeConstraints.contains("mode:reflective"))
        #expect(bootstrapped.activeTemplateIDs == ["template-1", "template-2"])
        #expect(bootstrapped.failureGuardIDs == ["failure-1"])
    }

    @Test("consistency harness catches mode drift forbidden actions and fact conflicts")
    func consistencyHarnessCatchesModeAndTruthDrift() {
        let result = BASConsistencyHarness.evaluate(
            BASConsistencyCheckInput(
                truthState: BASStructuredTruthState(
                    mode: "repeat_after_me",
                    currentGoal: "Keep the reply short.",
                    allowedActions: ["speak_short", "encourage", "correct_pronunciation"],
                    forbiddenActions: ["switch_topic", "tell_long_story"],
                    personaRules: ["句子短", "non-judgmental"],
                    sessionFacts: [
                        "lesson_stage": "repeat",
                        "current_goal": "Keep the reply short."
                    ]
                ),
                responseMode: "free_chat",
                responseText: "You should have known this already, so let me tell a very long story about why your reply should wait until tomorrow morning and how you failed the last time as well.",
                proposedActions: ["tell_long_story", "switch_topic"],
                referencedFacts: [
                    "lesson_stage": "story_time",
                    "current_goal": "Send the long reply now."
                ]
            )
        )

        #expect(!result.isConsistent)
        #expect(result.shouldRepair)
        #expect(result.severityScore > 0.5)
        #expect(result.violations.contains(where: { $0.kind == .modeMismatch }))
        #expect(result.violations.contains(where: { $0.kind == .forbiddenAction }))
        #expect(result.violations.contains(where: { $0.kind == .factConflict }))
        #expect(result.violations.contains(where: { $0.kind == .personaDrift }))
    }

    private func makeBrainState(
        mode: BASDecisionMode = .reflective,
        pendingRate: Double = 0.45,
        lowTrustRate: Double = 0.22,
        activeTemplates: [String] = ["template-1"],
        failureGuards: [String] = ["failure-1"]
    ) -> BASDecisionBrainState {
        let stableSlice = BASGovernedMemorySlice(
            id: "slice-1",
            role: .profile,
            type: "profile",
            headline: "prefer concise answers",
            source: "reflection",
            confidence: 0.92,
            priority: 0.88,
            lifecycleState: "admitted",
            governanceStatus: .admitted,
            eligibility: .allowed(.defaultAllowed),
            sourceTrustScore: 0.91,
            sourceTrustTier: .high,
            retrievalTags: ["mode:reflective", "kind:profile"],
            isPending: false,
            provenanceSummary: "profile"
        )
        let pendingLowTrustSlice = BASGovernedMemorySlice(
            id: "slice-2",
            role: .relevant,
            type: "semantic",
            headline: "night urge pattern",
            source: "reflection",
            confidence: max(0.3, pendingRate),
            priority: 0.52,
            lifecycleState: "pending",
            governanceStatus: .pending,
            eligibility: .allowed(.pendingGraceWindow),
            sourceTrustScore: max(0.2, lowTrustRate),
            sourceTrustTier: .low,
            retrievalTags: ["mode:\(mode.rawValue)", "kind:semantic", "night"],
            isPending: pendingRate > 0,
            provenanceSummary: "recent low-trust pattern"
        )
        let slices = pendingRate > 0 || lowTrustRate > 0
            ? [stableSlice, pendingLowTrustSlice]
            : [stableSlice]

        return BASDecisionBrainState(
            memorySlices: slices,
            sessionBiases: ["night", "brief"],
            retrievalTags: ["night", "brief"],
            reactionWeights: .defaults(for: mode.rawValue),
            identityProfile: .default(modeName: mode.rawValue),
            boundaryPolicy: .default(riskLevel: .low),
            calibrationState: BASCalibrationState.stable(at: Date(timeIntervalSince1970: 1_700_000_000)),
            evolutionState: .empty,
            activeInterventionTemplateIDs: activeTemplates,
            failureGuardIDs: failureGuards,
            memoryGovernance: BASMemoryGovernanceState(
                totalRecordCount: 3,
                totalCandidateCount: 2,
                pendingCandidateCount: pendingRate > 0 ? 1 : 0,
                promotedCandidateCount: 1,
                loadedPromotedMemoryCount: 1,
                loadedPendingMemoryCount: pendingRate > 0 ? 1 : 0
            ),
            loadedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
    }
}
#endif
