"""Regression pins for the Mamba-3 RAFT data builder (Tools/mamba3_raft.py).

These tests fence the audited invariants of the RAFT-via-fine-tuning PoC so a regression can never silently
make the paid cloud run unsafe:

  (1) _select_docs gold-survival      — ALL gold kept, distractors dropped under budget pressure.
  (2) to_ids contract                 — carries ex_id, never trims the question suffix, prompt_len>=1,
                                        answer mask covers >=1 token.
  (3) make_examples keep_p semantics  — keep_p=1.0 always includes gold; keep_p=0.0 includes NO gold and
                                        holds the doc-count constant (k + len(golden)).
  (4) make_eval_condition E1/E2/E3    — E1 gold-only, E2 gold+K_DISTRACT, E3 no-gold doc-count-matched;
                                        the gold ANSWER text must NOT leak into E3 distractors.
  (5) determinism                     — make_eval_condition is byte-identical across rebuilds.
  (6) masked_ce                       — None when the prompt leaves no answer token, else CE over the
                                        answer span only.
  (7) eval_nll                        — returns (nll, acc, skip); skips non-finite-logit examples.

CPU-only, no network/Granite/coreai. Uses the shared conftest fixtures (stub_tok, toy_rows, tiny_mamba,
eval_examples) and the module-level helpers (StubTok, make_row).
"""
from __future__ import annotations

import random

import pytest
import torch

import mamba3_raft as R
from conftest import StubTok, make_row


# --------------------------------------------------------------------------------------------------
# helpers
# --------------------------------------------------------------------------------------------------
def _is_subseq(sub: list, seq: list) -> bool:
    """True iff `sub` occurs as a contiguous run inside `seq` (empty sub → True)."""
    m = len(sub)
    if m == 0:
        return True
    return any(seq[i:i + m] == sub for i in range(len(seq) - m + 1))


def _count_subseq(sub: list, seq: list) -> int:
    m = len(sub)
    if m == 0:
        return 0
    return sum(1 for i in range(len(seq) - m + 1) if seq[i:i + m] == sub)


def _tok_ids(tok, text: str) -> list:
    return tok(text, add_special_tokens=False).input_ids


def _gold_title_tok(tok, row: dict, g: int = 0) -> list:
    return _tok_ids(tok, row["golden"][g][0])


def _doc_count(tok, seq: list) -> int:
    """Number of formatted documents in an input_ids sequence (counts the '[Document ' header marker)."""
    return _count_subseq(_tok_ids(tok, "[Document "), seq)


# --------------------------------------------------------------------------------------------------
# (1) _select_docs — gold-survival
# --------------------------------------------------------------------------------------------------
def test_select_docs_keeps_gold_under_budget_pressure(stub_tok):
    """The audit bug: a shuffled-to-the-back gold doc was silently cut. Gold must survive even when many
    big distractors blow the budget."""
    gold = [("GOLD", "the one gold fact.")]
    distract = [(f"D{j}", "x" * 200) for j in range(20)]
    kept = R._select_docs(gold, distract, budget=80, tok=stub_tok, rng=random.Random(0))
    titles = {t for t, _ in kept}
    assert "GOLD" in titles, "gold-survival FAILED: gold dropped under budget pressure"


def test_select_docs_drops_excess_distractors_when_over_budget(stub_tok):
    gold = [("GOLD", "the one gold fact.")]
    distract = [(f"D{j}", "x" * 200) for j in range(20)]
    kept = R._select_docs(gold, distract, budget=80, tok=stub_tok, rng=random.Random(0))
    assert len(kept) < 1 + len(distract), "excess distractors must be dropped when over budget"


