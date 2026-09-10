"""Regression pins for the Stage-3 logit-KD loss of the Mamba-3 cloud-distill pipeline.

Pins the audited invariants of mamba3_cloud_distill.{kd_topk, kd_kl, _sanitize} (+ mamba3_raft.masked_ce):
the paid cloud run trains on a CACHED teacher top-K, so a regression here silently corrupts the whole run.

CPU-only, tiny synthetic logits. We import the module fresh and read/patch its module-level TAU global directly
(the loss fns read mamba3_cloud_distill.TAU at call time), rather than relying on os.environ at import.
"""
from __future__ import annotations

import json
import math

import pytest
import torch

import mamba3_cloud_distill as CD
from mamba3_raft import masked_ce


# --------------------------------------------------------------------------------------
# helpers
# --------------------------------------------------------------------------------------
@pytest.fixture
def set_tau(monkeypatch):
    """Set the module-level TAU the loss fns read at call time, restored automatically."""
    def _set(tau: float):
        monkeypatch.setattr(CD, "TAU", float(tau))
        return float(tau)
    return _set


def _teacher_logits(T=5, V=20):
    return torch.randn(T, V)


def _topk_from_teacher(teacher_logits, K):
    val, idx = teacher_logits.topk(K, dim=-1)
    return idx, val


# --------------------------------------------------------------------------------------
# (1) kd_topk semantics: gathers student logprob at teacher top-K, teacher soft target
#     renormalized within K; KD >= 0; KD ~ 0 at the optimum.
# --------------------------------------------------------------------------------------
def test_kd_topk_nonnegative(set_tau):
    set_tau(1.0)
    teacher = _teacher_logits(T=6, V=24)
    idx, val = _topk_from_teacher(teacher, K=8)
    student = torch.randn(6, 24)
    kd = CD.kd_topk(student, idx, val)
    assert torch.isfinite(kd)
    # KL of a renormalized-within-K distribution vs student-gathered-logprobs must be >= 0 (allow tiny fp slack)
    assert float(kd) >= -1e-5


def test_kd_topk_gathers_at_teacher_topk_indices(set_tau):
    """The student term must be log_softmax(student) gathered at EXACTLY topk_idx — verify against a hand recompute."""
    set_tau(1.0)
    teacher = _teacher_logits(T=4, V=16)
    idx, val = _topk_from_teacher(teacher, K=5)
    student = torch.randn(4, 16)
    lp_full = torch.log_softmax(student.float(), dim=-1)
    lp_gathered = lp_full.gather(-1, idx.long())              # [T,K]
    q = torch.softmax(val.float(), dim=-1)                     # teacher soft target renormalized within K
    expect = (q * (q.clamp_min(1e-9).log() - lp_gathered)).sum(-1).mean()
    got = CD.kd_topk(student, idx, val)
    assert torch.allclose(got, expect, atol=1e-6), f"{float(got)} vs {float(expect)}"


def test_kd_topk_teacher_target_renormalized_within_k(set_tau):
    """q = softmax(topk_val) sums to 1 over the K kept logits — the renormalization-within-K contract.
    We verify indirectly: if student logprob at the K indices were uniform/constant, KD = -H(q) + const,
    and crucially the loss only depends on topk_val through softmax (a renormalized dist)."""
    set_tau(1.0)
    teacher = _teacher_logits(T=3, V=18)
    idx, val = _topk_from_teacher(teacher, K=6)
    # adding a constant to ALL topk_val must NOT change the loss (softmax shift-invariance == renormalization within K)
    student = torch.randn(3, 18)
    kd_a = CD.kd_topk(student, idx, val)
    kd_b = CD.kd_topk(student, idx, val + 7.5)
    assert torch.allclose(kd_a, kd_b, atol=1e-5), "topk_val must enter only through softmax (renorm within K)"


def test_kd_topk_near_zero_at_optimum(set_tau):
    """If the student logits are a scattered copy of the teacher top-K (matching mass on those indices and
    very low mass elsewhere), KD over the top-K must be ~0 — the optimum of the cached approximation."""
    set_tau(1.0)
    T, V, K = 5, 30, 10
    teacher = _teacher_logits(T, V)
    idx, val = _topk_from_teacher(teacher, K)
    # build a student whose log-softmax at the topk indices == log q (teacher renormalized within K),
    # by scattering the teacher topk_val into a -large background then it dominates the softmax.
    student = torch.full((T, V), -1e4)
    student.scatter_(-1, idx.long(), val)
    kd = CD.kd_topk(student, idx, val)
    assert abs(float(kd)) < 1e-3, f"expected ~0 KD at the scattered-teacher optimum, got {float(kd)}"


