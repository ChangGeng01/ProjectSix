"""H23 wire-1/wire-2 teeth: the orphan side-file merge that unblocks the CRITICAL
gates build_verdict never ingested. Pure-Python, no model load. Run:
    uv run --with pytest pytest test_merge_sidefile.py
"""

import json
import os
import pytest
import sys
import tempfile
import threading
from pathlib import Path

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
    merged = qm.merge_sidefile_into_values(
        {}, {"69": 3.2}, "qinao_eval"
    )  # #69 ∉ MODEL_CRITICAL
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
        json.dump(
            {"28": 55.0, "29": 40.0}, open(os.path.join(d, "qinao_bench_T.json"), "w")
        )
        merged = qm.merge_known_sidefiles({}, "T", tmpdir=d)
        assert merged["26"] == 80.0 and merged["28"] == 55.0 and merged["29"] == 40.0
        assert merged["_prov"]["26"]["kind"] == "computed"
        assert merged["_prov"]["28"]["kind"] == "computed"


def _seeded_humaneval_values():
    return {
        "7": 12.5,
        "30": 99.9,
        "_prov": {
            "7": {"kind": "computed", "runner": "keep"},
            "30": {"kind": "computed", "runner": "stale"},
        },
    }


def _valid_standard(score=50.0, sample_count=2):
    return {"30": score, "_N": sample_count, "_infra_errs": 0}


def _valid_paired(score=50.0, sample_count=2):
    if (score, sample_count) == (50.0, 2):
        vector = {"HumanEval/0": 1, "HumanEval/1": 0}
    elif (score, sample_count) == (100.0, 2):
        vector = {"HumanEval/0": 1, "HumanEval/1": 1}
    else:
        raise AssertionError("test fixture requires a hand-checked paired vector")
    return {
        "30": score,
        "_N": sample_count,
        "_infra_errs": 0,
        "per_problem": vector,
    }


def _write_sidefile(directory, prefix, tag, payload):
    path = Path(directory) / f"qinao_{prefix}_{tag}.json"
    path.write_text(json.dumps(payload), encoding="utf-8")
    return path


def _assert_humaneval_pending(base, tuned):
    verdict = bv.build(base, tuned)
    row = next(row for row in verdict["rows"] if row["num"] == 30)
    assert row["status"] == "PENDING"
    assert verdict["model_eval_ok"] is False


def _assert_only_humaneval_was_revoked(values):
    assert "30" not in values
    assert "30" not in values["_prov"]
    assert values["7"] == 12.5
    assert values["_prov"]["7"] == {"kind": "computed", "runner": "keep"}


def test_complete_known_observation_set_without_humaneval_revokes_prior_run():
    with tempfile.TemporaryDirectory() as directory:
        base = qm.merge_known_sidefiles(
            _seeded_humaneval_values(), "base", tmpdir=directory
        )
        tuned = qm.merge_known_sidefiles(
            _seeded_humaneval_values(), "tuned", tmpdir=directory
        )

    _assert_only_humaneval_was_revoked(base)
    _assert_only_humaneval_was_revoked(tuned)
    _assert_humaneval_pending(base, tuned)


def test_one_sided_missing_humaneval_is_pending_in_both_orientations():
    for missing_tag in ("base", "tuned"):
        with tempfile.TemporaryDirectory() as directory:
            context = _current_context(directory)
            from qinao_humaneval_evidence import HumanEvalProducer

            present_tag = "tuned" if missing_tag == "base" else "base"
            _write_sidefile(
                context.evidence_dir,
                "humaneval_paired",
                present_tag,
                _current_evidence(
                    context,
                    tag=present_tag,
                    producer=HumanEvalProducer.PAIRED,
                    outcomes={"HumanEval/0": 1, "HumanEval/1": 0},
                ),
            )
            merged = {
                tag: qm.merge_known_sidefiles(
                    _seeded_humaneval_values(),
                    tag,
                    tmpdir=directory,
                    humaneval_context=context,
                )
                for tag in ("base", "tuned")
            }

        _assert_only_humaneval_was_revoked(merged[missing_tag])
        assert merged[present_tag]["30"] == 50.0
        assert merged[present_tag]["_prov"]["30"]["kind"] == "computed"
        assert merged[present_tag]["_prov"]["30"]["runner"] == "qinao_humaneval_paired"
        _assert_humaneval_pending(merged["base"], merged["tuned"])


def test_explicit_empty_observation_set_revokes_only_prior_run_humaneval():
    merged = qm.merge_explicit_sidefiles(_seeded_humaneval_values(), [])

    _assert_only_humaneval_was_revoked(merged)


def test_explicit_unrelated_sidefile_revokes_prior_run_and_keeps_new_metric():
    with tempfile.TemporaryDirectory() as directory:
        path = Path(directory) / "unrelated.json"
        path.write_text(json.dumps({"26": 80.0}), encoding="utf-8")
        merged = qm.merge_explicit_sidefiles(_seeded_humaneval_values(), [path])

    _assert_only_humaneval_was_revoked(merged)
    assert merged["26"] == 80.0
    assert merged["_prov"]["26"] == {
        "kind": "computed",
        "runner": "unrelated.json",
    }


def test_direct_generic_merge_cannot_preserve_prior_run_humaneval():
    merged = qm.merge_sidefile_into_values(
        _seeded_humaneval_values(), {"26": 80.0}, "generic-runner"
    )

    _assert_only_humaneval_was_revoked(merged)
    assert merged["26"] == 80.0
    assert merged["_prov"]["26"] == {
        "kind": "computed",
        "runner": "generic-runner",
    }


