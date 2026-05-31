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
(BR-003/005/012 audit/SCT/host-removal) must be threaded in or conservatively
defaulted; a conservative default that makes the **engine** stricter is safe
(it can only yield `coordinatorStricter`, never a false `coordinatorLaxer`).

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
- **This ADR:** design only — no code.
- **Implementation (next):** (a) the BASHostKit projection (§4), (b) the opt-in
  shadow wiring at `buildSovereignVerdict` (default-OFF), (c) the `@Sendable`
  sink, (d) byte-equal-off + projection-faithfulness tests.
- **Deferred:** Phase 2 (the actual halt) — gated on §6 evidence, separate ADR.
- This does **not** touch #2 (Ed25519 commit gate, audit DEFER-1) — that is a
  distinct sovereign arc.
