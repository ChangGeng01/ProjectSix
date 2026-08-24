"""audit tools-scripts LOW / decision 7 teeth: qinao_humaneval_paired must EXCLUDE infra errors from
the pass@1 denominator (mirroring the sibling qinao_humaneval.py fix). The module's heavy deps are
now imported lazily inside main(), so the pure helper imports without mlx_lm/datasets present.
Run: uv run --with pytest pytest test_qinao_humaneval_paired.py
"""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "qinao_local_eval"))
import qinao_humaneval_paired as hp  # noqa: E402


def test_execute_generated_program_delegates_to_sandbox():
    calls = []
    sentinel = object()

    def recording_run_sandboxed(pybin, script_path, timeout):
        calls.append((pybin, script_path, timeout))
        return sentinel

    original = hp.run_sandboxed
    hp.run_sandboxed = recording_run_sandboxed
    try:
        result = hp.execute_generated_program(
            "/exact/python",
            "/exact/generated.py",
            timeout=23,
        )
    finally:
        hp.run_sandboxed = original

    assert calls == [("/exact/python", "/exact/generated.py", 23)]
    assert result is sentinel


def test_infra_errors_excluded_ran_and_timeout_counted():
    # 'ran' and 'timeout' are model-attributable outcomes ⇒ count toward the denominator.
    assert hp.counts_toward_denominator("ran") is True, "an executed run counts"
    assert hp.counts_toward_denominator("timeout") is True, "a hung program is a legitimate wrong answer"
    # 'infra' is a harness failure ⇒ EXCLUDED (reverting to always-True reds this — the false-0% bug).
    assert hp.counts_toward_denominator("infra") is False, \
        "an infra error must be EXCLUDED from the denominator, not scored as a model failure"


def test_shared_evidence_omits_metric_for_any_infrastructure_failure():
    from qinao_humaneval_evidence import build_humaneval_evidence

    all_infra = build_humaneval_evidence(
        passed=0,
        total=0,
        infra_errors=164,
        per_problem={},
    )
    partial_infra = build_humaneval_evidence(
        passed=1,
        total=2,
        infra_errors=1,
        per_problem={"HumanEval/0": 1, "HumanEval/1": 0},
    )
    complete = build_humaneval_evidence(
        passed=1,
        total=2,
        infra_errors=0,
        per_problem={"HumanEval/0": 1, "HumanEval/1": 0},
    )

    assert "30" not in all_infra
    assert all_infra == {"_N": 0, "_infra_errs": 164, "per_problem": {}}
    assert "30" not in partial_infra
    assert partial_infra["_infra_errs"] == 1
    assert complete["30"] == 50.0
    assert complete["_infra_errs"] == 0


def test_paired_evidence_requires_a_consistent_complete_vector():
    from qinao_humaneval_evidence import validate_humaneval_evidence

    valid = {
        "30": 50.0,
        "_N": 2,
        "_infra_errs": 0,
        "per_problem": {"HumanEval/0": 1, "HumanEval/1": 0},
    }
    wrong_length = {**valid, "per_problem": {"HumanEval/0": 1}}
    wrong_score = {**valid, "30": 100.0}
    wrong_value = {**valid, "per_problem": {"HumanEval/0": True, "HumanEval/1": 0}}

    summary = validate_humaneval_evidence(valid, paired=True)
    assert summary is not None
    assert (summary.score, summary.sample_count) == (50.0, 2)
    assert validate_humaneval_evidence(wrong_length, paired=True) is None
    assert validate_humaneval_evidence(wrong_score, paired=True) is None
    assert validate_humaneval_evidence(wrong_value, paired=True) is None
