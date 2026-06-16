"""Regression pins for mamba3_eval — the 8-gate honest claim_card + the SERIOUS evaluation batteries.

These tests PIN the audited invariants so a regression can never silently make the paid cloud run unsafe. The single
most important guarantee is the ANTI-PARROT contract: a context-ignoring model (slope_e3_e1 ≈ 0) MUST fail the
`context_use` gate; only a model that measurably degrades when the gold doc is removed may be claimed 成了.

CPU-only: mamba3_eval and mamba3_raft resolve DEV to mps on macOS, but the conftest fixtures build models on CPU. We
pin DEV='cpu' on both modules so data and weights live on the same device (no mps/cpu mismatch, no network/Granite).
"""
from __future__ import annotations

import copy
import math

import pytest
import torch

import mamba3_eval as EV
import mamba3_raft as RAFT

# Keep data + weights co-resident on CPU (fixtures build models on CPU; the modules would otherwise pick mps on macOS).
EV.DEV = "cpu"
RAFT.DEV = "cpu"


# --------------------------------------------------------------------------- helpers
def _passing_res() -> dict:
    """A result dict where EVERY gate passes → status 成了. Individual tests mutate one field to flip one gate."""
    return {
        "perplexity": {"hotpotqa_held_nll": 1.0},
        "raft": {
            "E1": {"nll": 1.0},
            "slope_e2_e1": 0.0,
            "slope_e3_e1": 0.5,        # well above CONTEXT_USE_MARGIN
            "skip_pct": 0.0,
            "subset_ok": True,
        },
        "fidelity": {"argmax_agreement": 0.9},
        "generation": {"EM": 0.9, "F1": 0.9},
        "teacher_E1_nll": 0.95,        # within TEACHER_GAP of E1 nll (1.0 - 0.95 = 0.05 <= 0.15)
        "decode_parity": {"argmax_agreement": 0.999},
        "contamination_ok": True,
    }


class _SpanTeacher:
    """Deterministic teacher whose argmax EXACTLY matches the student's argmax on the ANSWER span (positions predicting
    answer tokens) and is random/garbage on the PROMPT span. Used to prove compute_fidelity is masked to the answer span:
    argmax_agreement must read 1.0 regardless of what happens in the prompt region."""

    def __init__(self, student, plen: int, vocab: int):
        self.student, self.plen, self.vocab = student, plen, vocab

    def __call__(self, ids):
        ids0 = ids[0]
        sl, _ = self.student.run_twin(ids0, collect_ssm=False)
        T = ids.shape[1]
        out = torch.randn(1, T, self.vocab)
        sa = sl.argmax(-1)                                   # student argmax per position
        for p in range(T):
            if p >= self.plen - 1:                           # answer-predicting positions only
                out[0, p] = -1e4
                out[0, p, int(sa[p])] = 1e4
        return type("O", (), {"logits": out})


# =========================================================================== (B) the 8 gates wire
def test_claim_card_exactly_eight_gate_keys():
    card = EV.claim_card(_passing_res())
    assert set(card["gates"].keys()) == {
        "task_fit", "raft_e2_robust", "context_use", "fidelity_argmax",
        "generation", "stability", "device_parity", "no_contamination",
    }


def test_claim_card_status_chengle_only_when_all_true():
    card = EV.claim_card(_passing_res())
    assert all(card["gates"].values())
    assert card["failed_gates"] == []
    assert "成了" in card["status"]


def test_claim_card_one_failing_gate_flips_status_to_fail():
    res = _passing_res()
    res["contamination_ok"] = False                          # flip exactly one gate
    card = EV.claim_card(res)
    assert card["gates"]["no_contamination"] is False
    assert card["failed_gates"] == ["no_contamination"]
    assert "亏的" in card["status"]
    assert "成了" not in card["status"]


def test_claim_card_failed_gates_lists_every_failure():
    res = _passing_res()
    res["contamination_ok"] = False
    res["generation"] = {"EM": 0.0, "F1": 0.0}
    failed = set(EV.claim_card(res)["failed_gates"])
    assert {"no_contamination", "generation"} <= failed


# =========================================================================== (A) ANTI-PARROT: context_use
def test_context_use_fails_for_parrot_zero_slope():
    """slope_e3_e1 ≈ 0 means removing the gold doc did NOT hurt → the model ignored context → MUST fail."""
    res = _passing_res()
    res["raft"]["slope_e3_e1"] = 0.0
    assert EV.claim_card(res)["gates"]["context_use"] is False


