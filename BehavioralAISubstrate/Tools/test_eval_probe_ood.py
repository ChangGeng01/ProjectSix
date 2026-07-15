"""audit tools-scripts / decision 7 teeth: eval_probe_ood must resolve WEIGHTS cwd-independently and
name the OOD verdict floor. Pure-Python (no model deps). Run: uv run --with pytest pytest test_eval_probe_ood.py
"""
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
import eval_probe_ood as ep  # noqa: E402


def test_weights_path_is_absolute_and_cwd_independent():
    assert os.path.isabs(ep.WEIGHTS), "WEIGHTS must be absolute (runs from any cwd), not the old relative path"
    assert ep.WEIGHTS.replace(os.sep, "/").endswith("Docs/probe_weights_v1_2026-07-04.json")
    assert os.path.basename(os.path.dirname(ep.WEIGHTS)) == "Docs"


def test_downshift_success_floor_is_a_named_constant():
    assert ep.IN_DOMAIN_DOWNSHIFT_SUCCESS == 0.85
