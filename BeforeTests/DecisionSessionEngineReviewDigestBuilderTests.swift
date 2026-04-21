import XCTest
@testable import Before

final class DecisionSessionEngineReviewDigestBuilderTests: XCTestCase {
    func testBuildIncludesPendingImportMergeAndReplaySignals() {
        let session = DecisionSessionRuntimeInspectionSession(
            sessionID: "sess-replay",
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
        let summary = DecisionSystemSessionEngineSummary(
            layerPlacement: .foldedLung,
            sessions: 1,
            activeSessions: 1,
            stalledSessions: 0,
            mergeReadySessions: 1,
            mergeableBranches: 1,
            branches: 2,
            checkpoints: 3,
            events: 10,
            steps: 1,
            activeSession: session,
            recentSessions: [session],
            headline: "Session Engine L3.folded_lung protects edits, checkpoints, and recovery.",
            signals: [],
            pendingImportPreview: pendingImport.presentation
        )

        let reviewLines = DecisionSessionEngineReviewDigestBuilder.build(from: summary)

        XCTAssertEqual(reviewLines.map(\.title), [
            "Pending import draft",
            "Merge review queue",
            "Replay anchor ready"
        ])
        XCTAssertEqual(
            reviewLines,
            DecisionSessionReviewPresentationSupport.digestLines(from: summary)
        )
        XCTAssertTrue(reviewLines[0].detail.contains("Bundle parser-session.json"))
        XCTAssertEqual(reviewLines[0].severity, .watch)
        XCTAssertTrue(reviewLines[1].detail.contains("Merge-ready branches 1"))
        XCTAssertEqual(reviewLines[1].severity, .watch)
        XCTAssertTrue(reviewLines[2].detail.contains("Checkpoint ckpt-9"))
        XCTAssertEqual(reviewLines[2].severity, .stable)
    }

    func testPresentationsAndSignalLinesMirrorDigestLines() {
        let session = DecisionSessionRuntimeInspectionSession(
            sessionID: "sess-shared",
            title: "budget guard",
            status: .paused,
            updatedAt: Date(timeIntervalSince1970: 220),
            headBranchID: "branch-main",
            latestCheckpointID: "ckpt-3",
            latestCheckpointSeq: 3,
            latestCheckpointGoal: "guard runtime budget",
            latestEventID: "evt-4",
            latestEventSeq: 4,
            latestEventType: .assistantMessage,
            latestEventDetail: "Checkpoint line preserved.",
            openStepCount: 0,
            openStepStatus: nil,
            stalledStepCount: 0,
            branchCount: 1,
            mergeableBranchCount: 0,
            recoveryCount: 1,
            latestRecoveryAt: Date(timeIntervalSince1970: 230)
        )
        let summary = DecisionSystemSessionEngineSummary(
            layerPlacement: .foldedLung,
            sessions: 1,
            activeSessions: 0,
            stalledSessions: 0,
            mergeReadySessions: 0,
            mergeableBranches: 0,
            branches: 1,
            checkpoints: 1,
            events: 4,
            steps: 0,
            activeSession: session,
            recentSessions: [session],
            headline: "Session Engine folded_lung protects edits, checkpoints, and recovery.",
            signals: [],
            pendingImportPreview: nil
        )

        let reviewLines = DecisionSessionEngineReviewDigestBuilder.build(from: summary)
        let presentations = DecisionSessionEngineReviewDigestBuilder.presentations(from: summary)
        let signalLines = DecisionSessionEngineReviewDigestBuilder.signalLines(from: summary)

        XCTAssertEqual(presentations.map(\.id), reviewLines.map(\.id))
        XCTAssertEqual(presentations.map(\.title), reviewLines.map(\.title))
        XCTAssertEqual(presentations.map(\.detail), reviewLines.map(\.detail))
        XCTAssertEqual(presentations.map(\.severity), reviewLines.map(\.severity))
        XCTAssertEqual(
            signalLines,
            reviewLines.map(DecisionSessionReviewPresentationSupport.signalLine)
        )
    }

    func testBuildOmitsMergeAndReplaySignalsWhenSourceFactsAreMissing() {
        let summary = DecisionSystemSessionEngineSummary(
            layerPlacement: .foldedLung,
            sessions: 1,
            activeSessions: 0,
            stalledSessions: 0,
            mergeReadySessions: 0,
            mergeableBranches: 0,
            branches: 1,
            checkpoints: 1,
            events: 4,
            steps: 0,
            activeSession: nil,
            recentSessions: [
                DecisionSessionRuntimeInspectionSession(
                    sessionID: "sess-no-anchor",
                    title: "draft import",
                    status: .paused,
                    updatedAt: Date(timeIntervalSince1970: 140),
                    headBranchID: "branch-main",
                    latestCheckpointID: nil,
                    latestCheckpointSeq: nil,
                    latestCheckpointGoal: nil,
                    latestEventID: "evt-4",
                    latestEventSeq: 4,
                    latestEventType: .assistantMessage,
                    latestEventDetail: "No replay anchor available.",
                    openStepCount: 0,
                    openStepStatus: nil,
                    stalledStepCount: 0,
                    branchCount: 1,
                    mergeableBranchCount: 0,
                    recoveryCount: 0,
                    latestRecoveryAt: nil
                )
            ],
            headline: "Session Engine L3.folded_lung protects edits, checkpoints, and recovery.",
            signals: [],
            pendingImportPreview: DecisionSessionEnginePendingImportPreview(
                sourceFileName: "draft-session.json",
                preview: DecisionSessionImportBundlePreview(
                    id: "preview-2",
                    sourceSessionId: "sess-draft",
                    sourceTitle: "Draft import",
                    importedTitle: "Draft import (Imported)",
                    exportedAt: Date(timeIntervalSince1970: 310),
                    countsLine: "Branches 1 • Checkpoints 1 • Events 4 • Steps 0",
                    integrityLine: "Validated schema v1 • fingerprint fedcba654321",
                    checkpointLine: "Latest checkpoint ckpt-1 • draft import",
                    branchLine: "Head main • Layer folded_lung",
                    unfinishedStepCount: 0,
                    unfinishedStepsLine: "Open steps 0 • nothing needs recovery normalization.",
                    headline: "Importing creates a new paused recovery-safe session.",
                    branchPreviews: []
                )
            ).presentation
        )

        let reviewLines = DecisionSessionEngineReviewDigestBuilder.build(from: summary)

        XCTAssertEqual(reviewLines.map(\.title), ["Pending import draft"])
        XCTAssertTrue(reviewLines[0].detail.contains("Bundle draft-session.json"))
        XCTAssertEqual(reviewLines[0].severity, DecisionSessionEngineHealthSeverity.stable)
    }

    func testBuildIncludesHorizonDiagnosticsWhenCheckpointCarriesCaveatSignals() {
        let session = DecisionSessionRuntimeInspectionSession(
            sessionID: "sess-horizon",
            title: "evidence review",
            status: .active,
            updatedAt: Date(timeIntervalSince1970: 240),
            headBranchID: "branch-main",
            latestCheckpointID: "ckpt-horizon",
            latestCheckpointSeq: 4,
            latestCheckpointGoal: "preserve uncertainty",
            latestCheckpointEBrainAnchor: DecisionSessionCheckpointEBrainAnchor(
                sessionID: "sess-horizon",
                thoughtFoldChecksum: "fold-horizon",
                riskLevel: "guarded",
                permitMode: "replace",
                hostGatePercent: 58,
                reviewDirectiveLine: "Review evidence caveat before promotion.",
                riskFactorsLine: "Factors: evidence_caveat_load",
                reasonCodesLine: "Reason codes: evidence.caveat",
                courtLine: "Court: agency delay right • remand L9"
            ),
            latestEventID: "evt-5",
            latestEventSeq: 5,
            latestEventType: .assistantMessage,
            latestEventDetail: "Caveated checkpoint recorded.",
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
            mergeReadySessions: 0,
            mergeableBranches: 0,
            branches: 1,
            checkpoints: 1,
            events: 5,
            steps: 0,
            activeSession: session,
            recentSessions: [session],
            headline: "Session Engine folded_lung protects edits, checkpoints, and recovery.",
            signals: []
        )

        let reviewLines = DecisionSessionEngineReviewDigestBuilder.build(from: summary)

        XCTAssertEqual(reviewLines.map(\.title), [
            "Replay anchor ready",
            "Horizon diagnostics"
        ])
        XCTAssertEqual(
            reviewLines.last?.detail,
            "Factors: evidence_caveat_load • Reason codes: evidence.caveat • Court: agency delay right • remand L9"
        )
        XCTAssertEqual(reviewLines.last?.severity, .watch)
    }

    func testBuildIncludesSovereignPostureWhenCheckpointCarriesStructuredSovereignLines() {
        let session = DecisionSessionRuntimeInspectionSession(
            sessionID: "sess-sovereign",
            title: "quarantine review",
            status: .active,
            updatedAt: Date(timeIntervalSince1970: 260),
            headBranchID: "branch-main",
            latestCheckpointID: "ckpt-sovereign",
            latestCheckpointSeq: 7,
            latestCheckpointGoal: "preserve safe continuity",
            latestCheckpointEBrainAnchor: DecisionSessionCheckpointEBrainAnchor(
                sessionID: "sess-sovereign",
                thoughtFoldChecksum: "fold-sovereign",
                riskLevel: "guarded",
                permitMode: "replace",
                hostGatePercent: 63,
                sovereignVerdictLine: "Sovereign verdict quarantine • latched • mode guard • reason runtime.quarantine",
                sovereignAuthorityLine: "Sovereign authority • tokens memoryWrite • warrants memoryWrite • policy policy-hash.sess • ttl 30s • witnesses 4 • lock session • quarantine session",
                sovereignAuditLine: "Sovereign audit • BR-SOV-004 • ref audit.session-l14"
            ),
            latestEventID: "evt-8",
            latestEventSeq: 8,
            latestEventType: .assistantMessage,
            latestEventDetail: "Quarantine facts preserved.",
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
            mergeReadySessions: 0,
            mergeableBranches: 0,
            branches: 1,
            checkpoints: 1,
            events: 8,
            steps: 0,
            activeSession: session,
            recentSessions: [session],
            headline: "Session Engine folded_lung protects edits, checkpoints, and recovery.",
            signals: []
        )

        let reviewLines = DecisionSessionEngineReviewDigestBuilder.build(from: summary)

        XCTAssertEqual(reviewLines.map(\.title), [
            "Replay anchor ready",
            "Sovereign posture"
        ])
        XCTAssertEqual(
            reviewLines[1].detail,
            "Sovereign verdict quarantine • latched • mode guard • reason runtime.quarantine • Sovereign authority • tokens memoryWrite • warrants memoryWrite • policy policy-hash.sess • ttl 30s • witnesses 4 • lock session • quarantine session • Sovereign audit • BR-SOV-004 • ref audit.session-l14"
        )
        XCTAssertEqual(reviewLines[1].severity, .watch)
    }
}
