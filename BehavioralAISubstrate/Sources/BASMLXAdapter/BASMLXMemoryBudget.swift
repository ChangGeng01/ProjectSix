import Foundation

/// Pure (framework-free) load-time memory budget for `MLXOrganAdapter` — single-model OR the dual-residency
/// UNION required when a speculative draft model is co-resident (Phase C of the spec-decode restructure).
///
/// ## Why a union budget
/// MLX's `cacheLimit` (free-buffer pool) and `memoryLimit` (load-time malloc ceiling) are **process-global**
/// statics routed through `MLXRuntimeConfig.shared`, whose default policy is *first-`.adapterDefault`-wins*
/// (a conflicting second default is rejected). With two models co-resident (target + draft) that single-model
/// policy is wrong: the union must WIN over any single-model default already in force. So when a draft is
/// configured this budget is applied with **`.explicitOverride`** (last-write-wins); with no draft it resolves
/// to today's exact single-model values + `.adapterDefault` precedence → byte-identical to the pre-speculative
/// path.
///
/// ## Honest scope (R1 / 亏的不要)
/// The per-model resident-byte figures below are PLANNING ESTIMATES (4-bit quantized weights, order-of-magnitude
/// — not measured per entry). `memoryLimit` is intentionally left OPT-IN (nil unless a host supplies one): a
/// too-low load ceiling THROTTLES the load (the same reason `MLXOrganAdapter.memoryLimitBytes` defaults nil), and
/// guessing a hard load cap without on-device measurement would be a net-negative. `cacheLimit` is the lever we
/// *do* bound for dual residency — it is a CEILING (never worse than unbounded) and the two models share ONE
/// process-global pool, so the union cache cap is a modest lift over the single-model default, not a doubling.
/// The estimates exist to let the cert probe + verdict reason about feasibility; they are never asserted as fact.
public struct BASMLXMemoryBudget: Sendable, Equatable {

    /// MLX free-buffer pool ceiling (bytes) to apply on load, or nil to leave unbounded.
    public let cacheLimitBytes: Int?

    /// MLX load-time malloc ceiling (bytes) to apply BEFORE the load, or nil to leave the load unbounded.
    public let memoryLimitBytes: Int?

    /// True when this budget covers a co-resident draft model — the caller applies it with `.explicitOverride`
    /// (the union must beat any single-model `.adapterDefault`). False ⇒ single-model, `.adapterDefault` (today).
    public let isSpeculativeUnion: Bool

    /// Sum of the planning resident-byte estimates for every model this budget covers (target [+ draft]).
    /// Diagnostic only — surfaced to the cert probe / verdict, never a hard assertion.
    public let estimatedResidentBytes: Int

    public init(
        cacheLimitBytes: Int?,
        memoryLimitBytes: Int?,
        isSpeculativeUnion: Bool,
        estimatedResidentBytes: Int
    ) {
        self.cacheLimitBytes = cacheLimitBytes
        self.memoryLimitBytes = memoryLimitBytes
        self.isSpeculativeUnion = isSpeculativeUnion
        self.estimatedResidentBytes = estimatedResidentBytes
    }

    // MARK: - Constants (re-exported from BASMLXMemoryModel — the single source of truth)

    /// Re-export of `BASMLXMemoryModel.dualResidencyCacheFloorBytes` (kept here for the existing public name).
    public static let dualResidencyCacheFloorBytes = BASMLXMemoryModel.dualResidencyCacheFloorBytes

    /// Re-export of `BASMLXMemoryModel.defaultSpeculativeFitBudgetBytes` (kept here for the existing public name).
    public static let defaultSpeculativeFitBudgetBytes = BASMLXMemoryModel.defaultSpeculativeFitBudgetBytes

    /// Whether a target+draft pair's estimated dual residency fits within `budgetBytes`. Planning estimates → a
    /// CEILING test, never a guarantee; the on-device peak is the real check. Used to AUTO-gate greedy speculative
    /// default-on: fits ⇒ load the draft + speculate; doesn't fit ⇒ single-model (byte-identical).
    public static func dualResidencyFits(
        targetProviderID: String, draftProviderID: String, budgetBytes: Int
    ) -> Bool {
        approxResidentBytes(forProviderID: targetProviderID)
            + approxResidentBytes(forProviderID: draftProviderID) <= budgetBytes
    }

    /// Planning resident-byte estimate — delegates to `BASMLXMemoryModel` (the single merged table).
    static func approxResidentBytes(forProviderID providerID: String) -> Int {
        BASMLXMemoryModel.approxResidentBytes(forProviderID: providerID)
    }

    // MARK: - Pre-load admission (jetsam-cap guard, data-calibrated 2026-06-12 dual-device run)

