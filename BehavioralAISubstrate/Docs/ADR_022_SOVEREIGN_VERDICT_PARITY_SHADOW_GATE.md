# ADR-022 — Sovereign Verdict Parity Shadow Gate (#3, dormant-first)

> **Status: DESIGN (ch1044 严查 #3 / audit DEFER-2).** Specifies how to wire
> `BASSovereignTurnVerifier` as a **shadow** parity gate alongside the
> coordinator's hand-rolled `buildSovereignVerdict`, **dormant-first**: it
> observes + logs verdict drift, NEVER halts, and is byte-equal when off. A
> later **Phase 2** (separately gated, NOT in this ADR) flips the
> `coordinatorLaxer` signal to an actual session halt — only after Phase-1
> evidence proves parity. No code in this doc; it scopes the implementation.

## 1. The gap (verified ch1044 #3)

Production L14 verdict = `BASEBrainRuntimeCoordinator.buildSovereignVerdict`
(`EBrainRuntimeCoordinator+SovereignVerdict.swift:22`) via the pure
`computeVerdictDecision` core (`:103`). `BASSovereignTurnVerifier`
(`Sources/BASSovereign`, `:204`) **already exists** with exactly the right
contract — but it is **test-only / not wired** as a live cross-check. So the
coordinator is the *sole* verdict authority; there is no live detector for the
case the verifier was built to catch.

The verifier's own header states the invariant and the intended wiring:

- **Invariant (fail-closed):** `coordinatorLevel >= engineLevel` — the
  coordinator may be **stricter** (it sees deeper state), **never laxer**.
- `BASSovereignTurnParity.coordinatorLaxer` = "a turn the engine would have
  refused slipped through the coordinator" → **grounds to halt the session**.
- Intended wiring (verbatim): "after every turn, a host can project observable
  state from the `BASEBrainTurnResult` into `Observations`, run them through the
  real `BASSovereignVerdictEngine`, and compare levels."

So the verifier is the *designed* second authority; #3 is that it was never
connected. This ADR connects it — safely.

## 2. Two phases (only Phase 1 is in scope here)

| Phase | Behavior | Gate |
|---|---|---|
| **Phase 1 — SHADOW** (this arc) | Project turn state → run verifier → compare → **emit the parity report to a host sink + log**. NEVER halts. Default-OFF → byte-equal. | opt-in flag, default false |
| **Phase 2 — GATED** (future, separate ADR) | `parity == .coordinatorLaxer` → force a session halt (the real fail-closed gate). | only after Phase-1 evidence shows 0 spurious `coordinatorLaxer` across a large healthy corpus |

Phase 2 is **explicitly out of scope** — we do not flip a live safety gate until
the shadow has proven the projection is faithful (else a mis-projection would
halt healthy sessions). This is the "measure before core change" discipline.

## 3. Architecture — the ADR-021 carrier/fold/sink idiom

This is a textbook outer-loop slice (ADR-021 §2.2): opt-in flag + pure fold +
`@Sendable` sink, default-nil → identity → byte-equal.

```
buildSovereignVerdict(...) -> BASSovereignVerdict          // UNCHANGED production path
        │  (Phase 1, only if shadowParityEnabled)
        ▼
   project settled turn state ──► BASSovereignTurnObservations   // NEW, in BASHostKit
        ▼
   BASSovereignTurnVerifier(engine).verify(obs,                  // existing actor (BASSovereign)
        coordinatorLevel: verdict.verdictLevel)  -> Report{parity}
        ▼
   @Sendable paritySink?(report)   // host records/logs; NEVER mutates the verdict
```

- **enable-flag** `shadowParityEnabled: Bool = false` — when false, NONE of the
  above runs; `buildSovereignVerdict` returns byte-identically.
- **fold** = the existing, pure `BASSovereignVerdictEngine` (leaf, deterministic).
- **sink** `@Sendable (BASSovereignTurnVerifierReport) -> Void)? = nil` — host
  owns recording/logging. The coordinator's returned `BASSovereignVerdict` is
  **never** altered by the shadow result in Phase 1.
- **NEVER-EFFECTIVE-SAME-TURN / byte-equal:** off → no projection, no verify, no
  sink → identity. On → still byte-equal (the production verdict is unchanged;
  only an out-of-band observation is emitted).

## 4. The projection (the careful sub-task — implementation's main risk)

`BASSovereignTurnObservations` has 20 fields (`BASSovereignTurnVerifier.swift:44`).
The projection lives in **BASHostKit** (it can see `BASRiskCard`,
`BASActionPermit`, etc.; `BASSovereign` cannot). Each field must map to the
**same source the coordinator's BR-rule uses**, or the shadow will produce
spurious `coordinatorLaxer`. Mapping (to be verified per-field against the
coordinator at implementation time):

| Obs field (BR) | Source in settled turn state |
|---|---|
| `policyLineageMissing` (BR-006) | `policyLineage == nil` (coordinator already has `policyLineagePresent`) |
| `auditEntryMissing` (BR-012) | turn produced no audit entry |
| `runtimeUnstableInHighRisk` (BR-009) | `emergencyBrake` elevated **and** `riskCard` ≥ high |
| `riskPermitHeadConflict` (BR-010) | `actionPermit.mode == .answer` **and** `riskCard` ≥ high |
| `externalSideEffectWithoutSCT` (BR-003) | external-effect path without a sovereign commit token |
| `hostRemovalBypassed` (BR-005) | host-removal request unverified at finalize |
| `unauthorizedSelfMutation` (BR-007) | `updateTickets` non-empty without a matching warrant |
| `memoryOrHostWriteBypass` (BR-004) | memory admissions without a covering warrant |
| soft: `irreversibility/manipulation/uncertainty/gsi` | `riskCard` scalars |
| soft: `hostGateValue/quarantineCount/runMode/emergencyBrakeLevel/operation/evidenceSufficient` | settled frames |

Most sources are **already in scope at the `buildSovereignVerdict` call site**
(riskCard, actionPermit, emergencyBrake, policyLineage, updateTickets), so the
natural wiring point is there. The 3–4 flags without a direct local source
(BR-003/004/005/012 audit/SCT/host-removal/memory) are conservatively defaulted
toward making the **engine LAXER** (`false`/neutral) — **NOT** stricter.

> **Correction (the direction matters):** an earlier draft of this section said
> defaulting toward a *stricter* engine was safe. That is **backwards**. Making
> the engine artificially strict is exactly what risks a **false
> `coordinatorLaxer`** (engine level > coordinator level on a healthy turn). In a
> shadow we prefer a false negative (a missed divergence) over a false positive
> (a spurious halt-signal). So unsourced flags default `false`; they are wired in
> later Phase-1b increments as their real sources are threaded to this seam.

## 5. Red-line proofs (Phase 1)

- **Default-OFF byte-equal (红线 7):** `shadowParityEnabled=false` ⇒ no
  projection/verify/sink ⇒ `buildSovereignVerdict` output bit-identical.
  (Gate on `BASChapter1005ScaffoldInventoryPin` + a new byte-equal test.)
- **On is also byte-equal:** the production verdict is returned unchanged; the
  shadow only emits an out-of-band report. Phase 1 cannot alter a turn.
- **NEVER halts (Phase 1):** the sink is observation-only; no path forces a mode.
- **Replay-determinism:** the projection is a pure function of settled inputs;
  the engine is pure + leaf. Same turn → same parity.
- **不变量 #2 (神经不掌权):** the shadow changes no threshold/policy — it only
  compares two existing authorities.

## 6. Phase-1 acceptance (the gate to even consider Phase 2)

Run the shadow ON across a large healthy corpus (e.g. the ch1025 endurance
prompts + the canonical sweep). Required evidence before Phase 2 is designed:

- **0 `coordinatorLaxer`** on healthy turns (any occurrence = projection bug or a
  real coordinator-laxer defect — both must be root-caused first).
- Distribution of `match` vs `coordinatorStricter` recorded (stricter is
  expected + allowed; it proves the engine isn't spuriously over-firing).

Only with that evidence does flipping `coordinatorLaxer`→halt (Phase 2) become a
safe, separate ADR.

## 7. Honest scope

- **Real already:** the verifier, the invariant, the `Parity`/`Report` types, the
  pure engine — all exist (`BASSovereignTurnVerifier.swift`).
- **Phase-1a — LANDED (ch1044):** the pure projection
  `BASSovereignTurnObservationProjection.project(...)` + the observation-only
  `shadowVerify(...)` runner (`Sources/BASHostKit/BASSovereignTurnObservationProjection.swift`)
  + 8 tests (`BASSovereignTurnObservationProjectionTests`). `buildSovereignVerdict`
  is **untouched** → byte-equal by construction (not just by a flag). The 4
  unsourced BR-flags default engine-laxer (§4).
- **Phase-1b — PARTIALLY LANDED (ch1044):** the opt-in carrier
  `runShadowIfEnabled(observations:coordinatorLevel:verifier:sink:)` — a no-op /
  byte-equal when `verifier` is nil (default-OFF), emits the parity report to an
  `@Sendable` sink when enabled, swallows verify errors, never halts — plus a
  `hostGateValue` param on `project(...)` so the host can thread the real L13
  value. 3 new tests (no-op-when-off, emits-when-on, host-gate-threaded).
- **Phase-1c — LANDED (ch1044):** `projectFromResult(_:)` + the one-call
  `shadowVerifyResult(_:verifier:sink:)` source every field the result exposes
  (risk / permit / brake / budget→runMode / host-gate / update-tickets / policy
  lineage / the coordinator's own verdict level). A 12th test runs a real stub
  coordinator turn → project → shadow (opt-in, observation-only). A host turn loop
  can now shadow a turn in ONE line.
- **Phase-1d — LANDED (ch1044):** (a) host-friendly one-call
  `shadowParitySummary(result, enabled:)` / `shadowVerifyResultWithDefaultEngine`
  needing ONLY BASHostKit (no `BASSovereign` import) — the per-turn evidence
  one-liner; (b) **opt-in live wiring** in the device endurance runner
  (`BAS_SHADOW_PARITY=enabled`, default-OFF → byte-equal) so an on-device run
  gathers real evidence; (c) an **in-repo parity-evidence sweep** — 18 healthy
  combos run through the REAL coordinator core (`computeVerdictDecision`) vs the
  engine, **0 `coordinatorLaxer`** (the §6 healthy criterion, proven
  deterministically in CI). The 4 hard flags (BR-003/004/005/012) have **no
  faithful source at this seam** (verified — SCT-with-external-effect / audit-append
  / host-removal / memory-bypass are not on the turn result), so they stay
  engine-laxer-defaulted by **design, not omission**.
- **Phase-2 (deferred, 红线):** the `acceptable=false` / `.coordinatorLaxer`
  signal is now surfaced per turn; flipping it to an actual halt is the operator's
  evidence-gated decision (a real multi-turn run showing 0 spurious laxer). It is
  deliberately **NOT enabled here** — enabling a live safety gate without that
  evidence is exactly what §6 forbids.
- **Phase 2 (deferred):** the actual halt on `.coordinatorLaxer` — gated on §6
  evidence, separate ADR.
- This does **not** touch #2 (Ed25519 commit gate, audit DEFER-1) — that is a
  distinct sovereign arc.

## 8. Rigorous full-grid sweep finding (ch1044 全面优化)

`testParityFullGridSurfacesEveryCoordinatorLaxer` sweeps **1920 combos** (every
risk × brake × permit × runMode × lineage × protected-write), running the REAL
coordinator core (`computeVerdictDecision`) against the engine-via-projection:

- **Benign region (lineage present, `.engage` mode, no brake, low/medium risk):
  0 `coordinatorLaxer`** — the shadow never false-alarms on a normal turn (the
  enforced safety criterion; the test fails if any benign turn is laxer).
- **Adversarial region: ~46% `coordinatorLaxer`** (886/1920; dist = match 296 /
  stricter 738 / laxer 886). The two verdict authorities **genuinely diverge** on
  missing-lineage / elevated-mode turns: the engine escalates missing
  policy-lineage to `deadStop` (the verifier's `policyLineageMissing →
  policyBundleTampered` mapping in `makeContext`) while the coordinator gives
  `shadowLock`/`quarantine`.

### Bug the sweep caught + fixed
The first sweep showed **1242** laxer. Investigation found a **projection
faithfulness bug**: `unauthorizedSelfMutation` was mapped from the coordinator's
`needsProtectedWriteLane` ("this write needs REVIEW") — which is NOT BR-007
("self-mod WITHOUT a warrant") and also fires on permit `.delay`/`.replace`
(not self-mutation at all). That over-fired the engine into FALSE
`coordinatorLaxer`. Defaulting it engine-laxer (no faithful source at this seam,
like BR-003/004/005/012) dropped laxer **1242 → 886** and moved those cases to
the safe `coordinatorStricter` direction. `project(...)` lost its
`needsProtectedWriteLane` parameter as a result.

### Decisive consequence for Phase-2
This is the hard, in-repo evidence that **Phase-2 (auto-halt on
`coordinatorLaxer`) must stay OFF**: enabling it would halt ~46% of adversarial
turns. The prerequisite is **reconciling the two verdict authorities** (aligning
the engine's `policyBundleTampered` / escalation semantics with the coordinator's
lattice, or vice-versa) — a sovereign task beyond this shadow. The shadow has
done its job: it surfaced the divergence with hard numbers, and the benign path
is provably false-alarm-free.
