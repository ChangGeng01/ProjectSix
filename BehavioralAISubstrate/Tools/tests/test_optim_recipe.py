"""Pin the Track-G addendum-45 optimization recipe: LR decay schedule, no-decay param split, context-use best-ckpt
score, answer-weighted KD, fp32-CE. Locks the audited-and-verified optimizations so a regression can't silently revert
them before the paid cloud run. CPU-only, no Granite."""
from __future__ import annotations

import math

import pytest
import torch

import mamba3_cloud_distill as CD
import mamba3_hybrid as HY
import mamba3_raft as RAFT


# ----------------------------------------------------------------- LR-1: schedule shape
def _set_sched(monkeypatch, lr=3e-4, warmup=100, steps=1000, decay="cosine", floor=0.07):
    monkeypatch.setattr(CD, "LR", lr); monkeypatch.setattr(CD, "WARMUP", warmup)
    monkeypatch.setattr(CD, "STEPS", steps); monkeypatch.setattr(CD, "DECAY", decay)
    monkeypatch.setattr(CD, "LR_MIN_FRAC", floor)


def test_lr_warmup_ramps_linearly_to_peak(monkeypatch):
    _set_sched(monkeypatch)
    assert CD.lr_at(0) == pytest.approx(0.0, abs=1e-12)
    assert CD.lr_at(50) == pytest.approx(3e-4 * 0.5, rel=1e-6)
    assert CD.lr_at(100) == pytest.approx(3e-4, rel=1e-6)        # peak at WARMUP


def test_lr_cosine_decays_to_floor(monkeypatch):
    _set_sched(monkeypatch, decay="cosine", floor=0.07)
    assert CD.lr_at(1000) == pytest.approx(3e-4 * 0.07, rel=1e-6)   # floor at STEPS
    mid = CD.lr_at(550)                                              # halfway after warmup ≈ midpoint of cosine
    assert 3e-4 * 0.07 < mid < 3e-4


def test_lr_monotone_non_increasing_after_warmup(monkeypatch):
    _set_sched(monkeypatch, decay="cosine")
    vals = [CD.lr_at(s) for s in range(100, 1001, 25)]
    assert all(b <= a + 1e-12 for a, b in zip(vals, vals[1:]))
    assert vals[0] > vals[-1]


def test_lr_linear_and_none(monkeypatch):
    _set_sched(monkeypatch, decay="linear", floor=0.1)
    assert CD.lr_at(1000) == pytest.approx(3e-4 * 0.1, rel=1e-6)
    assert CD.lr_at(550) == pytest.approx(3e-4 * (1 - 0.9 * 450 / 900), rel=1e-6)
    _set_sched(monkeypatch, decay="none")
    assert CD.lr_at(1000) == pytest.approx(3e-4, rel=1e-6)       # legacy flat-after-warmup


# ----------------------------------------------------------------- LR-2: no-decay param split
def test_split_decay_params_protects_1d_and_embedding(tiny_hybrid):
    decay, no_decay = CD.split_decay_params(tiny_hybrid)
    nd = set(id(p) for p in no_decay)
    named = dict(tiny_hybrid.named_parameters())
    # every 1-D param + the tied embedding + fw must be in no_decay; every ≥2-D weight in decay
    for n, p in named.items():
        if p.ndim <= 1 or n.endswith("embedding.weight") or n == "fw":
            assert id(p) in nd, f"{n} (ndim={p.ndim}) must be no-decay"
        else:
            assert id(p) not in nd, f"{n} (ndim={p.ndim}) must be weight-decayed"
    # dt_bias / norm gains specifically protected (architecture-load-bearing)
    for n, p in named.items():
        if any(k in n for k in ("dt_bias", "norm", ".D", "bn_w", "gnorm")):
            assert id(p) in nd, f"{n} must be no-decay"
    assert len(decay) + len(no_decay) == sum(1 for _ in tiny_hybrid.parameters())
    assert len(decay) > 0 and len(no_decay) > 0


