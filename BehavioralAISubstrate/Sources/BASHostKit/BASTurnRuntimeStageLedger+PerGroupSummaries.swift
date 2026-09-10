// MARK: - BASTurnRuntimeStageLedger+PerGroupSummaries — chapter 四百十六 / M1036
// 系统熵 reduction
//
// Phase 2 entropy chapter 四百十六 third cut:typed per-group
// dispatch-summary accessors on `BASTurnRuntimeStageLedger`。
// Future callers wanting one specific group's summary don't
// have to index into the array returned by M1032
// `.parallelDispatchSummaries()` — they can ask for the
// group by name。
//
// ## Why this exists (system entropy framing)
//
// M1032 returns all 4 group summaries in array order via
// `.parallelDispatchSummaries()`。 But callers wanting just
// "how did entryAA2 fare?" would each have to index by hand
// → indexing-fragility entropy + stiff coupling to allCases
// ordering。
//
// `entryAA2DispatchSummary` / `dD2DispatchSummary` / etc.
// ship typed accessors so callers can read by name。
//
// ## What this ships (M1036)
//
//   - `.entryAA2DispatchSummary` /
//     `.dD2DispatchSummary` /
//     `.m1FourWayDispatchSummary` /
//     `.o12WayDispatchSummary` accessors,each returning
//     the appropriate `BASParallelStageDispatchSummary`
//
// ## Doctrine pins held
//
//   - All chapter 四百三/…/四百十五/四百十六 doctrine pins
//   - chapter 一百八十五 — typed accessors,not array index
//   - chapter 二百一一 — single source-of-truth for per-group
//     summary lookup
//   - chapter 三百九二 — deterministic
//   - ADR-014 OPT-IN — purely additive

import Foundation

extension BASTurnRuntimeStageLedger {

    /// Summary for the entry parallel group (A‖A2)。
    public var entryAA2DispatchSummary:
        BASParallelStageDispatchSummary
    {
        BASParallelStageDispatchSummary.from(
            records: records, group: .entryAA2)
    }

    /// Summary for the D‖D2 parallel group。
    public var dD2DispatchSummary:
        BASParallelStageDispatchSummary
    {
        BASParallelStageDispatchSummary.from(
            records: records, group: .dD2)
    }

    /// Summary for the M1 4-way fan-out group。
    public var m1FourWayDispatchSummary:
        BASParallelStageDispatchSummary
    {
        BASParallelStageDispatchSummary.from(
            records: records, group: .m1FourWay)
    }

    /// Summary for the O 12-way fan-out group。
    public var o12WayDispatchSummary:
        BASParallelStageDispatchSummary
    {
        BASParallelStageDispatchSummary.from(
            records: records, group: .o12Way)
    }
}
