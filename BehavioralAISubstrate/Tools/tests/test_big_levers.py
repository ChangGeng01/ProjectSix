"""Parity gates for the Track-G addendum-46 big levers: TBC-1 (vmap-batched forward ≡ per-row) and ARCH-3 (MLA RoPE
step≡forward_seq, and it actually rotates). These lock the correctness invariants that make the levers SAFE to enable on
the cloud run. CPU-only, fp64 for tight tolerance, no Granite."""
from __future__ import annotations

import random

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


def test_eval_counterfactual_follow_only_skips_recall(stub_tok, monkeypatch):
    """add.54: follow_only=True (used for the mismatch control) skips the free-greedy orig_recall pass → recall is nan."""
    import math
    import mamba3_trainable as MTT, mamba3_eval as EV, mamba3_raft as RAFT
    monkeypatch.setattr(EV, "DEV", "cpu"); monkeypatch.setattr(RAFT, "DEV", "cpu")
    torch.manual_seed(0)
    student = MTT.M(512, 2).eval()
    E4 = RAFT.make_counterfactual_condition([_swappable_row()], stub_tok)
    r = EV.eval_counterfactual(student, E4, stub_tok, maxlen=4, follow_only=True)
    assert math.isnan(r["orig_recall_rate"]) and 0.0 <= r["swap_follow_rate"] <= 1.0   # recall pass skipped


# ----------------------------------------------------------------- add.54: question-MISMATCH control
def _swap_rows_distinct(n=4):
    return [{"id": f"d{i}", "question": f"who discovered element {i}?", "answer": f"Personne{i}",
             "golden": [("G", f"Element {i} was discovered by Personne{i} in the old days.")],
             "distract": [("D", "an unrelated paragraph about weather.")],
             "gold_sents": [f"Element {i} was discovered by Personne{i} in the old days."]} for i in range(n)]


def test_cf_mismatch_pairs_foreign_questions(stub_tok):
    import mamba3_raft as RAFT
    rows = _swap_rows_distinct(4)
    matched = {it["id"]: it["input_ids"] for it in RAFT.make_counterfactual_condition(rows, stub_tok)}
    mism = RAFT.make_counterfactual_mismatch(rows, stub_tok)
    assert mism and all(it.get("mismatch") is True for it in mism)
    assert all(it["prompt_len"] >= 1 and it["input_ids"].numel() > it["prompt_len"] for it in mism)
    # same swapped doc, FOREIGN question → the tokenized input must DIFFER from the matched item with the same id
    for it in mism:
        if it["id"] in matched:
            a, b = it["input_ids"], matched[it["id"]]
            assert a.numel() != b.numel() or not bool((a == b).all())


def test_cf_mismatch_needs_two_distinct_rows(stub_tok):
    import mamba3_raft as RAFT
    assert RAFT.make_counterfactual_mismatch(_swap_rows_distinct(1), stub_tok) == []   # <2 swappable rows → no foreign question


class _CharDecodeTok:
    """A tok whose decode round-trips ids→chars (the StubTok decode emits numeric ids, so it can't test surrogate survival)."""
    def decode(self, ids):
        return "".join(chr(int(i)) for i in ids)


def test_align_cf_survivors_keeps_only_rows_surviving_in_both():
    """add.54b: align drops any row whose surrogate was truncated out of EITHER probe, and keeps the matched+mismatch sets
    over the SAME id set (so genuine compares like-for-like)."""
    import mamba3_raft as RAFT
    t = _CharDecodeTok()

    def mk(id_, txt):
        ids = torch.tensor([ord(c) for c in txt])
        return {"id": id_, "input_ids": ids, "prompt_len": ids.numel(), "surrogate": "Zelophar"}

    matched = [mk("a", "x Zelophar y"), mk("b", "x Zelophar y"), mk("c", "no surrogate")]   # b: surrogate only in matched
    mismatch = [mk("a", "p Zelophar q"), mk("b", "no surrogate"), mk("c", "p Zelophar q")]  # c: surrogate only in mismatch
    km, kmm = RAFT.align_cf_survivors(matched, mismatch, t)
    assert [it["id"] for it in km] == ["a"] and [it["id"] for it in kmm] == ["a"]           # only 'a' survives in BOTH
    assert [it["id"] for it in km] == [it["id"] for it in kmm]                              # aligned id sets


def test_align_cf_survivors_invariant_equal_ids(stub_tok):
    """Whatever survives, the two returned lists ALWAYS carry the same id set in the same order (the genuine premise)."""
    import mamba3_raft as RAFT
    t = _CharDecodeTok()
    rows = _swap_rows_distinct(5)
    km, kmm = RAFT.align_cf_survivors(RAFT.make_counterfactual_condition(rows, stub_tok),
                                      RAFT.make_counterfactual_mismatch(rows, stub_tok), t)
    assert [it["id"] for it in km] == [it["id"] for it in kmm]


