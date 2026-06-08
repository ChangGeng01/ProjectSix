// ADR-039 Phase 2 — async→sync bridge for running a Metal dispatch from a SYNC seam (ch883) with a HARD
// timeout + a guaranteed fallback. This is the mechanism that lets the L8 retrieval seam
// (`cosineTopKSync`, which must be synchronous) use the async Metal topK dispatcher.
//
// SAFETY (亏的不要上 / ADR-038): a synchronous Metal eval is UNCANCELLABLE — if it hangs, the timeout lets
// the CALLER proceed (via the fallback) but the GPU eval still leaks its task. That is acceptable ONLY
// here because (1) this is the APPROXIMATE side (retrieval ranking — never the deterministic spine), (2)
// there is a guaranteed CPU/Rust fallback, and (3) the caller is never blocked past the timeout, so the
// verdict path is never gated on Metal. If on-device proof shows the Metal path wedges under this bridge,
// the documented retreat is Rust-only (the fallback alone).

import Foundation

/// A lock-guarded one-shot box so the bridging Task can hand its result back to the waiting sync caller.
public final class BASSyncResultBox<T: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var value: T?
    public init() {}
    public func set(_ x: T?) { lock.lock(); value = x; lock.unlock() }
    public func take() -> T? { lock.lock(); defer { lock.unlock() }; let x = value; value = nil; return x }
}

public enum BASMetalSyncBridge {

    /// Run an async op under a hard timeout from a SYNC context; return its result if it completes in time,
    /// else the fallback. `op` returns `nil` on its own failure (→ fallback). NEVER blocks past
    /// `timeoutMs`. Use ONLY on the approximate side with a real fallback (never the deterministic spine).
    ///
    /// - Returns: `(value, usedFallback)` — `usedFallback == true` when the op failed or timed out.
    @discardableResult
    public static func runWithTimeout<T: Sendable>(
        timeoutMs: Int,
        _ op: @escaping @Sendable () async -> T?,
        fallback: () -> T
    ) -> (value: T, usedFallback: Bool) {
        let sem = DispatchSemaphore(value: 0)
        let box = BASSyncResultBox<T>()
        Task {
            let r = await op()
            box.set(r)
            sem.signal()
        }
        let waited = sem.wait(timeout: .now() + .milliseconds(max(0, timeoutMs)))
        if waited == .success, let v = box.take() {
            return (v, false)   // op completed in time with a non-nil result
        }
        return (fallback(), true)   // timed out, or op returned nil (its own failure)
    }
}
