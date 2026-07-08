"""audit M-j — release_gate.py must fail CLOSED, not default-PASS.

Two defects:
  1. never_worse defaulted `nw_model = True`, so an ABSENT regression-gate
     row (model_rows empty/None, or the row renamed/dropped) passed the
     "never ship a worse model" gate with zero evidence — fail-open.
  2. parse_substrate took the LAST "Executed N tests" line, so a truncated
     or stderr-interleaved log whose final line was a small partial
     sub-suite count overrode the real suite total.
"""
from __future__ import annotations

import os
import sys

TOOLS = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if os.path.join(TOOLS, "qinao_local_eval") not in sys.path:
    sys.path.insert(0, os.path.join(TOOLS, "qinao_local_eval"))

import release_gate as RG  # noqa: E402


class TestRegressionGateFailClosed:
    def test_absent_row_fails_closed(self):
        # THE bug: model ran, but no regression row present ⇒ must FAIL.
        ok, note = RG.regression_gate_status({"some_other_gate": {"status": "PASS"}})
        assert ok is False
        assert "fail-closed" in note

    def test_empty_model_rows_fails_closed(self):
        assert RG.regression_gate_status({})[0] is False

    def test_none_model_rows_fails_closed(self):
        # model_section() returns None rows when the verdict file is absent.
        assert RG.regression_gate_status(None)[0] is False

    def test_genuine_pass_passes(self):
        ok, note = RG.regression_gate_status({"regression_gate": {"status": "PASS"}})
        assert ok is True
        assert "PASS" in note

    def test_genuine_fail_fails(self):
        assert RG.regression_gate_status(
            {"never_worse_regression": {"status": "FAIL"}})[0] is False


class TestParseSubstrateTakesTotalNotLastLine:
    def test_truncated_partial_last_line_does_not_override_total(self):
        # The real total (98/3) appears, THEN a small partial sub-suite (5/0)
        # trails (truncated/interleaved log). The gate must see 98/3, not 5/0.
        log = (
            "Test Suite 'AllTests' Executed 98 tests, with 3 failures (0 unexpected)\n"
            "qinao-gate regression_gate_verdict: PASS\n"
            "Test Suite 'LateClass' Executed 5 tests, with 0 failures\n"
        )
        r = RG.parse_substrate(log)
        assert r["executed"] == 98
        assert r["failures"] == 3

    def test_normal_ascending_order_still_correct(self):
        log = (
            "Test Suite 'ClassA' Executed 5 tests, with 0 failures\n"
            "Test Suite 'AllTests' Executed 98 tests, with 0 failures\n"
            "Test Suite 'Selected tests' Executed 98 tests, with 0 failures\n"
        )
        r = RG.parse_substrate(log)
        assert r["executed"] == 98
        assert r["failures"] == 0

    def test_no_executed_line_stays_none(self):
        r = RG.parse_substrate("build failed, no tests ran\n")
        assert r["executed"] is None
        assert r["failures"] is None
