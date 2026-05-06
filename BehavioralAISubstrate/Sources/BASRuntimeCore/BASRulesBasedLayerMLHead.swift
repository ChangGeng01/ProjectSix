// MARK: - BASRulesBasedLayerMLHead — chapter 三百一一 / M798
//
// Phase Delta 第二刀:rules-based ML head adapter that conforms to
// `BASLayerMLHead` (chapter 三百, M787)。Serves as cascading-
// bottom for chapter 一百七十七 cascading inference stack — when
// real CoreML/MLX/AFM heads return `.low` confidence or are
// unavailable,this rules-based head provides a deterministic
// fallback。
//
// chapter 一百七十七 vision § 10 typed-pinned cascading inference:
// rules → small ML → big ML → AFM → cloud LLM。This file ships
// the **rules** tier of the cascade in a generic typed wrapper。
// Future Phase Delta cuts (chapter 三百一二+) ship real
// CoreML/MLX adapters into the same `BASLayerMLHead` protocol
// surface,cascading priority puts rules at priority 0 (tried
// first / fallback when others miss confidence floor)。
//
// ## 这一刀 ship 什么
//
// 2 typed primitives:
//
//   - `BASRulesBasedLayerMLHead` — generic wrapper struct
//     conforming to `BASLayerMLHead`. Takes a Sendable closure
//     `(BASLayerInferenceInput) throws -> BASLayerInferenceOutput`
//     + a stable headID + kind = .rules. Hosts construct one
//     per layer with hand-written rules logic.
//   - `BASRulesBasedLayerMLHeadFactory` — convenience namespace
//     with static `make(...)` helpers to construct heads with
//     common rules-based logic patterns (constant confidence,
//     score-by-keyword, etc).
//
// ## Why generic wrapper (not concrete per-layer struct)
//
// chapter 一百七十七 vision describes ~50 ML heads across 14
// layers。Each layer might have 1-5 heads (Preflight Multi-Head /
// Memory Multi-Head / Shadow Multi-Head)。Shipping a separate
// concrete struct per layer would mean 50+ files of mostly
// identical boilerplate。Generic wrapper means hosts compose:
//
//     let intentRules = BASRulesBasedLayerMLHead(
//         headID: "rules.l4.intent",
//         layerIDPin: .l4,
//         rulesLogic: { input in
//             // domain-specific rules
//             return BASLayerInferenceOutput(...)
//         })
//     try await registry.register(
//         head: intentRules, layerID: .l4, priority: 0)
//
// Layer ID is pinned at construction so caller can audit "this
// rules head is intended for L4" — but the rules logic itself
// can ignore it。Mismatched-layer registration is allowed (some
// rules logic is layer-agnostic), but `layerIDPin` flags the
// intended target for diagnostics。
//
// ## Doctrine pins held
//
//   - 不变量 #1 / #2 / #3 全保 — adapter is hint, not gate
//   - 红线 7 watcher hint only — confidence + recommendedAction
//     are hints; layer actor decides whether to act
//   - 单提交口 (L11/L14) 不变 — rules head doesn't issue permits
//   - chapter 二百一一 single-source-of-truth: ONE generic
//     wrapper for rules-tier heads (vs scattered per-layer
//     concrete structs)
//   - chapter 一百八十五 anti-magic-number: kind is typed
//     `.rules`, layerIDPin is typed `BASMotherboardLayer14`
//   - chapter 一百三十 BASLearnabilityClass: rules logic is pure
//     compute, no mutable state — semi-learnable (caller code
//     can be reviewed / replaced)
//   - chapter 三百 BASLayerMLHead protocol: this is the canonical
//     rules-tier conformer

import Foundation

/// Generic typed wrapper that turns a Sendable closure into a
/// `BASLayerMLHead` conformer at the rules tier of cascading
/// inference。
public struct BASRulesBasedLayerMLHead: BASLayerMLHead {

    /// Stable head identifier. Caller assigns at construction.
    public let headID: String

    /// Always `.rules` for this wrapper (cascading inference
    /// stack tier classifier).
    public let kind: BASLayerMLHeadKind = .rules

    /// Layer the rules logic is INTENDED for. Diagnostic hint —
    /// not enforced by infer (rules can ignore the input.layerID
    /// if logic is layer-agnostic).
    public let layerIDPin: BASMotherboardLayer14

