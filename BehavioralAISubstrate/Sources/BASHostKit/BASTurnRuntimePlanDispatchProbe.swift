// MARK: - BASTurnRuntimePlanDispatchProbe
// chapter 四百三十二 / M1101 — RADICAL EVOLUTION SWEEP Phase F
//
// Sendable + Codable typed snapshot of "what dispatch state
// the engine sees at this moment"。 Captured by
// `BASTurnRuntimeEngine.runWithPlan(...)` at dispatch time
// + surfaced via `BASTurnRuntimeEngine.lastPlanDispatchProbe`
// for tests + audit consumers + the M1102 BASHardwareAware
// Scheduler。
//
// ## Why this exists (system entropy framing)
//
// M1100 added 3 new configuration slots (`runtimeMode`,
// `metalKernelRegistry`, `aneCapability`) so callers can
// opt into hardware-aware dispatch。 But a configuration
// flag does nothing if the engine never CONSULTS it。
// `BASTurnRuntimePlanDispatchProbe` is the typed evidence
// that:
//   - The engine read the configuration's runtimeMode at
//     dispatch time
//   - The engine read the configuration's kernel registry
//     count at dispatch time
//   - The engine read the configuration's ANE capability
//     accelerator priority at dispatch time
//
// Without this typed surface,future PRs could silently
// regress the wiring (registry stays unread at dispatch
// time) and CI would not catch it。 The probe makes the
// wiring observable + testable。
//
// ## What this ships (M1101)
//
//   - `BASTurnRuntimePlanDispatchProbe` Sendable + Codable
//     + Equatable struct with 4 fields:
//       * `runtimeMode: BASTurnRuntimeMode`
//       * `kernelRegistryCount: Int` (0 if no registry
//         wired, or the live `await registry.kernelCount`)
//       * `aneAcceleratorPriority: BASAcceleratorPriority`
//         (`.gpuOnly` if no capability wired)
//       * `aneSupportedOpCount: Int` (0 if no capability
//         wired, or `capability.supportedOps.count`)
//   - `payloadJson()` String serializer for log emission
//
// ## Doctrine pins held
//
//   - chapter 一百八十五 — anti-magic-number (typed
//     enums + counts)
//   - chapter 二百一一 — single source-of-truth (one
//     probe shape; M1102 scheduler reads from this same
//     shape rather than re-introspecting the registry)
//   - chapter 三百九二 — replay-determinism (Sendable +
//     sortedKeys JSON)
//   - 不变量 #1/#2/#3 — V1 byte-equality preserved (probe
//     is observation only)
//   - 红线 7 — hint-only (probe carries dispatch state,
//     no commitment authority change)
//   - ADR-014 OPT-IN — purely additive

import Foundation
import BASMetalSubstrate

/// Sendable typed snapshot of what dispatch state the V2
/// runtime engine sees at the moment `runWithPlan(...)`
/// fires。 Captured per-call;surfaced via the engine's
/// `lastPlanDispatchProbe` accessor for tests + audit
/// consumers + the M1102 hardware-aware scheduler。
public struct BASTurnRuntimePlanDispatchProbe:
    Equatable, Hashable, Codable, Sendable
{

    /// Runtime mode from the engine's configuration at
    /// dispatch time。
    public let runtimeMode: BASTurnRuntimeMode

    /// Number of kernels registered on the configured
    /// kernel registry at dispatch time。 0 when no
    /// registry is wired into the configuration。
    public let kernelRegistryCount: Int

    /// ANE accelerator priority from the configured
    /// capability at dispatch time。 `.gpuOnly` when no
    /// capability is wired (matches `.conservative`
    /// fallback)。
    public let aneAcceleratorPriority: BASAcceleratorPriority

    /// Number of native ANE-supported ops from the
    /// configured capability at dispatch time。 0 when no
    /// capability is wired。
    public let aneSupportedOpCount: Int

    public init(
        runtimeMode: BASTurnRuntimeMode,
        kernelRegistryCount: Int,
        aneAcceleratorPriority: BASAcceleratorPriority,
        aneSupportedOpCount: Int
    ) {
        self.runtimeMode = runtimeMode
        self.kernelRegistryCount = kernelRegistryCount
        self.aneAcceleratorPriority =
            aneAcceleratorPriority
        self.aneSupportedOpCount = aneSupportedOpCount
    }

    /// Build a probe representing "no Phase F wiring at
    /// all" — runtimeMode = .v1ByteEqual,registry not
    /// wired,capability not wired。 Returned by the
    /// engine's accessor when `runWithPlan` has never
    /// been called yet。
    public static func unwired()
        -> BASTurnRuntimePlanDispatchProbe
    {
        return BASTurnRuntimePlanDispatchProbe(
            runtimeMode: .v1ByteEqual,
            kernelRegistryCount: 0,
            aneAcceleratorPriority: .gpuOnly,
            aneSupportedOpCount: 0)
    }

    /// JSON payload encoded with sortedKeys for byte-stable
    /// emission into the unified event log (Phase B
    /// chapter 四百二十八 — when shipped)。 Used by the
    /// M1102 scheduler + audit consumers。
    public func payloadJson() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(self),
              let json = String(data: data, encoding: .utf8)
        else {
            return "{}"
        }
        return json
    }
}
