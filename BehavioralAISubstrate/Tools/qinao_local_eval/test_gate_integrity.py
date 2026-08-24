"""H23 (mega-audit project tier, 2026-07-08): QINAO gate-integrity regression suite.

Pins the three theatre defects the audit found in the release-verdict chain, so the
gate can never silently regress to "self-certifying theatre" again:

  F1  build_verdict trusted /tmp JSON wholesale — a hand-crafted value (esp. a
      CRITICAL gate with NO computed writer, e.g. #89 audit_traceability) counted as
      a genuine PASS, indistinguishable from real compute.
  F2  qinao_eval hardcoded V[83]=0 / V[88]=100 / V[92]=100 as bare literals that
      flowed through the genuine-PASS channel — architectural facts a model eval
      cannot verify were laundered into "computed CRITICAL PASS".
  F3  release_gate.data_fp_match re-verified only the 2 TRAIN files; the 4 EVAL sets
      (the ones that would reveal contamination) were never fingerprinted.

Pure-logic tests over synthetic fixtures — NO model, NO eval data required.
Run: python -m pytest Tools/qinao_local_eval/test_gate_integrity.py -q
"""

import json
import os
import subprocess
import shutil
import sys
import tempfile
import uuid
from pathlib import Path

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

from registry import MODEL_CRITICAL, ATTEST_ONLY_CRITICAL, by_num  # noqa: E402
import build_verdict as bv  # noqa: E402
import qinao_merge as qm  # noqa: E402


def _classify(num, threshold, direction, val, bval=None, prov=None):
    """Drive build_verdict's classifier for a single metric."""
    return bv.evaluate(threshold, direction, val, bval, num=num, prov=prov)


# ---- F2: architectural attestations are ATTEST, never genuine PASS -------------


def test_offline_rate_is_attest_not_pass():
    # #88 on_device_offline_rate — a model eval cannot verify the deployment is offline.
    status, _ = _classify(88, "100", "up", 100)
    assert status == "ATTEST", f"#88 recorded value must be ATTEST, got {status}"


def test_sovereignty_is_attest_not_pass():
    status, _ = _classify(92, "100", "up", 100)
    assert status == "ATTEST", f"#92 recorded value must be ATTEST, got {status}"


def test_audit_traceability_is_attest_not_pass():
    # #89 — the gate the audit found had NO writer in all of git history.
    status, _ = _classify(89, "100", "up", 100)
    assert status == "ATTEST", f"#89 recorded value must be ATTEST, got {status}"


def test_attest_only_set_is_the_architectural_facts():
    assert ATTEST_ONLY_CRITICAL == {88, 89, 92}
    assert ATTEST_ONLY_CRITICAL <= MODEL_CRITICAL


# ---- F1: contamination gate must be genuinely computed, not a bare literal ------


def test_contamination_computed_value_can_pass():
    # #83 is genuinely computable — a real computed 0 with provenance is a real PASS.
    status, _ = _classify(83, "=0", "equal", 0, prov={"kind": "computed"})
    assert status == "PASS"


def test_contamination_injected_without_provenance_is_not_genuine_pass():
    # Hand-injected #83=0 with NO provenance stamp must NOT count as a genuine PASS.
    status, _ = _classify(83, "=0", "equal", 0, prov=None)
    assert status != "PASS", "injected CRITICAL value without provenance must not PASS"


def test_missing_critical_value_is_pending_fail_closed():
    status, _ = _classify(83, "=0", "equal", None)
    assert status == "PENDING"


# ---- release-verdict rollup: injection cannot flip release_ok -------------------


def _run_build_verdict(base_values, tuned_values):
    with tempfile.TemporaryDirectory() as d:
        bpath = os.path.join(d, "base.json")
        tpath = os.path.join(d, "tuned.json")
        json.dump(base_values, open(bpath, "w"))
        json.dump(tuned_values, open(tpath, "w"))
        out = subprocess.run(
            [sys.executable, os.path.join(HERE, "build_verdict.py"), bpath, tpath],
            capture_output=True,
            text=True,
            env={**os.environ, "QINAO_VERDICT_OUT": os.path.join(d, "v.json")},
        )
        assert out.returncode == 0, out.stderr
        return json.load(open(os.path.join(d, "v.json")))


