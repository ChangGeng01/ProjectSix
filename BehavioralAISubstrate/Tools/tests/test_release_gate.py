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
import hashlib
import json
import runpy
import shutil
import subprocess
from pathlib import Path

import pytest

TOOLS = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if os.path.join(TOOLS, "qinao_local_eval") not in sys.path:
    sys.path.insert(0, os.path.join(TOOLS, "qinao_local_eval"))

import release_gate as RG  # noqa: E402


@pytest.fixture
def combined_inputs(tmp_path, monkeypatch):
    """Real isolated report inputs; no model load, Swift call or external output."""
    package = tmp_path / "candidate" / "BehavioralAISubstrate"
    tests = package / "Tests" / "BehavioralAISubstrateTests"
    tests.mkdir(parents=True)
    keys = ["regression_gate_verdict"] + [f"fixture_gate_{i}" for i in range(97)]
    (tests / "QINAOTests.swift").write_text("\n".join(
        f"func test_qinao_{key}() {{}}" for key in keys
    ))
    log = tmp_path / "substrate.log"
    log.write_text("Executed 98 tests, with 0 failures\n" + "\n".join(
        f"QINAO-GATE {key}: PASS" for key in keys
    ))
    preserve = tmp_path / "reports"
    preserve.mkdir()
    manifest = {}
    for key, relative in (("v6_train", "data_v6/train.jsonl"),
                          ("v6_fix", "data_v6/fix_triples.jsonl")):
        path = preserve / relative
        path.parent.mkdir(exist_ok=True)
        path.write_bytes(b'{"text":"isolated fixture"}\n')
        manifest[key] = hashlib.sha256(path.read_bytes()).hexdigest()[:16]
    (preserve / "qinao_data_manifest.json").write_text(json.dumps(manifest))
    model = {
        "model_eval_ok": True, "release_ok_model": False,
        "attestations_pending": [88, 89, 92],
        "critical_pass": 2, "critical_fail": 0,
        "critical_attest": 3, "critical_pending": 0,
        "rows": [
            {"key": "capability_regression_gate", "status": "PASS", "critical_gate": True},
            {"key": "eval_set_contamination", "status": "PASS", "critical_gate": True},
            *[{"key": f"architecture_{n}", "status": "ATTEST", "critical_gate": True}
              for n in (88, 89, 92)],
        ],
    }
    (preserve / "qinao_verdict.json").write_text(json.dumps(model))
    monkeypatch.setattr(RG, "REPO", str(package))
    monkeypatch.setattr(RG, "PRESERVE", str(preserve))
    monkeypatch.setattr(sys, "argv", ["release_gate.py", str(log)])
    monkeypatch.delenv("SUBSTRATE_LOG", raising=False)

    def no_swift(*args, **kwargs):
        raise AssertionError("an explicit fixture log must not launch Swift")

    monkeypatch.setattr(RG.subprocess, "run", no_swift)
    return preserve, package, log, model


def _report(preserve):
    return json.loads((preserve / "qinao_release_verdict.json").read_text())


def test_partial_evaluation_control_preserves_computed_passes(combined_inputs):
    _, _, log, _ = combined_inputs
    model, rows = RG.model_section()
    substrate = RG.parse_substrate(log.read_text())
    assert model["available"] is True
    assert model["model_eval_ok"] is True
    assert model["attestations_pending"] == [88, 89, 92]
    assert substrate["n_gates_passed"] == 98
    assert all(value is True for value, _ in RG.aux_flags(rows, substrate).values())


def test_combined_partial_pass_is_not_full_release(combined_inputs, capsys):
    preserve, _, _, _ = combined_inputs
    status = RG.main()
    report = _report(preserve)
    assert report["release_ok"] is False
    assert report["evaluation_ok"] is True
    assert all(value is True for value in report["components"].values())
    assert set(report["model_deferred"]) == {"model_attest_88", "model_attest_89", "model_attest_92"}
    assert set(report["substrate_deferred"]) == {
        "coreai_ane_conversion_fidelity", "authoritative_test_suite_pass",
    }
    assert status == 1
    output = capsys.readouterr().out
    assert "EVALUATION_OK = True" in output
    assert "RELEASE_OK = False" in output


def test_substrate_deferrals_block_even_a_true_model_release(combined_inputs):
    preserve, _, _, model = combined_inputs
    model.update(release_ok_model=True, attestations_pending=[], critical_attest=0)
    model["rows"] = model["rows"][:2]
    (preserve / "qinao_verdict.json").write_text(json.dumps(model))
    assert RG.main() == 1
    assert _report(preserve)["evaluation_ok"] is True
    assert _report(preserve)["release_ok"] is False


