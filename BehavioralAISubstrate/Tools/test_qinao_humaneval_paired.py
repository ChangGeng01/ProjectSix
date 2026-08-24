"""audit tools-scripts LOW / decision 7 teeth: qinao_humaneval_paired must EXCLUDE infra errors from
the pass@1 denominator (mirroring the sibling qinao_humaneval.py fix). The module's heavy deps are
now imported lazily inside main(), so the pure helper imports without mlx_lm/datasets present.
Run: uv run --with pytest pytest test_qinao_humaneval_paired.py
"""

import os
import sys
import builtins
import json
import threading
import types
from pathlib import Path

import pytest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "qinao_local_eval"))
import qinao_humaneval_paired as hp  # noqa: E402
import qinao_humaneval as hs  # noqa: E402


def test_execute_generated_program_delegates_to_sandbox():
    calls = []
    sentinel = object()

    def recording_run_sandboxed(pybin, script_path, timeout):
        calls.append((pybin, script_path, timeout))
        return sentinel

    original = hp.run_sandboxed
    hp.run_sandboxed = recording_run_sandboxed
    try:
        result = hp.execute_generated_program(
            "/exact/python",
            "/exact/generated.py",
            timeout=23,
        )
    finally:
        hp.run_sandboxed = original

    assert calls == [("/exact/python", "/exact/generated.py", 23)]
    assert result is sentinel


def test_infra_errors_excluded_ran_and_timeout_counted():
    # 'ran' and 'timeout' are model-attributable outcomes ⇒ count toward the denominator.
    assert hp.counts_toward_denominator("ran") is True, "an executed run counts"
    assert hp.counts_toward_denominator("timeout") is True, (
        "a hung program is a legitimate wrong answer"
    )
    # 'infra' is a harness failure ⇒ EXCLUDED (reverting to always-True reds this — the false-0% bug).
    assert hp.counts_toward_denominator("infra") is False, (
        "an infra error must be EXCLUDED from the denominator, not scored as a model failure"
    )


def test_shared_evidence_omits_metric_for_any_infrastructure_failure():
    import tempfile
    from qinao_humaneval_evidence import (
        HumanEvalProducer,
        HumanEvalRunContext,
        SubjectReceipt,
        build_humaneval_evidence,
    )

    temporary = tempfile.TemporaryDirectory()
    run_id = "infra-evidence"
    evidence_dir = Path(temporary.name) / run_id
    evidence_dir.mkdir()
    context = HumanEvalRunContext(
        run_id=run_id,
        evidence_dir=evidence_dir,
        dataset_fingerprint="dataset-fingerprint-current",
        subjects={"base": SubjectReceipt("a" * 64, "model", None)},
    )

    all_infra = build_humaneval_evidence(
        passed=0,
        total=0,
        infra_errors=164,
        per_problem={},
        sample_ids=[],
        producer=HumanEvalProducer.PAIRED,
        context=context,
        tag="base",
    )
    partial_infra = build_humaneval_evidence(
        passed=1,
        total=2,
        infra_errors=1,
        per_problem={"HumanEval/0": 1, "HumanEval/1": 0},
        sample_ids=["HumanEval/0", "HumanEval/1"],
        producer=HumanEvalProducer.PAIRED,
        context=context,
        tag="base",
    )
    complete = build_humaneval_evidence(
        passed=1,
        total=2,
        infra_errors=0,
        per_problem={"HumanEval/0": 1, "HumanEval/1": 0},
        sample_ids=["HumanEval/0", "HumanEval/1"],
        producer=HumanEvalProducer.PAIRED,
        context=context,
        tag="base",
    )

    assert "30" not in all_infra
    assert all_infra["_N"] == 0
    assert all_infra["_sample_count"] == 0
    assert all_infra["per_problem"] == {}
    assert "30" not in partial_infra
    assert partial_infra["_infra_errs"] == 1
    assert complete["30"] == 50.0
    assert complete["_infra_errs"] == 0
    temporary.cleanup()


def test_paired_evidence_requires_a_consistent_complete_vector():
    import tempfile
    from qinao_humaneval_evidence import (
        HumanEvalProducer,
        HumanEvalRunContext,
        SubjectReceipt,
        build_humaneval_evidence,
        validate_humaneval_evidence,
    )

    temporary = tempfile.TemporaryDirectory()
    run_id = "paired-vector"
    evidence_dir = Path(temporary.name) / run_id
    evidence_dir.mkdir()
    context = HumanEvalRunContext(
        run_id=run_id,
        evidence_dir=evidence_dir,
        dataset_fingerprint="dataset-fingerprint-current",
        subjects={"base": SubjectReceipt("a" * 64, "model", None)},
    )
    valid = build_humaneval_evidence(
        passed=1,
        total=2,
        infra_errors=0,
        per_problem={"HumanEval/0": 1, "HumanEval/1": 0},
        sample_ids=["HumanEval/0", "HumanEval/1"],
        producer=HumanEvalProducer.PAIRED,
        context=context,
        tag="base",
    )
    wrong_length = {**valid, "per_problem": {"HumanEval/0": 1}}
    wrong_score = {**valid, "30": 100.0}
    wrong_value = {**valid, "per_problem": {"HumanEval/0": True, "HumanEval/1": 0}}

    def validate(payload):
        return validate_humaneval_evidence(
            payload,
            producer=HumanEvalProducer.PAIRED,
            context=context,
            tag="base",
        )

    summary = validate(valid)
    assert summary is not None
    assert (summary.score, summary.sample_count) == (50.0, 2)
    assert validate(wrong_length) is None
    assert validate(wrong_score) is None
    assert validate(wrong_value) is None
    temporary.cleanup()


