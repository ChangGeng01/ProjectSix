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

RunPod: bash scripts/runpod_setup.sh && bash scripts/runpod_distill.sh   (1× A100/H100 80GB).
"""
from __future__ import annotations

import contextlib
import hashlib
import json
import math
import os
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
from mamba3_curriculum_scheduler import CurriculumScheduler
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
DECAY = os.environ.get("DECAY", "cosine")                               # LR-1: cosine | linear | none (legacy flat-after-warmup)
LR_MIN_FRAC = float(os.environ.get("LR_MIN_FRAC", "0.07"))             # LR-1: decay floor as a fraction of LR
KD_ANSWER_W = float(os.environ.get("KD_ANSWER_W", "1.0"))             # KD-1: >1 up-weights KD on the answer span (1.0 = uniform = legacy)
FP32_MASTER = os.environ.get("FP32_MASTER", "1") == "1"               # TBC-6: fp32 master weights + autocast-bf16 forward on cuda
CTX_W = float(os.environ.get("CTX_W", "0.5"))                         # BCS-1: best-ckpt reward for context-use (positive E3-E1 slope = reading)


def lr_at(step: int) -> float:
    """Warmup → (cosine|linear) decay to LR*LR_MIN_FRAC over [WARMUP, STEPS] (LR-1). DECAY='none' = legacy flat-after-warmup.
    Pure function of the module env knobs → unit-testable without a training run."""
    if step <= WARMUP:
        return LR * step / max(1, WARMUP)
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


def select_score(e1, slope_e2, slope_e3, ctx_w=None):
    """BCS-1: best-ckpt score — low E1 nll + robust to distractors (small E2 slope) + REWARD context-use (a positive
    E3-E1 slope means the model USES the gold doc, not parrots). Higher is better; the E3 reward is capped at 1.0 nat."""
    w = CTX_W if ctx_w is None else ctx_w
    return -(e1 + max(0.0, slope_e2)) + w * max(0.0, min(slope_e3, 1.0))


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
            lp, tgt = tl[:-1], ids[1:]
            m = torch.arange(tgt.shape[0], device=DEV) >= (ex["prompt_len"] - 1)
            diff = float(F.cross_entropy(lp[m], tgt[m])) if m.any() else 0.0
        rec = {"topk_idx": idx.to(torch.int32).cpu(), "topk_val": val.to(torch.float16).cpu(), "difficulty": diff}
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
                "sched": sched.state_dict() if sched is not None else None}, tmp)   # resume the curriculum RNG deterministically
    os.replace(tmp, path)                                               # atomic — survives a mid-write preemption


@torch.no_grad()
def decode_parity(student, examples, max_ex=None):
    """DEVICE-TRUTH gate: the A19 runs the SEQUENTIAL fp16 decode (run_ref/step_ref); the eval card is computed on the
    PARALLEL run_twin in bf16. Cast a fp16 copy and compare argmax over the ANSWER SPAN on the trained ckpt — bounds the
    parallel-vs-sequential + dtype gap the eval would otherwise hide. Skips gracefully if the model has no run_ref."""
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
        assert gb >= 40, f"GPU {gb:.0f}GB < 40GB needed (teacher-3B + 24L student + AdamW + top-K cache); use A100/H100 80GB"
        print(f"GPU VRAM {gb:.0f}GB OK", flush=True)
    print(f"cloud-distill | dev={DEV} dt={DT} | teacher={TEACHER} | student L{LAYERS}/D{MT.D_MODEL} "
          f"(>8L = CoreAI GPU-backed; <=8L pure-ANE) | steps={STEPS} accum={ACCUM} lr={LR} KD_W={KD_W} CE_W={CE_W} "
          f"| CACHE={CACHE} K={KD_K} ORDER={ORDER}")

    tok = AutoTokenizer.from_pretrained(TEACHER)
    vocab = tok.vocab_size
    tkw = {}
    if DEV == "cuda":
        try:
            import flash_attn  # noqa: F401
            tkw["attn_implementation"] = "flash_attention_2"
        except Exception:
            tkw["attn_implementation"] = "sdpa"
    teacher = AutoModelForCausalLM.from_pretrained(
        TEACHER, dtype=(torch.bfloat16 if DEV == "cuda" else torch.float32), **tkw).to(DEV).eval()
    for p in teacher.parameters():
        p.requires_grad_(False)

    rows = load_dataset("hotpotqa/hotpot_qa", "distractor", split=f"validation[:{N_ROWS}]",
                        revision=os.environ.get("HOTPOT_REVISION") or None)   # pin a commit SHA → fully reproducible source
    print(f"data rows: requested N_ROWS={N_ROWS}, got {len(rows)}", flush=True)   # HotpotQA val ~7405 → larger N_ROWS silently caps
    ex_all = [build_example(r) for r in rows]
    def bucket(i):
        return int(hashlib.sha1(i.encode()).hexdigest(), 16) % 10
    held_rows = [e for e in ex_all if bucket(e["id"]) < 1][:200]          # ~10% held, capped
    train_rows = [e for e in ex_all if bucket(e["id"]) >= 1]
    contamination_ok = {e["id"] for e in train_rows}.isdisjoint({e["id"] for e in held_rows})  # VERIFY the real split
    assert contamination_ok, "train/held id OVERLAP — split is contaminated"   # bucket split is disjoint by construction
    train = make_examples(train_rows, RAFT.P_GOLDEN, RAFT.K_DISTRACT, tok, seed=0)

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
          f"LR={LR} DECAY={DECAY}→{LR_MIN_FRAC:.2f} WARMUP={WARMUP} | KD_ANSWER_W={KD_ANSWER_W} CTX_W={CTX_W}", flush=True)
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
    sched = CurriculumScheduler([e.get("difficulty", 0.0) for e in train], STEPS) if USE_SCHEDULER else None
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

    t0 = time.time()
    opt.zero_grad(set_to_none=True)
    nonfinite, last_gnorm = 0, 0.0
    for step in range(start, STEPS + 1):
        lr_t = lr_at(step)                                               # LR-1: warmup → decay
        for g in opt.param_groups:
            g["lr"] = lr_t
        ex = train[sched.sample(step) if USE_SCHEDULER else (step - 1) % len(train)]
        ids = ex["input_ids"].to(DEV)
        with (torch.autocast("cuda", dtype=DT) if master_fp32 else contextlib.nullcontext()):   # TBC-6: bf16 forward, fp32 master
            sl = student.run_twin(ids, collect_ssm=False)[0]
        if CACHE:                                                        # no teacher forward — cached top-K KD
            if KD_ANSWER_W != 1.0:                                       # KD-1: up-weight KD on the answer span
                ans = (torch.arange(sl.shape[0], device=DEV) >= (ex["prompt_len"] - 1)).float()
                kd = kd_topk(sl, ex["topk_idx"].to(DEV), ex["topk_val"].to(DEV), pos_w=1.0 + (KD_ANSWER_W - 1.0) * ans)
            else:
                kd = kd_topk(sl, ex["topk_idx"].to(DEV), ex["topk_val"].to(DEV))
        else:
            with torch.no_grad():
                tl = teacher(ids.unsqueeze(0)).logits[0]
            kd = kd_kl(sl, tl)
        ce = masked_ce(sl, ids, ex["prompt_len"])                        # fp32 CE (NS-2)
        loss = (KD_W * kd + (CE_W * ce if ce is not None else 0.0)) / ACCUM
        if not torch.isfinite(loss):                                     # NS-3: skip a transient non-finite step, do NOT crash the run
            nonfinite += 1
            opt.zero_grad(set_to_none=True)
            print(f"WARNING step {step}: non-finite loss — skipped ({nonfinite} total)", flush=True)
            assert nonfinite <= max(20, STEPS // 100), f"too many non-finite losses ({nonfinite}) — diverging, aborting"
            continue
        loss.backward()
        if step % ACCUM == 0:
            gn = torch.nn.utils.clip_grad_norm_(student.parameters(), 1.0)
            if torch.isfinite(gn):                                       # NS-4: an inf grad-norm must not poison AdamW moments
                opt.step(); last_gnorm = float(gn)
            else:
                print(f"WARNING step {step}: non-finite grad-norm — opt.step skipped", flush=True)
            opt.zero_grad(set_to_none=True)
        if step % 100 == 0:
            tps = 100 * RAFT.MAX_LEN / (time.time() - t0); t0 = time.time()
            print(f"step {step:6d}/{STEPS} | lr={lr_t:.2e} KD={float(kd):.3f} CE={float(ce) if ce is not None else 0:.3f} "
                  f"| gnorm={last_gnorm:.2f} | ~{tps:.0f} tok/s", flush=True)
        if step % CKPT_EVERY == 0:
            save_ckpt(student, opt, step, ckpt, sched)
        if step % EVAL_EVERY == 0:
            ev = evaluate()
            e1 = ev["E1"][0]; slope_e2 = ev["E2"][0] - e1; slope_e3 = ev["E3"][0] - e1
            score = select_score(e1, slope_e2, slope_e3)             # BCS-1: low E1 + distractor-robust + REWARD context-use
            if score > best_score and all(math.isfinite(ev[m][0]) for m in ev):
                best_score = score
                save_ckpt(student, opt, step, best_path, sched)       # best-ckpt selection (metric-gated, NOT just last)
                json.dump({"best_score": best_score, "step": step, "E1_nll": e1, "E2_nll": ev["E2"][0], "E3_nll": ev["E3"][0],
                           "slope_e2_e1": slope_e2, "slope_e3_e1": slope_e3,
                           "E1_acc": ev["E1"][1], "E2_acc": ev["E2"][1], "E3_acc": ev["E3"][1]},
                          open(best_meta + ".tmp", "w"))             # BCS-2: full eval breakdown for auditability
                os.replace(best_meta + ".tmp", best_meta)             # persist best_score so a resume can't regress ckpt_best
            print("  EVAL " + " ".join(f"{m}: nll={ev[m][0]:.3f} acc={ev[m][1]:.1%}" for m in ev)
                  + f"  | Δ(E2-E1)={slope_e2:+.3f} Δ(E3-E1)={slope_e3:+.3f} | best_score={best_score:.3f}"
                  + ("  ↑best" if score == best_score else ""), flush=True)
    save_ckpt(student, opt, STEPS, ckpt, sched)
    print(f"DONE — final ckpt {ckpt}")

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
        dp = decode_parity(student, E["E1"])                         # DEVICE-TRUTH: fp16 sequential-vs-parallel parity
        res = {"perplexity": ppl, "raft": raft, "fidelity": fid, "generation": gen,
               "quant": EVAL.quant_fidelity_stub(), "contamination_ok": contamination_ok,
               "teacher_E1_nll": t_e1, "decode_parity": dp, "best_score": best_score, "eval_on": eval_on}
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
    else:
        print(f"EVAL CARD → {_c['status']}  (eval crashed: {res.get('eval_error')}; ckpt is saved, re-run eval offline)", flush=True)


if __name__ == "__main__":
    main()
