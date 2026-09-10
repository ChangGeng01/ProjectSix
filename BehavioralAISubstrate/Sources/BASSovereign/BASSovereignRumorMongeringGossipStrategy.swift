import Foundation

// M296.3.zz higher gossip — rumor-mongering variant.
//
// ## Why this exists
//
// `BASSovereignAntiEntropyGossipStrategy` (M296.3.zz gossip) is
// peer-symmetric **complete-state** exchange — both peers
// converge on the union timeline. That's right when bandwidth
// is cheap. Manifest v2 also covers deployments where peers
// can't afford full-state exchange every sync round; **rumor-
// mongering** is the gossip variant that bounds output to the
// "most recent" subset, prioritizing novelty over completeness.
//
// `BASSovereignRumorMongeringGossipStrategy` ships that
// algorithm:
//
// 1. Combine `local + remote` and dedupe (canonical merge step)
// 2. Sort by causal recency (later vector clocks first;
//    concurrent broken by origin ASC then auditRef ASC)
// 3. Keep only top `mongerWindowSize` most recent
// 4. Re-sort the kept subset by canonical merger order for
//    deterministic output
//
// ## Doctrine
//
// - **Bounded output.** Result has size ≤ mongerWindowSize.
//   Older fragments may be dropped (distinct from anti-entropy
//   which always keeps everything).
// - **Recency-first window.** "Most recent" = latest vector
//   clock by canonical compare; concurrent broken
//   deterministically.
// - **Same `kind: .gossip`** as anti-entropy — they're both
//   gossip variants. Hosts choose by strategy type explicitly.
// - **Convergent across rounds.** Two peers running rumor-
//   mongering will exchange their windows; over time the union
//   propagates (provided window covers the new fragments each
//   round).
//
// ## When rumor-mongering over anti-entropy
//
// - Pick rumor-mongering when each sync round must be size-
//   bounded (mobile bandwidth, cell tower handoff, etc.) and
//   you trust multiple rounds to eventually propagate older
//   state.
// - Pick anti-entropy when bandwidth is cheap and you want
//   single-round full convergence.

public struct BASSovereignRumorMongeringGossipStrategy:
    BASSovereignFragmentSyncStrategy
{
    public let kind: BASSovereignSyncProtocolKind = .gossip

    /// Maximum number of fragments to retain per sync round.
    /// Higher window = closer to anti-entropy; lower window =
    /// stricter recency bound.
    public let mongerWindowSize: Int

    public init(mongerWindowSize: Int = 64) {
        self.mongerWindowSize = max(mongerWindowSize, 0)
    }

    public func sync(
        local: [BASSovereignCrossDeviceLedgerFrame],
        remote: [BASSovereignCrossDeviceLedgerFrame]
    ) async -> [BASSovereignCrossDeviceLedgerFrame] {
        // Step 1+2: combine + dedup via canonical merger.
        let merged = BASSovereignFragmentMerger.mergeOrdered(
            local, remote)

        // Step 3: take the most recent by reversing merger
        // order (merger sorts ascending causal; we want
        // descending recency for window selection).
        let descendingByRecency = merged.reversed()
        let windowed = Array(
            descendingByRecency.prefix(mongerWindowSize))

        // Step 4: re-canonicalize the kept subset's order so
        // output is deterministic + ascending causal.
        return BASSovereignFragmentMerger.mergeOrdered(
            windowed, [])
    }
}
