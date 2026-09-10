// MARK: - BASChengluHintSetReasonCodes — chapter 三百三〇 / M817
//
// Phase F (附录 X) 第九刀:typed audit emission helper for the
// `BASChengluHintSet` (chapter 三百二六) interpreter output。
// Converts populated hint fields into canonical kebab-case
// reason codes hosts emit into their audit ledger。
//
// **0 default behavior change**:helper is pure function, no
// side effects。Hosts that want hint-derived audit codes call
// `BASChengluHintSetReasonCodes.codes(for: hintSet)`。
//
// ## Format spec
//
// Each code follows the prefix doctrine `chenglu-hint:<family>:
// <attr>:<value>`。Cross-references chapter 三百二三
// `BASHostMeshReasonCodes` `mesh-coreml:` prefix doctrine。
//
// Per hint family:
//   - **Preflight**: `chenglu-hint:preflight:route:<afm-route|
//     gemma-route>` + `chenglu-hint:preflight:confidence:<conf>`
//   - **Length**: `chenglu-hint:length:predicted:<int>` +
//     `chenglu-hint:length:confidence:<conf>`
//   - **Latency**: `chenglu-hint:latency:predicted:<int>` +
//     `chenglu-hint:latency:confidence:<conf>`
//   - **Multi-head (intent/emotion/risk/memory_importance)**:
//     `chenglu-hint:<key>:score:<float>` +
//     `chenglu-hint:<key>:confidence:<conf>`
//   - **Permit-predict**: `chenglu-hint:permit-predict:policy:
//     <block|delay>` + `chenglu-hint:permit-predict:confidence:
//     <conf>`
//
// ## Doctrine pins held
//
//   - 不变量 #1 / #2 / #3 全保 — pure-function helper
//   - 红线 7 watcher hint only — emitted codes are observability
//     metadata only;hosts decide whether to act
//   - 单提交口 (L11/L14) 不变 — codes never replace permit/verdict
//   - chapter 二百一一 single-source-of-truth: ONE format spec
//     for hint-derived audit codes
//   - chapter 一百八十五 anti-magic-number: prefix + per-family
//     constants typed-pinned (no inline string concatenation
//     scattered across host code)
//   - chapter 三百二三 (M810) `BASHostMeshReasonCodes`
//     precedent: same kebab-case + colon-separator format

import Foundation
import BASRuntimeCore

/// Typed namespace for hint-set audit code synthesis。
public enum BASChengluHintSetReasonCodes {

    /// Canonical prefix for all hint-derived reason codes。
    public static let prefix: String = "chenglu-hint"

    // MARK: - Per-family codes

    /// Codes for a populated `BASChengluPreflightHint`。
    public static func codes(
        forPreflight hint: BASChengluPreflightHint
    ) -> [String] {
        [
            "\(prefix):preflight:route:" +
                "\(hint.route.rawValue)",
            "\(prefix):preflight:probability:" +
                String(format: "%.4f", hint.probability),
            "\(prefix):preflight:confidence:" +
                "\(hint.confidence.rawValue)"
        ]
    }

    /// Codes for a populated `BASChengluLengthHint`。
    public static func codes(
        forLength hint: BASChengluLengthHint
    ) -> [String] {
        [
            "\(prefix):length:predicted-chars:" +
                String(format: "%.1f",
                    hint.predictedLengthChars),
            "\(prefix):length:confidence:" +
                "\(hint.confidence.rawValue)"
        ]
    }

    /// Codes for a populated `BASChengluLatencyHint`。
    public static func codes(
        forLatency hint: BASChengluLatencyHint
    ) -> [String] {
        [
            "\(prefix):latency:predicted-ms:" +
                String(format: "%.1f",
                    hint.predictedDurationMs),
            "\(prefix):latency:confidence:" +
                "\(hint.confidence.rawValue)"
        ]
    }

    /// Codes for a populated `BASChengluMultiHeadHint`。
    /// `outputKey` becomes part of the code prefix (intent /
    /// emotion / risk / memory_importance) so audit greps can
    /// filter by family。
    public static func codes(
        forMultiHead hint: BASChengluMultiHeadHint
    ) -> [String] {
        [
            "\(prefix):\(hint.outputKey):score:" +
                String(format: "%.4f", hint.score),
            "\(prefix):\(hint.outputKey):confidence:" +
                "\(hint.confidence.rawValue)"
        ]
    }

    /// Codes for a populated `BASChengluPermitPredictHint`。
    public static func codes(
        forPermitPredict hint: BASChengluPermitPredictHint
    ) -> [String] {
        [
            "\(prefix):permit-predict:policy:" +
                "\(hint.policy.rawValue)",
            "\(prefix):permit-predict:block-probability:" +
                String(format: "%.4f", hint.blockProbability),
            "\(prefix):permit-predict:confidence:" +
                "\(hint.confidence.rawValue)"
        ]
    }

    // MARK: - Aggregated codes

    /// Aggregate canonical codes for all populated fields in
    /// a `BASChengluHintSet`。Order: preflight → length →
    /// latency → intent → emotion → risk → memory_importance →
    /// permit-predict。Within each family,codes are emitted in
    /// the order of `codes(for*:)` helpers above (route/predicted
    /// → probability/score → confidence)。Empty result when
    /// hint set has no populated fields。
    public static func codes(
        for hintSet: BASChengluHintSet
    ) -> [String] {
        var all: [String] = []
        if let preflight = hintSet.preflight {
            all.append(contentsOf: codes(
                forPreflight: preflight))
        }
        if let length = hintSet.length {
            all.append(contentsOf: codes(forLength: length))
        }
        if let latency = hintSet.latency {
            all.append(contentsOf: codes(forLatency: latency))
        }
        if let intent = hintSet.intent {
            all.append(contentsOf: codes(
                forMultiHead: intent))
        }
        if let emotion = hintSet.emotion {
            all.append(contentsOf: codes(
                forMultiHead: emotion))
        }
        if let risk = hintSet.risk {
            all.append(contentsOf: codes(
                forMultiHead: risk))
        }
        if let memoryImportance = hintSet.memoryImportance {
            all.append(contentsOf: codes(
                forMultiHead: memoryImportance))
        }
        if let permitPredict = hintSet.permitPredict {
            all.append(contentsOf: codes(
                forPermitPredict: permitPredict))
        }
        return all
    }

    /// Convenience: number of codes a fully-populated
    /// `BASChengluHintSet` emits。Used by tests + diagnostic
    /// hosts for "expected vs actual" pin。
    ///
    /// Computation:
    ///   - preflight: 3 codes (route + probability + confidence)
    ///   - length: 2 codes (predicted-chars + confidence)
    ///   - latency: 2 codes (predicted-ms + confidence)
    ///   - 4× multi-head: 4 × 2 = 8 codes (score + confidence
    ///     each)
    ///   - permit-predict: 3 codes (policy + block-probability
    ///     + confidence)
    /// Total: 3 + 2 + 2 + 8 + 3 = 18 codes
    public static let fullySaturatedCodeCount: Int = 18
}