def test_hand_injected_literals_block_both_verdicts():
    # Attacker hand-crafts a JSON injecting every CRITICAL gate = passing literal with
    # NO provenance. Both model_eval_ok AND release_ok_model must stay False — the
    # provenance guard routes every gate to ATTEST, and a verifiable ATTEST must block
    # model_eval_ok (adversarial review defect #2: it previously did not).
    injected = {str(n): (0 if by_num()[n][4] == "=0" else 100) for n in MODEL_CRITICAL}
    injected["_prov"] = {}  # no provenance for any of them
    v = _run_build_verdict(injected, injected)
    assert v["release_ok_model"] is False, "injected literals must not achieve release"
    assert v["model_eval_ok"] is False, (
        "injected literals (no provenance) must not pass model_eval_ok"
    )
    assert v["critical_pass"] == 0, (
        "no gate should be a genuine PASS without provenance"
    )
    assert v["critical_attest"] >= len(ATTEST_ONLY_CRITICAL)


def test_forged_computed_provenance_still_blocks_release():
    # Even if the forger ALSO writes _prov kind=computed for the architectural gates,
    # release_ok_model stays False (attestations_pending is keyed on gate identity,
    # unforgeable from the values file). This is the structural backstop.
    injected = {str(n): (0 if by_num()[n][4] == "=0" else 100) for n in MODEL_CRITICAL}
    injected["_prov"] = {str(n): {"kind": "computed"} for n in MODEL_CRITICAL}
    v = _run_build_verdict(injected, injected)
    assert v["release_ok_model"] is False
    assert set(v["attestations_pending"]) == ATTEST_ONLY_CRITICAL


def _fully_passing_critical_values():
    from registry import by_num

    tuned = {}
    prov = {}
    import re as _re

    for n in MODEL_CRITICAL:
        thr = by_num()[n][4]
        # pick a value that passes the gate's own threshold
        if thr == "=0":
            val = 0
        elif thr.startswith("~"):  # near-target: pick the target
            val = float(thr[1:])
        elif thr in ("100", "=target"):
            val = 100
        else:
            mm = _re.match(r"(<=|<|>=|>)\s*([\d.]+)", str(thr))
            if mm:
                t = float(mm.group(2))
                val = t + 5 if mm.group(1) in (">=", ">") else max(0.0, t - 5)
            else:
                val = 100  # frozen/all/=target style → routes to ATTEST anyway
        tuned[str(n)] = val
        prov[str(n)] = {"kind": "computed"}
    tuned["_prov"] = prov
    return tuned


def test_model_eval_ok_separates_from_deployment_attestations():
    # A run where every VERIFIABLE critical gate genuinely passes but the architectural
    # attestations are (correctly) ATTEST: model_eval_ok True, release_ok_model False,
    # attestations_pending lists exactly the architectural gates.
    with tempfile.TemporaryDirectory() as directory:
        from qinao_humaneval_evidence import (
            HumanEvalProducer,
            HumanEvalRunContext,
            SubjectReceipt,
            build_humaneval_evidence,
        )

        run_id = "model-eval-ok"
        evidence_dir = Path(directory) / run_id
        evidence_dir.mkdir()
        context = HumanEvalRunContext(
            run_id=run_id,
            evidence_dir=evidence_dir,
            dataset_fingerprint="dataset-fingerprint-current",
            subjects={
                "base": SubjectReceipt("a" * 64, "model", None),
                "tuned": SubjectReceipt("b" * 64, "model", "adapter"),
            },
        )
        for tag in ("base", "tuned"):
            outcomes = {"HumanEval/0": 1, "HumanEval/1": 1}
            standard = build_humaneval_evidence(
                passed=2,
                total=2,
                infra_errors=0,
                sample_ids=list(outcomes),
                producer=HumanEvalProducer.STANDARD,
                context=context,
                tag=tag,
            )
            paired = build_humaneval_evidence(
                passed=2,
                total=2,
                infra_errors=0,
                per_problem=outcomes,
                sample_ids=list(outcomes),
                producer=HumanEvalProducer.PAIRED,
                context=context,
                tag=tag,
            )
            Path(evidence_dir, f"qinao_humaneval_{tag}.json").write_text(
                json.dumps(standard), encoding="utf-8"
            )
            Path(evidence_dir, f"qinao_humaneval_paired_{tag}.json").write_text(
                json.dumps(paired), encoding="utf-8"
            )
        base = qm.merge_known_sidefiles(
            _fully_passing_critical_values(),
            "base",
            tmpdir=directory,
            humaneval_context=context,
        )
        tuned = qm.merge_known_sidefiles(
            _fully_passing_critical_values(),
            "tuned",
            tmpdir=directory,
            humaneval_context=context,
        )
    v = bv.build(base, tuned)
    assert v["model_eval_ok"] is True, (
        "all verifiable critical gates pass → model_eval_ok"
    )
    assert set(v["attestations_pending"]) == ATTEST_ONLY_CRITICAL
    assert v["release_ok_model"] is False, (
        "release still blocked on deployment attestations"
    )


