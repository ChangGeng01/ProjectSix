"""audit x-test-integrity F5 — the #26 novel_doc_read CRITICAL gate must DISCRIMINATE.

Before the fix, #26 was computed as a PERCENT (`mc/N*100`, 0-100) but the registry gates it
`> 0.20` (a fraction). So any non-zero reading — even a saturated probe's 100.0 — trivially
PASSED: a CRITICAL grounding gate that could never fail. #26 is now a FRACTION on the same
scale as its threshold, so a poor novel-doc reader FAILS.
"""
from build_verdict import build
from qinao_reading import novel_doc_read_score


def _row26(score: float) -> dict:
    # Provenance-stamped so build() treats it as a genuine computed PASS/FAIL (not ATTEST).
    tuned = {"26": score, "_prov": {"26": {"kind": "computed", "runner": "qinao_reading"}}}
    rows = build({}, tuned)["rows"]
    return next(r for r in rows if r["num"] == 26)


def test_score_is_a_fraction_not_a_percent():
    # 1 correct out of 20 novel-doc questions = 5% — must be 0.05, NOT 5.0.
    assert novel_doc_read_score(1, 20) == 0.05
    assert novel_doc_read_score(16, 20) == 0.8


def test_poor_novel_doc_reader_fails_the_critical_gate():
    score = novel_doc_read_score(1, 20)          # 5% correct — a poor grounding reader
    row = _row26(score)
    assert row["status"] == "FAIL", (
        f"a 5% novel-doc reader must FAIL #26 — the gate must discriminate, got {row}")


def test_good_novel_doc_reader_passes_the_critical_gate():
    score = novel_doc_read_score(16, 20)         # 80% correct
    assert _row26(score)["status"] == "PASS"


def test_saturated_probe_no_longer_auto_passes():
    # A saturated probe (base==tuned==1.0 on the fraction scale) still passes, but the point is
    # that the gate is now CAPABLE of failing — proven by the poor-reader case above. A
    # near-zero reader that the old percent gate waved through now fails.
    assert _row26(0.10)["status"] == "FAIL", "10% novel-doc-read is below the 0.20 floor"
