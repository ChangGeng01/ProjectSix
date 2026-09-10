// MARK: - Chenglu MLModel make overloads — split from the pure adapter cores
// (charter audit 2026-07-12 T4). One gate wraps all five extensions.

import Foundation
import BASRuntimeCore
import BASAppleLifecycleKit
#if canImport(CoreML)
import CoreML

extension BASChengluPreflightAdapter {
    /// Construct adapter bound to a real `MLModel`。Caller is
    /// responsible for loading the `.mlpackage` from app bundle。
    ///
    /// Real `.mlpackage` models trained via sklearn + coremltools
    /// expect a single `features` input of shape `[1, 43]`
    /// (Float32 MLMultiArray) — NOT 43 individual scalar feature
    /// entries。Chapter 三百三二 / M819 fixed this by routing
    /// real-model adapter construction through a custom
    /// inference closure that uses
    /// `BASCoreMLLayerHead.makeMultiArrayFeatureProvider(...)`。
    public static func make(
        headID: String,
        layerIDPin: BASMotherboardLayer14,
        model: MLModel
    ) -> BASCoreMLLayerHead {
        let outKey = outputKey
        let modelBox = ChengluPreflightAdapterModelBox(
            model: model)
        let inferenceClosure:
            @Sendable (BASCoreMLFeatureFrame) async throws
                -> BASCoreMLPredictionFrame
            = { frame in
                let startTime = Date()
                let provider = try BASCoreMLLayerHead
                    .makeMultiArrayFeatureProvider(
                        values: frame.featureValues,
                        orderedKeys: BASChengluFeatureEncoder
                            .canonicalKeyOrder,
                        featureKey: "features")
                let result = try modelBox.model.prediction(
                    from: provider)
                let scores = BASCoreMLLayerHead
                    .extractScores(from: result)
                let elapsed = Date()
                    .timeIntervalSince(startTime) * 1000
                return BASCoreMLPredictionFrame(
                    scores: scores,
                    modelDescription: "ChengluPreflight_v0",
                    inferenceLatencyMs: elapsed)
            }
        return BASCoreMLLayerHead(
            headID: headID,
            layerIDPin: layerIDPin,
            featureExtractor: bASChengluFeatureExtractor,
            outputTransformer: { frame, input in
                let score = frame.scores[outKey] ?? 0
                let action = score > 0.5
                    ? "afm-route"
                    : "gemma-route"
                let confidence = BASCoreMLLayerHeadFactory
                    .defaultProbabilityConfidence(score)
                return BASLayerInferenceOutput(
                    layerID: input.layerID,
                    scores: frame.scores,
                    confidence: confidence,
                    recommendedAction: action,
                    reasonCodes: [
                        "coreml-head:chenglu-preflight",
                        "coreml-score:\(outKey):" +
                        String(format: "%.4f", score)
                    ],
                    inferenceLatencyMs:
                        frame.inferenceLatencyMs)
            },
            inferenceClosure: inferenceClosure)
    }

    /// Box wrapping non-Sendable `MLModel` for use inside the
    /// adapter's Sendable inference closure。Safe because the
    /// closure is only invoked from within the adapter actor's
    /// isolation boundary。
    private struct ChengluPreflightAdapterModelBox:
        @unchecked Sendable
    {
        let model: MLModel
    }
}

