// MARK: - BASShadowEvaluateThenUpgrade — chapter 三百六七 / M854
//
// Phase P1 G3 L2 + G7 active-fire composer。Wraps M845 (`BAS
// ConstitutionalSoftCautionEvaluator` shadow evaluator) + M846
// (`BASShadowResultPermitUpgrader` permit upgrader) into a
// single async call so hosts get "evaluate body → decide upgrade
// → apply upgrade" in one substrate-side primitive。
//
// ## Why this exists
//
// M845 ships the L2 evaluator (body → BASShadowEvaluationResult)。
// M846 ships the upgrader (result → decision)。
// Hosts had to wire both manually:
//
//     let result = await evaluator.evaluate(...)
//     let decision = BASShadowResultPermitUpgrader.decide(
//         currentPermit: pre, shadowResult: result)
//     // ... apply decision
//
// M854 ships the composer that runs both stages in one call:
//
//     let outcome = await BASShadowEvaluateThenUpgrade.run(
//         prompt: prompt,
//         body: llmBody,
//         currentPermit: pre,
//         softCautionPatterns: patterns,
//         enforcer: { mode, from, code in
//             enforcedPermit(targetMode: mode,
//                 from: from, reasonCode: code) })
//     // outcome.upgradedPermit + outcome.evaluation +
//     // outcome.decision available
//
// Single composition site = single audit trail = single test
// surface (chapter 二百一一 single-source-of-truth)。
//
// ## Doctrine pins held
//
//   - 不变量 #1 / #2 / #3 全保 — composer is pure orchestration,
//     no permit/verdict mutation outside the caller's enforcer
//   - 红线 7 hint-only — evaluator is shadow-class;upgrader
//     returns decision-value;composer lets caller apply。No
//     side effects within the composer。
//   - 单提交口 (L11/L14) 不变 — caller's enforcer is the L11
//     gate;composer feeds it
//   - chapter 二百一一 single-source-of-truth — ONE composition
//     for the canonical "evaluate + upgrade" flow
//   - chapter 三百五八 (M845) + 三百五九 (M846) — composer
//     consumes both unchanged,both still callable independently
//   - ADR-014 OPT-IN → PROD — empty patterns / nil enforcer
//     yields current permit unchanged (zero behavior change)

import Foundation
import BASEvaluation
import BASPolicy

// MARK: - Outcome bundle

/// Typed result of running the M854 composer。Includes the
/// raw shadow evaluation,the upgrade decision,and the (possibly
/// upgraded) final permit。
public struct BASShadowEvaluateThenUpgradeOutcome:
    Equatable, Sendable
{
    /// Raw shadow evaluation result from the evaluator stage。
    /// Useful for audit emission + observability even when the
    /// upgrade decision is `.noChange`。
    public let evaluation: BASShadowEvaluationResult

    /// Upgrade decision from the upgrader stage。
    public let decision: BASShadowPermitUpgradeDecision

    /// Final permit。Equal to `currentPermit` when decision is
    /// `.noChange`;equal to caller's enforcer output when
    /// decision is `.escalate`。
    public let upgradedPermit: BASActionPermit

    public init(
        evaluation: BASShadowEvaluationResult,
        decision: BASShadowPermitUpgradeDecision,
        upgradedPermit: BASActionPermit
    ) {
        self.evaluation = evaluation
        self.decision = decision
        self.upgradedPermit = upgradedPermit
    }

    /// Convenience: did the composer actually upgrade the permit?
    public var didUpgrade: Bool {
        switch decision {
        case .noChange: return false
        case .escalate: return true
        }
    }

    /// Combined audit reason codes:evaluator codes + decision
    /// codes + permit's existing codes。Caller emits to audit
    /// ledger。
    public var combinedReasonCodes: [String] {
        var codes = evaluation.reasonCodes
        if case .escalate(_, let upgradeCodes) = decision {
            codes.append(contentsOf: upgradeCodes)
        }
        return codes
    }
}

// MARK: - Composer namespace

/// Pure-orchestration composer。Runs the M845 evaluator → M846
/// upgrader pipeline in one call;caller-supplied `enforcer`
/// applies the upgrade decision。
public enum BASShadowEvaluateThenUpgrade {

    /// Run the canonical 2-stage pipeline:
    ///
    ///   1. M845 evaluator: body + softCautionPatterns →
    ///      BASShadowEvaluationResult
    ///   2. M846 upgrader: currentPermit + result → decision
    ///   3. apply: decision → upgraded permit (via caller's
    ///      enforcer)
    ///
    /// **Caller's enforcer signature**:
    /// `(targetMode, fromPermit, reasonCode) -> BASActionPermit`。
    /// Typically `BASEBrainRuntimeCoordinator.enforcedPermit`。
    ///
    /// **Stateless + deterministic for fixed inputs**: the
    /// evaluator stage is async (BASShadowEvaluating contract)
    /// but the rest is sync。Composer is `async` because of
    /// the evaluator stage。
    ///
    /// - Parameters:
    ///   - prompt: prompt text the LLM saw (forwarded to
    ///     evaluator;most evaluators ignore it)
    ///   - body: post-LLM response body to evaluate
    ///   - prePermitMode: substrate's permit-mode rawValue
    ///     pre-LLM (for shifted detection in evaluator)
    ///   - currentPermit: typed permit issued before evaluator
    ///   - softCautionPatterns: M843 boundaryVeil.softCaution
    ///     entries (caller projects from
    ///     hostConstitution.boundaryVeil.softCaution)
    ///   - sessionRef / turnRef: forensic audit refs
    ///   - evaluatorVersion: optional override for the M845
    ///     evaluator's version tag (default uses M845's
    ///     defaultVersion)
    ///   - enforcer: closure applied on .escalate to construct
    ///     upgraded permit
    /// - Returns: typed outcome bundle with evaluation +
    ///   decision + final permit + audit codes
    public static func run(
        prompt: String,
        body: String,
        prePermitMode: String,
        currentPermit: BASActionPermit,
        softCautionPatterns: [String],
        sessionRef: String = "",
        turnRef: String = "",
        evaluatorVersion: String =
            BASConstitutionalSoftCautionEvaluator
                .defaultVersion,
        enforcer: (
            _ targetMode: BASActionPermitMode,
            _ from: BASActionPermit,
            _ reasonCode: String
        ) -> BASActionPermit
    ) async -> BASShadowEvaluateThenUpgradeOutcome {
        // Stage 1: evaluator (async)
        let evaluator =
            BASConstitutionalSoftCautionEvaluator(
                softCautionPatterns: softCautionPatterns,
                evaluatorVersion: evaluatorVersion)
        let evaluation = await evaluator.evaluate(
            prompt: prompt,
            body: body,
            prePermitMode: prePermitMode,
            sessionRef: sessionRef,
            turnRef: turnRef)
        // Stage 2: upgrader (sync)
        let decision = BASShadowResultPermitUpgrader.decide(
            currentPermit: currentPermit,
            shadowResult: evaluation)
        // Stage 3: apply decision via caller's enforcer
        let upgraded: BASActionPermit
        switch decision {
        case .noChange:
            upgraded = currentPermit
        case .escalate(let targetMode, let reasonCodes):
            let joined = reasonCodes
                .joined(separator: ", ")
            upgraded = enforcer(
                targetMode, currentPermit, joined)
        }
        return BASShadowEvaluateThenUpgradeOutcome(
            evaluation: evaluation,
            decision: decision,
            upgradedPermit: upgraded)
    }
}
