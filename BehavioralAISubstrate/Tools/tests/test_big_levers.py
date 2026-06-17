"""Parity gates for the Track-G addendum-46 big levers: TBC-1 (vmap-batched forward ≡ per-row) and ARCH-3 (MLA RoPE
step≡forward_seq, and it actually rotates). These lock the correctness invariants that make the levers SAFE to enable on
the cloud run. CPU-only, fp64 for tight tolerance, no Granite."""
from __future__ import annotations

import pytest
import torch

import mamba3_hybrid as HY
import mamba3_mla as MLA


# ----------------------------------------------------------------- TBC-1: vmap batching is exactly the per-row forward
def test_vmap_batched_equals_per_row(tiny_hybrid):
    m = tiny_hybrid.double().eval()
    toks = torch.randint(0, 96, (4, 16))
    ref = torch.stack([m.run_twin(toks[b])[0] for b in range(toks.shape[0])])
    out = torch.vmap(lambda t: m.run_twin(t)[0])(toks)
    assert out.shape == ref.shape
    assert (out - ref).abs().max().item() < 1e-9        # vmap reuses the audited per-row math verbatim


def test_vmap_batched_backward_trains_all_params(tiny_hybrid):
    m = tiny_hybrid.float().train()
    toks = torch.randint(0, 96, (4, 12))
    sl = torch.vmap(lambda t: m.run_twin(t)[0])(toks)
    sl.float().log_softmax(-1).mean().backward()
    grads = [p.grad for p in m.parameters()]
    assert all(g is not None and torch.isfinite(g).all() for g in grads)


def test_right_pad_is_causal_safe(tiny_hybrid):
    """The batched path right-pads to maxT; trailing pad must NOT change a real row's outputs (causal)."""
    m = tiny_hybrid.double().eval()
    toks = torch.randint(0, 96, (16,))
    a = m.run_twin(toks)[0]
    padded = torch.cat([toks, torch.zeros(8, dtype=torch.long)])
    b = m.run_twin(padded)[0][:16]
    assert (a - b).abs().max().item() < 1e-9


def test_batched_path_loss_matches_single(tiny_hybrid):
    """End-to-end TBC-1 invariant: per-row loss over the vmap-batched forward == per-row loss over single forwards."""
    m = tiny_hybrid.double().eval()
    import torch.nn.functional as F
    exs = [torch.randint(0, 96, (10 + i,)) for i in range(3)]          # ragged lengths → right-pad
    maxT = max(t.shape[0] for t in exs)
    ids_b = torch.stack([F.pad(t, (0, maxT - t.shape[0])) for t in exs])
    sl_b = torch.vmap(lambda t: m.run_twin(t)[0])(ids_b)
    for i, t in enumerate(exs):
        single = m.run_twin(t)[0]
        assert (sl_b[i, :t.shape[0]] - single).abs().max().item() < 1e-9


# ----------------------------------------------------------------- ARCH-3: MLA RoPE
@pytest.mark.parametrize("flag", ["0", "1"])
def test_mla_rope_step_equals_forward_seq(monkeypatch, flag):
    monkeypatch.setenv("MLA_ROPE", flag)
    torch.manual_seed(0)
    blk = MLA.MLABlock().double().eval()
    x = torch.randn(12, MLA.D_MODEL, dtype=torch.float64)
    seq, _ = blk.forward_seq(x)
    cache, outs = None, []
    for t in range(12):
        o, cache = blk.step(x[t], cache)
        outs.append(o)
    assert (seq - torch.stack(outs)).abs().max().item() < 1e-9        # cache stays position-independent; step≡prefill


def test_mla_rope_off_is_nope_default(monkeypatch):
    monkeypatch.delenv("MLA_ROPE", raising=False)
    assert MLA._use_rope() is False                                   # default OFF = audited NoPE


