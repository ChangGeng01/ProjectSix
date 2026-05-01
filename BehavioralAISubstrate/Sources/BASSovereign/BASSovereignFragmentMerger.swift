import Foundation

// M296.3.y — pure algorithmic merger for cross-device ledger
// fragments. Takes two device's frame lists and returns one
// causally-ordered combined list.
//
// ## Why this exists
//
// `BASSovereignCrossDeviceLedgerFrame` (M296.3.x) carries
// per-frame causal metadata, but says nothing about how to
// **combine** two devices' fragment lists into one timeline.
// `mergeOrdered(_:_:)` is the canonical merge algorithm:
//
// 1. Concatenate both inputs
// 2. Deduplicate (full-frame equality removes byte-identical
//    repeats; partial duplicates with differing clocks survive)
// 3. Sort using vector-clock total-ordering with origin tiebreak:
//    - clock-before → comes first
//    - clock-after → comes after
//    - clock-equal → tie-break by originDeviceID ASC
//    - clock-concurrent → tie-break by originDeviceID ASC, then
//      auditEntryRef ASC for full determinism
//
// This is **NOT** a sync protocol — it's the deterministic
// ordering primitive a sync protocol layers on top of.
//
// ## Doctrine
//
// - **Total ordering on what is partial.** Vector clocks give a
//   partial order; concurrent events have no causal ordering.
//   We impose origin-asc tiebreak to make the merge deterministic
//   so the same `(a, b)` input always yields the same output.
//   Sync protocols that need stronger semantics (e.g. CRDT-style
//   convergence) wrap this.
// - **Pure helper.** No actor, no mutation, no I/O. Pure
//   `[Frame] × [Frame] → [Frame]`.
// - **Idempotent.** `mergeOrdered(a, [])` returns sorted-`a`.
//   `mergeOrdered(a, a)` deduplicates and returns sorted-`a`.
// - **Commutative on byte-equal frames.** `mergeOrdered(a, b)`
//   has the same set as `mergeOrdered(b, a)` (order is the same
//   too because the comparator is total).

public enum BASSovereignFragmentMerger {

    /// Merge two device's frame lists into one causally-ordered
    /// list. See type-level doc for full doctrine.
    public static func mergeOrdered(
        _ a: [BASSovereignCrossDeviceLedgerFrame],
        _ b: [BASSovereignCrossDeviceLedgerFrame]
    ) -> [BASSovereignCrossDeviceLedgerFrame] {
        // Step 1+2: combine + dedup by full frame equality.
        var seen = Set<BASSovereignCrossDeviceLedgerFrame>()
        var combined: [BASSovereignCrossDeviceLedgerFrame] = []
        for frame in a + b {
            if seen.insert(frame).inserted {
                combined.append(frame)
            }
        }
        // Step 3: total-order sort.
        return combined.sorted(by: orderBefore)
    }

    /// Strict weak ordering predicate: returns true iff `lhs`
    /// must come before `rhs` in the merged timeline.
    static func orderBefore(
        _ lhs: BASSovereignCrossDeviceLedgerFrame,
        _ rhs: BASSovereignCrossDeviceLedgerFrame
    ) -> Bool {
        switch lhs.clock.compare(to: rhs.clock) {
        case .before:
            return true
        case .after:
            return false
        case .equal, .concurrent:
            // Tie-break: originDeviceID ASC, then auditEntryRef ASC.
            if lhs.originDeviceID != rhs.originDeviceID {
                return lhs.originDeviceID < rhs.originDeviceID
            }
            return lhs.auditEntryRef < rhs.auditEntryRef
        }
    }
}
