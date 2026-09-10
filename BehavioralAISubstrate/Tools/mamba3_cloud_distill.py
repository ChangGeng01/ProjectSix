"""Cloud (RunPod) scale distillation: Granite-4.1-3b → an 8-layer Mamba-3 narrow RAG reader.

WHY 8 layers: it is the MEASURED A19 per-asset 100%-ANE ceiling (Track G addendum 10 — robust to precision int8≡fp16
and to state-write pattern; a sharp depth cliff at 9). So 8 layers @ the proven per-layer config (D=1024,H=16,P=64,
N=64,R=4) is the deepest single-asset reader that deploys 100%-on-ANE today. This run answers the one open question:
is an 8-layer Mamba-3 deep enough, given enough tokens, for the narrow-RAG-reader quality bar.

RECIPE: Stage-3 logit-KD (the proven workhorse — white-box staging was null locally, Track G addendum 9) on
RAFT-formatted HotpotQA-distractor data (distractor-robust reader, the audit-fixed builder in mamba3_raft.py). The
teacher transfers its reading distribution (KD); the gold answers add the RAFT supervised signal (masked-CE).

CUDA bf16, device-agnostic (cuda → mps → cpu). Teacher top-K logit CACHE (run the frozen 3B teacher ONCE, reuse across
epochs) = the cost saver — the dominant cost is the teacher forward. Checkpoint/resume on a persistent volume.
NOTE on mamba_ssm: its selective-scan CUDA kernel is for the Mamba-2 SSD, NOT our trapezoid (3-term recurrence +
rotated delay + RoPE + MIMO), so it is NOT a drop-in. The pure-torch chunked scan (mamba3_trainable) runs correctly +
fast on CUDA (optionally torch.compile-fused, COMPILE=1). A custom trapezoid Triton kernel is a future lever.

RunPod: bash scripts/runpod_setup.sh && bash scripts/runpod_distill.sh   (1× RTX PRO 6000 96GB / Blackwell 'WK').
"""
from __future__ import annotations

import contextlib
import hashlib
import json
import math
import os
import random
import sys
import time

import torch
import torch.nn.functional as F

sys.path.insert(0, "/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tools")
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import mamba3_trainable as MT
import mamba3_hybrid as HY
import mamba3_raft as RAFT
import mamba3_eval as EVAL
from mamba3_curriculum_scheduler import CurriculumScheduler, CurriculumConfig
from mamba3_raft import build_example, make_examples, make_eval_condition, masked_ce, eval_nll

TEACHER = os.environ.get("TEACHER", "ibm-granite/granite-4.1-3b-base")   # prod: granite-4.1-8b-base
LAYERS = int(os.environ.get("LAYERS", "24"))                             # cloud target: ~600M, ~70 tok/s GPU-backed on A19
#   (re-verified 3 reps: 73.3/68.4/69.4 tok/s; >8L is a CoreAI GPU-backed reader, NOT pure-ANE — addendum 15.
#    Set LAYERS=8 for the literal pure-ANE/low-power variant ~112 tok/s; LAYERS=32 for ~0.8B/~57 tok/s.)
DEV = "cuda" if torch.cuda.is_available() else ("mps" if torch.backends.mps.is_available() else "cpu")
DT = torch.bfloat16 if DEV == "cuda" else torch.float32
RAFT.DEV = DEV                                                           # the reused RAFT helpers read this
STEPS = int(os.environ.get("STEPS", "20000"))
LR = float(os.environ.get("LR", "3e-4"))
WARMUP = int(os.environ.get("WARMUP", "800"))
ACCUM = int(os.environ.get("ACCUM", "8"))                               # grad-accum → effective batch
GRAD_CLIP = float(os.environ.get("GRAD_CLIP", "1.0"))                   # NS-9 (add.56): grad-norm clip — hoisted from a hardcoded 1.0. The
if GRAD_CLIP <= 0:                                                      # add.57 footgun guard: clip_grad_norm_(., 0) zeroes ALL grads = silent no-train. <=0 ⇒ no clipping (norm still logged).
    GRAD_CLIP = float("inf")
#   parrot's back-half PRE-clip gnorm median was 4.96 (p95 10.7), so clip=1.0 throttled ~100% of back-half steps 3-18× during the phase E1 nll
#   was STILL falling. 1.0 = byte-identical legacy; try GRAD_CLIP=5.0 to free the productive late updates. (Also: a peak-LR bump is a no-op while clip nullifies it.)
TAU = float(os.environ.get("TAU", "1.0"))   # P0-1 (test_p0_1_topk_kd.py): at TAU=2 over 100k vocab the top-K cache misses
#   68% of the tempered mass (grad-cos 0.91, loss-ratio 2.23 vs full KD). TAU=1 → top-64 captures 99%, grad-cos 0.999,
#   loss-ratio 1.04 = matches full-vocab KD. The cache (top-K logits) was fine; the temperature was the bug.
KD_W = float(os.environ.get("KD_W", "1.0"))
CE_W = float(os.environ.get("CE_W", "0.5"))
N_ROWS = int(os.environ.get("N_ROWS", "20000"))                         # HotpotQA rows to draw from
CKPT_DIR = os.environ.get("CKPT_DIR", "/workspace/ckpt")
CKPT_EVERY = int(os.environ.get("CKPT_EVERY", "500"))
EVAL_EVERY = int(os.environ.get("EVAL_EVERY", "1000"))
COMPILE = os.environ.get("COMPILE", "0") == "1"
RESUME = os.environ.get("RESUME", "1") == "1"
CACHE = os.environ.get("CACHE", "1") == "1"                              # precompute teacher top-K ONCE, reuse (cost saver)
KD_K = int(os.environ.get("KD_K", "64"))                                # top-K logits kept per token in the cache
ORDER = os.environ.get("ORDER", "curriculum")                           # curriculum (easy->hard by teacher CE) | random
# --- optimization recipe knobs (Track-G addendum 45; adversarially-verified) ---
DECAY = os.environ.get("DECAY", "cosine")                               # LR-1: cosine | linear | none (legacy flat-after-warmup) | wsd (add.55)
LR_MIN_FRAC = float(os.environ.get("LR_MIN_FRAC", "0.07"))             # LR-1: decay floor as a fraction of LR
WSD_DECAY_FRAC = float(os.environ.get("WSD_DECAY_FRAC", "0.2"))        # add.55: WSD = warmup→STABLE(flat@peak)→cosine DECAY over the last frac of steps
#   (recovers the back-half a long cosine wastes — the 20k run ran ~48% of steps below half-peak LR while E1 nll was still falling).
MAX_SEC = float(os.environ.get("MAX_SEC", "0"))                        # add.55: IN-LOOP wall-clock guard (0 = off). The wrapper MAX_SEC only fires
#   BETWEEN process restarts (post-crash) — a healthy run ignores it; this saves a ckpt + breaks gracefully so a long run honors a hard time wall.
KD_ANSWER_W = float(os.environ.get("KD_ANSWER_W", "1.0"))             # KD-1: >1 up-weights KD on the answer span (1.0 = uniform = legacy)
KD_NOGOLD_W = float(os.environ.get("KD_NOGOLD_W", "1.0"))            # NS-10 (add.56): down-weight KD on NO-GOLD examples. On those (~20% at P=0.8)
#   the frozen teacher emits its MEMORIZED answer with no evidence (teacher_E1_nll≈0.76), so KD-only no-gold steps distill the parrot
#   (counterfactual_lift=-0.007). RAFT_NOGOLD_CE gates the CE only ("KD still applies"); this is the COMPLEMENT — it stacks with CF. 1.0=legacy; try 0.3.
FP32_MASTER = os.environ.get("FP32_MASTER", "1") == "1"               # TBC-6: fp32 master weights + autocast-bf16 forward on cuda
CTX_W = float(os.environ.get("CTX_W", "0.5"))                         # BCS-1: best-ckpt reward for context-use (positive E3-E1 slope = reading)
BATCH_SIZE = int(os.environ.get("BATCH_SIZE", "1"))                  # TBC-1: vmap-batched forward (1 = single-[T], the 349-test path). >1 OOMs at T=1024 even on 96GB (see warning) — keep 1
TRAIN_SPLIT = os.environ.get("TRAIN_SPLIT", "train")                 # CS-6: HotpotQA train (~90k unique); validation[:N] caps at ~7405 (3x repeats over 20k steps)
HELD_SPLIT = os.environ.get("HELD_SPLIT", "validation")             # held from a DIFFERENT split → disjoint by construction
HELD_N = int(os.environ.get("HELD_N", "300"))
RAFT_NOGOLD_CE = os.environ.get("RAFT_NOGOLD_CE", "1") == "1"        # train answer-CE on NO-GOLD examples? RAFT default 1; set 0 = KD-only on
#   no-gold (stops the objective teaching "answer without evidence" — the E3 tension; complements the eval-side context_use gate)
PACE_T_FRAC = float(os.environ.get("PACE_T_FRAC", "1.0"))           # CURR-1: competence reaches the full set at PACE_T_FRAC*STEPS (0.5 = drill the hard tail in the back half)
KD_EXACT_TAIL = os.environ.get("KD_EXACT_TAIL", "0") == "1"         # KD-4: exact top-K + lumped-tail KD (needs cached logZ; TAU=1 only). off = renorm-within-K (legacy)
COUNTERFACTUAL = os.environ.get("COUNTERFACTUAL", "0") == "1"       # E4: counterfactual fact-swap reading DIAGNOSTIC in the eval card (off = not computed)
CF_FRAC = float(os.environ.get("CF_FRAC", "0.0"))                  # KD-C (add.50): the reading-FORCING lever — fraction of steps trained on a
CF_WARM = float(os.environ.get("CF_WARM", "0.15"))                #   counterfactual (gold fact swapped to a RANDOM surrogate, CE-only, NO KD),
CF_CE_W = float(os.environ.get("CF_CE_W", "0.5"))                 #   ramped 0→CF_FRAC after CF_WARM*STEPS so KD bootstraps fluency first. The
#   parametric/teacher answer is WRONG on a CF step → the loss is satisfiable ONLY by reading the swapped span (kills the question-only parrot).
#   The train surrogate is RANDOMIZED per example + DISTINCT from the E4 eval nonce → E4 stays an INDEPENDENT reads-vs-memorizes probe (don't
#   judge a CF run by E4 alone; the headline is slope_e3_e1 on the un-swapped E1/E2/E3 going POSITIVE). Default-off (CF_FRAC=0 → dead path).
E1_DROP_MIN = float(os.environ.get("E1_DROP_MIN", "0.20"))         # P0 verdict gate: min E1-nll drop = the reader is LEARNING
READING_SLOPE_MARGIN = float(os.environ.get("READING_SLOPE_MARGIN", "0.02"))  # P0 verdict gate: min GROWTH of Δ(E3-E1) — the NO-SWAP-regime reading proxy
CF_LIFT_MIN = float(os.environ.get("CF_LIFT_MIN", "0.30"))         # P0 verdict gate (add.52): min held-out swapped counterfactual_lift = the
#   CAUSAL reading test when COUNTERFACTUAL eval is on. The un-swapped Δ(E3-E1) slope is STRUCTURALLY BLIND to a working CF run (E1/E3 share
#   byte-identical targets at COT=0; CF never trains the no-evidence/abstain case E3 measures) → it is CORROBORATING-only, NOT the gate, for a CF run.
RECALL_LOW = float(os.environ.get("RECALL_LOW", "0.15"))           # add.53b: the recall guard passes if FINAL orig_recall is low in ABSOLUTE
RECALL_DROP_MIN = float(os.environ.get("RECALL_DROP_MIN", "0.05")) #   terms OR it DROPPED by RECALL_DROP_MIN. The parrot baseline showed orig_recall≈0.007
#   (this small model is NOT a confident memorizer) → a strict 'recall must DROP' gate would FALSE-NO-GO a working CF run (recall starts ~0, can't drop).
CF_GENUINE_MIN = float(os.environ.get("CF_GENUINE_MIN", "0.20"))    # add.54: min genuine = swap_follow_matched − swap_follow_MISMATCHED. The
#   matched teacher-forced swap_follow is foolable by a 'copy the salient novel token' heuristic; pairing the swapped doc with a FOREIGN question
#   (E4-mismatch) is the clean control — a genuine QUESTION-CONDITIONED reader follows the swap on the matched Q but NOT the foreign one.


