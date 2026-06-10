// MARK: - BASANEKernelEligibilityClassifier
// chapter 五百 / M1377 — typed ANE eligibility classifier
//
// 原生利用神经引擎 (native ANE utilization) substantive
// push:typed answer to "which BASNeuralOp can the Apple
// Neural Engine actually run today,which are MPSGraph-
// only,and which fall back to CPU?"
//
// HONEST DOCTRINE NOTE — chapter 五百:
// =============================================================
// This classifier reflects HONEST Apple Silicon ANE
// capability per iOS 17+/macOS 14+ as of 2026-05-11。
// Each operation's tier is documented WITH evidence
// pointing to the underlying capability boundary:
//
//   - ANE-capable ops: matMul (via CoreML conversion or
//     direct ANE descriptors when available);attention
//     for shapes ANE supports
//   - MPSGraph-native ops: layerNorm,rmsNorm,softmax,
//     rotaryEmbedding,conv2D (ANE doesn't expose
//     these as native fused ops at this SDK version)
//   - Fallback-required ops: ssmScan (no native ANE
//     OR MPSGraph support — custom Metal shader OR
//     MLX bridge required;Tier 2 phase K work)
//
// The classifier provides a TYPED routing surface that
// future BASKernelRegistryDispatchExecutor can consult
// to choose the highest-tier available impl for each
// op + dataType + shape。 V1 byte-equality is preserved
// because today's executor doesn't yet consult the
// classifier — that wire-in is deferred to follow-up
// arc。
//
// T1.2 MEASURED CORRECTION (2026-06-11, 全面进化) —
// =============================================================
// `MLComputePlan` on two iPhone Airs planned ZERO ops onto the
// Neural Engine for BOTH production CoreML heads (context-
// classifier cpu=2/2;MiniLM gpu=164/164,with `.all` 14× SLOWER
// than the deliberate `.cpuOnly`)。 The tiers below therefore
// describe OP-TYPE CAPABILITY,NOT PLACEMENT:the CoreML planner
// weighs model size/precision/shape and,at production-head
// scale,picks CPU/GPU — never ANE。 The Swift identifier was
// renamed `aneNative` → `aneCapable` to pin this semantics
// (raw value "ane-native" KEPT — it rides audit evidence
// strings + Codable wire bytes;ADR-014)。 Any future claim of
// actual ANE placement must re-run the BAS_ANE_PROBE and show
// `ane=` in the per-op histogram + win a paired latency gate。
// Details: Docs/ANE_UTILIZATION_FINDINGS.md。

import Foundation
import BASRuntimeCore

/// Typed ANE-eligibility tier for a BASNeuralOp。
public enum BASANEEligibilityTier:
    String, Codable, Sendable, Equatable, Hashable, CaseIterable
{
    /// Op TYPE is ANE-capable (CoreML ML Program conversion or
    /// direct ANE descriptors expose it)。 Capability,NOT
    /// placement:T1.2 measured the planner placing ZERO ops on
    /// the ANE for the production heads — whether a given model
    /// actually lands there depends on size/precision/shape and
    /// must be proven per-model via `MLComputePlan`
    /// (Docs/ANE_UTILIZATION_FINDINGS.md)。 Raw value "ane-native"
    /// KEPT for audit/Codable byte stability (ADR-014;pinned by
    /// test)。
    case aneCapable = "ane-native"

    /// Op runs on GPU via MPSGraph fused operators。 ANE
    /// doesn't expose this op natively at the current
    /// SDK version,but MPSGraph dispatch is still
    /// hardware-accelerated。 Medium priority。
    case mpsGraphNative = "mpsgraph-native"

    /// Op requires custom Metal compute shader OR external
    /// bridge (MLX-swift,vendored mlx-swift-lm)。 Falls
    /// back to CPU stub when none available。 Lowest
    /// priority — Tier 2 phase K external work required
    /// for first-class support。
    case fallbackRequired = "fallback-required"
}

/// Typed classifier surface for BASNeuralOp ANE
/// eligibility。 Provides honest evidence per op
/// describing why it lives in its tier。
public enum BASANEKernelEligibilityClassifier {

    /// Classify the given BASNeuralOp。 Result reflects
    /// HONEST current Apple Silicon capability per
    /// iOS 17+/macOS 14+。 Stable across chapter 500
    /// close-out;updates only when SDK boundaries shift。
    public static func tier(
        for op: BASNeuralOp
    ) -> BASANEEligibilityTier {
        switch op {
        case .matMul,
             .attention:
            return .aneCapable
        case .rmsNorm,
             .layerNorm,
             .softmax,
             .rotaryEmbedding,
             .conv2D:
            return .mpsGraphNative
        case .ssmScan:
            return .fallbackRequired
        }
    }

