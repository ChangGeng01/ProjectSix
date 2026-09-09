import Foundation

final class BASEventLogTestClock: @unchecked Sendable {
    private let lock = NSLock()
    private var value: Int64

    init(_ value: Int64) { self.value = value }

    func now() -> Int64 {
        lock.withLock { value }
    }

    func set(_ newValue: Int64) {
        lock.withLock { value = newValue }
    }

    func advance(by delta: Int64) {
        lock.withLock { value += delta }
    }
}
