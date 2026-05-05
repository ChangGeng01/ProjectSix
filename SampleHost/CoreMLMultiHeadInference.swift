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

/// Bundle of all 5 head predictions returned in one inference call.
public struct ChengluMultiHeadPrediction: Sendable, Codable, Equatable {
    /// Sigmoid output: P(AFM call returns "ok"). >= 0.5 → AFM.
    public let afmSuccessProbability: Double
    /// Sigmoid output: P(substrate routes to .block). >= 0.5 → block.
    public let blockProbability: Double
    /// Predicted AFM body length in characters (denormalized).
    public let predictedBodyLength: Double
    /// Predicted AFM duration in milliseconds (denormalized).
    public let predictedDurationMs: Double
    /// M661 chapter 一百八十三 — 5th head.
    /// Sigmoid output: P(AFM body > 1500 chars). UI hint for
    /// long-response anticipation. Threshold 0.5 → "long".
    /// Demonstrates cheap head-add via shared encoder pattern.
    public let verbosityProbability: Double
    /// Model identifier.
    public let modelVersion: String

    public init(
        afmSuccessProbability: Double,
        blockProbability: Double,
        predictedBodyLength: Double,
        predictedDurationMs: Double,
        verbosityProbability: Double,
        modelVersion: String
    ) {
        self.afmSuccessProbability = afmSuccessProbability
        self.blockProbability = blockProbability
        self.predictedBodyLength = predictedBodyLength
        self.predictedDurationMs = predictedDurationMs
        self.verbosityProbability = verbosityProbability
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
        "v0.1-multihead-shared-encoder-43-64-32-5heads"
    private static let modelResource = "ChengluMultiHead_v0"

    // M652 chapter 一百八十二 — single-source via
    // ChengluFeatureEncoder. THIS chapter shipped what 181 said
    // was pending: featurize alphabet now in one place.
    private static let featureCount =
        ChengluFeatureEncoder.featureCount

    private var model: MLModel?

    /// M687 chapter 一百八十七 — A20 (LOW closed): typed
    /// fallback constants (was: scattered magic numbers in
    /// stored-property defaults). These are chapter 175/176
    /// training-set means/stds; if metadata is stripped from
    /// bundle, M665 fix A4 throws missingNormalizationMetadata
    /// instead of silently using these — but they remain as
    /// safety floor in case future change un-throws.
    private enum Chapter175TrainingSetFallback {
        static let lengthMean: Double = 1360.34
        static let lengthStd: Double = 886.82
        static let latencyMean: Double = 5671.48
        static let latencyStd: Double = 6729.38
    }
    private var lengthMean: Double =
        Chapter175TrainingSetFallback.lengthMean
    private var lengthStd: Double =
        Chapter175TrainingSetFallback.lengthStd
    private var latencyMean: Double =
        Chapter175TrainingSetFallback.latencyMean
    private var latencyStd: Double =
        Chapter175TrainingSetFallback.latencyStd

    /// M665 chapter 一百八十四 fix A24 (LOW) + M683 chapter 一百
    /// 八十七 fix A2 (HIGH): private nonisolated — singleton
    /// enforced + Swift 6 strict mode compatible.
    private nonisolated init() {}

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
            //
            // M665 chapter 一百八十四 deep-review fix A4 + A26
            // (HIGH): metadata cast accepts `[String: Any]` and
            // converts each value via `String(describing:)` —
            // tolerant to NSString vs Swift String quirks. After
            // load, validate each std is positive + finite. Zero
            // std would make denorm a constant predictor (huge
            // observability bug); we throw
            // `missingNormalizationMetadata` instead of falling
            // through to stale chapter 175/176 defaults.
            let meta = m.modelDescription.metadata
            let userKV = (meta[MLModelMetadataKey.creatorDefinedKey]
                as? [String: Any]) ?? [:]
            func stringValue(_ k: String) -> String? {
                guard let v = userKV[k] else { return nil }
                if let s = v as? String { return s }
                return String(describing: v)
            }
            if let s = stringValue("length_mean"),
               let d = Double(s) { lengthMean = d }
            if let s = stringValue("length_std"),
               let d = Double(s) { lengthStd = d }
            if let s = stringValue("latency_mean"),
               let d = Double(s) { latencyMean = d }
            if let s = stringValue("latency_std"),
               let d = Double(s) { latencyStd = d }
            // A4 fail-loud invariant: std must be positive +
            // finite. Zero / NaN std would silently corrupt all
            // regression predictions (denorm becomes constant).
            guard lengthStd > 0, lengthStd.isFinite,
                  latencyStd > 0, latencyStd.isFinite,
                  lengthMean.isFinite, latencyMean.isFinite
            else {
                throw ChengluMultiHeadError
                    .missingNormalizationMetadata(
                        "length_std=\(lengthStd) "
                        + "latency_std=\(latencyStd) "
                        + "length_mean=\(lengthMean) "
                        + "latency_mean=\(latencyMean)")
            }
            self.model = m
            return m
        } catch let mhErr as ChengluMultiHeadError {
            // Re-throw typed errors unchanged.
            throw mhErr
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

    /// M665 chapter 一百八十四 deep-review fix A6 (HIGH):
    /// extractScalar's 0.0 NaN fallback silently routes
    /// classification heads to the negative class. For probability
    /// outputs (sigmoid heads) the doctrinally correct NaN
    /// fallback is 0.5 (uncertain) — matches
    /// `ChengluPreflightInference.applyCalibrationLUT`'s contract.
    /// This wrapper extracts AND remaps NaN→0.5 for sigmoid heads.
    private func extractProbability(
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
        return raw.isFinite ? raw : 0.5
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

        // M665 chapter 一百八十四 deep-review fix A6 (HIGH):
        // sigmoid outputs use extractProbability (NaN→0.5);
        // regression outputs use extractScalar (NaN→0.0).
        let afmProb = try extractProbability(
            result, key: "afm_success_prob")
        let blockProb = try extractProbability(
            result, key: "block_prob")
        let lengthNorm = try extractScalar(
            result, key: "length_norm")
        let latencyNorm = try extractScalar(
            result, key: "latency_norm")
        // M661 chapter 一百八十三 — 5th head extract. M665 chapter
        // 一百八十四 fix A6+M17: only catch the precise
        // "no verbosity_prob key" error from older 4-output v0
        // model — let other errors (malformed type, NaN
        // pathology if any) propagate so they're observable.
        let verbosityProb: Double
        do {
            verbosityProb = try extractProbability(
                result, key: "verbosity_prob")
        } catch ChengluMultiHeadError.unexpectedOutput(let msg)
            where msg == "no verbosity_prob key"
        {
            // Older v0 model (4 outputs); use uncertain fallback.
            verbosityProb = 0.5
        }

        // Denormalize z-space regression outputs to human units.
        // M665 chapter 一百八十四 deep-review fix A5 (HIGH):
        // clamp to >= 0 so a strongly-negative z doesn't yield
        // negative chars / negative ms (physically impossible
        // values would confuse UI consumers).
        let predictedBodyLength = max(
            0.0, lengthNorm * lengthStd + lengthMean)
        let predictedDurationMs = max(
            0.0, latencyNorm * latencyStd + latencyMean)

        return ChengluMultiHeadPrediction(
            afmSuccessProbability: afmProb,
            blockProbability: blockProb,
            predictedBodyLength: predictedBodyLength,
            predictedDurationMs: predictedDurationMs,
            verbosityProbability: verbosityProb,
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
