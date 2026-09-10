// MARK: - BASMambaTrainingCorpusSchema — chapter 四百 / M917
//
// G8 收尾 substrate-side typed input contract for the future
// Mamba SSM training pipeline (P2 G8 from M840 roadmap)。
// Pre-M917 the M903 training data exporter shipped a typed
// JSONL corpus (`BASTrainingDatum`),but no contract specified
// what shape the Mamba training Python pipeline EXPECTS to
// consume。This file pins the contract:
//
//   M903 export ──▶ BASMambaTrainingCorpusSchema
//   (event/state              (typed validation +
//   tuples)                    feature extraction
//                              spec)
//                                  │
//                                  ▼
//                              external Python pipeline
//                              (mamba-ssm + torch + GPU)
//
// ## Why a typed schema
//
// External work (Python training) is going to read JSONL
// emitted by M903。Without a typed schema:
//   - field renames in M903 silently break the trainer
//   - added optional fields silently get ignored
//   - the trainer's input shape diverges from the substrate's
//     Codable types
// With a typed schema:
//   - schema version is bumped explicitly when fields change
//   - `validate(datum:)` catches malformed inputs at corpus
//     load time,not 3 hours into training
//   - feature-extraction spec is versioned alongside the
//     corpus (the Python side reproduces feature extraction
//     from the typed spec)
//
// ## What this ships (M917)
//
//   - `BASMambaTrainingCorpusSchema.schemaVersion: String`
//     pinned constant the Python pipeline asserts on load
//   - `BASMambaTrainingFeatureSpec` typed Codable struct —
//     declares the feature-extraction shape (input dim,
//     sequence length, padding strategy, etc.)
//   - `BASMambaTrainingCorpusManifest` typed Codable struct
//     bundling schemaVersion + featureSpec + a list of
//     JSONL file paths (multi-shard corpora)
//   - `BASMambaTrainingValidator` typed validator namespace
//     with `validate(datum:)` that asserts a `BASTrainingDatum`
//     conforms to the schema (returns typed result with
//     specific failure reason)
//
// ## What this does NOT ship
//
//   - The Python training pipeline (genuinely external)
//   - The Mamba model architecture (genuinely external)
//   - GPU resource management (genuinely external)
//   - Output `.mlpackage` (M918 G11 conversion contract)
//
// ## Doctrine pins held
//
// - 不变量 #1 / #2 / #3 — schema is observation,no
//   permit/verdict mutation
// - 红线 7 hint-only — validator reports issues,host /
//   training pipeline decides what to do
// - chapter 二百一一 single-source-of-truth — ONE typed
//   schema for Mamba training input
// - chapter 一百八十五 anti-magic-number — feature dims +
//   sequence length defaults named typed constants
// - chapter 三百九二 (M892) replay-determinism — same
//   corpus + same schema → identical training inputs
// - ADR-014 OPT-IN — schema only validates when caller
//   invokes;substrate behavior unchanged for hosts that
//   don't train Mamba

import Foundation

// MARK: - Feature spec

/// Typed Codable feature-extraction spec。Pinned alongside the
/// corpus so the Python trainer reproduces feature extraction
/// from this exact configuration。Bumping any field means
/// bumping `schemaVersion` (re-validation required)。
public struct BASMambaTrainingFeatureSpec:
    Codable, Equatable, Sendable, Hashable
{
    /// Number of features per timestep。Matches the dim of
    /// `BASUserState`'s reduced feature vector after
    /// extraction (event kind one-hot + thermal band one-hot
    /// + risk band one-hot + numeric scalars)。
    public let inputDim: Int

    /// Maximum sequence length per training example。Sequences
    /// shorter than this are zero-padded;longer are truncated
    /// per `truncationStrategy`。Default 512 matches typical
    /// Mamba paper config + iPhone 1h runs (≈ 2-3 thousand
    /// events / 4-6 sequences per session).
    public let sequenceLength: Int

    /// Typed enum of how to handle sequences longer than
    /// `sequenceLength`。
    public enum TruncationStrategy:
        String, Codable, Equatable, Sendable, CaseIterable
    {
        /// Keep the FIRST `sequenceLength` events,drop tail。
        case dropTail = "dropTail"
        /// Keep the LAST `sequenceLength` events,drop head。
        case dropHead = "dropHead"
        /// Sliding window:emit MULTIPLE training examples
        /// from one over-long session,each `sequenceLength`
        /// events with `windowStride` overlap。
        case slidingWindow = "slidingWindow"
    }

    public let truncationStrategy: TruncationStrategy

    /// Stride between sliding-window training examples (only
    /// used when `truncationStrategy == .slidingWindow`)。
    /// Default 256 = 50% overlap at sequenceLength=512。
    public let windowStride: Int

    /// True if the trainer should mask events with `kind ==
    /// .internalSignal`(M888 cycle-feedback events) from the
    /// loss。Default false:cycle events ARE part of the
    /// signal,don't mask。Hosts running ablation studies
    /// flip this to true。
    public let maskInternalSignals: Bool

    public init(
        inputDim: Int = Self.defaultInputDim,
        sequenceLength: Int = Self.defaultSequenceLength,
        truncationStrategy: TruncationStrategy =
            .slidingWindow,
        windowStride: Int = Self.defaultWindowStride,
        maskInternalSignals: Bool = false
    ) {
        precondition(inputDim > 0,
            "inputDim must be > 0")
        precondition(sequenceLength > 0,
            "sequenceLength must be > 0")
        precondition(windowStride > 0
            && windowStride <= sequenceLength,
            "windowStride must be in 1...sequenceLength")
        self.inputDim = inputDim
        self.sequenceLength = sequenceLength
        self.truncationStrategy = truncationStrategy
        self.windowStride = windowStride
        self.maskInternalSignals = maskInternalSignals
    }

    /// chapter 一百八十五 anti-magic-number defaults
    public static let defaultInputDim: Int = 32
    public static let defaultSequenceLength: Int = 512
    public static let defaultWindowStride: Int = 256
}

