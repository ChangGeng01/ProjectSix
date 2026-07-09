"""audit x-test-integrity F5 teeth: CRITICAL gate #20 counterfactual_lift must DISCRIMINATE a
grounded reader from a parroter. It used to be backed by a saturated soft probe (novel-fiction items,
base==tuned==1.0) so it could never fail; it is now backed by the contamination-free hard
counterfactual probe (qinao_reading_hard.py emits "20"=follow/n). Pure-Python, no model load. Run:
    uv run --with pytest pytest test_reading_discriminates.py
"""
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
import qinao_merge as qm  # noqa: E402
import build_verdict as bv  # noqa: E402
import qinao_reading as qr  # noqa: E402


def _row(base, tuned, num):
    return next(r for r in bv.build(base, tuned)["rows"] if r["num"] == num)


# The hard probe's sidefile shape (what qinao_reading_hard.py now writes).
def _hard_sidefile(follow: int, n: int = 20) -> dict:
    return {"20": round(follow / n, 3), "reading_hard_followrate": round(follow / n * 100, 1),
            "follow": follow, "prior": n - follow, "other": 0, "n": n}


def test_parroter_fails_the_critical_counterfactual_gate():
    # A parroter reverts to its prior on hard counterfactuals: follow≈2/20=0.1.
    merged = qm.merge_sidefile_into_values({}, _hard_sidefile(follow=2), "qinao_reading_hard")
    row = _row({}, merged, 20)
    assert row["tuned"] == 0.1
    assert row["status"] == "FAIL", "a parroter (follow 2/20=0.1) must FAIL the >0.35 grounding gate"


def test_grounded_reader_passes_the_critical_counterfactual_gate():
    # A grounded reader follows the document over its prior: follow≈16/20=0.8.
    merged = qm.merge_sidefile_into_values({}, _hard_sidefile(follow=16), "qinao_reading_hard")
    row = _row({}, merged, 20)
    assert row["tuned"] == 0.8
    assert row["status"] == "PASS", "a grounded reader (follow 16/20=0.8) must PASS the >0.35 gate"


def test_hard_probe_backing_carries_computed_provenance_not_attest():
    # #20 ∈ MODEL_CRITICAL: the hard-probe merge must stamp computed provenance so the gate is a
    # genuine PASS/FAIL, never a laundered ATTEST.
    merged = qm.merge_sidefile_into_values({}, _hard_sidefile(follow=16), "qinao_reading_hard")
    assert merged["_prov"]["20"] == {"kind": "computed", "runner": "qinao_reading_hard"}
    assert _row({}, merged, 20)["status"] in ("PASS", "FAIL")


def test_soft_probe_no_longer_emits_20():
    # The saturated soft probe must NOT back #20 anymore (else its 1.0 could last-wins-launder the
    # gate green regardless of the hard probe).
    out = qr.reading_out(mc=20, follow=20, genuine=20, leak=0, n=20)
    assert "20" not in out, "qinao_reading must no longer emit the saturated soft #20"
    # #26/#21 remain (the legitimate matched-read floor + tracked #21 residual).
    assert "26" in out and "21" in out


def test_saturated_soft_backing_would_false_green_the_parroter():
    # REVERSAL DEMONSTRATION: if #20 were still backed by the saturated soft probe (1.0), a parroter
    # sails through — the exact false-green this repoint removes.
    saturated = qm.merge_sidefile_into_values({}, {"20": 1.0}, "qinao_reading")
    assert _row({}, saturated, 20)["status"] == "PASS"  # false-green under the old backing
    # …whereas the discriminating hard backing FAILs the same parroter.
    discriminating = qm.merge_sidefile_into_values({}, _hard_sidefile(follow=2), "qinao_reading_hard")
    assert _row({}, discriminating, 20)["status"] == "FAIL"
