import Foundation

// M296.3.zz higher CRDT — multi-value register strategy.
//
// ## Why this exists
//
// `BASSovereignLWWElementSetStrategy` (M296.3.zz CRDT) picks one
// winner per `auditEntryRef` on conflict. That's right when the
// host wants automatic resolution. But manifest v2 also covers
// scenarios where conflict itself is information — host wants to
// surface "two devices disagree" to user resolution, not silently
// discard one side. Multi-value register is the CRDT for that:
//
// - For each `auditEntryRef`, group all observed versions
// - Causal-ordered versions collapse to the latest (older
//   versions superseded)
// - Concurrent versions ALL preserved (no auto-resolution)
//
// Output: for each ref, every concurrent winner survives. LWW
// always returns 1 frame per ref; MVR may return N (one per
// concurrent branch).
//
// ## Doctrine
//
// - Same `BASSovereignSyncProtocolKind.crdt` tag as LWW —
//   they're both CRDTs. Hosts choose between them by picking
//   the strategy type explicitly.
// - For each group:
//   - find frames not causally dominated by any other in group
//   - those are the concurrent winners; keep them all
// - Output ordered by canonical merger (causal+tiebreak).
//
// ## When MVR over LWW
//
// - Pick MVR when concurrent updates should be surfaced to user
//   resolution rather than auto-resolved.
// - Pick LWW when each ref has one canonical state and you
//   trust the deterministic tiebreak to converge silently.

public struct BASSovereignMultiValueRegisterStrategy:
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

        var groups: [String: [BASSovereignCrossDeviceLedgerFrame]] = [:]
        for frame in combined {
            groups[frame.auditEntryRef, default: []].append(frame)
        }

        var winners: [BASSovereignCrossDeviceLedgerFrame] = []
        for (_, candidates) in groups {
            winners.append(
                contentsOf:
                    BASSovereignMultiValueRegisterStrategy
                        .nonDominatedFrames(in: candidates))
        }
        return BASSovereignFragmentMerger.mergeOrdered(
            winners, [])
    }

    /// Return the subset of `frames` that are *not* causally
    /// dominated by any other frame in the same set. A frame `f`
    /// is dominated iff there exists another frame `g` in the set
    /// where `f.compare(to: g) == .before`. Concurrent frames
    /// dominate nobody, so they survive. Causally-equal frames
    /// also survive (both kept since neither dominates).
    static func nonDominatedFrames(
        in frames: [BASSovereignCrossDeviceLedgerFrame]
    ) -> [BASSovereignCrossDeviceLedgerFrame] {
        var seen = Set<BASSovereignCrossDeviceLedgerFrame>()
        var output: [BASSovereignCrossDeviceLedgerFrame] = []
        for f in frames {
            var dominated = false
            for g in frames where f != g {
                if f.compare(to: g) == .before {
                    dominated = true
                    break
                }
            }
            if !dominated, seen.insert(f).inserted {
                output.append(f)
            }
        }
        return output
    }
}
