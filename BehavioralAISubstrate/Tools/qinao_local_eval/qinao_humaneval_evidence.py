"""Current-run construction and validation for certifiable HumanEval evidence.

This is an accidental-integrity boundary, not a signature system. A subject
receipt is supplied by the external model/checkpoint workflow; this module
binds that receipt and the current run/harness/dataset/sample set into the
plaintext evidence so stale or mismatched outputs fail closed.
"""

from __future__ import annotations

import hashlib
import errno
import fcntl
import json
import math
import os
import re
import secrets
import stat
from dataclasses import dataclass, field
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
    _evidence_device: int = field(init=False, repr=False, compare=False)
    _evidence_inode: int = field(init=False, repr=False, compare=False)

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
        if resolved_dir.name != self.run_id:
            raise ValueError("evidence directory must be the directory named by run id")
        try:
            descriptor = os.open(resolved_dir, _directory_open_flags())
        except OSError as error:
            raise ValueError(f"evidence directory is unavailable: {error}") from error
        try:
            directory_info = os.fstat(descriptor)
            if not stat.S_ISDIR(directory_info.st_mode):
                raise ValueError("evidence directory must be a directory")
        finally:
            os.close(descriptor)
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
        object.__setattr__(self, "_evidence_device", directory_info.st_dev)
        object.__setattr__(self, "_evidence_inode", directory_info.st_ino)

    def open_evidence_directory(self) -> int:
        """Open the captured run directory without following a replacement path."""

        try:
            descriptor = os.open(self.evidence_dir, _directory_open_flags())
        except OSError as error:
            raise ValueError(f"evidence directory is unavailable: {error}") from error
        try:
            directory_info = os.fstat(descriptor)
            if (
                not stat.S_ISDIR(directory_info.st_mode)
                or directory_info.st_dev != self._evidence_device
                or directory_info.st_ino != self._evidence_inode
            ):
                raise ValueError("evidence directory identity changed after validation")
        except BaseException:
            os.close(descriptor)
            raise
        return descriptor

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
    passed: int
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
            "score": self.score,
            "passed": self.passed,
            "sample_count": self.sample_count,
        }


def _strict_nonnegative_int(value: object) -> bool:
    return type(value) is int and value >= 0


def _directory_open_flags() -> int:
    flags = os.O_RDONLY
    for name in ("O_CLOEXEC", "O_DIRECTORY", "O_NOFOLLOW"):
        flag = getattr(os, name, None)
        if flag is None:
            raise RuntimeError(f"platform lacks required no-follow directory flag {name}")
        flags |= flag
    return flags


def _attempt_lock_name(tag: str) -> str:
    return f".qinao_humaneval_{tag}.lock"


def _attempt_admission_prefix(tag: str) -> str:
    return f".qinao_humaneval_{tag}.attempt."


def _open_attempt_lock(directory_descriptor: int, tag: str) -> int:
    flags = os.O_RDWR | os.O_CREAT
    for name in ("O_CLOEXEC", "O_NOFOLLOW"):
        flags |= getattr(os, name)
    descriptor = os.open(
        _attempt_lock_name(tag),
        flags,
        0o600,
        dir_fd=directory_descriptor,
    )
    try:
        lock_info = os.fstat(descriptor)
        if not stat.S_ISREG(lock_info.st_mode) or lock_info.st_nlink != 1:
            raise ValueError("HumanEval attempt lock is not a private regular file")
    except BaseException:
        os.close(descriptor)
        raise
    return descriptor


