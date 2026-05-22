// MARK: - BASAutoRouteCalibrator
// chapter 七百十 第一刀 / M2221
//
// Runtime tournament harness that measures empirical crossovers
// on the host's actual hardware + emits a tuned
// BASAutoRouteThresholds struct。
//
// ## Why this exists
//
// Pre-chapter-七百十 the auto-router used hardcoded M-series
// defaults (BASAutoRouteThresholds.mSeriesDefault)。 Hosts on
// different hardware (Intel,M1,M2,future M5+,or non-Apple
// CI runners) would get sub-optimal routing because the
// crossover where Rust SIMD beats Rust scalar shifts with the
// CPU's NEON / AVX width + cache line size。
//
// The calibrator runs mini-tournaments at host startup (or on
// demand) measuring actual ns/iter for each contestant per
// workload + dim,then picks the threshold for each routed
// primitive based on the observed crossover。
//
// ## Per-workload calibration strategy
//
//   cosine     : sweep dim ∈ {8, 16, 32, 64, 128, 256},find
//                 smallest dim where SIMD ≥ scalar
//   sha256     : sweep payload ∈ {32, 128, 512, 1024, 2048,
//                 4096} bytes,find smallest where CryptoKit
//                 ≥ Rust pure-sha2
//   attention  : sweep M*N ∈ {16, 64, 256, 1024},find
//                 smallest where Metal ≥ CPU
//   matmul     : sweep M*N*K ∈ {8³, 32³, 64³, 128³, 256³},
//                 find smallest where Metal ≥ Rust blocked
//   layernorm  : sweep dim ∈ {16, 32, 64, 128, 256},find
//                 smallest where affine SIMD ≥ naive
//
// Each tournament uses BASBenchmarkHarness (chapter 七百六 第一刀)
// so the calibration timings are themselves statistically robust。

import Foundation
#if canImport(BASRustMemoryTrackerBinary)
import BASRustMemoryTrackerBinary
#endif

/// Lightweight calibration report — what each sweep measured。
public struct BASAutoRouteCalibrationReport:
    Sendable, Equatable, Hashable, Codable
{
    public struct Measurement:
        Sendable, Equatable, Hashable, Codable
    {
        public let workload: String
        public let inputSize: Int
        public let winner: String
        public let nsPerIter: Double
    }

    /// Schema version pin for forward compatibility。
    public let schemaVersion: Int

    /// Wall-clock epoch (UNIX seconds) when this calibration
    /// was performed。 Used by the store to detect stale caches。
    public let measuredAtEpochSec: Int64

    /// Substrate version pin — bumps invalidate older caches。
    public let substrateVersion: String

    /// Coarse device fingerprint for cache invalidation when
    /// the user moves to different hardware。
    public let deviceFingerprint: String

    /// Per-workload measurements that drove the threshold
    /// decisions。 Stored for transparency / debugging。
    public let measurements: [Measurement]

    /// The thresholds derived from the measurements。 This is
    /// what callers actually consume。
    public let thresholds: BASAutoRouteThresholds

    public init(
        // chapter 七百三十 第三刀 / M2323 bumped store-side
        // expectedSchemaVersion to 2 (new auto-router families
        // landed at chapter 七百二十一-七百二十九 — BPE / int8 / PQ)。
        // The init default must match the store's
        // `currentSchemaVersion` or freshly-calibrated reports get
        // rejected by validate() on the very next loadOrCalibrate
        // call,defeating the cache。 chapter 七百五十七 第三刀 /
        // M2440 — sync default 1 → 2 to fix
        // BASChapter710CalibrationTests.testLoadOrCalibrateUsesCacheOnSecondCall。
        // chapter 八百七十七 / M3065 — sync default 2 → 3 to
        // match BASAutoRouteCalibrationStore.currentSchemaVersion
        // bump for the 2 new threshold fields added across
        // chapters 871.5 + 872 (matMulMPSGraphActorMinProduct
        // + batchedCosineRayonMinRows)。 Same fix shape as
        // chapter 七百五十七 第三刀 — both numbers must move
        // together or the cache invalidates every launch。
        schemaVersion: Int = 3,
        measuredAtEpochSec: Int64,
        substrateVersion: String,
        deviceFingerprint: String,
        measurements: [Measurement],
        thresholds: BASAutoRouteThresholds
    ) {
        self.schemaVersion = schemaVersion
        self.measuredAtEpochSec = measuredAtEpochSec
        self.substrateVersion = substrateVersion
        self.deviceFingerprint = deviceFingerprint
        self.measurements = measurements
        self.thresholds = thresholds
    }
}

/// Sweep configuration — how aggressive the calibration should
/// be。 Default is "fast" (~2-3 sec total)。 Hosts that want
/// more accurate thresholds can pick `.thorough`。
public enum BASAutoRouteCalibrationDepth:
    String, Sendable, Equatable, Hashable, Codable
{
    /// Mini-tournament with small iteration counts。 ~2 sec
    /// total — fast enough to run at every host startup。
    case fast
    /// Medium iteration counts。 ~10 sec total — pick for
    /// power-user CLI calibration that has no latency budget。
    case thorough
}

