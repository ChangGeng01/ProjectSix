// MARK: - BASAutoRouteRanker+DreamLoop
// God-object extraction (audit ch1040): the L9 Dream-Loop cluster — batch-scoring +
// dominance-order (i32 + f64) + telemetry + the test seam — split out of the
// BASAutoRouteRanker junk-drawer. Pure relocation, same namespace + symbols, byte-equal.

import Foundation
#if canImport(BASRustMemoryTrackerBinary)
import BASRustMemoryTrackerBinary
#endif
#if canImport(Darwin)
import Darwin
#endif

extension BASAutoRouteRanker {

    // MARK: - L9 Dream Loop batch-scoring (chapter 七百四十八 第一刀 / M2411)
    //
    // LAYER-MIGRATION ARC Swift bridge for L9 Dream Loop
    // batch-scoring kernel (Cargo/bas-dream-loop/src/lib.rs)。

    /// Returns the bas-dream-loop ABI version。
    public static func dreamLoopABIVersion() -> Int32 {
        #if os(iOS) || os(macOS)
        return bas_dream_loop_abi_version()
        #else
        return 0
        #endif
    }

    /// Batch-score candidates against a query via the L9
    /// Rust kernel。 Returns top-K candidate indices
    /// (descending by composite score),or nil on FFI
    /// fault (null pointer / bad shape)。
    public static func dreamLoopBatchScore(
        query: [Float],
        candidates: [[Float]],
        benefits: [Double],
        costs: [Double],
        topK: Int
    ) -> [Int32]? {
        #if os(iOS) || os(macOS)
        let n = candidates.count
        // deep-audit MED (rs-dream-loop): the Rust kernel reads exactly n*query.count f32 via
        // from_raw_parts(flat_ptr, n*dim). Without a per-ROW length check, a candidate row shorter
        // (or longer) than query.count makes flat.count != n*dim → the FFI reads out of bounds past
        // the Swift buffer (UB). Enforce the flat.count == n*query.count invariant here.
        guard n == benefits.count, n == costs.count,
              query.count > 0, candidates.allSatisfy({ $0.count == query.count })
        else { return nil }
        // Flatten candidates row-major
        var flat: [Float] = []
        flat.reserveCapacity(n * query.count)
        for c in candidates {
            flat.append(contentsOf: c)
        }
        var out = [Int32](repeating: -1, count: topK)
        let written = query.withUnsafeBufferPointer { qp -> Int32 in
            flat.withUnsafeBufferPointer { fp in
                benefits.withUnsafeBufferPointer { bp in
                    costs.withUnsafeBufferPointer { cp in
                        out.withUnsafeMutableBufferPointer {
                            op in
                            return bas_dream_loop_batch_score(
                                qp.baseAddress,
                                Int32(query.count),
                                fp.baseAddress,
                                Int32(n),
                                bp.baseAddress,
                                cp.baseAddress,
                                Int32(topK),
                                op.baseAddress,
                                Int32(topK))
                        }
                    }
                }
            }
        }
        if written < 0 { return nil }
        return Array(out.prefix(Int(written)))
        #else
        return nil
        #endif
    }

    // MARK: - L9 Dominance order (chapter 八百三十五 / M2826)
    //
    // Sorts indices [0, n) by `scores[i]` DESCENDING, stable on
    // ties。 Mirror of Swift `EBrainRuntimeCoordinator+
    // Candidates.swift` `candidateDominanceScore` sort —
    // returns ALL n indices (not truncated like batch-score top-K)。
    //
    // Use when the host needs the full frontier ordering for
    // composition (dominance order + reversible filter + guard
    // filter all derive from the same input scores)。 V1 Swift
    // path remains the production default;this opt-in routes
    // through the Rust SIMD-friendly sort when explicitly invoked。

