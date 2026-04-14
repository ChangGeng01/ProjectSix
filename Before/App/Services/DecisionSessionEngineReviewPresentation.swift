import Foundation

struct DecisionSessionEngineReviewDetailPresentation: Equatable, Sendable, Identifiable {
    let id: String
    let label: String
    let value: String
}

struct DecisionSessionEnginePendingImportPreview: Equatable, Sendable {
    let sourceFileName: String
    let preview: DecisionSessionImportBundlePreview

    var presentation: DecisionSessionEngineImportPreviewPresentation {
        DecisionSessionEngineImportPreviewPresentation.build(
            from: preview,
            sourceFileName: sourceFileName
        )
    }
}

struct DecisionSessionEngineImportBranchPresentation: Equatable, Sendable, Identifiable {
    let id: String
    let name: String
    let statusLine: String
    let detailLine: String
    let isHead: Bool
}

struct DecisionSessionEngineImportPreviewPresentation: Equatable, Sendable {
    let title: String
    let headline: String
    let bundleLine: String
    let sourceLine: String
    let importedLine: String
    let countsLine: String
    let integrityLine: String
    let checkpointLine: String
    let branchLine: String
    let unfinishedWorkSummary: DecisionSessionEngineHealthSummary
    let detailRows: [DecisionSessionEngineReviewDetailPresentation]
    let branchPresentations: [DecisionSessionEngineImportBranchPresentation]

    static func build(
        from preview: DecisionSessionImportBundlePreview,
        sourceFileName: String
    ) -> DecisionSessionEngineImportPreviewPresentation {
        let unfinishedWorkSummary = if preview.unfinishedStepsLine.contains("Open steps 0") {
            DecisionSessionEngineHealthSummary(
                severity: .stable,
                title: "Recovery-safe import",
                detail: preview.unfinishedStepsLine
            )
        } else {
            DecisionSessionEngineHealthSummary(
                severity: .watch,
                title: "Open work will be normalized",
                detail: preview.unfinishedStepsLine
            )
        }

        return DecisionSessionEngineImportPreviewPresentation(
            title: "Import Session Engine bundle",
            headline: preview.headline,
            bundleLine: "Bundle \(sourceFileName)",
            sourceLine: "Source \(preview.sourceTitle)",
            importedLine: "Will import as \(preview.importedTitle)",
            countsLine: preview.countsLine,
            integrityLine: preview.integrityLine,
            checkpointLine: preview.checkpointLine,
            branchLine: preview.branchLine,
            unfinishedWorkSummary: unfinishedWorkSummary,
            detailRows: [
                DecisionSessionEngineReviewDetailPresentation(
                    id: "bundle",
                    label: "Bundle",
                    value: sourceFileName
                ),
                DecisionSessionEngineReviewDetailPresentation(
                    id: "source",
                    label: "Source session",
                    value: preview.sourceTitle
                ),
                DecisionSessionEngineReviewDetailPresentation(
                    id: "imported",
                    label: "Imported title",
                    value: preview.importedTitle
                ),
                DecisionSessionEngineReviewDetailPresentation(
                    id: "counts",
                    label: "Counts",
                    value: preview.countsLine
                ),
                DecisionSessionEngineReviewDetailPresentation(
                    id: "integrity",
                    label: "Integrity",
                    value: preview.integrityLine
                ),
                DecisionSessionEngineReviewDetailPresentation(
                    id: "checkpoint",
                    label: "Checkpoint",
                    value: preview.checkpointLine
                ),
                DecisionSessionEngineReviewDetailPresentation(
                    id: "branch",
                    label: "Branch line",
                    value: preview.branchLine
                )
            ],
            branchPresentations: preview.branchPreviews.map {
                DecisionSessionEngineImportBranchPresentation(
                    id: $0.id,
                    name: $0.name,
                    statusLine: $0.statusLine,
                    detailLine: $0.detailLine,
                    isHead: $0.isHead
                )
            }
        )
    }
}

struct DecisionSessionEngineMergeReviewPresentation: Equatable, Sendable {
    let title: String
    let routeLine: String
    let sourceStatusLine: String
    let targetStatusLine: String
    let checkpointLine: String?
    let summary: DecisionSessionEngineHealthSummary
    let detailRows: [DecisionSessionEngineReviewDetailPresentation]

    static func build(
        from review: DecisionSessionEngineControlMergeReview
    ) -> DecisionSessionEngineMergeReviewPresentation {
        DecisionSessionEngineMergeReviewPresentation(
            title: "Merge review",
            routeLine: "\(review.sourceBranchName) → \(review.targetBranchName)",
            sourceStatusLine: review.sourceStatusLine,
            targetStatusLine: review.targetStatusLine,
            checkpointLine: review.checkpointLine,
            summary: DecisionSessionEngineHealthSummary(
                severity: .stable,
                title: "Append-only merge",
                detail: review.summaryLine
            ),
            detailRows: review.detailRows.map {
                DecisionSessionEngineReviewDetailPresentation(
                    id: $0.id,
                    label: $0.label,
                    value: $0.value
                )
            }
        )
    }
}
