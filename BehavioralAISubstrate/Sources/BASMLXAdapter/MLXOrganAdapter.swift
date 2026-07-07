import Foundation
import CryptoKit
import BASRuntimeCore
import BASOrgan
#if canImport(os)
import os
#endif
#if canImport(MLXLLM)
import MLXLLM
import MLXLMCommon
import MLXHuggingFace
import HuggingFace
import Tokenizers
import MLX
import MLXNN

/// M254 — `@unchecked Sendable` wrapper for `ChatSession`. See
/// `MLXOrganAdapter.sessions` doc for the safety argument: the box
/// only ever crosses the actor's executor, so no cross-task
/// aliasing is possible. Marked fileprivate so the unchecked
/// guarantee never leaks out of this file.
// internal (was fileprivate): the B5 SessionPersist extension (same type, separate file) rides the
// same actor-confinement contract — sessions are only ever reached via this actor's executor.
struct ChatSessionBox: @unchecked Sendable {
    let session: ChatSession
}

/// Same guarantee as ChatSessionBox: the decoder is only ever touched inside `container.perform` closures.
struct MTPDecoderBox: @unchecked Sendable {
    let decoder: BASQwen35MTPSpecDecoder
}
#endif

/// MLX organ adapter (Apple Silicon, on-device, downloaded
/// Gemma weights).
///
/// ## Why this exists
///
/// `BASOrganAdapter` is the single neural-organ contract. Apple
/// FoundationModels (`AppleFoundationOrganAdapter`) covers iOS/macOS
/// 26+ devices with Apple Intelligence. For older OS versions, or
/// for users who want a specific open-weights model, the substrate
/// needs a second on-device path: MLX with quantized Gemma 3 / 3n
/// weights from the `mlx-community` Hugging Face org.
///
/// ## M220 → M221 progression
///
/// **M220** shipped the dep tree (mlx-swift-lm + swift-transformers
/// + swift-huggingface) and the `BASOrganAdapter` conformance with
/// `draft(_:)` honestly reporting unavailable.
///
/// **M221 (this file)** wires the real path:
///
///   1. `loadModel(progressHandler:)` — downloads the
///      `MLXModelCatalog.Entry`'s weights from Hugging Face via
///      `huggingFaceLoadModelContainer` and caches the resulting
///      `ModelContainer` on the actor.
///   2. `draft(_:)` — once a `ModelContainer` is loaded, runs
///      `ChatSession.respond(to:)` and returns a real
///      `BASOrganDraft` with the model body, role, token estimates,
///      and a stable `traceID`.
///   3. `currentCapacity()` — reports `.unlimited`-ish (the model
///      itself decides input/output bounds at runtime) once loaded;
///      otherwise reports underPressure with a reason code so
///      callers can fall through to another provider.
///
/// Streaming lives in `MLXOrganAdapter+Streaming.swift`.
///
/// ## Availability
///
/// `MLXLLM` is Apple-Silicon-only (macOS 14+ / iOS 17+ / visionOS 1+
/// / tvOS 17+; **NOT watchOS** — Metal isn't available there). The
/// full implementation is behind `#if canImport(MLXLLM)`. On
/// platforms / OS versions that don't have it, the adapter compiles
/// as a stub that reports unavailability through `currentCapacity()`
/// — callers can fall back to another registered provider.
///
/// ## Test coverage
///
/// - `MLXOrganAdapterTests` — descriptor, role enforcement, capacity
///   on the not-loaded path, catalog stability. Runs on every CI.
/// - `MLXOrganAdapterE2ETests` — real `loadModel(...)` +
///   `respond(to:)` end-to-end. Gated behind `QINAO_MLX_E2E=1`
///   because first run downloads ~2.5 GB of weights and the network
///   round trip + model load takes minutes.
public actor MLXOrganAdapter: BASOrganAdapter {
    public nonisolated let descriptor: BASOrganDescriptor

    /// The model entry this adapter is configured to serve.
    public nonisolated let model: MLXModelCatalog.Entry

    /// Default MLX cache-pool cap (512 MB) — the band is ~384-768 MB (low enough to bound the pool, high
    /// enough to avoid §8's cap=64 re-alloc churn). Evidence: E2B wedge prevention (ADR-038) AND the
    /// 2026-07-07 {256,512,768,∞} device sweep on Qwen3.5-4B production decode
    /// (Docs/CACHELIMIT_AB_2026-07-07.md): fixed shapes plateau the pool naturally at ~290 MB and all four
    /// arms are speed-identical (12.3 tok/s, thermal=0) — 512 is zero-cost insurance above the natural
    /// plateau; its only ACTIVE role is variable-shape models (E2B class). Measured DON'T-CARE for speed
    /// on the Qwen lane — do not tune it expecting tok/s.
    public static let defaultCacheLimitBytes: Int = BASMLXMemoryModel.defaultCacheLimitBytes

    /// ADR-038 §11.7-§11.9 — cap for MLX's **free-buffer cache pool** (bytes), applied on `loadModel` (default
    /// `defaultCacheLimitBytes`). This is a pure MEMORY ceiling (a free-buffer recycling bound), NOT a math
    /// lever — it changes only WHEN buffers are reclaimed, so it is **output-byte-equal** for any input.
    ///
    /// WHY: on-device, models with variable buffer shapes (notably Gemma-3n: per-layer-inputs + sliding window
    /// + varying prompt lengths) leave freed buffers in MLX's cache pool that the next turn cannot reuse, so the
    /// pool grows unbounded and exhausts device memory after a few turns → the allocator drain LIVELOCKS (the
    /// "wedge") or the OS OOM-kills.
    ///
    /// EVIDENCE (honest scope): on iPhone Air (8 GB), iOS 27.0 beta, **Gemma-3n-E2B** with short (~35-134-token)
    /// prompts — the unbounded default wedges at ~3 turns; with this 512 MB cap the pool plateaus at ≈512 MB and
    /// the run completes 30/30 (ADR §11.8-§11.9). NOT yet measured for the larger E4B/Gemma-3-4B catalog entries
    /// or long prompts; the cap is a CEILING so it can never be WORSE than the unbounded default, but whether 512
    /// is OPTIMAL there (no within-turn-working-set churn) is unverified.
    ///
    /// CAVEAT: `MLX.Memory.cacheLimit` is a **process-global** static. All writes now route through the single
    /// `MLXRuntimeConfig.shared` seam (`MLXRuntimeConfig.swift`): the FIRST adapter default wins the global cap;
    /// a coexisting adapter with a *different* default is REJECTED + logged (no silent last-write-wins). `nil`
    /// disables the cap (upstream/unbounded); an explicit `setGPUCacheLimit` / env `BAS_MLX_CACHE_LIMIT_MB`
    /// overrides at runtime (last write wins, also logged).
    public nonisolated let cacheLimitBytes: Int?

    /// 默认闭环清点 (2026-06-12) — OPT-IN KV-cache quantization bits
    /// (vendor `GenerateParameters.kvBits`;group size stays the
    /// vendor default 64)。 nil (default) = no quantization =
    /// byte-equal;4/8 trades KV memory/bandwidth for low-bit cache
    /// precision and CHANGES decode numerics — flip only after an
    /// on-device A/B (throughput + memory + quality)。
    public nonisolated let kvCacheBits: Int?

    /// U2 (2026-06-12) — OPT-IN rotating-KV-cache token cap (vendor
    /// `GenerateParameters.maxKVSize`):when set,the cache becomes a
    /// `RotatingKVCache` that overwrites old entries (keeping the
    /// first 4 tokens),BOUNDING per-stream KV memory for long
    /// sessions。 nil (default) = unbounded `KVCacheSimple` =
    /// byte-equal (ADR-014)。 Non-nil CHANGES long-context attention
    /// content (evicted tokens) — opt-in only,flip needs the
    /// on-device A/B (long-session memory ceiling + quality)。
    public nonisolated let maxKVSize: Int?

    /// OPT-IN pre-load jetsam admission (data-driven, 2026-06-12 dual-device run). When true, `loadModel`
    /// REFUSES a single-model load whose estimated PEAK footprint would cross the device's ActiveHard cap
    /// (`BASMLXMemoryBudget.wouldExceedActiveHardCap`) — the only thing that prevents the instant mid-load
    /// jetsam SIGKILL E4B suffered twice on the iPhone Air (no runtime watchdog can catch a load-time kill).
    /// Default `false` ⇒ today's warn-only behavior, byte-equal (ADR-014); a host opts in.
    public nonisolated let enforceMemoryAdmission: Bool

    /// The device's per-process jetsam (ActiveHard) cap for the admission check; nil ⇒ the measured iPhone Air
    /// default. A larger-RAM / entitled host passes its own. Only consulted when `enforceMemoryAdmission`.
    public nonisolated let activeHardCapBytes: Int?

    /// MTP drafter weights URL override (see init; default-ON resolves canonically when nil).
    public nonisolated let mtpDrafterWeightsURL: URL?
    /// Kill-switch for the default-ON MTP lane (false ⇒ lane never offered, pure legacy byte-equal).
    public nonisolated let mtpSpecEnabled: Bool

    /// DEFAULT-ON resolution: explicit URL ?? canonical discovery (Qwen3.5-family main model only).
    /// Candidates: Documents/qwen35_mtp_folded.safetensors (device staging), the model's local directory,
    /// /tmp/gdn_coreai (Mac dev). nil ⇒ lane not offered.
    nonisolated func _resolveMTPWeightsURL() -> URL? {
        guard mtpSpecEnabled else { return nil }
        if let explicit = mtpDrafterWeightsURL { return explicit }
        guard model.id.lowercased().contains("qwen3.5") else { return nil }
        let fm = FileManager.default
        var candidates: [URL] = []
        if let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first {
            candidates.append(docs.appendingPathComponent("qwen35_mtp_folded.safetensors"))
            if let local = model.localDirectoryName {
                candidates.append(docs.appendingPathComponent(local)
                    .appendingPathComponent("qwen35_mtp_folded.safetensors"))
            }
        }
        candidates.append(URL(fileURLWithPath: "/tmp/gdn_coreai/qwen35_mtp_folded.safetensors"))
        return candidates.first { fm.fileExists(atPath: $0.path) }
    }
    /// Cached MTP decoder (created on first `.mtpSpec` execution inside the container actor; the box mirrors
    /// `ChatSessionBox`'s @unchecked-Sendable pattern — exclusively used within `container.perform`).
    var mtpDecoderBox: MTPDecoderBox?
    // B2 探针路由器 — the difficulty-probe head (BAS_DIFF_PROBE=1), resolved once per adapter.
    /// 缝1 telemetry/test surface: session turns decoded via the thermal plain-fallback.
    var sessionThermalFallbackCount = 0

    var diffProbeBox: BASDifficultyProbe?
    var diffProbeResolved = false

    /// ADR-041 §C — OPT-IN cap (bytes) for MLX's **load-time** memory peak, applied via `MLXRuntimeConfig`
    /// BEFORE the container load. Unlike `cacheLimitBytes` (a post-load recycling ceiling), `MLX.Memory.memoryLimit`
    /// makes `malloc` WAIT once exceeded — so it bounds the download/materialize SPIKE the cache cap cannot.
    /// Default `nil` (off → byte-equal, ADR-014 opt-in): a device-aware bound is follow-on work, and a too-low
    /// value could throttle the load, so this stays opt-in until measured. First-default-wins on the
    /// process-global, identical policy to `cacheLimitBytes`.
    public nonisolated let memoryLimitBytes: Int?

    // MARK: - Speculative decoding (结构大重构 — default OFF ⇒ byte-identical)

    /// The same-family smaller DRAFT model to co-resident for speculative decoding, or `nil` (the default) for
    /// single-model decoding. Must share the target's tokenizer (validated against `speculativePairings` by
    /// `loadDraftModel`). ADR-014 OPT-IN: `nil` ⇒ the draft container is never loaded ⇒ byte-identical to today.
    public nonisolated let draftModel: MLXModelCatalog.Entry?

    /// Speculative-decoding mode. `.off` (default) ⇒ single-model path, byte-identical. `.greedy` ⇒ token-identical
    /// speculative decoding at temperature 0. `.sampling` ⇒ rejection-sampling lane (Phase 2). See `BASSpeculativeMode`.
    public nonisolated let speculativeDecoding: BASSpeculativeMode

    /// Tokens the draft model proposes per speculation round (vendor default 2). Higher ⇒ bigger win when the
    /// draft agrees, bigger wasted verify when it diverges. Tuned per pairing during the on-device cert.
    public nonisolated let numDraftTokens: Int

    /// Conservative per-process memory budget (bytes) for AUTO-engaging the draft when greedy speculation is the
    /// default. `loadModel` loads the draft only if the estimated dual residency fits this budget — so a pair too
    /// heavy for the device (e.g. Gemma4 E4B+E2B on 8 GB) stays single-model (byte-identical), while the certified
    /// Llama/Qwen 3B+1B fits and engages. `nil` disables the fit-gate (load the draft whenever one is configured).
    /// Default `BASMLXMemoryBudget.defaultSpeculativeFitBudgetBytes` (3000 MB — fits without the increased-memory
    /// entitlement); a host on an entitled / higher-memory device can raise it.
    public nonisolated let speculativeFitBudgetBytes: Int?

    /// Whether `loadModel` will AUTO-engage speculation: the mode is on, a draft is resolved, and the estimated
    /// dual residency fits `speculativeFitBudgetBytes` (nil budget ⇒ fit-gate off). Pure over the configured
    /// fields (no container) so it is host-testable. This is what makes greedy default-on safe: a pair too heavy
    /// for the device (Gemma4 E4B+E2B on 8 GB) returns false ⇒ no draft loaded ⇒ single-model (byte-identical).
    public nonisolated var willEngageSpeculation: Bool {
        guard speculativeDecoding != .off, let draft = draftModel else { return false }
        guard let budget = speculativeFitBudgetBytes else { return true }
        return BASMLXMemoryBudget.dualResidencyFits(
            targetProviderID: model.providerID, draftProviderID: draft.providerID, budgetBytes: budget)
    }

    /// Pure validity check for a speculative target↔draft pairing: a shared tokenizer is REQUIRED (a cross-family
    /// draft would mis-tokenize the target's stream) and the draft must be a DISTINCT model. The shared tokenizer
    /// is proxied here by a shared turn terminator (`extraEOSTokens`); Phase 3 replaces the proxy with the explicit
    /// `speculativePairings` table. `nonisolated static` + framework-free so it is host-testable without a load.
    public nonisolated static func isValidDraftPairing(
        target: MLXModelCatalog.Entry,
        draft: MLXModelCatalog.Entry
    ) -> Bool {
        draft.providerID != target.providerID
            && draft.extraEOSTokens == target.extraEOSTokens
    }

    // MARK: - Descriptor defaults (ch1040 — named-constant extraction)

    /// Default input-token ceiling reported through the descriptor
    /// when the caller doesn't override it. The model itself decides
    /// the real runtime bound; this is the contracted descriptor cap.
    ///
    /// `public` (not `private`) because it's a default-argument value
    /// of the `public init`, so it must be visible at every external
    /// call site that omits `maxInputTokens`.
    public static let defaultMaxInputTokens = 4_096

    /// Default output-token ceiling reported through the descriptor
    /// when the caller doesn't override it. `public` for the same
    /// default-argument-of-a-public-init reason as the input ceiling.
    public static let defaultMaxOutputTokens = 4_096

    // MARK: - Shared error-reason strings (ch1040 — hoisted, byte-identical)

    /// Reason text for the non-Apple-Silicon / watchOS build where
    /// `MLXLLM` can't be imported. Internal (not `private`) so the
    /// streaming extension in `MLXOrganAdapter+Streaming.swift` can
    /// route its `#else` branch through the same string — same reason
    /// `_generateParameters` / `_loadedContainerForStreaming` aren't
    /// private (cross-file extensions can't see `private` members).
    static let frameworkUnavailableReason =
        "MLXLLM framework unavailable in this build"

    /// Suffix appended to `frameworkUnavailableReason` at the inference
    /// call sites (`draft` / `draftMultiTurn` / `streamDraft` / load),
    /// naming the platforms that lack Metal.
    static let frameworkUnavailablePlatformSuffix =
        " (watchOS / non-Apple-Silicon target)"

    /// Build the stable "model not loaded yet" reason. `method` is the
    /// full call-to-make tail (e.g. `"loadModel(...) before prewarm()"`)
    /// so each call site's rendered text stays byte-identical. Internal
    /// for the same cross-file-extension reason as above.
    static func notLoadedReason(_ method: String) -> String {
        "mlx-organ-adapter-not-loaded — call \(method)"
    }

    #if canImport(MLXLLM)
    /// The loaded model container. `nil` until `loadModel(...)` has
    /// completed at least once on this actor instance.
    private var modelContainer: ModelContainer?

    /// The loaded DRAFT model container for speculative decoding. `nil` until `loadDraftModel(...)` completes
    /// (and only ever loaded when `draftModel != nil && speculativeDecoding != .off`). Lives on this actor next
    /// to `modelContainer`; both are reached on the same executor, so the speculative path can co-drive them.
    private var draftContainer: ModelContainer?

    /// Why the AUTO draft load (greedy default-on, `loadModel`'s best-effort step) failed — `nil` when it
    /// succeeded or was never attempted. The auto-load is deliberately fail-closed (a draft failure must never
    /// break the target; the adapter just stays single-model, byte-identical) — but a SILENT fail-closed would
    /// leave a host believing speculation is active when it isn't. This property + the os.Logger fault line make
    /// the downgrade observable: hosts check `isSpeculationActive` / this reason after `loadModel()`.
    public private(set) var draftLoadFailureReason: String?

    /// True when the speculative path is LIVE right now (draft container loaded + mode on) — i.e. eligible
    /// requests can actually speculate. The honest post-`loadModel()` signal for hosts/dashboards
    /// (`willEngageSpeculation` is the pre-load PLAN; this is the post-load REALITY).
    public var isSpeculationActive: Bool {
        speculativeDecoding != .off && draftContainer != nil
    }

    /// Read accessor for the speculative streaming extension (different file, same module).
    func _loadedDraftContainerForStreaming() -> ModelContainer? {
        draftContainer
    }

    // MARK: - Prewarm constants (ch1040 — named-constant extraction)

    /// Decode-token cap for `prewarm()`. We only need to JIT the
    /// Metal kernels and exercise the prefill→decode boundary, not
    /// generate a full response, so 4 tokens is enough.
    private static let prewarmDecodeTokens = 4

    /// Synthetic request ID used by `prewarm()`'s dummy turn.
    private static let prewarmRequestID = "prewarm"

    /// M254 — multi-turn session pool. Keys are
    /// `"\(callerSessionID)#\(role.rawValue)"` so the same
    /// caller-side session ID with different roles gets separate
    /// `ChatSession` instances (different system instructions).
    /// `ChatSession` is not thread-safe but lives entirely on this
    /// actor, so per-session calls serialize through actor
    /// isolation and never race.
    ///
    /// Wrapped in a `@unchecked Sendable` box because `ChatSession`
    /// itself isn't `Sendable` (it's a `final class` with internal
    /// `SerialAccessContainer<Cache>` mutable state). Storing it in
    /// actor state and calling its `respond(...)` method —
    /// `nonisolated async` — would otherwise fail Swift 6's data-
    /// race check. The wrapper asserts the contract this actor
    /// enforces: each session is reached only via this actor's
    /// executor, so no cross-task aliasing is possible. The wrapper
    /// stays `fileprivate` — never escapes the type.
    private var sessions: [String: ChatSessionBox] = [:]
    /// P2: access order for the session-pool LRU bound (oldest first). 16 = the BASSessionTokenStore
    /// precedent; per-session KV for turn-shaped seat traffic is ~4-8MB — 16 sessions ≈ well under the
    /// dual-residency budget's slack.
    private var sessionLRU: [String] = []
    static let maxLiveSessions =
        Int(ProcessInfo.processInfo.environment["BAS_MAX_LIVE_SESSIONS"] ?? "") ?? 16

    /// 会话→加速lane (P2 gap #3, device-measured crossover 2026-07-04): greedy seat turns with SHORT
    /// histories run the STATELESS fused-MTP path (re-prefill whole conversation + 30 tok/s decode) —
    /// measured faster than KV-reuse+plain up to ~200-300 history tokens (stateless won depth-1/-2 by
    /// 350/228ms; reuse won depth-3 @400 tok). Past the threshold the session transitions ONCE to a
    /// ChatSession re-hydrated from the transcript (the vendored `init(history:)` — template-perfect,
    /// one amortized re-prefill). ADR-014: default false ⇒ byte-equal (all session turns = ChatSession).
    public nonisolated let sessionFusedLane: Bool
    /// History budget (est tokens) under which the stateless fused path wins (device crossover data).
    static let fusedSessionMaxTokens = 250
    /// Transcripts for fused-mode sessions (key = sessionKey; Sendable tuples — Chat.Message can carry
    /// media and is non-Sendable, so messages are rebuilt locally where consumed). Purged on
    /// clearSession/transition.
    private var fusedTranscripts: [String: [(role: String, text: String)]] = [:]
    /// Telemetry: turns served by the fused session lane (tests/observability).
    private(set) var fusedSessionTurnCount = 0

    /// P2 gap #5 — BOUNDED session-decode concurrency (the fairness governor's safety half). Device
    /// measurement (T4 concurrent, 2026-07-04): 8 seats decoding at once COMPLETE correctly (vendor
    /// parallel-ChatSession contract holds on GDN) but the in-flight footprint peaked 3241MB — 135MB
    /// from the jetsam cap. Cap 2: activation memory stays in the single-decode band while still hiding
    /// one decode's latency under another; FIFO waiters (no starvation). Stateless draft()/streamDraft
    /// are NOT gated (their concurrency profile is the historical one).
    static let maxConcurrentSessionDecodes = 2
    private var activeSessionDecodes = 0
    private var sessionDecodeWaiters: [CheckedContinuation<Void, Never>] = []

    /// 缝8b telemetry: high-water mark of concurrent decodes — the governor-coverage gate reads it.
    var peakSessionDecodes = 0
    func acquireSessionDecodeSlot() async {
        if activeSessionDecodes < Self.maxConcurrentSessionDecodes {
            activeSessionDecodes += 1
            peakSessionDecodes = max(peakSessionDecodes, activeSessionDecodes)
            return
        }
        await withCheckedContinuation { sessionDecodeWaiters.append($0) }
        activeSessionDecodes += 1
        peakSessionDecodes = max(peakSessionDecodes, activeSessionDecodes)
    }

    func releaseSessionDecodeSlot() {
        activeSessionDecodes -= 1
        if !sessionDecodeWaiters.isEmpty {
            sessionDecodeWaiters.removeFirst().resume()
        }
    }

    /// Cross-turn draft corpus (Universal Draft Layer, Phase 1): per-conversation token history that feeds the
    /// model-free cross-turn suffix source (`BASCrossTurnDrafter`). Plain RAM — no MLX residency — bounded both
    /// per-session and by session count. Actor-isolated, so its mutations are serialized like `sessions`.
    /// `internal` (not `private`) so the `+SuffixSpec` extension (same module, different file) can reach it.
    var crossTurnStore = BASSessionTokenStore()

    /// Online per-(source × purpose) acceptance learning for the Universal Draft Layer router
    /// (`respondAccelerated`). CROSS-session accumulated learning (an EMA), so it is intentionally NOT reset by
    /// `clearSession`/`clearAllSessions`. Immutable value folded after each accelerated turn. `internal` for
    /// `+SuffixSpec` access.
    var draftProfiler = BASAcceptanceProfiler()

    // ── P0 经验持久化 (RSI charter 2026-07-07): opt-in cross-process memory for the profiler
    // table + the fused lane's chainEmaL. Off (default) ⇒ byte-equal current behavior: no load,
    // no write, no seed. Latency-only by construction — bytes stay anchored by ADR-039; the
    // prior only warm-starts lane election / K ramp. Staleness gate + whole-snapshot sanity in
    // BASAcceptanceProfilerStore; a corrupt/stale file = cold start (= current behavior).
    nonisolated static var _profilerPersistEnabled: Bool {
        ProcessInfo.processInfo.environment["BAS_PROFILER_PERSIST"] == "1"
    }
    var experienceStore: BASAcceptanceProfilerStore?
    var experienceLoadAttempted = false
    /// Freshest chainEmaL carry: disk-restored at load, refreshed at each persist and at the
    /// pressure ladder's rung-2 drop — seeds the fused decoder at (re)creation so the regime
    /// EMA survives both process death and in-process decoder drops. nil unless persist is on.
    var restoredChainEmaL: Double?

    /// DecodePlan S4 — when true, `draft(_:electAccelerated:)` lets the single planner
    /// (`BASDecodeLanePolicy.decodeStrategy`) choose the lane (Option-3 auto-select) instead of the legacy
    /// elect→prompt-lookup gate. Default FALSE = EXACT legacy behavior (byte-identical). Flipped only after the
    /// on-device A/B proves per-lane token-equality. Settable so an A/B probe can toggle it.
    public var decodePlannerAutoSelect = true

    /// Toggle the planner at runtime (the on-device A/B probe flips this to compare flag-off vs flag-on output).
    public func setDecodePlannerAutoSelect(_ on: Bool) { decodePlannerAutoSelect = on }

    /// Read accessor for the streaming extension (different file,
    /// same module). Cannot be `private` because extensions in
    /// other files can't see private storage.
    func _loadedContainerForStreaming() -> ModelContainer? {
        modelContainer
    }

    /// Sampling parameters built from the request's preset.
    /// Exposed at module scope (not private) so the streaming
    /// extension in `MLXOrganAdapter+Streaming.swift` can reuse the
    /// same translation rule the non-streaming `draft(_:)` uses.
    func _generateParameters(
        for preset: BASOrganPreset,
        maxOutputTokens: Int? = nil
    ) -> GenerateParameters {
        var params = GenerateParameters()
        params.temperature = Float(preset.temperature)
        params.topP = Float(preset.topP)
        // 默认闭环清点 (2026-06-12) — KV-cache quantization, the cheapest
        // still-unbuilt decode-side lever the repo names
        // (MLX_DECODE_ANATOMY.md:42-43,74-77)。 DEFAULT nil = vendor
        // default = no quantization = byte-equal (ADR-014)。 Non-nil
        // (4/8) CHANGES decode numerics — opt-in only, on-device A/B
        // (throughput + memory + quality) before any default thought。
        params.kvBits = kvCacheBits
        // U2 — rotating-KV cap。 DEFAULT nil = unbounded KVCacheSimple
        // = byte-equal;non-nil bounds per-stream KV memory via
        // RotatingKVCache (evicts old tokens, keeps first 4) and
        // CHANGES long-context content — opt-in, A/B first。
        params.maxKVSize = maxKVSize
        // ch1066 — ENFORCE a decode bound (the cap was never applied; generation relied
        // solely on the model emitting EOS → an unbounded TOKEN runaway). Precedence: an
        // explicit POSITIVE per-request cap wins; else the PRESET's output budget
        // (scout=terse 192, core=fuller 1024) — the SAME fallback the cloud
        // BASChatCompletionsOrganAdapter uses, so provider choice no longer silently changes
        // output length (on-device used to ignore the preset and decode up to the 4096
        // descriptor max). In every case, clamp to the descriptor's contracted ceiling.
        //
        // HONEST SCOPE (ch1066 再查 / on-device A/B): this bounds a TOKEN runaway. It does
        // NOT fix the on-device iter=1 endurance freeze — that was an uncancellable Metal/GPU
        // eval hang with ZERO token progress (handled by the feed-forward gate default OFF +
        // sanitized/bounded authoritative projection; a per-turn wall-clock timeout was
        // rejected on-device because the synchronous Metal eval is not cancellable).
        let perRequestCap = maxOutputTokens.flatMap { $0 > 0 ? $0 : nil }
        params.maxTokens = min(
            perRequestCap ?? preset.maxOutputTokens,
            descriptor.maxOutputTokens)
        return params
    }

    /// Greedy generation parameters (temperature 0 → `ArgMaxSampler`, see `GenerateParameters.sampler()`). Used
    /// ONLY by the speculative greedy lane: at temperature 0 the vendored exact-equality acceptance is
    /// token-identical to greedy target-only decoding. Derived from `_generateParameters` so the decode-cap /
    /// clamp rule is shared; the sole delta is forcing the greedy sampler. `_generateParameters` itself is
    /// byte-unchanged, so single-model scout/core outputs are untouched.
    func _greedyParameters(
        for preset: BASOrganPreset,
        maxOutputTokens: Int? = nil
    ) -> GenerateParameters {
        var params = _generateParameters(
            for: preset, maxOutputTokens: maxOutputTokens)
        params.temperature = 0
        return params
    }

    /// Sampling-lane generation parameters: the preset's temperature with the PURE-TEMPERATURE envelope forced
    /// (topP=1 ⇒ `CategoricalSampler`, no topP/topK/minP filtering). The vendored rejection-sampling branch is
    /// exact ONLY for pure-temperature sampling — its p/q shaping mirrors `CategoricalSampler`'s
    /// `softmax(logits/temp)` draw; a filtered sampler would make q ≠ the draft's true draw distribution (audit
    /// fix). HONEST BOUND: the `.sampling` speculative lane therefore samples the pure-temperature distribution,
    /// NOT the preset's topP-shaped one — a host that needs nucleus sampling keeps the single-model path.
    func _samplingParameters(
        for preset: BASOrganPreset,
        maxOutputTokens: Int? = nil
    ) -> GenerateParameters {
        var params = _generateParameters(
            for: preset, maxOutputTokens: maxOutputTokens)
        params.topP = 1
        return params
    }

    /// Whether THIS request is eligible for speculation under `mode`, by the REQUEST's sampling temperature. Pure
    /// + framework-free + host-testable (no container needed). This is the byte-safety gate for greedy default-on:
    /// the greedy lane forces temperature 0, so it must run ONLY for requests that are ALREADY greedy
    /// (`temperature == 0`) — a scout (0.1) / core (0.7) request must NEVER be converted to greedy (that would
    /// change its output). The sampling lane is the mirror (temperature > 0); it stays gated OFF by
    /// `shouldSpeculate` (on-device cert: doNotEnable — slower) but the eligibility rule is defined for symmetry.
    ///
    /// This is the MECHANISM end of the doctrine→mechanism contract; the DOCTRINE end is
    /// `BASDecodeLane.engagesSpeculativeDecode` (BASOrgan) — `.greedy` is the only lane whose preset (temp 0)
    /// satisfies this gate. The two ends stay in their own modules (the gate keys on `temperature`, the honest
    /// framework-free invariant — no BASMLXAdapter→BASOrgan-policy coupling).
    public nonisolated static func requestEligibleForSpeculation(
        mode: BASSpeculativeMode, request: BASOrganRequest
    ) -> Bool {
        switch mode {
        case .off: return false
        case .greedy: return BASDecodeLanePolicy.isGreedyByteSafe(temperature: request.preset.temperature)
        case .sampling: return request.preset.temperature > 0
        }
    }

    // `shouldSpeculate(for:)` RETIRED (DecodePlan): the planner (BASDecodeLanePolicy.decodeStrategy) is now the SOLE
    // decode decider, so this scattered decision is gone. The spec-engagement condition it expressed is now the
    // planner's `capabilities.draftModelLoaded` (== `isSpeculationActive`: draft loaded + mode != .off) composed with
    // the shared `isGreedyByteSafe` temp gate. `requestEligibleForSpeculation` above is KEPT as the pure, tested
    // eligibility rule (it delegates to `isGreedyByteSafe`, so no drift).
    #endif

    public init(
        model: MLXModelCatalog.Entry = MLXModelCatalog.gemma4_E4B_4bit,
        providerID: String? = nil,
        providerName: String? = nil,
        supportsStreaming: Bool = true,
        maxInputTokens: Int = MLXOrganAdapter.defaultMaxInputTokens,
        maxOutputTokens: Int = MLXOrganAdapter.defaultMaxOutputTokens,
        supportedRoles: Set<BASOrganRole> = [.scout, .core],
        cacheLimitBytes: Int? = MLXOrganAdapter.defaultCacheLimitBytes,
        memoryLimitBytes: Int? = nil,
        draftModel: MLXModelCatalog.Entry? = nil,
        speculativeDecoding: BASSpeculativeMode = .greedy,
        numDraftTokens: Int = 2,
        speculativeFitBudgetBytes: Int? = BASMLXMemoryBudget.defaultSpeculativeFitBudgetBytes,
        kvCacheBits: Int? = nil,
        maxKVSize: Int? = nil,
        enforceMemoryAdmission: Bool = false,
        activeHardCapBytes: Int? = nil,
        // MTP DRAFTER DEFAULT-ON (operator-elected, 2026-07-03 — same election format as the 2026-06-11 greedy
        // speculation default-ON): when the main model is Qwen3.5-family and qwen35_mtp_folded.safetensors is
        // found at a canonical location (see _resolveMTPWeightsURL), the .mtpSpec lane is OFFERED by default —
        // ship-cert: planner 7/7 + endurance PASS (thermal-gated never-worse) + E2E pipeline 1.30×, ADR-039
        // lossless. `mtpDrafterWeightsURL` overrides discovery; `mtpSpecEnabled: false` is the kill-switch
        // (pure legacy behavior, byte-equal).
        mtpDrafterWeightsURL: URL? = nil,
        mtpSpecEnabled: Bool = true,
        // 会话→加速lane opt-in (device crossover 2026-07-04): greedy short-history session turns via the
        // stateless fused-MTP path; transition to ChatSession re-hydration past ~250 est tokens.
        sessionFusedLane: Bool = false
    ) {
        self.sessionFusedLane = sessionFusedLane
        self.model = model
        self.cacheLimitBytes = cacheLimitBytes
        self.memoryLimitBytes = memoryLimitBytes
        self.kvCacheBits = kvCacheBits
        self.maxKVSize = maxKVSize
        self.enforceMemoryAdmission = enforceMemoryAdmission
        self.activeHardCapBytes = activeHardCapBytes
        self.mtpDrafterWeightsURL = mtpDrafterWeightsURL
        self.mtpSpecEnabled = mtpSpecEnabled
        // GREEDY SPECULATION DEFAULT-ON (operator-elected, 2026-06-11): when speculation is enabled and the caller
        // didn't pass an explicit draft, auto-resolve the curated same-family draft from `speculativePairings`.
        // A target with no pairing (e.g. a small model used directly, or Gemma 3 4B) resolves to nil → no draft →
        // single-model (byte-identical). Whether the resolved draft is actually LOADED is gated by the fit budget
        // in `loadModel`.
        self.draftModel = draftModel
            ?? (speculativeDecoding != .off
                ? MLXModelCatalog.recommendedDraft(forTargetProviderID: model.providerID)
                : nil)
        self.speculativeDecoding = speculativeDecoding
        self.numDraftTokens = max(1, numDraftTokens)
        self.speculativeFitBudgetBytes = speculativeFitBudgetBytes
        self.descriptor = BASOrganDescriptor(
            providerID: providerID ?? model.providerID,
            providerName: providerName ?? model.providerName,
            supportsStreaming: supportsStreaming,
            maxInputTokens: maxInputTokens,
            maxOutputTokens: maxOutputTokens,
            runsOnDevice: true,
            supportedRoles: supportedRoles,
            // ADR-041 §D — matrix metadata: MLX is the open-weight on-device lane. The default Gemma entries are
            // on-device certified; the Llama/Qwen `availableAlternatives` are experimental.
            providerKind: .mlx,
            certificationTier: MLXModelCatalog.defaultEntries.contains { $0.providerID == model.providerID }
                ? .certified : .experimental)
    }

    /// Convenience init grouping the six memory/cache/KV/admission knobs into one `MLXMemoryPolicy` instead of
    /// six flat parameters. Delegates to the designated init — `MLXOrganAdapter(memoryPolicy: MLXMemoryPolicy())`
    /// is byte-identical to the bare `MLXOrganAdapter()`. `memoryPolicy` is required (no default) so it never
    /// collides with the zero-arg designated init.
    public init(
        model: MLXModelCatalog.Entry = MLXModelCatalog.gemma4_E4B_4bit,
        providerID: String? = nil,
        providerName: String? = nil,
        supportsStreaming: Bool = true,
        maxInputTokens: Int = MLXOrganAdapter.defaultMaxInputTokens,
        maxOutputTokens: Int = MLXOrganAdapter.defaultMaxOutputTokens,
        supportedRoles: Set<BASOrganRole> = [.scout, .core],
        memoryPolicy: MLXMemoryPolicy,
        draftModel: MLXModelCatalog.Entry? = nil,
        speculativeDecoding: BASSpeculativeMode = .greedy,
        numDraftTokens: Int = 2,
        speculativeFitBudgetBytes: Int? = BASMLXMemoryBudget.defaultSpeculativeFitBudgetBytes
    ) {
        self.init(
            model: model,
            providerID: providerID,
            providerName: providerName,
            supportsStreaming: supportsStreaming,
            maxInputTokens: maxInputTokens,
            maxOutputTokens: maxOutputTokens,
            supportedRoles: supportedRoles,
            cacheLimitBytes: memoryPolicy.cacheLimitBytes,
            memoryLimitBytes: memoryPolicy.memoryLimitBytes,
            draftModel: draftModel,
            speculativeDecoding: speculativeDecoding,
            numDraftTokens: numDraftTokens,
            speculativeFitBudgetBytes: speculativeFitBudgetBytes,
            kvCacheBits: memoryPolicy.kvCacheBits,
            maxKVSize: memoryPolicy.maxKVSize,
            enforceMemoryAdmission: memoryPolicy.enforceMemoryAdmission,
            activeHardCapBytes: memoryPolicy.activeHardCapBytes)
    }

    /// The current memory knobs as a grouped policy (mirror of the convenience init).
    public nonisolated var memoryPolicy: MLXMemoryPolicy {
        MLXMemoryPolicy(
            cacheLimitBytes: cacheLimitBytes,
            memoryLimitBytes: memoryLimitBytes,
            kvCacheBits: kvCacheBits,
            maxKVSize: maxKVSize,
            enforceMemoryAdmission: enforceMemoryAdmission,
            activeHardCapBytes: activeHardCapBytes)
    }

    // MARK: - Load

    /// Download (or fetch from cache) and load the configured model.
    /// Idempotent: if a container is already loaded, returns
    /// immediately. Subsequent calls re-load only if the caller
    /// passes a different `MLXModelCatalog.Entry` via a fresh
    /// `MLXOrganAdapter` instance.
    ///
    /// - Parameter progressHandler: receives `Progress` updates
    ///   during the Hugging Face download. Pass an empty closure to
    ///   ignore.
    ///
    /// First call against a cold cache downloads ~1.4–3 GB depending
    /// on the entry; second call hits the local cache and returns
    /// in seconds.
    public func loadModel(
        progressHandler: @Sendable @escaping (Progress) -> Void
            = { _ in }
    ) async throws {
        #if canImport(MLXLLM)
        #if targetEnvironment(simulator)
        // MLX's Metal device constructor (`mlx::core::metal::Device`) calls
        // `std::__libcpp_verbose_abort` on the iOS Simulator (no real Metal GPU) — a C++ abort that
        // Swift do/catch CANNOT intercept; it terminates the whole process (SIGABRT). Surface it as
        // a CATCHABLE Swift error so every caller's `try await loadModel()` handles it gracefully
        // instead of crashing. MLX runs normally on physical Apple-silicon devices.
        throw BASOrganError.providerUnavailable(
            reason:
                "MLX requires a physical Metal GPU; " +
                "unavailable on the iOS Simulator")
        #endif
        if modelContainer != nil { return }

        // OPT-IN pre-load jetsam admission (default off ⇒ byte-equal, ADR-014). A single-model load whose
        // estimated peak footprint crosses the device's ActiveHard cap is SIGKILL'd before the first token
        // (E4B died this way twice on the iPhone Air, deviceB) — refuse it cleanly here so the host gets a
        // CATCHABLE error instead of an uncatchable jetsam. The data-grounded fix the 2026-06-12 run mandated.
        if enforceMemoryAdmission {
            let cap = activeHardCapBytes
                ?? BASMLXMemoryModel.resolvedActiveHardCapBytes()          // 缝7: entitlement-aware
                ?? BASMLXMemoryBudget.measurediPhoneAirActiveHardCapBytes
            if BASMLXMemoryBudget.wouldExceedActiveHardCap(
                targetProviderID: model.providerID, capBytes: cap) {
                throw BASOrganError.providerUnavailable(
                    reason: "model \(model.providerID) projected peak footprint exceeds the device jetsam "
                        + "cap (\(cap / (1024 * 1024)) MB) — would SIGKILL at load; pick a smaller model "
                        + "(see MLXModelCatalog.recommendedDefault(forActiveHardCapBytes:))")
            }
        }

        // Tranche C — local-directory model lane: an Entry with `localDirectoryName` loads from the
        // app's Documents/<dir>/ (operator-staged, e.g. the locally-quantized 3-bit variant) instead
        // of the HF download. nil (every published entry) keeps the exact id-based path, byte-equal。
        let configuration: ModelConfiguration
        if let localDir = model.localDirectoryName {
            guard let docs = FileManager.default.urls(
                for: .documentDirectory, in: .userDomainMask).first else {
                throw BASOrganError.providerUnavailable(
                    reason: "document directory unavailable — cannot resolve "
                        + "local model dir Documents/\(localDir)")
            }
            let dirURL = docs.appendingPathComponent(localDir, isDirectory: true)
            guard FileManager.default.fileExists(atPath: dirURL.path) else {
                throw BASOrganError.providerUnavailable(
                    reason: "local model directory missing: Documents/\(localDir) "
                        + "(stage it via devicectl device copy to)")
            }
            configuration = ModelConfiguration(
                directory: dirURL,
                extraEOSTokens: Set(model.extraEOSTokens))
        } else {
            configuration = ModelConfiguration(
                id: model.id,
                extraEOSTokens: Set(model.extraEOSTokens))
        }

        // Resolve the load-time memory budget (Phase C). Only when speculation will ACTUALLY engage (mode on +
        // draft resolved + fits the budget) is the dual-residency UNION applied (`.explicitOverride`); otherwise
        // this returns today's exact single-model values + `.adapterDefault` precedence → byte-identical to the
        // pre-speculative path. So a non-fitting pair (Gemma4 E4B+E2B on 8 GB) keeps the single-model budget.
        let willSpeculate = willEngageSpeculation
        let budget = BASMLXMemoryBudget.resolve(
            targetProviderID: model.providerID,
            draftProviderID: willSpeculate ? draftModel?.providerID : nil,
            singleCacheLimitBytes: cacheLimitBytes,
            singleMemoryLimitBytes: memoryLimitBytes)
        let precedence: MLXRuntimeConfig.Precedence =
            budget.isSpeculativeUnion ? .explicitOverride : .adapterDefault

        // ADR-041 §C — bound the LOAD-TIME memory peak (the download/materialize spike) BEFORE the container
        // load: `MLX.Memory.memoryLimit` makes malloc WAIT once exceeded, so it must be set first (the
        // post-load `cacheLimit` below cannot bound the load spike). OPT-IN (default nil=off → byte-equal).
        if let mem = budget.memoryLimitBytes {
            MLXRuntimeConfig.shared.applyMemoryLimit(bytes: mem, precedence: precedence)
        }
        let container = try await #huggingFaceLoadModelContainer(
            configuration: configuration,
            progressHandler: progressHandler)
        self.modelContainer = container
        // ADR-038 §11.7-§11.9 — bound MLX's free-buffer cache pool so it can't grow unbounded across turns
        // (variable-shape models like Gemma-3n otherwise exhaust device memory → wedge/OOM). Output-byte-equal
        // (a free-buffer recycling ceiling). Single-model: first-`.adapterDefault`-wins; speculative union:
        // `.explicitOverride` (the union must win). An explicit `setGPUCacheLimit` still overrides either.
        if let cache = budget.cacheLimitBytes {
            MLXRuntimeConfig.shared.applyCacheLimit(bytes: cache, precedence: precedence)
        }
        // SPECULATION AUTO-LOAD: auto-load the draft when speculation will engage (mode on + draft resolved +
        // fits the budget). Greedy is the default-on lane; sampling only happens when explicitly configured.
        // Best-effort — a draft-load failure must NOT break the target; on any
        // throw the adapter stays single-model (byte-identical), `shouldSpeculate` returns false (no draft
        // container). But NEVER silently: the downgrade is recorded in `draftLoadFailureReason` + logged, so a
        // host can tell "speculating" from "quietly fell back". A host can still call `loadDraftModel()` itself.
        if willSpeculate {
            do {
                try await loadDraftModel()
                draftLoadFailureReason = nil
            } catch {
                draftLoadFailureReason = String(describing: error)
                #if canImport(os)
                Logger(subsystem: "com.bas.mlx", category: "speculative").fault(
                    "auto draft load FAILED — staying single-model (byte-identical): \(String(describing: error), privacy: .public)")
                #endif
            }
        }
        #else
        throw BASOrganError.providerUnavailable(
            reason: Self.frameworkUnavailableReason
                + Self.frameworkUnavailablePlatformSuffix)
        #endif
    }

    /// Load the configured DRAFT model into its own container for speculative decoding. Must be called AFTER
    /// `loadModel(...)` (the target's load sets the dual-residency union memory budget). Idempotent: a no-op if
    /// the draft container is already loaded.
    ///
    /// Throws — and the caller keeps the byte-identical single-model path (`shouldSpeculate` stays false), the
    /// fail-honest fallback — when: speculative decoding is off, no draft is configured, the target isn't loaded,
    /// or the draft is not a valid same-family pairing. A shared tokenizer is required (a cross-family draft would
    /// mis-tokenize the target's stream); it is proxied here by a shared turn terminator + a distinct provider.
    /// Phase 3 replaces this proxy with the explicit `speculativePairings` table.
    ///
    /// AUDIT-4 (the fit-budget asymmetry, made EXPLICIT): unlike the auto-load in `loadModel`, this explicit
    /// call does NOT enforce `speculativeFitBudgetBytes` — deliberately, so a cert probe / entitled host can
    /// probe pairs beyond the conservative default budget (it is how the Gemma memory finding was measured).
    /// Calling it when `willEngageSpeculation == false` means the HOST ACCEPTS THE MEMORY RISK: the union budget
    /// was never applied, and on a constrained device the load can be jetsam-killed (uncatchable). The breach is
    /// logged loudly below — never silent.
    public func loadDraftModel(
        progressHandler: @Sendable @escaping (Progress) -> Void = { _ in }
    ) async throws {
        #if canImport(MLXLLM)
        #if targetEnvironment(simulator)
        throw BASOrganError.providerUnavailable(
            reason:
                "MLX requires a physical Metal GPU; " +
                "unavailable on the iOS Simulator")
        #endif
        guard speculativeDecoding != .off else {
            throw BASOrganError.providerUnavailable(
                reason: "speculative decoding is off — no draft model to load")
        }
        guard let draft = draftModel else {
            throw BASOrganError.providerUnavailable(
                reason: "no draft model configured for speculative decoding")
        }
        guard modelContainer != nil else {
            throw BASOrganError.providerUnavailable(
                reason: Self.notLoadedReason(
                    "loadModel(...) before loadDraftModel(...)"))
        }
        guard Self.isValidDraftPairing(target: model, draft: draft) else {
            throw BASOrganError.providerUnavailable(
                reason: "draft model \(draft.providerID) is not a valid same-family pairing for "
                    + "target \(model.providerID) (tokenizer mismatch)")
        }
        if draftContainer != nil { return }
        // AUDIT-4: explicit loads beyond the fit budget are PERMITTED (the probe escape hatch) but never silent.
        if let budget = speculativeFitBudgetBytes,
           !BASMLXMemoryBudget.dualResidencyFits(
                targetProviderID: model.providerID,
                draftProviderID: draft.providerID,
                budgetBytes: budget) {
            #if canImport(os)
            Logger(subsystem: "com.bas.mlx", category: "speculative").warning(
                "explicit loadDraftModel BEYOND the fit budget (\(budget / (1024 * 1024), privacy: .public)MB) — host accepts the memory risk; a constrained device may jetsam-kill this load (uncatchable)")
            #endif
        }
        let configuration = ModelConfiguration(
            id: draft.id,
            extraEOSTokens: Set(draft.extraEOSTokens))
        // The union memory budget was already applied on the target's loadModel(); the draft loads under it.
        let container = try await #huggingFaceLoadModelContainer(
            configuration: configuration,
            progressHandler: progressHandler)
        self.draftContainer = container
        // AUDIT-4: an EXPLICIT load that succeeds clears any stale auto-load failure (a host that retried after
        // an auto failure must not see contradictory signals: active=true + a leftover failure reason).
        draftLoadFailureReason = nil
        #else
        throw BASOrganError.providerUnavailable(
            reason: Self.frameworkUnavailableReason
                + Self.frameworkUnavailablePlatformSuffix)
        #endif
    }

    /// U1 (2026-06-12) — release the DRAFT container so the memory
    /// governor (`BASSpeculationMemoryGovernor`) can shed dual-
    /// residency under runtime pressure。 BYTE-SAFE by construction:
    /// greedy speculation is token-identical to target-only decode,
    /// so the draft's absence changes latency only, never output
    /// bits — the one actuator that can flip freely across turns
    /// (ADR-014)。 Call ONLY between turns (the host owns that
    /// scheduling;this actor serializes against in-flight draft()
    /// calls anyway)。 Idempotent:a no-draft state returns false。
    /// NEVER silent:the reason lands in `draftLoadFailureReason` so
    /// `isSpeculationActive == false` is always explainable;a later
    /// `loadDraftModel()` (restore) clears it on success。
    @discardableResult
    public func unloadDraftModel(reason: String) -> Bool {
        #if canImport(MLXLLM)
        guard draftContainer != nil else { return false }
        draftContainer = nil
        draftLoadFailureReason = "unloaded: \(reason)"
        #if canImport(os)
        Logger(subsystem: "com.bas.mlx", category: "speculative")
            .notice("draft model UNLOADED — \(reason, privacy: .public)")
        #endif
        return true
        #else
        return false
        #endif
    }

    /// M246 — Load a previously-trained LoRA adapter (saved via
    /// `MLXLoRATrainer.saveAdapter`) into the loaded foundation
    /// model. Subsequent `draft(_:)` / `streamDraft(_:)` calls will
    /// use the LoRA-tuned model instead of the bare base.
    ///
    /// Must be called AFTER `loadModel(...)`. Idempotent in the
    /// sense that calling twice with the same URL is harmless
    /// (second call overwrites the LoRA params with the same data).
    /// Calling with a different URL replaces the loaded adapter.
    ///
    /// - Parameter url: file URL pointing to a `.safetensors` file
    ///   produced by `MLXLoRATrainer.saveAdapter`.
    /// - Parameter configuration: the SAME training `Configuration` the adapter was trained
    ///   with — its `rank`/`scale` must match the adapter's shapes or `update(verify:)`
    ///   throws. ch1066: was hardcoded rank 8 / scale 10, silently mismatching any adapter
    ///   trained with a non-default rank. Defaults to `Configuration()` (rank 8 / scale 10).
    /// - Parameter numLayers: the last-N transformer blocks the adapter modulates. MUST match the
    ///   layer count the adapter was trained with, or `update(verify: .noUnusedKeys)` throws on the
    ///   unmatched layers. Defaults to the trainer's `numLoRALayers` (4) so existing callers are
    ///   unchanged. The v12 honesty adapter (WiSE-FT λ=0.6 = `wiseft_v9_lam60`) was trained on 16
    ///   layers → load it with `loadAdapter(from:, configuration: .init(rank: 4, scale: 12.0), numLayers: 16)`.
    public func loadAdapter(
        from url: URL,
        configuration: MLXLoRATrainer.Configuration = MLXLoRATrainer.Configuration(),
        numLayers: Int = MLXLoRATrainer.Configuration.numLoRALayers
    ) async throws {
        #if canImport(MLXLLM)
        guard let container = modelContainer else {
            throw BASOrganError.providerUnavailable(
                reason: Self.notLoadedReason(
                    "loadModel(...) before loadAdapter(...)"))
        }
        // M246 — apply LoRA layers + load adapter weights via the
        // container's perform action so all model mutation runs on
        // the container's executor. Sendable-correct: weights are
        // loaded INSIDE the closure (NestedDictionary<MLXArray>
        // isn't Sendable across actor boundaries).
        let loraParams = LoRAConfiguration.LoRAParameters(
            rank: configuration.rank, scale: configuration.scale, keys: nil)
        let loraConfig = LoRAConfiguration(
            numLayers: numLayers,
            fineTuneType: .lora,
            loraParameters: loraParams)
        let adapterURL = url

        try await container.perform { (ctx: ModelContext) in
            _ = try LoRAContainer.from(
                model: ctx.model,
                configuration: loraConfig)
            let weights = try MLX.loadArrays(url: adapterURL)
            let parameters = ModuleParameters.unflattened(weights)
            try ctx.model.update(
                parameters: parameters,
                verify: .noUnusedKeys)
        }
        #else
        throw BASOrganError.providerUnavailable(
            reason: Self.frameworkUnavailableReason)
        #endif
    }

    /// `true` once `loadModel(...)` has produced a `ModelContainer`.
    /// Hosts use this to gate UI ("model ready") without forcing a
    /// load attempt.
    public func isModelLoaded() -> Bool {
        #if canImport(MLXLLM)
        return modelContainer != nil
        #else
        return false
        #endif
    }

    /// M249 — kick off a tiny dummy turn to JIT-compile Metal
    /// kernels and warm the model's compute path. The first real
    /// `draft(_:)` call after this returns in steady-state
    /// latency (~600ms for short outputs on Apple Silicon) instead
    /// of cold-start latency (~10–16s while kernels compile).
    ///
    /// Idempotent: safe to call any number of times. Skipped on
    /// non-Apple-Silicon builds. Caller must have completed
    /// `loadModel(...)`.
    ///
    /// On the M248 N=400 run, the first 100 prompts averaged
    /// 10898 ms while the last 100 averaged 566 ms — a 19×
    /// difference dominated by Metal kernel JIT. Prewarm
    /// captures most of that delta at adapter-load time so end
    /// users don't pay it on their first turn.
    public func prewarm() async throws {
        #if canImport(MLXLLM)
        guard let container = modelContainer else {
            throw BASOrganError.providerUnavailable(
                reason: Self.notLoadedReason(
                    "loadModel(...) before prewarm()"))
        }
        let role: BASOrganRole = descriptor.supportedRoles
            .contains(.scout) ? .scout : .core
        let dummyRequest = BASOrganRequest(
            requestID: Self.prewarmRequestID,
            role: role,
            preset: role == .scout ? .scout : .core,
            instruction: "Hi.")
        var params = _generateParameters(
            for: dummyRequest.preset)
        // Cap decode — we only need to JIT the kernels and exercise
        // the prefill→decode boundary, not generate a full response.
        params.maxTokens = Self.prewarmDecodeTokens
        let session = ChatSession(
            container,
            instructions:
                Self.systemInstructions(for: dummyRequest),
            generateParameters: params)
        _ = try await session.respond(
            to: Self.prompt(for: dummyRequest))
        #else
        // BUG-2 (ch1040) — every sibling (loadModel/loadAdapter/draft)
        // throws on the non-MLX path; prewarm previously had an empty
        // #else and silently "succeeded" off Apple Silicon. Match the
        // sibling contract.
        throw BASOrganError.providerUnavailable(
            reason: Self.frameworkUnavailableReason)
        #endif
    }

    /// Throughput-first prewarm for the greedy speculative lane.
    ///
    /// `prewarm()` intentionally mirrors the role's normal preset.
    /// For the max-throughput path, however, the useful hot path is
    /// `temperature == 0` speculative decode. This method exercises
    /// that lane when the draft is actually resident; if any gate has
    /// fallen back to single-model mode, it delegates to `prewarm()`
    /// so hosts still get the ordinary target-kernel warmup.
    public func prewarmGreedySpeculative() async throws {
        #if canImport(MLXLLM)
        guard modelContainer != nil else {
            throw BASOrganError.providerUnavailable(
                reason: Self.notLoadedReason(
                    "loadModel(...) before prewarmGreedySpeculative()"))
        }
        let role: BASOrganRole = descriptor.supportedRoles
            .contains(.core) ? .core : .scout
        let dummyRequest = BASOrganRequest(
            requestID: "prewarm-greedy-speculative",
            role: role,
            preset: .greedyDeterministic,
            instruction: "Hi.",
            maxOutputTokens: Self.prewarmDecodeTokens)
        // Prewarm the draft model whenever speculation is configured (draft loaded + mode != .off). Per-request
        // eligibility (temp 0) doesn't apply to prewarm — it uses a greedy dummy. (Was shouldSpeculate(dummy).)
        guard isSpeculationActive else {
            try await prewarm()
            return
        }
        _ = try await _draftSpeculative(dummyRequest)
        #else
        throw BASOrganError.providerUnavailable(
            reason: Self.frameworkUnavailableReason)
        #endif
    }

    // MARK: - Draft

    public func draft(
        _ request: BASOrganRequest
    ) async throws -> BASOrganDraft {
        guard descriptor.supportedRoles.contains(request.role) else {
            throw BASOrganError.unsupportedRole(request.role)
        }

        #if canImport(MLXLLM)
        // P2 多agent复用: a seat request (sessionID set) routes to the per-seat session pool — KV/history
        // reuse beats re-prefill + speculation on conversational turns (M254 measured), and the planner's
        // lanes are deliberately excluded there. nil sessionID = the historical stateless path, byte-equal.
        if let sid = request.sessionID {
            return try await draftMultiTurn(request, sessionID: sid)
        }
        // Route to the speculative decoder under the same fail-closed gates as `streamDraft`: loaded draft,
        // live mode, and request eligibility for that mode. Default off path / ineligible requests run the exact
        // single-model code below, byte-identical. (`draftMultiTurn` is deliberately NOT routed — its ChatSession
        // KV-cache reuse beats speculation, which would re-prefill the whole conversation per turn.)
        // DecodePlan: the planner decides this eager base entry too (so ALL eager production decode — draft /
        // draft(_:purpose:) / draft(_:electAccelerated:) — flows through ONE decider). Purpose .scoutDefault skips
        // the model-free lanes, so the planner yields draft-model spec (when a draft is loaded — byte-equal to
        // shouldSpeculate) or plain. The kill-switch (decodePlannerAutoSelect off) and the sampling mode fall back
        // to the explicit shouldSpeculate decision, which also still serves streamDraft + the prewarm check.
        // The planner is the SOLE production decider for eager decode. The kill-switch (decodePlannerAutoSelect off)
        // now means PURE PLAIN — no acceleration at all (the simplest safe revert), not the legacy spec gate.
        _pressureCheck(keeping: nil)                     // 案5: between-turn reclaim sample
        // 案5: ONE context per turn — every decider sees the same facts (and one telemetry line
        // says who could throttle and why; BAS_DECODE_CTX=1).
        let ctx = MLXOrganAdapter._decodeContext(purpose: .scoutDefault, request: request)
        let strategy: BASDecodeStrategy = decodePlannerAutoSelect
            ? BASDecodeLanePolicy.decodeStrategy(
                context: ctx, capabilities: _decodeCapabilities(),
                profiler: draftProfiler, numDraftTokens: numDraftTokens)
            : .plain
        // 可解释性①: THE turn line is emitted by _execute once the EXECUTED lane is known.
        return try await _execute(strategy, for: request, purpose: .scoutDefault, context: ctx)
        #else
        throw BASOrganError.providerUnavailable(
            reason: Self.frameworkUnavailableReason
                + Self.frameworkUnavailablePlatformSuffix)
        #endif
    }

    /// The single-model (non-speculative) draft path: ChatSession decode + terminal-metrics capture, byte-identical
    /// to `respond(to:)`. Extracted from `draft(_:)` (S1) so the DecodeStrategy executor can dispatch `.plain` here.
    func _plainDraft(_ request: BASOrganRequest) async throws -> BASOrganDraft {
        #if canImport(MLXLLM)
        // DecodePlan root-fix (byte-identity, point #3). The plain lane now runs the SAME `_buildLMInput` +
        // `BASPromptLookupDecoder` loop as every accelerated lane, driven by `nullDrafter` (ngram longer than any
        // generation ⇒ never proposes ⇒ pure single-token greedy). So `plain == model-free == draft-spec`
        // token-for-token on the N/N kernel (Llama) — one forward + one prompt path for ALL lanes.
        //
        // WHY (device-measured): the old plain used `ChatSession`, a SEPARATE forward/templating path. On Llama the
        // manual loop is byte-exact to single-token greedy ("Llama is N/N" — BASWindowMaskedCache), but ChatSession
        // is NOT, so plain(ChatSession) diverged from the manual-loop lanes at a thin argmax margin → the decode-
        // planner A/B was byte_equal=NO on the json workload (plain 2 entries vs model-free 3). `nullDrafter` IS the
        // AB-proven greedy baseline (the `crossTurnLookupAB` / `saguaroAB` K=0 base lane), so this makes the
        // planner's lane choice truly byte-invariant ("换 lane 不换 bytes").
        //
        // Trade-off: the loop emits no `GenerateCompletionInfo`, so plain's `completionMetrics` is now nil — matching
        // every other production lane. The prior ChatSession metrics were observability-only (not on any contract).
        do {
            let g = try await _generateModelFree(
                for: request, drafter: Self.nullDrafter,
                notLoadedHint: "loadModel(progressHandler:) before draft(_:)")
            return _modelFreeDraft(body: g.body, request: request)
        } catch BASPromptLookupDecoder.DecodeError.nonTrimmableCache {
            // GDN/SSM caches (Qwen3.5) fail the greedy loop's UPFRONT trimmable guard — before any forward — so
            // every eager `.plain` on these models crashed, INCLUDING the executor's fail-closed landing and the
            // planner's thermal-gate rerouting (device-caught 2026-07-03: thermal serious → temp>0 rerouted to
            // .plain → nonTrimmableCache). Fall back to the ChatSession path (the pre-703e8666d plain): on GDN
            // the production plain lane IS ChatSession (streamDraft), so plain-eager == plain-streaming is the
            // byte-invariant that matters here — the manual-loop identity is a trimmable-KV property.
            return try await _chatSessionPlainDraft(request)
        }
        #else
        throw BASOrganError.providerUnavailable(
            reason: Self.frameworkUnavailableReason
                + Self.frameworkUnavailablePlatformSuffix)
        #endif
    }

    #if canImport(MLXLLM)
    /// The ChatSession plain lane (the pre-703e8666d `_plainDraft` body, byte-identical to `respond(to:)`).
    /// Serves models whose caches can't run the trim-based greedy loop (GDN/SSM — see the catch above);
    /// on trimmable-KV models the manual loop remains the sole plain path.
    private func _chatSessionPlainDraft(_ request: BASOrganRequest) async throws -> BASOrganDraft {
        guard let container = modelContainer else {
            throw BASOrganError.providerUnavailable(
                reason: Self.notLoadedReason(
                    "loadModel(progressHandler:) before draft(_:)"))
        }
        let session = ChatSession(
            container,
            instructions: Self.systemInstructions(for: request),
            generateParameters: _generateParameters(
                for: request.preset,
                maxOutputTokens: request.maxOutputTokens))
        let prompt = Self.prompt(for: request)
        let (rawBody, completionInfo) = try await Self.streamBody(session, prompt: prompt)
        let body = Self.applyMarkerPostprocessing(rawBody)
        return _buildDraft(
            body: body, request: request,
            completionMetrics: Self.completionMetrics(from: completionInfo))
    }
    #endif

    // MARK: - Multi-turn (M254)

    /// M254 — multi-turn variant of `draft(_:)`. Reuses a
    /// `ChatSession` keyed by `(sessionID, role)` so KV cache +
    /// conversation history persist across turns. Each call after
    /// the first only prefills the new user-turn tokens; the
    /// system instructions + prior turns stay cached.
    ///
    /// Use this for any flow where conversational context matters
    /// (follow-up questions, multi-step reasoning, slot filling).
    /// For one-shot turns where each request is independent (the
    /// curriculum / RISK-PERMIT use case), use `draft(_:)` — it's
    /// stateless.
    ///
    /// Concurrency: `ChatSession` itself is not thread-safe, but
    /// every operation here runs on the actor's executor, so calls
    /// against the same session serialize naturally. Two callers
    /// using DIFFERENT session IDs can interleave without
    /// stomping on each other's KV state.
    ///
    /// - Parameters:
    ///   - request: same shape as `draft(_:)` — instruction +
    ///     optional context + role + preset
    ///   - sessionID: caller-supplied conversation ID. Same ID
    ///     across calls = same KV cache + history. Pass a fresh
    ///     UUID per conversation; use `clearSession(sessionID:)`
    ///     to evict.
    ///
    /// - Returns: `BASOrganDraft` with the model's response. Same
    ///   shape as `draft(_:)` — callers can swap the two methods
    ///   without changing downstream code.
    public func draftMultiTurn(
        _ request: BASOrganRequest,
        sessionID: String
    ) async throws -> BASOrganDraft {
        guard descriptor.supportedRoles.contains(request.role) else {
            throw BASOrganError.unsupportedRole(request.role)
        }

        #if canImport(MLXLLM)
        guard let container = modelContainer else {
            throw BASOrganError.providerUnavailable(
                reason: Self.notLoadedReason(
                    "loadModel(...) before draftMultiTurn(...)"))
        }

        // Composite key — same caller session ID with different
        // role gets its own ChatSession (different system prompt).
        let key = Self.sessionKey(sessionID, request.role)
        let dbgS = ProcessInfo.processInfo.environment["BAS_SESSION_DEBUG"] == "1"
        if dbgS { NSLog("[sess-dbg] %@ enter", key) }
        await _ensureExperienceLoaded()                  // P0: opt-in warm-start (once)
        _persistExperienceIfDue()                        // P0: session lane persists on next-turn entry
        _pressureCheck(keeping: key)                     // 案5: between-turn reclaim sample

        // 案3 (2026-07-06 decode-OS audit): lane election is ONE pure function (_sessionLane) —
        // the three inline guard chains re-deriving route class per turn were the seam-1/4 bug
        // class. Bodies below are the certified ones, unchanged; the pooled acquisition order
        // (existing → pending-reclaim → spill-restore → transcript-migration → fresh) stays the
        // seam-certified sequence.
        // Two-phase cost gating (mirrors the old guards' short-circuit profile): warm pooled
        // turns never pay the weights file-stat or the token estimate.
        let laneWanted = sessions[key] == nil && request.preset.temperature == 0
            && (sessionFusedLane || Self.sessionCappedFusedEnabled)
            && _resolveMTPWeightsURL() != nil
        let seedTranscript: [(role: String, text: String)] = laneWanted
            ? (fusedTranscripts[key] ?? [
                (role: "system", text: request.personaInstructions ?? Self.systemInstructions(for: request)),
              ])
            : []
        let lane = Self._sessionLane(
            fusedLaneEnabled: sessionFusedLane,
            cappedFusedEnabled: Self.sessionCappedFusedEnabled,
            hasLiveBox: sessions[key] != nil,
            temperature: request.preset.temperature,
            cap: request.maxOutputTokens,
            weightsAvailable: laneWanted,
            estTokens: laneWanted ? BASOrganDeterministicAdapter.estimateTokens(
                from: seedTranscript.map(\.text) + [request.instruction]) : 0,
            fusedMax: Self.fusedSessionMaxTokens,
            cappedMax: Self.cappedFusedMaxHistoryTokens)
        switch lane {
        case .fusedTranscript(transition: false), .cappedFusedTranscript(transition: false):
            var transcript = seedTranscript
            if dbgS { NSLog("[sess-dbg] %@ lane=%@", key, String(describing: lane)) }
            transcript.append((role: "user", text: Self.prompt(for: request)))
            let r = try await _generateMTPSpecFromMessages(transcript, for: request)
            transcript.append((role: "assistant", text: r.draft.body))
            fusedTranscripts[key] = transcript
            if case .fusedTranscript = lane { fusedSessionTurnCount += 1 }
            // 可解释性①: THE turn line, session flavor — lane election + thermal fallback +
            // B3/B2 facts carried up from the generation.
            let laneName = { if case .fusedTranscript = lane { return "session:fused" }
                             return "session:cappedFused" }()
            var draftOut = r.draft
            if let partial = draftOut.decodeAttribution {
                let a = BASDecodeAttribution(
                    requestID: request.requestID, context: nil,
                    plannedLane: laneName,
                    executedLane: partial.executedLane == "plain" ? "plain" : laneName,
                    failCloseReason: partial.failCloseReason,
                    traceExitReason: partial.traceExitReason,
                    traceThinkTokens: partial.traceThinkTokens,
                    diffProbe: partial.diffProbe)
                if Self.turnLineEnabled { print(a.summaryLine) }
                draftOut = draftOut.withDecodeAttribution(a)
            }
            // Transcript seats carry no KV — their own FIFO bound (缝8a: pooled eviction stays
            // single-sourced in _evictBeyondCap; the old inline LRU loop dropped KV unspilled).
            if fusedTranscripts.count > Self.maxTranscriptSessions,
               let drop = fusedTranscripts.keys.first(where: { $0 != key }) {
                fusedTranscripts.removeValue(forKey: drop)
            }
            return draftOut
        case .fusedTranscript(transition: true), .cappedFusedTranscript(transition: true):
            // TRANSITION: one amortized re-prefill via history re-hydration; the transcript
            // already carries the system message → instructions nil (the vendored init's
            // documented contract). Falls through to the pooled path with the box installed.
            if dbgS { NSLog("[sess-dbg] %@ TRANSITION lane=%@", key, String(describing: lane)) }
            let rehydrated = ChatSession(
                container,
                instructions: nil,
                history: Self.chatMessages(from: seedTranscript),
                generateParameters: _generateParameters(
                    for: request.preset, maxOutputTokens: request.maxOutputTokens),
                additionalContext: Self._sessionAdditionalContext)
            sessions[key] = ChatSessionBox(session: rehydrated)
            fusedTranscripts.removeValue(forKey: key)
        case .pooled:
            break
        }

        let box: ChatSessionBox
        let poolAcquisition: String
        if let existing = sessions[key] {
            if dbgS { NSLog("[sess-dbg] %@ pooled", key) }
            box = existing
            poolAcquisition = "warm"
        } else if let pending = pendingSpill.removeValue(forKey: key) {
            // 缝8a: the seat was evicted but its spill write hasn't landed — take the LIVE box back
            // (the in-flight write sees the removed entry and deletes its stale file).
            if dbgS { NSLog("[sess-dbg] %@ pending-spill reclaim", key) }
            box = pending.box
            sessions[key] = pending.box
            poolAcquisition = "pending-reclaim"
        } else if let restored = await _restoreFromSpill(
            key: key, container: container,
            params: _generateParameters(for: request.preset, maxOutputTokens: request.maxOutputTokens)) {
            if dbgS { NSLog("[sess-dbg] %@ spill-restored", key) }
            box = restored                                  // B5: warm-start from the spill file
            sessions[key] = restored
            poolAcquisition = "spill-restore"
        } else if let transcript = fusedTranscripts[key] {
            // 缝4 (2026-07-06 audit): a transcript-land seat whose next request fails the fused
            // guards (temp>0 / uncapped / cap>384) lands HERE — the fresh branch built a persona-only
            // ChatSession and silently dropped the whole conversation. Migrate through the same
            // init(history:) contract the history-overflow transitions use (the transcript already
            // carries its system message → instructions nil).
            if dbgS { NSLog("[sess-dbg] %@ route-change MIGRATION turns=%d", key, transcript.count) }
            let migrated = ChatSession(
                container,
                instructions: nil,
                history: Self.chatMessages(from: transcript),
                generateParameters: _generateParameters(
                    for: request.preset, maxOutputTokens: request.maxOutputTokens),
                additionalContext: Self._sessionAdditionalContext)
            box = ChatSessionBox(session: migrated)
            sessions[key] = box
            fusedTranscripts.removeValue(forKey: key)
            poolAcquisition = "transcript-migration"
        } else {
            if dbgS { NSLog("[sess-dbg] %@ fresh", key) }
            let fresh = ChatSession(
                container,
                // P2: per-seat persona (frozen at creation — sessions keep their system prompt);
                // nil = the role-derived default (byte-equal with the pre-persona pool).
                instructions:
                    request.personaInstructions ?? Self.systemInstructions(for: request),
                generateParameters: _generateParameters(
                    for: request.preset,
                    maxOutputTokens: request.maxOutputTokens),
                additionalContext: Self._sessionAdditionalContext)
            box = ChatSessionBox(session: fresh)
            sessions[key] = box
            poolAcquisition = "fresh"
        }
        // P2: LRU bound on the pool (recon gap #4 — it was unbounded/unaccounted). Touch on every use;
        // evict the least-recently-used session beyond the cap (its KV frees with the ChatSession).
        sessionLRU.removeAll { $0 == key }
        sessionLRU.append(key)
        if dbgS { NSLog("[sess-dbg] %@ pre-evict lru=%d", key, sessionLRU.count) }
        await _evictBeyondCap()
        if dbgS { NSLog("[sess-dbg] %@ post-evict", key) }

        let prompt = Self.prompt(for: request)
        // P2 gap #5: bounded-concurrency gate around the decode (see maxConcurrentSessionDecodes).
        await acquireSessionDecodeSlot()
        defer { releaseSessionDecodeSlot() }
        if dbgS { NSLog("[sess-dbg] %@ slot acquired (active=%d)", key, activeSessionDecodes) }
        // Same byte-equal stream-consume as draft(_:) — also surfaces the real prefill/decode metrics. On a
        // REUSED session (KV warm) the captured `promptTokenCount` reflects only the new turn → this is also
        // how the Phase-2 KV-reuse lever would be measured.
        let (rawBody, completionInfo) = try await Self.streamBody(box.session, prompt: prompt)
        if dbgS { NSLog("[sess-dbg] %@ decoded %d chars", key, rawBody.count) }
        let body = Self.applyMarkerPostprocessing(rawBody)  // M256

        let pooledLane = "session:pooled(\(poolAcquisition))"
        let attribution = BASDecodeAttribution(
            requestID: request.requestID, context: nil,
            plannedLane: pooledLane, executedLane: pooledLane)
        if Self.turnLineEnabled { print(attribution.summaryLine) }
        return _buildDraft(
            body: body, request: request,
            completionMetrics: Self.completionMetrics(from: completionInfo))
            .withDecodeAttribution(attribution)
        #else
        throw BASOrganError.providerUnavailable(
            reason: Self.frameworkUnavailableReason
                + Self.frameworkUnavailablePlatformSuffix)
        #endif
    }

    #if canImport(MLXLLM)
    /// Consume `ChatSession.streamDetails` (the same stream `respond(to:)` accumulates) → the joined body
    /// (BYTE-IDENTICAL to `respond`) PLUS the terminal `GenerateCompletionInfo`. Observability-only; the
    /// generated text is unchanged.
    private static func streamBody(
        _ session: ChatSession, prompt: String
    ) async throws -> (body: String, info: GenerateCompletionInfo?) {
        var body = ""
        var info: GenerateCompletionInfo?
        for try await gen in session.streamDetails(to: prompt, images: [], videos: []) {
            if let chunk = gen.chunk { body += chunk }
            if let i = gen.info { info = i }
        }
        return (body, info)
    }

    /// Map MLX's `GenerateCompletionInfo` (seconds-based) into the substrate's `BASOrganCompletionMetrics`
    /// (ms-based, real prefill/decode split + real tokens/s). `nil` info → `nil` metrics.
    static func completionMetrics(
        from info: GenerateCompletionInfo?
    ) -> BASOrganCompletionMetrics? {
        guard let info else { return nil }
        return BASOrganCompletionMetrics(
            promptTokens: info.promptTokenCount,
            generationTokens: info.generationTokenCount,
            prefillMs: info.promptTime * 1000.0,
            decodeMs: info.generateTime * 1000.0,
            prefillTokensPerSec: info.promptTokensPerSecond,
            decodeTokensPerSec: info.tokensPerSecond)
    }
    #endif

    #if canImport(MLXLLM)
    /// Rebuild non-Sendable Chat.Messages from the Sendable transcript tuples (local consumption only).
    static func chatMessages(from transcript: [(role: String, text: String)]) -> [Chat.Message] {
        transcript.map { entry in
            switch entry.role {
            case "system": return .system(entry.text)
            case "assistant": return .assistant(entry.text)
            default: return .user(entry.text)
            }
        }
    }

    /// ch1066 — single source of truth for the multi-turn session-pool key
    /// (`<sessionID>#<role>`); used by `draftMultiTurn` + `clearSession` so they can't drift.
    private static func sessionKey(
        _ sessionID: String, _ role: BASOrganRole
    ) -> String {
        "\(sessionID)#\(role.rawValue)"
    }
    #endif

    /// B5 internal surface (SessionPersist extension; the pool dict is private to this file).
    func _sessionBox(sessionID: String, role: BASOrganRole) -> ChatSessionBox? {
        sessions[Self.sessionKey(sessionID, role)]
    }
    /// B3-gap closure lane (spill-cert take-4 structural finding): CAPPED session turns route
    /// through the FUSED loop — the pooled ChatSession path has no trace-exit, so small-cap turns
    /// on the thinking model truncate inside <think>. DEFAULT ON since the 2026-07-06 endurance
    /// batch (mixed traffic 744s: recall 5/5 across all three route classes incl. the
    /// post-transition seat; transition exercised; zero hangs). BAS_SESSION_CAPPED_FUSED=0 =
    /// the ADR-014 kill-switch (the spill-cert suite pins it — those assertions need pool churn).
    nonisolated static var sessionCappedFusedEnabled: Bool {
        ProcessInfo.processInfo.environment["BAS_SESSION_CAPPED_FUSED"] != "0"
    }
    /// The capped-fused route serves histories up to this estimate (stateless re-prefill stays
    /// cheaper than losing B3/B2/MTP; beyond it the turn falls through to ChatSession KV-reuse).
    static let cappedFusedMaxHistoryTokens = 1024
    /// Transcript-land sessions hold NO KV — bounded separately from the ChatSession pool.
    static let maxTranscriptSessions = 64

    /// Opt-in `enable_thinking=false`(BAS_DISABLE_THINKING=1)— the streaming path's existing
    /// seam extended to the POOLED session lane (观点施压轴 harness 需要格式化最终答案;v12 诚实
    /// 测量全部 thinking-off 先例)。Default nil ⇒ byte-unchanged。
    nonisolated static var _sessionAdditionalContext: [String: any Sendable]? {
        ProcessInfo.processInfo.environment["BAS_DISABLE_THINKING"] == "1"
            ? ["enable_thinking": false] : nil
    }

    /// 案3 (2026-07-06 decode-OS audit): the session LANE election as ONE pure function — the
    /// audit found three inline guard chains re-deriving route class per turn (the seam-1/4 bug
    /// class lived exactly there). This decides WHICH lane a turn rides; the pooled acquisition
    /// order (existing → pending-reclaim → spill-restore → transcript-migration → fresh) stays
    /// in the actor, certified by the seam gates. `transition: true` = history outgrew the
    /// stateless budget → rehydrate to a ChatSession ONCE, then continue pooled this same turn.
    enum BASSessionLane: Equatable {
        case fusedTranscript(transition: Bool)        // opt-in uncapped fused lane
        case cappedFusedTranscript(transition: Bool)  // default-on capped lane (B2+B3+MTP live)
        case pooled
    }
    /// Precedence mirror of the certified guard chains: opt-in fused > capped-fused > pooled.
    /// A live ChatSession, a sampling temperature, missing MTP weights, or an out-of-band cap
    /// all force the pooled lane. PURE — the caller pre-gates the (weights-stat, token-estimate)
    /// costs so warm pooled turns pay neither (the old guards' short-circuit profile).
    nonisolated static func _sessionLane(
        fusedLaneEnabled: Bool, cappedFusedEnabled: Bool, hasLiveBox: Bool,
        temperature: Double, cap: Int?, weightsAvailable: Bool,
        estTokens: Int, fusedMax: Int, cappedMax: Int
    ) -> BASSessionLane {
        guard !hasLiveBox, temperature == 0, weightsAvailable else { return .pooled }
        if fusedLaneEnabled {
            return .fusedTranscript(transition: estTokens >= fusedMax)
        }
        if cappedFusedEnabled, let cap, cap <= 384 {
            return .cappedFusedTranscript(transition: estTokens >= cappedMax)
        }
        return .pooled
    }

    /// B5 spill lane — DEFAULT ON since the 2026-07-06 endurance cert (6 seats over a 4-cap pool,
    /// 55 spill/55 restore cycles, recall 10/10, stable latency at serious thermal, zero hangs;
    /// the cert also caught + fixed the restored-session parameter loss). LRU-evicted sessions
    /// snapshot to Caches instead of losing their KV; a session miss warm-restores from the spill
    /// file before re-prefilling. BAS_SESSION_SPILL=0 is the ADR-014 kill-switch.
    nonisolated static var sessionSpillEnabled: Bool {
        ProcessInfo.processInfo.environment["BAS_SESSION_SPILL"] != "0"
    }
    nonisolated static func _spillDir() -> URL {
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("bas_session_spill", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
    /// 缝3 (2026-07-06 audit): filenames are SHA256(key) — the old '#'→'_' sanitization mapped
    /// `a#scout` and `a_scout` to ONE file (a seat could warm-restore ANOTHER seat's conversation).
    /// Old-named files become orphans and age out via the GC bound / clearAllSessions (spill = cache).
    nonisolated static func _spillURL(forKey key: String) -> URL {
        let digest = SHA256.hash(data: Data(key.utf8))
        let name = digest.map { String(format: "%02x", $0) }.joined()
        return _spillDir().appendingPathComponent(name + ".safetensors")
    }
    /// 缝8a (2026-07-06 audit): eviction no longer awaits the victim's spill INLINE — _persist
    /// serializes behind the victim's ChatSession lock, so a 17th seat's turn could block behind a
    /// long-decoding victim's ENTIRE generation plus a multi-MB synchronous write (priority
    /// inversion). Victims park in a pending-spill side table; the write completes on a detached
    /// task; a seat reclaimed while pending returns LIVE (zero-cost resurrection) and the stale
    /// write self-deletes (generation guard). Also single-sources transcript cleanup here — the
    /// audit's second divergent eviction copy dropped KV without spilling.
    struct _PendingSpill { let box: ChatSessionBox; let generation: Int }
    var pendingSpill: [String: _PendingSpill] = [:]
    private var spillGeneration = 0
    func _evictBeyondCap() async {
        while sessionLRU.count > Self.maxLiveSessions, let oldest = sessionLRU.first {
            sessionLRU.removeFirst()
            fusedTranscripts.removeValue(forKey: oldest)
            guard let victim = sessions.removeValue(forKey: oldest), Self.sessionSpillEnabled
            else { continue }
            _parkPending(oldest, victim)
        }
    }
    /// Shared pending-spill park (缝8a machinery): the ONE way a live box leaves the pool with
    /// its KV preserved — LRU eviction and the pressure ladder's rung-1 both ride it.
    private func _parkPending(_ key: String, _ victim: ChatSessionBox) {
        spillGeneration += 1
        let hadPending = pendingSpill[key] != nil
        pendingSpill[key] = _PendingSpill(box: victim, generation: spillGeneration)
        if !hadPending {
            Task { [weak self] in await self?._completePendingSpill(key: key) }
        }
    }
    /// 案5 rung-1 actuator: warm-park every pooled seat except `key` (zero inline blocking;
    /// a reclaim-while-pending returns the live box — the certified seam-8a semantics).
    func _spillEvictAll(except key: String?) {
        for k in sessions.keys where k != key {
            sessionLRU.removeAll { $0 == k }
            fusedTranscripts.removeValue(forKey: k)
            guard let victim = sessions.removeValue(forKey: k), Self.sessionSpillEnabled
            else { continue }
            _parkPending(k, victim)
        }
    }

    // MARK: - 案5 pressure ladder (BAS_PRESSURE_LADDER=1, opt-in per ADR-014)

    nonisolated static var pressureLadderEnabled: Bool {
        ProcessInfo.processInfo.environment["BAS_PRESSURE_LADDER"] == "1"
    }
    var pressureLadder: BASPressureLadder? = nil
    var ladderFired: [Int] = []
    func pressureLadderTelemetry() -> [Int] { ladderFired }
    func _specDecoderResident() -> Bool { mtpDecoderBox != nil }
    /// Between-turn sample → graduated reclaim. Never called from inside a decode loop.
    /// P0: per-model experience file (SHA256(model.id) prefix — same hygiene as 缝3 spill names)
    /// under Application Support (durable, unlike the purgeable caches dir the spill uses).
    nonisolated func _experienceFileURL() -> URL {
        let digest = SHA256.hash(data: Data(model.id.utf8))
        let hex = digest.map { String(format: "%02x", $0) }.joined().prefix(16)
        return FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("bas_experience", isDirectory: true)
            .appendingPathComponent("experience-\(hex).json")
    }

    /// P0: one-shot load at the first draft entry (opt-in). Invalid/stale/mismatched snapshot
    /// ⇒ cold start, identical to today.
    func _ensureExperienceLoaded() async {
        guard Self._profilerPersistEnabled, !experienceLoadAttempted else { return }
        experienceLoadAttempted = true
        // 复审修1 (HIGH):store 在 load 完成【之后】才发布——发布提前会让并发轮在
        // await 窗口内经 _persistExperienceIfDue 用冷态空快照覆写 7 天累积经验
        // (新 store lastSaveMs=nil ⇒ 防抖不拦)。窗口内 experienceStore==nil 短路一切写。
        let store = BASAcceptanceProfilerStore(url: _experienceFileURL())
        let nowMs = Int64(Date().timeIntervalSince1970 * 1000)
        let snap = await store.load(expectedModelID: model.id, nowMs: nowMs)
        experienceStore = store
        guard let snap else {
            print("📊 experience cold-start (no valid snapshot)")
            return
        }
        // 复审修2 (MED):恢复只在仍冷时生效——await 间隙完成的并发轮可能已折叠在线
        // 学习/已置新鲜 chainEmaL,磁盘旧值不得覆盖活值。
        if draftProfiler.exportCells().isEmpty {
            draftProfiler = BASAcceptanceProfiler(cells: snap.cells)
        }
        if restoredChainEmaL == nil { restoredChainEmaL = snap.chainEmaL }
        let ema = snap.chainEmaL.map { String(format: "%.2f", $0) } ?? "nil"
        print("📊 experience warm-start cells=\(snap.cells.count) chainEmaL=\(ema) age_s=\((nowMs - snap.savedAtMs) / 1000)")
    }

    /// P0: debounced fire-and-forget snapshot (never blocks or fails the decode path).
    func _persistExperienceIfDue(force: Bool = false) {
        guard let store = experienceStore else { return }
        // restoredChainEmaL 由 _MTPRaw 快照在每次 MTP 生成后刷新(perform 闭包内读,
        // 与写同线程)——此处绝不读 box(2-slot 并发下跨线程读 Double = 数据竞争)。
        let snap = BASDecodeExperienceSnapshot(
            modelID: model.id,
            savedAtMs: Int64(Date().timeIntervalSince1970 * 1000),
            cells: draftProfiler.exportCells(),
            chainEmaL: restoredChainEmaL)
        Task { await store.save(snap, nowMs: snap.savedAtMs, force: force) }
    }

    func _pressureCheck(keeping key: String?) {
        guard Self.pressureLadderEnabled else { return }
        guard let headroom = Self._memoryHeadroomBytes() else { return }
        if pressureLadder == nil {
            guard let cap = BASMLXMemoryModel.resolvedActiveHardCapBytes() else { return }
            pressureLadder = BASPressureLadder(config: .init(capBytes: cap))
        }
        guard let rung = pressureLadder!.advise(headroomBytes: headroom) else { return }
        ladderFired.append(rung.rawValue)
        print("📊 pressure-ladder rung=\(rung.rawValue)(\(rung)) headroom=\(headroom / (1024 * 1024))MB")
        switch rung {
        case .parkColdSeats:
            _spillEvictAll(except: key)
        case .dropSpecDecoder:
            // P0: restoredChainEmaL 已由每次生成的 _MTPRaw 快照保持最新(线程安全),
            // 丢 box 无需再读——直接丢,重建时由快照播种。
            mtpDecoderBox = nil                          // ~300MB; lazily re-quantized later
        case .clearAllSessions:
            clearAllSessions()                           // survival over warmth
            setGPUCacheLimit(bytes: 256 * 1024 * 1024)
        }
    }
    /// Drain the pending-spill entry for `key` (looping across supersessions; actor-reentrant).
    func _completePendingSpill(key: String) async {
        while let entry = pendingSpill[key] {
            let gen = entry.generation
            let ok = (try? await Self._persist(entry.box, url: Self._spillURL(forKey: key),
                                               quantizeKV: false)) != nil
            if pendingSpill[key] == nil {
                // Reclaimed live while we were writing — the snapshot is stale; consume it.
                if ok { try? FileManager.default.removeItem(at: Self._spillURL(forKey: key)) }
                return
            }
            if let cur = pendingSpill[key], cur.generation == gen {
                pendingSpill.removeValue(forKey: key)
                if ok { spillCount += 1; Self._pruneSpillDir() }
                return
            }
            // Superseded by a newer eviction of the same key → loop and persist the newer box.
        }
    }
    /// Snapshot GC: keep the newest `keep` spill files (default 32 ≈ 2GB worst-case at 64MB each);
    /// one-shot restore already consumes reclaimed files — this bounds the never-reclaimed tail.
    nonisolated static func _pruneSpillDir(keep: Int = 32) {
        _pruneSpillDir(in: FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("bas_session_spill", isDirectory: true), keep: keep)
    }
    nonisolated static func _pruneSpillDir(in dir: URL, keep: Int) {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: [.contentModificationDateKey]) else { return }
        guard files.count > keep else { return }
        let dated = files.compactMap { url -> (URL, Date)? in
            guard let d = try? url.resourceValues(forKeys: [.contentModificationDateKey])
                .contentModificationDate else { return nil }
            return (url, d)
        }.sorted { $0.1 < $1.1 }
        for (url, _) in dated.prefix(max(0, dated.count - keep)) {
            try? FileManager.default.removeItem(at: url)
        }
    }
    /// Dream-loop window action (B5 follow-up): warm-park EVERY pooled seat to its spill URL
    /// WITHOUT evicting — an app kill after this point warm-starts instead of re-prefilling.
    /// Returns the number of seats snapshotted. Call from idle windows only (persist walks each
    /// session's serial lock; a decoding seat would serialize behind its own turn).
    public func snapshotWarmSeats() async -> Int {
        guard Self.sessionSpillEnabled else { return 0 }
        var n = 0
        for (key, box) in sessions {
            if (try? await Self._persist(box, url: Self._spillURL(forKey: key),
                                         quantizeKV: false)) != nil { n += 1 }
        }
        Self._pruneSpillDir()
        return n
    }
    /// B5 cert telemetry.
    var spillCount = 0
    var spillRestoreCount = 0
    var spillRestoreFailCount = 0
    public func sessionSpillStats() -> (spilled: Int, restored: Int) {
        (spillCount, spillRestoreCount)
    }
    /// Try to warm-restore `key` from its spill file (one-shot: the file is consumed).
    /// `params` MUST carry the restoring request's generate parameters — the spill-cert take-3
    /// probes caught a restored session running on ChatSession DEFAULTS (no token cap, sampling
    /// temperature): one "48-token" turn decoded 5,604 chars before the watchdog fired.
    func _restoreFromSpill(
        key: String, container: ModelContainer, params: GenerateParameters
    ) async -> ChatSessionBox? {
        guard Self.sessionSpillEnabled else { return nil }
        let url = Self._spillURL(forKey: key)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        struct CacheBox: @unchecked Sendable { let cache: [KVCache] }
        guard let box: CacheBox = try? await container.perform({ ctx in
            let fresh = ctx.model.newCache(parameters: nil)
            _ = try BASSessionKVStore.restore(into: fresh, from: url)
            for c in fresh { eval(c.innerState()) }
            return CacheBox(cache: fresh)
        }) else {
            // 缝3 (2026-07-06 audit): a corrupt/incompatible snapshot must be CONSUMED on failure —
            // leaving it meant every future miss re-paid the failed restore forever.
            try? FileManager.default.removeItem(at: url)
            spillRestoreFailCount += 1
            return nil
        }
        try? FileManager.default.removeItem(at: url)
        spillRestoreCount += 1
        return ChatSessionBox(session: ChatSession(
            container, instructions: nil, cache: box.cache, generateParameters: params,
            additionalContext: Self._sessionAdditionalContext))
    }
    /// B5: install a (restored) session under the key, honoring the pool's LRU bound.
    func _installSession(_ session: ChatSession, sessionID: String, role: BASOrganRole) async {
        let key = Self.sessionKey(sessionID, role)
        sessions[key] = ChatSessionBox(session: session)
        sessionLRU.removeAll { $0 == key }
        sessionLRU.append(key)
        await _evictBeyondCap()
    }

    /// Drop the `ChatSession` keyed by `sessionID` for both roles.
    /// Frees its KV cache; future calls with that ID start fresh.
    /// No-op if no session under that ID exists.
    public func clearSession(sessionID: String) {
        crossTurnStore.clear(session: sessionID)
        #if canImport(MLXLLM)
        for role in [BASOrganRole.scout, .core] {
            let key = Self.sessionKey(sessionID, role)
            sessions.removeValue(forKey: key)
            fusedTranscripts.removeValue(forKey: key)
            pendingSpill.removeValue(forKey: key)        // 缝8a: in-flight write self-deletes
            // 缝2 (2026-07-06 audit): clear must reach the DISK tier too — a spilled (or dream-loop
            // warm-parked) snapshot would otherwise RESURRECT the cleared conversation on the next
            // turn, violating the documented fresh-start contract and leaving conversation KV on disk.
            try? FileManager.default.removeItem(at: Self._spillURL(forKey: key))
        }
        sessionLRU.removeAll { $0 == Self.sessionKey(sessionID, .scout) || $0 == Self.sessionKey(sessionID, .core) }
        #endif
    }

    /// Evict every cached session at once. Useful for memory
    /// pressure events (L1 thermal/budget pressure) and for tests.
    public func clearAllSessions() {
        crossTurnStore.clearAll()
        #if canImport(MLXLLM)
        sessions.removeAll()
        fusedTranscripts.removeAll()
        sessionLRU.removeAll()
        pendingSpill.removeAll()                         // 缝8a: in-flight writes self-delete
        Self._clearSpillDir()                        // 缝2: the disk tier goes with the pool
        #endif
    }
    /// 缝2: wipe every spill snapshot (clear-all semantics + the old-naming orphan migration path).
    nonisolated static func _clearSpillDir() {
        let dir = _spillDir()
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: nil) else { return }
        for f in files { try? FileManager.default.removeItem(at: f) }
    }

    // MARK: - GPU memory cache control (opt-in memory tool)

    /// Drain ALL cached Metal buffers from MLX's allocator cache (`MLX.Memory.clearCache()`). That cache
    /// defaults to the full memory limit and can grow across a long inference run; this bounds steady-state GPU
    /// memory. It only frees buffers MLX would otherwise reallocate, so it is OUTPUT-byte-equal to not calling
    /// it (a memory lever, never a correctness one).
    ///
    /// **This drain-ALL is NOT the wedge fix; the bounded CAP (`setGPUCacheLimit` / `cacheLimitBytes`,
    /// default 512 MB) is — ADR-038 §11.8.** Root cause (§11.7): MLX's free-buffer cache POOL grows unbounded
    /// under Gemma-3n's variable buffer shapes (cache_mb 99→446→645… while `active` stays constant), and as the
    /// pool grows against low device headroom the allocator drain LIVELOCKS (the "wedge") or the OS OOM-kills.
    /// A moderate CAP bounds the pool while keeping within-turn reuse; draining EVERYTHING every iteration
    /// instead causes re-alloc churn and wedged EARLIER (§8 A/B: 15 vs 56 responses, slower) — so this is an
    /// occasional memory tool, NOT a per-iteration wedge cure. (§8 read the symptom as "not memory exhaustion —
    /// 730 MB free"; that's superseded by §11.7's pinning of the *cache-pool* growth as the cause.)
    public func drainGPUCache() {
        #if canImport(MLX)
        MLX.Memory.clearCache()
        #endif
    }

    /// Cap MLX's free-buffer cache to `bytes` (`MLX.Memory.cacheLimit`). The cache defaults to the memory limit
    /// (so it may cache GBs); a low cap reclaims aggressively on the next allocation. Output-byte-equal —
    /// buffers are reclaimed + reallocated, the math is unchanged. This is an EXPLICIT caller (host env override
    /// / deliberate API), so it routes through `MLXRuntimeConfig` with `.explicitOverride` precedence — it WINS
    /// over any adapter default already in force (and the change is logged; the global write is single-seamed).
    public func setGPUCacheLimit(bytes: Int) {
        MLXRuntimeConfig.shared.applyCacheLimit(bytes: bytes, precedence: .explicitOverride)
    }

    /// ADR-038 §11.7 — MLX GPU memory stats (MB). `active` = memory held by LIVE MLXArrays (a growing
    /// `active` across fresh sessions = a RETAINED-reference leak); `cache` = the free-buffer pool (a growing
    /// `cache` = pool not drained, which `clearCache()` would release). Splits WHERE the ~175 MB/turn goes.
    public func mlxMemoryStatsMB() -> (active: Double, cache: Double, peak: Double) {
        #if canImport(MLX)
        let mb = 1024.0 * 1024.0
        return (Double(MLX.Memory.activeMemory) / mb,
                Double(MLX.Memory.cacheMemory) / mb,
                Double(MLX.Memory.peakMemory) / mb)
        #else
        return (0, 0, 0)
        #endif
    }

    /// Number of active sessions. Hosts use this for UI / metrics
    /// (e.g. "5 ongoing conversations cached").
    /// Test/telemetry: transcript-land seat count (缝4 gate asserts route residency).
    func _transcriptSeatCount() -> Int {
        #if canImport(MLXLLM)
        return fusedTranscripts.count
        #else
        return 0
        #endif
    }
    public func sessionCount() -> Int {
        #if canImport(MLXLLM)
        return sessions.count
        #else
        return 0
        #endif
    }

    // MARK: - Capacity

    public func currentCapacity() async -> BASOrganCapacity {
        #if canImport(MLXLLM)
        if modelContainer != nil {
            return BASOrganCapacity(
                availableInputTokens: descriptor.maxInputTokens,
                availableOutputTokens: descriptor.maxOutputTokens,
                underPressure: false,
                reasonCodes: [])
        }
        return BASOrganCapacity(
            availableInputTokens: 0,
            availableOutputTokens: 0,
            underPressure: true,
            reasonCodes: ["MLX_NOT_LOADED"])
        #else
        return BASOrganCapacity(
            availableInputTokens: 0,
            availableOutputTokens: 0,
            underPressure: true,
            reasonCodes: ["MLX_UNAVAILABLE_BUILD"])
        #endif
    }

    // MARK: - Prompt helpers (pure)

    /// System-level instructions selected by role. Mirrors the
    /// `AppleFoundationOrganAdapter` pattern so swapping providers
    /// doesn't change the request shape callers see in audit logs.
    public static func systemInstructions(
        for request: BASOrganRequest
    ) -> String {
        switch request.role {
        case .scout:
            return """
            You are the Scout tier of a behavioural AI substrate.
            Keep answers short, structured, and low-commitment.
            Prefer identifying risks and candidate angles over
            producing final prose.
            """
        case .core:
            return """
            You are the Core tier of a behavioural AI substrate.
            Produce a considered response; you are being called
            because a draft has been admitted for full consideration.
            Answer directly and concisely — default to 2–4 sentences
            unless the task genuinely needs more. Do NOT add a
            Status/Role/Tone preamble, headers, or a "thinking process"
            lead-in; respond as the answer itself.
            """
        }
    }

    /// M256 — rewrite known LoRA marker substitutions back to the
    /// canonical curriculum vocabulary so L11 ActionPermit / L14
    /// SovereignWarrant parsers recognize them. Today only handles
    /// `[NEEDS_VERIFICATION]` → `[NEEDS_PERMIT]` (M251 N=400 found
    /// 2/400 cases where the M247 LoRA emits `[NEEDS_VERIFICATION]`
    /// on `Update my password, *` prompts; the substring isn't in
    /// the M239 curriculum vocabulary so the gate would otherwise
    /// pass these requests through as plain text).
    ///
    /// Pure function — deterministic, content-preserving (rewrites
    /// only the marker token, not the surrounding body), exposed
    /// `public static` so tests can pin the rewrite rules.
    /// Future substitutions caught by population eval get added
    /// here as additional `replacingOccurrences` calls.
    public static func applyMarkerPostprocessing(
        _ body: String
    ) -> String {
        body.replacingOccurrences(
            of: "[NEEDS_VERIFICATION]",
            with: "[NEEDS_PERMIT]")
    }

    /// Compose the user-visible prompt from `instruction` + numbered
    /// context items. Pure function — exposed publicly so tests can
    /// pin the format independently of the actor's state.
    public static func prompt(
        for request: BASOrganRequest
    ) -> String {
        var parts = ["Instruction:", request.instruction]
        if !request.context.isEmpty {
            parts.append("")
            parts.append("Context:")
            for (i, ctx) in request.context.enumerated() {
                parts.append("[\(i + 1)] \(ctx)")
            }
        }
        return parts.joined(separator: "\n")
    }
}
