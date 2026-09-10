#!/usr/bin/env python3
"""Validate the closed Artifact-Mesh recovery matrix.

Matrix mode is deliberately structural.  It proves that the immutable payload
contains the exact 40-row corpus; it does not claim that an iPhone executed any
row.  Device mode validates the closed external-evidence contract independently
and can never promote its diagnostic result into admission authority.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import stat
import subprocess
import sys
import unicodedata
from pathlib import Path, PurePosixPath
from typing import Any, Optional, Sequence


MATRIX_RELATIVE_PATH = PurePosixPath(
    "docs/superpowers/specs/qinao-artifact-mesh-device-recovery-matrix-v1.json"
)
MATRIX_ID = "qinao-artifact-mesh-device-recovery-matrix-v1"
OPERATIONS = (
    "genesisReserve",
    "genesisSQLiteCommit",
    "genesisAnchorPromote",
    "reopen",
    "ordinaryPutAnchorPending",
    "ordinaryPutSQLiteCommit",
    "walShmCheckpoint",
    "ordinaryPutAnchorFloorPromote",
    "k3ReferenceCommit",
    "quarantineInstall",
    "recoveryLeaseAcquire",
    "recoveryFloorUpdate",
    "recoveryComplete",
)
NO_FAULT_EXPECTED = {
    "genesisReserve": {
        "before": ("fresh", "resume", 0, 0, 0),
        "after": ("genesisPending", "resume", 0, 0, 0),
    },
    "genesisSQLiteCommit": {
        "before": ("genesisPending", "resume", 0, 0, 0),
        "after": ("sqliteCommittedG0", "promote", 0, 0, 0),
    },
    "genesisAnchorPromote": {
        "before": ("sqliteCommittedG0", "promote", 0, 0, 0),
        "after": ("committedG0", "resume", 0, 0, 0),
    },
    "reopen": {
        "before": ("committedG0", "resume", 0, 0, 0),
        "after": ("committedG0", "resume", 0, 0, 0),
    },
    "ordinaryPutAnchorPending": {
        "before": ("committedG0", "resume", 0, 0, 0),
        "after": ("committedPendingG1", "clearPending", 0, 0, 0),
    },
    "ordinaryPutSQLiteCommit": {
        "before": ("committedPendingG1", "clearPending", 0, 0, 0),
        "after": ("sqliteCommittedG1", "promote", 1, 1, 0),
    },
    "walShmCheckpoint": {
        "before": ("sqliteCommittedG1", "promote", 1, 1, 0),
        "after": ("walCheckpointedG1", "promote", 1, 1, 0),
    },
    "ordinaryPutAnchorFloorPromote": {
        "before": ("walCheckpointedG1", "promote", 1, 1, 0),
        "after": ("committedG1", "resume", 1, 1, 0),
    },
    "k3ReferenceCommit": {
        "before": ("committedG1", "queryReconcile", 1, 1, 0),
        "after": ("k3CommittedG1", "queryReconcile", 1, 1, 0),
    },
    "quarantineInstall": {
        "before": ("corruptCommittedG1", "quarantine", 1, 1, 0),
        "after": ("quarantinedG1", "quarantine", 1, 1, 0),
    },
    "recoveryLeaseAcquire": {
        "before": ("quarantinedG1", "recoveryComplete", 2, 1, 1),
        "after": ("recoveryLeaseG1", "recoveryComplete", 2, 1, 1),
    },
    "recoveryFloorUpdate": {
        "before": ("recoveryLeaseG1", "recoveryComplete", 2, 1, 1),
        "after": ("recoveryFloorG2", "recoveryComplete", 2, 1, 1),
    },
    "recoveryComplete": {
        "before": ("recoveryFloorG2", "recoveryComplete", 2, 1, 1),
        "after": ("recoveryCompleteG2", "recoveryComplete", 2, 1, 1),
    },
}
FAULT_CASES = (
    (
        "deleteDatabase",
        "committedG1",
        "after",
        "reopen",
        "beforeRecoveryOpen",
        "quarantine",
        1,
        1,
        0,
    ),
    (
        "deleteWAL",
        "walCheckpointedG1",
        "after",
        "walShmCheckpoint",
        "beforeRecoveryOpen",
        "quarantine",
        1,
        1,
        0,
    ),
    (
        "deleteSHM",
        "walCheckpointedG1",
        "after",
        "walShmCheckpoint",
        "beforeRecoveryOpen",
        "quarantine",
        1,
        1,
        0,
    ),
    (
        "replacePartialFamily",
        "walCheckpointedG1",
        "after",
        "walShmCheckpoint",
        "beforeRecoveryOpen",
        "quarantine",
        1,
        1,
        0,
    ),
    (
        "replaceStaleFamily",
        "committedG1",
        "after",
        "ordinaryPutAnchorFloorPromote",
        "beforeRecoveryOpen",
        "quarantine",
        1,
        1,
        0,
    ),
    (
        "substituteWrongKeyEpoch",
        "committedG0",
        "after",
        "genesisAnchorPromote",
        "beforeRecoveryOpen",
        "quarantine",
        0,
        0,
        0,
    ),
    (
        "regressAnchorFloor",
        "committedG1",
        "after",
        "ordinaryPutAnchorFloorPromote",
        "beforeRecoveryOpen",
        "quarantine",
        1,
        1,
        0,
    ),
    (
        "deleteKeychainAnchor",
        "committedG0",
        "after",
        "genesisAnchorPromote",
        "beforeRecoveryOpen",
        "quarantine",
        0,
        0,
        0,
    ),
    (
        "dropSQLiteReply",
        "committedPendingG1",
        "after",
        "ordinaryPutSQLiteCommit",
        "atDurableCommitBeforeReply",
        "promote",
        1,
        1,
        0,
    ),
    (
        "dropK3Reply",
        "committedG1",
        "after",
        "k3ReferenceCommit",
        "atDurableCommitBeforeReply",
        "queryReconcile",
        1,
        1,
        0,
    ),
    (
        "raceSecondCAS",
        "committedG1",
        "before",
        "ordinaryPutSQLiteCommit",
        "whileProcessAlive",
        "queryReconcile",
        1,
        1,
        0,
    ),
    (
        "corruptQuarantineMember",
        "quarantinedG1",
        "after",
        "quarantineInstall",
        "beforeRecoveryOpen",
        "quarantine",
        1,
        1,
        0,
    ),
    (
        "expireRecoveryLease",
        "recoveryLeaseG1",
        "after",
        "recoveryLeaseAcquire",
        "beforeRecoveryOpen",
        "recoveryComplete",
        2,
        1,
        1,
    ),
    (
        "protectedDataUnavailable",
        "committedG1",
        "before",
        "reopen",
        "afterRebootBeforeFirstUnlock",
        "denyUnavailable",
        1,
        1,
        0,
    ),
)
OUTER_KEYS = {"schema_version", "matrix_id", "operations", "rows"}
ROW_KEYS = {
    "scenarioID",
    "initialState",
    "cut",
    "mandatoryFaultAction",
    "faultTiming",
    "expectedReopenDisposition",
    "expectedStoreIdentity",
    "expectedGeneration",
    "expectedRecordRoot",
    "expectedCASHead",
    "expectedOrdinaryPutFloor",
    "expectedRecoveryFloor",
}
CUT_KEYS = {"operation", "tag"}
SYMBOLIC_REFERENCES = {
    "expectedStoreIdentity": "$derived.storeIdentity",
    "expectedRecordRoot": "$derived.recordRoot",
    "expectedCASHead": "$derived.casHead",
}
FORBIDDEN_KEY_FRAGMENTS = (
    "success",
    "passed",
    "wave",
    "owner",
    "status",
    "admission",
    "receipt",
    "result",
    "device",
)
OID_PATTERN = re.compile(r"(?:[0-9a-f]{40}|[0-9a-f]{64})\Z")
LOWER_HEX_64_PATTERN = re.compile(r"[0-9a-f]{64}\Z")
LOWER_UUID_PATTERN = re.compile(
    r"[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\Z"
)
ZERO_DIGEST = "0" * 64
OPERATION_ID = "w1.artifact-mesh-contract-freeze"
COMMAND_ID = "w1.artifact-mesh.device-recovery"
COMMON_BINDING_KEYS = (
    "operationID",
    "commandID",
    "candidateCommitOID",
    "candidateTreeOID",
    "policyRoot",
    "challengeDigest",
    "deviceProfileDigest",
    "matrixDigest",
    "custodyManifestDigest",
)
ASSERTION_COUNTS = (
    ("w1.assert.device-physical-40-of-40", 40),
    ("w1.assert.two-process-cas", 2),
    ("w1.assert.persist-wal-full", 3),
    ("w1.assert.sidecars-protected", 3),
    ("w1.assert.atomic-quarantine", 1),
    ("w1.assert.preunlock-zero-mutation", 1),
    ("w1.assert.factory-external-reopen", 1),
    ("w1.assert.release-exclusion", 1),
    ("w1.assert.custody-cleanup", 1),
)
MAX_MATRIX_BYTES = 2 * 1024 * 1024
MAX_EVIDENCE_BYTES = 64 * 1024 * 1024
GIT_ENVIRONMENT = {
    "GIT_ATTR_NOSYSTEM": "1",
    "GIT_CONFIG_GLOBAL": "/dev/null",
    "GIT_CONFIG_NOSYSTEM": "1",
    "GIT_CONFIG_SYSTEM": "/dev/null",
    "GIT_NO_LAZY_FETCH": "1",
    "GIT_NO_REPLACE_OBJECTS": "1",
    "GIT_OPTIONAL_LOCKS": "0",
    "GIT_PAGER": "cat",
    "GIT_TERMINAL_PROMPT": "0",
    "HOME": "/nonexistent",
    "LANG": "C",
    "LC_ALL": "C",
    "PAGER": "cat",
}


class MatrixValidationError(ValueError):
    """The matrix, payload binding, or evidence surface is invalid."""


class DuplicateJSONKeyError(MatrixValidationError):
    """A JSON object contains a duplicate key."""


def reject_duplicate_json_keys(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            raise DuplicateJSONKeyError(f"duplicate JSON key: {key!r}")
        result[key] = value
    return result


def canonical_json_bytes(value: Any) -> bytes:
    try:
        return json.dumps(
            value,
            allow_nan=False,
            ensure_ascii=False,
            separators=(",", ":"),
            sort_keys=True,
        ).encode("utf-8")
    except (TypeError, ValueError) as error:
        raise MatrixValidationError(f"value is not canonical JSON: {error}") from error


def _expected_row(
    scenario_id: str,
    initial_state: str,
    cut_tag: str,
    operation: str,
    fault: str,
    timing: str,
    terminal: str,
    generation: int,
    put_floor: int,
    recovery_floor: int,
) -> dict[str, Any]:
    return {
        "scenarioID": scenario_id,
        "initialState": initial_state,
        "cut": {"operation": operation, "tag": cut_tag},
        "mandatoryFaultAction": fault,
        "faultTiming": timing,
        "expectedReopenDisposition": terminal,
        "expectedStoreIdentity": "$derived.storeIdentity",
        "expectedGeneration": generation,
        "expectedRecordRoot": "$derived.recordRoot",
        "expectedCASHead": "$derived.casHead",
        "expectedOrdinaryPutFloor": put_floor,
        "expectedRecoveryFloor": recovery_floor,
    }


def expected_rows() -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    for operation in OPERATIONS:
        for cut_tag in ("before", "after"):
            initial, terminal, generation, put_floor, recovery_floor = (
                NO_FAULT_EXPECTED[operation][cut_tag]
            )
            rows.append(
                _expected_row(
                    f"nofault.{operation}.{cut_tag}",
                    initial,
                    cut_tag,
                    operation,
                    "none",
                    "none",
                    terminal,
                    generation,
                    put_floor,
                    recovery_floor,
                )
            )
    for case in FAULT_CASES:
        (
            action,
            initial,
            cut_tag,
            operation,
            timing,
            terminal,
            generation,
            put_floor,
            recovery_floor,
        ) = case
        rows.append(
            _expected_row(
                f"fault.{action}",
                initial,
                cut_tag,
                operation,
                action,
                timing,
                terminal,
                generation,
                put_floor,
                recovery_floor,
            )
        )
    if len(rows) != 40:
        raise AssertionError(f"closed checker corpus has {len(rows)} rows, not 40")
    return rows


def expected_matrix() -> dict[str, Any]:
    return {
        "schema_version": 1,
        "matrix_id": MATRIX_ID,
        "operations": list(OPERATIONS),
        "rows": expected_rows(),
    }


def _require_exact_keys(value: Any, expected: set[str], label: str) -> dict[str, Any]:
    if not isinstance(value, dict):
        raise MatrixValidationError(f"{label} must be a JSON object")
    actual = set(value)
    if actual != expected:
        missing = sorted(expected - actual)
        extra = sorted(actual - expected)
        raise MatrixValidationError(
            f"{label} key set mismatch: missing={missing!r} extra={extra!r}"
        )
    return value


def _reject_forbidden_key_fragments(value: Any, label: str = "matrix") -> None:
    if isinstance(value, dict):
        for key, child in value.items():
            folded = key.casefold()
            for fragment in FORBIDDEN_KEY_FRAGMENTS:
                if fragment in folded:
                    raise MatrixValidationError(
                        f"{label} contains forbidden key fragment {fragment!r}: {key!r}"
                    )
            _reject_forbidden_key_fragments(child, f"{label}.{key}")
    elif isinstance(value, list):
        for index, child in enumerate(value):
            _reject_forbidden_key_fragments(child, f"{label}[{index}]")


def validate_matrix_document(document: Any) -> None:
    _reject_forbidden_key_fragments(document)
    matrix = _require_exact_keys(document, OUTER_KEYS, "matrix")
    if type(matrix["schema_version"]) is not int or matrix["schema_version"] != 1:
        raise MatrixValidationError("schema_version must be unsigned integer 1")
    if matrix["matrix_id"] != MATRIX_ID:
        raise MatrixValidationError("matrix_id is not the closed matrix identity")
    if matrix["operations"] != list(OPERATIONS):
        raise MatrixValidationError(
            "operations are not the exact ordered 13-member corpus"
        )
    rows = matrix["rows"]
    if not isinstance(rows, list) or len(rows) != 40:
        raise MatrixValidationError("rows must contain exactly 40 entries")

    scenario_ids: list[str] = []
    for index, value in enumerate(rows):
        row = _require_exact_keys(value, ROW_KEYS, f"rows[{index}]")
        cut = _require_exact_keys(row["cut"], CUT_KEYS, f"rows[{index}].cut")
        scenario_id = row["scenarioID"]
        if (
            not isinstance(scenario_id, str)
            or unicodedata.normalize("NFC", scenario_id) != scenario_id
            or any(
                unicodedata.category(character).startswith("C")
                for character in scenario_id
            )
        ):
            raise MatrixValidationError(
                f"rows[{index}].scenarioID is not canonical NFC text"
            )
        scenario_ids.append(scenario_id)
        for key in (
            "expectedGeneration",
            "expectedOrdinaryPutFloor",
            "expectedRecoveryFloor",
        ):
            number = row[key]
            if type(number) is not int or number < 0:
                raise MatrixValidationError(
                    f"rows[{index}].{key} must be an unsigned JSON integer"
                )
        for key, expected in SYMBOLIC_REFERENCES.items():
            if row[key] != expected:
                raise MatrixValidationError(
                    f"rows[{index}].{key} must equal {expected!r}"
                )
        if cut["operation"] not in OPERATIONS or cut["tag"] not in {"before", "after"}:
            raise MatrixValidationError(
                f"rows[{index}].cut is outside the closed corpus"
            )

    if len(set(scenario_ids)) != 40:
        raise MatrixValidationError("scenarioID values must be unique")
    expected = expected_matrix()
    if matrix != expected:
        for index, (actual_row, expected_row) in enumerate(zip(rows, expected["rows"])):
            if actual_row != expected_row:
                raise MatrixValidationError(
                    f"rows[{index}] does not equal closed scenario {expected_row['scenarioID']!r}"
                )
        raise MatrixValidationError(
            "matrix does not equal the independently derived corpus"
        )


def validate_matrix(document: Any) -> None:
    """Public validator name frozen by the active convergence plan."""
    validate_matrix_document(document)


def _absolute_without_resolution(path: Path) -> Path:
    return Path(os.path.abspath(os.fspath(path)))


def _require_git_executable(argument: str) -> Path:
    path = Path(argument)
    if not path.is_absolute():
        raise MatrixValidationError("--git-executable must be absolute")
    lexical = _absolute_without_resolution(path)
    try:
        metadata = os.lstat(path)
        resolved = path.resolve(strict=True)
    except OSError as error:
        raise MatrixValidationError(
            f"--git-executable cannot be resolved: {error}"
        ) from error
    if lexical != path or resolved != path or stat.S_ISLNK(metadata.st_mode):
        raise MatrixValidationError(
            "--git-executable must be canonical and contain no symlink component"
        )
    if not stat.S_ISREG(metadata.st_mode):
        raise MatrixValidationError("--git-executable must be a regular file")
    if metadata.st_mode & 0o111 == 0 or not os.access(path, os.X_OK):
        raise MatrixValidationError("--git-executable must be executable")
    for component in (path, *path.parents):
        try:
            component_metadata = os.lstat(component)
            subject_can_write = os.access(
                component,
                os.W_OK,
                effective_ids=True,
            )
        except OSError as error:
            raise MatrixValidationError(
                f"--git-executable trust chain cannot be inspected: {error}"
            ) from error
        if (
            component_metadata.st_uid != 0
            or component_metadata.st_mode & (stat.S_IWGRP | stat.S_IWOTH)
            or subject_can_write
        ):
            raise MatrixValidationError(
                "--git-executable and every parent must be root-owned and "
                "non-writable by the current security subject"
            )
    return path


def _require_canonical_root(root_argument: str, git_executable: Path) -> Path:
    root = Path(root_argument)
    lexical = _absolute_without_resolution(root)
    try:
        resolved = root.resolve(strict=True)
    except OSError as error:
        raise MatrixValidationError(
            f"repository root cannot be resolved: {error}"
        ) from error
    if lexical != resolved:
        raise MatrixValidationError(
            "repository root must be canonical and contain no symlink component"
        )
    if not resolved.is_dir():
        raise MatrixValidationError("repository root must be a directory")
    result = _run_git(git_executable, resolved, ["rev-parse", "--show-toplevel"])
    try:
        git_root = Path(result.decode("utf-8").strip()).resolve(strict=True)
    except (OSError, UnicodeDecodeError) as error:
        raise MatrixValidationError(
            f"Git returned an invalid repository root: {error}"
        ) from error
    if git_root != resolved:
        raise MatrixValidationError("--root must name the repository worktree root")
    return resolved


def _require_exact_matrix_path(root: Path, matrix_argument: str) -> Path:
    candidate = Path(matrix_argument)
    if not candidate.is_absolute():
        candidate = root / candidate
    lexical = _absolute_without_resolution(candidate)
    try:
        resolved = candidate.resolve(strict=True)
    except OSError as error:
        raise MatrixValidationError(
            f"matrix path cannot be resolved: {error}"
        ) from error
    if lexical != resolved:
        raise MatrixValidationError(
            "matrix path must be canonical and contain no symlink component"
        )
    try:
        relative = PurePosixPath(resolved.relative_to(root).as_posix())
    except ValueError as error:
        raise MatrixValidationError(
            "matrix path must remain inside the repository"
        ) from error
    if relative != MATRIX_RELATIVE_PATH:
        raise MatrixValidationError(
            f"matrix path must be exactly {MATRIX_RELATIVE_PATH}"
        )
    return resolved


def _stable_regular_bytes(path: Path, label: str, limit: int) -> bytes:
    flags = os.O_RDONLY
    if hasattr(os, "O_CLOEXEC"):
        flags |= os.O_CLOEXEC
    if hasattr(os, "O_NOFOLLOW"):
        flags |= os.O_NOFOLLOW
    try:
        descriptor = os.open(path, flags)
    except OSError as error:
        raise MatrixValidationError(
            f"{label} cannot be opened safely: {error}"
        ) from error
    try:
        before = os.fstat(descriptor)
        if not stat.S_ISREG(before.st_mode):
            raise MatrixValidationError(f"{label} must be a regular file")
        if before.st_size < 0 or before.st_size > limit:
            raise MatrixValidationError(f"{label} exceeds the {limit}-byte bound")
        chunks: list[bytes] = []
        remaining = before.st_size
        while remaining:
            chunk = os.read(descriptor, min(remaining, 64 * 1024))
            if not chunk:
                raise MatrixValidationError(f"{label} changed during read")
            chunks.append(chunk)
            remaining -= len(chunk)
        if os.read(descriptor, 1):
            raise MatrixValidationError(f"{label} grew during read")
        after = os.fstat(descriptor)
        identity_before = (
            before.st_dev,
            before.st_ino,
            before.st_size,
            before.st_mtime_ns,
            before.st_ctime_ns,
        )
        identity_after = (
            after.st_dev,
            after.st_ino,
            after.st_size,
            after.st_mtime_ns,
            after.st_ctime_ns,
        )
        if identity_before != identity_after:
            raise MatrixValidationError(f"{label} changed during read")
        return b"".join(chunks)
    finally:
        os.close(descriptor)


def _parse_canonical_document(raw: bytes, label: str) -> Any:
    try:
        text = raw.decode("utf-8")
    except UnicodeDecodeError as error:
        raise MatrixValidationError(f"{label} is not UTF-8: {error}") from error
    try:
        document = json.loads(text, object_pairs_hook=reject_duplicate_json_keys)
    except (json.JSONDecodeError, DuplicateJSONKeyError) as error:
        raise MatrixValidationError(
            f"{label} is not valid duplicate-free JSON: {error}"
        ) from error
    if raw != canonical_json_bytes(document) + b"\n":
        raise MatrixValidationError(
            f"{label} must be canonical JSON followed by one newline"
        )
    return document


def _run_git(
    git_executable: Path,
    root: Path,
    arguments: Sequence[str],
) -> bytes:
    environment = dict(GIT_ENVIRONMENT)
    try:
        completed = subprocess.run(
            [os.fspath(git_executable), "-C", os.fspath(root), *arguments],
            stdin=subprocess.DEVNULL,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            env=environment,
            timeout=30,
            check=False,
        )
    except (OSError, subprocess.TimeoutExpired) as error:
        raise MatrixValidationError(
            f"Git command could not complete: {error}"
        ) from error
    if completed.returncode != 0:
        diagnostic = completed.stderr.decode("utf-8", errors="replace")[:1000].strip()
        raise MatrixValidationError(
            f"Git command failed: {diagnostic or completed.returncode}"
        )
    return completed.stdout


def _validate_payload_binding(
    git_executable: Path,
    root: Path,
    payload_commit: str,
    payload_tree: str,
    matrix_raw: bytes,
) -> None:
    if not OID_PATTERN.fullmatch(payload_commit):
        raise MatrixValidationError(
            "--payload-commit must be a canonical Git object ID"
        )
    if not OID_PATTERN.fullmatch(payload_tree):
        raise MatrixValidationError("--payload-tree must be a canonical Git object ID")
    actual_tree = (
        _run_git(
            git_executable,
            root,
            ["show", "-s", "--format=%T", payload_commit],
        )
        .decode("ascii", errors="strict")
        .strip()
    )
    if actual_tree != payload_tree:
        raise MatrixValidationError("payload tree does not belong to payload commit")
    if (
        _run_git(git_executable, root, ["cat-file", "-t", payload_tree]).strip()
        != b"tree"
    ):
        raise MatrixValidationError("--payload-tree does not name a Git tree")
    relative = MATRIX_RELATIVE_PATH.as_posix()
    listing = _run_git(
        git_executable,
        root,
        ["ls-tree", "-z", payload_tree, "--", relative],
    )
    records = [record for record in listing.split(b"\0") if record]
    if len(records) != 1:
        raise MatrixValidationError(
            "matrix is absent or duplicated in the payload tree"
        )
    try:
        metadata, encoded_path = records[0].split(b"\t", 1)
        mode, object_type, object_id = metadata.decode("ascii").split(" ")
        listed_path = encoded_path.decode("utf-8")
    except (UnicodeDecodeError, ValueError) as error:
        raise MatrixValidationError(
            "Git returned a malformed matrix tree row"
        ) from error
    if mode != "100644" or object_type != "blob" or listed_path != relative:
        raise MatrixValidationError(
            "matrix must be one stage-0 regular 100644 payload blob"
        )
    blob = _run_git(git_executable, root, ["cat-file", "blob", object_id])
    if blob != matrix_raw:
        raise MatrixValidationError(
            "matrix worktree bytes do not equal the payload-tree blob"
        )


def validate_matrix_file(
    root_argument: str,
    matrix_argument: str,
    payload_commit: str,
    payload_tree: str,
    git_executable_argument: str,
) -> tuple[Path, dict[str, Any], bytes]:
    git_executable = _require_git_executable(git_executable_argument)
    root = _require_canonical_root(root_argument, git_executable)
    matrix_path = _require_exact_matrix_path(root, matrix_argument)
    raw = _stable_regular_bytes(matrix_path, "matrix", MAX_MATRIX_BYTES)
    document = _parse_canonical_document(raw, "matrix")
    validate_matrix_document(document)
    _validate_payload_binding(
        git_executable,
        root,
        payload_commit,
        payload_tree,
        raw,
    )
    return root, document, raw


def _evidence_digest(domain: str, value: Any) -> str:
    return hashlib.sha256(
        domain.encode("ascii") + b"\0" + canonical_json_bytes(value)
    ).hexdigest()


def _require_digest(value: Any, label: str) -> str:
    if not isinstance(value, str) or not LOWER_HEX_64_PATTERN.fullmatch(value):
        raise MatrixValidationError(f"{label} must be lowercase 64-hex")
    return value


def _require_unsigned(value: Any, label: str, minimum: int = 0) -> int:
    if type(value) is not int or value < minimum:
        raise MatrixValidationError(f"{label} must be an integer >= {minimum}")
    return value


def _evidence_binding(document: dict[str, Any], label: str) -> dict[str, Any]:
    binding = {key: document[key] for key in COMMON_BINDING_KEYS}
    if binding["operationID"] != OPERATION_ID or binding["commandID"] != COMMAND_ID:
        raise MatrixValidationError(f"{label} is outside the frozen operation/command")
    for key in ("candidateCommitOID", "candidateTreeOID"):
        value = binding[key]
        if not isinstance(value, str) or not OID_PATTERN.fullmatch(value):
            raise MatrixValidationError(f"{label}.{key} is not a canonical Git OID")
    for key in (
        "policyRoot",
        "challengeDigest",
        "deviceProfileDigest",
        "matrixDigest",
        "custodyManifestDigest",
    ):
        _require_digest(binding[key], f"{label}.{key}")
    return binding


def _validate_trace_events(
    value: Any, chain_root: Any
) -> tuple[list[dict[str, Any]], dict[str, Any]]:
    if not isinstance(value, list) or len(value) != 40:
        raise MatrixValidationError(
            "device trace must contain exactly 40 ordered events"
        )
    keys = {
        "index",
        "scenarioID",
        "initialState",
        "cut",
        "mandatoryFaultAction",
        "faultTiming",
        "observedReopenDisposition",
        "observedStoreIdentity",
        "observedGeneration",
        "observedRecordRoot",
        "observedCASHead",
        "observedOrdinaryPutFloor",
        "observedRecoveryFloor",
        "previousEventDigest",
        "eventDigest",
    }
    previous = ZERO_DIGEST
    store_identity: Optional[str] = None
    result: list[dict[str, Any]] = []
    for index, (item, expected) in enumerate(zip(value, expected_rows())):
        event = _require_exact_keys(item, keys, f"device trace events[{index}]")
        if type(event["index"]) is not int or event["index"] != index:
            raise MatrixValidationError(
                f"device trace events[{index}] is not contiguous"
            )
        comparisons = {
            "scenarioID": expected["scenarioID"],
            "initialState": expected["initialState"],
            "cut": expected["cut"],
            "mandatoryFaultAction": expected["mandatoryFaultAction"],
            "faultTiming": expected["faultTiming"],
            "observedReopenDisposition": expected["expectedReopenDisposition"],
            "observedGeneration": expected["expectedGeneration"],
            "observedOrdinaryPutFloor": expected["expectedOrdinaryPutFloor"],
            "observedRecoveryFloor": expected["expectedRecoveryFloor"],
        }
        for key, expected_value in comparisons.items():
            if event[key] != expected_value or (
                isinstance(expected_value, int) and type(event[key]) is not int
            ):
                raise MatrixValidationError(
                    f"device trace events[{index}].{key} differs from the matrix"
                )
        identity = event["observedStoreIdentity"]
        if not isinstance(identity, str) or not LOWER_UUID_PATTERN.fullmatch(identity):
            raise MatrixValidationError(
                f"device trace events[{index}].observedStoreIdentity is invalid"
            )
        if store_identity is None:
            store_identity = identity
        elif identity != store_identity:
            raise MatrixValidationError("device trace changes store identity")
        _require_digest(
            event["observedRecordRoot"],
            f"device trace events[{index}].observedRecordRoot",
        )
        _require_digest(
            event["observedCASHead"],
            f"device trace events[{index}].observedCASHead",
        )
        if event["previousEventDigest"] != previous:
            raise MatrixValidationError(
                f"device trace events[{index}] breaks the chain"
            )
        supplied = _require_digest(
            event["eventDigest"],
            f"device trace events[{index}].eventDigest",
        )
        unsigned = dict(event)
        del unsigned["eventDigest"]
        calculated = _evidence_digest(
            "qinao.artifact-mesh.device-event.v1",
            unsigned,
        )
        if supplied != calculated:
            raise MatrixValidationError(
                f"device trace events[{index}] digest is invalid"
            )
        previous = supplied
        result.append(event)
    if chain_root != previous:
        raise MatrixValidationError("device trace eventChainRoot is invalid")
    recovery_terminal = next(
        event
        for event in result
        if event["scenarioID"] == "nofault.recoveryComplete.after"
    )
    return result, recovery_terminal


def _validate_trace_assertions(value: Any) -> list[dict[str, Any]]:
    if not isinstance(value, list) or len(value) != 9:
        raise MatrixValidationError("device trace must contain exactly nine assertions")
    keys = {
        "assertionID",
        "evidenceDigest",
        "expectedObservationCount",
        "observedObservationCount",
        "violationCount",
    }
    digests: set[str] = set()
    rows: list[dict[str, Any]] = []
    for index, (item, expected) in enumerate(zip(value, ASSERTION_COUNTS)):
        row = _require_exact_keys(item, keys, f"device trace assertions[{index}]")
        assertion_id, count = expected
        if row["assertionID"] != assertion_id:
            raise MatrixValidationError(
                f"device trace assertion {index} is out of order"
            )
        if (
            type(row["expectedObservationCount"]) is not int
            or row["expectedObservationCount"] != count
            or type(row["observedObservationCount"]) is not int
            or row["observedObservationCount"] != count
            or type(row["violationCount"]) is not int
            or row["violationCount"] != 0
        ):
            raise MatrixValidationError(f"device trace assertion {index} is incomplete")
        digest = _require_digest(
            row["evidenceDigest"],
            f"device trace assertions[{index}].evidenceDigest",
        )
        if digest in digests:
            raise MatrixValidationError(
                "device assertion evidence digests are not unique"
            )
        digests.add(digest)
        rows.append(row)
    return rows


def _validate_archive_facts(value: Any, label: str) -> dict[str, Any]:
    keys = {
        "schema",
        "archiveDigest",
        "codeIdentityRoot",
        "productManifestRoot",
        "scanManifestDigest",
        "shippingProductCount",
        "linkMapCount",
        "moduleInterfaceCount",
        "labProductCount",
        "forbiddenConditionCount",
        "forbiddenSymbolCount",
    }
    facts = _require_exact_keys(value, keys, label)
    if facts["schema"] != "QinaoArtifactMeshShippingArchiveFactsV1":
        raise MatrixValidationError(f"{label}.schema is invalid")
    for key in (
        "archiveDigest",
        "codeIdentityRoot",
        "productManifestRoot",
        "scanManifestDigest",
    ):
        _require_digest(facts[key], f"{label}.{key}")
    for key in ("shippingProductCount", "linkMapCount", "moduleInterfaceCount"):
        _require_unsigned(facts[key], f"{label}.{key}", 1)
    for key in ("labProductCount", "forbiddenConditionCount", "forbiddenSymbolCount"):
        if type(facts[key]) is not int or facts[key] != 0:
            raise MatrixValidationError(f"{label}.{key} must be zero")
    return facts


def _validate_reopen_facts(
    value: Any,
    terminal_event: dict[str, Any],
    label: str,
) -> dict[str, Any]:
    keys = {
        "schema",
        "factorySymbol",
        "storeIdentity",
        "storeLineageDigest",
        "generation",
        "recordRoot",
        "casHead",
        "ordinaryPutFloor",
        "recoveryFloor",
        "putRecordDigest",
        "reopenedRecordDigest",
        "openProcessID",
        "reopenProcessID",
        "reopenDisposition",
    }
    facts = _require_exact_keys(value, keys, label)
    if facts["schema"] != "QinaoArtifactMeshExternalReopenFactsV1":
        raise MatrixValidationError(f"{label}.schema is invalid")
    if facts["factorySymbol"] != "QinaoDefaults.makeArtifactMeshStore(configuration:)":
        raise MatrixValidationError(f"{label} did not use the production factory")
    equality = {
        "storeIdentity": "observedStoreIdentity",
        "generation": "observedGeneration",
        "recordRoot": "observedRecordRoot",
        "casHead": "observedCASHead",
        "ordinaryPutFloor": "observedOrdinaryPutFloor",
        "recoveryFloor": "observedRecoveryFloor",
    }
    for fact_key, event_key in equality.items():
        if facts[fact_key] != terminal_event[event_key]:
            raise MatrixValidationError(f"{label}.{fact_key} is terminal-misbound")
    _require_digest(facts["storeLineageDigest"], f"{label}.storeLineageDigest")
    put_digest = _require_digest(facts["putRecordDigest"], f"{label}.putRecordDigest")
    reopened = _require_digest(
        facts["reopenedRecordDigest"],
        f"{label}.reopenedRecordDigest",
    )
    if put_digest != reopened:
        raise MatrixValidationError(f"{label} put/reopen digests differ")
    first_pid = _require_unsigned(facts["openProcessID"], f"{label}.openProcessID", 1)
    second_pid = _require_unsigned(
        facts["reopenProcessID"], f"{label}.reopenProcessID", 1
    )
    if first_pid == second_pid or facts["reopenDisposition"] != "resume":
        raise MatrixValidationError(f"{label} is not a fresh-process resume")
    return facts


def _validate_device_trace(
    value: Any,
) -> tuple[dict[str, Any], dict[str, Any], dict[str, Any]]:
    keys = {
        "schema",
        "schemaVersion",
        "producer",
        *COMMON_BINDING_KEYS,
        "leaseDigest",
        "requestDigest",
        "events",
        "eventChainRoot",
        "physicalAssertions",
        "archiveAttestation",
        "externalReopenFacts",
        "terminal",
    }
    trace = _require_exact_keys(value, keys, "device trace")
    if (
        trace["schema"] != "QinaoArtifactMeshPhysicalBrokerEvidenceV1"
        or type(trace["schemaVersion"]) is not int
        or trace["schemaVersion"] != 1
        or trace["producer"] != "protectedPhysicalBroker"
    ):
        raise MatrixValidationError(
            "device trace is generic, app-authored, or wrong-version"
        )
    binding = _evidence_binding(trace, "device trace")
    lease_digest = _require_digest(trace["leaseDigest"], "device trace.leaseDigest")
    request = {
        "schema": "QinaoArtifactMeshPhysicalBrokerRequestV1",
        "schemaVersion": 1,
        **binding,
        "leaseDigest": lease_digest,
    }
    request_digest = _evidence_digest(
        "qinao.artifact-mesh.physical-broker.request.v1",
        request,
    )
    if trace["requestDigest"] != request_digest:
        raise MatrixValidationError(
            "device trace requestDigest is replayed or misbound"
        )
    _, terminal_event = _validate_trace_events(trace["events"], trace["eventChainRoot"])
    _validate_trace_assertions(trace["physicalAssertions"])
    archive = _validate_archive_facts(
        trace["archiveAttestation"], "device trace archive"
    )
    reopen = _validate_reopen_facts(
        trace["externalReopenFacts"],
        terminal_event,
        "device trace external reopen",
    )
    if trace["terminal"] != "physicalEvidenceComplete":
        raise MatrixValidationError("device trace terminal is incomplete")
    return trace, archive, reopen


def _validate_custody_proof(
    value: Any,
    binding: dict[str, Any],
    lease_digest: str,
    broker_digest: str,
    event_chain_root: str,
) -> tuple[dict[str, Any], str]:
    keys = {
        "schema",
        "schemaVersion",
        "producer",
        *COMMON_BINDING_KEYS,
        "leaseDigest",
        "brokerResponseDigest",
        "requestDigest",
        "overwriteReceiptDigest",
        "cleanupReceiptDigest",
        "keyDestructionReceiptDigest",
        "residueScanDigest",
        "encryptedRootCount",
        "overwrittenRegularFileCount",
        "cleanupDisposition",
        "keyDisposition",
        "residueFileCount",
        "residueByteCount",
        "terminal",
    }
    proof = _require_exact_keys(value, keys, "production reachability custodyProof")
    if (
        proof["schema"] != "QinaoArtifactMeshCustodyProofV1"
        or type(proof["schemaVersion"]) is not int
        or proof["schemaVersion"] != 1
        or proof["producer"] != "encryptedCustodyBroker"
    ):
        raise MatrixValidationError(
            "custody proof is generic, app-authored, or wrong-version"
        )
    if _evidence_binding(proof, "custody proof") != binding:
        raise MatrixValidationError("custody proof is replayed across bindings")
    request = {
        "schema": "QinaoArtifactMeshCustodyCleanupRequestV1",
        "schemaVersion": 1,
        **binding,
        "leaseDigest": lease_digest,
        "brokerResponseDigest": broker_digest,
        "eventChainRoot": event_chain_root,
    }
    request_digest = _evidence_digest(
        "qinao.artifact-mesh.custody.request.v1",
        request,
    )
    if (
        proof["leaseDigest"] != lease_digest
        or proof["brokerResponseDigest"] != broker_digest
        or proof["requestDigest"] != request_digest
    ):
        raise MatrixValidationError("custody proof is request-misbound or replayed")
    receipt_digests = [
        _require_digest(proof[key], f"custody proof.{key}")
        for key in (
            "overwriteReceiptDigest",
            "cleanupReceiptDigest",
            "keyDestructionReceiptDigest",
            "residueScanDigest",
        )
    ]
    if len(set(receipt_digests)) != 4:
        raise MatrixValidationError("custody receipt digests are not distinct")
    _require_unsigned(
        proof["encryptedRootCount"], "custody proof.encryptedRootCount", 1
    )
    _require_unsigned(
        proof["overwrittenRegularFileCount"],
        "custody proof.overwrittenRegularFileCount",
        1,
    )
    if (
        proof["cleanupDisposition"] != "removed"
        or proof["keyDisposition"] != "destroyed"
    ):
        raise MatrixValidationError("custody cleanup/key destruction is incomplete")
    if (
        type(proof["residueFileCount"]) is not int
        or proof["residueFileCount"] != 0
        or type(proof["residueByteCount"]) is not int
        or proof["residueByteCount"] != 0
    ):
        raise MatrixValidationError("custody proof contains residue")
    if proof["terminal"] != "custodyClosed":
        raise MatrixValidationError("custody proof terminal is incomplete")
    proof_digest = _evidence_digest(
        "qinao.artifact-mesh.custody.proof.v1",
        proof,
    )
    return proof, proof_digest


def _validate_evidence_surface(
    root: Path,
    values: Sequence[str],
    payload_commit: str,
    payload_tree: str,
    verified_matrix_raw: bytes,
) -> dict[str, Any]:
    documents: list[Any] = []
    for index, value in enumerate(values):
        path = Path(value)
        if not path.is_absolute():
            raise MatrixValidationError("device evidence paths must be absolute")
        lexical = _absolute_without_resolution(path)
        try:
            resolved = path.resolve(strict=True)
        except OSError as error:
            raise MatrixValidationError(
                f"device evidence path cannot be resolved: {error}"
            ) from error
        if lexical != resolved:
            raise MatrixValidationError(
                "device evidence paths must be canonical and symlink-free"
            )
        try:
            resolved.relative_to(root)
        except ValueError:
            pass
        else:
            raise MatrixValidationError(
                "device evidence must remain outside the repository"
            )
        raw = _stable_regular_bytes(
            resolved, f"device evidence {index}", MAX_EVIDENCE_BYTES
        )
        documents.append(_parse_canonical_document(raw, f"device evidence {index}"))

    trace, nested_archive, nested_reopen = _validate_device_trace(documents[0])
    binding = _evidence_binding(trace, "device trace")
    if (
        binding["candidateCommitOID"] != payload_commit
        or binding["candidateTreeOID"] != payload_tree
        or binding["matrixDigest"] != hashlib.sha256(verified_matrix_raw).hexdigest()
    ):
        raise MatrixValidationError("device trace is not bound to the candidate matrix")
    lease_digest = trace["leaseDigest"]
    broker_digest = _evidence_digest(
        "qinao.artifact-mesh.physical-broker.evidence.v1",
        trace,
    )

    wrapper_keys = {
        "schema",
        "schemaVersion",
        *COMMON_BINDING_KEYS,
        "leaseDigest",
        "brokerResponseDigest",
    }
    archive = _require_exact_keys(
        documents[1],
        wrapper_keys | {"attestation"},
        "archive attestation",
    )
    if (
        archive["schema"] != "QinaoArtifactMeshArchiveAttestationV1"
        or type(archive["schemaVersion"]) is not int
        or archive["schemaVersion"] != 1
        or _evidence_binding(archive, "archive attestation") != binding
        or archive["leaseDigest"] != lease_digest
        or archive["brokerResponseDigest"] != broker_digest
        or archive["attestation"] != nested_archive
    ):
        raise MatrixValidationError("archive attestation is replayed or trace-misbound")
    _validate_archive_facts(archive["attestation"], "archive attestation facts")

    reopen = _require_exact_keys(
        documents[2],
        wrapper_keys | {"facts"},
        "external reopen receipt",
    )
    if (
        reopen["schema"] != "QinaoArtifactMeshExternalReopenReceiptV1"
        or type(reopen["schemaVersion"]) is not int
        or reopen["schemaVersion"] != 1
        or _evidence_binding(reopen, "external reopen receipt") != binding
        or reopen["leaseDigest"] != lease_digest
        or reopen["brokerResponseDigest"] != broker_digest
        or reopen["facts"] != nested_reopen
    ):
        raise MatrixValidationError(
            "external reopen receipt is replayed or trace-misbound"
        )

    archive_digest = _evidence_digest(
        "qinao.artifact-mesh.archive-attestation.v1",
        archive,
    )
    reopen_digest = _evidence_digest(
        "qinao.artifact-mesh.external-reopen-receipt.v1",
        reopen,
    )
    reach_keys = {
        "schema",
        "schemaVersion",
        "authority",
        *COMMON_BINDING_KEYS,
        "leaseDigest",
        "brokerResponseDigest",
        "archiveAttestationDigest",
        "externalReopenReceiptDigest",
        "custodyProofDigest",
        "evidenceRoot",
        "custodyProof",
        "terminal",
    }
    reach = _require_exact_keys(documents[3], reach_keys, "production reachability")
    if (
        reach["schema"] != "QinaoArtifactMeshProductionReachabilityV1"
        or type(reach["schemaVersion"]) is not int
        or reach["schemaVersion"] != 1
        or reach["authority"] != "runnerAuthenticated"
        or _evidence_binding(reach, "production reachability") != binding
        or reach["leaseDigest"] != lease_digest
        or reach["brokerResponseDigest"] != broker_digest
        or reach["archiveAttestationDigest"] != archive_digest
        or reach["externalReopenReceiptDigest"] != reopen_digest
    ):
        raise MatrixValidationError("production reachability is replayed or misbound")
    _, custody_proof_digest = _validate_custody_proof(
        reach["custodyProof"],
        binding,
        lease_digest,
        broker_digest,
        trace["eventChainRoot"],
    )
    if reach["custodyProofDigest"] != custody_proof_digest:
        raise MatrixValidationError("production reachability custody digest is invalid")
    evidence_root = _evidence_digest(
        "qinao.artifact-mesh.device-recovery.terminal.v1",
        {
            "leaseDigest": lease_digest,
            "brokerResponseDigest": broker_digest,
            "custodyProofDigest": custody_proof_digest,
        },
    )
    if reach["evidenceRoot"] != evidence_root:
        raise MatrixValidationError("production reachability evidenceRoot is invalid")
    if reach["terminal"] != "validatedPhysicalRecovery":
        raise MatrixValidationError("production reachability terminal is incomplete")
    return {
        "rows": 40,
        "assertions": 9,
        "evidenceRoot": evidence_root,
    }


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--git-executable", required=True)
    parser.add_argument("--root", required=True)
    parser.add_argument("--matrix", required=True)
    parser.add_argument("--payload-commit", required=True)
    parser.add_argument("--payload-tree", required=True)
    parser.add_argument("--device-trace")
    parser.add_argument("--archive-attestation")
    parser.add_argument("--external-reopen-receipt")
    parser.add_argument("--production-reachability")
    return parser


def _require_closed_cli(values: Sequence[str]) -> None:
    required = (
        "--git-executable",
        "--root",
        "--matrix",
        "--payload-commit",
        "--payload-tree",
    )
    optional = (
        "--device-trace",
        "--archive-attestation",
        "--external-reopen-receipt",
        "--production-reachability",
    )
    option_tokens = [value for value in values if value.startswith("--")]
    if any("=" in value for value in option_tokens):
        raise MatrixValidationError("CLI options require separate values")
    allowed = set(required) | set(optional)
    unknown = sorted(set(option_tokens) - allowed)
    if unknown:
        raise MatrixValidationError(f"unknown CLI options: {unknown!r}")
    for option in required:
        if option_tokens.count(option) != 1:
            raise MatrixValidationError(f"{option} must occur exactly once")
    for option in optional:
        if option_tokens.count(option) > 1:
            raise MatrixValidationError(f"{option} may occur at most once")


def main(argv: Optional[Sequence[str]] = None) -> int:
    values = list(sys.argv[1:] if argv is None else argv)
    try:
        _require_closed_cli(values)
    except MatrixValidationError as error:
        print(f"artifact-mesh-device-recovery: ERROR {error}", file=sys.stderr)
        return 2
    arguments = build_parser().parse_args(values)
    evidence = (
        arguments.device_trace,
        arguments.archive_attestation,
        arguments.external_reopen_receipt,
        arguments.production_reachability,
    )
    present = [value is not None for value in evidence]
    if any(present) and not all(present):
        print(
            "artifact-mesh-device-recovery: ERROR all four device evidence options are mandatory",
            file=sys.stderr,
        )
        return 2
    device_summary: Optional[dict[str, Any]] = None
    try:
        root, _, verified_matrix_raw = validate_matrix_file(
            arguments.root,
            arguments.matrix,
            arguments.payload_commit,
            arguments.payload_tree,
            arguments.git_executable,
        )
        if all(present):
            device_summary = _validate_evidence_surface(
                root,
                [value for value in evidence if value is not None],
                arguments.payload_commit,
                arguments.payload_tree,
                verified_matrix_raw,
            )
    except MatrixValidationError as error:
        print(f"artifact-mesh-device-recovery: ERROR {error}", file=sys.stderr)
        return 1
    if device_summary is None:
        print(
            "artifact-mesh-device-recovery: PASS mode=matrix "
            "rows=40 no_fault=26 faults=14"
        )
    else:
        print(
            "artifact-mesh-device-recovery: PASS mode=device "
            f"rows={device_summary['rows']} "
            f"assertions={device_summary['assertions']} "
            f"evidence_root={device_summary['evidenceRoot']}"
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