def test_select_docs_keeps_all_gold_even_when_multiple(stub_tok):
    """ALL gold docs are guaranteed, not just the first one."""
    gold = [("G0", "gold zero " * 10), ("G1", "gold one " * 10)]
    distract = [(f"D{j}", "x" * 200) for j in range(20)]
    kept = R._select_docs(gold, distract, budget=50, tok=stub_tok, rng=random.Random(0))
    titles = {t for t, _ in kept}
    assert {"G0", "G1"} <= titles, "every gold doc must survive, not only the first"


def test_select_docs_gold_kept_even_if_it_alone_overflows(stub_tok):
    """Gold is appended before the budget check — kept even if a single gold doc exceeds the budget."""
    gold = [("BIG_GOLD", "g" * 500)]
    kept = R._select_docs(gold, [], budget=5, tok=stub_tok, rng=random.Random(0))
    assert [t for t, _ in kept] == ["BIG_GOLD"], "lone over-budget gold doc must still be kept"


def test_select_docs_keeps_all_when_budget_is_ample(stub_tok):
    gold = [("GOLD", "small gold.")]
    distract = [(f"D{j}", "tiny.") for j in range(3)]
    kept = R._select_docs(gold, distract, budget=100_000, tok=stub_tok, rng=random.Random(0))
    assert len(kept) == 1 + 3, "with ample budget every doc is kept"


def test_select_docs_no_distractors_only_gold(stub_tok):
    gold = [("GOLD", "gold fact.")]
    kept = R._select_docs(gold, [], budget=1000, tok=stub_tok, rng=random.Random(0))
    assert [t for t, _ in kept] == ["GOLD"]


def test_select_docs_shuffle_is_deterministic_for_fixed_rng(stub_tok):
    gold = [("GOLD", "gold fact.")]
    distract = [(f"D{j}", "tiny doc.") for j in range(5)]
    a = R._select_docs(gold, list(distract), budget=1000, tok=stub_tok, rng=random.Random(123))
    b = R._select_docs(gold, list(distract), budget=1000, tok=stub_tok, rng=random.Random(123))
    assert a == b, "same seed → same kept order (frozen eval set must be reproducible)"


def test_select_docs_does_not_mutate_inputs(stub_tok):
    """Immutability: the caller's gold/distract lists must be left untouched (shuffle hits the local copy)."""
    gold = [("GOLD", "gold fact.")]
    distract = [(f"D{j}", "tiny doc.") for j in range(5)]
    gold_before, distract_before = list(gold), list(distract)
    R._select_docs(gold, distract, budget=1000, tok=stub_tok, rng=random.Random(1))
    assert gold == gold_before and distract == distract_before, "_select_docs must not mutate its inputs"


# --------------------------------------------------------------------------------------------------
# (2) to_ids — contract
# --------------------------------------------------------------------------------------------------
def test_to_ids_carries_ex_id(stub_tok):
    gold = [("GOLD", "the one gold fact.")]
    it = R.to_ids(gold, [], "what is the answer?", " ans0", stub_tok, random.Random(1), ex_id="qid")
    assert it.get("id") == "qid", "to_ids must carry ex_id for cross-condition (E1/E2/E3) alignment"


def test_to_ids_omits_id_when_none(stub_tok):
    it = R.to_ids([("G", "g.")], [], "q?", " a", stub_tok, random.Random(1), ex_id=None)
    assert "id" not in it, "no id key when ex_id is None"


def test_to_ids_prompt_len_at_least_one(stub_tok):
    it = R.to_ids([("G", "g.")], [], "q?", " a", stub_tok, random.Random(1))
    assert it["prompt_len"] >= 1


def test_to_ids_mask_covers_at_least_one_answer_token(stub_tok):
    it = R.to_ids([("G", "g.")], [], "q?", " ans", stub_tok, random.Random(1))
    ntgt = it["input_ids"].numel() - 1
    mask = torch.arange(ntgt) >= (it["prompt_len"] - 1)
    assert int(mask.sum()) >= 1, "answer mask must cover >=1 token (>=1 answer token predicted)"