def test_build_verdict_cli_revokes_prior_run_humaneval_when_current_files_absent():
    token = f"pytest-{os.getpid()}-{uuid.uuid4().hex}"
    tags = (f"{token}-base", f"{token}-tuned")
    value_paths = [Path("/tmp") / f"qinao_values_{tag}.json" for tag in tags]
    humaneval_paths = [
        Path("/tmp") / f"qinao_{prefix}_{tag}.json"
        for tag in tags
        for prefix in ("humaneval", "humaneval_paired")
    ]

    try:
        assert all(not path.exists() for path in value_paths + humaneval_paths)
        for path in value_paths:
            values = _fully_passing_critical_values()
            values["_prov"]["30"] = {
                "kind": "computed",
                "runner": "qinao_humaneval_paired",
            }
            path.write_text(json.dumps(values), encoding="utf-8")

        with tempfile.TemporaryDirectory() as directory:
            verdict_path = Path(directory) / "verdict.json"
            out = subprocess.run(
                [
                    sys.executable,
                    os.path.join(HERE, "build_verdict.py"),
                    tags[0],
                    tags[1],
                ],
                capture_output=True,
                text=True,
                env={**os.environ, "QINAO_VERDICT_OUT": str(verdict_path)},
            )
            assert out.returncode == 0, out.stderr
            verdict = json.loads(verdict_path.read_text(encoding="utf-8"))

        row = next(row for row in verdict["rows"] if row["num"] == 30)
        assert (row["status"], verdict["model_eval_ok"]) == ("PENDING", False)
    finally:
        for path in value_paths + humaneval_paths:
            path.unlink(missing_ok=True)


def test_build_verdict_cli_accepts_only_receipt_bound_current_run_humaneval():
    from qinao_humaneval_evidence import (
        HumanEvalProducer,
        HumanEvalRunContext,
        SubjectReceipt,
        build_humaneval_evidence,
    )

    token = f"receipt-{os.getpid()}-{uuid.uuid4().hex}"
    tags = (f"{token}-base", f"{token}-tuned")
    value_paths = [Path("/tmp") / f"qinao_values_{tag}.json" for tag in tags]
    try:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            run_id = "current-receipt-run"
            evidence_dir = root / run_id
            evidence_dir.mkdir()
            subjects = {
                tags[0]: SubjectReceipt("a" * 64, "model", None),
                tags[1]: SubjectReceipt("b" * 64, "model", "adapter"),
            }
            context = HumanEvalRunContext(
                run_id=run_id,
                evidence_dir=evidence_dir,
                dataset_fingerprint="dataset-fingerprint-current",
                subjects=subjects,
            )
            receipt_manifest = root / "subjects.json"
            receipt_manifest.write_text(
                json.dumps(
                    {
                        "schema": "qinao/humaneval-subject-receipts/v1",
                        "subjects": {
                            tag: {
                                "sha256": receipt.sha256,
                                "model": receipt.model,
                                "adapter": receipt.adapter,
                            }
                            for tag, receipt in subjects.items()
                        },
                    }
                ),
                encoding="utf-8",
            )
            outcomes = {"HumanEval/0": 1, "HumanEval/1": 1}
            for tag, value_path in zip(tags, value_paths):
                value_path.write_text(
                    json.dumps(_fully_passing_critical_values()), encoding="utf-8"
                )
                evidence = build_humaneval_evidence(
                    passed=2,
                    total=2,
                    infra_errors=0,
                    per_problem=outcomes,
                    sample_ids=list(outcomes),
                    producer=HumanEvalProducer.PAIRED,
                    context=context,
                    tag=tag,
                )
                (evidence_dir / f"qinao_humaneval_paired_{tag}.json").write_text(
                    json.dumps(evidence), encoding="utf-8"
                )

            verdict_path = root / "verdict.json"
            out = subprocess.run(
                [sys.executable, Path(HERE) / "build_verdict.py", *tags],
                capture_output=True,
                text=True,
                env={
                    **os.environ,
                    "QINAO_VERDICT_OUT": str(verdict_path),
                    "QINAO_EVAL_RUN_ID": run_id,
                    "QINAO_EVAL_EVIDENCE_DIR": str(evidence_dir),
                    "QINAO_SUBJECT_RECEIPTS": str(receipt_manifest),
                    "QINAO_HUMANEVAL_DATASET_FINGERPRINT": context.dataset_fingerprint,
                },
            )
            assert out.returncode == 0, out.stderr
            verdict = json.loads(verdict_path.read_text(encoding="utf-8"))

        row = next(row for row in verdict["rows"] if row["num"] == 30)
        assert row["status"] == "PASS"
        assert verdict["model_eval_ok"] is True
    finally:
        for path in value_paths:
            path.unlink(missing_ok=True)


