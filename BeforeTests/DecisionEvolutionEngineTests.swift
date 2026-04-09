import XCTest
import SwiftData
@testable import Before

final class DecisionEvolutionEngineTests: XCTestCase {
    @MainActor
    func testEvolutionEngineDeduplicatesEquivalentCheckpointState() throws {
        let container = try ModelContainer(
            for: DecisionEvolutionCheckpoint.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext
        let now = Date()
        let brainState = DecisionBrainState(
            profileCore: ["Keep it brief."],
            activeGoals: ["Protect sleep"],
            relevantMemories: ["Tomorrow Box helps at night."],
            sessionBiases: ["Stay local."],
            retrievalTags: ["quick", "night"],
            reactionWeights: .defaults(for: .quick),
            loadedAt: now
        )

        let first = DecisionEvolutionEngine.recordCheckpoint(
            mode: .quick,
            source: .launch,
            brainState: brainState,
            context: context,
            now: now
        )
        let second = DecisionEvolutionEngine.recordCheckpoint(
            mode: .quick,
            source: .launch,
            brainState: brainState,
            context: context,
            now: now.addingTimeInterval(60)
        )

        let checkpoints = try context.fetch(FetchDescriptor<DecisionEvolutionCheckpoint>())
        XCTAssertEqual(checkpoints.count, 1)
        XCTAssertEqual(first.checkpointCount, 1)
        XCTAssertEqual(second.checkpointCount, 1)
        XCTAssertTrue(second.rollbackReady)
    }

    @MainActor
    func testEvolutionEngineMarksReviewSuggestedWhenCalibrationIsDrifting() throws {
        let container = try ModelContainer(
            for: DecisionEvolutionCheckpoint.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext

        let boundaryPolicy = DecisionBoundaryPolicyState(
            mode: .localOnlyProtective,
            riskLevel: .high,
            allowedActionClasses: ["render_local_guidance"],
            blockedActionClasses: ["cloud_escalation"],
            requiredConfirmations: ["irreversible_decision"],
            activeConstraints: [.noCloudEscalation, .lockSensitiveMemory],
            auditHeadline: "Stay local."
        )
        let calibrationState = DecisionCalibrationState(
            status: .drifting,
            alerts: [.highPendingInfluence, .lowTrustLoad],
            suggestedAdjustments: ["Tighten retrieval."],
            driftScore: 0.64,
            generatedAt: .now
        )
        let brainState = DecisionBrainState(
            memorySlices: [
                DecisionGovernedMemorySlice(
                    id: "drifted",
                    role: .relevant,
                    type: "semantic",
                    headline: "Weak pattern",
                    source: "reflection",
                    confidence: 0.4,
                    priority: 0.4,
                    lifecycleState: "pending",
                    governanceStatus: .deferred,
                    eligibility: .allowed(.pendingTagOverlap),
                    sourceTrustScore: 0.2,
                    sourceTrustTier: .low,
                    retrievalTags: ["mirror"],
                    isPending: true,
                    provenanceSummary: "Weak inferred evidence."
                )
            ],
            sessionBiases: [],
            retrievalTags: ["mirror"],
            reactionWeights: .defaults(for: .mirror),
            identityProfile: DecisionIdentityProfile.default(for: .mirror),
            boundaryPolicy: boundaryPolicy,
            calibrationState: calibrationState,
            loadedAt: .now
        )

        let evolutionState = DecisionEvolutionEngine.recordCheckpoint(
            mode: .mirror,
            source: .sceneActive,
            brainState: brainState,
            context: context,
            now: .now
        )

        let checkpoints = try context.fetch(FetchDescriptor<DecisionEvolutionCheckpoint>())
        XCTAssertEqual(checkpoints.count, 1)
        XCTAssertEqual(checkpoints.first?.approvalState, .reviewSuggested)
        XCTAssertEqual(evolutionState.pendingReviewCount, 1)
        XCTAssertTrue(evolutionState.recentDiffSummary.contains(where: { $0.contains("first local cognition checkpoint") }))
    }
}
