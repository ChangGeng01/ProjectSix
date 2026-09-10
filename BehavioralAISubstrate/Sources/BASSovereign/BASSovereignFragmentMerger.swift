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
        // Step 3: deterministic linear extension of the causal partial order.
        // audit blindspot-CRDT: was `combined.sorted(by: orderBefore)`, but `orderBefore` is
        // INTRANSITIVE (see its doc) — it mixed the causal PARTIAL order with a per-pair origin
        // tiebreak, so a 3-frame concurrent-with-causal-edge cycle A<B<C<A made `sorted(by:)`
        // undefined and input-order-dependent → two devices holding the same frame set sorted to
        // DIFFERENT timelines (falsifying the whole cross-device convergence guarantee). A topological
        // order is a genuine total order that respects causality AND is a pure function of the SET.
        return topologicalOrder(combined)
    }

    /// A deterministic topological order of the causal DAG: repeatedly emit the
    /// (originDeviceID, auditEntryRef)-minimal frame among those whose causal predecessors within the
    /// set have all been emitted. This RESPECTS causality (a frame follows all its causal ancestors),
    /// breaks a concurrent antichain by origin-ASC then ref-ASC (matching the documented tiebreak +
    /// the 2-frame tests), and is a pure function of the frame SET — so two devices with the same
    /// frames in ANY concatenation order produce the SAME timeline (the convergence the old comparator
    /// could not deliver). Kahn's algorithm; O(n²) over the (bounded) fragment set.
    static func topologicalOrder(
        _ frames: [BASSovereignCrossDeviceLedgerFrame]
    ) -> [BASSovereignCrossDeviceLedgerFrame] {
        let n = frames.count
        if n <= 1 { return frames }
        // Causal edges: j → i when frames[j] is causally-BEFORE frames[i]. `.equal` clocks are NOT
        // edges (same-clock frames are a concurrent antichain, broken by the tiebreak) — matching the
        // old code, which routed `.equal` through the origin/ref tiebreak too.
        var indeg = [Int](repeating: 0, count: n)
        var successors = [[Int]](repeating: [], count: n)
        for i in 0..<n {
            for j in 0..<n where j != i {
                if frames[j].clock.compare(to: frames[i].clock) == .before {
                    indeg[i] += 1
                    successors[j].append(i)
                }
            }
        }
        var emitted = [Bool](repeating: false, count: n)
        var result: [BASSovereignCrossDeviceLedgerFrame] = []
        result.reserveCapacity(n)
        for _ in 0..<n {
            // The (origin, ref)-minimal ready frame (indeg 0, not yet emitted).
            var best: Int?
            for i in 0..<n where !emitted[i] && indeg[i] == 0 {
                if best == nil || tieBreakBefore(frames[i], frames[best!]) { best = i }
            }
            guard let pick = best else { break }   // a finite DAG always has a source; defensive.
            emitted[pick] = true
            result.append(frames[pick])
            for s in successors[pick] { indeg[s] -= 1 }
        }
        return result
    }

    /// Antichain tiebreak: originDeviceID ASC, then auditEntryRef ASC. Lexicographic ⇒ a genuine
    /// strict weak ordering (transitive) — safe to use with `min`/`sorted`, unlike `orderBefore`.
    static func tieBreakBefore(
        _ lhs: BASSovereignCrossDeviceLedgerFrame,
        _ rhs: BASSovereignCrossDeviceLedgerFrame
    ) -> Bool {
        if lhs.originDeviceID != rhs.originDeviceID {
            return lhs.originDeviceID < rhs.originDeviceID
        }
        return lhs.auditEntryRef < rhs.auditEntryRef
    }

    /// SUPERSEDED (audit blindspot-CRDT) — INTRANSITIVE, DO NOT use as a sort comparator.
    /// It returns causal-before for a `.before`/`.after` pair but an origin/ref tiebreak for a
    /// `.concurrent`/`.equal` pair; mixing a partial order with a per-pair tiebreak is not transitive
    /// (A causally-before B, B origin< C, C origin< A ⇒ A<B<C<A, a cycle). `mergeOrdered` now uses
    /// `topologicalOrder`. Kept for reference (the intransitivity is pinned by a regression test).
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
            if lhs.originDeviceID != rhs.originDeviceID {
                return lhs.originDeviceID < rhs.originDeviceID
            }
            return lhs.auditEntryRef < rhs.auditEntryRef
        }
    }
}