def _cleanup_descriptor_snapshot(
    descriptors: Sequence[tuple[int | None, bool]],
) -> tuple[BaseException, ...]:
    """Unlock flock holders, then close every detached fd exactly once."""

    unique: list[tuple[int, bool]] = []
    positions: dict[int, int] = {}
    for descriptor, holds_flock in descriptors:
        if descriptor is None:
            continue
        position = positions.get(descriptor)
        if position is None:
            positions[descriptor] = len(unique)
            unique.append((descriptor, holds_flock))
        elif holds_flock and not unique[position][1]:
            unique[position] = (descriptor, True)

    failures: list[BaseException] = []
    for descriptor, holds_flock in unique:
        if not holds_flock:
            continue
        try:
            fcntl.flock(descriptor, fcntl.LOCK_UN)
        except BaseException as error:
            failures.append(error)
    for descriptor, _holds_flock in unique:
        try:
            # A non-EBADF close error has portable unknown fd state. Do not
            # inspect or retry: release was already attempted for every
            # authority-bearing flock, and every failure is reported upstream.
            os.close(descriptor)
        except BaseException as error:
            failures.append(error)
    return tuple(failures)


def _add_cleanup_notes(
    primary_error: BaseException,
    failures: Sequence[BaseException],
    *,
    label: str,
) -> None:
    for error in failures:
        primary_error.add_note(f"{label}: {type(error).__name__}: {error}")


def _raise_first_cleanup_error(
    failures: Sequence[BaseException], *, label: str
) -> None:
    if not failures:
        return
    primary_error = failures[0]
    _add_cleanup_notes(primary_error, failures[1:], label=label)
    raise primary_error


def _verify_observation_descriptors(
    context: HumanEvalRunContext,
    directory_descriptor: int,
    locks: Sequence[tuple[str, int]],
) -> None:
    try:
        directory_info = os.fstat(directory_descriptor)
        if (
            not stat.S_ISDIR(directory_info.st_mode)
            or directory_info.st_dev != context._evidence_device
            or directory_info.st_ino != context._evidence_inode
        ):
            raise ValueError("HumanEval observation directory identity changed")
        for tag, descriptor in locks:
            descriptor_info = os.fstat(descriptor)
            path_info = os.stat(
                _attempt_lock_name(tag),
                dir_fd=directory_descriptor,
                follow_symlinks=False,
            )
            if (
                not stat.S_ISREG(descriptor_info.st_mode)
                or descriptor_info.st_nlink != 1
                or not stat.S_ISREG(path_info.st_mode)
                or path_info.st_dev != descriptor_info.st_dev
                or path_info.st_ino != descriptor_info.st_ino
            ):
                raise ValueError("HumanEval observation lock identity changed")
    except OSError as error:
        raise ValueError("HumanEval observation descriptors are unavailable") from error


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

    candidate = default if raw_value is None else raw_value
    if type(candidate) is int:
        value = candidate
    elif isinstance(candidate, str):
        try:
            value = int(candidate)
        except ValueError as error:
            raise ValueError("HumanEval sample limit must be an integer") from error
    else:
        raise ValueError("HumanEval sample limit must be an integer")
    try:
        in_range = 1 <= value <= MAX_HUMANEVAL_SAMPLES
    except TypeError as error:
        raise ValueError("HumanEval sample limit must be an integer") from error
    if not in_range:
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
    if type(evidence.get("_N")) is not int or evidence["_N"] != sample_count:
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
        passed=passed,
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


