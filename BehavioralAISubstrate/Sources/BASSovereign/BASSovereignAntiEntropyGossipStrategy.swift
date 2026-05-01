import Foundation

// M296.3.zz gossip — anti-entropy gossip sync strategy.
//
// ## Why this exists
//
// `BASSovereignSyncProtocolKind.gossip` was named in M296.3.z
// but had no implementation. Gossip protocols are a family
// (anti-entropy / rumor-mongering / hierarchical aggregation /
// etc.); the simplest variant for cross-device fragment exchange
// is **anti-entropy**: two peers exchange their complete
// fragment lists and reconcile via vector-clock merge. Result:
// both peers converge on the same union timeline.
//
// Algorithmically anti-entropy is identical to
// `vectorClockMerge` — but the protocol doctrine is different
// (no privileged transport, no leader, peer-symmetric
// exchange). Tagging it as `.gossip` lets audit walkers
// distinguish "the host chose gossip transport" from "the host
// chose canonical merge as a default" even when the bytes
// produced are equivalent.
//
// ## Doctrine
//
// - **Peer-symmetric.** No leader, no privileged device.
//   `local` and `remote` are interchangeable — strategy output
//   doesn't depend on which side is which.
// - **Convergent.** Two peers running anti-entropy on the same
//   pair of fragment lists in either direction reach the same
//   final state.
// - **Delegates to merger.** Algorithm is identical to
//   `vectorClockMerge`; the strategy is a typed re-export with
//   a different `kind` tag for protocol audit.
//
// ## When to pick gossip over vectorClockMerge
//
// - Pick `gossip` when modeling peer-symmetric exchange where
//   audit needs to record *protocol transport* (e.g. peer
//   network without coordinator).
// - Pick `vectorClockMerge` when the merge is conceptually a
//   library operation, not an inter-device exchange.

public struct BASSovereignAntiEntropyGossipStrategy:
    BASSovereignFragmentSyncStrategy
{
    public let kind: BASSovereignSyncProtocolKind = .gossip

    public init() {}

    public func sync(
        local: [BASSovereignCrossDeviceLedgerFrame],
        remote: [BASSovereignCrossDeviceLedgerFrame]
    ) async -> [BASSovereignCrossDeviceLedgerFrame] {
        // Anti-entropy: peers exchange complete states; result
        // is the canonical merge.
        BASSovereignFragmentMerger.mergeOrdered(local, remote)
    }
}