def test_paired_main_invalidates_old_output_before_heavy_model_import(
    tmp_path, monkeypatch
):
    """A crash before model load must leave no prior-run success to replay."""

    run_id = "run-before-model"
    evidence_dir = tmp_path / run_id
    evidence_dir.mkdir()
    output = evidence_dir / "qinao_humaneval_paired_base.json"
    output.write_text('{"30": 100}', encoding="utf-8")
    receipts = tmp_path / "subjects.json"
    receipts.write_text(
        json.dumps(
            {
                "schema": "qinao/humaneval-subject-receipts/v1",
                "subjects": {
                    "base": {
                        "sha256": "a" * 64,
                        "model": "model-receipt",
                        "adapter": None,
                    }
                },
            }
        ),
        encoding="utf-8",
    )
    monkeypatch.setenv("QINAO_EVAL_RUN_ID", run_id)
    monkeypatch.setenv("QINAO_EVAL_EVIDENCE_DIR", str(evidence_dir))
    monkeypatch.setenv("QINAO_SUBJECT_RECEIPTS", str(receipts))
    monkeypatch.setenv(
        "QINAO_HUMANEVAL_DATASET_FINGERPRINT", "dataset-fingerprint-current"
    )
    monkeypatch.setattr(
        sys,
        "argv",
        [
            "qinao_humaneval_paired.py",
            "model-receipt",
            "none",
            "base",
            "2",
        ],
    )
    real_import = builtins.__import__

    def fail_at_model_import(name, *args, **kwargs):
        if name == "mlx_lm":
            raise ModuleNotFoundError("intentional model-import crash")
        return real_import(name, *args, **kwargs)

    monkeypatch.setattr(builtins, "__import__", fail_at_model_import)
    with pytest.raises(ModuleNotFoundError, match="intentional model-import crash"):
        hp.main()

    assert not output.exists()


def test_atomic_evidence_publish_replaces_in_same_run_directory(tmp_path):
    from qinao_humaneval_evidence import (
        HumanEvalProducer,
        HumanEvalRunContext,
        SubjectReceipt,
        atomic_write_humaneval_evidence,
        prepare_humaneval_output,
    )

    run_id = "run-atomic"
    evidence_dir = tmp_path / run_id
    evidence_dir.mkdir()
    context = HumanEvalRunContext(
        run_id=run_id,
        evidence_dir=evidence_dir,
        dataset_fingerprint="dataset-fingerprint-current",
        subjects={
            "base": SubjectReceipt(sha256="a" * 64, model="model-receipt", adapter=None)
        },
    )
    output = evidence_dir / "qinao_humaneval_paired_base.json"
    symlink_target = tmp_path / "must-not-be-overwritten.json"
    symlink_target.write_text("outside-sentinel", encoding="utf-8")
    output.symlink_to(symlink_target)
    with prepare_humaneval_output(
        context, HumanEvalProducer.PAIRED, "base"
    ) as attempt:
        assert attempt.output == output
        atomic_write_humaneval_evidence(attempt, {"marker": "new"})

    assert json.loads(output.read_text(encoding="utf-8")) == {"marker": "new"}
    assert not output.is_symlink()
    assert symlink_target.read_text(encoding="utf-8") == "outside-sentinel"
    assert list(evidence_dir.glob("*.tmp")) == []


def test_starting_either_writer_invalidates_all_humaneval_producers_for_tag(
    tmp_path,
):
    from qinao_humaneval_evidence import (
        HumanEvalProducer,
        HumanEvalRunContext,
        SubjectReceipt,
        prepare_humaneval_output,
    )

    run_id = "cross-producer-invalidation"
    evidence_dir = tmp_path / run_id
    evidence_dir.mkdir()
    context = HumanEvalRunContext(
        run_id=run_id,
        evidence_dir=evidence_dir,
        dataset_fingerprint="dataset-fingerprint-current",
        subjects={"base": SubjectReceipt("a" * 64, "model", None)},
    )
    standard = evidence_dir / "qinao_humaneval_base.json"
    paired = evidence_dir / "qinao_humaneval_paired_base.json"
    standard.write_text('{"30":100}', encoding="utf-8")
    paired.write_text('{"30":100}', encoding="utf-8")

    with prepare_humaneval_output(
        context, HumanEvalProducer.STANDARD, "base"
    ) as attempt:
        assert attempt.output == standard
        assert not standard.exists()
        assert not paired.exists()


def test_standard_evidence_score_must_recompute_from_strict_passed_count(tmp_path):
    from qinao_humaneval_evidence import (
        HumanEvalProducer,
        HumanEvalRunContext,
        SubjectReceipt,
        build_humaneval_evidence,
        validate_humaneval_evidence,
    )

    run_id = "standard-counts"
    evidence_dir = tmp_path / run_id
    evidence_dir.mkdir()
    context = HumanEvalRunContext(
        run_id=run_id,
        evidence_dir=evidence_dir,
        dataset_fingerprint="dataset-fingerprint-current",
        subjects={"base": SubjectReceipt("a" * 64, "model", None)},
    )
    evidence = build_humaneval_evidence(
        passed=1,
        total=2,
        infra_errors=0,
        sample_ids=["HumanEval/0", "HumanEval/1"],
        producer=HumanEvalProducer.STANDARD,
        context=context,
        tag="base",
    )
    forged_score = {**evidence, "30": 100.0}

    assert evidence["_passed"] == 1
    assert (
        validate_humaneval_evidence(
            forged_score,
            producer=HumanEvalProducer.STANDARD,
            context=context,
            tag="base",
        )
        is None
    )


def test_humaneval_sample_metadata_is_bounded_to_dataset_size(tmp_path):
    from qinao_humaneval_evidence import (
        HumanEvalProducer,
        HumanEvalRunContext,
        SubjectReceipt,
        build_humaneval_evidence,
    )

    run_id = "sample-bound"
    evidence_dir = tmp_path / run_id
    evidence_dir.mkdir()
    context = HumanEvalRunContext(
        run_id=run_id,
        evidence_dir=evidence_dir,
        dataset_fingerprint="dataset-fingerprint-current",
        subjects={"base": SubjectReceipt("a" * 64, "model", None)},
    )
    sample_ids = [f"HumanEval/{index}" for index in range(165)]

    with pytest.raises(ValueError, match="at most 164"):
        build_humaneval_evidence(
            passed=0,
            total=165,
            infra_errors=0,
            sample_ids=sample_ids,
            producer=HumanEvalProducer.STANDARD,
            context=context,
            tag="base",
        )


