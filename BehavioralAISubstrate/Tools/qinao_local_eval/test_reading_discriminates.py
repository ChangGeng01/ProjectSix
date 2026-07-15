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
    # #26 remains (the legitimate matched-read floor). #21's "tracked residual" here was CLOSED by
    # the 2026-07-11 operator-directed repoint — it now comes from the hard probe (see below).
    assert "26" in out


def test_saturated_soft_backing_would_false_green_the_parroter():
    # REVERSAL DEMONSTRATION: if #20 were still backed by the saturated soft probe (1.0), a parroter
    # sails through — the exact false-green this repoint removes.
    saturated = qm.merge_sidefile_into_values({}, {"20": 1.0}, "qinao_reading")
    assert _row({}, saturated, 20)["status"] == "PASS"  # false-green under the old backing
    # …whereas the discriminating hard backing FAILs the same parroter.
    discriminating = qm.merge_sidefile_into_values({}, _hard_sidefile(follow=2), "qinao_reading_hard")
    assert _row({}, discriminating, 20)["status"] == "FAIL"


# ── audit x-test-integrity F5 residual #21 (2026-07-11, operator-directed repoint) ──────────────
# CRITICAL gate #21 genuine_reading (>0.25) rode the SAME saturated soft probe (novel-fiction,
# base==tuned==1.0 ⇒ genuine==1.0 ⇒ structurally cannot fail). Repointed to the hard probe with a
# SECOND ARM: arm A reads a TRUE-fact doc (matched extraction), arm B is the existing counterfactual
# follow. #21 = fraction(matched_ok AND follow) — the conjunction pins a failure mode #20 alone
# cannot: a doc-contrarian/extraction-broken model that follows counterfactuals but cannot read a
# true doc passes #20 yet fails #21. Same ID, same >0.25 threshold; only the BACKING changed
# (the exact #20 precedent, 39e074027).

import qinao_reading_hard as qrh  # noqa: E402


def _hard_sidefile_v2(matched: int, follow: int, genuine: int, n: int = 20) -> dict:
    return qrh.hard_reading_out(matched=matched, follow=follow, genuine=genuine,
                                prior=n - follow, other=0, n=n)


def test_parroter_fails_the_critical_genuine_reading_gate():
    # A parroter aces the true-doc arm (doc agrees with its prior) but reverts on counterfactuals:
    # matched 19/20, follow 2/20, genuine (conjunction) 2/20 = 0.1 → FAIL >0.25.
    merged = qm.merge_sidefile_into_values({}, _hard_sidefile_v2(matched=19, follow=2, genuine=2),
                                           "qinao_reading_hard")
    row = _row({}, merged, 21)
    assert row["tuned"] == 0.1
    assert row["status"] == "FAIL", "a parroter (genuine 2/20) must FAIL the >0.25 gate"


def test_grounded_reader_passes_the_critical_genuine_reading_gate():
    merged = qm.merge_sidefile_into_values({}, _hard_sidefile_v2(matched=19, follow=16, genuine=15),
                                           "qinao_reading_hard")
    row = _row({}, merged, 21)
    assert row["tuned"] == 0.75
    assert row["status"] == "PASS"


def test_doc_contrarian_passes_20_but_fails_21():
    # The conjunction's added value: follows EVERY doc blindly (passes #20) yet cannot extract from
    # a TRUE doc (matched 3/20) ⇒ genuine ≤ matched ⇒ #21 FAILs. #20 alone cannot catch this.
    merged = qm.merge_sidefile_into_values({}, _hard_sidefile_v2(matched=3, follow=18, genuine=3),
                                           "qinao_reading_hard")
    assert _row({}, merged, 20)["status"] == "PASS", "blind doc-follower sails through #20"
    assert _row({}, merged, 21)["status"] == "FAIL", "…but the genuine_reading conjunction catches it"


def test_hard_probe_21_carries_computed_provenance():
    merged = qm.merge_sidefile_into_values({}, _hard_sidefile_v2(matched=19, follow=16, genuine=15),
                                           "qinao_reading_hard")
    assert merged["_prov"]["21"] == {"kind": "computed", "runner": "qinao_reading_hard"}


def test_soft_probe_no_longer_emits_21():
    # The saturated soft probe must NOT back #21 anymore (last-wins laundering, same as old #20).
    out = qr.reading_out(mc=20, follow=20, genuine=20, leak=0, n=20)
    assert "21" not in out, "qinao_reading must no longer emit the saturated soft #21"
    assert "26" in out, "#26 stays (legitimate matched-read floor)"


def test_conjunction_is_bounded_by_both_arms():
    # genuine ≤ min(matched, follow) by construction — the sidefile builder itself must keep the
    # invariant (a probe bug emitting genuine > matched would silently inflate the gate).
    out = qrh.hard_reading_out(matched=5, follow=10, genuine=5, prior=10, other=0, n=20)
    assert out["21"] <= min(out["_matched_frac"], out["20"])