def lr_at(step: int) -> float:
    """Warmup → (cosine|linear) decay to LR*LR_MIN_FRAC over [WARMUP, STEPS] (LR-1). DECAY='none' = legacy flat-after-warmup.
    Pure function of the module env knobs → unit-testable without a training run."""
    if step <= WARMUP:
        return LR * step / max(1, WARMUP)
    if DECAY == "wsd":                                                # add.55: warmup → STABLE(flat@peak) → cosine decay over the last WSD_DECAY_FRAC
        decay_start = STEPS * (1.0 - WSD_DECAY_FRAC)
        if step <= decay_start:
            return LR                                                 # stable phase holds peak LR (the cosine-wasted back-half, recovered)
        dprog = min(1.0, (step - decay_start) / max(1.0, STEPS - decay_start))
        return LR * (LR_MIN_FRAC + (1.0 - LR_MIN_FRAC) * 0.5 * (1.0 + math.cos(math.pi * dprog)))
    prog = min(1.0, (step - WARMUP) / max(1, STEPS - WARMUP))
    if DECAY == "cosine":
        return LR * (LR_MIN_FRAC + (1.0 - LR_MIN_FRAC) * 0.5 * (1.0 + math.cos(math.pi * prog)))
    if DECAY == "linear":
        return LR * (1.0 - (1.0 - LR_MIN_FRAC) * prog)
    return LR


def split_decay_params(student):
    """LR-2: partition params into (weight-decayed ≥2-D weights, no-decay 1-D params + tied embedding). The no-decay set
    protects the RMSNorm gains + dt_bias + D + bn_w + fw, whose small/init values are load-bearing for SSM stability."""
    decay, no_decay = [], []
    for pn, pp in student.named_parameters():
        if not pp.requires_grad:
            continue
        (no_decay if (pp.ndim <= 1 or pn.endswith("embedding.weight") or pn == "fw") else decay).append((pn, pp))
    return [p for _, p in decay], [p for _, p in no_decay]


def select_score(e1, slope_e2, slope_e3, ctx_w=None, cf_lift=None):
    """BCS-1: best-ckpt score — low E1 nll + robust to distractors (small E2 slope) + REWARD reading. The reading reward is
    the held-out swapped cf_lift when available (the CAUSAL signal on a CF run), else the un-swapped E3-E1 slope (add.53: the
    slope is STRUCTURALLY BLIND to CF — see p0_verdict — so on a CF run the best ckpt MUST be picked by cf_lift, not the slope,
    else it ships the lowest-E1 ckpt and can miss the best reader / ship a nonce-collapsed late one). Higher is better; capped 1 nat."""
    w = CTX_W if ctx_w is None else ctx_w
    reading = cf_lift if cf_lift is not None else slope_e3
    reading = 0.0 if reading != reading else reading                 # NaN-safe (degenerate E4 lift) → no reward (conservative)
    return -(e1 + max(0.0, slope_e2)) + w * max(0.0, min(reading, 1.0))


def cf_frac_at(step: int, steps: int, frac: float, warm: float) -> float:
    """KD-C anneal (add.50): the counterfactual reading-force fraction ramps 0 → `frac` linearly AFTER warm*steps (so KD
    bootstraps fluency before reading is forced). Pure fn of step → cf_pick is resume-safe with no rng state to persist."""
    w = warm * steps
    return frac * min(1.0, max(0.0, (step - w) / max(1.0, steps - w)))


def nogold_kd_scale(k, keep_gold: bool, kd_nogold_w: float):
    """add.57 (extracted from the kd_ce closure for testability): down-weight KD on NO-GOLD examples (where the teacher emits
    its evidence-free memorized answer = a parrot channel). 1.0 or keep_gold → unchanged."""
    return k * kd_nogold_w if (kd_nogold_w != 1.0 and not keep_gold) else k


def nogold_ce_skip(keep_gold: bool, raft_nogold_ce: bool) -> bool:
    """add.57: skip the answer-CE on a no-gold example iff RAFT_NOGOLD_CE is off (don't teach 'answer without evidence')."""
    return (not raft_nogold_ce) and (not keep_gold)