def test_kd_topk_self_distill_is_minimal(set_tau):
    """student == teacher full logits → student gathered logprob at topk == log q + log(within-K mass).
    KD should be small and >= the scattered optimum (background mass outside K bleeds a little)."""
    set_tau(1.0)
    T, V, K = 4, 40, 12
    teacher = _teacher_logits(T, V)
    idx, val = _topk_from_teacher(teacher, K)
    kd_self = CD.kd_topk(teacher.clone(), idx, val)
    assert float(kd_self) >= -1e-5
    # with K=12 of 40 covering most mass, self-distill KD is small
    assert float(kd_self) < 0.5


# --------------------------------------------------------------------------------------
# (2) seq-length drift guard
# --------------------------------------------------------------------------------------
def test_kd_topk_seq_mismatch_raises(set_tau):
    set_tau(1.0)
    student = torch.randn(7, 20)            # T=7
    idx = torch.randint(0, 20, (5, 8))      # cached T=5 — DRIFT
    val = torch.randn(5, 8)
    with pytest.raises(AssertionError):
        CD.kd_topk(student, idx, val)


def test_kd_topk_seq_match_ok(set_tau):
    set_tau(1.0)
    student = torch.randn(5, 20)
    idx = torch.randint(0, 20, (5, 8))
    val = torch.randn(5, 8)
    kd = CD.kd_topk(student, idx, val)      # must NOT raise
    assert torch.isfinite(kd)


# --------------------------------------------------------------------------------------
# (3) kd_kl semantics: >= 0, ~0 at self, TAU^2 scaling
# --------------------------------------------------------------------------------------
def test_kd_kl_nonnegative(set_tau):
    set_tau(1.0)
    student = torch.randn(6, 24)
    teacher = torch.randn(6, 24)
    kd = CD.kd_kl(student, teacher)
    assert torch.isfinite(kd)
    assert float(kd) >= -1e-5


def test_kd_kl_zero_when_equal(set_tau):
    set_tau(1.0)
    teacher = torch.randn(5, 30)
    kd = CD.kd_kl(teacher.clone(), teacher.clone())
    assert abs(float(kd)) < 1e-5, f"KL(t||t) must be 0, got {float(kd)}"


def test_kd_kl_zero_when_equal_high_tau(set_tau):
    set_tau(4.0)
    teacher = torch.randn(5, 30)
    kd = CD.kd_kl(teacher.clone(), teacher.clone())
    assert abs(float(kd)) < 1e-4, f"KL(t||t)==0 at any TAU, got {float(kd)}"


def test_kd_kl_tau_squared_scaling(set_tau):
    """kd_kl divides logits by TAU then multiplies the KL by TAU^2 (Hinton). For two FIXED distributions,
    raising TAU softens both equally; we verify the explicit TAU^2 factor by comparing the function's output
    to a hand recompute at two temperatures."""
    student = torch.randn(4, 20)
    teacher = torch.randn(4, 20)

    def manual(tau):
        s = torch.log_softmax(student.float() / tau, -1)
        t = torch.log_softmax(teacher.float() / tau, -1)
        return float(torch.nn.functional.kl_div(s, t, log_target=True, reduction="batchmean") * (tau * tau))

    set_tau(1.0)
    assert math.isclose(float(CD.kd_kl(student, teacher)), manual(1.0), rel_tol=1e-5, abs_tol=1e-6)
    set_tau(3.0)
    assert math.isclose(float(CD.kd_kl(student, teacher)), manual(3.0), rel_tol=1e-5, abs_tol=1e-6)


def test_kd_kl_tau_squared_factor_explicit(set_tau):
    """The TAU^2 multiplier is REAL: kd at TAU vs the same KL without the TAU^2 factor differs by exactly TAU^2."""
    student = torch.randn(4, 20)
    teacher = torch.randn(4, 20)
    tau = 2.5
    set_tau(tau)
    kd = float(CD.kd_kl(student, teacher))
    s = torch.log_softmax(student.float() / tau, -1)
    t = torch.log_softmax(teacher.float() / tau, -1)
    bare_kl = float(torch.nn.functional.kl_div(s, t, log_target=True, reduction="batchmean"))
    assert math.isclose(kd, bare_kl * tau * tau, rel_tol=1e-5, abs_tol=1e-7)


