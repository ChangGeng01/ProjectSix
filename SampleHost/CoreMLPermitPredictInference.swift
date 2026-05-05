// M633-M635 chapter 一百七十九 — ChengluPermitPredict v0
// 2nd CoreML head in the meridian network.
//
// Predicts substrate's permit-mode class (block vs non-block)
// from prompt signature features, BEFORE substrate runs. Used to:
//   1. Pre-warm UI with expected dispatch policy
//   2. Record prediction-vs-actual agreement in JSONL for empirical
//      doctrine-drift detection
//   3. Establish 2-head architecture pattern (will be folded into
//      shared-encoder + multi-head in chapter 一百八十+)
//
// Doctrine pin: prediction NEVER replaces substrate's authority.
// Substrate.startSession ALWAYS runs (red line: 不变量 #1
// 先醒再答). The CoreML inference runs in parallel and is logged
// for analysis only.
//
// Architecture: same MLP(64,32) shape as ChengluPreflight v0.4,
// same 43-dim signature one-hot input. Symmetric body lets future
// shared-encoder refactor lift heads unchanged.

import Foundation
#if canImport(CoreML)
import CoreML
#endif

/// Output of permit-mode prediction.
public struct ChengluPermitPredictDecision: Codable, Sendable, Equatable {
    /// Substrate-block probability ∈ [0,1].
    /// Above 0.5 → predicted `.block`; below → `.delay` / other.
    public let blockProbability: Double

    /// Predicted permit class. Binary in v0; will be multi-class
    /// in v1 once non-adversarial corpus is added (chapter 一百
    /// 八十+).
    public let predictedClass: PredictedClass

    /// Model identifier for downstream analysis.
    public let modelVersion: String

    public enum PredictedClass: String, Codable, Sendable, Equatable {
        /// Predicted substrate will route to `.block`.
        case block
        /// Predicted substrate will NOT route to `.block` (most
        /// likely `.delay` in chapter 176 corpus).
        case nonBlock = "non-block"
    }

    public init(
        blockProbability: Double,
        predictedClass: PredictedClass,
        modelVersion: String
    ) {
        self.blockProbability = blockProbability
        self.predictedClass = predictedClass
        self.modelVersion = modelVersion
    }
}

/// Errors specific to permit-predict inference.
public enum ChengluPermitPredictError: Error, Equatable {
    case modelMissingFromBundle
    case modelLoadFailed(String)
    case predictionFailed(String)
    case unexpectedOutput(String)
}

#if canImport(CoreML)
/// 2nd CoreML head: predicts substrate's permit-mode class.
///
/// MainActor-pinned because MLModel is not Sendable; we keep all
/// load + predict operations on the main actor (sub-1ms per call,
/// no UI blocking concern).
@MainActor
public final class ChengluPermitPredictInference {
    public static let shared = ChengluPermitPredictInference()

    private static let modelVersion = "v0-mlp-64-32-binary-block"

    /// Same 43-dim feature schema as ChengluPreflight v0.4.
    /// Reuses ChengluPromptFeatures from CoreMLPreflightInference
    /// (single source of truth for feature schema across heads).

    private static let featureCount = 43

    private static let tones = [
        "anxious", "authoritative", "vulnerable", "agentic",
        "confused", "grieving", "curious", "angry"
    ]
    private static let domains = [
        "financial", "medical", "relational", "work", "parenting",
        "identity", "ethical", "existential", "trauma", "creative"
    ]
    private static let stakes = [
        "low", "modest", "high", "very-high",
        "irreversible", "non-reversible-after-act"
    ]
    private static let timeframes = [
        "minutes", "hours", "days", "weeks",
        "months", "lifetime", "past-unresolved"
    ]
    private static let confidants = [
        "friend", "expert", "stranger", "decision-system"
    ]
    private static let askShapes = [
        "narrative", "decision-tree", "single-action"
    ]
    private static let mutationSeedRange = 0..<5

