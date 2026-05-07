// MARK: - BASChengluSweepInterpreter — chapter 三百二六 / M813
//
// Phase F (附录 X) 第六刀:typed interpreter that converts raw
// `BASHostMeshSweepResult` (chapter 三百二五) entries into
// actionable host-side hints。Bridges the gap between raw cascade
// results and "what should the host do" decisions。
//
// **0 default behavior change**:interpreter is pure value-type
// transformation。No registry mutation,no permit/verdict change。
// Hosts that opt into mesh consultation get a typed hint surface
// they can read like any other value type。
//
// ## What this ships
//
//   - `BASChengluHintSet` — typed bundle of optional hints from
//     each canonical Chenglu slot (8 slots distributed across 6
//     layers per附录 X §X.2)
//   - 5 typed hint value types (one per slot family):
//       * `BASChengluPreflightHint` — wake-policy (afm / gemma)
//       * `BASChengluLengthHint` — predicted body length
//       * `BASChengluLatencyHint` — predicted duration
//       * `BASChengluMultiHeadHint` — intent / emotion / risk /
//         memory_importance scores
//       * `BASChengluPermitPredictHint` — block / delay
//   - `BASChengluSweepInterpreter.interpret(_:)` — primary entry
//     point producing `BASChengluHintSet` from sweep result
//   - `BASChengluHintConfidence` — typed confidence carryover
//     mapping `BASLayerInferenceConfidence` to hint-side enum
//
// ## Doctrine pins held
//
//   - 不变量 #1 / #2 / #3 全保 — hints are read-only metadata
//   - 红线 7 watcher hint only — interpreter outputs hints, not
//     verdicts;hosts decide what to do with each hint
//   - 单提交口 (L11/L14) 不变 — `BASChengluPermitPredictHint`
//     is hint, NOT a permit issuer
//   - chapter 二百一一 single-source-of-truth: ONE interpreter
//     for all 5 Chenglu hint families;canonical headID set
//     pinned by `BASChengluCanonicalHeadIDs`
//   - chapter 一百八十五 anti-magic-number: canonical head IDs
//     constants typed-pinned (no inline string matching)
//   - chapter 三百二一 (M808) §X.2 doctrine: 8-slot canonical
//     mapping mirrored exactly in canonical head ID constants

import Foundation
import BASRuntimeCore

// MARK: - Canonical head IDs (mirrors附录 X §X.2 doctrine)

/// Canonical head IDs constants — typed-pinned to avoid drift。
/// Hosts can use these to grep audit codes / construct test
/// fixtures without re-deriving the chenglu.<layer>.<role>
/// format。
public enum BASChengluCanonicalHeadIDs {
    public static let l1WakePolicy =
        "chenglu.l1.wake-policy"
    public static let l1ComputeCostPredictor =
        "chenglu.l1.compute-cost-predictor"
    public static let l4QuestionType =
        "chenglu.l4.question-type"
    public static let l6EmotionClassifier =
        "chenglu.l6.emotion-classifier"
    public static let l8ImportanceScorer =
        "chenglu.l8.importance-scorer"
    public static let l11RiskScorer =
        "chenglu.l11.risk-scorer"
    public static let l11SafetyActionSelector =
        "chenglu.l11.safety-action-selector"
    public static let l12DensityController =
        "chenglu.l12.density-controller"

    /// All 8 canonical head IDs in priority-ordered sequence。
    public static let all: [String] = [
        l1WakePolicy, l1ComputeCostPredictor,
        l4QuestionType, l6EmotionClassifier,
        l8ImportanceScorer, l11RiskScorer,
        l11SafetyActionSelector, l12DensityController
    ]
}

// MARK: - Hint confidence

/// Typed confidence rank for hints。Mirrors `BASLayerInferenceConfidence`
/// 4-case enum but uses kebab-case raw values for cross-tool grep
/// stability。
public enum BASChengluHintConfidence:
    String, Sendable, Equatable, Hashable, Codable, CaseIterable
{
    case high, medium, low, unknown

    /// Build from `BASLayerInferenceConfidence`。Direct 1:1 map。
    public static func from(
        _ confidence: BASLayerInferenceConfidence
    ) -> BASChengluHintConfidence {
        switch confidence {
        case .high: return .high
        case .medium: return .medium
        case .low: return .low
        case .unknown: return .unknown
        }
    }
}

// MARK: - Preflight hint (binary AFM vs Gemma)

public enum BASChengluPreflightRoute:
    String, Sendable, Equatable, Hashable, Codable, CaseIterable
{
    case afm = "afm-route"
    case gemma = "gemma-route"
}

public struct BASChengluPreflightHint:
    Sendable, Equatable, Hashable
{
    public let route: BASChengluPreflightRoute
    public let probability: Double
    public let confidence: BASChengluHintConfidence

    public init(
        route: BASChengluPreflightRoute,
        probability: Double,
        confidence: BASChengluHintConfidence
    ) {
        self.route = route
        self.probability = probability
        self.confidence = confidence
    }
}

