import Foundation
import BASOrgan
import BASMLXAdapter
import BASHostKit   // observe→DISPOSE: BASLLMNeuralCoreService.adjudicating (default-OFF factual-belief wrap)
import BASAppleAdapters   // charter T4: BASMiniLMEmbeddingProvider is edge-injected here
import QinaoLoop

/// M222 — public factory for the Qinao + MLX (downloaded Gemma)
/// host configuration.
///
/// ## Why this exists
///
/// Mirrors `QinaoAppleFoundation.makeAppleFoundationEndpoint(...)`
/// — a one-call helper that wires a Qinao-owned model identity
/// (`QinaoMLXModel`) through `MLXOrganAdapter` into a
/// `QinaoOrganEndpoint`. Hosts wanting downloaded Gemma weights
/// add three lines:
///
/// ```swift
/// import QinaoMLX
/// let endpoint = try await QinaoLoop.makeMLXEndpoint(
///     model: .gemma4E4B,
///     progressHandler: { progress in /* update UI */ })
/// let loop = QinaoLoop(organEndpoint: endpoint)
/// ```
///
/// ## Why a separate library
///
/// Hosts that don't want MLX (Apple FoundationModels-only, or
/// remote-API-only) don't import this target — `QinaoLoop` stays
/// substrate-free, and the heavy `mlx-swift-lm` +
/// `swift-transformers` dep tree only enters consumers that
/// explicitly opt in.
///
/// ## Substrate redaction (護欄 #2 + #3)
///
/// BAS / MLX type names (`MLXOrganAdapter`, `MLXModelCatalog`,
/// `ModelContainer`, `ChatSession`) **never** appear in this
/// file's public API. Only `QinaoMLXModel` (Qinao-owned),
/// `Progress` (Foundation), and `any QinaoOrganEndpoint` cross
/// the seam. `scripts/check_mlx_redaction.sh` enforces this.
public extension QinaoLoop {

    /// One-call factory wiring downloaded MLX Gemma weights behind
    /// a `QinaoOrganEndpoint`.
    ///
    /// First call against a cold cache downloads the model
    /// (~1.4–3 GB depending on `model`); second call hits the
    /// local cache and returns in seconds.
    ///
    /// - Parameters:
    ///   - model: which Gemma variant to load. Default
    ///     `.gemma4E4B` (newest architecture; recommended).
    ///   - progressHandler: receives `Progress` updates during the
    ///     Hugging Face download. Defaults to ignored. Sample-app
    ///     hosts pass a closure that updates a SwiftUI binding so
    ///     the user can see download progress.
    /// - Returns: an opaque endpoint hosts pass to
    ///   `QinaoLoop.init(organEndpoint:)`.
    /// - Throws: any error from the model download or load path —
    ///   network failures, disk-full, corrupted weights, etc.
    static func makeMLXEndpoint(
        model: QinaoMLXModel = .gemma4E4B,
        progressHandler: @Sendable @escaping (Progress) -> Void
            = { _ in }
    ) async throws -> any QinaoOrganEndpoint {
        let entry = model.catalogEntry
        let adapter = MLXOrganAdapter(model: entry)
        try await adapter.loadModel(
            progressHandler: progressHandler)
        let registry = BASOrganRegistry()
        // observe→DISPOSE (Line A): route the live organ through the factual-belief adjudicator. Default-OFF
        // (`BAS_FACTUAL_ADJUDICATE` unset) ⇒ returns `adapter` byte-equal; ON ⇒ the streaming-capable wrapper,
        // so the chat loop's `as? BASStreamingOrganAdapter` probe resolves it and the verdict reaches
        // `streamDraft`. FAIL-OPEN: missing provider/corpus ⇒ `adapter` unchanged.
        let organ = BASLLMNeuralCoreService.adjudicating(
            adapter,
            // charter audit 2026-07-12 T4: edge-injected embedder (LLM-outside cut).
            embeddingProvider: BASMiniLMEmbeddingProvider())
        // Pre-embed the fact bank so the first ON turn doesn't stall before the first token (no-op when OFF).
        await BASLLMNeuralCoreService.prewarmAdjudicator(organ)
        await registry.register(organ)
        return BASOrganRegistryEndpoint(
            registry: registry,
            providerID: organ.descriptor.providerID)
    }

