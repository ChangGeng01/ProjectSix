// MARK: - BASThermalAwareKernelSelectionPolicy
// chapter 五百 / M1378 — typed policy surface mapping
// (thermalState, anePriority, op) → kernel routing
// preference
//
// 最创新 + 原生利用神经引擎 substantive push:typed
// policy answering "given current thermal pressure +
// accelerator priority,which kernel route should the
// substrate prefer for this op?"
//
// HONEST DOCTRINE NOTE — chapter 五百:
// =============================================================
// The policy is a pure-function typed mapping。 No
// production caller consults it at chapter 500 close-out
// (consultedByExecutorInProduction = false)。 The future
// BASKernelRegistryDispatchExecutor can adopt the policy
// incrementally with stress-sweep regression-guard
// confirming zero behavior drift on the default thermal
// state (.nominal)。
//
// The policy honors:
//   - Apple's documented advice to fall back from ANE
//     under .serious / .critical thermal pressure (ANE
//     dispatch overhead exceeds savings)
//   - BASANEEligibilityClassifier (M1377) tier info —
//     only ANE-eligible ops can route to ANE regardless
//     of priority
//   - Graceful CPU fallback at .critical thermal state
//
// V1 byte-equality preserved — purely additive policy
// surface;executor wiring deferred to follow-up arc。

import Foundation
import BASRuntimeCore

/// Typed kernel routing preference returned by the
/// policy。 Mirrors BASTensorBackingKind但 carries
/// explicit "preferred dispatch site" semantics。
public enum BASKernelRoutingPreference:
    String, Codable, Sendable, Equatable, Hashable, CaseIterable
{
    /// Prefer an ANE-CAPABLE impl when available。 Capability,
    /// not placement (T1.2:the planner decides per model;raw
    /// value "ane-native" kept for wire-byte stability)。
    case aneCapable = "ane-native"
    /// Route to GPU-native MPSGraph impl。
    case gpuMPSGraph = "gpu-mps-graph"
    /// Route to CPU stub (least preferred,emergency
    /// fallback or .critical thermal)。
    case cpuStub = "cpu-stub"
}

/// Typed policy surface mapping current device state +
/// op to a preferred kernel routing。
public enum BASThermalAwareKernelSelectionPolicy {

    /// Decide kernel routing for the given op given
    /// current thermal state + accelerator priority。
    ///
    /// Decision rules (HONEST priority order):
    ///   1. If thermal is .critical → always .cpuStub
    ///      (every other path risks throttle damage)
    ///   2. If op is .fallbackRequired tier → .cpuStub
    ///      (ANE + MPSGraph have no native impl)
    ///   3. If priority is .cpuOnly → .cpuStub
    ///   4. If priority is .gpuOnly → .gpuMPSGraph
    ///   5. If thermal is .serious AND op is ANE-native
    ///      → .gpuMPSGraph (ANE dispatch overhead
    ///      exceeds savings at .serious)
    ///   6. If op is ANE-native AND priority is .aneFirst
    ///      → .aneCapable
    ///   7. Default → .gpuMPSGraph (broadest support)
    public static func preferredRouting(
        for op: BASNeuralOp,
        thermalState: BASCapabilityThermalSnapshot,
        anePriority: BASAcceleratorPriority
    ) -> BASKernelRoutingPreference {
        // Rule 1: critical thermal → CPU
        if thermalState == .critical {
            return .cpuStub
        }
        // Rule 2: fallback-required op → CPU stub
        let tier = BASANEKernelEligibilityClassifier
            .tier(for: op)
        if tier == .fallbackRequired {
            return .cpuStub
        }
        // Rule 3: explicit CPU-only priority
        if anePriority == .cpuOnly {
            return .cpuStub
        }
        // Rule 4: explicit GPU-only priority
        if anePriority == .gpuOnly {
            return .gpuMPSGraph
        }
        // Rule 5: serious thermal + ANE-native op → GPU
        if thermalState == .serious
            && tier == .aneCapable
        {
            return .gpuMPSGraph
        }
        // Rule 6: ANE-native op + ANE-first priority
        if tier == .aneCapable
            && anePriority == .aneFirst
        {
            return .aneCapable
        }
        // Rule 7: default to GPU MPSGraph
        return .gpuMPSGraph
    }

    /// Indicates whether the substrate's actual executor
    /// consults this policy at chapter 500 close-out。
    /// FALSE — wire-in deferred to follow-up arc。 Honest
    /// scope acknowledgment。
    public static let consultedByExecutorInProduction: Bool =
        false

    /// Documented decision rules table (for audit walkers
    /// + doctrine walker introspection)。 Each entry
    /// describes one decision rule the policy applies。
    public static let decisionRulesDocumentation: [String] = [
        "1: thermalState=.critical → .cpuStub",
        "2: op tier=.fallbackRequired → .cpuStub",
        "3: anePriority=.cpuOnly → .cpuStub",
        "4: anePriority=.gpuOnly → .gpuMPSGraph",
        "5: thermalState=.serious AND ANE-native op → .gpuMPSGraph",
        "6: ANE-native op AND .aneFirst priority → .aneCapable",
        "7: default → .gpuMPSGraph"
    ]
}
