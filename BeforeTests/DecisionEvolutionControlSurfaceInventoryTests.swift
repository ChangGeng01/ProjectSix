import Foundation
import Testing
import BASHostKit
@testable import Before

struct DecisionEvolutionControlSurfaceInventoryTests {
    @Test
    func inventoryPrefersContextMatchedAutomaticLineage() {
        let quickOlder = makeLineage(
            checkpointID: "quick-older",
            createdAt: Date(timeIntervalSince1970: 10),
            mode: .quick,
            approvalState: .automatic,
            source: .persistedCheckpoint
        )
        let balanceCloser = makeLineage(
            checkpointID: "balance-closer",
            createdAt: Date(timeIntervalSince1970: 20),
            mode: .balance,
            approvalState: .automatic,
            source: .liveRuntime
        )
        let inventory = DecisionEvolutionControlSurfaceInventory(
            pendingReviewQueue: [],
            persistedLineages: [quickOlder, balanceCloser],
            activeCheckpoint: nil,
            restorableCheckpointIDs: []
        )
        let context = DecisionTestingCheckpointSelectionContext(
            mode: .balance,
            source: .liveRuntime,
            referenceDate: Date(timeIntervalSince1970: 21)
        )

        #expect(
            inventory.latestAutomaticLineage(matching: context)?.checkpointID == "balance-closer"
        )
        #expect(
            inventory.buildControlSurface(
                preferredCheckpointSelectionContext: context
            ).latestPersistedLineage?.checkpointID == "balance-closer"
        )
    }

    @Test
    func inventorySurfaceBuildPreservesPendingQueueAndRollbackFacts() {
        let review = DecisionReviewCheckpointSnapshot(
            checkpointID: "review-1",
            previousCheckpointID: "approved-1",
            createdAt: Date(timeIntervalSince1970: 50),
            mode: .mirror,
            approvalState: .reviewSuggested,
            rollbackReady: true,
            hasBrainStateSnapshot: true,
            diffSummary: ["review queue item"],
            eBrain: makeReplaySummary(
                checkpointID: "review-1",
                recordedAt: Date(timeIntervalSince1970: 50),
                source: .persistedCheckpoint
            ),
            fallbackRiskLevel: "watch",
            fallbackPermitMode: "delay"
        )
        let active = DecisionReviewCheckpointSnapshot(
            checkpointID: "approved-1",
            previousCheckpointID: "approved-0",
            createdAt: Date(timeIntervalSince1970: 40),
            mode: .quick,
            approvalState: .automatic,
            rollbackReady: true,
            hasBrainStateSnapshot: true,
            diffSummary: ["approved active"],
            eBrain: makeReplaySummary(
                checkpointID: "approved-1",
                recordedAt: Date(timeIntervalSince1970: 40),
                source: .liveRuntime
            ),
            fallbackRiskLevel: "stable",
            fallbackPermitMode: "answer"
        )

        let inventory = DecisionEvolutionControlSurfaceInventory(
            pendingReviewQueue: [review],
            persistedLineages: [],
            activeCheckpoint: active,
            restorableCheckpointIDs: ["approved-0", "approved-1"]
        )

        let surface = inventory.buildControlSurface()

        #expect(surface.activeCheckpoint?.checkpointID == "approved-1")
        #expect(surface.reviewCheckpoint?.checkpointID == "review-1")
        #expect(surface.pendingReviewCount == 1)
        #expect(surface.activeRollbackCheckpointID == "approved-0")
    }

    private func makeLineage(
        checkpointID: String,
        createdAt: Date,
        mode: DecisionMode,
        approvalState: DecisionEvolutionApprovalState,
        source: DeveloperDecisionReplayEBrainSource
    ) -> DecisionEvolutionLineageSnapshot {
        DecisionEvolutionLineageSnapshot(
            checkpointID: checkpointID,
            previousCheckpointID: nil,
            createdAt: createdAt,
            mode: mode,
            approvalState: approvalState,
            rollbackReady: false,
            hasBrainStateSnapshot: false,
            diffSummary: [checkpointID],
            eBrain: makeReplaySummary(
                checkpointID: checkpointID,
                recordedAt: createdAt,
                source: source
            )
        )
    }

    private func makeReplaySummary(
        checkpointID: String,
        recordedAt: Date,
        source: DeveloperDecisionReplayEBrainSource
    ) -> DeveloperDecisionReplayEBrainSummary {
        DeveloperDecisionReplayEBrainSummary(lineageSummary: BASEvolutionLineageSummary(
            recordedAt: recordedAt,
            sessionID: "session-\(checkpointID)",
            taskType: source == .liveRuntime ? "decision-live" : "decision-persisted",
            riskLevel: "high",
            permitMode: "delay",
            hostGatePercent: 75,
            thoughtFoldChecksum: "fold-\(checkpointID)",
            updateTicketSummaries: ["ticket-\(checkpointID)"],
            guardrailFindings: [],
            recommendedKillSwitches: []
        ))
    }
}
