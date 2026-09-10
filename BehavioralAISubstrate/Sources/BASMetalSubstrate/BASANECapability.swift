// MARK: - BASANECapability — chapter 四百三十一 / M1097
// 系统熵 reduction
//
// RADICAL EVOLUTION SWEEP Phase E middle entry。 First
// substrate-level introspection of the Apple Neural
// Engine。
//
// ## Why this exists (system entropy framing)
//
// Today the substrate carries `BASDeviceState.npuAvailable:
// Bool` — a single binary。 That tells the runtime
// "ANE exists" but not "what is its current memory
// budget" / "which ops does it support" / "how does
// thermal state derate it" / "does it prefer fp16"。
// The hardware-aware scheduler (M1102) needs all of
// that to make sound device-affinity decisions; today it
// can only read a binary。
//
// `BASANECapability` ships a typed snapshot of the ANE
// at a moment in time:supported ops,memory budget,
// estimated latency,priority hint。 The probe reads
// `MLComputeDevice.allComputeDevices` (iOS 17+ /
// macOS 14+) and caches per `ProcessInfo.thermalState`
// so repeated reads inside one thermal window stay free。
//
// ## What this ships (M1097)
//
//   - `BASANECapability` Sendable + Codable struct with:
//     - `maxBatchSize: Int` (probe-discovered or
//       conservative default)
//     - `supportedOps: Set<BASNeuralOp>`
//     - `estimatedLatencyMs: Double` (one-shot probe
//       latency for the most-common dense op)
//     - `memoryFootprintMB: Int` (current free budget
//       reported by ANE,or estimated)
//     - `acceleratorPriority: BASAcceleratorPriority`
//       enum (`.aneFirst` / `.gpuOnly` / `.cpuOnly`)
//     - `thermalSnapshot: BASCapabilityThermalSnapshot`
//       (caching key — capability invalidated when
//       thermal state changes)
//   - `BASAcceleratorPriority` enum (3 cases)
//   - `BASCapabilityThermalSnapshot` enum mirroring
//     `ProcessInfo.thermalState` (stays portable across
//     watchOS where ProcessInfo lacks the property)
//
// ## Doctrine pins held
//
//   - chapter 一百八十五 — anti-magic-number。 Every field
//     is typed (no raw Int op codes / state codes)。
//   - chapter 二百一一 — single source-of-truth。 One
//     capability struct;all schedulers consume the same
//     shape。
//   - chapter 三百九二 — replay-determinism。 Codable
//     via String rawvalue enums + sortedKeys JSON。
//   - ADR-014 OPT-IN — purely additive (no V1 hot path
//     reads BASANECapability yet)。
//   - 红线 7 — hint-only (capability is observation,
//     not commitment)。

import Foundation

// MARK: - Accelerator priority

/// Priority hint for the hardware-aware scheduler。 Returned
/// by the capability probe based on the current device's
/// silicon generation + thermal state。
public enum BASAcceleratorPriority:
    String, Codable, Equatable, Hashable, Sendable, CaseIterable
{

    /// Prefer ANE for supported ops,fall back to GPU /
    /// CPU for unsupported。 Default on M2/M3/M4 + A17/A18
    /// at `.nominal` thermal state。
    case aneFirst = "ane-first"

    /// Skip ANE,use GPU only。 Returned on simulator /
    /// older silicon / `.serious` thermal state where
    /// ANE dispatch overhead exceeds GPU savings。
    case gpuOnly = "gpu-only"

    /// CPU-only fallback。 Returned when GPU is also
    /// unavailable (rare;watchOS or `.critical` thermal)。
    case cpuOnly = "cpu-only"
}

// MARK: - Thermal snapshot (caching key)

/// Substrate-portable thermal state used as the capability
/// probe cache key。 Mirrors `ProcessInfo.thermalState` on
/// iOS+macOS;degraded to `.unknown` on platforms where
/// the API is unavailable。
public enum BASCapabilityThermalSnapshot:
    String, Codable, Equatable, Hashable, Sendable, CaseIterable
{
    case nominal = "nominal"
    case fair = "fair"
    case serious = "serious"
    case critical = "critical"
    case unknown = "unknown"

    /// Capture current thermal state from `ProcessInfo`。
    /// Returns `.unknown` on platforms where the API is
    /// unavailable (watchOS pre-watchOS 11)。
    public static func current() -> BASCapabilityThermalSnapshot {
        #if canImport(Foundation)
        switch ProcessInfo.processInfo.thermalState {
        case .nominal:  return .nominal
        case .fair:     return .fair
        case .serious:  return .serious
        case .critical: return .critical
        @unknown default: return .unknown
        }
        #else
        return .unknown
        #endif
    }
}