@pytest.mark.parametrize(
    ("writer", "prefix"),
    (
        (hs, "humaneval"),
        (hp, "humaneval_paired"),
    ),
)
def test_writer_checks_materialized_dataset_fingerprint_before_model_load(
    writer, prefix, tmp_path, monkeypatch
):
    run_id = f"dataset-check-{prefix}"
    evidence_dir = tmp_path / run_id
    evidence_dir.mkdir()
    output = evidence_dir / f"qinao_{prefix}_base.json"
    output.write_text('{"30":100}', encoding="utf-8")
    receipts = tmp_path / f"subjects-{prefix}.json"
    receipts.write_text(
        json.dumps(
            {
                "schema": "qinao/humaneval-subject-receipts/v1",
                "subjects": {
                    "base": {
                        "sha256": "a" * 64,
                        "model": "model-receipt",
                        "adapter": None,
                    }
                },
            }
        ),
        encoding="utf-8",
    )
    monkeypatch.setenv("QINAO_EVAL_RUN_ID", run_id)
    monkeypatch.setenv("QINAO_EVAL_EVIDENCE_DIR", str(evidence_dir))
    monkeypatch.setenv("QINAO_SUBJECT_RECEIPTS", str(receipts))
    monkeypatch.setenv("QINAO_HUMANEVAL_DATASET_FINGERPRINT", "expected-fingerprint")
    monkeypatch.setattr(
        sys,
        "argv",
        [writer.__name__ + ".py", "model-receipt", "none", "base", "2"],
    )

    model_loads = []
    fake_mlx = types.ModuleType("mlx_lm")

    def forbidden_model_load(*args, **kwargs):
        model_loads.append((args, kwargs))
        raise AssertionError("model must not load after dataset receipt mismatch")

    fake_mlx.load = forbidden_model_load
    fake_mlx.generate = lambda *args, **kwargs: ""
    fake_datasets = types.ModuleType("datasets")

    class MaterializedDataset(list):
        _fingerprint = "observed-different-fingerprint"

    fake_datasets.load_dataset = lambda *args, **kwargs: MaterializedDataset()
    monkeypatch.setitem(sys.modules, "mlx_lm", fake_mlx)
    monkeypatch.setitem(sys.modules, "datasets", fake_datasets)

    with pytest.raises(ValueError, match="loaded HumanEval dataset fingerprint"):
        writer.main()

    assert model_loads == []
    assert not output.exists()


def test_standard_body_only_completion_is_indented_under_signature():
    prompt = "def answer(value):\n"
    body = "return value + 1\n"

    assembled = hs.assemble_generated_function(prompt, body, "answer")

    assert assembled == "def answer(value):\n    return value + 1\n"
    compile(assembled, "<standard-humaneval>", "exec")


@pytest.mark.parametrize("invalid_limit", ("0", "-1", "165"))
@pytest.mark.parametrize(
    ("writer", "prefix"),
    (
        (hs, "humaneval"),
        (hp, "humaneval_paired"),
    ),
)
def test_writer_rejects_out_of_range_sample_limit_and_invalidates_output(
    writer, prefix, invalid_limit, tmp_path, monkeypatch
):
    run_id = f"limit-{prefix}-{invalid_limit.replace('-', 'negative')}"
    evidence_dir = tmp_path / run_id
    evidence_dir.mkdir()
    output = evidence_dir / f"qinao_{prefix}_base.json"
    output.write_text('{"30":100}', encoding="utf-8")
    receipts = tmp_path / f"subjects-{prefix}-{invalid_limit}.json"
    receipts.write_text(
        json.dumps(
            {
                "schema": "qinao/humaneval-subject-receipts/v1",
                "subjects": {
                    "base": {
                        "sha256": "a" * 64,
                        "model": "model-receipt",
                        "adapter": None,
                    }
                },
            }
        ),
        encoding="utf-8",
    )
    monkeypatch.setenv("QINAO_EVAL_RUN_ID", run_id)
    monkeypatch.setenv("QINAO_EVAL_EVIDENCE_DIR", str(evidence_dir))
    monkeypatch.setenv("QINAO_SUBJECT_RECEIPTS", str(receipts))
    monkeypatch.setenv("QINAO_HUMANEVAL_DATASET_FINGERPRINT", "expected-fingerprint")
    monkeypatch.setattr(
        sys,
        "argv",
        [
            writer.__name__ + ".py",
            "model-receipt",
            "none",
            "base",
            invalid_limit,
        ],
    )

    with pytest.raises(ValueError, match="between 1 and 164"):
        writer.main()

    assert not output.exists()


def _attempt_context(tmp_path, run_id="attempt-run"):
    from qinao_humaneval_evidence import HumanEvalRunContext, SubjectReceipt

    evidence_dir = tmp_path / run_id
    evidence_dir.mkdir()
    return HumanEvalRunContext(
        run_id=run_id,
        evidence_dir=evidence_dir,
        dataset_fingerprint="dataset-fingerprint-current",
        subjects={"base": SubjectReceipt("a" * 64, "model", None)},
    )


def test_newer_cross_producer_attempt_invalidates_older_publication(tmp_path):
    """Prepare through publish is one serial transaction for a run/tag."""

    from qinao_humaneval_evidence import (
        HumanEvalProducer,
        atomic_write_humaneval_evidence,
        prepare_humaneval_output,
    )

    context = _attempt_context(tmp_path, "linear-attempt")
    newer_entered = threading.Event()
    newer_finished = threading.Event()
    newer_errors = []

    def cancelled_newer_attempt():
        try:
            with prepare_humaneval_output(
                context, HumanEvalProducer.PAIRED, "base"
            ):
                newer_entered.set()
                # Simulate cancellation/crash: publish nothing.
        except BaseException as error:  # surfaced in the assertion below
            newer_errors.append(error)
        finally:
            newer_finished.set()

    with prepare_humaneval_output(
        context, HumanEvalProducer.STANDARD, "base"
    ) as older_attempt:
        worker = threading.Thread(target=cancelled_newer_attempt, daemon=True)
        worker.start()
        assert not newer_entered.wait(0.2), "newer prepare bypassed the active attempt"
        atomic_write_humaneval_evidence(older_attempt, {"marker": "older-success"})

    assert newer_entered.wait(2), "newer attempt never acquired the run/tag"
    assert newer_finished.wait(2), "newer cancelled attempt did not finish"
    worker.join(timeout=0)
    assert newer_errors == []
    assert not (context.evidence_dir / "qinao_humaneval_base.json").exists()
    assert not (context.evidence_dir / "qinao_humaneval_paired_base.json").exists()


