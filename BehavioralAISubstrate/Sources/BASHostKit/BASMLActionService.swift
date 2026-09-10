// MARK: - BASMLActionService
// REAL Layer-6 action service deriving rendered output
// from merged choice + risk card + action permit。 Sixth
// active ML-touched layer in the cognitive cascade。
//
// The action service is the brain's "output rendering"
// layer。 The placeholder simply echoed merged choice
// title/summary verbatim,emitting empty alternatives
// and using permit reason codes as explanation codes。
//
// This service uses the upstream cascade signals to
// produce a risk-aware rendered output:
//   - headline: prefixed with risk-aware verb
//     ("PROCEED" / "CONFIRM" / "DECLINE")
//   - body: choice action summary with risk caveat
//     appended when warranted
//   - alternativeActions: populated when verdict is
//     .compare or higher (offers explicit fall-back
//     paths)
//   - explanationCodes: aggregated from permit reason
//     codes + elevated risk factors
//
// **Honest scope**: this is STRUCTURED rendering,not
// generative natural-language production。 Each output
// field is a typed concatenation of upstream signals。
// A "real" action service would compose natural-language
// paragraphs reflecting the candidate's specific content。
// That requires LLM-grade text generation。 For the
// substrate's current scope,structured rendering is
// the right tradeoff: hosts get a rendered output whose
// SHAPE varies meaningfully with the cascade's risk
// signals。

import Foundation
import BASRuntimeCore
import BASPolicy
import BASOrchestration

/// Real action service deriving rendered output from
/// merged choice + risk card + permit。 Replaces
/// BASPlaceholderActionService in cognitive brains that
/// want risk-aware output rendering。
public struct BASMLActionService: BASActionServicing,
    Sendable
{

    /// Named headline-prefix labels by mode。 Stable
    /// across calls so hosts can localize / theme the
    /// prefixes by matching the typed value。
    public enum HeadlinePrefixes {
        public static let answer = "[PROCEED]"
        public static let mirror = "[REFLECT]"
        public static let compare = "[CONFIRM]"
        public static let delay = "[DELAY]"
        public static let block = "[DECLINE]"
        public static let escalate = "[ESCALATE]"
        public static let other = "[ACT]"
    }

    /// Named body-suffix caveats by risk level。 Appended
    /// to the merged-choice action summary to surface
    /// the cascade's risk reasoning to the user。
    public enum BodyCaveats {
        public static let lowRisk = ""
        public static let mediumRisk =
            "  (note: this turn carries moderate risk" +
            " — consider whether you really want this" +
            " before proceeding)"
        public static let highRisk =
            "  (caution: this turn carries elevated" +
            " risk — confirmation is recommended before" +
            " any irreversible step)"
        public static let extremeRisk =
            "  (STOP: this turn carries extreme risk —" +
            " the cognitive cascade recommends declining" +
            " or escalating to a human reviewer)"
    }

    /// Named alternative-action templates。 Hosts use
    /// these as default fall-back options in UI when
    /// the cascade asks for confirmation。
    public enum Alternatives {
        public static let askForClarification =
            "ask for clarification before proceeding"
        public static let suggestSlowdown =
            "slow down — break the request into smaller" +
            " reversible steps"
        public static let escalateToHuman =
            "escalate to human review for safety reasons"
        public static let declineWithExplanation =
            "decline the request — explain why and" +
            " offer a safe alternative"
    }

    public init() {}

    public func render(
        choice: BASMergedChoice,
        riskCard: BASRiskCard,
        permit: BASActionPermit,
        hostContext: BASHostProfile
    ) -> BASRenderedOutput {
        let prefix = Self.headlinePrefix(for: permit.mode)
        let headline = "\(prefix) \(choice.title)"
        let body = "\(choice.actionSummary)" +
            "\(Self.bodyCaveat(for: riskCard.riskLevel))"
        let alternatives = Self.alternativeActions(
            for: riskCard.riskLevel,
            vetoApplied: choice.vetoApplied)
        // Aggregate explanation codes: permit reason
        // codes + risk factors (deduplicated by string
        // identity)。
        var explanationSet = Set<String>()
        var ordered: [String] = []
        for code in permit.reasonCodes {
            if explanationSet.insert(code).inserted {
                ordered.append(code)
            }
        }
        for factor in riskCard.factors {
            if explanationSet.insert(factor).inserted {
                ordered.append(factor)
            }
        }
        return BASRenderedOutput(
            mode: permit.mode,
            headline: headline,
            body: body,
            alternativeActions: alternatives,
            explanationCodes: ordered)
    }

    // MARK: - Static derivation helpers

    public static func headlinePrefix(
        for mode: BASActionPermitMode
    ) -> String {
        switch mode {
        case .answer: return HeadlinePrefixes.answer
        case .mirror: return HeadlinePrefixes.mirror
        case .compare: return HeadlinePrefixes.compare
        case .delay: return HeadlinePrefixes.delay
        case .block: return HeadlinePrefixes.block
        case .escalate: return HeadlinePrefixes.escalate
        case .draftOnly, .localOnly, .replace:
            return HeadlinePrefixes.other
        }
    }

    public static func bodyCaveat(
        for level: BASBrainRiskLevel
    ) -> String {
        switch level {
        case .low: return BodyCaveats.lowRisk
        case .medium: return BodyCaveats.mediumRisk
        case .high: return BodyCaveats.highRisk
        case .extreme: return BodyCaveats.extremeRisk
        }
    }

    /// Produce alternative-action templates appropriate
    /// to the risk level + global veto state。
    public static func alternativeActions(
        for level: BASBrainRiskLevel,
        vetoApplied: Bool
    ) -> [String] {
        if vetoApplied {
            return [Alternatives.declineWithExplanation,
                Alternatives.escalateToHuman]
        }
        switch level {
        case .low:
            return []
        case .medium:
            return [Alternatives.askForClarification]
        case .high:
            return [Alternatives.askForClarification,
                Alternatives.suggestSlowdown]
        case .extreme:
            return [Alternatives.suggestSlowdown,
                Alternatives.declineWithExplanation,
                Alternatives.escalateToHuman]
        }
    }
}
