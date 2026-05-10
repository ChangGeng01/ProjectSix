// MARK: - BASChapter432EntropyDoctrine — chapter 四百三十二 / M1103
// 系统熵 reduction
//
// RADICAL EVOLUTION SWEEP Phase F close-out doctrine。
// Pins the chapter 四百三十二 entropy work shipped across 4
// commits (M1100-M1103):BASTurnRuntimeEngine consumes the
// Phase E BASMetalSubstrate primitives via configuration
// + dispatch probe + hardware-aware scheduler。
//
// ## Why this exists (system entropy framing)
//
// Phase E (chapter 四百三十一 / M1096-M1099) shipped the
// NATIVE APPLE SILICON FOUNDATION — typed tensors,ANE
// capability,kernel registry,3 reference kernels — but
// nothing in the runtime CONSUMED any of it。 Phase F
// closes that gap:
//
//   - M1100 extends `BASTurnRuntimeEngineConfiguration`
//     with 3 new optional slots (runtimeMode +
//     metalKernelRegistry + aneCapability)。 Default
//     values preserve V1 byte-equality (ADR-014 OPT-IN)。
//   - M1101 wires the slots into `BASTurnRuntimeEngine`
//     storage + adds a typed
//     `BASTurnRuntimePlanDispatchProbe` Sendable surface
//     so callers + tests + the M1102 scheduler can
//     verify the engine actually CONSULTS the config at
//     dispatch time (not just stores it)。
//   - M1102 ships `BASHardwareAwareScheduler` actor +
//     typed `BASStageAcceleratorHint` /
//     `BASStageAcceleratorAssignment` envelopes。 First
//     consumer of the M1097 capability + M1098 registry。
//   - M1103 (this commit) closes the chapter doctrine +
//     bumps Phase 2 + ADR-016 doctrine version。 No
//     default-mode flip — that needs CI dual-mode
//     verification first。
//
// ## What this ships (M1100-M1103)
//
//   - M1100:`BASTurnRuntimeEngineConfiguration` 3-slot
//     extension (Sources/BASHostKit/...) + 3 `with(...)`
//     immutable updaters。 BASHostKit gains
//     BASMetalSubstrate dependency。
//   - M1101:`BASTurnRuntimeEngine` 3 new stored fields
//     + 7-param init + bundle init threading + 2 new
//     async accessors (lastPlanDispatchProbe,
//     currentDispatchProbe) + `runWithPlan(...)` probe
//     capture。 New
//     `Sources/BASHostKit/BASTurnRuntimePlanDispatchProbe
//     .swift` typed Sendable struct。
//   - M1102:`Sources/BASHostKit/
//     BASStageAcceleratorHint.swift` (6-field hint +
//     3-case preference enum) +
//     `BASStageAcceleratorAssignment.swift` (5-field
//     assignment + 5-case rationale enum) +
//     `BASHardwareAwareScheduler.swift` (~270 LOC actor
//     + cost function + tiebreaker + thermal derate)。
//   - M1103:this close-out doctrine + Phase 2 doctrine
//     bump + ADR-016.M1099 → ADR-016.M1103。
//
// ## What's NOT in chapter 四百三十二 v1 (deferred)
//
//   - `BASTurnRuntimeStagePlan` per-stage acceleratorHint
//     wiring — touches every existing plan test;risks
//     widespread regression。 Lands in chapter 四百三十三+。
//   - `BASNativeStageExecutor.executePlan` consults
//     scheduler — depends on plan modification above。
//   - V2 default-mode flip from `.v1ByteEqual` to
//     `.nativeV2` — needs the M1074 BASStressSweepHarness
//     CI dual-mode run to prove byte-equality across the
//     canonical60 fixture set。 Conservative posture:
//     keep `.v1ByteEqual` as the engine default until
//     CI evidence accumulates。
//
// ## Doctrine pins held
//
//   - chapter 一百八十五 — anti-magic-number throughout
//     (typed enums + named cost components)
//   - chapter 二百一一 — single source-of-truth (one
//     scheduler, one cost function, one probe shape)
//   - chapter 三百九二 — replay-determinism (Sendable
//     bundles via Codable + sortedKeys; scheduler
//     deterministic for same hint+capability+thermal)
//   - 不变量 #1/#2/#3 — V1 byte-equality preserved
//     (default config keeps engine v1ByteEqual + nil
//     registry + nil capability — no behavioral change)
//   - 红线 7 — hint-only (probe + scheduler are
//     observation/dispatch, not commitment authority)
//   - ADR-014 OPT-IN — purely additive
//   - ADR-016 — bumped M1099 → M1103
//   - RADICAL EVOLUTION SWEEP Phase F — this chapter

import Foundation

public enum BASChapter432EntropyDoctrine {

    public static let chapterTag: String =
        "chapter 四百三十二"
    public static let mNumberFirst: Int = 1100
    public static let mNumberLast: Int = 1103