def test_known_unrelated_sidefile_revokes_prior_run_and_keeps_new_metric():
    with tempfile.TemporaryDirectory() as directory:
        _write_sidefile(directory, "read", "current", {"26": 80.0})
        merged = qm.merge_known_sidefiles(
            _seeded_humaneval_values(), "current", tmpdir=directory
        )

    _assert_only_humaneval_was_revoked(merged)
    assert merged["26"] == 80.0
    assert merged["_prov"]["26"] == {
        "kind": "computed",
        "runner": "qinao_reading",
    }


def test_invalid_humaneval_evidence_revokes_only_stale_metric_and_provenance():
    with tempfile.TemporaryDirectory() as directory:
        context = _current_context(directory)
        from qinao_humaneval_evidence import HumanEvalProducer

        valid = _current_evidence(
            context,
            tag="base",
            producer=HumanEvalProducer.PAIRED,
            outcomes={"HumanEval/0": 1, "HumanEval/1": 0},
        )
        invalid_cases = [
            {**valid, "_infra_errs": 1},
            {**valid, "_N": True},
            {**valid, "_N": "2"},
            {**valid, "_sample_count": 0},
            {**valid, "_passed": True},
            {k: v for k, v in valid.items() if k != "_infra_errs"},
            {**valid, "30": float("nan")},
            {**valid, "30": float("inf")},
            {**valid, "30": -0.1},
            {**valid, "30": 100.1},
            {**valid, "per_problem": {"HumanEval/0": 1}},
            {**valid, "_sample_ids": ["HumanEval/0"]},
        ]

        for sidefile in invalid_cases:
            merged = qm.merge_humaneval_sidefile_into_values(
                _seeded_humaneval_values(),
                sidefile,
                producer=HumanEvalProducer.PAIRED,
                context=context,
                tag="base",
            )
            assert "30" not in merged, sidefile
            assert "30" not in merged["_prov"], sidefile
            assert merged["7"] == 12.5
            assert merged["_prov"]["7"] == {
                "kind": "computed",
                "runner": "keep",
            }


def test_all_infrastructure_sidefiles_clear_stale_evidence_and_block_gate():
    with tempfile.TemporaryDirectory() as directory:
        context = _current_context(directory)
        for tag in ("base", "tuned"):
            _write_sidefile(
                context.evidence_dir,
                "humaneval_paired",
                tag,
                _current_unavailable_evidence(context, tag=tag),
            )
        base = qm.merge_known_sidefiles(
            _seeded_humaneval_values(),
            "base",
            tmpdir=directory,
            humaneval_context=context,
        )
        tuned = qm.merge_known_sidefiles(
            _seeded_humaneval_values(),
            "tuned",
            tmpdir=directory,
            humaneval_context=context,
        )

    assert "30" not in base and "30" not in tuned
    assert "30" not in base["_prov"] and "30" not in tuned["_prov"]
    assert _row(base, tuned, 30)["status"] == "PENDING"


def test_baseline_only_infrastructure_is_pending_not_note_or_pass():
    with tempfile.TemporaryDirectory() as directory:
        context = _current_context(directory)
        from qinao_humaneval_evidence import HumanEvalProducer

        _write_sidefile(
            context.evidence_dir,
            "humaneval_paired",
            "base",
            _current_unavailable_evidence(context, tag="base"),
        )
        _write_sidefile(
            context.evidence_dir,
            "humaneval_paired",
            "tuned",
            _current_evidence(
                context,
                tag="tuned",
                producer=HumanEvalProducer.PAIRED,
                outcomes={"HumanEval/0": 1, "HumanEval/1": 0},
            ),
        )
        base = qm.merge_known_sidefiles(
            _seeded_humaneval_values(),
            "base",
            tmpdir=directory,
            humaneval_context=context,
        )
        tuned = qm.merge_known_sidefiles(
            _seeded_humaneval_values(),
            "tuned",
            tmpdir=directory,
            humaneval_context=context,
        )

    assert _row(base, tuned, 30)["status"] == "PENDING"


def test_tuned_only_infrastructure_is_pending_not_pass():
    with tempfile.TemporaryDirectory() as directory:
        context = _current_context(directory)
        from qinao_humaneval_evidence import HumanEvalProducer

        _write_sidefile(
            context.evidence_dir,
            "humaneval_paired",
            "base",
            _current_evidence(
                context,
                tag="base",
                producer=HumanEvalProducer.PAIRED,
                outcomes={"HumanEval/0": 1, "HumanEval/1": 0},
            ),
        )
        _write_sidefile(
            context.evidence_dir,
            "humaneval_paired",
            "tuned",
            _current_unavailable_evidence(context, tag="tuned"),
        )
        base = qm.merge_known_sidefiles(
            _seeded_humaneval_values(),
            "base",
            tmpdir=directory,
            humaneval_context=context,
        )
        tuned = qm.merge_known_sidefiles(
            _seeded_humaneval_values(),
            "tuned",
            tmpdir=directory,
            humaneval_context=context,
        )

    assert _row(base, tuned, 30)["status"] == "PENDING"


