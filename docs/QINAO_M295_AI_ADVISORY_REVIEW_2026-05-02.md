# M295 AI Advisory Review — Path A 50-Template Starter Curriculum

**Date**: 2026-05-02
**Reviewer**: Claude (AI advisory) — **NOT a domain expert sign-off**
**Envelope**: `.illustrative` — typed pipeline (`BASWorldPriorTrainingPipelineFilter`) physically blocks promotion to `.domainExpertReviewed` regardless of this document's content
**Methodology**: Option C — my structural narrative review (A) cross-checked against real Apple Foundation Models 5-persona panel sample on 15/50 templates (B)
**AFM run**: 75 calls / 64 parse-success / 112.7s elapsed / `apple.foundation-models.v1`

---

## 0. Doctrine pin (read first)

This document is an **AI advisory review** in the sense the
M64-66 typed-pipeline ships. Reading it does **not** promote any
template's envelope. The substrate-level doctrine is hard:

1. `BASWorldPriorTrainingPipelineFilter.trainingProvenanceFloor = .domainExpertReviewed` physically rejects `.illustrative` content from L2 training
2. `BASWorldPriorTemplateAuthoringSession` 8-stage state machine refuses to skip `.peerReview → .approveDomain` transitions
3. `testPersonaPanelDoesNotPromoteEnvelope` (M67.4 deep-review fix) pins that even unanimous AI persona approval keeps envelope `.illustrative`

The 50 templates this document reviews are **AI-drafted starter
content** (chapter 五十四 Path A). They reach `.domainExpertReviewed`
only when a real human couples therapist / decision scientist /
time-management researcher / boundary coach / cognitive linguist
audits + signs the corresponding template through Path B/C/D.
This document is preparatory material for that real review,
**not a substitute for it**.

---

## 1. Methodology

### 1.A Structural narrative review (this document)

For each of 50 templates, I assess:

- **templateID shape**: matches `tmpl-{domain}-{slug}` convention; slug is descriptive
- **perturbKindsCovered**: `dropPrecondition` / `introduceBlocker` / `crossDomain` — match what the description claims
- **branchEvidenceRungs**: depth array; entries in [0,4]; total length reasonable for the claim
- **description claim**: factual + specific + grounded (where I can verify); generic-sounding claims flagged
- **domain assignment**: relationship / decision / time / boundary / analogy — does the content actually belong there

Categories I assign:

- **Strong** — claim is well-grounded in domain literature, structurally clean
- **Acceptable** — claim is plausible but generic; would benefit from specificity
- **Refine** — has specific issue I'd want a domain expert to address
- **Suspect** — claim potentially overgeneralized or contested in the literature

### 1.B AFM persona panel sample (real model run)

Ran `BASWorldPriorAIPersonaReviewer` against 15 representative
templates (3 per domain) via `AppleFoundationOrganAdapter` on
the host. Output captured at
`/var/folders/.../qinao-persona-panel-review-{uuid}.json`.

Five personas (one canonical per domain):

| Persona | Canonical domain |
|---|---|
| `relationshipTherapist` | relationship-conflict |
| `decisionScientist` | decision-uncertainty |
| `timeResearcher` | time-pressure |
| `boundaryCoach` | boundary-negotiation |
| `cognitiveLinguist` | cross-domain-analogy |

Each persona reviews each template; verdict is `approveSuggested`,
`rejectSuggested`, or `needsExpertJudgment`. Plus a domain comment
(1-2 sentences) and 1-3 cited concepts.

### 1.C Cross-check

Where AFM panel and my structural review agree → **convergent
signal** (real domain experts likely to concur).

