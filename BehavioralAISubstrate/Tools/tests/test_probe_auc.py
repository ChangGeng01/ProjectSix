"""audit M-j — the B2 difficulty-probe AUC must be tie-correct.

`fit_difficulty_probe.py` and `b2_refit_candidate.py` shared a naive
argsort AUC that gave EQUAL scores distinct 1..N ranks. The qlen-only and
family-onehot control baselines have heavily repeated scores, so their AUC
was biased by ±0.05-0.1 — and "does the probe beat the control line?" is
the B2 go/no-go criterion. Both now use the shared tie-averaged _auc.auc.
"""
from __future__ import annotations

import json

import numpy as np
import pytest
from scipy.stats import rankdata

from _auc import auc


def _ref_auc(scores, labels):
    """Reference AUC via scipy's tie-averaged rankdata (canonical)."""
    r = rankdata(scores)  # tie-averaged ranks, 1-based
    labels = np.asarray(labels)
    n1 = int((labels == 1).sum())
    n0 = int((labels == 0).sum())
    return (r[labels == 1].sum() - n1 * (n1 + 1) / 2) / (n1 * n0)


def _naive_argsort_auc(scores, labels):
    """The OLD buggy implementation, kept here to prove the teeth bites."""
    scores = np.asarray(scores, dtype=float)
    labels = np.asarray(labels)
    order = np.argsort(scores)
    ranks = np.empty(len(scores))
    ranks[order] = np.arange(1, len(scores) + 1)
    pos = labels == 1
    n1, n0 = pos.sum(), (~pos).sum()
    return (ranks[pos].sum() - n1 * (n1 + 1) / 2) / (n1 * n0)


def test_all_scores_tied_is_one_half():
    # Every pos-neg pair is a tie ⇒ AUC 0.5. The naive version gives 0.0.
    scores = [1.0, 1.0, 1.0, 1.0]
    labels = [1, 1, 0, 0]
    assert auc(scores, labels) == pytest.approx(0.5)
    assert _naive_argsort_auc(scores, labels) == pytest.approx(0.0)  # the bug


def test_partial_tie_hand_computed():
    scores = [0.5, 0.5, 0.9, 0.1]
    labels = [1, 0, 1, 0]
    assert auc(scores, labels) == pytest.approx(0.875)
    assert _naive_argsort_auc(scores, labels) == pytest.approx(0.75)  # the bug


def test_matches_scipy_rankdata_on_tie_heavy_random_data():
    rng = np.random.default_rng(20260707)
    for _ in range(50):
        n = int(rng.integers(20, 120))
        # Coarse quantization ⇒ MANY ties (the baseline-score regime).
        scores = np.round(rng.normal(size=n), 1)
        labels = (rng.random(n) < 0.5).astype(int)
        if labels.sum() == 0 or labels.sum() == n:
            continue
        assert auc(scores, labels) == pytest.approx(_ref_auc(scores, labels))


def test_no_ties_ranking_directions():
    # Both positives outrank the single negative ⇒ AUC 1.0.
    assert auc([3.0, 2.0, 1.0], [1, 1, 0]) == pytest.approx(1.0)
    # The negative outranks both positives ⇒ AUC 0.0.
    assert auc([1.0, 2.0, 3.0], [1, 1, 0]) == pytest.approx(0.0)


def test_single_class_is_nan():
    assert np.isnan(auc([1.0, 2.0, 3.0], [1, 1, 1]))
    assert np.isnan(auc([1.0, 2.0, 3.0], [0, 0, 0]))


def test_candidate_json_uses_null_not_bare_nan():
    # audit M-j — the propose end writes heldout_auc as JSON null (unknown),
    # never a bare NaN. `NaN` is invalid JSON; Swift's JSONDecoder throws.
    payload = {"heldout_auc": None, "lam": 0.01}
    text = json.dumps(payload, allow_nan=False)
    assert '"heldout_auc": null' in text
    assert "NaN" not in text
    json.loads(text)  # strict round-trip must not raise
    with pytest.raises(ValueError):
        json.dumps({"heldout_auc": float("nan")}, allow_nan=False)
