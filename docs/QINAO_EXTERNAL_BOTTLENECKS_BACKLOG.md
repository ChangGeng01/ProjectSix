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

### Unblock condition (concrete predicates)

At least one of the following must become true. Each is a verifiable
binary state, not "more work":

- **(EB-1.A) Compute commitment**: a written commitment for at least
  one of:
    - 200 GPU-hours on A100 80GB (LoRA rank-32 adapter on a 50-template
      curriculum, ~2 epochs)
    - 500 GPU-hours on A100 80GB (LoRA rank-128 on a 200-template
      curriculum, ~3 epochs)
    - 1000+ GPU-hours for full adapter rank or larger curriculum
- **(EB-1.B) Apple Foundation Models adapter API access**: when
  Apple ships the adapter training toolkit publicly (post-WWDC 2026
  estimated), this potentially shortcuts the GPU-hour commitment by
  delegating training to Apple's pipeline.
- **(EB-1.C) Licensed external adapter**: a third-party adapter
  carrying a `BASOrganTrainedWeightProvenance` envelope at
  `.domainExpertReviewed` tier with verifiable expert attestation.
  This requires upstream supplier compliance with the M343 typed
  schema, which today no third-party shipper does.

### Verifiable state when unblocked

- A `swift run QinaoSampleHost --adapter-load-demo --adapter-id ...`
  command exists that loads a real `.domainExpertReviewed` adapter
  envelope and `BASOrganRegistry.adapter(for:role:)` returns the
  trained provider.
- `BASOrganTrainedWeightFilter.acceptedForProduction([...])` returns
  the trained adapter envelope (does not reject).

### Repository-side preparation (fair game; does NOT unblock)

- ✅ M343 typed pin for trained-weight provenance shipped
  (`BASOrganTrainedWeightProvenance`).
- ✅ M67.4 typed pipeline filter rejects sub-tier curriculum at
  the curriculum boundary (`testPersonaPanelDoesNotPromoteEnvelope`).
- ✅ M343 outbound filter rejects sub-tier weights at the runtime
  registry boundary (`BASOrganTrainedWeightFilter.productionTierFloor`).
- ⚠️ Could ship: a mock `--adapter-load-demo` mode that exercises
  the registry path with a synthetic envelope (would help verify
  the load path is wired without unblocking the real bottleneck).

### Cross-references

- v1 invariant #3 (README "Host secrets stay out of base weights")
- v7 §4 ("Not cross-host weight sharing")
- M343 trained-weight provenance + filter
- Methodology Lesson 5 — triple-completion before authoring

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

### Unblock condition (concrete predicates)

A real human couples — therapist, decision scientist, time-management
researcher, boundary coach, cognitive linguist — must:

