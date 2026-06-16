"""Regression tests for mamba3_curriculum_scheduler.CurriculumScheduler.

Pins the audited invariants of the competence-driven, RAFT-staged sampler that replaces the static
ORDER=curriculum sort in the cloud distill run. Pure Python + NumPy, CPU-only, no model/data/network.

Invariants covered:
 (1) competence(step): monotonic non-decreasing, in [0,1], schedule-specific c(0)/c(num_steps).
 (2) _candidates(step) is a TRUE QUANTILE: pool-fraction tracks competence on BOTH uniform and right-skewed
     (exponential) difficulty (the audit fix — the old value-gate was inert on skew); always >=1 and <=N.
 (3) sample(step): valid index in [0,N); replay_prob path draws strictly from the easy_pool.
 (4) raft_params: gold-heavy early (p=1,k=0) -> distractor-heavy late (p->raft_final_p, k->raft_final_k), monotone.
 (5) state_dict/load_state_dict: round-trip yields the IDENTICAL next sample() (rng resume-safe).
 (6) ValueError on empty / num_steps<=0 / non-finite; degenerate all-equal difficulty does not crash.
"""
from __future__ import annotations

import json
import math

import numpy as np
import pytest

from mamba3_curriculum_scheduler import (
    CurriculumConfig,
    CurriculumScheduler,
    compute_difficulty,
)


# ---------- helpers ----------

def _uniform(n=500, seed=0):
    return np.random.default_rng(seed).random(n) * 5.0


def _skew(n=500, seed=1):
    """Right-skewed (exponential) difficulty — the case where the old value-gate was ~inert."""
    return np.random.default_rng(seed).exponential(1.0, n)


# =====================================================================================
# (1) competence(step): monotone non-decreasing, in [0,1], schedule-specific endpoints
# =====================================================================================

@pytest.mark.parametrize("schedule", ["root_p", "linear", "step"])
def test_competence_in_unit_interval(schedule):
    cfg = CurriculumConfig(pace_schedule=schedule)
    s = CurriculumScheduler(_uniform(200), num_steps=300, cfg=cfg)
    for t in range(0, 360, 3):
        c = s.competence(t)
        assert 0.0 <= c <= 1.0, f"{schedule} c({t})={c} out of [0,1]"


@pytest.mark.parametrize("schedule", ["root_p", "linear", "step"])
def test_competence_monotone_nondecreasing(schedule):
    cfg = CurriculumConfig(pace_schedule=schedule)
    s = CurriculumScheduler(_uniform(120), num_steps=400, cfg=cfg)
    prev = -1.0
    for t in range(0, 500):
        c = s.competence(t)
        assert c >= prev - 1e-12, f"{schedule} not monotone at step {t}: {c} < {prev}"
        prev = c


def test_competence_root_p_starts_at_c0():
    # root_p: c(0) = (c0**p)**(1/p) = c0  -> exactly pace_c0, satisfying c(0) >= pace_c0.
    cfg = CurriculumConfig(pace_schedule="root_p", pace_c0=0.1, pace_p=2.0)
    s = CurriculumScheduler(_uniform(), num_steps=1000, cfg=cfg)
    assert s.competence(0) == pytest.approx(cfg.pace_c0, abs=1e-9)
    assert s.competence(0) >= cfg.pace_c0 - 1e-12


def test_competence_step_starts_at_first_tier():
    # step schedule first tier = 0.2 (>= default pace_c0 = 0.1).
    cfg = CurriculumConfig(pace_schedule="step")
    s = CurriculumScheduler(_uniform(), num_steps=1000, cfg=cfg)
    assert s.competence(0) == pytest.approx(0.2)
    assert s.competence(0) >= cfg.pace_c0


def test_competence_step_tier_boundaries():
    # f<0.25->0.2, f<0.5->0.4, f<0.75->0.7, else 1.0 (f = step/num_steps).
    cfg = CurriculumConfig(pace_schedule="step")
    s = CurriculumScheduler(_uniform(), num_steps=1000, cfg=cfg)
    assert s.competence(0) == pytest.approx(0.2)
    assert s.competence(249) == pytest.approx(0.2)
    assert s.competence(250) == pytest.approx(0.4)
    assert s.competence(499) == pytest.approx(0.4)
    assert s.competence(500) == pytest.approx(0.7)
    assert s.competence(749) == pytest.approx(0.7)
    assert s.competence(750) == pytest.approx(1.0)
    assert s.competence(999) == pytest.approx(1.0)