def test_agreeing_standard_and_paired_evidence_prefers_paired_and_passes():
    with tempfile.TemporaryDirectory() as directory:
        context = _current_context(directory)
        from qinao_humaneval_evidence import HumanEvalProducer

        for tag in ("base", "tuned"):
            outcomes = {"HumanEval/0": 1, "HumanEval/1": 0}
            _write_sidefile(
                context.evidence_dir,
                "humaneval",
                tag,
                _current_evidence(
                    context,
                    tag=tag,
                    producer=HumanEvalProducer.STANDARD,
                    outcomes=outcomes,
                ),
            )
            _write_sidefile(
                context.evidence_dir,
                "humaneval_paired",
                tag,
                _current_evidence(
                    context,
                    tag=tag,
                    producer=HumanEvalProducer.PAIRED,
                    outcomes=outcomes,
                ),
            )
        base = qm.merge_known_sidefiles(
            _seeded_humaneval_values(),
            "base",
            tmpdir=directory,
            humaneval_context=context,
        )
        tuned = qm.merge_known_sidefiles(
            _seeded_humaneval_values(),
            "tuned",
            tmpdir=directory,
            humaneval_context=context,
        )

    assert base["30"] == 50.0 and tuned["30"] == 50.0
    assert tuned["_prov"]["30"]["kind"] == "computed"
    assert tuned["_prov"]["30"]["runner"] == "qinao_humaneval_paired"
    assert tuned["7"] == 12.5 and tuned["_prov"]["7"]["runner"] == "keep"
    assert _row(base, tuned, 30)["status"] == "PASS"


def test_malformed_non_object_and_unreadable_humaneval_files_revoke_stale_data():
    from qinao_humaneval_evidence import SubjectReceipt

    for tag, payload_kind in (
        ("badjson", "badjson"),
        ("nonobject", "nonobject"),
        ("unreadable", "unreadable"),
    ):
        with tempfile.TemporaryDirectory() as directory:
            context = _current_context(
                directory,
                subjects={tag: SubjectReceipt("a" * 64, "model", None)},
            )
            path = context.evidence_dir / f"qinao_humaneval_{tag}.json"
            if payload_kind == "badjson":
                path.write_text('{"30": 50.0,', encoding="utf-8")
            elif payload_kind == "nonobject":
                path.write_text(json.dumps([1, 2, 3]), encoding="utf-8")
            else:
                path.mkdir()

            merged = qm.merge_known_sidefiles(
                _seeded_humaneval_values(),
                tag,
                tmpdir=directory,
                humaneval_context=context,
            )
            assert "30" not in merged, tag
            assert "30" not in merged["_prov"], tag
            assert merged["7"] == 12.5


def test_conflicting_dual_humaneval_files_fail_closed_for_score_or_sample_count():
    from qinao_humaneval_evidence import HumanEvalProducer, SubjectReceipt

    for mismatch in ("score", "count"):
        with tempfile.TemporaryDirectory() as directory:
            context = _current_context(
                directory,
                subjects={mismatch: SubjectReceipt("a" * 64, "model", None)},
            )
            if mismatch == "score":
                standard_outcomes = {"HumanEval/0": 1, "HumanEval/1": 0}
                paired_outcomes = {"HumanEval/0": 1, "HumanEval/1": 1}
            else:
                standard_outcomes = {
                    "HumanEval/0": 1,
                    "HumanEval/1": 0,
                    "HumanEval/2": 1,
                    "HumanEval/3": 0,
                }
                paired_outcomes = {"HumanEval/0": 1, "HumanEval/1": 0}
            _write_sidefile(
                context.evidence_dir,
                "humaneval",
                mismatch,
                _current_evidence(
                    context,
                    tag=mismatch,
                    producer=HumanEvalProducer.STANDARD,
                    outcomes=standard_outcomes,
                ),
            )
            _write_sidefile(
                context.evidence_dir,
                "humaneval_paired",
                mismatch,
                _current_evidence(
                    context,
                    tag=mismatch,
                    producer=HumanEvalProducer.PAIRED,
                    outcomes=paired_outcomes,
                ),
            )
            merged = qm.merge_known_sidefiles(
                _seeded_humaneval_values(),
                mismatch,
                tmpdir=directory,
                humaneval_context=context,
            )
            assert "30" not in merged, mismatch
            assert "30" not in merged["_prov"], mismatch


def test_legacy_unbound_humaneval_files_are_not_current_run_evidence():
    with tempfile.TemporaryDirectory() as directory:
        Path(directory, "qinao_humaneval_badjson.json").write_text(
            '{"30": 50.0,', encoding="utf-8"
        )
        _write_sidefile(directory, "humaneval", "nonobject", [1, 2, 3])
        Path(directory, "qinao_humaneval_unreadable.json").mkdir()

        for tag in ("badjson", "nonobject", "unreadable"):
            merged = qm.merge_known_sidefiles(
                _seeded_humaneval_values(), tag, tmpdir=directory
            )
            assert "30" not in merged, tag
            assert "30" not in merged["_prov"], tag
            assert merged["7"] == 12.5


def test_known_non_humaneval_metric_30_owner_is_revoked_before_verdict():
    with tempfile.TemporaryDirectory() as directory:
        for tag in ("base", "tuned"):
            _write_sidefile(
                directory,
                "read",
                tag,
                {"26": 80.0, "30": 50.0, "_N": 2, "_infra_errs": 0},
            )
        base = qm.merge_known_sidefiles(
            _seeded_humaneval_values(), "base", tmpdir=directory
        )
        tuned = qm.merge_known_sidefiles(
            _seeded_humaneval_values(), "tuned", tmpdir=directory
        )

    for values in (base, tuned):
        _assert_only_humaneval_was_revoked(values)
        assert values["26"] == 80.0
        assert values["_prov"]["26"] == {
            "kind": "computed",
            "runner": "qinao_reading",
        }
    _assert_humaneval_pending(base, tuned)


def test_renamed_explicit_metric_30_owner_is_revoked_before_verdict():
    with tempfile.TemporaryDirectory() as directory:
        paths = {}
        for tag in ("base", "tuned"):
            path = Path(directory) / f"renamed-{tag}.json"
            path.write_text(json.dumps(_valid_standard()), encoding="utf-8")
            paths[tag] = path
        base = qm.merge_explicit_sidefiles(_seeded_humaneval_values(), [paths["base"]])
        tuned = qm.merge_explicit_sidefiles(
            _seeded_humaneval_values(), [paths["tuned"]]
        )

    _assert_only_humaneval_was_revoked(base)
    _assert_only_humaneval_was_revoked(tuned)
    _assert_humaneval_pending(base, tuned)