    /// Measured iOS per-process memory cap (jetsam ActiveHard) on the iPhone Air (11.5 GB phys, iOS 27): a load
    /// whose PEAK process footprint crosses this is SIGKILL'd BEFORE the first token — observed twice for Gemma4
    /// E4B at weight-load (deviceB, responses=0, never reached `post_brain_load`), while E2B (peak 3114 MB)
    /// survived with ~262 MB headroom. Because the kill is instant + mid-load, no runtime watermark or liveness
    /// stall detector can catch it — only a PRE-LOAD admission check prevents it. Default ceiling for the opt-in
    /// `wouldExceedActiveHardCap` guard; a host on a larger-RAM device passes its own measured cap.
    public static let measurediPhoneAirActiveHardCapBytes = BASMLXMemoryModel.measuredIPhoneAirActiveHardCapBytes

    /// Best PEAK-process-footprint estimate for an entry (NOT just resident weights — peak includes KV growth +
    /// the substrate working set + MLX runtime). Returns nil when there is neither a measurement nor a
    /// family-derived basis, so the admission check ADMITS by default (never refuse what the data can't justify —
    /// 亏的不要). Sources (2026-06-12 dual-device run), keyed by a providerID substring:
    ///   • `gemma4.e2b`  → 3114 MB — MEASURED deviceB peak (survived, 261 MB headroom under the cap).
    ///   • `llama3_2.3b` → 2969 MB — MEASURED deviceA peak (survived; sustained 38.3 tok/s over ~10h).
    ///   • `gemma4.e4b`  → 4314 MB — DERIVED: 2700 MB weights + the 1614 MB Gemma-3n (MatFormer) runtime overhead
    ///     measured on E2B (3114 − 1500); consistent with the 2 observed jetsam deaths at load above the cap.
    /// Dense Llama carries far less overhead than nested Gemma-3n, which is why a 3B Llama (2969 MB) fits where a
    /// nominally-smaller Gemma "E4B" does not — the substrate measured this directly.
    public static func estimatedPeakFootprintBytes(
        forProviderID providerID: String
    ) -> Int? {
        BASMLXMemoryModel.estimatedPeakFootprintBytes(forProviderID: providerID)
    }

    /// Pre-load admission: would loading `targetProviderID` (single-model) drive the PEAK process footprint across
    /// the jetsam cap and SIGKILL the process before the first token? Pure + data-calibrated. A nil estimate ⇒
    /// admit (returns false — never refuse a load the data can't justify refusing). `safetyMarginBytes` keeps a
    /// cushion under the hard cap (default 128 MB — deliberately below E2B's observed 261 MB survival headroom so
    /// a model the data proved survivable is never falsely refused).
    public static func wouldExceedActiveHardCap(
        targetProviderID: String,
        capBytes: Int = BASMLXMemoryModel.resolvedActiveHardCapBytes()
            ?? measurediPhoneAirActiveHardCapBytes,
        safetyMarginBytes: Int = 128 * 1024 * 1024
    ) -> Bool {
        guard let peak = estimatedPeakFootprintBytes(forProviderID: targetProviderID) else {
            return false
        }
        return peak + safetyMarginBytes > capBytes
    }

    // MARK: - Resolve

    /// Resolve the budget to apply on `loadModel`.
    ///
    /// - With `draftProviderID == nil` (spec-decode off): returns the caller's single-model values verbatim with
    ///   `isSpeculativeUnion == false` → the caller applies them with `.adapterDefault`, byte-identical to today.
    /// - With a draft configured: returns the UNION — `cacheLimit` lifted to at least
    ///   `dualResidencyCacheFloorBytes`, `memoryLimit` left as the caller's (opt-in) value — with
    ///   `isSpeculativeUnion == true` → the caller applies with `.explicitOverride`.
    public static func resolve(
        targetProviderID: String,
        draftProviderID: String?,
        singleCacheLimitBytes: Int?,
        singleMemoryLimitBytes: Int?
    ) -> BASMLXMemoryBudget {
        let targetEstimate = approxResidentBytes(forProviderID: targetProviderID)

        guard let draftProviderID else {
            return BASMLXMemoryBudget(
                cacheLimitBytes: singleCacheLimitBytes,
                memoryLimitBytes: singleMemoryLimitBytes,
                isSpeculativeUnion: false,
                estimatedResidentBytes: targetEstimate)
        }

        let draftEstimate = approxResidentBytes(forProviderID: draftProviderID)
        // Union cache pool: at least the single-model cap (if any), at least the dual-residency floor.
        let unionCache = max(singleCacheLimitBytes ?? 0, dualResidencyCacheFloorBytes)
        return BASMLXMemoryBudget(
            cacheLimitBytes: unionCache,
            // memoryLimit stays the caller's opt-in value (nil unless a host measured + supplied one).
            memoryLimitBytes: singleMemoryLimitBytes,
            isSpeculativeUnion: true,
            estimatedResidentBytes: targetEstimate + draftEstimate)
    }
}