    private var model: MLModel?

    public init() {}

    private func ensureLoaded() throws -> MLModel {
        if let m = model { return m }
        guard let url = Bundle.main.url(
            forResource: "ChengluPermitPredict_v0",
            withExtension: "mlmodelc")
        else {
            throw ChengluPermitPredictError.modelMissingFromBundle
        }
        do {
            let config = MLModelConfiguration()
            config.computeUnits = .all
            let m = try MLModel(contentsOf: url, configuration: config)
            self.model = m
            return m
        } catch {
            throw ChengluPermitPredictError.modelLoadFailed(
                "\(error)")
        }
    }

    /// Featurize identical to ChengluPreflight (cross-head shared
    /// schema). If schemas drift, single-source via ChengluPromptFeatures
    /// will be enforced in chapter 一百八十+ shared-encoder refactor.
    private static func featurize(
        _ features: ChengluPromptFeatures
    ) -> [Float] {
        var v: [Float] = []
        v.reserveCapacity(featureCount)
        for t in tones {
            v.append(features.tone == t ? 1.0 : 0.0)
        }
        for d in domains {
            v.append(features.domain == d ? 1.0 : 0.0)
        }
        for s in stakes {
            v.append(features.stake == s ? 1.0 : 0.0)
        }
        for t in timeframes {
            v.append(features.timeframe == t ? 1.0 : 0.0)
        }
        for c in confidants {
            v.append(features.confidant == c ? 1.0 : 0.0)
        }
        for a in askShapes {
            v.append(features.askShape == a ? 1.0 : 0.0)
        }
        for m in mutationSeedRange {
            v.append(features.mutationSeed == m ? 1.0 : 0.0)
        }
        return v
    }

    /// Predict permit-mode class. Threshold 0.5 — block vs non-block.
    public func predict(
        features: ChengluPromptFeatures
    ) throws -> ChengluPermitPredictDecision {
        let model = try ensureLoaded()
        let featureVector = Self.featurize(features)

        let shape: [NSNumber] = [1, NSNumber(value: Self.featureCount)]
        guard let inputArray = try? MLMultiArray(
            shape: shape, dataType: .float32)
        else {
            throw ChengluPermitPredictError.predictionFailed(
                "MLMultiArray init failed")
        }
        for (i, value) in featureVector.enumerated() {
            inputArray[i] = NSNumber(value: value)
        }
        let inputDict: [String: MLFeatureValue] = [
            "features": MLFeatureValue(multiArray: inputArray)
        ]
        let provider = try MLDictionaryFeatureProvider(
            dictionary: inputDict)
        let result: MLFeatureProvider
        do {
            result = try model.prediction(from: provider)
        } catch {
            throw ChengluPermitPredictError.predictionFailed(
                "\(error)")
        }
        guard let output = result.featureValue(
            for: "block_probability")
        else {
            throw ChengluPermitPredictError.unexpectedOutput(
                "no block_probability key")
        }
        let rawProb: Double
        if let arr = output.multiArrayValue {
            rawProb = arr[0].doubleValue
        } else if output.type == .double {
            rawProb = output.doubleValue
        } else {
            throw ChengluPermitPredictError.unexpectedOutput(
                "block_probability type \(output.type.rawValue)")
        }
        // M627 lesson #11 — NaN guard at boundary.
        let prob = rawProb.isFinite ? rawProb : 0.5
        let predicted: ChengluPermitPredictDecision.PredictedClass =
            prob >= 0.5 ? .block : .nonBlock
        return ChengluPermitPredictDecision(
            blockProbability: prob,
            predictedClass: predicted,
            modelVersion: Self.modelVersion)
    }

    /// Convenience: returns nil on error (for hot-loop callers).
    public func predictOrNil(
        features: ChengluPromptFeatures
    ) -> ChengluPermitPredictDecision? {
        return try? predict(features: features)
    }
}
#endif
