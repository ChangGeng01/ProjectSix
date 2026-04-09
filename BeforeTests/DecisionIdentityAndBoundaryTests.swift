import XCTest
@testable import Before

final class DecisionIdentityAndBoundaryTests: XCTestCase {
    func testNotificationHighRiskUsesPredictiveSentinelProfile() {
        let profile = DecisionIdentityRoleSystem.resolve(
            mode: .quick,
            source: .notification,
            sourceSurface: .notification,
            riskLevel: .high
        )

        XCTAssertEqual(profile.role, .predictiveSentinel)
        XCTAssertEqual(profile.posture, .protective)
        XCTAssertEqual(profile.initiative, .assertive)
        XCTAssertFalse(profile.canExecuteActions)
        XCTAssertFalse(profile.canEscalateToCloud)
    }

    func testWatchBoundaryPolicyStaysLocalAndLightweight() {
        let identity = DecisionIdentityRoleSystem.resolve(
            mode: .mirror,
            source: .watchHandoff,
            sourceSurface: .watch,
            riskLevel: .high
        )
        let taskGraph = DecisionTaskGraphSnapshot(
            mode: .mirror,
            promptSeed: "Do not send this tonight.",
            nextActionHint: "Reopen tomorrow.",
            continuityFingerprint: "fp",
            tasks: [
                DecisionTaskNode(
                    kind: .evaluate,
                    title: "Pause",
                    detail: "Reopen tomorrow",
                    status: .inProgress
                )
            ],
            updatedAt: Date()
        )
        let brainState = DecisionBrainState(
            profileCore: [],
            activeGoals: ["Sleep before midnight"],
            relevantMemories: [],
            sessionBiases: [],
            retrievalTags: ["mirror"],
            reactionWeights: .defaults(for: .mirror),
            failureGuardIDs: ["night_fast_path_failure"],
            loadedAt: .now
        )

        let policy = DecisionBoundaryPolicyEngine.evaluate(
            mode: .mirror,
            source: .watchHandoff,
            sourceSurface: .watch,
            riskLevel: .high,
            identityProfile: identity,
            brainState: brainState,
            taskGraph: taskGraph
        )

        XCTAssertEqual(policy.mode, DecisionBoundaryPolicyMode.localOnlyProtective)
        XCTAssertTrue(policy.activeConstraints.contains(DecisionBoundaryConstraint.noCloudEscalation))
        XCTAssertTrue(policy.activeConstraints.contains(DecisionBoundaryConstraint.lockSensitiveMemory))
        XCTAssertTrue(policy.activeConstraints.contains(DecisionBoundaryConstraint.watchSurfaceLightweight))
        XCTAssertTrue(policy.requiredConfirmations.contains("irreversible_decision"))
        XCTAssertTrue(policy.allowedActionClasses.contains("quick_capture"))
        XCTAssertTrue(policy.allowedActionClasses.contains("checkpoint_reopen"))
        XCTAssertTrue(policy.blockedActionClasses.contains("cloud_escalation"))
        XCTAssertTrue(policy.blockedActionClasses.contains("deep_editor_surface"))
    }
}
