"""Full white-box MOHAWK distillation: Granite-4.1-3b -> Mamba-3, Stage-2 (hidden-state alignment) + Stage-3
(logit-KD), jointly, on the M5 Max. The bigger transfer lever than logit-KD alone: the student's per-layer
hidden states are aligned to Granite's (projected up to the teacher dim, RMS-normalized so it matches direction
not scale). Validates that adding Stage-2 trains stably and lifts held-out teacher-agreement over Stage-3-only.

Stage-1 (attention-matrix orientation) is the remaining piece; this is Stage-2+3 (the dominant quality stages).
Env: STEPS (300)  L2W (1.0, the Stage-2 weight)  T (256). Run: ~/.venvs/coreai-cv/bin/python Tools/mamba3_mohawk.py
"""
from __future__ import annotations

import os
import sys

import torch
import torch.nn as nn
import torch.nn.functional as F

sys.path.insert(0, "/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tools")
import mamba3_trainable as MT
from mamba3_poc_distill import load_chunks

TEACHER = "ibm-granite/granite-4.1-3b-base"
DEV = "mps" if torch.backends.mps.is_available() else "cpu"
TAU = 2.0
STEPS = int(os.environ.get("STEPS", "300"))
T = int(os.environ.get("T", "256"))
LAYERS = 16
LR, WARMUP = 2e-4, 50
L2W = float(os.environ.get("L2W", "1.0"))


def rmsn(x: torch.Tensor) -> torch.Tensor:
    return x * torch.rsqrt(x.pow(2).mean(-1, keepdim=True) + 1e-5)


def main() -> None:
    from transformers import AutoModelForCausalLM, AutoTokenizer

    torch.manual_seed(0)
    tok = AutoTokenizer.from_pretrained(TEACHER)
    teacher = AutoModelForCausalLM.from_pretrained(TEACHER, dtype=torch.float16).to(DEV).eval()
    for p in teacher.parameters():
        p.requires_grad_(False)
    vocab, gL, gD = teacher.config.vocab_size, teacher.config.num_hidden_layers, teacher.config.hidden_size

    chunks = load_chunks(tok, STEPS + 16)
    train, held = chunks[:-8], chunks[-8:]
    student = MT.M(vocab, LAYERS).to(DEV)
    gmap = [round((i + 1) * gL / LAYERS) for i in range(LAYERS)]          # student layer i -> teacher hidden idx
    proj = nn.ModuleList([nn.Linear(MT.D_MODEL, gD, bias=False) for _ in range(LAYERS)]).to(DEV)   # training-only
    for m in proj:
        nn.init.normal_(m.weight, std=0.02)
    opt = torch.optim.AdamW(list(student.parameters()) + list(proj.parameters()), lr=LR, weight_decay=0.1)
    print(f"MOHAWK S2+S3: student L{LAYERS}/D{MT.D_MODEL} <- Granite L{gL}/D{gD} | gmap={gmap} | L2W={L2W}")

    @torch.no_grad()
    def agree() -> float:
        student.eval(); h = t = 0
        for ids in held:
            ids = ids.to(DEV)
            ta = teacher(ids.unsqueeze(0)).logits[0].argmax(-1)
            sa = student.run_twin(ids, collect_ssm=False)[0].argmax(-1)
            h += int((sa == ta).sum()); t += ids.shape[0]
        student.train(); return h / t

    print(f"step   0 | held-out agree={agree():.1%}")
    for step in range(1, STEPS + 1):
        for g in opt.param_groups:
            g["lr"] = LR * min(1.0, step / WARMUP)
        ids = train[(step - 1) % len(train)].to(DEV)
        with torch.no_grad():
            to = teacher(ids.unsqueeze(0), output_hidden_states=True)
            tlog = to.logits[0].float()
            thid = [h[0].float() for h in to.hidden_states]              # (gL+1) x [T, gD]
        opt.zero_grad(set_to_none=True)
        slog, shid = student.run_twin(ids, collect_ssm=False, return_hiddens=True)
        kd = F.kl_div(F.log_softmax(slog / TAU, -1), F.log_softmax(tlog / TAU, -1), log_target=True,
                      reduction="batchmean") * (TAU * TAU)
        ce = F.cross_entropy(slog[:-1], ids[1:])
        s2 = sum(F.mse_loss(rmsn(proj[i](shid[i])), rmsn(thid[gmap[i]])) for i in range(LAYERS)) / LAYERS
        (kd + 0.1 * ce + L2W * s2).backward()
        torch.nn.utils.clip_grad_norm_(list(student.parameters()) + list(proj.parameters()), 1.0)
        opt.step()
        if step % 50 == 0:
            print(f"step {step:4d} | KD={float(kd):.3f} S2={float(s2):.4f} CE={float(ce):.3f} agree={agree():.1%}")
    print("=== MOHAWK S2+S3 DONE ===")


if __name__ == "__main__":
    main()