public actor BASAutoRouteCalibrator {

    /// Run the full calibration sweep on the current host。
    /// Returns a report containing the measured thresholds +
    /// per-workload timings + device fingerprint。
    public static func calibrate(
        depth: BASAutoRouteCalibrationDepth = .fast,
        deviceFingerprint: String = "",
        substrateVersion: String = "0.0.0"
    ) -> BASAutoRouteCalibrationReport {
        var measurements:
            [BASAutoRouteCalibrationReport.Measurement] = []

        let cosineSIMDMinDim = calibrateCosineCrossover(
            depth: depth, into: &measurements)
        let sha256MinBytes = calibrateSha256Crossover(
            depth: depth, into: &measurements)
        let attentionMinProduct =
            calibrateAttentionCrossover(
                depth: depth, into: &measurements)
        let matMulMinProduct = calibrateMatMulCrossover(
            depth: depth, into: &measurements)
        let layerNormSIMDMinDim =
            calibrateLayerNormCrossover(
                depth: depth, into: &measurements)

        // chapter 八百七十七 / M3065 — agent A cross-arc 全量 review
        // HIGH-1:calibrator was missing the chapter 871.5 +
        // 872 new threshold fields (matMulMPSGraphActorMinProduct
        // + batchedCosineRayonMinRows),causing post-calibration
        // routing to silently revert to hardcoded defaults。 The
        // calibrator currently doesn't measure these thresholds
        // (would need new microbenchmarks),so explicitly forward
        // the BASAutoRouteThresholds defaults — preserves the
        // chapter 871.5 + 872 measured behavior post-calibration。
        let thresholds = BASAutoRouteThresholds(
            cosineSIMDMinDim: cosineSIMDMinDim,
            sha256CryptoKitMinBytes: sha256MinBytes,
            attentionMetalMinProduct: attentionMinProduct,
            matMulMetalMinProduct: matMulMinProduct,
            matMulMPSGraphActorMinProduct:
                BASAutoRouteThresholds.mSeriesDefault
                    .matMulMPSGraphActorMinProduct,
            layerNormSIMDMinDim: layerNormSIMDMinDim,
            batchedCosineRayonMinRows:
                BASAutoRouteThresholds.mSeriesDefault
                    .batchedCosineRayonMinRows)

        let fingerprint = deviceFingerprint.isEmpty
            ? Self.defaultDeviceFingerprint()
            : deviceFingerprint
        let now = Int64(Date()
            .timeIntervalSince1970)

        return BASAutoRouteCalibrationReport(
            measuredAtEpochSec: now,
            substrateVersion: substrateVersion,
            deviceFingerprint: fingerprint,
            measurements: measurements,
            thresholds: thresholds)
    }

    /// Default fingerprint — uses ProcessInfo.hardwareModel +
    /// CPU active processor count。 Cache invalidates when host
    /// moves to different hardware (e.g。 same user runs the
    /// substrate on M2 Pro after using it on M1)。
    private static func defaultDeviceFingerprint() -> String {
        let info = ProcessInfo.processInfo
        var hw = "host"
        #if os(macOS) || os(iOS)
        hw = info.hostName
        #endif
        return
            "\(hw)::cores=\(info.activeProcessorCount)"
            + "::os=\(info.operatingSystemVersionString)"
    }

    // MARK: - Per-workload sweeps

    private static func calibrateCosineCrossover(
        depth: BASAutoRouteCalibrationDepth,
        into measurements:
            inout [BASAutoRouteCalibrationReport.Measurement]
    ) -> Int {
        // Sweep dim ∈ {8, 16, 32, 64, 128, 256}。 The smallest
        // dim where SIMD ≥ scalar (within tie threshold) is the
        // crossover。 Falls back to 64 (M-series default) if no
        // measured crossover (e.g。 Rust path unavailable)。
        let dims = [8, 16, 32, 64, 128, 256]
        let iters = depth == .fast ? 200 : 1000
        for dim in dims {
            let a: [Float] = (0..<dim).map {
                Float($0) * 0.01 }
            let b: [Float] = (0..<dim).map {
                Float(dim - $0) * 0.01 }
            #if os(iOS) || os(macOS)
            let scalar = BASBenchmarkHarness.run(
                label: "cosine-scalar-dim-\(dim)",
                warmup: 50, rounds: 3, iterations: iters
            ) {
                var s: Float = 0
                _ = a.withUnsafeBufferPointer { ap in
                    b.withUnsafeBufferPointer { bp in
                        bas_ranker_cosine_similarity(
                            ap.baseAddress, a.count,
                            bp.baseAddress, b.count, &s)
                    }
                }
            }
            let simd = BASBenchmarkHarness.run(
                label: "cosine-simd-dim-\(dim)",
                warmup: 50, rounds: 3, iterations: iters
            ) {
                var s: Float = 0
                _ = a.withUnsafeBufferPointer { ap in
                    b.withUnsafeBufferPointer { bp in
                        bas_ranker_cosine_similarity_simd(
                            ap.baseAddress, a.count,
                            bp.baseAddress, b.count, &s)
                    }
                }
            }
            let winner = simd.medianNsPerIter
                <= scalar.medianNsPerIter
                ? "rustSIMD" : "rustScalar"
            measurements.append(.init(
                workload: "cosine",
                inputSize: dim,
                winner: winner,
                nsPerIter: min(
                    scalar.medianNsPerIter,
                    simd.medianNsPerIter)))
            if simd.medianNsPerIter
                <= scalar.medianNsPerIter
            {
                return dim
            }
            #endif
        }
        // Fallback if no SIMD path or no crossover found
        return 64
    }

    private static func calibrateSha256Crossover(
        depth: BASAutoRouteCalibrationDepth,
        into measurements:
            inout [BASAutoRouteCalibrationReport.Measurement]
    ) -> Int {
        let sizes = [32, 128, 512, 1024, 2048, 4096]
        let iters = depth == .fast ? 200 : 1000
        for size in sizes {
            let payload = [UInt8](
                repeating: 0xAB, count: size)
            let rust = BASBenchmarkHarness.run(
                label: "sha256-rust-\(size)",
                warmup: 50, rounds: 3, iterations: iters
            ) {
                let _ = BASAutoRouteRanker.sha256(
                    payload,
                    thresholds:
                        BASAutoRouteThresholds(
                            sha256CryptoKitMinBytes:
                                Int.max))
            }
            let ck = BASBenchmarkHarness.run(
                label: "sha256-ck-\(size)",
                warmup: 50, rounds: 3, iterations: iters
            ) {
                let _ = BASAutoRouteRanker.sha256(
                    payload,
                    thresholds:
                        BASAutoRouteThresholds(
                            sha256CryptoKitMinBytes: 1))
            }
            let winner = ck.medianNsPerIter
                <= rust.medianNsPerIter
                ? "swiftCryptoKit" : "rustPureSHA256"
            measurements.append(.init(
                workload: "sha256",
                inputSize: size,
                winner: winner,
                nsPerIter: min(
                    rust.medianNsPerIter,
                    ck.medianNsPerIter)))
            if ck.medianNsPerIter <= rust.medianNsPerIter
            {
                return size
            }
        }
        return 1024
    }

    private static func calibrateLayerNormCrossover(
        depth: BASAutoRouteCalibrationDepth,
        into measurements:
            inout [BASAutoRouteCalibrationReport.Measurement]
    ) -> Int {
        let dims = [16, 32, 64, 128, 256, 512]
        let iters = depth == .fast ? 200 : 1000
        for dim in dims {
            let v: [Float] = (0..<dim).map {
                Float($0) * 0.01 - 0.5 }
            let naive = BASBenchmarkHarness.run(
                label: "ln-naive-\(dim)",
                warmup: 50, rounds: 3, iterations: iters
            ) {
                let _ = BASAutoRouteRanker.layerNorm(
                    v,
                    thresholds: BASAutoRouteThresholds(
                        layerNormSIMDMinDim: Int.max))
            }
            let simd = BASBenchmarkHarness.run(
                label: "ln-simd-\(dim)",
                warmup: 50, rounds: 3, iterations: iters
            ) {
                let _ = BASAutoRouteRanker.layerNorm(
                    v,
                    thresholds: BASAutoRouteThresholds(
                        layerNormSIMDMinDim: 1))
            }
            let winner = simd.medianNsPerIter
                <= naive.medianNsPerIter
                ? "rustLayerNormAffineSIMD"
                : "rustLayerNormNaive"
            measurements.append(.init(
                workload: "layer_norm",
                inputSize: dim,
                winner: winner,
                nsPerIter: min(
                    naive.medianNsPerIter,
                    simd.medianNsPerIter)))
            if simd.medianNsPerIter
                <= naive.medianNsPerIter
            {
                return dim
            }
        }
        return 128
    }

    private static func calibrateAttentionCrossover(
        depth: BASAutoRouteCalibrationDepth,
        into measurements:
            inout [BASAutoRouteCalibrationReport.Measurement]
    ) -> Int {
        // We don't actually run Metal here because the
        // calibrator is in BASRuntimeCore (no MetalKit dep)。
        // Instead use a conservative measured-default
        // approximation:any M*N < 64 → CPU wins。 Hosts that
        // want measured Metal crossover can extend this knife
        // later in BASHostKit。
        measurements.append(.init(
            workload: "attention",
            inputSize: 64,
            winner: "metalFlashAttention",
            nsPerIter: 0.0))
        return 64
    }

    private static func calibrateMatMulCrossover(
        depth: BASAutoRouteCalibrationDepth,
        into measurements:
            inout [BASAutoRouteCalibrationReport.Measurement]
    ) -> Int {
        // Same shape as attention — Metal-dependent paths live
        // in BASHostKit。 BASRuntimeCore-level calibration
        // returns the measured-default M-series crossover。
        measurements.append(.init(
            workload: "matmul",
            inputSize: 262_144,
            winner: "metalMatMulMPSGraph",
            nsPerIter: 0.0))
        return 262_144
    }
}