def _assert_explicit_metric_30_poison_is_sticky(*, poison_first):
    with tempfile.TemporaryDirectory() as directory:
        merged = {}
        for tag in ("base", "tuned"):
            valid = _write_sidefile(directory, "humaneval", tag, _valid_standard())
            poison = Path(directory) / f"renamed-{tag}.json"
            poison.write_text(json.dumps(_valid_standard()), encoding="utf-8")
            ordered = [poison, valid] if poison_first else [valid, poison]
            merged[tag] = qm.merge_explicit_sidefiles(
                _seeded_humaneval_values(), ordered
            )

    _assert_only_humaneval_was_revoked(merged["base"])
    _assert_only_humaneval_was_revoked(merged["tuned"])
    _assert_humaneval_pending(merged["base"], merged["tuned"])


def test_explicit_metric_30_poison_is_sticky_invalid_then_valid():
    _assert_explicit_metric_30_poison_is_sticky(poison_first=True)


def test_explicit_metric_30_poison_is_sticky_valid_then_invalid():
    _assert_explicit_metric_30_poison_is_sticky(poison_first=False)


def test_legacy_unbound_invalid_humaneval_matrix_reaches_pending_verdict():
    valid = _valid_paired()
    invalid_payloads = {
        "partial-infra": {**valid, "_infra_errs": 1},
        "invalid-n": {**valid, "_N": True},
        "nan": {**valid, "30": float("nan")},
        "positive-inf": {**valid, "30": float("inf")},
        "negative-inf": {**valid, "30": float("-inf")},
        "below-range": {**valid, "30": -0.1},
        "above-range": {**valid, "30": 100.1},
        "non-object": [1, 2, 3],
    }
    with tempfile.TemporaryDirectory() as directory:
        for case, payload in invalid_payloads.items():
            for tag in (f"{case}-base", f"{case}-tuned"):
                _write_sidefile(directory, "humaneval_paired", tag, payload)
            base = qm.merge_known_sidefiles(
                _seeded_humaneval_values(), f"{case}-base", tmpdir=directory
            )
            tuned = qm.merge_known_sidefiles(
                _seeded_humaneval_values(), f"{case}-tuned", tmpdir=directory
            )
            _assert_only_humaneval_was_revoked(base)
            _assert_only_humaneval_was_revoked(tuned)
            _assert_humaneval_pending(base, tuned)


def test_legacy_unbound_malformed_humaneval_reaches_pending_verdict():
    with tempfile.TemporaryDirectory() as directory:
        for tag in ("base", "tuned"):
            Path(directory, f"qinao_humaneval_{tag}.json").write_text(
                '{"30": 50.0,', encoding="utf-8"
            )
        base = qm.merge_known_sidefiles(
            _seeded_humaneval_values(), "base", tmpdir=directory
        )
        tuned = qm.merge_known_sidefiles(
            _seeded_humaneval_values(), "tuned", tmpdir=directory
        )

    _assert_only_humaneval_was_revoked(base)
    _assert_only_humaneval_was_revoked(tuned)
    _assert_humaneval_pending(base, tuned)


def test_legacy_unbound_dual_humaneval_files_reach_pending_verdict():
    with tempfile.TemporaryDirectory() as directory:
        for tag in ("base", "tuned"):
            _write_sidefile(directory, "humaneval", tag, _valid_standard())
            _write_sidefile(directory, "humaneval_paired", tag, _valid_paired(100.0, 2))
        base = qm.merge_known_sidefiles(
            _seeded_humaneval_values(), "base", tmpdir=directory
        )
        tuned = qm.merge_known_sidefiles(
            _seeded_humaneval_values(), "tuned", tmpdir=directory
        )

    _assert_only_humaneval_was_revoked(base)
    _assert_only_humaneval_was_revoked(tuned)
    _assert_humaneval_pending(base, tuned)


# ---- P0 current-run receipt binding ------------------------------------------


def _current_context(directory, *, run_id="run-current", subjects=None):
    from qinao_humaneval_evidence import HumanEvalRunContext, SubjectReceipt

    evidence_dir = Path(directory) / run_id
    evidence_dir.mkdir()
    if subjects is None:
        subjects = {
            "base": SubjectReceipt(
                sha256="a" * 64,
                model="model-receipt",
                adapter=None,
            ),
            "tuned": SubjectReceipt(
                sha256="b" * 64,
                model="model-receipt",
                adapter="adapter-receipt",
            ),
        }
    return HumanEvalRunContext(
        run_id=run_id,
        evidence_dir=evidence_dir,
        dataset_fingerprint="dataset-fingerprint-current",
        subjects=subjects,
    )


def _current_evidence(context, *, tag, producer, outcomes):
    from qinao_humaneval_evidence import build_humaneval_evidence

    return build_humaneval_evidence(
        passed=sum(outcomes.values()),
        total=len(outcomes),
        infra_errors=0,
        per_problem=outcomes if producer.paired else None,
        sample_ids=list(outcomes),
        producer=producer,
        context=context,
        tag=tag,
    )


def _current_unavailable_evidence(context, *, tag):
    from qinao_humaneval_evidence import (
        HumanEvalProducer,
        build_humaneval_evidence,
    )

    return build_humaneval_evidence(
        passed=0,
        total=0,
        infra_errors=164,
        per_problem={},
        sample_ids=[],
        producer=HumanEvalProducer.PAIRED,
        context=context,
        tag=tag,
    )


