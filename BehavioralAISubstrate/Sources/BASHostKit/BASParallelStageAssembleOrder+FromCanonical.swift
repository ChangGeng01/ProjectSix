// MARK: - BASParallelStageAssembleOrder+FromCanonical — chapter 四百十四 / M1028
// 系统熵 reduction
//
// Phase 2 entropy chapter 四百十四 third cut:typed factory
// `.fromCanonicalOrder(_:group:)` that's the inverse of
// `.canonicalOutputs`。 Useful when callers already hold a
// canonical-order array (eg. a pre-canonicalized fixture
// or a stable test snapshot) and want to reconstruct the
// typed assembly。
//
// ## Why this exists (system entropy framing)
//
// M1027 ships the forward direction:assembly → canonical
// array via `.canonicalOutputs`。 Without the inverse,
// future test fixtures + V1↔V2 stress harness fixtures
// holding canonical-order arrays would each rederive the
// "zip stages with outputs" inline → scattered "inverse-
// assembly entropy"。
//
// `.fromCanonicalOrder(_:group:)` ships the inverse as one
// typed factory。 Round-trip property:
//
//   assembly.canonicalOutputs == [a, b, c, ...]
//   ↔
//   .fromCanonicalOrder([a, b, c, ...], group: assembly.group)
//
// holds when assembly is complete。
//
// ## What this ships (M1028)
//
//   - `BASParallelStageAssembleOrder.fromCanonicalOrder(
//      _:group:)` static factory
//   - Length mismatch handled by zipping the shorter side
//     (caller checks `.isComplete` if strict coverage
//     required)
//
// ## Doctrine pins held
//
//   - All chapter 四百三/…/四百十三/四百十四 doctrine pins
//   - chapter 一百八十五 — typed factory
//   - chapter 二百一一 — single source-of-truth for inverse
//     assembly logic
//   - chapter 三百九二 — same input → same assembly every call
//   - ADR-014 OPT-IN — purely additive

import Foundation

extension BASParallelStageAssembleOrder {

    /// Build an assembly from a canonical-order array of
    /// outputs。 Outputs are zipped with the group's
    /// canonical member-stage list。 Pure;same input →
    /// same assembly (chapter 三百九二)。
    ///
    /// If `canonicalOutputs.count` is less than
    /// `group.canonicalMemberStages.count`,only the first
    /// N stages are populated;use `.isComplete` to detect。
    /// If `canonicalOutputs.count` exceeds the member-stage
    /// count,extra outputs are ignored。
    public static func fromCanonicalOrder(
        _ canonicalOutputs: [Output],
        group: BASTurnRuntimeStageParallelGroup
    ) -> BASParallelStageAssembleOrder<Output> {
        let stages = group.canonicalMemberStages
        var dict: [BASTurnRuntimeStage: Output] = [:]
        for (stage, output) in zip(
            stages, canonicalOutputs)
        {
            dict[stage] = output
        }
        return BASParallelStageAssembleOrder<Output>(
            group: group,
            outputsByStage: dict)
    }
}
