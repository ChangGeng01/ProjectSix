# RunPod runbook — 24-layer Mamba-3 narrow-RAG-reader scale distill

The cloud scale run that answers the open question after the A19 device work:
**is a 24-layer (~600M) Mamba-3 deep enough, given enough tokens, for the narrow-RAG-reader quality bar?**

DEPTH CHOICE (Track G addenda 10-15, all on-device): the on-device decode speed/depth/engine tradeoff is:
- **≤8 layers** → the *only* depth with no fresh ANE-segment compile failures ("100%-ANE", ~112 tok/s) — but ANE
  participation is INFERRED (no positive placement measurement), and quality is capped low.
- **>8 layers** → a **CoreAI GPU-backed reader** (the ANE rejects most segments at depth — 24L threw 242 ANE-segment
  failures, so it runs on the GPU). Re-verified speed: **24L ≈ 70 tok/s GPU** (3 reps 73.3/68.4/69.4), ~600M params,
  ~80-120 MB resident (weights ~600 MB mmap'd). 32L ≈ 57 tok/s (~0.8B).
We anchor at **24 layers** for quality (you went cloud for quality; memory is a non-issue). This is a **GPU-backed**
reader, NOT pure-ANE — set `LAYERS=8` if literal pure-ANE/low-power is a hard requirement. (Quality-vs-depth is what
THIS run establishes — every on-device number above is random-weight op-graph speed, not quality.)

## Pod

- **GPU**: 1× **A100 80GB** (cheapest sufficient) or **H100 80GB** (faster). Single GPU — the ~600M student + frozen
  3B teacher fit one card with room. No multi-GPU.
- **Image**: a RunPod **PyTorch 2.x + CUDA 12.x** template.
- **Volume**: a **persistent volume mounted at `/workspace`** (≥100 GB) — holds the HF model/data cache (`$HF_HOME`)
  and checkpoints (`$CKPT_DIR`), so a spot-preempted / restarted pod resumes instead of restarting.

## Run

```bash
# 1. get the repo onto the volume
cd /workspace && git clone <this-repo> Project06 && cd Project06/BehavioralAISubstrate
git checkout vendor-latest-refresh

# 2. one-time deps (torch is preinstalled in the image; this adds transformers/datasets[/flash-attn])
bash scripts/runpod_setup.sh

# 3. launch (auto-resumes from /workspace/ckpt; self-heals on spot preemption)
bash scripts/runpod_distill.sh
```

## Recipe (what it does)

Stage-3 logit-KD (the proven workhorse — white-box staging was null locally, Track G addendum 9) on RAFT-formatted
HotpotQA-distractor data (the audit-fixed builder, `mamba3_raft.py`): `loss = KD_W·KL(teacher‖student) + CE_W·CE(answer)`.
The teacher transfers its reading distribution; the gold answers add the RAFT distractor-robust supervised signal.
bf16 on CUDA, grad-accum, warmup, grad-clip, atomic checkpoint/resume.

## Knobs (env; defaults in `runpod_distill.sh`)

| env | default | meaning |
|---|---|---|
| `STEPS` | 20000 | training steps (× `RAFT_T` tokens/step ≈ token budget) |
| `ACCUM` | 8 | grad-accum → effective batch |
| `LR` / `WARMUP` | 3e-4 / 800 | AdamW lr + linear warmup |
| `KD_W` / `CE_W` | 1.0 / 0.5 | KD vs answer-CE weights |
| `RAFT_P` / `RAFT_K` | 0.8 / 4 | RAFT: P(keep gold) / #distractors |
| `RAFT_T` | 1024 | prompt+answer token budget |
| `N_ROWS` | 20000 | HotpotQA rows drawn |
| `TEACHER` | granite-4.1-3b-base | swap to `granite-4.1-8b-base` for the stronger teacher |
| `LAYERS` | **24** | ~600M, ~70 tok/s GPU-backed. =8 → pure-ANE/112 tok/s (low quality); =32 → ~0.8B/~57 tok/s |

## What to watch

`EVAL` lines every 1000 steps print held-out NLL/acc on three retrieval conditions:
- **E1** gold-only, **E2** gold buried in distractors, **E3** distractors only (no gold).
- The headline RAFT signal is the **degradation slope Δ(E2−E1)** — a robust reader keeps it small.
- Falling E1/E2 NLL = the reader is learning; a flat/large Δ that shrinks over training = distractor robustness emerging.

## Deploy back to the A19 (the loop closes)

```bash
# copy /workspace/ckpt/ckpt_latest.pt → /tmp/draft_coreai/mamba3_poc_student.pt (24-layer)
uv run --with coreai-torch python Tools/mamba3_deploy.py 24 8   # int8, 24 layers → .aimodel
# then run on the A19 (CoreAI GPU backend) ≈ 70 tok/s, ~80-120 MB resident. NOT pure-ANE at 24L (addendum 15).
# (For the 8-layer pure-ANE variant: mamba3_deploy.py 8 8 — 0 fresh compile errors, ~112 tok/s.)
```

## Cost (honest)

- Narrow-reader PoC (~0.5–2 B tokens ≈ STEPS 5k–20k @ T=1024): **~$50–200** on A100 spot.
- Stronger/broader (8B-teacher, more tokens): **~$150–600**.
- The dominant cost is the frozen 3B teacher forward each step — a top-K teacher-cache (run teacher once, reuse across
  epochs) is the next optimization if you do many epochs over a fixed set (not yet wired; on-the-fly KD is the default).

## 云前 pre-launch runbook (P0-first discipline — addendum 41)

**Before any spend (GATE 0):** the cache-pollution guard must be committed (it is) — `build_cache` fingerprints
{teacher,P,K,T,N_ROWS,KD_K,n_train} and `raise SystemExit` on drift, so a reused stale-config cache can't silently pollute.

**P0 (small, cheap, fast — prove the pipeline + a learning signal BEFORE scaling):**
```
export HF_TOKEN=...                       # Granite teacher is gated; runpod_distill.sh fails fast if unset
rm -rf /workspace/ckpt-p0                 # FRESH dir (the fingerprint guard catches drift, but start clean)
ARCH=hybrid LAYERS=24 STEPS=2000 N_ROWS=3000 EVAL_EVERY=250 CKPT_EVERY=250 \
  CKPT_DIR=/workspace/ckpt-p0 USE_SCHEDULER=1 bash scripts/runpod_distill.sh
```
(N_ROWS=3000 < the ~7405 HotpotQA-val cap, so no silent truncation. ~30 min / ~$1-2 spot on an A100.)

**Watch 3 signals in the EVAL lines (every 250 steps):** (a) `KD=` falling toward <1; (b) `E1:/E2: nll=` both
falling = the reader is learning; (c) `slope Δ(E2-E1)=` trending toward <0.05 = distractor-robustness emerging.
Loss stays finite (the run asserts on NaN). **GO** to STEPS=20000 N_ROWS=7405 only if all three move the right way + `↑best`
fires; **NO-GO** (don't burn scale money) if KD is flat / nll stuck / slope widens — fix the recipe (LR/warmup/data) first.

## The 成了 gate-chain (only ALL-green is honest)
- GATE 1 — trained ckpt exists: `ckpt_best.pt` (metric-gated best-selection), born with `eval_card.json`.
- GATE 2 — `eval_card` PASS: the 7-gate `claim_card` reads `成了 ✓` (task-fit, RAFT E2-robust, E3-graceful, fidelity-argmax,
  generation EM/F1, stability, no-contamination — the last is now REAL, verifying the disjoint split).
- GATE 3 — ckpt → device WITH `CKPT` set: the converters now **fail-closed** on a missing CKPT (no silent random-weight asset;
  `FORCE_RANDOM=1` only for op-graph probes). `resolve_ckpt` is authoritative on vocab.
- GATE 4 — device argmax-consistency: the A19 `BAS_COREAI_STATELAKE_PROBE` reproduces `HOSTREF_STATELAKE_ARGMAX` (cross-launch int8).
- GATE 5 — quant-fidelity filled (replace the eval stub with measured int8-vs-fp32 argmax on the trained ckpt; device-phase).
- GATE 6 — scope honesty: a NARROW HotpotQA-distractor RAG/memory reader; the recipe is **difficulty-curriculum + static
  RAFT(P=0.8,K=4)**, NOT multi-stage RAFT-curriculum (raft_params staging is intentionally unwired — cache cost).