def test_to_ids_predicts_at_least_one_token(stub_tok):
    """prompt_len is capped at len(full)-1 so there is always a next token to predict."""
    it = R.to_ids([("G", "g.")], [], "q?", " a", stub_tok, random.Random(1))
    assert it["input_ids"].numel() > it["prompt_len"]


def test_to_ids_never_trims_question_suffix(stub_tok):
    """Under heavy budget pressure only DOCUMENT tokens may be dropped — the question suffix survives whole."""
    gold = [("GOLD", "the one gold fact.")]
    distract = [(f"D{j}", "x" * 200) for j in range(40)]
    q = "what is the secret answer to this very long question?"
    it = R.to_ids(gold, distract, q, " ans0", stub_tok, random.Random(2), ex_id="qid")
    suffix_ids = _tok_ids(stub_tok, f"\nQuestion: {q}\nAnswer:")
    seq = it["input_ids"].tolist()
    assert _is_subseq(suffix_ids, seq), "the question suffix must never be truncated away"


def test_to_ids_answer_tokens_are_the_trailing_tokens(stub_tok):
    """The answer tokens are appended verbatim at the end (the supervised target)."""
    aids = _tok_ids(stub_tok, " banana")
    it = R.to_ids([("G", "g.")], [], "q?", " banana", stub_tok, random.Random(3))
    seq = it["input_ids"].tolist()
    assert seq[-len(aids):] == aids, "answer tokens must be the trailing tokens of input_ids"


def test_to_ids_prepends_bos(stub_tok):
    it = R.to_ids([("G", "g.")], [], "q?", " a", stub_tok, random.Random(4))
    assert it["input_ids"][0].item() == stub_tok.bos_token_id, "BOS must lead the sequence"


def test_to_ids_input_ids_is_1d_long_tensor(stub_tok):
    it = R.to_ids([("G", "g.")], [], "q?", " a", stub_tok, random.Random(5))
    assert it["input_ids"].dim() == 1 and it["input_ids"].dtype == torch.long


def test_to_ids_respects_max_len_budget(stub_tok, monkeypatch):
    """With a tight MAX_LEN, distractor docs are dropped so the total stays within budget (gold + suffix
    + answer are the protected reserve)."""
    monkeypatch.setattr(R, "MAX_LEN", 60)
    gold = [("GOLD", "the one gold fact.")]
    distract = [(f"D{j}", "x" * 200) for j in range(40)]
    it = R.to_ids(gold, distract, "q?", " ans", stub_tok, random.Random(6))
    suffix_ids = _tok_ids(stub_tok, "\nQuestion: q?\nAnswer:")
    aids = _tok_ids(stub_tok, " ans")
    # the reserved (un-truncatable) tail = suffix + answer must still be fully present
    seq = it["input_ids"].tolist()
    assert _is_subseq(suffix_ids, seq) and seq[-len(aids):] == aids
    assert it["prompt_len"] >= 1 and it["input_ids"].numel() > it["prompt_len"]


# --------------------------------------------------------------------------------------------------
# (3) make_examples — keep_p semantics + doc-count
# --------------------------------------------------------------------------------------------------
def test_make_examples_keep_p_one_always_includes_gold(stub_tok, toy_rows):
    examples = R.make_examples(toy_rows, keep_p=1.0, k=4, tok=stub_tok, seed=0)
    assert len(examples) == len(toy_rows), "keep_p=1.0 keeps every row (all build a valid item)"
    for item, row in zip(examples, toy_rows):
        gtok = _gold_title_tok(stub_tok, row)
        assert _is_subseq(gtok, item["input_ids"].tolist()), "keep_p=1.0 must always include gold"


def test_make_examples_keep_p_zero_includes_no_gold(stub_tok, toy_rows):
    examples = R.make_examples(toy_rows, keep_p=0.0, k=4, tok=stub_tok, seed=0)
    assert len(examples) == len(toy_rows)
    for item, row in zip(examples, toy_rows):
        gtok = _gold_title_tok(stub_tok, row)
        assert not _is_subseq(gtok, item["input_ids"].tolist()), "keep_p=0.0 must include NO gold"