class HumanEvalOutputAttempt:
    """Run-scoped coordination for one prepare→attempt→publish transaction.

    The lock and per-attempt tombstone carry no evidence or authority. The
    tombstone is made durable before admission so a killed writer cannot expose
    an older publication; it is removed only after a durable publish.
    """

    def __init__(
        self, context: HumanEvalRunContext, producer: HumanEvalProducer, tag: str
    ) -> None:
        if not isinstance(context, HumanEvalRunContext):
            raise TypeError("context must be a HumanEvalRunContext")
        if not isinstance(producer, HumanEvalProducer):
            raise TypeError("producer must be a HumanEvalProducer")
        context.subject_for(tag)
        self.context = context
        self.producer = producer
        self.tag = tag
        self.output_name = f"qinao_{producer.sidefile_prefix}_{tag}.json"
        self._directory_descriptor: int | None = None
        self._lock_descriptor: int | None = None
        self._admission_token = secrets.token_hex(32)
        self._admission_name = (
            _attempt_admission_prefix(tag) + self._admission_token
        )
        self._admission_descriptor: int | None = None
        self._retired_admission_descriptors: list[int] = []
        self._published_descriptor: int | None = None
        self._active = False
        self._published = False

    @property
    def output(self) -> Path:
        return self.context.evidence_dir / self.output_name

    def _candidate_names(self) -> tuple[str, ...]:
        return tuple(
            f"qinao_{candidate.sidefile_prefix}_{self.tag}.json"
            for candidate in HumanEvalProducer
        )

    def _invalidate(self) -> None:
        if self._directory_descriptor is None:
            raise RuntimeError("HumanEval attempt has no anchored directory")
        failures: list[OSError] = []
        for candidate_name in self._candidate_names():
            try:
                os.unlink(candidate_name, dir_fd=self._directory_descriptor)
            except FileNotFoundError:
                pass
            except OSError as error:
                failures.append(error)
        os.fsync(self._directory_descriptor)
        if failures:
            raise ValueError(
                "failed to invalidate prior HumanEval output set"
            ) from failures[0]
        self._published = False

    def _create_admission(self) -> None:
        if self._directory_descriptor is None:
            raise RuntimeError("HumanEval attempt has no anchored directory")
        flags = os.O_RDWR | os.O_CREAT | os.O_EXCL
        for name in ("O_CLOEXEC", "O_NOFOLLOW"):
            flags |= getattr(os, name)
        descriptor = os.open(
            self._admission_name,
            flags,
            0o600,
            dir_fd=self._directory_descriptor,
        )
        self._admission_descriptor = descriptor
        admission_info = os.fstat(descriptor)
        if not stat.S_ISREG(admission_info.st_mode) or admission_info.st_nlink != 1:
            raise ValueError("HumanEval attempt admission is not a private regular file")
        fcntl.flock(descriptor, fcntl.LOCK_EX)
        payload = (self._admission_token + "\n").encode("ascii")
        view = memoryview(payload)
        while view:
            written = os.write(descriptor, view)
            if written <= 0:
                raise OSError("failed to persist HumanEval attempt admission")
            view = view[written:]
        os.fsync(descriptor)
        os.fsync(self._directory_descriptor)

    def _verify_admission(self) -> None:
        if (
            self._directory_descriptor is None
            or self._admission_descriptor is None
        ):
            raise RuntimeError("HumanEval attempt has no durable admission")
        try:
            path_info = os.stat(
                self._admission_name,
                dir_fd=self._directory_descriptor,
                follow_symlinks=False,
            )
        except OSError as error:
            raise ValueError("HumanEval attempt admission disappeared") from error
        descriptor_info = os.fstat(self._admission_descriptor)
        if (
            not stat.S_ISREG(path_info.st_mode)
            or path_info.st_dev != descriptor_info.st_dev
            or path_info.st_ino != descriptor_info.st_ino
        ):
            raise ValueError("HumanEval attempt admission identity changed")
        os.lseek(self._admission_descriptor, 0, os.SEEK_SET)
        payload = os.read(self._admission_descriptor, 256)
        if payload != (self._admission_token + "\n").encode("ascii"):
            raise ValueError("HumanEval attempt admission receipt is malformed")

    def _verify_published_output(self) -> None:
        """Prove the anchored output path still names the retained publish inode."""

        if (
            self._directory_descriptor is None
            or self._published_descriptor is None
        ):
            raise RuntimeError("HumanEval attempt has no retained publication")
        try:
            path_info = os.stat(
                self.output_name,
                dir_fd=self._directory_descriptor,
                follow_symlinks=False,
            )
        except OSError as error:
            raise ValueError("published HumanEval output disappeared") from error
        descriptor_info = os.fstat(self._published_descriptor)
        if (
            not stat.S_ISREG(path_info.st_mode)
            or not stat.S_ISREG(descriptor_info.st_mode)
            or path_info.st_nlink != 1
            or descriptor_info.st_nlink != 1
            or path_info.st_dev != descriptor_info.st_dev
            or path_info.st_ino != descriptor_info.st_ino
        ):
            raise ValueError("published HumanEval output identity changed")

    def _poison_published_output(self) -> None:
        """Durably make the exact retained publication unparsable."""

        self._verify_published_output()
        descriptor = self._published_descriptor
        if descriptor is None:
            raise RuntimeError("HumanEval attempt has no retained publication")
        os.ftruncate(descriptor, 0)
        os.fsync(descriptor)
        if os.fstat(descriptor).st_size != 0:
            raise OSError("failed to poison retained HumanEval publication")

    def _prune_stale_admissions(self) -> None:
        if self._directory_descriptor is None:
            raise RuntimeError("HumanEval attempt has no anchored directory")
        prefix = _attempt_admission_prefix(self.tag)
        removed = False
        for name in os.listdir(self._directory_descriptor):
            if not name.startswith(prefix) or name == self._admission_name:
                continue
            flags = os.O_RDWR
            for flag_name in ("O_CLOEXEC", "O_NOFOLLOW", "O_NONBLOCK"):
                flags |= getattr(os, flag_name)
            try:
                descriptor = os.open(
                    name, flags, dir_fd=self._directory_descriptor
                )
            except OSError:
                continue
            try:
                marker_info = os.fstat(descriptor)
                if not stat.S_ISREG(marker_info.st_mode):
                    continue
                try:
                    fcntl.flock(
                        descriptor, fcntl.LOCK_EX | fcntl.LOCK_NB
                    )
                except OSError as error:
                    if error.errno in (errno.EACCES, errno.EAGAIN):
                        continue
                    raise
                try:
                    os.unlink(name, dir_fd=self._directory_descriptor)
                    removed = True
                except FileNotFoundError:
                    pass
            finally:
                os.close(descriptor)
        if removed:
            os.fsync(self._directory_descriptor)

    def _commit_admission(self) -> None:
        if self._directory_descriptor is None:
            raise RuntimeError("HumanEval attempt has no anchored directory")
        self._verify_admission()
        os.unlink(self._admission_name, dir_fd=self._directory_descriptor)
        os.fsync(self._directory_descriptor)

    def _ensure_admission_visible(self) -> None:
        """Restore and durably sync admission after a commit failure."""

        try:
            self._verify_admission()
            return
        except (OSError, RuntimeError, ValueError):
            pass

        previous_descriptor = self._admission_descriptor
        self._admission_token = secrets.token_hex(32)
        self._admission_name = (
            _attempt_admission_prefix(self.tag) + self._admission_token
        )
        self._admission_descriptor = None
        if previous_descriptor is not None:
            # Keep the old locked descriptor alive until transaction cleanup;
            # closing it is not part of proving the replacement marker durable.
            self._retired_admission_descriptors.append(previous_descriptor)
        # _create_admission assigns the descriptor immediately after the
        # no-follow create. The caller records any file/directory fsync failure
        # and must establish a different fail-closed postcondition.
        self._create_admission()

    def _compensate_failed_commit(self, primary_error: BaseException) -> None:
        """Establish and report a concrete fail-closed postcondition."""

        secured_by: list[str] = []
        failures: list[tuple[str, BaseException]] = []
        for label, action in (
            ("durable admission", self._ensure_admission_visible),
            ("durably poisoned retained output", self._poison_published_output),
            ("durable output invalidation", self._invalidate),
        ):
            try:
                action()
                secured_by.append(label)
            except BaseException as error:
                failures.append((label, error))
        for label, error in failures:
            primary_error.add_note(
                f"HumanEval commit compensation failed ({label}): "
                f"{type(error).__name__}: {error}"
            )
        if not secured_by:
            failure = RuntimeError(
                "HumanEval commit failed without a provable fail-closed postcondition"
            )
            for label, error in failures:
                failure.add_note(
                    f"{label}: {type(error).__name__}: {error}"
                )
            raise failure from primary_error
        primary_error.add_note(
            "HumanEval evidence remained fail-closed via " + ", ".join(secured_by)
        )

    def _close(self) -> tuple[BaseException, ...]:
        """Detach, unlock authority-bearing fds, and close every fd once."""

        descriptors = [
            (self._admission_descriptor, True),
            *((descriptor, True) for descriptor in self._retired_admission_descriptors),
            (self._lock_descriptor, True),
            (self._published_descriptor, False),
            (self._directory_descriptor, False),
        ]
        self._published_descriptor = None
        self._admission_descriptor = None
        self._retired_admission_descriptors.clear()
        self._lock_descriptor = None
        self._directory_descriptor = None
        self._active = False
        return _cleanup_descriptor_snapshot(descriptors)

    def __enter__(self) -> HumanEvalOutputAttempt:
        if self._active or self._directory_descriptor is not None:
            raise RuntimeError("HumanEval attempt cannot be entered twice")
        self._directory_descriptor = self.context.open_evidence_directory()
        try:
            self._create_admission()
            self._lock_descriptor = _open_attempt_lock(
                self._directory_descriptor, self.tag
            )
            fcntl.flock(self._lock_descriptor, fcntl.LOCK_EX)
            self._active = True
            self._verify_admission()
            self._prune_stale_admissions()
            self._invalidate()
        except BaseException as error:
            _add_cleanup_notes(
                error,
                self._close(),
                label="HumanEval attempt cleanup",
            )
            raise
        return self

    def __exit__(self, exc_type, _exc, _traceback) -> bool:
        try:
            if exc_type is None and self._published:
                try:
                    # The admission remains visible for the entire with-body.
                    # Only a completely normal transaction exit may commit it.
                    self._verify_published_output()
                    self._commit_admission()
                except BaseException as error:
                    self._compensate_failed_commit(error)
                    raise
            elif exc_type is not None and self._published:
                self._invalidate()
        except BaseException as error:
            _add_cleanup_notes(
                error,
                self._close(),
                label="HumanEval attempt cleanup",
            )
            raise
        cleanup_failures = self._close()
        if _exc is not None:
            _add_cleanup_notes(
                _exc,
                cleanup_failures,
                label="HumanEval attempt cleanup",
            )
        else:
            _raise_first_cleanup_error(
                cleanup_failures,
                label="HumanEval attempt cleanup",
            )
        return False


