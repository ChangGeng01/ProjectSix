import XCTest
import BASHostKit
@testable import Before

final class DecisionEvolutionReleaseSummaryBuilderTests: XCTestCase {
    func testBuilderBlocksWhenActiveKillSwitchesArePresent() {
        let active = makeSnapshot(
            checkpointID: "active-1",
            createdAt: Date(timeIntervalSince1970: 10),
            approvalState: .automatic,
            hasLineage: true
        )
        let controlSurface = DecisionEvolutionControlSurface(
            activeCheckpoint: active,
            activeCheckpointSource: .pinnedHint,
            reviewCheckpoint: nil,
            pendingReviewQueue: [],
            latestPersistedLineage: nil,
            restorableCheckpointIDs: ["previous-active-1"]
        )

        let summary = DecisionEvolutionReleaseSummaryBuilder.build(
            evolutionControlSurface: controlSurface,
            eBrainSummary: nil,
            dominantBlockers: [],
            activeKillSwitches: ["force_guard_mode"],
            recommendedKillSwitchesHint: ["external-tools"]
        )

        XCTAssertEqual(summary.state, .blocked)
        XCTAssertEqual(summary.headline, "Blocked by active kill switches")
        XCTAssertEqual(summary.activeKillSwitches, ["force_guard_mode"])
        XCTAssertEqual(summary.recommendedKillSwitches, ["external-tools"])
        XCTAssertEqual(summary.killSwitches, ["force_guard_mode", "external-tools"])
    }

    func testBuilderSurfacesQueueRecommendationsWhenReviewRemains() {
        let active = makeSnapshot(
            checkpointID: "active-1",
            createdAt: Date(timeIntervalSince1970: 10),
            approvalState: .automatic,
            hasLineage: true
        )
        let review = makeSnapshot(
            checkpointID: "review-1",
            createdAt: Date(timeIntervalSince1970: 20),
            approvalState: .reviewSuggested,
            hasLineage: true,
            killSwitches: ["external-tools"]
        )
        let controlSurface = DecisionEvolutionControlSurface(
            activeCheckpoint: active,
            activeCheckpointSource: .pinnedHint,
            reviewCheckpoint: review,
            pendingReviewQueue: [review],
            latestPersistedLineage: nil,
            restorableCheckpointIDs: ["previous-active-1", "previous-review-1"]
        )

        let summary = DecisionEvolutionReleaseSummaryBuilder.build(
            evolutionControlSurface: controlSurface,
            eBrainSummary: nil,
            dominantBlockers: [],
            activeKillSwitches: [],
            recommendedKillSwitchesHint: []
        )

        XCTAssertEqual(summary.state, .watch)
        XCTAssertEqual(summary.headline, "Watching recommended kill switches")
        XCTAssertEqual(summary.pendingReviewCount, 1)
        XCTAssertEqual(summary.recommendedKillSwitches, ["external-tools"])
        XCTAssertTrue(summary.reasons.contains("Recommended kill switches are waiting for operator review before wider rollout."))
    }

    func testPresentationBuildCarriesCheckpointAndKillSwitchCopy() {
        let active = makeSnapshot(
            checkpointID: "active-1",
            createdAt: Date(timeIntervalSince1970: 10),
            approvalState: .automatic,
            hasLineage: true
        )
        let review = makeSnapshot(
            checkpointID: "review-1",
            createdAt: Date(timeIntervalSince1970: 20),
            approvalState: .reviewSuggested,
            hasLineage: true,
            killSwitches: ["external-tools"]
        )
        let controlSurface = DecisionEvolutionControlSurface(
            activeCheckpoint: active,
            activeCheckpointSource: .pinnedHint,
            reviewCheckpoint: review,
            pendingReviewQueue: [review],
            latestPersistedLineage: nil,
            restorableCheckpointIDs: ["previous-active-1", "previous-review-1"]
        )
        let summary = DecisionEvolutionReleaseSummaryBuilder.build(
            evolutionControlSurface: controlSurface,
            eBrainSummary: nil,
            dominantBlockers: [],
            activeKillSwitches: ["force_guard_mode"],
            recommendedKillSwitchesHint: ["external-tools"]
        )

        let presentation = DecisionEvolutionReleaseSummaryPresentation.build(
            releaseSummary: summary,
            controlSurface: controlSurface,
            presentationMode: .surface
        )

        XCTAssertEqual(presentation.activeSourceText, "Active source: Pinned active")
        XCTAssertEqual(presentation.activeKillSwitchesText, "Active kill switches: force_guard_mode")
        XCTAssertEqual(presentation.recommendedKillSwitchesText, "Recommended kill switches: external-tools")
        XCTAssertEqual(presentation.activeCheckpointHeadline, "Active: active-1 • Automatic • HIGH → DELAY")
        XCTAssertEqual(presentation.reviewCheckpointHeadline, "Review head: review-1 • Review suggested • HIGH → DELAY")
    }

    func testPresentationBuildCarriesMutationHubOperatorCopy() {
        let summary = DecisionSystemReleaseControlSummary(
            state: .watch,
            headline: "Watching the pending review queue",
            reasons: ["Queue review remains pending."],
            activeKillSwitches: [],
            recommendedKillSwitches: [],
            killSwitches: [],
            pendingReviewCount: 1,
            rollbackReadyCount: 0,
            canRestoreActiveCheckpoint: false,
            canRollbackActiveCheckpoint: false,
            activeCheckpointID: nil,
            activeCheckpointSource: .none,
            reviewCheckpointID: nil
        )

        let presentation = DecisionEvolutionReleaseSummaryPresentation.build(
            releaseSummary: summary,
            controlSurface: DecisionEvolutionControlSurface(
                activeCheckpoint: nil,
                reviewCheckpoint: nil,
                pendingReviewQueue: [],
                latestPersistedLineage: nil
            ),
            presentationMode: .mutationHub
        )

        XCTAssertEqual(presentation.operatorHeadline, "Mutation hub")
        XCTAssertTrue(presentation.operatorDetail?.contains("Apply, approve, rollback") == true)
    }

    private func makeSnapshot(
        checkpointID: String,
        createdAt: Date,
        approvalState: DecisionEvolutionApprovalState,
        hasLineage: Bool,
        killSwitches: [String] = []
    ) -> DecisionReviewCheckpointSnapshot {
        DecisionReviewCheckpointSnapshot(
            checkpointID: checkpointID,
            previousCheckpointID: "previous-\(checkpointID)",
            createdAt: createdAt,
            mode: .mirror,
            approvalState: approvalState,
            rollbackReady: true,
            hasBrainStateSnapshot: true,
            diffSummary: ["checkpoint \(checkpointID)"],
            eBrain: hasLineage ? DeveloperDecisionReplayEBrainSummary(
                lineageSummary: BASEvolutionLineageSummary(
                    recordedAt: createdAt,
                    sessionID: "session-\(checkpointID)",
                    taskType: "decision",
                    riskLevel: "high",
                    permitMode: "delay",
                    hostGatePercent: 73,
                    thoughtFoldChecksum: "fold-\(checkpointID)",
                    updateTicketSummaries: ["ticket-\(checkpointID)"],
                    activeKillSwitches: [],
                    guardrailFindings: ["guardrail-\(checkpointID)"],
                    recommendedKillSwitches: killSwitches
                )
            ) : nil,
            fallbackRiskLevel: "watch",
            fallbackPermitMode: "delay"
        )
    }
}
