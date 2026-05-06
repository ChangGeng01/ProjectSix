# 附录 V Stage 3 — Train Pipeline Composition Guide

**chapter 二百五十八 / M753** — operator-facing procedure document
for training ChengluPreflight v1 from real bench data.

This document explains how the existing pieces compose into a
train pipeline. Chapter 一百九十 / M704 already shipped the core
training script (`scripts/bench_to_train.py`); chapter 二百五十七
shipped the pull/retrain orchestrator (`scripts/pull_iphone_bench
_and_retrain.py`). Chapter 二百五十八's job is to record the
operator workflow + canary criteria + the explicit operator-
decision gates per ADR-012.

This is **not** a new code chapter. The pipeline mechanics exist;
this is the procedure record.

---

## Pipeline composition

```
┌──────────────────────────────────────────────────────────┐
│ Phase 1 — User runs iPhone .rawLLM 8h bench              │
│ (chapter 二百五十六 user-action guide)                     │
│ → Produces ~50K-200K rows of JSONL on the device         │
└────────────────┬─────────────────────────────────────────┘
                 │
                 ▼
┌──────────────────────────────────────────────────────────┐
│ Phase 2 — Pull + retrain orchestration                   │
│ scripts/pull_iphone_bench_and_retrain.py                 │
│ (chapter 二百五十七 / M743)                                 │
│ Internally:                                               │
│   a. devicectl device copy from <iPhone> → /tmp/...     │
│   b. invokes scripts/bench_to_train.py                   │
│      (chapter 一百九十 / M704)                              │
│   c. invokes scripts/compare_mlpackages.py if            │
│      --prior-package supplied                            │
│ → Produces ChengluMultiHead_v0.X.mlpackage candidate     │
└────────────────┬─────────────────────────────────────────┘
                 │
                 ▼
┌──────────────────────────────────────────────────────────┐
│ Phase 3 — Operator canary review (THIS CHAPTER)          │
│ Operator inspects:                                        │
│   - Head-by-head delta vs prior production .mlpackage    │
│   - Calibration regression (chapter 一百八十四 doctrine)   │
│   - Holdout validation results                           │
│   - Per-stratum behavior shifts                          │
│ Operator decides: ship v0.X to production or NOT         │
└────────────────┬─────────────────────────────────────────┘
                 │ (if approved)
                 ▼
┌──────────────────────────────────────────────────────────┐
│ Phase 4 — Bundle ship                                    │
│ Operator copies ChengluMultiHead_v0.X.mlpackage to       │
│ SampleHost/Resources/ ; rebuilds; redeploys.             │
│ Old .mlpackage → archived for rollback.                  │
└──────────────────────────────────────────────────────────┘
```

## Operator canary checklist (Phase 3 detail)

Per chapter 一百八十四 / M676 calibration regression doctrine,
operator MUST verify:

### A. Holdout validation

`scripts/bench_to_train.py` produces a held-out validation
result. Operator checks:

- **Accuracy ≥ prior version**: candidate must match or beat
  prior on holdout. Regression here = REJECT.
- **No calibration drift**: chapter 一百八十四 doctrine —
  predicted-probability buckets should match observed
  frequencies within 5% per bucket. Significant drift = REJECT.
- **No catastrophic per-class failure**: e.g. a head that
  dropped from 88% to 60% on `tone=angry` while staying
  unchanged on other strata. Operator decides whether the
  regression is workload-aligned.

### B. Head-by-head delta inspection

Run `scripts/compare_mlpackages.py` (already invoked by
chapter 二百五十七 orchestrator). Operator reviews:

- **Length head MAE**: candidate's length-prediction error in
  z-space (chapter 二百七 fix Python CRITICAL — z-score not raw
  multiplied). Should be ≤ prior. Regression = REJECT.
- **Latency head MAE**: same in z-space.
- **AFM-success-probability** (chapter 一百七十七 router head):
  ROC-AUC must beat prior or stay within 1% absolute.
- **Block-prediction head**: F1 on holdout should beat prior.
- **Verbosity head**: classification accuracy.

### C. Per-stratum stability

Operator runs `scripts/aggregate_risk_stratum.py` against the
SAME bench JSONL the candidate trained on, then compares per-
stratum statistics to historical aggregates. Significant drift
in a stratum's `permitMode` distribution = potential model
overfitting. Operator decides.

### D. Sovereign warrant gate

Per ADR-012, every production-shipped model is **L14 sovereign
warrant signed**. Operator obtains a warrant ref before
proceeding to Phase 4. Empty warrant ref = mlpackage stays a
candidate, never deploys.

---

## Why chapter 二百五十八 is doc-only

The training script already exists (`scripts/bench_to_train.py`,
chapter 一百九十 / M704). The orchestration already exists
(`scripts/pull_iphone_bench_and_retrain.py`, chapter 二百五十七 /
M743). What's missing per附录 V plan §V.6 is the explicit
**procedure record + canary criteria** — the operator decision
gates that Phase 3 demands.

This document is the canonical reference for that. Future
operators consult this when deciding whether a candidate is
ship-worthy.

## Doctrine pins held throughout

- **不变量 #2 神经不掌权**: every phase except Phase 1 (the
  device-side bench) is operator-driven. The retrain is
  candidate-only; Phase 3 canary is operator decision; Phase 4
  ship requires manual file copy + rebuild.
- **不变量 #3 私有经验不进权重**: the train data is bench JSONL
  (already filtered by chapter 二百八 ADR-006 — bench JSONL is
  observability ONLY at per-turn scope). The train pipeline
  doesn't touch host-specific identity beyond what bench
  observability already records.
- **ADR-006 strict**: bench data is between-deploy training
  signal, never per-turn permit feed. The pipeline produces a
  candidate; the candidate is a data-derived model that will
  influence future turns only after explicit deploy.
- **chapter 一百八十四 / M676 calibration regression**: Phase 3
  Section A enforces this verbatim — predicted/observed
  probability matching is the canary condition.
- **ADR-012**: Phase 4 ship requires L14 sovereign warrant.

## What the user must explicitly authorize

| Phase | Authorization required |
|---|---|
| 1 (bench) | User runs iPhone bench (chapter 二百五十六) |
| 2 (pull + retrain) | User authorizes devicectl pull |
| 3 (canary review) | Operator inspects holdout + calibration + per-stratum + warrant |
| 4 (ship) | Operator copies file + rebuilds + redeploys; archives prior version |