# ----------------------------------------------------------------- KD-C: counterfactual reading-FORCING train pool (add.50)
def test_cf_train_pool_builds_valid_reading_forcing_examples(stub_tok):
    import mamba3_raft as RAFT
    pool = RAFT.make_cf_train_pool([_swappable_row(i) for i in range(6)], stub_tok, seed=0)
    assert pool, "swappable rows must yield CF examples"
    for it in pool:
        assert it["cf"] is True                                       # tagged → CE-only branch (no KD) in the loop
        assert it["prompt_len"] >= 1 and it["input_ids"].numel() > it["prompt_len"]   # a target token is predicted
        assert it["surrogate"] != "Paris" and it["orig_answer"] == "Paris"            # the FACT was swapped away from the parametric answer


def test_cf_train_pool_surrogate_is_randomized_and_not_the_e4_nonce(stub_tok):
    """The verifier's load-bearing caveat: the train surrogate MUST be randomized per example AND distinct from the E4 eval
    nonce — else the model learns 'emit a fixed magic token' (and E4 stops being an independent probe)."""
    import mamba3_raft as RAFT
    pool = RAFT.make_cf_train_pool([_swappable_row(i) for i in range(12)], stub_tok, seed=0)
    surrogates = {it["surrogate"] for it in pool}
    assert RAFT._SURROGATE not in surrogates                          # never the E4 eval nonce ('Zelophar')
    assert len(surrogates) >= 2                                       # randomized per example, not one constant


def test_cf_train_pool_skips_yesno_and_nonsubstring(stub_tok):
    import mamba3_raft as RAFT
    yesno = {"id": "y", "question": "?", "answer": "yes", "golden": [("G", "blah yes blah.")],
             "distract": [], "gold_sents": ["blah yes blah."]}
    nonsub = {"id": "n", "question": "?", "answer": "Xyz", "golden": [("G", "no match here.")],
              "distract": [], "gold_sents": ["no match here."]}
    assert RAFT.make_cf_train_pool([yesno, nonsub], stub_tok, seed=0) == []


def test_cf_train_pool_includes_distractors_multidoc_regime(stub_tok):
    """add.52 regime-match (dual-verified HIGH): CF examples must be built WITH distractors so reading is forced in the SAME
    multi-doc shape as E2/E3 — gold-only CF taught reading only in the 1-doc regime the headline never measures."""
    import mamba3_raft as RAFT
    row = _swappable_row()
    row["distract"] = [("D1", "alpha beta gamma delta epsilon."), ("D2", "zeta eta theta iota kappa.")]
    with_d = RAFT.make_cf_train_pool([row], stub_tok, seed=0, k=2)
    gold_only = RAFT.make_cf_train_pool([row], stub_tok, seed=0, k=0)
    assert with_d and gold_only
    assert with_d[0]["input_ids"].numel() > gold_only[0]["input_ids"].numel()   # distractors add doc tokens → multi-doc


def test_cf_numeric_surrogate_has_different_leading_digit(stub_tok):
    """add.52: numeric surrogates are NOT digit-SHUFFLES of the answer (which share subword tokens, weak reading signal) — a
    fresh same-length number whose LEADING digit differs (breaks the shared leading subword token, e.g. years 19xx)."""
    import mamba3_raft as RAFT
    rng = random.Random(0)
    for ans in ["1925", "1804", "2011", "47", "365"]:
        for _ in range(40):
            s = RAFT._num_surrogate(ans, rng)
            assert len(s) == len(ans) and s != ans               # same length, different value
            assert s[0] != ans[0]                                 # leading digit differs → no shared leading subword token


def test_cf_frac_at_anneals_after_warmup():
    """cf_frac_at (the tested helper cf_pick calls) ramps 0 → CF_FRAC linearly AFTER CF_WARM*STEPS, then clamps at CF_FRAC."""
    import mamba3_cloud_distill as CD
    assert CD.cf_frac_at(100, 1000, 0.3, 0.15) == 0.0                 # inside the warmup window → no CF yet
    assert CD.cf_frac_at(150, 1000, 0.3, 0.15) == 0.0                 # exactly at warm boundary → still 0
    mid = CD.cf_frac_at(575, 1000, 0.3, 0.15)                        # halfway through the post-warm ramp → ~half of CF_FRAC
    assert abs(mid - 0.15) < 1e-6
    assert abs(CD.cf_frac_at(1000, 1000, 0.3, 0.15) - 0.3) < 1e-9    # end → full CF_FRAC
    assert CD.cf_frac_at(2000, 1000, 0.3, 0.15) <= 0.3 + 1e-9        # clamped (never exceeds CF_FRAC)
    assert CD.cf_frac_at(500, 1000, 0.0, 0.15) == 0.0                # CF_FRAC=0 (default) → always 0 = dead path


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
