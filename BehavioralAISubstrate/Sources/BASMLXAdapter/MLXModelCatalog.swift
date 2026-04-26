import Foundation

/// M220 — known-good MLX model identifiers for the Qinao runtime.
///
/// Entries point at the `mlx-community` Hugging Face org's
/// quantized variants. `id` is a HuggingFace repo path; the actual
/// download is handled in M221 by `MLXOrganAdapter.loadModel(...)`
/// via a `Hub.HubApi`.
///
/// All three entries are 4-bit instruction-tuned text-only models,
/// suitable for on-device chat:
///
/// - `gemma3_4B_it_4bit` — Gemma 3 4B, the higher-quality "long
///   context / standard transformer" pick. ~3 GB on disk, ~5 GB
///   resident under inference.
/// - `gemma3n_E4B_4bit` — Gemma 3n E4B, MatFormer architecture
///   designed for on-device. Same effective parameter count as
///   Gemma 3 4B but lower runtime memory and faster generation.
///   Recommended default for QinaoSampleApp on macOS / iOS.
/// - `gemma3n_E2B_4bit` — Gemma 3n E2B, the smallest variant.
///   ~1.4 GB on disk, ~2 GB resident. Pick for Watch / iPhone with
///   tight memory budgets.
///
/// The struct is `Sendable` value-type so hosts can store it in
/// snapshots or audit ledgers without ownership concerns. New
/// entries should be added with explicit `extraEOSTokens` (Gemma
/// terminates turns with `<end_of_turn>`).
public struct MLXModelCatalog: Sendable, Equatable {

    public struct Entry: Sendable, Equatable, Hashable {
        /// Hugging Face repository identifier
        /// (e.g. `mlx-community/gemma-3-4b-it-4bit`).
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
        /// as turn terminators. Gemma 3 / 3n require
        /// `<end_of_turn>`; without it generation runs past the
        /// reply.
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

    /// Gemma 3 4B instruction-tuned, 4-bit quantized.
    public static let gemma3_4B_it_4bit = Entry(
        id: "mlx-community/gemma-3-4b-it-4bit",
        providerID: "mlx.gemma3.4b.it.4bit",
        providerName: "Gemma 3 4B (MLX, 4-bit)",
        extraEOSTokens: ["<end_of_turn>"])

    /// Gemma 3n E4B instruction-tuned, 4-bit quantized. Default
    /// pick for QinaoSampleApp.
    public static let gemma3n_E4B_4bit = Entry(
        id: "mlx-community/gemma-3n-E4B-it-lm-4bit",
        providerID: "mlx.gemma3n.e4b.it.4bit",
        providerName: "Gemma 3n E4B (MLX, 4-bit)",
        extraEOSTokens: ["<end_of_turn>"])

    /// Gemma 3n E2B instruction-tuned, 4-bit quantized.
    public static let gemma3n_E2B_4bit = Entry(
        id: "mlx-community/gemma-3n-E2B-it-lm-4bit",
        providerID: "mlx.gemma3n.e2b.it.4bit",
        providerName: "Gemma 3n E2B (MLX, 4-bit)",
        extraEOSTokens: ["<end_of_turn>"])

    /// Gemma 4 E4B instruction-tuned, 4-bit quantized (M235).
    /// Newer than Gemma 3n E4B; same effective parameter count
    /// (~4B) but with Gemma 4 architecture improvements. Note the
    /// turn terminator is `<turn|>` (not `<end_of_turn>`) — without
    /// it Gemma 4 generation runs past the reply.
    public static let gemma4_E4B_4bit = Entry(
        id: "mlx-community/gemma-4-e4b-it-4bit",
        providerID: "mlx.gemma4.e4b.it.4bit",
        providerName: "Gemma 4 E4B (MLX, 4-bit)",
        extraEOSTokens: ["<turn|>"])

    /// Gemma 4 E2B instruction-tuned, 4-bit quantized (M235).
    /// Smallest Gemma 4 variant; pairs with Gemma 3n E2B as the
    /// "tight memory" pick. Same `<turn|>` terminator.
    public static let gemma4_E2B_4bit = Entry(
        id: "mlx-community/gemma-4-e2b-it-4bit",
        providerID: "mlx.gemma4.e2b.it.4bit",
        providerName: "Gemma 4 E2B (MLX, 4-bit)",
        extraEOSTokens: ["<turn|>"])

    /// Default Gemma entries, in the order they should appear in
    /// UI pickers. M235 adds Gemma 4 E4B/E2B at the front (newer
    /// architecture, recommended where available).
    public static let defaultEntries: [Entry] = [
        gemma4_E4B_4bit,
        gemma4_E2B_4bit,
        gemma3n_E4B_4bit,
        gemma3_4B_it_4bit,
        gemma3n_E2B_4bit
    ]
}
