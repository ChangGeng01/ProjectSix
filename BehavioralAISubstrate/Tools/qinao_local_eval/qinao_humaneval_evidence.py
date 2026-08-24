"""Shared construction and validation for certifiable HumanEval evidence."""

from __future__ import annotations

import math
from dataclasses import dataclass
from typing import Mapping


@dataclass(frozen=True)
class HumanEvalEvidenceSummary:
    score: float
    sample_count: int


def _strict_nonnegative_int(value: object) -> bool:
    return type(value) is int and value >= 0


def _valid_vector(
    per_problem: object,
    *,
    sample_count: int,
    passed: int | None = None,
) -> bool:
    if not isinstance(per_problem, dict) or len(per_problem) != sample_count:
        return False
    if not all(
        isinstance(task_id, str)
        and task_id
        and type(outcome) is int
        and outcome in (0, 1)
        for task_id, outcome in per_problem.items()
    ):
        return False
    return passed is None or sum(per_problem.values()) == passed


def build_humaneval_evidence(
    *,
    passed: int,
    total: int,
    infra_errors: int,
    per_problem: Mapping[str, int] | None = None,
) -> dict[str, object]:
    """Build diagnostics and emit metric 30 only for complete evidence."""

    if not all(
        _strict_nonnegative_int(value)
        for value in (passed, total, infra_errors)
    ):
        raise ValueError("HumanEval counts must be nonnegative integers")
    if passed > total:
        raise ValueError("HumanEval passed count cannot exceed its denominator")

    vector = dict(per_problem) if per_problem is not None else None
    if vector is not None and not _valid_vector(
        vector, sample_count=total, passed=passed
    ):
        raise ValueError("paired HumanEval vector is inconsistent with its counts")

    evidence: dict[str, object] = {
        "_N": total,
        "_infra_errs": infra_errors,
    }
    if vector is not None:
        evidence["per_problem"] = vector
    if total > 0 and infra_errors == 0:
        evidence["30"] = round(passed / total * 100, 1)
    return evidence


def validate_humaneval_evidence(
    evidence: object,
    *,
    paired: bool,
) -> HumanEvalEvidenceSummary | None:
    """Return the accepted summary, or ``None`` for unavailable evidence."""

    if not isinstance(evidence, dict):
        return None
    sample_count = evidence.get("_N")
    infra_errors = evidence.get("_infra_errs")
    score = evidence.get("30")
    if type(sample_count) is not int or sample_count <= 0:
        return None
    if type(infra_errors) is not int or infra_errors != 0:
        return None
    if (
        isinstance(score, bool)
        or not isinstance(score, (int, float))
        or not math.isfinite(score)
        or not 0 <= score <= 100
    ):
        return None

    vector_present = "per_problem" in evidence
    if paired and not vector_present:
        return None
    if vector_present:
        vector = evidence["per_problem"]
        if not _valid_vector(vector, sample_count=sample_count):
            return None
        expected_score = round(sum(vector.values()) / sample_count * 100, 1)
        if float(score) != expected_score:
            return None

    return HumanEvalEvidenceSummary(
        score=float(score),
        sample_count=sample_count,
    )
