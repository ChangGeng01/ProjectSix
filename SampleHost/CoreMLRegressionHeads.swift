// M638-M641 chapter 一百八十 — ChengluLength + ChengluLatency
// regression heads (3rd + 4th meridian points).
//
// Together with ChengluPreflight v0.4 (1st head, AFM-vs-Gemma
// router) and ChengluPermitPredict v0 (2nd head, block-vs-delay
// policy cache), this brings the meridian network to 4/18 points.
//
// What these heads predict (from same 43-dim signature one-hot):
// - ChengluLengthHead: AFM body length in characters (regression)
// - ChengluLatencyHead: AFM duration in milliseconds (regression)
//
// Honest empirical context (chapter 176 5,088 rows):
// - Length head: MAE 479 chars / R² 0.545 (36% better than mean
//   predictor baseline)
// - Latency head: MAE 2091 ms / R² 0.511 (32% better than baseline)
//
// These are real regressions with non-deterministic targets (AFM
// sampling, network jitter). Don't expect 100% — expect "useful
// pre-warm hints" for UI. Doctrine pin: prediction is observability,
// substrate decides authoritatively (red line: 不变量 #1 先醒再答).

import Foundation
#if canImport(CoreML)
import CoreML
#endif

/// Output of a regression head.
public struct ChengluRegressionPrediction: Sendable, Codable, Equatable {
    /// Predicted scalar value.
    public let predicted: Double
    /// Model identifier ("v0-mlp-64-32-mse").
    public let modelVersion: String

    public init(predicted: Double, modelVersion: String) {
        self.predicted = predicted
        self.modelVersion = modelVersion
    }
}

public enum ChengluRegressionError: Error, Equatable {
    case modelMissingFromBundle(String)
    case modelLoadFailed(String)
    case predictionFailed(String)
    case unexpectedOutput(String)
}

#if canImport(CoreML)
/// Shared helpers for both regression heads. We DON'T duplicate
/// featurize logic — both heads use the same 43-dim signature
/// one-hot as ChengluPreflight v0.4 and ChengluPermitPredict v0.
///
/// **Why a shared file**: Length and Latency heads share input
/// schema, model architecture (MLP 64,32), error types, and most
/// inference plumbing. Only differing in:
/// - the .mlpackage name
/// - the output feature key ("body_length" vs "duration_ms")
///
/// Splitting into two separate helper files would duplicate ~200
/// lines. Sharing here is a step toward chapter 一百八十一+ shared
/// encoder refactor where ALL heads will share even more.
@MainActor
public final class ChengluRegressionHeadInference {
    public static let lengthHead = ChengluRegressionHeadInference(
        modelResource: "ChengluLengthHead_v0",
        outputKey: "body_length",
        modelVersion: "length-v0-mlp-64-32-mse")

    public static let latencyHead = ChengluRegressionHeadInference(
        modelResource: "ChengluLatencyHead_v0",
        outputKey: "duration_ms",
        modelVersion: "latency-v0-mlp-64-32-mse")

    // M652 chapter 一百八十二 — single-source via
    // ChengluFeatureEncoder.
    private static let featureCount =
        ChengluFeatureEncoder.featureCount

    private let modelResource: String
    private let outputKey: String
    private let modelVersion: String
    private var model: MLModel?

    public init(
        modelResource: String,
        outputKey: String,
        modelVersion: String
    ) {
        self.modelResource = modelResource
        self.outputKey = outputKey
        self.modelVersion = modelVersion
    }

    private func ensureLoaded() throws -> MLModel {
        if let m = model { return m }
        guard let url = Bundle.main.url(
            forResource: modelResource,
            withExtension: "mlmodelc")
        else {
            throw ChengluRegressionError.modelMissingFromBundle(
                modelResource)
        }
        do {
            let config = MLModelConfiguration()
            config.computeUnits = .all
            let m = try MLModel(contentsOf: url, configuration: config)
            self.model = m
            return m
        } catch {
            throw ChengluRegressionError.modelLoadFailed("\(error)")
        }
    }

    /// M652 chapter 一百八十二 — delegate to shared encoder.
    private static func featurize(
        _ features: ChengluPromptFeatures
    ) -> [Float] {
        return ChengluFeatureEncoder.encode(features)
    }

    public func predict(
        features: ChengluPromptFeatures
    ) throws -> ChengluRegressionPrediction {
        let model = try ensureLoaded()
        let featureVector = Self.featurize(features)
        let shape: [NSNumber] = [
            1, NSNumber(value: Self.featureCount)
        ]
        guard let inputArray = try? MLMultiArray(
            shape: shape, dataType: .float32)
        else {
            throw ChengluRegressionError.predictionFailed(
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
            throw ChengluRegressionError.predictionFailed("\(error)")
        }
        guard let output = result.featureValue(for: outputKey) else {
            throw ChengluRegressionError.unexpectedOutput(
                "no \(outputKey) key")
        }
        let raw: Double
        if let arr = output.multiArrayValue {
            raw = arr[0].doubleValue
        } else if output.type == .double {
            raw = output.doubleValue
        } else {
            throw ChengluRegressionError.unexpectedOutput(
                "\(outputKey) type \(output.type.rawValue)")
        }
        // M627 lesson #11 — NaN guard at boundary.
        let predicted = raw.isFinite ? raw : 0.0
        return ChengluRegressionPrediction(
            predicted: predicted,
            modelVersion: modelVersion)
    }

    public func predictOrNil(
        features: ChengluPromptFeatures
    ) -> ChengluRegressionPrediction? {
        return try? predict(features: features)
    }
}
#endif