def test_competence_linear_starts_at_zero():
    # linear: c(0) = 0 (this is BELOW pace_c0 — the >=pace_c0 floor is applied by difficulty_quantile, not here).
    cfg = CurriculumConfig(pace_schedule="linear")
    s = CurriculumScheduler(_uniform(), num_steps=1000, cfg=cfg)
    assert s.competence(0) == pytest.approx(0.0)


@pytest.mark.parametrize("schedule", ["root_p", "linear", "step"])
def test_competence_reaches_one_at_num_steps(schedule):
    cfg = CurriculumConfig(pace_schedule=schedule)
    s = CurriculumScheduler(_uniform(), num_steps=1000, cfg=cfg)
    assert s.competence(1000) == pytest.approx(1.0)


@pytest.mark.parametrize("schedule", ["root_p", "linear", "step"])
def test_competence_clamped_beyond_num_steps(schedule):
    cfg = CurriculumConfig(pace_schedule=schedule)
    s = CurriculumScheduler(_uniform(), num_steps=500, cfg=cfg)
    assert s.competence(10_000) == pytest.approx(1.0)
    assert s.competence(10_000) <= 1.0


def test_competence_rises_strictly_overall_root_p():
    cfg = CurriculumConfig(pace_schedule="root_p")
    s = CurriculumScheduler(_uniform(), num_steps=1000, cfg=cfg)
    assert s.competence(0) < s.competence(1000)


def test_difficulty_quantile_floored_at_c0():
    # difficulty_quantile = max(pace_c0, competence). For linear, competence(0)=0 but quantile floors to pace_c0.
    cfg = CurriculumConfig(pace_schedule="linear", pace_c0=0.1)
    s = CurriculumScheduler(_uniform(), num_steps=1000, cfg=cfg)
    assert s.difficulty_quantile(0) == pytest.approx(cfg.pace_c0)
    assert s.difficulty_quantile(0) >= cfg.pace_c0


# =====================================================================================
# (2) _candidates is a TRUE QUANTILE
# =====================================================================================

def _frac(s, step):
    return len(s._candidates(step)) / s.N


def test_candidates_fraction_tracks_competence_uniform():
    s = CurriculumScheduler(_uniform(), num_steps=1000)
    early = _frac(s, 1)
    late = _frac(s, 900)
    # early pool ~= floor c0 fraction (small); late pool ~= competence (most of the set).
    assert early <= 0.25, f"early pool too large: {early}"
    assert late >= 0.80, f"late pool too small: {late}"
    assert late > early


def test_candidates_fraction_tracks_competence_skew():
    # AUDIT FIX: on right-skewed difficulty the OLD value-gate was inert (pool ~85% at step 0).
    # The rank/quantile gate must give the SAME easy->hard ramp regardless of distribution shape.
    s = CurriculumScheduler(_skew(), num_steps=1000)
    early = _frac(s, 1)
    late = _frac(s, 900)
    assert early <= 0.25, f"skew early pool too large (value-gate regression?): {early}"
    assert late >= 0.80, f"skew late pool too small: {late}"
    assert late > early


def test_candidates_fraction_matches_quantile_value():
    # The pool fraction must equal ceil(q*N)/N for the gating quantile q — a true rank gate, distribution-agnostic.
    for arr in (_uniform(), _skew()):
        s = CurriculumScheduler(arr, num_steps=1000)
        for step in (0, 1, 100, 500, 900, 1000):
            q = s.difficulty_quantile(step)
            expected = max(1, int(math.ceil(q * s.N))) / s.N
            assert _frac(s, step) == pytest.approx(expected)


def test_candidates_fraction_identical_uniform_vs_skew():
    # The rank gate depends only on the gating quantile (a function of step), NOT on difficulty values.
    su = CurriculumScheduler(_uniform(), num_steps=1000)
    ss = CurriculumScheduler(_skew(), num_steps=1000)
    for step in (0, 1, 50, 250, 500, 750, 1000):
        assert _frac(su, step) == pytest.approx(_frac(ss, step))


def test_candidates_monotone_nondecreasing_size():
    s = CurriculumScheduler(_uniform(), num_steps=1000)
    prev = 0
    for step in range(0, 1100, 10):
        sz = len(s._candidates(step))
        assert sz >= prev, f"candidate pool shrank at step {step}: {sz} < {prev}"
        prev = sz


