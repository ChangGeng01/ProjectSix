"""Current-run construction and validation for certifiable HumanEval evidence.

This is an accidental-integrity boundary, not a signature system. A subject
receipt is supplied by the external model/checkpoint workflow; this module
binds that receipt and the current run/harness/dataset/sample set into the
plaintext evidence so stale or mismatched outputs fail closed.
"""

from __future__ import annotations

import hashlib
import json
import math
import os
import re
import stat
import tempfile
from dataclasses import dataclass
from enum import Enum
from pathlib import Path
from types import MappingProxyType
from typing import Mapping, Sequence


EVIDENCE_SCHEMA = "qinao/humaneval-evidence/v2"
SUBJECT_RECEIPTS_SCHEMA = "qinao/humaneval-subject-receipts/v1"
DATASET_ID = "openai/openai_humaneval"
DATASET_SPLIT = "test"
MAX_HUMANEVAL_SAMPLES = 164

_SHA256 = re.compile(r"^[0-9a-f]{64}$")
_OPAQUE_ID = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$")
_HARNESS_DOMAIN = b"QINAO-HUMANEVAL-HARNESS-V1\0"
_SAMPLE_SET_DOMAIN = b"QINAO-HUMANEVAL-SAMPLE-SET-V1\0"
_CONTEXT_ENV = (
    "QINAO_EVAL_RUN_ID",
    "QINAO_EVAL_EVIDENCE_DIR",
    "QINAO_SUBJECT_RECEIPTS",
    "QINAO_HUMANEVAL_DATASET_FINGERPRINT",
)


class HumanEvalProducer(Enum):
    """Closed producer identity supplied by the aggregation API, never a path."""

    STANDARD = ("qinao_humaneval", "qinao_humaneval.py", False)
    PAIRED = ("qinao_humaneval_paired", "qinao_humaneval_paired.py", True)

    def __init__(self, runner: str, script_name: str, paired: bool):
        self.runner = runner
        self.script_name = script_name
        self.paired = paired

    @property
    def sidefile_prefix(self) -> str:
        return self.runner.removeprefix("qinao_")


@dataclass(frozen=True)
class SubjectReceipt:
    """External content receipt plus the exact selectors it was issued for."""

    sha256: str
    model: str
    adapter: str | None

    def __post_init__(self) -> None:
        if not isinstance(self.sha256, str) or not _SHA256.fullmatch(self.sha256):
            raise ValueError("subject receipt sha256 must be 64 lowercase hex digits")
        if not isinstance(self.model, str) or not self.model or "\x00" in self.model:
            raise ValueError("subject receipt model selector must be nonempty")
        if self.adapter is not None and (
            not isinstance(self.adapter, str)
            or not self.adapter
            or "\x00" in self.adapter
        ):
            raise ValueError(
                "subject receipt adapter selector must be null or nonempty"
            )


