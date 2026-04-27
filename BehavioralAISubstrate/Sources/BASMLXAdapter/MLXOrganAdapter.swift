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

    #if canImport(MLXLLM)
    /// The loaded model container. `nil` until `loadModel(...)` has
    /// completed at least once on this actor instance.
    private var modelContainer: ModelContainer?

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
        for preset: BASOrganPreset
    ) -> GenerateParameters {
        var params = GenerateParameters()
        params.temperature = Float(preset.temperature)
        params.topP = Float(preset.topP)
        return params
    }
    #endif

    public init(
        model: MLXModelCatalog.Entry = MLXModelCatalog.gemma4_E4B_4bit,
        providerID: String? = nil,
        providerName: String? = nil,
        supportsStreaming: Bool = true,
        maxInputTokens: Int = 4_096,
        maxOutputTokens: Int = 4_096,
        supportedRoles: Set<BASOrganRole> = [.scout, .core]
    ) {
        self.model = model
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
        if modelContainer != nil { return }

        let configuration = ModelConfiguration(
            id: model.id,
            extraEOSTokens: Set(model.extraEOSTokens))

        let container = try await #huggingFaceLoadModelContainer(
            configuration: configuration,
            progressHandler: progressHandler)
        self.modelContainer = container
        #else
        throw BASOrganError.providerUnavailable(
            reason:
                "MLXLLM framework unavailable in this build " +
                "(watchOS / non-Apple-Silicon target)")
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
    ///   produced by `MLXLoRATrainer.saveAdapter`. Must match the
    ///   trainer's `Configuration.rank` (default 8).
    public func loadAdapter(from url: URL) async throws {
        #if canImport(MLXLLM)
        guard let container = modelContainer else {
            throw BASOrganError.providerUnavailable(
                reason:
                    "mlx-organ-adapter-not-loaded — call " +
                    "loadModel(...) before loadAdapter(...)")
        }
        // M246 — apply LoRA layers + load adapter weights via the
        // container's perform action so all model mutation runs on
        // the container's executor. Sendable-correct: weights are
        // loaded INSIDE the closure (NestedDictionary<MLXArray>
        // isn't Sendable across actor boundaries).
        let loraParams = LoRAConfiguration.LoRAParameters(
            rank: 8, scale: 10.0, keys: nil)
        let loraConfig = LoRAConfiguration(
            numLayers: 4,
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
            reason:
                "MLXLLM framework unavailable in this build")
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
                reason:
                    "mlx-organ-adapter-not-loaded — call " +
                    "loadModel(progressHandler:) before draft(_:)")
        }

        let session = ChatSession(
            container,
            instructions: Self.systemInstructions(for: request),
            generateParameters: _generateParameters(
                for: request.preset))

        let prompt = Self.prompt(for: request)
        let body = try await session.respond(to: prompt)

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
                for: request, providerID: descriptor.providerID))
        #else
        throw BASOrganError.providerUnavailable(
            reason:
                "MLXLLM framework unavailable in this build " +
                "(watchOS / non-Apple-Silicon target)")
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
