"""P0-1 (battery's #1 blast-radius): does the teacher top-K cache train the SAME objective as full-vocab KD?

At TAU=2 over a 100k vocab the tempered softmax flattens → top-K may miss most mass → kd_topk trains a different
objective. Initial run FAILED (top-64 captured 0.32, grad-cosine 0.91, loss-ratio 2.23). This sweeps TAU × K × method
(top-K vs top-K+TAIL-bucket) on real Granite to find the config that recovers full KD. Pass: grad-cosine >= 0.98 AND
loss-ratio in [0.9,1.1].
"""
from __future__ import annotations

import os
import statistics as st
import sys

import torch
import torch.nn.functional as F

sys.path.insert(0, "/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tools")
import mamba3_raft as RAFT
import mamba3_trainable as MT
from mamba3_raft import build_example, make_examples

TEACHER = "ibm-granite/granite-4.1-3b-base"
DEV = "mps" if torch.backends.mps.is_available() else "cpu"
RAFT.DEV = DEV
N_EX = int(os.environ.get("N_EX", "12"))


def full_kd(s, tl, tau):
    return F.kl_div(F.log_softmax(s / tau, -1), F.log_softmax(tl / tau, -1), log_target=True, reduction="batchmean") * tau * tau


def topk_kd(s, tl, k, tau):                                            # KL over teacher's top-K renormalized
    val, idx = tl.topk(k, -1)
    q = F.softmax(val / tau, -1)
    lp = F.log_softmax(s / tau, -1).gather(-1, idx)
    return (q * (q.clamp_min(1e-9).log() - lp)).sum(-1).mean() * tau * tau


def topk_tail_kd(s, tl, k, tau):                                       # top-K + ONE lumped tail bucket (recovers full KL)
    val, idx = tl.topk(k, -1)
    q = F.softmax(tl / tau, -1)
    qt = q.gather(-1, idx)
    q_tail = (1 - qt.sum(-1, keepdim=True)).clamp_min(1e-9)
    sp = F.softmax(s / tau, -1)
    st_top = sp.gather(-1, idx)
    s_tail = (1 - st_top.sum(-1, keepdim=True)).clamp_min(1e-9)
    kl = (qt * (qt.clamp_min(1e-9).log() - st_top.clamp_min(1e-9).log())).sum(-1, keepdim=True) + q_tail * (q_tail.log() - s_tail.log())
    return kl.mean() * tau * tau


def main() -> None:
    from datasets import load_dataset
    from transformers import AutoModelForCausalLM, AutoTokenizer
    tok = AutoTokenizer.from_pretrained(TEACHER)
    vocab = tok.vocab_size
    teacher = AutoModelForCausalLM.from_pretrained(TEACHER, dtype=torch.bfloat16).to(DEV).eval()
    rows = [build_example(r) for r in load_dataset("hotpotqa/hotpot_qa", "distractor", split=f"validation[:{N_EX*3}]")]
    ex = make_examples(rows, RAFT.P_GOLDEN, RAFT.K_DISTRACT, tok, seed=0)[:N_EX]
    torch.manual_seed(0)
    student = MT.M(vocab, 8).to(DEV).float()
    cache = []
    for e in ex:
        ids = e["input_ids"].to(DEV)
        with torch.no_grad():
            tl = teacher(ids.unsqueeze(0)).logits[0].float()
        sl = student.run_twin(ids, collect_ssm=False)[0].detach()
        cache.append((tl, sl))

    print(f"P0-1 SWEEP — teacher KD cache vs full-vocab KD ({N_EX} real Granite RAFT ex, vocab={vocab}):")
    print(f"{'TAU':>4} {'K':>5} {'method':>10} | {'capt.mass':>9} {'grad-cos':>9} {'loss-ratio':>10} | verdict")
    cfgs = [(t, k, "topk") for t in (1.0, 1.5, 2.0) for k in (64, 256, 1024)] + [(t, 64, "topk+tail") for t in (1.0, 2.0)]
    for tau, k, method in cfgs:
        ms, cs, rs = [], [], []
        for tl, sl0 in cache:
            val, idx = tl.topk(k, -1)
            ms.append(F.softmax(tl / tau, -1).gather(-1, idx).sum(-1).median().item())
            s1 = sl0.clone().requires_grad_(True)
            gf = torch.autograd.grad(full_kd(s1, tl, tau), s1)[0]
            s2 = sl0.clone().requires_grad_(True)
            approx = topk_tail_kd(s2, tl, k, tau) if method == "topk+tail" else topk_kd(s2, tl, k, tau)
            gt = torch.autograd.grad(approx, s2)[0]
            cs.append(F.cosine_similarity(gf.flatten(), gt.flatten(), 0).item())
            rs.append(float(approx) / max(float(full_kd(s1.detach(), tl, tau)), 1e-9))
        mm, mc, mr = st.median(ms), st.median(cs), st.median(rs)
        ok = mc >= 0.98 and 0.9 <= mr <= 1.1
        print(f"{tau:>4} {k:>5} {method:>10} | {mm:9.3f} {mc:9.3f} {mr:10.2f} | {'PASS' if ok else 'fail'}")
    print("\nREAD: find the config that PASSES (grad-cos>=0.98, loss-ratio~1). Likely TAU=1 (peakier) or top-K+tail.")


if __name__ == "__main__":
    main()
