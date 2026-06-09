import Foundation

/// M220 — known-good MLX model identifiers for the Qinao runtime.
/// M236 retired Gemma 3n entries. The CERTIFIED defaults are Gemma 4
/// + Gemma 3 4B (`defaultEntries`); standard-architecture stable
/// fallbacks (Llama 3.2, Qwen2.5) are exposed as host-opt-in
/// `availableAlternatives` (ADR-038) — see those members for the
/// honest cert scope. `allEntries` = both, for SDK pickers.
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

    /// Llama 3.2 3B instruction-tuned, 4-bit. A STANDARD-architecture LLM (no Gemma-3n per-layer-inputs /
    /// altUp / laurel). ADR-038 §11.5 found it does NOT accumulate the variable-shape cache-pool growth that
    /// wedges Gemma-3n (Llama ran 20/20 where Gemma wedged at ~3) — so it is the **stable-architecture
    /// fallback** exposed for hosts that want to avoid the Gemma-3n wedge class entirely. Llama 3 turn
    /// terminator is `<|eot_id|>`. (Available, host opt-in — see `availableAlternatives`; not in the certified
    /// `defaultEntries`.)
    public static let llama3_2_3B_4bit = Entry(
        id: "mlx-community/Llama-3.2-3B-Instruct-4bit",
        providerID: "mlx.llama3_2.3b.it.4bit",
        providerName: "Llama 3.2 3B (MLX, 4-bit)",
        extraEOSTokens: ["<|eot_id|>"])

    /// Qwen2.5 3B instruction-tuned, 4-bit. Another STANDARD-architecture (ChatML) stable fallback alongside
    /// Llama — different vendor/tokenizer, same "no Gemma-3n variable-shape accumulation" property. Qwen uses
    /// the ChatML turn terminator `<|im_end|>`. (Available, host opt-in — see `availableAlternatives`; not yet
    /// on-device certified, so not in `defaultEntries`.)
    public static let qwen2_5_3B_4bit = Entry(
        id: "mlx-community/Qwen2.5-3B-Instruct-4bit",
        providerID: "mlx.qwen2_5.3b.it.4bit",
        providerName: "Qwen2.5 3B (MLX, 4-bit)",
        extraEOSTokens: ["<|im_end|>"])

    /// Llama 3.2 **1B** instruction-tuned, 4-bit — a SMALLER (sub-2B) throughput pick. Decode tok/s scales
    /// inversely with parameter count, so a 1B should decode meaningfully faster than the ~42.6 tok/s
    /// Gemma-3n-E2B baseline (MLX_DECODE_ANATOMY.md) — at a QUALITY cost (fits fast/scout/classify paths, not
    /// core reasoning). Same `<|eot_id|>` Llama-3 terminator. (Available, host opt-in; uncertified.)
    public static let llama3_2_1B_4bit = Entry(
        id: "mlx-community/Llama-3.2-1B-Instruct-4bit",
        providerID: "mlx.llama3_2.1b.it.4bit",
        providerName: "Llama 3.2 1B (MLX, 4-bit)",
        extraEOSTokens: ["<|eot_id|>"])

    /// Qwen2.5 **1.5B** instruction-tuned, 4-bit — the other smaller throughput pick (ChatML `<|im_end|>`).
    /// Same throughput-vs-quality tradeoff as Llama-3.2-1B. (Available, host opt-in; uncertified.)
    public static let qwen2_5_1_5B_4bit = Entry(
        id: "mlx-community/Qwen2.5-1.5B-Instruct-4bit",
        providerID: "mlx.qwen2_5.1_5b.it.4bit",
        providerName: "Qwen2.5 1.5B (MLX, 4-bit)",
        extraEOSTokens: ["<|im_end|>"])

    /// Default Gemma entries, in the order they should appear in UI pickers. Gemma 4 leads (newest +
    /// recommended); Gemma 3 4B trails as the long-context outlier. These are the ON-DEVICE-CERTIFIED picks.
    public static let defaultEntries: [Entry] = [
        gemma4_E4B_4bit,
        gemma4_E2B_4bit,
        gemma3_4B_it_4bit
    ]

    /// **Stable-architecture fallbacks** exposed to the product/SDK face (ADR-038): standard-arch LLMs that
    /// avoid the Gemma-3n variable-shape cache-pool wedge class. **Honest scope (R1 / 亏的不要上):** these are
    /// *available, host opt-in* options — NOT yet on-device certified to the same bar as `defaultEntries`
    /// (Llama: 20/20 in the §11.5 A/B but not a full endurance cert; Qwen: not yet exercised on-device). A host
    /// that hits the Gemma-3n wedge can switch to one of these via the catalog without waiting on the
    /// cache-cap fix. Kept OUT of `defaultEntries` precisely so "default" stays = "certified".
    public static let availableAlternatives: [Entry] = [
        llama3_2_3B_4bit,
        qwen2_5_3B_4bit,
        llama3_2_1B_4bit,
        qwen2_5_1_5B_4bit
    ]

    /// Every selectable entry (certified defaults + opt-in alternatives) for SDK pickers that want to surface
    /// the full set. Order: certified defaults first, then alternatives.
    public static let allEntries: [Entry] = defaultEntries + availableAlternatives
}
