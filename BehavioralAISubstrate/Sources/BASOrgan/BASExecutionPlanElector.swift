import Foundation

/// Execution-path orchestrator (2026-07-13 charter) — the PURE Pareto elector + deterministic
/// fallback builder.
///
/// `elect` composes the four inputs the census proved don't meet anywhere today — model manifest,
/// device profile, request load, runtime state — into one `BASExecutionPlan`. It is a pure function
/// (no MLX, no I/O, no actor) so the whole election is host-testable and replay-deterministic.
///
/// The elector encodes the census's HARD-WON constraints as executable rules instead of scattered
/// prose/landmines:
///  1. Resident admission: a model that does not fit under the device jetsam budget with headroom
///     is refused speculation and pinned to the conservative plan (never fail open on memory).
///  2. Spec-vs-RotatingKVCache: whenever the decode axis wants speculation, `maxKVSize` MUST stay
///     nil — a non-nil cap builds a RotatingKVCache on which every spec lane fail-closes. The census
///     flagged this as an unmodeled hazard; here it is a tested invariant.
///  3. kvBits: fp16 (nil) is the only VERIFIED default (zero device A/B verdicts exist), so the
///     elector never speculatively quantizes the KV cache.
///  4. Thermal: a thermally-constrained device that is ALREADY throttled drops to the plain floor
///     (the MTP lane measured 0.52–0.62× net-negative under serious+ throttle).
///  5. Purpose: `.deterministic` (unlock speculative model-free/self-draft lanes) is elected only
///     for a greedy (temp-0) request; any sampling request stays `.scoutDefault`.
public enum BASExecutionPlanElector {

    /// The runtime state the elector reads (the subset the census showed is decision-relevant and
    /// obtainable). Energy is deliberately absent — it has no runtime data on this stack.
    public struct RuntimeState: Sendable, Equatable {
        /// The host-elected sampling temperature (0 ⇒ greedy ⇒ speculative lanes eligible).
        public let temperature: Double
        /// OS thermal state already at serious/critical — speculation is net-negative here.
        public let thermallyThrottled: Bool
        /// Current free resident headroom (bytes), if the host sampled it; nil ⇒ not sampled.
        public let memoryHeadroomBytes: Int?
        public init(
            temperature: Double,
            thermallyThrottled: Bool = false,
            memoryHeadroomBytes: Int? = nil
        ) {
            self.temperature = temperature
            self.thermallyThrottled = thermallyThrottled
            self.memoryHeadroomBytes = memoryHeadroomBytes
        }
    }

    /// The conservative cache: fp16, unbounded — spec-safe and verified.
    private static let safeCache = BASExecutionPlan.Cache(kvBits: nil, maxKVSize: nil)

    /// Elect the Pareto-optimal verified plan. Never returns nil: an unmanifested model, an
    /// unadmitted footprint, or a throttled device each deterministically degrade to a safe floor.
    public static func elect(
        modelID: String,
        manifest: BASModelCapabilityManifest?,
        device: BASDeviceExecutionProfile,
        state: RuntimeState
    ) -> BASExecutionPlan {

        // Rule 1 — resident admission. Unknown model OR footprint that fails the jetsam budget ⇒
        // conservative plan (no speculation election; the caller still runs, just plain-leaning).
        let admitted: Bool
        let residentBytes: Int
        if let m = manifest {
            residentBytes = m.residentBytesEstimate
            admitted = device.admitsResident(bytes: m.residentBytesEstimate)
        } else {
            residentBytes = 0
            admitted = false
        }

        // Rule 5 — purpose: greedy request unlocks speculative lanes; sampling stays the default.
        // Rule 4 — a device already throttled forces the plain-leaning default regardless of temp.
        // Rule 1 — an unadmitted / unmanifested model also stays plain-leaning (no spec election).
        let wantsSpeculation =
            BASDecodeLanePolicy.isGreedyByteSafe(temperature: state.temperature)
            && !state.thermallyThrottled
            && admitted
            && manifest != nil
        let purpose: BASDecodeLanePolicy.Purpose =
            wantsSpeculation ? .deterministic : .scoutDefault

        // Rule 2 & 3 — cache: fp16 always (verified); maxKVSize stays nil whenever speculation is
        // wanted (RotatingKVCache would fail-close every spec lane). With no speculation there is no
        // spec lane to protect, but the census also found kvBits/maxKV have no verified default, so
        // the conservative cache is correct on both branches.
        let cache = safeCache
        let specCachePreserved = wantsSpeculation   // the hazard was actively honored

        let load = BASExecutionPlan.Load(
            modelID: modelID, residentAdmitted: admitted, residentBytesEstimate: residentBytes)

        // Prefill: the verified current value (vendor 512); declared for Phase-2 election.
        let prefill = BASExecutionPlan.Prefill(stepSize: 512)

        // Deterministic fallback ladder, most-capable first. The primary rung mirrors the elected
        // top-level axes; each lower rung is where a runtime condition or a lane failure lands. The
        // final rung is the guaranteed-safe floor (plain, single resident, safe cache).
        var chain: [BASExecutionPlan.Step] = []
        if wantsSpeculation {
            chain.append(.init(
                decodePurpose: .deterministic, cache: safeCache,
                reason: "primary: greedy + admitted + nominal thermal ⇒ speculative lanes eligible"))
            chain.append(.init(
                decodePurpose: .scoutDefault, cache: safeCache,
                reason: "thermal serious+ OR spec lane fail-close ⇒ byte-equal plain-leaning default"))
        } else {
            var reason = "primary: plain-leaning default"
            if !admitted { reason = "primary: model unadmitted/unmanifested ⇒ conservative plain" }
            else if state.thermallyThrottled { reason = "primary: device throttled ⇒ plain (spec is net-negative)" }
            else if !BASDecodeLanePolicy.isGreedyByteSafe(temperature: state.temperature) {
                reason = "primary: sampling request ⇒ byte-equal default"
            }
            chain.append(.init(decodePurpose: .scoutDefault, cache: safeCache, reason: reason))
        }

        let attestation = BASExecutionPlan.Attestation(
            deviceLabel: device.label,
            residentAdmitted: admitted,
            specCachePreserved: specCachePreserved,
            energyModeled: false)

        return BASExecutionPlan(
            load: load, prefill: prefill, cache: cache,
            decodePurpose: purpose, fallbackChain: chain, attestation: attestation)
    }
}
