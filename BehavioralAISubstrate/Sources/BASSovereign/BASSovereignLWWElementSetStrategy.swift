import Foundation

// M296.3.zz CRDT — LWW-element-set sync strategy.
//
// ## Why this exists
//
// `BASSovereignSyncProtocolKind.crdt` was named in M296.3.z but
// had no implementation. CRDTs are a family — for cross-device
// audit-entry sync the simplest applicable variant is the
// **Last-Writer-Wins element set**: per-element timestamp
// determines the winner on conflict. We don't have wall-clock
// timestamps but we have vector clocks (M296.3), which give a
// partial order. The LWW variant ships here uses vector-clock
// causal ordering as the timestamp; concurrent updates are
// resolved by `originDeviceID` ascending then `auditEntryRef`
// ascending — the same deterministic tiebreak the canonical
// merger uses.
//
// ## Doctrine
//
// 1. **Per-`auditEntryRef`** — group all frames by their audit
//    entry reference. Each group represents zero, one, or more
//    versions of the same logical audit entry observed across
//    devices.
// 2. **Pick the latest per group**:
//    - causal-after wins (vector clock comparison)
//    - if two are concurrent, use `originDeviceID` ASC then
//      `auditEntryRef` ASC tiebreak (deterministic)
// 3. **Drop the rest** — older versions of the same
//    `auditEntryRef` are discarded, not preserved as history.
//    This is the "last-writer-wins" property: only the most
//    current view of each ref survives.
// 4. **Final ordering** by canonical merger semantics.
//
// ## When to pick LWW over vectorClockMerge
//
// - Pick LWW when each `auditEntryRef` has *one* canonical state
//   that should converge across devices. Older versions are
//   noise; only the latest matters.
// - Pick vectorClockMerge when you need to preserve the *history*
//   of every observed state. Older versions stay around for
//   audit replay.

public struct BASSovereignLWWElementSetStrategy:
    BASSovereignFragmentSyncStrategy
{
    public let kind: BASSovereignSyncProtocolKind = .crdt

    public init() {}

    public func sync(
        local: [BASSovereignCrossDeviceLedgerFrame],
        remote: [BASSovereignCrossDeviceLedgerFrame]
    ) async -> [BASSovereignCrossDeviceLedgerFrame] {
        let combined = local + remote
        guard !combined.isEmpty else { return [] }

        // Group by auditEntryRef.
        var groups: [String: [BASSovereignCrossDeviceLedgerFrame]] = [:]
        for frame in combined {
            groups[frame.auditEntryRef, default: []].append(frame)
        }

        // Pick latest per group.
        var winners: [BASSovereignCrossDeviceLedgerFrame] = []
        for (_, candidates) in groups {
            if let winner =
                BASSovereignLWWElementSetStrategy.pickLatest(
                    among: candidates)
            {
                winners.append(winner)
            }
        }

        // Final canonical ordering.
        return BASSovereignFragmentMerger.mergeOrdered(
            winners, [])
    }

    /// Pick the "latest" frame from a non-empty group of frames
    /// with the same `auditEntryRef`. Causal-after wins;
    /// concurrent uses origin-asc then auditRef-asc tiebreak
    /// (auditRef tiebreak is degenerate within a group since
    /// all share the same ref — it's there for total
    /// determinism in the comparator).
    static func pickLatest(
        among frames: [BASSovereignCrossDeviceLedgerFrame]
    ) -> BASSovereignCrossDeviceLedgerFrame? {
        guard !frames.isEmpty else { return nil }
        var winner = frames[0]
        for candidate in frames.dropFirst() {
            switch candidate.compare(to: winner) {
            case .after:
                winner = candidate
            case .concurrent:
                if candidate.originDeviceID
                    < winner.originDeviceID
                {
                    winner = candidate
                } else if candidate.originDeviceID
                            == winner.originDeviceID,
                          candidate.auditEntryRef
                            < winner.auditEntryRef
                {
                    winner = candidate
                }
            case .before, .equal:
                continue
            }
        }
        return winner
    }
}
