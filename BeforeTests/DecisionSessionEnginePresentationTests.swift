import XCTest
@testable import Before

final class DecisionSessionEnginePresentationTests: XCTestCase {
    func testPresentationBuildsEmptyStateWithoutSummary() {
        let presentation = DecisionSessionEnginePresentation.build(from: nil)

        XCTAssertEqual(presentation.title, "Session engine")
        XCTAssertNil(presentation.activeSession)
        XCTAssertTrue(presentation.recentSessions.isEmpty)
        XCTAssertFalse(presentation.emptyMessage.isEmpty)
    }

    func testPresentationCarriesActiveAndRecentSessionInspection() {
        let active = DecisionSessionRuntimeInspectionSession(
            sessionID: "sess-active",
            title: "parser repair",
            status: .active,
            updatedAt: Date(timeIntervalSince1970: 100),
            headBranchID: "branch-active",
            latestCheckpointID: "ckpt-9",
            latestCheckpointSeq: 9,
            latestCheckpointGoal: "repair parser",
            latestCheckpointBudgetLine: "eBrain budget: engage • loops 2 • candidates 2 • decode 192",
            latestCheckpointRouteLine: "eBrain route: npu • precision mixed • retrieval 3",
            latestCheckpointDecisionLine: "eBrain risk: guarded • eBrain permit: replace • eBrain host gate: 61% • eBrain fold: fold9abc",
            latestCheckpointTaskLine: "Review update ticket: preserve parser-only correction",
            latestCheckpointActionLine: "action: restored active quick workspace state",
            latestEventID: "evt-10",
            latestEventSeq: 10,
            latestEventType: .stepRecovered,
            latestEventDetail: "Recovered from stalled tool step.",
            openStepCount: 1,
            openStepStatus: .planning,
            stalledStepCount: 0,
            branchCount: 2,
            mergeableBranchCount: 1,
            recoveryCount: 1,
            latestRecoveryAt: Date(timeIntervalSince1970: 120),
            openStepID: "step-active",
            openStepHeartbeatAt: Date(timeIntervalSince1970: 99),
            openStepUpdatedAt: Date(timeIntervalSince1970: 99),
            openStepTTLms: 15_000,
            openStepRemainingMs: 7_000,
            openStepIsHeartbeatOverdue: false
        )
        let recent = DecisionSessionRuntimeInspectionSession(
            sessionID: "sess-recent",
            title: "history rebuild",
            status: .paused,
            updatedAt: Date(timeIntervalSince1970: 90),
            headBranchID: "branch-recent",
            latestCheckpointID: nil,
            latestCheckpointSeq: nil,
            latestCheckpointGoal: nil,
            latestEventID: "evt-4",
            latestEventSeq: 4,
            latestEventType: .assistantMessage,
            latestEventDetail: "Stable branch preserved.",
            openStepCount: 0,
            openStepStatus: nil,
            stalledStepCount: 1,
            branchCount: 1,
            recoveryCount: 0,
            latestRecoveryAt: nil
        )
        let summary = DecisionSystemSessionEngineSummary(
            layerPlacement: .foldedLung,
            sessions: 2,
            activeSessions: 1,
            stalledSessions: 1,
            mergeReadySessions: 1,
            mergeableBranches: 1,
            branches: 3,
            checkpoints: 4,
            events: 10,
            steps: 2,
            activeSession: active,
            recentSessions: [active, recent],
            headline: "Session Engine L3.folded_lung protects edits, checkpoints, and recovery.",
            signals: []
        )

        let presentation = DecisionSessionEnginePresentation.build(from: summary)

        XCTAssertEqual(presentation.activeSession?.sessionID, "sess-active")
        XCTAssertEqual(presentation.recentSessions.map(\.sessionID), ["sess-recent"])
        XCTAssertTrue(presentation.countsLine.contains("Sessions 2"))
        XCTAssertTrue(presentation.countsLine.contains("Checkpoints 4"))
        XCTAssertEqual(presentation.healthSummary?.severity, .watch)
        XCTAssertEqual(presentation.healthSummary?.title, "Recovery attention required")
        XCTAssertTrue(presentation.healthLine?.contains("Stalled sessions 1") == true)
        XCTAssertEqual(presentation.reviewItems.map(\.title), [
            "Merge review queue",
            "Replay anchor ready"
        ])
        XCTAssertTrue(presentation.reviewItems[0].detail.contains("Merge-ready branches 1"))
        XCTAssertTrue(presentation.reviewItems[1].detail.contains("Checkpoint ckpt-9"))
        XCTAssertEqual(presentation.activeSession?.healthSummary?.severity, .stable)
        XCTAssertEqual(presentation.activeSession?.healthSummary?.title, "Recovered checkpoint line")
        XCTAssertEqual(presentation.activeSession?.replayRecoverySummary.sourceDescriptor.kind, .checkpointRecovery)
        XCTAssertEqual(presentation.activeSession?.replayRecoverySummary.title, "Checkpoint recovery")
        XCTAssertTrue(presentation.activeSession?.replayRecoverySummary.replayLine.contains("sess-active") == true)
        XCTAssertEqual(
            presentation.activeSession?.replayRecoverySummary.detailLine,
            "Checkpoint ckpt-9 • repair parser"
        )
        XCTAssertNil(presentation.activeSession?.replayRecoverySummary.killSwitchesLine)
        XCTAssertTrue(presentation.activeSession?.checkpointLine.contains("ckpt-9") == true)
        XCTAssertEqual(
            presentation.activeSession?.checkpointBudgetLine,
            "eBrain budget: engage • loops 2 • candidates 2 • decode 192 • eBrain route: npu • precision mixed • retrieval 3"
        )
        XCTAssertEqual(
            presentation.activeSession?.checkpointDecisionLine,
            "eBrain risk: guarded • eBrain permit: replace • eBrain host gate: 61% • eBrain fold: fold9abc"
        )
        XCTAssertEqual(
            presentation.activeSession?.checkpointTaskLine,
            "Review update ticket: preserve parser-only correction"
        )
        XCTAssertEqual(
            presentation.activeSession?.checkpointActionLine,
            "action: restored active quick workspace state"
        )
        XCTAssertEqual(
            presentation.activeSession?.replayRecoverySummary.actionLine,
            "action: restored active quick workspace state"
        )
        XCTAssertTrue(presentation.activeSession?.activityLine.contains("Open steps 1") == true)
        XCTAssertTrue(presentation.activeSession?.branchLine.contains("Merge-ready 1") == true)
        XCTAssertEqual(
            presentation.activeSession?.mergeReviewLine,
            "Merge review 1 active correction branch can append back onto head without rewriting history."
        )
        XCTAssertEqual(presentation.activeSession?.stepFreshnessLine, "Step planning • ttl 7s remaining")
        XCTAssertNil(presentation.activeSession?.stepAlertLine)
        XCTAssertFalse(presentation.activeSession?.canRecover == true)
        XCTAssertEqual(presentation.recentSessions.first?.healthSummary?.severity, .watch)
        XCTAssertEqual(presentation.recentSessions.first?.healthSummary?.title, "Recovery ready")
        XCTAssertEqual(presentation.recentSessions.first?.recoveryLine, "Recoveries 0")
        XCTAssertTrue(presentation.recentSessions.first?.canRecover == true)
        XCTAssertEqual(
            presentation.recentSessions.first?.stepAlertLine,
            "A stalled step was detected. Recovery should stay available from the last stable checkpoint."
        )
        XCTAssertEqual(presentation.recentSessions.first?.replayRecoverySummary.sourceDescriptor.kind, .checkpointRecovery)
        XCTAssertEqual(presentation.recentSessions.first?.replayRecoverySummary.title, "Checkpoint recovery")
    }

