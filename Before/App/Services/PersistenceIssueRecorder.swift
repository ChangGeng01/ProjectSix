import Foundation

enum PersistenceIssueRecorder {
    private static let queue = DispatchQueue(label: "before.persistence.issue.recorder")
    nonisolated(unsafe) private static var latestMessage: String?

    @discardableResult
    static func record(error: Error, operation: String) -> String {
        let message = "Before hit a local storage problem while \(operation). Recent state may be temporary until persistence recovers. (\(error.localizedDescription))"
        queue.sync {
            latestMessage = message
        }
        return message
    }

    static func latestNotice() -> String? {
        queue.sync { latestMessage }
    }

    static func clear() {
        queue.sync {
            latestMessage = nil
        }
    }
}