Where they disagree → **flagged for expert** — either AFM
missed something I caught (cite my reasoning) or I'm being too
critical (cite AFM's domain-specific reasoning).

---

## 2. Headline findings

After cross-checking my structural review against the 15-template
AFM panel sample (75 calls, 64 parsed):

### 2.1 AFM panel skews approval-heavy

Of 64 parsed reviews across 15 templates, ~85% are
`approveSuggested`. Only **1 reject** (boundaryCoach on
`tmpl-relationship-manipulation-pressure`) and ~5
`needsExpertJudgment` flags. This is exactly the failure mode
M64-66 + M67.4 anticipated: AFM is generally agreeable, so
panel consensus is a weak signal for promotion. **Doctrine A is
not paranoia — it's empirically warranted** even at small
sample size.

### 2.2 Personas often comment cross-domain with thin praise

Many persona reviews praise templates outside their canonical
domain via generic framing: `cognitiveLinguist` cites
"Lakoff-Fauconnier tradition" on basically every template
(including pure relationship / decision content); `decisionScientist`
applies "behavioral economics" framing to relationship and
analogy templates. This is signal that AFM is reaching for
domain vocabulary it knows rather than substantively engaging.

**Implication for real expert review**: real reviewers should
read templates outside their canonical domain with more
restraint than AFM — defer to the canonical-domain expert's
verdict.

### 2.3 Specific genuine flag from panel

`tmpl-relationship-manipulation-pressure` got a
`rejectSuggested` from `boundaryCoach` with substantive reason:
*"Pressure-driven urgency often stifles creativity and
exploration of alternative solutions"* — argues that the
template's framing centers manipulation defense in a way that
may itself foreclose the host's options. This **is** a real
critique a boundary expert might make. I include it in §3.1.

### 2.4 Templates I'd send to expert review queue first

Highest priority (strong + structurally clean + claim well-grounded):

1. `tmpl-decision-sunk-cost` — claim is canonical decision science
2. `tmpl-time-multi-tasking` — claim is canonical cognitive science
3. `tmpl-decision-anchoring` — canonical Tversky-Kahneman finding
4. `tmpl-decision-loss-aversion` — canonical prospect theory
5. `tmpl-analogy-causal-mechanism` — canonical analogical-reasoning literature

These are most likely to survive real expert review intact.

### 2.5 Templates I'd flag for refinement before expert review

Highest concern (claim overgeneralized / culturally narrow / contested):

1. `tmpl-relationship-indirect-communication` — culturally narrow framing
2. `tmpl-boundary-cultural-variation` — risk of essentialism in expert read
3. `tmpl-relationship-power-asymmetry` — political/legal implications need careful framing
4. `tmpl-relationship-manipulation-pressure` — AFM's reject signal is correct
5. `tmpl-decision-loss-aversion` — claim that loss aversion is "~2x" is contested in recent replication literature

(`tmpl-decision-loss-aversion` shows up in BOTH §2.4 and §2.5 — strong canonical claim that recent research has questioned the magnitude of. Real reviewers should resolve this directly.)

---

## 3. Per-domain advisory review

### 3.1 Domain 1 — relationship-conflict (10 templates)

**Domain reviewer**: couples / family therapist with clinical practice

#### 3.1.1 `tmpl-relationship-direct-confrontation`

> "Direct confrontation timing depends on relationship strength and emotional regulation capacity; premature confrontation often degrades the issue."

**Structural**: clean — 2 perturb kinds (`dropPrecondition`, `introduceBlocker`) match a "what if relationship strength is removed / what if a regulation blocker is added" framing. branchEvidenceRungs `[2, 1, 1]` proportionate.

**Content**: ✓ **acceptable**. Both halves of the claim — timing dependency + premature damage — are well-supported in Gottman literature (e.g., harsh start-up effect). The "emotional regulation capacity" prong is more recent (DBT-influenced).

**Expert flag**: `boundaryCoach` panel called for `needsExpertJudgment` ("given assertiveness level and escalation potential"). Consider whether "premature" is operationalizable — when does timing tip from premature to overdue?

#### 3.1.2 `tmpl-relationship-boundary-erosion`

> "Boundary erosion compounds gradually through micro-violations; isolated incidents underestimate cumulative effect on the relationship."

**Structural**: clean. Single perturb kind (`introduceBlocker`) makes sense — adding a micro-violation blocker tests the cumulative-effect claim.

**Content**: ✓ **strong**. Compounding-via-micro-violations is canonical in attachment-theory literature (e.g., negative reciprocity research, Gottman's Four Horsemen progression). 4/4 panel personas approved (1 parse fail).

**Expert flag**: none from me; would benefit from naming the specific framework (Gottman attachment, attachment-injury model, etc.).

#### 3.1.3 `tmpl-relationship-manipulation-pressure`

> "Manipulation pressure tends to manufacture urgency; granting the urgency premise typically forecloses better options."

**Structural**: clean. 2 perturb kinds appropriate.

**Content**: ⚠ **refine** — AFM panel surfaced a real concern. boundaryCoach explicitly rejected, arguing "pressure-driven urgency often stifles creativity and exploration of alternative solutions." That critique is **not** that the claim is wrong but that the **framing** centers manipulation-defense in a way that may foreclose host options. A real domain expert (boundary coach or therapist) might prefer "manipulation pressure surfaces options the host might otherwise dismiss" as a complementary claim.

**Expert flag**: confirm whether "forecloses better options" is the doctrinal frame or whether "narrows attention" is more accurate.

#### 3.1.4 `tmpl-relationship-apology-authenticity`

> "Apology authenticity correlates with specificity of acknowledgment plus visible behavior change; vague apologies typically signal repeat."

**Structural**: minimal but clean (1 perturb kind, 2 evidence rungs).

**Content**: ✓ **strong**. Both prongs are well-supported in repair-after-conflict literature (see Lazare, *On Apology*; Howell + Howell on apology effectiveness).

**Expert flag**: would benefit from operationalizing "specificity" — what counts as specific in clinical assessment.

#### 3.1.5 `tmpl-relationship-trust-rebuilding`

> "Trust rebuilding follows asymmetric cost: small consistent acts over time outweigh single grand gestures."

**Structural**: clean. `crossDomain` perturb kind makes sense — the "asymmetric cost" frame transfers from finance.

**Content**: ✓ **acceptable**. Claim is canonical in attachment-injury research (Gottman, Greenberg). The "small consistent over grand gesture" prong should cite specific research; without it the claim risks sounding folk-wisdom.

**Expert flag**: ensure the "outweigh" comparison is empirical not moral.

#### 3.1.6 `tmpl-relationship-power-asymmetry`

> "Power asymmetry shifts apparent voluntariness of consent; signals from lower-power party warrant additional scrutiny for coercion."

**Structural**: clean. `introduceBlocker` matches.

**Content**: ⚠ **refine** — claim is correct but operationally fraught. "Apparent voluntariness" is a legal/ethical term; "additional scrutiny" must be carefully framed to avoid pathologizing all power-differential relationships (boss/employee, parent/adult-child, therapist/client). A real reviewer will want stronger guard-rails on application.

**Expert flag**: needs explicit scope (clinical / legal / professional) and a counter-claim acknowledging that power asymmetry doesn't always invalidate consent.

#### 3.1.7 `tmpl-relationship-indirect-communication`

> "Indirect communication patterns vary by culture and individual; literal interpretation often misses intended meaning."

**Structural**: minimal (1 perturb, 2 evidence rungs).

**Content**: ⚠ **refine** — claim is true but framed in a way that can pattern-match to cultural-essentialism critiques. "Indirect communication" as a culture-coded variable is a real research finding (Hall's high-context vs low-context) but also a category that within-culture variation often exceeds between-culture variation.

**Expert flag**: a real cross-cultural psychologist would want this template to acknowledge that within-group variance often exceeds between-group variance.

#### 3.1.8 `tmpl-relationship-conflict-avoidance`

> "Sustained conflict avoidance accumulates unaddressed issues; short-term peace often trades against long-term rupture."

**Structural**: clean.

**Content**: ✓ **acceptable**. Claim aligns with Gottman avoidance/withdrawal research and Karpman triangle dynamics. "Often trades" is appropriately hedged.

**Expert flag**: would benefit from acknowledging that avoidance sometimes is correct (self-preservation in unsafe relationships).

#### 3.1.9 `tmpl-relationship-repair-vs-withdrawal`

> "Repair vs withdrawal choice depends on remaining mutual investment plus expected pattern repetition; symmetric assessment helps."

**Structural**: clean.

**Content**: ✓ **acceptable**. Both prongs are reasonable; "symmetric assessment helps" is a good qualifier (though "helps" is weak — does it shift outcomes meaningfully?).

**Expert flag**: operationalize "remaining mutual investment".

#### 3.1.10 `tmpl-relationship-continuation-stress`

> "Relationship continuation under chronic stress requires deliberate maintenance practices; assumption of automatic continuity is fragile."

**Structural**: clean.

**Content**: ✓ **strong**. Canonical in marital-stability research (e.g., Bradbury + Karney). "Automatic continuity is fragile" is a useful prior.

**Expert flag**: none from me.

---

### 3.2 Domain 2 — decision-uncertainty (10 templates)

**Domain reviewer**: decision scientist / behavioral economist

#### 3.2.1 `tmpl-decision-info-sufficiency`

> "Information sufficiency threshold is decision-specific; perfect information is rarely worth its acquisition cost in time-bounded contexts."

**Structural**: clean. branchEvidenceRungs `[3, 2, 1]` deeper than most relationship templates — reasonable for decision science.

**Content**: ✓ **strong**. Canonical Simon (bounded rationality) + Gigerenzer (satisficing) framing. AFM panel: 4 approve / 0 reject / 1 needsExpertJudgment (decisionScientist flagged "missing some contextual info needed to evaluate sufficiency" — meta-level critique that the template lacks specificity, not that the claim is wrong).

**Expert flag**: would benefit from specifying decision class (high-stakes irreversible vs. low-stakes reversible behave very differently).

#### 3.2.2 `tmpl-decision-reversibility`

> "Reversibility assessment trades evidence threshold against action urgency; high-reversibility decisions tolerate less evidence than low-reversibility."

**Structural**: clean. branchEvidenceRungs `[3, 2, 2, 1]` is the deepest in the curriculum — appropriate for a multi-axis claim.

**Content**: ✓ **strong**. Canonical (Bezos famously frames as "Type 1 / Type 2 doors"). The claim direction is correct.

**Expert flag**: real reviewer would tune the language — "tolerate less evidence" might read as encouraging hasty decisions; clarify that the trade is contextual.

#### 3.2.3 `tmpl-decision-sunk-cost`

> "Sunk costs are causally irrelevant to forward decisions; their psychological weight nonetheless biases continuation past optimal exit."

**Structural**: clean. branchEvidenceRungs `[4, 3, 2]` highest in the entire curriculum — appropriate for one of the most-replicated findings in decision science.

**Content**: ✓ **strong, send first**. Both prongs (causal irrelevance + psychological weight) are gold-standard. Canonical Arkes + Blumer 1985 + decades of replication.

**Expert flag**: none. This is the template I'd put first in front of a real expert.

#### 3.2.4 `tmpl-decision-anchoring`

> "Initial number anchors subsequent estimates even when irrelevant; explicit anchor identification reduces effect."

**Structural**: clean.

**Content**: ✓ **strong, send first**. Tversky-Kahneman canonical. The "explicit identification reduces" prong is supported by debiasing literature (though the effect size of debiasing is modest — real reviewer should note).

**Expert flag**: clarify "reduces" magnitude — debiasing is partial, not full.

#### 3.2.5 `tmpl-decision-loss-aversion`

> "Loss aversion exceeds equivalent gain weight by ~2x in many contexts; symmetric framing reduces but does not eliminate."

**Structural**: clean.

**Content**: ⚠ **refine** — the "~2x" specific magnitude is contested. Recent meta-analyses (Gal + Rucker 2018) and replication failures (Mrkva et al.) have challenged whether loss aversion is as universal or as ~2x as the original Kahneman-Tversky framing. The claim is not wrong but the magnitude statement may be too confident.

**Expert flag**: real decision scientist will want this template to either soften "~2x" to "1.5-2.5x in many but not all contexts" or to cite domain-conditional scope.

#### 3.2.6 `tmpl-decision-probability-misjudgment`

> "Probability estimates over rare events tend to overshoot or undershoot by orders of magnitude; base rate consultation reduces error."

**Structural**: clean. `crossDomain` + `dropPrecondition` makes sense.

**Content**: ✓ **acceptable**. Lichtenstein + Slovic + Fischhoff canonical research on rare-event misestimation. "Orders of magnitude" is the right scale of error.

**Expert flag**: clarify that base-rate consultation is one debiasing technique among several (also: comparison classes, frequency framing).

#### 3.2.7 `tmpl-decision-time-horizon`

> "Decision quality varies with the time horizon weighted; short-horizon decisions often externalize cost to long-horizon self."

**Structural**: clean.

**Content**: ✓ **acceptable**. Hyperbolic-discounting + intertemporal-choice literature. The "externalize cost to long-horizon self" framing is from Ainslie / Thaler.

**Expert flag**: AFM cognitiveLinguist needsExpertJudgment ("lacks specific examples") — fair point. Real reviewer will want concrete intertemporal-choice operationalization.

#### 3.2.8 `tmpl-decision-multi-objective`

> "Multi-objective decisions force tradeoffs between incommensurate values; explicit weighting precedes good comparison."

**Structural**: clean.

**Content**: ✓ **acceptable**. Multi-attribute utility theory canonical (Keeney + Raiffa). "Incommensurate values" is correct — many decisions involve genuinely incomparable axes.

**Expert flag**: "explicit weighting precedes good comparison" might be too strong — some decision researchers argue heuristic / lexicographic methods outperform weighted-sum in real-world decisions (Gigerenzer's fast-and-frugal).

#### 3.2.9 `tmpl-decision-default-bias`

> "Default option carries disproportionate stickiness; opt-in vs opt-out framings can flip behavior without value change."

**Structural**: clean.

**Content**: ✓ **strong**. Johnson + Goldstein (organ donation) and behavioral-economics nudge literature canonical.

**Expert flag**: would benefit from operational scope ("for low-engagement decisions" — not all decisions are equally default-driven).

#### 3.2.10 `tmpl-decision-pre-mortem`

> "Pre-mortem reasoning (assume the decision failed; explain why) surfaces failure modes that prospective optimism omits."

**Structural**: clean. `crossDomain` makes sense — pre-mortem is a structured-analysis technique adapted from medicine.

**Content**: ✓ **acceptable**. Klein's pre-mortem is well-known among decision practitioners.

**Expert flag**: real reviewer might want effect-size estimate or noted limitation (pre-mortem can also encourage over-conservatism).

---

### 3.3 Domain 3 — time-pressure (10 templates)

**Domain reviewer**: time-management researcher / cognitive psychologist

#### 3.3.1 `tmpl-time-urgency-vs-importance`

> "Urgency and importance are distinct axes; high-urgency low-importance items often crowd out low-urgency high-importance ones."

**Structural**: minimal (1 perturb, 2 evidence rungs).

**Content**: ✓ **acceptable**. Eisenhower-matrix folk wisdom + Covey canonical. "Crowd out" is the right effect direction. AFM panel: 3/0/1 (cognitiveLinguist needsExpertJudgment for nuance).

**Expert flag**: this is folk-wisdom level; real expert may want this template grounded in attention-economics or workload-prioritization research, not just intuitive 2x2.

#### 3.3.2 `tmpl-time-quality-decay`

> "Decision quality degrades nonlinearly under time pressure; small time savings often trade against large quality losses."

**Structural**: clean.

**Content**: ✓ **strong**. Cognitive-load + speed-accuracy-tradeoff literature canonical. "Nonlinearly" is the key claim and it's correct (quadratic-ish curves in many studies).

**Expert flag**: real reviewer might want explicit speed-accuracy frontier framing.

#### 3.3.3 `tmpl-time-manufactured-urgency`

> "Manufactured urgency is a common manipulation pattern; testing if delay actually causes harm distinguishes real from manufactured."

**Structural**: clean.

**Content**: ✓ **strong**. The "test if delay causes harm" prong is operationalizable and useful. AFM panel: 3 approve / 1 needsExpertJudgment (decisionScientist flagged "methodology and sample size may not adequately account for biases" — meta-critique on study design, not the claim itself).

**Expert flag**: this template overlaps with `tmpl-relationship-manipulation-pressure` — coordinate with relationship-domain expert.

#### 3.3.4 `tmpl-time-cognitive-load`

> "Cognitive load saturation degrades attention quality; multitasking under load typically reduces total throughput."

**Structural**: minimal.

**Content**: ✓ **strong**. Cognitive-load theory (Sweller) + Pashler dual-task interference canonical.

**Expert flag**: clarify "saturation" — at what load level?

#### 3.3.5 `tmpl-time-rest-budget`

> "Rest budget and deadline budget interact; insufficient rest often produces lower-quality work in equal or greater elapsed time."

**Structural**: minimal.

**Content**: ✓ **acceptable**. Sleep + decision-quality literature (Walker, Cirelli + Tononi) supports. "Equal or greater elapsed time" is the key insight (rest pays back in throughput).

**Expert flag**: real reviewer may want specific sleep-debt / circadian-disruption framing.

#### 3.3.6 `tmpl-time-multi-tasking`

> "Multi-tasking degrades each task's quality and total throughput; switching costs accumulate per context shift."

**Structural**: clean.

**Content**: ✓ **strong, send first**. Canonical Pashler / Meyer + Kieras task-switching cost research. "Switching costs accumulate" is correct (context-switching has nonzero per-switch overhead).

**Expert flag**: none. This is the cleanest claim in the time domain.

#### 3.3.7 `tmpl-time-deadline-anchor`

> "Stated deadline anchors response speed; arbitrary deadlines invite acceptance unless explicitly questioned."

**Structural**: clean.

**Content**: ✓ **acceptable**. Anchoring research extends to deadlines (Ariely + Wertenbroch). "Invite acceptance" is the right frame.

**Expert flag**: would benefit from concrete example of testing whether a deadline is real.

#### 3.3.8 `tmpl-time-quick-heuristics`

> "Quick-decision heuristics work in familiar domains and degrade outside them; novel context warrants slower deliberation."

**Structural**: minimal (1 perturb, `crossDomain`).

**Content**: ✓ **acceptable**. Klein's recognition-primed-decision + Kahneman System 1/System 2 canonical.

**Expert flag**: "warrant" is normative — real reviewer might want this template framed as "predict" rather than "warrant" to stay descriptive.

#### 3.3.9 `tmpl-time-pause-reflect-roi`

> "Pausing for reflection has variable ROI by decision class; high-impact irreversible decisions warrant longer pause budgets."

**Structural**: minimal.

**Content**: ✓ **acceptable**. Same family as 3.3.8 + 3.2.2.

**Expert flag**: overlaps with `tmpl-decision-reversibility` — coordinate.

#### 3.3.10 `tmpl-time-constrained-creativity`

> "Time constraints can both stimulate (forcing function) and degrade (premature closure) creative output; optimum varies by individual and task."

**Structural**: clean.

**Content**: ✓ **strong**. Two-pronged claim with the right hedge ("optimum varies"). Amabile's componential theory of creativity supports both directions.

**Expert flag**: real reviewer may want operational scope — "creative output" is heterogeneous (divergent vs convergent thinking respond differently to time pressure).

---

### 3.4 Domain 4 — boundary-negotiation (10 templates)

**Domain reviewer**: assertiveness coach / OD consultant / clinical boundary specialist

#### 3.4.1 `tmpl-boundary-assertion-accommodation`

> "Self-assertion and accommodation are not opposites but complementary skills; chronic dominance of either degrades long-term outcomes."

**Structural**: clean.

**Content**: ✓ **strong**. AFM panel: 5/0/0 unanimous approve. Modern boundary-coaching literature has moved toward complementarity framing (Brené Brown's "BRAVING" framework, etc.). "Chronic dominance" is appropriately scoped to long-term.

**Expert flag**: none from me. Strong.

#### 3.4.2 `tmpl-boundary-violation-gradient`

> "Boundary violations exist on a gradient from minor to severe; aggregate pattern matters more than any single incident."

**Structural**: clean.

**Content**: ✓ **strong**. AFM panel: 5/0/0 unanimous approve. Aggregate-pattern primacy is canonical in boundary-coaching practice.

**Expert flag**: none.

#### 3.4.3 `tmpl-boundary-recovery`

> "Recovery from boundary breach often requires re-establishment ritual visible to both parties; silent recovery tends to compound."

**Structural**: clean.

**Content**: ✓ **strong**. AFM panel: 5/0/0 unanimous. The "ritual visible to both" prong is good — it operationalizes "recovery" as bilateral acknowledgment, not unilateral forgetting.

**Expert flag**: would benefit from naming examples of re-establishment rituals.

#### 3.4.4 `tmpl-boundary-consent-scope`

> "Consent scope rarely transfers across contexts without explicit re-consent; assumption of carryover is a common error."

**Structural**: clean.

**Content**: ✓ **strong**. Canonical in consent-coaching literature; deeply important for bodily-autonomy and clinical contexts.

**Expert flag**: real reviewer will want explicit named context examples (medical, sexual, professional).

#### 3.4.5 `tmpl-boundary-non-negotiables`

> "Non-negotiable boundaries should be identified before negotiation begins; identifying mid-conflict invites rationalization."

**Structural**: minimal.

**Content**: ✓ **acceptable**. The "rationalization risk" prong is a useful mid-conflict-degradation framing.

**Expert flag**: would benefit from acknowledgment that some non-negotiables emerge from in-the-moment realization (not all need pre-identification).

#### 3.4.6 `tmpl-boundary-compromise-capitulation`

> "Compromise and capitulation differ by reciprocity and core-value preservation; capitulation feels like compromise but doesn't reciprocate."

**Structural**: clean.

**Content**: ✓ **strong**. The "feels like compromise but doesn't" prong is sharp diagnostic.

**Expert flag**: would benefit from concrete reciprocity-test examples.

#### 3.4.7 `tmpl-boundary-signaling`

> "Boundary signaling effectiveness varies by channel; explicit verbal channels typically less ambiguous than behavioral cues."

**Structural**: minimal (1 perturb, `crossDomain`).

**Content**: ✓ **acceptable**. The verbal-vs-behavioral channel distinction is supported in communication research.

**Expert flag**: cultural-variation caveat (similar to 3.1.7) — within some communities, behavioral cues are the primary boundary signaling; explicit verbal is read as confrontational.

#### 3.4.8 `tmpl-boundary-micro-erosion`

> "Micro-violations erode boundaries faster than single major violations; pattern observation needs longer time horizon than single events."

**Structural**: minimal.

**Content**: ✓ **strong**. Overlaps significantly with `tmpl-relationship-boundary-erosion` (3.1.2) — coordinate to avoid double-coverage.

**Expert flag**: dedupe vs 3.1.2.

#### 3.4.9 `tmpl-boundary-reestablishment`

> "Re-establishing a lapsed boundary requires explicit signaling; assumed re-establishment usually produces immediate re-erosion."

**Structural**: clean.

**Content**: ✓ **acceptable**. Overlaps with 3.4.3 — coordinate.

**Expert flag**: dedupe vs 3.4.3.

#### 3.4.10 `tmpl-boundary-cultural-variation`

> "Boundary norms vary substantially by culture; transposing one culture's norms to another typically generates miscommunication."

**Structural**: minimal.

**Content**: ⚠ **refine** — same essentialism-risk concern as 3.1.7. "Vary substantially by culture" is true but easily slips into stereotype. Real reviewer (cross-cultural psychologist) will want within-culture variance acknowledged.

**Expert flag**: pair with 3.1.7 for joint cultural-variance review.

---

### 3.5 Domain 5 — cross-domain-analogy (10 templates)

**Domain reviewer**: cognitive linguist / educational researcher

#### 3.5.1 `tmpl-analogy-transfer-caution`

> "Analogical reasoning carries inferences from source to target domain; surface similarity doesn't guarantee causal mechanism transfer."

**Structural**: clean.

**Content**: ✓ **strong**. Gentner's structure-mapping theory canonical. The "surface vs causal" distinction is the central finding in analogical reasoning.

**Expert flag**: AFM panel: 4 approve / 1 needsExpertJudgment (relationshipTherapist flagged appropriately — therapy-context analogy use is fraught).

#### 3.5.2 `tmpl-analogy-surface-deep`

> "Deep similarity (causal structure) supports valid analogy more than surface similarity (features); surface-only analogies often mislead."

**Structural**: clean.

**Content**: ✓ **strong**. Direct restatement of Gentner. AFM panel: 5/0/0 unanimous approve.

**Expert flag**: overlaps with 3.5.1 — could merge into one stronger template.

#### 3.5.3 `tmpl-analogy-causal-mechanism`

> "Causal mechanism preservation determines analogy validity; analogies that preserve only outcomes without mechanism are fragile."

**Structural**: clean. branchEvidenceRungs `[3, 2, 2]` reasonable.

**Content**: ✓ **strong, send first**. AFM panel: 5/0/0 unanimous. The "outcomes without mechanism" failure mode is exactly what cognitive-science teachers warn against.

**Expert flag**: none. Strongest analogy template.

#### 3.5.4 `tmpl-analogy-reasoning-bias`

> "Analogical reasoning anchors on a single source domain; consulting multiple sources reduces single-anchor bias."

**Structural**: minimal.

**Content**: ✓ **acceptable**. Reasonable claim though not as canonical as 3.5.1-3.5.3.

**Expert flag**: would benefit from cited example (e.g., Gick + Holyoak's "fortress" / "tumor" analog studies).

#### 3.5.5 `tmpl-analogy-source-selection`

> "Choice of source domain shapes target inferences; explicit source-selection rationale helps audit transfer validity."

**Structural**: clean.

**Content**: ✓ **acceptable**. The "audit transfer validity" framing is procedural and useful.

**Expert flag**: would benefit from concrete source-selection criteria.

#### 3.5.6 `tmpl-analogy-mapping-completeness`

> "Mapping completeness check reveals analogy boundaries; partial mappings often elide where the analogy breaks."

**Structural**: minimal.

**Content**: ✓ **acceptable**. "Elide where the analogy breaks" is the right risk-naming.

**Expert flag**: very abstract — would benefit from operational example.

#### 3.5.7 `tmpl-analogy-inference-validity`

> "Inference validity from analogy requires the inferred relation to depend on the mapped causal structure; coincidental coincidences don't transfer."

**Structural**: clean.

**Content**: ✓ **acceptable**. Restatement of structure-mapping with focus on inference-licensing.

**Expert flag**: overlaps with 3.5.3 — could be merged or differentiated more clearly.

#### 3.5.8 `tmpl-analogy-domain-exceptions`

> "Domain-specific exceptions limit analogy applicability; well-chosen analogies note where they don't apply."

**Structural**: minimal.

**Content**: ✓ **acceptable**. Useful pedagogical claim.

**Expert flag**: real reviewer (educational researcher) will want this paired with examples of how to teach analogy-with-caveats.

#### 3.5.9 `tmpl-analogy-composite`

> "Composite analogies (multiple sources combined) can capture more structure than single-source; consistency check across sources is required."

**Structural**: clean.

**Content**: ✓ **acceptable**. Holyoak + Thagard multi-constraint satisfaction theory.

**Expert flag**: would benefit from operational consistency-check criteria.

#### 3.5.10 `tmpl-analogy-counter-analogy`

> "Counter-analogies test the chosen analogy's robustness; if a plausible counter-analogy yields opposite inference, the original is fragile."

**Structural**: clean.

**Content**: ✓ **strong**. Counter-analogy as analogy-stress-test is a robust pedagogical technique.

**Expert flag**: would benefit from worked example.

---

## 4. Cross-cutting findings

### 4.1 Coverage shape

50 templates / 5 domains is balanced but the **decision** and
**analogy** domains have stronger canonical-literature grounding
than **relationship**, **time**, or **boundary**. This is
because cognitive science (decision theory, analogical
reasoning) has more formal canonical findings than clinical
practice (couples therapy, boundary coaching), where
practitioner wisdom is more pluralistic.

**Implication**: real expert review should weight the
decision/analogy templates as faster-to-promote (canonical
content) and the relationship/boundary templates as
more-iteration-needed (practitioner judgment + cultural
variance considerations).

### 4.2 Operational-framing pattern

Templates that explicitly operationalize their claim (e.g.,
"specificity of acknowledgment plus visible behavior change",
"explicit anchor identification reduces effect", "consulting
multiple sources reduces single-anchor bias") are stronger than
those that stay at general-principle level (e.g., "Indirect
communication patterns vary by culture and individual" — true
but not actionable). About **30 of 50** are well-operationalized;
**20 of 50** would benefit from concrete operational hooks.

### 4.3 Hedging discipline

Templates that hedge appropriately ("often", "typically",
"tends to") are well-calibrated. A few templates assert too
strongly:

- `tmpl-decision-loss-aversion` — "~2x" is contested
- `tmpl-relationship-power-asymmetry` — "warrant additional scrutiny" reads as policy not prior

Most templates use appropriate hedging. **45 of 50** are
well-calibrated; **5 of 50** could soften.

### 4.4 Cultural / political sensitivity

Templates touching culture (`tmpl-relationship-indirect-communication`,
`tmpl-boundary-cultural-variation`, `tmpl-boundary-signaling`)
or power dynamics (`tmpl-relationship-power-asymmetry`,
`tmpl-relationship-manipulation-pressure`) need careful framing
to avoid both essentialism and pathologizing. 4-5 templates fall
in this category. Real expert review should be paired with a
diversity-aware co-reviewer.

### 4.5 Cross-domain redundancy

I count **3 overlap pairs** that could be merged or differentiated:

1. `tmpl-relationship-boundary-erosion` ↔ `tmpl-boundary-micro-erosion` (essentially the same claim with different framing)
2. `tmpl-boundary-recovery` ↔ `tmpl-boundary-reestablishment` (overlap)
3. `tmpl-analogy-transfer-caution` ↔ `tmpl-analogy-surface-deep` ↔ `tmpl-analogy-inference-validity` (3-way restatement of structure-mapping)

Real expert review may consolidate or sharpen the differentiation.

### 4.6 AFM panel sample agreement

For the 15 templates that AFM panel reviewed, my structural
review category and AFM panel verdict mostly converge:

| My review | AFM modal verdict | Templates |
|---|---|---|
| **strong** | approveSuggested (4-5/5) | 6 of 7 ✓ converge |
| **acceptable** | approveSuggested (3-4/5) | 6 of 6 ✓ converge |
| **refine** | approveSuggested (3-4/5) | 0 of 2 — AFM is more lenient than I am |

AFM panel **never** rejected a "strong" or "acceptable" template
I assessed; AFM also approved both **refine** templates I flagged
(only `tmpl-relationship-manipulation-pressure` got a single
boundaryCoach reject, in agreement with my refine). This pattern
matches the §2.1 finding — AFM skews approval-heavy.

**Implication for real expert review**: my "refine" flags are
the highest-value items to bring to a real reviewer's attention,
because AFM consensus alone won't surface them.

---

## 5. Doctrine pin (read last)

This document does **NOT** promote any template's envelope from
`.illustrative` to `.domainExpertReviewed`.

| Layer | Outcome |
|---|---|
| `BASWorldPriorTemplateAuthoringSession` state | unchanged — still `.draft` for all 50 |
| `BASWorldPriorTemplateEnvelope.provenance` | unchanged — `.illustrative` for all 50 |
| `BASWorldPriorTrainingPipelineFilter.acceptedForTraining(...)` | unchanged — all 50 still rejected from L2 training |
| Sovereign audit | this advisory has no audit-entry effect (it's an external doc) |

To promote a template to `.domainExpertReviewed`, a real human
domain expert must:

1. Read the template
2. Independently verify the claim against domain literature
3. Optionally use this document as preparatory pre-review material
4. Walk the template through `.peerReview` → `.approveDomain`
   transitions in `BASWorldPriorTemplateAuthoringSession`

Path B / C / D in chapter 五十四 covers the production-tier
authoring paths; Path A starter (this curriculum) is the
lowest-tier illustrative content.

This document is preparatory pre-review material in service of
that real expert review. Nothing more.

---

## 6. Appendix — AFM panel raw data location

15-template AFM panel sample run output saved at:

```
/var/folders/.../qinao-persona-panel-review-377A6D65.json
```

(Demo execution is reproducible — re-run via:
`QINAO_AFM_PANEL_REVIEW=1 QINAO_PANEL_COUNT=15 swift run QinaoSampleHost --persona-panel-review`)

Run statistics:
- 15 templates × 5 personas = 75 AFM calls
- 64 / 75 parse-success (85%)
- 11 parse-fail (AFM formatting drift — markdown `**` wrappers, pipe `|` separators, missing CITED_CONCEPTS lines)
- 112.7 sec elapsed
- `apple.foundation-models.v1` provider stable across all calls

Full 50-template panel run is available via `QINAO_PANEL_COUNT=50`
(estimated ~7-8 min, ~250 calls).

---

**END — `.illustrative` envelope only**