// MARK: - Length hint (regression)

public struct BASChengluLengthHint:
    Sendable, Equatable, Hashable
{
    public let predictedLengthChars: Double
    public let confidence: BASChengluHintConfidence

    public init(
        predictedLengthChars: Double,
        confidence: BASChengluHintConfidence
    ) {
        self.predictedLengthChars = predictedLengthChars
        self.confidence = confidence
    }
}

// MARK: - Latency hint (regression)

public struct BASChengluLatencyHint:
    Sendable, Equatable, Hashable
{
    public let predictedDurationMs: Double
    public let confidence: BASChengluHintConfidence

    public init(
        predictedDurationMs: Double,
        confidence: BASChengluHintConfidence
    ) {
        self.predictedDurationMs = predictedDurationMs
        self.confidence = confidence
    }
}

// MARK: - MultiHead hint (4 outputs)

/// One single-output multi-head hint。Wrapping each multi-head
/// output in its own hint lets hosts reason about them
/// independently (e.g. "intent confidence is high but emotion
/// confidence is low → ask clarifying question")。
public struct BASChengluMultiHeadHint:
    Sendable, Equatable, Hashable
{
    public let outputKey: String
    public let score: Double
    public let confidence: BASChengluHintConfidence

    public init(
        outputKey: String,
        score: Double,
        confidence: BASChengluHintConfidence
    ) {
        self.outputKey = outputKey
        self.score = score
        self.confidence = confidence
    }
}

// MARK: - Permit-predict hint (block vs delay)

public enum BASChengluPermitPolicy:
    String, Sendable, Equatable, Hashable, Codable, CaseIterable
{
    case block, delay
}

public struct BASChengluPermitPredictHint:
    Sendable, Equatable, Hashable
{
    public let policy: BASChengluPermitPolicy
    public let blockProbability: Double
    public let confidence: BASChengluHintConfidence

    public init(
        policy: BASChengluPermitPolicy,
        blockProbability: Double,
        confidence: BASChengluHintConfidence
    ) {
        self.policy = policy
        self.blockProbability = blockProbability
        self.confidence = confidence
    }
}

// MARK: - Hint set (aggregated typed bundle)

/// Bundle of optional hints — one slot per Chenglu canonical
/// head。Each field is nil when:
///   - The corresponding slot didn't match in cascade
///   - The cascade fell through (no head met confidence floor)
///   - The registry has no head at that slot
///
/// Hosts that opt into mesh consultation read this bundle to make
/// downstream decisions — preflight nil means use default routing,
/// permit-predict nil means follow normal L11 path,etc。
public struct BASChengluHintSet: Sendable, Equatable {

    public let preflight: BASChengluPreflightHint?
    public let length: BASChengluLengthHint?
    public let latency: BASChengluLatencyHint?
    public let intent: BASChengluMultiHeadHint?
    public let emotion: BASChengluMultiHeadHint?
    public let risk: BASChengluMultiHeadHint?
    public let memoryImportance: BASChengluMultiHeadHint?
    public let permitPredict: BASChengluPermitPredictHint?

    public init(
        preflight: BASChengluPreflightHint? = nil,
        length: BASChengluLengthHint? = nil,
        latency: BASChengluLatencyHint? = nil,
        intent: BASChengluMultiHeadHint? = nil,
        emotion: BASChengluMultiHeadHint? = nil,
        risk: BASChengluMultiHeadHint? = nil,
        memoryImportance: BASChengluMultiHeadHint? = nil,
        permitPredict: BASChengluPermitPredictHint? = nil
    ) {
        self.preflight = preflight
        self.length = length
        self.latency = latency
        self.intent = intent
        self.emotion = emotion
        self.risk = risk
        self.memoryImportance = memoryImportance
        self.permitPredict = permitPredict
    }

    /// Empty set — no hints derived。Returned when sweep is empty。
    public static let empty = BASChengluHintSet()

    /// Number of populated hint fields。Range 0...8。
    public var populatedCount: Int {
        var n = 0
        if preflight != nil { n += 1 }
        if length != nil { n += 1 }
        if latency != nil { n += 1 }
        if intent != nil { n += 1 }
        if emotion != nil { n += 1 }
        if risk != nil { n += 1 }
        if memoryImportance != nil { n += 1 }
        if permitPredict != nil { n += 1 }
        return n
    }

    /// True when every canonical hint is populated。Useful for
    /// the host's "fully-instrumented sweep ran" pin。
    public var isComplete: Bool { populatedCount == 8 }
}

// MARK: - Interpreter

public enum BASChengluSweepInterpreter {