def test_missing_or_invalid_baseline_for_relative_critical_gate_is_pending():
    tuned = _fully_passing_critical_values()
    for bad_baseline in (None, "not-a-number", True, float("nan"), float("inf")):
        base = dict(tuned)
        if bad_baseline is None:
            base.pop("30")
        else:
            base["30"] = bad_baseline
        verdict = bv.build(base, tuned)
        row = next(row for row in verdict["rows"] if row["num"] == 30)
        assert row["status"] == "PENDING", bad_baseline
        assert verdict["model_eval_ok"] is False, bad_baseline


def test_verifiable_critical_note_blocks_model_eval_ok():
    base = _fully_passing_critical_values()
    tuned = {**base, "83": "not-a-number"}
    verdict = bv.build(base, tuned)
    row = next(row for row in verdict["rows"] if row["num"] == 83)
    assert row["status"] == "NOTE"
    assert verdict["model_eval_ok"] is False


def test_known_foreign_metric_30_owner_blocks_otherwise_passing_model_eval():
    base_seed = _fully_passing_critical_values()
    tuned_seed = _fully_passing_critical_values()
    with tempfile.TemporaryDirectory() as directory:
        for tag in ("base", "tuned"):
            Path(directory, f"qinao_read_{tag}.json").write_text(
                json.dumps({"30": base_seed["30"], "_N": 2, "_infra_errs": 0}),
                encoding="utf-8",
            )
        base = qm.merge_known_sidefiles(base_seed, "base", tmpdir=directory)
        tuned = qm.merge_known_sidefiles(tuned_seed, "tuned", tmpdir=directory)

    verdict = bv.build(base, tuned)
    row = next(row for row in verdict["rows"] if row["num"] == 30)
    assert row["status"] == "PENDING"
    assert verdict["model_eval_ok"] is False


def test_renamed_metric_30_owner_blocks_otherwise_passing_model_eval():
    base_seed = _fully_passing_critical_values()
    tuned_seed = _fully_passing_critical_values()
    with tempfile.TemporaryDirectory() as directory:
        paths = {}
        for tag in ("base", "tuned"):
            path = Path(directory, f"renamed-{tag}.json")
            path.write_text(
                json.dumps({"30": base_seed["30"], "_N": 2, "_infra_errs": 0}),
                encoding="utf-8",
            )
            paths[tag] = path
        base = qm.merge_explicit_sidefiles(base_seed, [paths["base"]])
        tuned = qm.merge_explicit_sidefiles(tuned_seed, [paths["tuned"]])

    verdict = bv.build(base, tuned)
    row = next(row for row in verdict["rows"] if row["num"] == 30)
    assert row["status"] == "PENDING"
    assert verdict["model_eval_ok"] is False


