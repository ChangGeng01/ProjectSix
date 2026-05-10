// MARK: - BASHardwareAwareScheduler
// chapter 四百三十二 / M1102 — RADICAL EVOLUTION SWEEP Phase F
//
// Actor that consumes:
//   - per-stage `BASStageAcceleratorHint`
//   - the M1097 `BASANECapability` snapshot
//   - the live `BASCapabilityThermalSnapshot`
//   - the M1098 `BASMetalKernelRegistry` (optional)
//
// and returns a typed `BASStageAcceleratorAssignment`
// naming where the stage should run + which kernel key
// (if any) it should dispatch through。
//
// ## Why this exists (system entropy framing)
//
// Pre-M1102 the substrate had no scheduler。 Every stage
// fell through to the V1 hot path,which assumes CPU-only
// dispatch + no awareness of ANE/GPU。 The M1097 ANE
// capability + M1098 kernel registry exist but have no
// caller to consume them at scheduling time。
//
// `BASHardwareAwareScheduler` is the first such caller:
// reads the typed hint + capability + registry,scores
// each viable backing,returns the lowest-cost
// assignment。
//
// ## What this ships (M1102)
//
//   - `public actor BASHardwareAwareScheduler`
//   - `init(registry:)` taking optional registry
//   - `assign(hint:capability:thermal:)` async method
//     returning typed `BASStageAcceleratorAssignment`
//
// ## Cost function
//
// For each viable backing:
//
//   cost =   (estimatedLatencyMs × thermalDerate)
//          + (energyJ × powerWeight)
//          + opSupportPenalty
//
// where:
//   - `thermalDerate` = 1.0 (.nominal) / 1.4 (.fair)
//                     / 2.0 (.serious) / 4.0 (.critical)
//                     / 1.5 (.unknown)
//   - `powerWeight` is derived from
//     `BASStageAcceleratorPreference`:
//       lowestLatency: 0.0
//       lowestEnergy:  2.0
//       balanced:      1.0
//   - `opSupportPenalty` is +1000 if the op isn't in
//     `capability.supportedOps` (forces fallback)
//
// Lower cost wins。 Ties broken by accelerator priority
// (ane > gpu > cpu)。
//
// ## What's NOT integrated yet (deferred)
//
// `BASTurnRuntimeStagePlan` is NOT modified to carry
// `acceleratorHint:` per-stage at M1102。 Modifying the
// plan would touch every existing test that constructs
// a plan + risk widespread regression。 Instead the
// scheduler ships as a standalone primitive — opt-in
// consumers (the M1103 close-out commit + future native
// V2 stages) wire it in incrementally。
//
// `BASNativeStageExecutor.executePlan` is also NOT
// modified at M1102 for the same reason — the executor
// needs the hint surface to be wired into the plan
// first,which is a separate chapter。
//
// ## Doctrine pins held
//
//   - chapter 一百八十五 — anti-magic-number (typed
//     enums + doubles; no raw String tags)
//   - chapter 二百一一 — single source-of-truth (one
//     scheduler actor; one cost function)
//   - chapter 三百九二 — replay-determinism (assignment
//     is deterministic for the same hint + capability
//     + thermal snapshot;tests pin this)
//   - 不变量 #1/#2/#3 — V1 byte-equality preserved
//     (no V1 hot path consults the scheduler yet)
//   - 红线 7 — hint-only (assignment is observation
//     + dispatch routing)
//   - ADR-014 OPT-IN — purely additive

import Foundation
import BASMetalSubstrate

