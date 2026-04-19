import XCTest
@testable import Before

final class DecisionSessionEngineControlSnapshotTests: XCTestCase {
    func testControlSnapshotBuildsEmptyStateWithoutSessions() {
        let snapshot = DecisionSessionEngineControlSnapshot.build(
            runtimeSnapshot: nil,
            sessions: [],
            inspectionBySessionID: [:],
            selectedSessionID: nil,
            selectedBranchID: nil,
            selectedBranches: [],
            selectedCheckpoint: nil,
            selectedTimeline: nil
        )

        XCTAssertTrue(snapshot.sessions.isEmpty)
        XCTAssertNil(snapshot.selectedBranchID)
        XCTAssertTrue(snapshot.selectedBranches.isEmpty)
        XCTAssertTrue(snapshot.timelineItems.isEmpty)
        XCTAssertNil(snapshot.selectedSessionID)
        XCTAssertTrue(snapshot.reviewItems.isEmpty)
        XCTAssertNil(snapshot.pendingImportPreview)
        XCTAssertEqual(snapshot.emptyMessage, "No Session Engine session has been recorded yet.")
    }

    func testControlSnapshotBuildsSelectedSessionAndTimeline() throws {
        let now = Date(timeIntervalSince1970: 1_000)
        let session = DecisionSession(
            id: "sess_1",
            title: "Parser repair",
            createdAt: now,
            updatedAt: now.addingTimeInterval(60),
            status: .stalled,
            headBranchId: "branch_main",
            latestCheckpointId: "ckpt_1"
        )
        let inspection = DecisionSessionRuntimeInspectionSession(
            sessionID: session.id,
            title: session.title,
            status: .stalled,
            updatedAt: session.updatedAt,
            headBranchID: session.headBranchId,
            latestCheckpointID: "ckpt_1",
            latestCheckpointSeq: 8,
            latestCheckpointGoal: "repair parser only",
            latestCheckpointBudgetLine: "eBrain budget: guarded • loops 1 • candidates 1 • decode 128 • thermal watch",
            latestCheckpointRouteLine: "eBrain route: cpu • precision low • retrieval 1",
            latestCheckpointDecisionLine: "eBrain risk: guarded • eBrain permit: delay • eBrain host gate: 40% • eBrain fold: fold1abc",
            latestCheckpointTaskLine: "Review protective path: delay",
            latestCheckpointPressureLine: "eBrain pressure: latency 57/900ms • power 32% • cache 100% • thermal warm -> watch",
            latestCheckpointAuditLine: "eBrain audit findings: 1",
            latestCheckpointActiveKillSwitchesLine: "eBrain active kill switches: force_guard_mode",
            latestCheckpointKillSwitchesLine: "eBrain active kill switches: force_guard_mode • eBrain recommended kill switches: require_reviewed_writes",
            latestCheckpointActionLine: "action: restored active quick workspace state",
            latestCheckpointEBrainAnchor: DecisionSessionCheckpointEBrainAnchor(
                sessionID: session.id,
                thoughtFoldChecksum: "fold1abc",
                riskLevel: "guarded",
                permitMode: "delay",
                hostGatePercent: 40,
                riskFactorsLine: "Factors: evidence_caveat_load",
                reasonCodesLine: "Reason codes: evidence.caveat",
                sovereignVerdictLine: "Sovereign verdict quarantine • latched • mode guard • reason runtime.quarantine",
                sovereignAuthorityLine: "Sovereign authority • tokens memoryWrite • lock session • quarantine session",
                sovereignAuditLine: "Sovereign audit • BR-SOV-004 • ref audit.session-l14",
            ),
            latestEventID: "evt_9",
            latestEventSeq: 9,
            latestEventType: .sessionError,
            latestEventDetail: "stalled step",
            openStepCount: 1,
            openStepStatus: .stalled,
            stalledStepCount: 1,
            branchCount: 2,
            mergeableBranchCount: 1,
            recoveryCount: 1,
            latestRecoveryAt: now.addingTimeInterval(120),
            openStepID: "step_stalled",
            openStepHeartbeatAt: now.addingTimeInterval(30),
            openStepUpdatedAt: now.addingTimeInterval(30),
            openStepTTLms: 15_000,
            openStepRemainingMs: -3_000,
            openStepIsHeartbeatOverdue: true
        )
        let runtimeSnapshot = DecisionSessionRuntimeSnapshot(
            layerPlacement: .foldedLung,
            sessions: 1,
            activeSessions: 0,
            stalledSessions: 1,
            branches: 2,
            checkpoints: 1,
            events: 9,
            steps: 1,
            recentSessions: [inspection]
        )
        let checkpoint = DecisionSessionCheckpoint(
            id: "ckpt_1",
            sessionId: session.id,
            branchId: session.headBranchId,
            basedOnEventSeq: 8,
            createdAt: now,
            summary: DecisionSessionCheckpointSummary(
                goal: "repair parser only",
                acceptedConstraints: ["keep history"],
                confirmedFacts: ["parser isolated"],
                openTasks: ["recover"],
                currentScope: ["src/parser.ts"]
            ),
            runtimeState: .empty,
            integrity: DecisionSessionCheckpointIntegrity(
                eventHash: "evt_hash",
                previousCheckpointHash: nil
            ),
            previousCheckpointId: nil,
            checkpointHash: "ckpt_hash"
        )
        let branches = [
            DecisionSessionBranch(
                id: "branch_main",
                sessionId: session.id,
                parentBranchId: nil,
                baseCheckpointId: nil,
                name: "main",
                createdAt: now,
                status: .active
            ),
            DecisionSessionBranch(
                id: "branch_recovery",
                sessionId: session.id,
                parentBranchId: "branch_main",
                baseCheckpointId: "ckpt_1",
                name: "recovery-main",
                createdAt: now.addingTimeInterval(120),
                status: .active
            )
        ]
        let timeline = DecisionSessionTimeline(
            sessionId: session.id,
            branchId: session.headBranchId,
            checkpoint: checkpoint,
            items: [
                DecisionSessionTimelineItem(
                    id: "checkpoint-ckpt_1",
                    createdAt: now,
                    branchId: session.headBranchId,
                    title: "Checkpoint ckpt_1",
                    detail: "repair parser only",
                    kind: .checkpoint(checkpoint)
                ),
                DecisionSessionTimelineItem(
                    id: "event-evt_10",
                    createdAt: now.addingTimeInterval(10),
                    branchId: session.headBranchId,
                    title: "session_recovered",
                    detail: "Recovered from last checkpoint.",
                    kind: .event(
                        DecisionSessionEvent(
                            id: "evt_10",
                            sessionId: session.id,
                            branchId: session.headBranchId,
                            seq: 10,
                            createdAt: now.addingTimeInterval(10),
                            type: .sessionRecovered,
                            parentEventId: nil,
                            payloadRef: nil,
                            payloadHash: "payload",
                            recordHash: "record"
                        )
                    )
                )
            ],
            recoveryNotice: "Recovered from the last stable checkpoint after an incomplete or stalled step.",
            mergeNotice: "Latest checkpoint on main already folded in merge facts from correction-8."
        )

        let snapshot = DecisionSessionEngineControlSnapshot.build(
            runtimeSnapshot: runtimeSnapshot,
            sessions: [session],
            inspectionBySessionID: [session.id: inspection],
            selectedSessionID: session.id,
            selectedBranchID: branches[1].id,
            selectedBranches: branches,
            selectedCheckpoint: checkpoint,
            selectedTimeline: timeline
        )

        XCTAssertEqual(snapshot.selectedSessionID, session.id)
        XCTAssertEqual(snapshot.selectedBranchID, branches[1].id)
        XCTAssertEqual(snapshot.sessions.count, 1)
        XCTAssertEqual(snapshot.sessions[0].healthSummary?.severity, .critical)
        XCTAssertEqual(snapshot.sessions[0].healthSummary?.title, "Watchdog expired")
        XCTAssertTrue(snapshot.sessions[0].canRecover)
        XCTAssertTrue(snapshot.sessions[0].canCorrect)
        XCTAssertEqual(snapshot.reviewItems.map(\.title), [
            "Merge review queue",
            "Replay anchor ready",
            "Sovereign posture",
            "Horizon diagnostics"
        ])
        XCTAssertTrue(snapshot.reviewItems[0].detail.contains("Merge-ready branches 1"))
        XCTAssertTrue(snapshot.reviewItems[1].detail.contains("Checkpoint ckpt_1"))
        XCTAssertEqual(
            snapshot.reviewItems[2].detail,
            "Sovereign verdict quarantine • latched • mode guard • reason runtime.quarantine • Sovereign authority • tokens memoryWrite • lock session • quarantine session • Sovereign audit • BR-SOV-004 • ref audit.session-l14"
        )
        XCTAssertEqual(snapshot.reviewItems[2].severity, .watch)
        XCTAssertEqual(
            snapshot.reviewItems[3].detail,
            "Factors: evidence_caveat_load • Reason codes: evidence.caveat"
        )
        XCTAssertEqual(
            snapshot.sessions[0].checkpointBudgetLine,
            "eBrain budget: guarded • loops 1 • candidates 1 • decode 128 • thermal watch • eBrain route: cpu • precision low • retrieval 1"
        )
        XCTAssertEqual(
            snapshot.sessions[0].checkpointPressureLine,
            "eBrain pressure: latency 57/900ms • power 32% • cache 100% • thermal warm -> watch"
        )
        XCTAssertEqual(
            snapshot.sessions[0].checkpointDecisionLine,
            "eBrain risk: guarded • eBrain permit: delay • eBrain host gate: 40% • eBrain fold: fold1abc"
        )
        XCTAssertEqual(snapshot.sessions[0].checkpointTaskLine, "Review protective path: delay")
        XCTAssertEqual(
            snapshot.sessions[0].checkpointActionLine,
            "action: restored active quick workspace state"
        )
        XCTAssertEqual(snapshot.sessions[0].checkpointAuditLine, "eBrain audit findings: 1")
        XCTAssertEqual(
            snapshot.sessions[0].checkpointSovereignVerdictLine,
            "Sovereign verdict quarantine • latched • mode guard • reason runtime.quarantine"
        )
        XCTAssertEqual(
            snapshot.sessions[0].checkpointSovereignAuthorityLine,
            "Sovereign authority • tokens memoryWrite • lock session • quarantine session"
        )
        XCTAssertEqual(
            snapshot.sessions[0].checkpointSovereignAuditLine,
            "Sovereign audit • BR-SOV-004 • ref audit.session-l14"
        )
        XCTAssertEqual(
            snapshot.sessions[0].checkpointKillSwitchesLine,
            "eBrain active kill switches: force_guard_mode • eBrain recommended kill switches: require_reviewed_writes"
        )
        XCTAssertEqual(snapshot.sessions[0].checkpointRiskFactorsLine, "Factors: evidence_caveat_load")
        XCTAssertEqual(snapshot.sessions[0].checkpointReasonCodesLine, "Reason codes: evidence.caveat")
        XCTAssertTrue(snapshot.sessions[0].branchLine.contains("Merge-ready 1"))
        XCTAssertEqual(
            snapshot.sessions[0].mergeReviewLine,
            "Merge review 1 active correction branch can append back onto head without rewriting history."
        )
        let mergeReview = try XCTUnwrap(snapshot.selectedMergeReview)
        XCTAssertEqual(mergeReview.sourceBranchID, "branch_recovery")
        XCTAssertEqual(mergeReview.targetBranchID, "branch_main")
        XCTAssertEqual(mergeReview.detailRows.map(\.label), [
            "Source branch",
            "Target branch",
            "Source status",
            "Target status",
            "Checkpoint"
        ])
        XCTAssertEqual(mergeReview.detailRows[0].value, "recovery-main • branch_recovery")
        XCTAssertEqual(mergeReview.detailRows[1].value, "main • branch_main")
        XCTAssertEqual(mergeReview.detailRows[2].value, "Active")
        XCTAssertEqual(mergeReview.detailRows[3].value, "Active • current head")
        XCTAssertEqual(mergeReview.detailRows[4].value, "Selected checkpoint ckpt_1 • repair parser only")
        XCTAssertEqual(
            snapshot.sessions[0].faultLine,
            "Fault line • watchdog expired on the current open step."
        )
        XCTAssertEqual(snapshot.sessions[0].stepFreshnessLine, "Step stalled • watchdog overdue")
        XCTAssertEqual(
            snapshot.sessions[0].stepAlertLine,
            "Watchdog budget expired on the current open step. Recover before continuing."
        )
        XCTAssertEqual(snapshot.selectedBranches.count, 2)
        XCTAssertEqual(snapshot.selectedBranches[0].name, "main")
        XCTAssertTrue(snapshot.selectedBranches[0].isHead)
        XCTAssertFalse(snapshot.selectedBranches[0].isInspecting)
        XCTAssertFalse(snapshot.selectedBranches[0].canSwitch)
        XCTAssertFalse(snapshot.selectedBranches[0].canMerge)
        XCTAssertFalse(snapshot.selectedBranches[0].canAbandon)
        XCTAssertEqual(snapshot.selectedBranches[1].name, "recovery-main")
        XCTAssertTrue(snapshot.selectedBranches[1].detailLine.contains("Recovery branch"))
        XCTAssertTrue(snapshot.selectedBranches[1].isInspecting)
        XCTAssertTrue(snapshot.selectedBranches[1].canSwitch)
        XCTAssertTrue(snapshot.selectedBranches[1].canMerge)
        XCTAssertTrue(snapshot.selectedBranches[1].canAbandon)
        XCTAssertEqual(snapshot.timelineItems.count, 2)
        XCTAssertEqual(snapshot.selectedCheckpointID, "ckpt_1")
        XCTAssertEqual(snapshot.timelineItems.first?.checkpointID, "ckpt_1")
        XCTAssertEqual(snapshot.timelineItems.first?.seqLine, "Checkpoint event seq 8")
        XCTAssertTrue(snapshot.timelineItems.first?.canRestoreCheckpoint == true)
        XCTAssertFalse(snapshot.timelineItems.first?.canTargetCorrection == true)
        XCTAssertEqual(snapshot.selectedCheckpointLine, "Checkpoint ckpt_1 • repair parser only")
        XCTAssertEqual(snapshot.selectedBranchesLine, "Branches 2 • Head main")
        XCTAssertEqual(snapshot.selectedRecoveryNotice, timeline.recoveryNotice)
        XCTAssertEqual(snapshot.selectedMergeNotice, timeline.mergeNotice)
        XCTAssertTrue(snapshot.timelineItems.contains(where: { $0.emphasizesRecovery }))
        let recoveredEvent = try XCTUnwrap(snapshot.timelineItems.last)
        XCTAssertEqual(recoveredEvent.eventID, "evt_10")
        XCTAssertEqual(recoveredEvent.seqLine, "Event seq 10")
        XCTAssertFalse(recoveredEvent.canTargetCorrection)
    }

