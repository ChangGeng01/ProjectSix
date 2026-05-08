// MARK: - BASMambaCheckpointManifest — chapter 四百 / M926
//
// G8 收尾 step 4:typed Codable manifest for one trained Mamba
// SSM checkpoint。Pre-M926 G8's substrate-side surface had:
//   - M903 BASTrainingDataExporter (corpus OUT)
//   - M917 BASMambaTrainingCorpusSchema (input contract)
//   - M921 BASMambaModelArchitectureSpec (model shape)
//   - M922 BASMambaTrainingObjective (loss shape)
//   - M925 BASTrainingLabels enricher (supervised labels)
// All of these describe the INPUT side of training。The
// OUTPUT side — what file format to write trained weights as,
// what metadata to bundle with them,how to version a sweep —
// had no typed contract。Post-M926 the typed manifest pins:
//
//   - which spec + objective + corpus produced this checkpoint
//   - which final + best-epoch loss + accuracy + perplexity
//   - which weights file path (host writes weights to disk)
//   - which corpus-tag the checkpoint trained against
//   - sweep-tag for hyperparameter-sweep correlation
//   - typed eval-set metric snapshot (loss / accuracy /
//     custom metrics)
//
// Trainer writes one of these alongside each checkpoint。
// Substrate-side consumers (M918 conversion contract,future
// inference registration code) read it。
//
// ## What this ships
//
//   - `BASMambaCheckpointManifest` typed Codable struct
//     bundling spec + objective + corpus tag + metrics +
//     paths
//   - `BASMambaCheckpointMetric` typed Codable bundle:
//     metricName + value + sampleCount (e.g. "valLoss" /
//     "accuracy@5" / "perplexity" with the eval-set size)
//   - `BASMambaCheckpointStatus` typed enum: `.training`
//     (in-progress) / `.completed` / `.aborted`
//   - `BASMambaCheckpointManifestSchema` namespace with
//     pinned schemaVersion + validator
//
// ## Doctrine pins held
//
// - chapter 二百一一 single-source-of-truth — ONE typed
//   manifest, trainer + substrate both consume
// - chapter 一百八十五 anti-magic-number — schema version +
//   metric name conventions named typed constants
// - chapter 三百九二 (M892) replay-determinism — same
//   spec + same corpus + same training run → same manifest
// - ADR-014 OPT-IN — manifest written only when caller
//   chooses;substrate doesn't auto-create
// - ADR-016 (M918 doctrine bump) — extends G8's typed
//   substrate-contract surface

import Foundation

// MARK: - Status

public enum BASMambaCheckpointStatus:
    String, Codable, Equatable, Sendable, Hashable, CaseIterable
{
    /// Training in progress — checkpoint is intermediate,
    /// metrics may improve before final saved checkpoint。
    case training = "training"
    /// Training completed normally — checkpoint represents
    /// final state of this run。
    case completed = "completed"
    /// Training aborted (OOM / NaN loss / user cancel)。
    /// Checkpoint may be partial。
    case aborted = "aborted"
}

// MARK: - Metric

public struct BASMambaCheckpointMetric:
    Codable, Equatable, Sendable, Hashable
{
    /// Canonical metric name。Convention: lowerCamelCase。
    /// Trainer must use the substrate's pinned names for
    /// any metric that downstream eval consumers compare:
    ///   - "trainLoss" / "valLoss" / "testLoss"
    ///   - "accuracy" / "accuracy@5" / "topKAccuracy"
    ///   - "perplexity" / "valPerplexity"
    ///   - "f1" / "precision" / "recall"
    /// Custom-named metrics are allowed for hyperparameter-
    /// sweep introspection but won't be compared by
    /// `BASEvalRegressionDetector`(M861)。
    public let metricName: String
    /// Numeric value of the metric。
    public let value: Double
    /// Number of samples this metric was computed over。Used
    /// for confidence weighting in cross-checkpoint comparison。
    public let sampleCount: Int

    public init(
        metricName: String,
        value: Double,
        sampleCount: Int
    ) {
        self.metricName = metricName
        self.value = value
        self.sampleCount = sampleCount
    }
}

// MARK: - Manifest

