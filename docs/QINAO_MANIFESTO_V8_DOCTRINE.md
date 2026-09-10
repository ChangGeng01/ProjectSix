# Qinao Manifesto v8 — Adapter-Trained Weight Trust Filter

> The substrate may train its own adapters.
> But it may never train them on content it didn't trust.

**Status**: target doctrine spec, additive on top of v1–v7.
Authored 2026-05-02 (chapter 九十一.7) after M343 supplied
`BASOrganTrainedWeightProvenance` + `BASOrganTrainedWeightFilter`,
satisfying the v5 doctrine triple in repository scope. v8 makes
a substantive runtime promise about which adapter weights may
participate in production inference.

**Source of authority**: implementation-grounded — every claim is
bound to a typed primitive, a measurement, and a regression gate
(per v5 doctrine triple). The measurement leg's *full real-world
extension* depends on EB-1 (compute) + EB-2 (domain experts);
**v8 is authorable in repository scope today** because the
typed primitive already physically blocks untrusted-provenance
weights from production paths regardless of training compute
availability.

---

## §1 The promise

The substrate already ships:

- **`BASOrganDeterministicAdapter`** — a fully-deterministic
  adapter for tests and stub paths.
- **`AppleFoundationOrganAdapter`** — a wrapper around Apple
  Foundation Models (uses Apple's pre-trained weights; substrate
  doesn't own the training).
- **`BASOrganRegistry`** — selects the most-recent on-device
  adapter for each role.

What's NOT shipped today: substrate-trained adapter weights.
That's gated on EB-1 (GPU/TPU compute for actual training) +
EB-2 (domain-expert sign-off on training data). The day those
external resources arrive, the substrate will start producing
adapter weights of its own — and v8 governs what may
participate.

**v8 promises**: adapter weights flowing into the production
inference pipeline carry a typed `BASOrganTrainedWeightProvenance`
envelope, and the typed filter `BASOrganTrainedWeightFilter`
physically rejects any envelope whose tier is below
`.domainExpertReviewed`. No untrusted-provenance weights reach
production inference. The path is closed by construction, not
by review process.

---

## §2 The triple

| Leg | Primitive |
|---|---|
| Typed pin | `BASOrganTrainedWeightProvenance` (tier ladder: `.illustrative` (0) / `.aiAdvisory` (1) / `.peerReviewed` (2) / `.domainExpertReviewed` (3)) + `BASOrganTrainedWeightFilter.productionTierFloor = .domainExpertReviewed` |
| Measurement | `BASOrganTrainedWeightFilter.filter(_:against:)` returns typed `.permitted` / `.rejected(BASOrganTrainedWeightRejection)` per envelope. `M343OrganTrainedWeightProvenanceTests` (16 tests) pin every tier-rejection combination. The substrate's existing `M67.4 testPersonaPanelDoesNotPromoteEnvelope` regression-gates the analogous `BASWorldPriorTemplateEnvelope` filter at the curriculum-content level. v8 mirrors that pattern at the trained-weight level. |
| Regression gate | M343 production tier filter rejects every envelope below `.domainExpertReviewed` regardless of how many AI-advisory reviews approve it (M67.4 doctrine: `unanimous AI persona approval keeps envelope .illustrative`). The same physical-block applies at the trained-weight layer. |

---

## §3 The four rejection paths

When `BASOrganTrainedWeightFilter.filter(envelope, against: floor)` runs, the four typed rejection reasons are:

1. **`tierBelowFloor`** — envelope's tier (e.g. `.aiAdvisory`)
   ranks below the production floor (`.domainExpertReviewed`).
   Most common case. Catches AI-only-reviewed weights from
   reaching production.
2. **`missingDomainAttestation`** — tier is
   `.domainExpertReviewed` but `attestation == nil`. The doctrine
   requires expert attestation be physically present, not just
   claimed.
3. **`expiredAttestation`** — attestation present but past its
   `validUntil` deadline. Forces re-review of expert-approved
   weights on a cadence.
4. **`missingTrainingDataProvenance`** — tier is
   `.domainExpertReviewed` but `trainingDataProvenanceRefs` is
   empty. The doctrine requires every domain-expert-reviewed
   weight cite the curriculum / dataset source so the v6
   self-evolution lifecycle can audit upstream.

All four rejections produce a typed `BASOrganTrainedWeightRejection`
that audit ledger consumers can grep. Hosts cannot bypass them.

---

## §4 What v8 forbids

A future trained-weight pipeline may not introduce:

1. A weight envelope skipping the `BASOrganTrainedWeightFilter`
   (some "fast path" for testing/staging).
2. A custom `productionTierFloor` lower than `.domainExpertReviewed`
   shipped to production hosts.
3. An attestation backdated to past `validUntil` to retroactively
   permit expired weights.
4. A `trainingDataProvenanceRefs` populated with fictional refs
   to satisfy the missing-provenance check.

The exclusion list is concrete because the temptation is
concrete: under deadline pressure to ship trained adapters,
shortcuts will be tempting. v8's job is to close those shortcut
paths at the typed-primitive layer so they cannot be opened
without the same-PR review.

---

## §5 The relationship to v1–v7

v8 does **not** modify any prior invariant. It re-frames them:

| Axis | Pre-v8 framing | Post-v8 framing |
|---|---|---|
| v1 | Three invariants are the public contract. | Same; trained weights compose under invariant #3 (host secrets stay out of base weights — extended to: only domain-expert-reviewed weights may flow into the training pipeline). |
| v3 | Schemas are typed. | Adapter trained-weight provenance is typed too. |
| v5 | Performance is doctrine. | v8 is the third "candidate parked" axis to reach v5-triple-complete + author. |
| v6 | Self-evolution lifecycle shape is fixed. | The lifecycle's terminal `.distilled` stage feeds into the trained-weight pipeline; v8 governs what may exit `.distilled` into production. |
| v7 | Multi-instance audit converges. | Trained weights propagate across host instances via the same audit-merge primitives; v8 ensures every propagated weight is provenance-typed. |

---

## §6 The production-tier doctrine (operational layer)

In repository scope today (no real trained weights yet), the
production tier floor is set to `.domainExpertReviewed` by
default. Hosts may override via a typed configuration option,
but v8 doctrine forbids overriding it BELOW `.peerReviewed` —
the next-lower tier — even for staging environments. This
preserves a safety floor: even staging never trains on
`.illustrative` content.

Operationally:
- Production: `.domainExpertReviewed`
- Staging: `.peerReviewed` (allowed override)
- Test fixture: `.aiAdvisory` (allowed override; never reaches
  production code path)
- `.illustrative`: never an allowed floor

---

## §7 What is not in v8

- **No claim about trained-weight effectiveness.** Whether the
  resulting adapter performs well on benchmarks is a separate
  measurement, gated on EB-1 (compute) for the actual training
  run. v8's claim is purely about provenance gating, not output
  quality.
- **No claim about expert reviewer credentialing.** v8 doesn't
  define who counts as a "domain expert"; that's EB-2 territory
  (real domain expert sign-off process). The substrate accepts
  whatever the host's attestation fixture supplies; it just
  requires the attestation be typed + non-expired + present.
- **No claim about training data quality.** The substrate
  requires `trainingDataProvenanceRefs` be populated; it does
  not validate the refs point to anything in particular. That
  validation belongs at the curriculum-content layer (M67.4
  enforces the analogous claim for AI-advisory templates).
- **No claim about the training pipeline itself.** The training
  pipeline is host-owned. v8 governs only what may *exit* the
  training pipeline into the inference path.

---

## Appendix — relationship to EB-1 and EB-2

v8 is authorable today **in repository scope**. The full
real-world doctrine landing requires:

- **EB-1 (compute)**: actual GPU/TPU training of adapter weights
  to produce the first non-fixture `BASOrganTrainedWeightProvenance`
  envelopes.
- **EB-2 (domain experts)**: real expert sign-off populating
  `BASOrganTrainedWeightAttestation` rather than fixture data.

When EB-1 + EB-2 arrive, v8 is the doctrine that governs what
the substrate accepts. Today, the typed primitive + filter +
M343 tests guarantee that any future training-pipeline output
must satisfy v8 — the gate is closed regardless of when the
gate's inputs start flowing.

This is the essence of v5: doctrine is what the typed primitives
enforce, not what the documentation promises. v8 inherits that
posture: the gate is real today even if no trained-weight
envelope has flowed through it yet.

---

*Authored 2026-05-02 as chapter 九十一.7 — third "v6/v7
candidate parked" axis to reach v5-triple-complete + author.
v6 (self-evolution shape) and v7 (multi-instance convergence)
preceded; v8 closes the third candidate. v9+ candidates remain
open if future doctrine surfaces emerge that satisfy the v5
triple.*
