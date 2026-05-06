# 附录 V Stage 6 — LoRA Per-User Adapter Doctrine

**chapter 二百七十一 / M758** — doctrine document for Stage 6
LoRA per-user adapter pipeline.

This document is the doctrine record for附录 V Stage 6. Code-
side Stage 6 is **multi-month + system-level ML infrastructure**
(LoRA training pipeline + on-device hot-swap + Counter-Host gate
enforcement on LoRA promotion). Chapter 二百七十一 ships the
**doctrine** so future Stage 6 chapters have a clear reference;
the implementation chapters are deferred.

This is **not** a new code chapter. The LoRA infrastructure does
not exist in this branch. This document records the doctrine
boundaries that future Stage 6 chapters must respect.

---

## What the doctrine says LoRA can do

Stage 6 envisions per-user **LoRA adapters** (low-rank
adaptation matrices, ~1-100MB each) that personalize the base
model without modifying base weights. Each user gets their own
adapter, trained from a curated subset of their interaction
history (filtered through the Counter-Host gate, chapter 一百三十
/ M514 + chapter 二百五十四 / M741).

The doctrine permits this **specifically because** LoRA is an
adapter, not a weight modification:

- **Base weights stay frozen**. The base model the substrate
  ships with is the same across all users.
- **LoRA matrices are additive deltas** applied at inference
  time. They can be loaded, swapped, or removed without
  retraining the base.
- **Per-user adapters are isolated**. User A's adapter never
  influences user B's inference. Cross-user leakage is forbidden
  by doctrine.

This is why Stage 6 doesn't violate 不变量 #3 ("私有经验不进权
重") — LoRA adapters are typed-distinct from base weights. The
substrate's L2 cognitive plane treats them as adapter inputs,
not as weight modifications.

## What the doctrine says LoRA cannot do

The same doctrine that permits LoRA also constrains it. A
Stage 6 chapter that proposes any of the following violates
doctrine and must be rejected:

### Forbidden #1: LoRA promoted without Counter-Host gate

Chapter 二百五十四 / M741 wired the Counter-Host gate to all
ticket promotions. LoRA training data is "host-derived
candidates" by definition. Every LoRA training input MUST pass
the Counter-Host gate (`approveForDistillationResolvingCounterHost
(...)`). Adapters trained from system-induced-drift candidates
violate 不变量 #3 in spirit even if not in letter.

### Forbidden #2: Cross-user adapter sharing

User A's LoRA adapter never influences user B's inference.
Adapters are keyed by `hostID`; the substrate's L2 plane MUST
load only the active host's adapter at inference time. A
"shared adapter pool" is forbidden — that's effectively
modifying base weights for all users.

### Forbidden #3: Auto-promote without operator review

LoRA training pipelines run offline (Mac-side or cloud-side).
The trained adapter is a **candidate**. Operator review +
explicit on-device deploy is required, parallel to chapter
二百五十九 / M752 calibration bundle workflow:
1. Operator reviews holdout validation (chapter 一百八十四
   calibration regression doctrine).
2. Operator obtains L14 sovereign warrant.
3. Adapter ships to device via the same operator-controlled
   path that ships base model updates.

### Forbidden #4: Live adapter swap mid-turn

Adapters are loaded at session start (chapter 二百四十八+ Stage
0 host vault load path) or at explicit between-turn checkpoints.
Swapping mid-turn would break determinism guarantees the
substrate makes about per-turn permit decisions (ADR-006).

### Forbidden #5: Adapter persists across forget cascade

Chapter 一百零二 五级删除 doctrine: when a user invokes a forget
cascade, their LoRA adapter MUST be revoked. The adapter is
host-derived data; it inherits the same lifecycle as L8 atoms +
L5 host vault entries.

## Pipeline shape (deferred to Stage 6 implementation chapters)