extension BASChengluMultiHeadAdapter {
    /// Construct one head per output key bound to real `MLModel`。
    /// Same `MLModel` instance can be wrapped 4 times — each
    /// adapter picks a different `outputKey` from the same
    /// inference output。Real `.mlpackage` uses `features:
    /// MLMultiArray(shape: [1, 43])` input format (chapter 三百三二
    /// fix pattern)。
    public static func make(
        headID: String,
        layerIDPin: BASMotherboardLayer14,
        outputKey: String,
        model: MLModel
    ) -> BASCoreMLLayerHead {
        let outKey = outputKey
        let modelBox = ChengluMultiHeadAdapterModelBox(
            model: model)
        let inferenceClosure:
            @Sendable (BASCoreMLFeatureFrame) async throws
                -> BASCoreMLPredictionFrame
            = { frame in
                let startTime = Date()
                let provider = try BASCoreMLLayerHead
                    .makeMultiArrayFeatureProvider(
                        values: frame.featureValues,
                        orderedKeys: BASChengluFeatureEncoder
                            .canonicalKeyOrder,
                        featureKey: "features")
                let result = try modelBox.model.prediction(
                    from: provider)
                let scores = BASCoreMLLayerHead
                    .extractScores(from: result)
                let elapsed = Date()
                    .timeIntervalSince(startTime) * 1000
                return BASCoreMLPredictionFrame(
                    scores: scores,
                    modelDescription:
                        "ChengluMultiHead_v0:\(outKey)",
                    inferenceLatencyMs: elapsed)
            }
        return BASCoreMLLayerHead(
            headID: headID,
            layerIDPin: layerIDPin,
            featureExtractor: bASChengluFeatureExtractor,
            outputTransformer: { frame, input in
                let score = frame.scores[outKey] ?? 0
                let confidence = BASCoreMLLayerHeadFactory
                    .defaultProbabilityConfidence(score)
                return BASLayerInferenceOutput(
                    layerID: input.layerID,
                    scores: frame.scores,
                    confidence: confidence,
                    reasonCodes: [
                        "coreml-head:chenglu-multihead",
                        "coreml-output-key:\(outKey)",
                        "coreml-score:\(outKey):" +
                        String(format: "%.4f", score)
                    ],
                    inferenceLatencyMs:
                        frame.inferenceLatencyMs)
            },
            inferenceClosure: inferenceClosure)
    }

    private struct ChengluMultiHeadAdapterModelBox:
        @unchecked Sendable
    {
        let model: MLModel
    }
}

extension BASChengluPermitPredictAdapter {
    /// Real `.mlpackage` uses `features: MLMultiArray(shape: [1, 43])`
    /// input format (chapter 三百三二 fix pattern)。
    public static func make(
        headID: String,
        layerIDPin: BASMotherboardLayer14,
        model: MLModel
    ) -> BASCoreMLLayerHead {
        let outKey = outputKey
        let modelBox = ChengluPermitPredictAdapterModelBox(
            model: model)
        let inferenceClosure:
            @Sendable (BASCoreMLFeatureFrame) async throws
                -> BASCoreMLPredictionFrame
            = { frame in
                let startTime = Date()
                let provider = try BASCoreMLLayerHead
                    .makeMultiArrayFeatureProvider(
                        values: frame.featureValues,
                        orderedKeys: BASChengluFeatureEncoder
                            .canonicalKeyOrder,
                        featureKey: "features")
                let result = try modelBox.model.prediction(
                    from: provider)
                let scores = BASCoreMLLayerHead
                    .extractScores(from: result)
                let elapsed = Date()
                    .timeIntervalSince(startTime) * 1000
                return BASCoreMLPredictionFrame(
                    scores: scores,
                    modelDescription:
                        "ChengluPermitPredict_v0",
                    inferenceLatencyMs: elapsed)
            }
        return BASCoreMLLayerHead(
            headID: headID,
            layerIDPin: layerIDPin,
            featureExtractor: bASChengluFeatureExtractor,
            outputTransformer: { frame, input in
                let blockProb = frame.scores[outKey] ?? 0
                let action = blockProb > 0.5
                    ? "block"
                    : "delay"
                let confidence = BASCoreMLLayerHeadFactory
                    .defaultProbabilityConfidence(blockProb)
                return BASLayerInferenceOutput(
                    layerID: input.layerID,
                    scores: frame.scores,
                    confidence: confidence,
                    recommendedAction: action,
                    reasonCodes: [
                        "coreml-head:chenglu-permit-predict",
                        "coreml-policy-hint:\(action)",
                        "coreml-score:\(outKey):" +
                        String(format: "%.4f", blockProb)
                    ],
                    inferenceLatencyMs:
                        frame.inferenceLatencyMs)
            },
            inferenceClosure: inferenceClosure)
    }

    private struct ChengluPermitPredictAdapterModelBox:
        @unchecked Sendable
    {
        let model: MLModel
    }
}