// MARK: - Capability snapshot

/// Sendable + Codable typed snapshot of the Apple Neural
/// Engine's capability at a moment in time。 Cached per
/// thermal state by `BASANECapabilityProbe`。
///
/// All fields are observation-only (红线 7)。 The
/// hardware-aware scheduler (M1102) consumes this struct
/// to make device-affinity decisions but never mutates it。
public struct BASANECapability:
    Equatable, Hashable, Codable, Sendable
{

    /// Maximum supported batch size for ANE dispatch。
    /// Conservative default of 1 when the probe cannot
    /// inspect the live device。
    public let maxBatchSize: Int

    /// Set of `BASNeuralOp` cases the ANE supports
    /// natively at this thermal state。 Ops not in this
    /// set must be routed to GPU or CPU。
    public let supportedOps: Set<BASNeuralOp>

    /// Estimated latency for the most-common dense op
    /// (matMul on `[64, 64] × [64, 64]` Float16) in
    /// milliseconds。 Used as a throughput proxy by the
    /// scheduler。 Conservative default of 10.0 when the
    /// probe cannot benchmark。
    public let estimatedLatencyMs: Double

    /// Estimated free memory budget for ANE-resident
    /// tensors,in megabytes。 Conservative default of
    /// 256 MB when the probe cannot inspect the live
    /// device。
    public let memoryFootprintMB: Int

    /// Priority hint for the scheduler。
    public let acceleratorPriority: BASAcceleratorPriority

    /// Thermal snapshot key — capability is invalidated
    /// when this changes。
    public let thermalSnapshot: BASCapabilityThermalSnapshot

    public init(
        maxBatchSize: Int,
        supportedOps: Set<BASNeuralOp>,
        estimatedLatencyMs: Double,
        memoryFootprintMB: Int,
        acceleratorPriority: BASAcceleratorPriority,
        thermalSnapshot: BASCapabilityThermalSnapshot
    ) {
        self.maxBatchSize = maxBatchSize
        self.supportedOps = supportedOps
        self.estimatedLatencyMs = estimatedLatencyMs
        self.memoryFootprintMB = memoryFootprintMB
        self.acceleratorPriority = acceleratorPriority
        self.thermalSnapshot = thermalSnapshot
    }

    // MARK: - Conservative defaults

    /// Conservative substrate default for environments
    /// where the live ANE cannot be probed (simulator,
    /// watchOS,older silicon)。 Returns `.gpuOnly` priority
    /// + empty op set so scheduler routes everything to
    /// GPU/CPU。
    public static func conservative(
        thermalSnapshot: BASCapabilityThermalSnapshot
    ) -> BASANECapability {
        return BASANECapability(
            maxBatchSize: 1,
            supportedOps: [],
            estimatedLatencyMs: 10.0,
            memoryFootprintMB: 256,
            acceleratorPriority: .gpuOnly,
            thermalSnapshot: thermalSnapshot)
    }

    /// CPU-only fallback for the most-degraded paths
    /// (`.critical` thermal,or no GPU)。
    public static func cpuOnlyFallback(
        thermalSnapshot: BASCapabilityThermalSnapshot
    ) -> BASANECapability {
        return BASANECapability(
            maxBatchSize: 1,
            supportedOps: [],
            estimatedLatencyMs: 50.0,
            memoryFootprintMB: 64,
            acceleratorPriority: .cpuOnly,
            thermalSnapshot: thermalSnapshot)
    }

    /// Reference snapshot for an M-series Mac at `.nominal`
    /// thermal state — useful as the "real silicon"
    /// example in tests + replay fixtures。 Real probe
    /// (`BASANECapabilityProbe`) returns this shape on
    /// physical M2/M3/M4 hardware at room temperature。
    public static func nominalAppleSilicon() -> BASANECapability {
        return BASANECapability(
            maxBatchSize: 8,
            supportedOps: [
                .matMul, .conv2D, .attention,
                .layerNorm, .rmsNorm, .softmax,
                .rotaryEmbedding
                // .ssmScan reserved — Mamba SSM future work
            ],
            estimatedLatencyMs: 0.5,
            memoryFootprintMB: 2048,
            acceleratorPriority: .aneFirst,
            thermalSnapshot: .nominal)
    }
}
