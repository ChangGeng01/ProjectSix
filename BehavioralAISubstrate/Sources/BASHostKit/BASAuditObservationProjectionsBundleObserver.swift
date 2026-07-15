// MARK: - BASAuditObservationProjectionsBundleObserver
// chapter 五百十二 / M1426 — actor-isolated observer for
//                            projection-block emissions
//
// Sibling of the M1389 BASKernelRoutingDecisionObserver
// pattern。 Records per-turn projection-block observations
// (M1425) in arrival order;snapshot returns an immutable
// copy for audit emission + M1427 BASBundle aggregation。
//
// ## Why this exists
//
// Chapter 511 shipped the projection-block packaging
// surfaces。 Chapter 512 closes the wire-in chain:
//
//   1. M1425 BASAuditObservationProjectionsBundle
//      Observation — per-turn record type
//   2. M1426 (this file) — actor accumulator
//   3. M1427 — BASBundle<Item> typealias adoption
//
// Hosts wanting cross-turn projection-coverage audit
// attach this observer + call `recordEmission(...)` after
// every audit-projection emission。
//
// ## Doctrine pins
//
//   - 不变量 #1/#2/#3:V1 byte-equality preserved
//     (observer is opt-in,no production callers wire it
//     up at chapter 512 close-out — matches M1389 pattern)
//   - 红线 7:additive surface only
//   - chapter 三百九二:replay-determinism via Hashable
//     records + actor-isolated array
//   - chapter 四百二十九:typed-surface count 56 → 57
//   - ADR-014 OPT-IN:default behavior unchanged
//   - ADR-016 advances M1425 → M1426

import Foundation
import BASRuntimeCore

/// Actor-isolated observer accumulating per-turn
/// projection-block emission records。 Pure storage —
/// no side effects,no IO,no derive calls on top of
/// the records callers provide。
public actor BASAuditObservationProjectionsBundleObserver
{

    private var records:
        [BASAuditObservationProjectionsBundleObservation]
        = []

    public init() {}

    /// Test-only stagger hook (audit hostkit-rest MED-5 teeth). When set, each
    /// `recordEmission` awaits this before appending — letting a test force a
    /// per-observation delay so the ordering contract can be exercised
    /// deterministically. `nil` in production ⇒ zero behavior change (no await,
    /// byte-equal). Never wired by any production caller.
    public nonisolated(unsafe) static var
        _recordStaggerForTesting:
        (@Sendable (BASAuditObservationProjectionsBundleObservation)
            async -> Void)?

    // MARK: - Recording

    /// Record an already-built observation。 Callers
    /// build the record via one of the M1425 factory
    /// methods (`.fullyCovered(...)`,`.kunlunOnly(...)`,
    /// etc.) and hand it to this observer。
    public func recordEmission(
        _ observation:
            BASAuditObservationProjectionsBundleObservation
    ) async {
        if let stagger = Self._recordStaggerForTesting {
            await stagger(observation)
        }
        records.append(observation)
    }

    /// Convenience: record a fully-covered emission with
    /// both blocks。 Equivalent to building via M1425's
    /// `.fullyCovered(...)` factory + recording it。
    public func recordFullyCoveredEmission(
        turnID: String,
        sessionID: String,
        emittedAt: Date,
        kunlunInputs:
            BASAuditObservationProjectionsKunlunInputs,
        cthulhuInputs:
            BASAuditObservationProjectionsCthulhuInputs
    ) {
        let obs =
            BASAuditObservationProjectionsBundleObservation
                .fullyCovered(
                    turnID: turnID,
                    sessionID: sessionID,
                    emittedAt: emittedAt,
                    kunlunInputs: kunlunInputs,
                    cthulhuInputs: cthulhuInputs)
        records.append(obs)
    }

    // MARK: - Snapshot accessors

    /// Total emissions recorded since construction (or
    /// last reset)。
    public var emissionCount: Int { records.count }

    /// Count of emissions where both blocks fired。
    /// Useful for "how many turns had full audit-
    /// projection coverage?" rollups。
    public var fullyCoveredCount: Int {
        records.filter(\.hasBothBlocks).count
    }

    /// Count of emissions where neither block fired (host
    /// bypassed both convenience inits)。 Useful for
    /// "how many cold turns?" audits。
    public var coldEmissionCount: Int {
        records.filter(\.hasNoBlocks).count
    }

    /// Fully-covered ratio in [0, 1]。 Zero when no
    /// emissions。
    public var fullyCoveredRatio: Double {
        guard !records.isEmpty else { return 0 }
        return Double(fullyCoveredCount)
            / Double(records.count)
    }

    /// Cumulative populated-block count across all
    /// records (each fullyCovered = +2,each partial =
    /// +1,each uncovered = +0)。 Useful for "did the
    /// projection-block path fire enough?" audits。
    public var cumulativePopulatedBlockCount: Int {
        records.reduce(0) {
            $0 + $1.populatedBlockCount
        }
    }

    /// Distinct turn IDs in the records。 Hosts that
    /// emit one record per turn expect this to equal
    /// `emissionCount`。
    public var distinctTurnCount: Int {
        Set(records.map(\.turnID)).count
    }

    /// Snapshot the current records as an immutable
    /// array for audit emission。 Read-only。
    public func snapshot()
        -> [BASAuditObservationProjectionsBundleObservation]
    {
        return records
    }

    /// Reset observation state。 Useful for tests +
    /// per-session observer instances。
    public func reset() {
        records.removeAll()
    }
}