def p0_verdict(eval_hist, e1_drop_min, reading_slope_margin, cf_lift_min, recall_low=0.15, recall_drop_min=0.05, cf_genuine_min=0.20):
    """Programmatic P0 GO/NO-GO — the 不要亏 gate that decides whether to scale a small run to the full 20k. eval_hist rows are
    (step, e1, slope_e2, slope_e3, kd, cf|None) where cf is {"lift","swap_follow","orig_recall","swap_mismatch","genuine"} from
    the held-out swapped E4 probe (or None when COUNTERFACTUAL is off). GO = LEARNING (E1 nll fell by e1_drop_min — this also
    subsumes the 'E1 must not regress' guard) AND READING. The READING test is REGIME-AWARE:
      • CF/swap regime (cf present): the CAUSAL test — ALL of (a) counterfactual_lift>cf_lift_min (reads-vs-memory, add.52);
        (b) recall guard — final orig_recall low OR dropped (add.53b, tolerant of a non-memorizer's ~0 baseline recall);
        (c) GENUINE — when the E4-MISMATCH control is measured, genuine = swap_follow(matched) − swap_follow(mismatched) >
        cf_genuine_min, which rejects a 'copy the salient novel token' heuristic that the teacher-forced matched swap_follow
        alone can't (add.54). The un-swapped Δ(E3-E1) slope is STRUCTURALLY BLIND to a working CF run → corroborating-only.
      • no-swap regime (cf absent, COUNTERFACTUAL off): fall back to the slope proxy — Δ(E3-E1) GREW by reading_slope_margin
        (add.51 anti-parrot: E1-drop ALONE was the original false-positive — a memorizer's E1 falls while the slope stays ~0)."""
    first, last = eval_hist[0], eval_hist[-1]
    e1_drop = first[1] - last[1]
    s3_0, s3_N = first[3], last[3]
    cf0 = first[5] if len(first) > 5 else None
    cfN = last[5] if len(last) > 5 else None
    e1_ok = e1_drop > e1_drop_min
    reading_trend_up = (s3_N - s3_0) > reading_slope_margin           # corroborating; the ONLY reading proxy when no swap signal
    swap_measured = cf0 is not None and cfN is not None
    genuine_last = None
    if swap_measured:                                                # CF/swap regime — the causal reading test
        lift_last = cfN["lift"]
        recall_drop = cf0["orig_recall"] - cfN["orig_recall"]
        # recall guard (add.53b): the model must NOT confidently default to the memorized answer in FREE generation. Tolerant
        # of an already-low baseline recall — pass if FINAL recall is low in absolute terms OR it DROPPED meaningfully.
        recall_ok = (cfN["orig_recall"] < recall_low) or (recall_drop > recall_drop_min)
        genuine_last = cfN.get("genuine")                            # add.54: matched − MISMATCH; question-conditioned reading
        genuine_measured = genuine_last is not None and genuine_last == genuine_last   # not None, not NaN
        genuine_ok = (genuine_last >= cf_genuine_min) if genuine_measured else True     # add.57: >= (match claim_card's CF_GENUINE_GATE op — no boundary disagreement; same 0.20 default)
        cf_reads = (lift_last > cf_lift_min) and recall_ok and genuine_ok
        reading_ok = bool(cf_reads)
    else:                                                            # no-swap regime — the slope proxy is all we have
        lift_last = recall_drop = cf_reads = recall_ok = genuine_measured = None
        genuine_ok = None
        reading_ok = reading_trend_up
    go = bool(e1_ok and reading_ok)
    return {
        "go": go, "e1_first": first[1], "e1_last": last[1], "e1_drop": e1_drop, "e1_drop_min": e1_drop_min, "e1_ok": bool(e1_ok),
        "slope_e3_first": s3_0, "slope_e3_last": s3_N, "slope_e3_delta": s3_N - s3_0,
        "reading_slope_margin": reading_slope_margin, "reading_trend_up": bool(reading_trend_up),
        "swap_measured": bool(swap_measured), "cf_lift_min": cf_lift_min,
        "cf_lift_first": (cf0["lift"] if swap_measured else None), "cf_lift_last": lift_last,
        "orig_recall_first": (cf0["orig_recall"] if swap_measured else None),
        "orig_recall_last": (cfN["orig_recall"] if swap_measured else None), "orig_recall_drop": recall_drop,
        "recall_ok": (None if recall_ok is None else bool(recall_ok)),
        "swap_mismatch_last": (cfN.get("swap_mismatch") if swap_measured else None),
        "genuine_last": genuine_last, "cf_genuine_min": cf_genuine_min,
        "genuine_ok": (bool(genuine_ok) if genuine_measured else None),   # None = the mismatch control wasn't measured
        "cf_reads": (None if cf_reads is None else bool(cf_reads)),
        "reading_basis": ("counterfactual_lift+genuine" if swap_measured else "slope_e3_e1"),
        "kd_first": first[4], "kd_last": last[4], "n_evals": len(eval_hist),
    }


def _sanitize(x):
    """Recursively replace non-finite floats (NaN/Inf) with None so eval_card.json is STRICT-JSON valid (BUG-4)."""
    if isinstance(x, float):
        return x if math.isfinite(x) else None
    if isinstance(x, dict):
        return {k: _sanitize(v) for k, v in x.items()}
    if isinstance(x, (list, tuple)):
        return [_sanitize(v) for v in x]
    return x


def kd_kl(student_logits, teacher_logits):
    """Full-vocab Stage-3 KD: KL(teacher || student) at temperature TAU, scaled by TAU^2 (Hinton)."""
    s = F.log_softmax(student_logits.float() / TAU, -1)
    t = F.log_softmax(teacher_logits.float() / TAU, -1)
    return F.kl_div(s, t, log_target=True, reduction="batchmean") * (TAU * TAU)


def kd_topk(student_logits, topk_idx, topk_val, pos_w=None):
    """Top-K KD from a CACHED teacher: student full-vocab log-softmax gathered at the teacher's top-K indices, vs the
    teacher's top-K soft target (renormalized within the K). Standard cached-distillation approximation.
    pos_w (optional [T] weights, KD-1): a per-position weighted mean instead of the uniform mean — used to up-weight the
    answer span. pos_w=None ⇒ uniform mean (identical to the legacy behavior; the 349-test default)."""
    assert student_logits.shape[0] == topk_idx.shape[0], \
        f"seq mismatch: student T={student_logits.shape[0]} vs cached T={topk_idx.shape[0]} — cache/example drift"
    lp = F.log_softmax(student_logits.float() / TAU, -1).gather(-1, topk_idx.long())   # [T,K] student logprob @ teacher topk
    q = F.softmax(topk_val.float() / TAU, -1)                                          # [T,K] teacher soft target
    per_pos = (q * (q.clamp_min(1e-9).log() - lp)).sum(-1)                             # [T] per-position KL
    if pos_w is not None:
        return (per_pos * pos_w).sum() / pos_w.sum().clamp_min(1e-9) * (TAU * TAU)
    return per_pos.mean() * (TAU * TAU)


def kd_topk_tail(student_logits, topk_idx, topk_val, topk_logZ, pos_w=None):
    """KD-4: EXACT KD via top-K + ONE lumped TAIL bucket (valid at TAU=1 only). Uses the cached per-token logZ to recover
    the TRUE teacher probs at the K kept tokens (q_k = exp(val - logZ), NOT renormalized-within-K) + a tail mass
    q_tail = 1 - Σq_k; the student gets the analogous top-K + tail split. Closes the ~1% top-K renorm bias of kd_topk."""
    assert TAU == 1.0, "kd_topk_tail is exact only at TAU=1 (set KD_EXACT_TAIL=0 or TAU=1)"
    assert student_logits.shape[0] == topk_idx.shape[0], \
        f"seq mismatch: student T={student_logits.shape[0]} vs cached T={topk_idx.shape[0]} — cache/example drift"
    s_logp = F.log_softmax(student_logits.float(), -1)
    s_k = s_logp.gather(-1, topk_idx.long())                                           # [T,K] student logprob @ teacher topk
    q_k = (topk_val.float() - topk_logZ.float().unsqueeze(-1)).exp()                    # [T,K] TRUE teacher prob at top-K
    q_tail = (1.0 - q_k.sum(-1)).clamp_min(1e-9)                                        # [T] teacher tail mass
    s_tail = (1.0 - s_k.exp().sum(-1)).clamp_min(1e-9)                                  # [T] student tail mass
    per_pos = (q_k * (q_k.clamp_min(1e-9).log() - s_k)).sum(-1) + q_tail * (q_tail.log() - s_tail.log())   # [T] exact KL(t‖s)
    if pos_w is not None:
        return (per_pos * pos_w).sum() / pos_w.sum().clamp_min(1e-9)
    return per_pos.mean()


