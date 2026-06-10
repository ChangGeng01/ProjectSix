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

    // MARK: - Constants (named, no magic numbers)

    private static let mib = 1024 * 1024
    private static let gib = 1024 * 1024 * 1024

    /// Floor for the dual-residency cache pool. Two co-resident models churn more free buffers than one, so the
    /// union pool is lifted from the single-model 512 MB default to 768 MB — still a CEILING, just enough headroom
    /// to avoid cap-too-low re-alloc churn across two working sets. (Unmeasured; revisit with on-device evidence.)
    public static let dualResidencyCacheFloorBytes = 768 * mib

    /// Planning resident-byte estimate for a 4-bit entry, keyed by a substring of its providerID. NOT measured —
    /// see the type doc's honest-scope note. Used only to populate `estimatedResidentBytes`.
    static func approxResidentBytes(forProviderID providerID: String) -> Int {
        // Ordered most-specific first.
        let table: [(needle: String, bytes: Int)] = [
            ("gemma4.e4b", 2_700 * mib),
            ("gemma4.e2b", 1_500 * mib),
            ("gemma3.4b", 3_000 * mib),
            ("llama3_2.3b", 1_800 * mib),
            ("llama3_2.1b", 700 * mib),
            ("qwen2_5.3b", 1_800 * mib),
            ("qwen2_5.1_5b", 1_000 * mib),
        ]
        for (needle, bytes) in table where providerID.contains(needle) {
            return bytes
        }
        // Unknown entry — a conservative mid estimate so the union doesn't under-count.
        return 2 * gib
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
