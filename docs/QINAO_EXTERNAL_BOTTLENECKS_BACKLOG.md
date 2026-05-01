# Qinao External Bottlenecks Backlog

**Status**: tracked, not in active scope. Each item below cannot be
closed by writing more Swift in this repository. Recording them here
makes the boundary between "repository surgical scope" and "external
resource coordination" explicit.

**Convention**: each entry lists (1) what's missing, (2) what would
need to be true for the item to become unblocked, (3) the smallest
possible repository-side preparation work that does not depend on the
external resource. Repository-side preparation is fair game; the
unblock condition is not.

---

## EB-1 · L4 World-Prior 训练资产（base-weight pretraining）

### What is missing

The substrate L4 layer ships typed contracts (`BASWorldPriorVault`,
`BASWorldPriorTemplate`, `BASWorldPriorAttestation`, the M64-67 typed
training pipeline filter) but has zero trained weights riding on them.
The `BASWorldPriorAdapter` typed envelope can carry an adapter-trained
L2 layer, but no such adapter has been trained.

### Unblock condition

At least one of the following must become true:

- **Compute available**: GPU/TPU minutes for at least the curriculum
  size needed to fine-tune a small adapter (rough order: A100 × tens
  of hours for an Apple Foundation Models compatible adapter, depending
  on adapter rank + curriculum size).
- **External adapter accepted**: a third-party adapter that satisfies
  the M67.4 `domainExpertReviewed` envelope contract is licensed and
  drops into the `BASOrganRegistry` provider chain.

### Repository-side preparation (fair game)

- Add typed pin for trained-weight provenance — done in M343
  (`BASOrganTrainedWeightProvenance` envelope).
- Tighten the M67.4 typed pipeline filter so any `.illustrative` or
  `.aiAdvisory` adapter gets rejected at the runtime registry layer
  (already in place; verified by `testPersonaPanelDoesNotPromoteEnvelope`).
- Document an explicit rejection path so a host that ships the wrong
  envelope gets a clear typed error rather than silent fallback.

### What does NOT close this item

Writing more curriculum templates does not close it (that's EB-2).
Writing more typed contracts does not close it (the typed surface is
already there). Mocking weights does not close it (typed pipeline filter
catches this by construction).

---

## EB-2 · Authoritative Curriculum Content (M295.1+ domainExpertReviewed)

### What is missing

The M64-67 typed pipeline distinguishes four envelope tiers:
`.illustrative` < `.aiAdvisory` < `.peerReviewed` < `.domainExpertReviewed`.
Only the top tier qualifies for L2 / L4 training. Today the curriculum
shipped via the M295.1 starter (chapter 五十四) is `.illustrative` —
50 templates AI-drafted, useful as scaffolding, not authoritative.

### Unblock condition

A real human couples — therapist, decision scientist, time-management
researcher, boundary coach, cognitive linguist — must:

1. Audit each template against domain literature.
2. Sign through the M51 typed attestation pathway with their professional
   identity bound to the `BASWorldPriorAttestation`.
3. Accept the legal / professional liability that comes with that signature.

### Repository-side preparation (fair game)

- M327 AI advisory simulation already in place — gives expert reviewers
  a starting cross-check.
- M326 5-persona panel demo (`--persona-panel-review`) gives reviewers
  a per-template AI second-opinion bundle.
- The M53 `AuthoringProgressReport` + `AuthoringBatchReport` typed
  dashboards let reviewers track their own progress without a custom
  reviewer harness.

### What does NOT close this item

- AI persona panels do not promote envelope tier (M67.4 typed pipeline
  filter pin enforces this).
- Bulk-importing existing public-domain text does not close it — the
  attestation requires a *real* domain expert to bind their identity to
  each template, not a textual citation.

---

## EB-3 · W1–W5 Real-World Coordination

### What is missing

The W1-W5 backlog (introduced in chapter 二十八.6 and tracked across
chapters 三十一 / 七十.5 / 七十六.4) covers:

- **W1** Recruit + onboard at least one host pilot user willing to commit
  to a 4-week multi-session integration.
- **W2** Procure at least one secondary device (iPad / Mac) for a host
  to exercise the M329 cross-device sync demo against a real second
  device, not the in-process two-host fixture.
- **W3** Run a real adapter training cycle against the M64-67 typed
  pipeline (depends on EB-1 + EB-2).
- **W4** Submit at least one Qinao-hosted application to the App Store
  to surface real OS / sandbox / privacy review feedback.
- **W5** Set up a CI / TestFlight build pipeline for a real host
  application.

### Unblock condition

Coordination outside the repository: people, devices, money,
calendar time. None of W1-W5 can be discharged by writing Swift.

### Repository-side preparation (fair game)

- All three invariants enforced at substrate boundary so a pilot
  cannot accidentally violate them by mis-configuration.
- M306 multi-session demo + M335 multi-host demo + M328 dual-key demo
  + M329 cross-device sync demo + M306-M335 coverage of every contract
  the pilot would exercise — sample-host channels are the on-ramp.
- M325 / M326 honest-truth demo modes so a pilot's first session
  exercises real behaviour, not a happy path stub.

### What does NOT close this item

Writing more demos does not close W1 (a pilot human must say yes).
Writing more sync strategies does not close W2 (a secondary device must
exist on someone's desk). Writing more typed schemas does not close W4
(Apple's review process must run).

---

## Recording rules

- **Items added here cannot be closed by code in this repository.** If
  a backlog item turns out to be writable in Swift after all, it is
  promoted to the regular surgical backlog (e.g., honesty board "next
  candidates" section) and removed from this file.
- **Each item must list a verifiable unblock condition.** "More work"
  is not a condition; "$X compute available" or "expert Y signs through
  attestation Z" are conditions.
- **Repository-side preparation is fair game and tracked separately.**
  Preparation work goes into the regular milestone numbering. Preparation
  does not unblock the external item; it makes the eventual unblock
  cheaper.

---

## Cross-references

- v5 doctrine `appendix v6/v7 candidates parked` (`QINAO_MANIFESTO_V5_DOCTRINE.md`)
- chapter 七十七.7 / 七十八.10 surgical-scope-all-close 实证
- chapter 七十八.11 一句话总结
- M67.4 typed pipeline filter `testPersonaPanelDoesNotPromoteEnvelope`

---

*Created 2026-05-02 as M339 — direction "外部瓶颈先记下" of the
内部加强完善 batch (M339-M344). Items here are deferred to external
resource coordination and explicitly do not block any further
repository-side milestones.*
