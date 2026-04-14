import Foundation

struct DecisionSessionEngineReviewDigestLine: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let detail: String
    let severity: DecisionSessionEngineHealthSeverity
}

enum DecisionSessionEngineReviewDigestBuilder {
    static func build(
        from summary: DecisionSystemSessionEngineSummary
    ) -> [DecisionSessionEngineReviewDigestLine] {
        var items: [DecisionSessionEngineReviewDigestLine] = []

        if let pendingImportPreview = summary.pendingImportPreview {
            items.append(
                DecisionSessionEngineReviewDigestLine(
                    id: "pending-import",
                    title: "Pending import draft",
                    detail: "\(pendingImportPreview.importedLine) • \(pendingImportPreview.bundleLine)",
                    severity: pendingImportPreview.unfinishedWorkSummary.severity
                )
            )
        }

        if summary.mergeableBranches > 0 {
            items.append(
                DecisionSessionEngineReviewDigestLine(
                    id: "merge-review",
                    title: "Merge review queue",
                    detail: "Merge-ready sessions \(summary.mergeReadySessions) • Merge-ready branches \(summary.mergeableBranches) • Review correction branches before they drift from head.",
                    severity: .watch
                )
            )
        }

        let replayableSessions = summary.recentSessions.filter { $0.latestCheckpointID != nil }
        if let anchorSession = replayableSessions.first,
           let checkpointID = anchorSession.latestCheckpointID {
            items.append(
                DecisionSessionEngineReviewDigestLine(
                    id: "replay-anchor",
                    title: "Replay anchor ready",
                    detail: "\(anchorSession.title) • Checkpoint \(checkpointID) remains available for rebuild and recovery branch creation.",
                    severity: .stable
                )
            )
        }

        return items
    }
}
