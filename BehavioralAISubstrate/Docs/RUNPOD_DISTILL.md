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

- **GPU**: 1× **RTX PRO 6000 (Blackwell Workstation, 96 GB GDDR7)** — RunPod 'RTX PRO 6000 WK'. Single GPU; 96 GB > A100/H100 80 GB = more headroom. The ~600M student + frozen
  3B teacher fit one card with room. No multi-GPU.
- **Image**: a RunPod **PyTorch 2.x + CUDA 12.x** template.
- **Volume**: a **persistent volume mounted at `/workspace`** (≥100 GB) — holds the HF model/data cache (`$HF_HOME`)
  and checkpoints (`$CKPT_DIR`), so a spot-preempted / restarted pod resumes instead of restarting.

## Run

```bash
# 1. get the repo onto the volume
cd /workspace && git clone <this-repo> Project06 && cd Project06/BehavioralAISubstrate
git checkout ssd-track-g-distill-optimized            # the branch carrying the audited+optimized distill recipe

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

- Narrow-reader PoC (STEPS 5k–20k @ T=1024 ≈ **~5–20 M token-forwards** at BATCH_SIZE=1; ×BATCH_SIZE×ACCUM for the
  effective batch): order **~$50–250** on an RTX PRO 6000 — **VERIFY the live RunPod $/hr for "RTX PRO 6000 WK" before launch**
  (it has ranged ~$0.8–1.7/hr; use `MAX_SEC` as a hard budget). NOT "B"-scale — 20k × 1024 ≈ 20 M token-forwards.
- Stronger/broader (8B-teacher, more steps/rows): **~$150–600**.
- The frozen-teacher forward is the dominant cost, and it is AMORTIZED by the top-K teacher CACHE (CACHE=1, the default):
  the teacher runs ONCE in build_cache, then training does KD from the cached top-K with NO teacher forward in the loop.

## 云前 pre-launch runbook (P0-first discipline — addendum 41)

**Before any spend (GATE 0):** the cache-pollution guard must be committed (it is) — `build_cache` fingerprints
{teacher,P,K,T,N_ROWS,KD_K,n_train} and `raise SystemExit` on drift, so a reused stale-config cache can't silently pollute.

**P0 (small, cheap, fast — prove the pipeline + a learning signal BEFORE scaling):**
```
export HF_TOKEN=...                       # Granite teacher is gated; runpod_distill.sh fails fast if unset
rm -rf /workspace/ckpt-p0                 # FRESH dir (the fingerprint guard catches drift, but start clean)
ARCH=hybrid LAYERS=24 STEPS=2000 WARMUP=200 N_ROWS=3000 EVAL_EVERY=250 CKPT_EVERY=250 \
  CKPT_DIR=/workspace/ckpt-p0 USE_SCHEDULER=1 COUNTERFACTUAL=1 MAX_SEC=5400 bash scripts/runpod_distill.sh
```
- `WARMUP=200` (not the 800 default) so a 2000-step run isn't 40% in warmup. `COUNTERFACTUAL=1` adds the **E4 reads-vs-memorizes**
  diagnostic to the card. `MAX_SEC=5400` is a 1.5 h hard budget (不要亏). First run also pays a one-time HotpotQA-train + Granite-3B
  (~6 GB) download into `$HF_HOME` (not in the ~30 min estimate). N_ROWS draws from the **train split** (~90k unique) — no cap.

**The GO/NO-GO is PROGRAMMATIC now** — at the end the run prints `>> P0 VERDICT: GO ✓ / NO-GO ✗` and writes `verdict.json` from the
E1-nll trend. **`EVAL CARD → 亏的 ✗ FAIL` at 2000 steps is EXPECTED** (the 8 gates are calibrated for the full 20k run) — do NOT
read it as "broken." Also watch the EVAL lines (every 250): `KD=` falling, `E1:/E2: nll=` falling = learning, `Δ(E2-E1)` shrinking
= distractor-robust, `Δ(E3-E1)` *growing* = using the gold doc. GO → scale; NO-GO (KD flat / nll stuck) → fix the recipe first.

**Scale run (only after a GO) — its OWN fresh dir (the P0 cache is config-locked and cannot be reused at scale):**
```
rm -rf /workspace/ckpt-scale
ARCH=hybrid LAYERS=24 STEPS=20000 N_ROWS=20000 EVAL_EVERY=1000 CKPT_EVERY=250 \
  CKPT_DIR=/workspace/ckpt-scale USE_SCHEDULER=1 COUNTERFACTUAL=1 PACE_T_FRAC=0.5 bash scripts/runpod_distill.sh
```

## The 成了 gate-chain (only ALL-green is honest)
- GATE 1 — trained ckpt exists: `ckpt_best.pt` (metric-gated best-selection), born with `eval_card.json`.
- GATE 2 — `eval_card` PASS: the **8-gate** `claim_card` reads `成了 ✓` — task_fit (within TEACHER_GAP of the **MEASURED** teacher,
  not a hardcoded guess), raft_e2_robust, **context_use** (anti-parrot: removing the gold doc must MEASURABLY hurt — replaced the
  backwards E3-graceful), fidelity_argmax (answer-span), generation EM/F1, stability (incl. id-aligned subset), **fp16_seq_parity**
  (HOST run_twin≡run_ref in fp16 — NOT on-device parity), no_contamination (REAL disjoint split). Plus the opt-in **E4 counterfactual**
  reads-vs-memorizes diagnostic (`COUNTERFACTUAL=1`). Offline re-eval entry: `EVAL_CKPT=/path/ckpt.pt python Tools/mamba3_eval.py`.
- GATE 3 — ckpt → device WITH `CKPT` set: the converters now **fail-closed** on a missing CKPT (no silent random-weight asset;
  `FORCE_RANDOM=1` only for op-graph probes) AND on a mismatched arch/layers/vocab/mla_positions/config or an MLA_ROPE ckpt
  (the deploy converter is still NoPE). `resolve_ckpt` is authoritative on vocab.
- GATE 4 — device argmax-consistency: the A19 `BAS_COREAI_STATELAKE_PROBE` reproduces `HOSTREF_STATELAKE_ARGMAX` (cross-launch int8).
- GATE 5 — quant-fidelity (device phase): `quant_fidelity_stub` is HONESTLY a stub and is NOT a gate; `fp16_seq_parity` is a HOST
  PyTorch-fp16 check, not real int8/CoreAI. Real int8-vs-fp32 + A19 argmax parity is measured at the device phase.
- GATE 6 — scope honesty: a NARROW HotpotQA-distractor RAG/memory reader; the recipe is **difficulty-curriculum + static
  RAFT(P=0.8,K=4)**, NOT multi-stage RAFT-curriculum (raft_params staging is intentionally unwired — cache cost).