def test_context_use_fails_just_below_margin():
    res = _passing_res()
    res["raft"]["slope_e3_e1"] = EV.CONTEXT_USE_MARGIN - 1e-6
    assert EV.claim_card(res)["gates"]["context_use"] is False


def test_context_use_passes_at_margin():
    res = _passing_res()
    res["raft"]["slope_e3_e1"] = EV.CONTEXT_USE_MARGIN
    assert EV.claim_card(res)["gates"]["context_use"] is True


def test_context_use_passes_above_margin():
    res = _passing_res()
    res["raft"]["slope_e3_e1"] = EV.CONTEXT_USE_MARGIN + 0.5
    assert EV.claim_card(res)["gates"]["context_use"] is True


def test_context_use_negative_slope_fails():
    """A negative slope (no-gold HELPED) is even more parrot-like than zero → fail-closed."""
    res = _passing_res()
    res["raft"]["slope_e3_e1"] = -0.3
    assert EV.claim_card(res)["gates"]["context_use"] is False


def test_context_use_missing_slope_fail_closed():
    res = _passing_res()
    res["raft"] = {"E1": {"nll": 1.0}, "slope_e2_e1": 0.0, "skip_pct": 0.0, "subset_ok": True}
    assert EV.claim_card(res)["gates"]["context_use"] is False


# =========================================================================== (C) task_fit fail-closed
def test_task_fit_fail_closed_when_teacher_missing():
    res = _passing_res()
    res.pop("teacher_E1_nll")
    assert EV.claim_card(res)["gates"]["task_fit"] is False


def test_task_fit_fail_closed_when_teacher_none():
    res = _passing_res()
    res["teacher_E1_nll"] = None
    assert EV.claim_card(res)["gates"]["task_fit"] is False


def test_task_fit_fail_closed_when_teacher_nan():
    res = _passing_res()
    res["teacher_E1_nll"] = float("nan")
    assert EV.claim_card(res)["gates"]["task_fit"] is False


def test_task_fit_fail_closed_when_teacher_inf():
    res = _passing_res()
    res["teacher_E1_nll"] = float("inf")
    assert EV.claim_card(res)["gates"]["task_fit"] is False


def test_task_fit_fails_when_held_nll_over_abs_bar():
    res = _passing_res()
    res["perplexity"]["hotpotqa_held_nll"] = EV.TASK_FIT_ABS + 0.01
    res["raft"]["E1"]["nll"] = EV.TASK_FIT_ABS + 0.01
    res["teacher_E1_nll"] = EV.TASK_FIT_ABS                  # gap ok, but absolute bar is exceeded
    assert EV.claim_card(res)["gates"]["task_fit"] is False


def test_task_fit_fails_when_teacher_gap_too_wide():
    res = _passing_res()
    res["perplexity"]["hotpotqa_held_nll"] = 1.0            # absolute bar fine
    res["raft"]["E1"]["nll"] = 1.0
    res["teacher_E1_nll"] = 1.0 - (EV.TEACHER_GAP + 0.01)   # student worse than teacher by > gap
    assert EV.claim_card(res)["gates"]["task_fit"] is False


def test_task_fit_passes_within_abs_and_gap():
    res = _passing_res()
    res["perplexity"]["hotpotqa_held_nll"] = EV.TASK_FIT_ABS
    res["raft"]["E1"]["nll"] = EV.TASK_FIT_ABS
    res["teacher_E1_nll"] = EV.TASK_FIT_ABS - EV.TEACHER_GAP   # exactly at the gap boundary
    assert EV.claim_card(res)["gates"]["task_fit"] is True


def test_task_fit_passes_when_student_beats_teacher():
    res = _passing_res()
    res["perplexity"]["hotpotqa_held_nll"] = 0.5
    res["raft"]["E1"]["nll"] = 0.5
    res["teacher_E1_nll"] = 2.0                              # student strictly better → gap negative ok
    assert EV.claim_card(res)["gates"]["task_fit"] is True


# =========================================================================== (D) device_parity
def test_device_parity_none_is_false_no_typeerror():
    res = _passing_res()
    res["decode_parity"] = {"argmax_agreement": None}        # no run_ref produced a number
    assert EV.claim_card(res)["gates"]["device_parity"] is False


