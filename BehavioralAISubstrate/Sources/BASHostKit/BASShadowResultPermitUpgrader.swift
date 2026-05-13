// MARK: - BASShadowResultPermitUpgrader — chapter 三百五九 / M846
//
// Phase P1 G7 第一刀: typed permit-upgrade decision helper that
// closes the loop on M845 (G3 L2 softCaution shadow evaluator)。
// Closes G7 from chapter 三百五三 / M840 Cognitive OS roadmap。
//
// ## Why this exists
//
// `BASShadowEvaluating` conformers (chapter 二百六十六 / M748) were
// designed as **pure observability** — they emit a result with
// `shifted: Bool` + `postPermitMode: String?` but never mutate
// the runtime permit。
//
// Hosts that want to ACT on shadow results (e.g. escalate permits
// when M845's BASConstitutionalSoftCautionEvaluator says
// `shifted=true, postPermitMode="draft_only"`) needed to roll
// their own translation logic。This file ships the canonical
// translation primitive。
//
// ## Doctrine pin (red line 7 — preserved)
//
// The upgrader does NOT itself decide。It returns a typed
// `BASShadowPermitUpgradeDecision` value;the caller (the
// substrate gate / host coordinator) applies the decision to the
// permit。This keeps:
//   - `BASShadowEvaluating` strict-observation contract intact
//     (evaluators still don't decide)
//   - **Single commit mouth at L11/L14** intact — the gate
//     consumes this decision as one input among many,never
//     bypassed by it
//   - Doctrine: shadow → decision → caller-applies → permit
//     (vs the disallowed shadow → permit-mutation directly)
//
// ## What this ships
//
//   - `BASShadowPermitUpgradeDecision` typed enum (`.noChange` |
//     `.escalate(targetMode:reasonCodes:)`)
//   - `BASShadowResultPermitUpgrader.decide(currentPermit:
//     shadowResult:)` pure-function helper
//   - Edge-case handling: skipped result / nil postPermitMode /
//     unknown rawValue / shifted-but-no-target-mode
//
// ## Doctrine pins held
//
//   - 不变量 #1 / #2 / #3 全保 — pure decision helper,no runtime
//     state mutation
//   - 红线 7 hint-only — shadow-evaluator contract preserved;
//     this helper translates hint to decision-input but is
//     itself hint-class to the caller's gate
//   - 单提交口 (L11/L14) 不变 — caller applies the decision via
//     existing enforcedPermit / equivalent;upgrader returns
//     a value,gate decides
//   - chapter 二百一一 single-source-of-truth — ONE upgrade
//     decision helper,no per-host duplication
//   - chapter 一百八十五 anti-magic-number — decision enum
//     cases + typed reason code constants named
//   - ADR-014 OPT-IN → PROD — `.skipped` / nil postPermitMode
//     produce `.noChange` (zero behavior change)

import Foundation
import BASEvaluation
import BASPolicy

// MARK: - Upgrade decision

/// Typed result of `BASShadowResultPermitUpgrader.decide(...)`。
/// Caller (the substrate gate / host coordinator) inspects this
/// to either keep the current permit or escalate to a new mode。
public enum BASShadowPermitUpgradeDecision:
    Sendable, Equatable, Codable
{
    /// No upgrade needed — caller keeps the current permit。
    /// Emitted when:
    ///   - shadow result is `.skipped`
    ///   - `shifted == false`
    ///   - `postPermitMode` is nil
    ///   - `postPermitMode` is invalid (unknown rawValue)
    case noChange

    /// Caller should upgrade the current permit to `targetMode`,
    /// merging `reasonCodes` from the shadow result into the
    /// new permit's reasonCodes。
    case escalate(
        targetMode: BASActionPermitMode,
        reasonCodes: [String])
}

// MARK: - Upgrader namespace

/// Pure-function helper that translates a `BASShadowEvaluationResult`
/// into a typed permit-upgrade decision。
///
/// **Stateless + deterministic**: same `(currentPermit, shadowResult)`
/// pair always produces the same decision。No I/O,no actor
/// hops,no closures captured。
public enum BASShadowResultPermitUpgrader {

