import Foundation

// M296.3.z — typed sync protocol scaffold for cross-device
// fragment exchange.
//
// ## Why this exists
//
// `BASSovereignFragmentMerger.mergeOrdered(_:_:)` (M296.3.y) is
// the *vector-clock + origin-tiebreak* canonical merge — one of
// several possible cross-device sync strategies. Manifest v2
// 「跨设备一致性」doesn't pick *the* protocol; it requires that
// whichever protocol gets picked produces deterministic causal
// ordering. M296.3.z ships the typed enum + strategy protocol so
// future protocol selection is a typed choice, and ships the
// vector-clock-merge default (wrapping M296.3.y) so hosts have a
// working strategy out of the box.
//
// ## Doctrine
//
// - **Protocol choice is host policy.** Different deployments
//   may pick different protocols (CRDT for offline-tolerant,
//   leader-follower for strict consistency, gossip for ad-hoc
//   peer networks). The strategy abstraction lets each host
//   plug its own without touching the merger.
// - **Vector-clock merge is the default.** Hosts that don't
//   want to think about it get deterministic causal ordering
//   from M296.3.y. Anyone wanting stronger or different
//   semantics implements `BASSovereignFragmentSyncStrategy`.
// - **Typed kind tag.** `BASSovereignSyncProtocolKind` enum
//   names the four candidate protocols manifest v2 mentions
//   (vector-clock-merge / CRDT / leader-follower / gossip).
//   Audit can group fragments by protocol kind.

public enum BASSovereignSyncProtocolKind:
    String, Sendable, Equatable, Hashable, Codable, CaseIterable
{
    /// Vector-clock-with-origin-tiebreak deterministic merge.
    /// Default; ships in M296.3.y.
    case vectorClockMerge

    /// Conflict-free Replicated Data Type semantics — eventually
    /// consistent, supports concurrent updates without manual
    /// resolution.
    case crdt

    /// Leader-follower replication — one device is canonical;
    /// others sync from it.
    case leaderFollower

    /// Gossip propagation — peers exchange fragments
    /// opportunistically; no central authority.
    case gossip
}

/// Protocol every cross-device sync strategy implements. Takes
/// local + remote frame lists, returns the merged-and-ordered
/// result.
public protocol BASSovereignFragmentSyncStrategy: Sendable {
    /// Which protocol kind this strategy implements.
    var kind: BASSovereignSyncProtocolKind { get }

    /// Merge local and remote fragments into one timeline.
    /// Implementation chooses the merge semantics; result must
    /// be deterministic for the same inputs.
    func sync(
        local: [BASSovereignCrossDeviceLedgerFrame],
        remote: [BASSovereignCrossDeviceLedgerFrame]
    ) async -> [BASSovereignCrossDeviceLedgerFrame]
}

/// Default strategy — wraps `BASSovereignFragmentMerger`
/// (M296.3.y). Vector-clock causal ordering with
/// origin-then-auditRef ASC tiebreak. Pure, deterministic, no
/// I/O.
public struct BASSovereignVectorClockMergeStrategy:
    BASSovereignFragmentSyncStrategy
{
    public let kind: BASSovereignSyncProtocolKind =
        .vectorClockMerge

    public init() {}

    public func sync(
        local: [BASSovereignCrossDeviceLedgerFrame],
        remote: [BASSovereignCrossDeviceLedgerFrame]
    ) async -> [BASSovereignCrossDeviceLedgerFrame] {
        BASSovereignFragmentMerger.mergeOrdered(
            local, remote)
    }
}
