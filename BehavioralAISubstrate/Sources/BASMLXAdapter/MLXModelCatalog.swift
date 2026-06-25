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

        /// Tranche C (2026-06-12) — OPTIONAL local-directory model:
        /// a Documents-relative directory name holding an MLX model
        /// (config.json + *.safetensors + tokenizer), staged via
        /// `devicectl device copy to`。 When non-nil, `loadModel`
        /// uses `ModelConfiguration(directory:)` (no HF download) —
        /// the lane for locally-quantized variants (e.g. the 3-bit
        /// decode-bandwidth A/B) that mlx-community doesn't publish。
        /// nil (default) = the HF `id` download path, byte-equal。
        public let localDirectoryName: String?

        public init(
            id: String,
            providerID: String,
            providerName: String,
            extraEOSTokens: [String],
            localDirectoryName: String? = nil
        ) {
            self.id = id
            self.providerID = providerID
            self.providerName = providerName
            self.extraEOSTokens = extraEOSTokens
            self.localDirectoryName = localDirectoryName
        }
    }

    /// Gemma 4 E4B instruction-tuned, 4-bit quantized.
    /// **Recommended default for QinaoSampleApp.**
    public static let gemma4_E4B_4bit = Entry(
        id: "mlx-community/gemma-4-e4b-it-4bit",
        providerID: "mlx.gemma4.e4b.it.4bit",
        providerName: "Gemma 4 E4B (MLX, 4-bit)",
        extraEOSTokens: ["<turn|>"])

    /// Gemma 4 E4B **4-bit LOCAL** (Mac-downloaded + staged via devicectl, bypasses the iPhone-WiFi
    /// HF download which dropped 3x on a 2.7GB pull). Loads from Documents/<localDirectoryName>/.
    public static let gemma4_E4B_4bit_local = Entry(
        id: "local/gemma-4-e4b-it-4bit",
        providerID: "mlx.gemma4.e4b.it.4bit.local",
        providerName: "Gemma 4 E4B (MLX, 4-bit local)",
        extraEOSTokens: ["<turn|>"],
        localDirectoryName: "models/gemma-4-e4b-it-4bit")

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

    /// Qwen2.5 **7B** instruction-tuned, 4-bit (~4.3 GB). The MODEL-AXIS lever for the cross-turn UDL: a LARGER
    /// full-attention (batch-invariant → strict byte-identical) model whose slower per-token decode AMORTIZES the
    /// fixed per-round n-gram-scan overhead — so the cross-turn ratio rises toward the ideal accepted-length and the
    /// free-form control penalty shrinks toward neutral, with a bigger absolute tok/s win. Memory-marginal on the 8 GB
    /// A19 (bigger than E4B's ~2.7 GB) — needs the increased-memory entitlement; may jetsam. ChatML `<|im_end|>`.
    public static let qwen2_5_7B_4bit = Entry(
        id: "mlx-community/Qwen2.5-7B-Instruct-4bit",
        providerID: "mlx.qwen2_5.7b.it.4bit",
        providerName: "Qwen2.5 7B (MLX, 4-bit)",
        extraEOSTokens: ["<|im_end|>"])

    /// Qwen3.5 **4B** 4-bit — the on-device base for the **v12 honesty adapter** (WiSE-FT λ=0.6 =
    /// the `wiseft_v9_lam60` LoRA at scale 12, applied LIVE on top of this 4-bit base via the
    /// `loadAdapter` QLoRALinear path — NEVER a sub-8-bit merge, which destroys the anti-syco signal).
    /// HYBRID architecture (GatedDeltaNet linear-attn + periodic full-attention), routed text-only
    /// through MLXLLM's already-registered `qwen3_5`/`qwen3_5_text` factory (the multimodal vision tower
    /// is stripped by `Qwen35Model.sanitize`). ChatML `<|im_end|>`. Load the v12 adapter via
    /// `loadAdapter(from:, configuration: .init(rank: 4, scale: 12.0), numLayers: 16)`.
    /// MEMORY: a 4B GDN + MambaCache on the 8 GB A19 is UNVALIDATED — host dry-run first; watch jetsam.
    /// (Available, host opt-in; not yet on-device certified, so not in `defaultEntries`.)
    public static let qwen3_5_4B_4bit = Entry(
        id: "mlx-community/Qwen3.5-4B-4bit",
        providerID: "mlx.qwen3_5.4b.4bit",
        providerName: "Qwen3.5 4B (MLX, 4-bit) — v12 honesty base",
        extraEOSTokens: ["<|im_end|>"])

    /// Qwen3.5 4B 4-bit **LOCAL** — the device ship form for v12 honesty. Mac-downloaded (~2.9 GB) + staged via
    /// `devicectl device copy` into `Documents/models/Qwen3.5-4B-4bit/`, loaded with `ModelConfiguration(directory:)`
    /// (no on-device HF download — that drops for >2 GB pulls on iPhone-WiFi, same reason as the Gemma/Llama
    /// local entries). The v12 adapter is staged alongside + applied via
    /// `loadAdapter(…, .init(rank: 4, scale: 12.0), numLayers: 16)`. GDN ⇒ generate via STREAMING with
    /// `setDecodePlannerAutoSelect(false)` (eager prompt-lookup lanes fail-close on the non-trimmable MambaCache).
    public static let qwen3_5_4B_4bit_local = Entry(
        id: "local/Qwen3.5-4B-4bit",
        providerID: "mlx.qwen3_5.4b.4bit.local",
        providerName: "Qwen3.5 4B (MLX, 4-bit local) — v12 honesty base",
        extraEOSTokens: ["<|im_end|>"],
        localDirectoryName: "models/Qwen3.5-4B-4bit")

    /// Llama 3.2 **1B** instruction-tuned, 4-bit — a SMALLER (sub-2B) throughput pick. Decode tok/s scales
    /// inversely with parameter count, so a 1B should decode meaningfully faster than the ~42.6 tok/s
    /// Gemma-3n-E2B baseline (MLX_DECODE_ANATOMY.md) — at a QUALITY cost (fits fast/scout/classify paths, not
    /// core reasoning). Same `<|eot_id|>` Llama-3 terminator. (Available, host opt-in; uncertified.)
    public static let llama3_2_1B_4bit = Entry(
        id: "mlx-community/Llama-3.2-1B-Instruct-4bit",
        providerID: "mlx.llama3_2.1b.it.4bit",
        providerName: "Llama 3.2 1B (MLX, 4-bit)",
        extraEOSTokens: ["<|eot_id|>"])

    /// Llama-3.2-1B 4-bit LOCAL-staged (Mac-download + devicectl push) — the reliable spec-draft for on-device probes
    /// when the HF cache is evicted / iPhone-WiFi download fails (Gate-2b re-measure hit `specActive=false` because
    /// the HF-id 1B would not load). Same weights as `llama3_2_1B_4bit`; loads from Documents/<localDirectoryName>.
    public static let llama3_2_1B_4bit_local = Entry(
        id: "local/Llama-3.2-1B-Instruct-4bit",
        providerID: "mlx.llama3_2.1b.it.4bit.local",
        providerName: "Llama 3.2 1B (MLX, 4-bit local)",
        extraEOSTokens: ["<|eot_id|>"],
        localDirectoryName: "models/Llama-3.2-1B-Instruct-4bit")

    /// Qwen2.5 **1.5B** instruction-tuned, 4-bit — the other smaller throughput pick (ChatML `<|im_end|>`).
    /// Same throughput-vs-quality tradeoff as Llama-3.2-1B. (Available, host opt-in; uncertified.)
    public static let qwen2_5_1_5B_4bit = Entry(
        id: "mlx-community/Qwen2.5-1.5B-Instruct-4bit",
        providerID: "mlx.qwen2_5.1_5b.it.4bit",
        providerName: "Qwen2.5 1.5B (MLX, 4-bit)",
        extraEOSTokens: ["<|im_end|>"])

    /// Tranche C (2026-06-12) — Llama 3.2 3B **3-bit** LOCAL variant for the decode-bandwidth A/B.
    /// Decode is bandwidth-bound qmv GEMV (every token reads all weights), so 3-bit reads ~25% fewer
    /// bytes than 4-bit through the same kernel — the device A/B (tok/s + memory + HUMAN-READ quality)
    /// decides whether the quality holds (3-bit degradation is the known risk; the quality gate is
    /// independent). mlx-community publishes no 3B-class 3-bit, so this is locally quantized
    /// (`mlx_lm convert --hf-path mlx-community/Llama-3.2-3B-Instruct-bf16 -q --q-bits 3
    /// --q-group-size 64`) and STAGED to the app's Documents/<localDirectoryName>/ via
    /// `devicectl device copy to`. Loads from the local directory — no HF download. Uncertified;
    /// A/B-only until the quality gate passes (亏的不要).
    public static let llama3_2_3B_3bit_local = Entry(
        id: "local/Llama-3.2-3B-Instruct-3bit",
        providerID: "mlx.llama3_2.3b.it.3bit.local",
        providerName: "Llama 3.2 3B (MLX, 3-bit local)",
        extraEOSTokens: ["<|eot_id|>"],
        localDirectoryName: "models/Llama-3.2-3B-Instruct-3bit")

    /// Llama-3.2-3B MIXED-PRECISION (mlx_lm `mixed_3_4`: 3-bit base + 4-bit on the sensitive layers — early/late
    /// blocks, v_proj / down_proj, lm_head; 3.624 bpw, ~1.4GB vs ~1.9GB for 4-bit). The bandwidth-lever follow-up
    /// after naive 3-bit DECLINED (quality崩) and the CoreAI/LiteRT kernel levers were exhausted/blocked. Loads via
    /// MLX-swift's `perLayerQuantization` (config carries 197 per-layer overrides). Local-staged like the 3-bit entry.
    public static let llama3_2_3B_mixed34_local = Entry(
        id: "local/Llama-3.2-3B-Instruct-mixed34",
        providerID: "mlx.llama3_2.3b.it.mixed34.local",
        providerName: "Llama 3.2 3B (MLX, mixed 3/4-bit local)",
        extraEOSTokens: ["<|eot_id|>"],
        localDirectoryName: "models/Llama-3.2-3B-Instruct-mixed34")

    /// Llama-3.2-3B MIXED v2 (audit-driven): spare `embed_tokens` + ALL attention (q/k/v/o) + tied `lm_head` at 4-bit,
    /// FFN (gate/up/down) at 3-bit (3.843 bpw, ~1.5GB vs ~1.9GB 4-bit). The `mixed_3_4` recipe left `embed_tokens` at
    /// 3-bit → embedding corruption = the system-prompt LEAK (audit catch); this protects it. Tests whether a
    /// quality-preserving sub-4-bit bandwidth win exists. Loads via MLX-swift `perLayerQuantization`.
    public static let llama3_2_3B_mixed_attn4_local = Entry(
        id: "local/Llama-3.2-3B-Instruct-mixed-attn4",
        providerID: "mlx.llama3_2.3b.it.mixed_attn4.local",
        providerName: "Llama 3.2 3B (MLX, mixed embed+attn 4-bit / FFN 3-bit local)",
        extraEOSTokens: ["<|eot_id|>"],
        localDirectoryName: "models/Llama-3.2-3B-Instruct-mixed-attn4")

    /// Llama-3.2-3B MXFP4 (MX block float, group 32, q_mode=mxfp4; 4.251 bpw, 1.6GB). Audit "weakens" item: does the
    /// MX format beat affine at ~4-bit? NOTE the bpw is ≥ affine-4bit (4.0) → bandwidth-NEUTRAL by construction (MX has
    /// no sub-4-bit mode); this entry tests only the kernel/quality angle, not a bandwidth saving. Loads via MLX-swift
    /// `QuantizationMode.mxfp4` (Ops.swift:1115).
    public static let llama3_2_3B_mxfp4_local = Entry(
        id: "local/Llama-3.2-3B-Instruct-mxfp4",
        providerID: "mlx.llama3_2.3b.it.mxfp4.local",
        providerName: "Llama 3.2 3B (MLX, mxfp4 local)",
        extraEOSTokens: ["<|eot_id|>"],
        localDirectoryName: "models/Llama-3.2-3B-Instruct-mxfp4")

    /// Llama-3.2-3B 4-bit GROUP_SIZE 128 (vs the g64 baseline; 4.251 bpw, 1.6GB). Completeness-audit lever: every prior
    /// quant probe moved BITS — group_size was never the variable. g128 halves the scale/bias metadata (4.5→4.25 bpw) at
    /// the SAME 4-bit weights, so it cuts decode bytes WITHOUT the 3-bit FFN rot, and hits the IDENTICAL fast qmv kernel
    /// (`quantized.cpp` fast-path keys on N/K, not group_size). Expected ~3-5% (likely < thermal noise). Local-staged.
    public static let llama3_2_3B_4bit_g128_local = Entry(
        id: "local/Llama-3.2-3B-Instruct-g128",
        providerID: "mlx.llama3_2.3b.it.4bit.g128.local",
        providerName: "Llama 3.2 3B (MLX, 4-bit g128 local)",
        extraEOSTokens: ["<|eot_id|>"],
        localDirectoryName: "models/Llama-3.2-3B-Instruct-g128")

    /// Llama-3.2-3B AWQ 3-bit (mlx_lm.quant.awq: activation-aware scale-search, body 3-bit g64, EMBED kept 4-bit →
    /// leak-safe). The quality-preserving sub-4-bit retry: decode is bandwidth-bound (3bit measured 1.25× faster,
    /// BASBandwidthProbe), so the ONLY open question is whether AWQ holds the 3B's reasoning where naive affine-3bit
    /// ROTTED (17-sheep flip + system-prompt leak). ~1.40GB. Gate = the known rot-prompts pass + ~1.25× over 4-bit.
    public static let llama3_2_3B_awq3_local = Entry(
        id: "local/Llama-3.2-3B-Instruct-awq3",
        providerID: "mlx.llama3_2.3b.it.awq3.local",
        providerName: "Llama 3.2 3B (MLX, AWQ 3-bit local)",
        extraEOSTokens: ["<|eot_id|>"],
        localDirectoryName: "models/Llama-3.2-3B-Instruct-awq3")

    /// Llama-3.2-3B DWQ 3-bit (mlx_lm.quant.dwq: gradient distillation w/ KL-div vs the fp16 teacher, distilled ON TOP
    /// of the AWQ-3bit base so the leak-safe layout is preserved — 196×3-bit body + 1×4-bit embed). The STRONGEST
    /// sub-4-bit lever (1024 samples, avg_loss ~0.063). Final test of whether a 3B survives 3-bit: if the 1/6
    /// system-prompt leak that AWQ left STILL survives DWQ → the 3-bit body is fundamentally too lossy for a 3B.
    public static let llama3_2_3B_dwq3_local = Entry(
        id: "local/Llama-3.2-3B-Instruct-dwq3",
        providerID: "mlx.llama3_2.3b.it.dwq3.local",
        providerName: "Llama 3.2 3B (MLX, DWQ 3-bit local)",
        extraEOSTokens: ["<|eot_id|>"],
        localDirectoryName: "models/Llama-3.2-3B-Instruct-dwq3")

    /// Granite-4.0-H-Micro 4-bit (IBM, 3B dense Mamba-2/transformer HYBRID, 36/40 layers Mamba → KV-free state on ~90%
    /// of layers). Completeness-audit MODEL-AXIS lever: the prior cross-model sweep was dense-only; Mamba had only ever
    /// been a draft/distill target, never the PRIMARY decode backbone. Quality-NEUTRAL (full 4-bit). Verifier bets
    /// LATERAL at short ctx (KV-elim = the kvBits no-op pool; weights at parity). Loads via vendored `granitemoehybrid`.
    public static let granite4_h_micro_4bit_local = Entry(
        id: "local/Granite-4.0-H-Micro-4bit",
        providerID: "mlx.granite4.h_micro.4bit.local",
        providerName: "Granite 4.0 H-Micro (MLX, 4-bit local)",
        extraEOSTokens: [],
        localDirectoryName: "models/Granite-4.0-H-Micro-4bit")

    /// Granite-4.0-H-Tiny 4-bit-DWQ (IBM, 7B-total / ~1B-active hybrid MoE, 6-of-64 experts, 36/40 Mamba-2). The unique
    /// completeness-audit lever that cuts per-token ACTIVE bytes while RAISING capacity, all at full 4-bit (sidesteps the
    /// sub-4-bit rot wall). RISK: ~3906MB resident > the ~3376MB iPhone-Air jetsam cap → may SIGKILL even with the
    /// increased-memory entitlement; and batch-1 expert-gather overhead may eat the active-byte saving (<1×). Loads via
    /// vendored `granitemoehybrid` + `SwitchLayers` gatherQuantizedMM (reads only the 6 selected experts at batch-1).
    public static let granite4_h_tiny_4bit_local = Entry(
        id: "local/Granite-4.0-H-Tiny-4bit-DWQ",
        providerID: "mlx.granite4.h_tiny.4bit.dwq.local",
        providerName: "Granite 4.0 H-Tiny MoE (MLX, 4-bit DWQ local)",
        extraEOSTokens: [],
        localDirectoryName: "models/Granite-4.0-H-Tiny-4bit-DWQ")

    /// Default Gemma entries, in the order they should appear in UI pickers. Gemma 4 leads (newest +
    /// recommended); Gemma 3 4B trails as the long-context outlier. These are the ON-DEVICE-CERTIFIED picks.
    public static let defaultEntries: [Entry] = [
        gemma4_E4B_4bit,
        gemma4_E2B_4bit,
        gemma3_4B_it_4bit
    ]

    /// Data-grounded constrained-device default selector (2026-06-12 dual-device run). The catalog's nominal
    /// default is `gemma4_E4B_4bit`, but on a ≤~12 GB iPhone-class device E4B JETSAMS at weight-load (2 deaths
    /// on deviceB — responses=0, never reached the first token) while E2B survives (peak 3114 MB / 261 MB
    /// headroom under the ~3376 MB cap). A host that knows its device's per-process jetsam cap can ask for the
    /// richest default that ADMITS under it instead of blindly loading E4B and dying mid-load.
    ///
    /// Purely additive: does NOT change `defaultEntries` or the hardcoded `MLXOrganAdapter` default
    /// (byte-equal-off, ADR-014) — a host OPTS IN to device-aware selection.
    ///
    /// - Parameter capBytes: the device's per-process jetsam (ActiveHard) cap. Defaults to the measured iPhone
    ///   Air value; a larger-RAM host passes its own (where E4B admits and is returned).
    /// - Returns: `gemma4_E4B_4bit` where it fits under the cap, else `gemma4_E2B_4bit` (the measured survivor).
    public static func recommendedDefault(
        forActiveHardCapBytes capBytes: Int =
            BASMLXMemoryBudget.measurediPhoneAirActiveHardCapBytes
    ) -> Entry {
        if !BASMLXMemoryBudget.wouldExceedActiveHardCap(
            targetProviderID: gemma4_E4B_4bit.providerID,
            capBytes: capBytes) {
            return gemma4_E4B_4bit
        }
        return gemma4_E2B_4bit
    }

    /// **Stable-architecture fallbacks** exposed to the product/SDK face (ADR-038): standard-arch LLMs that
    /// avoid the Gemma-3n variable-shape cache-pool wedge class. **Honest scope (R1 / 亏的不要上):** these are
    /// *available, host opt-in* options — NOT yet on-device certified to the same bar as `defaultEntries`
    /// (Llama: 20/20 in the §11.5 A/B but not a full endurance cert; Qwen: not yet exercised on-device). A host
    /// that hits the Gemma-3n wedge can switch to one of these via the catalog without waiting on the
    /// cache-cap fix. Kept OUT of `defaultEntries` precisely so "default" stays = "certified".
    public static let availableAlternatives: [Entry] = [
        llama3_2_3B_4bit,
        qwen2_5_3B_4bit,
        qwen3_5_4B_4bit,
        llama3_2_1B_4bit,
        qwen2_5_1_5B_4bit
    ]

    /// Every selectable entry (certified defaults + opt-in alternatives) for SDK pickers that want to surface
    /// the full set. Order: certified defaults first, then alternatives.
    public static let allEntries: [Entry] = defaultEntries + availableAlternatives

    /// 结构大重构 — Phase 3: curated same-family TARGET → DRAFT speculative-decoding pairings. A target's value is
    /// the recommended SMALLER same-tokenizer-family draft to co-resident for speculative decoding. Keyed by the
    /// target's `providerID`. Every pair shares a turn terminator (same tokenizer family), the hard requirement
    /// for speculative decoding.
    ///
    /// - `gemma4.e4b → e2b` — the PRIMARY on-device cert target (operator-elected). Heaviest dual residency +
    ///   the ADR-038 Gemma-3n cache-wedge risk under two pools — see the spec-decode plan's risk ranking.
    /// - `llama3_2.3b → 1b`, `qwen2_5.3b → 1.5b` — standard-architecture pairs with NO Gemma-3n variable-shape
    ///   wedge (ADR-038 §11.5); the documented FALLBACK lane if the Gemma pair OOMs/wedges on 8 GB.
    /// - `gemma3.4b` is intentionally ABSENT (no same-family sibling) ⇒ speculative decoding honestly unavailable.
    public static let speculativePairings: [String: Entry] = [
        gemma4_E4B_4bit.providerID: gemma4_E2B_4bit,
        llama3_2_3B_4bit.providerID: llama3_2_1B_4bit,
        qwen2_5_3B_4bit.providerID: qwen2_5_1_5B_4bit,
    ]

    /// The recommended same-family draft for a target's `providerID`, or nil if the target has no curated pairing.
    public static func recommendedDraft(forTargetProviderID providerID: String) -> Entry? {
        speculativePairings[providerID]
    }

    /// The SPECULATION-OPTIMAL target — the entry whose greedy speculative decoding is ON-DEVICE CERTIFIED
    /// `enable` (Llama-3.2 3B↔1B: token-identity bytewise-verified, ~31% latency win, dual peak 2533 MB — fits
    /// the default per-process cap; 100 paired records / 2 devices; Docs/SPEC_DECODE_CERT_RESULTS.md).
    ///
    /// HONEST TRADE (the default target is deliberately NOT changed): `gemma4_E4B_4bit` stays the quality
    /// default, but its dual residency does NOT fit 8 GB, so greedy speculation stays dormant there. A host that
    /// prioritizes LATENCY over the Gemma quality tier constructs its adapter with THIS entry — the auto-resolved
    /// 1B draft engages and greedy turns get the certified speedup. Quality-vs-speed is the host's election;
    /// this constant just makes the certified fast lane discoverable.
    public static let speculativeOptimalTarget: Entry = llama3_2_3B_4bit
}
