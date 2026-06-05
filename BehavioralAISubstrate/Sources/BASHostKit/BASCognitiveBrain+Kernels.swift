// MARK: - BASCognitiveBrain math/Metal kernels (cosine · rmsnorm · matmul · attention)
// chapter 一千〇四十 / WS-brain-decomp — relocated from BASCognitiveBrain.swift (god-object split).
// `extension BASCognitiveBrain` method cluster — same actor, same symbols, call sites unchanged.
// Pure relocation ⇒ byte-equal (cascade-digest net).

import Foundation
import CryptoKit
import BASMemory
import BASPolicy
import BASRuntimeCore
import BASMetalSubstrate
import BASRustCoreBridge
#if os(iOS) || os(macOS)
import BASRustMemoryTrackerBinary
#endif

extension BASCognitiveBrain {
    public func cosineSimilarity(
        _ a: [Float],
        _ b: [Float]
    ) async throws -> BASMetalCosineSimilarityResult {
        try await metalKernels.cosineSimilarity(a, b)
    }

    /// chapter 七百四 第三刀 / M2193 — Rust-backed cosine path。
    ///
    /// CPU-side cosine similarity via the chapter-七百三 第三刀
    /// `bas-retrieval-ranker` crate (now LIVE in the XCFramework
    /// after chapter 七百四 第一刀)。 Use this in callers that
    /// want native math without the Metal pipeline cost — for
    /// small dim (<= ~256) the Rust path is typically faster
    /// than spinning up a Metal compute pass。
    ///
    /// Per 「术业有专攻」: Swift orchestrates, Rust computes。
    ///
    /// Throws on length mismatch or empty input。
    public func cosineSimilarityRust(
        _ a: [Float], _ b: [Float]
    ) throws -> Float {
        return try Self.cosineSimilarityRustImpl(a, b)
    }

    /// Same as `cosineSimilarityRust` but the static helper —
    /// non-isolated so perf tests can call it without paying
    /// the actor-hop on every iteration。
    /// chapter 七百六 第四刀 / M2204 — auto-routing cosine。
    /// Picks the empirically-fastest implementation per input
    /// size based on the chapter-七百六-第二刀 tournament
    /// measurements。
    ///
    /// At M-series default thresholds:
    ///   dim ≤ 32 → Rust scalar
    ///   dim ≥ 64 → Rust SIMD
    ///   fallback  → Swift naive (watchOS / Linux)
    ///
    /// Per 「多次 对比」 — no assumed winner,real measurement
    /// picks。 Returns the routed result + which path executed
    /// so telemetry / tests can verify the decision。
    public nonisolated static func cosineSimilarityAuto(
        _ a: [Float], _ b: [Float],
        thresholds: BASAutoRouteThresholds = .mSeriesDefault
    ) -> BASAutoRouteResult<Float> {
        return BASAutoRouteRanker.cosineSimilarity(
            a, b, thresholds: thresholds)
    }

    public static func cosineSimilarityRustImpl(
        _ a: [Float], _ b: [Float]
    ) throws -> Float {
        guard !a.isEmpty else {
            throw BASMetalCosineSimilarityDispatcherError
                .zeroLengthVectors
        }
        guard a.count == b.count else {
            throw BASMetalCosineSimilarityDispatcherError
                .payloadCountMismatch(
                    name: "b",
                    expected: a.count,
                    actual: b.count)
        }
        var score: Float = 0
        let rc: Int32 = a.withUnsafeBufferPointer { ap in
            b.withUnsafeBufferPointer { bp in
                bas_ranker_cosine_similarity(
                    ap.baseAddress, a.count,
                    bp.baseAddress, b.count,
                    &score)
            }
        }
        guard rc == 0 else {
            throw BASMetalCosineSimilarityDispatcherError
                .libraryUnavailable(
                    message: "rust rc=\(rc)")
        }
        return score
    }