def test_make_examples_keep_p_zero_holds_doc_count_constant(stub_tok):
    """no-gold build replaces gold with extra distractors so total doc count == k + len(golden)."""
    row = make_row(0, n_gold=2, n_dist=6)
    k = 3
    keep = R.make_examples([row], keep_p=1.0, k=k, tok=stub_tok, seed=0)[0]
    drop = R.make_examples([row], keep_p=0.0, k=k, tok=stub_tok, seed=0)[0]
    n_keep = _doc_count(stub_tok, keep["input_ids"].tolist())
    n_drop = _doc_count(stub_tok, drop["input_ids"].tolist())
    assert n_keep == k + len(row["golden"]), "keep build = k distractors + gold docs"
    assert n_drop == n_keep, "no-gold build must hold doc-count constant (k + len(golden))"


def test_make_examples_items_have_valid_answer_span(stub_tok, toy_rows):
    for item in R.make_examples(toy_rows, keep_p=1.0, k=4, tok=stub_tok, seed=0):
        assert item["prompt_len"] >= 1
        assert item["input_ids"].numel() > item["prompt_len"], "every emitted item predicts >=1 answer token"


def test_make_examples_carries_ids(stub_tok, toy_rows):
    examples = R.make_examples(toy_rows, keep_p=1.0, k=4, tok=stub_tok, seed=0)
    assert [e.get("id") for e in examples] == [r["id"] for r in toy_rows]


def test_make_examples_keep_p_is_reproducible_for_seed(stub_tok, toy_rows):
    a = R.make_examples(toy_rows, keep_p=0.5, k=4, tok=stub_tok, seed=7)
    b = R.make_examples(toy_rows, keep_p=0.5, k=4, tok=stub_tok, seed=7)
    assert len(a) == len(b)
    assert all(torch.equal(x["input_ids"], y["input_ids"]) for x, y in zip(a, b)), \
        "per-(seed,idx) rng → reproducible keep/drop decisions"


def test_make_examples_does_not_mutate_rows(stub_tok, toy_rows):
    snapshot = [(r["id"], len(r["golden"]), len(r["distract"])) for r in toy_rows]
    R.make_examples(toy_rows, keep_p=1.0, k=4, tok=stub_tok, seed=0)
    after = [(r["id"], len(r["golden"]), len(r["distract"])) for r in toy_rows]
    assert snapshot == after, "make_examples must not mutate the input rows"


# --------------------------------------------------------------------------------------------------
# (4) make_eval_condition — E1/E2/E3 + no answer leak
# --------------------------------------------------------------------------------------------------
def test_eval_condition_e1_is_gold_only(stub_tok):
    """E1 = gold-only, ZERO distractors."""
    row = make_row(0, n_gold=1, n_dist=6)
    it = R.make_eval_condition([row], "E1", stub_tok)[0]
    seq = it["input_ids"].tolist()
    assert _doc_count(stub_tok, seq) == 1, "E1 has exactly the gold docs and no distractors"
    assert _is_subseq(_gold_title_tok(stub_tok, row), seq), "E1 must contain the gold doc"


def test_eval_condition_e2_is_gold_plus_k_distract(stub_tok):
    """E2 = gold + K_DISTRACT distractors."""
    row = make_row(0, n_gold=1, n_dist=6)
    it = R.make_eval_condition([row], "E2", stub_tok)[0]
    seq = it["input_ids"].tolist()
    assert _doc_count(stub_tok, seq) == 1 + R.K_DISTRACT, "E2 = gold + K_DISTRACT distractors"
    assert _is_subseq(_gold_title_tok(stub_tok, row), seq), "E2 must still contain the gold doc"


