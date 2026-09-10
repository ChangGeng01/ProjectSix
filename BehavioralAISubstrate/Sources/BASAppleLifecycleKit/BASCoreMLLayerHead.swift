// charter audit 2026-07-12 T4: the ungated closure-based actor + factory moved to
// BASAppleLifecycleKit (model-free); the MLModel-bound conveniences stay in
// BASAppleAdapters (BASCoreMLLayerHead+CoreML.swift).
// MARK: - BASCoreMLLayerHead — chapter 三百二〇 / M807
//
// Phase F (附录 X) 第一刀:typed CoreML adapter that wraps any
// `MLModel` into the `BASLayerMLHead` protocol shipped by chapter
// 三百 (M787)。This is the substrate-side bridge that activates
// chapter 一百七十七 vision § "Core ML mesh × 14 层" by letting
// hosts plug real `.mlpackage`-backed inference into the typed
// 14-layer mesh registry。
//
// chapter 一百七十七 (M616-M641) shipped 5 real `.mlpackage` files
// in `SampleHost/`:
//   - ChengluPreflight_v0 (binary AFM-vs-Gemma router, 92.53% acc)
//   - ChengluMultiHead_v0 (shared encoder + 4 outputs)
//   - ChengluPermitPredict_v0
//   - ChengluLengthHead_v0
//   - ChengluLatencyHead_v0
//
// These models are wrapped by 4 `@MainActor` inference singletons
// in SampleHost — they work, but they're NOT bridged into the
// typed `BASLayerMLHead` protocol。This file is the bridge。
//
// ## Why parametric closure init
//
// `MLModel` is non-Sendable + Apple-platform-only。Hosts need to:
//   1. Load `MLModel` from app bundle (host-side responsibility)
//   2. Pass `MLModel` reference to the adapter
//   3. Adapter wraps inside actor isolation for safe access
//
// To keep tests possible without bundling `.mlpackage` in the BAS
// test target, the adapter accepts a Sendable inference closure
// at the protocol-conformance level。Tests pass stub closures
// that mimic prediction output without loading real binaries。
// Production callers use the convenience init that takes
// `MLModel` directly。
//
// ## Doctrine pins held
//
//   - 不变量 #1 / #2 / #3 全保 — adapter is hint-class, no
//     production decision path mutation
//   - 红线 7 watcher hint only — kind = `.coremlOnDevice` matches
//     cascading tier 10 (between rules tier 0 and mlx tier 20)
//   - 单提交口 (L11/L14) 不变 — adapter doesn't issue permits
//   - chapter 二百一一 single-source-of-truth: ONE generic CoreML
//     adapter (vs N concrete per-Chenglu adapters scattered
//     across files)
//   - chapter 一百八十五 anti-magic-number: kind typed
//     `.coremlOnDevice`, latency clamped to ≥ 0
//   - chapter 一百三 schema-version: 1.0.0 invariant for
//     `BASCoreMLPredictionFrame`
//   - chapter 一百三十 BASLearnabilityClass: prediction frame is
//     observability metadata, semi-learnable
//   - chapter 三百 (M787) BASLayerMLHead protocol: this is the
//     canonical CoreML-tier conformer
//   - `#if canImport(CoreML)` matches existing
//     `#if canImport(FoundationModels)` precedent in
//     `BASAppleAdapters/AppleFoundationOrganAdapter.swift`

import Foundation
import BASRuntimeCore

// `BASCoreMLFeatureFrame` + `BASCoreMLPredictionFrame` typed
// value types live in `BASRuntimeCore/BASCoreMLFrames.swift`
// (cross-platform). This file (in BASAppleAdapters) hosts the
// actor wrapper + MLModel-bound conveniences that need
// `#if canImport(CoreML)` guards.

// MARK: - Generic CoreML layer head adapter

