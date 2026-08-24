"""H23 wire-1/wire-2 teeth: the orphan side-file merge that unblocks the CRITICAL
gates build_verdict never ingested. Pure-Python, no model load. Run:
    uv run --with pytest pytest test_merge_sidefile.py
"""
import json
import os
import sys
import tempfile
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
            present_tag = "tuned" if missing_tag == "base" else "base"
            _write_sidefile(
                directory, "humaneval_paired", present_tag, _valid_paired()
            )
            merged = {
                tag: qm.merge_known_sidefiles(
                    _seeded_humaneval_values(), tag, tmpdir=directory
                )
                for tag in ("base", "tuned")
            }

        _assert_only_humaneval_was_revoked(merged[missing_tag])
        assert merged[present_tag]["30"] == 50.0
        assert merged[present_tag]["_prov"]["30"] == {
            "kind": "computed",
            "runner": "qinao_humaneval_paired",
        }
        _assert_humaneval_pending(merged["base"], merged["tuned"])


def test_explicit_empty_observation_set_revokes_only_prior_run_humaneval():
    merged = qm.merge_explicit_sidefiles(_seeded_humaneval_values(), [])

    _assert_only_humaneval_was_revoked(merged)


def test_explicit_unrelated_sidefile_revokes_prior_run_and_keeps_new_metric():
    with tempfile.TemporaryDirectory() as directory:
        path = Path(directory) / "unrelated.json"
        path.write_text(json.dumps({"26": 80.0}), encoding="utf-8")
        merged = qm.merge_explicit_sidefiles(
            _seeded_humaneval_values(), [path]
        )

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
    valid = _valid_paired()
    invalid_cases = [
        {"_N": 0, "_infra_errs": 164, "per_problem": {}},
        {**valid, "_infra_errs": 1},
        {**valid, "_N": True},
        {**valid, "_N": "2"},
        {**valid, "_infra_errs": False},
        {k: v for k, v in valid.items() if k != "_infra_errs"},
        {**valid, "30": float("nan")},
        {**valid, "30": float("inf")},
        {**valid, "30": -0.1},
        {**valid, "30": 100.1},
        {**valid, "per_problem": {"HumanEval/0": 1}},
    ]

    for sidefile in invalid_cases:
        merged = qm.merge_sidefile_into_values(
            _seeded_humaneval_values(), sidefile, "qinao_humaneval_paired"
        )
        assert "30" not in merged, sidefile
        assert "30" not in merged["_prov"], sidefile
        assert merged["7"] == 12.5
        assert merged["_prov"]["7"] == {"kind": "computed", "runner": "keep"}


def test_all_infrastructure_sidefiles_clear_stale_evidence_and_block_gate():
    unavailable = {"_N": 0, "_infra_errs": 164, "per_problem": {}}
    with tempfile.TemporaryDirectory() as directory:
        _write_sidefile(directory, "humaneval_paired", "base", unavailable)
        _write_sidefile(directory, "humaneval_paired", "tuned", unavailable)
        base = qm.merge_known_sidefiles(
            _seeded_humaneval_values(), "base", tmpdir=directory
        )
        tuned = qm.merge_known_sidefiles(
            _seeded_humaneval_values(), "tuned", tmpdir=directory
        )

    assert "30" not in base and "30" not in tuned
    assert "30" not in base["_prov"] and "30" not in tuned["_prov"]
    assert _row(base, tuned, 30)["status"] == "PENDING"


def test_baseline_only_infrastructure_is_pending_not_note_or_pass():
    unavailable = {"_N": 0, "_infra_errs": 164, "per_problem": {}}
    with tempfile.TemporaryDirectory() as directory:
        _write_sidefile(directory, "humaneval_paired", "base", unavailable)
        _write_sidefile(directory, "humaneval_paired", "tuned", _valid_paired())
        base = qm.merge_known_sidefiles(
            _seeded_humaneval_values(), "base", tmpdir=directory
        )
        tuned = qm.merge_known_sidefiles(
            _seeded_humaneval_values(), "tuned", tmpdir=directory
        )

    assert _row(base, tuned, 30)["status"] == "PENDING"


def test_tuned_only_infrastructure_is_pending_not_pass():
    unavailable = {"_N": 0, "_infra_errs": 164, "per_problem": {}}
    with tempfile.TemporaryDirectory() as directory:
        _write_sidefile(directory, "humaneval_paired", "base", _valid_paired())
        _write_sidefile(directory, "humaneval_paired", "tuned", unavailable)
        base = qm.merge_known_sidefiles(
            _seeded_humaneval_values(), "base", tmpdir=directory
        )
        tuned = qm.merge_known_sidefiles(
            _seeded_humaneval_values(), "tuned", tmpdir=directory
        )

    assert _row(base, tuned, 30)["status"] == "PENDING"


def test_agreeing_standard_and_paired_evidence_prefers_paired_and_passes():
    with tempfile.TemporaryDirectory() as directory:
        for tag in ("base", "tuned"):
            _write_sidefile(directory, "humaneval", tag, _valid_standard())
            _write_sidefile(directory, "humaneval_paired", tag, _valid_paired())
        base = qm.merge_known_sidefiles(
            _seeded_humaneval_values(), "base", tmpdir=directory
        )
        tuned = qm.merge_known_sidefiles(
            _seeded_humaneval_values(), "tuned", tmpdir=directory
        )

    assert base["30"] == 50.0 and tuned["30"] == 50.0
    assert tuned["_prov"]["30"] == {
        "kind": "computed",
        "runner": "qinao_humaneval_paired",
    }
    assert tuned["7"] == 12.5 and tuned["_prov"]["7"]["runner"] == "keep"
    assert _row(base, tuned, 30)["status"] == "PASS"


def test_malformed_non_object_and_unreadable_humaneval_files_revoke_stale_data():
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


def test_conflicting_dual_humaneval_files_fail_closed_for_score_or_sample_count():
    with tempfile.TemporaryDirectory() as directory:
        _write_sidefile(directory, "humaneval", "score", _valid_standard())
        _write_sidefile(
            directory, "humaneval_paired", "score", _valid_paired(100.0, 2)
        )
        _write_sidefile(directory, "humaneval", "count", _valid_standard(50.0, 4))
        _write_sidefile(directory, "humaneval_paired", "count", _valid_paired())

        for tag in ("score", "count"):
            merged = qm.merge_known_sidefiles(
                _seeded_humaneval_values(), tag, tmpdir=directory
            )
            assert "30" not in merged, tag
            assert "30" not in merged["_prov"], tag


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
        base = qm.merge_explicit_sidefiles(
            _seeded_humaneval_values(), [paths["base"]]
        )
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
            valid = _write_sidefile(
                directory, "humaneval", tag, _valid_standard()
            )
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


def test_invalid_known_humaneval_matrix_reaches_pending_verdict():
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


def test_malformed_known_humaneval_reaches_pending_verdict():
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


def test_dual_humaneval_conflict_reaches_pending_verdict():
    with tempfile.TemporaryDirectory() as directory:
        for tag in ("base", "tuned"):
            _write_sidefile(directory, "humaneval", tag, _valid_standard())
            _write_sidefile(
                directory, "humaneval_paired", tag, _valid_paired(100.0, 2)
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