def test_admission_fsync_failure_is_fail_closed(tmp_path, monkeypatch):
    import qinao_humaneval_evidence as evidence_module
    import qinao_merge as merge_module
    from qinao_humaneval_evidence import (
        HumanEvalProducer,
        build_humaneval_evidence,
        prepare_humaneval_output,
    )

    context = _attempt_context(tmp_path, "prepare-fsync")
    old_output = context.evidence_dir / "qinao_humaneval_paired_base.json"
    old_output.write_text(
        json.dumps(
            build_humaneval_evidence(
                passed=1,
                total=2,
                infra_errors=0,
                per_problem={"HumanEval/0": 1, "HumanEval/1": 0},
                sample_ids=["HumanEval/0", "HumanEval/1"],
                producer=HumanEvalProducer.PAIRED,
                context=context,
                tag="base",
            )
        ),
        encoding="utf-8",
    )

    def fail_fsync(_descriptor):
        raise OSError("intentional directory fsync failure")

    monkeypatch.setattr(evidence_module.os, "fsync", fail_fsync)
    with pytest.raises(OSError, match="intentional directory fsync failure"):
        with prepare_humaneval_output(
            context, HumanEvalProducer.STANDARD, "base"
        ):
            pass

    assert old_output.exists(), "probe must exercise replay through the tombstone"
    assert list(context.evidence_dir.glob(".qinao_humaneval_base.attempt.*"))
    merged = merge_module.merge_known_sidefiles(
        {
            "30": 99.0,
            "_prov": {"30": {"kind": "computed", "runner": "stale"}},
        },
        "base",
        tmpdir=str(tmp_path),
        humaneval_context=context,
    )
    assert "30" not in merged
    assert "30" not in merged["_prov"]


def test_invalidation_directory_fsync_failure_keeps_tombstone(tmp_path, monkeypatch):
    import qinao_humaneval_evidence as evidence_module
    from qinao_humaneval_evidence import HumanEvalProducer, prepare_humaneval_output

    context = _attempt_context(tmp_path, "invalidation-fsync")
    outputs = [
        context.evidence_dir / "qinao_humaneval_base.json",
        context.evidence_dir / "qinao_humaneval_paired_base.json",
    ]
    for output in outputs:
        output.write_text('{"30":100}', encoding="utf-8")
    real_fsync = evidence_module.os.fsync
    calls = 0

    def fail_invalidation_fsync(descriptor):
        nonlocal calls
        calls += 1
        if calls == 3:
            raise OSError("intentional invalidation directory fsync failure")
        return real_fsync(descriptor)

    monkeypatch.setattr(evidence_module.os, "fsync", fail_invalidation_fsync)
    with pytest.raises(OSError, match="intentional invalidation directory"):
        with prepare_humaneval_output(
            context, HumanEvalProducer.STANDARD, "base"
        ):
            pass

    assert calls == 3
    assert all(not output.exists() for output in outputs)
    assert list(context.evidence_dir.glob(".qinao_humaneval_base.attempt.*"))


@pytest.mark.parametrize("failed_fsync_call", (2, 3))
def test_publish_or_commit_directory_fsync_failure_removes_replaced_output(
    failed_fsync_call, tmp_path, monkeypatch
):
    import qinao_humaneval_evidence as evidence_module
    from qinao_humaneval_evidence import (
        HumanEvalProducer,
        atomic_write_humaneval_evidence,
        prepare_humaneval_output,
    )

    context = _attempt_context(tmp_path, "publish-fsync")
    output = context.evidence_dir / "qinao_humaneval_base.json"
    real_fsync = evidence_module.os.fsync
    calls = 0

    with pytest.raises(OSError, match="intentional publish directory fsync failure"):
        with prepare_humaneval_output(
            context, HumanEvalProducer.STANDARD, "base"
        ) as attempt:
            def fail_selected_fsync(descriptor):
                nonlocal calls
                calls += 1
                if calls == failed_fsync_call:
                    raise OSError("intentional publish directory fsync failure")
                return real_fsync(descriptor)

            monkeypatch.setattr(evidence_module.os, "fsync", fail_selected_fsync)
            atomic_write_humaneval_evidence(attempt, {"marker": "must-not-survive"})

    assert calls >= 2
    assert not output.exists(), "a durability failure left acceptable evidence"


def test_post_publish_exception_keeps_pending_marker_when_revocation_fails(
    tmp_path, monkeypatch
):
    import qinao_humaneval_evidence as evidence_module
    import qinao_merge as merge_module
    from qinao_humaneval_evidence import (
        HumanEvalProducer,
        atomic_write_humaneval_evidence,
        build_humaneval_evidence,
        prepare_humaneval_output,
    )

    context = _attempt_context(tmp_path, "post-publish-revoke")
    output = context.evidence_dir / "qinao_humaneval_paired_base.json"
    payload = build_humaneval_evidence(
        passed=1,
        total=2,
        infra_errors=0,
        per_problem={"HumanEval/0": 1, "HumanEval/1": 0},
        sample_ids=["HumanEval/0", "HumanEval/1"],
        producer=HumanEvalProducer.PAIRED,
        context=context,
        tag="base",
    )
    real_unlink = evidence_module.os.unlink

    with pytest.raises(OSError, match="intentional revocation fsync failure"):
        with prepare_humaneval_output(
            context, HumanEvalProducer.PAIRED, "base"
        ) as attempt:
            atomic_write_humaneval_evidence(attempt, payload)

            def fail_output_unlink(path, *args, **kwargs):
                if path == output.name:
                    raise PermissionError("intentional output unlink failure")
                return real_unlink(path, *args, **kwargs)

            def fail_revocation_fsync(_descriptor):
                raise OSError("intentional revocation fsync failure")

            monkeypatch.setattr(evidence_module.os, "unlink", fail_output_unlink)
            monkeypatch.setattr(evidence_module.os, "fsync", fail_revocation_fsync)
            raise RuntimeError("intentional exception after publish")

    assert output.exists(), "probe requires a valid residual publication"
    assert list(context.evidence_dir.glob(".qinao_humaneval_base.attempt.*"))
    merged = merge_module.merge_known_sidefiles(
        {"30": 99.0, "_prov": {"30": {"kind": "computed", "runner": "old"}}},
        "base",
        tmpdir=str(tmp_path),
        humaneval_context=context,
    )
    assert "30" not in merged
    assert "30" not in merged["_prov"]


