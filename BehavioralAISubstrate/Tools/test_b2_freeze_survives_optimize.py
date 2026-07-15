"""audit tools-scripts / decision 7 teeth: the b2 freeze-clause sha/existence pins must fail-closed
via sys.exit so they SURVIVE `python -O` (which strips bare `assert`). A regression to `assert` would
silently disable the freeze clause under -O. Static lint, no deps. Run:
    uv run --with pytest pytest test_b2_freeze_survives_optimize.py
"""
import os
import re

HERE = os.path.dirname(os.path.abspath(__file__))


def test_b2_freeze_pins_use_sys_exit_not_bare_assert():
    for fn in ("b2_r2_pipeline.py", "b2_refit_candidate.py"):
        src = open(os.path.join(HERE, fn)).read()
        assert "sys.exit(" in src, f"{fn}: freeze-clause checks must fail via sys.exit"
        offenders = re.findall(
            r"^\s*assert\s+(?:sha|actual|os\.path\.exists|sha256)\b.*$", src, re.M)
        assert not offenders, (
            f"{fn}: a freeze-clause check reverted to a bare `assert` (stripped under python -O): "
            + " | ".join(offenders))