class HumanEvalObservation:
    """Shared-lock snapshot used by filesystem and typed aggregation paths."""

    def __init__(self, context: HumanEvalRunContext, tag: str) -> None:
        if not isinstance(context, HumanEvalRunContext):
            raise TypeError("context must be a HumanEvalRunContext")
        context.subject_for(tag)
        self.context = context
        self.tag = tag
        self.directory_descriptor: int | None = None
        self._lock_descriptor: int | None = None
        self.admission_pending = False
        self._active = False

    def _cleanup(self) -> tuple[BaseException, ...]:
        descriptors = (
            (self._lock_descriptor, True),
            (self.directory_descriptor, False),
        )
        self._lock_descriptor = None
        self.directory_descriptor = None
        self.admission_pending = False
        self._active = False
        return _cleanup_descriptor_snapshot(descriptors)

    def __enter__(self) -> HumanEvalObservation:
        if self.directory_descriptor is not None:
            raise RuntimeError("HumanEval observation cannot be entered twice")
        self.directory_descriptor = self.context.open_evidence_directory()
        try:
            self._lock_descriptor = _open_attempt_lock(
                self.directory_descriptor, self.tag
            )
            fcntl.flock(self._lock_descriptor, fcntl.LOCK_SH)
            prefix = _attempt_admission_prefix(self.tag)
            self.admission_pending = any(
                name.startswith(prefix)
                for name in os.listdir(self.directory_descriptor)
            )
            self._active = True
        except BaseException as error:
            _add_cleanup_notes(
                error,
                self._cleanup(),
                label="HumanEval observation enter cleanup",
            )
            raise
        return self

    def __exit__(self, _exc_type, exc, _traceback) -> bool:
        cleanup_failures = self._cleanup()
        if exc is not None:
            _add_cleanup_notes(
                exc,
                cleanup_failures,
                label="HumanEval observation cleanup",
            )
        else:
            _raise_first_cleanup_error(
                cleanup_failures,
                label="HumanEval observation cleanup",
            )
        return False

    def snapshot_for(
        self, context: HumanEvalRunContext, tag: str
    ) -> tuple[int, bool]:
        if type(self) is not HumanEvalObservation:
            raise ValueError("HumanEval observation runtime type is not closed")
        if context is not self.context or tag != self.tag:
            raise ValueError("HumanEval observation does not cover this run/tag")
        if (
            not self._active
            or self.directory_descriptor is None
            or self._lock_descriptor is None
        ):
            raise ValueError("HumanEval observation is not active")
        _verify_observation_descriptors(
            context,
            self.directory_descriptor,
            ((self.tag, self._lock_descriptor),),
        )
        return self.directory_descriptor, self.admission_pending


