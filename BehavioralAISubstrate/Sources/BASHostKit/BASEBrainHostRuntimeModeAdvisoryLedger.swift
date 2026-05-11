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

    private var advisories:
        [BASEBrainHostRuntimeModeAdvisory] = []

    public init() {}

    /// Record an advisory。 Order-preserving append。
    public func record(
        advisory: BASEBrainHostRuntimeModeAdvisory
    ) {
        advisories.append(advisory)
    }

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
        advisories.append(advisory)
    }

    // MARK: - Read accessors

    /// Total advisories recorded since construction。
    public var totalAdvisoryCount: Int {
        advisories.count
    }

    /// Distinct host IDs that have recorded an advisory。
    public var distinctHostCount: Int {
        Set(advisories.map(\.hostID)).count
    }

    /// Count of advisories the substrate HONORED at the
    /// time of recording。
    public var honoredAdvisoryCount: Int {
        advisories.filter(\.wasHonored).count
    }

    /// Count of advisories the substrate did NOT honor
    /// (e.g. host requested .nativeV2 but production wire
    /// in is deferred per chapter 498 doctrine)。
    public var unhonoredAdvisoryCount: Int {
        advisories.filter { !$0.wasHonored }.count
    }

    /// Ratio of honored advisories in [0, 1]。 Zero when
    /// no advisories recorded。
    public var honoredRatio: Double {
        guard !advisories.isEmpty else { return 0 }
        return Double(honoredAdvisoryCount)
            / Double(advisories.count)
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
    }
}
