// MARK: - BASStageAcceleratorAssignment
// chapter 四百三十二 / M1102 — RADICAL EVOLUTION SWEEP Phase F
//
// Scheduler's typed answer to "where should this stage
// run"。 Returned by `BASHardwareAwareScheduler.assign(...)`。
//
// ## Why this exists (system entropy framing)
//
// The scheduler's decision is more than "use ANE" — it
// must also report:
//   - which backing kind (mlxArray / mlMultiArray /
//     metalBuffer / cpuBytes) the stage should produce
//   - the kernel key the stage should dispatch through
//     (or nil if no kernel registered → CPU fallback)
//   - the cost score that drove the choice (for audit
//     replay + scheduler tuning)
//   - the thermal snapshot the decision was made at
//     (so replay sees deterministic decisions)
//
// `BASStageAcceleratorAssignment` is the typed envelope
// for all four dimensions。
//
// ## What this ships (M1102)
//
//   - `BASStageAcceleratorAssignment` Sendable + Codable
//     + Equatable struct with 5 fields:
//       * `selectedBackingKind: BASTensorBackingKind`
//       * `selectedKernelKey: BASKernelKey?`
//       * `costScore: Double` (lower is better)
//       * `thermalSnapshot: BASCapabilityThermalSnapshot`
//       * `assignmentRationale: BASAssignmentRationale`
//   - `BASAssignmentRationale` enum (5 cases naming
//     why the scheduler chose this assignment)
//
// ## Doctrine pins held
//
//   - chapter 一百八十五 — anti-magic-number (typed
//     enums for backing + rationale)
//   - chapter 二百一一 — single source-of-truth (one
//     assignment shape; downstream consumers consume
//     the same shape)
//   - chapter 三百九二 — replay-determinism (Sendable
//     + Codable; thermal snapshot key carries forward
//     so replay sees same assignment)
//   - 红线 7 — hint-only (assignment is observation +
//     dispatch routing, not commitment authority)
//   - ADR-014 OPT-IN — purely additive

import Foundation
import BASMetalSubstrate

// MARK: - Rationale enum

/// Typed reason the scheduler chose this assignment。
/// Surfaced for audit replay + scheduler tuning。
public enum BASAssignmentRationale:
    String, Codable, Equatable, Hashable, Sendable, CaseIterable
{

    /// ANE supports the op + capability priority is
    /// `.aneFirst` + thermal allows it。 Best case。
    case aneSupported = "ane-supported"

    /// ANE doesn't support the op but a kernel is
    /// registered for the GPU backing。 Falls back to
    /// GPU。
    case gpuFallbackAneUnsupported =
        "gpu-fallback-ane-unsupported"

    /// Thermal state is `.serious` or `.critical` —
    /// scheduler downgrades from ANE to GPU/CPU to
    /// reduce heat。
    case thermalDowngrade = "thermal-downgrade"

    /// Latency budget cannot be met by any accelerator
    /// at the current thermal state — falls back to
    /// CPU and reports the budget as missed。
    case cpuLatencyBudgetMiss =
        "cpu-latency-budget-miss"

    /// No kernel registered for the op + dtype + any
    /// backing → CPU-only dispatch。 The base default
    /// when registry is empty。
    case cpuNoKernelRegistered =
        "cpu-no-kernel-registered"
}

// MARK: - Assignment struct

/// Scheduler's typed answer to "where should this stage
/// run"。 Returned by `BASHardwareAwareScheduler.assign(
/// for:hint:capability:thermal:)`。
public struct BASStageAcceleratorAssignment:
    Equatable, Hashable, Codable, Sendable
{

    /// Which backing kind the stage should produce its
    /// outputs in。 Downstream stages with matching
    /// backing-kind keys can dispatch zero-copy。
    public let selectedBackingKind: BASTensorBackingKind

    /// The kernel key to dispatch through, or nil if
    /// no kernel was registered for the op + dtype +
    /// backing combination (CPU-only fallback)。
    public let selectedKernelKey: BASKernelKey?

    /// Cost score that drove this choice。 Lower is
    /// better。 Computed by the scheduler's cost
    /// function:
    ///   `cost = (estimatedLatencyMs × thermalDerate)
    ///         + (energyJ × powerWeight)
    ///         + opSupportPenalty`
    public let costScore: Double

    /// Thermal snapshot key the decision was made at。
    /// Carried so replay sees the same assignment for
    /// the same recorded thermal level。
    public let thermalSnapshot: BASCapabilityThermalSnapshot

    /// Why the scheduler chose this assignment。
    public let assignmentRationale: BASAssignmentRationale

    public init(
        selectedBackingKind: BASTensorBackingKind,
        selectedKernelKey: BASKernelKey?,
        costScore: Double,
        thermalSnapshot: BASCapabilityThermalSnapshot,
        assignmentRationale: BASAssignmentRationale
    ) {
        self.selectedBackingKind = selectedBackingKind
        self.selectedKernelKey = selectedKernelKey
        self.costScore = costScore
        self.thermalSnapshot = thermalSnapshot
        self.assignmentRationale = assignmentRationale
    }
}
