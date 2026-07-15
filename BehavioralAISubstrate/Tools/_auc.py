"""Shared, tie-correct ROC-AUC (audit M-j).

`fit_difficulty_probe.py` and `b2_refit_candidate.py` each carried a naive
argsort-based AUC that assigned distinct 1..N ranks even to EQUAL scores.
Whenever a baseline's scores had repeated values — the qlen-only and
family-onehot controls do, heavily — the tied elements got arbitrary
ranks decided by argsort's ordering, biasing those baselines' AUC by
±0.05-0.1. Since "does the probe beat the control line?" is the B2 go/
no-go criterion, that bias could flip the decision.

This is the Mann-Whitney U AUC with tie-AVERAGED ranks (ties share their
mean rank) — the same semantics the already-correct `eval_probe_ood.py`
uses, kept numpy-based here because the probe callers pass numpy arrays.
"""
from __future__ import annotations

import numpy as np


def auc(scores, labels) -> float:
    """ROC-AUC via tie-averaged Mann-Whitney U.

    Returns NaN when either class is empty (a rank statistic is undefined
    with no positives or no negatives — never silently 0/1)."""
    scores = np.asarray(scores, dtype=np.float64)
    labels = np.asarray(labels)
    pos = labels == 1
    n1 = int(pos.sum())
    n0 = int((~pos).sum())
    if n1 == 0 or n0 == 0:
        return float("nan")
    # Tie-averaged 1-based ranks: within each run of equal scores every
    # element gets the mean of the ranks that run spans.
    order = np.argsort(scores, kind="mergesort")
    s_sorted = scores[order]
    ranks_sorted = np.empty(len(scores), dtype=np.float64)
    i = 0
    n = len(scores)
    while i < n:
        j = i
        while j < n and s_sorted[j] == s_sorted[i]:
            j += 1
        ranks_sorted[i:j] = (i + j + 1) / 2.0  # mean of 1-based ranks i+1..j
        i = j
    ranks = np.empty(n, dtype=np.float64)
    ranks[order] = ranks_sorted
    return float((ranks[pos].sum() - n1 * (n1 + 1) / 2.0) / (n1 * n0))