def test_device_parity_missing_block_is_false():
    res = _passing_res()
    res.pop("decode_parity")
    assert EV.claim_card(res)["gates"]["device_parity"] is False


def test_device_parity_high_agreement_passes():
    res = _passing_res()
    res["decode_parity"] = {"argmax_agreement": 0.995}
    assert EV.claim_card(res)["gates"]["device_parity"] is True


def test_device_parity_below_bar_fails():
    res = _passing_res()
    res["decode_parity"] = {"argmax_agreement": 0.989}
    assert EV.claim_card(res)["gates"]["device_parity"] is False


def test_device_parity_exactly_at_bar_passes():
    res = _passing_res()
    res["decode_parity"] = {"argmax_agreement": EV.PARITY_BAR}
    assert EV.claim_card(res)["gates"]["device_parity"] is True


def test_device_parity_nan_is_false():
    """NaN must not slip through the comparison (NaN >= bar is False → fail-closed)."""
    res = _passing_res()
    res["decode_parity"] = {"argmax_agreement": float("nan")}
    assert EV.claim_card(res)["gates"]["device_parity"] is False


# =========================================================================== (E) stability
def test_stability_passes_low_skip_and_subset_ok():
    res = _passing_res()
    res["raft"]["skip_pct"] = 0.05
    res["raft"]["subset_ok"] = True
    assert EV.claim_card(res)["gates"]["stability"] is True


def test_stability_fails_when_skip_over_threshold():
    res = _passing_res()
    res["raft"]["skip_pct"] = 0.06
    res["raft"]["subset_ok"] = True
    assert EV.claim_card(res)["gates"]["stability"] is False


def test_stability_fails_when_subset_not_ok():
    res = _passing_res()
    res["raft"]["skip_pct"] = 0.0
    res["raft"]["subset_ok"] = False
    assert EV.claim_card(res)["gates"]["stability"] is False


def test_stability_requires_both_conditions():
    res = _passing_res()
    res["raft"]["skip_pct"] = 0.10
    res["raft"]["subset_ok"] = False
    assert EV.claim_card(res)["gates"]["stability"] is False


# =========================================================================== raft_e2_robust + fidelity_argmax + generation gates
def test_raft_e2_robust_passes_small_slope():
    res = _passing_res()
    res["raft"]["slope_e2_e1"] = 0.04
    assert EV.claim_card(res)["gates"]["raft_e2_robust"] is True


def test_raft_e2_robust_fails_large_slope():
    res = _passing_res()
    res["raft"]["slope_e2_e1"] = 0.06
    assert EV.claim_card(res)["gates"]["raft_e2_robust"] is False


def test_fidelity_argmax_gate_threshold():
    res = _passing_res()
    res["fidelity"] = {"argmax_agreement": 0.60}
    assert EV.claim_card(res)["gates"]["fidelity_argmax"] is True
    res["fidelity"] = {"argmax_agreement": 0.59}
    assert EV.claim_card(res)["gates"]["fidelity_argmax"] is False


def test_fidelity_argmax_none_fidelity_block_fail_closed():
    """res['fidelity'] None (teacher absent) → claim_card coerces to {} → argmax_agreement defaults 0 → fail."""
    res = _passing_res()
    res["fidelity"] = None
    assert EV.claim_card(res)["gates"]["fidelity_argmax"] is False


def test_generation_gate_requires_both_em_and_f1():
    res = _passing_res()
    res["generation"] = {"EM": 0.50, "F1": 0.60}
    assert EV.claim_card(res)["gates"]["generation"] is True
    res["generation"] = {"EM": 0.49, "F1": 0.99}            # EM below bar
    assert EV.claim_card(res)["gates"]["generation"] is False
    res["generation"] = {"EM": 0.99, "F1": 0.59}            # F1 below bar
    assert EV.claim_card(res)["gates"]["generation"] is False


# =========================================================================== (F) teacher_answer_nll
def test_teacher_answer_nll_finite_float(stub_teacher, eval_examples):
    val = EV.teacher_answer_nll(stub_teacher, eval_examples())
    assert isinstance(val, float)
    assert math.isfinite(val)