def test_commit_compound_failure_leaves_marker_or_durably_poisoned_output(
    tmp_path, monkeypatch
):
    import qinao_humaneval_evidence as evidence_module
    from qinao_humaneval_evidence import (
        HumanEvalProducer,
        atomic_write_humaneval_evidence,
        build_humaneval_evidence,
        prepare_humaneval_output,
    )

    context = _attempt_context(tmp_path, "commit-compound-failure")
    output = context.evidence_dir / "qinao_humaneval_paired_base.json"
    payload = build_humaneval_evidence(
        passed=1,
        total=2,
        infra_errors=0,
        per_problem={"HumanEval/0": 1, "HumanEval/1": 0},
        sample_ids=["HumanEval/0", "HumanEval/1"],
        producer=HumanEvalProducer.PAIRED,
        context=context,
        tag="base",
    )
    real_fsync = evidence_module.os.fsync
    real_open = evidence_module.os.open
    real_unlink = evidence_module.os.unlink
    admission_removed = False
    poison_synced = False

    with pytest.raises(OSError, match="intentional commit directory fsync failure"):
        with prepare_humaneval_output(
            context, HumanEvalProducer.PAIRED, "base"
        ) as attempt:
            atomic_write_humaneval_evidence(attempt, payload)
            admission_prefix = f".qinao_humaneval_{attempt.tag}.attempt."

            def fail_compound_unlink(path, *args, **kwargs):
                nonlocal admission_removed
                if path == attempt._admission_name:
                    result = real_unlink(path, *args, **kwargs)
                    admission_removed = True
                    return result
                if path in attempt._candidate_names():
                    raise PermissionError("intentional producer unlink failure")
                return real_unlink(path, *args, **kwargs)

            def fail_admission_recreate(path, *args, **kwargs):
                if (
                    admission_removed
                    and isinstance(path, str)
                    and path.startswith(admission_prefix)
                ):
                    raise PermissionError("intentional admission recreate failure")
                return real_open(path, *args, **kwargs)

            def fail_directory_fsync(descriptor):
                nonlocal poison_synced
                if descriptor == attempt._directory_descriptor:
                    raise OSError("intentional commit directory fsync failure")
                poison_synced = True
                return real_fsync(descriptor)

            monkeypatch.setattr(evidence_module.os, "unlink", fail_compound_unlink)
            monkeypatch.setattr(evidence_module.os, "open", fail_admission_recreate)
            monkeypatch.setattr(evidence_module.os, "fsync", fail_directory_fsync)

    markers = list(context.evidence_dir.glob(".qinao_humaneval_base.attempt.*"))
    try:
        json.loads(output.read_text(encoding="utf-8"))
        output_is_invalid = False
    except (json.JSONDecodeError, OSError, UnicodeError):
        output_is_invalid = True
    assert markers or (output_is_invalid and poison_synced), (
        "failed commit left no marker and a still-verifiable producer publication"
    )


def test_successful_commit_reports_unlock_cleanup_failure_without_revoking(
    tmp_path, monkeypatch
):
    import qinao_humaneval_evidence as evidence_module
    from qinao_humaneval_evidence import (
        HumanEvalProducer,
        atomic_write_humaneval_evidence,
        prepare_humaneval_output,
    )

    context = _attempt_context(tmp_path, "close-releases-lock")
    output = context.evidence_dir / "qinao_humaneval_base.json"
    real_flock = evidence_module.fcntl.flock

    attempt = prepare_humaneval_output(
        context, HumanEvalProducer.STANDARD, "base"
    )
    with pytest.raises(OSError, match="intentional attempt unlock failure"):
        with attempt:
            atomic_write_humaneval_evidence(attempt, {"marker": "committed"})

            def reject_first_unlock(descriptor, operation):
                if operation == evidence_module.fcntl.LOCK_UN:
                    raise OSError("intentional attempt unlock failure")
                return real_flock(descriptor, operation)

            monkeypatch.setattr(
                evidence_module.fcntl, "flock", reject_first_unlock
            )

    assert json.loads(output.read_text(encoding="utf-8")) == {
        "marker": "committed"
    }
    assert not list(context.evidence_dir.glob(".qinao_humaneval_base.attempt.*"))
    assert attempt._admission_descriptor is None
    assert attempt._lock_descriptor is None
    assert attempt._directory_descriptor is None


def _close_if_still_open(descriptor, real_close):
    try:
        os.fstat(descriptor)
    except OSError:
        return
    real_close(descriptor)


def test_single_observation_exit_reports_first_error_after_full_cleanup(
    tmp_path, monkeypatch
):
    import qinao_humaneval_evidence as evidence_module
    from qinao_humaneval_evidence import HumanEvalObservation

    context = _attempt_context(tmp_path, "single-observation-cleanup")
    observation = HumanEvalObservation(context, "base").__enter__()
    lock_descriptor = observation._lock_descriptor
    directory_descriptor = observation.directory_descriptor
    assert lock_descriptor is not None and directory_descriptor is not None
    real_close = evidence_module.os.close
    real_flock = evidence_module.fcntl.flock
    close_calls = []
    failed_unlock = False

    def fail_first_unlock(descriptor, operation):
        nonlocal failed_unlock
        if operation == evidence_module.fcntl.LOCK_UN and not failed_unlock:
            failed_unlock = True
            raise OSError("intentional first observation unlock failure")
        return real_flock(descriptor, operation)

    def record_real_close(descriptor):
        close_calls.append(descriptor)
        return real_close(descriptor)

    monkeypatch.setattr(evidence_module.fcntl, "flock", fail_first_unlock)
    monkeypatch.setattr(evidence_module.os, "close", record_real_close)
    try:
        with pytest.raises(OSError, match="first observation unlock"):
            observation.__exit__(None, None, None)
        assert observation._lock_descriptor is None
        assert observation.directory_descriptor is None
        assert {lock_descriptor, directory_descriptor} <= set(close_calls)
    finally:
        monkeypatch.setattr(evidence_module.os, "close", real_close)
        monkeypatch.setattr(evidence_module.fcntl, "flock", real_flock)
        _close_if_still_open(lock_descriptor, real_close)
        _close_if_still_open(directory_descriptor, real_close)


