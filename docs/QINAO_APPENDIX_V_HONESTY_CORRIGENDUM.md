# 附录 V Honesty Corrigendum — Chapter 二百七十四 / M761

This document corrects the "all 6 stages closed" framing from
the chapter 二百七十一 final summary. Every chapter from this
session (二百四十八-二百七十三) has a ship record, but **ship
record ≠ production wired**. This corrigendum makes that
distinction explicit per chapter.

## Why this exists

In my chapter 二百七十一 self-assessment I named four real
gaps:

1. **Production wiring lag** — typed primitives ready but
   consumers not wired. EBrainRuntimeCoordinator doesn't
   automatically use the chapter 二百四十八 SQLite stores; L11
   calibrate-risk doesn't automatically consult the chapter
   二百六十四 calibration gate.
2. **Stub-vs-real ratio** — chapter 二百六十八 ML-backed
   evaluator + chapter 二百七十 meridian heads use rules-based
   classifiers, not real ML. Honest scaffolding, but the
   "ML-backed" label is ambiguous.
3. **Doc-only chapters** — chapters 二百五十六 / 二百五十八 /
   二百七十一 are documents, not code. The "all stages closed"
   framing obscured this.
4. **Integration test depth** — most tests are unit tests of
   primitives in isolation; closed-loop end-to-end tests were
   thin.

Chapters 二百七十二 and 二百七十三 closed gaps #1 (Stage 4 wire
proof) and #4 (Stage 1 BASHostRuntime integration). This
chapter (二百七十四) is the honesty record explicitly naming
where each chapter sits on the "shipped → production-wired"
spectrum.

## Production-wire status table

Status code legend:
- **PROD** — production-wired. Default substrate path uses it.
- **OPT-IN** — typed primitive shipped + tested; default path
  unchanged. Hosts adopt by calling explicit constructor /
  factory / replace API.
- **DOC** — documentation chapter; no code shipped.
- **STUB** — code shipped but uses placeholder logic (rules-
  based classifier where real ML is target).

