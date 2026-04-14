import XCTest
@testable import Before

final class DecisionSessionEngineReviewPresentationTests: XCTestCase {
    func testImportPreviewPresentationMarksSafePausedImportAsStable() {
        let preview = DecisionSessionImportBundlePreview(
            id: "sess-preview|1",
            sourceSessionId: "sess-preview",
            sourceTitle: "Parser repair",
            importedTitle: "Parser repair (Imported)",
            exportedAt: Date(timeIntervalSince1970: 100),
            countsLine: "Branches 1 • Checkpoints 1 • Events 8 • Steps 0",
            integrityLine: "Validated schema v1 • fingerprint abcdef123456",
            checkpointLine: "Latest checkpoint ckpt-1 • repair parser",
            branchLine: "Head main • Layer folded_lung",
            unfinishedStepsLine: "Open steps 0 • import can start from a paused safe point.",
            headline: "Importing creates a new paused recovery-safe session.",
            branchPreviews: [
                DecisionSessionImportBundleBranchPreview(
                    id: "main",
                    name: "main",
                    statusLine: "Active • exported head",
                    detailLine: "Created Apr 14 at 10:00 AM",
                    isHead: true
                )
            ]
        )

        let presentation = DecisionSessionEngineImportPreviewPresentation.build(
            from: preview,
            sourceFileName: "session-bundle.json"
        )

        XCTAssertEqual(presentation.title, "Import Session Engine bundle")
        XCTAssertEqual(presentation.bundleLine, "Bundle session-bundle.json")
        XCTAssertEqual(presentation.sourceLine, "Source Parser repair")
        XCTAssertEqual(presentation.importedLine, "Will import as Parser repair (Imported)")
        XCTAssertEqual(presentation.checkpointLine, "Latest checkpoint ckpt-1 • repair parser")
        XCTAssertEqual(presentation.branchLine, "Head main • Layer folded_lung")
        XCTAssertEqual(presentation.unfinishedWorkSummary.severity, .stable)
        XCTAssertEqual(presentation.unfinishedWorkSummary.title, "Recovery-safe import")
        XCTAssertEqual(
            presentation.detailRows.map(\.label),
            [
                "Bundle",
                "Source session",
                "Imported title",
                "Counts",
                "Integrity",
                "Checkpoint",
                "Branch line"
            ]
        )
        XCTAssertEqual(
            presentation.detailRows.last?.value,
            "Head main • Layer folded_lung"
        )
        XCTAssertEqual(presentation.branchPresentations.count, 1)
        XCTAssertTrue(presentation.branchPresentations.first?.isHead == true)
    }

    func testImportPreviewPresentationMarksUnfinishedStepsAsWatch() {
        let preview = DecisionSessionImportBundlePreview(
            id: "sess-preview|2",
            sourceSessionId: "sess-preview",
            sourceTitle: "Tool crash",
            importedTitle: "Tool crash (Imported)",
            exportedAt: Date(timeIntervalSince1970: 100),
            countsLine: "Branches 2 • Checkpoints 1 • Events 10 • Steps 1",
            integrityLine: "Validated schema v1 • fingerprint abcdef123456",
            checkpointLine: "Latest checkpoint ckpt-2",
            branchLine: "Head recovery-main • Layer folded_lung",
            unfinishedStepsLine: "Open steps 2 • unfinished work will import as failed recovery facts.",
            headline: "Importing creates a new paused recovery-safe session.",
            branchPreviews: []
        )

        let presentation = DecisionSessionEngineImportPreviewPresentation.build(
            from: preview,
            sourceFileName: "tool-crash.json"
        )

        XCTAssertEqual(presentation.unfinishedWorkSummary.severity, .watch)
        XCTAssertEqual(presentation.unfinishedWorkSummary.title, "Open work will be normalized")
        XCTAssertEqual(presentation.checkpointLine, "Latest checkpoint ckpt-2")
        XCTAssertEqual(presentation.branchLine, "Head recovery-main • Layer folded_lung")
        XCTAssertEqual(
            presentation.detailRows.first?.value,
            "tool-crash.json"
        )
        XCTAssertTrue(presentation.branchPresentations.isEmpty)
    }

    func testMergeReviewPresentationPreservesAppendOnlySummary() {
        let review = DecisionSessionEngineControlMergeReview(
            sourceBranchID: "branch-correction",
            sourceBranchName: "correction-parser",
            targetBranchID: "branch-main",
            targetBranchName: "main",
            sourceStatusLine: "Active",
            targetStatusLine: "Active • current head",
            checkpointLine: "Selected checkpoint ckpt-9 • repair parser",
            summaryLine: "Merge will append a branch_merged fact onto the current head branch.",
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

        let presentation = DecisionSessionEngineMergeReviewPresentation.build(from: review)

        XCTAssertEqual(presentation.title, "Merge review")
        XCTAssertEqual(presentation.routeLine, "correction-parser → main")
        XCTAssertEqual(presentation.sourceStatusLine, "Active")
        XCTAssertEqual(presentation.targetStatusLine, "Active • current head")
        XCTAssertEqual(presentation.checkpointLine, "Selected checkpoint ckpt-9 • repair parser")
        XCTAssertEqual(presentation.summary.severity, .stable)
        XCTAssertEqual(presentation.summary.title, "Append-only merge")
        XCTAssertEqual(presentation.summary.detail, "Merge will append a branch_merged fact onto the current head branch.")
        XCTAssertEqual(
            presentation.detailRows.map(\.label),
            [
                "Source branch",
                "Target branch",
                "Source status",
                "Target status",
                "Checkpoint"
            ]
        )
        XCTAssertTrue(presentation.summary.detail.contains("branch_merged"))
    }
}