    /// Throughput-first MLX factory.
    ///
    /// This is deliberately a separate entry point from
    /// `makeMLXEndpoint(...)`: the public default stays the
    /// quality-oriented Gemma 4 E4B path, while hosts that want the
    /// fastest certified on-device lane can opt into the Llama
    /// 3.2 3B target with its Llama 3.2 1B speculative draft.
    ///
    /// The endpoint also maps both Qinao roles to the greedy
    /// deterministic preset, because MLX greedy speculative decoding
    /// engages only for `temperature == 0` requests. For routed
    /// `generateCandidates(..., routedBudget:)` calls, pair this
    /// endpoint with `QinaoOrganRoutingPolicy.maxThroughput` so the
    /// routing decision also emits temperature 0.
    ///
    /// `prewarm` defaults to true so the first user-visible turn
    /// avoids paying Metal kernel JIT latency. It increases endpoint
    /// construction time, but not per-turn output bytes.
    static func makeMaxThroughputMLXEndpoint(
        progressHandler: @Sendable @escaping (Progress) -> Void
            = { _ in },
        prewarm: Bool = true
    ) async throws -> any QinaoOrganEndpoint {
        let adapter = MLXOrganAdapter(
            model: QinaoMLXModel.speculativeOptimal.catalogEntry)
        try await adapter.loadModel(progressHandler: progressHandler)
        if prewarm {
            try await adapter.prewarmGreedySpeculative()
        }

        let registry = BASOrganRegistry()
        // observe→DISPOSE (Line A): same default-OFF adjudicator wrap as makeMLXEndpoint. Greedy-speculative
        // byte-identity is unaffected — default-OFF returns the bare adapter, and when ON the verdict changes
        // the prompt anyway (a different, intended input), so the speculative certification still holds.
        let organ = BASLLMNeuralCoreService.adjudicating(
            adapter,
            // charter audit 2026-07-12 T4: edge-injected embedder (LLM-outside cut).
            embeddingProvider: BASMiniLMEmbeddingProvider())
        await BASLLMNeuralCoreService.prewarmAdjudicator(organ)   // no-op when OFF
        await registry.register(organ)
        return BASOrganRegistryEndpoint(
            registry: registry,
            providerID: organ.descriptor.providerID,
            presetForRole: { _ in .greedyDeterministic })
    }

    /// M234 — public factory for the Qinao + MLX LoRA fine-tuning
    /// path. Returns the substrate trainer typed against
    /// `QinaoMLXModel` so callers don't import BASMLXAdapter.
    ///
    /// Hosts wanting on-device LoRA fine-tune `import QinaoMLX` and
    /// drive:
    ///
    /// ```swift
    /// let trainer = QinaoLoop.makeLoRATrainer(
    ///     model: .gemma4E2B,
    ///     configuration: .init(rank: 4, iterations: 20))
    /// try await trainer.loadFoundationModel { progress in /* ui */ }
    /// try await trainer.train(
    ///     trainingCorpus: corpus,
    ///     validationCorpus: validate)
    /// try await trainer.saveAdapter(to: url)
    /// ```
    ///
    /// Substrate redaction keeps `MLXOrganAdapter` /
    /// `MLXModelCatalog` invisible to consumers; the `MLXLoRATrainer`
    /// type is opaque-ish (consumers see it but don't need to name
    /// any vendored MLX type).
    static func makeLoRATrainer(
        model: QinaoMLXModel = .gemma4E2B,
        configuration: MLXLoRATrainer.Configuration =
            MLXLoRATrainer.Configuration()
    ) -> MLXLoRATrainer {
        MLXLoRATrainer(
            model: model.catalogEntry,
            configuration: configuration)
    }
}

