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


def kd_kl(student_logits, teacher_logits):
    """Full-vocab Stage-3 KD: KL(teacher || student) at temperature TAU, scaled by TAU^2 (Hinton)."""
    s = F.log_softmax(student_logits.float() / TAU, -1)
    t = F.log_softmax(teacher_logits.float() / TAU, -1)
    return F.kl_div(s, t, log_target=True, reduction="batchmean") * (TAU * TAU)


def kd_topk(student_logits, topk_idx, topk_val):
    """Top-K KD from a CACHED teacher: student full-vocab log-softmax gathered at the teacher's top-K indices, vs the
    teacher's top-K soft target (renormalized within the K). Standard cached-distillation approximation."""
    lp = F.log_softmax(student_logits.float() / TAU, -1).gather(-1, topk_idx.long())   # [T,K] student logprob @ teacher topk
    q = F.softmax(topk_val.float() / TAU, -1)                                          # [T,K] teacher soft target
    return (q * (q.clamp_min(1e-9).log() - lp)).sum(-1).mean() * (TAU * TAU)


def build_cache(teacher, train, cache_dir):
    """Phase 1 (run ONCE): frozen-teacher forward over every train example → cache top-K logits + per-example
    DIFFICULTY (teacher CE on the answer tokens, for curriculum ordering). Resumable (skips existing .pt). After this,
    training needs NO teacher forward — the dominant cost is amortized across all epochs."""
    os.makedirs(cache_dir, exist_ok=True)
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
        torch.save(rec, path); ex.update(rec)
        if i % 200 == 0:
            print(f"  cache {i}/{len(train)} (diff={diff:.2f})", flush=True)


def save_ckpt(student, opt, step, path):
    tmp = path + ".tmp"
    torch.save({"model": student.state_dict(), "opt": opt.state_dict(), "step": step,
                "layers": LAYERS, "config": (MT.D_MODEL, MT.H, MT.P, MT.N, MT.R)}, tmp)
    os.replace(tmp, path)                                               # atomic — survives a mid-write preemption


def main() -> None:
    from datasets import load_dataset
    from transformers import AutoModelForCausalLM, AutoTokenizer
    import hashlib
    os.makedirs(CKPT_DIR, exist_ok=True)
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

    rows = load_dataset("hotpotqa/hotpot_qa", "distractor", split=f"validation[:{N_ROWS}]")
    ex_all = [build_example(r) for r in rows]
    def bucket(i):
        return int(hashlib.sha1(i.encode()).hexdigest(), 16) % 10
    held_rows = [e for e in ex_all if bucket(e["id"]) < 1][:200]          # ~10% held, capped
    train_rows = [e for e in ex_all if bucket(e["id"]) >= 1]
    train = make_examples(train_rows, RAFT.P_GOLDEN, RAFT.K_DISTRACT, tok, seed=0)
    E = {m: make_eval_condition(held_rows, m, tok) for m in ("E1", "E2", "E3")}
    print(f"data | HotpotQA distractor | train={len(train)} held={len(held_rows)} | "
          f"P={RAFT.P_GOLDEN} K={RAFT.K_DISTRACT} T={RAFT.MAX_LEN} CoT={RAFT.COT} | vocab={vocab}")
    if CACHE:
        print(f"caching teacher top-{KD_K} over {len(train)} examples (once; resumable)…", flush=True)
        build_cache(teacher, train, os.path.join(CKPT_DIR, "cache"))
        if ORDER == "curriculum":
            train.sort(key=lambda e: e["difficulty"])                    # easy (low teacher-CE) -> hard
        ds = [e["difficulty"] for e in train]
        print(f"cache done | order={ORDER} | difficulty [{min(ds):.2f},{max(ds):.2f}] | teacher no longer needed for KD")

    torch.manual_seed(0)
    ARCH = os.environ.get("ARCH", "mamba")                            # "hybrid" = 20 Mamba-3 + 4 MLA @ L6/12/18/23 (the DUET reader)
    student = (HY.HybridM(vocab, LAYERS) if ARCH == "hybrid" else MT.M(vocab, LAYERS)).to(DEV).to(DT)
    print(f"student ARCH={ARCH} ({'HybridM 20-Mamba+4-MLA' if ARCH == 'hybrid' else 'pure Mamba-3'})")
    opt = torch.optim.AdamW(student.parameters(), lr=LR, weight_decay=0.1, betas=(0.9, 0.95))
    start = 1
    ckpt = os.path.join(CKPT_DIR, "ckpt_latest.pt")
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

    t0 = time.time()
    opt.zero_grad(set_to_none=True)
    for step in range(start, STEPS + 1):
        for g in opt.param_groups:
            g["lr"] = LR * min(1.0, step / WARMUP)
        ex = train[(step - 1) % len(train)]
        ids = ex["input_ids"].to(DEV)
        sl = student.run_twin(ids, collect_ssm=False)[0]
        if CACHE:                                                        # no teacher forward — cached top-K KD
            kd = kd_topk(sl, ex["topk_idx"].to(DEV), ex["topk_val"].to(DEV))
        else:
            with torch.no_grad():
                tl = teacher(ids.unsqueeze(0)).logits[0]
            kd = kd_kl(sl, tl)
        ce = masked_ce(sl, ids, ex["prompt_len"])
        loss = (KD_W * kd + (CE_W * ce if ce is not None else 0.0)) / ACCUM
        assert torch.isfinite(loss), f"step {step}: non-finite loss"
        loss.backward()
        if step % ACCUM == 0:
            torch.nn.utils.clip_grad_norm_(student.parameters(), 1.0)
            opt.step(); opt.zero_grad(set_to_none=True)
        if step % 100 == 0:
            tps = 100 * RAFT.MAX_LEN / (time.time() - t0); t0 = time.time()
            print(f"step {step:6d}/{STEPS} | KD={float(kd):.3f} CE={float(ce) if ce is not None else 0:.3f} "
                  f"| ~{tps:.0f} tok/s", flush=True)
        if step % CKPT_EVERY == 0:
            save_ckpt(student, opt, step, ckpt)
        if step % EVAL_EVERY == 0:
            ev = evaluate()
            print("  EVAL " + " ".join(f"{m}: nll={ev[m][0]:.3f} acc={ev[m][1]:.1%}" for m in ev)
                  + f"  | slope Δ(E2-E1)={ev['E2'][0]-ev['E1'][0]:+.3f}", flush=True)
    save_ckpt(student, opt, STEPS, ckpt)
    print(f"DONE — final ckpt {ckpt}")


if __name__ == "__main__":
    main()
