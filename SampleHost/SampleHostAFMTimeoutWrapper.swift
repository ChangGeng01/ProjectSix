// MARK: - SampleHostAFMTimeoutWrapper — chapter 三百四二 / M829
//
// Closes the chapter 三百四一 / M828 commit's backlog item:
// `afmBenchAFMTimeoutSec` UI setting was declared but inert until
// plumbed via a `withTimeout(...)` wrapper around the AFM call。
//
// This file ships the canonical `withTimeout` helper + typed
// `AFMTimeoutError` that lets bench loops + future hosts wrap any
// async AFM call (`LanguageModelSession.respond(to:)`) with a
// per-call deadline。
//
// Doctrine pins:
//   - 不变量 #1 / #2 / #3 全保 — pure async helper,no decision
//     path mutation
//   - 红线 7 watcher hint only — caller decides what to do with
//     timeout error (skip / retry / record-as-failure)
//   - 单提交口 (L11/L14) 不变 — AFM body produced under timeout
//     still goes through substrate permit/verdict path normally
//   - chapter 三百四一 (M828) doctrine note: AFM timeout
//     enforcement is the honest backlog item — this chapter
//     closes it
//
// Implementation pattern: `withThrowingTaskGroup` with two child
// tasks (operation + sleep timer)。First-completing wins,other
// gets cancelled。Standard Swift concurrency timeout idiom。

import Foundation

/// Typed error thrown when an async operation wrapped by
/// `withTimeout` exceeds its deadline。Caller catches this to
/// distinguish timeout from operation-side errors。
public struct AFMTimeoutError: Error, Equatable, Sendable {
    public let timeoutSeconds: TimeInterval
    public init(timeoutSeconds: TimeInterval) {
        self.timeoutSeconds = timeoutSeconds
    }
}

/// Run an async operation with a wall-clock timeout。If the
/// operation completes first,its result is returned。If the
/// timeout fires first,the operation is cancelled and
/// `AFMTimeoutError` is thrown。
///
/// **Cancellation contract**:Apple's `LanguageModelSession
/// .respond(to:)` honors `Task.cancel()` — cooperative cancellation
/// at the next `await` point inside the AFM stack。Result:on
/// timeout,the AFM session is told to stop generating and the
/// caller catches `AFMTimeoutError`。
///
/// **Doctrine pins**:
///   - First-finisher wins via `group.next()` then `cancelAll()`
///   - Sleep is itself a `Task.sleep` which is cancellation-safe
///   - Generic over Sendable T so callers wrap any return type
///
/// - Parameters:
///   - seconds: timeout deadline in seconds (must be > 0;
///     callers should clamp before passing)
///   - operation: the async work to run with the deadline
/// - Returns: operation's result if it completes first
/// - Throws: `AFMTimeoutError` if the deadline fires first;
///   re-throws operation's error otherwise
public func withTimeout<T: Sendable>(
    seconds: TimeInterval,
    operation: @escaping @Sendable () async throws -> T
) async throws -> T {
    let deadline = max(0.001, seconds)
    return try await withThrowingTaskGroup(
        of: T.self
    ) { group in
        group.addTask {
            try await operation()
        }
        group.addTask {
            try await Task.sleep(
                nanoseconds: UInt64(deadline * 1_000_000_000))
            throw AFMTimeoutError(
                timeoutSeconds: deadline)
        }
        // First child to complete (whether operation result or
        // timeout error) is the result we surface。Cancel the
        // remaining child either way to free its resources。
        guard let result = try await group.next() else {
            // Should be unreachable — group.next() returns nil
            // only after all tasks finish,but we await it
            // before that。Defensive throw。
            throw AFMTimeoutError(
                timeoutSeconds: deadline)
        }
        group.cancelAll()
        return result
    }
}