def test_eval_condition_e3_is_no_gold_doc_count_matched(stub_tok):
    """E3 = no gold, doc-count matched to E2 (K_DISTRACT + len(golden) distractors)."""
    row = make_row(0, n_gold=2, n_dist=10)
    e2 = R.make_eval_condition([row], "E2", stub_tok)[0]
    e3 = R.make_eval_condition([row], "E3", stub_tok)[0]
    n2 = _doc_count(stub_tok, e2["input_ids"].tolist())
    n3 = _doc_count(stub_tok, e3["input_ids"].tolist())
    assert n3 == n2, "E3 doc-count must match E2 (slope must compare equal-length contexts)"
    assert n3 == R.K_DISTRACT + len(row["golden"]), "E3 = K_DISTRACT + len(golden) distractors"
    assert not _is_subseq(_gold_title_tok(stub_tok, row), e3["input_ids"].tolist()), "E3 has NO gold doc"


def test_eval_condition_e3_does_not_leak_gold_answer_text():
    """CRITICAL leak gate: the gold ANSWER text must NOT appear in E3's distractor documents. The answer
    appears exactly once in E3 (the supervised target only); gold-bearing conditions show it >once."""
    tok = StubTok()
    sentinel = "Zqxw"  # unique token sequence; lives only in the gold paragraph + answer field
    row = {"id": "q0", "question": "who?", "answer": sentinel,
           "golden": [("GoldTitle", f"the secret is {sentinel} indeed {sentinel}.")],
           "distract": [(f"Dst{d}", f"completely unrelated text block {d}.") for d in range(8)],
           "gold_sents": [f"the secret is {sentinel}."]}
    stok = _tok_ids(tok, sentinel)
    e3 = R.make_eval_condition([row], "E3", tok)[0]
    e2 = R.make_eval_condition([row], "E2", tok)[0]
    n_e3 = _count_subseq(stok, e3["input_ids"].tolist())
    n_e2 = _count_subseq(stok, e2["input_ids"].tolist())
    assert n_e3 == 1, "E3 must contain the answer ONLY as the target — no gold-text leak into distractors"
    assert n_e2 > n_e3, "E2 (gold present) contains the answer text more than once (sanity for the leak probe)"


def test_eval_condition_carries_ids(stub_tok, toy_rows):
    for mode in ("E1", "E2", "E3"):
        out = R.make_eval_condition(toy_rows, mode, stub_tok)
        assert [e.get("id") for e in out] == [r["id"] for r in toy_rows], f"{mode} must carry ids"


def test_eval_condition_items_have_valid_answer_span(stub_tok, toy_rows):
    for mode in ("E1", "E2", "E3"):
        for item in R.make_eval_condition(toy_rows, mode, stub_tok):
            assert item["prompt_len"] >= 1 and item["input_ids"].numel() > item["prompt_len"]


# --------------------------------------------------------------------------------------------------
# (5) determinism
# --------------------------------------------------------------------------------------------------
def test_eval_condition_byte_identical_across_rebuilds(stub_tok, toy_rows):
    a = R.make_eval_condition(toy_rows, "E2", stub_tok)
    b = R.make_eval_condition(toy_rows, "E2", stub_tok)
    assert len(a) == len(b)
    for x, y in zip(a, b):
        assert torch.equal(x["input_ids"], y["input_ids"]), "frozen eval set must rebuild byte-identical"
        assert x.get("id") == y.get("id")


def test_eval_condition_determinism_all_modes(stub_tok, toy_rows):
    for mode in ("E1", "E2", "E3"):
        a = R.make_eval_condition(toy_rows, mode, stub_tok)
        b = R.make_eval_condition(toy_rows, mode, stub_tok)
        assert all(torch.equal(x["input_ids"], y["input_ids"]) for x, y in zip(a, b)), \
            f"{mode} eval build must be deterministic"


