import Foundation

// M296.3.zz (partial) — leader-follower sync strategy.
//
// ## Why this exists
//
// `BASSovereignFragmentSyncStrategy` (M296.3.z) declares 4 protocol
// kinds; `BASSovereignVectorClockMergeStrategy` ships the
// `vectorClockMerge` default. The other 3 (`crdt` /
// `leaderFollower` / `gossip`) are protocol choices each with
// their own semantics. M296.3.zz starts the series by shipping
// `leaderFollower` — the simplest of the three, with clear
// "leader's view is authoritative" semantics.
//
// ## Doctrine
//
// Leader-follower rules:
//
// 1. **Take all of the leader's frames.** Whatever auditEntryRefs
//    the leader has, those are the canonical ones.
// 2. **Add non-leader frames whose auditEntryRef is NOT in the
//    leader's set.** Followers can contribute new entries the
//    leader hasn't seen yet; those go through.
// 3. **Discard non-leader frames whose auditEntryRef DOES appear
//    in the leader's set.** This is the "leader wins on conflict"
//    rule — even if a follower's clock looks more advanced for
//    that ref, the leader's version is canonical.
// 4. **Final ordering** by `BASSovereignFragmentMerger` semantics
//    (vector-clock causal + origin/auditRef tiebreak) — same
//    deterministic order as the default strategy, applied to the
//    filtered set.
//
// ## What this doesn't do
//
// - Doesn't elect a leader. The `leaderDeviceID` is supplied at
//   strategy construction; election protocols are a separate
//   spec item.
// - Doesn't prevent leader from being wrong — by doctrine the
//   leader is authoritative. Hosts that need conflict resolution
//   beyond "leader wins" should pick a different strategy.

public struct BASSovereignLeaderFollowerStrategy:
    BASSovereignFragmentSyncStrategy
{
    public let kind: BASSovereignSyncProtocolKind =
        .leaderFollower

    /// The device whose frames are authoritative on conflict.
    public let leaderDeviceID: String

    public init(leaderDeviceID: String) {
        self.leaderDeviceID = leaderDeviceID
    }

    public func sync(
        local: [BASSovereignCrossDeviceLedgerFrame],
        remote: [BASSovereignCrossDeviceLedgerFrame]
    ) async -> [BASSovereignCrossDeviceLedgerFrame] {
        // Step 1: gather every frame regardless of origin.
        let combined = local + remote

        // Step 2: collect auditEntryRefs the leader has seen.
        let leaderRefs: Set<String> = Set(
            combined
                .filter {
                    $0.originDeviceID == leaderDeviceID
                }
                .map(\.auditEntryRef))

        // Step 3: keep all leader frames + non-leader frames
        // whose auditEntryRef the leader hasn't seen.
        let filtered = combined.filter { frame in
            if frame.originDeviceID == leaderDeviceID {
                return true
            }
            return !leaderRefs.contains(frame.auditEntryRef)
        }

        // Step 4: deterministic causal ordering via the canonical
        // merger. Pass empty as the second list; merger does
        // dedup + sort.
        return BASSovereignFragmentMerger.mergeOrdered(
            filtered, [])
    }
}
