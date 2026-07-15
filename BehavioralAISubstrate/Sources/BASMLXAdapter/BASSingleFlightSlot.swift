// MARK: - BASSingleFlightSlot — generic in-flight coalescing (gaps-reconciliation MED-8, 2026-07-11)
//
// The cold-start concurrent double-build class: two turns race past a nil cache and BOTH run an
// expensive build (for the MTP decoder: ~300MB quantize each — a transient ~600MB overlap near the
// jetsam ceiling — plus a last-writer-wins publish that clobbers the other's EMA continuity). This
// slot coalesces them: the FIRST caller installs one build task; every concurrent caller awaits the
// SAME task; an error propagates to all waiters and clears the slot so the next call retries fresh.
// CACHING remains the caller's job (check your cache BEFORE run(); publish after) — the slot only
// guarantees at-most-one build IN FLIGHT. Mac-testable by construction (the control flow is generic;
// the MTP payoff itself is device-runtime-observable, per the reconciliation adjudication).

import Foundation

actor BASSingleFlightSlot<Value: Sendable> {
    private var inFlight: Task<Value, Error>?

    /// Run `build` unless one is already in flight — then await THAT one instead.
    func run(_ build: @escaping @Sendable () async throws -> Value) async throws -> Value {
        if let existing = inFlight {
            return try await existing.value
        }
        let task = Task { try await build() }
        inFlight = task
        defer { inFlight = nil }   // installer clears on completion; awaiters hold their reference
        return try await task.value
    }
}
