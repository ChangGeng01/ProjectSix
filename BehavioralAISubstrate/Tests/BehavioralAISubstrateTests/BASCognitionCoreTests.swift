import Foundation
import Testing
@testable import BASMemory
@testable import BASPolicy
@testable import BASRuntimeCore

#if !os(iOS)  // ch 1022 source-gate: SwiftTesting iOS bundle discovery quirk
@Suite("BAS cognition core")
struct BASCognitionCoreTests {
    @Test("generic cognition identifiers reject legacy host vocabulary")
    func genericCognitionIdentifiersRejectLegacyVocabulary() {
        #expect(BASDecisionMode(identifier: "quick") == nil)
        #expect(BASDecisionMode(identifier: "balance") == nil)
        #expect(BASDecisionMode(identifier: "mirror") == nil)
        #expect(BASMemorySource(identifier: "history") == nil)
        #expect(BASMemorySource(identifier: "reminder") == nil)
    }

    @Test("brain state snapshot surfaces pending and low-trust risk flags")
    func brainStateSnapshotSurfacesRiskFlags() {
        let state = BASDecisionBrainState(
            memorySlices: [
                BASGovernedMemorySlice(
                    id: "pending",
                    role: .relevant,
                    type: "semantic",
                    headline: "Night texting pattern",
                    source: "archive",
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
            retrievalTags: [BASDecisionMode.reflective.identifier, "night"],
            reactionWeights: .defaults(for: BASDecisionMode.reflective.identifier),
            identityProfile: .default(modeName: BASDecisionMode.reflective.identifier),
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

    @Test("brain state snapshot surfaces horizon refresh and quarantine flags")
    func brainStateSnapshotSurfacesHorizonFlags() {
        let state = BASDecisionBrainState(
            memorySlices: [
                BASGovernedMemorySlice(
                    id: "quarantined-observation",
                    role: .relevant,
                    type: "situational",
                    headline: "Observed tool output still needs corroboration",
                    source: "pattern",
                    confidence: 0.66,
                    priority: 0.7,
                    lifecycleState: "warming",
                    governanceStatus: .pending,
                    eligibility: .allowed(.pendingGraceWindow),
                    sourceTrustScore: 0.54,
                    sourceTrustTier: .medium,
                    retrievalTags: ["quarantined", "tool_observation", "evidence_caveat"],
                    isPending: true,
                    provenanceSummary: "Observation-only candidate."
                )
            ],
            sessionBiases: [],
            retrievalTags: [BASDecisionMode.primary.identifier],
            reactionWeights: .defaults(for: BASDecisionMode.primary.identifier),
            identityProfile: .default(modeName: BASDecisionMode.primary.identifier),
            boundaryPolicy: .default(riskLevel: .medium),
            memoryGovernance: BASMemoryGovernanceState(
                totalRecordCount: 0,
                totalCandidateCount: 1,
                pendingCandidateCount: 1,
                promotedCandidateCount: 0,
                loadedPromotedMemoryCount: 0,
                loadedPendingMemoryCount: 1,
                quarantinedObservationCount: 1,
                evidenceCaveatedCandidateCount: 1,
                screenedOutReasonCounts: [.externalRefreshNoOverlap: 2]
            ),
            loadedAt: .now
        )

        let snapshot = state.verificationSnapshot

        #expect(snapshot.riskFlags.contains(.externalRefreshGuardTriggered))
        #expect(snapshot.riskFlags.contains(.observationOnlyQuarantine))
        #expect(snapshot.riskFlags.contains(.evidenceCaveatLoad))
    }

    @Test("identity evaluator switches to predictive sentinel for high-risk notifications")
    func identityEvaluatorSwitchesToPredictiveSentinel() {
        let profile = BASIdentityRoleResolver.resolve(
            mode: .primary,
            sourceSurface: .notification,
            riskLevel: .high
        )

        #expect(profile.role == .predictiveSentinel)
        #expect(profile.posture == .protective)
        #expect(profile.initiative == .guided)
        #expect(profile.canExecuteActions == false)
        #expect(profile.canEscalateToCloud == false)
    }

    @Test("boundary evaluator keeps watch flow local lightweight and confirmable")
    func boundaryEvaluatorKeepsWatchFlowLocalLightweight() {
        let identity = BASIdentityRoleResolver.resolve(
            mode: .reflective,
            sourceSurface: .watch,
            riskLevel: .high
        )
        let brainState = BASDecisionBrainState(
            profileCore: [],
            activeGoals: ["Sleep before midnight"],
            relevantMemories: [],
            sessionBiases: [],
            retrievalTags: [BASDecisionMode.reflective.identifier],
            reactionWeights: .defaults(for: BASDecisionMode.reflective.identifier),
            failureGuardIDs: ["night_fast_path_failure"],
            loadedAt: .now
        )

        let policy = BASBoundaryPolicyEvaluator.evaluate(
            mode: .reflective,
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
        #expect(policy.allowedActionClasses.contains("lightweight_capture"))
        #expect(policy.allowedActionClasses.contains("checkpoint_reopen"))
        #expect(policy.blockedActionClasses.contains("deep_editor_surface"))
    }

    @Test("calibration evaluator flags drift when high-risk flow is under-constrained")
    func calibrationEvaluatorFlagsDriftWhenHighRiskFlowIsUnderConstrained() {
        let brainState = BASDecisionBrainState(
            memorySlices: [],
            sessionBiases: [],
            retrievalTags: [],
            reactionWeights: .defaults(for: BASDecisionMode.primary.identifier),
            identityProfile: .default(modeName: BASDecisionMode.primary.identifier),
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
            identityProfile: .default(modeName: BASDecisionMode.primary.identifier),
            boundaryPolicy: brainState.boundaryPolicy,
            now: .now
        )

        #expect(calibration.status != .stable)
        #expect(calibration.alerts.contains(.underConstrainedHighRisk))
        #expect(calibration.alerts.contains(.templateCoverageGap))
        #expect(calibration.driftScore > 0.3)
    }
}
#endif
