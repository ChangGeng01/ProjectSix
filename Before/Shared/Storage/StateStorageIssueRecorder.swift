import Foundation

enum StateStorageIssueRecorder {
    private static let queue = DispatchQueue(label: "before.state.storage.issue.recorder")
    nonisolated(unsafe) private static var latestMessage: String?

    @discardableResult
    static func record(error: Error, operation: String) -> String {
        let message = "Before isolated a local state artifact while \(operation). Recent in-progress state may be reset until storage stabilizes. (\(error.localizedDescription))"
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