def test_teacher_answer_nll_nan_when_no_answer_tokens(stub_teacher):
    """When prompt_len >= T (no answer span), the mask is empty for every example → nan (no division by zero)."""
    ex = [{"id": "e0", "input_ids": torch.randint(0, 96, (10,)), "prompt_len": 10}]
    val = EV.teacher_answer_nll(stub_teacher, ex)
    assert math.isnan(val)


# =========================================================================== (G) compute_fidelity answer-span masking
def test_compute_fidelity_keys_and_ranges(tiny_mamba, stub_teacher, eval_examples):
    fid = EV.compute_fidelity(tiny_mamba, stub_teacher, eval_examples())
    assert set(fid.keys()) == {"full_vocab_kl", "top_k_agreement", "argmax_agreement"}
    assert 0.0 <= fid["top_k_agreement"] <= 1.0
    assert 0.0 <= fid["argmax_agreement"] <= 1.0
    assert math.isfinite(fid["full_vocab_kl"])


def test_compute_fidelity_none_teacher_returns_none(tiny_mamba, eval_examples):
    assert EV.compute_fidelity(tiny_mamba, None, eval_examples()) is None


def test_compute_fidelity_empty_examples_returns_fallback(tiny_mamba, stub_teacher):
    """A REAL teacher with NO examples → loop never runs (n==0) → the documented all-positions-skipped fallback dict
    (nan KL, 0.0 agreements). This is distinct from the teacher-None path, which returns None."""
    fid = EV.compute_fidelity(tiny_mamba, stub_teacher, [])
    assert math.isnan(fid["full_vocab_kl"])
    assert fid["top_k_agreement"] == 0.0
    assert fid["argmax_agreement"] == 0.0


def test_compute_fidelity_no_answer_span_falls_back(tiny_mamba, stub_teacher):
    """Every example has prompt_len==T (no answer-predicting positions) → n stays 0 → nan/0.0 fallback dict."""
    ex = [{"id": "e0", "input_ids": torch.randint(0, 96, (10,)), "prompt_len": 10}]
    fid = EV.compute_fidelity(tiny_mamba, stub_teacher, ex)
    assert math.isnan(fid["full_vocab_kl"])
    assert fid["top_k_agreement"] == 0.0
    assert fid["argmax_agreement"] == 0.0


def test_compute_fidelity_masked_to_answer_span_only(tiny_mamba, vocab):
    """ANTI-PARROT MASKING: a teacher that matches the student argmax ONLY on the answer span (garbage in the prompt)
    yields argmax_agreement == 1.0 — proving prompt-span positions are NOT counted."""
    plen = 30
    ex = [{"id": "a", "input_ids": torch.randint(0, vocab, (40,)), "prompt_len": plen}]
    teacher = _SpanTeacher(tiny_mamba, plen, vocab)
    fid = EV.compute_fidelity(tiny_mamba, teacher, ex)
    assert fid["argmax_agreement"] == pytest.approx(1.0)


def test_compute_fidelity_ignores_prompt_token_differences(tiny_mamba, vocab):
    """Two examples that differ ONLY in PROMPT tokens but share an identical answer region produce the SAME answer-span
    argmax_agreement under the span-matched teacher (the prompt difference is masked out)."""
    plen, T = 30, 40
    answer = torch.randint(0, vocab, (T - plen,))
    base = torch.randint(0, vocab, (T,)); base[plen:] = answer
    other = torch.randint(0, vocab, (T,)); other[plen:] = answer        # same answer, different prompt
    teacher = _SpanTeacher(tiny_mamba, plen, vocab)
    f1 = EV.compute_fidelity(tiny_mamba, teacher, [{"id": "a", "input_ids": base, "prompt_len": plen}])
    f2 = EV.compute_fidelity(tiny_mamba, teacher, [{"id": "b", "input_ids": other, "prompt_len": plen}])
    assert f1["argmax_agreement"] == pytest.approx(1.0)
    assert f2["argmax_agreement"] == pytest.approx(1.0)


# =========================================================================== (H) generate_and_score + text utils
def test_generate_and_score_em_f1_in_range(tiny_mamba, eval_examples, stub_tok):
    out = EV.generate_and_score(tiny_mamba, eval_examples(), stub_tok, maxlen=6)
    assert set(out.keys()) == {"EM", "F1"}
    assert 0.0 <= out["EM"] <= 1.0
    assert 0.0 <= out["F1"] <= 1.0