/// Actor-isolated typed adapter wrapping a CoreML inference
/// closure into `BASLayerMLHead` protocol。
///
/// ## Two construction paths
///
/// 1. **Parametric closure init** (preferred for tests):
///    Caller provides `featureExtractor` + `outputTransformer` +
///    `inferenceClosure`. No `MLModel` needed — tests pass stub
///    closures that mimic prediction output.
/// 2. **MLModel-bound convenience init** (production callers):
///    Available only on Apple platforms (`#if canImport(CoreML)`).
///    Caller passes a real `MLModel` reference;adapter wraps it
///    inside the actor + constructs `MLFeatureProvider` on the
///    fly + calls `model.prediction(from:)`.
///
/// ## Doctrine pin
///
/// `kind` is always `.coremlOnDevice` — corresponds to chapter
/// 一百七十七 cascading inference tier 10。Cascade runner walks
/// priority 0 (rules) first,then priority 10 (this kind),then
/// priority 20 (mlx),etc.
public actor BASCoreMLLayerHead: BASLayerMLHead {

    public nonisolated let headID: String
    public nonisolated let kind: BASLayerMLHeadKind = .coremlOnDevice

    /// Layer this head is intended to serve. Diagnostic hint
    /// (matches `BASRulesBasedLayerMLHead.layerIDPin` pattern
    /// from chapter 三百一一 / M798).
    public nonisolated let layerIDPin: BASMotherboardLayer14

    private let featureExtractor:
        @Sendable (BASLayerInferenceInput) -> BASCoreMLFeatureFrame
    private let outputTransformer:
        @Sendable (BASCoreMLPredictionFrame, BASLayerInferenceInput)
            -> BASLayerInferenceOutput
    private let inferenceClosure:
        @Sendable (BASCoreMLFeatureFrame) async throws
            -> BASCoreMLPredictionFrame

    /// Parametric closure init — testable without `MLModel`。
    public init(
        headID: String,
        layerIDPin: BASMotherboardLayer14,
        featureExtractor:
            @escaping @Sendable (BASLayerInferenceInput)
                -> BASCoreMLFeatureFrame,
        outputTransformer:
            @escaping @Sendable
                (BASCoreMLPredictionFrame, BASLayerInferenceInput)
                    -> BASLayerInferenceOutput,
        inferenceClosure:
            @escaping @Sendable (BASCoreMLFeatureFrame)
                async throws -> BASCoreMLPredictionFrame
    ) {
        self.headID = headID
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.layerIDPin = layerIDPin
        self.featureExtractor = featureExtractor
        self.outputTransformer = outputTransformer
        self.inferenceClosure = inferenceClosure
    }

    /// Conformance to `BASLayerMLHead`。Walks the 3-stage pipeline:
    ///   1. Extract features from typed input
    ///   2. Run inference closure (host's MLModel call lives here)
    ///   3. Transform prediction frame to typed output
    public func infer(
        input: BASLayerInferenceInput
    ) async throws -> BASLayerInferenceOutput {
        let featureFrame = featureExtractor(input)
        let predictionFrame = try await inferenceClosure(
            featureFrame)
        return outputTransformer(predictionFrame, input)
    }
}

// MARK: - MLModel-bound feature-provider helpers (Apple platforms only)


// MARK: - Factory namespace

/// Convenience factory namespace for common `BASCoreMLLayerHead`
/// construction patterns。
public enum BASCoreMLLayerHeadFactory {

    /// Build a parametric closure-based head with a fixed
    /// confidence-from-score mapping。Useful for stub heads in
    /// tests + for simple single-output classifiers where the
    /// score-to-confidence mapping is uniform。
    ///
    /// The output transformer maps:
    ///   - `scores[scoreKey]` → confidence via `confidenceFromScore`
    ///   - `recommendedAction` from caller-supplied closure
    ///   - `reasonCodes` derived from score
    public static func makeStubSingleOutput(
        headID: String,
        layerIDPin: BASMotherboardLayer14,
        scoreKey: String,
        stubScore: Double,
        confidenceFromScore:
            @escaping @Sendable (Double)
                -> BASLayerInferenceConfidence,
        recommendedAction: String? = nil
    ) -> BASCoreMLLayerHead {
        let recommendedActionCopy = recommendedAction
        return BASCoreMLLayerHead(
            headID: headID,
            layerIDPin: layerIDPin,
            featureExtractor: { _ in
                BASCoreMLFeatureFrame(featureValues: [:])
            },
            outputTransformer: { frame, input in
                let score = frame.scores[scoreKey] ?? 0
                return BASLayerInferenceOutput(
                    layerID: input.layerID,
                    scores: frame.scores,
                    confidence: confidenceFromScore(score),
                    recommendedAction: recommendedActionCopy,
                    reasonCodes: [
                        "coreml-head:\(headID)",
                        "coreml-score:\(scoreKey):" +
                        String(format: "%.4f", score)
                    ],
                    inferenceLatencyMs:
                        frame.inferenceLatencyMs)
            },
            inferenceClosure: { _ in
                BASCoreMLPredictionFrame(
                    scores: [scoreKey: stubScore],
                    modelDescription: headID,
                    inferenceLatencyMs: 0)
            })
    }

    /// Map a probability score (0..1) to typed confidence using
    /// chapter 一百七十七 v0.4 boundaries:
    ///   - prob < 0.30 or prob > 0.70 → `.high` (confident)
    ///   - prob ∈ [0.30, 0.40) ∪ (0.60, 0.70] → `.medium`
    ///   - prob ∈ [0.40, 0.60] → `.low` (uncertain zone)
    /// Out-of-range scores (< 0 or > 1) → `.unknown`.
    public static func defaultProbabilityConfidence(
        _ score: Double
    ) -> BASLayerInferenceConfidence {
        guard score >= 0, score <= 1 else { return .unknown }
        let absDistanceFromMid = abs(score - 0.5)
        if absDistanceFromMid > 0.20 { return .high }
        if absDistanceFromMid > 0.10 { return .medium }
        return .low
    }
}
