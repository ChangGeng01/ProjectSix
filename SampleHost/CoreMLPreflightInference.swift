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

    /// v0.2 — confidence band classifies prob into 3 zones.
    /// In `uncertain` zone, hybrid runner can call BOTH LLMs and
    /// pick best output (instead of single + fallback).
    public enum Confidence: String, Codable, Sendable {
        /// prob >= 0.75 → confident AFM (or <= 0.25 → confident Gemma)
        case high
        /// prob in [0.55, 0.75) or (0.25, 0.45]
        case medium
        /// prob in [0.45, 0.55] — model uncertain, both LLMs viable
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

    /// v0.2 — derive confidence from probability.
    public static func confidence(forProb p: Double) -> Confidence {
        let dist = abs(p - 0.5)
        if dist >= 0.25 { return .high }
        if dist >= 0.05 { return .medium }
        return .uncertain
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

    private static let modelVersion = "v0.1-mlp-64-32"

    // Feature ordering MUST match training script
    // scripts/train_chenglu_preflight_v0.py (43 dims total).
    private static let tones = [
        "anxious", "authoritative", "vulnerable", "agentic",
        "confused", "grieving", "curious", "angry"]
    private static let domains = [
        "financial", "medical", "relational", "work",
        "parenting", "identity", "ethical", "existential",
        "trauma", "creative"]
    private static let stakes = [
        "low", "modest", "high", "very-high",
        "irreversible", "non-reversible-after-act"]
    private static let timeframes = [
        "minutes", "hours", "days", "weeks",
        "months", "lifetime", "past-unresolved"]
    private static let confidants = [
        "friend", "expert", "stranger", "decision-system"]
    private static let askShapes = [
        "narrative", "decision-tree", "single-action"]
    private static let mutationSeedRange = 0..<5

    private static let featureCount =
        tones.count
        + domains.count
        + stakes.count
        + timeframes.count
        + confidants.count
        + askShapes.count
        + mutationSeedRange.count

    private var model: MLModel?

    public init() {}

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

    /// Featurize a `ChengluPromptFeatures` into 43-dim float32
    /// one-hot vector matching the training feature order.
    private static func featurize(
        _ features: ChengluPromptFeatures
    ) -> [Float] {
        var v: [Float] = []
        v.reserveCapacity(Self.featureCount)
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

        let prob: Double
        if let arr = output.multiArrayValue {
            prob = arr[0].doubleValue
        } else if output.type == .double {
            prob = output.doubleValue
        } else {
            throw ChengluPreflightError.unexpectedOutput(
                "afm_success_probability type \(output.type.rawValue)")
        }

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