class HumanEvalObservationSet:
    """One anchored, ordered shared-lock snapshot across multiple tags."""

    def __init__(self, context: HumanEvalRunContext, tags: Sequence[str]) -> None:
        if not isinstance(context, HumanEvalRunContext):
            raise TypeError("context must be a HumanEvalRunContext")
        if isinstance(tags, (str, bytes)) or not isinstance(tags, Sequence):
            raise TypeError("HumanEval observation tags must be a sequence")
        ordered_tags = tuple(sorted(tags))
        if not ordered_tags or len(set(ordered_tags)) != len(ordered_tags):
            raise ValueError("HumanEval observation tags must be nonempty and distinct")
        for tag in ordered_tags:
            context.subject_for(tag)
        self.context = context
        self.tags = ordered_tags
        self.directory_descriptor: int | None = None
        self._lock_descriptors: list[int] = []
        self._admission_pending: dict[str, bool] = {}
        self._active = False

    def _cleanup(self) -> tuple[BaseException, ...]:
        descriptors = [
            *((descriptor, True) for descriptor in self._lock_descriptors),
            (self.directory_descriptor, False),
        ]
        self._lock_descriptors.clear()
        self.directory_descriptor = None
        self._admission_pending.clear()
        self._active = False
        return _cleanup_descriptor_snapshot(descriptors)

    def __enter__(self) -> HumanEvalObservationSet:
        if self.directory_descriptor is not None:
            raise RuntimeError("HumanEval observation cannot be entered twice")
        self.directory_descriptor = self.context.open_evidence_directory()
        try:
            for tag in self.tags:
                descriptor = _open_attempt_lock(self.directory_descriptor, tag)
                self._lock_descriptors.append(descriptor)
                fcntl.flock(descriptor, fcntl.LOCK_SH)
            names = tuple(os.listdir(self.directory_descriptor))
            self._admission_pending = {
                tag: any(
                    name.startswith(_attempt_admission_prefix(tag)) for name in names
                )
                for tag in self.tags
            }
            self._active = True
        except BaseException as error:
            _add_cleanup_notes(
                error,
                self._cleanup(),
                label="HumanEval observation-set enter cleanup",
            )
            raise
        return self

    def snapshot_for(
        self, context: HumanEvalRunContext, tag: str
    ) -> tuple[int, bool]:
        if type(self) is not HumanEvalObservationSet:
            raise ValueError("HumanEval observation-set runtime type is not closed")
        if context is not self.context or tag not in self.tags:
            raise ValueError("HumanEval observation does not cover this run/tag")
        if (
            not self._active
            or self.directory_descriptor is None
            or len(self._lock_descriptors) != len(self.tags)
            or set(self._admission_pending) != set(self.tags)
        ):
            raise ValueError("HumanEval observation is not active")
        _verify_observation_descriptors(
            context,
            self.directory_descriptor,
            tuple(zip(self.tags, self._lock_descriptors)),
        )
        return self.directory_descriptor, self._admission_pending[tag]

    def __exit__(self, _exc_type, exc, _traceback) -> bool:
        cleanup_failures = self._cleanup()
        if exc is not None:
            _add_cleanup_notes(
                exc,
                cleanup_failures,
                label="HumanEval observation-set cleanup",
            )
        else:
            _raise_first_cleanup_error(
                cleanup_failures,
                label="HumanEval observation-set cleanup",
            )
        return False