def build_cache(teacher, train, cache_dir, extra_fp=""):
    """Phase 1 (run ONCE): frozen-teacher forward over every train example → cache top-K logits + per-example
    DIFFICULTY (teacher CE on the answer tokens, for curriculum ordering). Resumable (skips existing .pt). After this,
    training needs NO teacher forward — the dominant cost is amortized across all epochs."""
    os.makedirs(cache_dir, exist_ok=True)
    # CACHE-POLLUTION GUARD: ex{i}.pt is index-keyed, so reusing a CKPT_DIR after changing teacher/RAFT/N_ROWS/KD_K (or
    # the train/eval DATA itself — extra_fp) would silently train on STALE teacher logits / a moved baseline. Fingerprint
    # the config + a content hash of the actual examples; REFUSE (loud) on drift — never silently reuse.
    fp = hashlib.sha256(json.dumps({"teacher": TEACHER, "p": RAFT.P_GOLDEN, "k": RAFT.K_DISTRACT, "t": RAFT.MAX_LEN,
                                    "n_rows": N_ROWS, "kd_k": KD_K, "n_train": len(train), "data": extra_fp},
                                   sort_keys=True).encode()).hexdigest()[:16]
    fpf = os.path.join(cache_dir, "fingerprint.txt")
    if os.path.exists(fpf):
        old = open(fpf).read().strip()
        if old != fp:
            raise SystemExit(f"CACHE CONFIG DRIFT in {cache_dir}: built with {old}, current config {fp} "
                             f"(teacher/RAFT/N_ROWS/KD_K or the train/eval DATA changed) — reusing would POLLUTE training. "
                             f"Use a FRESH CKPT_DIR or delete the cache.")
    else:
        open(fpf, "w").write(fp)
    for i, ex in enumerate(train):
        path = os.path.join(cache_dir, f"ex{i}.pt")
        if os.path.exists(path):
            ex.update(torch.load(path, map_location="cpu")); continue
        ids = ex["input_ids"].to(DEV)
        with torch.no_grad():
            tl = teacher(ids.unsqueeze(0)).logits[0].float()
            val, idx = tl.topk(KD_K, dim=-1)
            logZ = torch.logsumexp(tl, dim=-1)                            # KD-4: per-token logZ → exact top-K + lumped-tail KD (cheap [T] vector)
            lp, tgt = tl[:-1], ids[1:]
            m = torch.arange(tgt.shape[0], device=DEV) >= (ex["prompt_len"] - 1)
            diff = float(F.cross_entropy(lp[m], tgt[m])) if m.any() else 0.0
        rec = {"topk_idx": idx.to(torch.int32).cpu(), "topk_val": val.to(torch.float16).cpu(),
               "topk_logZ": logZ.to(torch.float32).cpu(), "difficulty": diff}
        torch.save(rec, path + ".tmp"); os.replace(path + ".tmp", path)   # ATOMIC — a spot-preempt mid-save can't leave a corrupt ex{i}.pt
        ex.update(rec)
        if i % 200 == 0:
            print(f"  cache {i}/{len(train)} (diff={diff:.2f})", flush=True)


def save_ckpt(student, opt, step, path, sched=None):
    tmp = path + ".tmp"
    arch = "hybrid" if hasattr(student, "mla_pos") else "mamba"         # portability: the converter must rebuild the SAME graph
    torch.save({"model": student.state_dict(), "opt": opt.state_dict(), "step": step,
                "layers": LAYERS, "config": (MT.D_MODEL, MT.H, MT.P, MT.N, MT.R),
                "arch": arch, "vocab": student.embedding.weight.shape[0],
                "mla_positions": sorted(student.mla_pos) if arch == "hybrid" else None,
                "mla_rope": os.environ.get("MLA_ROPE") == "1",          # ARCH-3: tag so the (NoPE) deploy converter fails-closed on a RoPE ckpt
                "sched": sched.state_dict() if sched is not None else None}, tmp)   # resume the curriculum RNG deterministically
    os.replace(tmp, path)                                               # atomic — survives a mid-write preemption


@torch.no_grad()
def decode_parity(student, examples, max_ex=None):
    """HOST fp16 parity (NOT on-device CoreAI parity): the device graph mirrors the SEQUENTIAL decode (run_ref/step_ref);
    the eval card is computed on the PARALLEL run_twin. Cast a fp16 copy and compare argmax over the ANSWER SPAN on the
    trained ckpt — bounds the parallel-vs-sequential + bf16/fp16 gap. Real A19/CoreAI int8 parity is the device phase."""
    import copy
    n = int(os.environ.get("DECODE_PARITY_N", "8")) if max_ex is None else max_ex
    if not hasattr(student, "run_ref"):
        return {"argmax_agreement": None, "logit_max_err": None, "note": "model has no run_ref (sequential path); skipped"}
    sf = copy.deepcopy(student).half().eval()
    agree = tot = 0
    maxerr = 0.0
    for ex in examples[:n]:
        ids = ex["input_ids"].to(DEV)
        par = sf.run_twin(ids, collect_ssm=False)[0].float()            # parallel (the eval graph)
        seq = sf.run_ref(ids).float()                                   # sequential (the device graph)
        plen = int(ex["prompt_len"])
        m = torch.arange(par.shape[0] - 1, device=DEV) >= (plen - 1)    # answer-span positions
        if not m.any():
            continue
        pa, sa = par[:-1][m], seq[:-1][m]
        agree += int((pa.argmax(-1) == sa.argmax(-1)).sum()); tot += int(m.sum())
        maxerr = max(maxerr, float((pa - sa).abs().max()))
    return {"argmax_agreement": (agree / tot if tot else float("nan")), "logit_max_err": maxerr,
            "n_positions": tot, "n_examples": min(n, len(examples)), "dtype": "fp16"}