    func testControlSnapshotMarksUserFacingHistoryEventsAsCorrectionTargets() throws {
        let now = Date(timeIntervalSince1970: 2_000)
        let session = DecisionSession(
            id: "sess_2",
            title: "Parser repair",
            createdAt: now,
            updatedAt: now,
            status: .active,
            headBranchId: "branch_main",
            latestCheckpointId: nil
        )
        let event = DecisionSessionEvent(
            id: "evt_user",
            sessionId: session.id,
            branchId: session.headBranchId,
            seq: 3,
            createdAt: now,
            type: .userMessage,
            parentEventId: nil,
            payloadRef: nil,
            payloadHash: "payload",
            recordHash: "record"
        )
        let timeline = DecisionSessionTimeline(
            sessionId: session.id,
            branchId: session.headBranchId,
            checkpoint: nil,
            items: [
                DecisionSessionTimelineItem(
                    id: "event-evt_user",
                    createdAt: now,
                    branchId: session.headBranchId,
                    title: "user_message",
                    detail: "Only fix the parser path.",
                    kind: .event(event)
                )
            ],
            recoveryNotice: nil,
            mergeNotice: nil
        )

        let snapshot = DecisionSessionEngineControlSnapshot.build(
            runtimeSnapshot: nil,
            sessions: [session],
            inspectionBySessionID: [:],
            selectedSessionID: session.id,
            selectedBranchID: session.headBranchId,
            selectedBranches: [],
            selectedCheckpoint: nil,
            selectedTimeline: timeline
        )

        let targetableItem = try XCTUnwrap(snapshot.timelineItems.first)
        XCTAssertEqual(targetableItem.eventID, "evt_user")
        XCTAssertEqual(targetableItem.seqLine, "Event seq 3")
        XCTAssertTrue(targetableItem.canTargetCorrection)
    }

    func testControlSnapshotCarriesPendingImportReviewDigest() {
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
                unfinishedStepCount: 1,
                unfinishedStepsLine: "Open steps 1 • unfinished work will import as failed recovery facts.",
                headline: "Importing creates a new paused recovery-safe session.",
                branchPreviews: []
            )
        )

        let snapshot = DecisionSessionEngineControlSnapshot.build(
            runtimeSnapshot: nil,
            sessions: [],
            inspectionBySessionID: [:],
            selectedSessionID: nil,
            selectedBranchID: nil,
            selectedBranches: [],
            selectedCheckpoint: nil,
            selectedTimeline: nil,
            pendingImportPreview: pendingImport.presentation
        )

        XCTAssertEqual(snapshot.reviewItems.map(\.title), ["Pending import draft"])
        XCTAssertTrue(snapshot.reviewItems[0].detail.contains("Bundle parser-session.json"))
        XCTAssertEqual(snapshot.pendingImportPreview?.bundleLine, "Bundle parser-session.json")
    }
}
