# Qinao Manifesto v5 — Performance is Doctrine

> A doctrine that cannot be measured is a wish.
> A doctrine without a regression gate is a memory.

**Status**: target doctrine spec, additive on top of v1–v4. Does not
replace any prior axis. Does not introduce a new invariant. Strengthens
the *testability* of every doctrine that came before.

**Source of authority**: implementation-grounded — every claim in this
document is bound to either an existing measurement primitive
(`BASLatencyStats`, `M179` perf gates, M334 throughput bench) or a
structural typed-pin in the substrate (`BASEvolutionLifecycleSession`,
`BASSovereignFragmentMerger`).

---

## §1 The four prior axes (recap)

Each axis was authored when the substrate could *demonstrate* its claim:

| Axis | What it added |
|---|---|
| v1 — Operational integrity | The three invariants (wake before answer / network never rules / host secrets stay out of base weights). Public contract surface. |
| v2 — 14-layer living net | L1 wick → L14 sovereign black ring as a single weave; each layer typed, each interface load-bearing. |
| v3 — Typed motherboard | Every doctrine claim becomes a Swift type; `BASSchemaVersioned` makes drift visible. M120 schema parity gate enforces it. |
| v4 — Agent fabric | Single-sovereign / single-host / single-state-graph / single-commit-mouth swarm of 9 seats. Coordination without coup. |

Each axis is single-purpose. None of them touches the others' invariants.
The compounding effect is what makes the substrate distinguishable from a
"chat plus tools" stack.

---

## §2 The v5 statement

**Every doctrine claim must be typed, measurable, and regression-gated.
A doctrine without a measurement primitive is not enforceable. A
measurement primitive without a regression gate decays. A regression gate
without a typed-pin lies.**

The three together form a *doctrine triple*:

```
         typed pin
            │
       (existence)
            │
            ▼
      measurement ──── regression gate
       (current)         (drift alarm)
```

v5 elevates the triple from "good engineering practice" to "doctrine
authoring rule": you cannot add a v6 axis without supplying all three
parts for every claim under it.

---

## §3 The four working examples

The substrate already ships four claims that obey the v5 triple. Each is
the proof that the rule is realisable, not a fresh promise.

### 3.A L13 lifecycle state transition < 100 µs

- **Typed pin**: `BASEvolutionLifecycleSession.applying(_:)` is pure
  value-type, 8 stages × 7 actions, no I/O.
- **Measurement**: M333 `EvolutionLoopDemo` traverses promotion +
  retraction + early-withdrawal paths in a single demo run.
- **Regression gate**: 4 invariant assertions + per-stage banner pin
  sub-millisecond. Any state-machine bloat that breaks the budget shows
  up the next time the demo runs.

### 3.B AFM E2E latency < 2 s (M179 baseline)

- **Typed pin**: `BASLatencyStats` (nearest-rank percentile) +
  `AppleFoundationOrganAdapter` env-gated tests.
- **Measurement**: 100-turn observation pipeline p50 ~0.76 ms, p95
  ~1.16 ms (M179); M334 throughput bench extends the gauge to full
  per-turn latency.
- **Regression gate**: `QinaoSampleHostThroughputBenchDemoTests` +
  per-percentile ceiling. CI can run the bench gated on a perf budget
  without coupling to the model's content.

### 3.C Multi-host fragment merger convergence ≤ N rounds

- **Typed pin**: `BASSovereignFragmentMerger.mergeOrdered(_:_:)` plus
  `BASSovereignCrossDeviceClock.merged(with:)` element-wise max.
- **Measurement**: M335 `MultiHostDemo` proves symmetric merge +
  commutative clock + isolated constitutions + no duplicate frames in
  one ledger pass.
- **Regression gate**: 6 typed-pin tests in
  `QinaoSampleHostMultiHostDemoTests`. A regression that breaks
  symmetry would fail before any audit divergence reaches downstream.

### 3.D Training pipeline block rate 100% on illustrative content

- **Typed pin**: `BASWorldPriorTrainingPipelineFilter.trainingProvenanceFloor = .domainExpertReviewed`.
- **Measurement**: `testPersonaPanelDoesNotPromoteEnvelope` (M67.4) —
  unanimous AI persona approval still keeps the envelope `.illustrative`.
- **Regression gate**: a removal of the floor would fail the typed
  filter test before the build even ships.

---

## §4 What v5 forbids

A future axis may not introduce:

