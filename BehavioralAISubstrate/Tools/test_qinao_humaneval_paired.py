"""audit tools-scripts LOW / decision 7 teeth: qinao_humaneval_paired must EXCLUDE infra errors from
the pass@1 denominator (mirroring the sibling qinao_humaneval.py fix). The module's heavy deps are
now imported lazily inside main(), so the pure helper imports without mlx_lm/datasets present.
Run: uv run --with pytest pytest test_qinao_humaneval_paired.py
"""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "qinao_local_eval"))
import qinao_humaneval_paired as hp  # noqa: E402


def test_infra_errors_excluded_ran_and_timeout_counted():
    # 'ran' and 'timeout' are model-attributable outcomes ⇒ count toward the denominator.
    assert hp.counts_toward_denominator("ran") is True, "an executed run counts"
    assert hp.counts_toward_denominator("timeout") is True, "a hung program is a legitimate wrong answer"
    # 'infra' is a harness failure ⇒ EXCLUDED (reverting to always-True reds this — the false-0% bug).
    assert hp.counts_toward_denominator("infra") is False, \
        "an infra error must be EXCLUDED from the denominator, not scored as a model failure"