def test_eval_condition_distinct_modes_differ(stub_tok, toy_rows):
    """Sanity: E1, E2, E3 actually produce different contexts for the same rows."""
    e1 = R.make_eval_condition(toy_rows, "E1", stub_tok)
    e2 = R.make_eval_condition(toy_rows, "E2", stub_tok)
    differ = any(not torch.equal(a["input_ids"], b["input_ids"]) for a, b in zip(e1, e2))
    assert differ, "E1 (gold-only) and E2 (gold+distractors) must differ"


# --------------------------------------------------------------------------------------------------
# (6) masked_ce
# --------------------------------------------------------------------------------------------------
def test_masked_ce_returns_none_when_no_answer_token():
    """prompt_len == len(ids): the causal-shifted mask (>= prompt_len-1 over the T-1 targets) is empty → None."""
    logits = torch.randn(6, 96)
    ids = torch.arange(6)
    assert R.masked_ce(logits, ids, prompt_len=6) is None


def test_masked_ce_returns_none_when_prompt_len_past_end():
    logits = torch.randn(6, 96)
    ids = torch.arange(6)
    assert R.masked_ce(logits, ids, prompt_len=7) is None


def test_masked_ce_returns_scalar_loss_over_answer_span():
    logits = torch.randn(6, 96)
    ids = torch.arange(6)
    loss = R.masked_ce(logits, ids, prompt_len=3)
    assert loss is not None
    assert loss.dim() == 0 and torch.isfinite(loss), "CE over the answer span is a finite scalar"


def test_masked_ce_covers_only_answer_span():
    """Loss over a 1-token answer span must equal the plain CE of that single (logit, target) pair —
    proving prompt tokens are excluded from the objective."""
    torch.manual_seed(1)
    logits = torch.randn(6, 96)
    ids = torch.randint(0, 96, (6,))
    plen = 5  # mask = arange(5) >= 4 → only the last target (index 4 → predicts ids[5])
    got = R.masked_ce(logits, ids, prompt_len=plen)
    expected = torch.nn.functional.cross_entropy(
        logits[4].unsqueeze(0), ids[5].unsqueeze(0), reduction="mean")
    assert torch.allclose(got, expected, atol=1e-5), "masked_ce must score ONLY the answer span"


def test_masked_ce_full_span_matches_unmasked_ce():
    """prompt_len=1 covers the entire shifted sequence; should equal the unmasked next-token CE."""
    torch.manual_seed(2)
    logits = torch.randn(5, 96)
    ids = torch.randint(0, 96, (5,))
    got = R.masked_ce(logits, ids, prompt_len=1)
    expected = torch.nn.functional.cross_entropy(logits[:-1], ids[1:], reduction="mean")
    assert torch.allclose(got, expected, atol=1e-6)


def test_masked_ce_uses_causal_shift():
    """The target for position t is ids[t+1] (project causal-shift convention). A perfectly-confident,
    correctly-shifted logit set yields ~0 loss; a mis-shift yields a large loss."""
    V = 96
    ids = torch.tensor([5, 9, 13, 21, 30])
    logits = torch.full((5, V), -20.0)
    for t in range(4):  # position t should predict ids[t+1]
        logits[t, ids[t + 1]] = 20.0
    loss = R.masked_ce(logits, ids, prompt_len=1)
    assert float(loss) < 1e-3, "correctly causal-shifted confident logits → ~0 masked CE"


# --------------------------------------------------------------------------------------------------
# (7) eval_nll
# --------------------------------------------------------------------------------------------------
def test_eval_nll_returns_triplet(tiny_mamba, eval_examples, monkeypatch):
    monkeypatch.setattr(R, "DEV", "cpu")  # fixture model lives on CPU; eval_nll co-locates ids via DEV
    out = R.eval_nll(tiny_mamba, eval_examples())
    assert isinstance(out, tuple) and len(out) == 3, "eval_nll returns (nll, acc, skip)"
    nll, acc, skip = out
    assert isinstance(skip, int)