1. A doctrine claim with no measurement primitive ("the model behaves
   well under load" without a load measurement).
2. A measurement primitive disconnected from a typed-pin ("p95 latency
   is 1.2 s" with no schema-bound caller path).
3. A regression gate that depends on the model's content ("the response
   uses respectful language" — testable in the wild, but not a
   substrate-level gate).
4. An axis whose claim cannot be falsified by the test suite.

The exclusion list is concrete because the temptation is concrete: every
"agent quality" surface invites soft claims. v5's job is to keep the
soft claims out of the doctrine layer and contained in product
documentation.

---

## §5 The relationship to v1–v4

v5 does **not** modify any prior invariant. It re-frames them:

| Axis | Pre-v5 framing | Post-v5 framing |
|---|---|---|
| v1 | Three invariants are the public contract. | Three invariants are the public contract; each carries a measurement primitive (lease lifecycle / three-signature gate / training-pipeline filter). |
| v2 | 14 layers compose into a living net. | 14 layers compose; per-layer regression gate exists or the layer is "schema-only" — and the schema-only label is itself a typed claim. |
| v3 | Schemas are typed. | Schemas are typed; the parity gate keeps drift visible. |
| v4 | 9-seat fabric coordinates without coup. | 9-seat fabric; coordination latency is bounded by the dispatch layer's typed contract. |

The change is small per axis. The compounding effect is large: a v6
authoring attempt now fails at the doctrine review stage if it cannot
produce the triple.

---

## §6 The measurement plane

v5's substrate-level home is `BASLatencyStats` plus the M334 throughput
bench. Together they form a *measurement plane* that v6+ axes can extend
without re-implementing the percentile algebra. The plane is intentionally
boring — `nearest-rank percentile`, `Swift.min` / `Swift.max`, no
exotic statistics — because the doctrine value is in the regression gate,
not the math.

The thermal twin (M334's `ThermalCycleStats`) extends the plane to L1
without forcing any new doctrine. Future axes that need a new measurement
domain (memory pressure, cross-device sync convergence) follow the same
pattern: typed-pin first, measurement second, regression gate third.

---

## §7 What is not in v5

- **No new invariant.** Adding a fourth invariant would dilute v1.
- **No SLA promises.** "p95 < 100 ms" is a regression alarm, not a
  customer commitment.
- **No model-quality claims.** Whether the LLM "thinks well" is product
  surface, not doctrine.
- **No multi-agent emergence claims.** v4 is about coordination
  primitives; v5 keeps the discipline of typing and measuring those
  primitives without claiming downstream behavioural properties.
- **No L13 self-evolution doctrine.** v5 makes self-evolution
  measurable but does not yet promise it. As of M341 the v5 triple is
  complete (typed pin via `BASEvolutionLifecycleStructuralFingerprint`,
  measurement via M333 `EvolutionLoopDemo`, regression gate via the
  fingerprint hash + drift detector). The candidate is now
  *authoring-ready* — actually authoring it is a separate decision.
- **No multi-instance distribution doctrine.** As of M342 the v5
  triple is complete (typed pin via M329 merger primitives,
  measurement plane via `BASMultiHostConvergenceMetric`, regression
  gate via `allInvariantsHold` + `failingInvariants`). Same status
  as L13: authoring-ready, not yet authored.
- **No adapter-trained L2 doctrine.** As of M343 the v5 triple is
  complete in repository scope (typed pin via `BASOrganTrainedWeightProvenance`
  + `BASOrganTrainedWeightFilter`, regression gate via the production
  tier filter). The measurement plane partially depends on EB-1
  (compute) + EB-2 (domain experts), so this candidate is
  *authoring-ready in repository scope* but the doctrine claim itself
  awaits real trained weights to measure.
- **Cthulhu doctrine status.** As of **M384–M389** the v5 triple is
  **triple-leg-complete** on the Cthulhu doctrine — meaning all
  three legs of the triple (typed pin / measurement / regression
  gate) are in place. This is distinct from "all wires firing on
  every turn", which is an empirical-coverage claim that depends
  on per-input substrate state. The 2026-05-02 empirical
  end-to-end run showed **8 of 9 wires** emit audit codes (M318
  abyssal-branch's `aggregateMagnitude` threshold was not crossed
  by the demo's medium-risk-level input — the wire is wired and
  testable, but its non-trivial path simply wasn't activated by
  that particular input). Triple-leg-complete + all-wires-firing-
  on-every-turn are different claims; the former holds, the
  latter is input-dependent and not a doctrine requirement. Pre-M384 the eight Cthulhu
  schemas (M287) had typed pins (the Swift structs themselves) plus
  audit-metadata measurement (M303–M305 / M316–M318 / M320–M321
  derives + signalRefs), but no regression gate that the substrate's
  decision paths actually consult them. M384–M388 ship four typed
  decision wires (`BASAbyssalPermitEscalation`,
  `BASAssertionCeilingGate`, `BASForbiddenLifecycleGate`,
  `BASSealEnvelope.Aggregate.policyHistogram`) plus a watcher-hint
  audit upgrade with red-line-7 regression pin; M389 ships
  `BASAbyssalDoctrineRedLine` (10 typed cases with white-paper
  references and forbidden-substring lists) plus a static lint test
  that pins the substrate's audit-emission vocabulary clean against
  every red line. The doctrine itself was already authored
  (CTHULHU_SPEC_V1 + ABYSSAL_VINF predate v5), so the only
  outstanding work was the v5 triple — now closed in repository
  scope. **Repository-scope production landing as of M391–M393**
  (chapter 八十八): `BASForbiddenLifecycleGate` is now load-bearing
  in the `BASUpdateTicketLifecycleCoordinator` actor path via three
  opt-in extension methods (`submitWithForbiddenGate` /
  `startTrialWithForbiddenGate` /
  `ingestTicketsWithForbiddenGate`); the M384/M385 escalation +
  cap hooks now run BEFORE `renderedOutput` projection so the
  rendered surface stays consistent with the persisted permit;
  and `QinaoSampleHost --cthulhu-doctrine-demo` exercises every
  wire in a 7-step banner with all invariants pinned. **Full
  end-to-end verification as of M398–M399** (chapter 九十):
  `M398CthulhuBehavioralSnapshotTests` adds 7 byte-equal
  behavioral snapshots (the regression-gate leg now covers
  decision-result drift in addition to M389's
  audit-vocabulary lint); `--cthulhu-end-to-end-demo` (M399)
  drives a real `BASHostRuntime` session and inspects the
  resulting `BASEBrainTurnResult` for evidence each wire ran in
  production (empirical run 2026-05-02: 8/9 wires emit audit
  codes, M384 escalates `.answer → .delay + [.draftOnly]`,
  M385 caps assertion ceiling to `meta-only`, M391 forbidden
  gate refuses the resulting ticket via `markRejected`).
  **What's still external (not in repo scope):** L4 training
  assets (EB-1: GPU/TPU compute), authoritative curriculum
  (EB-2: domain-expert sign-off), and W1-W5 real-world
  coordination (EB-3). These are the genuine doctrine gaps —
  they can't be closed by writing more Swift. The
  repository-scope claims above stop at substrate behaviour
  + sample-host verification.

---

## Appendix — v6/v7 candidates parked

The following are tracked as future doctrine candidates. Each is
deliberately *not* yet authored because the candidate has not been
through a doctrine-authoring decision — but as of M341–M343 (chapter
七十九 of the honesty board), all three legs of the v5 triple are now
in place for every parked candidate:

| Candidate | typed pin | measurement | regression gate | Authoring status |
|---|---|---|---|---|
| L13 self-evolution as doctrine | `BASEvolutionLifecycleStage` (8) + `BASEvolutionLifecycleAction` (7) + `BASEvolutionLifecyclePolicy` | M333 `EvolutionLoopDemo` traverses every path | **M341** `BASEvolutionLifecycleStructuralFingerprint` (typed shape + SHA-256 + drift detector) | **triple-complete, awaiting v6 authoring decision** |
| Multi-instance distribution doctrine | M329 `BASSovereignFragmentMerger` + `BASSovereignCrossDeviceClock` + `BASSovereignCrossDeviceLedgerFrame` | M335 `MultiHostDemo` proves symmetric merge + commutative clock | **M342** `BASMultiHostConvergenceMetric` (frames + duplicates + symmetry + clock divergence + wall-clock seconds) | **triple-complete, awaiting v6 authoring decision** |
| Adapter-trained L2 doctrine | **M343** `BASOrganTrainedWeightProvenance` + `BASOrganTrainedWeightFilter` (4-tier ladder mirroring M295.2 curriculum tier ladder) | EB-1 + EB-2 (external resources required, see `QINAO_EXTERNAL_BOTTLENECKS_BACKLOG.md`) | M67.4 `testPersonaPanelDoesNotPromoteEnvelope` + M343 production tier filter | **triple-complete in repository scope; doctrine authoring waits on EB-1/EB-2** |

The status "triple-complete, awaiting v6 authoring decision" means
v5 §4 no longer forbids authoring the doctrine. Whether to author it
is a separate decision: a v6 doctrine claim makes a substantive
promise about runtime behaviour, and that promise wants its own
review stage independent of the typed-primitive work that unblocked
it.

The L4 training assets / authoritative curriculum / W1-W5 items
remain external bottlenecks — see
`docs/QINAO_EXTERNAL_BOTTLENECKS_BACKLOG.md`. Those items cannot be
closed by writing more Swift in this repository regardless of how
many v5 triples get filled.

---

*Authored 2026-05-02 as附录 J 阶段 5 (M337) — direction A of the 全面进化
batch. Triple-completion update added 2026-05-02 (M344) after M341–M343
shipped the missing legs for all three parked candidates. v5 remains
the framing doctrine; the candidates move from "parked due to missing
leg" to "ready when authoring is wanted".*