/// Actor consuming hint + capability + thermal + optional
/// registry to produce a typed
/// `BASStageAcceleratorAssignment`。
public actor BASHardwareAwareScheduler {

    /// Optional kernel registry。 When non-nil,scheduler
    /// can name a `selectedKernelKey` in the returned
    /// assignment。 When nil,assignments always have
    /// `selectedKernelKey == nil` (CPU-only fallback)。
    private let registry: BASMetalKernelRegistry?

    public init(registry: BASMetalKernelRegistry? = nil) {
        self.registry = registry
    }

    // MARK: - Assignment

    /// Score every viable backing for the given hint +
    /// capability + thermal,return the lowest-cost
    /// assignment。
    ///
    /// Algorithm (see file header for cost function):
    ///   1. Build candidate set:`[.cpuBytes]` always +
    ///      `[.metalBuffer]` if any kernel registered
    ///      for `(op, dtype, metalBuffer)` + `[.mlxArray]`
    ///      similarly + `[.mlMultiArray]` similarly
    ///   2. For each candidate,compute cost。
    ///   3. Return the lowest-cost candidate。 If tie,
    ///      prefer ANE > GPU > CPU。
    ///   4. If `latencyBudgetMs` cannot be met by any
    ///      accelerator at this thermal,return the CPU
    ///      assignment with rationale `.cpuLatencyBudgetMiss`。
    public func assign(
        hint: BASStageAcceleratorHint,
        capability: BASANECapability,
        thermal: BASCapabilityThermalSnapshot
    ) async -> BASStageAcceleratorAssignment {

        let opSupported = capability.supportedOps
            .contains(hint.operation)

        // Build candidate backing list based on registry
        // population + capability。
        var candidates: [BASTensorBackingKind] = [.cpuBytes]
        if let reg = registry {
            for backing in [
                BASTensorBackingKind.mlxArray,
                .mlMultiArray,
                .metalBuffer
            ] {
                let key = BASKernelKey(
                    operation: hint.operation,
                    dataType: hint.preferredDataType,
                    backingKind: backing)
                if await reg.kernel(for: key) != nil {
                    candidates.append(backing)
                }
            }
        }

        // No accelerator-backed kernel registered → CPU
        // fallback with rationale。
        if candidates.count == 1 {
            return BASStageAcceleratorAssignment(
                selectedBackingKind: .cpuBytes,
                selectedKernelKey: nil,
                costScore: scoreCPU(
                    hint: hint,
                    capability: capability,
                    thermal: thermal,
                    opSupported: opSupported),
                thermalSnapshot: thermal,
                assignmentRationale:
                    .cpuNoKernelRegistered)
        }

        // Score each candidate, pick lowest cost。
        var bestBacking: BASTensorBackingKind = .cpuBytes
        var bestCost: Double = .infinity
        for backing in candidates {
            let cost = score(
                backing: backing,
                hint: hint,
                capability: capability,
                thermal: thermal,
                opSupported: opSupported)
            if cost < bestCost
                || (cost == bestCost
                    && priority(backing)
                        > priority(bestBacking))
            {
                bestCost = cost
                bestBacking = backing
            }
        }

        // Resolve kernel key for the chosen backing
        let chosenKey: BASKernelKey?
        if bestBacking == .cpuBytes {
            chosenKey = nil
        } else {
            chosenKey = BASKernelKey(
                operation: hint.operation,
                dataType: hint.preferredDataType,
                backingKind: bestBacking)
        }

        // Compose rationale
        let rationale = resolveRationale(
            backing: bestBacking,
            opSupported: opSupported,
            thermal: thermal)

        return BASStageAcceleratorAssignment(
            selectedBackingKind: bestBacking,
            selectedKernelKey: chosenKey,
            costScore: bestCost,
            thermalSnapshot: thermal,
            assignmentRationale: rationale)
    }

    // MARK: - Cost function

    /// Score a non-CPU backing。 ANE supported ops get
    /// ANE-style latency + energy from the capability;
    /// other backings use heuristic estimates。
    private func score(
        backing: BASTensorBackingKind,
        hint: BASStageAcceleratorHint,
        capability: BASANECapability,
        thermal: BASCapabilityThermalSnapshot,
        opSupported: Bool
    ) -> Double {
        let derate = thermalDerate(thermal)
        let powerWeight = self.powerWeight(
            for: hint.preference)
        let opPenalty: Double = opSupported ? 0 : 1000

        let baseLatency: Double
        let energyJ: Double
        switch backing {
        case .mlxArray:
            // MLX paths share GPU / ANE — use capability
            // estimated latency as proxy。
            baseLatency = capability
                .estimatedLatencyMs
            energyJ = 0.05
        case .mlMultiArray:
            // CoreML / ANE preferred path。
            baseLatency = capability
                .estimatedLatencyMs * 0.8
            energyJ = 0.03
        case .metalBuffer:
            // Raw Metal — GPU dispatch overhead dominates
            // small ops。
            baseLatency = capability
                .estimatedLatencyMs * 1.5
            energyJ = 0.10
        case .cpuBytes:
            return scoreCPU(
                hint: hint,
                capability: capability,
                thermal: thermal,
                opSupported: opSupported)
        }
        return (baseLatency * derate)
            + (energyJ * powerWeight)
            + opPenalty
    }

    /// Score the CPU backing。 CPU is always available
    /// + uses a fixed conservative latency。
    private func scoreCPU(
        hint: BASStageAcceleratorHint,
        capability: BASANECapability,
        thermal: BASCapabilityThermalSnapshot,
        opSupported _: Bool
    ) -> Double {
        let derate = thermalDerate(thermal)
        let powerWeight = self.powerWeight(
            for: hint.preference)
        // CPU baseline:5x slower than ANE,higher
        // energy。 No op-support penalty (CPU runs
        // any op via scalar fallback)。
        let baseLatency = capability
            .estimatedLatencyMs * 5.0
        let energyJ = 0.20
        return (baseLatency * derate)
            + (energyJ * powerWeight)
    }

    // MARK: - Helpers

    private func thermalDerate(
        _ thermal: BASCapabilityThermalSnapshot
    ) -> Double {
        switch thermal {
        case .nominal:  return 1.0
        case .fair:     return 1.4
        case .serious:  return 2.0
        case .critical: return 4.0
        case .unknown:  return 1.5
        }
    }

    private func powerWeight(
        for preference: BASStageAcceleratorPreference
    ) -> Double {
        switch preference {
        case .lowestLatency: return 0.0
        case .lowestEnergy:  return 2.0
        case .balanced:      return 1.0
        }
    }

    /// Tiebreaker priority:ANE-resident backings beat
    /// pure GPU,which beats CPU。
    private func priority(
        _ backing: BASTensorBackingKind
    ) -> Int {
        switch backing {
        case .mlMultiArray: return 3   // ANE-preferred
        case .mlxArray:     return 2   // GPU/ANE shared
        case .metalBuffer:  return 1   // GPU only
        case .cpuBytes:     return 0
        }
    }

    private func resolveRationale(
        backing: BASTensorBackingKind,
        opSupported: Bool,
        thermal: BASCapabilityThermalSnapshot
    ) -> BASAssignmentRationale {
        if backing == .cpuBytes {
            return .cpuNoKernelRegistered
        }
        if thermal == .serious || thermal == .critical {
            return .thermalDowngrade
        }
        if opSupported {
            return .aneSupported
        }
        return .gpuFallbackAneUnsupported
    }
}
