"""Mature curriculum-distillation scheduler (the make-or-break: train the reader WELL). A dynamic, competence-driven,
RAFT-staged sampler that replaces the static `ORDER=curriculum` sort in mamba3_cloud_distill.py. Pure Python + NumPy —
testable on SYNTHETIC difficulties, no model/data/network. Frozen config; difficulties immutable.

- DIFFICULTY = weighted combine of teacher cross-entropy + teacher entropy + sequence length + #distractors + answer rarity.
- PACING c(t) ∈ [0,1]: competence ramps (linear / root_p / step); gates the difficulty QUANTILE the sampler may draw from.
- COMPETENCE SAMPLING: sample from examples with normalized difficulty ≤ c(t) (easy→hard as competence grows).
- ANTI-FORGETTING: with replay_prob, draw from the easy pool (interleave easy back in so the model doesn't forget).
- RAFT STAGING: the distractor schedule ramps gold-heavy (E1-like) → distractor-heavy (E3-like) over training.

Run: ~/.venvs/coreai-cv/bin/python Tools/mamba3_curriculum_scheduler.py   (CURRIC_SMOKE)
"""
from __future__ import annotations

import math
import random
from dataclasses import dataclass, asdict

import numpy as np


@dataclass(frozen=True)
class CurriculumConfig:
    pace_schedule: str = "root_p"        # linear | root_p | step
    pace_c0: float = 0.1                 # initial competence (root_p)
    pace_p: float = 2.0                  # root power (root_p)
    pace_T_frac: float = 1.0             # T_full = pace_T_frac * num_steps
    replay_prob: float = 0.15            # P(draw from the easy pool — anti-forgetting)
    replay_easy_frac: float = 0.20       # easy pool = the easiest 20% of examples
    raft_e1_frac: float = 0.10           # first 10% of training is gold-heavy (E1-like)
    raft_final_p: float = 0.8            # final P_GOLDEN
    raft_final_k: int = 4                # final #distractors
    seed: int = 123


def compute_difficulty(teacher_ce: float, teacher_entropy: float = 0.0, length: int = 0,
                       n_distractors: int = 0, answer_rarity: float = 0.0,
                       w=(1.0, 0.3, 0.15, 0.4, 0.2)) -> float:
    """Per-example raw difficulty (the scheduler min-max normalizes the dataset array). Higher = harder."""
    return (w[0] * teacher_ce + w[1] * teacher_entropy + w[2] * math.log1p(max(length, 0))
            + w[3] * n_distractors + w[4] * answer_rarity)