    /// Sort indices [0, scores.count) descending by score, stable
    /// on ties。
    ///
    /// Empty input returns `[]` on iOS/macOS,`nil` on non-Apple
    /// platforms (Linux,etc.) where the FFI is unavailable。
    /// Non-empty input on non-Apple returns `nil`,routing callers
    /// to their Swift fallback path。 On iOS/macOS,returns `nil`
    /// only if the C ABI reports fault (`bas_dream_loop_dominance_order`
    /// returns negative — currently unreachable from this wrapper
    /// since we own both the input slice and output buffer,but the
    /// nil branch is preserved for forward-compat with future
    /// fault modes)。
    ///
    /// chapter 八百四十六 / M2883 — doc-comment corrected per
    /// post-v0.61.0 review finding L1。 The earlier wording claimed
    /// "nil impossible" but the C ABI does return -1 in some cases;
    /// the wrapper's own input invariants make those unreachable
    /// FROM THIS CALLER,but the nil signal is still semantically
    /// meaningful for cross-platform fallback dispatch。
    public static func dreamLoopDominanceOrder(
        scores: [Float]
    ) -> [Int32]? {
        // chapter 八百五十 / M2901 — telemetry increment
        atomicAdd1(&_f32CallCount)
        // chapter 八百五十一 / M2906 — test seam for forced fallback
        #if DEBUG
        if _testForceFallback {
            atomicAdd1(&_f32FallbackCount)
            return nil
        }
        #endif
        #if os(iOS) || os(macOS)
        let n = scores.count
        if n == 0 { return [] }
        var out = [Int32](repeating: -1, count: n)
        let written = scores.withUnsafeBufferPointer { sp -> Int32 in
            out.withUnsafeMutableBufferPointer { op in
                return bas_dream_loop_dominance_order(
                    sp.baseAddress,
                    Int32(n),
                    op.baseAddress,
                    Int32(n))
            }
        }
        if written < 0 {
            atomicAdd1(&_f32FallbackCount)
            return nil
        }
        return Array(out.prefix(Int(written)))
        #else
        atomicAdd1(&_f32FallbackCount)
        return nil
        #endif
    }

    // MARK: - L9 Dominance order telemetry (chapter 八百五十 / M2901)
    //
    // Lightweight observability for the L9 dominance order dispatch。
    // Hosts can read counters at any time to verify:
    //   - The Rust path is actually firing in production
    //     (not just shadowed by a silent fallback regression)
    //   - Call frequency for capacity planning / cost attribution
    //   - Float vs Double variant uptake
    //
    // Implementation:nonisolated(unsafe) integer counters
    // protected by a lock-free atomic increment via
    // OSAtomicIncrement32 equivalent。 The increment cost is
    // ~1-2 ns per call on Apple Silicon (LDADD instruction) —
    // <0.1% of the routed call's walltime even at small N。
    //
    // The counters are PROCESS-WIDE。 Hosts running multiple
    // BAS instances will see merged counts。 If per-instance
    // attribution is needed,filter by host-owned site identifiers
    // at the consumer level。

    /// Snapshot of per-call counters。 Immutable value type;
    /// fetched via `dominanceOrderTelemetrySnapshot()`。
    public struct DominanceOrderTelemetrySnapshot:
        Equatable, Sendable
    {
        /// Total calls to `dreamLoopDominanceOrder(scores:)`
        /// (the Float32 variant) since process start or last
        /// reset。 Includes both Rust-success and Rust-fault paths。
        public var f32CallCount: Int

        /// Calls where the Rust path returned `nil` (either FFI
        /// fault or non-Apple platform)。 Increments BEFORE the
        /// caller's Swift fallback fires。
        public var f32FallbackCount: Int

        /// Total calls to `dreamLoopDominanceOrderDouble(scores:)`
        /// (the Float64 variant introduced in chapter 八百四十七)。
        public var f64CallCount: Int

        /// Fallback count for the f64 variant。 Same semantics
        /// as f32FallbackCount。
        public var f64FallbackCount: Int

        /// Convenience:total dominance-order calls across both
        /// variants since reset。
        public var totalCallCount: Int {
            f32CallCount + f64CallCount
        }

        /// Convenience:total fallbacks across both variants。
        public var totalFallbackCount: Int {
            f32FallbackCount + f64FallbackCount
        }

        /// Convenience:fraction of calls that fell back to Swift。
        /// Returns 0 when `totalCallCount == 0`。
        public var fallbackFraction: Double {
            guard totalCallCount > 0 else { return 0 }
            return Double(totalFallbackCount)
                / Double(totalCallCount)
        }
    }

    // Storage:nonisolated(unsafe) Int with atomic increments via
    // OSAtomicAdd32 (POSIX-equivalent on Apple)。 Using Int (machine
    // word) so 32-bit and 64-bit builds work — but increment uses
    // `Int32` operations under the hood,wrapping at 2^31 which is
    // a practical never under normal call frequencies。
    nonisolated(unsafe) private static var _f32CallCount:
        Int32 = 0
    nonisolated(unsafe) private static var _f32FallbackCount:
        Int32 = 0
    nonisolated(unsafe) private static var _f64CallCount:
        Int32 = 0
    nonisolated(unsafe) private static var _f64FallbackCount:
        Int32 = 0

