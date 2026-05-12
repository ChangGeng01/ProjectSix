// MARK: - BASTurnRuntimeEngineObservationFailureLog
// chapter 五百三十七 / M1525 — typed observability sink
//                              for the 4 documented
//                              silent-swallow paths in
//                              BASTurnRuntimeEngine
//
// Background:BASTurnRuntimeEngine has 4 explicit silent-
// swallow sites,each documented as "audit emission is
// hint-only per 红线 7;failure to emit must not break
// runtime correctness":
//
//   1. biomimetic observer.observe(signal)
//      — engine line 594 (chapter 467 M1246)
//   2. eventLog.append(biomimeticCheckpointEvent)
//      — engine line 629 (chapter 467 M1246)
//   3. log.append(nativeStageDispatchEvent)
//      — engine line 810
//   4. log.append(planAssignmentEvent)
//      — engine line 854 (chapter 四百四十一 M1141)
//
// Per chapter 536 pattern,ship a typed observability
// sink so hosts that want to OBSERVE background-
// emission failures can opt in。 Default behavior
// unchanged (sink nil → swallow continues as docu-
// mented);non-nil → each failed emission records to
// the actor sink with a typed `Kind` discriminator
// identifying which path failed。
//
// ## Doctrine pins
//
//   - 不变量 #1/#2/#3:V1 byte-equality preserved
//     (default behavior unchanged when sink is nil)
//   - 红线 7:additive surface only;commitment path
//     unaffected (errors STILL swallowed for the
//     runtime path — they're just additionally
//     RECORDED for host observation)
//   - chapter 一百八十五:typed enum (Kind) + typed
//     factory
//   - chapter 二百一一:single source-of-truth for
//     engine background-emission failures
//   - chapter 三百九二:replay-determinism via actor-
//     isolated state + Equatable record
//   - chapter 四百二十九:typed-surface count 82 → 83
//   - User error-handling standard:errors NO LONGER
//     silently swallowed when hosts opt in
//   - ADR-014 OPT-IN:default behavior unchanged
//   - ADR-016 advances M1524 → M1525

import Foundation

/// Discriminates which silent-swallow path inside
/// BASTurnRuntimeEngine produced the recorded failure。
public enum BASTurnRuntimeEngineObservationFailureKind:
    String, Codable, Equatable, Hashable, Sendable,
    CaseIterable
{
    /// Biomimetic turn observer's `observe(signal)` call
    /// threw。 Path:engine line ~594 (chapter 467
    /// M1246)。
    case biomimeticObserverObserve

    /// Auto-checkpoint event-log append threw。 Path:
    /// engine line ~629 (chapter 467 M1246)。
    case autoCheckpointEventLogAppend

    /// Native-stage-dispatch event-log append threw。
    /// Path:engine line ~810。
    case nativeStageDispatchEventLogAppend

    /// Plan-assignment event-log append threw。 Path:
    /// engine line ~854 (chapter 四百四十一 M1141)。
    case planAssignmentEventLogAppend
}

/// Typed record of a single engine-side background
/// observability failure。 Captures the path-kind
/// discriminator + a human-readable error message +
/// optional turn/session identifiers for diagnostic
/// inspection by hosts。
public struct BASTurnRuntimeEngineObservationFailureRecord:
    Codable, Sendable, Equatable, Hashable
{
    /// Which silent-swallow path produced the failure。
    public let kind:
        BASTurnRuntimeEngineObservationFailureKind

    /// Human-readable error message via
    /// `String(describing:)` of the thrown error。
    public let errorMessage: String

    /// Optional session identifier (when known at the
    /// failure point)。 Useful for correlating with
    /// other event-log entries。
    public let sessionID: String?

    /// Wall-clock time the failure was recorded。
    public let recordedAt: Date

    public init(
        kind:
            BASTurnRuntimeEngineObservationFailureKind,
        errorMessage: String,
        sessionID: String?,
        recordedAt: Date
    ) {
        self.kind = kind
        self.errorMessage = errorMessage
        self.sessionID = sessionID
        self.recordedAt = recordedAt
    }
}

/// Actor-isolated observability sink for the 4 documented
/// silent-swallow paths in BASTurnRuntimeEngine。 Hosts
/// that want to observe background-emission failures
/// pass an instance to the engine's optional
/// `observationFailureLog:` parameter (chapter 537
/// M1526);hosts that don't care omit the parameter (or
/// pass nil) and behavior is unchanged from the existing
/// `try?` silent-swallow path。
public actor BASTurnRuntimeEngineObservationFailureLog {

    // MARK: - Internal state

    private var records:
        [BASTurnRuntimeEngineObservationFailureRecord]

    /// Optional clock for tests to inject deterministic
    /// timestamps。 Defaults to `Date.init` (system
    /// clock)。
    private let clock: @Sendable () -> Date

    // MARK: - Construction

    public init(
        clock: @escaping @Sendable () -> Date = Date.init
    ) {
        self.records = []
        self.clock = clock
    }

    // MARK: - Recording

    /// Record a single observation failure。 Captures the
    /// path-kind discriminator + the error's
    /// `String(describing:)` representation + optional
    /// session ID at the current clock time。
    public func record(
        kind:
            BASTurnRuntimeEngineObservationFailureKind,
        error: any Error,
        sessionID: String?
    ) {
        let rec =
            BASTurnRuntimeEngineObservationFailureRecord(
                kind: kind,
                errorMessage: String(describing: error),
                sessionID: sessionID,
                recordedAt: clock())
        records.append(rec)
    }

    // MARK: - Snapshot

    /// Returns a chronologically-ordered snapshot of all
    /// recorded failures。 Safe to call concurrently;
    /// each snapshot is an immutable copy。
    public func snapshot()
        -> [BASTurnRuntimeEngineObservationFailureRecord]
    {
        return records
    }

    /// Count of recorded failures。
    public var recordedCount: Int {
        return records.count
    }

    /// Count of recorded failures of a specific kind。
    /// Convenience accessor for hosts that want to
    /// audit per-path frequency。
    public func recordedCount(
        of kind:
            BASTurnRuntimeEngineObservationFailureKind
    ) -> Int {
        return records.filter { $0.kind == kind }
            .count
    }
}
