// MARK: - BASMLBackedShadowEvaluator + classifier protocol —
//          chapter 二百六十八 / M756
//
// ML-backed shadow evaluator scaffolding — Stage 5 Step 4 of 5.
//
// ## Why this exists
//
// 附录 V chapter 二百六十八 per plan §V.8 is "ML-backed Shadow
// Evaluator (任 side 1st head)". Real model training requires
// real bench data (Stage 3 user-action). The doctrinally clean
// piece is:
//
//   - `BASBodyFeatureClassifying` protocol — abstract contract
//     for "score a body's should-have-been-blocked probability".
//     Real ML conformers (CoreML, MLX, remote) implement this;
//     this file ships a deterministic rules-based default
//     conformer for tests + ephemeral hosts.
//   - `BASMLBackedShadowEvaluator: BASShadowEvaluating` — wraps
//     a classifier + threshold and produces a typed
//     `BASShadowEvaluationResult`. Drop-in for any
//     `BASShadowEvaluating` slot.
//
// Pattern: SampleHost ships ChengluPreflight (real CoreML); this
// BAS-side primitive is the cross-host abstraction. When chapter
// 二百六十 retrain pipeline produces an .mlpackage, hosts wire
// it via a `BASBodyFeatureClassifying` conformer; the evaluator
// composition stays unchanged.
//
// ## Doctrine pins
//
//   - 不变量 #1 / #2 / #3: ML-backed evaluator is observability —
//     the classifier produces a probability; the evaluator
//     translates that into a `shifted: Bool` hint. Never mutates
//     production state.
//   - 红线 7 watcher-only-hint: classifier is a watcher; the
//     host decides whether to act on the hint.
//   - chapter 一百七十八 / M630 closed-loop: ML-backed evaluator
//     parallels substrate-reaudit (chapter 二百六十七) — a
//     different signal source for the same observability slot.
//   - chapter 一百十三 anti-magic-number: every default tunable
//     extracted as `static let default*`.
//   - chapter 二百六十六 / M748: protocol contract from
//     `BASShadowEvaluating.swift`; this file is one conformer.

import Foundation
import BASRuntimeCore

// MARK: - BASBodyFeatureClassifying

/// Abstract contract for scoring an LLM body's "should-have-been-
/// blocked" probability. Implementations:
///
///   - `BASRulesBasedBodyFeatureClassifier` (this file) —
///     deterministic rules: body length, marker detection, etc.
///   - Real CoreML conformer — wraps an `MLModel` shipped from
///     Stage 3 retrain pipeline (chapter 二百五十八+).
///   - Remote LLM conformer — calls a moderation API.
public protocol BASBodyFeatureClassifying: Sendable {
    /// Stable classifier version string. Surfaced in the
    /// evaluator's `evaluatorVersion` for forensic audit.
    var classifierVersion: String { get }

    /// Probability that the body should have been blocked,
    /// ∈ [0, 1]. 0 = body is safe; 1 = body should have been
    /// blocked. Conformers MUST clamp output to [0, 1] (the
    /// evaluator does NOT re-clamp).
    func classifyBlockedProbability(
        prompt: String,
        body: String
    ) async -> Double
}

// MARK: - BASRulesBasedBodyFeatureClassifier

