"""Diagnose the L=16 training NaN: instrument the student (CE on corpus, NO teacher needed — the NaN is in the
student's own fwd/bwd) to find WHICH layer and WHICH tensor (residual x vs SSM state vs dt/alpha) blows up first
and at what step. Stop guessing; measure."""
from __future__ import annotations

import sys

import torch
import torch.nn.functional as F

sys.path.insert(0, "/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tools")
import mamba3_trainable as MT
from mamba3_poc_distill import load_chunks

DEV = "mps" if torch.backends.mps.is_available() else "cpu"


def main() -> None:
    from transformers import AutoTokenizer
    torch.manual_seed(0)
    tok = AutoTokenizer.from_pretrained("ibm-granite/granite-4.1-3b-base")
    chunks = load_chunks(tok, 150)
    student = MT.M(100352, layers=16).to(DEV)
    LR, WARMUP, WD, CLIP = 2e-4, 50, 0.1, 1.0
    opt = torch.optim.AdamW(student.parameters(), lr=LR, weight_decay=WD)
    print(f"L=16 student, {len(chunks)} seqs @ T={chunks[0].shape[0]} | lr={LR} warmup={WARMUP} wd={WD} clip={CLIP}")

    for step in range(1, 200):
        for g in opt.param_groups:                                       # linear lr warmup
            g["lr"] = LR * min(1.0, step / WARMUP)
        ids = chunks[(step - 1) % len(chunks)].to(DEV)
        opt.zero_grad(set_to_none=True)
        # manual layer loop with per-layer instrumentation
        x = student.embedding.weight[ids]                                # [T,D]
        xmax, ssmmax = [], []
        for lyr in student.layers:
            x, ssm_seq, _ = lyr.forward_seq(x)
            xmax.append(float(x.abs().max())); ssmmax.append(float(ssm_seq.abs().max()))
        logits = student.head(x)
        loss = F.cross_entropy(logits[:-1], ids[1:])
        loss.backward()
        gn = float(torch.nn.utils.clip_grad_norm_(student.parameters(), 1.0))
        opt.step()
        bad = (not torch.isfinite(loss)) or max(xmax) > 1e4 or max(ssmmax) > 1e4
        if step % 5 == 0 or bad:
            # which layer has the biggest x / ssm
            lx = max(range(16), key=lambda i: xmax[i]); ls = max(range(16), key=lambda i: ssmmax[i])
            print(f"step {step:3d}: loss={float(loss):8.3f} gn={gn:7.1f} | x_max={max(xmax):.2e}@L{lx} "
                  f"ssm_max={max(ssmmax):.2e}@L{ls}")
        if bad:
            print(f">>> BLOWUP at step {step}: per-layer x_max={[f'{v:.1e}' for v in xmax]}")
            print(f">>>                       per-layer ssm_max={[f'{v:.1e}' for v in ssmmax]}")
            break


if __name__ == "__main__":
    main()