def observe_humaneval_outputs(
    context: HumanEvalRunContext, tag: str
) -> HumanEvalObservation:
    return HumanEvalObservation(context, tag)


def observe_humaneval_output_set(
    context: HumanEvalRunContext, tags: Sequence[str]
) -> HumanEvalObservationSet:
    return HumanEvalObservationSet(context, tags)


def prepare_humaneval_output(
    context: HumanEvalRunContext, producer: HumanEvalProducer, tag: str
) -> HumanEvalOutputAttempt:
    """Create the exclusive transaction that invalidates before model work."""

    return HumanEvalOutputAttempt(context, producer, tag)


def atomic_write_humaneval_evidence(
    attempt: HumanEvalOutputAttempt, evidence: Mapping[str, object]
) -> None:
    """Publish through an active attempt with atomic rename and durable ordering."""

    if not isinstance(attempt, HumanEvalOutputAttempt):
        raise TypeError("HumanEval evidence publication requires an active attempt")
    if not attempt._active or attempt._directory_descriptor is None:
        raise RuntimeError("HumanEval evidence publication requires an active attempt")
    if attempt._published:
        raise RuntimeError("HumanEval attempt already published evidence")
    payload = (
        json.dumps(
            evidence,
            allow_nan=False,
            sort_keys=True,
            separators=(",", ":"),
        )
        + "\n"
    ).encode("utf-8")
    temporary_name = f".{attempt.output_name}.{secrets.token_hex(16)}.tmp"
    temporary_descriptor: int | None = None
    try:
        temporary_flags = os.O_WRONLY | os.O_CREAT | os.O_EXCL
        for name in ("O_CLOEXEC", "O_NOFOLLOW"):
            temporary_flags |= getattr(os, name)
        temporary_descriptor = os.open(
            temporary_name,
            temporary_flags,
            0o600,
            dir_fd=attempt._directory_descriptor,
        )
        view = memoryview(payload)
        while view:
            written = os.write(temporary_descriptor, view)
            if written <= 0:
                raise OSError("failed to write HumanEval evidence")
            view = view[written:]
        os.fsync(temporary_descriptor)
        os.replace(
            temporary_name,
            attempt.output_name,
            src_dir_fd=attempt._directory_descriptor,
            dst_dir_fd=attempt._directory_descriptor,
        )
        attempt._published_descriptor = temporary_descriptor
        temporary_descriptor = None
        try:
            attempt._verify_published_output()
            os.fsync(attempt._directory_descriptor)
        except BaseException as error:
            # A rename whose directory entry could not be made durable is not
            # acceptable evidence. Remove it before returning the failure.
            try:
                attempt._poison_published_output()
            except BaseException as poison_error:
                error.add_note(
                    "HumanEval publish poison failed: "
                    f"{type(poison_error).__name__}: {poison_error}"
                )
            try:
                attempt._invalidate()
            except BaseException as invalidation_error:
                error.add_note(
                    "HumanEval publish invalidation failed: "
                    f"{type(invalidation_error).__name__}: {invalidation_error}"
                )
            raise
        attempt._published = True
    finally:
        if temporary_descriptor is not None:
            os.close(temporary_descriptor)
        try:
            os.unlink(temporary_name, dir_fd=attempt._directory_descriptor)
        except FileNotFoundError:
            pass
