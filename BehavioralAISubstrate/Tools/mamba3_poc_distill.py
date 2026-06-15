"""PoC distillation: full L=16 Mamba-3 student <- Granite-4.1-3b (dense) on a REAL corpus, locally on MPS.

Scales the proven smoke (mamba3_distill.py) into a real (short) training run: Stage-3 logit-KD on wikitext-2
sequences, with a HELD-OUT teacher-agreement eval — held-out agreement rising over training proves the student
learns a real LM from Granite (generalizes), not memorizes one batch. Saves a student checkpoint.

This is the PoC harness; a full PoC run is just more steps (days local at ~444 tok/s, or cloud). Env:
  POC_STEPS (default 300)  POC_T (256)  POC_LAYERS (16)  POC_LR (3e-4)  POC_EVAL_EVERY (50)
Run: ~/.venvs/coreai-cv/bin/python Tools/mamba3_poc_distill.py
"""
from __future__ import annotations

import os
import sys
import time

import torch
import torch.nn.functional as F

sys.path.insert(0, "/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tools")
import mamba3_trainable as MT

TEACHER = "ibm-granite/granite-4.1-3b-base"
DEV = "mps" if torch.backends.mps.is_available() else "cpu"
TAU = 2.0
STEPS = int(os.environ.get("POC_STEPS", "300"))
T = int(os.environ.get("POC_T", "256"))
LAYERS = int(os.environ.get("POC_LAYERS", "16"))
LR = float(os.environ.get("POC_LR", "2e-4"))
WARMUP = int(os.environ.get("POC_WARMUP", "50"))
EVAL_EVERY = int(os.environ.get("POC_EVAL_EVERY", "50"))
CKPT = "/tmp/draft_coreai/mamba3_poc_student.pt"


def load_chunks(tok, n_needed: int) -> list[torch.Tensor]:
    from datasets import load_dataset
    ds = load_dataset("Salesforce/wikitext", "wikitext-2-raw-v1", split="train")
    buf: list[int] = []
    chunks: list[torch.Tensor] = []
    for row in ds:
        t = row["text"].strip()
        if not t:
            continue
        buf.extend(tok(t).input_ids)
        while len(buf) >= T:
            chunks.append(torch.tensor(buf[:T], dtype=torch.long))
            buf = buf[T:]
        if len(chunks) >= n_needed:
            break
    return chunks


def main() -> None:
    from transformers import AutoModelForCausalLM, AutoTokenizer

    torch.manual_seed(0)
    tok = AutoTokenizer.from_pretrained(TEACHER)
    teacher = AutoModelForCausalLM.from_pretrained(TEACHER, dtype=torch.float16).to(DEV).eval()
    for p in teacher.parameters():
        p.requires_grad_(False)
    vocab = teacher.config.vocab_size

    chunks = load_chunks(tok, STEPS + 16)
    train, heldout = chunks[:-8], chunks[-8:]
    print(f"corpus: {len(train)} train + {len(heldout)} held-out seqs @ T={T} | teacher vocab={vocab}")

    student = MT.M(vocab, layers=LAYERS).to(DEV)
    sp = sum(p.numel() for p in student.parameters()) / 1e6
    opt = torch.optim.AdamW(student.parameters(), lr=LR, weight_decay=0.1)
    print(f"student: {sp:.0f}M (L={LAYERS}, D={MT.D_MODEL}), lr={LR} warmup={WARMUP} wd=0.1, steps={STEPS}")

    @torch.no_grad()
    def eval_agree() -> float:
        student.eval()
        hits = tot = 0
        for ids in heldout:
            ids = ids.to(DEV)
            ta = teacher(ids.unsqueeze(0)).logits[0].argmax(-1)
            sa = student.run_twin(ids, collect_ssm=False)[0].argmax(-1)
            hits += int((sa == ta).sum()); tot += ids.shape[0]
        student.train()
        return hits / tot

    print(f"step   0 | held-out teacher-agreement: {eval_agree():.1%}")
    t0 = time.time()
    run_kd = 0.0
    for step in range(1, STEPS + 1):
        for g in opt.param_groups:                                    # linear lr warmup (stability)
            g["lr"] = LR * min(1.0, step / WARMUP)
        ids = train[(step - 1) % len(train)].to(DEV)
        with torch.no_grad():
            tlog = teacher(ids.unsqueeze(0)).logits[0].float()
        tsoft = F.log_softmax(tlog / TAU, dim=-1)
        opt.zero_grad(set_to_none=True)
        slog, _ = student.run_twin(ids, collect_ssm=False)
        kd = F.kl_div(F.log_softmax(slog / TAU, dim=-1), tsoft, log_target=True, reduction="batchmean") * (TAU * TAU)
        ce = F.cross_entropy(slog[:-1], ids[1:])
        (kd + 0.1 * ce).backward()
        torch.nn.utils.clip_grad_norm_(student.parameters(), 1.0)
        opt.step()
        run_kd += float(kd)
        if step % EVAL_EVERY == 0:
            tps = step * T / (time.time() - t0)
            print(f"step {step:4d} | KD(avg)={run_kd/EVAL_EVERY:.3f} | held-out agree={eval_agree():.1%} | {tps:.0f} tok/s")
            run_kd = 0.0

    os.makedirs(os.path.dirname(CKPT), exist_ok=True)
    torch.save({"model": student.state_dict(), "vocab": vocab, "layers": LAYERS}, CKPT)
    print(f"=== POC DISTILL DONE === checkpoint -> {CKPT}")


if __name__ == "__main__":
    main()