    /// Typed evidence string per op describing why it
    /// lives in its tier。 Suitable for audit emission
    /// + doctrine walker grep。
    public static func evidence(
        for op: BASNeuralOp
    ) -> String {
        switch op {
        // T1.2 correction: capability-not-placement language。 The
        // "ane-native:" raw-value prefix is KEPT (doctrine-walker
        // grep + audit-byte stability);the claim after the colon
        // no longer asserts placement — MLComputePlan measured zero
        // ANE ops for the production heads (ANE_UTILIZATION_FINDINGS)。
        case .matMul:
            return "ane-native:matmul is an ANE-CAPABLE op type" +
                " (CoreML ML Program exposes it);actual placement" +
                " is planner-decided per model — T1.2 measured CPU" +
                " for the production heads"
        case .attention:
            return "ane-native:transformer attention is an" +
                " ANE-CAPABLE op type for supported shapes;actual" +
                " placement is planner-decided per model — T1.2" +
                " measured zero ANE ops for the production heads"
        case .rmsNorm:
            return "mpsgraph-native:MPSGraph rsqrt +" +
                " elementwise composition (no native ANE)"
        case .layerNorm:
            return "mpsgraph-native:MPSGraph mean +" +
                " variance + scale-shift (no native ANE)"
        case .softmax:
            return "mpsgraph-native:MPSGraph softmax" +
                "WithAxis (no native ANE fused op)"
        case .rotaryEmbedding:
            return "mpsgraph-native:MPSGraph sin/cos" +
                " elementwise (no native ANE)"
        case .conv2D:
            return "mpsgraph-native:MPSGraph conv2D" +
                " (older ANE versions support;M-series" +
                " uses MPSGraph for stability)"
        case .ssmScan:
            return "fallback-required:Mamba SSM" +
                " selective scan unsupported by both ANE" +
                " and MPSGraph;custom Metal shader OR" +
                " MLX bridge required (Tier 2 phase K)"
        }
    }

    /// All operations in a given tier — useful for
    /// scheduler routing。
    public static func operations(
        inTier targetTier: BASANEEligibilityTier
    ) -> [BASNeuralOp] {
        BASNeuralOp.allCases.filter {
            tier(for: $0) == targetTier
        }
    }

    /// Indicates whether the substrate's BASKernelRegistry
    /// DispatchExecutor consults this classifier at
    /// chapter 500 close-out。 FALSE — wire-in deferred
    /// to follow-up arc。 Honest scope acknowledgment。
    ///
    /// chapter 九百九十八 / M3695 update:still FALSE at this
    /// invariant level (a static-let cannot reflect runtime
    /// state),BUT see the new `executorConsultationCount`
    /// counter below — production executor side now DOES
    /// consult the classifier via `BASAutoRouteRanker
    /// .consultANE(for:)`,and that counter increments per
    /// call。 The invariant `consultedByExecutorInProduction`
    /// at chapter-500 doctrine semantics meant "the substrate's
    /// runtime dispatch path branches on this classifier's
    /// output" — that is STILL false (ch 998 only adds an
    /// observe-only consultation that records the tier into
    /// audit but doesn't branch dispatch logic on it)。
    ///
    /// Future arc (post-ch-998) can flip this to true by
    /// wiring `tier(for:)` into the actual kernel-choice
    /// branches in `BASAutoRouteRanker.softmaxChoice` /
    /// `matMulChoice` / etc。 ch 998 closes the smaller gap:
    /// "no production consultation at all" → "at least one
    /// production-side caller invokes the classifier per
    /// dispatch"。
    public static let consultedByExecutorInProduction: Bool =
        false

    /// chapter 一千零十四 / M3785 — 全面 一次性 gap closure
    /// HONEST SPLIT of the chapter-500 invariant。 The original
    /// flag `consultedByExecutorInProduction` carries the
    /// SEMANTIC「runtime dispatch path branches on tier」,which
    /// is STILL false (ch 998-1000.5 added observe-only
    /// counting,not dispatch branching)。
    ///
    /// But hosts reading this static-let directly via grep
    /// have no easy way to distinguish:
    ///   - "tier IS read by executor" (true since ch 998)
    ///   - "tier IS NOT branched on by executor" (still true)
    ///
    /// This companion flag closes that doctrine gap honestly。
    /// It DOES NOT change substrate behavior — substrate still
    /// observe-only,dispatch still unchanged。 The flag exists
    /// to make the actually-true state machine-readable for
    /// audit + scaffold inventory replay。
    ///
    /// True since ch 998 (`BASCognitiveBrain.recordANEConsultation`
    /// is the production read site)。 Future tier-based dispatch
    /// arc (Phase 9++) will flip
    /// `consultedByExecutorInProduction` to true ALONGSIDE
    /// keeping `tierReadByExecutorInProduction` true。 The two
    /// flags then encode the full state machine:
    ///   - (read=F, branch=F) — pre-ch-998 (frozen 497 chapters)
    ///   - (read=T, branch=F) — current state (ch 998-1014)
    ///   - (read=T, branch=T) — future tier-dispatch arc
    ///   - (read=F, branch=T) — illegal (would mean dispatch
    ///     branches on a value the executor doesn't read)
    public static let tierReadByExecutorInProduction: Bool =
        true

    /// chapter 九百九十八 / M3695 — runtime counter incremented
    /// by `BASAutoRouteRanker.consultANE(for:)` each time the
    /// production executor side consults the classifier。 Lets
    /// tests + audit prove that production code paths ARE
    /// reaching the classifier。 Pre-ch-998 this counter
    /// stayed at 0 across the entire arc — confirming
    /// consultedByExecutorInProduction=false。 Post-ch-998 the
    /// counter increments on each consultation,proving the
    /// observe-only wire is live。
    ///
    /// Note:this is a `nonisolated(unsafe)` static var because
    /// it's incremented from synchronous static contexts and
    /// observed from sync tests。 Concurrent increments may
    /// race + lose updates (the counter is an APPROXIMATE
    /// observability signal,not a strict counter)。 Hosts
    /// requiring exact counting should add their own
    /// instrumented wrapper around consultANE。
    nonisolated(unsafe)
    public static var executorConsultationCount: Int = 0
}
