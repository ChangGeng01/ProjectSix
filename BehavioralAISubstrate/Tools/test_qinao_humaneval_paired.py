"""audit tools-scripts LOW / decision 7 teeth: qinao_humaneval_paired must EXCLUDE infra errors from
the pass@1 denominator (mirroring the sibling qinao_humaneval.py fix). The module's heavy deps are
now imported lazily inside main(), so the pure helper imports without mlx_lm/datasets present.
Run: uv run --with pytest pytest test_qinao_humaneval_paired.py
"""

import os
import sys
import builtins
import json
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
    output = prepare_humaneval_output(context, HumanEvalProducer.PAIRED, "base")
    atomic_write_humaneval_evidence(output, {"marker": "new"})

    assert json.loads(output.read_text(encoding="utf-8")) == {"marker": "new"}
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

    selected = prepare_humaneval_output(context, HumanEvalProducer.STANDARD, "base")

    assert selected == standard
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