def test_mla_rope_actually_rotates(monkeypatch):
    torch.manual_seed(0)
    blk = MLA.MLABlock().double().eval()
    x = torch.randn(12, MLA.D_MODEL, dtype=torch.float64)
    monkeypatch.setenv("MLA_ROPE", "0"); nope, _ = blk.forward_seq(x)
    monkeypatch.setenv("MLA_ROPE", "1"); rope, _ = blk.forward_seq(x)
    assert (nope - rope).abs().max().item() > 1e-6                    # RoPE materially changes attention


def test_hybrid_run_twin_equals_run_ref_with_rope(monkeypatch, tiny_hybrid):
    monkeypatch.setenv("MLA_ROPE", "1")
    m = tiny_hybrid.double().eval()
    toks = torch.randint(0, 96, (14,))
    # 1e-6 is the established hybrid device-truth tolerance (inherent Mamba chunked-scan vs sequential ~4e-7); RoPE on must
    # NOT widen it beyond NoPE. Assert rope-on error ≈ rope-off error (rope adds no extra divergence) AND both < 1e-6.
    err_rope = (m.run_twin(toks)[0] - m.run_ref(toks)).abs().max().item()
    monkeypatch.setenv("MLA_ROPE", "0")
    err_nope = (m.run_twin(toks)[0] - m.run_ref(toks)).abs().max().item()
    assert err_rope < 1e-6, f"train/deploy drift with MLA RoPE {err_rope:.2e} >= 1e-6"
    assert err_rope < err_nope * 5 + 1e-9, f"RoPE widened the drift ({err_rope:.2e} vs NoPE {err_nope:.2e})"


def test_resolve_ckpt_fails_closed_on_mla_rope(tmp_path, tiny_hybrid, monkeypatch):
    """ARCH-3 deploy guard: a ckpt trained with MLA_ROPE=1 must be REFUSED by the (still-NoPE) converter; NoPE loads fine."""
    import mamba3_cloud_distill as CD
    monkeypatch.setattr(CD, "LAYERS", 8)                             # save_ckpt records the module LAYERS; match the 8-layer fixture
    opt = torch.optim.AdamW(tiny_hybrid.parameters(), lr=1e-3)
    monkeypatch.setenv("MLA_ROPE", "1")
    p_rope = str(tmp_path / "rope.pt"); CD.save_ckpt(tiny_hybrid, opt, 1, p_rope)
    monkeypatch.setenv("CKPT", p_rope)
    with pytest.raises(AssertionError):
        HY.resolve_ckpt(96, 8)                                       # fail-closed on the RoPE ckpt
    monkeypatch.setenv("MLA_ROPE", "0")
    p_nope = str(tmp_path / "nope.pt"); CD.save_ckpt(tiny_hybrid, opt, 1, p_nope)
    monkeypatch.setenv("CKPT", p_nope)
    vocab, sd = HY.resolve_ckpt(96, 8)
    assert vocab == 96 and sd is not None                            # NoPE ckpt carries cleanly


def test_make_examples_tags_keep_gold(toy_rows, stub_tok):
    """Fix-5: examples are tagged keep_gold so the loop can opt out of answer-CE on no-gold (RAFT_NOGOLD_CE=0)."""
    import mamba3_raft as RAFT
    allkeep = RAFT.make_examples(toy_rows, keep_p=1.0, k=4, tok=stub_tok, seed=0)
    nokeep = RAFT.make_examples(toy_rows, keep_p=0.0, k=4, tok=stub_tok, seed=0)
    assert allkeep and all(it["keep_gold"] is True for it in allkeep)
    assert nokeep and all(it["keep_gold"] is False for it in nokeep)


# ----------------------------------------------------------------- E4-1: counterfactual reading probe (add.48)
def _swappable_row(i=0):
    return {"id": f"q{i}", "question": "what is the capital?", "answer": "Paris",
            "golden": [("G", "The capital is Paris and it is very old.")],
            "distract": [("D", "an unrelated paragraph.")], "gold_sents": ["The capital is Paris and it is very old."]}


