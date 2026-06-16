"""Shared fixtures for the Mamba-3 cloud-distill regression suite.

Run the whole suite:  ~/.venvs/coreai-cv/bin/python -m pytest Tools/tests -q
These tests are CPU-only, no network, no Granite, no coreai — they pin the audited invariants of the distill pipeline
(data builder, KD loss, curriculum, eval gates, forward consistency, checkpoint/resume, deploy carry) so a regression
can't silently make the cloud run unsafe. Heavy/real-Granite paths are covered by the standalone e2e, not here.
"""
from __future__ import annotations

import os
import sys

import pytest
import torch

TOOLS = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if TOOLS not in sys.path:
    sys.path.insert(0, TOOLS)


@pytest.fixture(autouse=True)
def _det():
    """Determinism for every test."""
    torch.manual_seed(0)
    yield


class StubTok:
    """Char-level stub tokenizer: __call__ for to_ids/make_examples, decode for generate_and_score."""
    bos_token_id = 1
    eos_token_id = 2

    def __call__(self, s, add_special_tokens=True):
        return type("E", (), {"input_ids": [ord(c) % 500 + 3 for c in s]})

    def decode(self, ids):
        return " ".join(str(int(i)) for i in ids)


class StubTeacher:
    """Returns random logits [1, T, V] — exercises teacher-forward eval paths without Granite."""
    def __init__(self, vocab):
        self.vocab = vocab

    def __call__(self, ids):
        T = ids.shape[1]
        return type("O", (), {"logits": torch.randn(1, T, self.vocab)})


@pytest.fixture
def stub_tok():
    return StubTok()


@pytest.fixture
def vocab():
    return 96


@pytest.fixture
def tiny_mamba(vocab):
    import mamba3_trainable as MT
    return MT.M(vocab, 3).eval()


@pytest.fixture
def tiny_hybrid(vocab):
    """L=8 → MLA at position 6 included (6<8): exercises BOTH Mamba and MLA layers + run_ref/run_twin."""
    import mamba3_hybrid as HY
    return HY.HybridM(vocab, 8).eval()


@pytest.fixture
def stub_teacher(vocab):
    return StubTeacher(vocab)


def _row(i, n_gold=1, n_dist=6):
    """A build_example-shaped HotpotQA example (the make_examples / make_eval_condition input)."""
    return {"id": f"q{i}", "question": f"who did thing number {i}?", "answer": f"answer{i}",
            "golden": [(f"G{i}_{g}", f"gold paragraph {i} part {g} with the answer{i} fact.") for g in range(n_gold)],
            "distract": [(f"D{i}_{d}", f"distractor paragraph {i} number {d} unrelated text.") for d in range(n_dist)],
            "gold_sents": [f"gold paragraph {i} part 0 with the answer{i} fact."]}


@pytest.fixture
def toy_rows():
    return [_row(i) for i in range(8)]


def make_row(i, **kw):
    return _row(i, **kw)


@pytest.fixture
def eval_examples(vocab):
    """Frozen-eval-set-shaped examples: {id, input_ids, prompt_len} (what eval_nll / fidelity / generate consume)."""
    def _mk(n=6, T=40, plen=30):
        return [{"id": f"e{i}", "input_ids": torch.randint(0, vocab, (T,)), "prompt_len": plen} for i in range(n)]
    return _mk
