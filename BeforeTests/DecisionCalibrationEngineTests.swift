import XCTest
import BASHostKit
@testable import Before

final class DecisionCalibrationEngineTests: XCTestCase {
    func testCalibrationEngineFlagsDriftingHighRiskBrainState() {
        let identity = DecisionIdentityProfile(
            role: .predictiveSentinel,
            posture: .protective,
            initiative: .assertive,
            confidenceCeiling: 0.6,
            canAdvise: true,
            canExecuteActions: false,
            canEscalateToCloud: false,
            relationshipBoundary: "Interrupt momentum."
        )
        let boundaryPolicy = DecisionBoundaryPolicyState(
            mode: .localOnlyAdvisory,
            riskLevel: .high,
            allowedActionClasses: ["render_local_guidance"],
            blockedActionClasses: ["cloud_escalation"],
            requiredConfirmations: [],
            activeConstraints: [.noCloudEscalation],
            auditHeadline: "Too loose for high-risk work."
        )
        let brainState = DecisionBrainState(
            memorySlices: [
                DecisionGovernedMemorySlice(
                    id: "pending.lowtrust",
                    role: .relevant,
                    type: "semantic",
                    headline: "Unverified pattern",
                    source: "reflection",
                    confidence: 0.42,
                    priority: 0.4,
                    lifecycleState: "pending",
                    governanceStatus: .deferred,
                    eligibility: .allowed(.pendingTagOverlap),
                    sourceTrustScore: 0.2,
                    sourceTrustTier: .low,
                    retrievalTags: ["night"],
                    isPending: true,
                    provenanceSummary: "Single weak inferred event."
                )
            ],
            sessionBiases: [],
            retrievalTags: ["quick", "night"],
            reactionWeights: .defaults(for: .quick),
            identityProfile: identity,
            boundaryPolicy: boundaryPolicy,
            activeInterventionTemplateIDs: [],
            memoryGovernance: DecisionMemoryGovernanceState(
                totalRecordCount: 1,
                totalCandidateCount: 1,
                pendingCandidateCount: 1,
                promotedCandidateCount: 0,
                loadedPromotedMemoryCount: 0,
                loadedPendingMemoryCount: 1
            ),
            loadedAt: .now
        )

        let calibration = DecisionCalibrationEngine.evaluate(
            brainState: brainState,
            riskLevel: .high,
            identityProfile: identity,
            boundaryPolicy: boundaryPolicy,
            now: .now
        )

        XCTAssertEqual(calibration.status, .drifting)
        XCTAssertTrue(calibration.alerts.contains(.highPendingInfluence))
        XCTAssertTrue(calibration.alerts.contains(.lowTrustLoad))
        XCTAssertTrue(calibration.alerts.contains(.underConstrainedHighRisk))
        XCTAssertTrue(calibration.alerts.contains(.templateCoverageGap))
        XCTAssertGreaterThan(calibration.driftScore, 0.5)
        XCTAssertEqual(calibration.packageCalibrationReport.status, BASRegressionStatus.fail)
        XCTAssertFalse(calibration.packageCalibrationReport.summary.isEmpty)
    }
}