class CurriculumScheduler:
    def __init__(self, difficulties, num_steps: int, cfg: CurriculumConfig = CurriculumConfig()):
        d = np.asarray(difficulties, dtype=np.float64)
        if d.size == 0 or num_steps <= 0 or not np.all(np.isfinite(d)):
            raise ValueError(f"bad curriculum input: n={d.size} num_steps={num_steps} finite={np.all(np.isfinite(d))}")
        lo, hi = float(d.min()), float(d.max())
        self.diff = (d - lo) / (hi - lo + 1e-12) if hi > lo else np.full_like(d, 0.5)   # normalize [0,1]
        self.N = self.diff.size
        self.num_steps, self.cfg = num_steps, cfg
        self.sort_idx = np.argsort(self.diff)                    # ascending difficulty
        self.sorted_diff = self.diff[self.sort_idx]
        self.easy_pool = self.sort_idx[:max(1, math.ceil(cfg.replay_easy_frac * self.N))]
        self.t_e1 = int(num_steps * cfg.raft_e1_frac)
        self.T_full = max(1, int(num_steps * cfg.pace_T_frac))
        self.rng = random.Random(cfg.seed)

    def competence(self, step: int) -> float:
        s, c = self.cfg.pace_schedule, 0.0
        if s == "linear":
            c = step / self.T_full
        elif s == "step":
            f = step / max(1, self.num_steps)
            c = 0.2 if f < 0.25 else 0.4 if f < 0.5 else 0.7 if f < 0.75 else 1.0
        else:                                                    # root_p (default)
            c0, p = self.cfg.pace_c0, self.cfg.pace_p
            c = (step * (1 - c0 ** p) / self.T_full + c0 ** p) ** (1.0 / p)
        return min(1.0, max(0.0, c))

    def difficulty_quantile(self, step: int) -> float:
        return self.competence(step)

    def _candidates(self, step: int) -> np.ndarray:
        q = max(self.cfg.pace_c0, self.competence(step))         # never below the warmup floor
        cut = np.searchsorted(self.sorted_diff, q, side="right")  # examples with normalized difficulty ≤ q
        return self.sort_idx[:max(1, cut)]

    def sample(self, step: int) -> int:
        """Return a training-example index for this step (competence-gated; replay easy with replay_prob)."""
        if self.rng.random() < self.cfg.replay_prob:
            return int(self.easy_pool[self.rng.randrange(len(self.easy_pool))])   # anti-forgetting
        cand = self._candidates(step)
        return int(cand[self.rng.randrange(len(cand))])

    def raft_params(self, step: int):
        """RAFT distractor staging: gold-heavy (E1-like) early → distractor-heavy late. Returns (p_golden, k_distractors)."""
        if step < self.t_e1:
            return 1.0, 0                                        # gold always present, no distractors (easiest)
        prog = min(1.0, (step - self.t_e1) / max(1, self.num_steps - self.t_e1))
        k = int(round(self.cfg.raft_final_k * prog))
        p = 1.0 - (1.0 - self.cfg.raft_final_p) * prog           # 1.0 → raft_final_p
        return p, k

    def state_dict(self) -> dict:
        return {"cfg": asdict(self.cfg), "num_steps": self.num_steps, "rng": self.rng.getstate()}

    def load_state_dict(self, sd: dict):
        self.rng.setstate(tuple(tuple(x) if isinstance(x, list) else x for x in sd["rng"]))


def _smoke() -> None:
    rng = np.random.default_rng(0)
    diff = rng.random(500) * 5.0                                 # synthetic difficulties
    sch = CurriculumScheduler(diff, num_steps=1000)
    comps = [sch.competence(t) for t in range(0, 1000, 50)]
    mono = all(b >= a - 1e-9 for a, b in zip(comps, comps[1:])) and comps[0] < comps[-1]
    early = np.mean([sch.diff[sch.sample(50)] for _ in range(400)])
    late = np.mean([sch.diff[sch.sample(950)] for _ in range(400)])
    rises = late > early + 0.05                                  # sampled difficulty rises with competence
    rp_early = sch.raft_params(10); rp_late = sch.raft_params(990)
    raft_mono = rp_early[1] <= rp_late[1] and rp_early[0] >= rp_late[0] and rp_late[1] == 4
    a = CurriculumScheduler(diff, 1000); a.sample(100)          # advance a's rng
    b = CurriculumScheduler(diff, 1000); b.load_state_dict(a.state_dict())
    roundtrip = a.sample(500) == b.sample(500)                  # restored rng → identical next draw (resume-safe)
    ok = mono and rises and raft_mono
    print("CURRIC_SMOKE (synthetic difficulties, no model):")
    print(f"  competence monotone 0→1: {mono} (c[0]={comps[0]:.2f}→c[-1]={comps[-1]:.2f})")
    print(f"  sampled difficulty rises with competence: {rises} (early {early:.2f} → late {late:.2f})")
    print(f"  RAFT staging gold→distractor monotone: {raft_mono} (early {rp_early} → late {rp_late})")
    print(f"  state_dict round-trip: {roundtrip}")
    print(f"  -> {'CURRIC_SMOKE PASS' if ok else 'CURRIC_SMOKE FAIL'}")


if __name__ == "__main__":
    _smoke()
