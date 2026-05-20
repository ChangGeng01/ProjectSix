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
        DecisionSessionReviewPresentationSupport.importPreviewPresentation(
            preview: preview,
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
        DecisionSessionReviewPresentationSupport.importPreviewPresentation(
            preview: preview,
            sourceFileName: sourceFileName
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
        DecisionSessionReviewPresentationSupport.mergeReviewPresentation(
            review: review
        )
    }
}