@dataclass(frozen=True)
class HumanEvalRunContext:
    """Explicit current-run receipt context shared by writers and aggregation."""

    run_id: str
    evidence_dir: Path
    dataset_fingerprint: str
    subjects: Mapping[str, SubjectReceipt]

    def __post_init__(self) -> None:
        if not isinstance(self.run_id, str) or not _OPAQUE_ID.fullmatch(self.run_id):
            raise ValueError("run id must be a bounded filesystem-safe opaque id")
        raw_dir = Path(self.evidence_dir)
        if not raw_dir.is_absolute():
            raise ValueError("evidence directory must be absolute")
        if raw_dir.is_symlink():
            raise ValueError("evidence directory must not be a symlink")
        try:
            resolved_dir = raw_dir.resolve(strict=True)
        except OSError as error:
            raise ValueError(f"evidence directory is unavailable: {error}") from error
        if not resolved_dir.is_dir() or resolved_dir.name != self.run_id:
            raise ValueError("evidence directory must be the directory named by run id")
        if (
            not isinstance(self.dataset_fingerprint, str)
            or not self.dataset_fingerprint
            or len(self.dataset_fingerprint) > 256
            or any(ord(character) < 0x21 for character in self.dataset_fingerprint)
        ):
            raise ValueError("dataset fingerprint must be a bounded visible string")
        if not isinstance(self.subjects, Mapping) or not self.subjects:
            raise ValueError("at least one external subject receipt is required")
        copied_subjects: dict[str, SubjectReceipt] = {}
        for tag, receipt in self.subjects.items():
            if not isinstance(tag, str) or not _OPAQUE_ID.fullmatch(tag):
                raise ValueError("subject receipt tag must be a bounded opaque id")
            if not isinstance(receipt, SubjectReceipt):
                raise ValueError("subjects must contain typed SubjectReceipt values")
            copied_subjects[tag] = receipt
        object.__setattr__(self, "evidence_dir", resolved_dir)
        object.__setattr__(self, "subjects", MappingProxyType(copied_subjects))

    def subject_for(self, tag: str) -> SubjectReceipt:
        try:
            return self.subjects[tag]
        except KeyError as error:
            raise ValueError(
                f"external subject receipt missing for tag {tag!r}"
            ) from error

    def require_invocation(
        self, tag: str, *, model: str, adapter: str | None
    ) -> SubjectReceipt:
        receipt = self.subject_for(tag)
        if (model, adapter) != (receipt.model, receipt.adapter):
            raise ValueError(
                f"subject selectors for {tag!r} do not match the external receipt"
            )
        return receipt

    def require_dataset_fingerprint(self, observed: object) -> str:
        """Compare the loaded dataset's real fingerprint to the external receipt."""

        if observed != self.dataset_fingerprint:
            raise ValueError(
                "loaded HumanEval dataset fingerprint does not match current-run context"
            )
        return self.dataset_fingerprint


@dataclass(frozen=True)
class HumanEvalEvidenceSummary:
    score: float
    sample_count: int
    producer: HumanEvalProducer
    run_id: str
    tag: str
    subject_sha256: str
    harness_sha256: str
    dataset_id: str
    dataset_split: str
    dataset_fingerprint: str
    sample_set_sha256: str

    def provenance(self) -> dict[str, object]:
        return {
            "schema": EVIDENCE_SCHEMA,
            "producer": self.producer.runner,
            "run_id": self.run_id,
            "tag": self.tag,
            "subject_sha256": self.subject_sha256,
            "harness_sha256": self.harness_sha256,
            "dataset_id": self.dataset_id,
            "dataset_split": self.dataset_split,
            "dataset_fingerprint": self.dataset_fingerprint,
            "sample_set_sha256": self.sample_set_sha256,
            "sample_count": self.sample_count,
        }


def _strict_nonnegative_int(value: object) -> bool:
    return type(value) is int and value >= 0


def _frame(payload: bytes) -> bytes:
    return len(payload).to_bytes(8, "big") + payload


def _read_regular_file(path: Path) -> bytes:
    flags = os.O_RDONLY
    if hasattr(os, "O_CLOEXEC"):
        flags |= os.O_CLOEXEC
    if hasattr(os, "O_NOFOLLOW"):
        flags |= os.O_NOFOLLOW
    descriptor = os.open(path, flags)
    try:
        info = os.fstat(descriptor)
        if not stat.S_ISREG(info.st_mode):
            raise ValueError(f"harness component is not a regular file: {path.name}")
        chunks: list[bytes] = []
        while True:
            chunk = os.read(descriptor, 1024 * 1024)
            if not chunk:
                return b"".join(chunks)
            chunks.append(chunk)
    finally:
        os.close(descriptor)


def current_harness_sha256(producer: HumanEvalProducer) -> str:
    """Digest the exact current producer + shared evidence/sandbox source closure."""

    if not isinstance(producer, HumanEvalProducer):
        raise TypeError("producer must be a HumanEvalProducer")
    here = Path(__file__).resolve().parent
    producer_scripts = {producer.script_name}
    if producer is HumanEvalProducer.PAIRED:
        producer_scripts.add(HumanEvalProducer.STANDARD.script_name)
    component_names = sorted(
        producer_scripts | {"qinao_humaneval_evidence.py", "qinao_sandbox.py"}
    )
    digest = hashlib.sha256(_HARNESS_DOMAIN)
    for name in component_names:
        payload = _read_regular_file(here / name)
        digest.update(_frame(name.encode("utf-8")))
        digest.update(_frame(payload))
    return digest.hexdigest()