    /// 主线 全面 开发 — Metal RMSNorm GPU compute。
    /// Per blueprint:Metal owns RMSNorm。 Computes
    /// y[i] = x[i] / sqrt(mean(x²) + epsilon) via the
    /// `vector_rmsnorm` MSL kernel (two-pass: CPU sum-
    /// of-squares + GPU per-element scale)。
    public func rmsnorm(
        _ x: [Float],
        epsilon: Float = BASMetalRMSNormDispatcher
            .defaultEpsilon
    ) async throws -> [Float] {
        try await metalKernels.rmsnorm(x, epsilon: epsilon)
    }

    /// 主线 全面 开发 — Metal MatMul GPU compute。 Per
    /// blueprint:Metal owns MatMul。 Computes C = A · B
    /// for row-major float32 matrices via the
    /// `matmul_float32` MSL kernel (one GPU thread per
    /// output cell)。
    public func matmul(
        a: [Float], aRows: Int, aCols: Int,
        b: [Float], bRows: Int, bCols: Int
    ) async throws -> [Float] {
        try await metalKernels.matmul(a: a, aRows: aRows, aCols: aCols, b: b, bRows: bRows, bCols: bCols)
    }

    /// chapter 八百七十一 / M3021 — MPSGraph matMul dispatch via
    /// `BASMPSGraphMatMulKernel` actor。 Distinct from
    /// `brain.matmul(...)` which routes to the MSL custom kernel
    /// `matmul_float32` (the confusingly-named
    /// `.metalMatMulMPSGraph` enum case has historically routed
    /// to MSL despite the name — see naming-legacy comment on
    /// the BASAutoRouteChoice enum)。
    ///
    /// Live measurement at chapter 八百七十一 5-way benchmark:
    /// MPSGraph (warm) wins at workProduct ≥ 16M (256³ ~tie,
    /// 512³ 1.38× faster than MSL)。 The auto-router at
    /// `matMulAuto` routes large shapes here。
    public func mpsGraphMatMul(
        a: [Float], aRows: Int, aCols: Int,
        b: [Float], bRows: Int, bCols: Int
    ) async throws -> [Float] {
        try await metalKernels.mpsGraphMatMul(a: a, aRows: aRows, aCols: aCols, b: b, bRows: bRows, bCols: bCols)
    }

    /// 主线 全面 开发 — Metal single-head scaled-dot-
    /// product attention。 Per blueprint:Metal owns
    /// attention。 Computes softmax(Q · K^T / sqrt(D))
    /// · V via the `scaled_dot_product_attention` MSL
    /// kernel。 Each GPU thread handles one output cell。
    ///
    /// Inputs are row-major float32 flat arrays:
    ///   Q is qRows × qCols (M × D)
    ///   K is kRows × qCols (N × D — same key/query dim)
    ///   V is kRows × vCols (N × Dv)
    ///   output is M × Dv
    public func attention(
        q: [Float], qRows: Int, qCols: Int,
        k: [Float], kRows: Int,
        v: [Float], vCols: Int
    ) async throws -> [Float] {
        try await metalKernels.attention(q: q, qRows: qRows, qCols: qCols, k: k, kRows: kRows, v: v, vCols: vCols)
    }

    /// chapter 七百七 第三刀 / M2208 — auto-routed attention。
    ///
    /// chapter 七百八 第四刀 / M2214 — auto-routed SHA256-hex helper。
    ///
    /// Convenience for callers that have a UTF-8 string + want a
    /// hex digest with the optimal implementation picked by
    /// measured crossovers (small payloads → Rust pure-sha2,
    /// large payloads → CryptoKit HW)。
    public nonisolated static func sha256HexAuto(
        _ s: String,
        thresholds: BASAutoRouteThresholds = .mSeriesDefault
    ) -> BASAutoRouteResult<String> {
        let bytes = Array(s.utf8)
        let r = BASAutoRouteRanker.sha256(
            bytes, thresholds: thresholds)
        // LEGACY (chapter 七百十九 第三刀 / M2268):
        //     let hex = r.value.map {
        //         String(format: "%02x", $0) }.joined()
        let hex = BASAutoRouteRanker.bytesToHexLower(
            r.value)
        return BASAutoRouteResult(
            value: hex, choice: r.choice)
    }

