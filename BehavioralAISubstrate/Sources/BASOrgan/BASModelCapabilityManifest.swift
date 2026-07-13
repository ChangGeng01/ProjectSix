import Foundation

/// Execution-path orchestrator (2026-07-13 charter) — the TYPED model-capability manifest.
///
/// The census found model capability scattered as string checks and filesystem probes:
/// MTP-head availability was `model.id.lowercased().contains("qwen3.5")` (MLXOrganAdapter:163),
/// the draft sibling lived only in `MLXModelCatalog.speculativePairings`, the architecture class
/// (GDN vs trimmable-attention) was an implicit `as?`-cast at decode time, and the resident
/// footprint was a lookup that fell back to a 2 GiB guess. An orchestrator that elects a Pareto
/// load/prefill/cache/decode plan cannot reason over string checks — it needs the model's facts
/// as DATA. This is that data: pure, `Sendable`, host-testable, no MLX import.
///
/// Doctrine: this manifest is DESCRIPTIVE (what the model IS), never prescriptive (what to run) —
/// the elector composes it with the device profile + runtime state. Adding a model is a data edit
/// here, not a new `contains(...)` branch scattered across the adapter.
public struct BASModelCapabilityManifest: Sendable, Equatable, Hashable, Codable {

    /// The attention/state architecture class — decides which rollback mechanism a spec lane needs.
    public enum Architecture: String, Sendable, Equatable, Hashable, Codable {
        /// Full/sliding attention with a trim-rewindable KV cache (Llama, Gemma). Prompt-lookup's
        /// stock `trimPromptCache` rewind is sound here.
        case trimmableAttention
        /// Gated-DeltaNet / Mamba hybrid: recurrent `ArraysCache` layers that CANNOT be trim-rewound
        /// (Qwen3.5). Spec lanes must use snapshot-restore (BASTrunkCheckpoint) + carry-forward.
        case gdnHybrid
    }

    /// The self-drafting acceleration a model carries, as a typed fact (not a filename probe).
    public enum DraftMechanism: Sendable, Equatable, Hashable, Codable {
        /// No self-draft; only model-free (prompt-lookup / cross-turn) speculation applies.
        case none
        /// A folded multi-token-prediction head resides alongside the model (Qwen3.5's
        /// `qwen35_mtp_folded.safetensors`) — the `.mtpSpec` lane's drafter.
        case mtpHead(weightsBasename: String)
        /// A separate smaller draft model of the SAME vocabulary (Llama-3B ← Llama-1B).
        case draftSibling(modelID: String)
    }

    /// Stable model identity (matches `MLXModelCatalog.Entry.id`).
    public let modelID: String
    public let architecture: Architecture
    public let draft: DraftMechanism
    /// Quantization width of the resident weights (4 / 3 / 8 / 16).
    public let quantBits: Int
    /// Measured/estimated resident footprint of the loaded model, in bytes. Load-plan admission and
    /// dual-residency election read this against the device jetsam budget.
    public let residentBytesEstimate: Int
    /// Maximum context the model was converted for (tokens); prefill/cache election reads it.
    public let contextCapTokens: Int

    public init(
        modelID: String,
        architecture: Architecture,
        draft: DraftMechanism,
        quantBits: Int,
        residentBytesEstimate: Int,
        contextCapTokens: Int
    ) {
        self.modelID = modelID
        self.architecture = architecture
        self.draft = draft
        self.quantBits = quantBits
        self.residentBytesEstimate = residentBytesEstimate
        self.contextCapTokens = contextCapTokens
    }

    /// Whether the model carries a folded MTP head — the typed replacement for the
    /// `model.id.contains("qwen3.5")` check. (The adapter still filesystem-resolves the actual
    /// weights URL; this states only that the model is a CANDIDATE, which the string check conflated
    /// with the architecture.)
    public var carriesMTPHead: Bool {
        if case .mtpHead = draft { return true }
        return false
    }

    /// Whether a spec lane on this model must use snapshot-restore rollback rather than KV-trim.
    public var requiresSnapshotRollback: Bool { architecture == .gdnHybrid }
}

/// The seeded manifest set — one entry per model the substrate ships/stages, filled from the
/// census's MEASURED facts. This is the single place a new model's capabilities are declared.
public enum BASModelManifestRegistry {

    /// Qwen3.5-4B-4bit — the chartered production default. GDN hybrid (linear DeltaNet + full-attn
    /// interval-4), carries the folded MTP head, ~3114 MB resident (device-measured phys_footprint,
    /// BASQwen35MTPProbe SUSTAIN 2026-07-13), 256k context.
    public static let qwen35_4B_4bit = BASModelCapabilityManifest(
        modelID: "mlx-community/Qwen3.5-4B-4bit",
        architecture: .gdnHybrid,
        draft: .mtpHead(weightsBasename: "qwen35_mtp_folded.safetensors"),
        quantBits: 4,
        residentBytesEstimate: 3_114 * 1_048_576,
        contextCapTokens: 262_144)

    /// Llama-3.2-3B-Instruct-4bit — trimmable attention, its draft sibling is the 1B (same vocab).
    public static let llama32_3B_4bit = BASModelCapabilityManifest(
        modelID: "mlx-community/Llama-3.2-3B-Instruct-4bit",
        architecture: .trimmableAttention,
        draft: .draftSibling(modelID: "mlx-community/Llama-3.2-1B-Instruct-4bit"),
        quantBits: 4,
        residentBytesEstimate: 2_542 * 1_048_576,
        contextCapTokens: 131_072)

    /// Gemma-4-E4B-4bit — sliding/trimmable attention (window-masked verify), no self-draft
    /// (E2B is the E4B draft; single-model here → prompt-lookup is its one decode accelerator).
    public static let gemma4_E4B_4bit = BASModelCapabilityManifest(
        modelID: "mlx-community/gemma-4-e4b-it-4bit",
        architecture: .trimmableAttention,
        draft: .none,
        quantBits: 4,
        residentBytesEstimate: 2_593 * 1_048_576,
        contextCapTokens: 131_072)

    private static let byID: [String: BASModelCapabilityManifest] = [
        qwen35_4B_4bit.modelID: qwen35_4B_4bit,
        llama32_3B_4bit.modelID: llama32_3B_4bit,
        gemma4_E4B_4bit.modelID: gemma4_E4B_4bit,
    ]

    /// The chartered production default (2026-07-13): Qwen3.5-4B-4bit.
    public static let productionDefault = qwen35_4B_4bit

    /// Resolve a manifest by exact model id, or nil if the model is unknown to the registry.
    /// A nil result is the orchestrator's signal to run the CONSERVATIVE plan (no self-draft
    /// election, plain decode) rather than guess — never fail open on an unmanifested model.
    public static func manifest(forModelID id: String) -> BASModelCapabilityManifest? {
        byID[id]
    }
}
