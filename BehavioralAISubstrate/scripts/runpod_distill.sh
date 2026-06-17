#!/usr/bin/env bash
# Launch the 8-layer Mamba-3 cloud distill on RunPod. Auto-RESUMES from $CKPT_DIR (survives spot preemption /
# pod restart): the harness checkpoints atomically and reloads model+optimizer+step on start. The while-loop
# relaunches on a transient crash/preemption so a spot pod self-heals.
set -uo pipefail
cd "$(dirname "$0")/.."                                   # repo root (BehavioralAISubstrate)

export CKPT_DIR="${CKPT_DIR:-/workspace/ckpt}"           # PERSISTENT volume — checkpoints live here
export HF_HOME="${HF_HOME:-/workspace/hf}"               # cache the 3B teacher + HotpotQA on the volume
# RAFT data knobs (read by mamba3_raft):
export RAFT_P="${RAFT_P:-0.8}" RAFT_K="${RAFT_K:-4}" RAFT_T="${RAFT_T:-1024}" RAFT_COT="${RAFT_COT:-0}"
# distill knobs:
export ARCH="${ARCH:-hybrid}"                            # hybrid = 20 Mamba-3 + 4 MLA DUET reader (the goal); "mamba" = pure
export LAYERS="${LAYERS:-24}" STEPS="${STEPS:-20000}" LR="${LR:-3e-4}" ACCUM="${ACCUM:-8}"
export KD_W="${KD_W:-1.0}" CE_W="${CE_W:-0.5}" N_ROWS="${N_ROWS:-20000}"
# optimization recipe (Track-G add.45, adversarially-verified):
export CKPT_EVERY="${CKPT_EVERY:-250}" EVAL_EVERY="${EVAL_EVERY:-1000}"   # NS-5: ≤250 steps lost on a spot preempt (was 500)
export DECAY="${DECAY:-cosine}" LR_MIN_FRAC="${LR_MIN_FRAC:-0.07}"        # LR-1: warmup → cosine decay to 7% of peak
export FP32_MASTER="${FP32_MASTER:-1}" CTX_W="${CTX_W:-0.5}"             # TBC-6 fp32-master+autocast | BCS-1 context-use ckpt selection
export KD_ANSWER_W="${KD_ANSWER_W:-1.0}"                                  # KD-1: 1.0=uniform; set >1 (e.g. 2.0) to up-weight answer-span KD
export TEACHER="${TEACHER:-ibm-granite/granite-4.1-3b-base}"
: "${HF_TOKEN:?set HF_TOKEN (the Granite teacher may be gated; download fails AFTER the cache phase otherwise)}"
mkdir -p "$CKPT_DIR" "$HF_HOME"

echo ">> Mamba-3 distill | arch=$ARCH L=$LAYERS | teacher=$TEACHER | ckpt=$CKPT_DIR | STEPS=$STEPS | resume=on"
for attempt in $(seq 1 100); do
  # Once the teacher + dataset are cached (first successful cache phase), PIN them OFFLINE so the dataset/teacher can't
  # drift across the self-healing relaunch loop (reproducibility + supply-chain). Attempt 1 stays online to download.
  if [ -f "$CKPT_DIR/cache/fingerprint.txt" ]; then
    export HF_HUB_OFFLINE=1 HF_DATASETS_OFFLINE=1
    echo ">> cache present — pinning HF OFFLINE (immutable dataset + teacher for the rest of the loop)"
  fi
  python -u Tools/mamba3_cloud_distill.py 2>&1 | tee -a "$CKPT_DIR/train.log" && { echo ">> DONE"; break; }
  echo ">> crash/preemption (attempt $attempt) — auto-resuming from $CKPT_DIR in 10s…"; sleep 10
done
