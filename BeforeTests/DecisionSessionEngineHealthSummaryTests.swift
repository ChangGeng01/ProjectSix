import XCTest
@testable import Before

final class DecisionSessionEngineHealthSummaryTests: XCTestCase {
    func testGlobalSummaryReturnsNilForEmptyInventory() {
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
            signals: []
        )

        XCTAssertNil(DecisionSessionEngineHealthSummary.summary(from: summary))
    }

    func testGlobalSummaryPrefersWatchdogOverdueOverOtherSignals() {
        let overdueSession = DecisionSessionRuntimeInspectionSession(
            sessionID: "sess-overdue",
            title: "parser repair",
            status: .active,
            updatedAt: Date(timeIntervalSince1970: 100),
            headBranchID: "branch-main",
            latestCheckpointID: "ckpt-1",
            latestCheckpointSeq: 8,
            latestCheckpointGoal: "repair parser only",
            latestEventID: "evt-9",
            latestEventSeq: 9,
            latestEventType: .stepHeartbeat,
            latestEventDetail: "tool still running",
            openStepCount: 1,
            openStepStatus: .waitingTool,
            stalledStepCount: 0,
            branchCount: 2,
            mergeableBranchCount: 1,
            recoveryCount: 0,
            latestRecoveryAt: nil,
            openStepID: "step-overdue",
            openStepHeartbeatAt: Date(timeIntervalSince1970: 90),
            openStepUpdatedAt: Date(timeIntervalSince1970: 90),
            openStepTTLms: 15_000,
            openStepRemainingMs: -2_000,
            openStepIsHeartbeatOverdue: true
        )
        let summary = DecisionSystemSessionEngineSummary(
            layerPlacement: .foldedLung,
            sessions: 1,
            activeSessions: 1,
            stalledSessions: 0,
            mergeReadySessions: 1,
            mergeableBranches: 1,
            branches: 2,
            checkpoints: 1,
            events: 9,
            steps: 1,
            activeSession: overdueSession,
            recentSessions: [overdueSession],
            headline: "Session Engine L3.folded_lung protects edits, checkpoints, and recovery.",
            signals: []
        )

        let healthSummary = DecisionSessionEngineHealthSummary.summary(from: summary)

        XCTAssertEqual(healthSummary?.severity, .critical)
        XCTAssertEqual(healthSummary?.title, "Watchdog overdue")
    }

    func testSessionSummaryReturnsRecoveredCheckpointLineWhenRecoveriesExist() {
        let inspection = DecisionSessionRuntimeInspectionSession(
            sessionID: "sess-recovered",
            title: "history rebuild",
            status: .active,
            updatedAt: Date(timeIntervalSince1970: 120),
            headBranchID: "branch-main",
            latestCheckpointID: "ckpt-9",
            latestCheckpointSeq: 9,
            latestCheckpointGoal: "repair parser",
            latestEventID: "evt-10",
            latestEventSeq: 10,
            latestEventType: .stepRecovered,
            latestEventDetail: "Recovered from stalled step.",
            openStepCount: 0,
            openStepStatus: nil,
            stalledStepCount: 0,
            branchCount: 1,
            recoveryCount: 1,
            latestRecoveryAt: Date(timeIntervalSince1970: 125)
        )

        let healthSummary = DecisionSessionEngineHealthSummary.summary(
            sessionStatus: .active,
            inspection: inspection
        )

        XCTAssertEqual(healthSummary?.severity, .stable)
        XCTAssertEqual(healthSummary?.title, "Recovered checkpoint line")
        XCTAssertTrue(healthSummary?.detail.contains("Recovered") == true)
    }

    func testGlobalSummaryReturnsHorizonDiagnosticsWhenCheckpointFactsCarryCaveatSignals() {
        let inspection = DecisionSessionRuntimeInspectionSession(
            sessionID: "sess-horizon",
            title: "policy refresh",
            status: .active,
            updatedAt: Date(timeIntervalSince1970: 180),
            headBranchID: "branch-main",
            latestCheckpointID: "ckpt-12",
            latestCheckpointSeq: 12,
            latestCheckpointGoal: "refresh volatile facts",
            latestCheckpointEBrainAnchor: DecisionSessionCheckpointEBrainAnchor(
                sessionID: "sess-horizon",
                thoughtFoldChecksum: "fold12abc",
                riskLevel: "guarded",
                permitMode: "replace",
                hostGatePercent: 58,
                riskFactorsLine: "Factors: evidence_caveat_load",
                reasonCodesLine: "Reason codes: evidence.caveat"
            ),
            latestEventID: "evt-12",
            latestEventSeq: 12,
            latestEventType: .assistantMessage,
            latestEventDetail: "Stable checkpoint preserved.",
            openStepCount: 0,
            openStepStatus: nil,
            stalledStepCount: 0,
            branchCount: 1,
            recoveryCount: 0,
            latestRecoveryAt: nil
        )
        let summary = DecisionSystemSessionEngineSummary(
            layerPlacement: .foldedLung,
            sessions: 1,
            activeSessions: 1,
            stalledSessions: 0,
            branches: 1,
            checkpoints: 1,
            events: 12,
            steps: 0,
            activeSession: inspection,
            recentSessions: [inspection],
            headline: "Session Engine L3.folded_lung protects edits, checkpoints, and recovery.",
            signals: []
        )

        let healthSummary = DecisionSessionEngineHealthSummary.summary(from: summary)

        XCTAssertEqual(healthSummary?.severity, .watch)
        XCTAssertEqual(healthSummary?.title, "Horizon diagnostics active")
        XCTAssertEqual(
            healthSummary?.detail,
            "Factors: evidence_caveat_load • Reason codes: evidence.caveat"
        )
    }

    func testSessionSummaryReturnsRecoveryReadyForStalledSession() {
        let inspection = DecisionSessionRuntimeInspectionSession(
            sessionID: "sess-stalled",
            title: "tool rewrite",
            status: .stalled,
            updatedAt: Date(timeIntervalSince1970: 200),
            headBranchID: "branch-main",
            latestCheckpointID: "ckpt-11",
            latestCheckpointSeq: 11,
            latestCheckpointGoal: "rewrite parser",
            latestEventID: "evt-12",
            latestEventSeq: 12,
            latestEventType: .sessionError,
            latestEventDetail: "incomplete tool step",
            openStepCount: 1,
            openStepStatus: .stalled,
            stalledStepCount: 1,
            branchCount: 2,
            recoveryCount: 0,
            latestRecoveryAt: nil
        )

        let healthSummary = DecisionSessionEngineHealthSummary.summary(
            sessionStatus: .stalled,
            inspection: inspection
        )

        XCTAssertEqual(healthSummary?.severity, .watch)
        XCTAssertEqual(healthSummary?.title, "Recovery ready")
    }

    func testSessionSummaryReturnsHorizonDiagnosticsForCheckpointCaveats() {
        let inspection = DecisionSessionRuntimeInspectionSession(
            sessionID: "sess-caveat",
            title: "latest policy review",
            status: .active,
            updatedAt: Date(timeIntervalSince1970: 220),
            headBranchID: "branch-main",
            latestCheckpointID: "ckpt-14",
            latestCheckpointSeq: 14,
            latestCheckpointGoal: "preserve stable facts only",
            latestCheckpointEBrainAnchor: DecisionSessionCheckpointEBrainAnchor(
                sessionID: "sess-caveat",
                thoughtFoldChecksum: "fold14abc",
                riskLevel: "guarded",
                permitMode: "delay",
                hostGatePercent: 44,
                riskFactorsLine: "Factors: evidence_caveat_load",
                reasonCodesLine: "Reason codes: evidence.caveat"
            ),
            latestEventID: "evt-14",
            latestEventSeq: 14,
            latestEventType: .assistantMessage,
            latestEventDetail: "Checkpoint remains stable.",
            openStepCount: 0,
            openStepStatus: nil,
            stalledStepCount: 0,
            branchCount: 1,
            recoveryCount: 0,
            latestRecoveryAt: nil
        )

        let healthSummary = DecisionSessionEngineHealthSummary.summary(
            sessionStatus: .active,
            inspection: inspection
        )

        XCTAssertEqual(healthSummary?.severity, .watch)
        XCTAssertEqual(healthSummary?.title, "Horizon diagnostics active")
        XCTAssertEqual(
            healthSummary?.detail,
            "Factors: evidence_caveat_load • Reason codes: evidence.caveat"
        )
    }
}