```
┌──────────────────────────────────────────────────────────┐
│ Phase A — Per-user candidate pool                        │
│ L13 lifecycle holds .distilled tickets per user (chapter │
│ 二百五十 / M737 SQLite-backed). All candidates passed     │
│ Counter-Host gate (chapter 二百五十四 / M741).             │
└────────────────┬─────────────────────────────────────────┘
                 │
                 ▼
┌──────────────────────────────────────────────────────────┐
│ Phase B — Mac-side LoRA training (multi-month)           │
│ Pull per-user .distilled candidate set; train LoRA       │
│ matrices (PEFT-style) targeting the chapter 一百七十七    │
│ ChengluPreflight base. Hold out 10% for validation.       │
└────────────────┬─────────────────────────────────────────┘
                 │
                 ▼
┌──────────────────────────────────────────────────────────┐
│ Phase C — Operator canary (chapter 二百五十八 doctrine)   │
│ Holdout accuracy ≥ baseline; calibration drift ≤ 5%;     │
│ per-stratum stability; L14 sovereign warrant signed.     │
└────────────────┬─────────────────────────────────────────┘
                 │
                 ▼
┌──────────────────────────────────────────────────────────┐
│ Phase D — On-device adapter ship                         │
│ Adapter file (~1-100MB) ships via App Store update or    │
│ a host-controlled per-user OTA path. Substrate L2 plane   │
│ loads adapter at session start; revokes on forget cascade.│
└──────────────────────────────────────────────────────────┘
```

## Why Stage 6 is multi-month

Each phase requires substantial out-of-substrate work:

- **Phase A**: chapter 二百五十 storage is shipped, but candidate
  selection logic (which `.distilled` tickets to include in
  training) is Counter-Host-aware operator policy. Default
  policy: all `.distilled` tickets within the user's last 30
  days. Operator can override.
- **Phase B**: LoRA training requires PEFT framework integration,
  GPU compute, hyperparameter tuning. ~2-4 weeks for first
  pipeline.
- **Phase C**: chapter 二百五十八 / M753 doctrine applies; same
  canary checklist + warrant signing.
- **Phase D**: on-device adapter loading is L2 cognitive plane
  work — chapter 一百七十七 / Core ML mlpackage runtime + LoRA
  matrix application. Requires Core ML LoRA ops (or MLX-backed
  inference). ~2-4 weeks.

Total estimated: **8-12 weeks of focused engineering**. Stage 6
is genuinely multi-month; this is honest.

## What ships in this chapter (二百七十一)

This document. **No code**. Future Stage 6 implementation
chapters (二百七十二+) reference this for doctrine boundaries.

## What's in scope for future Stage 6 chapters (二百七十二+)

| Chapter (proposed) | Scope |
|---|---|
| 二百七十二 | LoRA candidate selector — pulls `.distilled` tickets per Counter-Host policy |
| 二百七十三 | LoRA training pipeline (Mac-side, PEFT) |
| 二百七十四 | LoRA holdout validation + calibration regression |
| 二百七十五 | On-device adapter loading runtime hook (L2) |
| 二百七十六 | Adapter swap-on-forget-cascade hook (chapter 一百零二) |
| 二百七十七 | Adapter shipping path (App Store or host-OTA) |

## Authorization required

| Phase | Authorization |
|---|---|
| A | Per-user opt-in to adapter training (chapter 二百四十九 host vault consent flag) |
| B | Operator-launched training run (Mac-side; user data NOT on Mac without operator-controlled extraction) |
| C | Operator review + L14 sovereign warrant signing |
| D | User-controlled adapter installation (or App Store gate) |

## Doctrine pins for Stage 6 implementation

- **不变量 #1 / #2 / #3**: LoRA is adapter, not weight. Base
  weights stay frozen across all users. Adapter is host-keyed.
- **chapter 一百三十 Counter-Host doctrine**: every training
  candidate passed the gate.
- **chapter 二百四十九 host vault**: adapter eligibility flag is
  a vault field; revocation cascades.
- **chapter 一百零二 五级删除**: forget cascade revokes adapter.
- **ADR-006 strict**: per-turn observability data never feeds
  live adapter mutation. Adapter changes are between-deploy.
- **ADR-012**: adapter as a calibration artifact follows the
  same Hybrid pipeline (offline aggregation → operator review →
  L14 warrant → deploy).

## Out of scope for Stage 6 (forever)

- **Federated learning across users**: explicitly forbidden
  (forbidden #2 above).
- **Continuous online adapter learning**: explicitly forbidden
  (forbidden #4).
- **Auto-promote LoRA based on per-turn signal**: explicitly
  forbidden (forbidden #3).

These remain external research projects, not Stage 6 chapters.
