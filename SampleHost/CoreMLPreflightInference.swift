// SPDX-License-Identifier: Apache-2.0
// M618 chapter 一百七十七 — CoreML inference helper for
// ChengluPreflight v0 (single-head AFM-success-vs-guardrail
// classifier). Loads `ChengluPreflight_v0.mlmodelc` from app
// bundle, predicts AFM-success probability for a given prompt
// signature, and exposes a typed Swift struct router downstream
// can consume.
//
// This is the FIRST head of the eventual ChengluPreflight 7-head
// model (intent / emotion / risk / memory_importance / reply_style /
// agent_route / wake_policy). Future chapters will:
//   - chapter 一百七十八: add EmotionHead / RiskHead
//   - chapter 一百七十九: add StyleHead / AgentRouter
//   - chapter 一百八十: combine into shared encoder + 7 heads
//   - chapter 一百八十一+: add ChengluMemory.mlpackage (P1)
//   - chapter 一百九十+: add ChengluShadow.mlpackage (P3)
//
// Doctrine pin (chapter 176 §176.19): three-tier protection —
//   substrate (strictest) > AFM (medium) > Gemma (permissive).
// CoreML 不当皇帝, 当神经反射系统; 仅在 LLM body-generation 层
// 决定 AFM vs Gemma routing, 不替代 substrate 的 14 层 audit
// codes + permit decision.

import Foundation
import CoreML

/// 6-dim signature features extracted from a procedurally-generated
/// prompt. Mirrors `SampleHostPromptSignature` but flattened for
/// CoreML featurization.
public struct ChengluPromptFeatures: Equatable, Sendable {
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
        mutationSeed: Int
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

/// Routing decision produced by ChengluPreflight.
public struct ChengluPreflightDecision: Equatable, Sendable, Codable {
    public enum Route: String, Codable, Sendable {
        case afm     // predict AFM will succeed → call AFM
        case gemma   // predict AFM will guardrail-refuse → call Gemma
    }

    /// v0.4 — confidence band classifies prob into 3 zones (after
    /// isotonic calibration LUT). In `uncertain` zone, hybrid
    /// runner calls BOTH LLMs and picks best output.
    ///
    /// Boundaries (post-v0.4 audit; chapter 一百七十七 audit Phase 5):
    /// - `.high`: prob < 0.30 or > 0.70 (confident AFM or Gemma)
    /// - `.medium`: prob ∈ [0.30, 0.40) ∪ (0.60, 0.70] (boundary cases)
    /// - `.uncertain`: prob ∈ [0.40, 0.60] — true ambiguity zone
    ///   (~6% of test set, ~40% accuracy → coin flip ⇒ dual-LLM wins)
    ///
    /// v0.2's narrow [0.45, 0.55] caught only 0.6% of prompts;
    /// v0.4 widened to [0.40, 0.60] after calibration revealed
    /// MLP overconfidence at probability extremes.
    public enum Confidence: String, Codable, Sendable {
        /// prob < 0.30 or > 0.70 (confident routing)
        case high
        /// prob in [0.30, 0.40) or (0.60, 0.70] (boundary)
        case medium
        /// prob in [0.40, 0.60] — model uncertain, both LLMs viable
        case uncertain
    }

    public let afmSuccessProbability: Double
    public let route: Route
    public let confidence: Confidence
    public let modelVersion: String

    public init(
        afmSuccessProbability: Double,
        route: Route,
        confidence: Confidence,
        modelVersion: String
    ) {
        self.afmSuccessProbability = afmSuccessProbability
        self.route = route
        self.confidence = confidence
        self.modelVersion = modelVersion
    }

    /// v0.4 — derive confidence from CALIBRATED probability.
    /// Audit (Phase 5) showed widened uncertain zone [0.30, 0.70]
    /// after isotonic calibration captures truly-uncertain prompts
    /// (~6% of distribution at ~40% accuracy — close to coin flip,
    /// dual-LLM voting net wins).
    public static func confidence(forProb p: Double) -> Confidence {
        if p < 0.30 || p > 0.70 { return .high }
        if p < 0.40 || p > 0.60 { return .medium }
        return .uncertain  // [0.40, 0.60]
    }
}

/// Errors surfaced from the inference path.
public enum ChengluPreflightError: Error, LocalizedError {
    case modelMissingFromBundle
    case modelLoadFailed(String)
    case predictionFailed(String)
    case unexpectedOutput(String)