    func testPresentationMarksHeartbeatOverdueSessionRecoverable() {
        let overdue = DecisionSessionRuntimeInspectionSession(
            sessionID: "sess-overdue",
            title: "tool rewrite",
            status: .active,
            updatedAt: Date(timeIntervalSince1970: 200),
            headBranchID: "branch-overdue",
            latestCheckpointID: "ckpt-overdue",
            latestCheckpointSeq: 12,
            latestCheckpointGoal: "rewrite parser",
            latestEventID: "evt-overdue",
            latestEventSeq: 13,
            latestEventType: .stepHeartbeat,
            latestEventDetail: "tool still running",
            openStepCount: 1,
            openStepStatus: .waitingTool,
            stalledStepCount: 0,
            branchCount: 1,
            recoveryCount: 0,
            latestRecoveryAt: nil,
            openStepID: "step-overdue",
            openStepHeartbeatAt: Date(timeIntervalSince1970: 150),
            openStepUpdatedAt: Date(timeIntervalSince1970: 150),
            openStepTTLms: 20_000,
            openStepRemainingMs: -2_000,
            openStepIsHeartbeatOverdue: true
        )
        let summary = DecisionSystemSessionEngineSummary(
            layerPlacement: .foldedLung,
            sessions: 1,
            activeSessions: 1,
            stalledSessions: 0,
            branches: 1,
            checkpoints: 1,
            events: 3,
            steps: 1,
            activeSession: overdue,
            recentSessions: [overdue],
            headline: "Session Engine L3.folded_lung protects edits, checkpoints, and recovery.",
            signals: []
        )

        let presentation = DecisionSessionEnginePresentation.build(from: summary)

        XCTAssertEqual(presentation.healthSummary?.severity, .critical)
        XCTAssertEqual(presentation.healthSummary?.title, "Watchdog overdue")
        XCTAssertTrue(presentation.healthLine?.contains("outlived its watchdog budget") == true)
        XCTAssertTrue(presentation.activeSession?.canRecover == true)
        XCTAssertEqual(presentation.activeSession?.healthSummary?.severity, .critical)
        XCTAssertEqual(presentation.activeSession?.healthSummary?.title, "Watchdog expired")
        XCTAssertEqual(presentation.activeSession?.stepFreshnessLine, "Step waiting tool • watchdog overdue")
        XCTAssertEqual(
            presentation.activeSession?.stepAlertLine,
            "Watchdog budget expired on the current open step. Recover before continuing."
        )
    }

