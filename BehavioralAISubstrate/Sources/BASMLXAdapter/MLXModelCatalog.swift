import Foundation

/// M220 — known-good MLX model identifiers for the Qinao runtime.
/// M236 retired Gemma 3n entries; the catalog is now Gemma 4 +
/// Gemma 3 4B only.
///
/// Entries point at the `mlx-community` Hugging Face org's
/// quantized variants. `id` is a HuggingFace repo path; the actual
/// download is handled in M221 by `MLXOrganAdapter.loadModel(...)`
/// via a `Hub.HubApi`.
///
/// Three 4-bit instruction-tuned text-only models, suitable for
/// on-device chat:
///
/// - `gemma4_E4B_4bit` — Gemma 4 E4B, the **recommended default**.
///   Newest architecture; ~4B effective parameter count. Note the
///   turn terminator is `<turn|>` (not `<end_of_turn>`).
/// - `gemma4_E2B_4bit` — Gemma 4 E2B, the smallest variant.
///   Pick for iPhone / Watch / tight-memory targets.
/// - `gemma3_4B_it_4bit` — Gemma 3 4B, the long-context (128K)
///   pick. ~3 GB on disk, ~5 GB resident. Different terminator
///   (`<end_of_turn>`) and different architecture from Gemma 4 —
///   keep this entry only if you specifically need long context.
///
/// The struct is `Sendable` value-type so hosts can store it in
/// snapshots or audit ledgers without ownership concerns.
public struct MLXModelCatalog: Sendable, Equatable {

    public struct Entry: Sendable, Equatable, Hashable, Codable {
        /// Hugging Face repository identifier
        /// (e.g. `mlx-community/gemma-4-e4b-it-4bit`).
        public let id: String

        /// Stable adapter identity reported through
        /// `BASOrganDescriptor.providerID`. Carries the model name
        /// so audit logs can answer "which on-device model
        /// produced this body?" without ambiguity.
        public let providerID: String

        /// Human-readable display name, surfaced in UI and audit
        /// summaries. Independent of `providerID` so renaming one
        /// doesn't break the other.
        public let providerName: String

        /// Extra end-of-sequence tokens the tokenizer should treat
        /// as turn terminators. Gemma 4 uses `<turn|>`; Gemma 3 4B
        /// uses `<end_of_turn>`. Without these generation runs
        /// past the reply boundary.
        public let extraEOSTokens: [String]

        public init(
            id: String,
            providerID: String,
            providerName: String,
            extraEOSTokens: [String]
        ) {
            self.id = id
            self.providerID = providerID
            self.providerName = providerName
            self.extraEOSTokens = extraEOSTokens
        }
    }

    /// Gemma 4 E4B instruction-tuned, 4-bit quantized.
    /// **Recommended default for QinaoSampleApp.**
    public static let gemma4_E4B_4bit = Entry(
        id: "mlx-community/gemma-4-e4b-it-4bit",
        providerID: "mlx.gemma4.e4b.it.4bit",
        providerName: "Gemma 4 E4B (MLX, 4-bit)",
        extraEOSTokens: ["<turn|>"])

    /// Gemma 4 E2B instruction-tuned, 4-bit quantized. Smallest
    /// Gemma 4 variant; pick for iPhone / Watch / tight-memory.
    public static let gemma4_E2B_4bit = Entry(
        id: "mlx-community/gemma-4-e2b-it-4bit",
        providerID: "mlx.gemma4.e2b.it.4bit",
        providerName: "Gemma 4 E2B (MLX, 4-bit)",
        extraEOSTokens: ["<turn|>"])

    /// Gemma 3 4B instruction-tuned, 4-bit quantized. Different
    /// architecture from Gemma 4; kept for long-context (128K)
    /// hosts that have specific use for that property.
    public static let gemma3_4B_it_4bit = Entry(
        id: "mlx-community/gemma-3-4b-it-4bit",
        providerID: "mlx.gemma3.4b.it.4bit",
        providerName: "Gemma 3 4B (MLX, 4-bit)",
        extraEOSTokens: ["<end_of_turn>"])

    /// Llama 3.2 3B instruction-tuned, 4-bit. ADR-038 §11.5 — a STANDARD-architecture LLM (no Gemma-3n
    /// per-layer-inputs / altUp / laurel), used to test whether the on-device decode wedge is Gemma-3n-
    /// specific (Llama doesn't wedge → confirmed Gemma-3n) or a general MLX issue (Llama also wedges).
    /// Llama 3 turn terminator is `<|eot_id|>`.
    public static let llama3_2_3B_4bit = Entry(
        id: "mlx-community/Llama-3.2-3B-Instruct-4bit",
        providerID: "mlx.llama3_2.3b.it.4bit",
        providerName: "Llama 3.2 3B (MLX, 4-bit)",
        extraEOSTokens: ["<|eot_id|>"])

    /// Default Gemma entries, in the order they should appear in
    /// UI pickers. Gemma 4 leads (newest + recommended); Gemma 3
    /// 4B trails as the long-context outlier.
    public static let defaultEntries: [Entry] = [
        gemma4_E4B_4bit,
        gemma4_E2B_4bit,
        gemma3_4B_it_4bit
    ]
}
