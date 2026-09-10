import Foundation

// 五十四 — Path A starter curriculum: 50 AI-drafted illustrative
// templates across manifesto v2 织团 B 5 domains.
//
// ## Doctrine 透明声明
//
// **THESE ARE AI-DRAFTED ILLUSTRATIVE CONTENT, NOT AUTHORITATIVE.**
//
// Per Doctrine A (M295.1 + M295.2 enforcement):
//
// - All 50 envelopes default to `.illustrative` provenance.
// - All 50 are typed-blocked from L2 training pipeline by
//   `BASWorldPriorTrainingPipelineFilter` (M295.2). The filter's
//   `trainingProvenanceFloor` is `.domainExpertReviewed`;
//   illustrative content rejects with
//   `.privateProvenance(.illustrative)`.
// - Promotion to `.hostReviewed` requires the host to call
//   `session.applying(.hostAccept)` after actually reading the
//   draft. The typed authoring track (M295.1.0) physically
//   refuses to skip stages.
// - Promotion to `.domainExpertReviewed` requires going through
//   `.peerReview` → `.approveDomain` (M295.1.0 transitions).
//   This still needs **human** domain expert sign-off; the
//   typed track only enforces the *process*, not the *content*.
//
// ## 5 domains × 10 templates each
//
// Domains correspond to manifesto v2 织团 B (世界-宿主 双经纬)
// — the L4+L5+L6+L7 weave that lets the second brain see local
// situation against world structure + host position:
//
// 1. **relationship-conflict** — interpersonal conflict patterns
// 2. **decision-uncertainty** — decision-making under
//    incomplete information
// 3. **time-pressure** — cognitive degradation under deadline /
//    urgency
// 4. **boundary-negotiation** — host boundary maintenance vs
//    accommodation
// 5. **cross-domain-analogy** — analogical transfer validity
//
// ## How a host uses this
//
// 1. `BASWorldPriorStarterCurriculum.allTemplates` — get all 50
//    typed `Input` fixtures.
// 2. `BASWorldPriorStarterCurriculum.allDraftSessions` — wrap
//    each in a fresh authoring session at `.draft` stage.
// 3. Host iterates: for each session, **read the description**,
//    decide if doctrine fits this host's context. If yes, call
//    `session.applying(.hostAccept)` to advance to
//    `.hostReviewed`. If no, call `.applying(.reject)` or
//    `.withdraw`.
// 4. Reviewed envelopes can ship to host-private deployments
//    (still blocked from training).
// 5. To reach `.domainExpertReviewed`, schedule a real domain
//    expert through Path B.

public enum BASWorldPriorStarterCurriculum {

    // MARK: - 1. Relationship conflict (10)

    public static let relationshipDirectConfrontation =
        BASWorldPriorTemplateAcceptance.Input(
            templateID:
                "tmpl-relationship-direct-confrontation",
            perturbKindsCovered: [
                "dropPrecondition", "introduceBlocker"],
            branchEvidenceRungs: [2, 1, 1],
            description:
                "Direct confrontation timing depends on relationship strength and emotional regulation capacity; premature confrontation often degrades the issue.")

    public static let relationshipBoundaryErosion =
        BASWorldPriorTemplateAcceptance.Input(
            templateID:
                "tmpl-relationship-boundary-erosion",
            perturbKindsCovered: [
                "introduceBlocker"],
            branchEvidenceRungs: [2, 2, 1],
            description:
                "Boundary erosion compounds gradually through micro-violations; isolated incidents underestimate cumulative effect on the relationship.")

    public static let relationshipManipulationPressure =
        BASWorldPriorTemplateAcceptance.Input(
            templateID:
                "tmpl-relationship-manipulation-pressure",
            perturbKindsCovered: [
                "dropPrecondition",
                "introduceBlocker"],
            branchEvidenceRungs: [3, 2, 1],
            description:
                "Manipulation pressure tends to manufacture urgency; granting the urgency premise typically forecloses better options.")

    public static let relationshipApologyAuthenticity =
        BASWorldPriorTemplateAcceptance.Input(
            templateID:
                "tmpl-relationship-apology-authenticity",
            perturbKindsCovered: ["dropPrecondition"],
            branchEvidenceRungs: [2, 1],
            description:
                "Apology authenticity correlates with specificity of acknowledgment plus visible behavior change; vague apologies typically signal repeat.")