def test_candidates_bounds_ge_one_le_n():
    s = CurriculumScheduler(_uniform(), num_steps=1000)
    for step in range(0, 1100, 5):
        cand = s._candidates(step)
        assert 1 <= len(cand) <= s.N


def test_candidates_late_covers_full_set():
    s = CurriculumScheduler(_uniform(), num_steps=1000)
    assert len(s._candidates(1000)) == s.N
    assert len(s._candidates(5000)) == s.N


def test_candidates_are_easiest_prefix():
    # The pool must be the easiest examples (ascending-difficulty prefix of sort_idx), not arbitrary indices.
    s = CurriculumScheduler(_uniform(), num_steps=1000)
    for step in (10, 300, 700):
        cand = s._candidates(step)
        cut = len(cand)
        assert np.array_equal(cand, s.sort_idx[:cut])
        # every candidate is no harder than the hardest candidate, and easier than anything excluded
        if cut < s.N:
            max_in = s.diff[cand].max()
            min_out = s.diff[s.sort_idx[cut:]].min()
            assert max_in <= min_out + 1e-12


# =====================================================================================
# (3) sample(step): valid index, replay path draws from easy_pool
# =====================================================================================

def test_sample_returns_valid_index():
    s = CurriculumScheduler(_uniform(), num_steps=1000)
    for step in range(0, 1000, 7):
        idx = s.sample(step)
        assert isinstance(idx, int)
        assert 0 <= idx < s.N


def test_sample_only_draws_from_candidate_pool_when_no_replay():
    # With replay disabled, every draw must be inside the competence-gated candidate prefix.
    s = CurriculumScheduler(_uniform(), num_steps=1000, cfg=CurriculumConfig(replay_prob=0.0))
    step = 100
    pool = set(int(x) for x in s._candidates(step))
    for _ in range(300):
        assert s.sample(step) in pool


def test_replay_path_draws_strictly_from_easy_pool():
    # replay_prob=1.0 forces the anti-forgetting branch every call -> all draws from easy_pool.
    s = CurriculumScheduler(_uniform(), num_steps=1000, cfg=CurriculumConfig(replay_prob=1.0))
    easy = set(int(x) for x in s.easy_pool)
    assert 0 < len(easy) <= s.N
    for _ in range(300):
        assert s.sample(500) in easy


def test_easy_pool_is_easiest_fraction():
    cfg = CurriculumConfig(replay_easy_frac=0.20)
    s = CurriculumScheduler(_uniform(), num_steps=1000, cfg=cfg)
    expected_len = max(1, math.ceil(cfg.replay_easy_frac * s.N))
    assert len(s.easy_pool) == expected_len
    assert np.array_equal(s.easy_pool, s.sort_idx[:expected_len])
    # the easy pool is the genuinely easiest examples
    assert s.diff[s.easy_pool].max() <= s.diff[s.sort_idx[expected_len:]].min() + 1e-12


def test_sample_easy_difficulty_rises_with_competence():
    # Mean sampled (normalized) difficulty must rise from early to late training.
    s = CurriculumScheduler(_uniform(), num_steps=1000)
    early = np.mean([s.diff[s.sample(50)] for _ in range(500)])
    late = np.mean([s.diff[s.sample(950)] for _ in range(500)])
    assert late > early + 0.05, f"sampled difficulty did not rise: early={early} late={late}"


# =====================================================================================
# (4) raft_params staging: gold-heavy early -> distractor-heavy late, monotone
# =====================================================================================

def test_raft_gold_heavy_before_t_e1():
    cfg = CurriculumConfig(raft_e1_frac=0.10)
    s = CurriculumScheduler(_uniform(), num_steps=1000, cfg=cfg)
    assert s.t_e1 == 100
    for step in range(0, s.t_e1):
        p, k = s.raft_params(step)
        assert p == 1.0
        assert k == 0


def test_raft_at_t_e1_is_still_gold():
    # At step == t_e1 progress is 0 -> (1.0, 0).
    s = CurriculumScheduler(_uniform(), num_steps=1000)
    p, k = s.raft_params(s.t_e1)
    assert p == pytest.approx(1.0)
    assert k == 0


def test_raft_final_approaches_config_targets():
    cfg = CurriculumConfig(raft_final_p=0.8, raft_final_k=4)
    s = CurriculumScheduler(_uniform(), num_steps=1000, cfg=cfg)
    p, k = s.raft_params(1000)
    assert p == pytest.approx(cfg.raft_final_p)
    assert k == cfg.raft_final_k