def test_observation_set_exit_reports_first_error_after_full_cleanup(
    tmp_path, monkeypatch
):
    import qinao_humaneval_evidence as evidence_module
    from qinao_humaneval_evidence import (
        HumanEvalObservationSet,
        HumanEvalRunContext,
        SubjectReceipt,
    )

    run_id = "set-observation-cleanup"
    evidence_dir = tmp_path / run_id
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
    observation = HumanEvalObservationSet(context, ("base", "tuned")).__enter__()
    lock_descriptors = tuple(observation._lock_descriptors)
    directory_descriptor = observation.directory_descriptor
    assert len(lock_descriptors) == 2 and directory_descriptor is not None
    real_close = evidence_module.os.close
    real_flock = evidence_module.fcntl.flock
    close_calls = []
    failed_close = False
    unlock_calls = []

    def record_unlock(descriptor, operation):
        if operation == evidence_module.fcntl.LOCK_UN:
            unlock_calls.append(descriptor)
        return real_flock(descriptor, operation)

    def fail_first_close_without_closing(descriptor):
        nonlocal failed_close
        close_calls.append(descriptor)
        if not failed_close:
            failed_close = True
            raise OSError("intentional first observation-set close failure")
        return real_close(descriptor)

    monkeypatch.setattr(evidence_module.fcntl, "flock", record_unlock)
    monkeypatch.setattr(
        evidence_module.os, "close", fail_first_close_without_closing
    )
    try:
        with pytest.raises(OSError, match="first observation-set close"):
            observation.__exit__(None, None, None)
        assert observation._lock_descriptors == []
        assert observation.directory_descriptor is None
        assert observation._admission_pending == {}
        assert {*lock_descriptors, directory_descriptor} <= set(close_calls)
        assert set(lock_descriptors) <= set(unlock_calls)
    finally:
        monkeypatch.setattr(evidence_module.os, "close", real_close)
        monkeypatch.setattr(evidence_module.fcntl, "flock", real_flock)
        for descriptor in (*lock_descriptors, directory_descriptor):
            _close_if_still_open(descriptor, real_close)


def _assert_observation_enter_preserves_primary_error(
    observation, evidence_module, monkeypatch
):
    real_close = evidence_module.os.close
    real_flock = evidence_module.fcntl.flock
    real_listdir = evidence_module.os.listdir
    close_calls = []
    failed_unlock = False

    def fail_snapshot(_descriptor):
        raise ValueError("intentional observation snapshot failure")

    def fail_first_cleanup_unlock(descriptor, operation):
        nonlocal failed_unlock
        if operation == evidence_module.fcntl.LOCK_UN and not failed_unlock:
            failed_unlock = True
            raise OSError("intentional observation enter cleanup failure")
        return real_flock(descriptor, operation)

    def record_real_close(descriptor):
        close_calls.append(descriptor)
        return real_close(descriptor)

    monkeypatch.setattr(evidence_module.os, "listdir", fail_snapshot)
    monkeypatch.setattr(
        evidence_module.fcntl, "flock", fail_first_cleanup_unlock
    )
    monkeypatch.setattr(evidence_module.os, "close", record_real_close)
    observed_error = None
    try:
        try:
            observation.__enter__()
        except BaseException as error:
            observed_error = error
        if hasattr(observation, "_lock_descriptors"):
            remaining_locks = tuple(observation._lock_descriptors)
        else:
            remaining_locks = (observation._lock_descriptor,)
        remaining_directory = observation.directory_descriptor
    finally:
        monkeypatch.setattr(evidence_module.os, "close", real_close)
        monkeypatch.setattr(evidence_module.fcntl, "flock", real_flock)
        monkeypatch.setattr(evidence_module.os, "listdir", real_listdir)
        for descriptor in (*remaining_locks, remaining_directory):
            if descriptor is not None:
                _close_if_still_open(descriptor, real_close)

    assert isinstance(observed_error, ValueError)
    assert "snapshot failure" in str(observed_error)
    assert any(
        "cleanup" in note for note in getattr(observed_error, "__notes__", ())
    )
    if hasattr(observation, "_lock_descriptors"):
        assert observation._lock_descriptors == []
        assert observation._admission_pending == {}
    else:
        assert observation._lock_descriptor is None
    assert observation.directory_descriptor is None
    assert close_calls


def test_single_observation_enter_preserves_primary_error_over_cleanup_error(
    tmp_path, monkeypatch
):
    import qinao_humaneval_evidence as evidence_module
    from qinao_humaneval_evidence import HumanEvalObservation

    context = _attempt_context(tmp_path, "single-observation-enter-error")
    _assert_observation_enter_preserves_primary_error(
        HumanEvalObservation(context, "base"), evidence_module, monkeypatch
    )


def test_observation_set_enter_preserves_primary_error_over_cleanup_error(
    tmp_path, monkeypatch
):
    import qinao_humaneval_evidence as evidence_module
    from qinao_humaneval_evidence import (
        HumanEvalObservationSet,
        HumanEvalRunContext,
        SubjectReceipt,
    )

    run_id = "set-observation-enter-error"
    evidence_dir = tmp_path / run_id
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
    _assert_observation_enter_preserves_primary_error(
        HumanEvalObservationSet(context, ("base", "tuned")),
        evidence_module,
        monkeypatch,
    )