public struct BASMambaCheckpointManifest:
    Codable, Equatable, Sendable, Hashable
{
    /// Pinned schema version。Trainer + substrate both assert。
    public let schemaVersion: String

    /// Stable unique ID for this checkpoint。Convention:
    /// `<sweepTag>-<epochNumber>`(host-supplied)。
    public let checkpointID: String

    /// Architecture spec used to build the model (M921)。
    public let architectureSpec: BASMambaModelArchitectureSpec

    /// Training objective (M922)。
    public let objective: BASMambaTrainingObjective

    /// Corpus tag the checkpoint trained against (matches
    /// `BASMambaTrainingCorpusManifest.corpusTag`)。
    public let corpusTag: String

    /// Path to the weights file。Convention:
    /// `<sweepTag>/<checkpointID>.safetensors` or
    /// `<sweepTag>/<checkpointID>.pt`。
    public let weightsPath: String

    /// Status of the checkpoint (training / completed /
    /// aborted)。
    public let status: BASMambaCheckpointStatus

    /// Epoch number this checkpoint was saved at (0-indexed)。
    public let epochNumber: Int

    /// Optional sweep tag for hyperparameter-sweep
    /// correlation (e.g. "lr-1e3-batch-128")。
    public let sweepTag: String?

    /// Metric snapshot at this checkpoint。Trainer computes
    /// these per `BASMambaTrainingObjective.lossClass`。
    public let metrics: [BASMambaCheckpointMetric]

    /// Wall-clock timestamp when the checkpoint was emitted
    /// (millis since UNIX epoch)。
    public let emittedAtMs: Int64

    /// Optional human-readable notes (e.g. "best val loss
    /// so far","aborted on NaN at step 4500")。
    public let notes: String?

    public init(
        schemaVersion: String =
            BASMambaCheckpointManifestSchema.schemaVersion,
        checkpointID: String,
        architectureSpec: BASMambaModelArchitectureSpec,
        objective: BASMambaTrainingObjective,
        corpusTag: String,
        weightsPath: String,
        status: BASMambaCheckpointStatus,
        epochNumber: Int,
        sweepTag: String? = nil,
        metrics: [BASMambaCheckpointMetric] = [],
        emittedAtMs: Int64,
        notes: String? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.checkpointID = checkpointID
        self.architectureSpec = architectureSpec
        self.objective = objective
        self.corpusTag = corpusTag
        self.weightsPath = weightsPath
        self.status = status
        self.epochNumber = epochNumber
        self.sweepTag = sweepTag
        self.metrics = metrics
        self.emittedAtMs = emittedAtMs
        self.notes = notes
    }

    /// Convenience:lookup a metric by canonical name。
    public func metric(
        named name: String
    ) -> BASMambaCheckpointMetric? {
        metrics.first { $0.metricName == name }
    }
}

// MARK: - Validation

public enum BASMambaCheckpointValidationResult:
    Sendable, Equatable
{
    case valid
    case invalid(reason:
        BASMambaCheckpointValidationFailure)
}

public enum BASMambaCheckpointValidationFailure:
    String, Sendable, Equatable, Hashable, CaseIterable, Codable
{
    case mismatchedSchemaVersion = "mismatchedSchemaVersion"
    case emptyCheckpointID = "emptyCheckpointID"
    case emptyCorpusTag = "emptyCorpusTag"
    case emptyWeightsPath = "emptyWeightsPath"
    case negativeEpochNumber = "negativeEpochNumber"
    case duplicateMetricName = "duplicateMetricName"
}

// MARK: - Schema namespace

public enum BASMambaCheckpointManifestSchema {

    /// Schema version pin。Bumped when ANY field shape changes。
    public static let schemaVersion: String = "M926.1.0.0"

    /// Pinned canonical metric names。Custom names allowed,
    /// but these specific names are what downstream eval
    /// consumers (M861 BASEvalRegressionDetector) recognize。
    public static let canonicalMetricTrainLoss: String =
        "trainLoss"
    public static let canonicalMetricValLoss: String =
        "valLoss"
    public static let canonicalMetricTestLoss: String =
        "testLoss"
    public static let canonicalMetricAccuracy: String =
        "accuracy"
    public static let canonicalMetricPerplexity: String =
        "perplexity"

    /// All canonical names for iteration / completeness checks。
    public static let canonicalMetricNames: [String] = [
        canonicalMetricTrainLoss,
        canonicalMetricValLoss,
        canonicalMetricTestLoss,
        canonicalMetricAccuracy,
        canonicalMetricPerplexity,
    ]

    /// Validate a manifest before persisting / consuming。Pure。
    public static func validate(
        manifest: BASMambaCheckpointManifest
    ) -> BASMambaCheckpointValidationResult {
        if manifest.schemaVersion != schemaVersion {
            return .invalid(
                reason: .mismatchedSchemaVersion)
        }
        if manifest.checkpointID
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty
        {
            return .invalid(
                reason: .emptyCheckpointID)
        }
        if manifest.corpusTag
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty
        {
            return .invalid(reason: .emptyCorpusTag)
        }
        if manifest.weightsPath
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty
        {
            return .invalid(reason: .emptyWeightsPath)
        }
        if manifest.epochNumber < 0 {
            return .invalid(reason: .negativeEpochNumber)
        }
        // Metric names must be unique within the manifest
        let names = manifest.metrics.map(\.metricName)
        if Set(names).count != names.count {
            return .invalid(
                reason: .duplicateMetricName)
        }
        return .valid
    }
}