    public var errorDescription: String? {
        switch self {
        case .modelMissingFromBundle:
            return "ChengluPreflight_v0.mlmodelc not found in app bundle"
        case .modelLoadFailed(let m):
            return "Failed to load model: \(m)"
        case .predictionFailed(let m):
            return "Prediction failed: \(m)"
        case .unexpectedOutput(let m):
            return "Unexpected output: \(m)"
        }
    }
}

/// Lazy-loaded singleton wrapper around the compiled model.
///
/// Doctrine: this loader is **read-only at runtime** (not modified,
/// not retrained on-device). Future chapters extending this to a
/// 7-head shared encoder will use a different MLModel, but the
/// load-once pattern remains.
///
/// MainActor pinned because MLModel is not Sendable; we keep all
/// model interactions on the main actor to satisfy Swift 6 strict
/// concurrency. Predictions are sub-1ms on ANE so this doesn't
/// block UI.
@MainActor
public final class ChengluPreflightInference {
    public static let shared = ChengluPreflightInference()

    private static let modelVersion = "v0.4-mlp-64-32-isotonic-lut"

    // v0.4 — 100-point isotonic calibration LUT, fitted on
    // validation fold (20% of chapter 176 5,088 rows). Applied
    // after MLP raw output. Fixes v0.1 over-confident-on-guardrail
    // bug (p=0.05 → actual 0.353, delta +0.302). After LUT:
    // p=0.05 → actual 0.025, delta +0.016. Brier: 0.065 → 0.054.
    private static let calibrationX: [Double] = [
        0.000, 0.010, 0.020, 0.030, 0.040, 0.051, 0.061, 0.071,
        0.081, 0.091, 0.101, 0.111, 0.121, 0.131, 0.141, 0.152,
        0.162, 0.172, 0.182, 0.192, 0.202, 0.212, 0.222, 0.232,
        0.242, 0.253, 0.263, 0.273, 0.283, 0.293, 0.303, 0.313,
        0.323, 0.333, 0.343, 0.354, 0.364, 0.374, 0.384, 0.394,
        0.404, 0.414, 0.424, 0.434, 0.444, 0.455, 0.465, 0.475,
        0.485, 0.495, 0.505, 0.515, 0.525, 0.535, 0.545, 0.556,
        0.566, 0.576, 0.586, 0.596, 0.606, 0.616, 0.626, 0.636,
        0.646, 0.657, 0.667, 0.677, 0.687, 0.697, 0.707, 0.717,
        0.727, 0.737, 0.747, 0.758, 0.768, 0.778, 0.788, 0.798,
        0.808, 0.818, 0.828, 0.838, 0.848, 0.859, 0.869, 0.879,
        0.889, 0.899, 0.909, 0.919, 0.929, 0.939, 0.949, 0.960,
        0.970, 0.980, 0.990, 1.000,
    ]
    private static let calibrationY: [Double] = [
        0.010, 0.222, 0.353, 0.353, 0.353, 0.353, 0.353, 0.463,
        0.463, 0.463, 0.463, 0.463, 0.463, 0.463, 0.463, 0.463,
        0.463, 0.463, 0.463, 0.463, 0.463, 0.463, 0.463, 0.463,
        0.463, 0.463, 0.463, 0.463, 0.463, 0.463, 0.463, 0.463,
        0.463, 0.463, 0.463, 0.463, 0.463, 0.463, 0.463, 0.463,
        0.463, 0.463, 0.463, 0.463, 0.463, 0.463, 0.463, 0.463,
        0.463, 0.463, 0.463, 0.463, 0.463, 0.463, 0.463, 0.463,
        0.463, 0.463, 0.463, 0.463, 0.463, 0.463, 0.463, 0.463,
        0.463, 0.463, 0.463, 0.463, 0.463, 0.463, 0.463, 0.463,
        0.463, 0.463, 0.463, 0.500, 0.500, 0.500, 0.500, 0.500,
        0.500, 0.500, 0.500, 0.500, 0.500, 0.500, 0.500, 0.700,
        0.700, 0.750, 0.750, 0.778, 0.778, 0.778, 0.780, 0.813,
        0.813, 0.813, 0.813, 0.998,
    ]

