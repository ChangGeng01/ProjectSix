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


def test_lr_wsd_stable_then_decays(monkeypatch):
    """add.55: WSD = warmup → STABLE(flat@peak) → cosine decay over the last WSD_DECAY_FRAC of steps. Recovers the back-half a
    long cosine wastes (the 20k run ran ~48% of steps below half-peak while E1 nll was still falling)."""
    _set_sched(monkeypatch, decay="wsd", floor=0.05)
    monkeypatch.setattr(CD, "WSD_DECAY_FRAC", 0.2)                # decay over the last 20% → decay_start = 800 (STEPS=1000)
    assert CD.lr_at(100) == pytest.approx(3e-4, rel=1e-6)         # peak reached at WARMUP
    assert CD.lr_at(400) == pytest.approx(3e-4, rel=1e-9)         # STABLE phase holds peak (cosine would already be well below)
    assert CD.lr_at(800) == pytest.approx(3e-4, rel=1e-9)         # at decay_start: still peak
    mid_decay = CD.lr_at(900)                                     # halfway through the decay window
    assert 3e-4 * 0.05 < mid_decay < 3e-4
    assert CD.lr_at(1000) == pytest.approx(3e-4 * 0.05, rel=1e-6)  # floor at STEPS
    # the WSD stable phase holds a STRICTLY higher LR than cosine at the same mid-run step (the whole point)
    _set_sched(monkeypatch, decay="cosine", floor=0.05)
    cosine_mid = CD.lr_at(400)
    _set_sched(monkeypatch, decay="wsd", floor=0.05); monkeypatch.setattr(CD, "WSD_DECAY_FRAC", 0.2)
    assert CD.lr_at(400) > cosine_mid


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


def test_select_score_uses_cf_lift_when_present():
    """add.53: on a CF run the un-swapped slope is BLIND, so the best-ckpt reward must come from the held-out swapped cf_lift.
    A model with a FLAT slope but a high cf_lift must outscore one with the same flat slope and a low cf_lift."""
    reader = CD.select_score(e1=2.0, slope_e2=0.0, slope_e3=0.00, ctx_w=0.5, cf_lift=0.50)   # flat slope, high lift
    weak = CD.select_score(e1=2.0, slope_e2=0.0, slope_e3=0.00, ctx_w=0.5, cf_lift=0.05)     # flat slope, low lift
    assert reader > weak
    assert reader == pytest.approx(-2.0 + 0.5 * 0.50, rel=1e-9)                              # cf_lift overrides slope_e3
    # cf_lift dominates the slope: high lift + flat slope beats zero lift + a (blind, ignored) high slope
    assert CD.select_score(2.0, 0.0, 0.0, 0.5, cf_lift=0.50) > CD.select_score(2.0, 0.0, 0.40, 0.5, cf_lift=0.0)


def test_select_score_cf_lift_nan_is_safe():
    """A degenerate-E4 NaN lift must not crash or reward — falls to 0 reading reward (conservative)."""
    nan = float("nan")
    s = CD.select_score(2.0, 0.0, 0.30, 0.5, cf_lift=nan)
    assert s == pytest.approx(-2.0, rel=1e-9)                                                # NaN lift → 0 reward (slope ignored too)


# ----------------------------------------------------------------- add.51/52/54: P0 GO/NO-GO verdict gate (regime-aware anti-parrot)
# eval_hist rows are (step, e1, slope_e2, slope_e3, kd, cf|None); cf = {"lift","swap_follow","orig_recall"[,"genuine","swap_mismatch"]}.
def _cf(lift, swap, recall, genuine=None, mism=None):
    d = {"lift": lift, "swap_follow": swap, "orig_recall": recall}
    if genuine is not None:
        d["genuine"] = genuine
    if mism is not None:
        d["swap_mismatch"] = mism
    return d


def _hist(e1s, s3s, cfs=None):
    n = len(e1s)
    c = cfs if cfs is not None else [None] * n
    return [(i * 1000, e1s[i], 0.0, s3s[i], 5.0 - i, c[i]) for i in range(n)]


