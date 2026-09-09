import Foundation
import BASOrgan

/// Owns only this request. The session retains its task delegate, so cleanup lives
/// in this independent owner, not in a receiver ↔ task retain cycle.
final class BoundedChatResponse: @unchecked Sendable {
    private let receiver: Receiver
    private let task: URLSessionDataTask

    init(session: URLSession, request: URLRequest, cap: Int, deadline: Date?, streaming: Bool) throws {
        // Foundation does not support per-task delegates on background sessions.
        guard session.configuration.identifier == nil else {
            throw BASOrganError.providerUnavailable(reason: "transport:background-session-unsupported")
        }
        receiver = Receiver(cap: cap, deadline: deadline, streaming: streaming)
        task = session.dataTask(with: request)
        task.delegate = receiver // Must be installed before resume.
        receiver.start(task)
    }

    deinit { receiver.fail(CancellationError()) }
    func cancel() { receiver.fail(CancellationError()) }
    func check() throws { try receiver.check() }
    func finish() throws { try receiver.finish() }

    func collect() async throws -> Data {
        try await withTaskCancellationHandler {
            while true {
                try Task.checkCancellation()
                if let data = try receiver.collected() { return data }
                await receiver.changed()
            }
        } onCancel: { self.cancel() }
    }

    struct Bytes: AsyncSequence, Sendable {
        typealias Element = UInt8
        let owner: BoundedChatResponse
        struct AsyncIterator: AsyncIteratorProtocol {
            let owner: BoundedChatResponse
            mutating func next() async throws -> UInt8? { try await owner.nextByte() }
        }
        func makeAsyncIterator() -> AsyncIterator { AsyncIterator(owner: owner) }
    }
    var bytes: Bytes { Bytes(owner: self) }

    private func nextByte() async throws -> UInt8? {
        try await withTaskCancellationHandler {
            while true {
                try Task.checkCancellation()
                let result = try receiver.byte()
                if result.ready { return result.value }
                await receiver.changed()
            }
        } onCancel: { self.cancel() }
    }

    /// All callback state is protected by one lock. Data is charged synchronously
    /// before retention: no actor hop, per-chunk Task, or unbounded stream queue.
    private final class Receiver: NSObject, URLSessionDataDelegate, @unchecked Sendable {
        private let lock = NSLock()
        private let cap: Int
        private let deadline: Date?
        private let streaming: Bool
        private var data = Data()
        private var cursor = 0
        private var receivedHeaders = false
        private var networkComplete = false
        private var transferError: Error?
        private var failure: Error?
        private var delivered = false
        private var waiter: CheckedContinuation<Void, Never>?
        private weak var task: URLSessionDataTask?
        private var timer: DispatchWorkItem?

        init(cap: Int, deadline: Date?, streaming: Bool) {
            self.cap = cap; self.deadline = deadline; self.streaming = streaming
        }

        func start(_ task: URLSessionDataTask) {
            let timer = deadline.map { _ in DispatchWorkItem { [weak self] in self?.fail(BASOrganError.deadlineExpired) } }
            lock.withLock { self.task = task; self.timer = timer }
            if let deadline, let timer {
                DispatchQueue.global().asyncAfter(deadline: .now() + max(0, deadline.timeIntervalSinceNow), execute: timer)
            }
            task.resume()
        }

        // Returns effects to perform after unlocking; never calls Foundation or
        // resumes a continuation while holding the state lock.
        private func failLocked(_ error: Error) -> (CheckedContinuation<Void, Never>?, URLSessionDataTask?, DispatchWorkItem?) {
            guard failure == nil, !delivered else { return (nil, nil, nil) }
            failure = error
            let pending = waiter; waiter = nil
            return (pending, task, timer)
        }
        func fail(_ error: Error) {
            let effects = lock.withLock { failLocked(error) }
            effects.2?.cancel(); effects.0?.resume(); effects.1?.cancel()
        }
        private func expireIfNeeded() {
            if let deadline, deadline <= Date() { fail(BASOrganError.deadlineExpired) }
        }
        func check() throws {
            expireIfNeeded()
            try lock.withLock { if let failure { throw failure } }
        }
        func finish() throws {
            expireIfNeeded()
            let effects = try lock.withLock {
                if let failure { throw failure }
                delivered = true
                let pending = waiter; waiter = nil
                return (pending, task, timer)
            }
            effects.2?.cancel(); effects.0?.resume(); effects.1?.cancel()
        }

        func collected() throws -> Data? {
            try check()
            return try lock.withLock {
                if let failure { throw failure }
                guard networkComplete else { return nil }
                if let transferError { throw transferError }
                return data
            }
        }
        func byte() throws -> (ready: Bool, value: UInt8?) {
            try check()
            return try lock.withLock {
                if let failure { throw failure }
                if cursor < data.count {
                    let value = data[cursor]; cursor += 1
                    return (true, value)
                }
                if let transferError { throw transferError }
                return (networkComplete || delivered, nil)
            }
        }
        func changed() async {
            await withCheckedContinuation { continuation in
                let resumeNow = lock.withLock {
                    // Recheck under the registration lock: a callback/cancel can
                    // win between the caller's state probe and this registration.
                    if failure != nil || delivered || networkComplete || (streaming && cursor < data.count) { return true }
                    waiter = continuation
                    return false
                }
                if resumeNow { continuation.resume() }
            }
        }

        func urlSession(_ session: URLSession, dataTask: URLSessionDataTask,
                        didReceive response: URLResponse,
                        completionHandler: @escaping @Sendable (URLSession.ResponseDisposition) -> Void) {
            expireIfNeeded()
            let effects = lock.withLock { () -> (Bool, CheckedContinuation<Void, Never>?, URLSessionDataTask?, DispatchWorkItem?) in
                if failure != nil || delivered { return (false, nil, nil, nil) }
                let error: Error?
                if let http = response as? HTTPURLResponse {
                    error = (200..<300).contains(http.statusCode) ? nil
                        : BASOrganError.providerUnavailable(reason: "http-\(http.statusCode)")
                } else { error = BASOrganError.providerUnavailable(reason: "non-http-response") }
                if let error {
                    let effects = failLocked(error)
                    return (false, effects.0, effects.1, effects.2)
                }
                receivedHeaders = true
                return (true, nil, nil, nil)
            }
            completionHandler(effects.0 ? .allow : .cancel)
            effects.3?.cancel(); effects.1?.resume(); effects.2?.cancel()
        }
        func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive chunk: Data) {
            expireIfNeeded()
            let effects = lock.withLock { () -> (CheckedContinuation<Void, Never>?, URLSessionDataTask?, DispatchWorkItem?) in
                guard failure == nil, !delivered else { return (nil, nil, nil) }
                guard chunk.count <= cap - data.count else {
                    return failLocked(BASOrganError.providerUnavailable(reason: "response-too-large:raw>\(cap)"))
                }
                data.append(chunk)
                let pending = waiter; waiter = nil
                return (pending, nil, nil)
            }
            effects.2?.cancel(); effects.0?.resume(); effects.1?.cancel()
        }
        func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
            let pending = lock.withLock {
                networkComplete = true
                if let error, failure == nil, !delivered {
                    transferError = (!streaming || !receivedHeaders)
                        ? BASOrganError.providerUnavailable(reason: "transport:\(error.localizedDescription)") : error
                }
                let pending = waiter; waiter = nil
                return pending
            }
            pending?.resume()
            // Network EOF is not final delivery: the absolute deadline remains
            // active while a consumer is paused over buffered bytes.
        }
    }
}