def test_attempt_close_error_is_reported_and_cannot_leave_acceptable_evidence(
    tmp_path, monkeypatch
):
    import qinao_humaneval_evidence as evidence_module
    from qinao_humaneval_evidence import (
        HumanEvalProducer,
        atomic_write_humaneval_evidence,
        prepare_humaneval_output,
    )

    context = _attempt_context(tmp_path, "attempt-close-failure")
    output = context.evidence_dir / "qinao_humaneval_base.json"
    lock_path = context.evidence_dir / ".qinao_humaneval_base.lock"
    real_close = evidence_module.os.close
    failed_descriptor = None
    attempt = None
    target_lock_descriptor = None
    target_admission_descriptor = None
    reported_error = None
    unlock_calls = []
    close_calls = []
    real_flock = evidence_module.fcntl.flock

    def record_unlock(descriptor, operation):
        if operation == evidence_module.fcntl.LOCK_UN:
            unlock_calls.append(descriptor)
        return real_flock(descriptor, operation)

    def fail_lock_close_without_closing(descriptor):
        nonlocal failed_descriptor
        close_calls.append(descriptor)
        if descriptor == target_lock_descriptor and failed_descriptor is None:
            failed_descriptor = descriptor
            raise OSError("intentional attempt lock close failure")
        return real_close(descriptor)

    try:
        try:
            with prepare_humaneval_output(
                context, HumanEvalProducer.STANDARD, "base"
            ) as active_attempt:
                attempt = active_attempt
                atomic_write_humaneval_evidence(attempt, {"marker": "committed"})
                target_lock_descriptor = attempt._lock_descriptor
                target_admission_descriptor = attempt._admission_descriptor
                expected_descriptors = {
                    attempt._published_descriptor,
                    attempt._admission_descriptor,
                    attempt._lock_descriptor,
                    attempt._directory_descriptor,
                }
                monkeypatch.setattr(evidence_module.fcntl, "flock", record_unlock)
                monkeypatch.setattr(
                    evidence_module.os, "close", fail_lock_close_without_closing
                )
        except OSError as error:
            reported_error = error
        monkeypatch.setattr(evidence_module.os, "close", real_close)

        probe_read, probe_write = os.pipe()
        child = os.fork()
        if child == 0:
            real_close(probe_read)
            # Drop the inherited duplicate of the intentionally unclosed
            # parent fd before acting as an independent lock contender.
            real_close(target_lock_descriptor)
            lock_descriptor = os.open(lock_path, os.O_RDWR)
            try:
                try:
                    evidence_module.fcntl.flock(
                        lock_descriptor,
                        evidence_module.fcntl.LOCK_EX
                        | evidence_module.fcntl.LOCK_NB,
                    )
                    os.write(probe_write, b"1")
                    os._exit(0)
                except OSError:
                    os.write(probe_write, b"0")
                    os._exit(73)
            finally:
                real_close(lock_descriptor)
        real_close(probe_write)
        probe_result = os.read(probe_read, 1)
        real_close(probe_read)
        _, child_status = os.waitpid(child, 0)
        exclusive_lock_is_available = (
            probe_result == b"1" and os.waitstatus_to_exitcode(child_status) == 0
        )
        markers = list(
            context.evidence_dir.glob(".qinao_humaneval_base.attempt.*")
        )
        try:
            json.loads(output.read_text(encoding="utf-8"))
            output_is_acceptable = True
        except (json.JSONDecodeError, OSError, UnicodeError):
            output_is_acceptable = False

        assert reported_error is not None, "attempt close failure was silently accepted"
        assert exclusive_lock_is_available, "attempt EX lock fd was leaked"
        assert target_lock_descriptor in unlock_calls
        assert target_admission_descriptor in unlock_calls
        assert expected_descriptors <= set(close_calls)
        assert attempt._published_descriptor is None
        assert attempt._admission_descriptor is None
        assert attempt._lock_descriptor is None
        assert attempt._directory_descriptor is None
        assert not markers and output_is_acceptable, (
            "durable commit must remain accepted despite a cleanup-only error"
        )
    finally:
        monkeypatch.setattr(evidence_module.os, "close", real_close)
        if failed_descriptor is not None:
            _close_if_still_open(failed_descriptor, real_close)


def test_attempt_cleanup_never_retries_or_probes_an_unknown_close_state(
    tmp_path, monkeypatch
):
    import qinao_humaneval_evidence as evidence_module
    from qinao_humaneval_evidence import (
        HumanEvalProducer,
        atomic_write_humaneval_evidence,
        prepare_humaneval_output,
    )

    context = _attempt_context(tmp_path, "attempt-fd-reuse")
    output = context.evidence_dir / "qinao_humaneval_base.json"
    attempt = prepare_humaneval_output(
        context, HumanEvalProducer.STANDARD, "base"
    )
    real_close = evidence_module.os.close
    real_fstat = evidence_module.os.fstat
    real_flock = evidence_module.fcntl.flock
    source_descriptor = None
    reused_descriptor = None
    target_lock_descriptor = None
    close_calls = []
    unlock_calls = []
    reuse_installed = False

    def record_unlock(descriptor, operation):
        if operation == evidence_module.fcntl.LOCK_UN:
            unlock_calls.append(descriptor)
        return real_flock(descriptor, operation)

    def close_then_reuse_and_raise(descriptor):
        nonlocal reused_descriptor, reuse_installed
        close_calls.append(descriptor)
        if descriptor == target_lock_descriptor and not reuse_installed:
            real_close(descriptor)
            os.dup2(source_descriptor, descriptor)
            reused_descriptor = descriptor
            reuse_installed = True
            raise OSError("intentional unknown close state after fd reuse")
        return real_close(descriptor)

    def reject_reused_fd_probe(descriptor):
        if reuse_installed and descriptor == reused_descriptor:
            raise AssertionError("cleanup probed a descriptor after close error")
        return real_fstat(descriptor)

    try:
        with pytest.raises(OSError, match="unknown close state after fd reuse"):
            with attempt:
                atomic_write_humaneval_evidence(attempt, {"marker": "committed"})
                target_lock_descriptor = attempt._lock_descriptor
                source_descriptor = os.open(os.devnull, os.O_RDONLY)
                monkeypatch.setattr(evidence_module.fcntl, "flock", record_unlock)
                monkeypatch.setattr(
                    evidence_module.os, "close", close_then_reuse_and_raise
                )
                monkeypatch.setattr(
                    evidence_module.os, "fstat", reject_reused_fd_probe
                )

        monkeypatch.setattr(evidence_module.os, "close", real_close)
        monkeypatch.setattr(evidence_module.os, "fstat", real_fstat)
        assert reused_descriptor == target_lock_descriptor
        assert close_calls.count(target_lock_descriptor) == 1
        assert target_lock_descriptor in unlock_calls
        assert real_fstat(reused_descriptor).st_mode
        assert json.loads(output.read_text(encoding="utf-8")) == {
            "marker": "committed"
        }
    finally:
        monkeypatch.setattr(evidence_module.os, "close", real_close)
        monkeypatch.setattr(evidence_module.os, "fstat", real_fstat)
        monkeypatch.setattr(evidence_module.fcntl, "flock", real_flock)
        if reused_descriptor is not None:
            _close_if_still_open(reused_descriptor, real_close)
        if source_descriptor is not None:
            _close_if_still_open(source_descriptor, real_close)