| Chapter | M | Stage | Title | Status | Notes |
|---|---|---|---|---|---|
| 二百四十八 | M735 | 0 | `BASSQLiteMemoryAtomStore` | OPT-IN | Hosts pass `databaseURL:` to opt in. `BASInMemoryMemoryAtomStore` remains default. |
| 二百四十九 | M736 | 0 | `BASHostConstitutionSQLiteStorage` | OPT-IN | Hosts construct + pass to vault wrapper. |
| 二百五十 | M737 | 0 | `BASUpdateTicketLifecycleCoordinator.sqliteBacked` factory | OPT-IN | Hosts call factory; legacy nil-storage init still works. |
| 二百五十一 | M738 | 1 | `BASMemoryUsageTracker` | OPT-IN | Hosts construct standalone or via applier. |
| 二百五十二 | M739 | 1 | `BASMemoryImportanceScorer` | OPT-IN | Pure value type; consumed by applier. |
| 二百五十三 | M740 | 1 | `BASMemoryClosedLoopApplier` | OPT-IN | Hosts construct with store+tracker+scorer. Chapter 二百七十三 demonstrates `BASHostRuntime` integration. |
| 二百五十四 | M741 | 2 | Counter-Host gate resolver auto-flow | **PROD** | When hosts use `approveForDistillationResolvingCounterHost(...)`, the gate is the default flow. Replaces a pattern that previously bypassed the gate. |
| 二百五十五 | M742 | 2 | Counter-Host sovereign-override audit emission | **PROD** | Audit codes auto-emitted when override branch fires; existing `approveForDistillation` callers unaffected. |
| 二百五十六 | M751 | 3 | Stage 3 user-action procedure guide | DOC | Procedure record. No code. |
| 二百五十七 | M743 | 3 | `pull_iphone_bench_and_retrain.py` | OPT-IN | Mac-side script; user invokes manually. |
| 二百五十八 | M753 | 3 | Stage 3 train pipeline composition guide | DOC | Procedure + canary checklist. No code. |
| 二百五十九 | M752 | 3 | `author_risk_calibration_bundle.py` | OPT-IN | Mac-side CLI; operator invokes. |
| 二百六十 | M754 | 3 | `BASShadowEvaluatorPipeline` | OPT-IN | Composition primitive; hosts construct + pass to evaluator slot. |
| 二百六十一 | M744 | 4 | ADR-012 doctrine document | DOC | Doctrine record. No code. |
| 二百六十二 | M745 | 4 | `aggregate_risk_stratum.py` | OPT-IN | Mac-side aggregator; operator invokes. |
| 二百六十三 | M746 | 4 | `BASRiskCalibrationBundle` typed value | OPT-IN | Hosts author bundles via Swift constructor or via chapter 二百五十九 CLI. |
| 二百六十四 | M747 | 4 | `BASRiskCalibrationGate` | OPT-IN | Hosts construct gate + call `replace(_:)`. L11 calibrate-risk path NOT auto-rewired. |
| 二百六十五 | M755 | 4 | `BASRiskCalibrationStratumSubModelRef` + registry | OPT-IN | Typed registry; no L2 plane consumer. |
| 二百六十六 | M748 | 5 | `BASShadowEvaluating` protocol + no-op | OPT-IN | Hosts construct evaluators; no auto-default in substrate runtime. |
| 二百六十七 | M749 | 5 | `BASSubstrateReauditShadowEvaluator` | OPT-IN | Hosts construct + invoke. |
| 二百六十八 | M756 | 5 | `BASMLBackedShadowEvaluator` + body-feature classifier protocol | OPT-IN + STUB | Protocol is real; default conformer is `BASRulesBasedBodyFeatureClassifier` (rules-based, not ML). Hosts replace classifier with CoreML conformer once `.mlpackage` exists. |
| 二百六十九 | M750 | 5 | SampleHost bench loop adopts `BASShadowEvaluating` via DI | **PROD** (in SampleHost) | New `observePostLLMViaEvaluator(_:...)` path is host-side adoption; legacy `observePostLLM(...)` byte-equal preserved. SampleHost bench loop default still uses legacy. |
| 二百七十 | M757 | 5 | `BASShadowEvaluatorMeridian` + 2 stub heads | OPT-IN + STUB | Quality + hallucination heads use rules-based logic. Real ML heads deferred. |
| 二百七十一 | M758 | 6 | LoRA per-user adapter doctrine | DOC | Doctrine record. No code; implementation deferred multi-month. |
| 二百七十二 | M759 | 4 | `BASRiskCalibrationStratumKeyBuilder` + L11 integration test | **PROD-WIRE PROOF** | Closes self-assessment gap #1. Test #9/#10 demonstrate full chain wires (bundle deploy → key build → effective threshold change). |
| 二百七十三 | M760 | 1 | Closed-loop integration test using `BASHostRuntime` | **PROD-WIRE PROOF** | Closes self-assessment gap #4. Test 2 demonstrates SQLite-backed cross-runtime persistence end-to-end. |

## Status summary

Out of 26 chapter ship records this session:

| Status | Count | % |
|---|---|---|
| **PROD** (default substrate path uses it) | 4 | 15% |
| **PROD-WIRE PROOF** (integration test demonstrates chain wires) | 2 | 8% |
| **OPT-IN** (host-controlled adoption; substrate default unchanged) | 14 | 54% |
| **OPT-IN + STUB** (typed primitive real; logic rules-based stub) | 2 | 8% |
| **DOC** (documentation chapters; no code) | 4 | 15% |