def test_generate_and_score_respects_eos_stop(tiny_mamba, eval_examples, stub_tok):
    """With an EOS set, generation must still produce a well-formed EM/F1 in range (the stop path runs without error)."""
    out = EV.generate_and_score(tiny_mamba, eval_examples(), stub_tok, maxlen=6, eos=stub_tok.eos_token_id)
    assert 0.0 <= out["EM"] <= 1.0
    assert 0.0 <= out["F1"] <= 1.0


def test_generate_and_score_empty_examples():
    out = EV.generate_and_score(None, [], None, maxlen=6)   # n==0 → guarded division
    assert out["EM"] == 0.0
    assert out["F1"] == 0.0


def test_normalize_text_lowercases_strips_punct_and_articles():
    assert EV._normalize_text("The Quick, Brown FOX!") == "quick brown fox"
    assert EV._normalize_text("A an THE cat") == "cat"
    assert EV._normalize_text("  multiple   spaces  ") == "multiple spaces"


def test_f1_text_exact_match_is_one():
    assert EV._f1_text("hello world", "hello world") == 1.0


def test_f1_text_partial_overlap():
    # pred='a b c' gold='a b' → common=2, prec=2/3, rec=2/2 → F1 = 2*(2/3*1)/(2/3+1) = 0.8
    assert EV._f1_text("a b c", "a b") == pytest.approx(0.8)


def test_f1_text_disjoint_is_zero():
    assert EV._f1_text("x y", "a b") == 0.0


def test_f1_text_both_empty_is_one():
    assert EV._f1_text("", "") == 1.0


def test_f1_text_one_empty_is_zero():
    assert EV._f1_text("", "a") == 0.0
    assert EV._f1_text("a", "") == 0.0


def test_f1_text_counts_token_multiplicity():
    """Token-overlap removes matched golds, so a doubled pred token only matches the single gold occurrence once."""
    # pred='a a' gold='a' → common=1, prec=1/2, rec=1/1 → F1 = 2*(0.5)/(1.5)
    assert EV._f1_text("a a", "a") == pytest.approx(2 * 0.5 * 1.0 / (0.5 + 1.0))


# =========================================================================== (I) eval_raft_robustness
def test_raft_robustness_keys_and_slopes(tiny_mamba, eval_examples):
    E = {"E1": eval_examples(), "E2": eval_examples(), "E3": eval_examples()}
    r = EV.eval_raft_robustness(tiny_mamba, E)
    for k in ("E1", "E2", "E3", "slope_e2_e1", "slope_e3_e1", "slope_e3_e2",
              "skip_pct", "subset_ok", "surviving"):
        assert k in r
    # slope identities: slope_e3_e1 == slope_e3_e2 + slope_e2_e1
    assert r["slope_e3_e1"] == pytest.approx(r["slope_e3_e2"] + r["slope_e2_e1"])
    for m in ("E1", "E2", "E3"):
        assert set(r[m].keys()) == {"nll", "acc", "skip"}


def test_raft_robustness_subset_ok_true_when_equal_survival(tiny_mamba, eval_examples):
    E = {"E1": eval_examples(n=4), "E2": eval_examples(n=4), "E3": eval_examples(n=4)}
    r = EV.eval_raft_robustness(tiny_mamba, E)
    assert r["subset_ok"] is True
    assert set(r["surviving"].values()) == {4}
    assert r["skip_pct"] == 0.0


def test_raft_robustness_subset_ok_false_when_unequal_counts(tiny_mamba, eval_examples):
    """Unequal example counts → unequal surviving counts → slopes computed over different subsets → subset_ok False."""
    E = {"E1": eval_examples(n=4), "E2": eval_examples(n=4), "E3": eval_examples(n=3)}
    r = EV.eval_raft_robustness(tiny_mamba, E)
    assert r["subset_ok"] is False
    assert len(set(r["surviving"].values())) > 1


def test_raft_robustness_subset_ok_false_when_a_condition_empty(tiny_mamba, eval_examples):
    """An empty condition has 0 survivors → the all-positive guard trips → subset_ok False (slopes are meaningless)."""
    E = {"E1": eval_examples(n=4), "E2": eval_examples(n=4), "E3": []}
    r = EV.eval_raft_robustness(tiny_mamba, E)
    assert r["subset_ok"] is False
    assert r["surviving"]["E3"] == 0