extension BASChengluLengthHeadAdapter {
    /// Real `.mlpackage` uses `features: MLMultiArray(shape: [1, 43])`
    /// input format (chapter 三百三二 fix pattern)。
    public static func make(
        headID: String,
        layerIDPin: BASMotherboardLayer14,
        model: MLModel
    ) -> BASCoreMLLayerHead {
        let outKey = outputKey
        let minLen = minSensibleLength
        let maxLen = maxSensibleLength
        let modelBox = ChengluLengthHeadAdapterModelBox(
            model: model)
        let inferenceClosure:
            @Sendable (BASCoreMLFeatureFrame) async throws
                -> BASCoreMLPredictionFrame
            = { frame in
                let startTime = Date()
                let provider = try BASCoreMLLayerHead
                    .makeMultiArrayFeatureProvider(
                        values: frame.featureValues,
                        orderedKeys: BASChengluFeatureEncoder
                            .canonicalKeyOrder,
                        featureKey: "features")
                let result = try modelBox.model.prediction(
                    from: provider)
                let scores = BASCoreMLLayerHead
                    .extractScores(from: result)
                let elapsed = Date()
                    .timeIntervalSince(startTime) * 1000
                return BASCoreMLPredictionFrame(
                    scores: scores,
                    modelDescription: "ChengluLengthHead_v0",
                    inferenceLatencyMs: elapsed)
            }
        return BASCoreMLLayerHead(
            headID: headID,
            layerIDPin: layerIDPin,
            featureExtractor: bASChengluFeatureExtractor,
            outputTransformer: { frame, input in
                let length = frame.scores[outKey] ?? 0
                let confidence =
                    bASChengluRegressionConfidence(
                        score: length,
                        minSensible: minLen,
                        maxSensible: maxLen)
                return BASLayerInferenceOutput(
                    layerID: input.layerID,
                    scores: frame.scores,
                    confidence: confidence,
                    reasonCodes: [
                        "coreml-head:chenglu-length-head",
                        "coreml-prediction:\(outKey):" +
                        String(format: "%.1f", length)
                    ],
                    inferenceLatencyMs:
                        frame.inferenceLatencyMs)
            },
            inferenceClosure: inferenceClosure)
    }

    private struct ChengluLengthHeadAdapterModelBox:
        @unchecked Sendable
    {
        let model: MLModel
    }
}

extension BASChengluLatencyHeadAdapter {
    /// Real `.mlpackage` uses `features: MLMultiArray(shape: [1, 43])`
    /// input format (chapter 三百三二 fix pattern)。
    public static func make(
        headID: String,
        layerIDPin: BASMotherboardLayer14,
        model: MLModel
    ) -> BASCoreMLLayerHead {
        let outKey = outputKey
        let minLat = minSensibleLatency
        let maxLat = maxSensibleLatency
        let modelBox = ChengluLatencyHeadAdapterModelBox(
            model: model)
        let inferenceClosure:
            @Sendable (BASCoreMLFeatureFrame) async throws
                -> BASCoreMLPredictionFrame
            = { frame in
                let startTime = Date()
                let provider = try BASCoreMLLayerHead
                    .makeMultiArrayFeatureProvider(
                        values: frame.featureValues,
                        orderedKeys: BASChengluFeatureEncoder
                            .canonicalKeyOrder,
                        featureKey: "features")
                let result = try modelBox.model.prediction(
                    from: provider)
                let scores = BASCoreMLLayerHead
                    .extractScores(from: result)
                let elapsed = Date()
                    .timeIntervalSince(startTime) * 1000
                return BASCoreMLPredictionFrame(
                    scores: scores,
                    modelDescription: "ChengluLatencyHead_v0",
                    inferenceLatencyMs: elapsed)
            }
        return BASCoreMLLayerHead(
            headID: headID,
            layerIDPin: layerIDPin,
            featureExtractor: bASChengluFeatureExtractor,
            outputTransformer: { frame, input in
                let latency = frame.scores[outKey] ?? 0
                let confidence =
                    bASChengluRegressionConfidence(
                        score: latency,
                        minSensible: minLat,
                        maxSensible: maxLat)
                return BASLayerInferenceOutput(
                    layerID: input.layerID,
                    scores: frame.scores,
                    confidence: confidence,
                    reasonCodes: [
                        "coreml-head:chenglu-latency-head",
                        "coreml-prediction:\(outKey):" +
                        String(format: "%.1f", latency)
                    ],
                    inferenceLatencyMs:
                        frame.inferenceLatencyMs)
            },
            inferenceClosure: inferenceClosure)
    }

    private struct ChengluLatencyHeadAdapterModelBox:
        @unchecked Sendable
    {
        let model: MLModel
    }
}

#endif
