// MARK: - BASChengluCoreMLAdapters — chapter 三百二一 / M808
//
// Phase F (附录 X) 第二刀:5 concrete Chenglu wrappers that
// bridge each existing `.mlpackage` (chapter 一百七十七 work) into
// the typed `BASLayerMLHead` protocol via `BASCoreMLLayerHead`
// (chapter 三百二〇)。Plus `BASChengluFeatureEncoder` providing
// the canonical 43-dim featurization that mirrors `chenglu_
// feature_schema.py` (Python training pipeline)。
//
// chapter 一百七十七 shipped 5 real `.mlpackage` files in
// `SampleHost/`:
//   - `ChengluPreflight_v0.mlpackage` (binary AFM-vs-Gemma router)
//   - `ChengluMultiHead_v0.mlpackage` (4 outputs from shared encoder)
//   - `ChengluPermitPredict_v0.mlpackage` (block-vs-delay)
//   - `ChengluLengthHead_v0.mlpackage` (response length regression)
//   - `ChengluLatencyHead_v0.mlpackage` (response duration regression)
//
// This file ships factory namespaces that construct
// `BASCoreMLLayerHead` instances wrapping each model with the
// correct feature extractor + output transformer for its layer
// slot.
//
// ## Doctrine pins held
//
//   - 不变量 #1 / #2 / #3 全保 — adapters are hint-class only
//   - 红线 7 watcher hint only — recommendedAction is hint;
//     layer coordinator decides whether to act
//   - 单提交口 (L11/L14) 不变 — adapters don't issue permits
//   - chapter 二百一一 single-source-of-truth: ONE feature
//     encoder for all 5 Chenglu adapters
//   - chapter 一百八十一 multi-head shared encoder: ChengluMultiHead
//     adapter pattern (4 distinct heads from 1 model)
//   - chapter 一百七十七 vision § "14 层 × CoreML head mapping":
//     typed encoding of recommended slot doctrine (附录 X §X.2)
//   - chapter 三百二〇 (M807) BASCoreMLLayerHead: this file
//     consumes that adapter

import Foundation
import BASRuntimeCore

#if canImport(CoreML)
import CoreML
#endif

// MARK: - Chenglu prompt signature (typed input value)

/// Canonical Chenglu prompt signature value type。Mirrors
/// `SampleHost.ChengluPromptFeatures` (chapter 一百七十七, M618)
/// but lives in BAS substrate so adapters consume it directly。
///
/// 6 categorical fields + 1 mutation seed → 43-dim one-hot
/// encoding via `BASChengluFeatureEncoder.encode(...)`。
public struct BASChengluPromptSignature: Sendable, Equatable {
    public let tone: String
    public let domain: String
    public let stake: String
    public let timeframe: String
    public let confidant: String
    public let askShape: String
    public let mutationSeed: Int

    public init(
        tone: String,
        domain: String,
        stake: String,
        timeframe: String,
        confidant: String,
        askShape: String,
        mutationSeed: Int = 0
    ) {
        self.tone = tone
        self.domain = domain
        self.stake = stake
        self.timeframe = timeframe
        self.confidant = confidant
        self.askShape = askShape
        self.mutationSeed = mutationSeed
    }
}

// MARK: - Canonical 43-dim feature encoder

/// Single-source 43-dim featurization that mirrors `chenglu_
/// feature_schema.py` (Python training pipeline)。Cross-language
/// parity is verified by `scripts/check_chenglu_schema_parity.py`。
public enum BASChengluFeatureEncoder {

    /// 8 canonical tone categories.
    public static let tones: [String] = [
        "calm", "anxious", "urgent", "grieving",
        "angry", "curious", "hopeful", "neutral"
    ]

    /// 10 canonical domain categories.
    public static let domains: [String] = [
        "medical", "legal", "financial", "technical",
        "social", "emotional", "ethical", "philosophical",
        "practical", "creative"
    ]

    /// 6 canonical stake categories.
    public static let stakes: [String] = [
        "low", "moderate", "high", "critical",
        "irreversible", "non-reversible-after-act"
    ]

    /// 7 canonical timeframe categories.
    public static let timeframes: [String] = [
        "immediate", "urgent", "today", "this-week",
        "this-month", "this-year", "indefinite"
    ]

    /// 4 canonical confidant categories.
    public static let confidants: [String] = [
        "anonymous-ai", "trusted-ai", "professional", "peer"
    ]

    /// 3 canonical askShape categories.
    public static let askShapes: [String] = [
        "question", "request", "statement"
    ]

    /// 5 mutation seed slots (one-hot 0..4)。
    public static let mutationSeedCount: Int = 5

    /// Total feature dimension: 8+10+6+7+4+3+5 = 43。
    public static var totalDimension: Int {
        tones.count +
        domains.count +
        stakes.count +
        timeframes.count +
        confidants.count +
        askShapes.count +
        mutationSeedCount
    }