/// Qinao-owned model identity. Mirrors the three `mlx-community`
/// 4-bit Gemma variants the substrate ships in
/// `MLXModelCatalog.defaultEntries` without leaking any BAS or MLX
/// type names into Qinao public surface.
///
/// New variants are added here in lockstep with
/// `MLXModelCatalog.Entry`; the `catalogEntry` mapping is the only
/// place BAS-side identifiers live.
public enum QinaoMLXModel: String, Sendable, Equatable,
    CaseIterable, Hashable, Codable, Identifiable
{
    /// Gemma 4 E4B instruction-tuned, 4-bit quantized (M235).
    /// Newest Gemma architecture; same effective ~4B parameter
    /// count as Gemma 3n E4B but with Gemma 4 improvements.
    /// **Recommended default for QinaoSampleApp** (M235).
    case gemma4E4B = "gemma-4-e4b-it-4bit"

    /// Gemma 4 E2B instruction-tuned, 4-bit quantized (M235).
    /// Smallest Gemma 4 variant; same role as Gemma 3n E2B but
    /// newer architecture.
    case gemma4E2B = "gemma-4-e2b-it-4bit"

    /// Gemma 3 4B instruction-tuned, 4-bit quantized. Higher
    /// quality / longer context (128K) variant. ~3 GB on disk.
    case gemma3_4B = "gemma-3-4b-it-4bit"

    // MARK: - availableAlternatives (stable-arch fallbacks — EXPERIMENTAL tier, host opt-in)
    // Mirror `MLXModelCatalog.availableAlternatives` (Llama 3.2 / Qwen2.5). NOT in `defaultEntries`;
    // `certificationTier` reports them "experimental". Distinct EOS tokens (Llama `<|eot_id|>`, Qwen
    // `<|im_end|>`) live in the catalog entries — `catalogEntry` returns those verbatim.

    /// Llama 3.2 3B instruction-tuned, 4-bit (stable transformer-arch fallback).
    case llama3_2_3B = "llama-3.2-3b-it-4bit"
    /// Qwen2.5 3B instruction-tuned, 4-bit.
    case qwen2_5_3B = "qwen2.5-3b-it-4bit"
    /// Llama 3.2 1B instruction-tuned, 4-bit (smallest fallback).
    case llama3_2_1B = "llama-3.2-1b-it-4bit"
    /// Qwen2.5 1.5B instruction-tuned, 4-bit.
    case qwen2_5_1_5B = "qwen2.5-1.5b-it-4bit"

    public var id: String { rawValue }

    /// Human-readable display name suitable for picker UIs.
    public var displayName: String {
        switch self {
        case .gemma4E4B:
            return "Gemma 4 E4B (MLX, 4-bit)"
        case .gemma4E2B:
            return "Gemma 4 E2B (MLX, 4-bit)"
        case .gemma3_4B:
            return "Gemma 3 4B (MLX, 4-bit)"
        case .llama3_2_3B:
            return "Llama 3.2 3B (MLX, 4-bit)"
        case .qwen2_5_3B:
            return "Qwen2.5 3B (MLX, 4-bit)"
        case .llama3_2_1B:
            return "Llama 3.2 1B (MLX, 4-bit)"
        case .qwen2_5_1_5B:
            return "Qwen2.5 1.5B (MLX, 4-bit)"
        }
    }

    /// Stable provider identity reported through draft / candidate
    /// trace records. Independent of `displayName` so renaming one
    /// doesn't break the other.
    public var providerID: String {
        catalogEntry.providerID
    }

    /// Internal mapping back to the substrate's catalog entry.
    /// `internal` access — Qinao's public surface never exposes
    /// `MLXModelCatalog`.
    var catalogEntry: MLXModelCatalog.Entry {
        switch self {
        case .gemma4E4B:
            return MLXModelCatalog.gemma4_E4B_4bit
        case .gemma4E2B:
            return MLXModelCatalog.gemma4_E2B_4bit
        case .gemma3_4B:
            return MLXModelCatalog.gemma3_4B_it_4bit
        case .llama3_2_3B:
            return MLXModelCatalog.llama3_2_3B_4bit
        case .qwen2_5_3B:
            return MLXModelCatalog.qwen2_5_3B_4bit
        case .llama3_2_1B:
            return MLXModelCatalog.llama3_2_1B_4bit
        case .qwen2_5_1_5B:
            return MLXModelCatalog.qwen2_5_1_5B_4bit
        }
    }

    /// Advisory certification tier for UI / audit labeling — `"certified"` for the on-device-certified default
    /// Gemma entries, `"experimental"` for the `availableAlternatives` (Llama/Qwen). Computed from the live
    /// catalog so it can never drift. A `String` (not a BAS enum) to keep the substrate-redaction seam clean.
    public var certificationTier: String {
        MLXModelCatalog.defaultEntries.contains { $0.providerID == catalogEntry.providerID }
            ? "certified" : "experimental"
    }

    /// 结构大重构 — Phase 3: the recommended same-family DRAFT model for SPECULATIVE DECODING with this model as
    /// the target, or nil if this model has no curated pairing (e.g. Gemma 3 4B, which has no same-tokenizer
    /// sibling). Speculative decoding co-residents a smaller same-family draft that proposes tokens the target
    /// verifies — a latency lever. Surfaced through the Qinao facade so a host can elect a pair WITHOUT touching
    /// `MLXModelCatalog` (the BAS identifiers stay behind `catalogEntry`).
    public var speculativeDraft: QinaoMLXModel? {
        guard let draft = MLXModelCatalog.recommendedDraft(
            forTargetProviderID: catalogEntry.providerID) else { return nil }
        return QinaoMLXModel.allCases.first {
            $0.catalogEntry.providerID == draft.providerID
        }
    }

    /// Whether this model can be a speculative-decoding TARGET (has a curated same-family draft). Honest scope:
    /// availability ≠ certification — see `speculativeOptimal` for the one pairing that IS certified.
    public var supportsSpeculativeDecoding: Bool { speculativeDraft != nil }

    /// The SPECULATION-OPTIMAL pick: greedy speculative decoding on this model is ON-DEVICE CERTIFIED `enable`
    /// (Llama-3.2 3B↔1B — bytewise-correct, ~31% faster, fits the default memory cap; 2 devices, n=100). The
    /// quality default (`gemma4E4B`) is unchanged — its pair does not fit 8 GB, so speculation stays dormant
    /// there. A latency-prioritizing host picks THIS model and the certified fast lane engages automatically.
    public static var speculativeOptimal: QinaoMLXModel { .llama3_2_3B }
}
