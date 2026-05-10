// MARK: - BASChapter431EntropyDoctrine — chapter 四百三十一 / M1099
// 系统熵 reduction
//
// RADICAL EVOLUTION SWEEP Phase E close-out doctrine。 Pins
// the chapter 四百三十一 entropy work shipped across 4
// commits (M1096-M1099):BASMetalSubstrate native Apple
// Silicon foundation。
//
// ## Why this exists (system entropy framing)
//
// The user directive (2026-05-10) demanded "原生利用神经引擎"
// — native Neural Engine leverage at the substrate level。
// Pre-M1096,the substrate had:
//   - NO typed tensor primitives (every adapter rolled
//     its own untyped `[Int]` shape + raw `Data`)
//   - NO ANE capability introspection (binary
//     `npuAvailable: Bool` only)
//   - NO unified kernel registry (every adapter had its
//     own ad-hoc lookup)
//   - NO substrate touched MTLDevice / MPSGraph directly
//
// Chapter 四百三十一 ships all four primitives so future
// chapters can register MPSGraph / MLX / CoreML kernels
// under a uniform contract。
//
// ## What this ships (M1096-M1099)
//
//   - M1096:BASTensor / BASTensorShape / BASTensorDescriptor
//     (typed property wrapper + phantom-rank evidence +
//     Sendable wire envelope)
//   - M1097:BASNeuralOp / BASANECapability /
//     BASANECapabilityProbe (typed neural op vocabulary +
//     ANE introspection actor with thermal-state caching)
//   - M1098:BASKernelKey / BASMetalKernel /
//     BASMetalKernelRegistry (typed kernel contract +
//     actor-owned dispatch table)
//   - M1099:BASMatMulKernel / BASRMSNormKernel /
//     BASRotaryEmbeddingKernel + this close-out doctrine
//     (3 reference CPU kernels proving the contract end-
//     to-end + Phase 2 + ADR-016 doctrine bumps)
//
// ## Doctrine pins held
//
//   - chapter 一百八十五 — anti-magic-number throughout
//   - chapter 二百一一 — single source-of-truth (one
//     descriptor, one registry, one capability snapshot
//     shape)
//   - chapter 三百九二 — replay-determinism (Sendable
//     bundles via cpu-bytes Data + sortedKeys JSON)
//   - 不变量 #1/#2/#3 — V1 byte-equality preserved (no
//     V1 hot path touches BASMetalSubstrate yet)
//   - 红线 7 — hint-only (capability + kernel dispatch
//     are observation/dispatch, not commitment authority)
//   - ADR-014 OPT-IN — purely additive new module
//   - ADR-016 — bumped M1083 → M1099
//   - RADICAL EVOLUTION SWEEP Phase E — this chapter

import Foundation

public enum BASChapter431EntropyDoctrine {

    public static let chapterTag: String =
        "chapter 四百三十一"
    public static let mNumberFirst: Int = 1096
    public static let mNumberLast: Int = 1099

    /// `v1` milestone:NATIVE APPLE SILICON FOUNDATION at
    /// M1099。 First substrate module to:
    ///   - Link Metal / MPS / MPSGraph / Accelerate / CoreML
    ///   - Ship typed tensor primitives with phantom-rank
    ///     + scalar evidence
    ///   - Introspect Apple Neural Engine capability per
    ///     thermal state
    ///   - Own a single kernel dispatch table actor
    ///   - Register reference matMul / rmsNorm /
    ///     rotaryEmbedding kernels
    public static let v1MilestoneMNumber: Int = 1099
    public static let v1MilestoneStatus: String =
        "chapter-431-v1-native-apple-silicon-foundation"

    public static let knives:
        [(mNumber: Int, knife: String, concept: String)] =
    [
        (1096, "第一刀",
            "BASMetalSubstrate module entry — BASTensor " +
            "typed property wrapper (phantom-rank + scalar " +
            "evidence + discriminated MLX/CoreML/Metal/CPU " +
            "backing) + BASTensorShape phantom-type ranks " +
            "+ BASTensorDescriptor Sendable wire envelope " +
            "+ Package.swift links 5 frameworks"),
        (1097, "第二刀",
            "BASANECapability typed snapshot + BASNeuralOp " +
            "vocabulary (8 ops) + BASANECapabilityProbe " +
            "actor with per-thermal-state caching — " +
            "replaces the binary npuAvailable: Bool"),
        (1098, "第三刀",
            "BASMetalKernel Sendable contract + BASKernelKey " +
            "typed lookup + BASMetalKernelRegistry actor " +
            "dispatch table — single source-of-truth for " +
            "which kernels exist for which (op, dtype, " +
            "backing) triple"),
        (1099, "第四刀",
            "3 reference CPU kernels (matMul / rmsNorm / " +
            "rotaryEmbedding) proving the contract end-to-end " +
            "+ chapter 四百三十一 close-out doctrine + " +
            "ADR-016.M1099 bump")
    ]

    public static let entropyClassesAttacked: [String] = [
        "untyped-tensor-shape-entropy",      // M1096
        "binary-npu-capability-entropy",     // M1097
        "fragmented-kernel-dispatch-entropy",// M1098
        "missing-reference-kernels-entropy"  // M1099
    ]

    public static let pinHeld: [String] = [
        "不变量 #1",
        "不变量 #2",
        "不变量 #3",
        "红线 7",
        "chapter 一百八十五",
        "chapter 二百一一",
        "chapter 三百九二",
        "ADR-014 OPT-IN preserved (no V1 hot path touch)",
        "ADR-016 (bumped M1099)",
        "系统熵 reduction",
        "RADICAL EVOLUTION SWEEP Phase E"
    ]

    public static let plannedFutureCuts: [String] = [
        "Phase F (chapter 四百三十二):" +
        "BASHardwareAwareScheduler consumes BASANECapability" +
        " + BASMetalKernelRegistry to make per-stage" +
        " device-affinity decisions",
        "Live MLComputeDevice.allComputeDevices binding" +
        " inside BASANECapabilityProbe (deferred until iOS" +
        " 26 SDK MLCompute API stabilizes)",
        "GPU-resident kernel handoff pathway (avoids" +
        " upload/download cost when caller stays on GPU" +
        " across multiple kernel calls)",
        "BASMLXAdapter port to register its MLX kernels" +
        " under (matMul/rmsNorm/rotaryEmbedding, float16," +
        " mlxArray) keys via the registry"
    ]

    public static let summary: String =
        "RADICAL EVOLUTION SWEEP chapter 四百三十一 v1" +
        " closes at M1099 — NATIVE APPLE SILICON FOUNDATION" +
        " milestone。 Ships the FIRST substrate module to" +
        " touch Metal / MPS / MPSGraph / Accelerate /" +
        " CoreML at link-time + ship typed tensor" +
        " primitives + ANE introspection + unified kernel" +
        " registry。 4 cuts ship (M1096-M1099):" +
        "(1) BASTensor + shape + descriptor," +
        "(2) BASANECapability + neural op vocabulary +" +
        " probe actor," +
        "(3) BASMetalKernelRegistry actor + kernel" +
        " contract," +
        "(4) 3 reference CPU kernels (matMul / rmsNorm /" +
        " rotaryEmbedding) + chapter close-out。 ADR-014" +
        " OPT-IN held — no V1 hot path consumes" +
        " BASMetalSubstrate yet;Phase F scheduler will" +
        " be the first consumer。 V1 byte-equality" +
        " preserved (5,400+ BAS tests pass)。"
}