def canonical_sample_ids(sample_ids: Sequence[str]) -> tuple[str, ...]:
    if isinstance(sample_ids, (str, bytes)) or not isinstance(sample_ids, Sequence):
        raise ValueError("sample ids must be a sequence")
    if not all(isinstance(task_id, str) and task_id for task_id in sample_ids):
        raise ValueError("sample ids must be nonempty strings")
    ordered = tuple(sorted(sample_ids))
    if len(ordered) > MAX_HUMANEVAL_SAMPLES:
        raise ValueError(
            f"HumanEval evidence may contain at most {MAX_HUMANEVAL_SAMPLES} samples"
        )
    if len(set(ordered)) != len(ordered):
        raise ValueError("sample ids must be unique")
    return ordered


def validated_sample_limit(raw_value: object, *, default: int) -> int:
    """Parse the CLI sample count without negative slicing or silent truncation."""

    try:
        value = int(raw_value) if raw_value is not None else default
    except (TypeError, ValueError) as error:
        raise ValueError("HumanEval sample limit must be an integer") from error
    if not 1 <= value <= MAX_HUMANEVAL_SAMPLES:
        raise ValueError(
            f"HumanEval sample limit must be between 1 and {MAX_HUMANEVAL_SAMPLES}"
        )
    return value


def sample_set_sha256(sample_ids: Sequence[str]) -> str:
    digest = hashlib.sha256(_SAMPLE_SET_DOMAIN)
    for task_id in canonical_sample_ids(sample_ids):
        digest.update(_frame(task_id.encode("utf-8")))
    return digest.hexdigest()


def _valid_vector(
    per_problem: object,
    *,
    sample_ids: tuple[str, ...],
    passed: int | None = None,
) -> bool:
    if not isinstance(per_problem, dict) or set(per_problem) != set(sample_ids):
        return False
    if not all(
        isinstance(task_id, str)
        and task_id
        and type(outcome) is int
        and outcome in (0, 1)
        for task_id, outcome in per_problem.items()
    ):
        return False
    return passed is None or sum(per_problem.values()) == passed


def build_humaneval_evidence(
    *,
    passed: int,
    total: int,
    infra_errors: int,
    sample_ids: Sequence[str],
    producer: HumanEvalProducer,
    context: HumanEvalRunContext,
    tag: str,
    per_problem: Mapping[str, int] | None = None,
) -> dict[str, object]:
    """Build diagnostics and emit metric 30 only for complete current evidence."""

    if not all(
        _strict_nonnegative_int(value) for value in (passed, total, infra_errors)
    ):
        raise ValueError("HumanEval counts must be nonnegative integers")
    if total + infra_errors > MAX_HUMANEVAL_SAMPLES:
        raise ValueError(
            f"HumanEval evidence may cover at most {MAX_HUMANEVAL_SAMPLES} tasks"
        )
    if passed > total:
        raise ValueError("HumanEval passed count cannot exceed its denominator")
    if not isinstance(producer, HumanEvalProducer):
        raise TypeError("producer must be a HumanEvalProducer")
    receipt = context.subject_for(tag)
    ordered_ids = canonical_sample_ids(sample_ids)
    if len(ordered_ids) != total:
        raise ValueError("HumanEval sample ids must equal the counted denominator")

    vector = dict(per_problem) if per_problem is not None else None
    if producer.paired:
        if vector is None or not _valid_vector(
            vector, sample_ids=ordered_ids, passed=passed
        ):
            raise ValueError("paired HumanEval vector is inconsistent with its samples")
    elif vector is not None:
        raise ValueError("standard HumanEval evidence must not carry outcomes")

    evidence: dict[str, object] = {
        "_evidence_schema": EVIDENCE_SCHEMA,
        "_producer": producer.runner,
        "_run_id": context.run_id,
        "_tag": tag,
        "_subject_sha256": receipt.sha256,
        "_harness_sha256": current_harness_sha256(producer),
        "_dataset_id": DATASET_ID,
        "_dataset_split": DATASET_SPLIT,
        "_dataset_fingerprint": context.dataset_fingerprint,
        "_sample_ids": list(ordered_ids),
        "_sample_set_sha256": sample_set_sha256(ordered_ids),
        "_sample_count": total,
        "_N": total,
        "_passed": passed,
        "_infra_errs": infra_errors,
    }
    if vector is not None:
        evidence["per_problem"] = vector
    if total > 0 and infra_errors == 0:
        evidence["30"] = round(passed / total * 100, 1)
    return evidence