    public static let relationshipTrustRebuilding =
        BASWorldPriorTemplateAcceptance.Input(
            templateID:
                "tmpl-relationship-trust-rebuilding",
            perturbKindsCovered: [
                "dropPrecondition", "crossDomain"],
            branchEvidenceRungs: [2, 1, 1],
            description:
                "Trust rebuilding follows asymmetric cost: small consistent acts over time outweigh single grand gestures.")

    public static let relationshipPowerAsymmetry =
        BASWorldPriorTemplateAcceptance.Input(
            templateID:
                "tmpl-relationship-power-asymmetry",
            perturbKindsCovered: [
                "introduceBlocker"],
            branchEvidenceRungs: [3, 2],
            description:
                "Power asymmetry shifts apparent voluntariness of consent; signals from lower-power party warrant additional scrutiny for coercion.")

    public static let relationshipIndirectCommunication =
        BASWorldPriorTemplateAcceptance.Input(
            templateID:
                "tmpl-relationship-indirect-communication",
            perturbKindsCovered: ["crossDomain"],
            branchEvidenceRungs: [1, 1],
            description:
                "Indirect communication patterns vary by culture and individual; literal interpretation often misses intended meaning.")

    public static let relationshipConflictAvoidance =
        BASWorldPriorTemplateAcceptance.Input(
            templateID:
                "tmpl-relationship-conflict-avoidance",
            perturbKindsCovered: [
                "dropPrecondition"],
            branchEvidenceRungs: [2, 1],
            description:
                "Sustained conflict avoidance accumulates unaddressed issues; short-term peace often trades against long-term rupture.")

    public static let relationshipRepairVsWithdrawal =
        BASWorldPriorTemplateAcceptance.Input(
            templateID:
                "tmpl-relationship-repair-vs-withdrawal",
            perturbKindsCovered: [
                "dropPrecondition",
                "introduceBlocker"],
            branchEvidenceRungs: [2, 1, 1],
            description:
                "Repair vs withdrawal choice depends on remaining mutual investment plus expected pattern repetition; symmetric assessment helps.")

    public static let relationshipContinuationUnderStress =
        BASWorldPriorTemplateAcceptance.Input(
            templateID:
                "tmpl-relationship-continuation-stress",
            perturbKindsCovered: [
                "introduceBlocker", "crossDomain"],
            branchEvidenceRungs: [2, 1],
            description:
                "Relationship continuation under chronic stress requires deliberate maintenance practices; assumption of automatic continuity is fragile.")

    // MARK: - 2. Decision uncertainty (10)

    public static let decisionInfoSufficiency =
        BASWorldPriorTemplateAcceptance.Input(
            templateID:
                "tmpl-decision-info-sufficiency",
            perturbKindsCovered: [
                "dropPrecondition"],
            branchEvidenceRungs: [3, 2, 1],
            description:
                "Information sufficiency threshold is decision-specific; perfect information is rarely worth its acquisition cost in time-bounded contexts.")

    public static let decisionReversibilityAssessment =
        BASWorldPriorTemplateAcceptance.Input(
            templateID:
                "tmpl-decision-reversibility",
            perturbKindsCovered: [
                "dropPrecondition",
                "introduceBlocker"],
            branchEvidenceRungs: [3, 2, 2, 1],
            description:
                "Reversibility assessment trades evidence threshold against action urgency; high-reversibility decisions tolerate less evidence than low-reversibility.")

    public static let decisionSunkCost =
        BASWorldPriorTemplateAcceptance.Input(
            templateID:
                "tmpl-decision-sunk-cost",
            perturbKindsCovered: ["dropPrecondition"],
            branchEvidenceRungs: [4, 3, 2],
            description:
                "Sunk costs are causally irrelevant to forward decisions; their psychological weight nonetheless biases continuation past optimal exit.")

    public static let decisionAnchoringResistance =
        BASWorldPriorTemplateAcceptance.Input(
            templateID:
                "tmpl-decision-anchoring",
            perturbKindsCovered: ["dropPrecondition"],
            branchEvidenceRungs: [3, 2, 2],
            description:
                "Initial number anchors subsequent estimates even when irrelevant; explicit anchor identification reduces effect.")