def test_commit_repair_unlocks_current_retired_and_main_lock_descriptors(
    tmp_path, monkeypatch
):
    import qinao_humaneval_evidence as evidence_module
    from qinao_humaneval_evidence import (
        HumanEvalProducer,
        atomic_write_humaneval_evidence,
        prepare_humaneval_output,
    )

    context = _attempt_context(tmp_path, "retired-admission-cleanup")
    attempt = prepare_humaneval_output(
        context, HumanEvalProducer.STANDARD, "base"
    )
    real_close = evidence_module.os.close
    real_create_admission = attempt._create_admission
    real_flock = evidence_module.fcntl.flock
    real_fsync = evidence_module.os.fsync
    close_calls = []
    unlock_calls = []
    recreated_admissions = []
    failed_commit_fsync = False

    def capture_recreated_admission():
        real_create_admission()
        recreated_admissions.append(attempt._admission_descriptor)

    def fail_first_commit_directory_fsync(descriptor):
        nonlocal failed_commit_fsync
        if descriptor == attempt._directory_descriptor and not failed_commit_fsync:
            failed_commit_fsync = True
            raise OSError("intentional retired-admission commit fsync failure")
        return real_fsync(descriptor)

    def record_unlock(descriptor, operation):
        if operation == evidence_module.fcntl.LOCK_UN:
            unlock_calls.append(descriptor)
        return real_flock(descriptor, operation)

    def record_real_close(descriptor):
        close_calls.append(descriptor)
        return real_close(descriptor)

    with pytest.raises(OSError, match="retired-admission commit fsync"):
        with attempt:
            atomic_write_humaneval_evidence(attempt, {"marker": "committed"})
            original_admission = attempt._admission_descriptor
            main_lock = attempt._lock_descriptor
            attempt._create_admission = capture_recreated_admission
            monkeypatch.setattr(
                evidence_module.os, "fsync", fail_first_commit_directory_fsync
            )
            monkeypatch.setattr(evidence_module.fcntl, "flock", record_unlock)
            monkeypatch.setattr(evidence_module.os, "close", record_real_close)

    assert len(recreated_admissions) == 1
    recreated_admission = recreated_admissions[0]
    assert {original_admission, recreated_admission, main_lock} <= set(unlock_calls)
    for descriptor in (original_admission, recreated_admission, main_lock):
        assert close_calls.count(descriptor) == 1
    assert attempt._admission_descriptor is None
    assert attempt._retired_admission_descriptors == []
    assert attempt._lock_descriptor is None
    assert attempt._directory_descriptor is None


def test_context_rejects_replaced_evidence_directory_before_write(tmp_path):
    from qinao_humaneval_evidence import HumanEvalProducer, prepare_humaneval_output

    context = _attempt_context(tmp_path, "replaced-write-dir")
    original = tmp_path / "captured-original"
    context.evidence_dir.rename(original)
    attacker = tmp_path / "attacker"
    attacker.mkdir()
    sentinel = attacker / "qinao_humaneval_base.json"
    sentinel.write_text("attacker-owned", encoding="utf-8")
    context.evidence_dir.symlink_to(attacker, target_is_directory=True)

    with pytest.raises(ValueError, match="evidence directory"):
        with prepare_humaneval_output(
            context, HumanEvalProducer.STANDARD, "base"
        ):
            pass

    assert sentinel.read_text(encoding="utf-8") == "attacker-owned"


def test_active_attempt_keeps_writes_on_anchored_directory_after_replacement(
    tmp_path,
):
    from qinao_humaneval_evidence import (
        HumanEvalProducer,
        atomic_write_humaneval_evidence,
        prepare_humaneval_output,
    )

    context = _attempt_context(tmp_path, "replaced-active-dir")
    captured = tmp_path / "captured-active"
    attacker = tmp_path / "attacker-active"
    attacker.mkdir()
    attacker_output = attacker / "qinao_humaneval_base.json"
    attacker_output.write_text("attacker-owned", encoding="utf-8")

    with prepare_humaneval_output(
        context, HumanEvalProducer.STANDARD, "base"
    ) as attempt:
        context.evidence_dir.rename(captured)
        context.evidence_dir.symlink_to(attacker, target_is_directory=True)
        atomic_write_humaneval_evidence(attempt, {"marker": "anchored"})

    assert attacker_output.read_text(encoding="utf-8") == "attacker-owned"
    assert json.loads(
        (captured / "qinao_humaneval_base.json").read_text(encoding="utf-8")
    ) == {"marker": "anchored"}


def test_sample_limit_and_embedded_n_require_strict_integers(tmp_path):
    from qinao_humaneval_evidence import (
        HumanEvalProducer,
        build_humaneval_evidence,
        validate_humaneval_evidence,
        validated_sample_limit,
    )

    for non_integral in (True, 1.9):
        with pytest.raises(ValueError, match="integer"):
            validated_sample_limit(non_integral, default=60)

    context = _attempt_context(tmp_path, "strict-n")
    payload = build_humaneval_evidence(
        passed=1,
        total=2,
        infra_errors=0,
        sample_ids=["HumanEval/0", "HumanEval/1"],
        producer=HumanEvalProducer.STANDARD,
        context=context,
        tag="base",
    )
    payload["_N"] = 2.0
    assert (
        validate_humaneval_evidence(
            payload,
            producer=HumanEvalProducer.STANDARD,
            context=context,
            tag="base",
        )
        is None
    )
