"""NS-8 lock: the chunked scan must stay precise under autocast-bf16 (carry/exp/cumsum stay fp32 by autocast policy; only
matmul is bf16). Catches a future refactor that casts la/u to bf16 and re-introduces the ~17% pure-bf16 blow-up (which is
why mamba3_cloud_distill autocasts on cuda even for FP32_MASTER=0, NS-8.2). CPU autocast = same op-policy as cuda, no GPU."""
from __future__ import annotations

import pytest
import torch

import mamba3_trainable as MT


def _inp(T=1024, scale=0.1):
    torch.manual_seed(0)
    la = -torch.rand(T, MT.H, dtype=torch.float64) * scale            # log_alpha <= 0
    u = torch.randn(T, MT.H, MT.P, MT.N, dtype=torch.float64) * 0.1
    return la, u


@pytest.mark.parametrize("scale,name", [(0.01, "benign"), (0.1, "moderate"), (1.0, "aggressive")])
def test_scan_chunked_autocast_rel_err_small(scale, name):
    la, u = _inp(1024, scale)
    ref = MT.scan_chunked(la.float(), u.float())                      # fp32 reference
    with torch.autocast("cpu", dtype=torch.bfloat16):
        got = MT.scan_chunked(la.float(), u.float())                 # autocast: matmul bf16, carry/exp fp32
    rel = ((got.float() - ref).abs().max() / ref.abs().max().clamp_min(1e-6)).item()
    assert rel < 2e-2, f"{name}: autocast scan rel-err {rel:.3e} >= 2e-2 — a bf16 carry/exp leak?"


def test_scan_chunked_equals_scan_parallel():
    la, u = _inp(200, 0.3)                                            # the two scan impls must agree (chunked == parallel)
    assert (MT.scan_chunked(la, u) - MT.scan_parallel(la, u)).abs().max().item() < 1e-9


def test_forward_seq_autocast_argmax_match():
    torch.manual_seed(0)
    m = MT.M(64, 2).eval()                                            # fp32 model
    toks = torch.randint(0, 64, (256,))
    ref = m.run_twin(toks)[0]
    with torch.autocast("cpu", dtype=torch.bfloat16):
        got = m.run_twin(toks)[0]
    agree = (ref.argmax(-1) == got.float().argmax(-1)).float().mean().item()
    assert agree >= 0.95, f"autocast forward argmax agreement {agree:.3f} < 0.95"


def test_decay_finite_over_long_T():
    la = -torch.rand(1024, MT.H) * 2.0                               # aggressive decay
    cl = torch.cumsum(la.view(16, 64, MT.H), dim=1)
    ds = torch.exp(cl)                                               # decay_start; la<=0 ⇒ finite and <=1
    assert torch.isfinite(ds).all() and (ds <= 1.0 + 1e-6).all()