def main() -> None:
    from datasets import load_dataset
    from transformers import AutoModelForCausalLM, AutoTokenizer
    import hashlib
    os.makedirs(CKPT_DIR, exist_ok=True)
    if DEV == "cuda":                                                 # OOM mid-run = wasted spend; fail fast on a too-small pod
        gb = torch.cuda.get_device_properties(0).total_memory / 1e9
        assert gb >= 40, f"GPU {gb:.0f}GB < 40GB needed (teacher-3B + 24L student + AdamW + top-K cache); target: RTX PRO 6000 96GB"
        print(f"GPU VRAM {gb:.0f}GB OK", flush=True)
    print(f"cloud-distill | dev={DEV} dt={DT} | teacher={TEACHER} | student L{LAYERS}/D{MT.D_MODEL} "
          f"(>8L = CoreAI GPU-backed; <=8L pure-ANE) | steps={STEPS} accum={ACCUM} lr={LR} KD_W={KD_W} CE_W={CE_W} "
          f"| CACHE={CACHE} K={KD_K} ORDER={ORDER}")

    tok = AutoTokenizer.from_pretrained(TEACHER)
    vocab = tok.vocab_size
    tkw = {}
    if DEV == "cuda":
        tkw["attn_implementation"] = "sdpa"                          # DEFAULT sdpa — robust on Blackwell sm_120 (no flash-attn wheel);
        if os.environ.get("FLASH_ATTN") == "1":                     #   the teacher cache is a ONE-TIME pass, so sdpa speed is fine.
            try:
                import flash_attn  # noqa: F401
                tkw["attn_implementation"] = "flash_attention_2"
            except Exception as e:
                print(f"FLASH_ATTN=1 but flash_attn unavailable ({e!r}) — falling back to sdpa", flush=True)
    teacher = AutoModelForCausalLM.from_pretrained(
        TEACHER, dtype=(torch.bfloat16 if DEV == "cuda" else torch.float32), **tkw).to(DEV).eval()
    for p in teacher.parameters():
        p.requires_grad_(False)

    def _load(split, n):
        rs = load_dataset("hotpotqa/hotpot_qa", "distractor", split=f"{split}[:{n}]",
                          revision=os.environ.get("HOTPOT_REVISION") or None)   # pin a commit SHA → fully reproducible source
        return [build_example(r) for r in rs]
    def bucket(i):
        return int(hashlib.sha1(i.encode()).hexdigest(), 16) % 10
    if TRAIN_SPLIT == HELD_SPLIT:                                        # same source → disjoint by sha1 bucket (legacy; offline-cached val)
        ex_all = _load(TRAIN_SPLIT, N_ROWS)
        held_rows = [e for e in ex_all if bucket(e["id"]) < 1][:HELD_N]
        train_rows = [e for e in ex_all if bucket(e["id"]) >= 1]
    else:                                                               # CS-6: distinct splits → ~N_ROWS UNIQUE train + a disjoint held set
        train_rows = _load(TRAIN_SPLIT, N_ROWS)
        held_rows = _load(HELD_SPLIT, HELD_N)
    print(f"data rows: train={TRAIN_SPLIT}[:{N_ROWS}]→{len(train_rows)} unique | held={HELD_SPLIT}→{len(held_rows)}", flush=True)
    contamination_ok = {e["id"] for e in train_rows}.isdisjoint({e["id"] for e in held_rows})  # VERIFY the real split
    assert contamination_ok, "train/held id OVERLAP — split is contaminated"
    train = make_examples(train_rows, RAFT.P_GOLDEN, RAFT.K_DISTRACT, tok, seed=0)
    cf_pool = RAFT.make_cf_train_pool(train_rows, tok, seed=0) if CF_FRAC > 0 else []   # KD-C: reading-forcing CF pool (CE-only, no cache)
    # CF state is ALWAYS printed (add.52 observability) — a forgotten/silent CF setting must be unmistakable in train.log.
    if CF_FRAC > 0:
        print(f">> CF READING-FORCE: ON | CF_FRAC={CF_FRAC} ramp@{CF_WARM:.2f}*STEPS CF_CE_W={CF_CE_W} CF_LIFT_MIN={CF_LIFT_MIN} | "
              f"cf_pool={len(cf_pool)} swappable rows (multi-doc +{RAFT.K_DISTRACT} distractors, random surrogate per ex, CE-only, ≠ E4 nonce '{RAFT._SURROGATE}')"
              + ("" if cf_pool else " — EMPTY pool (no swappable rows): CF is a NO-OP this run"), flush=True)
        min_pool = max(200, int(0.05 * len(train_rows)))             # add.52 min-pool guard: an under-firing CF run is under-POWERED, not a verdict
        if 0 < len(cf_pool) < min_pool:
            print(f"!! WARNING CF under-powered: cf_pool={len(cf_pool)} < {min_pool} (max(200, 5% of {len(train_rows)} train rows)) — CF will "
                  f"repeat a few facts heavily (overfit/under-power risk). A FLAT reading result then means 'CF barely fired', NOT 'recipe failed'.", flush=True)
        if not COUNTERFACTUAL:
            print("!! WARNING CF_FRAC>0 but COUNTERFACTUAL=0: the held-out swapped reading metric (counterfactual_lift) will NOT be measured, "
                  "so the verdict falls back to the un-swapped slope proxy — which is STRUCTURALLY BLIND to a working CF run (add.52). "
                  "Set COUNTERFACTUAL=1 to judge a CF run correctly.", flush=True)
        if BATCH_SIZE > 1:
            print("!! WARNING CF_FRAC>0 with BATCH_SIZE>1: CF is wired only on the single-row path (the vmap batch path is the "
                  "deferred OOM-prone one) — CF will be SKIPPED. Use BATCH_SIZE=1 for the reading-forcing run.", flush=True)
    else:
        print(">> CF READING-FORCE: OFF (CF_FRAC=0) — set CF_FRAC>0 + COUNTERFACTUAL=1 to force/measure reading", flush=True)

    # FROZEN eval set: build once, persist atomically, RELOAD on resume so E1/E2/E3 are byte-identical across the
    # self-healing relaunch loop (reproducible slopes/gates; immune to an upstream dataset move mid-run).
    eval_set_path = os.path.join(CKPT_DIR, "eval_set.pt")
    if RESUME and os.path.exists(eval_set_path):
        E = torch.load(eval_set_path)
        print(f"resume: loaded FROZEN eval set from {eval_set_path} (E1/E2/E3={[len(E[m]) for m in E]})", flush=True)
    else:
        E = {m: make_eval_condition(held_rows, m, tok) for m in ("E1", "E2", "E3")}
        _common = set.intersection(*[{x["id"] for x in E[m]} for m in E])    # IDENTICAL subset across E1/E2/E3 → slopes are valid
        E = {m: [x for x in E[m] if x["id"] in _common] for m in E}
        _tmp = eval_set_path + ".tmp"; torch.save(E, _tmp); os.replace(_tmp, eval_set_path)   # atomic freeze (save_ckpt pattern)

    # E4 (reads-vs-memorizes) frozen the same way — when COUNTERFACTUAL, the swap-follow rate is measured PER-EVAL and threaded
    # into the verdict (so a parrot's flat swap-follow forces NO-GO), not just once in the final card. Built from held_rows → an
    # INDEPENDENT probe disjoint from the CF TRAIN pool (which is built from train_rows; the surrogate is also randomized + ≠ this nonce).
    E4_eval, E4_mismatch = [], []
    if COUNTERFACTUAL:
        cf_eval_path = os.path.join(CKPT_DIR, "cf_eval.pt")
        cf_mismatch_path = os.path.join(CKPT_DIR, "cf_mismatch.pt")
        if RESUME and os.path.exists(cf_eval_path):
            E4_eval = torch.load(cf_eval_path)
            E4_mismatch = torch.load(cf_mismatch_path) if os.path.exists(cf_mismatch_path) else []
        else:
            E4_eval = RAFT.make_counterfactual_condition(held_rows, tok)
            E4_mismatch = RAFT.make_counterfactual_mismatch(held_rows, tok)   # add.54: same swapped docs, FOREIGN questions
            if E4_mismatch:                                          # add.54b: keep only surrogate-surviving rows in BOTH, aligned (else
                E4_eval, E4_mismatch = RAFT.align_cf_survivors(E4_eval, E4_mismatch, tok)   # leave E4_eval intact — don't empty it on a degenerate set)
            _tmp = cf_eval_path + ".tmp"; torch.save(E4_eval, _tmp); os.replace(_tmp, cf_eval_path)
            _tmp = cf_mismatch_path + ".tmp"; torch.save(E4_mismatch, _tmp); os.replace(_tmp, cf_mismatch_path)
        print(f"E4 counterfactual probe: {len(E4_eval)} matched + {len(E4_mismatch)} MISMATCH (foreign-question) held rows "
              f"→ per-eval genuine = swap_follow(matched) − swap_follow(mismatch) → P0 verdict gate", flush=True)

    def _content_fp(items):                                              # hash the ACTUAL token content → loud on any data drift
        h = hashlib.sha256()
        for it in items:
            h.update(it["input_ids"].cpu().numpy().tobytes())
        return h.hexdigest()[:16]
    data_fp = _content_fp(train) + "|" + _content_fp([x for m in ("E1", "E2", "E3") for x in E[m]])
    print(f"data | HotpotQA distractor | train={len(train)} held={len(held_rows)} | E1/E2/E3={[len(E[m]) for m in E]} | "
          f"data_fp={data_fp} | P={RAFT.P_GOLDEN} K={RAFT.K_DISTRACT} T={RAFT.MAX_LEN} CoT={RAFT.COT} | vocab={vocab}")
    if CACHE:
        print(f"caching teacher top-{KD_K} over {len(train)} examples (once; resumable)…", flush=True)
        build_cache(teacher, train, os.path.join(CKPT_DIR, "cache"), extra_fp=data_fp)
        if ORDER == "curriculum":
            train.sort(key=lambda e: e["difficulty"])                    # easy (low teacher-CE) -> hard
        ds = [e["difficulty"] for e in train]
        print(f"cache done | order={ORDER} | difficulty [{min(ds):.2f},{max(ds):.2f}] | teacher no longer needed for KD")

    torch.manual_seed(0)
    ARCH = os.environ.get("ARCH", "mamba")                            # "hybrid" = 20 Mamba-3 + 4 MLA @ L6/12/18/23 (the DUET reader)
    ckpt = os.path.join(CKPT_DIR, "ckpt_latest.pt")
    if RESUME and os.path.exists(ckpt):                               # the ckpt is AUTHORITATIVE on arch/vocab (avoid rebuild mismatch)
        _peek = torch.load(ckpt, map_location="cpu")
        ARCH = _peek.get("arch", ARCH); vocab = _peek.get("vocab", vocab)
        print(f"resume: ckpt arch={ARCH} vocab={vocab}")
    master_fp32 = (DEV == "cuda" and FP32_MASTER)                     # TBC-6: fp32 master weights + autocast-bf16 forward (cuda)
    build_dt = torch.float32 if master_fp32 else DT
    student = (HY.HybridM(vocab, LAYERS) if ARCH == "hybrid" else MT.M(vocab, LAYERS)).to(DEV).to(build_dt)
    print(f"student ARCH={ARCH} ({'HybridM 20-Mamba+4-MLA' if ARCH == 'hybrid' else 'pure Mamba-3'}) vocab={vocab} "
          f"| {'fp32-master+autocast-' + str(DT).split('.')[-1] if master_fp32 else 'dtype=' + str(build_dt).split('.')[-1]}")
    # LR-2: NO-DECAY group for 1-D params (RMSNorm gains, dt_bias, D, bn_w, fw) + the tied embedding. Weight-decaying the
    # norm gains / dt_bias would erode the small-dt init that keeps the SSM recurrence bounded (architecture-load-bearing).
    decay_p, no_decay_p = split_decay_params(student)
    opt = torch.optim.AdamW([{"params": decay_p, "weight_decay": 0.1},
                             {"params": no_decay_p, "weight_decay": 0.0}], lr=LR, betas=(0.9, 0.95))
    print(f"optimizer: AdamW decay={sum(p.numel() for p in decay_p)/1e6:.0f}M / no-decay={sum(p.numel() for p in no_decay_p)/1e3:.0f}K params | "
          f"LR={LR} DECAY={DECAY}→{LR_MIN_FRAC:.2f} WARMUP={WARMUP} GRAD_CLIP={GRAD_CLIP} | KD_ANSWER_W={KD_ANSWER_W} KD_NOGOLD_W={KD_NOGOLD_W} CTX_W={CTX_W} | "
          f"BATCH_SIZE={BATCH_SIZE} TRAIN_SPLIT={TRAIN_SPLIT} NOGOLD_CE={int(RAFT_NOGOLD_CE)} MLA_ROPE={int(os.environ.get('MLA_ROPE') == '1')}", flush=True)
    if os.environ.get("MLA_ROPE") == "1":                            # ARCH-3 footgun guard: the deploy converter is still NoPE
        print("!! WARNING MLA_ROPE=1: training WITH MLA RoPE, but the device converter (mamba3_hybrid_decode_deploy) is still "
              "NoPE — this ckpt will FAIL-CLOSED at deploy (resolve_ckpt asserts mla_rope==0). Use ONLY for a cloud quality "
              "A/B, NOT for a ckpt you intend to ship to the A19 yet.", flush=True)
    if BATCH_SIZE > 1:                                               # TBC-1 honest limit: vmap materializes the chunked scan × batch
        print(f"!! WARNING BATCH_SIZE={BATCH_SIZE}: the vmap-batched forward is PROVEN-equivalent to per-row but materializes the "
              f"O(C^2) chunked scan × batch — it OOMs at long T (~87 GiB at B=4/T={RAFT.MAX_LEN}, no margin even on the 96 GB RTX PRO 6000). Viable ONLY at "
              f"SMALL T; for production T={RAFT.MAX_LEN} keep BATCH_SIZE=1. Real throughput batching needs the memory-efficient "
              f"batched-scan rewrite (still deferred — vmap is NOT it).", flush=True)
    if not CACHE and STEPS > 200:                                   # 不要亏: CACHE=0 = a full 3B teacher forward EVERY step
        print(f"!! WARNING CACHE=0 with STEPS={STEPS}: the 3B teacher runs a FULL forward on EVERY step (~10-100× the cost of the "
              f"cached top-K KD). Intended only for tiny debug runs. For the real run use CACHE=1 (the default).", flush=True)
    start = 1
    if RESUME and os.path.exists(ckpt):
        st = torch.load(ckpt, map_location=DEV)
        student.load_state_dict(st["model"]); opt.load_state_dict(st["opt"]); start = st["step"] + 1
        print(f"RESUMED from {ckpt} at step {start}")
    if COMPILE:
        student.run_twin = torch.compile(student.run_twin)              # optional CUDA fusion of the chunked scan

    @torch.no_grad()
    def evaluate():
        out = {}
        for m in ("E1", "E2", "E3"):
            nll, acc, sk = eval_nll(student, E[m])
            out[m] = (nll, acc, sk)
        return out

    USE_SCHEDULER = os.environ.get("USE_SCHEDULER", "0") == "1"       # opt-in: dynamic competence curriculum (else static ORDER)
    sched = (CurriculumScheduler([e.get("difficulty", 0.0) for e in train], STEPS,
                                 CurriculumConfig(pace_T_frac=PACE_T_FRAC))    # CURR-1: PACE_T_FRAC<1 drills the hard tail in the back half
             if USE_SCHEDULER else None)
    # HONEST label: USE_SCHEDULER = difficulty-curriculum (competence sampling) + STATIC RAFT(P,K). The scheduler's RAFT
    # gold→distractor staging (raft_params) is NOT wired — distractor composition is frozen at make_examples + locked by the
    # teacher cache. Dynamic per-step RAFT would bust the cache (~10-100x cost). Not 'multi-stage RAFT curriculum'.
    print(f"curriculum: {'difficulty-curriculum (competence sampling) + STATIC RAFT(P=%.2f,K=%d)' % (RAFT.P_GOLDEN, RAFT.K_DISTRACT) if USE_SCHEDULER else 'static ORDER=' + ORDER}", flush=True)
    assert STEPS % ACCUM == 0, f"STEPS={STEPS} must be a multiple of ACCUM={ACCUM} (else the final partial accumulation is dropped)"
    best_path, best_meta = os.path.join(CKPT_DIR, "ckpt_best.pt"), os.path.join(CKPT_DIR, "best_meta.json")
    best_score = -float("inf")
    if RESUME and os.path.exists(ckpt):                              # BUG-1: persist/restore best_score so a resume can't
        _st = torch.load(ckpt, map_location="cpu")                   # overwrite a genuinely-better ckpt_best with a worse one
        if sched is not None and _st.get("sched"):
            sched.load_state_dict(_st["sched"])
        if os.path.exists(best_meta):
            best_score = json.load(open(best_meta)).get("best_score", -float("inf"))
            print(f"RESUMED best_score={best_score:.3f} (curriculum rng {'restored' if sched and _st.get('sched') else 'n/a'})", flush=True)
        else:
            print("WARNING: resuming but no best_meta.json — best_score reset to -inf (a worse ckpt_best could be saved)", flush=True)

    def kd_ce(sl, ex):                                                   # per-example KD + masked CE (shared by single + batched paths)
        pos_w = None
        if KD_ANSWER_W != 1.0:                                           # KD-1: up-weight KD on the answer span
            ans = (torch.arange(sl.shape[0], device=DEV) >= (ex["prompt_len"] - 1)).float()
            pos_w = 1.0 + (KD_ANSWER_W - 1.0) * ans
        if CACHE:                                                        # no teacher forward — cached top-K KD
            if KD_EXACT_TAIL and "topk_logZ" in ex:                      # KD-4: exact top-K + lumped-tail KD (TAU=1)
                k = kd_topk_tail(sl, ex["topk_idx"].to(DEV), ex["topk_val"].to(DEV), ex["topk_logZ"].to(DEV), pos_w=pos_w)
            else:
                k = kd_topk(sl, ex["topk_idx"].to(DEV), ex["topk_val"].to(DEV), pos_w=pos_w)
        else:
            with torch.no_grad():
                tl = teacher(ex["input_ids"].to(DEV).unsqueeze(0)).logits[0]
            k = kd_kl(sl, tl)
        k = nogold_kd_scale(k, ex.get("keep_gold", True), KD_NOGOLD_W)   # NS-10: down-weight KD on no-gold (the teacher's evidence-free memorized
        #   answer = a parrot channel CF doesn't cover). Complements RAFT_NOGOLD_CE (CE-only gate); both extracted to module helpers (add.57, testable).
        ce = None if nogold_ce_skip(ex.get("keep_gold", True), RAFT_NOGOLD_CE) else masked_ce(sl, ex["input_ids"].to(DEV), ex["prompt_len"])
        return k, ce                                                     # fp32 CE (NS-2)

    def cf_pick(step):                                                   # KD-C: deterministic per-step CF draw (resume-safe — seeded by step,
        if not cf_pool:                                                  #   no rng state to persist) + CF-3 anneal via cf_frac_at
            return None
        frac = cf_frac_at(step, STEPS, CF_FRAC, CF_WARM)
        r = random.Random((step * 2654435761) & 0x7FFFFFFF)
        return cf_pool[r.randrange(len(cf_pool))] if r.random() < frac else None

    t0 = run_start = time.time()
    opt.zero_grad(set_to_none=True)
    nonfinite, last_gnorm, eval_hist, cf_count, hit_wall = 0, 0.0, [], 0, False
    for step in range(start, STEPS + 1):
        if MAX_SEC > 0 and (time.time() - run_start) > MAX_SEC:          # add.55: IN-LOOP hard wall — save + break GRACEFULLY (the wrapper
            save_ckpt(student, opt, step - 1, ckpt, sched)              #   MAX_SEC only fires post-crash; a healthy run needs this to honor a time wall).
            hit_wall = True                                             # add.57: so the final save below can't overwrite this at step=STEPS (which would make RESUME think it's DONE)
            print(f"!! MAX_SEC={MAX_SEC:.0f}s reached at step {step} — saved ckpt@{step-1} + stopping gracefully (RESUME continues; ckpt_best is the ship target)", flush=True)
            break
        lr_t = lr_at(step)                                               # LR-1: warmup → decay
        for g in opt.param_groups:
            g["lr"] = lr_t
        # TBC-6 + NS-8.2: ALWAYS autocast on cuda — even a bf16-built (FP32_MASTER=0) model then gets fp32 cumsum/exp/carry in
        # the chunked scan by autocast policy (a pure-bf16 scan diverged up to 17% rel-err). Non-cuda (mps/cpu fp32) = nullcontext.
        amp = torch.autocast("cuda", dtype=DT) if DEV == "cuda" else contextlib.nullcontext()
        ce_w = CE_W                                                      # KD-C: a CF step overrides KD→0 + uses CF_CE_W (CE-only reading force)
        cf_ex = cf_pick(step) if (CF_FRAC > 0 and BATCH_SIZE == 1) else None
        if cf_ex is not None:                                            # reading-FORCING counterfactual: CE-only (the teacher doesn't know the swap)
            with amp:
                sl = student.run_twin(cf_ex["input_ids"].to(DEV), collect_ssm=False)[0]
            kd = torch.zeros((), device=DEV, dtype=sl.dtype)
            ce = masked_ce(sl, cf_ex["input_ids"].to(DEV), cf_ex["prompt_len"])
            ce_w, cf_count = CF_CE_W, cf_count + 1
        elif BATCH_SIZE > 1:                                             # TBC-1: vmap-batched forward (≡ per-row, proven 0-err) + per-row loss
            if USE_SCHEDULER:
                exs = [train[sched.sample(step)] for _ in range(BATCH_SIZE)]   # competence(step) correct; B draws
            else:
                exs = [train[((step - 1) * BATCH_SIZE + i) % len(train)] for i in range(BATCH_SIZE)]
            maxT = max(e["input_ids"].shape[0] for e in exs)
            ids_b = torch.stack([F.pad(e["input_ids"], (0, maxT - e["input_ids"].shape[0])) for e in exs]).to(DEV)  # right-pad (causal-safe)
            with amp:
                sl_b = torch.vmap(lambda t: student.run_twin(t, collect_ssm=False)[0])(ids_b)   # [B,maxT,V]
            kds, ces = [], []
            for i, e in enumerate(exs):
                tb = e["input_ids"].shape[0]
                k_, c_ = kd_ce(sl_b[i, :tb], e)                          # real positions only — padded outputs never enter the loss
                kds.append(k_); ces.append(c_)
            kd = torch.stack(kds).mean()
            ce_terms = [c for c in ces if c is not None]
            ce = torch.stack(ce_terms).mean() if ce_terms else None
        else:
            ex = train[sched.sample(step) if USE_SCHEDULER else (step - 1) % len(train)]
            with amp:
                sl = student.run_twin(ex["input_ids"].to(DEV), collect_ssm=False)[0]
            kd, ce = kd_ce(sl, ex)
        loss = (KD_W * kd + (ce_w * ce if ce is not None else 0.0)) / ACCUM
        if not torch.isfinite(loss):                                     # NS-3: skip a transient non-finite step, do NOT crash the run
            nonfinite += 1
            opt.zero_grad(set_to_none=True)
            print(f"WARNING step {step}: non-finite loss — skipped ({nonfinite} total)", flush=True)
            assert nonfinite <= max(20, STEPS // 100), f"too many non-finite losses ({nonfinite}) — diverging, aborting"
            continue
        loss.backward()
        if step % ACCUM == 0:
            gn = torch.nn.utils.clip_grad_norm_(student.parameters(), GRAD_CLIP)
            if torch.isfinite(gn):                                       # NS-4: an inf grad-norm must not poison AdamW moments
                opt.step(); last_gnorm = float(gn)
            else:
                print(f"WARNING step {step}: non-finite grad-norm — opt.step skipped", flush=True)
            opt.zero_grad(set_to_none=True)
        if step % 100 == 0:
            tps = 100 * RAFT.MAX_LEN / (time.time() - t0); t0 = time.time()
            curr = (f" | q={sched.difficulty_quantile(step):.2f} pool={len(sched._candidates(step)) / sched.N:.2f}"
                    if USE_SCHEDULER else "")    # CURR-5: is the easy→hard ramp actually firing or saturated? (deterministic, no rng touch)
            cf_tag = f" cf={cf_count}{'*' if cf_ex is not None else ''}" if CF_FRAC > 0 else ""   # KD-C: CF steps so far (* = this step was CF)
            print(f"step {step:6d}/{STEPS} | lr={lr_t:.2e} KD={float(kd):.3f} CE={float(ce) if ce is not None else 0:.3f} "
                  f"| gnorm={last_gnorm:.2f}{curr}{cf_tag} | ~{tps:.0f} tok/s", flush=True)
        if step % CKPT_EVERY == 0:
            save_ckpt(student, opt, step, ckpt, sched)
        if step % EVAL_EVERY == 0:
            ev = evaluate()
            e1 = ev["E1"][0]; slope_e2 = ev["E2"][0] - e1; slope_e3 = ev["E3"][0] - e1
            subset_ok = ev["E1"][2] == ev["E2"][2] == ev["E3"][2]    # equal skips → the slope is over the SAME surviving subset
            cf = None                                                # add.52: held-out swapped counterfactual = the CAUSAL reading signal
            if COUNTERFACTUAL and E4_eval:                           # computed BEFORE the score so best-ckpt selection can use cf_lift (add.53)
                cr = EVAL.eval_counterfactual(student, E4_eval, tok)
                mm = EVAL.eval_counterfactual(student, E4_mismatch, tok, follow_only=True)["swap_follow_rate"] if E4_mismatch else float("nan")
                genuine = cr["swap_follow_rate"] - mm if mm == mm else float("nan")   # add.54: matched − MISMATCH = question-conditioned reading
                cf = {"lift": cr["counterfactual_lift"], "swap_follow": cr["swap_follow_rate"], "orig_recall": cr["orig_recall_rate"],
                      "swap_mismatch": mm, "genuine": genuine}
            score = select_score(e1, slope_e2, slope_e3, cf_lift=(cf["lift"] if cf else None))   # reward CAUSAL reading on a CF run, not the blind slope
            if score > best_score and subset_ok and all(math.isfinite(ev[m][0]) for m in ev):
                best_score = score
                save_ckpt(student, opt, step, best_path, sched)       # best-ckpt selection (metric-gated, NOT just last)
                json.dump({"best_score": best_score, "step": step, "E1_nll": e1, "E2_nll": ev["E2"][0], "E3_nll": ev["E3"][0],
                           "slope_e2_e1": slope_e2, "slope_e3_e1": slope_e3, "cf_lift": (cf["lift"] if cf else None),
                           "orig_recall": (cf["orig_recall"] if cf else None),
                           "E1_acc": ev["E1"][1], "E2_acc": ev["E2"][1], "E3_acc": ev["E3"][1]},
                          open(best_meta + ".tmp", "w"))             # BCS-2: full eval breakdown for auditability
                os.replace(best_meta + ".tmp", best_meta)             # persist best_score so a resume can't regress ckpt_best
            eval_hist.append((step, e1, slope_e2, slope_e3, float(kd), cf))   # 6-tuple: cf dict = the CAUSAL reading signal
            print("  EVAL " + " ".join(f"{m}: nll={ev[m][0]:.3f} acc={ev[m][1]:.1%} sk={ev[m][2]}" for m in ev)
                  + f"  | Δ(E2-E1)={slope_e2:+.3f} Δ(E3-E1)={slope_e3:+.3f} | best_score={best_score:.3f}"
                  + (f" | E4 lift={cf['lift']:+.2f} genuine={cf['genuine']:+.2f} (swap={cf['swap_follow']:.2f} "
                     f"mism={cf['swap_mismatch']:.2f} recall={cf['orig_recall']:.2f})" if cf is not None else "")
                  + ("  ↑best" if score == best_score else "") + ("" if subset_ok else "  [subset≠ — slope unreliable]"), flush=True)
    if not hit_wall:                                                 # add.57: DON'T overwrite the wall-save (step<STEPS) with step=STEPS — that would
        save_ckpt(student, opt, STEPS, ckpt, sched)                  #   make RESUME (start=STEPS+1) skip the loop and treat an under-trained model as complete.
        print(f"DONE — final ckpt {ckpt}")
    else:
        print(f"STOPPED at MAX_SEC wall — PARTIAL run (ckpt saved for RESUME, NOT done). The verdict/eval-card below grade a PARTIAL model.", flush=True)
    if len(eval_hist) >= 2:                                          # programmatic P0 GO/NO-GO (不要亏 — don't scale a PARROT run)
        verdict = p0_verdict(eval_hist, E1_DROP_MIN, READING_SLOPE_MARGIN, CF_LIFT_MIN, RECALL_LOW, RECALL_DROP_MIN, CF_GENUINE_MIN)
        verdict["steps"] = STEPS
        verdict["partial_run"] = hit_wall                           # add.57: a wall-stopped run's GO/NO-GO is premature — flag it
        with open(os.path.join(CKPT_DIR, "verdict.json"), "w") as f:
            json.dump(_sanitize(verdict), f, indent=2)               # strict-JSON: non-finite (e.g. NaN lift on a degenerate E4) → null
        v = verdict
        # GO = LEARNING (E1 drop) AND READING. READING is the held-out swapped counterfactual_lift+recall-drop when measured
        # (add.52 — the un-swapped slope is BLIND to a working CF run), else the slope proxy (add.51 anti-parrot fallback).
        if v["swap_measured"]:
            gstr = (f"genuine(matched−mism) {v['genuine_last']:+.2f} vs >{CF_GENUINE_MIN}{'✓' if v['genuine_ok'] else '✗'}"
                    if v["genuine_last"] is not None and v["genuine_last"] == v["genuine_last"] else "genuine n/a")
            read_str = (f"READ[causal]: lift {v['cf_lift_first']:+.2f}→{v['cf_lift_last']:+.2f} vs >{CF_LIFT_MIN} + "
                        f"recall {v['orig_recall_first']:.2f}→{v['orig_recall_last']:.2f}{'✓' if v['recall_ok'] else '✗'} + {gstr} "
                        f"⇒ reads {'✓' if v['cf_reads'] else '✗'} [slope Δ(E3-E1) {v['slope_e3_delta']:+.3f} corroborating-only]")
        else:
            read_str = (f"READ[slope-proxy]: Δ(E3-E1) {v['slope_e3_first']:+.3f}→{v['slope_e3_last']:+.3f} "
                        f"grew {v['slope_e3_delta']:+.3f}{'✓' if v['reading_trend_up'] else '✗'} vs >{READING_SLOPE_MARGIN}")
        print(f">> P0 VERDICT: {'GO ✓ scale to 20k' if v['go'] else 'NO-GO ✗ do NOT scale — still parrots / fix recipe first'} "
              f"(LEARN: E1 {v['e1_first']:.2f}→{v['e1_last']:.2f} Δ{v['e1_drop']:+.2f}{'✓' if v['e1_ok'] else '✗'} vs >{E1_DROP_MIN} "
              f"| {read_str} | KD {v['kd_first']:.2f}→{v['kd_last']:.2f}) → verdict.json", flush=True)

    # The checkpoint is born WITH its eval card: run the serious battery on the BEST checkpoint + the honest claim_card.
    if os.path.exists(best_path):
        student.load_state_dict(torch.load(best_path, map_location=DEV)["model"])
        eval_on = "ckpt_best"
        print(f"loaded best ckpt (score={best_score:.3f}) for the final eval card", flush=True)
    else:                                                            # BUG-3: no best was ever saved (all evals non-finite)
        eval_on = "ckpt_latest"
        print("WARNING: no ckpt_best.pt (no finite eval) — eval card runs on ckpt_latest, NOT a best-selected ckpt", flush=True)
    eos = getattr(tok, "eos_token_id", None)
    try:                                                             # never lose the run to an eval crash — the ckpt is saved
        raft = EVAL.eval_raft_robustness(student, E)
        ppl = EVAL.compute_perplexity(student, [], E["E1"])
        t_e1 = EVAL.teacher_answer_nll(teacher, E["E1"])             # MEASURED teacher baseline (the real task_fit gap target)
        fid = EVAL.compute_fidelity(student, teacher, E["E1"][:64])
        gen = EVAL.generate_and_score(student, E["E1"][:64], tok, maxlen=24, eos=eos)
        dp = decode_parity(student, E["E1"])                         # HOST fp16 sequential-vs-parallel parity (NOT on-device CoreAI)
        res = {"perplexity": ppl, "raft": raft, "fidelity": fid, "generation": gen,
               "quant": EVAL.quant_fidelity_stub(), "contamination_ok": contamination_ok,
               "teacher_E1_nll": t_e1, "decode_parity": dp, "best_score": best_score, "eval_on": eval_on}
        if COUNTERFACTUAL and E4_eval:                              # E4: reads-vs-memorizes — FROZEN per-eval probe via the SHARED full helper
            res["counterfactual"] = EVAL.eval_counterfactual_full(student, E4_eval, E4_mismatch, tok)   # add.57: single-source w/ the offline path
        res["claim"] = EVAL.claim_card(res)
    except Exception as e:
        import traceback
        traceback.print_exc()
        res = {"eval_error": repr(e), "contamination_ok": contamination_ok, "best_score": best_score, "eval_on": eval_on}
        res["claim"] = EVAL.claim_card(res)                          # fail-closed → 亏的 (missing gates default False)
    with open(os.path.join(CKPT_DIR, "eval_card.json"), "w") as f:
        json.dump(_sanitize(res), f, indent=2)                       # BUG-4: non-finite floats → null (strict-JSON valid)
    _c = res["claim"]
    if "raft" in res:
        print(f"EVAL CARD → {_c['status']}" + (f"  failed: {_c['failed_gates']}" if _c['failed_gates'] else "")
              + f"  (E1 nll={res['raft']['E1']['nll']:.3f}, ctx-use slope(E3-E1)={res['raft']['slope_e3_e1']:+.3f}, "
              + f"teacher_E1={res['teacher_E1_nll']:.3f}, EM={res['generation']['EM']:.2f}, F1={res['generation']['F1']:.2f}, "
              + f"parity={res['decode_parity'].get('argmax_agreement')})", flush=True)
        if STEPS <= 5000 and _c["failed_gates"]:                     # readability (不要亏): a P0-scale 亏的 is EXPECTED, not "broken"
            print("   NOTE: a 亏的 ✗ at this STEPS is EXPECTED — the 8 gates are calibrated for the full ~20k run. The GO/NO-GO "
                  "is the P0 VERDICT line above (E1 nll trend), NOT this card.", flush=True)
    else:
        print(f"EVAL CARD → {_c['status']}  (eval crashed: {res.get('eval_error')}; ckpt is saved, re-run eval offline)", flush=True)


if __name__ == "__main__":
    main()