    public static let decisionLossAversionCalibration =
        BASWorldPriorTemplateAcceptance.Input(
            templateID:
                "tmpl-decision-loss-aversion",
            perturbKindsCovered: ["dropPrecondition"],
            branchEvidenceRungs: [3, 2],
            description:
                "Loss aversion exceeds equivalent gain weight by ~2x in many contexts; symmetric framing reduces but does not eliminate.")

    public static let decisionProbabilityMisjudgment =
        BASWorldPriorTemplateAcceptance.Input(
            templateID:
                "tmpl-decision-probability-misjudgment",
            perturbKindsCovered: [
                "dropPrecondition", "crossDomain"],
            branchEvidenceRungs: [3, 2, 1],
            description:
                "Probability estimates over rare events tend to overshoot or undershoot by orders of magnitude; base rate consultation reduces error.")

    public static let decisionTimeHorizon =
        BASWorldPriorTemplateAcceptance.Input(
            templateID:
                "tmpl-decision-time-horizon",
            perturbKindsCovered: [
                "introduceBlocker"],
            branchEvidenceRungs: [2, 2, 1],
            description:
                "Decision quality varies with the time horizon weighted; short-horizon decisions often externalize cost to long-horizon self.")

    public static let decisionMultiObjective =
        BASWorldPriorTemplateAcceptance.Input(
            templateID:
                "tmpl-decision-multi-objective",
            perturbKindsCovered: [
                "introduceBlocker", "crossDomain"],
            branchEvidenceRungs: [2, 1],
            description:
                "Multi-objective decisions force tradeoffs between incommensurate values; explicit weighting precedes good comparison.")

    public static let decisionDefaultOptionBias =
        BASWorldPriorTemplateAcceptance.Input(
            templateID:
                "tmpl-decision-default-bias",
            perturbKindsCovered: [
                "dropPrecondition"],
            branchEvidenceRungs: [3, 2, 1],
            description:
                "Default option carries disproportionate stickiness; opt-in vs opt-out framings can flip behavior without value change.")

    public static let decisionPreMortem =
        BASWorldPriorTemplateAcceptance.Input(
            templateID:
                "tmpl-decision-pre-mortem",
            perturbKindsCovered: [
                "introduceBlocker", "crossDomain"],
            branchEvidenceRungs: [2, 1, 1],
            description:
                "Pre-mortem reasoning (assume the decision failed; explain why) surfaces failure modes that prospective optimism omits.")

    // MARK: - 3. Time pressure (10)

    public static let timeUrgencyVsImportance =
        BASWorldPriorTemplateAcceptance.Input(
            templateID:
                "tmpl-time-urgency-vs-importance",
            perturbKindsCovered: ["dropPrecondition"],
            branchEvidenceRungs: [3, 2],
            description:
                "Urgency and importance are distinct axes; high-urgency low-importance items often crowd out low-urgency high-importance ones.")

    public static let timeQualityDecayUnderHaste =
        BASWorldPriorTemplateAcceptance.Input(
            templateID:
                "tmpl-time-quality-decay",
            perturbKindsCovered: [
                "introduceBlocker"],
            branchEvidenceRungs: [3, 2, 1],
            description:
                "Decision quality degrades nonlinearly under time pressure; small time savings often trade against large quality losses.")

    public static let timeManufacturedUrgency =
        BASWorldPriorTemplateAcceptance.Input(
            templateID:
                "tmpl-time-manufactured-urgency",
            perturbKindsCovered: [
                "dropPrecondition",
                "introduceBlocker"],
            branchEvidenceRungs: [3, 2, 1],
            description:
                "Manufactured urgency is a common manipulation pattern; testing if delay actually causes harm distinguishes real from manufactured.")

    public static let timeCognitiveLoadSaturation =
        BASWorldPriorTemplateAcceptance.Input(
            templateID:
                "tmpl-time-cognitive-load",
            perturbKindsCovered: ["dropPrecondition"],
            branchEvidenceRungs: [3, 2],
            description:
                "Cognitive load saturation degrades attention quality; multitasking under load typically reduces total throughput.")

    public static let timeRestBudgetVsDeadline =
        BASWorldPriorTemplateAcceptance.Input(
            templateID:
                "tmpl-time-rest-budget",
            perturbKindsCovered: [
                "introduceBlocker"],
            branchEvidenceRungs: [2, 1],
            description:
                "Rest budget and deadline budget interact; insufficient rest often produces lower-quality work in equal or greater elapsed time.")