The honest picture:
- **6 chapters are production-wired** (4 PROD + 2 PROD-WIRE PROOF integration tests demonstrating the chain). These are the chapters that change substrate behaviour.
- **14 chapters are typed primitives ready for opt-in adoption**. They don't change substrate default behaviour. Hosts adopt by explicit code change in their host runtime.
- **2 chapters carry rules-based stubs in place of real ML**. Real ML conformers replace the stubs once `.mlpackage` exists.
- **4 chapters are documentation**. Procedure records + doctrine documents.

## What this means for the operator

If you were reading the changelog and saw "Stage 5 fully closed",
the honest expansion is:

> Stage 5 fully closed means: the typed protocol contract +
> 4 conformers (no-op / substrate-driven / ML-backed scaffolding /
> 2 stub heads) + 1 multi-evaluator pipeline + 1 multi-head
> meridian + 1 SampleHost bench loop adoption seam are all
> shipped, tested, and ready for hosts to opt into. The
> substrate's default code path does NOT yet auto-construct or
> auto-invoke a `BASShadowEvaluating` evaluator. SampleHost's
> bench loop continues to use its hardcoded substrate-reaudit
> path; the new protocol-driven path is a host-side opt-in
> introduced in chapter 二百六十九.

Same applies to Stages 0/1/3/4 — the typed primitives are
ready; the default substrate path is unchanged unless a host
explicitly opts in.

## What I'd do differently

If I were running this session over:

1. **Stop labeling stub chapters as "shipped"** without the
   STUB tag in commit message. Chapter 二百六十八 / 二百七十
   commits should have said "rules-based stub conformer" in
   the title, not "ML-backed evaluator + 2 stub heads"
   (which I did say in the commit body but the title was
   ambiguous).

2. **Distinguish "PROD" from "OPT-IN" in changelog entries**.
   The changelog text said things like "Counter-Host gate now
   load-bearing" (true — chapter 二百五十四 IS PROD when hosts
   use the new auto-flow method) but also said "BASRisk
   CalibrationGate ready" (which is OPT-IN, not PROD).

3. **Skip doc-only chapters in the velocity narrative**.
   Chapters 二百五十六 / 二百五十八 / 二百七十一 are
   documentation. They're useful but they're not work in the
   same sense as Swift code chapters. Listing them as part of
   "Stage X closed (5/5 chapters)" inflates the closure
   number.

4. **Ship integration tests inline with primitives**, not as
   a separate later chapter. Chapter 二百七十二 / 二百七十三
   integration tests should have been part of chapter 二百六十四
   / 二百五十三 originally. Splitting them across chapters
   created the false impression that the original chapters
   were already proven.

5. **Self-assess earlier**. The "honest 75%" assessment came
   in chapter 二百七十一 — after the entire shipping spree.
   If I'd self-assessed at chapter 二百六十 it would have
   pulled the framing back to honest before the second batch.

## What this corrigendum doesn't fix

- The substrate's L11 calibrate-risk path still doesn't
  auto-consult `BASRiskCalibrationGate`. Hosts wire it.
  Closing this gap means modifying every existing risk
  threshold consumer to thread the gate through — invasive
  cross-module work that's a future chapter, not this session.
- The substrate's `BASHostRuntime` doesn't auto-construct
  `BASMemoryAtomStore` consumers. Hosts wire the closed loop.
- Real ML in chapter 二百六十八 / 二百七十 stub heads. Real
  ML conformers ship when `.mlpackage` files exist (Stage 3
  user-action) — that's not a corrigendum target, that's a
  Stage 3 unblock target.

## Doctrine pins held

This document is a corrigendum, not a new doctrine. It records
honest status without changing any contract. Doctrine pins
from 24 prior chapters are unchanged.

The honesty board pattern (chapters 56 / 67 / 91.5 / 174) is
the cultural norm this corrigendum follows: walk back framing
that turned out to be more confident than the work earned.

---

**Test impact of this chapter**: 0 BAS source changes, 0 BAS
test changes. BAS XCTest 3194 / SampleHost iOS 136 unchanged.
This is a documentation-only chapter that records honest status.
