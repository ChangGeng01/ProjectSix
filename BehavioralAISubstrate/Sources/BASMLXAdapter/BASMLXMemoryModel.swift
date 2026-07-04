import Foundation

/// SINGLE SOURCE OF TRUTH for the MLX adapter's memory model — every cap, fit budget, cache floor/default,
/// watermark ratio, and the per-model resident/peak estimate table. Pure, framework-free. Everything else
/// (`BASMLXMemoryBudget`, `BASSpeculationMemoryGovernor`, `MLXOrganAdapter`'s cache default) READS from here,
/// so each number is written in exactly ONE place — closing the duplication where the governor re-derived the
/// fit budget and two parallel tables drifted independently.
///
/// ## Honest scope (R1 / 亏的不要)
/// The per-model figures are PLANNING ESTIMATES — `residentBytes` from 4-bit weight size (order-of-magnitude),
/// `peakBytes` from the 2026-06-12 dual-device run (MEASURED for e2b/llama-3B survivors; DERIVED for e4b). They
/// let the budget + admission + governor reason about feasibility; they are never asserted as fact.
public enum BASMLXMemoryModel {

    static let mib = 1024 * 1024

    // MARK: - P2 多agent复用 N-session terms (device-measured, T4 cert 2026-07-04, Qwen3.5-4B trunk)
    //
    // Per-SESSION marginal memory at turn scale (≤~200-token conversations) is NOISE against the MLX
    // buffer cache + decode activations: 8 live seats measured the SAME ~3100-3180MB single-trunk
    // operating band as zero sessions. The term that DOES move the needle is CONCURRENT DECODES:
    // 8-at-once spiked +222MB over base (≈ +32MB per in-flight decode beyond the first) → in-flight
    // peak 3241MB, 135MB from the jetsam cap. `MLXOrganAdapter.maxConcurrentSessionDecodes = 2`
    // bounds that spike (re-measured 3163MB peak, wall-clock unchanged — the GPU is the bottleneck,
    // not the gate).
    /// Marginal in-flight memory per concurrent session decode beyond the first (empirical, T4).
    public static let concurrentSessionDecodeSpikeBytes = 32 * mib
    static let gib = 1024 * 1024 * 1024

    // MARK: - Canonical constants (the ONLY place these numbers are written)

    /// Measured iOS per-process jetsam (ActiveHard) cap on the iPhone Air (11.5 GB phys, iOS 27): a load whose
    /// PEAK footprint crosses this is SIGKILL'd before the first token (observed twice for Gemma4 E4B at load).
    public static let measuredIPhoneAirActiveHardCapBytes = 3_376 * mib

    /// Conservative per-process FIT budget for auto-engaging dual residency (greedy speculative default-on). A
    /// pair whose estimated dual residency exceeds this stays single-model (byte-identical).
    public static let defaultSpeculativeFitBudgetBytes = 3_000 * mib

    /// Floor for the dual-residency cache pool (two co-resident models churn more free buffers than one). A
    /// CEILING, never worse than unbounded.
    public static let dualResidencyCacheFloorBytes = 768 * mib

    /// Single-model MLX free-buffer pool default (ADR-038 §11.7-§11.9 variable-buffer wedge cap).
    public static let defaultCacheLimitBytes = 512 * mib

    /// Governor HIGH-water as a fraction of the fit budget (draft-drop threshold). The governor reads this
    /// instead of inlining `0.9`, so the watermark tracks the fit budget automatically.
    public static let highWaterRatio = 0.9

    /// Governor LOW-water as a fraction of high-water (restore hysteresis). Read in place of an inlined `0.8`.
    public static let lowWaterRatio = 0.8

    /// The measured Gemma-3n (MatFormer) runtime overhead on top of resident weights — `peak(e2b) − resident(e2b)`
    /// = 3114 − 1500 MB. NAMED + invariant-checked (see `BASMLXMemoryModelTests`) so the resident→peak
    /// relationship can never silently drift when a table entry is edited.
    public static let gemma3nRuntimeOverheadBytes = 1_614 * mib

    /// Conservative resident estimate for an unmapped entry, so the dual-residency union never under-counts.
    public static let unknownResidentFallbackBytes = 2 * gib

    // MARK: - Per-model estimate table (ONE table, two columns)

    /// Planning estimate for a model: 4-bit `residentBytes` (always present) + `peakBytes` (PEAK process
    /// footprint = weights + KV growth + substrate working set + MLX runtime; nil when unmeasured / no basis).
    public struct Estimate: Sendable, Equatable {
        public let residentBytes: Int
        public let peakBytes: Int?
        public init(residentBytes: Int, peakBytes: Int?) {
            self.residentBytes = residentBytes
            self.peakBytes = peakBytes
        }
    }

    /// The merged resident+peak table. Ordered MOST-SPECIFIC-FIRST; first providerID-substring match wins
    /// (preserves the historical lookup of the two former tables). `peakBytes`:
    ///   • `gemma4.e2b`  → 3114 MB MEASURED (deviceB peak, survived 261 MB under the cap)
    ///   • `llama3_2.3b` → 2969 MB MEASURED (deviceA peak, sustained 38.3 tok/s over ~10h)
    ///   • `gemma4.e4b`  → 4314 MB DERIVED (2700 weights + the 1614 MB Gemma-3n overhead; 2 jetsam deaths at load)
    ///   • others        → nil (no measurement → admission ADMITS by default)
    private static let table: [(needle: String, estimate: Estimate)] = [
        ("gemma4.e4b",   Estimate(residentBytes: 2_700 * mib, peakBytes: 4_314 * mib)),
        ("gemma4.e2b",   Estimate(residentBytes: 1_500 * mib, peakBytes: 3_114 * mib)),
        ("gemma3.4b",    Estimate(residentBytes: 3_000 * mib, peakBytes: nil)),
        ("llama3_2.3b",  Estimate(residentBytes: 1_800 * mib, peakBytes: 2_969 * mib)),
        ("llama3_2.1b",  Estimate(residentBytes: 700 * mib,   peakBytes: nil)),
        ("qwen2_5.3b",   Estimate(residentBytes: 1_800 * mib, peakBytes: nil)),
        ("qwen2_5.1_5b", Estimate(residentBytes: 1_000 * mib, peakBytes: nil)),
        // Saguaro Mamba (Llamba-1B fp16 .aimodel, 2.81 GB on disk) co-resident DRAFT alongside the 3B target.
        // resident is an ESTIMATE (fp16 ~1B; mmap clean pages may run lower); peakBytes nil ⇒ admits until the
        // device probe (BAS_COREAI_SAGUARO_PROBE) measures dual-residency peak, then tighten.
        ("coreai.mamba", Estimate(residentBytes: 2_000 * mib, peakBytes: nil)),
    ]

    /// The merged estimate for a providerID, or nil if unmapped.
    public static func estimate(forProviderID providerID: String) -> Estimate? {
        for (needle, estimate) in table where providerID.contains(needle) {
            return estimate
        }
        return nil
    }

    /// Planning resident-byte estimate (unmapped → conservative fallback). Canonical for `dualResidencyFits`.
    public static func approxResidentBytes(forProviderID providerID: String) -> Int {
        estimate(forProviderID: providerID)?.residentBytes ?? unknownResidentFallbackBytes
    }

    /// Best PEAK-footprint estimate (nil where no measurement/derivation). Canonical for the admission guard.
    public static func estimatedPeakFootprintBytes(forProviderID providerID: String) -> Int? {
        estimate(forProviderID: providerID)?.peakBytes
    }
}
