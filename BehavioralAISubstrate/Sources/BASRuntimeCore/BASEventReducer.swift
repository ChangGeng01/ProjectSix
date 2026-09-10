// MARK: - BASEventReducer — chapter 四百三 / M955 — 系统熵 reduction
//
// Phase 2 entropy 第三刀:typed protocol formalizing the shared
// `(State, Event) -> State?` shape that existing reducers already
// implement informally and that `BASEventReplayRunner.replay(...)`
// already requires。
//
// ## Why this exists (system entropy framing)
//
// Per the chapter 四百三 entropy audit:
//
//   - **Reducer shape entropy**: existing reducers (M842
//     BASUserStateReducer,M942 BASMemoryAtomReducer) each
//     declare their own static fold method。Shapes overlap
//     (each takes `prior + event → next`),but the protocol
//     convention is implicit。
//   - **Convention drift**: M942 mirrored M842's shape by
//     copying M842's pattern。If a future reducer copies
//     incorrectly,the drift only surfaces at
//     BASEventReplayRunner.replay call sites that pass it as
//     a closure。
//
// `BASEventReducer<State>` formalizes the convention as a typed
// protocol so:
//
//   1. Future reducers conform explicitly (compile-time pin)
//   2. The static-function version still works for legacy
//      callers (additive,not replacement)
//   3. Doctrine guard tests can verify uniform replay-determinism
//
// Conformance for individual reducers (e.g. M942
// `BASMemoryAtomReducer`) lives in their owning modules to keep
// the BASRuntimeCore → BASMemory dep direction acyclic。
//
// ## What this ships (M955)
//
//   - `BASEventReducer` protocol with `associatedtype State: Sendable`
//     and `static func reduceStep(prior:event:) -> State?`
//   - Replay adapter helper `BASEventReducer.replayAdapter`
//     producing the `@Sendable (State, BASEventLogEntry) ->
//     State?` closure that `BASEventReplayRunner.replay(...)`
//     expects
//
// ## Doctrine pins held
//
//   - 不变量 #1 / #2 / #3 — protocol is observation plumbing
//   - chapter 一百八十五 anti-magic-number — protocol shape
//     pinned as typed contract,not free-form
//   - chapter 二百一一 single-source-of-truth — ONE protocol
//     for the (State, Event) -> State? pattern
//   - chapter 三百九二 (M892) replay-determinism — protocol
//     conformers MUST be pure functions (same inputs → same
//     output);test class pins this
//   - ADR-014 OPT-IN — purely additive,no existing reducer
//     surface changes

import Foundation

// MARK: - Protocol

/// Typed contract for event reducers: a pure function from
/// `(prior: State, event: BASEventLogEntry)` to next state or
/// nil (event-skip)。
///
/// **Required invariants** (chapter 三百九二 replay-determinism):
///
///   - **Purity**: `reduceStep(prior: A, event: E)` always
///     produces the same output given the same `(A, E)` pair。
///     No internal mutable state。No `Date()` / `UUID()`
///     calls inside the reducer body — those must be supplied
///     via `event.timestampMs` / `event.eventID` already pinned。
///   - **Skip semantics**: returning `nil` signals "this event
///     is not for me"。`BASEventReplayRunner.replay(...)` counts
///     skipped events but leaves state unchanged。
///   - **Append-style**: returning a value treats it as the
///     next state。Reducers must NOT mutate `prior`(the
///     `prior` is `let`-bound by callers anyway,but conformance
///     should never depend on identity)。
public protocol BASEventReducer: Sendable {

    /// The state type this reducer projects events into。
    associatedtype State: Sendable

    /// Pure-function step。Returns next state on apply,or nil
    /// to skip。
    static func reduceStep(
        prior: State,
        event: BASEventLogEntry
    ) -> State?
}

// MARK: - Replay adapter

extension BASEventReducer {

    /// Produce the `@Sendable (State, BASEventLogEntry) -> State?`
    /// closure that `BASEventReplayRunner.replay(...)` consumes。
    /// Conformers don't have to define this — the default
    /// captures `Self.reduceStep` directly。
    public static var replayAdapter:
        @Sendable (State, BASEventLogEntry) -> State?
    {
        { prior, event in
            Self.reduceStep(prior: prior, event: event)
        }
    }
}