def test_split_decay_optimizer_constructs_and_steps(tiny_hybrid):
    decay, no_decay = CD.split_decay_params(tiny_hybrid)
    opt = torch.optim.AdamW([{"params": decay, "weight_decay": 0.1},
                             {"params": no_decay, "weight_decay": 0.0}], lr=1e-3, betas=(0.9, 0.95))
    assert len(opt.param_groups) == 2
    assert opt.param_groups[0]["weight_decay"] == 0.1 and opt.param_groups[1]["weight_decay"] == 0.0
    toks = torch.randint(0, 96, (12,))
    loss = tiny_hybrid.run_twin(toks)[0].float().pow(2).mean()
    loss.backward(); opt.step()                                  # no crash, both groups update


# ----------------------------------------------------------------- BCS-1: context-use best-ckpt score
def test_select_score_rewards_reading_over_parrot():
    # two checkpoints with the SAME E1 nll and E2 robustness; the reader (positive E3 slope) must outscore the parrot (E3≈E1).
    reader = CD.select_score(e1=2.0, slope_e2=0.02, slope_e3=0.40, ctx_w=0.5)
    parrot = CD.select_score(e1=2.0, slope_e2=0.02, slope_e3=0.00, ctx_w=0.5)
    assert reader > parrot
    assert reader == pytest.approx(-(2.0 + 0.02) + 0.5 * 0.40, rel=1e-9)


def test_select_score_penalizes_e1_and_e2_slope():
    assert CD.select_score(2.0, 0.0, 0.0, 0.5) > CD.select_score(3.0, 0.0, 0.0, 0.5)   # lower E1 better
    assert CD.select_score(2.0, 0.0, 0.0, 0.5) > CD.select_score(2.0, 0.5, 0.0, 0.5)   # distractor-robust better


def test_select_score_caps_e3_reward():
    # a huge E3 nll (broken-on-E3) can't dominate — reward capped at 1.0 nat
    assert CD.select_score(2.0, 0.0, 5.0, 0.5) == pytest.approx(CD.select_score(2.0, 0.0, 1.0, 0.5), rel=1e-9)


# ----------------------------------------------------------------- KD-1: answer-weighted kd_topk
def _kd_inputs(T=10, V=96, K=8):
    torch.manual_seed(1)
    sl = torch.randn(T, V, requires_grad=True)
    tl = torch.randn(T, V)
    val, idx = tl.topk(K, dim=-1)
    return sl, idx, val


def test_kd_topk_uniform_weight_equals_legacy_mean():
    sl, idx, val = _kd_inputs()
    base = CD.kd_topk(sl, idx, val)                              # pos_w=None (legacy uniform mean)
    ones = CD.kd_topk(sl, idx, val, pos_w=torch.ones(sl.shape[0]))
    assert float(base) == pytest.approx(float(ones), rel=1e-5)


def test_kd_topk_answer_weight_shifts_value_and_flows_grad():
    sl, idx, val = _kd_inputs()
    plen = 6
    ans = (torch.arange(sl.shape[0]) >= (plen - 1)).float()
    pw = 1.0 + (2.0 - 1.0) * ans                                 # KD_ANSWER_W=2.0 up-weights the answer span
    kd = CD.kd_topk(sl, idx, val, pos_w=pw)
    assert torch.isfinite(kd) and float(kd) >= 0.0
    kd.backward()
    assert sl.grad is not None and torch.isfinite(sl.grad).all()


def test_kd_topk_seq_mismatch_still_asserts():
    sl, idx, val = _kd_inputs(T=10)
    with pytest.raises(AssertionError):
        CD.kd_topk(sl, idx[:8], val[:8])                         # T mismatch guard intact


# ----------------------------------------------------------------- NS-2: fp32 CE is value-correct
def test_masked_ce_fp32_matches_and_masks(monkeypatch):
    monkeypatch.setattr(RAFT, "DEV", "cpu")
    ids = torch.tensor([1, 2, 3, 4, 5, 6])
    logits = torch.randn(6, 96)
    out = RAFT.masked_ce(logits, ids, prompt_len=4)
    assert out is not None and torch.isfinite(out)
    # equals manual fp32 CE over the answer span (targets at t>=prompt_len-1)
    m = torch.arange(5) >= 3
    ref = torch.nn.functional.cross_entropy(logits[:-1][m].float(), ids[1:][m], reduction="mean")
    assert float(out) == pytest.approx(float(ref), rel=1e-6)
    assert RAFT.masked_ce(logits, ids, prompt_len=6) is None     # no answer token → None
