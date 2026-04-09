import Foundation

enum PersistenceIssueRecorder {
    private final class Storage: @unchecked Sendable {
        let queue = DispatchQueue(label: "before.persistence.issue.recorder")
        var latestMessage: String?
    }

    private static let storage = Storage()

    @discardableResult
    static func record(error: Error, operation: String) -> String {
        let message = "Before hit a local storage problem while \(operation). Recent state may be temporary until persistence recovers. (\(error.localizedDescription))"
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