def test_spoofed_humaneval_filename_blocks_otherwise_passing_model_eval():
    """The former startswith(filename) owner inference cannot return."""

    seeds = [_fully_passing_critical_values(), _fully_passing_critical_values()]
    with tempfile.TemporaryDirectory() as directory:
        merged = []
        for tag, seed in zip(("base", "tuned"), seeds):
            path = Path(directory, f"qinao_humaneval_spoof-{tag}.json")
            path.write_text(
                json.dumps({"30": 100.0, "_N": 2, "_infra_errs": 0}),
                encoding="utf-8",
            )
            merged.append(qm.merge_explicit_sidefiles(seed, [path]))

    verdict = bv.build(*merged)
    row = next(row for row in verdict["rows"] if row["num"] == 30)
    assert row["status"] == "PENDING"
    assert verdict["model_eval_ok"] is False


def test_copied_ladder_executes_tools_from_its_own_resolved_directory():
    """A candidate copy must not jump back to the main checkout's harness."""

    with tempfile.TemporaryDirectory() as directory:
        root = Path(directory)
        copied_tools = root / "candidate-tools"
        copied_tools.mkdir()
        ladder = copied_tools / "run_ladder.sh"
        shutil.copy2(Path(HERE) / "run_ladder.sh", ladder)

        fake_home = root / "home"
        fake_python = fake_home / "qwen_honesty_finetune/.venv/bin/python"
        fake_python.parent.mkdir(parents=True)
        (fake_home / "qwen_honesty_finetune").mkdir(exist_ok=True)
        cwd_log = root / "python-cwds.txt"
        fake_python.write_text(
            '#!/bin/sh\nprintf \'%s\\n\' "$PWD" >> "$QINAO_FAKE_CWD_LOG"\nexit 0\n',
            encoding="utf-8",
        )
        fake_python.chmod(0o755)

        run_id = "copied-ladder"
        evidence_dir = root / run_id
        out = subprocess.run(
            ["/bin/bash", str(ladder)],
            cwd=root,
            capture_output=True,
            text=True,
            env={
                **os.environ,
                "HOME": str(fake_home),
                "QINAO_EVAL_RUN_ID": run_id,
                "QINAO_EVAL_EVIDENCE_DIR": str(evidence_dir),
                "QINAO_SUBJECT_RECEIPTS": str(root / "subjects.json"),
                "QINAO_HUMANEVAL_DATASET_FINGERPRINT": "dataset-fingerprint",
                "QINAO_FAKE_CWD_LOG": str(cwd_log),
                "QINAO_LADDER_PREFLIGHT_ONLY": "1",
            },
        )
        assert out.returncode == 0, out.stderr
        observed = cwd_log.read_text(encoding="utf-8").splitlines()

    assert observed
    expected_tools = os.path.realpath(copied_tools)
    expected_home = os.path.realpath(fake_home / "qwen_honesty_finetune")
    observed_real = {os.path.realpath(path) for path in observed}
    assert observed_real <= {expected_tools, expected_home}
    assert expected_tools in observed_real


def test_truncated_json_fails_closed():
    with tempfile.TemporaryDirectory() as d:
        bpath = os.path.join(d, "base.json")
        tpath = os.path.join(d, "tuned.json")
        open(bpath, "w").write('{"27": 45.8}')
        open(tpath, "w").write('{"27": 45.8, "83":')  # truncated / malformed
        out = subprocess.run(
            [sys.executable, os.path.join(HERE, "build_verdict.py"), bpath, tpath],
            capture_output=True,
            text=True,
        )
        assert out.returncode != 0, (
            "malformed values JSON must fail closed (non-zero exit)"
        )


# ---- F3: eval-set fingerprints are re-verified, not just train files ------------


def test_release_gate_fingerprints_eval_sets():
    import release_gate as rg

    # The fingerprint keymap must cover eval sets, not only the 2 train files.
    keys = set(rg.FINGERPRINT_KEYMAP.keys())
    assert any("eval" in k or "held" in k or "test" in k for k in keys), (
        f"eval-set fingerprints missing from keymap: {sorted(keys)}"
    )
    assert len(keys) >= 4, (
        f"expected >=4 fingerprinted files (2 train + eval sets), got {sorted(keys)}"
    )
    assert rg.FINGERPRINT_REQUIRED == {"v6_train", "v6_fix"}


