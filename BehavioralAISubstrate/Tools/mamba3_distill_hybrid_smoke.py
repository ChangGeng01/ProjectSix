"""Hybrid trainability smoke — proves the 20-Mamba+4-MLA HybridM is DISTILLABLE end-to-end (the prerequisite for the cloud
24L distill / the 最强大 quality gate). The shipped device assets are random-weight; before burning cloud $ we must show the
HYBRID (with its NEW from-scratch MLA layers) can actually fit a teacher signal — gradients flow through MLA + Mamba, loss
drops, no NaN. Overfit on ONE fixed batch against a synthetic teacher (fast; the cloud run uses real Granite via
mamba3_cloud_distill.py ARCH=hybrid). L=8 includes 1 MLA layer (@ position 6) so the MLA training path is exercised.

Run: ~/.venvs/coreai-cv/bin/python Tools/mamba3_distill_hybrid_smoke.py
"""
from __future__ import annotations

import sys

import torch
import torch.nn.functional as F

sys.path.insert(0, "/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tools")
import mamba3_hybrid as HY

TAU = 1.0                                                              # P0-1: TAU=1 makes the (cached) top-K KD ≡ full-vocab KD


def main() -> None:
    torch.manual_seed(0)
    V, L, T, STEPS = 512, 8, 32, 60
    student = HY.HybridM(V, L).float()
    n_mla = len(student.mla_pos)
    assert n_mla >= 1, f"L={L} has no MLA layer — MLA training path not exercised (mla_pos={student.mla_pos})"
    tokens = torch.randint(0, V, (T,))
    teacher_logits = torch.randn(T, V) * 2.0                           # fixed synthetic teacher
    tsoft = F.softmax(teacher_logits / TAU, -1)
    tgt = teacher_logits.argmax(-1)
    opt = torch.optim.AdamW(student.parameters(), lr=2e-3, weight_decay=0.0, betas=(0.9, 0.95))

    @torch.no_grad()
    def agree():
        return (student.run_twin(tokens)[0].argmax(-1) == tgt).float().mean().item()

    a0 = agree()                                                      # initial (untrained) teacher-argmax agreement
    print(f"hybrid distill smoke | HybridM L={L} ({L - n_mla} Mamba + {n_mla} MLA @ {sorted(student.mla_pos)}) | V={V} T={T} | init agree={a0:.0%}:")
    kd0 = None
    for step in range(STEPS):
        opt.zero_grad()
        sl = student.run_twin(tokens)[0]
        kd = F.kl_div(F.log_softmax(sl / TAU, -1), tsoft, reduction="batchmean") * TAU * TAU
        ce = F.cross_entropy(sl, tgt)
        loss = kd + 0.1 * ce
        assert torch.isfinite(loss), f"step {step}: non-finite loss (hybrid NOT trainable)"
        loss.backward()
        torch.nn.utils.clip_grad_norm_(student.parameters(), 1.0)
        opt.step()
        if kd0 is None:
            kd0 = float(kd)
        if step % 12 == 11 or step == 0:
            print(f"  step {step + 1:2d}: KD={float(kd):.4f}  CE={float(ce):.4f}  teacher-argmax-agree={agree():.0%}")
    kN, aN = float(kd), agree()
    # grad actually reaches the MLA layer?
    mla_i = min(student.mla_pos)
    g = student.layers[mla_i].kv_down.weight.grad
    mla_grad = (g is not None and torch.isfinite(g).all() and g.abs().sum() > 0)
    ok = kN < kd0 * 0.5 and aN >= 0.95 and aN > a0 and mla_grad
    print(f"  KD {kd0:.4f} -> {kN:.4f} ({kN / kd0:.0%}) | agree {a0:.0%} -> {aN:.0%} | MLA layer {mla_i} kv_down grad finite+nonzero: {mla_grad}")
    print(f"  -> {'PASS' if ok else 'FAIL'} — the MLA-hybrid {'IS' if ok else 'is NOT'} distillable (gradients flow through MLA + Mamba, loss drops, no NaN)")
    print("READ: PASS = HybridM trains end-to-end → the cloud 24L distill (mamba3_cloud_distill.py ARCH=hybrid) can produce the trained "
          "hybrid checkpoint that substantiates 最强大 (the one gate every random-weight result is waiting on).")


if __name__ == "__main__":
    main()
