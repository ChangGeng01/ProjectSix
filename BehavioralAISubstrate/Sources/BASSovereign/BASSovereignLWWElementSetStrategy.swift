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
        // audit blindspot-CRDT: the old single-pass fold's "beats" relation (causal `.after` mixed
        // with a concurrent origin-ASC tiebreak) is INTRANSITIVE, so the winner depended on array
        // order — two devices picked DIFFERENT LWW winners for the same ref (divergence), and the
        // fold could even settle on a causally-DOMINATED (non-latest) frame. Correct LWW in two
        // stages: (1) the causally-MAXIMAL set = frames dominated by NO other (the genuinely-latest,
        // a concurrent antichain); (2) break that antichain deterministically by origin-ASC then
        // ref-ASC. A pure function of the group ⇒ every device converges on the same winner.
        let maximal = frames.filter { candidate in
            !frames.contains { other in
                other != candidate && candidate.compare(to: other) == .before
            }
        }
        // `maximal` is non-empty (a finite causal DAG has at least one maximum). `.min` over a
        // lexicographic (origin, ref) key — a genuine strict weak ordering — is well-defined.
        return maximal.min { lhs, rhs in
            if lhs.originDeviceID != rhs.originDeviceID {
                return lhs.originDeviceID < rhs.originDeviceID
            }
            return lhs.auditEntryRef < rhs.auditEntryRef
        }
    }
}