1. **Audit per template**: read each template against domain literature
   (typical estimate: 30 min per template for an experienced expert
   familiar with the substrate's typed schema).
2. **Sign through M51 typed attestation pathway**: bind professional
   identity (license number / institutional affiliation) to the
   `BASWorldPriorAttestation` via the typed authoring session.
3. **Accept liability**: the signature carries professional liability
   for downstream use of that template in training.

### Verifiable state when unblocked

- At least one template's `BASWorldPriorTemplateProvenance` is
  `.domainExpertReviewed` (not `.illustrative` / `.aiAdvisory` /
  `.peerReviewed`).
- `BASWorldPriorTrainingPipelineFilter.isPermittedForTraining(envelope)`
  returns `true` for that template.
- The signed attestation is queryable from the audit ledger by
  `BASSovereignAuditLedger.entry(forID:)`.

### Repository-side preparation (fair game; does NOT unblock)

- ✅ M295.1 50-template starter curriculum at `.illustrative` tier
  (chapter 五十四).
- ✅ M327 AI advisory simulation gives reviewers a structural
  cross-check.
- ✅ M326 5-persona panel demo (`--persona-panel-review`) provides
  per-template AI second-opinion bundle.
- ✅ M53 `AuthoringProgressReport` + `AuthoringBatchReport` typed
  dashboards let reviewers track progress.
- ⚠️ Could ship: a reviewer onboarding bundle (PDF + sample
  attestation flow) — but this only reduces friction; doesn't
  unblock the bottleneck without the actual reviewer.

### What does NOT close this item

- AI persona panels do not promote envelope tier (M67.4 typed pipeline
  filter pin enforces this).
- Bulk-importing existing public-domain text does not close it — the
  attestation requires a *real* domain expert to bind their identity to
  each template, not a textual citation.
- An expert who *would* sign but hasn't actually done so does not
  close it. Verbal commitment ≠ M51 attestation.

### Cross-references

- v1 invariant #3 (curriculum side of the host-secrets gate)
- M67.4 / M295.2 inbound training pipeline filter
- EB-1 (compute commitment is needed AFTER the curriculum is
  expert-attested, to actually train an adapter)
- Methodology Lesson 4 — repository-side preparation vs external
  bottleneck

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

### Unblock condition (concrete predicates per W-item)

- **W1 — pilot user**: a named human signs a 4-week commitment letter
  and has a working development build of a Qinao-hosted application
  installed on their primary device.
- **W2 — secondary device**: a second iPad or Mac is on someone's
  physical desk, paired via iCloud, with the development build
  installed and the M329 cross-device sync demo runnable end-to-end
  on real hardware (not the in-process two-host fixture).
- **W3 — adapter training cycle**: depends on EB-1 + EB-2; a real
  adapter trained from `.domainExpertReviewed` curriculum is loaded
  into a real host and serves at least one production session via
  `BASOrganRegistry`.
- **W4 — App Store submission**: Apple Connect submission queue
  contains at least one Qinao-hosted application; first review
  feedback (accept / reject with reasons) is in hand.
- **W5 — CI / TestFlight pipeline**: a working `.ipa` build is
  produced by GitHub Actions and uploaded to TestFlight; at least
  one external tester has installed and run it.

Each item is binary: either it's true or it isn't. "Drafting" /
"considering" / "scoping" do not move the indicator.

### Repository-side preparation (fair game; does NOT unblock)

- ✅ All three v1 invariants enforced at substrate boundary so a
  pilot cannot accidentally violate them by mis-configuration.
- ✅ 11 sample-host demo modes (M306 / M325 / M326 / M328 / M329 /
  M333 / M334 / M335 / M306-M335 lineage / M313 / M314) cover every
  contract the pilot would exercise.
- ✅ M325 / M326 honest-truth demo modes so a pilot's first session
  exercises real behaviour, not a happy-path stub.
- ✅ v6 + v7 manifestos pin the substantive runtime contracts
  the pilot would observe.
- ⚠️ Could ship: a one-page "what to do when you become a pilot"
  onboarding doc — but this only smooths W1's entry, doesn't close W1.

### What does NOT close this item

Writing more demos does not close W1 (a pilot human must say yes).
Writing more sync strategies does not close W2 (a secondary device must
exist on someone's desk). Writing more typed schemas does not close W4
(Apple's review process must run). Writing more docs does not close
W5 (a real CI runner must be configured and a real TestFlight
account must exist).

### Cross-references

- v6 §1 (the lifecycle promise W1 pilot would observe in action)
- v7 §1 (the multi-host promise W2 secondary-device would exercise)
- EB-1 + EB-2 (W3 depends on both)
- Methodology Lesson 4 — preparation does not unblock the external
  resource itself

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
- v6 doctrine "Self-Evolution Without Drift" (`QINAO_MANIFESTO_V6_DOCTRINE.md`)
- v7 doctrine "Multi-Instance Audit Convergence" (`QINAO_MANIFESTO_V7_DOCTRINE.md`)
- Review methodology lessons (`QINAO_REVIEW_METHODOLOGY_LESSONS.md`)
- chapter 七十七.7 / 七十八.10 surgical-scope-all-close 实证
- chapter 七十八.11 一句话总结
- chapter 七十九.12 + 八十 仓库 surgical scope 真实状态
- M67.4 typed pipeline filter `testPersonaPanelDoesNotPromoteEnvelope`
- M343 trained-weight provenance + filter (outbound mirror to M67.4)

---

*Created 2026-05-02 as M339 — direction "外部瓶颈先记下" of the
内部加强完善 batch (M339-M344). Items here are deferred to external
resource coordination and explicitly do not block any further
repository-side milestones.*
