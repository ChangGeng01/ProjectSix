import Foundation
import BASRuntimeCore
import BASOrgan
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
fileprivate struct ChatSessionBox: @unchecked Sendable {
    let session: ChatSession
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
    /// enough to avoid §8's cap=64 re-alloc churn). This is the value with measured on-device evidence (E2B).
    public static let defaultCacheLimitBytes: Int = 512 * 1024 * 1024

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
    #endif

    public init(
        model: MLXModelCatalog.Entry = MLXModelCatalog.gemma4_E4B_4bit,
        providerID: String? = nil,
        providerName: String? = nil,
        supportsStreaming: Bool = true,
        maxInputTokens: Int = MLXOrganAdapter.defaultMaxInputTokens,
        maxOutputTokens: Int = MLXOrganAdapter.defaultMaxOutputTokens,
        supportedRoles: Set<BASOrganRole> = [.scout, .core],
        cacheLimitBytes: Int? = MLXOrganAdapter.defaultCacheLimitBytes
    ) {
        self.model = model
        self.cacheLimitBytes = cacheLimitBytes
        self.descriptor = BASOrganDescriptor(
            providerID: providerID ?? model.providerID,
            providerName: providerName ?? model.providerName,
            supportsStreaming: supportsStreaming,
            maxInputTokens: maxInputTokens,
            maxOutputTokens: maxOutputTokens,
            runsOnDevice: true,
            supportedRoles: supportedRoles)
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

        let configuration = ModelConfiguration(
            id: model.id,
            extraEOSTokens: Set(model.extraEOSTokens))

        let container = try await #huggingFaceLoadModelContainer(
            configuration: configuration,
            progressHandler: progressHandler)
        self.modelContainer = container
        // ADR-038 §11.7-§11.9 — bound MLX's free-buffer cache pool so it can't grow unbounded across turns
        // (variable-shape models like Gemma-3n otherwise exhaust device memory → wedge/OOM). Output-byte-equal
        // (a free-buffer recycling ceiling). Applied with `.adapterDefault` precedence via MLXRuntimeConfig:
        // the FIRST adapter's default wins the process-global cap; a SECOND adapter with a different default is
        // rejected + logged (not a silent last-write-wins). An explicit `setGPUCacheLimit` still overrides.
        if let cacheLimitBytes {
            MLXRuntimeConfig.shared.applyCacheLimit(bytes: cacheLimitBytes, precedence: .adapterDefault)
        }
        #else
        throw BASOrganError.providerUnavailable(
            reason: Self.frameworkUnavailableReason
                + Self.frameworkUnavailablePlatformSuffix)
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
    public func loadAdapter(
        from url: URL,
        configuration: MLXLoRATrainer.Configuration = MLXLoRATrainer.Configuration()
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
            numLayers: MLXLoRATrainer.Configuration.numLoRALayers,
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

    // MARK: - Draft

    public func draft(
        _ request: BASOrganRequest
    ) async throws -> BASOrganDraft {
        guard descriptor.supportedRoles.contains(request.role) else {
            throw BASOrganError.unsupportedRole(request.role)
        }

        #if canImport(MLXLLM)
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
        // Consume `streamDetails` (the SAME underlying stream `respond(to:)` accumulates — respond does exactly
        // `output += chunk`) so we ALSO capture the terminal `GenerateCompletionInfo` (real prefill/decode time
        // + token counts). The joined body is BYTE-IDENTICAL to `respond(to:)`; this is observability-only.
        let (rawBody, completionInfo) = try await Self.streamBody(session, prompt: prompt)
        let body = Self.applyMarkerPostprocessing(rawBody)  // M256

        return BASOrganDraft(
            requestID: request.requestID,
            providerID: descriptor.providerID,
            role: request.role,
            body: body,
            inputTokensEstimated: BASOrganDeterministicAdapter
                .estimateTokens(
                    from: [request.instruction] + request.context),
            outputTokensEstimated: BASOrganDeterministicAdapter
                .estimateTokens(from: [body]),
            producedAt: Date(),
            traceID: BASOrganDeterministicAdapter.digest(
                for: request, providerID: descriptor.providerID),
            completionMetrics: Self.completionMetrics(from: completionInfo))
        #else
        throw BASOrganError.providerUnavailable(
            reason: Self.frameworkUnavailableReason
                + Self.frameworkUnavailablePlatformSuffix)
        #endif
    }

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
        let box: ChatSessionBox
        if let existing = sessions[key] {
            box = existing
        } else {
            let fresh = ChatSession(
                container,
                instructions:
                    Self.systemInstructions(for: request),
                generateParameters: _generateParameters(
                    for: request.preset,
                    maxOutputTokens: request.maxOutputTokens))
            box = ChatSessionBox(session: fresh)
            sessions[key] = box
        }

        let prompt = Self.prompt(for: request)
        // Same byte-equal stream-consume as draft(_:) — also surfaces the real prefill/decode metrics. On a
        // REUSED session (KV warm) the captured `promptTokenCount` reflects only the new turn → this is also
        // how the Phase-2 KV-reuse lever would be measured.
        let (rawBody, completionInfo) = try await Self.streamBody(box.session, prompt: prompt)
        let body = Self.applyMarkerPostprocessing(rawBody)  // M256

        return BASOrganDraft(
            requestID: request.requestID,
            providerID: descriptor.providerID,
            role: request.role,
            body: body,
            inputTokensEstimated: BASOrganDeterministicAdapter
                .estimateTokens(
                    from: [request.instruction] + request.context),
            outputTokensEstimated: BASOrganDeterministicAdapter
                .estimateTokens(from: [body]),
            producedAt: Date(),
            traceID: BASOrganDeterministicAdapter.digest(
                for: request, providerID: descriptor.providerID),
            completionMetrics: Self.completionMetrics(from: completionInfo))
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
    private static func completionMetrics(
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
    /// ch1066 — single source of truth for the multi-turn session-pool key
    /// (`<sessionID>#<role>`); used by `draftMultiTurn` + `clearSession` so they can't drift.
    private static func sessionKey(
        _ sessionID: String, _ role: BASOrganRole
    ) -> String {
        "\(sessionID)#\(role.rawValue)"
    }
    #endif

    /// Drop the `ChatSession` keyed by `sessionID` for both roles.
    /// Frees its KV cache; future calls with that ID start fresh.
    /// No-op if no session under that ID exists.
    public func clearSession(sessionID: String) {
        #if canImport(MLXLLM)
        sessions.removeValue(forKey: Self.sessionKey(sessionID, .scout))
        sessions.removeValue(forKey: Self.sessionKey(sessionID, .core))
        #endif
    }

    /// Evict every cached session at once. Useful for memory
    /// pressure events (L1 thermal/budget pressure) and for tests.
    public func clearAllSessions() {
        #if canImport(MLXLLM)
        sessions.removeAll()
        #endif
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