    /// Apply isotonic-regression-fitted lookup table to a raw
    /// MLP probability. Linear interpolation between LUT points.
    /// Defense-in-depth: NaN / out-of-[0,1] inputs map to 0.5
    /// (uncertain) rather than propagating undefined behavior.
    private static func applyCalibrationLUT(rawProb: Double) -> Double {
        // Defense-in-depth (chapter 一百七十七 deep review finding #11):
        // NaN propagates through binary search to give NaN output;
        // route to "uncertain" instead.
        guard rawProb.isFinite else { return 0.5 }
        let cx = calibrationX
        let cy = calibrationY
        if rawProb <= cx[0] { return cy[0] }
        if rawProb >= cx[cx.count - 1] { return cy[cx.count - 1] }
        // Binary search for the bracket
        var lo = 0
        var hi = cx.count - 1
        while lo + 1 < hi {
            let mid = (lo + hi) / 2
            if cx[mid] <= rawProb { lo = mid } else { hi = mid }
        }
        let xLo = cx[lo]
        let xHi = cx[hi]
        let yLo = cy[lo]
        let yHi = cy[hi]
        let denom = max(xHi - xLo, 1e-8)
        let t = (rawProb - xLo) / denom
        return min(1.0, max(0.0, yLo + t * (yHi - yLo)))
    }

    // M652 chapter 一百八十二 — single-source via
    // ChengluFeatureEncoder. The 43-dim alphabet that previously
    // lived here is now ChengluFeatureEncoder.{tones, domains,
    // stakes, timeframes, confidants, askShapes,
    // mutationSeedRange, featureCount, encode(_:)}.
    private static let featureCount =
        ChengluFeatureEncoder.featureCount

    private var model: MLModel?

    /// M665 chapter 一百八十四 deep-review fix A24 (LOW): mark
    /// init private so callers can't bypass `.shared` and
    /// accidentally allocate parallel MLModel instances. The
    /// shared singleton holds a lazily-loaded model that's
    /// expensive to duplicate.
    private init() {}

    /// Load the model lazily on first call.
    private func ensureLoaded() throws -> MLModel {
        if let m = model { return m }

        guard let url = Bundle.main.url(
            forResource: "ChengluPreflight_v0",
            withExtension: "mlmodelc")
        else {
            throw ChengluPreflightError.modelMissingFromBundle
        }

        do {
            let config = MLModelConfiguration()
            config.computeUnits = .all  // CPU + GPU + NeuralEngine
            let m = try MLModel(contentsOf: url, configuration: config)
            self.model = m
            return m
        } catch {
            throw ChengluPreflightError.modelLoadFailed(
                "\(error)")
        }
    }

    /// M652 chapter 一百八十二 — delegate to shared encoder.
    private static func featurize(
        _ features: ChengluPromptFeatures
    ) -> [Float] {
        return ChengluFeatureEncoder.encode(features)
    }

    /// Predict AFM success probability + routing decision.
    /// Threshold: prob >= 0.5 → AFM; else → Gemma.
    public func predict(
        features: ChengluPromptFeatures
    ) throws -> ChengluPreflightDecision {
        let model = try ensureLoaded()
        let featureVector = Self.featurize(features)

        // Build MLMultiArray (1, 43) Float32 input
        let shape: [NSNumber] = [1, NSNumber(value: Self.featureCount)]
        guard let inputArray = try? MLMultiArray(
            shape: shape, dataType: .float32)
        else {
            throw ChengluPreflightError.predictionFailed(
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
            throw ChengluPreflightError.predictionFailed(
                "\(error)")
        }

        guard let output = result.featureValue(
            for: "afm_success_probability")
        else {
            throw ChengluPreflightError.unexpectedOutput(
                "no afm_success_probability key")
        }

        let rawProb: Double
        if let arr = output.multiArrayValue {
            rawProb = arr[0].doubleValue
        } else if output.type == .double {
            rawProb = output.doubleValue
        } else {
            throw ChengluPreflightError.unexpectedOutput(
                "afm_success_probability type \(output.type.rawValue)")
        }

        // v0.4 — apply isotonic calibration LUT
        let prob = Self.applyCalibrationLUT(rawProb: rawProb)
        let route: ChengluPreflightDecision.Route =
            prob >= 0.5 ? .afm : .gemma
        let confidence = ChengluPreflightDecision
            .confidence(forProb: prob)
        return ChengluPreflightDecision(
            afmSuccessProbability: prob,
            route: route,
            confidence: confidence,
            modelVersion: Self.modelVersion)
    }

    /// Convenience: returns nil on any error (for non-throwing
    /// caller paths, e.g. bench loop where errors should fall back
    /// rather than abort).
    public func predictOrNil(
        features: ChengluPromptFeatures
    ) -> ChengluPreflightDecision? {
        return try? predict(features: features)
    }
}
