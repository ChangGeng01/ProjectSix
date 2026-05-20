import Foundation

enum StateStorageIssueRecorder {
    /// Maximum number of recent storage-issue notices kept in the ring buffer.
    /// Chosen to balance debuggability (capture cascading failures) against
    /// memory and privacy (we never want to accumulate unbounded state).
    static let ringBufferCapacity = 5

    private final class Storage: @unchecked Sendable {
        let queue = DispatchQueue(label: "before.state.storage.issue.recorder")
        var recentMessages: [String] = []
    }

    private static let storage = Storage()

    @discardableResult
    static func record(error: Error, operation: String) -> String {
        let message = "Before isolated a local state artifact while \(operation). Recent in-progress state may be reset until storage stabilizes. (\(error.localizedDescription))"
        storage.queue.sync {
            storage.recentMessages.append(message)
            if storage.recentMessages.count > ringBufferCapacity {
                let overflow = storage.recentMessages.count - ringBufferCapacity
                storage.recentMessages.removeFirst(overflow)
            }
        }
        return message
    }

    /// Most recent notice, or `nil` if no issue has been recorded since the
    /// last `clear()`. Kept for API compatibility with single-message callers.
    static func latestNotice() -> String? {
        storage.queue.sync { storage.recentMessages.last }
    }

    /// Up to `ringBufferCapacity` most-recent notices in chronological order
    /// (oldest first, newest last). Useful for diagnosing cascading failures.
    static func recentNotices() -> [String] {
        storage.queue.sync { storage.recentMessages }
    }

    static func clear() {
        storage.queue.sync {
            storage.recentMessages.removeAll(keepingCapacity: false)
        }
    }
}