    public static let timeMultiTaskingDegradation =
        BASWorldPriorTemplateAcceptance.Input(
            templateID:
                "tmpl-time-multi-tasking",
            perturbKindsCovered: ["dropPrecondition"],
            branchEvidenceRungs: [3, 2, 2],
            description:
                "Multi-tasking degrades each task's quality and total throughput; switching costs accumulate per context shift.")

    public static let timeDeadlineAnchorManipulation =
        BASWorldPriorTemplateAcceptance.Input(
            templateID:
                "tmpl-time-deadline-anchor",
            perturbKindsCovered: [
                "dropPrecondition",
                "introduceBlocker"],
            branchEvidenceRungs: [2, 1, 1],
            description:
                "Stated deadline anchors response speed; arbitrary deadlines invite acceptance unless explicitly questioned.")

    public static let timeQuickDecisionHeuristics =
        BASWorldPriorTemplateAcceptance.Input(
            templateID:
                "tmpl-time-quick-heuristics",
            perturbKindsCovered: ["crossDomain"],
            branchEvidenceRungs: [2, 1],
            description:
                "Quick-decision heuristics work in familiar domains and degrade outside them; novel context warrants slower deliberation.")

    public static let timePauseAndReflectROI =
        BASWorldPriorTemplateAcceptance.Input(
            templateID:
                "tmpl-time-pause-reflect-roi",
            perturbKindsCovered: [
                "introduceBlocker"],
            branchEvidenceRungs: [2, 1],
            description:
                "Pausing for reflection has variable ROI by decision class; high-impact irreversible decisions warrant longer pause budgets.")

    public static let timeConstrainedCreativity =
        BASWorldPriorTemplateAcceptance.Input(
            templateID:
                "tmpl-time-constrained-creativity",
            perturbKindsCovered: [
                "crossDomain", "dropPrecondition"],
            branchEvidenceRungs: [2, 1, 1],
            description:
                "Time constraints can both stimulate (forcing function) and degrade (premature closure) creative output; optimum varies by individual and task.")

    // MARK: - 4. Boundary negotiation (10)

    public static let boundaryAssertionVsAccommodation =
        BASWorldPriorTemplateAcceptance.Input(
            templateID:
                "tmpl-boundary-assertion-accommodation",
            perturbKindsCovered: [
                "dropPrecondition",
                "introduceBlocker"],
            branchEvidenceRungs: [2, 1, 1],
            description:
                "Self-assertion and accommodation are not opposites but complementary skills; chronic dominance of either degrades long-term outcomes.")

    public static let boundaryViolationGradients =
        BASWorldPriorTemplateAcceptance.Input(
            templateID:
                "tmpl-boundary-violation-gradient",
            perturbKindsCovered: [
                "introduceBlocker"],
            branchEvidenceRungs: [3, 2, 1],
            description:
                "Boundary violations exist on a gradient from minor to severe; aggregate pattern matters more than any single incident.")

    public static let boundaryRecovery =
        BASWorldPriorTemplateAcceptance.Input(
            templateID:
                "tmpl-boundary-recovery",
            perturbKindsCovered: [
                "dropPrecondition", "crossDomain"],
            branchEvidenceRungs: [2, 1],
            description:
                "Recovery from boundary breach often requires re-establishment ritual visible to both parties; silent recovery tends to compound.")

    public static let boundaryConsentScope =
        BASWorldPriorTemplateAcceptance.Input(
            templateID:
                "tmpl-boundary-consent-scope",
            perturbKindsCovered: [
                "introduceBlocker"],
            branchEvidenceRungs: [3, 2, 1],
            description:
                "Consent scope rarely transfers across contexts without explicit re-consent; assumption of carryover is a common error.")

    public static let boundaryNonNegotiables =
        BASWorldPriorTemplateAcceptance.Input(
            templateID:
                "tmpl-boundary-non-negotiables",
            perturbKindsCovered: ["dropPrecondition"],
            branchEvidenceRungs: [3, 2],
            description:
                "Non-negotiable boundaries should be identified before negotiation begins; identifying mid-conflict invites rationalization.")

    public static let boundaryCompromiseVsCapitulation =
        BASWorldPriorTemplateAcceptance.Input(
            templateID:
                "tmpl-boundary-compromise-capitulation",
            perturbKindsCovered: [
                "dropPrecondition",
                "introduceBlocker"],
            branchEvidenceRungs: [2, 1, 1],
            description:
                "Compromise and capitulation differ by reciprocity and core-value preservation; capitulation feels like compromise but doesn't reciprocate.")

