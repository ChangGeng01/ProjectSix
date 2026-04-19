import Foundation

enum PersistenceIssueSeverity: String, Equatable, Sendable {
    case warning
    case critical
}

enum PersistenceIssueCategory: String, Equatable, Sendable {
    case storage
    case brainBootstrapFallback = "brain_bootstrap_fallback"
}

struct PersistenceIssueRecord: Equatable, Sendable {
    let category: PersistenceIssueCategory
    let severity: PersistenceIssueSeverity
    let operation: String?
    let summary: String
    let detail: String?
    let remediation: String?
    let recordedAt: Date

    var displayMessage: String {
        guard let detail, !detail.isEmpty else {
            return summary
        }

        return "\(summary) (\(detail))"
    }

    var remediationSnapshot: PersistenceRemediationSnapshot {
        PersistenceRemediationSnapshot(
            isDegraded: true,
            category: category,
            severity: severity,
            operation: operation,
            summary: summary,
            detail: detail,
            remediation: remediation,
            recordedAt: recordedAt
        )
    }
}

struct PersistenceRemediationSnapshot: Equatable, Sendable {
    let isDegraded: Bool
    let category: PersistenceIssueCategory
    let severity: PersistenceIssueSeverity
    let operation: String?
    let summary: String
    let detail: String?
    let remediation: String?
    let recordedAt: Date
}

enum PersistenceIssueRecorder {
    private final class Storage: @unchecked Sendable {
        let queue = DispatchQueue(label: "before.persistence.issue.recorder")
        var latestIssue: PersistenceIssueRecord?
        var latestCategoryStreak: Int = 0
    }

    private static let storage = Storage()

    @discardableResult
    static func record(error: Error, operation: String) -> String {
        record(
            category: .storage,
            severity: .warning,
            operation: operation,
            summary: "Before hit a local storage problem while \(operation). Recent state may be temporary until persistence recovers.",
            detail: error.localizedDescription,
            remediation: "Retry the local persistence path and verify the latest state commits cleanly."
        ).displayMessage
    }

    @discardableResult
    static func record(
        category: PersistenceIssueCategory,
        severity: PersistenceIssueSeverity = .warning,
        operation: String? = nil,
        summary: String,
        detail: String? = nil,
        remediation: String? = nil,
        recordedAt: Date = .now
    ) -> PersistenceIssueRecord {
        let issue = PersistenceIssueRecord(
            category: category,
            severity: severity,
            operation: operation,
            summary: summary,
            detail: detail,
            remediation: remediation,
            recordedAt: recordedAt
        )
        storage.queue.sync {
            if storage.latestIssue?.category == category {
                storage.latestCategoryStreak += 1
            } else {
                storage.latestCategoryStreak = 1
            }
            storage.latestIssue = issue
        }
        return issue
    }

    static func currentStreak(for category: PersistenceIssueCategory) -> Int {
        storage.queue.sync {
            guard storage.latestIssue?.category == category else {
                return 0
            }

            return storage.latestCategoryStreak
        }
    }

    static func latestIssue() -> PersistenceIssueRecord? {
        storage.queue.sync { storage.latestIssue }
    }

    static func latestNotice() -> String? {
        latestIssue()?.displayMessage
    }

    static func clear() {
        storage.queue.sync {
            storage.latestIssue = nil
            storage.latestCategoryStreak = 0
        }
    }
}
