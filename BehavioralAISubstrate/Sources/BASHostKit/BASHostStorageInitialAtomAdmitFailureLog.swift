// MARK: - BASHostStorageInitialAtomAdmitFailureLog
// chapter 五百三十六 / M1521 — typed observability sink
//                              for the silent-swallow
//                              paths in
//                              BASHostStorageWireBuilder
//                              .makeAtomStore(...)
//
// Background:chapter 535 / M1517 converted two `try?`
// discards in `BASHostStorageWireBuilder` to explicit
// `do/catch` blocks with documented silent-swallow
// markers。 The error-handling pin
// ("Never silently swallow errors") was honored by
// MAKING the swallow explicit + documented;but the
// errors themselves remained unobservable to hosts。
//
// Chapter 536 / M1521 ships this typed observability
// sink so hosts that want to OBSERVE bootstrap-time
// admission failures can opt in。 The sink is purely
// additive:
//
//   - Pass `nil` (default) → behavior unchanged
//     (silent swallow,as documented since M1517)
//   - Pass a `BASHostStorageInitialAtomAdmitFailureLog`
//     instance → each catch block records the failure
//     for later inspection via `snapshot()`
//
// ## Doctrine pins
//
//   - 不变量 #1/#2/#3:V1 byte-equality preserved
//     (default behavior unchanged when log is nil)
//   - 红线 7:additive surface only
//   - chapter 一百八十五:typed enum + typed factory
//   - chapter 二百一一:single source-of-truth for
//     bootstrap-time admission failures
//   - chapter 三百九二:replay-determinism via actor-
//     isolated state + Equatable record
//   - chapter 四百二十九:typed-surface count 81 → 82
//   - User error-handling standard:errors NO LONGER
//     silently swallowed when hosts opt in
//   - ADR-014 OPT-IN:default behavior unchanged
//   - ADR-016 advances M1520 → M1521

import Foundation

/// Typed record of a single bootstrap-time atom
/// admission failure。 Captures the atom ID + a
/// human-readable error message for diagnostic
/// inspection by hosts。
public struct BASHostStorageInitialAtomAdmitFailureRecord:
    Codable, Sendable, Equatable, Hashable
{
    /// UUID of the `BASGovernedMemory` atom whose
    /// admission failed。
    public let atomID: UUID

    /// Human-readable error message extracted from the
    /// thrown error via `String(describing:)`。
    public let errorMessage: String

    /// Wall-clock time the failure was recorded。
    public let recordedAt: Date

    public init(
        atomID: UUID,
        errorMessage: String,
        recordedAt: Date
    ) {
        self.atomID = atomID
        self.errorMessage = errorMessage
        self.recordedAt = recordedAt
    }
}

/// Actor-isolated observability sink for bootstrap-time
/// atom admission failures。 Hosts that want to observe
/// failures (e.g. for diagnostic logging,test
/// assertions,or surfacing to operators) pass an
/// instance to `BASHostStorageWireBuilder.makeAtomStore
/// (..., failureLog:)`。 Hosts that don't care pass nil
/// (or omit the parameter) and behavior is unchanged
/// from M1517's documented silent-swallow。
public actor BASHostStorageInitialAtomAdmitFailureLog {

    // MARK: - Internal state

    private var records:
        [BASHostStorageInitialAtomAdmitFailureRecord]

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

    /// Record a single admission failure。 Captures the
    /// atom's UUID + the error's `String(describing:)`
    /// representation at the current clock time。
    public func record(
        atomID: UUID,
        error: any Error
    ) {
        let rec =
            BASHostStorageInitialAtomAdmitFailureRecord(
                atomID: atomID,
                errorMessage: String(describing: error),
                recordedAt: clock())
        records.append(rec)
    }

    // MARK: - Snapshot

    /// Returns a chronologically-ordered snapshot of all
    /// recorded failures。 Safe to call concurrently;
    /// each snapshot is an immutable copy。
    public func snapshot()
        -> [BASHostStorageInitialAtomAdmitFailureRecord]
    {
        return records
    }

    /// Count of recorded failures。 Equivalent to
    /// `snapshot().count` but doesn't allocate the
    /// snapshot copy。
    public var recordedCount: Int {
        return records.count
    }
}