    public static let boundarySignalingChannels =
        BASWorldPriorTemplateAcceptance.Input(
            templateID:
                "tmpl-boundary-signaling",
            perturbKindsCovered: ["crossDomain"],
            branchEvidenceRungs: [1, 1],
            description:
                "Boundary signaling effectiveness varies by channel; explicit verbal channels typically less ambiguous than behavioral cues.")

    public static let boundaryMicroErosion =
        BASWorldPriorTemplateAcceptance.Input(
            templateID:
                "tmpl-boundary-micro-erosion",
            perturbKindsCovered: [
                "introduceBlocker"],
            branchEvidenceRungs: [2, 1],
            description:
                "Micro-violations erode boundaries faster than single major violations; pattern observation needs longer time horizon than single events.")

    public static let boundaryReestablishment =
        BASWorldPriorTemplateAcceptance.Input(
            templateID:
                "tmpl-boundary-reestablishment",
            perturbKindsCovered: [
                "dropPrecondition", "crossDomain"],
            branchEvidenceRungs: [2, 1, 1],
            description:
                "Re-establishing a lapsed boundary requires explicit signaling; assumed re-establishment usually produces immediate re-erosion.")

    public static let boundaryCulturalVariation =
        BASWorldPriorTemplateAcceptance.Input(
            templateID:
                "tmpl-boundary-cultural-variation",
            perturbKindsCovered: ["crossDomain"],
            branchEvidenceRungs: [2, 1],
            description:
                "Boundary norms vary substantially by culture; transposing one culture's norms to another typically generates miscommunication.")

    // MARK: - 5. Cross-domain analogy (10)

    public static let analogyTransferCaution =
        BASWorldPriorTemplateAcceptance.Input(
            templateID:
                "tmpl-analogy-transfer-caution",
            perturbKindsCovered: [
                "crossDomain", "introduceBlocker"],
            branchEvidenceRungs: [2, 1, 1],
            description:
                "Analogical reasoning carries inferences from source to target domain; surface similarity doesn't guarantee causal mechanism transfer.")

    public static let analogySurfaceVsDeep =
        BASWorldPriorTemplateAcceptance.Input(
            templateID:
                "tmpl-analogy-surface-deep",
            perturbKindsCovered: ["crossDomain"],
            branchEvidenceRungs: [3, 2, 1],
            description:
                "Deep similarity (causal structure) supports valid analogy more than surface similarity (features); surface-only analogies often mislead.")

    public static let analogyCausalMechanism =
        BASWorldPriorTemplateAcceptance.Input(
            templateID:
                "tmpl-analogy-causal-mechanism",
            perturbKindsCovered: [
                "crossDomain", "dropPrecondition"],
            branchEvidenceRungs: [3, 2, 2],
            description:
                "Causal mechanism preservation determines analogy validity; analogies that preserve only outcomes without mechanism are fragile.")

    public static let analogyReasoningBias =
        BASWorldPriorTemplateAcceptance.Input(
            templateID:
                "tmpl-analogy-reasoning-bias",
            perturbKindsCovered: ["dropPrecondition"],
            branchEvidenceRungs: [2, 1],
            description:
                "Analogical reasoning anchors on a single source domain; consulting multiple sources reduces single-anchor bias.")

    public static let analogySourceSelection =
        BASWorldPriorTemplateAcceptance.Input(
            templateID:
                "tmpl-analogy-source-selection",
            perturbKindsCovered: [
                "crossDomain", "introduceBlocker"],
            branchEvidenceRungs: [2, 1, 1],
            description:
                "Choice of source domain shapes target inferences; explicit source-selection rationale helps audit transfer validity.")

    public static let analogyMappingCompleteness =
        BASWorldPriorTemplateAcceptance.Input(
            templateID:
                "tmpl-analogy-mapping-completeness",
            perturbKindsCovered: ["crossDomain"],
            branchEvidenceRungs: [2, 1],
            description:
                "Mapping completeness check reveals analogy boundaries; partial mappings often elide where the analogy breaks.")

    public static let analogyInferenceValidity =
        BASWorldPriorTemplateAcceptance.Input(
            templateID:
                "tmpl-analogy-inference-validity",
            perturbKindsCovered: [
                "crossDomain", "introduceBlocker"],
            branchEvidenceRungs: [2, 2, 1],
            description:
                "Inference validity from analogy requires the inferred relation to depend on the mapped causal structure; coincidental coincidences don't transfer.")