def test_explicit_standard_and_paired_looking_filenames_cannot_mint_metric_30():
    """Changing only an arbitrary filename must never grant HumanEval ownership."""

    with tempfile.TemporaryDirectory() as directory:
        context = _current_context(directory)
        from qinao_humaneval_evidence import HumanEvalProducer

        payload = _current_evidence(
            context,
            tag="base",
            producer=HumanEvalProducer.STANDARD,
            outcomes={"HumanEval/0": 1, "HumanEval/1": 0},
        )
        for name in (
            "qinao_humaneval_base.json",
            "qinao_humaneval_paired_base.json",
            "qinao_humaneval_spoof-anything.json",
        ):
            path = Path(directory) / name
            path.write_text(json.dumps(payload), encoding="utf-8")
            merged = qm.merge_explicit_sidefiles(_seeded_humaneval_values(), [path])
            _assert_only_humaneval_was_revoked(merged)


def test_known_typed_producer_accepts_only_current_receipt_bound_evidence():
    """The internal known mapping—not a basename—supplies producer authority."""

    with tempfile.TemporaryDirectory() as directory:
        context = _current_context(directory)
        from qinao_humaneval_evidence import HumanEvalProducer

        payload = _current_evidence(
            context,
            tag="base",
            producer=HumanEvalProducer.PAIRED,
            outcomes={"HumanEval/0": 1, "HumanEval/1": 0},
        )
        _write_sidefile(
            context.evidence_dir,
            "humaneval_paired",
            "base",
            payload,
        )
        merged = qm.merge_known_sidefiles(
            _seeded_humaneval_values(),
            "base",
            tmpdir=directory,
            humaneval_context=context,
        )

    assert merged["30"] == 50.0
    receipt = merged["_prov"]["30"]["evidence"]
    assert receipt["run_id"] == "run-current"
    assert receipt["subject_sha256"] == "a" * 64
    assert receipt["dataset_fingerprint"] == "dataset-fingerprint-current"
    assert receipt["sample_count"] == 2
    assert len(receipt["sample_set_sha256"]) == 64


def _assert_external_observation_cannot_bypass_pending_marker(observation_factory):
    from qinao_humaneval_evidence import HumanEvalProducer

    with tempfile.TemporaryDirectory() as directory:
        root = Path(directory)
        context = _current_context(root, run_id="closed-observation")
        payload = _current_evidence(
            context,
            tag="base",
            producer=HumanEvalProducer.PAIRED,
            outcomes={"HumanEval/0": 1, "HumanEval/1": 0},
        )
        (context.evidence_dir / ".qinao_humaneval_base.attempt.pending").write_text(
            "pending\n", encoding="utf-8"
        )
        attacker_dir = root / "attacker"
        attacker_dir.mkdir()
        _write_sidefile(attacker_dir, "humaneval_paired", "base", payload)
        attacker_descriptor = os.open(
            attacker_dir, os.O_RDONLY | getattr(os, "O_DIRECTORY", 0)
        )
        try:
            observation = observation_factory(context, attacker_descriptor)
            merged = qm.merge_known_sidefiles(
                _seeded_humaneval_values(),
                "base",
                tmpdir=directory,
                humaneval_context=context,
                humaneval_observation=observation,
            )
        finally:
            os.close(attacker_descriptor)
    _assert_only_humaneval_was_revoked(merged)
    return observation


def test_fake_observation_cannot_supply_an_attacker_directory_descriptor():
    class FakeObservation:
        def __init__(self, descriptor):
            self.descriptor = descriptor
            self.snapshot_called = False

        def snapshot_for(self, _context, _tag):
            self.snapshot_called = True
            return self.descriptor, False

    observation = _assert_external_observation_cannot_bypass_pending_marker(
        lambda _context, descriptor: FakeObservation(descriptor)
    )
    assert observation.snapshot_called is False


def test_observation_subclass_override_cannot_supply_attacker_descriptor():
    from qinao_humaneval_evidence import HumanEvalObservation

    class ForgedObservation(HumanEvalObservation):
        def __init__(self, context, descriptor):
            super().__init__(context, "base")
            self.attacker_descriptor = descriptor
            self.snapshot_called = False

        def snapshot_for(self, _context, _tag):
            self.snapshot_called = True
            return self.attacker_descriptor, False

    observation = _assert_external_observation_cannot_bypass_pending_marker(
        ForgedObservation
    )
    assert observation.snapshot_called is False


