// MARK: - BASSingleDriverTripwire
//
// audit x-concurrency §三① — a DEBUG-only single-driver tripwire for the stateful CoreAI decode
// sessions (BASCoreAIDecodeSession et al.). Those sessions are `@unchecked Sendable` on the
// documented-but-UNENFORCED contract "driven ONLY on a single serialized executor (never
// concurrently)". A second concurrent driver would corrupt the in-place fused KV state with no
// signal. This tripwire turns that latent contract into a loud DEBUG failure: each driver entry
// increments an in-flight counter under a lock, and any entry that observes an already-in-flight
// driver fires the (swappable) violation handler.
//
// Foundation-only + toolchain-agnostic on purpose: the CoreAI sessions compile only under Xcode 27
// (`#if canImport(CoreAI)`), but this utility must compile and UNIT-TEST on any host so the guard
// logic itself has real teeth. The session-side install is `#if DEBUG` (zero-cost in release).

import Foundation

/// A reentrancy / concurrency tripwire for types whose soundness rests on a "single serialized
/// driver" contract. `enter()`/`exit()` bracket each drive; a nested or concurrent `enter()` (one
/// that sees the in-flight count already > 0) fires `onViolation`. Reference type so one instance
/// is shared by all callers of the guarded object.
public final class BASSingleDriverTripwire: @unchecked Sendable {

    private let lock = NSLock()
    private var inFlight = 0
    private let label: String
    private let onViolation: @Sendable (_ label: String, _ inFlight: Int) -> Void

    /// - Parameters:
    ///   - label: identifies the guarded object in the violation message.
    ///   - onViolation: invoked (OUTSIDE the lock) whenever an entry observes a concurrent driver.
    ///     Defaults to `assertionFailure` — a loud DEBUG crash. Tests inject a recording closure.
    public init(
        label: String,
        onViolation: @escaping @Sendable (_ label: String, _ inFlight: Int) -> Void = { label, n in
            assertionFailure(
                "BASSingleDriverTripwire: concurrent driver detected on \(label) (inFlight=\(n)) — "
                + "this type must be driven on a single serialized executor")
        }
    ) {
        self.label = label
        self.onViolation = onViolation
    }

    /// Mark the start of a drive. Fires `onViolation` if another driver is already in flight.
    public func enter() {
        lock.lock()
        inFlight += 1
        let n = inFlight
        lock.unlock()
        if n > 1 { onViolation(label, n) }
    }

    /// Mark the end of a drive.
    public func exit() {
        lock.lock()
        if inFlight > 0 { inFlight -= 1 }
        lock.unlock()
    }

    /// Current in-flight driver count (for tests / diagnostics).
    public var inFlightCount: Int {
        lock.lock(); defer { lock.unlock() }
        return inFlight
    }
}