# --------------------------------------------------------------------------------------
# (4) top-K full-vocab approximation converges to full KD at TAU=1
# --------------------------------------------------------------------------------------
def test_kd_topk_full_vocab_equals_kd_kl(set_tau):
    """With K = full vocab, kd_topk's gathered+renormalized form equals full-vocab kd_kl at TAU=1."""
    set_tau(1.0)
    T, V = 5, 24
    teacher = _teacher_logits(T, V)
    student = torch.randn(T, V)
    idx, val = _topk_from_teacher(teacher, K=V)        # K == V → top-K is the whole vocab (a permutation)
    kd_t = CD.kd_topk(student, idx, val)
    kd_f = CD.kd_kl(student, teacher)
    assert torch.allclose(kd_t, kd_f, atol=1e-4), f"topk(K=V)={float(kd_t)} vs full KL={float(kd_f)}"


def test_kd_topk_approaches_full_as_k_grows(set_tau):
    """Larger K → kd_topk closer to full kd_kl (monotone-ish convergence of the cache approximation)."""
    set_tau(1.0)
    T, V = 4, 40
    teacher = _teacher_logits(T, V)
    student = torch.randn(T, V)
    full = float(CD.kd_kl(student, teacher))
    errs = []
    for K in (4, 12, 40):
        idx, val = _topk_from_teacher(teacher, K)
        errs.append(abs(float(CD.kd_topk(student, idx, val)) - full))
    assert errs[-1] <= errs[0] + 1e-6, f"K=V should be at least as close as K=4: {errs}"
    assert errs[-1] < 1e-4, f"K=V must converge to full KD, residual={errs[-1]}"


# --------------------------------------------------------------------------------------
# (5) gradient flow through kd_topk
# --------------------------------------------------------------------------------------
def test_kd_topk_gradient_flows(set_tau):
    set_tau(1.0)
    teacher = _teacher_logits(T=5, V=24)
    idx, val = _topk_from_teacher(teacher, K=8)
    student = torch.randn(5, 24, requires_grad=True)
    kd = CD.kd_topk(student, idx, val)
    kd.backward()
    assert student.grad is not None
    assert torch.isfinite(student.grad).all()
    assert float(student.grad.abs().sum()) > 0.0, "grad must be non-trivial (some flow to student logits)"


def test_kd_kl_gradient_flows(set_tau):
    set_tau(1.0)
    teacher = _teacher_logits(T=5, V=24)
    student = torch.randn(5, 24, requires_grad=True)
    kd = CD.kd_kl(student, teacher)
    kd.backward()
    assert student.grad is not None
    assert torch.isfinite(student.grad).all()
    assert float(student.grad.abs().sum()) > 0.0


def test_kd_topk_grad_zero_at_optimum(set_tau):
    """At the scattered-teacher optimum the gradient on the student should be ~0 (a true minimum)."""
    set_tau(1.0)
    T, V, K = 4, 30, 10
    teacher = _teacher_logits(T, V)
    idx, val = _topk_from_teacher(teacher, K)
    student = torch.full((T, V), -1e4)
    student.scatter_(-1, idx.long(), val)
    student = student.detach().requires_grad_(True)
    kd = CD.kd_topk(student, idx, val)
    kd.backward()
    assert torch.isfinite(student.grad).all()
    assert float(student.grad.abs().max()) < 1e-2, "grad should be near zero at the optimum"


# --------------------------------------------------------------------------------------
# (6) _sanitize: NaN/Inf -> None, recurse, unchanged normal, strict-JSON dumpable
# --------------------------------------------------------------------------------------
def test_sanitize_nan_to_none():
    assert CD._sanitize(float("nan")) is None


def test_sanitize_inf_to_none():
    assert CD._sanitize(float("inf")) is None
    assert CD._sanitize(float("-inf")) is None


def test_sanitize_normal_float_unchanged():
    assert CD._sanitize(3.14) == 3.14
    assert CD._sanitize(0.0) == 0.0
    assert CD._sanitize(-2.5) == -2.5


def test_sanitize_non_float_unchanged():
    assert CD._sanitize("hello") == "hello"
    assert CD._sanitize(42) == 42
    assert CD._sanitize(True) is True
    assert CD._sanitize(None) is None


def test_sanitize_nested_dict_recursed():
    x = {"a": float("nan"), "b": {"c": float("inf"), "d": 1.0}, "e": "ok"}
    out = CD._sanitize(x)
    assert out == {"a": None, "b": {"c": None, "d": 1.0}, "e": "ok"}