def validate_humaneval_evidence(
    evidence: object,
    *,
    producer: HumanEvalProducer,
    context: HumanEvalRunContext,
    tag: str,
) -> HumanEvalEvidenceSummary | None:
    """Return the current receipt-bound summary, or ``None`` if unavailable."""

    if not isinstance(producer, HumanEvalProducer) or not isinstance(evidence, dict):
        return None
    try:
        receipt = context.subject_for(tag)
        expected_harness = current_harness_sha256(producer)
    except (OSError, TypeError, ValueError):
        return None
    expected_metadata = {
        "_evidence_schema": EVIDENCE_SCHEMA,
        "_producer": producer.runner,
        "_run_id": context.run_id,
        "_tag": tag,
        "_subject_sha256": receipt.sha256,
        "_harness_sha256": expected_harness,
        "_dataset_id": DATASET_ID,
        "_dataset_split": DATASET_SPLIT,
        "_dataset_fingerprint": context.dataset_fingerprint,
    }
    if any(evidence.get(key) != value for key, value in expected_metadata.items()):
        return None

    sample_count = evidence.get("_sample_count")
    if (
        type(sample_count) is not int
        or sample_count <= 0
        or sample_count > MAX_HUMANEVAL_SAMPLES
    ):
        return None
    if evidence.get("_N") != sample_count:
        return None
    infra_errors = evidence.get("_infra_errs")
    if type(infra_errors) is not int or infra_errors != 0:
        return None
    passed = evidence.get("_passed")
    if type(passed) is not int or not 0 <= passed <= sample_count:
        return None
    try:
        sample_ids = canonical_sample_ids(evidence.get("_sample_ids"))
    except ValueError:
        return None
    if len(sample_ids) != sample_count:
        return None
    digest = sample_set_sha256(sample_ids)
    if evidence.get("_sample_set_sha256") != digest:
        return None

    score = evidence.get("30")
    if (
        isinstance(score, bool)
        or not isinstance(score, (int, float))
        or not math.isfinite(score)
        or not 0 <= score <= 100
    ):
        return None
    if float(score) != round(passed / sample_count * 100, 1):
        return None

    vector_present = "per_problem" in evidence
    if producer.paired != vector_present:
        return None
    if vector_present:
        vector = evidence["per_problem"]
        if not _valid_vector(vector, sample_ids=sample_ids, passed=passed):
            return None
        expected_score = round(sum(vector.values()) / sample_count * 100, 1)
        if float(score) != expected_score:
            return None

    return HumanEvalEvidenceSummary(
        score=float(score),
        sample_count=sample_count,
        producer=producer,
        run_id=context.run_id,
        tag=tag,
        subject_sha256=receipt.sha256,
        harness_sha256=expected_harness,
        dataset_id=DATASET_ID,
        dataset_split=DATASET_SPLIT,
        dataset_fingerprint=context.dataset_fingerprint,
        sample_set_sha256=digest,
    )