# ---- contamination: genuinely computed, fail-closed on missing data ------------


def _write(path, rows):
    with open(path, "w") as fh:
        for r in rows:
            fh.write(json.dumps(r) + "\n")


def test_contamination_detects_exact_leak():
    import contamination as ct

    with tempfile.TemporaryDirectory() as d:
        train = os.path.join(d, "train.jsonl")
        ev = os.path.join(d, "eval.jsonl")
        _write(
            train,
            [
                {"text": "The capital of France is Paris."},
                {"text": "Water boils at 100 degrees."},
            ],
        )
        _write(
            ev,
            [
                {"question": "The capital of France is Paris."},  # exact leak
                {"question": "Who painted the Mona Lisa?"},
            ],
        )  # clean
        pct = ct.compute_contamination([ev], [train])
        assert pct == 50.0, f"one of two eval items leaks → 50%, got {pct}"


def test_contamination_clean_corpus_is_zero():
    import contamination as ct

    with tempfile.TemporaryDirectory() as d:
        train = os.path.join(d, "train.jsonl")
        ev = os.path.join(d, "eval.jsonl")
        _write(
            train, [{"text": "Completely unrelated training sentence about biology."}]
        )
        _write(
            ev, [{"question": "Who painted the Mona Lisa in the sixteenth century?"}]
        )
        assert ct.compute_contamination([ev], [train]) == 0.0


def test_contamination_missing_data_is_none_not_zero():
    import contamination as ct

    # The crux of F2: absent corpus must be None (→ PENDING), NEVER a silent 0.
    assert (
        ct.compute_contamination(
            ["/nonexistent/eval.jsonl"], ["/nonexistent/train.jsonl"]
        )
        is None
    )


def test_contamination_reads_chat_messages_schema():
    # Adversarial review defect #3 (SEVERE): the real train corpus is chat schema
    # {"messages":[{role,content}]}. Without reading it the check no-ops (→ None) against
    # production. A leaked question in messages format MUST be detected.
    import contamination as ct

    with tempfile.TemporaryDirectory() as d:
        train = os.path.join(d, "train.jsonl")
        ev = os.path.join(d, "eval.jsonl")
        _write(
            train,
            [
                {
                    "messages": [
                        {
                            "role": "user",
                            "content": "What is the capital of France in Europe?",
                        },
                        {"role": "assistant", "content": "Paris."},
                    ]
                }
            ],
        )
        _write(ev, [{"question": "What is the capital of France in Europe?"}])
        pct = ct.compute_contamination([ev], [train])
        assert pct == 100.0, f"chat-schema leak must be detected, got {pct}"


def test_contamination_short_question_embedded_in_train_turn():
    # Adversarial review defect #3(2): a short (<8-token) eval question embedded inside a
    # longer training turn must be caught by substring fallback, not scored falsely clean.
    import contamination as ct

    with tempfile.TemporaryDirectory() as d:
        train = os.path.join(d, "train.jsonl")
        ev = os.path.join(d, "eval.jsonl")
        _write(
            train,
            [
                {
                    "messages": [
                        {
                            "role": "user",
                            "content": "Consider this: is the earth flat? Explain why not in detail.",
                        }
                    ]
                }
            ],
        )
        _write(ev, [{"question": "is the earth flat"}])
        pct = ct.compute_contamination([ev], [train])
        assert pct == 100.0, f"short embedded-substring leak must be caught, got {pct}"


# ---- plain runner (no pytest required in this environment) ----------------------

if __name__ == "__main__":
    import traceback

    tests = sorted(
        (n, f) for n, f in globals().items() if n.startswith("test_") and callable(f)
    )
    passed = failed = 0
    for name, fn in tests:
        try:
            fn()
            passed += 1
            print(f"  PASS {name}")
        except Exception:
            failed += 1
            print(f"  FAIL {name}")
            traceback.print_exc()
    print(f"\n{passed} passed, {failed} failed of {len(tests)}")
    sys.exit(1 if failed else 0)
