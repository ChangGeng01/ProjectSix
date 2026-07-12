// MARK: - BASCoreMLLayerHead MLModel conveniences — split from the pure actor
// (charter audit 2026-07-12 T4). The closure-based actor lives in BASAppleLifecycleKit;
// these MLModel-bound helpers are the model-side half.

import Foundation
import BASRuntimeCore
import BASAppleLifecycleKit

#if canImport(CoreML)
import CoreML

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