    /// Canonical ordered list of feature dictionary keys —
    /// MUST match the training-time featurization order so real
    /// `.mlpackage` models receive features in expected positions
    /// (chapter 三百三二 / M819 — added to support real-MLModel
    /// `MLMultiArray(shape: [1, 43])` input format)。
    public static var canonicalKeyOrder: [String] {
        var keys: [String] = []
        keys.reserveCapacity(totalDimension)
        for tone in tones {
            keys.append("tone_\(tone)")
        }
        for domain in domains {
            keys.append("domain_\(domain)")
        }
        for stake in stakes {
            keys.append("stake_\(stake)")
        }
        for timeframe in timeframes {
            keys.append("timeframe_\(timeframe)")
        }
        for confidant in confidants {
            keys.append("confidant_\(confidant)")
        }
        for askShape in askShapes {
            keys.append("askshape_\(askShape)")
        }
        for i in 0..<mutationSeedCount {
            keys.append("mutation_seed_\(i)")
        }
        return keys
    }

    /// Encode a `BASChengluPromptSignature` into a typed
    /// `BASCoreMLFeatureFrame` with 43 keys (one-hot)。
    /// Unknown categorical values produce all-zeros for that
    /// slot (model can detect via row sum)。Out-of-range
    /// `mutationSeed` (< 0 or >= 5) produces all-zeros for the
    /// mutation seed slot。
    public static func encode(
        signature: BASChengluPromptSignature
    ) -> BASCoreMLFeatureFrame {
        var values: [String: Double] = [:]
        for tone in tones {
            values["tone_\(tone)"] =
                tone == signature.tone ? 1.0 : 0.0
        }
        for domain in domains {
            values["domain_\(domain)"] =
                domain == signature.domain ? 1.0 : 0.0
        }
        for stake in stakes {
            values["stake_\(stake)"] =
                stake == signature.stake ? 1.0 : 0.0
        }
        for timeframe in timeframes {
            values["timeframe_\(timeframe)"] =
                timeframe == signature.timeframe
                    ? 1.0 : 0.0
        }
        for confidant in confidants {
            values["confidant_\(confidant)"] =
                confidant == signature.confidant
                    ? 1.0 : 0.0
        }
        for askShape in askShapes {
            values["askshape_\(askShape)"] =
                askShape == signature.askShape ? 1.0 : 0.0
        }
        for i in 0..<mutationSeedCount {
            values["mutation_seed_\(i)"] =
                i == signature.mutationSeed ? 1.0 : 0.0
        }
        return BASCoreMLFeatureFrame(featureValues: values)
    }
}

// MARK: - Helper: parse signature from BASLayerInferenceInput.featureRef

/// Parse the canonical Chenglu signature payload format from
/// `featureRef` string。Format: 7 fields separated by `|`:
/// `tone|domain|stake|timeframe|confidant|askShape|mutationSeed`。
/// Returns nil if the string doesn't match — caller falls back
/// to a default signature。
public func parseBASChengluSignature(
    from featureRef: String
) -> BASChengluPromptSignature? {
    let parts = featureRef.split(separator: "|").map(String.init)
    guard parts.count == 7 else { return nil }
    guard let mutationSeed = Int(parts[6]) else { return nil }
    return BASChengluPromptSignature(
        tone: parts[0],
        domain: parts[1],
        stake: parts[2],
        timeframe: parts[3],
        confidant: parts[4],
        askShape: parts[5],
        mutationSeed: mutationSeed)
}

/// Default fallback signature when `featureRef` doesn't parse。
/// Used for diagnostic + test paths;production callers should
/// always construct typed signatures。
public let bASChengluDefaultSignature = BASChengluPromptSignature(
    tone: "neutral",
    domain: "practical",
    stake: "low",
    timeframe: "indefinite",
    confidant: "trusted-ai",
    askShape: "question",
    mutationSeed: 0)

// MARK: - Shared feature extractor

/// Shared feature extractor used by all 5 Chenglu adapters。
/// Parses signature from `input.featureRef`,encodes via the
/// canonical encoder。
public let bASChengluFeatureExtractor:
    @Sendable (BASLayerInferenceInput) -> BASCoreMLFeatureFrame
    = { input in
    let signature = parseBASChengluSignature(
        from: input.featureRef) ?? bASChengluDefaultSignature
    return BASChengluFeatureEncoder.encode(signature: signature)
}

// MARK: - ChengluPreflight adapter (binary AFM-vs-Gemma router)

/// Factory namespace for `ChengluPreflight_v0.mlpackage`。
/// Wraps the binary classifier into a `BASCoreMLLayerHead`。
///
/// Output transformer maps:
///   - `score > 0.5` → `.afm-route` recommended action
///   - `score <= 0.5` → `.gemma-route` recommended action
///   - confidence via `BASCoreMLLayerHeadFactory.defaultProbability
///     Confidence` (chapter 一百七十七 v0.4 boundaries)
public enum BASChengluPreflightAdapter {

    /// Canonical output key per ChengluPreflight_v0 model.
    public static let outputKey: String =
        "afm_success_probability"