    /// Interpret a sweep result into typed hints。Walks each
    /// layer entry,looks at the matched head ID,decodes the
    /// corresponding hint family from the matched output。
    /// Layers without a matched head contribute no hints。
    ///
    /// - Parameter result: sweep result from chapter 三百二五
    ///   `BASHostRuntime.runMeshSweep(...)`
    /// - Returns: typed hint bundle with one optional field per
    ///   canonical Chenglu slot
    public static func interpret(
        _ result: BASHostMeshSweepResult
    ) -> BASChengluHintSet {
        var preflight: BASChengluPreflightHint?
        var length: BASChengluLengthHint?
        var latency: BASChengluLatencyHint?
        var intent: BASChengluMultiHeadHint?
        var emotion: BASChengluMultiHeadHint?
        var risk: BASChengluMultiHeadHint?
        var memoryImportance: BASChengluMultiHeadHint?
        var permitPredict: BASChengluPermitPredictHint?

        for entry in result.layerEntries {
            let cascade = entry.consultation.cascadeResult
            guard
                let matchedHeadID = cascade.matchedHeadID,
                let output = cascade.matchedOutput
            else { continue }

            let confidence = BASChengluHintConfidence.from(
                output.confidence)

            switch matchedHeadID {
            case BASChengluCanonicalHeadIDs.l1WakePolicy:
                preflight = makePreflightHint(
                    output: output, confidence: confidence)
            case BASChengluCanonicalHeadIDs
                .l1ComputeCostPredictor:
                latency = makeLatencyHint(
                    output: output, confidence: confidence)
            case BASChengluCanonicalHeadIDs.l4QuestionType:
                intent = makeMultiHeadHint(
                    output: output,
                    outputKey: "intent",
                    confidence: confidence)
            case BASChengluCanonicalHeadIDs.l6EmotionClassifier:
                emotion = makeMultiHeadHint(
                    output: output,
                    outputKey: "emotion",
                    confidence: confidence)
            case BASChengluCanonicalHeadIDs.l8ImportanceScorer:
                memoryImportance = makeMultiHeadHint(
                    output: output,
                    outputKey: "memory_importance",
                    confidence: confidence)
            case BASChengluCanonicalHeadIDs.l11RiskScorer:
                risk = makeMultiHeadHint(
                    output: output,
                    outputKey: "risk",
                    confidence: confidence)
            case BASChengluCanonicalHeadIDs
                .l11SafetyActionSelector:
                permitPredict = makePermitPredictHint(
                    output: output, confidence: confidence)
            case BASChengluCanonicalHeadIDs.l12DensityController:
                length = makeLengthHint(
                    output: output, confidence: confidence)
            default:
                // Unknown head ID — don't derive a hint。Host
                // can still inspect raw cascade result for
                // custom head IDs。
                break
            }
        }

        return BASChengluHintSet(
            preflight: preflight,
            length: length,
            latency: latency,
            intent: intent,
            emotion: emotion,
            risk: risk,
            memoryImportance: memoryImportance,
            permitPredict: permitPredict)
    }

    // MARK: - Per-family hint constructors

    private static func makePreflightHint(
        output: BASLayerInferenceOutput,
        confidence: BASChengluHintConfidence
    ) -> BASChengluPreflightHint {
        let prob = output.scores["afm_success_probability"]
            ?? 0
        let route: BASChengluPreflightRoute =
            prob > 0.5 ? .afm : .gemma
        return BASChengluPreflightHint(
            route: route,
            probability: prob,
            confidence: confidence)
    }

    private static func makeLengthHint(
        output: BASLayerInferenceOutput,
        confidence: BASChengluHintConfidence
    ) -> BASChengluLengthHint {
        let len = output.scores["body_length"] ?? 0
        return BASChengluLengthHint(
            predictedLengthChars: len,
            confidence: confidence)
    }

    private static func makeLatencyHint(
        output: BASLayerInferenceOutput,
        confidence: BASChengluHintConfidence
    ) -> BASChengluLatencyHint {
        let dur = output.scores["duration_ms"] ?? 0
        return BASChengluLatencyHint(
            predictedDurationMs: dur,
            confidence: confidence)
    }

    private static func makeMultiHeadHint(
        output: BASLayerInferenceOutput,
        outputKey: String,
        confidence: BASChengluHintConfidence
    ) -> BASChengluMultiHeadHint {
        let score = output.scores[outputKey] ?? 0
        return BASChengluMultiHeadHint(
            outputKey: outputKey,
            score: score,
            confidence: confidence)
    }

    private static func makePermitPredictHint(
        output: BASLayerInferenceOutput,
        confidence: BASChengluHintConfidence
    ) -> BASChengluPermitPredictHint {
        let blockProb = output.scores["block_probability"]
            ?? 0
        let policy: BASChengluPermitPolicy =
            blockProb > 0.5 ? .block : .delay
        return BASChengluPermitPredictHint(
            policy: policy,
            blockProbability: blockProb,
            confidence: confidence)
    }
}
