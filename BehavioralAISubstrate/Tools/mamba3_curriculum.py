"""Curriculum distillation harness (black-box-ready). Teacher scores each training sequence's DIFFICULTY
(= teacher perplexity), the data is ordered easy->hard, and the Mamba-3 student is KD-distilled in that order.
Validates the MECHANISM locally (curriculum vs random) with a tractable teacher; the production config plugs in
the big models (TEACHER=Granite-4.1-8B generates+scores, COACH=Qwen3.6-27B filters/curates) on cloud.

Why curriculum: a capacity-bound <1B student learns a 3B+ teacher's distribution more stably easy-first; random
order mixes hard high-perplexity sequences early that destabilize / waste the small student's gradient.

Env: TEACHER (default granite-4.1-3b-base, the local proxy), STEPS (240), T (256), ORDER (curriculum|random).
Run BOTH orders to compare: ORDER=curriculum then ORDER=random.
"""
from __future__ import annotations

import os
import sys

import torch
import torch.nn.functional as F

sys.path.insert(0, "/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tools")
import mamba3_trainable as MT
from mamba3_poc_distill import load_chunks

TEACHER = os.environ.get("TEACHER", "ibm-granite/granite-4.1-3b-base")   # prod: ibm-granite/granite-4.1-8b-base
DEV = "mps" if torch.backends.mps.is_available() else "cpu"
TAU = 2.0
STEPS = int(os.environ.get("STEPS", "240"))
T = int(os.environ.get("T", "256"))
ORDER = os.environ.get("ORDER", "curriculum")
LR, WARMUP = 2e-4, 50


def main() -> None:
    from transformers import AutoModelForCausalLM, AutoTokenizer
    torch.manual_seed(0)
    tok = AutoTokenizer.from_pretrained(TEACHER)
    teacher = AutoModelForCausalLM.from_pretrained(TEACHER, dtype=torch.float16).to(DEV).eval()
    for p in teacher.parameters():
        p.requires_grad_(False)
    vocab = teacher.config.vocab_size

    chunks = load_chunks(tok, STEPS + 16)
    train, held = chunks[:-8], chunks[-8:]

    # DIFFICULTY = teacher per-sequence perplexity (the coach refines this in prod). One forward per chunk.
    diff = []
    with torch.no_grad():
        for ids in train:
            ids = ids.to(DEV)
            lg = teacher(ids.unsqueeze(0)).logits[0].float()
            ce = F.cross_entropy(lg[:-1], ids[1:])
            diff.append(float(ce))
    order = sorted(range(len(train)), key=lambda i: diff[i])               # easy (low ppl) -> hard
    if ORDER == "random":
        g = torch.Generator().manual_seed(1); order = torch.randperm(len(train), generator=g).tolist()
    train = [train[i] for i in order]
    print(f"curriculum harness | teacher={TEACHER} | ORDER={ORDER} | difficulty CE "
          f"min={min(diff):.2f} max={max(diff):.2f} | {len(train)} train seqs")

    student = MT.M(vocab, 16).to(DEV)
    opt = torch.optim.AdamW(student.parameters(), lr=LR, weight_decay=0.1)

    @torch.no_grad()
    def agree() -> float:
        student.eval(); h = t = 0
        for ids in held:
            ids = ids.to(DEV)
            ta = teacher(ids.unsqueeze(0)).logits[0].argmax(-1)
            sa = student.run_twin(ids, collect_ssm=False)[0].argmax(-1)
            h += int((sa == ta).sum()); t += ids.shape[0]
        student.train(); return h / t

    print(f"step   0 | agree={agree():.1%}")
    for step in range(1, STEPS + 1):
        for gp in opt.param_groups:
            gp["lr"] = LR * min(1.0, step / WARMUP)
        ids = train[(step - 1) % len(train)].to(DEV)
        with torch.no_grad():
            tlog = teacher(ids.unsqueeze(0)).logits[0].float()
        opt.zero_grad(set_to_none=True)
        slog, _ = student.run_twin(ids, collect_ssm=False)
        kd = F.kl_div(F.log_softmax(slog / TAU, -1), F.log_softmax(tlog / TAU, -1), log_target=True,
                      reduction="batchmean") * (TAU * TAU)
        ce = F.cross_entropy(slog[:-1], ids[1:])
        (kd + 0.1 * ce).backward()
        torch.nn.utils.clip_grad_norm_(student.parameters(), 1.0)
        opt.step()
        if step % 60 == 0:
            print(f"step {step:4d} | KD={float(kd):.3f} | agree={agree():.1%}")
    print(f"=== CURRICULUM ({ORDER}) DONE — final agree={agree():.1%} ===")


if __name__ == "__main__":
    main()
