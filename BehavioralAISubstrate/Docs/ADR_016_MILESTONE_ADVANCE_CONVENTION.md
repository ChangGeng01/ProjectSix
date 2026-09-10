# ADR-016 — Milestone-Advance Convention (retroactive charter)

> **Status: ACCEPTED (retroactive charter, ch 1044).** ADR-016 is referenced
> ~1800 times across the code but was never written down (ch1044 foundational
> audit, MED-5). Unlike ADR-014/018/019/020, ADR-016 is **not a behavioral
> doctrine** — it is a *development-process convention*. This file records what
> the label means. It introduces no behavior and gates no runtime code.

## 1. What it is

ADR-016 is the **monotonic milestone-counter (M-number) advance convention**:
every substantive commit advances a global, never-reused `M####` milestone
counter, and the advance is stamped in the touched files' header comments as:

```
//   - ADR-016 advances M1428 → M1429
```

(real examples: `BASAuditObservationProjectionsBundleEmitter.swift:40` M1428→M1429;
`BASAuditObservationProjectionsCthulhuAggregatesBlock.swift:50` M1444→M1445;
`BASTurnRuntimeEngineObservationFailureLog.swift:47` M1524→M1525;
`BASEBrainTurnResultEvolutionBundle.swift:48` M1472→M1473).

It is also used as a **substrate-completion marker** — e.g. "ADR-016 — chapter
四百三十一 v1 substrate completion" (`BASMetalSubstrate/BASTensor.swift:62`,
`BASNeuralOp.swift:39`, `BASTensorShape.swift:48`).

## 2. What it is FOR

- **Per-change provenance.** Each M-number is a stable, greppable anchor tying a
  file/feature to the chapter + commit that introduced or last-advanced it. The
  many `*Doctrine` registry enums (and the SQL `chapter_doctrine_*` tables) key
  off these M-numbers + chapter numbers for the project's historical ledger.
- **Monotonic discipline.** M-numbers only ever increase and are never reused, so
  a higher M-number reliably means "later work." This pairs with "N consecutive
  byte-equality clean commits" counts the project tracks.
- **A completion/advance signal in headers**, so a reader of any file can see
  which milestone wave last touched it without consulting git.

## 3. What it is NOT (the honest scope)

- **NOT a runtime gate.** No code branches on ADR-016 or an M-number; it changes
  no behavior. (Audit-confirmed: every reference is a comment or a literal in a
  doctrine-registry/SQL row.)
- **NOT a behavioral doctrine** like ADR-014 (OPT-IN), 红线 7 (byte-equal), or the
  ADR-018/019/020 capability ADRs. Do not cite ADR-016 as a safety or behavior
  contract — cite ADR-014 / 红线 7 / the relevant capability ADR for those.
- **NOT verifiable by a test.** It is a bookkeeping convention; its only
  "enforcement" is the team stamping it consistently.

## 4. Relationship to the other contracts

| Contract | Kind | Defining doc |
|---|---|---|
| 红线 7 | byte-equal-when-off safety invariant | (stated in ADR-014 §4 + L8_ARC_SEAL) |
| ADR-014 | OPT-IN doctrine (behavioral) | `ADR_014_OPT_IN_DOCTRINE.md` |
| **ADR-016** | **milestone-advance convention (process)** | **this file** |
| 不变量 #1/#2/#3 | structural invariants | `L8_ARC_SEAL.md:553-558` |
| ADR-018/019/020 | capability ADRs (behavioral) | their own files |
| ADR-006/012 | risk-calibration doctrine | inline in `BASPolicy/BASRiskCalibration*.swift` (not yet standalone ADRs) |

## 5. Reference
`Docs/ARCHITECTURE_AUDIT_ch1044.md` (MED-5, which flagged ADR-014 + ADR-016 as the
two most-referenced-but-undefined doctrines). ADR-006/012/013 remain
referenced-but-without-standalone-docs (ADR-012's doctrine lives in
`BASRiskCalibrationBundle.swift`/`BASRiskCalibrationGate.swift` inline comments);
chartering those is a smaller follow-up if desired.