    /// Atomic increment helper。 Uses `OSAtomicAdd32` on Apple
    /// platforms (compiles to LDADD on AArch64,a single
    /// uncontended instruction)。 On non-Apple platforms,falls
    /// back to non-atomic `&+= 1` — telemetry on Linux is
    /// best-effort since BAS is Apple-platform-primary。
    ///
    /// chapter 八百五十一 / M2906 — original chapter 八百五十
    /// implementation used naive `&+= 1` which is NOT atomic
    /// (three-op read-modify-write,loses updates under
    /// contention)。 The chapter 八百五十一 concurrent-call test
    /// caught this:1000 parallel calls produced 988/1000
    /// counter ticks (12 updates lost to race)。 Fixed by using
    /// the system-level atomic-add intrinsic。
    @inline(__always)
    private static func atomicAdd1(_ ptr: UnsafeMutablePointer<Int32>) {
        #if canImport(Darwin)
        // OSAtomicAdd32 is API-deprecated but ABI-stable + still
        // emits LDADD on ARMv8.1+ (which includes all Apple Silicon
        // + iPhone XS / iPad Pro 2018 onward = all currently-
        // supported Apple devices)。 Recommended replacement is
        // C11 stdatomic via a C shim,but for a single relaxed-
        // ordering counter increment OSAtomic is fully equivalent。
        _ = OSAtomicAdd32(1, ptr)
        #else
        ptr.pointee &+= 1
        #endif
    }

    /// Read the current telemetry snapshot。 Thread-safe;the
    /// counts may not perfectly agree across the 4 fields if a
    /// concurrent increment fires mid-read,but each individual
    /// count is monotonic + correct under relaxed atomic semantics。
    public static func dominanceOrderTelemetrySnapshot()
        -> DominanceOrderTelemetrySnapshot
    {
        DominanceOrderTelemetrySnapshot(
            f32CallCount: Int(_f32CallCount),
            f32FallbackCount: Int(_f32FallbackCount),
            f64CallCount: Int(_f64CallCount),
            f64FallbackCount: Int(_f64FallbackCount))
    }

    /// Reset all counters to zero。 Intended for test-suite
    /// hygiene — production hosts typically only READ。
    public static func resetDominanceOrderTelemetry() {
        _f32CallCount = 0
        _f32FallbackCount = 0
        _f64CallCount = 0
        _f64FallbackCount = 0
    }

    // MARK: - Test seam: forced-fallback (chapter 八百五十一 / M2906)
    //
    // Debug-build-only seam that lets tests exercise the Swift
    // fallback path on Apple platforms。 Agent-B review at chapter
    // 八百四十五 flagged that the fallback is untested on Apple
    // (CRITICAL-1) since the FFI never returns nil under current
    // call-site invariants — the Swift `if let` branch always
    // takes the Rust result。 Without a seam,a future FFI
    // regression that DID return nil would activate Swift code
    // paths that have no test coverage。
    //
    // The seam is `#if DEBUG`-gated so production builds skip
    // the check entirely (zero overhead)。 Tests use the SPI to
    // flip the flag,exercise the call,then reset。

    #if DEBUG
    nonisolated(unsafe) private static var _testForceFallback:
        Bool = false

    /// Set/clear the forced-fallback flag。 When `true`,both
    /// `dreamLoopDominanceOrder` and
    /// `dreamLoopDominanceOrderDouble` will return `nil` BEFORE
    /// calling the FFI,as if the C ABI had reported fault。
    /// Telemetry fallback-count still increments。
    ///
    /// PRODUCTION CODE MUST NEVER CALL THIS。 The flag is
    /// `#if DEBUG`-gated and the method symbol does not exist
    /// in Release builds。 Marked `@_spi(BASTestSeam)` to make
    /// the testing-only intent visible at consumer call sites。
    @_spi(BASTestSeam)
    public static func _setForceFallbackForTesting(_ force: Bool) {
        _testForceFallback = force
    }