// MARK: - Corpus manifest

/// Typed Codable manifest bundling a Mamba training corpus's
/// schema version + feature spec + JSONL shard paths。Hosts
/// emit this alongside the M903-exported JSONL so the Python
/// trainer can verify schema compatibility on load。
public struct BASMambaTrainingCorpusManifest:
    Codable, Equatable, Sendable
{
    /// Pinned schema version。Trainer asserts this on load。
    public let schemaVersion: String

    /// Feature-extraction spec (must match the trainer's
    /// expected shape)。
    public let featureSpec: BASMambaTrainingFeatureSpec

    /// Relative file paths of the JSONL shards (relative to
    /// the manifest's enclosing directory)。Multi-shard
    /// corpora common at multi-GB scale。
    public let shardPaths: [String]

    /// Number of `BASTrainingDatum` rows summed across all
    /// shards。For sanity check on the trainer side。
    public let totalRowCount: Int

    /// Wall-clock timestamp when the manifest was emitted
    /// (millis since UNIX epoch)。
    public let emittedAtMs: Int64

    /// Optional host-supplied corpus tag (e.g. "10h-iphone-
    /// stress-2026-05-08")。Helps correlate corpus shards
    /// with the run that produced them。
    public let corpusTag: String?

    public init(
        schemaVersion: String =
            BASMambaTrainingCorpusSchema.schemaVersion,
        featureSpec: BASMambaTrainingFeatureSpec,
        shardPaths: [String],
        totalRowCount: Int,
        emittedAtMs: Int64,
        corpusTag: String? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.featureSpec = featureSpec
        self.shardPaths = shardPaths
        self.totalRowCount = totalRowCount
        self.emittedAtMs = emittedAtMs
        self.corpusTag = corpusTag
    }
}

// MARK: - Validation result

/// Typed result of validating a single `BASTrainingDatum`
/// against the schema。Trainer aggregates these across the
/// corpus to decide whether to proceed。
public enum BASMambaTrainingValidationResult:
    Sendable, Equatable, Codable
{
    case valid
    case invalid(reason: BASMambaTrainingValidationFailure)
}

public enum BASMambaTrainingValidationFailure:
    String, Sendable, Equatable, Hashable, CaseIterable, Codable
{
    /// Datum's event has missing required fields (eventID,
    /// timestampMs, kind, sessionID)。
    case missingRequiredEventField =
        "missingRequiredEventField"
    /// Datum's event timestampMs is non-positive (impossible
    /// for a valid wall-clock timestamp)。
    case nonPositiveTimestamp = "nonPositiveTimestamp"
    /// Datum claims `includeStateContext` was on but BOTH
    /// stateBefore AND stateAfter are nil — contradictory。
    case contradictoryStateContext =
        "contradictoryStateContext"
    /// Datum's event sessionID is empty (cross-session
    /// fixture events not allowed in training corpus)。
    case emptySessionID = "emptySessionID"
}

// MARK: - Corpus schema namespace

/// Substrate-side typed namespace for Mamba training corpus
/// validation。Pure functions over `BASTrainingDatum` so
/// callers can validate offline without I/O dependencies。
public enum BASMambaTrainingCorpusSchema {

    /// Schema version pin。Bumped when ANY field changes in
    /// `BASMambaTrainingFeatureSpec` or `BASMambaTrainingCorpus
    /// Manifest`。Trainer asserts this on load — mismatched
    /// versions abort training before GPU time is wasted。
    public static let schemaVersion: String = "M917.1.0.0"
}

// MARK: - Validator (BASHostKit)

// NOTE:the validator that actually examines `BASTrainingDatum`
// values lives in BASHostKit because `BASTrainingDatum` is
// defined there。This file in BASRuntimeCore declares the
// schema + feature spec primitives;BASHostKit's
// `BASMambaTrainingValidator.swift` implements the
// validate(datum:) entry point per chapter 二百一一
// single-source-of-truth (validator co-located with the
// type it inspects)。