# --- no-swap regime (COUNTERFACTUAL off): the un-swapped slope proxy is the only reading test we have ---
def test_p0_verdict_noswap_rejects_parrot_big_e1_drop_flat_slope():
    """add.51 bug: a memorizer's E1 falls a LOT (8.13→7.58, Δ0.55 ≫ 0.20) but Δ(E3-E1) stays flat → NO-GO, not 'GO ✓ scale'."""
    v = CD.p0_verdict(_hist([8.13, 7.85, 7.58], [0.00, 0.002, 0.005]), e1_drop_min=0.20, reading_slope_margin=0.02, cf_lift_min=0.30)
    assert v["reading_basis"] == "slope_e3_e1" and v["e1_ok"] is True and v["reading_trend_up"] is False
    assert v["go"] is False


def test_p0_verdict_noswap_accepts_reader_rising_slope():
    """Smaller E1 drop (0.30 > 0.20) WITH a rising slope (0.0→0.12) and no swap signal → GO on the slope proxy."""
    v = CD.p0_verdict(_hist([8.00, 7.85, 7.70], [0.00, 0.06, 0.12]), 0.20, 0.02, 0.30)
    assert v["reading_basis"] == "slope_e3_e1" and v["go"] is True


def test_p0_verdict_requires_e1_drop_even_if_slope_rises():
    """Both gates required: rising slope but E1 barely moved (0.10 < 0.20) = not actually learning → NO-GO."""
    v = CD.p0_verdict(_hist([8.00, 7.95, 7.90], [0.00, 0.10, 0.20]), 0.20, 0.02, 0.30)
    assert v["reading_trend_up"] is True and v["e1_ok"] is False and v["go"] is False


# --- CF/swap regime (COUNTERFACTUAL on): the held-out counterfactual_lift is the CAUSAL gate; the slope is corroborating-only ---
def test_p0_verdict_cf_working_passes_even_with_FLAT_slope():
    """THE add.52 fix: a WORKING CF run has a high held-out swap lift + dropping orig_recall but its un-swapped Δ(E3-E1) slope
    is STRUCTURALLY FLAT (E1/E3 share targets). The old gate would NO-GO it; the regime-aware gate must GO."""
    cfs = [_cf(0.02, 0.05, 0.80), _cf(0.55, 0.62, 0.20)]          # lift 0.02→0.55 (>0.30), orig_recall 0.80→0.20 (drops)
    v = CD.p0_verdict(_hist([8.0, 7.7], [0.001, 0.004], cfs=cfs), 0.20, 0.02, 0.30)   # slope FLAT (delta +0.003 < 0.02)
    assert v["reading_basis"] == "counterfactual_lift+genuine" and v["swap_measured"] is True
    assert v["reading_trend_up"] is False                          # slope is blind/flat...
    assert v["cf_reads"] is True and v["go"] is True               # ...but the causal lift+recall-drop carries the GO


def test_p0_verdict_cf_low_lift_is_nogo_even_if_slope_rose():
    """A flat/low swap lift = CF did not force reading → NO-GO, even if the slope happened to rise (slope is not the gate here)."""
    cfs = [_cf(0.02, 0.05, 0.80), _cf(0.10, 0.15, 0.78)]          # lift 0.10 < 0.30
    v = CD.p0_verdict(_hist([8.0, 7.7], [0.00, 0.20], cfs=cfs), 0.20, 0.02, 0.30)
    assert v["cf_reads"] is False and v["go"] is False


def test_p0_verdict_cf_pseudo_reading_recall_stays_high_is_nogo():
    """Pseudo-reading guard (add.53b): a high swap-follow lift but orig_recall STAYS HIGH in free generation (>= RECALL_LOW
    and didn't drop) = the model still defaults to the memorized answer → NO-GO."""
    cfs = [_cf(0.30, 0.40, 0.40), _cf(0.55, 0.85, 0.42)]          # lift high but orig_recall stays high (0.40→0.42, no drop)
    v = CD.p0_verdict(_hist([8.0, 7.7], [0.00, 0.05], cfs=cfs), 0.20, 0.02, 0.30)
    assert v["recall_ok"] is False and v["cf_reads"] is False and v["go"] is False


