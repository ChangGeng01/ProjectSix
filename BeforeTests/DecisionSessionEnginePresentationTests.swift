import XCTest
import BASHostKit
@testable import Before

final class DecisionSessionEnginePresentationTests: XCTestCase {
    private func abbreviatedDateTime(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .shortened)
    }

    private func shortenedTime(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }

    func testRecoveryPresentationSupportProvidesRecordedAndCompactRecoveryLines() {
        let recordedAt = Date(timeIntervalSince1970: 36_000)

        XCTAssertEqual(
            DecisionSessionRecoveryPresentationSupport.recordedRecoveryLine(
                latestRecoveryAt: recordedAt,
                recoveryCount: 2
            ),
            "Recoveries 2 • latest \(shortenedTime(recordedAt))"
        )
        XCTAssertEqual(
            DecisionSessionRecoveryPresentationSupport.recordedRecoveryLine(
                latestRecoveryAt: nil,
                recoveryCount: 1
            ),
            "Recoveries 1 • latest recorded"
        )
        XCTAssertEqual(
            DecisionSessionRecoveryPresentationSupport.recordedRecoveryLine(
                latestRecoveryAt: nil,
                recoveryCount: 0
            ),
            "Recoveries 0"
        )
        XCTAssertEqual(
            DecisionSessionRecoveryPresentationSupport.compactRecoveryLine(
                latestRecoveryAt: recordedAt,
                recoveryCount: 2
            ),
            "Recovered \(shortenedTime(recordedAt))"
        )
        XCTAssertEqual(
            DecisionSessionRecoveryPresentationSupport.compactRecoveryLine(
                latestRecoveryAt: nil,
                recoveryCount: 2
            ),
            "Recoveries 2"
        )
        XCTAssertEqual(
            DecisionSessionRecoveryPresentationSupport.watchdogExpiredLine,
            "Watchdog budget expired on the current open step. Recover before continuing."
        )
        XCTAssertEqual(
            DecisionSessionRecoveryPresentationSupport.stalledRecoveryLine,
            "A stalled step was detected. Recovery should stay available from the last stable checkpoint."
        )
        XCTAssertEqual(
            DecisionSessionRecoveryPresentationSupport.pausedRecoveryLine,
            "The session is paused, but its stable checkpoint line remains available for recovery."
        )
        XCTAssertEqual(
            DecisionSessionRecoveryPresentationSupport.protectedExecutionLine(activeSessions: 2),
            "Active sessions 2 • Recovery line stays attached to the latest stable checkpoint."
        )
    }

    func testInspectionPresentationSupportBuildsCheckpointAndBranchDescriptors() {
        XCTAssertEqual(
            DecisionSessionTimelinePresentationSupport.branchMergedDetail(
                sourceBranchID: "branch-correction",
                targetBranchID: "branch-main"
            ),
            "Merged branch branch-correction into branch-main"
        )
        XCTAssertEqual(
            DecisionSessionTimelinePresentationSupport.toolStartedDetail(
                tool: "import_bundle"
            ),
            "Tool started: import_bundle"
        )
        XCTAssertEqual(
            DecisionSessionTimelinePresentationSupport.toolFailedDetail(
                tool: "import_bundle",
                errorCode: "invalid_manifest"
            ),
            "Tool failed: import_bundle • invalid_manifest"
        )
        XCTAssertEqual(
            DecisionSessionTimelinePresentationSupport.checkpointCreatedDetail(
                basedOnEventSeq: 42
            ),
            "Checkpoint created at event 42"
        )
        XCTAssertEqual(
            DecisionSessionTimelinePresentationSupport.heartbeatDetail(
                stepID: "step-1",
                progress: 0.42
            ),
            "Heartbeat step-1 • 42%"
        )
        XCTAssertEqual(
            DecisionSessionTimelinePresentationSupport.branchCreatedDetail(
                fromCheckpointID: nil
            ),
            "Branch created from root"
        )
        XCTAssertEqual(
            DecisionSessionTimelinePresentationSupport.foldedMergeNotice(
                branchName: "main",
                foldedSources: "correction-parser",
                visibleSources: "recovery-watchdog"
            ),
            "Latest checkpoint on main already folded in merge facts from correction-parser. Newer merge events remain visible for recovery-watchdog."
        )
        XCTAssertEqual(
            DecisionSessionTimelinePresentationSupport.visibleMergeNotice(
                visibleSources: "correction-parser"
            ),
            "This branch recorded merge events after the latest checkpoint from correction-parser."
        )
        XCTAssertEqual(
            DecisionSessionInspectionPresentationSupport.eventLine(
                latestEventType: .toolCallStarted
            ),
            "tool call started"
        )
        XCTAssertEqual(
            DecisionSessionInspectionPresentationSupport.statusLine(
                status: .active,
                latestEventType: .assistantMessage
            ),
            "Active • assistant message"
        )
        XCTAssertEqual(
            DecisionSessionInspectionPresentationSupport.headline(
                title: "parser repair",
                status: .stalled,
                latestEventType: .stepRecovered
            ),
            "parser repair • stalled • step_recovered"
        )
        XCTAssertEqual(
            DecisionSessionInspectionPresentationSupport.fallbackDetailLine(
                sessionID: "sess-9",
                updatedAt: Date(timeIntervalSince1970: 36_000)
            ),
            "Session sess-9 • updated \(abbreviatedDateTime(Date(timeIntervalSince1970: 36_000)))"
        )
        XCTAssertEqual(
            DecisionSessionInspectionPresentationSupport.checkpointLine(
                checkpointID: "ckpt-9",
                goal: "repair parser"
            ),
            "Checkpoint ckpt-9 • repair parser"
        )
        XCTAssertEqual(
            DecisionSessionInspectionPresentationSupport.checkpointLine(
                checkpointID: nil,
                goal: "ignored"
            ),
            "Checkpoint none"
        )
        XCTAssertEqual(
            DecisionSessionInspectionPresentationSupport.checkpointAnchorLine(
                checkpointID: "ckpt-9",
                goal: "",
                basedOnEventSeq: 42
            ),
            "Checkpoint ckpt-9 at event 42"
        )
        XCTAssertEqual(
            DecisionSessionInspectionPresentationSupport.selectedCheckpointLine(
                checkpointID: "ckpt-9",
                goal: "repair parser"
            ),
            "Selected checkpoint ckpt-9 • repair parser"
        )
        XCTAssertEqual(
            DecisionSessionInspectionPresentationSupport.selectedCheckpointAnchorLine(
                checkpoint: DecisionSessionCheckpoint(
                    id: "ckpt-9",
                    sessionId: "sess-1",
                    branchId: "branch-main",
                    basedOnEventSeq: 42,
                    createdAt: Date(timeIntervalSince1970: 300),
                    summary: DecisionSessionCheckpointSummary(
                        goal: "repair parser",
                        acceptedConstraints: [],
                        confirmedFacts: [],
                        openTasks: [],
                        currentScope: []
                    ),
                    runtimeState: .empty,
                    integrity: DecisionSessionCheckpointIntegrity(
                        eventHash: "evt-hash-1",
                        previousCheckpointHash: nil
                    ),
                    previousCheckpointId: nil,
                    checkpointHash: "ckpt-hash-1"
                )
            ),
            "Checkpoint ckpt-9 • repair parser"
        )
        XCTAssertEqual(
            DecisionSessionInspectionPresentationSupport.openStepLine(
                count: 2,
                status: .waitingTool
            ),
            "Open steps 2 • waiting tool"
        )
        XCTAssertEqual(
            DecisionSessionInspectionPresentationSupport.branchLine(
                branchCount: 3,
                latestEventSeq: 42,
                latestCheckpointSeq: 40,
                mergeableBranchCount: 1
            ),
            "Branches 3 • Latest seq 42 • Merge-ready 1"
        )
        XCTAssertEqual(
            DecisionSessionInspectionPresentationSupport.controlBranchLine(
                headBranchID: "branch-main",
                branchCount: 3,
                mergeableBranchCount: 1
            ),
            "Head branch-main • Branches 3 • Merge-ready 1"
        )
        XCTAssertEqual(
            DecisionSessionReviewPresentationSupport.pendingImportDetail(
                bundleLine: "Bundle parser-session.json",
                importedLine: "Will import as Parser repair (Imported)"
            ),
            DecisionEvolutionNarrativeFormattingSupport.joined([
                "Will import as Parser repair (Imported)",
                "Bundle parser-session.json"
            ])
        )
        XCTAssertEqual(
            DecisionSessionReviewPresentationSupport.pendingImportDigestLine(
                preview: DecisionSessionEngineImportPreviewPresentation(
                    title: "Import Session Engine bundle",
                    headline: DecisionSessionReviewPresentationSupport.importPreviewHeadline,
                    bundleLine: "Bundle parser-session.json",
                    sourceLine: "Source Parser repair",
                    importedLine: "Will import as Parser repair (Imported)",
                    countsLine: "Branches 2 • Checkpoints 3 • Events 12 • Steps 1",
                    integrityLine: "Validated schema v1 • fingerprint abcdef123456",
                    checkpointLine: "Latest checkpoint ckpt-7 • repair parser",
                    branchLine: "Head main • Layer L3.folded_lung",
                    unfinishedWorkSummary: DecisionSessionEngineHealthSummary(
                        severity: .watch,
                        title: "Open work will be normalized",
                        detail: "Open steps 1 • unfinished work will import as failed recovery facts."
                    ),
                    detailRows: [],
                    branchPresentations: []
                )
            ),
            DecisionSessionEngineReviewDigestLine(
                id: "pending-import",
                title: "Pending import draft",
                detail: DecisionEvolutionNarrativeFormattingSupport.joined([
                    "Will import as Parser repair (Imported)",
                    "Bundle parser-session.json"
                ]),
                severity: .watch
            )
        )
        XCTAssertEqual(
            DecisionSessionReviewPresentationSupport.importBundleTitle,
            "Import Session Engine bundle"
        )
        XCTAssertEqual(
            DecisionSessionReviewPresentationSupport.importBundleLine(
                sourceFileName: "parser-session.json"
            ),
            "Bundle parser-session.json"
        )
        XCTAssertEqual(
            DecisionSessionReviewPresentationSupport.importSourceLine(
                sourceTitle: "Parser repair"
            ),
            "Source Parser repair"
        )
        XCTAssertEqual(
            DecisionSessionReviewPresentationSupport.importAsLine(
                importedTitle: "Parser repair (Imported)"
            ),
            "Will import as Parser repair (Imported)"
        )
        XCTAssertEqual(
            DecisionSessionReviewPresentationSupport.mergeReviewDetail(
                mergeReadySessions: 1,
                mergeableBranches: 2
            ),
            DecisionEvolutionNarrativeFormattingSupport.joined([
                "Merge-ready sessions 1",
                "Merge-ready branches 2",
                "Review correction branches before they drift from head."
            ])
        )
        XCTAssertEqual(
            DecisionSessionReviewPresentationSupport.mergeReviewDigestLine(
                mergeReadySessions: 1,
                mergeableBranches: 2
            ),
            DecisionSessionEngineReviewDigestLine(
                id: "merge-review",
                title: "Merge review queue",
                detail: DecisionEvolutionNarrativeFormattingSupport.joined([
                    "Merge-ready sessions 1",
                    "Merge-ready branches 2",
                    "Review correction branches before they drift from head."
                ]),
                severity: .watch
            )
        )
        XCTAssertEqual(
            DecisionSessionReviewPresentationSupport.replaySessionLine(
                sessionID: "sess-active",
                headBranchID: "branch-main"
            ),
            DecisionEvolutionNarrativeFormattingSupport.joined([
                "Replay session sess-active",
                "Head branch-main"
            ])
        )
        XCTAssertEqual(
            DecisionSessionReviewPresentationSupport.replayAnchorDigestLine(
                session: DecisionSessionRuntimeInspectionSession(
                    sessionID: "sess-active",
                    title: "parser repair",
                    status: .active,
                    updatedAt: Date(timeIntervalSince1970: 120),
                    headBranchID: "branch-main",
                    latestCheckpointID: "ckpt-9",
                    latestCheckpointSeq: 9,
                    latestCheckpointGoal: "repair parser",
                    latestEventID: "evt-10",
                    latestEventSeq: 10,
                    latestEventType: .assistantMessage,
                    latestEventDetail: "Stable branch preserved.",
                    openStepCount: 0,
                    openStepStatus: nil,
                    stalledStepCount: 0,
                    branchCount: 2,
                    mergeableBranchCount: 1,
                    recoveryCount: 0,
                    latestRecoveryAt: nil
                )
            ),
            DecisionSessionEngineReviewDigestLine(
                id: "replay-anchor",
                title: "Replay anchor ready",
                detail: "parser repair • Checkpoint ckpt-9 • repair parser remains available for rebuild and recovery branch creation.",
                severity: .stable
            )
        )
        XCTAssertEqual(
            DecisionSessionReviewPresentationSupport.checkpointDetailLine(
                checkpointID: "ckpt-9",
                goal: "repair parser"
            ),
            "Checkpoint ckpt-9 • repair parser"
        )
        XCTAssertEqual(
            DecisionSessionReviewPresentationSupport.mergeReviewLine(
                mergeableBranchCount: 1
            ),
            "Merge review 1 active correction branch can append back onto head without rewriting history."
        )
        XCTAssertEqual(
            DecisionSessionReviewPresentationSupport.mergeRouteLine(
                sourceBranchName: "correction-parser",
                targetBranchName: "main"
            ),
            "correction-parser → main"
        )
        XCTAssertEqual(
            DecisionSessionReviewPresentationSupport.mergeReviewSummary(
                detail: "Merge will append a branch_merged fact onto head."
            ),
            DecisionSessionEngineHealthSummary(
                severity: .stable,
                title: "Append-only merge",
                detail: "Merge will append a branch_merged fact onto head."
            )
        )
        XCTAssertEqual(
            DecisionSessionReviewPresentationSupport.detailPresentation(
                id: "checkpoint",
                label: "Checkpoint",
                value: "Selected checkpoint ckpt-9 • repair parser"
            ),
            DecisionSessionEngineReviewDetailPresentation(
                id: "checkpoint",
                label: "Checkpoint",
                value: "Selected checkpoint ckpt-9 • repair parser"
            )
        )
        let summary = DecisionSystemSessionEngineSummary(
            layerPlacement: .foldedLung,
            sessions: 2,
            activeSessions: 1,
            stalledSessions: 1,
            mergeReadySessions: 1,
            mergeableBranches: 2,
            branches: 3,
            checkpoints: 4,
            events: 10,
            steps: 2,
            activeSession: nil,
            recentSessions: [],
            headline: "Session Engine L3.folded_lung protects edits, checkpoints, and recovery.",
            signals: []
        )
        XCTAssertEqual(
            DecisionSessionControlPresentationSupport.countsLine(from: summary),
            "Sessions 2 • Active 1 • Stalled 1 • Merge-ready 2 • Branches 3 • Checkpoints 4"
        )
        XCTAssertEqual(
            DecisionSessionControlPresentationSupport.countsLine(
                runtimeSnapshot: DecisionSessionRuntimeSnapshot(
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
                    recentSessions: []
                ),
                synthesizedSummary: summary
            ),
            "Sessions 2 • Active 1 • Stalled 1 • Merge-ready 2 • Branches 3 • Checkpoints 4"
        )
        XCTAssertEqual(
            DecisionSessionControlPresentationSupport.countsLine(
                runtimeSnapshot: nil,
                synthesizedSummary: summary
            ),
            DecisionSessionControlPresentationSupport.unavailableCountsLine
        )
        XCTAssertEqual(
            DecisionSessionControlPresentationSupport.selectedBranchesLine(
                branchCount: 2,
                headName: "main"
            ),
            "Branches 2 • Head main"
        )
        XCTAssertEqual(
            DecisionSessionControlPresentationSupport.selectedBranchesLine(
                branchPresentations: [
                    DecisionSessionEngineControlBranchPresentation(
                        id: "branch-main",
                        name: "main",
                        statusLine: "Active • current head",
                        detailLine: "Created \(abbreviatedDateTime(Date(timeIntervalSince1970: 36_000)))",
                        createdAt: Date(timeIntervalSince1970: 36_000),
                        isHead: true,
                        isInspecting: true,
                        canSwitch: false,
                        canMerge: false,
                        canAbandon: false
                    ),
                    DecisionSessionEngineControlBranchPresentation(
                        id: "branch-correction",
                        name: "correction-parser",
                        statusLine: "Active",
                        detailLine: "Correction branch • Parent branch-main • Base ckpt-9",
                        createdAt: Date(timeIntervalSince1970: 35_000),
                        isHead: false,
                        isInspecting: false,
                        canSwitch: true,
                        canMerge: true,
                        canAbandon: true
                    )
                ]
            ),
            "Branches 2 • Head main"
        )
        XCTAssertEqual(
            DecisionSessionControlPresentationSupport.selectedCheckpointLine(
                checkpoint: DecisionSessionCheckpoint(
                    id: "ckpt-9",
                    sessionId: "sess-1",
                    branchId: "branch-main",
                    basedOnEventSeq: 42,
                    createdAt: Date(timeIntervalSince1970: 300),
                    summary: DecisionSessionCheckpointSummary(
                        goal: "repair parser",
                        acceptedConstraints: [],
                        confirmedFacts: [],
                        openTasks: [],
                        currentScope: []
                    ),
                    runtimeState: .empty,
                    integrity: DecisionSessionCheckpointIntegrity(
                        eventHash: "evt-hash-1",
                        previousCheckpointHash: nil
                    ),
                    previousCheckpointId: nil,
                    checkpointHash: "ckpt-hash-1"
                )
            ),
            "Checkpoint ckpt-9 • repair parser"
        )
        let headBranch = DecisionSessionBranch(
            id: "branch-main",
            sessionId: "sess-1",
            parentBranchId: nil,
            baseCheckpointId: "ckpt-9",
            name: "main",
            createdAt: Date(timeIntervalSince1970: 36_000),
            status: .active
        )
        let correctionBranch = DecisionSessionBranch(
            id: "branch-correction",
            sessionId: "sess-1",
            parentBranchId: "branch-main",
            baseCheckpointId: "ckpt-9",
            name: "correction-parser",
            createdAt: Date(timeIntervalSince1970: 35_000),
            status: .active
        )
        XCTAssertEqual(
            DecisionSessionControlPresentationSupport.branchPresentation(
                branch: correctionBranch,
                headBranchID: "branch-main",
                selectedBranchID: "branch-correction",
                sessionAllowsMutations: true
            ),
            DecisionSessionEngineControlBranchPresentation(
                id: "branch-correction",
                name: "correction-parser",
                statusLine: "Active",
                detailLine: "Correction branch • Parent branch-main • Base ckpt-9",
                createdAt: Date(timeIntervalSince1970: 35_000),
                isHead: false,
                isInspecting: true,
                canSwitch: true,
                canMerge: true,
                canAbandon: true
            )
        )
        XCTAssertEqual(
            DecisionSessionControlPresentationSupport.branchPresentations(
                branches: [correctionBranch, headBranch],
                headBranchID: "branch-main",
                selectedBranchID: "branch-correction",
                sessionAllowsMutations: true
            ),
            [
                DecisionSessionEngineControlBranchPresentation(
                    id: "branch-main",
                    name: "main",
                    statusLine: "Active • current head",
                    detailLine: "Derived branch • Base ckpt-9",
                    createdAt: Date(timeIntervalSince1970: 36_000),
                    isHead: true,
                    isInspecting: false,
                    canSwitch: false,
                    canMerge: false,
                    canAbandon: false
                ),
                DecisionSessionEngineControlBranchPresentation(
                    id: "branch-correction",
                    name: "correction-parser",
                    statusLine: "Active",
                    detailLine: "Correction branch • Parent branch-main • Base ckpt-9",
                    createdAt: Date(timeIntervalSince1970: 35_000),
                    isHead: false,
                    isInspecting: true,
                    canSwitch: true,
                    canMerge: true,
                    canAbandon: true
                )
            ]
        )
        XCTAssertEqual(
            DecisionSessionControlPresentationSupport.checkpointSeqLine(42),
            "Checkpoint event seq 42"
        )
        XCTAssertEqual(
            DecisionSessionControlPresentationSupport.eventSeqLine(43),
            "Event seq 43"
        )
        let timelineCheckpoint = DecisionSessionTimelineItem(
            id: "timeline-ckpt",
            createdAt: Date(timeIntervalSince1970: 36_100),
            branchId: "branch-main",
            title: "Stable checkpoint",
            detail: "Latest checkpoint remains replayable.",
            kind: .checkpoint(
                DecisionSessionCheckpoint(
                    id: "ckpt-9",
                    sessionId: "sess-1",
                    branchId: "branch-main",
                    basedOnEventSeq: 42,
                    createdAt: Date(timeIntervalSince1970: 36_100),
                    summary: DecisionSessionCheckpointSummary(
                        goal: "repair parser",
                        acceptedConstraints: [],
                        confirmedFacts: [],
                        openTasks: [],
                        currentScope: []
                    ),
                    runtimeState: .empty,
                    integrity: DecisionSessionCheckpointIntegrity(
                        eventHash: "hash-1",
                        previousCheckpointHash: nil
                    ),
                    previousCheckpointId: nil,
                    checkpointHash: "checkpoint-hash"
                )
            )
        )
        XCTAssertEqual(
            DecisionSessionControlPresentationSupport.timelinePresentation(
                item: timelineCheckpoint,
                sessionAllowsMutations: true
            ),
            DecisionSessionEngineControlTimelinePresentation(
                id: "timeline-ckpt",
                title: "Stable checkpoint",
                detail: "Latest checkpoint remains replayable.",
                branchID: "branch-main",
                createdAt: Date(timeIntervalSince1970: 36_100),
                seqLine: "Checkpoint event seq 42",
                isCheckpoint: true,
                checkpointID: "ckpt-9",
                eventID: nil,
                canRestoreCheckpoint: true,
                canTargetCorrection: false,
                emphasizesRecovery: false
            )
        )
        let timelineEvent = DecisionSessionTimelineItem(
            id: "timeline-evt",
            createdAt: Date(timeIntervalSince1970: 36_200),
            branchId: "branch-main",
            title: "tool_call_finished",
            detail: "Tool finished: parser repaired",
            kind: .event(
                DecisionSessionEvent(
                    id: "evt-43",
                    sessionId: "sess-1",
                    branchId: "branch-main",
                    seq: 43,
                    createdAt: Date(timeIntervalSince1970: 36_200),
                    type: .toolCallFinished,
                    parentEventId: nil,
                    payloadRef: nil,
                    payloadHash: "payload-hash",
                    recordHash: "record-hash"
                )
            )
        )
        XCTAssertEqual(
            DecisionSessionControlPresentationSupport.timelinePresentation(
                item: timelineEvent,
                sessionAllowsMutations: true
            ),
            DecisionSessionEngineControlTimelinePresentation(
                id: "timeline-evt",
                title: "tool call finished",
                detail: "Tool finished: parser repaired",
                branchID: "branch-main",
                createdAt: Date(timeIntervalSince1970: 36_200),
                seqLine: "Event seq 43",
                isCheckpoint: false,
                checkpointID: nil,
                eventID: "evt-43",
                canRestoreCheckpoint: false,
                canTargetCorrection: true,
                emphasizesRecovery: false
            )
        )
        XCTAssertEqual(
            DecisionSessionControlPresentationSupport.timelinePresentations(
                items: [timelineCheckpoint, timelineEvent],
                sessionAllowsMutations: true
            ),
            [
                DecisionSessionEngineControlTimelinePresentation(
                    id: "timeline-ckpt",
                    title: "Stable checkpoint",
                    detail: "Latest checkpoint remains replayable.",
                    branchID: "branch-main",
                    createdAt: Date(timeIntervalSince1970: 36_100),
                    seqLine: "Checkpoint event seq 42",
                    isCheckpoint: true,
                    checkpointID: "ckpt-9",
                    eventID: nil,
                    canRestoreCheckpoint: true,
                    canTargetCorrection: false,
                    emphasizesRecovery: false
                ),
                DecisionSessionEngineControlTimelinePresentation(
                    id: "timeline-evt",
                    title: "tool call finished",
                    detail: "Tool finished: parser repaired",
                    branchID: "branch-main",
                    createdAt: Date(timeIntervalSince1970: 36_200),
                    seqLine: "Event seq 43",
                    isCheckpoint: false,
                    checkpointID: nil,
                    eventID: "evt-43",
                    canRestoreCheckpoint: false,
                    canTargetCorrection: true,
                    emphasizesRecovery: false
                )
            ]
        )
        let selectedMergeCheckpoint = DecisionSessionCheckpoint(
            id: "ckpt-9",
            sessionId: "sess-1",
            branchId: "branch-main",
            basedOnEventSeq: 42,
            createdAt: Date(timeIntervalSince1970: 300),
            summary: DecisionSessionCheckpointSummary(
                goal: "repair parser",
                acceptedConstraints: [],
                confirmedFacts: [],
                openTasks: [],
                currentScope: []
            ),
            runtimeState: .empty,
            integrity: DecisionSessionCheckpointIntegrity(
                eventHash: "evt-hash-1",
                previousCheckpointHash: nil
            ),
            previousCheckpointId: nil,
            checkpointHash: "ckpt-hash-1"
        )
        XCTAssertEqual(
            DecisionSessionControlPresentationSupport.selectedMergeReview(
                session: DecisionSession(
                    id: "sess-1",
                    title: "Parser repair",
                    createdAt: Date(timeIntervalSince1970: 100),
                    updatedAt: Date(timeIntervalSince1970: 200),
                    status: .active,
                    headBranchId: "branch-main",
                    latestCheckpointId: "ckpt-9"
                ),
                selectedBranchID: "branch-correction",
                branches: [headBranch, correctionBranch],
                selectedCheckpoint: selectedMergeCheckpoint
            ),
            DecisionSessionEngineControlMergeReview(
                sourceBranchID: "branch-correction",
                sourceBranchName: "correction-parser",
                targetBranchID: "branch-main",
                targetBranchName: "main",
                sourceStatusLine: "Active",
                targetStatusLine: "Active • current head",
                checkpointLine: "Selected checkpoint ckpt-9 • repair parser",
                summaryLine: DecisionSessionControlPresentationSupport.appendOnlyMergeSummaryLine,
                detailRows: [
                    DecisionSessionEngineControlReviewDetail(
                        id: "source-branch",
                        label: "Source branch",
                        value: "correction-parser • branch-correction"
                    ),
                    DecisionSessionEngineControlReviewDetail(
                        id: "target-branch",
                        label: "Target branch",
                        value: "main • branch-main"
                    ),
                    DecisionSessionEngineControlReviewDetail(
                        id: "source-status",
                        label: "Source status",
                        value: "Active"
                    ),
                    DecisionSessionEngineControlReviewDetail(
                        id: "target-status",
                        label: "Target status",
                        value: "Active • current head"
                    ),
                    DecisionSessionEngineControlReviewDetail(
                        id: "checkpoint",
                        label: "Checkpoint",
                        value: "Selected checkpoint ckpt-9 • repair parser"
                    )
                ]
            )
        )
        let controlSession = DecisionSession(
            id: "sess-control",
            title: "Parser repair",
            createdAt: Date(timeIntervalSince1970: 100),
            updatedAt: Date(timeIntervalSince1970: 200),
            status: .stalled,
            headBranchId: "branch-main",
            latestCheckpointId: "ckpt-9"
        )
        let controlInspection = DecisionSessionRuntimeInspectionSession(
            sessionID: "sess-control",
            title: "Parser repair",
            status: .stalled,
            updatedAt: Date(timeIntervalSince1970: 200),
            headBranchID: "branch-main",
            latestCheckpointID: "ckpt-9",
            latestCheckpointSeq: 42,
            latestCheckpointGoal: "repair parser",
            latestCheckpointActionLine: "action: restored parser workspace",
            latestCheckpointEBrainAnchor: {
                var anchor = DecisionSessionCheckpointEBrainAnchor(
                    sessionID: "sess-control",
                    thoughtFoldChecksum: "fold-control",
                    riskLevel: "high",
                    permitMode: "delay",
                    hostGatePercent: 74,
                    reviewDirectiveLine: "Review guarded resume path"
                )
                anchor.stackedModes = ["draftOnly", "mirror"]
                anchor.assertionCeiling = "guarded"
                anchor.allowedDomains = ["draft.note", "text.delay"]
                anchor.blockedDomains = ["tool.write", "memory.write", "host.write"]
                anchor.delayType = "cool_down"
                anchor.substituteType = "draft"
                anchor.sovereignHintLevel = "elevated"
                anchor.lungState = BASLungState(
                    breathMode: .guard,
                    breathPhase: .resume,
                    thermalPressure: 71,
                    cachePressure: 49,
                    restoreReadiness: 0.91,
                    rollbackAnchorRef: "anchor-control"
                )
                anchor.resumeFrame = BASResumeFrame(
                    resumeID: "resume-control",
                    sourceFoldID: "fold-control",
                    resumeDepth: 1,
                    requiredOrgans: [.riskSpine, .stubCore],
                    consistencyChecks: ["fold_checksum"],
                    fallbackMode: .rollbackAnchor
                )
                anchor.rollbackAnchor = BASRollbackAnchor(
                    anchorID: "anchor-control",
                    safeSnapshotRef: "snapshot-control",
                    foldRefs: ["fold-control"],
                    hostVersionRef: "host.v3",
                    cacheStateRef: "cache-control",
                    integrityHash: "hash-control"
                )
                anchor.sovereignBridgeResult = DecisionFoldedLungSovereignBridgeResult(
                    actuationKinds: [.quarantine],
                    invalidatedResumeFrameIDs: [],
                    invalidatedCacheRefs: [],
                    invalidatedFoldRefs: [],
                    invalidatedPackageIDs: [],
                    quarantinedFoldRefs: ["fold-control"],
                    resultingBreathMode: .quarantine,
                    preservedReadOnlyRecovery: true,
                    summary: "quarantine -> fold-control"
                )
                return anchor
            }(),
            latestEventID: "evt-43",
            latestEventSeq: 43,
            latestEventType: .stepStalled,
            latestEventDetail: "Stalled step preserved.",
            openStepCount: 1,
            openStepStatus: .stalled,
            stalledStepCount: 1,
            branchCount: 2,
            mergeableBranchCount: 1,
            recoveryCount: 2,
            latestRecoveryAt: Date(timeIntervalSince1970: 210)
        )
        let controlPresentation = DecisionSessionControlPresentationSupport.sessionPresentation(
            session: controlSession,
            inspection: controlInspection,
            isSelected: true
        )
        XCTAssertEqual(controlPresentation.sessionID, "sess-control")
        XCTAssertEqual(controlPresentation.title, "Parser repair")
        XCTAssertEqual(controlPresentation.statusLine, "Stalled • step stalled")
        XCTAssertEqual(
            controlPresentation.healthSummary,
            DecisionSessionEngineHealthSummary(
                severity: .watch,
                title: "Recovery ready",
                detail: "A stalled step was detected. Recovery should stay available from the last stable checkpoint."
            )
        )
        XCTAssertEqual(controlPresentation.checkpointLine, "Checkpoint ckpt-9 • repair parser")
        XCTAssertNil(controlPresentation.checkpointBudgetLine)
        XCTAssertNil(controlPresentation.checkpointDecisionLine)
        XCTAssertNil(controlPresentation.checkpointTaskLine)
        XCTAssertEqual(
            controlPresentation.checkpointWindGateLine,
            "Wind gate primary delay • stacked draft only, mirror • assert guarded • allow draft.note, text.delay • block tool.write, memory.write, host.write • delay cool down • substitute draft • sovereign elevated"
        )
        XCTAssertNil(controlPresentation.checkpointPressureLine)
        XCTAssertNil(controlPresentation.checkpointRiskFactorsLine)
        XCTAssertNil(controlPresentation.checkpointReasonCodesLine)
        XCTAssertNil(controlPresentation.checkpointAuditLine)
        XCTAssertNil(controlPresentation.checkpointSovereignVerdictLine)
        XCTAssertNil(controlPresentation.checkpointSovereignAuthorityLine)
        XCTAssertNil(controlPresentation.checkpointSovereignAuditLine)
        XCTAssertNil(controlPresentation.checkpointKillSwitchesLine)
        XCTAssertEqual(controlPresentation.checkpointActionLine, "action: restored parser workspace")
        XCTAssertEqual(
            controlPresentation.checkpointMorphLine,
            "Morph graph morph.sess-control.fold-control • organs riskSpine, stubCore • route checkpoint • thermal checkpoint-recovery"
        )
        XCTAssertEqual(controlPresentation.checkpointLungLine, "Breath guard • Phase resume • Restore 91%")
        XCTAssertEqual(
            controlPresentation.checkpointHotColdLine,
            "Hot pack stubCore, riskSpine • Warm memoryCodecRidge, hostModulationMesh, toolIntentMesh • Cold 7 • preload guard_preload • eviction protective_retain"
        )
        XCTAssertEqual(
            controlPresentation.checkpointPrecisionLine,
            "Precision profile full -> protected -> balanced -> minimal • floor protected • locked riskSpine, stubCore"
        )
        XCTAssertEqual(
            controlPresentation.checkpointOrganPackageLine,
            "Organ packages 12 • hot 2 • warm 3 • cold 7 • protected 3 • recovery 2"
        )
        XCTAssertEqual(
            controlPresentation.checkpointOrganDeltaLine,
            "Organ delta quarantine_swap • activate package.stubcore.hot, package.riskspine.hot • preload package.memorycodecridge.warm, package.hostmodulationmesh.warm, package.toolintentmesh.warm • evict package.criticblade.cold • rollback-safe package.stubcore.hot, package.riskspine.hot, package.memorycodecridge.warm, package.permitknot.cold, package.consistencylattice.cold • sovereign quarantine"
        )
        XCTAssertEqual(
            controlPresentation.checkpointSchedulerLine,
            "Breath scheduler guard_resume • checkpoint anchor_each_turn • micro-sleep 203ms • maintenance 0ms • resume rollback_hot"
        )
        XCTAssertEqual(
            controlPresentation.checkpointThermalExchangeLine,
            "Thermal exchanger balanced_exchange • band warm • actions delay_cold_organs • suppress criticBlade"
        )
        XCTAssertEqual(
            controlPresentation.checkpointIntegrityWeaveLine,
            "Integrity weave quarantined • checks 3/3 • contamination 1 • hash hash-control"
        )
        XCTAssertEqual(
            controlPresentation.checkpointResumeLine,
            "Resume frame resume-control • source fold-control • depth 1 • organs riskSpine, stubCore"
        )
        XCTAssertEqual(
            controlPresentation.checkpointRollbackLine,
            "Rollback anchor anchor-control • snapshot snapshot-control • cache cache-control"
        )
        XCTAssertEqual(controlPresentation.checkpointSovereignBridgeLine, "quarantine -> fold-control")
        XCTAssertEqual(
            controlPresentation.checkpointSovereignBridgeDetailLines,
            [
                "Sovereign quarantined fold fold-control",
                "Sovereign quarantined package package.criticblade.cold",
                "Sovereign readonly recovery",
                "Sovereign mode quarantine"
            ]
        )
        XCTAssertEqual(controlPresentation.branchLine, "Head branch-main • Branches 2 • Merge-ready 1")
        XCTAssertEqual(
            controlPresentation.recoveryLine,
            "Recoveries 2 • latest \(shortenedTime(Date(timeIntervalSince1970: 210)))"
        )
        XCTAssertEqual(
            controlPresentation.mergeReviewLine,
            "Merge review 1 active correction branch can append back onto head without rewriting history."
        )
        XCTAssertEqual(
            controlPresentation.faultLine,
            "Fault line • A stalled step was detected. Recovery should stay available from the last stable checkpoint."
        )
        XCTAssertEqual(controlPresentation.stepFreshnessLine, "Step stalled • awaiting first heartbeat")
        XCTAssertEqual(
            controlPresentation.stepAlertLine,
            "A stalled step was detected. Recovery should stay available from the last stable checkpoint."
        )
        XCTAssertEqual(
            controlPresentation.detailLine,
            "ckpt ckpt-9 • evt 43 • steps 1 • stalled • Step stalled • awaiting first heartbeat • recoveries 2"
        )
        XCTAssertEqual(controlPresentation.updatedAt, Date(timeIntervalSince1970: 200))
        XCTAssertFalse(controlPresentation.canPause)
        XCTAssertFalse(controlPresentation.canResume)
        XCTAssertTrue(controlPresentation.canRecover)
        XCTAssertTrue(controlPresentation.canArchive)
        XCTAssertTrue(controlPresentation.canCorrect)
        XCTAssertTrue(controlPresentation.isSelected)
        XCTAssertEqual(
            DecisionSessionControlPresentationSupport.appendOnlyMergeSummaryTitle,
            "Append-only merge"
        )
        XCTAssertEqual(
            DecisionSessionControlPresentationSupport.emptyMessage,
            "No Session Engine session has been recorded yet."
        )
        XCTAssertEqual(
            DecisionSessionControlPresentationSupport.appendOnlyMergeSummaryLine,
            "Merge will append a branch_merged fact onto the current head branch, keep the source branch inspectable, and avoid rewriting existing history."
        )
        XCTAssertEqual(
            DecisionSessionControlReviewPresentationSupport.sourceBranchLabel,
            "Source branch"
        )
        XCTAssertEqual(
            DecisionSessionReviewDetailPresentationSupport.bundleLabel,
            "Bundle"
        )
        XCTAssertEqual(
            DecisionSessionReviewDetailPresentationSupport.sourceSessionLabel,
            "Source session"
        )
        XCTAssertEqual(
            DecisionSessionReviewDetailPresentationSupport.branchIdentityLine(
                branchName: "main",
                branchID: "branch-main"
            ),
            "main • branch-main"
        )
        XCTAssertEqual(
            DecisionSessionControlReviewPresentationSupport.branchValueLine(
                branchName: "correction-parser",
                branchID: "branch-7"
            ),
            "correction-parser • branch-7"
        )
        let mergeSource = DecisionSessionBranch(
            id: "branch-correction",
            sessionId: "sess-1",
            parentBranchId: "branch-main",
            baseCheckpointId: "ckpt-9",
            name: "correction-parser",
            createdAt: Date(timeIntervalSince1970: 200),
            status: .active
        )
        let mergeTarget = DecisionSessionBranch(
            id: "branch-main",
            sessionId: "sess-1",
            parentBranchId: nil,
            baseCheckpointId: "ckpt-9",
            name: "main",
            createdAt: Date(timeIntervalSince1970: 100),
            status: .active
        )
        XCTAssertEqual(
            DecisionSessionControlReviewPresentationSupport.mergeReview(
                sourceBranch: mergeSource,
                targetBranch: mergeTarget,
                checkpointLine: "Selected checkpoint ckpt-9 • repair parser"
            ),
            DecisionSessionEngineControlMergeReview(
                sourceBranchID: "branch-correction",
                sourceBranchName: "correction-parser",
                targetBranchID: "branch-main",
                targetBranchName: "main",
                sourceStatusLine: "Active",
                targetStatusLine: "Active • current head",
                checkpointLine: "Selected checkpoint ckpt-9 • repair parser",
                summaryLine: DecisionSessionControlPresentationSupport.appendOnlyMergeSummaryLine,
                detailRows: [
                    DecisionSessionEngineControlReviewDetail(
                        id: "source-branch",
                        label: "Source branch",
                        value: "correction-parser • branch-correction"
                    ),
                    DecisionSessionEngineControlReviewDetail(
                        id: "target-branch",
                        label: "Target branch",
                        value: "main • branch-main"
                    ),
                    DecisionSessionEngineControlReviewDetail(
                        id: "source-status",
                        label: "Source status",
                        value: "Active"
                    ),
                    DecisionSessionEngineControlReviewDetail(
                        id: "target-status",
                        label: "Target status",
                        value: "Active • current head"
                    ),
                    DecisionSessionEngineControlReviewDetail(
                        id: "checkpoint",
                        label: "Checkpoint",
                        value: "Selected checkpoint ckpt-9 • repair parser"
                    )
                ]
            )
        )
        XCTAssertEqual(
            DecisionSessionControlReviewPresentationSupport.checkpointLabel,
            "Checkpoint"
        )
        XCTAssertEqual(
            DecisionSessionSummaryPresentationSupport.runtimeHeadline(
                layerPlacement: .foldedLung
            ),
            "Session Engine L3.folded_lung protects edits, checkpoints, and recovery."
        )
        XCTAssertEqual(
            DecisionSessionSummaryPresentationSupport.pendingImportHeadline(),
            "Session Engine L3.folded_lung has a pending import draft ready for review before local recovery state is attached."
        )
        XCTAssertEqual(
            DecisionSessionSummaryPresentationSupport.inventorySignalLine(
                sessions: 2,
                activeSessions: 1,
                stalledSessions: 1,
                layerPlacement: .foldedLung
            ),
            "Session Engine L3.folded_lung • Sessions 2 • Active 1 • Stalled 1"
        )
        XCTAssertEqual(
            DecisionSessionSummaryPresentationSupport.branchSignalLine(
                branches: 3,
                mergeReadySessions: 1,
                mergeableBranches: 2
            ),
            "Branches 3 • Merge-ready sessions 1 • Merge-ready branches 2"
        )
        XCTAssertEqual(
            DecisionSessionSummaryPresentationSupport.progressSignalLine(
                checkpoints: 4,
                events: 10,
                steps: 2
            ),
            "Checkpoints 4 • Events 10 • Steps 2"
        )
        XCTAssertEqual(
            DecisionSessionInspectionPresentationSupport.activityLine(
                openStepCount: 2,
                openStepStatus: .waitingTool,
                stalledStepCount: 1
            ),
            "Open steps 2 • waiting tool • Stalled 1"
        )
        XCTAssertEqual(
            DecisionSessionInspectionPresentationSupport.stepSignalLine(
                openStepCount: 2,
                openStepAlertLine: nil,
                openStepFreshnessLine: "Step waiting tool • heartbeat active"
            ),
            "Step waiting tool • heartbeat active"
        )
        XCTAssertEqual(
            DecisionSessionReviewPresentationSupport.replaySessionRecordedLine(
                sessionID: "sess-recorded",
                recordedAt: Date(timeIntervalSince1970: 36_000)
            ),
            DecisionEvolutionNarrativeFormattingSupport.joined([
                "Replay session sess-recorded",
                "Recorded \(abbreviatedDateTime(Date(timeIntervalSince1970: 36_000)))"
            ])
        )
        XCTAssertEqual(
            DecisionSessionReviewPresentationSupport.importPreviewHeadline,
            "Importing creates a new paused recovery-safe session. Old history stays untouched, and unfinished steps become auditable recovery facts."
        )
        XCTAssertEqual(
            DecisionSessionReviewPresentationSupport.importCountsLine(
                branches: 2,
                checkpoints: 3,
                events: 12,
                steps: 1
            ),
            "Branches 2 • Checkpoints 3 • Events 12 • Steps 1"
        )
        XCTAssertEqual(
            DecisionSessionReviewPresentationSupport.importBranchLine(
                headBranchName: "main",
                layerPlacement: .foldedLung
            ),
            "Head main • Layer L3.folded_lung"
        )
        XCTAssertEqual(
            DecisionSessionReviewPresentationSupport.latestCheckpointLine(
                latestCheckpointID: "ckpt-7",
                goal: "repair parser"
            ),
            "Latest checkpoint ckpt-7 • repair parser"
        )
        XCTAssertEqual(
            DecisionSessionReviewPresentationSupport.latestCheckpointLine(
                latestCheckpointID: nil,
                goal: nil
            ),
            "No checkpoint was exported with this session."
        )
        XCTAssertEqual(
            DecisionSessionReviewPresentationSupport.importBranchStatusLine(
                status: .active,
                isHead: true
            ),
            DecisionEvolutionNarrativeFormattingSupport.joined([
                "Active",
                "exported head"
            ])
        )
        XCTAssertEqual(
            DecisionSessionBranchPresentationSupport.controlStatusLine(
                status: .active,
                isHead: true
            ),
            DecisionEvolutionNarrativeFormattingSupport.joined([
                "Active",
                "current head"
            ])
        )
        XCTAssertEqual(
            DecisionSessionBranchPresentationSupport.originLine(
                branchName: "correction-parser",
                parentBranchID: "branch-main",
                baseCheckpointID: "ckpt-9"
            ),
            "Correction branch"
        )
        XCTAssertEqual(
            DecisionSessionBranchPresentationSupport.detailLine(
                originLine: "Correction branch",
                parentBranchID: "branch-main",
                baseCheckpointID: "ckpt-9",
                createdAt: Date(timeIntervalSince1970: 36_000)
            ),
            DecisionEvolutionNarrativeFormattingSupport.joined([
                "Correction branch",
                "Parent branch-main",
                "Base ckpt-9"
            ])
        )
        XCTAssertEqual(
            DecisionSessionBranchPresentationSupport.detailLine(
                originLine: nil,
                parentBranchID: nil,
                baseCheckpointID: nil,
                createdAt: Date(timeIntervalSince1970: 36_000)
            ),
            "Created \(abbreviatedDateTime(Date(timeIntervalSince1970: 36_000)))"
        )
        XCTAssertEqual(
            DecisionSessionReviewPresentationSupport.mergeReviewSignalLine(
                mergeableBranchCount: 0
            ),
            "Merge review 0"
        )
        XCTAssertEqual(
            DecisionSessionInspectionPresentationSupport.detailLine(
                checkpointID: "ckpt-9",
                eventSeq: 42,
                openStepCount: 2,
                openStepStatus: .waitingTool,
                openStepFreshnessLine: "Step waiting tool • heartbeat active",
                recoveryCount: 1
            ),
            "ckpt ckpt-9 • evt 42 • steps 2 • waiting_tool • Step waiting tool • heartbeat active • recoveries 1"
        )
    }

    func testCheckpointPresentationFactsBuildDigestLinesFromInspection() {
        let inspection = DecisionSessionRuntimeInspectionSession(
            sessionID: "sess-checkpoint",
            title: "parser repair",
            status: .active,
            updatedAt: Date(timeIntervalSince1970: 100),
            headBranchID: "branch-main",
            latestCheckpointID: "ckpt-9",
            latestCheckpointSeq: 9,
            latestCheckpointGoal: "repair parser",
            latestCheckpointBudgetLine: "eBrain budget: guarded • loops 2 • candidates 2 • decode 160 • thermal watch",
            latestCheckpointRouteLine: "eBrain route: npu • precision mixed • retrieval 3",
            latestCheckpointDecisionLine: "eBrain risk: guarded • eBrain permit: replace • eBrain host gate: 61% • eBrain fold: fold9abc",
            latestCheckpointTaskLine: "Review update ticket: preserve parser-only correction",
            latestCheckpointPressureLine: "eBrain pressure: latency 82/1200ms • power 46% • cache 67% • thermal nominal -> watch",
            latestCheckpointAuditLine: "eBrain audit findings: 2",
            latestCheckpointActiveKillSwitchesLine: "eBrain active kill switches: force_guard_mode",
            latestCheckpointKillSwitchesLine: "eBrain active kill switches: force_guard_mode • eBrain recommended kill switches: require_reviewed_writes",
            latestCheckpointActionLine: "action: restored active quick workspace state",
            latestEventID: "evt-10",
            latestEventSeq: 10,
            latestEventType: .stepRecovered,
            latestEventDetail: "Recovered from stalled tool step.",
            openStepCount: 1,
            openStepStatus: .planning,
            stalledStepCount: 0,
            branchCount: 2,
            recoveryCount: 1,
            latestRecoveryAt: Date(timeIntervalSince1970: 120)
        )

        let facts = inspection.checkpointPresentationFacts

        XCTAssertEqual(
            facts.runtimeLine,
            DecisionEvolutionNarrativeFormattingSupport.joined([
                "eBrain budget: guarded • loops 2 • candidates 2 • decode 160 • thermal watch",
                "eBrain route: npu • precision mixed • retrieval 3"
            ])
        )
        XCTAssertEqual(
            facts.auditPressureLine,
            DecisionEvolutionNarrativeFormattingSupport.joined([
                "eBrain audit findings: 2",
                "eBrain active kill switches: force_guard_mode • eBrain recommended kill switches: require_reviewed_writes"
            ])
        )
        XCTAssertEqual(
            facts.digestLines,
            [
                "eBrain budget: guarded • loops 2 • candidates 2 • decode 160 • thermal watch • eBrain route: npu • precision mixed • retrieval 3",
                "eBrain risk: guarded • eBrain permit: replace • eBrain host gate: 61% • eBrain fold: fold9abc • Review update ticket: preserve parser-only correction",
                "eBrain pressure: latency 82/1200ms • power 46% • cache 67% • thermal nominal -> watch",
                "eBrain audit findings: 2 • eBrain active kill switches: force_guard_mode • eBrain recommended kill switches: require_reviewed_writes",
                "action: restored active quick workspace state"
            ]
        )
        XCTAssertEqual(
            facts.combinedAuditLine(addition: "Watchdog budget expired on the current open step. Recover before continuing."),
            DecisionEvolutionNarrativeFormattingSupport.joined([
                "eBrain audit findings: 2",
                "Watchdog budget expired on the current open step. Recover before continuing."
            ])
        )

        let importPreview = DecisionSessionImportBundlePreview(
            id: "preview-1",
            sourceSessionId: "sess-exported",
            sourceTitle: "Parser repair",
            importedTitle: "Parser repair (Imported)",
            exportedAt: Date(timeIntervalSince1970: 300),
            countsLine: "Branches 2 • Checkpoints 3 • Events 12 • Steps 1",
            integrityLine: "Validated schema v1 • fingerprint abcdef123456",
            checkpointLine: "Latest checkpoint ckpt-7 • repair parser",
            branchLine: "Head main • Layer L3.folded_lung",
            unfinishedStepCount: 1,
            unfinishedStepsLine: "Open steps 1 • unfinished work will import as failed recovery facts.",
            headline: DecisionSessionReviewPresentationSupport.importPreviewHeadline,
            branchPreviews: []
        )
        let preview = DecisionSessionEnginePendingImportPreview(
            sourceFileName: "parser-session.json",
            preview: importPreview
        ).presentation

        XCTAssertEqual(
            DecisionSessionReviewPresentationSupport.pendingImportSignalLines(preview: preview),
            [
                "Pending import • Bundle parser-session.json • Will import as Parser repair (Imported)",
                "Open work will be normalized • Branches 2 • Checkpoints 3 • Events 12 • Steps 1"
            ]
        )
        XCTAssertEqual(
            DecisionSessionReviewPresentationSupport.importDetailRows(
                preview: importPreview,
                sourceFileName: "parser-session.json"
            ),
            [
                DecisionSessionEngineReviewDetailPresentation(
                    id: "bundle",
                    label: "Bundle",
                    value: "parser-session.json"
                ),
                DecisionSessionEngineReviewDetailPresentation(
                    id: "source",
                    label: "Source session",
                    value: "Parser repair"
                ),
                DecisionSessionEngineReviewDetailPresentation(
                    id: "imported",
                    label: "Imported title",
                    value: "Parser repair (Imported)"
                ),
                DecisionSessionEngineReviewDetailPresentation(
                    id: "counts",
                    label: "Counts",
                    value: "Branches 2 • Checkpoints 3 • Events 12 • Steps 1"
                ),
                DecisionSessionEngineReviewDetailPresentation(
                    id: "integrity",
                    label: "Integrity",
                    value: "Validated schema v1 • fingerprint abcdef123456"
                ),
                DecisionSessionEngineReviewDetailPresentation(
                    id: "checkpoint",
                    label: "Checkpoint",
                    value: "Latest checkpoint ckpt-7 • repair parser"
                ),
                DecisionSessionEngineReviewDetailPresentation(
                    id: "branch",
                    label: "Branch line",
                    value: "Head main • Layer L3.folded_lung"
                )
            ]
        )
        XCTAssertEqual(
            DecisionSessionReviewPresentationSupport.importBranchPresentation(
                DecisionSessionImportBundleBranchPreview(
                    id: "branch-main",
                    name: "main",
                    statusLine: "Exported head",
                    detailLine: "Created \(abbreviatedDateTime(Date(timeIntervalSince1970: 36_000)))",
                    isHead: true
                )
            ),
            DecisionSessionEngineImportBranchPresentation(
                id: "branch-main",
                name: "main",
                statusLine: "Exported head",
                detailLine: "Created \(abbreviatedDateTime(Date(timeIntervalSince1970: 36_000)))",
                isHead: true
            )
        )
        XCTAssertEqual(
            DecisionSessionSummaryPresentationSupport.replayRecoverySignalLines(
                sessions: [inspection]
            ),
            inspection.replayRecoverySummary.digestLines
        )
        XCTAssertEqual(
            DecisionSessionSummaryPresentationSupport.checkpointDigestSignalLines(
                sessions: [inspection]
            ),
            facts.digestLines.map { "parser repair • \($0)" }
        )
        let breakdown = DecisionSessionSummaryPresentationSupport.summarySignalBreakdown(
            layerPlacement: .foldedLung,
            sessions: 2,
            activeSessions: 1,
            stalledSessions: 1,
            mergeReadySessions: 1,
            mergeableBranches: 2,
            branches: 3,
            checkpoints: 4,
            events: 10,
            steps: 2,
            recentSessions: [inspection],
            pendingImportPreview: preview
        )
        XCTAssertEqual(
            breakdown,
            DecisionSessionSummarySignalBreakdown(
                inventoryLine: "Session Engine L3.folded_lung • Sessions 2 • Active 1 • Stalled 1",
                branchLine: "Branches 3 • Merge-ready sessions 1 • Merge-ready branches 2",
                progressLine: "Checkpoints 4 • Events 10 • Steps 2",
                supplementalLines: [
                    "Pending import • Bundle parser-session.json • Will import as Parser repair (Imported)",
                    "Open work will be normalized • Branches 2 • Checkpoints 3 • Events 12 • Steps 1"
                ] + inspection.replayRecoverySummary.digestLines
                    + facts.digestLines.map { "parser repair • \($0)" }
                    + [DecisionSessionSummaryPresentationSupport.recentSessionSignalLine(session: inspection)]
            )
        )
        XCTAssertEqual(
            DecisionSessionSummaryPresentationSupport.summarySignalLines(
                layerPlacement: .foldedLung,
                sessions: 2,
                activeSessions: 1,
                stalledSessions: 1,
                mergeReadySessions: 1,
                mergeableBranches: 2,
                branches: 3,
                checkpoints: 4,
                events: 10,
                steps: 2,
                recentSessions: [inspection],
                pendingImportPreview: preview
            ),
            breakdown.allSignals
        )
        let summarySignals = breakdown.allSignals
        let summary = DecisionSystemSessionEngineSummary(
            layerPlacement: .foldedLung,
            sessions: 2,
            activeSessions: 1,
            stalledSessions: 1,
            mergeReadySessions: 1,
            mergeableBranches: 2,
            branches: 3,
            checkpoints: 4,
            events: 10,
            steps: 2,
            activeSession: inspection,
            recentSessions: [inspection],
            headline: "Session Engine L3.folded_lung protects edits, checkpoints, and recovery.",
            signalBreakdown: breakdown,
            pendingImportPreview: preview
        )
        XCTAssertEqual(summary.signals, summarySignals)
        XCTAssertEqual(
            DecisionSessionSummaryPresentationSupport.runtimeLayerSignals(summary: summary),
            [
                "Session Engine L3.folded_lung protects edits, checkpoints, and recovery.",
                breakdown.inventoryLine!,
                "Pending import • Bundle parser-session.json • Will import as Parser repair (Imported)",
                "Open work will be normalized • Branches 2 • Checkpoints 3 • Events 12 • Steps 1"
            ]
        )
        XCTAssertEqual(
            DecisionSessionSummaryPresentationSupport.dataLayerSignals(summary: summary),
            [breakdown.branchLine!, breakdown.progressLine!]
                + breakdown.supplementalLines
                + DecisionSessionReviewPresentationSupport.digestLines(from: summary)
                    .map(DecisionSessionReviewPresentationSupport.signalLine)
        )
        XCTAssertEqual(
            DecisionSessionSummaryPresentationSupport.inspectionAggregate(
                sessions: [inspection]
            ),
            DecisionSessionInspectionAggregate(
                sessions: 1,
                activeSessions: 1,
                stalledSessions: 0,
                branches: 2,
                checkpoints: 1
            )
        )
    }

    func testControlCenterSummarySynthesizesMergePressureFromInspectionFallback() {
        let inspection = DecisionSessionRuntimeInspectionSession(
            sessionID: "sess-fallback",
            title: "parser repair",
            status: .stalled,
            updatedAt: Date(timeIntervalSince1970: 200),
            headBranchID: "branch-main",
            latestCheckpointID: "ckpt-4",
            latestCheckpointSeq: 4,
            latestCheckpointGoal: "repair parser",
            latestEventID: "evt-5",
            latestEventSeq: 5,
            latestEventType: .sessionRecovered,
            latestEventDetail: "Recovered from checkpoint ckpt-4",
            openStepCount: 0,
            openStepStatus: nil,
            stalledStepCount: 1,
            branchCount: 3,
            mergeableBranchCount: 2,
            recoveryCount: 1,
            latestRecoveryAt: Date(timeIntervalSince1970: 210)
        )

        let summary = DecisionSystemSessionEngineSummary.controlCenterSummary(
            runtimeSnapshot: nil,
            inspectionBySessionID: [inspection.sessionID: inspection],
            pendingImportPreview: nil
        )

        XCTAssertEqual(summary.layerPlacement, .foldedLung)
        XCTAssertEqual(summary.sessions, 1)
        XCTAssertEqual(summary.activeSessions, 0)
        XCTAssertEqual(summary.stalledSessions, 1)
        XCTAssertEqual(summary.mergeReadySessions, 1)
        XCTAssertEqual(summary.mergeableBranches, 2)
        XCTAssertEqual(summary.branches, 3)
        XCTAssertEqual(summary.checkpoints, 1)
        XCTAssertEqual(summary.activeSession?.sessionID, "sess-fallback")
        XCTAssertEqual(summary.headline, DecisionSessionControlPresentationSupport.summaryHeadline)
        XCTAssertEqual(
            summary.signals.prefix(3),
            [
                "Session Engine L3.folded_lung • Sessions 1 • Active 0 • Stalled 1",
                "Branches 3 • Merge-ready sessions 1 • Merge-ready branches 2",
                "Checkpoints 1 • Events 0 • Steps 0"
            ]
        )
        XCTAssertTrue(summary.signals.contains { $0.contains("Replay session") })
    }

    func testPendingImportSummaryUsesSharedSummarySignalStack() {
        let preview = DecisionSessionEngineImportPreviewPresentation(
            title: "Import Session Engine bundle",
            headline: DecisionSessionReviewPresentationSupport.importPreviewHeadline,
            bundleLine: "Bundle parser-session.json",
            sourceLine: "Source Parser repair",
            importedLine: "Will import as Parser repair (Imported)",
            countsLine: "Branches 2 • Checkpoints 3 • Events 12 • Steps 1",
            integrityLine: "Validated schema v1 • fingerprint abcdef123456",
            checkpointLine: "Latest checkpoint ckpt-7 • repair parser",
            branchLine: "Head main • Layer L3.folded_lung",
            unfinishedWorkSummary: DecisionSessionEngineHealthSummary(
                severity: .watch,
                title: "Open work will be normalized",
                detail: "Open steps 1 • unfinished work will import as failed recovery facts."
            ),
            detailRows: [],
            branchPresentations: []
        )

        let summary = DecisionSystemSessionEngineSummary.pendingImportSummary(
            for: preview
        )

        XCTAssertEqual(summary.layerPlacement, .foldedLung)
        XCTAssertEqual(summary.sessions, 0)
        XCTAssertEqual(summary.activeSessions, 0)
        XCTAssertEqual(summary.stalledSessions, 0)
        XCTAssertEqual(summary.mergeReadySessions, 0)
        XCTAssertEqual(summary.mergeableBranches, 0)
        XCTAssertEqual(summary.branches, 0)
        XCTAssertEqual(summary.checkpoints, 0)
        XCTAssertEqual(summary.events, 0)
        XCTAssertEqual(summary.steps, 0)
        XCTAssertNil(summary.activeSession)
        XCTAssertEqual(summary.pendingImportPreview, preview)
        XCTAssertEqual(summary.headline, DecisionSessionSummaryPresentationSupport.pendingImportHeadline())
        XCTAssertEqual(
            summary.signals,
            [
                "Session Engine L3.folded_lung • Sessions 0 • Active 0 • Stalled 0",
                "Branches 0 • Merge-ready sessions 0 • Merge-ready branches 0",
                "Checkpoints 0 • Events 0 • Steps 0",
                "Pending import • Bundle parser-session.json • Will import as Parser repair (Imported)",
                "Open work will be normalized • Branches 2 • Checkpoints 3 • Events 12 • Steps 1"
            ]
        )
    }

    func testCheckpointPresentationFactsFallBackToStructuredAnchorWhenSummaryLinesAreMissing() {
        let inspection = DecisionSessionRuntimeInspectionSession(
            sessionID: "sess-checkpoint",
            title: "parser repair",
            status: .active,
            updatedAt: Date(timeIntervalSince1970: 100),
            headBranchID: "branch-main",
            latestCheckpointID: "ckpt-9",
            latestCheckpointSeq: 9,
            latestCheckpointGoal: "repair parser",
            latestCheckpointBudgetLine: "eBrain budget: guarded • loops 2 • candidates 2 • decode 160 • thermal watch",
            latestCheckpointRouteLine: "eBrain route: npu • precision mixed • retrieval 3",
            latestCheckpointDecisionLine: nil,
            latestCheckpointTaskLine: nil,
            latestCheckpointPressureLine: "eBrain pressure: latency 82/1200ms • power 46% • cache 67% • thermal nominal -> watch",
            latestCheckpointAuditLine: "eBrain audit findings: 2",
            latestCheckpointActiveKillSwitchesLine: "eBrain active kill switches: force_guard_mode",
            latestCheckpointKillSwitchesLine: "eBrain active kill switches: force_guard_mode • eBrain recommended kill switches: require_reviewed_writes",
            latestCheckpointActionLine: "action: restored active quick workspace state",
            latestCheckpointEBrainAnchor: {
                var anchor = DecisionSessionCheckpointEBrainAnchor(
                    sessionID: "sess-anchor",
                    thoughtFoldChecksum: "fold9abc",
                    riskLevel: "guarded",
                    permitMode: "replace",
                    hostGatePercent: 61,
                    reviewDirectiveLine: "Review update ticket: preserve parser-only correction"
                )
                anchor.riskFactorsLine = "Factors: evidence_caveat_load"
                anchor.reasonCodesLine = "Reason codes: evidence.caveat"
                anchor.courtLine = "Court: agency delay right • remand L9"
                anchor.stackedModes = ["localOnly"]
                anchor.assertionCeiling = "guarded"
                anchor.allowedDomains = ["local.action", "text.replace"]
                anchor.blockedDomains = ["tool.write", "memory.write", "host.write"]
                anchor.substituteType = "local_only_action"
                anchor.sovereignHintLevel = "elevated"
                return anchor
            }(),
            latestEventID: "evt-10",
            latestEventSeq: 10,
            latestEventType: .stepRecovered,
            latestEventDetail: "Recovered from stalled tool step.",
            openStepCount: 1,
            openStepStatus: .planning,
            stalledStepCount: 0,
            branchCount: 2,
            recoveryCount: 1,
            latestRecoveryAt: Date(timeIntervalSince1970: 120)
        )

        let facts = inspection.checkpointPresentationFacts

        XCTAssertEqual(
            facts.resolvedDecisionLine,
            "eBrain risk: guarded • eBrain permit: replace • eBrain host gate: 61% • eBrain fold: fold9abc"
        )
        XCTAssertEqual(
            facts.resolvedTaskLine,
            "Review update ticket: preserve parser-only correction"
        )
        XCTAssertEqual(
            facts.digestLines,
            [
                "eBrain budget: guarded • loops 2 • candidates 2 • decode 160 • thermal watch • eBrain route: npu • precision mixed • retrieval 3",
                "eBrain risk: guarded • eBrain permit: replace • eBrain host gate: 61% • eBrain fold: fold9abc • Review update ticket: preserve parser-only correction",
                "L11 wind gate • primary replace • stacked localOnly • assert guarded • allow local.action, text.replace • block tool.write, memory.write, host.write • substitute local_only_action • sovereign elevated",
                "eBrain pressure: latency 82/1200ms • power 46% • cache 67% • thermal nominal -> watch",
                "Factors: evidence_caveat_load",
                "Reason codes: evidence.caveat",
                "Court: agency delay right • remand L9",
                "eBrain audit findings: 2 • eBrain active kill switches: force_guard_mode • eBrain recommended kill switches: require_reviewed_writes",
                "action: restored active quick workspace state"
            ]
        )

        let presentation = DecisionSessionEnginePresentation.build(
            from: DecisionSystemSessionEngineSummary(
                layerPlacement: .foldedLung,
                sessions: 1,
                activeSessions: 1,
                stalledSessions: 0,
                branches: 2,
                checkpoints: 1,
                events: 10,
                steps: 1,
                activeSession: inspection,
                recentSessions: [inspection],
                headline: "Session Engine L3.folded_lung protects edits, checkpoints, and recovery.",
                signals: []
            )
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
            presentation.activeSession?.checkpointWindGateLine,
            "Wind gate primary replace • stacked local only • assert guarded • allow local.action, text.replace • block tool.write, memory.write, host.write • substitute local only action • sovereign elevated"
        )
        XCTAssertEqual(
            presentation.activeSession?.checkpointRiskFactorsLine,
            "Factors: evidence_caveat_load"
        )
        XCTAssertEqual(
            presentation.activeSession?.checkpointReasonCodesLine,
            "Reason codes: evidence.caveat"
        )
        XCTAssertEqual(
            presentation.activeSession?.checkpointCourtLine,
            "Court: agency delay right • remand L9"
        )
    }

    func testReplayRecoverySummaryBuildsDigestLines() {
        let summary = DecisionSessionEngineReplayRecoverySummary(
            sourceDescriptor: .checkpointRecoveryDefault,
            title: "Checkpoint recovery",
            replayLine: "Replay session sess-active • Head branch-main",
            recoveryLine: "Recovered \(shortenedTime(Date(timeIntervalSince1970: 36_000))) • latest stable checkpoint remains replayable.",
            detailLine: "Checkpoint ckpt-9 • repair parser",
            budgetLine: "eBrain budget: guarded",
            taskLine: "Review update ticket: preserve parser-only correction",
            actionLine: "action: restored active quick workspace state",
            pressureLine: "eBrain pressure: latency 82/1200ms",
            windGateLine: "L11 wind gate • primary replace • stacked localOnly • assert guarded • allow local.action, text.replace • block tool.write, memory.write, host.write • substitute local_only_action • sovereign elevated",
            riskFactorsLine: "Factors: evidence_caveat_load",
            reasonCodesLine: "Reason codes: evidence.caveat",
            courtLine: "Court: agency delay right • remand L9",
            auditLine: "eBrain audit findings: 2",
            sovereignVerdictLine: "Sovereign verdict quarantine • latched • mode guard • reason runtime.quarantine",
            sovereignAuthorityLine: "Sovereign authority • tokens memoryWrite • warrants memoryWrite • policy policy-hash.sess • ttl 30s • witnesses 4 • lock session • quarantine session",
            sovereignAuditLine: "Sovereign audit • BR-SOV-004 • ref audit.session-l14",
            activeKillSwitchesLine: "eBrain active kill switches: force_guard_mode",
            killSwitchesLine: "eBrain active kill switches: force_guard_mode • eBrain recommended kill switches: require_reviewed_writes",
            lungLine: nil,
            resumeLine: nil,
            rollbackLine: nil,
            sovereignBridgeLine: nil
        )

        XCTAssertEqual(
            summary.digestLines,
            [
                "Checkpoint recovery • Replay session sess-active • Head branch-main • Recovered \(shortenedTime(Date(timeIntervalSince1970: 36_000))) • latest stable checkpoint remains replayable.",
                "Checkpoint ckpt-9 • repair parser • eBrain active kill switches: force_guard_mode • eBrain recommended kill switches: require_reviewed_writes",
                "action: restored active quick workspace state",
                "L11 wind gate • primary replace • stacked localOnly • assert guarded • allow local.action, text.replace • block tool.write, memory.write, host.write • substitute local_only_action • sovereign elevated",
                "Factors: evidence_caveat_load • Reason codes: evidence.caveat • Court: agency delay right • remand L9",
                "Sovereign verdict quarantine • latched • mode guard • reason runtime.quarantine",
                "Sovereign authority • tokens memoryWrite • warrants memoryWrite • policy policy-hash.sess • ttl 30s • witnesses 4 • lock session • quarantine session",
                "Sovereign audit • BR-SOV-004 • ref audit.session-l14"
            ]
        )
    }

    func testCheckpointPresentationFactsDigestLinesIncludeWindGateSummary() {
        let facts = DecisionSessionCheckpointPresentationFacts(
            budgetLine: nil,
            routeLine: nil,
            decisionLine: nil,
            taskLine: nil,
            pressureLine: nil,
            presenceLine: nil,
            riskFactorsLine: nil,
            reasonCodesLine: nil,
            courtLine: nil,
            auditLine: nil,
            activeKillSwitchesLine: nil,
            killSwitchesLine: nil,
            actionLine: nil,
            anchor: {
                var anchor = DecisionSessionCheckpointEBrainAnchor(
                    sessionID: "sess-l11",
                    thoughtFoldChecksum: "fold-l11",
                    riskLevel: "high",
                    permitMode: "delay",
                    hostGatePercent: 61,
                    reviewDirectiveLine: "Review guarded resume path"
                )
                anchor.stackedModes = ["draftOnly", "mirror"]
                anchor.assertionCeiling = "guarded"
                anchor.allowedDomains = ["draft.note", "text.delay"]
                anchor.blockedDomains = ["tool.write", "memory.write", "host.write"]
                anchor.delayType = "cool_down"
                anchor.substituteType = "draft"
                anchor.sovereignHintLevel = "elevated"
                return anchor
            }()
        )

        XCTAssertEqual(
            facts.windGateLine,
            "L11 wind gate • primary delay • stacked draftOnly, mirror • assert guarded • allow draft.note, text.delay • block tool.write, memory.write, host.write • delay cool_down • substitute draft • sovereign elevated"
        )
        XCTAssertEqual(
            facts.digestLines,
            [
                "eBrain risk: high • eBrain permit: delay • eBrain host gate: 61% • eBrain fold: fold-l11 • Review guarded resume path",
                "L11 wind gate • primary delay • stacked draftOnly, mirror • assert guarded • allow draft.note, text.delay • block tool.write, memory.write, host.write • delay cool_down • substitute draft • sovereign elevated"
            ]
        )
    }

    func testCheckpointPresentationFactsDigestLinesExpandFoldedLungReceipts() {
        let facts = DecisionSessionCheckpointPresentationFacts(
            budgetLine: nil,
            routeLine: nil,
            decisionLine: nil,
            taskLine: nil,
            pressureLine: nil,
            presenceLine: nil,
            riskFactorsLine: nil,
            reasonCodesLine: nil,
            courtLine: nil,
            auditLine: nil,
            activeKillSwitchesLine: nil,
            killSwitchesLine: nil,
            actionLine: nil,
            anchor: DecisionSessionCheckpointEBrainAnchor(
                sessionID: "sess-active",
                thoughtFoldChecksum: "fold-capability",
                riskLevel: "high",
                permitMode: "delay",
                hostGatePercent: 61,
                reviewDirectiveLine: "Review guarded resume path",
                morphGraph: BASMorphGraph(
                    graphID: "morph-capability",
                    activeOrgans: [.stubCore, .riskSpine, .permitKnot],
                    executionOrder: ["stubCore", "riskSpine", "permitKnot"],
                    precisionMap: [
                        BASNeuralOrganPrecision(organ: .stubCore, tier: .full),
                        BASNeuralOrganPrecision(organ: .riskSpine, tier: .protected),
                        BASNeuralOrganPrecision(organ: .permitKnot, tier: .protected)
                    ],
                    deviceRouteMap: [
                        "stubCore": "coreNPU",
                        "riskSpine": "coreNPU",
                        "permitKnot": "scoutCPU"
                    ],
                    thermalProfile: ["thermal.hot", "latency.192", "cadence.resume_guarded"],
                    sovereignConstraints: ["rollback"]
                ),
                precisionProfile: BASPrecisionProfile(
                    organPrecisions: [
                        BASNeuralOrganPrecision(organ: .stubCore, tier: .full),
                        BASNeuralOrganPrecision(organ: .riskSpine, tier: .protected),
                        BASNeuralOrganPrecision(organ: .permitKnot, tier: .protected)
                    ],
                    lockedPrecisions: [.riskSpine, .permitKnot, .stubCore],
                    degradationOrder: [.full, .protected, .balanced, .minimal],
                    guardSafeFloor: .protected
                ),
                lungState: BASLungState(
                    breathMode: .guard,
                    breathPhase: .resume,
                    thermalPressure: 71,
                    cachePressure: 49,
                    restoreReadiness: 0.91,
                    rollbackAnchorRef: "anchor-safe"
                ),
                resumeFrame: BASResumeFrame(
                    resumeID: "resume-safe",
                    sourceFoldID: "fold-capability",
                    resumeDepth: 2,
                    requiredOrgans: [.riskSpine, .permitKnot, .stubCore],
                    consistencyChecks: ["fold_checksum"],
                    fallbackMode: .rollbackAnchor
                ),
                rollbackAnchor: BASRollbackAnchor(
                    anchorID: "anchor-safe",
                    safeSnapshotRef: "snapshot-safe",
                    foldRefs: ["fold-capability"],
                    hostVersionRef: "host-v1",
                    cacheStateRef: "cache-safe",
                    integrityHash: "hash-safe"
                ),
                sovereignBridgeResult: DecisionFoldedLungSovereignBridgeResult(
                    actuationKinds: [.rollback],
                    invalidatedResumeFrameIDs: ["resume-safe"],
                    invalidatedCacheRefs: ["cache-safe"],
                    invalidatedFoldRefs: ["fold-capability"],
                    invalidatedPackageIDs: [],
                    quarantinedFoldRefs: [],
                    resultingBreathMode: .guard,
                    preservedReadOnlyRecovery: true,
                    summary: "rollback -> snapshot-safe • guard breath"
                )
            )
        )

        let expectedOrganDeltaLine = try! XCTUnwrap(facts.anchor?.organDeltaLine)

        XCTAssertEqual(facts.organDeltaLine, expectedOrganDeltaLine)
        XCTAssertTrue(facts.digestLines.contains(expectedOrganDeltaLine))

        XCTAssertEqual(
            facts.digestLines,
            [
                "eBrain risk: high • eBrain permit: delay • eBrain host gate: 61% • eBrain fold: fold-capability • Review guarded resume path",
                "L11 wind gate • primary delay",
                "Breath guard • Phase resume • Restore 91%",
                "Morph graph morph-capability • organs stubCore, riskSpine, permitKnot • route coreNPU • thermal thermal.hot",
                "Hot pack stubCore, riskSpine, permitKnot • Warm memoryCodecRidge, hostModulationMesh, toolIntentMesh • Cold 6 • preload guard_preload • eviction protective_retain",
                "Precision profile full -> protected -> balanced -> minimal • floor protected • locked riskSpine, permitKnot, stubCore",
                "Organ packages 12 • hot 3 • warm 3 • cold 6 • protected 3 • recovery 2",
                "Organ delta rollback_retain • activate package.stubcore.hot, package.riskspine.hot, package.permitknot.hot • preload package.memorycodecridge.warm, package.hostmodulationmesh.warm, package.toolintentmesh.warm • evict package.criticblade.cold • rollback-safe package.stubcore.hot, package.riskspine.hot, package.permitknot.hot, package.memorycodecridge.warm, package.consistencylattice.cold • sovereign rollback",
                "Breath scheduler guard_resume • checkpoint anchor_each_turn • micro-sleep 173ms • maintenance 0ms • resume rollback_hot",
                "Thermal exchanger balanced_exchange • band warm • actions delay_cold_organs • suppress criticBlade",
                "Integrity weave recovered • checks 3/3 • contamination 2 • hash hash-safe",
                "Resume frame resume-safe • source fold-capability • depth 2 • organs riskSpine, permitKnot, stubCore",
                "Rollback anchor anchor-safe • snapshot snapshot-safe • cache cache-safe",
                "rollback -> snapshot-safe • guard breath",
                "Sovereign invalidated resume resume-safe",
                "Sovereign invalidated cache cache-safe",
                "Sovereign invalidated fold fold-capability",
                "Sovereign rollback retain package.stubcore.hot, package.riskspine.hot, package.permitknot.hot, package.memorycodecridge.warm, package.consistencylattice.cold",
                "Sovereign readonly recovery",
                "Sovereign mode guard"
            ]
        )
    }

    func testPresentationBuildsEmptyStateWithoutSummary() {
        let presentation = DecisionSessionEnginePresentation.build(from: nil)

        XCTAssertEqual(presentation.title, "Session engine")
        XCTAssertNil(presentation.activeSession)
        XCTAssertTrue(presentation.recentSessions.isEmpty)
        XCTAssertFalse(presentation.emptyMessage.isEmpty)
    }

    func testPresentationCarriesActiveAndRecentSessionInspection() {
        let checkpointAnchor: DecisionSessionCheckpointEBrainAnchor = {
            var anchor = DecisionSessionCheckpointEBrainAnchor(
                sessionID: "sess-active",
                thoughtFoldChecksum: "fold9abc",
                riskLevel: "guarded",
                permitMode: "replace",
                hostGatePercent: 61,
                reviewDirectiveLine: "Review update ticket: preserve parser-only correction"
            )
            anchor.riskFactorsLine = "Factors: evidence_caveat_load"
            anchor.reasonCodesLine = "Reason codes: evidence.caveat"
            anchor.courtLine = "Court: agency delay right • remand L9"
            anchor.stackedModes = ["localOnly"]
            anchor.assertionCeiling = "guarded"
            anchor.allowedDomains = ["local.action", "text.replace"]
            anchor.blockedDomains = ["tool.write", "memory.write", "host.write"]
            anchor.substituteType = "local_only_action"
            anchor.sovereignHintLevel = "elevated"
            anchor.sovereignVerdictLine = "Sovereign verdict quarantine • latched • mode quarantine • reason runtime.quarantine"
            anchor.sovereignAuthorityLine = "Sovereign authority • tokens memoryWrite • warrants memoryWrite • policy policy-hash.sess • ttl 30s • witnesses 4 • lock session • quarantine session"
            anchor.sovereignAuditLine = "Sovereign audit • BR-SOV-004 • ref audit.session-l14"
            anchor.lungState = BASLungState(
                breathMode: .guard,
                breathPhase: .resume,
                thermalPressure: 67,
                cachePressure: 54,
                restoreReadiness: 0.82,
                rollbackAnchorRef: "anchor-active"
            )
            anchor.resumeFrame = BASResumeFrame(
                resumeID: "resume-active",
                sourceFoldID: "fold9abc",
                resumeDepth: 2,
                requiredOrgans: [.riskSpine, .permitKnot, .stubCore],
                consistencyChecks: ["fold_checksum", "risk_permit"],
                fallbackMode: .rollbackAnchor
            )
            anchor.rollbackAnchor = BASRollbackAnchor(
                anchorID: "anchor-active",
                safeSnapshotRef: "snapshot-active",
                foldRefs: ["fold9abc"],
                hostVersionRef: "host.v2",
                cacheStateRef: "cache-active",
                integrityHash: "hash-active"
            )
            anchor.sovereignBridgeResult = DecisionFoldedLungSovereignBridgeResult(
                actuationKinds: [.rollback],
                invalidatedResumeFrameIDs: ["resume-stale"],
                invalidatedCacheRefs: ["cache-dirty"],
                invalidatedFoldRefs: ["fold-dirty"],
                invalidatedPackageIDs: [],
                quarantinedFoldRefs: [],
                resultingBreathMode: .guard,
                preservedReadOnlyRecovery: true,
                summary: "rollback -> snapshot-active • guard breath"
            )
            return anchor
        }()

        let active = DecisionSessionRuntimeInspectionSession(
            sessionID: "sess-active",
            title: "parser repair",
            status: .active,
            updatedAt: Date(timeIntervalSince1970: 100),
            headBranchID: "branch-active",
            latestCheckpointID: "ckpt-9",
            latestCheckpointSeq: 9,
            latestCheckpointGoal: "repair parser",
            latestCheckpointBudgetLine: "eBrain budget: engage • loops 2 • candidates 2 • decode 192 • thermal watch",
            latestCheckpointRouteLine: "eBrain route: npu • precision mixed • retrieval 3",
            latestCheckpointDecisionLine: "eBrain risk: guarded • eBrain permit: replace • eBrain host gate: 61% • eBrain fold: fold9abc",
            latestCheckpointTaskLine: "Review update ticket: preserve parser-only correction",
            latestCheckpointPressureLine: "eBrain pressure: latency 82/1200ms • power 46% • cache 67% • thermal nominal -> watch",
            latestCheckpointAuditLine: "eBrain audit findings: 2",
            latestCheckpointActiveKillSwitchesLine: "eBrain active kill switches: force_guard_mode",
            latestCheckpointKillSwitchesLine: "eBrain active kill switches: force_guard_mode • eBrain recommended kill switches: require_reviewed_writes",
            latestCheckpointActionLine: "action: restored active quick workspace state",
            latestCheckpointEBrainAnchor: checkpointAnchor,
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
        XCTAssertEqual(presentation.recentSessions.map { $0.sessionID }, ["sess-recent"])
        XCTAssertTrue(presentation.countsLine.contains("Sessions 2"))
        XCTAssertTrue(presentation.countsLine.contains("Checkpoints 4"))
        XCTAssertEqual(
            presentation.healthSummary?.severity,
            DecisionSessionEngineHealthSeverity.watch
        )
        XCTAssertEqual(presentation.healthSummary?.title, "Recovery attention required")
        XCTAssertTrue(presentation.healthLine?.contains("Stalled sessions 1") == true)
        XCTAssertEqual(presentation.reviewItems.map { $0.title }, [
            "Merge review queue",
            "Replay anchor ready",
            "Sovereign posture",
            "Horizon diagnostics"
        ])
        XCTAssertTrue(presentation.reviewItems[0].detail.contains("Merge-ready branches 1"))
        XCTAssertTrue(presentation.reviewItems[1].detail.contains("Checkpoint ckpt-9"))
        XCTAssertEqual(
            presentation.reviewItems[2].detail,
            "Sovereign verdict quarantine • latched • mode quarantine • reason runtime.quarantine • Sovereign authority • tokens memoryWrite • warrants memoryWrite • policy policy-hash.sess • ttl 30s • witnesses 4 • lock session • quarantine session • Sovereign audit • BR-SOV-004 • ref audit.session-l14"
        )
        XCTAssertEqual(
            presentation.reviewItems[2].severity,
            DecisionSessionEngineHealthSeverity.watch
        )
        XCTAssertEqual(
            presentation.reviewItems[3].detail,
            "Factors: evidence_caveat_load • Reason codes: evidence.caveat • Court: agency delay right • remand L9"
        )
        XCTAssertEqual(presentation.activeSession?.healthSummary?.severity, .stable)
        XCTAssertEqual(presentation.activeSession?.healthSummary?.title, "Recovered checkpoint line")
        XCTAssertEqual(presentation.activeSession?.replayRecoverySummary.sourceDescriptor.kind, .checkpointRecovery)
        XCTAssertEqual(presentation.activeSession?.replayRecoverySummary.title, "Checkpoint recovery")
        XCTAssertTrue(presentation.activeSession?.replayRecoverySummary.replayLine.contains("sess-active") == true)
        XCTAssertEqual(
            presentation.activeSession?.replayRecoverySummary.detailLine,
            "Checkpoint ckpt-9 • repair parser"
        )
        XCTAssertEqual(
            presentation.activeSession?.checkpointAuditLine,
            "eBrain audit findings: 2"
        )
        XCTAssertEqual(
            presentation.activeSession?.checkpointSovereignVerdictLine,
            "Sovereign verdict quarantine • latched • mode quarantine • reason runtime.quarantine"
        )
        XCTAssertEqual(
            presentation.activeSession?.checkpointSovereignAuthorityLine,
            "Sovereign authority • tokens memoryWrite • warrants memoryWrite • policy policy-hash.sess • ttl 30s • witnesses 4 • lock session • quarantine session"
        )
        XCTAssertEqual(
            presentation.activeSession?.checkpointSovereignAuditLine,
            "Sovereign audit • BR-SOV-004 • ref audit.session-l14"
        )
        XCTAssertEqual(
            presentation.activeSession?.checkpointKillSwitchesLine,
            "eBrain active kill switches: force_guard_mode • eBrain recommended kill switches: require_reviewed_writes"
        )
        XCTAssertEqual(
            presentation.activeSession?.checkpointPressureLine,
            "eBrain pressure: latency 82/1200ms • power 46% • cache 67% • thermal nominal -> watch"
        )
        XCTAssertEqual(
            presentation.activeSession?.replayRecoverySummary.auditLine,
            "eBrain audit findings: 2"
        )
        XCTAssertEqual(
            presentation.activeSession?.replayRecoverySummary.sovereignVerdictLine,
            "Sovereign verdict quarantine • latched • mode quarantine • reason runtime.quarantine"
        )
        XCTAssertEqual(
            presentation.activeSession?.replayRecoverySummary.sovereignAuthorityLine,
            "Sovereign authority • tokens memoryWrite • warrants memoryWrite • policy policy-hash.sess • ttl 30s • witnesses 4 • lock session • quarantine session"
        )
        XCTAssertEqual(
            presentation.activeSession?.replayRecoverySummary.sovereignAuditLine,
            "Sovereign audit • BR-SOV-004 • ref audit.session-l14"
        )
        XCTAssertEqual(
            presentation.activeSession?.replayRecoverySummary.pressureLine,
            "eBrain pressure: latency 82/1200ms • power 46% • cache 67% • thermal nominal -> watch"
        )
        XCTAssertEqual(
            presentation.activeSession?.replayRecoverySummary.activeKillSwitchesLine,
            "eBrain active kill switches: force_guard_mode"
        )
        XCTAssertEqual(
            presentation.activeSession?.replayRecoverySummary.killSwitchesLine,
            "eBrain active kill switches: force_guard_mode • eBrain recommended kill switches: require_reviewed_writes"
        )
        XCTAssertTrue(presentation.activeSession?.checkpointLine.contains("ckpt-9") == true)
        XCTAssertEqual(
            presentation.activeSession?.checkpointBudgetLine,
            "eBrain budget: engage • loops 2 • candidates 2 • decode 192 • thermal watch • eBrain route: npu • precision mixed • retrieval 3"
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
            presentation.activeSession?.checkpointWindGateLine,
            "Wind gate primary replace • stacked local only • assert guarded • allow local.action, text.replace • block tool.write, memory.write, host.write • substitute local only action • sovereign elevated"
        )
        XCTAssertEqual(
            presentation.activeSession?.checkpointActionLine,
            "action: restored active quick workspace state"
        )
        XCTAssertEqual(
            presentation.activeSession?.checkpointRiskFactorsLine,
            "Factors: evidence_caveat_load"
        )
        XCTAssertEqual(
            presentation.activeSession?.checkpointReasonCodesLine,
            "Reason codes: evidence.caveat"
        )
        XCTAssertEqual(
            presentation.activeSession?.checkpointCourtLine,
            "Court: agency delay right • remand L9"
        )
        XCTAssertEqual(
            presentation.activeSession?.replayRecoverySummary.actionLine,
            "action: restored active quick workspace state"
        )
        XCTAssertEqual(
            presentation.activeSession?.replayRecoverySummary.riskFactorsLine,
            "Factors: evidence_caveat_load"
        )
        XCTAssertEqual(
            presentation.activeSession?.replayRecoverySummary.reasonCodesLine,
            "Reason codes: evidence.caveat"
        )
        XCTAssertEqual(
            presentation.activeSession?.replayRecoverySummary.courtLine,
            "Court: agency delay right • remand L9"
        )
        XCTAssertEqual(
            presentation.activeSession?.replayRecoverySummary.windGateLine,
            "Wind gate primary replace • stacked local only • assert guarded • allow local.action, text.replace • block tool.write, memory.write, host.write • substitute local only action • sovereign elevated"
        )
        XCTAssertTrue(
            presentation.activeSession?.replayRecoverySummary.digestLines.contains(
                "Factors: evidence_caveat_load • Reason codes: evidence.caveat • Court: agency delay right • remand L9"
            ) == true
        )
        XCTAssertTrue(
            presentation.activeSession?.replayRecoverySummary.digestLines.contains(
                "Wind gate primary replace • stacked local only • assert guarded • allow local.action, text.replace • block tool.write, memory.write, host.write • substitute local only action • sovereign elevated"
            ) == true
        )
        XCTAssertTrue(
            presentation.activeSession?.replayRecoverySummary.digestLines.contains(
                "Sovereign verdict quarantine • latched • mode quarantine • reason runtime.quarantine"
            ) == true
        )
        XCTAssertTrue(
            presentation.activeSession?.replayRecoverySummary.digestLines.contains(
                "Sovereign authority • tokens memoryWrite • warrants memoryWrite • policy policy-hash.sess • ttl 30s • witnesses 4 • lock session • quarantine session"
            ) == true
        )
        XCTAssertTrue(
            presentation.activeSession?.replayRecoverySummary.digestLines.contains(
                "Sovereign audit • BR-SOV-004 • ref audit.session-l14"
            ) == true
        )
        XCTAssertEqual(
            presentation.activeSession?.lungLine,
            "Breath guard • Phase resume • Restore 82%"
        )
        XCTAssertEqual(
            presentation.activeSession?.morphLine,
            "Morph graph morph.sess-active.fold9abc • organs riskSpine, permitKnot, stubCore • route checkpoint • thermal checkpoint-recovery"
        )
        XCTAssertEqual(
            presentation.activeSession?.precisionLine,
            "Precision profile full -> protected -> balanced -> minimal • floor protected • locked riskSpine, permitKnot, stubCore"
        )
        XCTAssertEqual(
            presentation.activeSession?.organPackageLine,
            "Organ packages 12 • hot 3 • warm 3 • cold 6 • protected 3 • recovery 2"
        )
        XCTAssertTrue(
            presentation.activeSession?.organDeltaLine?.contains("Organ delta rollback_retain") == true
        )
        XCTAssertEqual(
            presentation.activeSession?.schedulerLine,
            "Breath scheduler guard_resume • checkpoint anchor_each_turn • micro-sleep 166ms • maintenance 0ms • resume rollback_hot"
        )
        XCTAssertEqual(
            presentation.activeSession?.integrityWeaveLine,
            "Integrity weave recovered • checks 3/3 • contamination 2 • hash hash-active"
        )
        XCTAssertEqual(
            presentation.activeSession?.resumeLine,
            "Resume frame resume-active • source fold9abc • depth 2 • organs riskSpine, permitKnot, stubCore"
        )
        XCTAssertEqual(
            presentation.activeSession?.rollbackLine,
            "Rollback anchor anchor-active • snapshot snapshot-active • cache cache-active"
        )
        XCTAssertEqual(
            presentation.activeSession?.sovereignBridgeLine,
            "rollback -> snapshot-active • guard breath"
        )
        XCTAssertEqual(
            presentation.activeSession?.replayRecoverySummary.lungLine,
            "Breath guard • Phase resume • Restore 82%"
        )
        XCTAssertEqual(
            presentation.activeSession?.replayRecoverySummary.morphLine,
            "Morph graph morph.sess-active.fold9abc • organs riskSpine, permitKnot, stubCore • route checkpoint • thermal checkpoint-recovery"
        )
        XCTAssertEqual(
            presentation.activeSession?.replayRecoverySummary.precisionLine,
            "Precision profile full -> protected -> balanced -> minimal • floor protected • locked riskSpine, permitKnot, stubCore"
        )
        XCTAssertEqual(
            presentation.activeSession?.replayRecoverySummary.organPackageLine,
            "Organ packages 12 • hot 3 • warm 3 • cold 6 • protected 3 • recovery 2"
        )
        XCTAssertTrue(
            presentation.activeSession?.replayRecoverySummary.organDeltaLine?.contains("Organ delta rollback_retain") == true
        )
        XCTAssertEqual(
            presentation.activeSession?.replayRecoverySummary.schedulerLine,
            "Breath scheduler guard_resume • checkpoint anchor_each_turn • micro-sleep 166ms • maintenance 0ms • resume rollback_hot"
        )
        XCTAssertEqual(
            presentation.activeSession?.replayRecoverySummary.integrityWeaveLine,
            "Integrity weave recovered • checks 3/3 • contamination 2 • hash hash-active"
        )
        XCTAssertEqual(
            presentation.activeSession?.replayRecoverySummary.resumeLine,
            "Resume frame resume-active • source fold9abc • depth 2 • organs riskSpine, permitKnot, stubCore"
        )
        XCTAssertEqual(
            presentation.activeSession?.replayRecoverySummary.rollbackLine,
            "Rollback anchor anchor-active • snapshot snapshot-active • cache cache-active"
        )
        XCTAssertEqual(
            presentation.activeSession?.replayRecoverySummary.sovereignBridgeLine,
            "rollback -> snapshot-active • guard breath"
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

    func testPresentationElevatesHorizonDiagnosticsIntoHealthSummary() {
        let active = DecisionSessionRuntimeInspectionSession(
            sessionID: "sess-horizon",
            title: "latest policy review",
            status: .active,
            updatedAt: Date(timeIntervalSince1970: 260),
            headBranchID: "branch-main",
            latestCheckpointID: "ckpt-14",
            latestCheckpointSeq: 14,
            latestCheckpointGoal: "preserve stable facts only",
            latestCheckpointEBrainAnchor: DecisionSessionCheckpointEBrainAnchor(
                sessionID: "sess-horizon",
                thoughtFoldChecksum: "fold14abc",
                riskLevel: "guarded",
                permitMode: "delay",
                hostGatePercent: 44,
                riskFactorsLine: "Factors: evidence_caveat_load",
                reasonCodesLine: "Reason codes: evidence.caveat",
                courtLine: "Court: agency delay right • remand L9"
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
        let summary = DecisionSystemSessionEngineSummary(
            layerPlacement: .foldedLung,
            sessions: 1,
            activeSessions: 1,
            stalledSessions: 0,
            branches: 1,
            checkpoints: 1,
            events: 14,
            steps: 0,
            activeSession: active,
            recentSessions: [active],
            headline: "Session Engine L3.folded_lung protects edits, checkpoints, and recovery.",
            signals: []
        )

        let presentation = DecisionSessionEnginePresentation.build(from: summary)

        XCTAssertEqual(
            presentation.healthSummary?.severity,
            DecisionSessionEngineHealthSeverity.watch
        )
        XCTAssertEqual(presentation.healthSummary?.title, "Horizon diagnostics active")
        XCTAssertEqual(
            presentation.healthLine,
            "Factors: evidence_caveat_load • Reason codes: evidence.caveat • Court: agency delay right • remand L9"
        )
        XCTAssertEqual(
            presentation.activeSession?.healthSummary?.severity,
            DecisionSessionEngineHealthSeverity.watch
        )
        XCTAssertEqual(presentation.activeSession?.healthSummary?.title, "Horizon diagnostics active")
        XCTAssertEqual(
            presentation.activeSession?.healthSummary?.detail,
            "Factors: evidence_caveat_load • Reason codes: evidence.caveat • Court: agency delay right • remand L9"
        )
        XCTAssertEqual(
            presentation.reviewItems.map { $0.title },
            [
                "Replay anchor ready",
                "Horizon diagnostics"
            ]
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
                branchLine: "Head main • Layer L3.folded_lung",
                unfinishedStepCount: 1,
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
        XCTAssertEqual(
            presentation.pendingImportPreview?.unfinishedWorkSummary.severity,
            DecisionSessionEngineHealthSeverity.watch
        )
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
        XCTAssertEqual(
            presentation.healthSummary?.severity,
            DecisionSessionEngineHealthSeverity.watch
        )
        XCTAssertEqual(presentation.healthSummary?.title, "Merge review pending")
        XCTAssertEqual(
            presentation.healthLine,
            DecisionSessionReviewPresentationSupport.mergeReviewDetail(
                mergeReadySessions: 1,
                mergeableBranches: 2
            )
        )
        XCTAssertEqual(presentation.activeSession?.replayRecoverySummary.sourceDescriptor.kind, .liveRuntime)
        XCTAssertEqual(presentation.activeSession?.replayRecoverySummary.title, "Live runtime")
        XCTAssertTrue(presentation.activeSession?.replayRecoverySummary.replayLine.contains("sess-merge") == true)
        XCTAssertNil(presentation.activeSession?.replayRecoverySummary.killSwitchesLine)
        XCTAssertEqual(presentation.reviewItems.map { $0.title }, [
            "Merge review queue",
            "Replay anchor ready"
        ])
        XCTAssertTrue(presentation.reviewItems[0].detail.contains("Merge-ready branches 2"))
        XCTAssertTrue(presentation.reviewItems[1].detail.contains("Checkpoint ckpt-merge"))
    }
}
