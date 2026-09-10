# ADR-014 — OPT-IN Doctrine (retroactive charter)

> **Status: ACCEPTED (retroactive charter, ch 1044).** This doctrine has governed
> the substrate since ~ch 960 and is referenced ~1600 times across the code, but
> was never written down as a standalone ADR (the ch1044 foundational audit,
> MED-5, flagged it as "referenced everywhere, defined nowhere"). This file
> records the doctrine that the code already follows — it does NOT introduce new
> behavior. Companion to 红线 7 (additive byte-equal) and ADR-016 (milestone
> advance).

## 1. The doctrine (one sentence)

**Every capability that could change a turn's output is introduced OFF by default;
a host must explicitly opt in (a flag, a non-nil slot, an injected service), and
with every such switch at its default the substrate is byte-equal to the
behavior before the capability existed.**

## 2. Why (the substrate's safety posture)

The substrate is a behavioral-AI decision core whose default path is audited,
pinned, and trusted. New cognition (loops, evolution, agent fabric, evidence
resolution, thermal gating, …) is added continuously, but **adding a capability
must never silently change what an existing host does.** OPT-IN makes every
addition a *reviewable, host-elected* behavior change rather than an ambient one.
This is the precondition that lets the substrate grow without re-validating every
host on every commit.

## 3. The canonical OPT-IN shapes (as used in code)

1. **A default-false `Bool` flag** on the coordinator. Example:
   `BASEBrainRuntimeCoordinator.deliberationLoopEnabled: Bool = false`
   (`EBrainRuntimeCoordinator.swift`). The guarded block runs only when true.
2. **A default-nil carrier slot** (host-held state IN). Examples:
   `evidenceLedger: BASEvidenceLedger? = nil`,
   `pendingTrialLedgerIn: BASShadowTrialFeedbackLedger? = nil`. Nil ⇒ the
   consuming seam computes a no-op (e.g. credit 0 / empty resolve).
3. **A default-nil `@Sendable` sink** (observation OUT). Examples:
   `provisionalVerdictSink`, `resolvedEvidenceSink`, `resolvedTrialSink`. Nil ⇒
   nothing is emitted; the sink can never feed render/seal/verdict/hash.
4. **A default-nil injected service / runtime** (capability slot). Examples:
   `agentFabric: BASAgentFabricRuntime? = nil`; the `memoryEventLog` /
   `projectionBlockEmissionHandler` slots. Nil ⇒ the capability is absent.

The coordinator is a value-type `struct`, so cross-turn opt-in state lives in a
host-held carrier re-injected each turn (it is never coordinator-mutated). This
is why the carrier+sink pattern (2)+(3) is the canonical cross-turn shape.

## 4. The contract each OPT-IN must satisfy

- **Default = OFF.** Flag `false`, slot/sink `nil`. No exceptions.
- **Byte-equal when off** (红线 7). With the switch at default, the full result
  (`BASEBrainTurnResult`) is byte-identical to the pre-capability behavior. The
  fast witnesses are the per-suite on/off tests (e.g.
  `BASChapter1039DeliberationLoopTests.testSinglePassWhenDisabled` + the real-host
  on/off comparison) and the `loopCount==1` pin.
- **Observation-only OUT.** Any sink/emission must NOT mutate render, seals, the
  sovereign verdict's inputs, governance, or any canonical-bytes/hash path. It may
  only be read by a host that chose to wire it.
- **Never relaxes a hard control.** An opt-in feature may add caution / pick a
  safer action / raise an assessment, but may NEVER relax a kill switch, the
  hard-no-go constitution block, the L14 verdict's hard rules, or push a permit
  toward less restriction. (Audit-confirmed: a grep of every opt-in flag/carrier
  identifier against the verdict / kill-switch / hard-no-go enforcement files is
  empty.)
- **Replay-deterministic.** Same inputs + same opt-in state ⇒ same output.

## 5. Relationship to the dangerous-endpoint closures

OPT-IN is *necessary but not sufficient* for a dangerous capability. Several
capabilities that COULD be opt-in were still CLOSED because opt-in alone doesn't
make them safe:
- **P1.5b** (sovereign-gated caution REDUCTION) — closed (ADR-019 §14):
  architecturally incompatible with verdict-after-render.
- **P4** (feedback → policy/threshold mutation) — closed NO-GO (ADR-018 §12):
  unsafe-by-construction; the substrate's own `BASRiskCalibrationGate` (ADR-012)
  deliberately forbids per-turn auto-derived threshold mutation (不变量 #2).
- **P5** (version-tree branch/merge) — deferred (ADR-018 §13): gate-safeable but a
  multi-session sovereign-reviewed arc.

So the doctrine ladder is: **OPT-IN (default-off, byte-equal) → + caution-only/
non-hard-relaxing → + (for dangerous directions) sovereign gate + cap +
reversibility → or CLOSE if even that can't make it safe.**

## 6. Verification / enforcement status (honest, per the ch1044 audit)

- **By construction:** the V2/nativeV2 runtime path re-dispatches to V1
  (`EBrainHostRuntimeSynthesis.swift`), and opt-in seams are guarded blocks whose
  default skips them — so byte-equality holds by code shape.
- **By fast witness:** the per-suite on/off tests + the `loopCount==1` pin + the
  `BASChapter602` init-signature pin.
- **GAP (audit HIGH-2):** there is NO substrate-wide automated byte-equality
  regression harness in CI — the `BASStressSweepCanonical60Driver` is stub-only
  and `pre-commit-gates.sh` does not enforce red-line 7. OPT-IN/byte-equal is
  therefore a *disciplined convention with selective structural backing*, not a
  fully automated guarantee. Closing this gap is the HIGH-2 follow-up.

## 7. References
ADR-018/019/020 (every phase is opt-in per this doctrine); 红线 7; ADR-016;
不变量 #1/#2/#3 (`L8_ARC_SEAL.md`); `Docs/ARCHITECTURE_AUDIT_ch1044.md` (MED-5).