def _parse_subject_receipts(path: Path) -> Mapping[str, SubjectReceipt]:
    try:
        with path.open(encoding="utf-8") as handle:
            payload = json.load(handle)
    except (OSError, json.JSONDecodeError) as error:
        raise ValueError(f"subject receipt manifest is unavailable: {error}") from error
    if not isinstance(payload, dict) or set(payload) != {"schema", "subjects"}:
        raise ValueError("subject receipt manifest has an invalid top-level shape")
    if payload["schema"] != SUBJECT_RECEIPTS_SCHEMA:
        raise ValueError("subject receipt manifest schema is unsupported")
    subjects = payload["subjects"]
    if not isinstance(subjects, dict) or not subjects:
        raise ValueError("subject receipt manifest has no subjects")
    parsed: dict[str, SubjectReceipt] = {}
    for tag, raw_receipt in subjects.items():
        if not isinstance(raw_receipt, dict) or set(raw_receipt) != {
            "sha256",
            "model",
            "adapter",
        }:
            raise ValueError(f"subject receipt for {tag!r} has an invalid shape")
        parsed[tag] = SubjectReceipt(**raw_receipt)
    return parsed


def load_humaneval_run_context_from_env(
    *, required_tags: Sequence[str] = ()
) -> HumanEvalRunContext:
    missing = [name for name in _CONTEXT_ENV if not os.environ.get(name)]
    if missing:
        raise ValueError(
            "HumanEval current-run context missing: " + ", ".join(sorted(missing))
        )
    context = HumanEvalRunContext(
        run_id=os.environ["QINAO_EVAL_RUN_ID"],
        evidence_dir=Path(os.environ["QINAO_EVAL_EVIDENCE_DIR"]),
        dataset_fingerprint=os.environ["QINAO_HUMANEVAL_DATASET_FINGERPRINT"],
        subjects=_parse_subject_receipts(Path(os.environ["QINAO_SUBJECT_RECEIPTS"])),
    )
    for tag in required_tags:
        context.subject_for(tag)
    return context


def optional_humaneval_run_context_from_env(
    *, required_tags: Sequence[str] = ()
) -> HumanEvalRunContext | None:
    present = [bool(os.environ.get(name)) for name in _CONTEXT_ENV]
    if not any(present):
        return None
    if not all(present):
        missing = [
            name for name, is_present in zip(_CONTEXT_ENV, present) if not is_present
        ]
        raise ValueError(
            "partial HumanEval current-run context: " + ", ".join(sorted(missing))
        )
    return load_humaneval_run_context_from_env(required_tags=required_tags)


def prepare_humaneval_output(
    context: HumanEvalRunContext, producer: HumanEvalProducer, tag: str
) -> Path:
    """Invalidate all producer variants before any model/dataset work begins."""

    context.subject_for(tag)
    output = context.evidence_dir / f"qinao_{producer.sidefile_prefix}_{tag}.json"
    if output.parent != context.evidence_dir:
        raise ValueError("HumanEval output escaped its run-scoped directory")
    failures: list[OSError] = []
    for candidate_producer in HumanEvalProducer:
        candidate = (
            context.evidence_dir
            / f"qinao_{candidate_producer.sidefile_prefix}_{tag}.json"
        )
        try:
            candidate.unlink()
        except FileNotFoundError:
            pass
        except OSError as error:
            failures.append(error)
    if failures:
        raise ValueError(
            "failed to invalidate prior HumanEval output set"
        ) from failures[0]
    return output


def atomic_write_humaneval_evidence(
    output: Path, evidence: Mapping[str, object]
) -> None:
    """Publish complete JSON with a same-directory atomic rename and fsync."""

    output = Path(output)
    parent = output.parent
    descriptor, temporary_name = tempfile.mkstemp(
        prefix=f".{output.name}.", suffix=".tmp", dir=parent
    )
    temporary = Path(temporary_name)
    try:
        with os.fdopen(descriptor, "w", encoding="utf-8") as handle:
            json.dump(
                evidence,
                handle,
                allow_nan=False,
                sort_keys=True,
                separators=(",", ":"),
            )
            handle.write("\n")
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temporary, output)
        directory_descriptor = os.open(parent, os.O_RDONLY)
        try:
            os.fsync(directory_descriptor)
        finally:
            os.close(directory_descriptor)
    finally:
        try:
            temporary.unlink()
        except FileNotFoundError:
            pass