def test_raft_p_monotone_nonincreasing():
    # P_GOLDEN ramps DOWN: 1.0 -> raft_final_p.
    s = CurriculumScheduler(_uniform(), num_steps=1000)
    prev = 2.0
    for step in range(0, 1001, 5):
        p, _ = s.raft_params(step)
        assert p <= prev + 1e-12, f"p_golden increased at step {step}: {p} > {prev}"
        prev = p


def test_raft_k_monotone_nondecreasing():
    # #distractors ramps UP: 0 -> raft_final_k.
    s = CurriculumScheduler(_uniform(), num_steps=1000)
    prev = -1
    for step in range(0, 1001, 5):
        _, k = s.raft_params(step)
        assert k >= prev, f"k_distractors decreased at step {step}: {k} < {prev}"
        prev = k


def test_raft_endpoints_bracket_the_staging():
    cfg = CurriculumConfig(raft_final_p=0.8, raft_final_k=4)
    s = CurriculumScheduler(_uniform(), num_steps=1000, cfg=cfg)
    p0, k0 = s.raft_params(10)
    p1, k1 = s.raft_params(990)
    assert p0 >= p1            # gold-heavy early
    assert k0 <= k1            # distractor-heavy late
    assert p0 == 1.0 and k0 == 0
    assert k1 == cfg.raft_final_k


def test_raft_k_within_bounds():
    cfg = CurriculumConfig(raft_final_k=4)
    s = CurriculumScheduler(_uniform(), num_steps=1000, cfg=cfg)
    for step in range(0, 1001, 3):
        _, k = s.raft_params(step)
        assert 0 <= k <= cfg.raft_final_k


def test_raft_p_within_bounds():
    cfg = CurriculumConfig(raft_final_p=0.8)
    s = CurriculumScheduler(_uniform(), num_steps=1000, cfg=cfg)
    for step in range(0, 1001, 3):
        p, _ = s.raft_params(step)
        assert cfg.raft_final_p - 1e-9 <= p <= 1.0 + 1e-9


# =====================================================================================
# (5) state_dict / load_state_dict: rng round-trip is resume-safe
# =====================================================================================

def test_state_dict_round_trip_identical_next_sample():
    diff = _uniform()
    a = CurriculumScheduler(diff, num_steps=1000)
    a.sample(100)                               # advance a's rng off its initial state
    b = CurriculumScheduler(diff, num_steps=1000)
    b.load_state_dict(a.state_dict())
    # restored rng -> identical subsequent draw sequence
    for _ in range(20):
        assert a.sample(500) == b.sample(500)


def test_state_dict_round_trip_through_json():
    # The resume checkpoint is serialized to JSON on disk; the list->tuple re-hydration in load_state_dict
    # must survive the round-trip and still reproduce the rng exactly.
    diff = _uniform()
    a = CurriculumScheduler(diff, num_steps=1000)
    a.sample(7)
    sd = json.loads(json.dumps(a.state_dict()))
    b = CurriculumScheduler(diff, num_steps=1000)
    b.load_state_dict(sd)
    for _ in range(20):
        assert a.sample(321) == b.sample(321)


def test_state_dict_contains_expected_keys():
    s = CurriculumScheduler(_uniform(), num_steps=1000)
    sd = s.state_dict()
    assert set(sd.keys()) == {"cfg", "num_steps", "rng"}
    assert sd["num_steps"] == 1000
    assert sd["cfg"]["pace_schedule"] == "root_p"


def test_fresh_schedulers_same_seed_match_without_load():
    # Two schedulers built from the same seed must produce the identical draw sequence (deterministic seeding).
    diff = _uniform()
    a = CurriculumScheduler(diff, num_steps=1000)
    b = CurriculumScheduler(diff, num_steps=1000)
    for step in range(0, 200, 11):
        assert a.sample(step) == b.sample(step)


def test_different_seed_diverges():
    diff = _uniform()
    a = CurriculumScheduler(diff, num_steps=1000, cfg=CurriculumConfig(seed=123))
    b = CurriculumScheduler(diff, num_steps=1000, cfg=CurriculumConfig(seed=999))
    draws_a = [a.sample(s) for s in range(0, 400)]
    draws_b = [b.sample(s) for s in range(0, 400)]
    assert draws_a != draws_b