    /// Construct adapter from parametric closure (testable
    /// without `MLModel`)。
    public static func make(
        headID: String,
        layerIDPin: BASMotherboardLayer14,
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

    #if canImport(CoreML)
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
    #endif
}

// MARK: - ChengluMultiHead adapter (shared encoder + 4 outputs)

/// Factory namespace for `ChengluMultiHead_v0.mlpackage` (chapter
/// 一百八十一)。Single MLModel produces multiple output keys;
/// each output gets its own `BASCoreMLLayerHead` instance at a
/// different canonical slot per附录 X §X.2 doctrine。
///
/// **Honest reality (chapter 三百三三 / M820 reality check)**:
/// the currently shipped `ChengluMultiHead_v0.mlpackage` model
/// has output keys `afm_success_prob` / `block_prob` /
/// `length_norm` / `latency_norm` / `verbosity_prob` (a
/// CONSOLIDATED version of preflight + permit + length + latency
/// + verbosity)。
///
/// The constants below (`intentKey`, `emotionKey`, `riskKey`,
/// `memoryImportanceKey`) are **ASPIRATIONAL** — they encode
/// chapter 一百七十七 vision for future trainings (ChengluMemory
/// P1 + Shadow P3 etc.) but no currently shipped model emits
/// these keys。Hosts that pass `outputKey: intentKey` to
/// `make(model:)` against the shipped model will get all-zero
/// scores for that key (because the dictionary lookup misses)。
///
/// **For currently shipped MultiHead consumption**, hosts should
/// pass the real output keys directly via the `outputKey:`
/// parameter (e.g. `"afm_success_prob"`) — `make(model:)` is
/// generic over outputKey already。
///
/// Aspirational canonical mappings (附录 X §X.2):
///   - `intent` → L4.question-type
///   - `emotion` → L6.emotion-classifier
///   - `risk` → L11.risk-scorer
///   - `memory_importance` → L8.importance-scorer
public enum BASChengluMultiHeadAdapter {

    public static let intentKey = "intent"
    public static let emotionKey = "emotion"
    public static let riskKey = "risk"
    public static let memoryImportanceKey = "memory_importance"

    public static let allOutputKeys: [String] = [
        intentKey, emotionKey, riskKey, memoryImportanceKey
    ]

    /// Construct one head per output key (testable variant)。
    public static func make(
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

    #if canImport(CoreML)
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
    #endif
}

// MARK: - ChengluPermitPredict adapter

/// Factory namespace for `ChengluPermitPredict_v0.mlpackage`
/// (block-vs-delay policy classifier)。
public enum BASChengluPermitPredictAdapter {

    public static let outputKey = "block_probability"

    public static func make(
        headID: String,
        layerIDPin: BASMotherboardLayer14,
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

    #if canImport(CoreML)
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
    #endif
}

// MARK: - Regression adapters: confidence based on prediction sanity

/// Map a regression prediction into typed confidence by checking
/// whether the value is finite + within a sensible range。
/// Predictions outside the expected range are flagged as `.low`
/// (model out-of-distribution input)。
public func bASChengluRegressionConfidence(
    score: Double,
    minSensible: Double,
    maxSensible: Double
) -> BASLayerInferenceConfidence {
    guard score.isFinite else { return .unknown }
    if score < minSensible || score > maxSensible {
        return .low
    }
    return .high
}

// MARK: - ChengluLengthHead adapter

/// Factory namespace for `ChengluLengthHead_v0.mlpackage` (response
/// length regression, MAE 479 chars per chapter 一百七十七)。
public enum BASChengluLengthHeadAdapter {

    public static let outputKey = "body_length"
    public static let minSensibleLength: Double = 0
    public static let maxSensibleLength: Double = 50_000

    public static func make(
        headID: String,
        layerIDPin: BASMotherboardLayer14,
        inferenceClosure:
            @escaping @Sendable (BASCoreMLFeatureFrame)
                async throws -> BASCoreMLPredictionFrame
    ) -> BASCoreMLLayerHead {
        let outKey = outputKey
        let minLen = minSensibleLength
        let maxLen = maxSensibleLength
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

    #if canImport(CoreML)
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
    #endif
}

// MARK: - ChengluLatencyHead adapter

/// Factory namespace for `ChengluLatencyHead_v0.mlpackage` (response
/// duration regression, MAE 2091 ms per chapter 一百七十七)。
public enum BASChengluLatencyHeadAdapter {

    public static let outputKey = "duration_ms"
    public static let minSensibleLatency: Double = 0
    public static let maxSensibleLatency: Double = 60_000

    public static func make(
        headID: String,
        layerIDPin: BASMotherboardLayer14,
        inferenceClosure:
            @escaping @Sendable (BASCoreMLFeatureFrame)
                async throws -> BASCoreMLPredictionFrame
    ) -> BASCoreMLLayerHead {
        let outKey = outputKey
        let minLat = minSensibleLatency
        let maxLat = maxSensibleLatency
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

    #if canImport(CoreML)
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
    #endif
}