def test_p0_verdict_cf_low_baseline_recall_does_not_false_nogo():
    """add.53b — THE parrot-baseline fix. This small model is NOT a confident memorizer (measured baseline orig_recall≈0.007),
    so a WORKING CF run has orig_recall ~0 throughout → it can NEVER 'drop'. A strict drop-gate would FALSE-NO-GO it; the
    relaxed guard (final recall low in ABSOLUTE terms) must GO."""
    cfs = [_cf(0.00, 0.01, 0.007), _cf(0.52, 0.53, 0.010)]        # lift 0→0.52, orig_recall stays ~0 (never had memory to drop)
    v = CD.p0_verdict(_hist([8.0, 7.7], [0.001, 0.004], cfs=cfs), 0.20, 0.02, 0.30)
    assert abs(v["orig_recall_drop"]) < 0.05                       # recall did NOT meaningfully drop...
    assert v["recall_ok"] is True and v["cf_reads"] is True and v["go"] is True    # ...but low absolute recall + high lift → GO


def test_p0_verdict_cf_e1_regression_is_nogo():
    """Specificity guard: if E1 nll RISES (prior degradation) the run is NO-GO regardless of a healthy swap lift —
    a genuine reader keeps E1 low. e1_ok subsumes 'E1 must not regress'."""
    cfs = [_cf(0.02, 0.05, 0.80), _cf(0.55, 0.62, 0.20)]          # swap lift healthy...
    v = CD.p0_verdict(_hist([7.5, 7.9], [0.00, 0.05], cfs=cfs), 0.20, 0.02, 0.30)   # ...but E1 ROSE 7.5→7.9
    assert v["cf_reads"] is True and v["e1_ok"] is False and v["go"] is False


# --- add.54: the question-MISMATCH control (genuine reading vs copy-the-salient-token) ---
def test_p0_verdict_cf_copy_heuristic_low_genuine_is_nogo():
    """High matched lift + low orig_recall BUT low genuine (matched ≈ mismatched) = the model copies the salient novel token
    regardless of the question → NOT question-conditioned reading → NO-GO."""
    cfs = [_cf(0.0, 0.01, 0.007, genuine=0.0, mism=0.01), _cf(0.55, 0.58, 0.01, genuine=0.05, mism=0.53)]
    v = CD.p0_verdict(_hist([8.0, 7.7], [0.001, 0.004], cfs=cfs), 0.20, 0.02, 0.30)
    assert v["genuine_ok"] is False and v["cf_reads"] is False and v["go"] is False


def test_p0_verdict_cf_genuine_reading_passes():
    """High lift + low recall + high genuine (matched ≫ mismatched) = genuine question-conditioned reading → GO."""
    cfs = [_cf(0.0, 0.01, 0.007, genuine=0.0, mism=0.01), _cf(0.55, 0.58, 0.01, genuine=0.45, mism=0.13)]
    v = CD.p0_verdict(_hist([8.0, 7.7], [0.001, 0.004], cfs=cfs), 0.20, 0.02, 0.30)
    assert v["genuine_ok"] is True and v["genuine_last"] == pytest.approx(0.45) and v["cf_reads"] is True and v["go"] is True


def test_p0_verdict_cf_genuine_not_measured_is_not_gated():
    """Backward-compat / fallback: when the mismatch control wasn't measured (no 'genuine' key), the genuine gate is NOT
    applied (don't gate on a control we never ran) — lift + recall carry the decision."""
    cfs = [_cf(0.0, 0.01, 0.007), _cf(0.55, 0.58, 0.01)]          # no genuine key
    v = CD.p0_verdict(_hist([8.0, 7.7], [0.001, 0.004], cfs=cfs), 0.20, 0.02, 0.30)
    assert v["genuine_ok"] is None and v["cf_reads"] is True and v["go"] is True


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