# =========================================================================== (J) contamination + buckets + ece + ppl
def test_verify_no_contamination_raises_on_overlap():
    with pytest.raises(AssertionError):
        EV.verify_no_contamination([{"id": "x"}, {"id": "y"}], [{"id": "x"}])


def test_verify_no_contamination_noop_when_disjoint():
    assert EV.verify_no_contamination([{"id": "a"}], [{"id": "b"}]) is None


def test_verify_no_contamination_ignores_idless_rows():
    """Rows without an 'id' key contribute no membership → no false-positive contamination."""
    assert EV.verify_no_contamination([{"q": 1}], [{"q": 2}]) is None


def test_split_bucket_deterministic():
    assert EV.split_bucket("q42") == EV.split_bucket("q42")
    assert EV.split_bucket("q42", 0.1) == EV.split_bucket("q42", 0.1)


def test_split_bucket_returns_bool_and_partitions():
    """Over many ids, ~held_frac fall in the held band — deterministic and roughly the requested fraction."""
    held = [i for i in range(1000) if EV.split_bucket(f"q{i}", 0.1)]
    assert isinstance(EV.split_bucket("q0", 0.1), bool)
    assert 0 < len(held) < 1000                              # both buckets are populated
    assert 50 <= len(held) <= 150                            # ~10% of 1000


def test_split_bucket_held_frac_zero_excludes_all():
    assert all(not EV.split_bucket(f"q{i}", 0.0) for i in range(50))


def test_compute_ece_in_range(tiny_mamba, eval_examples):
    out = EV.compute_ece(tiny_mamba, eval_examples())
    assert "ece" in out
    assert 0.0 <= out["ece"] <= 1.0


def test_compute_ece_nan_when_no_examples(tiny_mamba):
    out = EV.compute_ece(tiny_mamba, [])
    assert math.isnan(out["ece"])


def test_compute_perplexity_expected_keys(tiny_mamba, eval_examples):
    wt = [torch.randint(0, 96, (20,)) for _ in range(3)]
    out = EV.compute_perplexity(tiny_mamba, wt, eval_examples())
    assert set(out.keys()) == {"wikitext_ppl", "hotpotqa_held_ppl", "hotpotqa_held_nll", "skip"}
    assert math.isfinite(out["wikitext_ppl"]) and out["wikitext_ppl"] > 0
    assert math.isfinite(out["hotpotqa_held_nll"])
    assert out["skip"] == 0


def test_compute_perplexity_no_held_returns_inf(tiny_mamba):
    wt = [torch.randint(0, 96, (20,)) for _ in range(2)]
    out = EV.compute_perplexity(tiny_mamba, wt, None)
    assert out["hotpotqa_held_ppl"] == float("inf")
    assert out["hotpotqa_held_nll"] == float("inf")
    assert math.isfinite(out["wikitext_ppl"])


def test_quant_fidelity_stub_shape():
    out = EV.quant_fidelity_stub()
    assert out["status"] == "STUB"
    assert "note" in out


# =========================================================================== end-to-end claim_card on real batteries
def test_claim_card_on_random_weights_fails(tiny_mamba, eval_examples, stub_teacher, stub_tok):
    """A random-weight model wired through the REAL batteries must NOT be claimable (sanity: thresholds bite)."""
    ex = eval_examples()
    E = {"E1": eval_examples(), "E2": eval_examples(), "E3": eval_examples()}
    res = {
        "perplexity": EV.compute_perplexity(tiny_mamba, [torch.randint(0, 96, (20,))], ex),
        "raft": EV.eval_raft_robustness(tiny_mamba, E),
        "fidelity": EV.compute_fidelity(tiny_mamba, stub_teacher, ex),
        "generation": EV.generate_and_score(tiny_mamba, ex, stub_tok, maxlen=6),
        "teacher_E1_nll": EV.teacher_answer_nll(stub_teacher, E["E1"]),
        "decode_parity": {"argmax_agreement": None},        # tiny_mamba has run_ref but parity not run here
        "contamination_ok": True,
    }
    card = EV.claim_card(res)
    assert "亏的" in card["status"]
    assert card["failed_gates"]                              # at least one gate fails on random weights