    /// Rules logic. Sendable closure transforms typed input to
    /// typed output. Caller's responsibility to make output
    /// fields consistent with `BASLayerInferenceOutput`
    /// invariants (clamping handled by `BASLayerInferenceOutput`
    /// init).
    public let rulesLogic:
        @Sendable (BASLayerInferenceInput) throws
            -> BASLayerInferenceOutput

    public init(
        headID: String,
        layerIDPin: BASMotherboardLayer14,
        rulesLogic:
            @escaping @Sendable
                (BASLayerInferenceInput) throws
                    -> BASLayerInferenceOutput
    ) {
        self.headID = headID
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.layerIDPin = layerIDPin
        self.rulesLogic = rulesLogic
    }

    /// Invokes the rules closure。Throws caller's error if rules
    /// logic throws (preserved as-is, not wrapped)。
    public func infer(
        input: BASLayerInferenceInput
    ) async throws -> BASLayerInferenceOutput {
        try rulesLogic(input)
    }
}

// MARK: - Convenience factory namespace

/// Common patterns for rules-based ML heads。Hosts compose these
/// instead of writing custom closures for trivial cases。
public enum BASRulesBasedLayerMLHeadFactory {

    /// Always-`.high`-confidence head returning a fixed hint。
    /// Useful as a no-op cascade fallback or test fixture。
    public static func makeConstant(
        headID: String,
        layerIDPin: BASMotherboardLayer14,
        recommendedAction: String? = nil,
        reasonCodes: [String] = []
    ) -> BASRulesBasedLayerMLHead {
        BASRulesBasedLayerMLHead(
            headID: headID,
            layerIDPin: layerIDPin
        ) { input in
            BASLayerInferenceOutput(
                layerID: input.layerID,
                confidence: .high,
                recommendedAction: recommendedAction,
                reasonCodes: reasonCodes,
                inferenceLatencyMs: 0)
        }
    }

    /// Always-`.unknown`-confidence head — forces cascade
    /// fallthrough。Useful as a diagnostic insertion point or
    /// when caller wants to wire a slot that never matches。
    public static func makeAlwaysFallthrough(
        headID: String,
        layerIDPin: BASMotherboardLayer14
    ) -> BASRulesBasedLayerMLHead {
        BASRulesBasedLayerMLHead(
            headID: headID,
            layerIDPin: layerIDPin
        ) { input in
            BASLayerInferenceOutput(
                layerID: input.layerID,
                confidence: .unknown,
                reasonCodes: [
                    "rules-fallthrough:\(headID)"
                ],
                inferenceLatencyMs: 0)
        }
    }

    /// Score-by-keyword head:returns `.high` confidence when any
    /// keyword in `keywords` appears in `input.featureRef`,
    /// `.low` otherwise。Hosts use this as the simplest possible
    /// rules-tier classifier。Keyword match is case-insensitive。
    public static func makeKeywordMatcher(
        headID: String,
        layerIDPin: BASMotherboardLayer14,
        keywords: [String],
        recommendedActionOnMatch: String? = nil
    ) -> BASRulesBasedLayerMLHead {
        // Clean + lowercase keyword set at construction time so
        // each invocation doesn't re-process.
        let cleanedKeywords = Set(
            keywords
                .map { $0.lowercased()
                    .trimmingCharacters(
                        in: .whitespacesAndNewlines)
                }
                .filter { !$0.isEmpty })
        return BASRulesBasedLayerMLHead(
            headID: headID,
            layerIDPin: layerIDPin
        ) { input in
            let lowered = input.featureRef.lowercased()
            let matched = cleanedKeywords.first { keyword in
                lowered.contains(keyword)
            }
            if let keyword = matched {
                return BASLayerInferenceOutput(
                    layerID: input.layerID,
                    scores: ["matched": 1.0],
                    confidence: .high,
                    recommendedAction: recommendedActionOnMatch,
                    reasonCodes: [
                        "rules-keyword-match:\(keyword)"
                    ],
                    inferenceLatencyMs: 0)
            }
            return BASLayerInferenceOutput(
                layerID: input.layerID,
                scores: ["matched": 0.0],
                confidence: .low,
                reasonCodes: [
                    "rules-keyword-no-match"
                ],
                inferenceLatencyMs: 0)
        }
    }
}