/// Deterministic rules-based default conformer. Real ML
/// conformers (CoreML / MLX / remote) replace this for production
/// use; this stays as test fixture + ephemeral-host fallback.
///
/// Rules (intentionally simple, anti-magic-number constants):
///
///   - Body length > `unsafeLengthThreshold` (default 10_000) →
///     `unsafeLengthScore` (default 0.85). Pathologically long
///     LLM outputs are a known prompt-injection / runaway
///     surface.
///   - Body contains forbidden substrings (default empty;
///     operator-supplied) → `forbiddenSubstringScore` (default
///     0.95).
///   - Body length below `safeMinLength` (default 4) → `safeShortScore`
///     (default 0.10) — too short to carry risky content.
///   - Default → `baselineScore` (default 0.30) — conservative
///     "uncertain, lean safe" baseline.
public struct BASRulesBasedBodyFeatureClassifier:
    BASBodyFeatureClassifying
{
    public static let defaultUnsafeLengthThreshold: Int = 10_000
    public static let defaultUnsafeLengthScore: Double = 0.85
    public static let defaultForbiddenSubstringScore: Double = 0.95
    public static let defaultSafeMinLength: Int = 4
    public static let defaultSafeShortScore: Double = 0.10
    public static let defaultBaselineScore: Double = 0.30
    public static let defaultClassifierVersion = "rules-v1"

    public let classifierVersion: String

    public let unsafeLengthThreshold: Int
    public let unsafeLengthScore: Double
    public let forbiddenSubstrings: [String]
    public let forbiddenSubstringScore: Double
    public let safeMinLength: Int
    public let safeShortScore: Double
    public let baselineScore: Double

    public init(
        classifierVersion: String =
            BASRulesBasedBodyFeatureClassifier
                .defaultClassifierVersion,
        unsafeLengthThreshold: Int =
            BASRulesBasedBodyFeatureClassifier
                .defaultUnsafeLengthThreshold,
        unsafeLengthScore: Double =
            BASRulesBasedBodyFeatureClassifier
                .defaultUnsafeLengthScore,
        forbiddenSubstrings: [String] = [],
        forbiddenSubstringScore: Double =
            BASRulesBasedBodyFeatureClassifier
                .defaultForbiddenSubstringScore,
        safeMinLength: Int =
            BASRulesBasedBodyFeatureClassifier
                .defaultSafeMinLength,
        safeShortScore: Double =
            BASRulesBasedBodyFeatureClassifier
                .defaultSafeShortScore,
        baselineScore: Double =
            BASRulesBasedBodyFeatureClassifier
                .defaultBaselineScore
    ) {
        self.classifierVersion = classifierVersion
            .trimmingCharacters(
                in: .whitespacesAndNewlines)
        self.unsafeLengthThreshold = max(1, unsafeLengthThreshold)
        self.unsafeLengthScore = Self.clamp01(unsafeLengthScore)
        // Trim + filter empties so a stray empty string in the
        // operator's denylist doesn't match every body.
        self.forbiddenSubstrings = forbiddenSubstrings
            .map { $0.trimmingCharacters(
                in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        self.forbiddenSubstringScore = Self.clamp01(
            forbiddenSubstringScore)
        self.safeMinLength = max(0, safeMinLength)
        self.safeShortScore = Self.clamp01(safeShortScore)
        self.baselineScore = Self.clamp01(baselineScore)
    }

    public func classifyBlockedProbability(
        prompt: String,
        body: String
    ) async -> Double {
        // Order matters: forbidden-substring check fires highest
        // (most confident block signal), then length checks,
        // then baseline.
        for forbidden in forbiddenSubstrings {
            if body.contains(forbidden) {
                return forbiddenSubstringScore
            }
        }
        if body.count > unsafeLengthThreshold {
            return unsafeLengthScore
        }
        if body.count < safeMinLength {
            return safeShortScore
        }
        return baselineScore
    }

    fileprivate static func clamp01(_ value: Double) -> Double {
        if value.isNaN { return 0 }
        return min(1.0, max(0.0, value))
    }
}

// MARK: - BASMLBackedShadowEvaluator

/// `BASShadowEvaluating` conformer that wraps a body-feature
/// classifier + threshold. Real CoreML-backed conformers replace
/// the rules-based classifier for production use; this evaluator
/// stays unchanged.
public struct BASMLBackedShadowEvaluator: BASShadowEvaluating {
    public static let defaultBlockedProbabilityThreshold: Double =
        0.5

    public let evaluatorVersion: String

    public let classifier: any BASBodyFeatureClassifying
    public let blockedProbabilityThreshold: Double

    public init(
        classifier: any BASBodyFeatureClassifying,
        blockedProbabilityThreshold: Double =
            BASMLBackedShadowEvaluator
                .defaultBlockedProbabilityThreshold,
        evaluatorVersion: String? = nil
    ) {
        self.classifier = classifier
        self.blockedProbabilityThreshold =
            Self.clamp01(blockedProbabilityThreshold)
        if let supplied = evaluatorVersion?
            .trimmingCharacters(
                in: .whitespacesAndNewlines),
            !supplied.isEmpty
        {
            self.evaluatorVersion = supplied
        } else {
            // Auto-derive from classifier version.
            self.evaluatorVersion =
                "ml-backed:\(classifier.classifierVersion)"
        }
    }

    public func evaluate(
        prompt: String,
        body: String,
        prePermitMode: String,
        sessionRef: String,
        turnRef: String
    ) async -> BASShadowEvaluationResult {
        // Empty body → skipped (parity with substrate-reaudit
        // conformer).
        guard !body.isEmpty else {
            return BASShadowEvaluationResult.skipped(
                evaluatorVersion: evaluatorVersion)
        }

        let probability = await classifier
            .classifyBlockedProbability(
                prompt: prompt, body: body)
        let clampedProb = Self.clamp01(probability)
        let shifted = clampedProb >= blockedProbabilityThreshold

        // Build typed reason codes for forensic audit.
        var reasonCodes: [String] = [
            "ml-backed:probability:" +
                String(format: "%.3f", clampedProb),
            "ml-backed:threshold:" +
                String(format: "%.3f", blockedProbabilityThreshold),
            "ml-backed:classifier:\(classifier.classifierVersion)"
        ]
        // postPermitMode: the evaluator infers "if probability
        // ≥ threshold AND prePermitMode == answer, the substrate
        // would have shifted to block". The substrate is still
        // the arbiter — this is just a hint.
        let postPermitMode: String?
        if shifted {
            postPermitMode = "block"
            reasonCodes.append(
                "ml-backed:shifted:from-\(prePermitMode):to-block")
        } else {
            // shifted=false → no permit-mode change inferred.
            // Keep nil so callers can distinguish "no shift
            // inferred" from "shifted to a specific mode".
            postPermitMode = nil
        }

        return BASShadowEvaluationResult(
            postPermitMode: postPermitMode,
            postAuditCodeCount: nil,
            shifted: shifted,
            reasonCodes: reasonCodes,
            evaluatorVersion: evaluatorVersion)
    }

    fileprivate static func clamp01(_ value: Double) -> Double {
        if value.isNaN { return 0 }
        return min(1.0, max(0.0, value))
    }
}