@pytest.mark.parametrize("change", [
    {"model_eval_ok": "true"}, {"model_eval_ok": 1},
    {"release_ok_model": "false"}, {"release_ok_model": 1},
    {"rows": {}}, {"rows": None}, {"rows": [None]},
    {"rows": [{"status": "PASS"}]},
    {"rows": [{"key": [], "status": "PASS"}]},
    {"rows": [{"key": "regression_gate", "status": True}]},
    {"rows": [{"key": "regression_gate", "status": "UNKNOWN"}]},
    {"rows": [{"key": "regression_gate", "status": "PASS", "critical_gate": "true"}]},
    {"rows": [{"key": "duplicate", "status": "PASS"}] * 2},
    {"attestations_pending": None}, {"attestations_pending": "88"},
    {"attestations_pending": [True]}, {"attestations_pending": [{}]},
    {"critical_pending": "0"},
])
def test_malformed_model_structures_are_unavailable(combined_inputs, change):
    preserve, _, _, model = combined_inputs
    model.update(change)
    (preserve / "qinao_verdict.json").write_text(json.dumps(model))
    section, rows = RG.model_section()
    assert section["available"] is False
    assert section["model_eval_ok"] is False
    assert "invalid" in section["reason"].lower()
    assert rows is None
    assert RG.main() == 1
    assert _report(preserve)["evaluation_ok"] is False


@pytest.mark.parametrize("raw", ["[]", "42", "true", '"text"', '{"rows":', "null"])
def test_invalid_top_level_model_is_unavailable(combined_inputs, raw):
    preserve, _, _, _ = combined_inputs
    (preserve / "qinao_verdict.json").write_text(raw)
    section, rows = RG.model_section()
    assert section["available"] is False
    assert section["reason"]
    assert rows is None


def test_builder_document_remains_supported(combined_inputs):
    import build_verdict

    preserve, _, _, _ = combined_inputs
    built = build_verdict.build({}, {})
    (preserve / "qinao_verdict.json").write_text(json.dumps(built))
    section, rows = RG.model_section()
    assert section["available"] is True
    assert section["model_eval_ok"] is False
    assert len(rows) == built["n_metrics"]
    assert section["attestations_pending"] == [88, 89, 92]
    assert RG.main() == 1


def test_package_discovery_uses_the_script_checkout(tmp_path):
    package = tmp_path / "candidate" / "BehavioralAISubstrate"
    script = package / "Tools" / "qinao_local_eval" / "release_gate.py"
    script.parent.mkdir(parents=True)
    shutil.copyfile(RG.__file__, script)
    tests = package / "Tests" / "BehavioralAISubstrateTests"
    tests.mkdir(parents=True)
    (tests / "Local.swift").write_text("func test_qinao_candidateLocal_only() {}")
    namespace = runpy.run_path(str(script))
    assert Path(namespace["REPO"]) == package
    assert namespace["authored_gate_keys"]() == {"candidateLocal_only"}


@pytest.mark.parametrize("source", ["argument", "environment"])
def test_missing_requested_log_does_not_run_swift(combined_inputs, monkeypatch, source):
    preserve, _, log, _ = combined_inputs
    missing = str(log.parent / "missing.log")
    if source == "argument":
        monkeypatch.setattr(sys, "argv", ["release_gate.py", missing])
        monkeypatch.setenv("SUBSTRATE_LOG", str(log))
    else:
        monkeypatch.setattr(sys, "argv", ["release_gate.py"])
        monkeypatch.setenv("SUBSTRATE_LOG", missing)
    assert RG.main() == 1
    report = _report(preserve)
    assert report["substrate"]["source"].startswith("unavailable:")
    assert missing in report["substrate"]["source"]
    assert report["substrate"]["substrate_ok"] is False


def test_unreadable_requested_log_does_not_run_swift(combined_inputs, monkeypatch):
    _, _, log, _ = combined_inputs
    monkeypatch.setattr(sys, "argv", ["release_gate.py", str(log.parent)])
    assert RG.main() == 1
    assert RG.substrate_log_text(str(log.parent))[1].startswith("unavailable:")


@pytest.mark.parametrize("returncode", [0, 1, -9])
def test_fallback_process_status_is_not_replaced_by_passing_text(
    combined_inputs, monkeypatch, returncode,
):
    preserve, package, log, _ = combined_inputs
    monkeypatch.setattr(sys, "argv", ["release_gate.py"])

    def completed(command, **kwargs):
        assert command == ["swift", "test", "--filter", "QINAO", "--disable-swift-testing"]
        assert Path(kwargs["cwd"]) == package
        return subprocess.CompletedProcess(command, returncode, log.read_text(), "")

    monkeypatch.setattr(RG.subprocess, "run", completed)
    assert RG.main() == 1
    report = _report(preserve)
    assert report["substrate"]["n_gates_passed"] == 98  # partial diagnostics retained
    assert report["substrate"]["substrate_ok"] is (returncode == 0)
    assert report["evaluation_ok"] is (returncode == 0)
    if returncode:
        assert f"exit {returncode}" in report["substrate"]["source"]


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
