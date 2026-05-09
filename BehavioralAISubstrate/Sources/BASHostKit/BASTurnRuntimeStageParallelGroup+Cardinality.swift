// MARK: - BASTurnRuntimeStageParallelGroup+Cardinality — chapter 四百十四 / M1026
// 系统熵 reduction
//
// Phase 2 entropy chapter 四百十四 entry:typed metadata
// extending `BASTurnRuntimeStageParallelGroup` (M1000) with
// canonical fan-out cardinality + canonical member-stage
// list per group。 Future native V2 parallel-dispatch
// drivers consume these to size + populate `async let`
// fan-outs。
//
// ## Why this exists (system entropy framing)
//
// M1000 ships the 4-case parallel-group enum and
// `BASTurnRuntimeStage.parallelGroup` per-stage accessor。
// But the inverse mapping (group → fan-out count + member
// stages) is not pinned。 Future native V2 parallel-dispatch
// drivers would each rederive this inline → scattered
// "fan-out cardinality entropy"。
//
// `BASTurnRuntimeStageParallelGroup.canonicalFanOutCount`
// ships the typed cardinality;
// `BASTurnRuntimeStageParallelGroup.canonicalMemberStages`
// ships the typed member-stage list per group。 Future
// drivers iterate via the typed mapping rather than
// hardcoding the M1000 DAG topology inline。
//
// Note:M1 and O fan out INTERNALLY (4-way and 12-way) but
// each appears as one "stage" in the M1000 enum。 The
// cardinality below reflects the INTERNAL fan-out,not the
// stage-cell count in the plan。 M1006 plan steps still
// reference the single stage cell;the driver is responsible
// for the internal fan-out。
//
// ## What this ships (M1026)
//
//   - `.canonicalFanOutCount: Int` per group (2/2/4/12)
//   - `.canonicalMemberStages: [BASTurnRuntimeStage]` per
//     group (only for stage-level fan-outs;internal fan-
//     outs return the single stage cell)
//
// ## Doctrine pins held
//
//   - All chapter 四百三/…/四百十三 doctrine pins
//   - chapter 一百八十五 — typed metadata,raw cardinalities
//     pinned per anti-magic-number
//   - chapter 二百一一 — single source-of-truth for fan-out
//     metadata
//   - chapter 三百九二 — same group → same metadata every call
//   - ADR-014 OPT-IN — purely additive

import Foundation

extension BASTurnRuntimeStageParallelGroup {

    /// Canonical fan-out cardinality per parallel group。
    /// For `.entryAA2` and `.dD2`,this is 2 (stage-level
    /// fan-out)。 For `.m1FourWay`,4 (internal-fan-out)。
    /// For `.o12Way`,12 (internal-fan-out)。
    public var canonicalFanOutCount: Int {
        switch self {
        case .entryAA2: return 2
        case .dD2: return 2
        case .m1FourWay: return 4
        case .o12Way: return 12
        }
    }

    /// Canonical member-stage list per parallel group。
    /// For stage-level fan-outs (entryAA2 / dD2),returns
    /// the 2 sibling stages。 For internal-fan-out groups
    /// (m1FourWay / o12Way),returns the single stage
    /// cell that contains the internal fan-out。
    public var canonicalMemberStages:
        [BASTurnRuntimeStage]
    {
        switch self {
        case .entryAA2:
            return [.stageA, .stageA2]
        case .dD2:
            return [.stageD, .stageD2]
        case .m1FourWay:
            return [.stageM1]
        case .o12Way:
            return [.stageO]
        }
    }
}
