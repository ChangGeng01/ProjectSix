// MARK: - BASCognitiveBrain ANE-tiered kernels + full 8-op coverage (ch999/ch1000)
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
    // MARK: - chapter 九百九十九 / M3700 — elegant ANE
    //         consultation generic + extended op coverage
    //
    // Pre-fix:ch 998 wired ONE op (softmax) with 3-line copy-
    // paste boilerplate (tier-read + counter-bump + dispatch)。
    // For 8 BASNeuralOp cases that's 24 lines of duplication
    // and 8 separate maintenance burdens。 Plus the existing
    // *Auto functions silently consumed the tier — callers
    // couldn't observe what tier the classifier reported,only
    // that consultation happened。
    //
    // Ch 999 elegant evolution:
    //
    //   1. Single generic helper `aneConsulted(op:dispatch:)`
    //      that runs the classifier consult + counter bump +
    //      caller's dispatch closure in one call。 Zero
    //      boilerplate at each call site。
    //
    //   2. New parallel set of `*AutoWithANETier` functions
    //      that EXPOSE the tier alongside the dispatch result,
    //      so callers who want the host-observable signal
    //      (e.g. for telemetry / future routing logic) can
    //      read both。 Existing `*Auto` functions stay byte-
    //      equal — they call the helper internally but
    //      discard the tier (observe-only doctrine preserved)。
    //
    //   3. Wire across all 4 BASNeuralOp-mapped public entry
    //      points on this brain class:softmaxAuto,
    //      layerNormAuto,plus the in-method matMul + attention
    //      consultations (covered separately at their call
    //      sites since they live inside larger pipeline
    //      methods,not standalone *Auto entries)。 The 4
    //      missing ops (rotaryEmbedding,conv2D,rmsNorm,
    //      ssmScan) get the helper when their *Auto entries
    //      land in future chapters。
    //
    //   4. The helper is `@inlinable` so call-site cost is the
    //      same as the inlined copy-paste version。 No
    //      indirection overhead。 Just the boilerplate
    //      elimination + tier exposure。

    /// Result bundle for an ANE-consulted op:dispatch result
    /// + the classifier's tier verdict for the op type。
    /// Sendable so it can cross actor boundaries safely。
    public struct BASANEConsultedResult<Value: Sendable>:
        Sendable
    {
        public let value: Value
        public let aneTier: BASANEEligibilityTier

        public init(
            value: Value,
            aneTier: BASANEEligibilityTier
        ) {
            self.value = value
            self.aneTier = aneTier
        }
    }

    /// chapter 一千.5 / M3705.5 — single canonical consultation
    /// side-effect。 Pre-fix:both the sync `aneConsulted` helper
    /// AND the async variant AND the 2 instance-bound inline
    /// methods (matMulAutoWithANETier + attentionAutoWithANETier)
    /// performed the SAME 2-step consultation (tier-read +
    /// counter-bump)。 4 copies of identical logic = divergence
    /// risk:if a future arc adds (e.g.) a thermal probe call
    /// to the consultation,3 of the 4 copies would silently
    /// stay at the old behavior。 Same orphan-class bug pattern
    /// the cascade has caught for 7 consecutive rounds。
    ///
    /// Fix:single `recordANEConsultation(op:)` static method
    /// that BOTH variants of the generic helper AND the 2
    /// instance-bound inline methods call。 Now there's exactly
    /// ONE place to maintain the consultation logic。 If thermal
    /// probe is added at a future chapter,update this one method
    /// + all 4 call paths get it automatically。
    @inlinable
    public nonisolated static func recordANEConsultation(
        op: BASNeuralOp
    ) -> BASANEEligibilityTier {
        let tier = BASANEKernelEligibilityClassifier
            .tier(for: op)
        BASANEKernelEligibilityClassifier
            .executorConsultationCount += 1
        return tier
    }

    /// Generic ANE-consultation wrapper。 Runs the classifier's
    /// tier(for:op) check + increments the executor counter +
    /// invokes the caller-supplied dispatch closure。 Returns
    /// the dispatch result wrapped with the tier verdict。
    ///
    /// Observe-only:the tier is captured + returned to caller
    /// but the substrate does NOT use it for dispatch routing
    /// at this chapter。 Future arc may flip the static-let
    /// invariant when actual routing branches on tier。
    ///
    /// chapter 一千.5:delegates to `recordANEConsultation(op:)`
    /// for the consultation side-effect — single canonical
    /// implementation。
    @inlinable
    public nonisolated static func aneConsulted<Value: Sendable>(
        op: BASNeuralOp,
        dispatch: () -> Value
    ) -> BASANEConsultedResult<Value> {
        let tier = recordANEConsultation(op: op)
        return BASANEConsultedResult(
            value: dispatch(),
            aneTier: tier)
    }

    /// chapter 一千 / M3705 — async variant of `aneConsulted`
    /// for ops dispatched via actor-isolated paths (matMul +
    /// attention go through Metal/MPSGraph actors;ssmScan
    /// dispatches via BASMetalSSMScanDispatcher actor)。 Same
    /// observe-only doctrine — tier captured + returned but
    /// substrate doesn't branch dispatch on it。 `rethrows`
    /// preserves the caller's error-handling contract。
    ///
    /// chapter 一千.5:delegates to `recordANEConsultation(op:)`。
    @inlinable
    public nonisolated static func aneConsulted<Value: Sendable>(
        op: BASNeuralOp,
        dispatch: () async throws -> Value
    ) async rethrows -> BASANEConsultedResult<Value> {
        let tier = recordANEConsultation(op: op)
        return BASANEConsultedResult(
            value: try await dispatch(),
            aneTier: tier)
    }

    /// chapter 七百九 第四刀 / M2219 — auto-routed softmax。
    ///
    /// Always routes through Rust scalar (measured tie with
    /// SIMD,scalar is simpler)。 Returns the normalized
    /// probability vector + which path executed。
    ///
    /// chapter 九百九十八 / M3695 → ch 999 / M3700 evolution:
    /// the ANE consultation that ch 998 inlined as 3 lines is
    /// now delegated to the generic `aneConsulted(op:dispatch:)`
    /// helper。 Byte-equal behavior + same counter increment +
    /// less boilerplate。 The tier is discarded here (observe-
    /// only doctrine);callers wanting to observe the tier
    /// alongside the softmax result use `softmaxAutoWithANETier`
    /// (below)。
    public nonisolated static func softmaxAuto(
        _ x: [Float]
    ) -> BASAutoRouteResult<[Float]> {
        return aneConsulted(op: .softmax) {
            BASAutoRouteRanker.softmax(x)
        }.value
    }

    /// chapter 九百九十九 / M3700 — same dispatch as `softmaxAuto`
    /// but exposes the ANE classifier's tier verdict for the
    /// caller to observe (e.g. telemetry,future routing logic)。
    public nonisolated static func softmaxAutoWithANETier(
        _ x: [Float]
    ) -> BASANEConsultedResult<BASAutoRouteResult<[Float]>> {
        return aneConsulted(op: .softmax) {
            BASAutoRouteRanker.softmax(x)
        }
    }

    /// chapter 七百九 第四刀 / M2219 — auto-routed LayerNorm。
    ///
    /// Routes between Rust naive (dim < 128) and Rust affine
    /// SIMD (dim ≥ 128) based on measured crossover。 Plain
    /// LayerNorm with γ=1 β=0。
    ///
    /// chapter 九百九十九 / M3700 — wired through
    /// `aneConsulted(op: .layerNorm,...)` so the ANE
    /// classifier is consulted before dispatch + the executor
    /// counter increments per call。 Observe-only:dispatch
    /// behavior unchanged。
    public nonisolated static func layerNormAuto(
        _ x: [Float], eps: Float = 1e-5,
        thresholds: BASAutoRouteThresholds = .mSeriesDefault
    ) -> BASAutoRouteResult<[Float]> {
        return aneConsulted(op: .layerNorm) {
            BASAutoRouteRanker.layerNorm(
                x, eps: eps, thresholds: thresholds)
        }.value
    }

    /// chapter 九百九十九 / M3700 — `layerNormAuto` variant
    /// exposing the ANE classifier's tier verdict alongside
    /// the result。
    public nonisolated static func layerNormAutoWithANETier(
        _ x: [Float], eps: Float = 1e-5,
        thresholds: BASAutoRouteThresholds = .mSeriesDefault
    ) -> BASANEConsultedResult<BASAutoRouteResult<[Float]>> {
        return aneConsulted(op: .layerNorm) {
            BASAutoRouteRanker.layerNorm(
                x, eps: eps, thresholds: thresholds)
        }
    }

    /// chapter 七百十一 第四刀 / M2229 — auto-routed GELU exact。
    ///
    /// y = 0.5*x*(1 + erf(x/√2))。 Matches
    /// torch.nn.functional.gelu (default mode)。 Always routes
    /// through Rust scalar (measured M-series win — SIMD parity
    /// within ±1% since erf cost dominates)。
    public nonisolated static func geluAuto(
        _ x: [Float]
    ) -> BASAutoRouteResult<[Float]> {
        return BASAutoRouteRanker.gelu(x)
    }

    /// chapter 七百十一 第四刀 / M2229 — auto-routed GELU tanh
    /// approximation。
    ///
    /// y = 0.5*x*(1 + tanh(√(2/π)*(x + 0.044715*x³)))。 Matches
    /// torch.nn.functional.gelu(approximate="tanh")。 Routes
    /// between Rust scalar (dim < 256) and Rust SIMD (dim ≥ 256)
    /// per measured crossover。
    public nonisolated static func geluTanhAuto(
        _ x: [Float],
        thresholds: BASAutoRouteThresholds = .mSeriesDefault
    ) -> BASAutoRouteResult<[Float]> {
        return BASAutoRouteRanker.geluTanhApprox(
            x, thresholds: thresholds)
    }

    /// chapter 七百十一 第四刀 / M2229 — auto-routed SiLU
    /// (= Swish, beta=1)。
    ///
    /// y = x*σ(x) = x/(1+e⁻ˣ)。 Matches
    /// torch.nn.functional.silu。 Always routes through Rust
    /// scalar (measured M-series win — SIMD parity within ±2%
    /// since sigmoid's exp() cost dominates the loop)。
    public nonisolated static func siluAuto(
        _ x: [Float]
    ) -> BASAutoRouteResult<[Float]> {
        return BASAutoRouteRanker.silu(x)
    }

    // MARK: - chapter 一千 / M3705 — 全面开发 full 8-op coverage
    //
    // After ch 999 wired softmax + layerNorm (2 of 8 BASNeuralOp
    // cases),ch 1000 closes the remaining 6 with consultation
    // entry points + WithANETier variants:
    //   - matMul (heavy production op via Metal/MPSGraph actor)
    //   - attention (heavy production op via MPSGraph actor)
    //   - rmsNorm (scaffold for future rmsNorm kernel)
    //   - rotaryEmbedding (scaffold for future RoPE kernel)
    //   - conv2D (scaffold for future conv2D kernel)
    //   - ssmScan (Mamba state-space scan via BASMetalSSMScan
    //     Dispatcher actor)
    //
    // All 6 use the new async aneConsulted variant since they
    // dispatch through actor boundaries。 The 3 scaffold entries
    // (rmsNorm / rotaryEmbedding / conv2D) preserve the
    // consultation pattern even though no production kernel
    // wires them yet — when a future arc ships the kernel + its
    // dispatch entry,the consultation call ALREADY exists at
    // the public surface and just needs the kernel hooked in。

    /// chapter 一千 / M3705 — ANE-consulted matMul entry。
    /// Wraps the existing matMulAuto (which dispatches through
    /// Metal MSL / MPSGraph actor / Rust SIMD paths per
    /// matMulChoice) with the ANE classifier consultation。
    /// Observe-only:tier captured + returned for caller's
    /// host-observable signal,but dispatch path unchanged。
    public func matMulAutoWithANETier(
        a: [Float], aRows: Int, aCols: Int,
        b: [Float], bRows: Int, bCols: Int,
        thresholds: BASAutoRouteThresholds = .mSeriesDefault
    ) async throws ->
        BASANEConsultedResult<BASAutoRouteResult<[Float]>>
    {
        // chapter 一千.5 fix:single canonical consultation via
        // recordANEConsultation。 Pre-fix this method inlined
        // the 2-step consultation,creating a 4-copy divergence
        // risk with the generic helpers (sync + async)。 Now
        // ALL 4 paths share one canonical implementation。
        let tier = Self.recordANEConsultation(op: .matMul)
        let result = try await self.matMulAuto(
            a: a, aRows: aRows, aCols: aCols,
            b: b, bRows: bRows, bCols: bCols,
            thresholds: thresholds)
        return BASANEConsultedResult(
            value: result, aneTier: tier)
    }

    /// chapter 一千 / M3705 — ANE-consulted RMSNorm scaffold。
    /// No production kernel calls this yet — the consultation
    /// entry ships ahead of the kernel so future arc can plug
    /// the kernel dispatch into the closure。 Returns
    /// BASANEConsultedResult<Void>:counter increments + tier
    /// captured but no dispatch happens (closure no-ops)。
    /// Hosts wanting to drive an RMSNorm dispatch use their
    /// own kernel + this entry simultaneously。
    public nonisolated static func rmsNormAutoWithANETier(
    ) -> BASANEConsultedResult<Void> {
        return aneConsulted(op: .rmsNorm) {
            // ch 1000:scaffold — no production kernel wires
            // here yet。 Future arc fills this in。
        }
    }

    /// chapter 一千 / M3705 — ANE-consulted rotaryEmbedding
    /// scaffold (same pattern as rmsNorm)。
    public nonisolated static func rotaryEmbeddingAutoWithANETier(
    ) -> BASANEConsultedResult<Void> {
        return aneConsulted(op: .rotaryEmbedding) { }
    }

    /// chapter 一千 / M3705 — ANE-consulted conv2D scaffold
    /// (same pattern as rmsNorm + rotaryEmbedding)。
    public nonisolated static func conv2DAutoWithANETier(
    ) -> BASANEConsultedResult<Void> {
        return aneConsulted(op: .conv2D) { }
    }

    /// chapter 一千 / M3705 — ANE-consulted attention entry。
    /// Wraps the existing attentionAuto (which dispatches
    /// through Metal MSL / MPSGraph actor / CPU fallback per
    /// attentionChoice) with the ANE classifier consultation。
    /// Observe-only:tier captured for caller's host-observable
    /// signal but dispatch path unchanged byte-equal。
    public func attentionAutoWithANETier(
        q: [Float], qRows: Int, qCols: Int,
        k: [Float], kRows: Int,
        v: [Float], vCols: Int,
        thresholds: BASAutoRouteThresholds = .mSeriesDefault
    ) async throws ->
        BASANEConsultedResult<BASAutoRouteResult<[Float]>>
    {
        // chapter 一千.5 fix:single canonical consultation via
        // recordANEConsultation (same as matMulAutoWithANETier
        // refactor)。 Sendable constraint on async closures
        // capturing instance self still prevents direct
        // delegation to the generic aneConsulted helper,but
        // the consultation side-effect itself is now a single
        // canonical call。
        let tier = Self.recordANEConsultation(op: .attention)
        let result = try await self.attentionAuto(
            q: q, qRows: qRows, qCols: qCols,
            k: k, kRows: kRows,
            v: v, vCols: vCols,
            thresholds: thresholds)
        return BASANEConsultedResult(
            value: result, aneTier: tier)
    }

    /// chapter 一千 / M3705 — ANE-consulted SSM-scan scaffold。
    /// The production Mamba SSM scan goes through
    /// BASMetalSSMScanDispatcher (ch 720+ actor) which lives
    /// in BASMetalSubstrate — invoked from BASCognitiveBrain
    /// at line ~3211。 This entry adds the ANE classifier
    /// consultation without changing the dispatcher call;
    /// hosts wanting the consultation+dispatch pair use both
    /// in sequence。 Scaffold form keeps the dispatch closure
    /// empty so the consultation is uncoupled from kernel
    /// invocation timing。
    public nonisolated static func ssmScanAutoWithANETier(
    ) -> BASANEConsultedResult<Void> {
        return aneConsulted(op: .ssmScan) { }
    }

    /// chapter 七百十二 第四刀 / M2234 — auto-routed ledger seal。
    ///
    /// y = SHA256(canonical)。 Byte-equal to Swift CryptoKit。
    /// Always routes through Rust (5-8× win over CryptoKit per
    /// chapter 七百十二 第三刀 tournament across chain depths
    /// 1/16/256/4096)。
    public nonisolated static func ledgerSealAuto(
        _ canonical: [UInt8]
    ) -> BASAutoRouteResult<[UInt8]> {
        return BASAutoRouteRanker.ledgerSeal(canonical)
    }

    /// chapter 七百十二 第四刀 / M2234 — auto-routed batch ledger
    /// seal。 For each record,write its 32-byte SHA256(canonical)
    /// into the returned [[UInt8]]。 Used by the audit-ledger
    /// append path to amortize FFI overhead across N entries
    /// (1.3-1.31× over per-entry FFI in chapter 七百十二 第三刀)。
    public nonisolated static func ledgerSealBatchAuto(
        initialHash: [UInt8],
        canonicals: [[UInt8]]
    ) -> BASAutoRouteResult<[[UInt8]]> {
        return BASAutoRouteRanker.ledgerSealBatch(
            initialHash: initialHash,
            canonicals: canonicals)
    }

    /// chapter 七百十二 第四刀 / M2234 — auto-routed chain verify。
    /// Returns the chain tip on success or the first failing
    /// index on tamper detection。 Always routes through Rust
    /// (2.85-3.06× win over CryptoKit per chapter 七百十二 第三刀
    /// tournament at depths 16/256/4096)。
    public nonisolated static func ledgerVerifyChainAuto(
        initialHash: [UInt8],
        canonicals: [[UInt8]],
        expectedSelfHashes: [[UInt8]]
    ) -> BASAutoRouteResult<
        BASAutoRouteRanker.BASLedgerVerifyOutcome>
    {
        return BASAutoRouteRanker.ledgerVerifyChain(
            initialHash: initialHash,
            canonicals: canonicals,
            expectedSelfHashes: expectedSelfHashes)
    }

    /// chapter 七百十三 第四刀 / M2239 — auto-routed forget
    /// cascade partition。
    ///
    /// Per architectural matrix「Rust:Memory engine + forget
    /// cascade」 — set-difference partition with O(N+M) HashSet
    /// membership。 Returns (kept,removed) index lists in input
    /// order so callers can partition their own typed record
    /// arrays without paying Codable serialization across FFI。
    public nonisolated static func forgetCascadeFilterAuto(
        recordIds: [String],
        targetIds: [String]
    ) -> BASAutoRouteResult<(
        kept: [Int], removed: [Int]
    )> {
        return BASAutoRouteRanker.forgetCascadeFilter(
            recordIds: recordIds,
            targetIds: targetIds)
    }

    /// chapter 七百十三 第四刀 / M2239 — auto-routed provenance
    /// gate decision。
    ///
    /// Per matrix「Rust:provenance + integrity hash」 — typed
    /// rejection ladder mirroring
    /// `BASOrganTrainedWeightFilter.rejectionReason` exactly。
    /// Returns the typed decision + routing choice;callers
    /// switch on `.permitted` vs the rejection variants for
    /// stable audit telemetry。
    public nonisolated static func provenanceFilterAuto(
        trainingCorpusHashHex: String,
        trainedWeightsHashHex: String,
        tier: BASProvenanceTier,
        hasAttestationSignatureRef: Bool,
        hasAttestationIssuedAt: Bool
    ) -> BASAutoRouteResult<BASProvenanceGateDecision> {
        return BASAutoRouteRanker.provenanceFilter(
            trainingCorpusHashHex: trainingCorpusHashHex,
            trainedWeightsHashHex: trainedWeightsHashHex,
            tier: tier,
            hasAttestationSignatureRef:
                hasAttestationSignatureRef,
            hasAttestationIssuedAt: hasAttestationIssuedAt)
    }

    /// chapter 七百十五 第四刀 / M2249 — auto-routed batched
    /// cosine similarity。
    ///
    /// Per matrix「Metal:embedding similarity」 — but per
    /// chapter 七百十五 第三刀 tournament Rust SIMD wins at all
    /// measured M-series sizes (1.06×-90× faster than Metal
    /// up to 4096 × 512)。 Default threshold
    /// `batchedCosineMetalMinRows = 16384` means production
    /// callers always get Rust SIMD。 Future hardware where
    /// the crossover shifts can lower the threshold via
    /// calibration。
    ///
    /// Sync-only variant — always Rust SIMD path。 For Metal-
    /// dispatch async variant see `batchedCosineAutoMetal`
    /// which takes a dispatcher argument。
    public nonisolated static func batchedCosineAuto(
        query: [Float],
        corpus: [Float],
        dim: Int,
        thresholds: BASAutoRouteThresholds = .mSeriesDefault
    ) -> BASAutoRouteResult<[Float]> {
        return BASAutoRouteRanker.batchedCosineSimilarity(
            query: query, corpus: corpus, dim: dim,
            thresholds: thresholds)
    }

    /// chapter 七百八 第三刀 / M2213 — auto-routed MatMul。
    public func matMulAuto(
        a: [Float], aRows: Int, aCols: Int,
        b: [Float], bRows: Int, bCols: Int,
        thresholds: BASAutoRouteThresholds = .mSeriesDefault
    ) async throws -> BASAutoRouteResult<[Float]> {
        try await metalKernels.matMulAuto(a: a, aRows: aRows, aCols: aCols, b: b, bRows: bRows, bCols: bCols, thresholds: thresholds)
    }

    /// Picks the empirically fastest implementation per shape:
    ///   M*N <  64  → CPU reference (Metal pipeline overhead
    ///                 dominates at tiny shapes)
    ///   M*N >= 64  → Metal FlashAttention (CURRENT routing,but
    ///                 see chapter 八百六十八 / M2996 correction
    ///                 below — the original claim of 「1.24-1.62×
    ///                 faster than scaled_dot_product per chapter
    ///                 七百七 第二刀」 was UNBACKED by an asserted
    ///                 test。 Live measurement on this Mac mini
    ///                 shows FA is actually 1.07-1.10× SLOWER
    ///                 than scaled_dot_product at every shape ≥
    ///                 small。 See BASChapter868...AssertedBenchmark
    ///                 tests for the pinned numbers + ratios。 The
    ///                 routing rule is DEFERRED-PENDING data from
    ///                 the 4th contestant (MPSGraph attention,
    ///                 chapter 八百六十九 scope) — flipping the
    ///                 routing before MPSGraph is measured risks
    ///                 picking the second-worst option。)
    ///
    /// Returns BASAutoRouteResult so callers / telemetry can
    /// inspect which path actually executed。
    public func attentionAuto(
        q: [Float], qRows: Int, qCols: Int,
        k: [Float], kRows: Int,
        v: [Float], vCols: Int,
        thresholds: BASAutoRouteThresholds = .mSeriesDefault
    ) async throws -> BASAutoRouteResult<[Float]> {
        try await metalKernels.attentionAuto(q: q, qRows: qRows, qCols: qCols, k: k, kRows: kRows, v: v, vCols: vCols, thresholds: thresholds)
    }

    /// chapter 七百七 第一刀 / M2206 — tiled FlashAttention path。
    /// Mathematically equivalent to `attention(...)` but uses
    /// O(N) memory via online softmax + key/value tiling。 Wins
    /// over the standard kernel for long sequences (N ≥ ~256)
    /// or large head dim — the standard kernel materializes the
    /// full N×N attention matrix while FlashAttention keeps
    /// only O(B_r × D + B_c × D) resident。
    ///
    /// V1 tile sizes: B_r = B_c = 32, head dim cap 64。
    public func flashAttention(
        q: [Float], qRows: Int, qCols: Int,
        k: [Float], kRows: Int,
        v: [Float], vCols: Int
    ) async throws -> [Float] {
        try await metalKernels.flashAttention(q: q, qRows: qRows, qCols: qCols, k: k, kRows: kRows, v: v, vCols: vCols)
    }

    /// chapter 八百七十 / M3016 — MPSGraph attention dispatch。
    ///
    /// Live measurement at chapter 八百六十九 showed MPSGraph
    /// (warm cache) is 2.31-3.09× FASTER than both
    /// scaled_dot_product (`brain.attention`) AND FlashAttention
    /// (`brain.flashAttention`) at production shapes。 The
    /// auto-router at chapter 八百七十 routes M*N≥64 +
    /// shape.Dv == shape.D to this entry。
    ///
    /// CONSTRAINT: qCols must equal vCols (Dv == D)。 Callers
    /// hitting this constraint should route through
    /// `attentionAuto` which falls back to `.metalStandardAttention`
    /// automatically when Dv ≠ D — or call `attention(...)` /
    /// `flashAttention(...)` directly。
    ///
    /// Throws `BASCognitiveBrainAttentionError.mpsGraphDvDimensionMustEqualD`
    /// when the constraint is violated。
    public func mpsGraphAttention(
        q: [Float], qRows: Int, qCols: Int,
        k: [Float], kRows: Int,
        v: [Float], vCols: Int
    ) async throws -> [Float] {
        try await metalKernels.mpsGraphAttention(q: q, qRows: qRows, qCols: qCols, k: k, kRows: kRows, v: v, vCols: vCols)
    }

    /// 主线 继续 开发 — public Metal compute entry point。
    /// Lets brain hosts dispatch the SSMScan kernel
    /// without constructing a dispatcher themselves。
    /// Throws if no Metal loader is wired OR if the
    /// kernel dispatch fails (any
    /// BASMetalSSMScanDispatcherError case)。
    ///
    /// Memoizes the dispatcher across calls so the
    /// pipeline state + command queue are reused — same
    /// amortization story as warmMetalKernel()。
    public func dispatchSSMScan(
        x: [Float],
        delta: [Float],
        A: [Float],
        B: [Float],
        C: [Float],
        shape: BASSSMScanShape
    ) async throws -> [Float] {
        try await metalKernels.dispatchSSMScan(x: x, delta: delta, A: A, B: B, C: C, shape: shape)
    }
}
