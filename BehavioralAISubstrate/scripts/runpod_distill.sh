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
export TEACHER="${TEACHER:-ibm-granite/granite-4.1-3b-base}"
: "${HF_TOKEN:?set HF_TOKEN (the Granite teacher may be gated; download fails AFTER the cache phase otherwise)}"
mkdir -p "$CKPT_DIR" "$HF_HOME"

echo ">> Mamba-3 distill | arch=$ARCH L=$LAYERS | teacher=$TEACHER | ckpt=$CKPT_DIR | STEPS=$STEPS | resume=on"
for attempt in $(seq 1 100); do
  python -u Tools/mamba3_cloud_distill.py 2>&1 | tee -a "$CKPT_DIR/train.log" && { echo ">> DONE"; break; }
  echo ">> crash/preemption (attempt $attempt) — auto-resuming from $CKPT_DIR in 10s…"; sleep 10
done
