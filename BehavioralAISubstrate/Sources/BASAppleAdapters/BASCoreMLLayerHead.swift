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

#if canImport(CoreML)
import CoreML
#endif

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

#if canImport(CoreML)

public extension BASCoreMLLayerHead {

    // chapter 三百四八 / M835 — `makeFromMLModel` removed。Was
    // marked `@available(*, deprecated, ...)` in chapter 三百三五 /
    // M822 with 0 production callers (only the chapter 三百二一
    // Chenglu adapters used it,and chapter 三百三二 / M819 reality
    // check rewrote all 5 to bypass it via direct inferenceClosure
    // construction)。Removal closes the v9 §8 backlog HIGH #3 item
    // raised in chapter 三百四七 / M834 audit。
    //
    // **Migration path** for any external host that called it:
    //   - For Chenglu `.mlpackage` integrations → use the chapter
    //     三百二一 adapter factories
    //     (`BASChengluPreflightAdapter.make(model:)` etc.),which
    //     route through `makeMultiArrayFeatureProvider` (the only
    //     correct shape for sklearn-trained Chenglu models)
    //   - For genuinely per-key models → call the parametric
    //     `BASCoreMLLayerHead(...)` initializer directly,passing
    //     a custom `inferenceClosure` that calls
    //     `makeFeatureProvider(from:)` + `model.prediction(from:)`
    //     yourself (recipe in `BASChengluCoreMLAdapters.swift`)

    /// Build an `MLDictionaryFeatureProvider` from a Sendable
    /// `[String: Double]` dictionary,with one `MLFeatureValue
    /// (double:)` per key。
    ///
    /// **Use case**:CoreML models trained to consume named
    /// scalar features (one input port per feature)。Less common
    /// than the MLMultiArray-batched shape produced by sklearn /
    /// coremltools' default conversion path。
    ///
    /// **NOT compatible with real shipped Chenglu `.mlpackage`
    /// files** (chapter 一百七十七+) — those expect a single
    /// `features` MLMultiArray input。Use
    /// `makeMultiArrayFeatureProvider(values:orderedKeys:
    /// featureKey:)` for those。
    ///
    /// Kept public for hosts with custom CoreML models that DO
    /// use per-key scalar inputs (legacy / non-sklearn-trained
    /// models)。
    static func makeFeatureProvider(
        from values: [String: Double]
    ) throws -> MLFeatureProvider {
        var mlValues: [String: MLFeatureValue] = [:]
        for (key, value) in values {
            mlValues[key] = MLFeatureValue(double: value)
        }
        return try MLDictionaryFeatureProvider(
            dictionary: mlValues)
    }

    /// Build an `MLDictionaryFeatureProvider` that wraps a single
    /// `MLMultiArray(shape: [1, N])` Float32 input under the given
    /// `featureKey`。This matches the input format produced by
    /// CoreML models that were trained with sklearn / coremltools'
    /// default `features` input convention (chapter 一百七十七 + 一百八十一
    /// SampleHost `.mlpackage` files use this shape)。
    ///
    /// The values are extracted from the input dictionary in the
    /// caller-supplied `orderedKeys` order — this MUST match the
    /// training-time featurization order for the model to produce
    /// correct predictions。
    ///
    /// - Parameters:
    ///   - values: dictionary of feature names → numeric values
    ///     (typically produced by `BASChengluFeatureEncoder.encode`)
    ///   - orderedKeys: canonical order of dictionary keys to
    ///     extract values from (length = N = expected MLMultiArray
    ///     dim 1)
    ///   - featureKey: input feature name expected by the model
    ///     (typically `"features"` for sklearn-trained models)
    /// - Returns: provider wrapping `[featureKey: MLMultiArray]`
    /// - Throws: `BASCoreMLAdapterError.multiArrayConstructionFailed`
    ///   if MLMultiArray init fails;rethrows provider init errors
    static func makeMultiArrayFeatureProvider(
        values: [String: Double],
        orderedKeys: [String],
        featureKey: String = "features"
    ) throws -> MLFeatureProvider {
        let n = orderedKeys.count
        let shape: [NSNumber] = [1, NSNumber(value: n)]
        guard let array = try? MLMultiArray(
            shape: shape, dataType: .float32)
        else {
            throw BASCoreMLAdapterError
                .multiArrayConstructionFailed(
                    expectedShape: [1, n])
        }
        for (index, key) in orderedKeys.enumerated() {
            let value = values[key] ?? 0
            array[index] = NSNumber(value: Float(value))
        }
        let dict: [String: MLFeatureValue] = [
            featureKey: MLFeatureValue(multiArray: array)
        ]
        return try MLDictionaryFeatureProvider(
            dictionary: dict)
    }

    /// Extract output feature names + Double values from an
    /// `MLFeatureProvider`。Skips non-numeric output features
    /// (returns 0 for those — caller's outputTransformer can
    /// detect missing keys)。
    static func extractScores(
        from provider: MLFeatureProvider
    ) -> [String: Double] {
        var scores: [String: Double] = [:]
        for name in provider.featureNames {
            guard let value = provider.featureValue(for: name)
            else { continue }
            switch value.type {
            case .double:
                scores[name] = value.doubleValue
            case .int64:
                scores[name] = Double(value.int64Value)
            case .multiArray:
                // For multiArray outputs, take first scalar if
                // shape is [1] or [1,1]; otherwise skip + caller
                // handles via a custom outputTransformer.
                if let array = value.multiArrayValue,
                   array.count == 1
                {
                    scores[name] = array[0].doubleValue
                }
            default:
                continue
            }
        }
        return scores
    }
}

// Chapter 三百四八 / M835: `BASCoreMLModelBox` removed alongside
// `makeFromMLModel`。Was a private struct used only by the
// removed factory。Each Chenglu adapter in
// `BASChengluCoreMLAdapters.swift` defines its own private box
// (5 separate `@unchecked Sendable` boxes,one per adapter)
// so the removal is non-breaking。

/// Typed error cases for CoreML adapter construction + inference
/// (chapter 三百三二 / M819)。
public enum BASCoreMLAdapterError:
    Error, Equatable, Sendable, Codable
{
    /// `MLMultiArray(shape:dataType:)` returned nil。Includes
    /// the expected shape for diagnostic emission。
    case multiArrayConstructionFailed(expectedShape: [Int])
}

#endif

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
