import Foundation

enum StateStorageIssueRecorder {
    private final class Storage: @unchecked Sendable {
        let queue = DispatchQueue(label: "before.state.storage.issue.recorder")
        var latestMessage: String?
    }

    private static let storage = Storage()

    @discardableResult
    static func record(error: Error, operation: String) -> String {
        let message = "Before isolated a local state artifact while \(operation). Recent in-progress state may be reset until storage stabilizes. (\(error.localizedDescription))"
        storage.queue.sync {
            storage.latestMessage = message
        }
        return message
    }

    static func latestNotice() -> String? {
        storage.queue.sync { storage.latestMessage }
    }

    static func clear() {
        storage.queue.sync {
            storage.latestMessage = nil
        }
    }
}
