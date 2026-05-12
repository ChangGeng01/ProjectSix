// MARK: - BASCoreMLFrames — chapter 三百二〇 / M807
//
// Phase F (附录 X) typed Sendable frames for CoreML inference。
// These value types live in BASRuntimeCore (cross-platform) so
// the governance registry + Codable round-trip tests can
// reference them without importing BASAppleAdapters。The actor
// wrapper that consumes these frames lives in BASAppleAdapters
// (Apple-platform-only) because it requires `MLModel`。
//
// ## Doctrine pins
//
//   - 不变量 #1 / #2 / #3 全保 — value types only
//   - chapter 二百一一 single-source-of-truth: typed shapes
//     defined here, consumed by BASAppleAdapters
//   - chapter 一百八十五 anti-magic-number: latency clamped ≥ 0
//   - chapter 一百三 schema-version: 1.0.0 invariant for
//     `BASCoreMLPredictionFrame`

import Foundation

// MARK: - Sendable feature frame

/// Sendable input frame for CoreML inference。Hosts construct
/// from typed feature value dictionary;adapter converts to
/// `MLFeatureProvider` on actor isolation boundary at the
/// inference-closure level (in BASAppleAdapters)。
///
/// Field semantics:
///   - `featureValues` — dictionary of feature names to numeric
///     values. Schema is caller-defined (e.g. ChengluPreflight
///     uses 43 keys for one-hot tone/domain/stake/etc.). Values
///     are `Double` because CoreML's `MLFeatureValue` is most
///     commonly numeric;categorical features are pre-one-hot-
///     encoded by the caller。
public struct BASCoreMLFeatureFrame:
    Codable, Sendable, Equatable
{
    public let featureValues: [String: Double]

    public init(featureValues: [String: Double] = [:]) {
        self.featureValues = featureValues
    }
}

// MARK: - Sendable prediction frame

/// Sendable typed output frame from CoreML inference。Tracks the
/// model's prediction scores plus diagnostic metadata for audit
/// emission。
///
/// Field semantics:
///   - `scores` — output scores keyed by output name. e.g. for
///     ChengluPreflight: `["afm_success_probability": 0.83]`;
///     for ChengluMultiHead: `["intent": ..., "emotion": ...,
///     "risk": ..., "memory_importance": ...]`.
///   - `modelDescription` — opaque model identifier (typically
///     `headID` or model name). Round-trips through Codable for
///     audit trail。
///   - `inferenceLatencyMs` — wall-clock inference latency,
///     clamped ≥ 0 per `BASLayerInferenceOutput` invariant
public struct BASCoreMLPredictionFrame:
    BASSchemaVersioned, Sendable, Equatable, Codable
{
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var scores: [String: Double]
    public var modelDescription: String
    public var inferenceLatencyMs: Double

    public init(
        schemaVersion: String
            = BASCoreMLPredictionFrame.currentSchemaVersion,
        scores: [String: Double] = [:],
        modelDescription: String = "",
        inferenceLatencyMs: Double = 0
    ) {
        self.schemaVersion = schemaVersion
        self.scores = scores
        self.modelDescription = modelDescription
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.inferenceLatencyMs = max(0, inferenceLatencyMs)
    }
}

// MARK: - Mesh registration report (chapter 三百二一 / M808)

/// Typed report describing which Chenglu heads got registered into
/// a `BASLayerMLHedRegistry` via `BASChengluMeshRegistration
/// .assemble(...)` (lives in BASAppleAdapters)。
///
/// Lives in BASRuntimeCore (not BASAppleAdapters) so the schema
/// governance registry + Codable round-trip tests can reference it
/// without importing the Apple-platform-only target。
///
/// Hosts emit `reasonCodes` into audit trail for observability。
public struct BASChengluMeshRegistrationReport:
    BASSchemaVersioned, Sendable, Equatable, Codable
{
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String

    /// Total heads registered (max 8 when all 5 models present)。
    public var registeredHeadCount: Int

    /// Per-layer count of registered heads (key = `layer.rawValue`)。
    /// Unused layers absent from this map。
    public var perLayerCounts: [String: Int]

    /// Names of MLModels caller didn't pass (e.g. ["multiHead",
    /// "lengthHead"] if those 2 weren't loaded)。Empty when all
    /// 5 models present。
    public var missingMLModels: [String]

    /// Typed audit reason codes for emission into substrate
    /// trace。Caller appends these to `BASLayerActorOutput
    /// .reasonCodes` or audit ledger。
    public var reasonCodes: [String]

    public init(
        schemaVersion: String
            = BASChengluMeshRegistrationReport
                .currentSchemaVersion,
        registeredHeadCount: Int = 0,
        perLayerCounts: [String: Int] = [:],
        missingMLModels: [String] = [],
        reasonCodes: [String] = []
    ) {
        self.schemaVersion = schemaVersion
        self.registeredHeadCount = max(0, registeredHeadCount)
        self.perLayerCounts = perLayerCounts
        self.missingMLModels = missingMLModels
            .map {
                $0.trimmingCharacters(
                    in: .whitespacesAndNewlines)
            }
            .filter { !$0.isEmpty }
        self.reasonCodes = reasonCodes
            .map {
                $0.trimmingCharacters(
                    in: .whitespacesAndNewlines)
            }
            .filter { !$0.isEmpty }
    }

    /// Whether all 8 canonical slots got real CoreML heads
    /// registered (per附录 X §X.2 doctrine)。
    public var isComplete: Bool {
        registeredHeadCount == 8
    }
}