def test_external_observation_requires_live_matching_runtime_state():
    from qinao_humaneval_evidence import (
        HumanEvalObservation,
        HumanEvalObservationSet,
    )

    with tempfile.TemporaryDirectory() as directory:
        root = Path(directory)
        context = _current_context(root, run_id="observation-lifecycle")
        other_context = _current_context(root, run_id="other-observation-context")
        invalid_observations = [
            (HumanEvalObservation(context, "base"), context, "base"),
            (HumanEvalObservationSet(context, ("base", "tuned")), context, "base"),
        ]
        for observation, observed_context, tag in invalid_observations:
            merged = qm.merge_known_sidefiles(
                _seeded_humaneval_values(),
                tag,
                tmpdir=directory,
                humaneval_context=observed_context,
                humaneval_observation=observation,
            )
            _assert_only_humaneval_was_revoked(merged)

            observation.__enter__()
            observation.__exit__(None, None, None)
            merged = qm.merge_known_sidefiles(
                _seeded_humaneval_values(),
                tag,
                tmpdir=directory,
                humaneval_context=observed_context,
                humaneval_observation=observation,
            )
            _assert_only_humaneval_was_revoked(merged)

        with HumanEvalObservation(context, "base") as active:
            for observed_context, tag in (
                (context, "tuned"),
                (other_context, "base"),
            ):
                merged = qm.merge_known_sidefiles(
                    _seeded_humaneval_values(),
                    tag,
                    tmpdir=directory,
                    humaneval_context=observed_context,
                    humaneval_observation=active,
                )
                _assert_only_humaneval_was_revoked(merged)

            saved_lock = active._lock_descriptor
            active._lock_descriptor = None
            try:
                merged = qm.merge_known_sidefiles(
                    _seeded_humaneval_values(),
                    "base",
                    tmpdir=directory,
                    humaneval_context=context,
                    humaneval_observation=active,
                )
                _assert_only_humaneval_was_revoked(merged)
            finally:
                active._lock_descriptor = saved_lock

        with HumanEvalObservationSet(context, ("base", "tuned")) as active_set:
            with pytest.raises(ValueError, match="cover"):
                active_set.snapshot_for(other_context, "base")
            saved_lock = active_set._lock_descriptors.pop()
            try:
                merged = qm.merge_known_sidefiles(
                    _seeded_humaneval_values(),
                    "base",
                    tmpdir=directory,
                    humaneval_context=context,
                    humaneval_observation=active_set,
                )
                _assert_only_humaneval_was_revoked(merged)
            finally:
                active_set._lock_descriptors.append(saved_lock)


def test_replayed_or_misbound_humaneval_evidence_is_revoked():
    """Old run, wrong subject, old harness, or wrong dataset cannot certify #30."""

    with tempfile.TemporaryDirectory() as directory:
        context = _current_context(directory)
        from qinao_humaneval_evidence import HumanEvalProducer

        valid = _current_evidence(
            context,
            tag="base",
            producer=HumanEvalProducer.PAIRED,
            outcomes={"HumanEval/0": 1, "HumanEval/1": 0},
        )
        mutations = {
            "_run_id": "run-old",
            "_subject_sha256": "c" * 64,
            "_harness_sha256": "d" * 64,
            "_dataset_fingerprint": "dataset-fingerprint-old",
        }
        for field, replacement in mutations.items():
            payload = {**valid, field: replacement}
            _write_sidefile(
                context.evidence_dir,
                "humaneval_paired",
                "base",
                payload,
            )
            merged = qm.merge_known_sidefiles(
                _seeded_humaneval_values(),
                "base",
                tmpdir=directory,
                humaneval_context=context,
            )
            _assert_only_humaneval_was_revoked(merged)


def test_build_verdict_rejects_disjoint_humaneval_sample_sets():
    """Equal-looking aggregate scores from different tasks are not comparable."""

    with tempfile.TemporaryDirectory() as directory:
        context = _current_context(directory)
        from qinao_humaneval_evidence import HumanEvalProducer

        base_payload = _current_evidence(
            context,
            tag="base",
            producer=HumanEvalProducer.PAIRED,
            outcomes={"HumanEval/0": 1, "HumanEval/1": 0},
        )
        tuned_payload = _current_evidence(
            context,
            tag="tuned",
            producer=HumanEvalProducer.PAIRED,
            outcomes={"HumanEval/2": 1, "HumanEval/3": 1},
        )
        _write_sidefile(context.evidence_dir, "humaneval_paired", "base", base_payload)
        _write_sidefile(
            context.evidence_dir, "humaneval_paired", "tuned", tuned_payload
        )
        base = qm.merge_known_sidefiles(
            _seeded_humaneval_values(),
            "base",
            tmpdir=directory,
            humaneval_context=context,
        )
        tuned = qm.merge_known_sidefiles(
            _seeded_humaneval_values(),
            "tuned",
            tmpdir=directory,
            humaneval_context=context,
        )

    row = _row(base, tuned, 30)
    assert row["status"] == "PENDING"
    assert "sample set" in row["note"]
    assert bv.build(base, tuned)["model_eval_ok"] is False


def test_build_verdict_requires_every_humaneval_comparability_receipt():
    with tempfile.TemporaryDirectory() as directory:
        context = _current_context(directory)
        from qinao_humaneval_evidence import HumanEvalProducer

        for tag in ("base", "tuned"):
            payload = _current_evidence(
                context,
                tag=tag,
                producer=HumanEvalProducer.PAIRED,
                outcomes={"HumanEval/0": 1, "HumanEval/1": 0},
            )
            _write_sidefile(context.evidence_dir, "humaneval_paired", tag, payload)
        base = qm.merge_known_sidefiles(
            _seeded_humaneval_values(),
            "base",
            tmpdir=directory,
            humaneval_context=context,
        )
        tuned = qm.merge_known_sidefiles(
            _seeded_humaneval_values(),
            "tuned",
            tmpdir=directory,
            humaneval_context=context,
        )

    assert _row(base, tuned, 30)["status"] == "PASS"
    mutations = {
        "producer": "qinao_humaneval",
        "run_id": "another-run",
        "harness_sha256": "c" * 64,
        "dataset_id": "another/dataset",
        "dataset_split": "validation",
        "dataset_fingerprint": "another-fingerprint",
        "sample_set_sha256": "d" * 64,
        "sample_count": 1,
    }
    for field, replacement in mutations.items():
        changed = json.loads(json.dumps(tuned))
        evidence = changed["_prov"]["30"]["evidence"]
        evidence[field] = replacement
        if field == "producer":
            changed["_prov"]["30"]["runner"] = replacement
        row = _row(base, changed, 30)
        assert row["status"] == "PENDING", field


