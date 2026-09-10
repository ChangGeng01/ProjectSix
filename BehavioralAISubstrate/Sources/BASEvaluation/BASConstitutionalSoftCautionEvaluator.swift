// MARK: - BASConstitutionalSoftCautionEvaluator — chapter 三百五八 / M845
//
// Phase P1 G3 L2 wire-up: substrate-side `BASShadowEvaluating`
// conformer that fires the `boundaryVeil.softCaution[]` gate
// after the LLM produces a response body。Closes the deferred-
// from-M843 G3 L2 work item per the M840 Cognitive OS roadmap。
//
// ## What this is
//
// A typed `BASShadowEvaluating` conformer that implements G3
// Layer 2 (softCaution post-LLM body gate)。
//
// **Pre-evaluator chain**:
//   - Pre-LLM input → BASHostRuntimeEBrainRiskService.gateAction
//     (chapter 三百五七 / M844 fires L1 hardNoGo here)
//   - LLM produces body
//   - Post-LLM body → THIS evaluator fires L2 softCaution
//     (returns `shifted: true` + `postPermitMode: .draftOnly`)
//   - Host coordinator inspects shifted flag + postPermitMode +
//     decides whether to escalate the permit (single commit
//     mouth doctrine — substrate decides;evaluator hints)
//
// ## Construction
//
// Hosts build this from a `BASHostConstitution` like:
//
//     let evaluator = BASConstitutionalSoftCautionEvaluator(
//         softCautionPatterns: hostConstitution?
//             .boundaryVeil.softCaution ?? [])
//
// The evaluator does NOT take a `BASHostConstitution` directly
// because BASEvaluation module does not depend on BASMemory
// (where BASBoundaryVeil lives)。Hosts do the projection from
// `boundaryVeil.softCaution: [String]` themselves。
//
// **Empty pattern list = pass-through evaluator** that always
// returns `.skipped`。This is the ADR-014 OPT-IN doctrine:
// hosts opt in by providing patterns;default empty list = zero
// behavior change vs `BASNoOpShadowEvaluator`。
//
// ## Doctrine pins held
//
//   - 不变量 #1 / #2 / #3 全保 — evaluator returns observation,
//     does NOT mutate runtime state
//   - 红线 7 hint-only — `shifted: true` is the substrate's HINT
//     to the host coordinator;the coordinator decides whether
//     to escalate the permit (chapter 二百六十六 BASShadowEvaluating
//     pure-observability doctrine)
//   - 单提交口 (L11/L14) 不变 — this evaluator is hint-class to
//     the existing post-LLM observer path,never the gate
//   - chapter 二百六十七 / 二百六十八 evaluator strategy precedent —
//     this is the "constitutional-softCaution-v1" strategy
//     alongside the existing substrate-reaudit + ML-backed
//     evaluators
//   - chapter 二百一一 single-source-of-truth — match logic
//     mirrors `BASConstitutionEnforcer.evaluateBodyAgainstSoftCaution`
//     (which lives in BASMemory and isn't visible here);the
//     trivial 5-line containment check is duplicated for module
//     boundary reasons but pinned by tests to behave identically
//   - chapter 一百八十五 anti-magic-number — reason codes via
//     typed factory pattern,version string named
//   - ADR-014 OPT-IN → PROD — empty patterns = `.skipped`,
//     no behavior change

import Foundation
import BASRuntimeCore

/// `BASShadowEvaluating` conformer that fires when the LLM body
/// contains any of the configured `softCaution[]` patterns。
///
/// **Match shape**: case-insensitive substring containment,first-
/// match-wins (mirrors `BASConstitutionEnforcer` doctrine in
/// BASMemory module)。
///
/// **Output on match**:
///   - `shifted = true`
///   - `postPermitMode = "draftOnly"` (raw value of
///     `BASActionPermitMode.draftOnly`,without importing
///     BASPolicy from this module)
///   - `reasonCodes` includes:
///     - `constitution.softCaution:<pattern>` (matched pattern)
///     - `constitution.softCaution.match` (audit anchor)
///     - `evaluator:constitutional-softCaution-v1` (version tag)
///
/// **Output on no-match (or empty patterns)**: `.skipped`
public struct BASConstitutionalSoftCautionEvaluator:
    BASShadowEvaluating
{
    public let evaluatorVersion: String

    /// Soft-caution patterns to match against post-LLM body。
    /// Empty array = no-op evaluator (returns `.skipped`)。
    /// Whitespace-only entries are skipped (defensive against
    /// config typos)。
    public let softCautionPatterns: [String]

    /// Default version tag。Mirrors chapter 二百六十六 evaluator
    /// version naming convention。
    public static let defaultVersion: String =
        "constitutional-softCaution-v1"

    /// Reason code emitted when the evaluator's match fires。
    /// Used as a stable audit anchor (chapter 八十七 raw-value
    /// stability doctrine)。
    public static let matchAnchorCode: String =
        "constitution.softCaution.match"

    /// Permit mode rawValue the evaluator reports on match。
    /// Hardcoded as `"draft_only"` to match
    /// `BASActionPermitMode.draftOnly.rawValue` without importing
    /// BASPolicy。Pinned by tests (BASHostKit-side wiring asserts
    /// rawValue alignment to catch any drift on either side)。
    public static let escalateToPermitMode: String =
        "draft_only"

    public init(
        softCautionPatterns: [String],
        evaluatorVersion: String =
            BASConstitutionalSoftCautionEvaluator
                .defaultVersion
    ) {
        // Pre-trim patterns + drop empties at construction — the
        // evaluate path then doesn't need to re-check on every
        // call (chapter 一百八十五 anti-magic-number — defensive
        // normalization at the boundary)
        self.softCautionPatterns = softCautionPatterns
            .map { $0.trimmingCharacters(
                in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        self.evaluatorVersion = evaluatorVersion
    }

    public func evaluate(
        prompt: String,
        body: String,
        prePermitMode: String,
        sessionRef: String,
        turnRef: String
    ) async -> BASShadowEvaluationResult {
        // Empty patterns → skipped (ADR-014 OPT-IN: no-op when
        // host hasn't configured any softCaution boundaries)
        guard !softCautionPatterns.isEmpty else {
            return BASShadowEvaluationResult.skipped(
                evaluatorVersion: evaluatorVersion)
        }
        // Empty body → skipped (nothing to match against)
        let trimmedBody = body.trimmingCharacters(
            in: .whitespacesAndNewlines)
        guard !trimmedBody.isEmpty else {
            return BASShadowEvaluationResult.skipped(
                evaluatorVersion: evaluatorVersion)
        }
        // First-match-wins (case-insensitive substring)
        let lowered = trimmedBody.lowercased()
        for pattern in softCautionPatterns {
            if lowered.contains(pattern.lowercased()) {
                return BASShadowEvaluationResult(
                    postPermitMode: Self
                        .escalateToPermitMode,
                    postAuditCodeCount: nil,
                    shifted: true,
                    reasonCodes: [
                        "constitution.softCaution:\(pattern)",
                        Self.matchAnchorCode,
                        "evaluator:\(evaluatorVersion)"
                    ],
                    evaluatorVersion: evaluatorVersion)
            }
        }
        // No match — body is clean
        return BASShadowEvaluationResult.skipped(
            evaluatorVersion: evaluatorVersion)
    }
}