    /// Reason code prefix emitted on escalation。Mirrors existing
    /// permit reason code conventions (chapter 一百八十五 typed
    /// constants doctrine)。
    public static let escalationReasonCodePrefix: String =
        "permit.escalated:shadow"

    /// Audit anchor reason code emitted on every escalation。
    /// Audit walkers grep this to count escalation frequency。
    public static let escalationAnchorCode: String =
        "permit.escalated:shadow.match"

    /// Translate a shadow result into a typed upgrade decision。
    ///
    /// **Decision matrix**:
    ///
    /// | Shadow state | Decision |
    /// |---|---|
    /// | `shifted == false` | `.noChange` |
    /// | `shifted == true, postPermitMode == nil` | `.noChange` |
    /// | `shifted == true, postPermitMode = "<unknown>"` | `.noChange` |
    /// | `shifted == true, postPermitMode = "<valid>"` AND mode == currentPermit.mode | `.noChange` (already at target) |
    /// | `shifted == true, postPermitMode = "<valid>"` AND mode != currentPermit.mode | `.escalate(...)` |
    ///
    /// **reasonCodes on escalation**:
    ///   - All `shadowResult.reasonCodes` (preserves the
    ///     evaluator's audit trail e.g.
    ///     `constitution.softCaution:<pattern>`)
    ///   - `escalationAnchorCode` ("permit.escalated:shadow.match")
    ///   - `escalationReasonCodePrefix:<targetMode>:from:<currentMode>`
    ///     audit trail of the upgrade transition
    ///
    /// - Parameters:
    ///   - currentPermit: pre-shadow permit issued by the gate
    ///   - shadowResult: result from a `BASShadowEvaluating`
    ///     conformer (e.g. M845
    ///     `BASConstitutionalSoftCautionEvaluator`)
    /// - Returns: typed decision (`.noChange` or `.escalate`)
    public static func decide(
        currentPermit: BASActionPermit,
        shadowResult: BASShadowEvaluationResult
    ) -> BASShadowPermitUpgradeDecision {
        // Skipped path — no shifted flag means evaluator chose
        // not to weigh in
        guard shadowResult.shifted else {
            return .noChange
        }
        // Need a target mode to escalate to
        guard let targetRaw = shadowResult.postPermitMode,
              !targetRaw.isEmpty
        else {
            return .noChange
        }
        // Parse to typed mode — defensive against rawValue drift
        guard let targetMode = BASActionPermitMode(
            rawValue: targetRaw)
        else {
            return .noChange
        }
        // Already at target → noop
        guard targetMode != currentPermit.mode else {
            return .noChange
        }
        // Build merged reason codes
        let transitionTag =
            "\(escalationReasonCodePrefix):" +
            "\(targetMode.rawValue):from:" +
            "\(currentPermit.mode.rawValue)"
        let merged = shadowResult.reasonCodes + [
            escalationAnchorCode, transitionTag
        ]
        return .escalate(
            targetMode: targetMode,
            reasonCodes: merged)
    }

    /// Convenience: apply the decision in one step。Caller passes
    /// a closure that knows how to construct the upgraded permit
    /// (typically `BASEBrainRuntimeCoordinator.enforcedPermit(
    /// targetMode:from:reasonCode:)`)。
    ///
    /// On `.noChange`,returns currentPermit unchanged。On
    /// `.escalate`,calls `enforcer` with the typed mode + a
    /// joined reason-code string。
    ///
    /// **Stateless** — no captures,no side effects。
    public static func apply(
        currentPermit: BASActionPermit,
        shadowResult: BASShadowEvaluationResult,
        enforcer: (
            _ targetMode: BASActionPermitMode,
            _ from: BASActionPermit,
            _ reasonCode: String
        ) -> BASActionPermit
    ) -> BASActionPermit {
        switch decide(
            currentPermit: currentPermit,
            shadowResult: shadowResult)
        {
        case .noChange:
            return currentPermit
        case .escalate(let targetMode, let reasonCodes):
            // Caller's enforcer typically takes a single
            // reasonCode string;join the merged audit codes
            // with a comma so they all surface in the upgrade
            let joined = reasonCodes.joined(separator: ", ")
            return enforcer(targetMode, currentPermit, joined)
        }
    }
}