    /// chapter 七百八 第四刀 / M2214 — auto-routed HMAC-SHA256
    /// helper。 Same routing as sha256HexAuto:Rust for small
    /// payloads,CryptoKit HW for large。 Returns hex-encoded
    /// 32-byte tag。
    public nonisolated static func hmacSha256HexAuto(
        key: String, payload: String,
        thresholds: BASAutoRouteThresholds = .mSeriesDefault
    ) -> BASAutoRouteResult<String> {
        let keyBytes = Array(key.utf8)
        let payloadBytes = Array(payload.utf8)
        let r = BASAutoRouteRanker.hmacSHA256(
            key: keyBytes, payload: payloadBytes,
            thresholds: thresholds)
        // LEGACY (chapter 七百十九 第三刀 / M2268):
        //     let hex = r.value.map {
        //         String(format: "%02x", $0) }.joined()
        let hex = BASAutoRouteRanker.bytesToHexLower(
            r.value)
        return BASAutoRouteResult(
            value: hex, choice: r.choice)
    }

    /// chapter 七百十 第三刀 / M2223 — calibrate auto-router
    /// thresholds against THIS host's CPU。 Returns a fresh
    /// BASAutoRouteCalibrationReport that callers can pass to
    /// any auto-routed primitive via the `thresholds:`
    /// parameter for measured-correct routing。
    ///
    /// Cost: ~2 seconds (`.fast`) or ~10 seconds
    /// (`.thorough`)。 Hosts typically call this once at
    /// startup + cache the result via
    /// BASAutoRouteCalibrationStore。
    public nonisolated static func calibrateAutoRoute(
        depth: BASAutoRouteCalibrationDepth = .fast
    ) -> BASAutoRouteCalibrationReport {
        return BASAutoRouteCalibrator.calibrate(
            depth: depth,
            substrateVersion: substrateAutoRouteSchemaVersion)
    }

    /// chapter 七百十 第三刀 — substrate version pin used by
    /// the calibration cache for schema invalidation。 Bumping
    /// this constant retires any older cached reports。
    public nonisolated static let
        substrateAutoRouteSchemaVersion: String = "1.0.0"

    /// chapter 七百十 第三刀 — convenience wrapper around the
    /// calibration store。 Loads from `cacheURL` if a fresh,
    /// host-matching cache exists;otherwise recalibrates +
    /// saves a new cache。 Both load + save are best-effort —
    /// any IO failure falls through to a fresh in-memory
    /// calibration so the substrate boot path is never blocked。
    public nonisolated static func loadOrCalibrateAutoRoute(
        cacheURL: URL,
        maxAgeSec: Int64 = BASAutoRouteCalibrationStore
            .defaultMaxAgeSec,
        depth: BASAutoRouteCalibrationDepth = .fast
    ) -> BASAutoRouteCalibrationReport {
        // Compute fingerprint up-front so calibrateFn closure
        // can attribute the calibration to the same host。
        let fingerprint =
            BASCognitiveBrain.currentDeviceFingerprint()
        return BASAutoRouteCalibrationStore.loadOrCalibrate(
            cacheURL: cacheURL,
            expectedSchemaVersion: 1,
            expectedSubstrateVersion:
                substrateAutoRouteSchemaVersion,
            expectedDeviceFingerprint: fingerprint,
            maxAgeSec: maxAgeSec,
            depth: depth,
            calibrateFn: {
                BASAutoRouteCalibrator.calibrate(
                    depth: depth,
                    deviceFingerprint: fingerprint,
                    substrateVersion:
                        substrateAutoRouteSchemaVersion)
            })
    }

    /// Stable fingerprint for the current host。 Exposed so
    /// tests can inject a known value via the calibrator's
    /// `deviceFingerprint:` parameter。
    public nonisolated static func currentDeviceFingerprint()
        -> String
    {
        let info = ProcessInfo.processInfo
        var hw = "host"
        #if os(macOS) || os(iOS)
        hw = info.hostName
        #endif
        return
            "\(hw)::cores=\(info.activeProcessorCount)"
            + "::os=\(info.operatingSystemVersionString)"
    }
}