def test_base_and_tuned_subjects_are_validated_against_their_own_receipts():
    with tempfile.TemporaryDirectory() as directory:
        context = _current_context(directory)
        from qinao_humaneval_evidence import HumanEvalProducer

        merged = {}
        for tag in ("base", "tuned"):
            payload = _current_evidence(
                context,
                tag=tag,
                producer=HumanEvalProducer.PAIRED,
                outcomes={"HumanEval/0": 1, "HumanEval/1": 0},
            )
            _write_sidefile(context.evidence_dir, "humaneval_paired", tag, payload)
            merged[tag] = qm.merge_known_sidefiles(
                _seeded_humaneval_values(),
                tag,
                tmpdir=directory,
                humaneval_context=context,
            )

    assert merged["base"]["_prov"]["30"]["evidence"]["subject_sha256"] == "a" * 64
    assert merged["tuned"]["_prov"]["30"]["evidence"]["subject_sha256"] == "b" * 64
    assert _row(merged["base"], merged["tuned"], 30)["status"] == "PASS"


def test_known_humaneval_read_rejects_replaced_context_directory():
    """A validated pathname cannot later redirect evidence reads through a symlink."""

    with tempfile.TemporaryDirectory() as directory:
        root = Path(directory)
        context = _current_context(root, run_id="anchored-read")
        from qinao_humaneval_evidence import HumanEvalProducer

        payload = _current_evidence(
            context,
            tag="base",
            producer=HumanEvalProducer.PAIRED,
            outcomes={"HumanEval/0": 1, "HumanEval/1": 0},
        )
        captured = root / "captured-original"
        context.evidence_dir.rename(captured)
        attacker = root / "attacker"
        attacker.mkdir()
        _write_sidefile(attacker, "humaneval_paired", "base", payload)
        context.evidence_dir.symlink_to(attacker, target_is_directory=True)

        merged = qm.merge_known_sidefiles(
            _seeded_humaneval_values(),
            "base",
            tmpdir=directory,
            humaneval_context=context,
        )

    _assert_only_humaneval_was_revoked(merged)


def test_build_verdict_rejects_same_tag_and_same_subject_identity():
    from qinao_humaneval_evidence import SubjectReceipt

    with tempfile.TemporaryDirectory() as directory:
        subjects = {
            "base": SubjectReceipt("a" * 64, "model", None),
            "tuned": SubjectReceipt("a" * 64, "model", "adapter"),
        }
        context = _current_context(directory, subjects=subjects)
        from qinao_humaneval_evidence import HumanEvalProducer

        merged = {}
        for tag in ("base", "tuned"):
            payload = _current_evidence(
                context,
                tag=tag,
                producer=HumanEvalProducer.PAIRED,
                outcomes={"HumanEval/0": 1, "HumanEval/1": 0},
            )
            _write_sidefile(context.evidence_dir, "humaneval_paired", tag, payload)
            merged[tag] = qm.merge_known_sidefiles(
                _seeded_humaneval_values(),
                tag,
                tmpdir=directory,
                humaneval_context=context,
            )

    same_subject = _row(merged["base"], merged["tuned"], 30)
    assert same_subject["status"] == "PENDING"
    assert "subject" in same_subject["note"]

    same_tag = _row(merged["base"], merged["base"], 30)
    assert same_tag["status"] == "PENDING"
    assert "tag" in same_tag["note"]


def test_humaneval_provenance_binds_value_score_and_passed_count():
    with tempfile.TemporaryDirectory() as directory:
        context = _current_context(directory)
        from qinao_humaneval_evidence import HumanEvalProducer

        merged = {}
        for tag in ("base", "tuned"):
            payload = _current_evidence(
                context,
                tag=tag,
                producer=HumanEvalProducer.PAIRED,
                outcomes={"HumanEval/0": 1, "HumanEval/1": 0},
            )
            _write_sidefile(context.evidence_dir, "humaneval_paired", tag, payload)
            merged[tag] = qm.merge_known_sidefiles(
                _seeded_humaneval_values(),
                tag,
                tmpdir=directory,
                humaneval_context=context,
            )

    receipt = merged["tuned"]["_prov"]["30"]["evidence"]
    assert receipt["score"] == 50.0
    assert receipt["passed"] == 1
    assert _row(merged["base"], merged["tuned"], 30)["status"] == "PASS"

    score_drift = json.loads(json.dumps(merged["tuned"]))
    score_drift["30"] = 100.0
    assert _row(merged["base"], score_drift, 30)["status"] == "PENDING"

    passed_drift = json.loads(json.dumps(merged["tuned"]))
    passed_drift["_prov"]["30"]["evidence"]["passed"] = 2
    assert _row(merged["base"], passed_drift, 30)["status"] == "PENDING"

    string_value = json.loads(json.dumps(merged["tuned"]))
    string_value["30"] = "50.0"
    assert _row(merged["base"], string_value, 30)["status"] == "PENDING"

    string_score = json.loads(json.dumps(merged["tuned"]))
    string_score["_prov"]["30"]["evidence"]["score"] = "50.0"
    assert _row(merged["base"], string_score, 30)["status"] == "PENDING"


