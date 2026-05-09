// MARK: - BASParallelStageAssembleOrder — chapter 四百十四 / M1027
// 系统熵 reduction
//
// Phase 2 entropy chapter 四百十四 second cut:typed generic
// value type wrapping outputs from a stage-level parallel
// fan-out (M1000 entryAA2 / dD2) and producing them in
// canonical order via the M1026 member-stage list。 Future
// native V2 parallel-dispatch drivers use this to anchor
// chapter 三百九二 byte-stability across non-deterministic
// async-let completion ordering。
//
// ## Why this exists (system entropy framing)
//
// `async let` fan-outs return values in completion order,
// which is non-deterministic。 Without a typed canonical-
// assemble-order primitive,future native V2 stage rewrites
// would each manually reorder fan-out outputs inline →
// scattered "assemble-order entropy" + risk of byte-stability
// regression (chapter 三百九二)。
//
// `BASParallelStageAssembleOrder` ships the typed wrapper:
//
//   - Caller populates `outputsByStage` from any completion
//     order (could be A2-then-A or A-then-A2)
//   - `.canonicalOutputs` returns outputs in M1000-pinned
//     order:[A, A2] for entryAA2,[D, D2] for dD2
//
// Result:byte-stability holds regardless of what order
// async-let happened to complete in。
//
// ## What this ships (M1027)
//
//   - `BASParallelStageAssembleOrder<Output>` generic Sendable
//     value type wrapping
//     `[BASTurnRuntimeStage: Output]` + group identifier
//   - `.canonicalOutputs: [Output]` returning in M1026
//     member-stage order
//   - `.isComplete: Bool` accessor (every member-stage has
//     an output)
//
// ## Doctrine pins held
//
//   - All chapter 四百三/…/四百十三 doctrine pins
//   - chapter 一百八十五 — typed assembly,not raw dictionary
//   - chapter 二百一一 — single source-of-truth for canonical
//     assemble-order logic
//   - chapter 三百九二 (CRITICAL) — byte-stability across non-
//     deterministic async-let completion order
//   - ADR-014 OPT-IN — purely additive

import Foundation

/// Typed generic wrapper for assembling parallel-fan-out
/// outputs in canonical order regardless of async-let
/// completion order。
public struct BASParallelStageAssembleOrder<
    Output: Sendable
>: Sendable {

    // MARK: - Storage

    /// The parallel group this assembly targets。
    public let group: BASTurnRuntimeStageParallelGroup

    /// Outputs keyed by stage。 Caller populates from any
    /// completion order。
    public let outputsByStage:
        [BASTurnRuntimeStage: Output]

    // MARK: - Init

    public init(
        group: BASTurnRuntimeStageParallelGroup,
        outputsByStage: [BASTurnRuntimeStage: Output]
    ) {
        self.group = group
        self.outputsByStage = outputsByStage
    }

    // MARK: - Canonical assembly

    /// Outputs in M1000-pinned order per `group.canonical
    /// MemberStages`。 Same input → same canonical array
    /// (chapter 三百九二)。 Missing stages omit their output
    /// from the array;use `.isComplete` to check coverage。
    public var canonicalOutputs: [Output] {
        group.canonicalMemberStages.compactMap {
            outputsByStage[$0]
        }
    }

    /// `true` when every member-stage of `group` has an
    /// output entry。
    public var isComplete: Bool {
        group.canonicalMemberStages.allSatisfy {
            outputsByStage[$0] != nil
        }
    }
}