def test_counterfactual_condition_swaps_the_fact(stub_tok):
    import mamba3_raft as RAFT
    E4 = RAFT.make_counterfactual_condition([_swappable_row()], stub_tok)
    assert len(E4) == 1
    it = E4[0]
    assert it["orig_answer"] == "Paris" and it["surrogate"] == RAFT._SURROGATE
    assert it["prompt_len"] >= 1 and it["input_ids"].numel() > it["prompt_len"]   # surrogate target appended


def test_counterfactual_skips_yesno_and_nonsubstring(stub_tok):
    import mamba3_raft as RAFT
    yesno = {"id": "y", "question": "?", "answer": "yes", "golden": [("G", "blah yes blah.")],
             "distract": [], "gold_sents": ["blah yes blah."]}
    nonsub = {"id": "n", "question": "?", "answer": "Xyz", "golden": [("G", "no match here.")],
              "distract": [], "gold_sents": ["no match here."]}
    assert RAFT.make_counterfactual_condition([yesno, nonsub], stub_tok) == []


def test_eval_counterfactual_runs_and_reports(stub_tok, monkeypatch):
    import mamba3_trainable as MTT, mamba3_eval as EV, mamba3_raft as RAFT
    monkeypatch.setattr(EV, "DEV", "cpu"); monkeypatch.setattr(RAFT, "DEV", "cpu")
    torch.manual_seed(0)
    student = MTT.M(512, 2).eval()                                   # vocab 512 covers the stub_tok char ids
    E4 = RAFT.make_counterfactual_condition([_swappable_row()], stub_tok)
    r = EV.eval_counterfactual(student, E4, stub_tok, maxlen=4)
    assert set(r) >= {"swap_follow_rate", "orig_recall_rate", "counterfactual_lift", "n"}
    assert r["n"] == len(E4) and 0.0 <= r["swap_follow_rate"] <= 1.0


# ----------------------------------------------------------------- KD-4: exact top-K + lumped-tail KD (add.48)
def _kd_tail_inputs(T=6, V=96, K=8):
    torch.manual_seed(0)
    tl = torch.randn(T, V)
    val, idx = tl.topk(K, dim=-1)
    logZ = torch.logsumexp(tl, dim=-1)
    return tl, idx, val, logZ


def test_kd_topk_tail_zero_at_optimum_and_grad_flows():
    import mamba3_cloud_distill as CD
    tl, idx, val, logZ = _kd_tail_inputs()
    assert float(CD.kd_topk_tail(tl.clone(), idx, val, logZ)) < 1e-4   # student==teacher → exact KL ≈ 0
    sl = torch.randn(tl.shape, requires_grad=True)
    kd = CD.kd_topk_tail(sl, idx, val, logZ)
    assert torch.isfinite(kd) and float(kd) >= 0.0
    kd.backward()
    assert sl.grad is not None and torch.isfinite(sl.grad).all()


def test_kd_topk_tail_requires_tau1(monkeypatch):
    import mamba3_cloud_distill as CD
    monkeypatch.setattr(CD, "TAU", 2.0)
    tl, idx, val, logZ = _kd_tail_inputs()
    with pytest.raises(AssertionError):
        CD.kd_topk_tail(tl, idx, val, logZ)                          # exact only at TAU=1


# ----------------------------------------------------------------- CURR-1: pace_T_frac drills the hard tail earlier
def test_pace_t_frac_reaches_full_set_earlier():
    from mamba3_curriculum_scheduler import CurriculumScheduler, CurriculumConfig
    import numpy as np
    d = np.random.default_rng(0).random(200)
    full = CurriculumScheduler(d, 1000, CurriculumConfig(pace_T_frac=1.0))
    half = CurriculumScheduler(d, 1000, CurriculumConfig(pace_T_frac=0.5))
    assert half.competence(500) > full.competence(500)              # half-frac drills the full distribution by the midpoint
    assert half.competence(500) >= 0.99 and full.competence(1000) >= 0.99