def test_merge_waits_for_admitted_attempt_before_reading_old_publication():
    from qinao_humaneval_evidence import (
        HumanEvalProducer,
        prepare_humaneval_output,
    )

    with tempfile.TemporaryDirectory() as directory:
        context = _current_context(directory)
        old_payload = _current_evidence(
            context,
            tag="base",
            producer=HumanEvalProducer.PAIRED,
            outcomes={"HumanEval/0": 1, "HumanEval/1": 0},
        )
        _write_sidefile(
            context.evidence_dir, "humaneval_paired", "base", old_payload
        )

        attempt = prepare_humaneval_output(
            context, HumanEvalProducer.STANDARD, "base"
        )
        admitted = threading.Event()
        release_invalidation = threading.Event()
        writer_finished = threading.Event()
        writer_errors = []
        real_invalidate = attempt._invalidate

        def paused_invalidation():
            admitted.set()
            assert release_invalidation.wait(2)
            real_invalidate()

        attempt._invalidate = paused_invalidation

        def run_writer():
            try:
                with attempt:
                    pass
            except BaseException as error:
                writer_errors.append(error)
            finally:
                writer_finished.set()

        writer = threading.Thread(target=run_writer, daemon=True)
        writer.start()
        assert admitted.wait(2)

        merge_finished = threading.Event()
        merged = {}

        def run_merge():
            merged["values"] = qm.merge_known_sidefiles(
                _seeded_humaneval_values(),
                "base",
                tmpdir=directory,
                humaneval_context=context,
            )
            merge_finished.set()

        reader = threading.Thread(target=run_merge, daemon=True)
        reader.start()
        reader_was_blocked = not merge_finished.wait(0.2)
        release_invalidation.set()
        assert writer_finished.wait(2)
        assert merge_finished.wait(2)
        writer.join(timeout=0)
        reader.join(timeout=0)

        assert reader_was_blocked, "merge bypassed the admitted writer transaction"
        assert writer_errors == []
        _assert_only_humaneval_was_revoked(merged["values"])


def test_abrupt_exit_immediately_after_attempt_admission_revokes_old_output():
    from qinao_humaneval_evidence import (
        HumanEvalProducer,
        prepare_humaneval_output,
    )

    with tempfile.TemporaryDirectory() as directory:
        context = _current_context(directory)
        old_payload = _current_evidence(
            context,
            tag="base",
            producer=HumanEvalProducer.PAIRED,
            outcomes={"HumanEval/0": 1, "HumanEval/1": 0},
        )
        _write_sidefile(
            context.evidence_dir, "humaneval_paired", "base", old_payload
        )

        child = os.fork()
        if child == 0:
            attempt = prepare_humaneval_output(
                context, HumanEvalProducer.STANDARD, "base"
            )
            attempt._invalidate = lambda: os._exit(73)
            with attempt:
                pass
            os._exit(74)

        waited_child, status = os.waitpid(child, 0)
        assert waited_child == child
        assert os.WIFEXITED(status) and os.WEXITSTATUS(status) == 73
        merged = qm.merge_known_sidefiles(
            _seeded_humaneval_values(),
            "base",
            tmpdir=directory,
            humaneval_context=context,
        )

        _assert_only_humaneval_was_revoked(merged)


def test_typed_api_requires_matching_anchored_producer_publication():
    from qinao_humaneval_evidence import HumanEvalProducer

    with tempfile.TemporaryDirectory() as directory:
        context = _current_context(directory)
        fifty = _current_evidence(
            context,
            tag="base",
            producer=HumanEvalProducer.PAIRED,
            outcomes={"HumanEval/0": 1, "HumanEval/1": 0},
        )
        hundred = _current_evidence(
            context,
            tag="base",
            producer=HumanEvalProducer.PAIRED,
            outcomes={"HumanEval/0": 1, "HumanEval/1": 1},
        )

        unpublished = qm.merge_humaneval_sidefile_into_values(
            _seeded_humaneval_values(),
            fifty,
            producer=HumanEvalProducer.PAIRED,
            context=context,
            tag="base",
        )
        _assert_only_humaneval_was_revoked(unpublished)

        output = _write_sidefile(
            context.evidence_dir, "humaneval_paired", "base", fifty
        )
        mismatched = qm.merge_humaneval_sidefile_into_values(
            _seeded_humaneval_values(),
            hundred,
            producer=HumanEvalProducer.PAIRED,
            context=context,
            tag="base",
        )
        _assert_only_humaneval_was_revoked(mismatched)

        matched = qm.merge_humaneval_sidefile_into_values(
            _seeded_humaneval_values(),
            fifty,
            producer=HumanEvalProducer.PAIRED,
            context=context,
            tag="base",
        )
        assert matched["30"] == 50.0

        target = Path(directory) / "outside.json"
        target.write_text(json.dumps(fifty), encoding="utf-8")
        output.unlink()
        output.symlink_to(target)
        symlinked = qm.merge_humaneval_sidefile_into_values(
            _seeded_humaneval_values(),
            fifty,
            producer=HumanEvalProducer.PAIRED,
            context=context,
            tag="base",
        )
        _assert_only_humaneval_was_revoked(symlinked)


def test_successful_retry_prunes_stale_failed_attempt_tombstone():
    from qinao_humaneval_evidence import (
        HumanEvalProducer,
        atomic_write_humaneval_evidence,
        prepare_humaneval_output,
    )

    with tempfile.TemporaryDirectory() as directory:
        context = _current_context(directory)
        payload = _current_evidence(
            context,
            tag="base",
            producer=HumanEvalProducer.PAIRED,
            outcomes={"HumanEval/0": 1, "HumanEval/1": 0},
        )
        with prepare_humaneval_output(
            context, HumanEvalProducer.STANDARD, "base"
        ):
            pass
        assert list(
            context.evidence_dir.glob(".qinao_humaneval_base.attempt.*")
        )

        with prepare_humaneval_output(
            context, HumanEvalProducer.PAIRED, "base"
        ) as retry:
            atomic_write_humaneval_evidence(retry, payload)

        assert not list(
            context.evidence_dir.glob(".qinao_humaneval_base.attempt.*")
        )
        merged = qm.merge_known_sidefiles(
            _seeded_humaneval_values(),
            "base",
            tmpdir=directory,
            humaneval_context=context,
        )
        assert merged["30"] == 50.0
