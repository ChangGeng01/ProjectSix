"""H23 wire-1/wire-2 teeth: the orphan side-file merge that unblocks the CRITICAL
gates build_verdict never ingested. Pure-Python, no model load. Run:
    uv run --with pytest pytest test_merge_sidefile.py
"""
import json
import os
import sys
import tempfile

sys.path.insert(0, os.path.dirname(__file__))
import qinao_merge as qm  # noqa: E402
import build_verdict as bv  # noqa: E402


def _row(base, tuned, num):
    return next(r for r in bv.build(base, tuned)["rows"] if r["num"] == num)


def test_wire1_merge_promotes_pending_critical_gate_to_computed():
    # #26 (MODEL_CRITICAL) absent in tuned -> PENDING; the side-file provides it.
    base = {"26": 50.0}
    assert _row(base, {}, 26)["status"] == "PENDING"
    side = {"26": 80.0, "_leak": 0.1, "_N": 40, "26_err": ""}  # + diagnostics to ignore
    merged = qm.merge_sidefile_into_values({}, side, "qinao_reading")
    assert _row(base, merged, 26)["status"] != "PENDING"  # gate now flows
    # diagnostic keys are NOT ingested as metrics
    assert "_leak" not in merged and "_N" not in merged and "26_err" not in merged


def test_wire2_model_critical_merge_carries_computed_provenance():
    # A bare literal with no _prov ATTESTs (not a verified pass); the helper
    # stamps computed provenance, so it counts as a genuine PASS/FAIL.
    base = {"26": 50.0}
    assert _row(base, {"26": 80.0}, 26)["status"] == "ATTEST"
    merged = qm.merge_sidefile_into_values({}, {"26": 80.0}, "qinao_reading")
    assert merged["_prov"]["26"] == {"kind": "computed", "runner": "qinao_reading"}
    assert _row(base, merged, 26)["status"] != "ATTEST"


def test_non_critical_metric_is_not_prov_stamped():
    merged = qm.merge_sidefile_into_values({}, {"69": 3.2}, "qinao_eval")  # #69 ∉ MODEL_CRITICAL
    assert merged["69"] == 3.2
    assert "69" not in merged.get("_prov", {})


def test_merge_is_immutable_and_preserves_existing():
    values = {"1": 10.0, "_prov": {"1": {"kind": "computed", "runner": "qinao_eval"}}}
    snapshot = json.loads(json.dumps(values))
    merged = qm.merge_sidefile_into_values(values, {"26": 80.0}, "qinao_reading")
    assert merged["1"] == 10.0 and merged["_prov"]["1"]["runner"] == "qinao_eval"
    assert merged["_prov"]["26"]["kind"] == "computed"
    assert values == snapshot  # input dict was NOT mutated


def test_merge_known_sidefiles_ingests_present_files_from_dir():
    with tempfile.TemporaryDirectory() as d:
        json.dump({"26": 80.0}, open(os.path.join(d, "qinao_read_T.json"), "w"))
        json.dump({"28": 55.0, "29": 40.0}, open(os.path.join(d, "qinao_bench_T.json"), "w"))
        merged = qm.merge_known_sidefiles({}, "T", tmpdir=d)
        assert merged["26"] == 80.0 and merged["28"] == 55.0 and merged["29"] == 40.0
        assert merged["_prov"]["26"]["kind"] == "computed"
        assert merged["_prov"]["28"]["kind"] == "computed"
