// M648 chapter 一百八十一 — ChengluMultiHead v0 inference helper.
//
// The architectural shift the chapter 一百七十七 plan called for:
// shared TextEncoder + multi-head pattern. Single CoreML model
// with 4 outputs replaces 4 separate models + 4 separate
// inference calls + 4 separate featurize duplications.
//
// Architecture:
//   Input: 43-dim signature one-hot
//   ↓ fc1: 43 → 64 (ReLU)        ← shared encoder layer 1
//   ↓ fc2: 64 → 32 (ReLU)        ← shared encoder layer 2
//   ├─ head_afm:    32 → 1 (sigmoid) → afm_success_prob
//   ├─ head_block:  32 → 1 (sigmoid) → block_prob
//   ├─ head_length: 32 → 1 (linear)  → length_norm (z-space)
//   └─ head_latency:32 → 1 (linear)  → latency_norm (z-space)
//
// Denorm constants (length_mean / length_std / latency_mean /
// latency_std) are saved in user_defined_metadata of the
// .mlpackage and read at load time, then applied at predict time
// to convert z-space outputs back to human-readable chars / ms.
//
// Doctrine pin: prediction NEVER replaces substrate (red line
// #1 先醒再答). All 4 head outputs are observability + UI hints;
// substrate.startSession is the load-bearing decision.

import Foundation
#if canImport(CoreML)
import CoreML
#endif

/// Bundle of all 4 head predictions returned in one inference call.
public struct ChengluMultiHeadPrediction: Sendable, Codable, Equatable {
    /// Sigmoid output: P(AFM call returns "ok"). >= 0.5 → AFM.
    public let afmSuccessProbability: Double
    /// Sigmoid output: P(substrate routes to .block). >= 0.5 → block.
    public let blockProbability: Double
    /// Predicted AFM body length in characters (denormalized).
    public let predictedBodyLength: Double
    /// Predicted AFM duration in milliseconds (denormalized).
    public let predictedDurationMs: Double
    /// Model identifier.
    public let modelVersion: String

    public init(
        afmSuccessProbability: Double,
        blockProbability: Double,
        predictedBodyLength: Double,
        predictedDurationMs: Double,
        modelVersion: String
    ) {
        self.afmSuccessProbability = afmSuccessProbability
        self.blockProbability = blockProbability
        self.predictedBodyLength = predictedBodyLength
        self.predictedDurationMs = predictedDurationMs
        self.modelVersion = modelVersion
    }
}

public enum ChengluMultiHeadError: Error, Equatable {
    case modelMissingFromBundle
    case modelLoadFailed(String)
    case predictionFailed(String)
    case unexpectedOutput(String)
    case missingNormalizationMetadata(String)
}

#if canImport(CoreML)
/// Single-load inference helper for the multi-head model. One
/// MLModel instance, one forward pass per turn, 4 outputs in
/// one call. Replaces 4 separate inference calls in hybrid runner.
@MainActor
public final class ChengluMultiHeadInference {
    public static let shared = ChengluMultiHeadInference()

    private static let modelVersion =
        "v0-multihead-shared-encoder-43-64-32"
    private static let modelResource = "ChengluMultiHead_v0"

    // M652 chapter 一百八十二 — single-source via
    // ChengluFeatureEncoder. THIS chapter shipped what 181 said
    // was pending: featurize alphabet now in one place.
    private static let featureCount =
        ChengluFeatureEncoder.featureCount

    private var model: MLModel?

    /// Z-norm constants read from .mlpackage user_defined_metadata
    /// at first load. We need these to denormalize the regression
    /// outputs (length_norm, latency_norm) back to chars / ms.
    /// Fallback to chapter 175/176 training-set values if metadata
    /// missing (defensive — should always be present in bundled
    /// .mlpackage).
    private var lengthMean: Double = 1360.34
    private var lengthStd: Double = 886.82
    private var latencyMean: Double = 5671.48
    private var latencyStd: Double = 6729.38

    public init() {}

    private func ensureLoaded() throws -> MLModel {
        if let m = model { return m }
        guard let url = Bundle.main.url(
            forResource: Self.modelResource,
            withExtension: "mlmodelc")
        else {
            throw ChengluMultiHeadError.modelMissingFromBundle
        }
        do {
            let config = MLModelConfiguration()
            config.computeUnits = .all
            let m = try MLModel(contentsOf: url, configuration: config)
            // Read normalization constants from
            // user_defined_metadata. CoreML compiled the metadata
            // into the .mlmodelc bundle's metadata.json.
            let meta = m.modelDescription.metadata
            if let userKV = meta[
                MLModelMetadataKey.creatorDefinedKey
            ] as? [String: String] {
                if let s = userKV["length_mean"],
                   let d = Double(s) { lengthMean = d }
                if let s = userKV["length_std"],
                   let d = Double(s) { lengthStd = d }
                if let s = userKV["latency_mean"],
                   let d = Double(s) { latencyMean = d }
                if let s = userKV["latency_std"],
                   let d = Double(s) { latencyStd = d }
            }
            self.model = m
            return m
        } catch {
            throw ChengluMultiHeadError.modelLoadFailed("\(error)")
        }
    }

    /// M652 chapter 一百八十二 — delegate to shared encoder.
    private static func featurize(
        _ features: ChengluPromptFeatures
    ) -> [Float] {
        return ChengluFeatureEncoder.encode(features)
    }

    private func extractScalar(
        _ result: MLFeatureProvider, key: String
    ) throws -> Double {
        guard let output = result.featureValue(for: key) else {
            throw ChengluMultiHeadError.unexpectedOutput(
                "no \(key) key")
        }
        let raw: Double
        if let arr = output.multiArrayValue {
            raw = arr[0].doubleValue
        } else if output.type == .double {
            raw = output.doubleValue
        } else {
            throw ChengluMultiHeadError.unexpectedOutput(
                "\(key) type \(output.type.rawValue)")
        }
        // M627 NaN guard — return 0 fallback if non-finite.
        return raw.isFinite ? raw : 0.0
    }

    /// One forward pass produces all 4 head outputs.
    public func predict(
        features: ChengluPromptFeatures
    ) throws -> ChengluMultiHeadPrediction {
        let model = try ensureLoaded()
        let featureVector = Self.featurize(features)
        let shape: [NSNumber] = [
            1, NSNumber(value: Self.featureCount)
        ]
        guard let inputArray = try? MLMultiArray(
            shape: shape, dataType: .float32)
        else {
            throw ChengluMultiHeadError.predictionFailed(
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
            throw ChengluMultiHeadError.predictionFailed("\(error)")
        }

        let afmProb = try extractScalar(
            result, key: "afm_success_prob")
        let blockProb = try extractScalar(
            result, key: "block_prob")
        let lengthNorm = try extractScalar(
            result, key: "length_norm")
        let latencyNorm = try extractScalar(
            result, key: "latency_norm")

        // Denormalize z-space regression outputs to human units.
        let predictedBodyLength = lengthNorm * lengthStd + lengthMean
        let predictedDurationMs = latencyNorm * latencyStd + latencyMean

        return ChengluMultiHeadPrediction(
            afmSuccessProbability: afmProb,
            blockProbability: blockProb,
            predictedBodyLength: predictedBodyLength,
            predictedDurationMs: predictedDurationMs,
            modelVersion: Self.modelVersion)
    }

    /// Convenience: returns nil on any error.
    public func predictOrNil(
        features: ChengluPromptFeatures
    ) -> ChengluMultiHeadPrediction? {
        return try? predict(features: features)
    }
}
#endif
