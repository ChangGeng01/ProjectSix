import Foundation

/// Execution-path orchestrator (2026-07-13 charter) — the elected PLAN artifact.
///
/// The charter: after the host picks a model, the system auto-elects the full path — load, prefill,
/// cache, decode — as the verified Pareto-optimal plan under quality/latency/energy/memory
/// constraints, with deterministic fallback. The census found this artifact does not exist: load
/// knobs are frozen `MLXOrganAdapter.init` constants, decode is a per-turn lane pick, and fallback
/// is per-arm `try/catch` — deterministic in BEHAVIOR but with no VERIFIABLE plan object. This type
/// IS that object: the elected knobs on every axis + the ordered fallback chain + a constraint
/// attestation. Pure value, `Sendable`, host-testable.
///
/// Phase boundary (honest, per pin-boundary-defer-interface): the DECODE axis is actuatable today
/// (it delegates to the shipped BASDecodeLanePolicy via `decodePurpose`). The LOAD/PREFILL/CACHE
/// axes are ELECTED here but their actuation hoists frozen `init` constants + needs on-device
/// re-cert — that is Phase 2, named and triggered, not built speculatively. Until then the plan is
/// the machine-readable election + attestation the orchestrator reasons and reports over.
public struct BASExecutionPlan: Sendable, Equatable, Codable {

    // MARK: Load axis

    public struct Load: Sendable, Equatable, Codable {
        public let modelID: String
        /// Residency admitted under the device jetsam budget with headroom. Always true for an
        /// elected plan (a plan that fails admission is never returned — see the elector).
        public let residentAdmitted: Bool
        public let residentBytesEstimate: Int
        public init(modelID: String, residentAdmitted: Bool, residentBytesEstimate: Int) {
            self.modelID = modelID
            self.residentAdmitted = residentAdmitted
            self.residentBytesEstimate = residentBytesEstimate
        }
    }

    // MARK: Cache axis

    public struct Cache: Sendable, Equatable, Codable {
        /// KV-cache quantization bits (nil = fp16, the only VERIFIED default — the census found
        /// kvBits has ZERO device A/B verdicts, so electing a quantized default would be
        /// speculative). Present as an axis so Phase 2 can elect it once an A/B lands.
        public let kvBits: Int?
        /// Rotating-KV window cap (nil = unbounded/append-only). HARD constraint: a non-nil value
        /// builds a `RotatingKVCache`, on which EVERY spec lane fail-closes to plain — so the
        /// elector must NOT set this when the decode axis wants speculation.
        public let maxKVSize: Int?
        public init(kvBits: Int?, maxKVSize: Int?) {
            self.kvBits = kvBits
            self.maxKVSize = maxKVSize
        }
    }

    // MARK: Prefill axis

    public struct Prefill: Sendable, Equatable, Codable {
        /// Chunked-prefill window (the vendor constant is 512; no BAS knob exists yet — declared for
        /// Phase 2, carried as the verified current value).
        public let stepSize: Int
        public init(stepSize: Int) { self.stepSize = stepSize }
    }

    public let load: Load
    public let prefill: Prefill
    public let cache: Cache
    /// The decode purpose the planner should run under — the ONE axis actuated today (delegates to
    /// `BASDecodeLanePolicy`). `.deterministic` unlocks the model-free/self-draft speculative lanes;
    /// `.scoutDefault` is the byte-equal plain-leaning default.
    public let decodePurpose: BASDecodeLanePolicy.Purpose
    /// Ordered deterministic degradations, most-capable first. Element 0 is the primary path; each
    /// subsequent element is where execution deterministically falls back when the prior fails or a
    /// runtime condition (thermal/memory) forbids it. The LAST element is always a guaranteed-safe
    /// floor (plain decode, single resident).
    public let fallbackChain: [Step]
    /// Which constraints the elector verified when producing this plan (for attestation/telemetry).
    public let attestation: Attestation

    /// A single rung of the deterministic fallback ladder.
    public struct Step: Sendable, Equatable, Codable {
        public let decodePurpose: BASDecodeLanePolicy.Purpose
        public let cache: Cache
        /// Why this rung exists / when it is entered (e.g. "thermal serious+", "memory pressure").
        public let reason: String
        public init(decodePurpose: BASDecodeLanePolicy.Purpose, cache: Cache, reason: String) {
            self.decodePurpose = decodePurpose
            self.cache = cache
            self.reason = reason
        }
    }

    public struct Attestation: Sendable, Equatable, Codable {
        public let deviceLabel: String
        public let residentAdmitted: Bool
        /// True when the elector kept `maxKVSize == nil` because the decode axis wants speculation
        /// (the RotatingKVCache-vs-spec hazard was actively honored, not incidentally satisfied).
        public let specCachePreserved: Bool
        /// Honest: energy has no runtime data on this stack (3 of 4 Pareto axes have evidence).
        public let energyModeled: Bool
        public init(
            deviceLabel: String, residentAdmitted: Bool,
            specCachePreserved: Bool, energyModeled: Bool
        ) {
            self.deviceLabel = deviceLabel
            self.residentAdmitted = residentAdmitted
            self.specCachePreserved = specCachePreserved
            self.energyModeled = energyModeled
        }
    }

    public init(
        load: Load, prefill: Prefill, cache: Cache,
        decodePurpose: BASDecodeLanePolicy.Purpose,
        fallbackChain: [Step], attestation: Attestation
    ) {
        self.load = load
        self.prefill = prefill
        self.cache = cache
        self.decodePurpose = decodePurpose
        self.fallbackChain = fallbackChain
        self.attestation = attestation
    }
}