def test_load_state_dict_resyncs_a_diverged_scheduler():
    # b runs ahead independently, then loads a's state -> must re-converge to a's stream.
    diff = _uniform()
    a = CurriculumScheduler(diff, num_steps=1000)
    b = CurriculumScheduler(diff, num_steps=1000)
    for _ in range(50):
        b.sample(400)                           # diverge b's rng
    b.load_state_dict(a.state_dict())
    for _ in range(15):
        assert a.sample(250) == b.sample(250)


# =====================================================================================
# (6) input validation + degenerate difficulty
# =====================================================================================

def test_empty_difficulties_raises():
    with pytest.raises(ValueError):
        CurriculumScheduler([], num_steps=10)


def test_empty_numpy_difficulties_raises():
    with pytest.raises(ValueError):
        CurriculumScheduler(np.array([]), num_steps=10)


@pytest.mark.parametrize("ns", [0, -1, -100])
def test_nonpositive_num_steps_raises(ns):
    with pytest.raises(ValueError):
        CurriculumScheduler([1.0, 2.0, 3.0], num_steps=ns)


def test_inf_difficulty_raises():
    with pytest.raises(ValueError):
        CurriculumScheduler([1.0, np.inf, 2.0], num_steps=10)


def test_nan_difficulty_raises():
    with pytest.raises(ValueError):
        CurriculumScheduler([np.nan, 1.0, 2.0], num_steps=10)


def test_neg_inf_difficulty_raises():
    with pytest.raises(ValueError):
        CurriculumScheduler([-np.inf, 1.0], num_steps=10)


def test_all_equal_difficulty_does_not_crash():
    # hi == lo path: normalized difficulty is set to a constant 0.5 (no divide-by-zero).
    eq = np.full(50, 3.7)
    s = CurriculumScheduler(eq, num_steps=100)
    assert np.allclose(s.diff, 0.5)
    # sampling, candidates, raft all still operate
    for step in (0, 50, 99):
        idx = s.sample(step)
        assert 0 <= idx < s.N
        assert 1 <= len(s._candidates(step)) <= s.N
        p, k = s.raft_params(step)
        assert 0.0 <= p <= 1.0 and k >= 0


def test_single_example_dataset():
    # N == 1: easy_pool, candidates, sample all collapse to index 0 without crashing.
    s = CurriculumScheduler([2.0], num_steps=10)
    assert s.N == 1
    assert len(s.easy_pool) == 1
    for step in (0, 5, 10):
        assert len(s._candidates(step)) == 1
        assert s.sample(step) == 0


def test_two_example_dataset_candidates_floor_at_one():
    # tiny N: the ceil-based cut must still yield at least 1 candidate early.
    s = CurriculumScheduler([0.0, 5.0], num_steps=100)
    assert s.N == 2
    assert len(s._candidates(0)) >= 1
    assert len(s._candidates(100)) == 2


# =====================================================================================
# compute_difficulty: the per-example raw score that feeds the scheduler
# =====================================================================================

def test_compute_difficulty_monotone_in_each_term():
    base = compute_difficulty(teacher_ce=1.0)
    assert compute_difficulty(teacher_ce=2.0) > base
    assert compute_difficulty(teacher_ce=1.0, teacher_entropy=1.0) > base
    assert compute_difficulty(teacher_ce=1.0, length=100) > base
    assert compute_difficulty(teacher_ce=1.0, n_distractors=3) > base
    assert compute_difficulty(teacher_ce=1.0, answer_rarity=2.0) > base


def test_compute_difficulty_weighted_sum_formula():
    ce, ent, length, nd, rar = 1.5, 0.5, 100, 4, 0.7
    w = (1.0, 0.3, 0.15, 0.4, 0.2)
    expected = (w[0] * ce + w[1] * ent + w[2] * math.log1p(length) + w[3] * nd + w[4] * rar)
    assert compute_difficulty(ce, ent, length, nd, rar) == pytest.approx(expected)


def test_compute_difficulty_negative_length_clamped():
    # max(length, 0) guard: a negative length must not blow up log1p.
    val = compute_difficulty(teacher_ce=1.0, length=-5)
    assert val == pytest.approx(compute_difficulty(teacher_ce=1.0, length=0))


def test_compute_difficulty_output_feeds_scheduler():
    # End-to-end: scores from compute_difficulty are accepted and normalized by the scheduler.
    scores = [compute_difficulty(teacher_ce=float(i), length=10 * i, n_distractors=i % 4) for i in range(1, 30)]
    s = CurriculumScheduler(scores, num_steps=300)
    assert s.N == len(scores)
    assert s.diff.min() == pytest.approx(0.0)
    assert s.diff.max() == pytest.approx(1.0)
