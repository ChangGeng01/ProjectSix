// MARK: - BASStageAcceleratorHint
// chapter 四百三十二 / M1102 — RADICAL EVOLUTION SWEEP Phase F
//
// Caller's typed hint about a single stage's compute
// requirements。 Consumed by `BASHardwareAwareScheduler`
// alongside the M1097 `BASANECapability` + the live
// `BASDeviceState` to produce a `BASStageAcceleratorAssignment`。
//
// ## Why this exists (system entropy framing)
//
// Today every stage in `BASTurnRuntimeStagePlan` is opaque
// to the runtime — there's no typed surface for "this
// stage runs an attention op" or "this stage needs
// Float16"。 The hardware-aware scheduler cannot make
// device-affinity decisions without that information,so
// today every stage falls through to the V1 hot path。
//
// `BASStageAcceleratorHint` is the typed surface:caller
// names the op,dtype,batch/seq budgets,and the energy
// vs latency preference per stage。 The scheduler reads
// the hint + matches against the registered kernels +
// ANE capability to return a typed assignment。
//
// ## What this ships (M1102)
//
//   - `BASStageAcceleratorHint` Sendable + Codable +
//     Equatable struct with 6 fields:
//       * `operation: BASNeuralOp`
//       * `preferredDataType: BASTensorDataType`
//       * `batchSize: Int`
//       * `sequenceLength: Int`
//       * `latencyBudgetMs: Double`
//       * `preference: BASStageAcceleratorPreference`
//   - `BASStageAcceleratorPreference` enum (3 cases:
//     `.lowestLatency` / `.lowestEnergy` / `.balanced`)
//
// ## Doctrine pins held
//
//   - chapter 一百八十五 — anti-magic-number (typed
//     enums + counts; no raw String budget tags)
//   - chapter 二百一一 — single source-of-truth (one
//     hint shape; scheduler consumes this same shape)
//   - chapter 三百九二 — replay-determinism (Sendable
//     + Codable via String-rawvalue enums)
//   - 不变量 #1/#2/#3 — V1 byte-equality preserved
//     (hint is pure observation; default routing skips
//     scheduler when hint is absent)
//   - 红线 7 — hint-only by definition
//   - ADR-014 OPT-IN — purely additive

import Foundation
import BASMetalSubstrate

// MARK: - Preference enum

/// Caller's tradeoff preference for the scheduler's
/// cost function。 Adjusts the relative weight of
/// latency vs energy in the assignment decision。
public enum BASStageAcceleratorPreference:
    String, Codable, Equatable, Hashable, Sendable, CaseIterable
{

    /// Minimize latency at any energy cost。 Prefers
    /// ANE > GPU > CPU when all support the op。
    case lowestLatency = "lowest-latency"

    /// Minimize energy at any latency cost。 Prefers
    /// ANE > CPU > GPU (ANE is most energy-efficient
    /// for supported ops;CPU beats GPU for small ops
    /// where GPU dispatch overhead dominates)。
    case lowestEnergy = "lowest-energy"

    /// Equal weight — default policy。 Scheduler
    /// uses the cost function with equal latency +
    /// energy weights。
    case balanced = "balanced"
}

// MARK: - Hint struct

/// Caller's typed hint about a single stage's compute
/// requirements。 Consumed by `BASHardwareAwareScheduler`
/// to choose a `BASStageAcceleratorAssignment`。
public struct BASStageAcceleratorHint:
    Equatable, Hashable, Codable, Sendable
{

    /// The neural op this stage runs。 Used by the
    /// scheduler to query the kernel registry for
    /// "which backings have a kernel for this op"。
    public let operation: BASNeuralOp

    /// Preferred element dtype。 Float16 is preferred
    /// for ANE supported ops;Float32 is the safe
    /// fallback。
    public let preferredDataType: BASTensorDataType

    /// Batch size for this stage's tensor inputs。 Used
    /// by the scheduler to check against
    /// `BASANECapability.maxBatchSize`。
    public let batchSize: Int

    /// Sequence length for this stage's tensor inputs
    /// (or 1 for non-sequential ops like matMul)。
    public let sequenceLength: Int

    /// Caller's latency budget for this stage in
    /// milliseconds。 The scheduler may downgrade to
    /// CPU if no accelerator can meet the budget at
    /// the current thermal state。
    public let latencyBudgetMs: Double

    /// Tradeoff preference (latency vs energy)。
    public let preference: BASStageAcceleratorPreference

    public init(
        operation: BASNeuralOp,
        preferredDataType: BASTensorDataType,
        batchSize: Int,
        sequenceLength: Int,
        latencyBudgetMs: Double,
        preference: BASStageAcceleratorPreference =
            .balanced
    ) {
        self.operation = operation
        self.preferredDataType = preferredDataType
        self.batchSize = batchSize
        self.sequenceLength = sequenceLength
        self.latencyBudgetMs = latencyBudgetMs
        self.preference = preference
    }
}