def test_eval_nll_finite_examples_give_finite_nll_and_no_skip(tiny_mamba, eval_examples, monkeypatch):
    monkeypatch.setattr(R, "DEV", "cpu")
    nll, acc, skip = R.eval_nll(tiny_mamba, eval_examples(n=6, T=40, plen=30))
    assert skip == 0, "finite-logit examples must not be skipped"
    assert nll == nll and nll != float("inf"), "nll over finite examples is finite"
    assert 0.0 <= acc <= 1.0, "accuracy is a fraction in [0,1]"


def test_eval_nll_skips_non_finite_logits(eval_examples, monkeypatch):
    """A student that emits non-finite logits must be skipped (never poison the slope/NLL)."""
    monkeypatch.setattr(R, "DEV", "cpu")

    class InfStudent:
        def eval(self): ...
        def train(self): ...
        def run_twin(self, ids, collect_ssm=True):
            T = ids.shape[0]
            return torch.full((T, 96), float("inf")), []

    examples = eval_examples(n=4)
    nll, acc, skip = R.eval_nll(InfStudent(), examples)
    assert skip == len(examples), "every non-finite-logit example must be counted as skipped"
    assert nll != nll, "no usable tokens → nll is nan"
    assert acc == 0.0


def test_eval_nll_mixed_finite_and_non_finite(tiny_mamba, eval_examples, monkeypatch):
    """Only the non-finite examples are skipped; finite ones still contribute."""
    monkeypatch.setattr(R, "DEV", "cpu")
    real_run = tiny_mamba.run_twin
    state = {"i": 0}

    def flaky(ids, collect_ssm=True):
        logits, extra = real_run(ids, collect_ssm=collect_ssm)
        i = state["i"]
        state["i"] += 1
        if i % 2 == 1:  # poison every other example
            return torch.full_like(logits, float("inf")), extra
        return logits, extra

    monkeypatch.setattr(tiny_mamba, "run_twin", flaky)
    examples = eval_examples(n=4, T=40, plen=30)
    nll, acc, skip = R.eval_nll(tiny_mamba, examples)
    assert skip == 2, "exactly the 2 poisoned examples are skipped"
    assert nll == nll, "the 2 finite examples still produce a finite nll"


def test_eval_nll_no_answer_token_examples_yield_nan_without_skip(tiny_mamba, monkeypatch):
    """An example whose prompt_len leaves no answer token contributes no tokens (mask empty) but is NOT
    counted as a non-finite skip — it simply adds nothing."""
    monkeypatch.setattr(R, "DEV", "cpu")
    examples = [{"id": "e0", "input_ids": torch.randint(0, 96, (10,)), "prompt_len": 10}]
    nll, acc, skip = R.eval_nll(tiny_mamba, examples)
    assert skip == 0, "an empty-answer example is not a non-finite skip"
    assert nll != nll, "no scored tokens → nan nll"
    assert acc == 0.0


def test_eval_nll_accuracy_perfect_when_model_is_oracle(eval_examples, monkeypatch):
    """A student whose argmax always equals the next token must score acc == 1.0 over the answer span."""
    monkeypatch.setattr(R, "DEV", "cpu")
    examples = eval_examples(n=3, T=20, plen=12)

    class OracleStudent:
        def eval(self): ...
        def train(self): ...
        def run_twin(self, ids, collect_ssm=True):
            T = ids.shape[0]
            logits = torch.full((T, 96), -10.0)
            # position t predicts ids[t+1]; make that the confident argmax
            for t in range(T - 1):
                logits[t, ids[t + 1]] = 10.0
            return logits, []

    nll, acc, skip = R.eval_nll(OracleStudent(), examples)
    assert skip == 0
    assert acc == pytest.approx(1.0), "an oracle student scores perfect teacher-forced answer accuracy"
