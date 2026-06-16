# RunPod runbook — 8-layer Mamba-3 narrow-RAG-reader scale distill

The cloud scale run that answers the one open question after the A19 ANE work:
**is an 8-layer Mamba-3 deep enough, given enough tokens, for the narrow-RAG-reader quality bar?**

Why 8 layers is fixed: it is the MEASURED A19 per-asset 100%-ANE ceiling (Track G addendum 10 — a sharp depth cliff at
9, robust to precision int8≡fp16 and to state-write pattern). 8 layers @ the proven per-layer config
(D=1024, H=16, P=64, N=64, R=4) is the deepest single-asset reader that deploys 100%-on-ANE today. Split is dead
(Track E). So we train EXACTLY the artifact that deploys.

## Pod

- **GPU**: 1× **A100 80GB** (cheapest sufficient) or **H100 80GB** (faster). Single GPU — the 8-layer student + frozen
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
| `LAYERS` | **8** | leave at 8 (the ANE ceiling) — a deeper student will NOT deploy 100%-ANE |

## What to watch

`EVAL` lines every 1000 steps print held-out NLL/acc on three retrieval conditions:
- **E1** gold-only, **E2** gold buried in distractors, **E3** distractors only (no gold).
- The headline RAFT signal is the **degradation slope Δ(E2−E1)** — a robust reader keeps it small.
- Falling E1/E2 NLL = the reader is learning; a flat/large Δ that shrinks over training = distractor robustness emerging.

## Deploy back to the A19 (the loop closes)

```bash
# copy /workspace/ckpt/ckpt_latest.pt → /tmp/draft_coreai/mamba3_poc_student.pt (8-layer)
uv run --with coreai-torch python Tools/mamba3_deploy.py 8 8    # int8, 8 layers → .aimodel
# then the A19 100%-ANE path is PROVEN for 8 layers (Track G addendum 10): 0 compile errors, ~112 tok/s.
```

## Cost (honest)

- Narrow-reader PoC (~0.5–2 B tokens ≈ STEPS 5k–20k @ T=1024): **~$50–200** on A100 spot.
- Stronger/broader (8B-teacher, more tokens): **~$150–600**.
- The dominant cost is the frozen 3B teacher forward each step — a top-K teacher-cache (run teacher once, reuse across
  epochs) is the next optimization if you do many epochs over a fixed set (not yet wired; on-the-fly KD is the default).
