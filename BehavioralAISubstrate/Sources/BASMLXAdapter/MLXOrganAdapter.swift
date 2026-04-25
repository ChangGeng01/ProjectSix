import Foundation
import BASRuntimeCore
import BASOrgan
#if canImport(MLXLLM)
import MLXLLM
import MLXLMCommon
#endif

/// M220 — MLX organ adapter (Apple Silicon, on-device, downloaded
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
/// `MLXOrganAdapter` is the M220 scaffolding layer — it ships the
/// `BASOrganAdapter` conformance, the descriptor, and the model
/// catalog so downstream layers (QinaoMLX façade, sample-app
/// picker) have stable types to compile against. The real model
/// download + inference path is wired in M221 once the dep tree is
/// proven stable.
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
/// ## M220 vs M221 boundary
///
/// **M220 (this file)** — descriptor, capacity reporting,
/// `BASOrganAdapter` conformance compiled clean against
/// `mlx-swift-lm` + `swift-transformers`. `draft(_:)` throws
/// `BASOrganError.providerUnavailable("mlx-not-loaded-yet")` because
/// no model has been wired in. Honest: capacity reasonCode says
/// `MLX_NOT_LOADED_M221`.
///
/// **M221 (next)** — real `loadModel(...)` async method; once a
/// model is loaded, `draft(_:)` runs `ChatSession.respond(to:)` and
/// returns a real `BASOrganDraft`. Streaming via `+Streaming.swift`.
public actor MLXOrganAdapter: BASOrganAdapter {
    public nonisolated let descriptor: BASOrganDescriptor

    /// The model the host wants this adapter to serve. Carried as
    /// metadata in M220; M221 uses it to drive `loadModel(...)`.
    public nonisolated let model: MLXModelCatalog.Entry

    public init(
        model: MLXModelCatalog.Entry = MLXModelCatalog.gemma3n_E4B_4bit,
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

    public func draft(
        _ request: BASOrganRequest
    ) async throws -> BASOrganDraft {
        guard descriptor.supportedRoles.contains(request.role) else {
            throw BASOrganError.unsupportedRole(request.role)
        }

        #if canImport(MLXLLM)
        // M221 will wire `ChatSession.respond(to:)` here. Until
        // then, draft() honestly reports unavailable so audit
        // trails can't accidentally show "MLX produced X" before
        // we actually run a model.
        throw BASOrganError.providerUnavailable(
            reason:
                "mlx-organ-adapter-not-loaded-yet (M221 will " +
                "wire ChatSession.respond from a loaded " +
                "ModelContainer; M220 ships the dep tree + " +
                "BASOrganAdapter conformance only)")
        #else
        throw BASOrganError.providerUnavailable(
            reason:
                "MLXLLM framework unavailable in this build " +
                "(watchOS / non-Apple-Silicon target)")
        #endif
    }

    public func currentCapacity() async -> BASOrganCapacity {
        #if canImport(MLXLLM)
        return BASOrganCapacity(
            availableInputTokens: 0,
            availableOutputTokens: 0,
            underPressure: true,
            reasonCodes: ["MLX_NOT_LOADED_M221"])
        #else
        return BASOrganCapacity(
            availableInputTokens: 0,
            availableOutputTokens: 0,
            underPressure: true,
            reasonCodes: ["MLX_UNAVAILABLE_BUILD"])
        #endif
    }
}
