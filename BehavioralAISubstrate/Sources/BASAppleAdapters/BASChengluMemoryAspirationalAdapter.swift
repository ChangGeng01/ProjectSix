// MARK: - BASChengluMemoryAspirationalAdapter — chapter 三百三六 / M823 (residual #6)
//
// Closes the **Swift-side portion** of the chapter 一百七十七 P1
// vision (`ChengluMemory.mlpackage` 5-head training)。
//
// **Honest reality**:no `ChengluMemory_v0.mlpackage` has been
// trained yet。The chapter 一百七十七 vision specifies 5 outputs:
//   - `embedding`        — vector embedding of prompt
//   - `memory_type`      — typed classifier (4-way)
//   - `memory_decay`     — regression: decay rate
//   - `retrieval_rerank` — score: re-rank quality
//   - `conflict_score`   — score: conflict-with-existing memory
//
// Training requires:
//   - Multi-day Python pipeline (sklearn + coremltools)
//   - GPU + corpus
//   - Domain expert review of memory tier doctrine
//   - All explicit external work outside auto-mode safe scope
//
// What this chapter ships:
//   - **Swift-side aspirational adapter** with output key
//     constants matching chapter 一百七十七 vision
//   - When the model eventually trains + ships,this adapter
//     wires it through `BASCoreMLLayerHead.makeMultiArrayFeature
//     Provider` (chapter 三百三二 fix pattern) — same canonical
//     43-dim feature input as the 5 already-shipped Chenglu
//     adapters
//   - Aspirational typed slot mapping per附录 X §X.2 doctrine:
//     L8.importance-scorer ← memory_type (newer, replaces
//     chapter 三百二一 ChengluMultiHead.memory_importance
//     aspirational mapping)
//
// **What this does NOT ship**:
//   - The actual `.mlpackage` binary
//   - Real-model gated E2E test (gated tests would skip until
//     the env var path is set,but right now there's no model
//     to point them at)
//   - Memory-system integration with L8 retrieval logic
//
// ## Doctrine pins held
//
//   - 不变量 #1 / #2 / #3 全保 — adapter is hint-class only
//   - 红线 7 watcher hint only
//   - 单提交口 (L11/L14) 不变
//   - chapter 二百一一 single-source-of-truth: ONE
//     ChengluMemory adapter + 1 canonical output key set
//   - chapter 三百三二 (M819) MLMultiArray fix pattern: this
//     adapter uses `makeMultiArrayFeatureProvider` from day 1
//     (won't repeat the per-key bug)
//   - chapter 三百三三 (M820) aspirational-keys honest doctrine:
//     this adapter is ASPIRATIONAL until model ships;doc
//     comment makes the gap explicit
//   - chapter 一百七十七 P1 vision: typed encoding of expected
//     output keys for forward-compat training

import Foundation
import BASRuntimeCore

#if canImport(CoreML)
import CoreML
#endif

/// Factory namespace for the **forward-compat** ChengluMemory
/// adapter。No `ChengluMemory_v0.mlpackage` is currently shipped。
///
/// **Aspirational output keys** (chapter 一百七十七 P1 vision):
///   - `embedding`        — vector embedding (regression /
///                          MLMultiArray output)
///   - `memory_type`      — 4-way classifier (sigmoid?softmax?)
///   - `memory_decay`     — regression: decay rate
///   - `retrieval_rerank` — score: re-rank quality
///   - `conflict_score`   — score: conflict-with-existing-memory
///
/// **Aspirational slot mapping** (附录 X §X.2 update):
///   - L8.importance-scorer ← `memory_type` (replaces chapter
///     三百二一 ChengluMultiHead.memory_importance aspirational
///     mapping when ChengluMemory ships)
///
/// **Today's reality**:adapter shipped with `make(model:)`
/// factory ready,but no shipped model has these output keys。
/// Hosts that want to test the adapter against a stub closure
/// can do so;real-model E2E gated tests will activate when
/// the env var `QINAO_CHENGLU_MEMORY_PATH` points to a real
/// trained model。
public enum BASChengluMemoryAspirationalAdapter {

    // MARK: - Aspirational output key constants

    public static let embeddingKey: String = "embedding"
    public static let memoryTypeKey: String = "memory_type"
    public static let memoryDecayKey: String = "memory_decay"
    public static let retrievalRerankKey: String =
        "retrieval_rerank"
    public static let conflictScoreKey: String =
        "conflict_score"

    public static let allOutputKeys: [String] = [
        embeddingKey,
        memoryTypeKey,
        memoryDecayKey,
        retrievalRerankKey,
        conflictScoreKey
    ]

    /// Total aspirational output count (5 per chapter 一百七十七
    /// P1 vision)。
    public static let outputCount: Int = 5

    // MARK: - Closure-based factory (testable today)

    /// Construct adapter from parametric closure (testable
    /// without `MLModel`)。Tests use this path with stub
    /// closures since no real `ChengluMemory_v0.mlpackage`
    /// exists today。
    public static func makeWithClosure(
        headID: String,
        layerIDPin: BASMotherboardLayer14,
        outputKey: String,
        inferenceClosure:
            @escaping @Sendable (BASCoreMLFeatureFrame)
                async throws -> BASCoreMLPredictionFrame
    ) -> BASCoreMLLayerHead {
        let outKey = outputKey
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
                        "coreml-head:chenglu-memory-" +
                        "aspirational",
                        "coreml-output-key:\(outKey)",
                        "coreml-score:\(outKey):" +
                        String(format: "%.4f", score)
                    ],
                    inferenceLatencyMs:
                        frame.inferenceLatencyMs)
            },
            inferenceClosure: inferenceClosure)
    }

    #if canImport(CoreML)

    /// Construct adapter bound to a real `MLModel` — once
    /// `ChengluMemory_v0.mlpackage` is trained + bundled。
    /// Uses chapter 三百三二's `makeMultiArrayFeatureProvider`
    /// path with canonical 43-dim feature shape (matches the
    /// 5 already-shipped Chenglu adapters)。
    public static func make(
        headID: String,
        layerIDPin: BASMotherboardLayer14,
        outputKey: String,
        model: MLModel
    ) -> BASCoreMLLayerHead {
        let outKey = outputKey
        let modelBox = ChengluMemoryAdapterModelBox(
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
                        "ChengluMemory_aspirational:" +
                        "\(outKey)",
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
                        "coreml-head:chenglu-memory-" +
                        "aspirational",
                        "coreml-output-key:\(outKey)",
                        "coreml-score:\(outKey):" +
                        String(format: "%.4f", score)
                    ],
                    inferenceLatencyMs:
                        frame.inferenceLatencyMs)
            },
            inferenceClosure: inferenceClosure)
    }

    private struct ChengluMemoryAdapterModelBox:
        @unchecked Sendable
    {
        let model: MLModel
    }

    #endif
}
