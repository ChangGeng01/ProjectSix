import Foundation
import BASOrgan
import BASMLXAdapter
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
///     model: .gemma3nE4B,
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
    ///     `.gemma3nE4B` (best balance of quality + memory + speed
    ///     on Apple Silicon).
    ///   - progressHandler: receives `Progress` updates during the
    ///     Hugging Face download. Defaults to ignored. Sample-app
    ///     hosts pass a closure that updates a SwiftUI binding so
    ///     the user can see download progress.
    /// - Returns: an opaque endpoint hosts pass to
    ///   `QinaoLoop.init(organEndpoint:)`.
    /// - Throws: any error from the model download or load path —
    ///   network failures, disk-full, corrupted weights, etc.
    static func makeMLXEndpoint(
        model: QinaoMLXModel = .gemma3nE4B,
        progressHandler: @Sendable @escaping (Progress) -> Void
            = { _ in }
    ) async throws -> any QinaoOrganEndpoint {
        let entry = model.catalogEntry
        let adapter = MLXOrganAdapter(model: entry)
        try await adapter.loadModel(
            progressHandler: progressHandler)
        let registry = BASOrganRegistry()
        await registry.register(adapter)
        return BASOrganRegistryEndpoint(registry: registry)
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
    ///     model: .gemma3nE2B,
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
        model: QinaoMLXModel = .gemma3nE2B,
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

    /// Gemma 3n E4B instruction-tuned, 4-bit quantized. MatFormer
    /// architecture; same effective parameter count as Gemma 3 4B
    /// but lower runtime memory and faster generation. Pre-M235
    /// default; kept for hosts that have weights cached locally.
    case gemma3nE4B = "gemma-3n-E4B-it-lm-4bit"

    /// Gemma 3n E2B instruction-tuned, 4-bit quantized. Smallest
    /// pre-Gemma-4 variant; ~1.4 GB on disk. Pick for Watch /
    /// iPhone with tight memory budgets.
    case gemma3nE2B = "gemma-3n-E2B-it-lm-4bit"

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
        case .gemma3nE4B:
            return "Gemma 3n E4B (MLX, 4-bit)"
        case .gemma3nE2B:
            return "Gemma 3n E2B (MLX, 4-bit)"
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
        case .gemma3nE4B:
            return MLXModelCatalog.gemma3n_E4B_4bit
        case .gemma3nE2B:
            return MLXModelCatalog.gemma3n_E2B_4bit
        }
    }
}
