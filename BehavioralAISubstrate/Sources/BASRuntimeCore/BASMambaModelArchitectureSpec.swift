// MARK: - BASMambaModelArchitectureSpec — chapter 四百 / M921
//
// G8 收尾 step 2:typed Codable spec describing the expected
// Mamba SSM architecture for the future training pipeline。
// Pre-M921 the M917 corpus schema told the trainer WHAT to
// feed the model;M921 tells it WHAT MODEL to build。
//
// The substrate doesn't run training,but it owns the
// architecture decision (which dim / how many layers / what
// state size) so that:
//   1. Substrate-side inference code knows the shape it'll
//      receive after G11 conversion to .mlpackage
//   2. Trainer reads this from a sidecar manifest and builds
//      `mamba_ssm.MambaConfig(...)` matching values
//   3. Hyperparameter sweeps version this file (each sweep
//      candidate = new instance with bumped tag)
//
// ## What this ships
//
//   - `BASMambaModelArchitectureSpec` typed Codable struct:
//     d_model / n_layers / d_state / d_conv / expand /
//     vocab_size / max_seq_len + named typed defaults from
//     the Mamba paper's "Mamba-130M" config
//   - `BASMambaModelSizeClass` typed enum naming canonical
//     model sizes (small / base / large / xlarge) so
//     hyperparameter sweeps stay typed not magic-number-y
//   - `BASMambaModelArchitectureSpec.preset(for:)` factory
//     returning the canonical spec for each size class
//   - `BASMambaModelArchitectureSpec.estimatedParameterCount`
//     pure helper for sanity-checking trained weights
//     against the spec
//
// ## Doctrine pins held
//
// - chapter 二百一一 single-source-of-truth — ONE typed
//   architecture spec, trainer + substrate both consume it
// - chapter 一百八十五 anti-magic-number — every hyperparam
//   default named typed constant
// - ADR-014 OPT-IN — spec is queried only when caller
//   constructs;substrate doesn't auto-load any model
// - ADR-016 (M918) externalSubstrateContractTyped — this
//   file extends G8's typed contract surface

import Foundation

// MARK: - Size class

/// Typed enum of canonical Mamba model size classes。
/// Mirrors the Mamba paper's released checkpoints (130M /
/// 370M / 790M / 1.4B) with substrate-specific names。
public enum BASMambaModelSizeClass:
    String, Codable, Equatable, Sendable, Hashable, CaseIterable
{
    /// ~130M params — Mamba paper's smallest released size。
    /// Suitable for on-device iPhone inference after G11
    /// conversion。Default for first training run。
    case small = "small"

    /// ~370M params — Mamba paper's "Mamba-370M"。Likely
    /// too large for iPhone real-time inference but useful
    /// for offline corpus-replay tasks (e.g. M898 replay
    /// runner consuming M903 export)。
    case base = "base"

    /// ~790M params — Mamba paper's "Mamba-790M"。Cloud-
    /// only inference if used at all。
    case large = "large"

    /// ~1.4B params — Mamba paper's "Mamba-1.4B"。Reserved
    /// for future research,not initial training。
    case xlarge = "xlarge"
}

// MARK: - Architecture spec