def test_sanitize_nested_list_recursed():
    x = [1.0, float("nan"), [float("-inf"), 2.0], {"k": float("inf")}]
    out = CD._sanitize(x)
    assert out == [1.0, None, [None, 2.0], {"k": None}]


def test_sanitize_tuple_becomes_list():
    """Tuples are recursed into a list (json has no tuple)."""
    out = CD._sanitize((1.0, float("nan"), 3.0))
    assert out == [1.0, None, 3.0]
    assert isinstance(out, list)


def test_sanitize_output_is_strict_json_dumpable():
    """The whole point of BUG-4: the sanitized structure must be allow_nan=False JSON-valid."""
    res = {"perplexity": float("nan"), "raft": {"E1": {"nll": float("inf"), "acc": 0.5}},
           "scores": [1.0, float("-inf"), 2.0], "ok": True, "name": "card"}
    clean = CD._sanitize(res)
    s = json.dumps(clean, allow_nan=False)        # would raise ValueError on a bare NaN/Inf
    assert "NaN" not in s and "Infinity" not in s
    reloaded = json.loads(s)
    assert reloaded["perplexity"] is None
    assert reloaded["raft"]["E1"]["nll"] is None
    assert reloaded["scores"] == [1.0, None, 2.0]


def test_sanitize_raw_dict_would_break_strict_json():
    """Sanity-check the premise: without _sanitize, the same dict is NOT strict-JSON dumpable."""
    res = {"perplexity": float("nan")}
    with pytest.raises(ValueError):
        json.dumps(res, allow_nan=False)


# --------------------------------------------------------------------------------------
# masked_ce (mamba3_raft) — the CE half of the distill loss, used alongside KD
# --------------------------------------------------------------------------------------
def test_masked_ce_only_answer_span(set_tau):
    """masked_ce supervises only positions >= prompt_len-1 (answer span), causal-shifted."""
    T, V, plen = 10, 16, 7
    logits = torch.randn(T, V)
    ids = torch.randint(0, V, (T,))
    ce = masked_ce(logits, ids, plen)
    assert ce is not None and torch.isfinite(ce)
    assert float(ce) >= 0.0


def test_masked_ce_none_when_no_answer_span(set_tau):
    """If prompt_len-1 >= T-1 there is no answer token after the shift → None (the loss must skip it)."""
    T, V = 8, 16
    logits = torch.randn(T, V)
    ids = torch.randint(0, V, (T,))
    ce = masked_ce(logits, ids, prompt_len=T)     # mask all False after shift
    assert ce is None


def test_masked_ce_matches_manual(set_tau):
    T, V, plen = 9, 12, 5
    logits = torch.randn(T, V)
    ids = torch.randint(0, V, (T,))
    lp, tgt = logits[:-1], ids[1:]
    mask = torch.arange(tgt.shape[0]) >= (plen - 1)
    expect = torch.nn.functional.cross_entropy(lp[mask], tgt[mask], reduction="mean")
    got = masked_ce(logits, ids, plen)
    assert torch.allclose(got, expect, atol=1e-6)


def test_masked_ce_gradient_flows(set_tau):
    T, V, plen = 9, 12, 5
    logits = torch.randn(T, V, requires_grad=True)
    ids = torch.randint(0, V, (T,))
    ce = masked_ce(logits, ids, plen)
    ce.backward()
    assert logits.grad is not None and torch.isfinite(logits.grad).all()
    assert float(logits.grad.abs().sum()) > 0.0


# --------------------------------------------------------------------------------------
# integration: the actual training combine (KD_W*kd + CE_W*ce) is finite & differentiable
# --------------------------------------------------------------------------------------
def test_combined_loss_finite_and_differentiable(set_tau):
    set_tau(1.0)
    T, V, K, plen = 12, 24, 8, 8
    teacher = _teacher_logits(T, V)
    idx, val = _topk_from_teacher(teacher, K)
    student = torch.randn(T, V, requires_grad=True)
    ids = torch.randint(0, V, (T,))
    kd = CD.kd_topk(student, idx, val)
    ce = masked_ce(student, ids, plen)
    loss = (CD.KD_W * kd + (CD.CE_W * ce if ce is not None else 0.0)) / CD.ACCUM
    assert torch.isfinite(loss)
    loss.backward()
    assert torch.isfinite(student.grad).all()