    /// `v1` milestone:HARDWARE-AWARE SCHEDULER COMPOSITION
    /// at M1103。 First chapter where:
    ///   - The runtime engine reads BASMetalSubstrate
    ///     primitives at dispatch time
    ///   - A typed dispatch probe makes the consumption
    ///     observable + testable
    ///   - A typed scheduler consumes BASANECapability +
    ///     BASMetalKernelRegistry to make stage routing
    ///     decisions
    public static let v1MilestoneMNumber: Int = 1103
    public static let v1MilestoneStatus: String =
        "chapter-432-v1-hardware-aware-scheduler-composition"

    public static let knives:
        [(mNumber: Int, knife: String, concept: String)] =
    [
        (1100, "第一刀",
            "BASTurnRuntimeEngineConfiguration extension " +
            "— 3 new optional slots (runtimeMode + " +
            "metalKernelRegistry + aneCapability) + 3 " +
            "with(...) updaters。 BASHostKit gains " +
            "BASMetalSubstrate dependency。 Default config " +
            "preserves V1 byte-equality (ADR-014 OPT-IN)"),
        (1101, "第二刀",
            "BASTurnRuntimePlanDispatchProbe Sendable + " +
            "Codable typed snapshot + BASTurnRuntimeEngine " +
            "wires 3 config slots into actor storage + adds " +
            "lastPlanDispatchProbe/currentDispatchProbe " +
            "accessors + runWithPlan captures the probe " +
            "per call (proving the wiring fires)"),
        (1102, "第三刀",
            "BASHardwareAwareScheduler actor (~270 LOC) " +
            "+ BASStageAcceleratorHint (6-field) + " +
            "BASStageAcceleratorAssignment (5-field) + 3 " +
            "rationale enums。 Cost function: " +
            "(latency × thermalDerate) + (energy × " +
            "powerWeight) + opSupportPenalty。 First " +
            "consumer of M1097 capability + M1098 registry"),
        (1103, "第四刀",
            "chapter 四百三十二 v1 close-out doctrine + " +
            "Phase 2 doctrine bump (chapter count 26 → " +
            "27, mNumberLast 1099 → 1103, commitsShipped " +
            "133 → 137) + ADR-016.M1099 → ADR-016.M1103 " +
            "bump。 No default-mode flip — needs CI " +
            "dual-mode verification first")
    ]

    public static let entropyClassesAttacked: [String] = [
        "configuration-substrate-disconnect-entropy",  // M1100
        "dispatch-probe-observability-entropy",        // M1101
        "missing-hardware-aware-scheduler-entropy",    // M1102
        "doctrine-pin-entropy"                         // M1103
    ]

    public static let pinHeld: [String] = [
        "不变量 #1",
        "不变量 #2",
        "不变量 #3",
        "红线 7",
        "chapter 一百八十五",
        "chapter 二百一一",
        "chapter 三百九二",
        "ADR-014 OPT-IN preserved (.v1ByteEqual default + " +
        "nil registry + nil capability = byte-equal)",
        "ADR-016 (bumped M1103)",
        "系统熵 reduction",
        "RADICAL EVOLUTION SWEEP Phase F"
    ]

    public static let plannedFutureCuts: [String] = [
        "BASTurnRuntimeStagePlan per-stage acceleratorHint " +
        "wiring (touches every plan test;defer to " +
        "chapter 四百三十三+)",
        "BASNativeStageExecutor.executePlan consults " +
        "scheduler before each stage (depends on plan " +
        "wiring above)",
        "V2 default-mode flip from .v1ByteEqual to " +
        ".nativeV2 (needs CI dual-mode run via M1074 " +
        "BASStressSweepHarness over canonical60 fixture " +
        "set first)",
        "Live MLComputeDevice.allComputeDevices binding " +
        "inside BASANECapabilityProbe (deferred until " +
        "iOS 26 SDK MLCompute API stabilizes)",
        "Real-device benchmarks vs scheduler heuristic " +
        "costs — refines the cost function with measured " +
        "latency/energy on M2/M3/M4 + A17/A18 silicon"
    ]

    public static let summary: String =
        "RADICAL EVOLUTION SWEEP chapter 四百三十二 v1 " +
        "closes at M1103 — HARDWARE-AWARE SCHEDULER " +
        "COMPOSITION milestone。 Closes the consumption " +
        "gap between Phase E BASMetalSubstrate primitives " +
        "and the V2 runtime engine。 4 cuts ship " +
        "(M1100-M1103):" +
        "(1) BASTurnRuntimeEngineConfiguration 3-slot " +
        "extension (runtimeMode + registry + capability)," +
        "(2) BASTurnRuntimePlanDispatchProbe + engine " +
        "wiring + per-call probe capture," +
        "(3) BASHardwareAwareScheduler actor + typed " +
        "hint/assignment envelopes (first consumer of " +
        "M1097 capability + M1098 registry)," +
        "(4) chapter 四百三十二 v1 close-out + Phase 2 " +
        "doctrine bump + ADR-016 bump。 ADR-014 OPT-IN " +
        "preserved — no V1 hot path consumes the " +
        "scheduler yet;default config keeps engine in " +
        "v1ByteEqual mode with nil registry + nil " +
        "capability。 V1 byte-equality preserved (5,700+ " +
        "BAS tests pass)。 No default-mode flip — that " +
        "needs CI dual-mode evidence first。"
}