    public static let analogyDomainExceptions =
        BASWorldPriorTemplateAcceptance.Input(
            templateID:
                "tmpl-analogy-domain-exceptions",
            perturbKindsCovered: ["crossDomain"],
            branchEvidenceRungs: [2, 1],
            description:
                "Domain-specific exceptions limit analogy applicability; well-chosen analogies note where they don't apply.")

    public static let analogyComposite =
        BASWorldPriorTemplateAcceptance.Input(
            templateID:
                "tmpl-analogy-composite",
            perturbKindsCovered: [
                "crossDomain", "introduceBlocker"],
            branchEvidenceRungs: [2, 1, 1],
            description:
                "Composite analogies (multiple sources combined) can capture more structure than single-source; consistency check across sources is required.")

    public static let analogyCounterAnalogy =
        BASWorldPriorTemplateAcceptance.Input(
            templateID:
                "tmpl-analogy-counter-analogy",
            perturbKindsCovered: [
                "crossDomain", "dropPrecondition"],
            branchEvidenceRungs: [2, 1],
            description:
                "Counter-analogies test the chosen analogy's robustness; if a plausible counter-analogy yields opposite inference, the original is fragile.")

    // MARK: - Aggregators

    /// All 50 starter templates flat list.
    public static let allTemplates: [
        BASWorldPriorTemplateAcceptance.Input
    ] = [
        // Relationship conflict (10)
        relationshipDirectConfrontation,
        relationshipBoundaryErosion,
        relationshipManipulationPressure,
        relationshipApologyAuthenticity,
        relationshipTrustRebuilding,
        relationshipPowerAsymmetry,
        relationshipIndirectCommunication,
        relationshipConflictAvoidance,
        relationshipRepairVsWithdrawal,
        relationshipContinuationUnderStress,
        // Decision uncertainty (10)
        decisionInfoSufficiency,
        decisionReversibilityAssessment,
        decisionSunkCost,
        decisionAnchoringResistance,
        decisionLossAversionCalibration,
        decisionProbabilityMisjudgment,
        decisionTimeHorizon,
        decisionMultiObjective,
        decisionDefaultOptionBias,
        decisionPreMortem,
        // Time pressure (10)
        timeUrgencyVsImportance,
        timeQualityDecayUnderHaste,
        timeManufacturedUrgency,
        timeCognitiveLoadSaturation,
        timeRestBudgetVsDeadline,
        timeMultiTaskingDegradation,
        timeDeadlineAnchorManipulation,
        timeQuickDecisionHeuristics,
        timePauseAndReflectROI,
        timeConstrainedCreativity,
        // Boundary negotiation (10)
        boundaryAssertionVsAccommodation,
        boundaryViolationGradients,
        boundaryRecovery,
        boundaryConsentScope,
        boundaryNonNegotiables,
        boundaryCompromiseVsCapitulation,
        boundarySignalingChannels,
        boundaryMicroErosion,
        boundaryReestablishment,
        boundaryCulturalVariation,
        // Cross-domain analogy (10)
        analogyTransferCaution,
        analogySurfaceVsDeep,
        analogyCausalMechanism,
        analogyReasoningBias,
        analogySourceSelection,
        analogyMappingCompleteness,
        analogyInferenceValidity,
        analogyDomainExceptions,
        analogyComposite,
        analogyCounterAnalogy,
    ]

    /// Convenience: wrap each starter in an `.illustrative`
    /// envelope. Doctrinally these MUST stay illustrative until
    /// host runs them through authoring track.
    public static var allIllustrativeEnvelopes: [
        BASWorldPriorTemplateEnvelope
    ] {
        allTemplates.map {
            BASWorldPriorTemplateEnvelope(
                input: $0,
                provenance: .illustrative)
        }
    }

    /// Convenience: produce a fresh authoring session at
    /// `.draft` for each starter. Host iterates these and calls
    /// `.applying(.hostAccept)` after reviewing each
    /// description.
    public static var allDraftSessions: [
        BASWorldPriorTemplateAuthoringSession
    ] {
        allTemplates.map {
            BASWorldPriorTemplateAuthoringSession(
                templateID: $0.templateID)
        }
    }
}
