// MARK: - BASCognitiveMetalKernels
// God-object extraction (audit ch1040): the brain's Metal-kernel cluster — 10 GPU dispatch
// methods + their lazily-cached dispatcher/kernel/cache props — moved off the sovereign-path
// BASCognitiveBrain actor into this collaborator actor. The brain keeps `public let
// metalLibraryLoader` + forwards each call here, so the ~100 external call sites stay byte-equal.
// (The 2 ANE-tier orchestrators stay on the brain — they use brain-local ANE telemetry — and
// call the brain's matMulAuto/attentionAuto forwarders. The audit's "pure numerics" premise was
// WRONG: these read the loader + lazily cache dispatchers, so it's a stateful collaborator.)

import Foundation
import CryptoKit
import BASMemory
import BASPolicy
import BASRuntimeCore
import BASMetalSubstrate
import BASRustCoreBridge
#if canImport(BASRustMemoryTrackerBinary)
import BASRustMemoryTrackerBinary
#endif

actor BASCognitiveMetalKernels {

    /// Shared reference to the brain's injected Metal library loader (same instance).
    let metalLibraryLoader: BASMetalKernelLibraryLoader?

    init(metalLibraryLoader: BASMetalKernelLibraryLoader?) {
        self.metalLibraryLoader = metalLibraryLoader
    }

    /// 主线 继续 开发 — memoized SSMScan dispatcher built
    /// on first `brain.dispatchSSMScan(...)` call。 nil
    /// until the host actually invokes dispatch。 Cheap
    /// to construct,but lazily-built so the dispatcher
    /// isn't created for brains that never compute Metal
    /// (most cases)。
    fileprivate var metalSSMScanDispatcher:
        BASMetalSSMScanDispatcher?

    /// 主线 全面 开发 — memoized cosine-similarity
    /// dispatcher。 Same lazy-init pattern as the
    /// SSMScan dispatcher。
    fileprivate var metalCosineDispatcher:
        BASMetalCosineSimilarityDispatcher?

    /// 主线 全面 开发 — memoized RMSNorm + MatMul GPU
    /// dispatchers, lazily built on first use。
    fileprivate var metalRMSNormDispatcher:
        BASMetalRMSNormDispatcher?
    fileprivate var metalMatMulDispatcher:
        BASMetalMatMulDispatcher?

    /// 主线 全面 开发 — memoized single-head attention
    /// GPU dispatcher,lazily built on first use。
    fileprivate var metalAttentionDispatcher:
        BASMetalAttentionDispatcher?

    /// chapter 七百七 第一刀 — memoized tiled FlashAttention
    /// dispatcher,lazily built on first use。 Distinct from
    /// the standard attention dispatcher so the two compete
    /// in the auto-router tournament at chapter 七百七 第三刀。
    fileprivate var metalFlashAttentionDispatcher:
        BASMetalFlashAttentionDispatcher?

    /// chapter 八百七十 / M3016 — MPSGraph attention kernel +
    /// executable cache,lazily built on first use。 Kernel
    /// reads/writes to the shared cache,which provides the
    /// 30.48× cold→warm speedup measured at chapter 八百六十九。
    /// Per-call new kernel would defeat the cache (each call
    /// would recompile the MPSGraph executable from scratch)
    /// — that's the load-bearing reason for these slots to
    /// exist as brain-owned stored props rather than per-call
    /// locals。
    fileprivate var mpsGraphAttentionKernel:
        BASMPSGraphAttentionKernel?
    fileprivate var mpsGraphAttentionCache:
        BASMPSGraphExecutableCache?

    /// chapter 八百七十一 / M3021 — MPSGraph matMul kernel,
    /// lazily built on first use。 NOTE: unlike the attention
    /// kernel, BASMPSGraphMatMulKernel.init() does NOT accept
    /// a BASMPSGraphExecutableCache parameter — the kernel
    /// uses MPSGraph's internal executable caching on its own
    /// device。 Reusing the SAME kernel instance across calls
    /// is what amortizes the compile cost (chapter 八百七十一
    /// measured ~2.6× difference between per-call new kernel
    /// and shared-kernel for 512³ matMul)。
    fileprivate var mpsGraphMatMulKernel:
        BASMPSGraphMatMulKernel?

    public func cosineSimilarity(
        _ a: [Float],
        _ b: [Float]
    ) async throws -> BASMetalCosineSimilarityResult {
        guard let loader = metalLibraryLoader else {
            throw BASMetalCosineSimilarityDispatcherError
                .libraryUnavailable(
                    message:
                        "no metalLibraryLoader wired")
        }
        if metalCosineDispatcher == nil {
            metalCosineDispatcher =
                BASMetalCosineSimilarityDispatcher(
                    loader: loader)
        }
        guard let d = metalCosineDispatcher else {
            throw BASMetalCosineSimilarityDispatcherError
                .libraryUnavailable(
                    message: "dispatcher init failed")
        }
        return try await d.dispatch(a: a, b: b)
    }

    public func rmsnorm(
        _ x: [Float],
        epsilon: Float = BASMetalRMSNormDispatcher
            .defaultEpsilon
    ) async throws -> [Float] {
        guard let loader = metalLibraryLoader else {
            throw BASMetalRMSNormDispatcherError
                .libraryUnavailable(
                    message:
                        "no metalLibraryLoader wired")
        }
        if metalRMSNormDispatcher == nil {
            metalRMSNormDispatcher =
                BASMetalRMSNormDispatcher(
                    loader: loader)
        }
        guard let d = metalRMSNormDispatcher else {
            throw BASMetalRMSNormDispatcherError
                .libraryUnavailable(
                    message: "dispatcher nil")
        }
        return try await d.dispatch(
            x: x, epsilon: epsilon)
    }

    public func matmul(
        a: [Float], aRows: Int, aCols: Int,
        b: [Float], bRows: Int, bCols: Int
    ) async throws -> [Float] {
        guard let loader = metalLibraryLoader else {
            throw BASMetalMatMulDispatcherError
                .libraryUnavailable(
                    message:
                        "no metalLibraryLoader wired")
        }
        if metalMatMulDispatcher == nil {
            metalMatMulDispatcher =
                BASMetalMatMulDispatcher(
                    loader: loader)
        }
        guard let d = metalMatMulDispatcher else {
            throw BASMetalMatMulDispatcherError
                .libraryUnavailable(
                    message: "dispatcher nil")
        }
        return try await d.dispatch(
            a: a, aRows: aRows, aCols: aCols,
            b: b, bRows: bRows, bCols: bCols)
    }

    public func mpsGraphMatMul(
        a: [Float], aRows: Int, aCols: Int,
        b: [Float], bRows: Int, bCols: Int
    ) async throws -> [Float] {
        guard aCols == bRows else {
            // chapter 八百七十一.5 — use Brain-scoped error,not
            // dispatcher-scoped (the MPSGraph path doesn't go
            // through BASMetalMatMulDispatcher)
            throw BASCognitiveBrainMatMulError
                .shapeMismatch(
                    aCols: aCols, bRows: bRows)
        }
        guard aRows > 0, aCols > 0, bCols > 0 else {
            throw BASCognitiveBrainMatMulError
                .zeroDimension(
                    aRows: aRows, aCols: aCols, bCols: bCols)
        }
        if mpsGraphMatMulKernel == nil {
            mpsGraphMatMulKernel =
                try BASMPSGraphMatMulKernel()
        }
        guard let kernel = mpsGraphMatMulKernel else {
            throw BASCognitiveBrainMatMulError
                .mpsGraphKernelUnavailable
        }
        let inputs = BASCanonicalKernelInputBuilders
            .matMul(a: a, b: b,
                M: aRows, K: aCols, N: bCols)
        let out = try await kernel.evaluate(inputs: inputs)
        return BASCanonicalKernelInputBuilders
            .dataToFloatArray(
                out.payloads[0],
                elementCount: aRows * bCols)
    }

    public func attention(
        q: [Float], qRows: Int, qCols: Int,
        k: [Float], kRows: Int,
        v: [Float], vCols: Int
    ) async throws -> [Float] {
        guard let loader = metalLibraryLoader else {
            throw BASMetalAttentionDispatcherError
                .libraryUnavailable(
                    message:
                        "no metalLibraryLoader wired")
        }
        if metalAttentionDispatcher == nil {
            metalAttentionDispatcher =
                BASMetalAttentionDispatcher(
                    loader: loader)
        }
        guard let d = metalAttentionDispatcher else {
            throw BASMetalAttentionDispatcherError
                .libraryUnavailable(
                    message: "dispatcher nil")
        }
        return try await d.dispatch(
            q: q, qRows: qRows, qCols: qCols,
            k: k, kRows: kRows,
            v: v, vCols: vCols)
    }

    public func matMulAuto(
        a: [Float], aRows: Int, aCols: Int,
        b: [Float], bRows: Int, bCols: Int,
        thresholds: BASAutoRouteThresholds = .mSeriesDefault
    ) async throws -> BASAutoRouteResult<[Float]> {
        let shape = BASMatMulShape(
            M: aRows, N: bCols, K: aCols)
        let choice = BASAutoRouteRanker.matMulChoice(
            shape: shape, thresholds: thresholds)
        switch choice {
        case .metalMatMulMPSGraph:
            // Misleadingly-named case — routes to MSL kernel
            // (matmul_float32) per the naming-legacy note on
            // the enum。 brain.matmul calls
            // BASMetalMatMulDispatcher,not BASMPSGraphMatMulKernel。
            let value = try await matmul(
                a: a, aRows: aRows, aCols: aCols,
                b: b, bRows: bRows, bCols: bCols)
            return BASAutoRouteResult(
                value: value,
                choice: .metalMatMulMPSGraph)
        case .metalMatMulMPSGraphActor:
            // chapter 八百七十一 / M3021 — TRUE MPSGraph actor
            // path via shared kernel instance。 Routed by the
            // ranker for workProduct ≥ 16M where chapter 八百七十一
            // measured MPSGraph beats MSL 1.07-1.38×。
            let value = try await mpsGraphMatMul(
                a: a, aRows: aRows, aCols: aCols,
                b: b, bRows: bRows, bCols: bCols)
            return BASAutoRouteResult(
                value: value,
                choice: .metalMatMulMPSGraphActor)
        case .rustMatMulNaive, .rustMatMulBlocked:
            #if os(iOS) || os(macOS)
            var c = [Float](
                repeating: 0,
                count: aRows * bCols)
            let rc = a.withUnsafeBufferPointer { ap in
                b.withUnsafeBufferPointer { bp in
                    c.withUnsafeMutableBufferPointer
                        { cp in
                        if choice == .rustMatMulNaive {
                            return bas_ranker_matmul_naive(
                                ap.baseAddress, a.count,
                                bp.baseAddress, b.count,
                                cp.baseAddress, cp.count,
                                aRows, bCols, aCols)
                        }
                        return bas_ranker_matmul_blocked(
                            ap.baseAddress, a.count,
                            bp.baseAddress, b.count,
                            cp.baseAddress, cp.count,
                            aRows, bCols, aCols)
                    }
                }
            }
            guard rc == 0 else {
                let value = try await matmul(
                    a: a, aRows: aRows, aCols: aCols,
                    b: b, bRows: bRows, bCols: bCols)
                return BASAutoRouteResult(
                    value: value,
                    choice: .metalMatMulMPSGraph)
            }
            return BASAutoRouteResult(
                value: c, choice: choice)
            #else
            let value = try await matmul(
                a: a, aRows: aRows, aCols: aCols,
                b: b, bRows: bRows, bCols: bCols)
            return BASAutoRouteResult(
                value: value,
                choice: .metalMatMulMPSGraph)
            #endif
        default:
            let value = try await matmul(
                a: a, aRows: aRows, aCols: aCols,
                b: b, bRows: bRows, bCols: bCols)
            return BASAutoRouteResult(
                value: value,
                choice: .metalMatMulMPSGraph)
        }
    }

    public func attentionAuto(
        q: [Float], qRows: Int, qCols: Int,
        k: [Float], kRows: Int,
        v: [Float], vCols: Int,
        thresholds: BASAutoRouteThresholds = .mSeriesDefault
    ) async throws -> BASAutoRouteResult<[Float]> {
        let shape = BASAttentionShape(
            M: qRows, N: kRows, D: qCols, Dv: vCols)
        let choice = BASAutoRouteRanker.attentionChoice(
            shape: shape, thresholds: thresholds)
        switch choice {
        case .swiftCPUAttention:
            return BASAutoRouteResult(
                value: BASAutoRouteRanker.cpuAttention(
                    q: q, M: qRows, D: qCols,
                    k: k, N: kRows,
                    v: v, Dv: vCols),
                choice: .swiftCPUAttention)
        case .metalFlashAttention:
            // Head-dim cap fallback: if dim exceeds FlashAttention's
            // tile cap (64) fall back to the standard kernel
            // which has no such limit。
            if qCols
                > BASMetalFlashAttentionTileConfig.dMax
                || vCols
                    > BASMetalFlashAttentionTileConfig.dMax
            {
                let value = try await attention(
                    q: q, qRows: qRows, qCols: qCols,
                    k: k, kRows: kRows,
                    v: v, vCols: vCols)
                return BASAutoRouteResult(
                    value: value,
                    choice: .metalStandardAttention)
            }
            let value = try await flashAttention(
                q: q, qRows: qRows, qCols: qCols,
                k: k, kRows: kRows,
                v: v, vCols: vCols)
            return BASAutoRouteResult(
                value: value,
                choice: .metalFlashAttention)
        case .metalStandardAttention:
            let value = try await attention(
                q: q, qRows: qRows, qCols: qCols,
                k: k, kRows: kRows,
                v: v, vCols: vCols)
            return BASAutoRouteResult(
                value: value,
                choice: .metalStandardAttention)
        case .metalMPSGraphAttention:
            // chapter 八百七十 / M3016 — Dv ≠ D fallback (defense
            // in depth: ranker already filters Dv≠D shapes away
            // from this choice via attentionChoice,but a third-
            // party caller can construct the choice manually,so
            // re-check the constraint here)。 Falls back to std
            // (not FA — chapter 八百六十八 measured FA as 1.07-1.10×
            // slower than std)。
            if qCols != vCols {
                let value = try await attention(
                    q: q, qRows: qRows, qCols: qCols,
                    k: k, kRows: kRows,
                    v: v, vCols: vCols)
                return BASAutoRouteResult(
                    value: value,
                    choice: .metalStandardAttention)
            }
            let value = try await mpsGraphAttention(
                q: q, qRows: qRows, qCols: qCols,
                k: k, kRows: kRows,
                v: v, vCols: vCols)
            return BASAutoRouteResult(
                value: value,
                choice: .metalMPSGraphAttention)
        default:
            // Should not happen — attentionChoice never returns
            // non-attention cases。 Conservative fallback:CPU。
            return BASAutoRouteResult(
                value: BASAutoRouteRanker.cpuAttention(
                    q: q, M: qRows, D: qCols,
                    k: k, N: kRows,
                    v: v, Dv: vCols),
                choice: .swiftCPUAttention)
        }
    }

    public func flashAttention(
        q: [Float], qRows: Int, qCols: Int,
        k: [Float], kRows: Int,
        v: [Float], vCols: Int
    ) async throws -> [Float] {
        guard let loader = metalLibraryLoader else {
            throw BASMetalFlashAttentionDispatcherError
                .libraryUnavailable(
                    message:
                        "no metalLibraryLoader wired")
        }
        if metalFlashAttentionDispatcher == nil {
            metalFlashAttentionDispatcher =
                BASMetalFlashAttentionDispatcher(
                    loader: loader)
        }
        guard let d = metalFlashAttentionDispatcher
        else {
            throw BASMetalFlashAttentionDispatcherError
                .libraryUnavailable(
                    message: "dispatcher nil")
        }
        return try await d.dispatch(
            q: q, qRows: qRows, qCols: qCols,
            k: k, kRows: kRows,
            v: v, vCols: vCols)
    }

    public func mpsGraphAttention(
        q: [Float], qRows: Int, qCols: Int,
        k: [Float], kRows: Int,
        v: [Float], vCols: Int
    ) async throws -> [Float] {
        guard qCols == vCols else {
            throw BASCognitiveBrainAttentionError
                .mpsGraphDvDimensionMustEqualD(
                    qCols: qCols, vCols: vCols)
        }
        // Lazy-init kernel + cache as shared singletons —
        // the SAME instance must persist across calls,otherwise
        // the 30.48× cache speedup measured at chapter 八百六十九
        // collapses to per-call recompile cost。
        if mpsGraphAttentionKernel == nil {
            let cache = BASMPSGraphExecutableCache()
            mpsGraphAttentionCache = cache
            mpsGraphAttentionKernel =
                try BASMPSGraphAttentionKernel(cache: cache)
        }
        guard let kernel = mpsGraphAttentionKernel else {
            throw BASCognitiveBrainAttentionError
                .mpsGraphKernelUnavailable
        }
        let descQ = BASTensorDescriptor.contiguous(
            shape: [qRows, qCols], dataType: .float32,
            backingKind: .metalBuffer,
            rankTag: _2D.rankTag)
        let descKV = BASTensorDescriptor.contiguous(
            shape: [kRows, qCols], dataType: .float32,
            backingKind: .metalBuffer,
            rankTag: _2D.rankTag)
        let qD = q.withUnsafeBufferPointer {
            Data(buffer: $0)
        }
        let kD = k.withUnsafeBufferPointer {
            Data(buffer: $0)
        }
        let vD = v.withUnsafeBufferPointer {
            Data(buffer: $0)
        }
        let inputs = BASKernelInputs(
            descriptors: [descQ, descKV, descKV],
            payloads: [qD, kD, vD])
        let out = try await kernel.evaluate(inputs: inputs)
        return BASCanonicalKernelInputBuilders
            .dataToFloatArray(
                out.payloads[0],
                elementCount: qRows * qCols)
    }

    public func dispatchSSMScan(
        x: [Float],
        delta: [Float],
        A: [Float],
        B: [Float],
        C: [Float],
        shape: BASSSMScanShape
    ) async throws -> [Float] {
        guard let loader = metalLibraryLoader else {
            throw BASMetalSSMScanDispatcherError
                .libraryUnavailable(
                    message:
                        "no metalLibraryLoader wired")
        }
        if metalSSMScanDispatcher == nil {
            metalSSMScanDispatcher =
                BASMetalSSMScanDispatcher(loader: loader)
        }
        guard let d = metalSSMScanDispatcher else {
            throw BASMetalSSMScanDispatcherError
                .libraryUnavailable(
                    message: "dispatcher init failed")
        }
        return try await d.dispatch(
            x: x, delta: delta, A: A, B: B, C: C,
            shape: shape)
    }

}