    // audit orchestration MED-2 — test seam: substitute an injected raw index array for the FFI's
    // output, so a test can PROVE the wrapper's permutation validation rejects a corrupt (OOB /
    // short / duplicate) return by falling back to nil, instead of passing it to a call site whose
    // precondition would abort the whole process. #if DEBUG-gated; the symbol is absent in Release.
    nonisolated(unsafe) private static var _testInjectRawIndices: [Int32]? = nil

    /// Set/clear the injected raw-index array. When non-nil, `dreamLoopDominanceOrderDouble`
    /// validates THESE indices (as if the C ABI had returned them) instead of calling the FFI.
    @_spi(BASTestSeam)
    public static func _setInjectRawIndicesForTesting(_ raw: [Int32]?) {
        _testInjectRawIndices = raw
    }
    #endif

    /// audit orchestration MED-2 — validate that a Rust dominance-order FFI return is a genuine
    /// permutation of `0..<count` (exact length, every index in range, no duplicates). Returns nil
    /// on ANY violation so callers fall back to the Swift `.sorted` path instead of aborting the
    /// process with a call-site `precondition`. Pure + injectable ⇒ unit-testable without the FFI.
    /// A healthy kernel always returns a full permutation, so this is a no-op on the happy path.
    public static func validatedPermutation(_ raw: [Int32], count: Int) -> [Int32]? {
        guard raw.count == count else { return nil }
        var seen = Set<Int32>()
        seen.reserveCapacity(count)
        for idx in raw {
            guard idx >= 0, idx < Int32(count), seen.insert(idx).inserted else { return nil }
        }
        return raw
    }

    // MARK: - L9 Dominance order (f64 — chapter 八百四十七 / M2886)
    //
    // Same as `dreamLoopDominanceOrder(scores:)` but accepts
    // `[Double]` to eliminate the Float32 narrowing risk identified
    // by the post-八百四十六 strict review。 Production call sites
    // SHOULD prefer this variant whenever the source values are
    // Double (which is every Swift call site since Swift's default
    // numeric type is Double)。
    //
    // The Float32 variant remains for callers whose scores are
    // already Float (e.g., the chapter 八百三十六 wrapper-invariant
    // tests)。

    /// Sort indices [0, scores.count) descending by Double score,
    /// stable on ties。 Distinguishes Doubles that round to the
    /// same Float32 (which the Float variant ties)。
    ///
    /// Empty input returns `[]` on iOS/macOS,`nil` on non-Apple
    /// platforms where the FFI is unavailable (routing callers to
    /// their Swift fallback path)。
    public static func dreamLoopDominanceOrderDouble(
        scores: [Double]
    ) -> [Int32]? {
        // chapter 八百五十 / M2901 — telemetry increment
        atomicAdd1(&_f64CallCount)
        // chapter 八百五十一 / M2906 — test seam for forced fallback
        #if DEBUG
        if _testForceFallback {
            atomicAdd1(&_f64FallbackCount)
            return nil
        }
        #endif
        #if os(iOS) || os(macOS)
        let n = scores.count
        if n == 0 { return [] }
        #if DEBUG
        // audit orchestration MED-2 seam: validate injected indices exactly as a real FFI return.
        if let injected = _testInjectRawIndices {
            guard let permutation = Self.validatedPermutation(injected, count: n) else {
                atomicAdd1(&_f64FallbackCount)
                return nil
            }
            return permutation
        }
        #endif
        var out = [Int32](repeating: -1, count: n)
        let written = scores.withUnsafeBufferPointer { sp -> Int32 in
            out.withUnsafeMutableBufferPointer { op in
                return bas_dream_loop_dominance_order_f64(
                    sp.baseAddress,
                    Int32(n),
                    op.baseAddress,
                    Int32(n))
            }
        }
        if written < 0 {
            atomicAdd1(&_f64FallbackCount)
            return nil
        }
        // audit orchestration MED-2: validate the kernel's return is a full permutation of 0..<n.
        // A corrupt / short / duplicate return becomes a SAFE nil fallback HERE (→ each call site's
        // Swift `.sorted` path), never a process-aborting precondition at the 5 call sites — which
        // now map over a guaranteed-valid permutation.
        guard let permutation = Self.validatedPermutation(Array(out.prefix(Int(written))), count: n) else {
            atomicAdd1(&_f64FallbackCount)
            return nil
        }
        return permutation
        #else
        atomicAdd1(&_f64FallbackCount)
        return nil
        #endif
    }
}