    func testPresentationCarriesPendingImportPreview() {
        let pendingImport = DecisionSessionEnginePendingImportPreview(
            sourceFileName: "parser-session.json",
            preview: DecisionSessionImportBundlePreview(
                id: "preview-1",
                sourceSessionId: "sess-exported",
                sourceTitle: "Parser repair",
                importedTitle: "Parser repair (Imported)",
                exportedAt: Date(timeIntervalSince1970: 300),
                countsLine: "Branches 2 • Checkpoints 3 • Events 12 • Steps 1",
                integrityLine: "Validated schema v1 • fingerprint abcdef123456",
                checkpointLine: "Latest checkpoint ckpt-7 • repair parser",
                branchLine: "Head main • Layer folded_lung",
                unfinishedStepsLine: "Open steps 1 • unfinished work will import as failed recovery facts.",
                headline: "Importing creates a new paused recovery-safe session.",
                branchPreviews: []
            )
        )
        let summary = DecisionSystemSessionEngineSummary(
            layerPlacement: .foldedLung,
            sessions: 0,
            activeSessions: 0,
            stalledSessions: 0,
            branches: 0,
            checkpoints: 0,
            events: 0,
            steps: 0,
            activeSession: nil,
            recentSessions: [],
            headline: "Session Engine L3.folded_lung protects edits, checkpoints, and recovery.",
            signals: [],
            pendingImportPreview: pendingImport.presentation
        )

        let presentation = DecisionSessionEnginePresentation.build(from: summary)

        XCTAssertEqual(presentation.pendingImportPreview?.bundleLine, "Bundle parser-session.json")
        XCTAssertEqual(presentation.pendingImportPreview?.importedLine, "Will import as Parser repair (Imported)")
        XCTAssertEqual(presentation.pendingImportPreview?.unfinishedWorkSummary.severity, .watch)
        XCTAssertEqual(presentation.reviewItems.first?.title, "Pending import draft")
        XCTAssertTrue(presentation.reviewItems.first?.detail.contains("Bundle parser-session.json") == true)
        XCTAssertNil(presentation.activeSession)
        XCTAssertTrue(presentation.recentSessions.isEmpty)
    }

    func testPresentationMarksGlobalMergeReviewPressureWhenNoStallOrWatchdogIssueExists() {
        let active = DecisionSessionRuntimeInspectionSession(
            sessionID: "sess-merge",
            title: "branch review",
            status: .active,
            updatedAt: Date(timeIntervalSince1970: 500),
            headBranchID: "branch-main",
            latestCheckpointID: "ckpt-merge",
            latestCheckpointSeq: 14,
            latestCheckpointGoal: "merge correction",
            latestEventID: "evt-merge",
            latestEventSeq: 15,
            latestEventType: .assistantMessage,
            latestEventDetail: "ready for merge review",
            openStepCount: 0,
            openStepStatus: nil,
            stalledStepCount: 0,
            branchCount: 3,
            mergeableBranchCount: 2,
            recoveryCount: 0,
            latestRecoveryAt: nil
        )
        let summary = DecisionSystemSessionEngineSummary(
            layerPlacement: .foldedLung,
            sessions: 1,
            activeSessions: 1,
            stalledSessions: 0,
            mergeReadySessions: 1,
            mergeableBranches: 2,
            branches: 3,
            checkpoints: 2,
            events: 8,
            steps: 1,
            activeSession: active,
            recentSessions: [active],
            headline: "Session Engine L3.folded_lung protects edits, checkpoints, and recovery.",
            signals: []
        )

        let presentation = DecisionSessionEnginePresentation.build(from: summary)

        XCTAssertTrue(presentation.countsLine.contains("Merge-ready 2"))
        XCTAssertEqual(presentation.healthSummary?.severity, .watch)
        XCTAssertEqual(presentation.healthSummary?.title, "Merge review pending")
        XCTAssertTrue(presentation.healthLine?.contains("Merge-ready sessions 1") == true)
        XCTAssertEqual(presentation.activeSession?.replayRecoverySummary.sourceDescriptor.kind, .liveRuntime)
        XCTAssertEqual(presentation.activeSession?.replayRecoverySummary.title, "Live runtime")
        XCTAssertTrue(presentation.activeSession?.replayRecoverySummary.replayLine.contains("sess-merge") == true)
        XCTAssertNil(presentation.activeSession?.replayRecoverySummary.killSwitchesLine)
        XCTAssertEqual(presentation.reviewItems.map(\.title), [
            "Merge review queue",
            "Replay anchor ready"
        ])
        XCTAssertTrue(presentation.reviewItems[0].detail.contains("Merge-ready branches 2"))
        XCTAssertTrue(presentation.reviewItems[1].detail.contains("Checkpoint ckpt-merge"))
    }
}