/// Typed Codable spec of one Mamba SSM model instance。
/// Trainer reads this from a sidecar manifest and constructs
/// `mamba_ssm.MambaConfig(...)` with matching values。
public struct BASMambaModelArchitectureSpec:
    Codable, Equatable, Sendable, Hashable
{
    /// Model dimension (`d_model` in the Mamba paper)。
    /// Embedding + hidden state width。Default 768 matches
    /// Mamba-130M。
    public let dModel: Int

    /// Number of Mamba blocks stacked。Default 24 matches
    /// Mamba-130M。
    public let nLayers: Int

    /// State dimension per Mamba block (`d_state` in the
    /// paper)。Controls the SSM hidden state size。Default 16
    /// per the paper (kept small to enable parallel scan
    /// efficiency on hardware)。
    public let dState: Int

    /// Conv1D kernel width inside each block (`d_conv`)。
    /// Default 4 per the paper。
    public let dConv: Int

    /// Block expansion factor (`expand` in paper)。Default 2
    /// — block hidden width = `expand * d_model`。
    public let expand: Int

    /// Vocabulary size for the embedding + output head。
    /// Default uses BAS event-kind taxonomy + risk band +
    /// thermal band cardinalities = approximately 64。
    /// Trainer overrides per loss-function decision
    /// (M922 BASMambaTrainingObjective)。
    public let vocabSize: Int

    /// Maximum context window length (in tokens / events)。
    /// Default 2048 matches typical Mamba paper config。
    /// At 600 iter/s iPhone throughput this represents
    /// ~3.4 seconds of event history。
    public let maxSequenceLength: Int

    /// Optional human-readable tag (e.g. "v1-iphone-stress-
    /// 2026-05-08")。Helps correlate trained weights with
    /// the spec used to train them。
    public let tag: String?

    public init(
        dModel: Int =
            BASMambaModelArchitectureSpec.defaultDModelSmall,
        nLayers: Int =
            BASMambaModelArchitectureSpec.defaultNLayersSmall,
        dState: Int =
            BASMambaModelArchitectureSpec.defaultDState,
        dConv: Int =
            BASMambaModelArchitectureSpec.defaultDConv,
        expand: Int =
            BASMambaModelArchitectureSpec.defaultExpand,
        vocabSize: Int =
            BASMambaModelArchitectureSpec.defaultVocabSize,
        maxSequenceLength: Int =
            BASMambaModelArchitectureSpec
                .defaultMaxSequenceLength,
        tag: String? = nil
    ) {
        precondition(dModel > 0, "dModel must be > 0")
        precondition(nLayers > 0, "nLayers must be > 0")
        precondition(dState > 0, "dState must be > 0")
        precondition(dConv > 0, "dConv must be > 0")
        precondition(expand > 0, "expand must be > 0")
        precondition(vocabSize > 0, "vocabSize must be > 0")
        precondition(maxSequenceLength > 0,
            "maxSequenceLength must be > 0")
        self.dModel = dModel
        self.nLayers = nLayers
        self.dState = dState
        self.dConv = dConv
        self.expand = expand
        self.vocabSize = vocabSize
        self.maxSequenceLength = maxSequenceLength
        self.tag = tag
    }

    // MARK: - Defaults (chapter 一百八十五)

    /// Mamba-130M defaults (smallest released size,suitable
    /// for iPhone inference after G11 conversion)。
    public static let defaultDModelSmall: Int = 768
    public static let defaultNLayersSmall: Int = 24

    /// Mamba-370M defaults。
    public static let defaultDModelBase: Int = 1024
    public static let defaultNLayersBase: Int = 48

    /// Mamba-790M defaults。
    public static let defaultDModelLarge: Int = 1536
    public static let defaultNLayersLarge: Int = 48

    /// Mamba-1.4B defaults。
    public static let defaultDModelXLarge: Int = 2048
    public static let defaultNLayersXLarge: Int = 48

    /// Per-paper invariants shared across all sizes。
    public static let defaultDState: Int = 16
    public static let defaultDConv: Int = 4
    public static let defaultExpand: Int = 2

    /// BAS event taxonomy cardinality:12 event kinds + 4
    /// risk bands + 4 thermal bands + reserved tokens →
    /// rounds up to 64 for tensor-friendliness。Trainer
    /// overrides if the M922 objective demands a wider
    /// vocab (e.g. predicting full action strings)。
    public static let defaultVocabSize: Int = 64

    /// Default context window matches the M917 feature
    /// spec's `defaultSequenceLength` × 4 (roomy for
    /// concatenated session sequences)。
    public static let defaultMaxSequenceLength: Int = 2048

    // MARK: - Presets

    /// Canonical preset for each size class。Hosts use this
    /// instead of constructing manually to avoid drift。
    public static func preset(
        for sizeClass: BASMambaModelSizeClass,
        tag: String? = nil
    ) -> BASMambaModelArchitectureSpec {
        switch sizeClass {
        case .small:
            return BASMambaModelArchitectureSpec(
                dModel: defaultDModelSmall,
                nLayers: defaultNLayersSmall,
                tag: tag)
        case .base:
            return BASMambaModelArchitectureSpec(
                dModel: defaultDModelBase,
                nLayers: defaultNLayersBase,
                tag: tag)
        case .large:
            return BASMambaModelArchitectureSpec(
                dModel: defaultDModelLarge,
                nLayers: defaultNLayersLarge,
                tag: tag)
        case .xlarge:
            return BASMambaModelArchitectureSpec(
                dModel: defaultDModelXLarge,
                nLayers: defaultNLayersXLarge,
                tag: tag)
        }
    }

    // MARK: - Helpers

    /// Rough parameter-count estimate (Mamba paper formula
    /// approximation)。Used by trainers to sanity-check
    /// loaded weights against the spec。
    /// Per Mamba paper:
    ///   params ≈ vocabSize * d_model
    ///          + n_layers * (block params)
    ///   block ≈ 3 * expand * d_model^2
    ///         + d_model * d_state
    ///         + small bias / norm terms
    /// Returns approximate count (within 5% of actual)。
    public var estimatedParameterCount: Int {
        let embedding = vocabSize * dModel
        let blockApprox = (3 * expand * dModel * dModel)
            + (dModel * dState)
        let blocks = nLayers * blockApprox
        return embedding + blocks
    }
}
