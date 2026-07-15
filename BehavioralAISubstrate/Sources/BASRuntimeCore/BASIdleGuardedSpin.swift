import Foundation

/// audit M-i MED-2 / device-recon id5 — the lock-screen-surviving cooldown spin,
/// extracted from the iOS-only DeviceTestApp into a pure, macOS-unit-testable form
/// with an INJECTABLE clock.
///
/// The probe cooldown keeps the process schedulable across a locked screen with a
/// ~1-e-core busy spin (the GPU still rests). The spin must bound its own duration
/// on a MONOTONIC clock: the original inline loop bounded on wall-clock `Date()`,
/// so a backward NTP/DST correction during the spin could stall it past its
/// deadline, and a forward jump could cut a cooldown short. `DispatchTime`'s
/// uptime nanoseconds are immune. Injecting the clock lets the termination be
/// verified deterministically on any Mac (the actual thermal rest is device-only).
public enum BASIdleGuardedSpin {

    /// Busy-spin until `nowNs()` reaches `nowNs()_start + seconds`, on the caller's
    /// monotonic nanosecond clock. Returns the iteration count (for tests); `0`
    /// for a non-positive duration. Callers pass
    /// `{ DispatchTime.now().uptimeNanoseconds }` in production.
    @discardableResult
    public static func spin(seconds: Double, nowNs: () -> UInt64) -> Int {
        guard seconds > 0 else { return 0 }
        let endNs = nowNs() &+ UInt64(seconds * 1_000_000_000)
        var x = 1.0
        var iters = 0
        while nowNs() < endNs {
            x = sin(x) + 1.000001
            iters += 1
        }
        // Defeat dead-code elimination of the spin body (x is otherwise unused).
        if x == .infinity { return -1 }
        return iters
    }
}
