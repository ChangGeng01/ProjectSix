// MARK: - BASEBrainHostRuntimeModeAdvisoryLedger
// chapter 五百三 / M1391 — actor-isolated ledger that
// accumulates per-host runtime-mode advisories over time
//
// REAL CONSUMPTION of chapter 498 typed surfaces:
//   - M1370 BASEBrainHostRuntimeModeAdvisory — typed
//     advisory record
//   - M1370 BASEBrainHostRuntimeModeAdvisoryDoctrine —
//     honor-policy contract
//
// Hosts call `record(advisory:)` to append a typed
// advisory record to the ledger。 The ledger preserves
// arrival order + exposes typed aggregates:
//   - distinctHostCount
//   - honoredAdvisoryCount + unhonoredAdvisoryCount
//   - latestAdvisory(for hostID:)
//   - allAdvisories()
//
// HONEST SCOPE — chapter 五百三:
// =============================================================
// The ledger is OPT-IN observability — substrate doesn't
// route based on its contents at chapter 503 close-out
// (preserves M1370 advisoryHonoredInProduction = false
// invariant)。 Hosts opt-in by constructing a ledger +
// recording advisories before/after each turn for audit
// emission and replay-determinism evidence。
//
// V1 byte-equality preserved — ledger is purely additive
// observation。

import Foundation

/// Actor-isolated ledger of host runtime-mode advisories。
public actor BASEBrainHostRuntimeModeAdvisoryLedger {

    /// gaps-reconciliation hostkit-rest LOW-4 (2026-07-11): the stored array grew UNBOUNDED
    /// (manual reset only) — a long-lived host session leaked memory linearly in advisory count.
    /// The stored DETAIL surface is now a drop-oldest ring capped at `maxStoredAdvisories`
    /// (default 4096; pass nil for the unbounded replay-test mode), with `droppedAdvisoryCount`
    /// auditing every eviction. The AGGREGATES (total/honored/unhonored/ratio) are running
    /// counters that never drop — capping the ring must not skew the honesty metrics.
    private var advisories:
        [BASEBrainHostRuntimeModeAdvisory] = []
    private let maxStoredAdvisories: Int?
    private var _droppedAdvisoryCount = 0
    private var _totalAdvisoryCount = 0
    private var _honoredAdvisoryCount = 0
    private var knownHostIDs: Set<String> = []

    public init(maxStoredAdvisories: Int? = 4096) {
        self.maxStoredAdvisories = maxStoredAdvisories
    }

    /// Record an advisory。 Order-preserving append (drop-oldest past the cap)。
    public func record(
        advisory: BASEBrainHostRuntimeModeAdvisory
    ) {
        _totalAdvisoryCount += 1
        if advisory.wasHonored { _honoredAdvisoryCount += 1 }
        knownHostIDs.insert(advisory.hostID)
        advisories.append(advisory)
        if let cap = maxStoredAdvisories, advisories.count > cap {
            let overflow = advisories.count - cap
            advisories.removeFirst(overflow)
            _droppedAdvisoryCount += overflow
        }
    }

    /// Advisories evicted from the stored ring (aggregates unaffected)。
    public var droppedAdvisoryCount: Int { _droppedAdvisoryCount }

    /// Convenience that constructs the advisory via
    /// BASEBrainHostRuntimeModeAdvisoryDoctrine.advisory
    /// For(...) then records it。
    public func record(
        preferredMode: BASTurnRuntimeMode,
        hostID: String,
        recordedAtMs: Int64
    ) {
        let advisory =
            BASEBrainHostRuntimeModeAdvisoryDoctrine
                .advisoryFor(
                    preferredMode: preferredMode,
                    hostID: hostID,
                    recordedAtMs: recordedAtMs)
        record(advisory: advisory)
    }

    // MARK: - Read accessors

    /// Total advisories recorded since construction (running counter — survives ring drops)。
    public var totalAdvisoryCount: Int {
        _totalAdvisoryCount
    }

    /// Distinct host IDs that have recorded an advisory (survives ring drops;bounded by the
    /// real host population, not advisory volume)。
    public var distinctHostCount: Int {
        knownHostIDs.count
    }

    /// Count of advisories the substrate HONORED at the
    /// time of recording。
    public var honoredAdvisoryCount: Int {
        _honoredAdvisoryCount
    }

    /// Count of advisories the substrate did NOT honor
    /// (e.g. host requested .nativeV2 but production wire
    /// in is deferred per chapter 498 doctrine)。
    public var unhonoredAdvisoryCount: Int {
        _totalAdvisoryCount - _honoredAdvisoryCount
    }

    /// Ratio of honored advisories in [0, 1]。 Zero when
    /// no advisories recorded。
    public var honoredRatio: Double {
        guard _totalAdvisoryCount > 0 else { return 0 }
        return Double(_honoredAdvisoryCount)
            / Double(_totalAdvisoryCount)
    }

    /// Latest advisory recorded for the given host
    /// (most recent insertion order)。 Returns nil if
    /// the host has no advisories。
    public func latestAdvisory(
        for hostID: String
    ) -> BASEBrainHostRuntimeModeAdvisory? {
        return advisories
            .last { $0.hostID == hostID }
    }

    /// Snapshot all advisories in arrival order。 Read-
    /// only — does not mutate ledger state。
    public func allAdvisories()
        -> [BASEBrainHostRuntimeModeAdvisory]
    {
        return advisories
    }

    /// Reset ledger state — useful for tests + per-
    /// session ledger instances。
    public func reset() {
        advisories.removeAll()
        _droppedAdvisoryCount = 0
        _totalAdvisoryCount = 0
        _honoredAdvisoryCount = 0
        knownHostIDs.removeAll()
    }
}
