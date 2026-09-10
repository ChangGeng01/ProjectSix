// MARK: - BASAuditEmissionFailureLog
// chapter 五百三十九 / M1533 — typed observability sink
//                              for the remaining audit-
//                              emission silent-swallow
//                              paths in BASHostKit +
//                              BASSovereign
//
// Background:chapters 536-537 shipped typed observability
// sinks for documented silent-swallow paths in
// BASHostStorageWireBuilder (chapter 536) and
// BASTurnRuntimeEngine (chapter 537)。 Both sinks live
// in BASHostKit。
//
// Two additional documented silent-swallow paths remain:
//
//   1. BASEventLogStorage.appendTurnEnvelope(...) in
//      BASHostKit (chapter 304 / file
//      BASEventLogEntry+TurnEnvelope.swift line ~78)
//      — fire-and-forget turn envelope append
//   2. BASSovereignCleanRebootCoordinator's reboot plan
//      audit append in BASSovereign (line ~237)
//      — best-effort audit trail for reboot plans
//
// Both paths span MULTIPLE MODULES。 The first is in
// BASHostKit;the second is in BASSovereign,which only
// depends on BASRuntimeCore (not BASHostKit)。 To make
// the typed sink usable from both,it ships in
// BASRuntimeCore — the substrate's lowest non-Foundation
// layer。
//
// ## Doctrine pins
//
//   - 不变量 #1/#2/#3:V1 byte-equality preserved
//     (default behavior unchanged when sink is nil)
//   - 红线 7:additive surface only;commitment path
//     unaffected (errors STILL swallowed for the runtime
//     contract — they're just additionally RECORDED for
//     host observation)
//   - chapter 一百八十五:typed enum (Kind) + typed
//     factory
//   - chapter 二百一一:single source-of-truth for
//     cross-module audit-emission failures
//   - chapter 三百九二:replay-determinism via actor-
//     isolated state + Equatable record
//   - chapter 四百二十九:typed-surface count 84 → 85
//   - User error-handling standard:errors NO LONGER
//     silently swallowed when hosts opt in
//   - ADR-014 OPT-IN:default behavior unchanged
//   - ADR-016 advances M1532 → M1533

import Foundation

/// Discriminates which audit-emission silent-swallow path
/// produced the recorded failure。
public enum BASAuditEmissionFailureKind:
    String, Codable, Equatable, Hashable, Sendable,
    CaseIterable
{
    /// `BASEventLogStorage.appendTurnEnvelope(...)`
    /// append threw。 Path:BASHostKit
    /// BASEventLogEntry+TurnEnvelope.swift line ~78。
    /// Per chapter 304 fire-and-forget contract,errors
    /// are dropped — this sink lets hosts observe them
    /// when wired。
    case turnEnvelopeAppend

    /// `BASSovereignCleanRebootCoordinator`'s reboot
    /// plan audit ledger append threw。 Path:
    /// BASSovereign BASSovereignCleanRebootCoordinator
    /// .swift line ~237。 Per the coordinator's
    /// best-effort audit-trail contract,errors are
    /// dropped — this sink lets hosts observe them when
    /// wired。
    case sovereignRebootAuditAppend
}

/// Typed record of a single audit-emission failure。
/// Captures the path-kind discriminator + a human-readable
/// error message + optional turn/session identifiers for
/// diagnostic inspection by hosts。
public struct BASAuditEmissionFailureRecord:
    Codable, Sendable, Equatable, Hashable
{
    /// Which silent-swallow path produced the failure。
    public let kind: BASAuditEmissionFailureKind

    /// Human-readable error message via
    /// `String(describing:)` of the thrown error。
    public let errorMessage: String

    /// Optional turn identifier (when known at the
    /// failure point — used for correlation with
    /// other event-log entries)。
    public let turnID: String?

    /// Optional session identifier (when known at the
    /// failure point)。
    public let sessionID: String?

    /// Wall-clock time the failure was recorded。
    public let recordedAt: Date

    public init(
        kind: BASAuditEmissionFailureKind,
        errorMessage: String,
        turnID: String?,
        sessionID: String?,
        recordedAt: Date
    ) {
        self.kind = kind
        self.errorMessage = errorMessage
        self.turnID = turnID
        self.sessionID = sessionID
        self.recordedAt = recordedAt
    }
}

/// Actor-isolated cross-module observability sink for
/// the 2 documented audit-emission silent-swallow paths
/// in BASHostKit + BASSovereign。 Lives in
/// BASRuntimeCore so both modules can opt in。
///
/// Hosts pass an instance to:
///   - `BASEventLogStorage.appendTurnEnvelope(...,`
///     `failureLog:)` (BASHostKit wire-in,M1534)
///   - `BASSovereignCleanRebootCoordinator.init(...,`
///     `auditFailureLog:)` (BASSovereign wire-in,M1534)
///
/// Hosts that don't care omit the parameter (or pass
/// nil) and behavior is unchanged from the existing
/// `try?` silent-swallow path。
public actor BASAuditEmissionFailureLog {

    // MARK: - Internal state

    private var records:
        [BASAuditEmissionFailureRecord]

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

    /// Record a single audit-emission failure。 Captures
    /// the path-kind discriminator + the error's
    /// `String(describing:)` representation + optional
    /// turn/session IDs at the current clock time。
    public func record(
        kind: BASAuditEmissionFailureKind,
        error: any Error,
        turnID: String?,
        sessionID: String?
    ) {
        let rec = BASAuditEmissionFailureRecord(
            kind: kind,
            errorMessage: String(describing: error),
            turnID: turnID,
            sessionID: sessionID,
            recordedAt: clock())
        records.append(rec)
    }

    // MARK: - Snapshot

    /// Returns a chronologically-ordered snapshot of all
    /// recorded failures。 Safe to call concurrently;
    /// each snapshot is an immutable copy。
    public func snapshot()
        -> [BASAuditEmissionFailureRecord]
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
        of kind: BASAuditEmissionFailureKind
    ) -> Int {
        return records.filter { $0.kind == kind }
            .count
    }
}
