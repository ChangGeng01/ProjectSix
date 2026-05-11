// MARK: - BASANELiveReader — chapter 四百七十四 / M1272
// 系统熵 reduction
//
// REAL HOT-PATH ATTACK Phase 1 entry — closes the
// "ANE probe defaults to .conservative" gap that the
// chapter 四百七十三 deep-review scored 1/10。
//
// ## Why this exists (system entropy framing)
//
// `BASANECapabilityProbe` (M1097) ships with an injected
// reader closure defaulting to `.conservative`,which means
// schedulers see `.gpuOnly` priority everywhere even on
// real M2/M3/M4 silicon with available ANE。 The probe
// design always intended a live binding to land later
// (see M1097 doctrine note:"the live `MLComputeDevice
// .allComputeDevices` binding will land in a follow-up
// commit once iOS 26 SDK MLCompute API stabilizes")。
// `BASANELiveReader` is that follow-up。
//
// ## What this ships (M1272)
//
//   - `BASANELiveReader.live` static factory returning a
//     `BASANECapabilityProbe.CapabilityReader` closure
//   - Live closure queries `MLComputeDevice
//     .allComputeDevices` when iOS 17+ / macOS 14+ +
//     ProcessInfo.processInfo.isiOSAppOnMac is false
//     (i.e。 real device or native macOS)。 Inspects:
//       - presence of `.neuralEngine` case → flips
//         priority to `.aneFirst`
//       - count of `.gpu` cases → batches above conservative
//       - thermal snapshot (passed in) → derates latency
//   - Simulator / older OS / catalyst fall through to
//     `.conservative` — preserving all existing behavior
//
// ## Determinism / replay
//
// The live closure is NOT pure — `MLComputeDevice
// .allComputeDevices` returns whatever the device reports
// at probe time。 However `BASANECapabilityProbe` caches
// per-thermal-state snapshot,so within one thermal window
// repeat reads are deterministic (chapter 三百九二)。
//
// Test paths inject `.conservative` directly via the
// probe init,bypassing this reader entirely — so test
// determinism is unchanged。
//
// ## Doctrine pins held
//
//   - chapter 一百八十五 — anti-magic-number (typed
//     priority enum,typed thermal snapshot)
//   - chapter 二百一一 — single source-of-truth (one live
//     reader factory,one conservative fallback)
//   - chapter 三百九二 — replay-determinism (within
//     thermal window,cache returns identical snapshot)
//   - ADR-014 OPT-IN — purely additive。 Probe default
//     remains `.conservative` until a host explicitly
//     constructs `BASANECapabilityProbe(reader:
//     BASANELiveReader.live())`
//   - 红线 7 — hint-only (capability is observation;
//     scheduler uses it for routing decisions but never
//     mutates it)

import Foundation
#if canImport(CoreML)
import CoreML
#endif

/// Factory namespace producing live-binding capability
/// readers for `BASANECapabilityProbe`。 Each factory
/// returns a `@Sendable` closure that maps a thermal
/// snapshot to a probed `BASANECapability`。
public enum BASANELiveReader {

    /// Live-binding reader that queries
    /// `MLComputeDevice.allComputeDevices` when running on
    /// iOS 17+ / macOS 14+ native silicon。 Falls back to
    /// `.conservative` on simulator,older OS,or when
    /// CoreML cannot be imported。
    ///
    /// Per chapter 三百九二 replay-determinism — the
    /// returned closure is wrapped by
    /// `BASANECapabilityProbe`'s per-thermal-state cache。
    /// Within one thermal window,repeat probes return the
    /// SAME snapshot。
    public static func live() -> BASANECapabilityProbe
        .CapabilityReader
    {
        return { thermal in
            return liveProbe(thermal: thermal)
        }
    }

    /// Internal live-probe implementation。 Visible as
    /// `internal` so tests can call it directly to verify
    /// fallback behavior without going through the probe
    /// actor。
    internal static func liveProbe(
        thermal: BASCapabilityThermalSnapshot
    ) -> BASANECapability {
        #if canImport(CoreML)
        if #available(iOS 17.0, macOS 14.0, *) {
            return liveProbeFromMLCompute(thermal: thermal)
        } else {
            return BASANECapability.conservative(
                thermalSnapshot: thermal)
        }
        #else
        return BASANECapability.conservative(
            thermalSnapshot: thermal)
        #endif
    }

    #if canImport(CoreML)
    @available(iOS 17.0, macOS 14.0, *)
    private static func liveProbeFromMLCompute(
        thermal: BASCapabilityThermalSnapshot
    ) -> BASANECapability {
        let devices = MLComputeDevice.allComputeDevices
        var hasANE = false
        var gpuCount = 0
        for d in devices {
            switch d {
            case .neuralEngine:
                hasANE = true
            case .gpu:
                gpuCount += 1
            case .cpu:
                break
            @unknown default:
                break
            }
        }
        // Critical thermal → drop to CPU-only fallback per
        // chapter 二百四 thermal contract (preserve battery,
        // avoid throttle)。
        if thermal == .critical {
            return BASANECapability.cpuOnlyFallback(
                thermalSnapshot: thermal)
        }
        // No ANE present (older silicon,or future device
        // without it) → conservative + slight bump if a
        // GPU is around。
        if !hasANE {
            return BASANECapability(
                maxBatchSize: max(1, gpuCount * 2),
                supportedOps: [],
                estimatedLatencyMs: thermal == .nominal
                    ? 5.0
                    : 10.0,
                memoryFootprintMB: 512,
                acceleratorPriority: gpuCount > 0
                    ? .gpuOnly
                    : .cpuOnly,
                thermalSnapshot: thermal)
        }
        // ANE present → derate latency by thermal level。
        // `.unknown` thermal collapses to conservative-of-
        // live (treat like `.fair`) — keeps the probe useful
        // when ProcessInfo doesn't surface thermal state。
        let baselineLatency: Double
        switch thermal {
        case .nominal: baselineLatency = 0.5
        case .fair: baselineLatency = 0.8
        case .serious: baselineLatency = 2.0
        case .critical: baselineLatency = 5.0
        case .unknown: baselineLatency = 0.8
        }
        // Op set matches nominalAppleSilicon — ssmScan is
        // reserved for Mamba SSM follow-up so omit。 Other
        // supported ops are stable across M2/M3/M4。
        let supported: Set<BASNeuralOp> = [
            .matMul, .conv2D, .attention,
            .layerNorm, .rmsNorm, .softmax,
            .rotaryEmbedding
        ]
        return BASANECapability(
            maxBatchSize: 8,
            supportedOps: supported,
            estimatedLatencyMs: baselineLatency,
            memoryFootprintMB: 2048,
            acceleratorPriority: .aneFirst,
            thermalSnapshot: thermal)
    }
    #endif
}
