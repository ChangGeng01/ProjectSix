#!/usr/bin/env python3
"""Fail-closed Artifact-Mesh physical-recovery controller boundary.

The candidate-preflight surface validates the immutable payload and emits only
an explicitly non-authoritative blocked disposition.  The production surface
accepts only three inherited capability descriptors and speaks one closed,
versioned, length-prefixed canonical-JSON protocol with the protected runner,
physical broker, and encrypted-custody broker.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import socket
import stat
import subprocess
import sys
import time
import unicodedata
from pathlib import Path, PurePosixPath
from typing import Any, Optional, Sequence


# This corpus is intentionally repeated rather than imported from the checker.
# The generator and checker must be capable of disagreeing when either drifts.
MATRIX_RELATIVE_PATH = PurePosixPath(
    "docs/superpowers/specs/qinao-artifact-mesh-device-recovery-matrix-v1.json"
)
MATRIX_ID = "qinao-artifact-mesh-device-recovery-matrix-v1"
GENERATOR_OPERATIONS = (
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
GENERATOR_NO_FAULT = {
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
GENERATOR_FAULTS = (
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
GENERATOR_OUTER_KEYS = {"schema_version", "matrix_id", "operations", "rows"}
GENERATOR_ROW_KEYS = {
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
OID_PATTERN = re.compile(r"(?:[0-9a-f]{40}|[0-9a-f]{64})\Z")
DEVICE_PATTERN = re.compile(r"[A-Za-z0-9][A-Za-z0-9-]{0,127}\Z")
TEAM_PATTERN = re.compile(r"[A-Z0-9]{10}\Z")
LOWER_HEX_64_PATTERN = re.compile(r"[0-9a-f]{64}\Z")
LOWER_UUID_PATTERN = re.compile(
    r"[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\Z"
)
DISPOSITION_NAME = "preflight-disposition-v1.json"
PROTOCOL_VERSION = 1
PROTOCOL_HEADER_BYTES = 8
MAX_PROTOCOL_FRAME_BYTES = 64 * 1024 * 1024
PROTOCOL_TIMEOUT_SECONDS = 30.0
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


class ArtifactMeshDeviceRecoveryRunnerError(ValueError):
    """The controller boundary or candidate preflight is invalid."""


class _DuplicateKey(ArtifactMeshDeviceRecoveryRunnerError):
    pass


def _reject_duplicates(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            raise _DuplicateKey(f"duplicate JSON key: {key!r}")
        result[key] = value
    return result


def _canonical_json(value: Any) -> bytes:
    try:
        return json.dumps(
            value,
            allow_nan=False,
            ensure_ascii=False,
            separators=(",", ":"),
            sort_keys=True,
        ).encode("utf-8")
    except (TypeError, ValueError) as error:
        raise ArtifactMeshDeviceRecoveryRunnerError(
            f"value is not canonical JSON: {error}"
        ) from error


def _generator_row(
    scenario_id: str,
    initial: str,
    cut_tag: str,
    operation: str,
    action: str,
    timing: str,
    terminal: str,
    generation: int,
    put_floor: int,
    recovery_floor: int,
) -> dict[str, Any]:
    return {
        "scenarioID": scenario_id,
        "initialState": initial,
        "cut": {"operation": operation, "tag": cut_tag},
        "mandatoryFaultAction": action,
        "faultTiming": timing,
        "expectedReopenDisposition": terminal,
        "expectedStoreIdentity": "$derived.storeIdentity",
        "expectedGeneration": generation,
        "expectedRecordRoot": "$derived.recordRoot",
        "expectedCASHead": "$derived.casHead",
        "expectedOrdinaryPutFloor": put_floor,
        "expectedRecoveryFloor": recovery_floor,
    }


def generator_expected_matrix() -> dict[str, Any]:
    rows: list[dict[str, Any]] = []
    for operation in GENERATOR_OPERATIONS:
        for cut_tag in ("before", "after"):
            initial, terminal, generation, put_floor, recovery_floor = (
                GENERATOR_NO_FAULT[operation][cut_tag]
            )
            rows.append(
                _generator_row(
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
    for case in GENERATOR_FAULTS:
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
            _generator_row(
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
        raise AssertionError("closed generator corpus is not 40 rows")
    return {
        "schema_version": 1,
        "matrix_id": MATRIX_ID,
        "operations": list(GENERATOR_OPERATIONS),
        "rows": rows,
    }


def _require_git_executable(argument: str) -> Path:
    path = Path(argument)
    if not path.is_absolute():
        raise ArtifactMeshDeviceRecoveryRunnerError("--git-executable must be absolute")
    lexical = Path(os.path.abspath(os.fspath(path)))
    try:
        metadata = os.lstat(path)
        resolved = path.resolve(strict=True)
    except OSError as error:
        raise ArtifactMeshDeviceRecoveryRunnerError(
            f"--git-executable cannot be resolved: {error}"
        ) from error
    if lexical != path or resolved != path or stat.S_ISLNK(metadata.st_mode):
        raise ArtifactMeshDeviceRecoveryRunnerError(
            "--git-executable must be canonical and contain no symlink component"
        )
    if not stat.S_ISREG(metadata.st_mode):
        raise ArtifactMeshDeviceRecoveryRunnerError(
            "--git-executable must be a regular file"
        )
    if metadata.st_mode & 0o111 == 0 or not os.access(path, os.X_OK):
        raise ArtifactMeshDeviceRecoveryRunnerError(
            "--git-executable must be executable"
        )
    for component in (path, *path.parents):
        try:
            component_metadata = os.lstat(component)
            subject_can_write = os.access(
                component,
                os.W_OK,
                effective_ids=True,
            )
        except OSError as error:
            raise ArtifactMeshDeviceRecoveryRunnerError(
                f"--git-executable trust chain cannot be inspected: {error}"
            ) from error
        if (
            component_metadata.st_uid != 0
            or component_metadata.st_mode & (stat.S_IWGRP | stat.S_IWOTH)
            or subject_can_write
        ):
            raise ArtifactMeshDeviceRecoveryRunnerError(
                "--git-executable and every parent must be root-owned and "
                "non-writable by the current security subject"
            )
    return path


def _run_git(
    git_executable: Path,
    root: Path,
    arguments: Sequence[str],
) -> bytes:
    try:
        completed = subprocess.run(
            [os.fspath(git_executable), "-C", os.fspath(root), *arguments],
            stdin=subprocess.DEVNULL,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            env=dict(GIT_ENVIRONMENT),
            timeout=30,
            check=False,
        )
    except (OSError, subprocess.TimeoutExpired) as error:
        raise ArtifactMeshDeviceRecoveryRunnerError(
            f"Git command could not complete: {error}"
        ) from error
    if completed.returncode != 0:
        diagnostic = completed.stderr.decode("utf-8", errors="replace")[:1000].strip()
        raise ArtifactMeshDeviceRecoveryRunnerError(
            f"Git command failed: {diagnostic or completed.returncode}"
        )
    return completed.stdout


def _canonical_root(argument: str, git_executable: Path) -> Path:
    path = Path(argument)
    lexical = Path(os.path.abspath(os.fspath(path)))
    try:
        resolved = path.resolve(strict=True)
    except OSError as error:
        raise ArtifactMeshDeviceRecoveryRunnerError(
            f"repository root cannot be resolved: {error}"
        ) from error
    if lexical != resolved or not resolved.is_dir():
        raise ArtifactMeshDeviceRecoveryRunnerError(
            "repository root must be a canonical symlink-free directory"
        )
    top = _run_git(git_executable, resolved, ["rev-parse", "--show-toplevel"])
    try:
        git_root = Path(top.decode("utf-8").strip()).resolve(strict=True)
    except (OSError, UnicodeDecodeError) as error:
        raise ArtifactMeshDeviceRecoveryRunnerError(
            f"Git returned an invalid worktree root: {error}"
        ) from error
    if git_root != resolved:
        raise ArtifactMeshDeviceRecoveryRunnerError(
            "--root must name the repository worktree root"
        )
    return resolved


def _stable_file(path: Path, label: str, limit: int = 2 * 1024 * 1024) -> bytes:
    flags = os.O_RDONLY | getattr(os, "O_CLOEXEC", 0) | getattr(os, "O_NOFOLLOW", 0)
    try:
        descriptor = os.open(path, flags)
    except OSError as error:
        raise ArtifactMeshDeviceRecoveryRunnerError(
            f"{label} cannot be opened safely: {error}"
        ) from error
    try:
        before = os.fstat(descriptor)
        if (
            not stat.S_ISREG(before.st_mode)
            or before.st_size < 0
            or before.st_size > limit
        ):
            raise ArtifactMeshDeviceRecoveryRunnerError(
                f"{label} must be a bounded regular file"
            )
        chunks: list[bytes] = []
        remaining = before.st_size
        while remaining:
            chunk = os.read(descriptor, min(remaining, 64 * 1024))
            if not chunk:
                raise ArtifactMeshDeviceRecoveryRunnerError(
                    f"{label} changed during read"
                )
            chunks.append(chunk)
            remaining -= len(chunk)
        if os.read(descriptor, 1):
            raise ArtifactMeshDeviceRecoveryRunnerError(f"{label} grew during read")
        after = os.fstat(descriptor)
        before_identity = (
            before.st_dev,
            before.st_ino,
            before.st_size,
            before.st_mtime_ns,
            before.st_ctime_ns,
        )
        after_identity = (
            after.st_dev,
            after.st_ino,
            after.st_size,
            after.st_mtime_ns,
            after.st_ctime_ns,
        )
        if before_identity != after_identity:
            raise ArtifactMeshDeviceRecoveryRunnerError(f"{label} changed during read")
        return b"".join(chunks)
    finally:
        os.close(descriptor)


def _validate_candidate_matrix(
    git_executable: Path,
    root: Path,
    matrix_argument: str,
    payload_commit: str,
    payload_tree: str,
) -> bytes:
    path = Path(matrix_argument)
    if not path.is_absolute():
        path = root / path
    lexical = Path(os.path.abspath(os.fspath(path)))
    try:
        resolved = path.resolve(strict=True)
    except OSError as error:
        raise ArtifactMeshDeviceRecoveryRunnerError(
            f"matrix path cannot be resolved: {error}"
        ) from error
    if lexical != resolved:
        raise ArtifactMeshDeviceRecoveryRunnerError(
            "matrix path must be canonical and symlink-free"
        )
    try:
        relative = PurePosixPath(resolved.relative_to(root).as_posix())
    except ValueError as error:
        raise ArtifactMeshDeviceRecoveryRunnerError(
            "matrix path must remain inside the repository"
        ) from error
    if relative != MATRIX_RELATIVE_PATH:
        raise ArtifactMeshDeviceRecoveryRunnerError(
            f"matrix path must be exactly {MATRIX_RELATIVE_PATH}"
        )
    raw = _stable_file(resolved, "matrix")
    try:
        document = json.loads(raw.decode("utf-8"), object_pairs_hook=_reject_duplicates)
    except (UnicodeDecodeError, json.JSONDecodeError, _DuplicateKey) as error:
        raise ArtifactMeshDeviceRecoveryRunnerError(
            f"matrix is not duplicate-free UTF-8 JSON: {error}"
        ) from error
    if raw != _canonical_json(document) + b"\n":
        raise ArtifactMeshDeviceRecoveryRunnerError(
            "matrix must be canonical JSON followed by one newline"
        )
    if not isinstance(document, dict) or set(document) != GENERATOR_OUTER_KEYS:
        raise ArtifactMeshDeviceRecoveryRunnerError(
            "matrix outer key set is not closed"
        )
    rows = document.get("rows")
    if not isinstance(rows, list) or len(rows) != 40:
        raise ArtifactMeshDeviceRecoveryRunnerError(
            "matrix must contain exactly 40 rows"
        )
    for index, row in enumerate(rows):
        if not isinstance(row, dict) or set(row) != GENERATOR_ROW_KEYS:
            raise ArtifactMeshDeviceRecoveryRunnerError(
                f"matrix row {index} has an invalid key set"
            )
        for key in (
            "expectedGeneration",
            "expectedOrdinaryPutFloor",
            "expectedRecoveryFloor",
        ):
            if type(row[key]) is not int or row[key] < 0:
                raise ArtifactMeshDeviceRecoveryRunnerError(
                    f"matrix row {index} has a non-unsigned {key}"
                )
        scenario_id = row["scenarioID"]
        if (
            not isinstance(scenario_id, str)
            or unicodedata.normalize("NFC", scenario_id) != scenario_id
        ):
            raise ArtifactMeshDeviceRecoveryRunnerError(
                f"matrix row {index} has a non-NFC scenarioID"
            )
    if document != generator_expected_matrix():
        raise ArtifactMeshDeviceRecoveryRunnerError(
            "matrix differs from the controller generator's independent corpus"
        )
    if not OID_PATTERN.fullmatch(payload_commit) or not OID_PATTERN.fullmatch(
        payload_tree
    ):
        raise ArtifactMeshDeviceRecoveryRunnerError(
            "payload commit/tree must be canonical Git object IDs"
        )
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
        raise ArtifactMeshDeviceRecoveryRunnerError(
            "payload tree does not belong to payload commit"
        )
    listing = _run_git(
        git_executable,
        root,
        ["ls-tree", "-z", payload_tree, "--", MATRIX_RELATIVE_PATH.as_posix()],
    )
    records = [record for record in listing.split(b"\0") if record]
    if len(records) != 1:
        raise ArtifactMeshDeviceRecoveryRunnerError(
            "matrix is absent or duplicated in the payload tree"
        )
    try:
        metadata, encoded_path = records[0].split(b"\t", 1)
        mode, object_type, object_id = metadata.decode("ascii").split(" ")
        listed_path = encoded_path.decode("utf-8")
    except (UnicodeDecodeError, ValueError) as error:
        raise ArtifactMeshDeviceRecoveryRunnerError(
            "Git returned a malformed matrix row"
        ) from error
    if (
        mode != "100644"
        or object_type != "blob"
        or listed_path != MATRIX_RELATIVE_PATH.as_posix()
    ):
        raise ArtifactMeshDeviceRecoveryRunnerError(
            "matrix must be one regular 100644 payload blob"
        )
    if _run_git(git_executable, root, ["cat-file", "blob", object_id]) != raw:
        raise ArtifactMeshDeviceRecoveryRunnerError(
            "matrix worktree bytes do not equal the payload blob"
        )
    return raw


def _validate_output_directory(
    git_executable: Path,
    root: Path,
    argument: str,
) -> tuple[Path, tuple[int, int]]:
    path = Path(argument)
    if not path.is_absolute():
        raise ArtifactMeshDeviceRecoveryRunnerError(
            "--output-directory must be absolute"
        )
    lexical = Path(os.path.abspath(os.fspath(path)))
    try:
        resolved = path.resolve(strict=True)
    except OSError as error:
        raise ArtifactMeshDeviceRecoveryRunnerError(
            f"output directory cannot be resolved: {error}"
        ) from error
    if lexical != resolved or not resolved.is_dir():
        raise ArtifactMeshDeviceRecoveryRunnerError(
            "output directory must be canonical, symlink-free, and pre-existing"
        )
    try:
        resolved.relative_to(root)
    except ValueError:
        pass
    else:
        raise ArtifactMeshDeviceRecoveryRunnerError(
            "output directory must remain outside the repository"
        )
    common = _run_git(
        git_executable,
        root,
        ["rev-parse", "--path-format=absolute", "--git-common-dir"],
    )
    common_path = Path(common.decode("utf-8").strip()).resolve(strict=True)
    try:
        resolved.relative_to(common_path)
    except ValueError:
        pass
    else:
        raise ArtifactMeshDeviceRecoveryRunnerError(
            "output directory must remain outside the common Git directory"
        )
    metadata = resolved.stat()
    if not stat.S_ISDIR(metadata.st_mode) or metadata.st_nlink < 1:
        raise ArtifactMeshDeviceRecoveryRunnerError("output directory is unstable")
    return resolved, (metadata.st_dev, metadata.st_ino)


def _write_blocked_disposition(
    output_directory: Path,
    expected_directory_identity: tuple[int, int],
    payload_commit: str,
    payload_tree: str,
    matrix_raw: bytes,
    device: str,
    development_team: str,
) -> None:
    disposition = {
        "schema_version": 1,
        "kind": "artifact-mesh-device-recovery-preflight-disposition-v1",
        "authority": "none",
        "disposition": "blockedPhysicalBrokerRequired",
        "payload_commit_oid": payload_commit,
        "payload_tree_oid": payload_tree,
        "matrix_sha256": hashlib.sha256(matrix_raw).hexdigest(),
        "matrix_rows_validated": 40,
        "physical_rows_executed": 0,
        "device_selector_digest": hashlib.sha256(device.encode("utf-8")).hexdigest(),
        "development_team_digest": hashlib.sha256(
            development_team.encode("utf-8")
        ).hexdigest(),
    }
    raw = _canonical_json(disposition) + b"\n"
    try:
        directory_fd = os.open(
            output_directory,
            os.O_RDONLY
            | getattr(os, "O_DIRECTORY", 0)
            | getattr(os, "O_CLOEXEC", 0)
            | getattr(os, "O_NOFOLLOW", 0),
        )
    except OSError as error:
        raise ArtifactMeshDeviceRecoveryRunnerError(
            f"output directory cannot be opened as a stable capability: {error}"
        ) from error
    descriptor = -1
    try:
        opened_directory = os.fstat(directory_fd)
        if (
            not stat.S_ISDIR(opened_directory.st_mode)
            or (opened_directory.st_dev, opened_directory.st_ino)
            != expected_directory_identity
        ):
            raise ArtifactMeshDeviceRecoveryRunnerError(
                "output directory identity changed before disposition creation"
            )
        flags = os.O_WRONLY | os.O_CREAT | os.O_EXCL | getattr(os, "O_CLOEXEC", 0)
        flags |= getattr(os, "O_NOFOLLOW", 0)
        descriptor = os.open(DISPOSITION_NAME, flags, 0o600, dir_fd=directory_fd)
        view = memoryview(raw)
        while view:
            written = os.write(descriptor, view)
            if written <= 0:
                raise ArtifactMeshDeviceRecoveryRunnerError(
                    "preflight disposition write made no progress"
                )
            view = view[written:]
        os.fsync(descriptor)
        os.fsync(directory_fd)
    except OSError as error:
        raise ArtifactMeshDeviceRecoveryRunnerError(
            f"preflight disposition cannot be written safely: {error}"
        ) from error
    finally:
        if descriptor >= 0:
            os.close(descriptor)
        os.close(directory_fd)


def _candidate_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--mode", required=True, choices=("candidate-preflight",))
    parser.add_argument("--git-executable", required=True)
    parser.add_argument("--root", required=True)
    parser.add_argument("--matrix", required=True)
    parser.add_argument("--payload-commit", required=True)
    parser.add_argument("--payload-tree", required=True)
    parser.add_argument("--device", required=True)
    parser.add_argument("--development-team", required=True)
    parser.add_argument("--output-directory", required=True)
    return parser


def _production_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--mode", required=True, choices=("production",))
    parser.add_argument("--lease-fd", required=True, type=int)
    parser.add_argument("--physical-broker-fd", required=True, type=int)
    parser.add_argument("--custody-fd", required=True, type=int)
    return parser


def _dispatch_parser(argv: Sequence[str]) -> argparse.Namespace:
    option_tokens = [value for value in argv if value.startswith("--")]
    if any("=" in value for value in option_tokens):
        raise ArtifactMeshDeviceRecoveryRunnerError(
            "controller options require separate values"
        )
    if option_tokens.count("--mode") != 1:
        raise ArtifactMeshDeviceRecoveryRunnerError(
            "exactly one separate --mode argument is required"
        )
    index = list(argv).index("--mode")
    if index + 1 >= len(argv):
        raise ArtifactMeshDeviceRecoveryRunnerError("--mode requires a value")
    mode = argv[index + 1]
    if mode == "candidate-preflight":
        expected = {
            "--mode",
            "--git-executable",
            "--root",
            "--matrix",
            "--payload-commit",
            "--payload-tree",
            "--device",
            "--development-team",
            "--output-directory",
        }
        if set(option_tokens) - expected or any(
            option_tokens.count(option) != 1 for option in expected
        ):
            raise ArtifactMeshDeviceRecoveryRunnerError(
                "candidate-preflight requires each exact option once"
            )
        return _candidate_parser().parse_args(argv)
    if mode == "production":
        expected = {
            "--mode",
            "--lease-fd",
            "--physical-broker-fd",
            "--custody-fd",
        }
        if set(option_tokens) - expected or any(
            option_tokens.count(option) != 1 for option in expected
        ):
            raise ArtifactMeshDeviceRecoveryRunnerError(
                "production requires each exact capability option once"
            )
        return _production_parser().parse_args(argv)
    raise ArtifactMeshDeviceRecoveryRunnerError(
        "--mode must be candidate-preflight or production"
    )


def run_candidate_preflight(arguments: argparse.Namespace) -> int:
    if not DEVICE_PATTERN.fullmatch(arguments.device):
        raise ArtifactMeshDeviceRecoveryRunnerError("--device is not a closed selector")
    if not TEAM_PATTERN.fullmatch(arguments.development_team):
        raise ArtifactMeshDeviceRecoveryRunnerError(
            "--development-team must be exactly ten uppercase alphanumeric characters"
        )
    git_executable = _require_git_executable(arguments.git_executable)
    root = _canonical_root(arguments.root, git_executable)
    matrix_raw = _validate_candidate_matrix(
        git_executable,
        root,
        arguments.matrix,
        arguments.payload_commit,
        arguments.payload_tree,
    )
    output_directory, output_directory_identity = _validate_output_directory(
        git_executable,
        root,
        arguments.output_directory,
    )
    _write_blocked_disposition(
        output_directory,
        output_directory_identity,
        arguments.payload_commit,
        arguments.payload_tree,
        matrix_raw,
        arguments.device,
        arguments.development_team,
    )
    print(
        "BLOCKED_ARTIFACT_MESH_DEVICE_RECOVERY "
        "reason=PHYSICAL_BROKER_REQUIRED mode=candidate-preflight "
        "rows_validated=40 rows_executed=0",
        file=sys.stderr,
    )
    return 22


def _require_capability_socket(descriptor: int, expected: int, label: str) -> None:
    if descriptor != expected:
        raise ArtifactMeshDeviceRecoveryRunnerError(
            f"{label} must be inherited on descriptor {expected}"
        )
    try:
        metadata = os.fstat(descriptor)
    except OSError as error:
        raise ArtifactMeshDeviceRecoveryRunnerError(
            f"{label} is not an open inherited capability: {error}"
        ) from error
    if not stat.S_ISSOCK(metadata.st_mode):
        raise ArtifactMeshDeviceRecoveryRunnerError(
            f"{label} must be a non-path socket capability"
        )
    duplicate = -1
    try:
        duplicate = os.dup(descriptor)
        capability = socket.socket(fileno=duplicate)
        duplicate = -1
        try:
            if (
                capability.getsockopt(socket.SOL_SOCKET, socket.SO_TYPE)
                != socket.SOCK_STREAM
            ):
                raise ArtifactMeshDeviceRecoveryRunnerError(
                    f"{label} must be a stream capability"
                )
            capability.getpeername()
        finally:
            capability.close()
    except OSError as error:
        raise ArtifactMeshDeviceRecoveryRunnerError(
            f"{label} is not a connected socket capability: {error}"
        ) from error
    finally:
        if duplicate >= 0:
            os.close(duplicate)


def _protocol_digest(domain: str, value: Any) -> str:
    return hashlib.sha256(
        domain.encode("ascii") + b"\0" + _canonical_json(value)
    ).hexdigest()


def _require_exact_object(
    value: Any,
    expected_keys: set[str],
    label: str,
) -> dict[str, Any]:
    if not isinstance(value, dict):
        raise ArtifactMeshDeviceRecoveryRunnerError(f"{label} must be a JSON object")
    actual = set(value)
    if actual != expected_keys:
        raise ArtifactMeshDeviceRecoveryRunnerError(
            f"{label} key set mismatch: "
            f"missing={sorted(expected_keys - actual)!r} "
            f"extra={sorted(actual - expected_keys)!r}"
        )
    return value


def _require_digest(value: Any, label: str) -> str:
    if not isinstance(value, str) or not LOWER_HEX_64_PATTERN.fullmatch(value):
        raise ArtifactMeshDeviceRecoveryRunnerError(f"{label} must be lowercase 64-hex")
    return value


def _require_unsigned(value: Any, label: str, minimum: int = 0) -> int:
    if type(value) is not int or value < minimum:
        raise ArtifactMeshDeviceRecoveryRunnerError(
            f"{label} must be an integer >= {minimum}"
        )
    return value


def _remaining_protocol_time(deadline: float, label: str) -> float:
    remaining = deadline - time.monotonic()
    if remaining <= 0.0:
        raise ArtifactMeshDeviceRecoveryRunnerError(f"{label} frame deadline exceeded")
    return remaining


def _receive_exact(
    capability: socket.socket,
    count: int,
    label: str,
    deadline: float,
) -> bytes:
    chunks: list[bytes] = []
    remaining = count
    while remaining:
        try:
            capability.settimeout(_remaining_protocol_time(deadline, label))
            chunk = capability.recv(remaining)
        except socket.timeout as error:
            raise ArtifactMeshDeviceRecoveryRunnerError(
                f"{label} frame deadline exceeded"
            ) from error
        except OSError as error:
            raise ArtifactMeshDeviceRecoveryRunnerError(
                f"{label} frame could not be received: {error}"
            ) from error
        if not chunk:
            raise ArtifactMeshDeviceRecoveryRunnerError(
                f"{label} capability closed with {remaining} frame bytes missing"
            )
        chunks.append(chunk)
        remaining -= len(chunk)
    return b"".join(chunks)


def _receive_protocol_frame(
    capability: socket.socket,
    label: str,
    deadline: float,
) -> Any:
    header = _receive_exact(capability, PROTOCOL_HEADER_BYTES, label, deadline)
    length = int.from_bytes(header, byteorder="big", signed=False)
    if length == 0 or length > MAX_PROTOCOL_FRAME_BYTES:
        raise ArtifactMeshDeviceRecoveryRunnerError(
            f"{label} frame length is outside the closed bound"
        )
    raw = _receive_exact(capability, length, label, deadline)
    try:
        text = raw.decode("utf-8")
        document = json.loads(text, object_pairs_hook=_reject_duplicates)
    except (UnicodeDecodeError, json.JSONDecodeError, _DuplicateKey) as error:
        raise ArtifactMeshDeviceRecoveryRunnerError(
            f"{label} frame is not duplicate-free UTF-8 JSON: {error}"
        ) from error
    if raw != _canonical_json(document):
        raise ArtifactMeshDeviceRecoveryRunnerError(
            f"{label} frame must be canonical JSON without a newline"
        )
    return document


def _send_protocol_frame(
    capability: socket.socket,
    document: Any,
    label: str,
    deadline: float,
) -> None:
    raw = _canonical_json(document)
    if len(raw) == 0 or len(raw) > MAX_PROTOCOL_FRAME_BYTES:
        raise ArtifactMeshDeviceRecoveryRunnerError(
            f"{label} frame length is outside the closed bound"
        )
    try:
        capability.settimeout(_remaining_protocol_time(deadline, label))
        capability.sendall(len(raw).to_bytes(PROTOCOL_HEADER_BYTES, "big") + raw)
    except socket.timeout as error:
        raise ArtifactMeshDeviceRecoveryRunnerError(
            f"{label} frame deadline exceeded"
        ) from error
    except OSError as error:
        raise ArtifactMeshDeviceRecoveryRunnerError(
            f"{label} frame could not be sent: {error}"
        ) from error


def _common_binding(document: dict[str, Any], label: str) -> dict[str, Any]:
    binding = {key: document[key] for key in COMMON_BINDING_KEYS}
    if binding["operationID"] != OPERATION_ID:
        raise ArtifactMeshDeviceRecoveryRunnerError(
            f"{label}.operationID is not the frozen operation"
        )
    if binding["commandID"] != COMMAND_ID:
        raise ArtifactMeshDeviceRecoveryRunnerError(
            f"{label}.commandID is not the frozen command"
        )
    for key in ("candidateCommitOID", "candidateTreeOID"):
        value = binding[key]
        if not isinstance(value, str) or not OID_PATTERN.fullmatch(value):
            raise ArtifactMeshDeviceRecoveryRunnerError(
                f"{label}.{key} must be a canonical Git object ID"
            )
    for key in (
        "policyRoot",
        "challengeDigest",
        "deviceProfileDigest",
        "matrixDigest",
        "custodyManifestDigest",
    ):
        _require_digest(binding[key], f"{label}.{key}")
    return binding


def _require_same_binding(
    document: dict[str, Any],
    expected: dict[str, Any],
    label: str,
) -> None:
    actual = _common_binding(document, label)
    if actual != expected:
        raise ArtifactMeshDeviceRecoveryRunnerError(
            f"{label} is replayed or misbound across capability descriptors"
        )


def _validate_lease(value: Any) -> tuple[dict[str, Any], dict[str, Any], str]:
    keys = {
        "schema",
        "schemaVersion",
        "authority",
        *COMMON_BINDING_KEYS,
    }
    lease = _require_exact_object(value, keys, "FD3 lease")
    if lease["schema"] != "QinaoArtifactMeshDeviceRecoveryLeaseV1":
        raise ArtifactMeshDeviceRecoveryRunnerError("FD3 lease schema is invalid")
    if type(lease["schemaVersion"]) is not int or lease["schemaVersion"] != 1:
        raise ArtifactMeshDeviceRecoveryRunnerError("FD3 lease version is invalid")
    if lease["authority"] != "runnerAuthenticated":
        raise ArtifactMeshDeviceRecoveryRunnerError(
            "FD3 lease is not runnerAuthenticated"
        )
    binding = _common_binding(lease, "FD3 lease")
    digest = _protocol_digest(
        "qinao.artifact-mesh.device-recovery.lease.v1",
        lease,
    )
    return lease, binding, digest


def _build_broker_request(
    binding: dict[str, Any],
    lease_digest: str,
) -> dict[str, Any]:
    return {
        "schema": "QinaoArtifactMeshPhysicalBrokerRequestV1",
        "schemaVersion": PROTOCOL_VERSION,
        **binding,
        "leaseDigest": lease_digest,
    }


def _validate_event_chain(
    events_value: Any,
    event_chain_root: Any,
) -> tuple[list[dict[str, Any]], dict[str, Any]]:
    if not isinstance(events_value, list) or len(events_value) != 40:
        raise ArtifactMeshDeviceRecoveryRunnerError(
            "FD4 evidence must contain exactly 40 ordered events"
        )
    expected_rows = generator_expected_matrix()["rows"]
    event_keys = {
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
    events: list[dict[str, Any]] = []
    for index, (value, expected) in enumerate(zip(events_value, expected_rows)):
        event = _require_exact_object(value, event_keys, f"FD4 events[{index}]")
        if type(event["index"]) is not int or event["index"] != index:
            raise ArtifactMeshDeviceRecoveryRunnerError(
                f"FD4 events[{index}].index is not contiguous"
            )
        expected_pairs = {
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
        for key, expected_value in expected_pairs.items():
            if event[key] != expected_value or (
                isinstance(expected_value, int) and type(event[key]) is not int
            ):
                raise ArtifactMeshDeviceRecoveryRunnerError(
                    f"FD4 events[{index}].{key} does not match the closed matrix"
                )
        identity = event["observedStoreIdentity"]
        if not isinstance(identity, str) or not LOWER_UUID_PATTERN.fullmatch(identity):
            raise ArtifactMeshDeviceRecoveryRunnerError(
                f"FD4 events[{index}].observedStoreIdentity is not canonical"
            )
        if store_identity is None:
            store_identity = identity
        elif identity != store_identity:
            raise ArtifactMeshDeviceRecoveryRunnerError(
                "FD4 event chain changes store identity"
            )
        _require_digest(
            event["observedRecordRoot"], f"FD4 events[{index}].observedRecordRoot"
        )
        _require_digest(
            event["observedCASHead"], f"FD4 events[{index}].observedCASHead"
        )
        if event["previousEventDigest"] != previous:
            raise ArtifactMeshDeviceRecoveryRunnerError(
                f"FD4 events[{index}] breaks the event digest chain"
            )
        supplied_digest = _require_digest(
            event["eventDigest"],
            f"FD4 events[{index}].eventDigest",
        )
        unsigned_event = dict(event)
        del unsigned_event["eventDigest"]
        expected_digest = _protocol_digest(
            "qinao.artifact-mesh.device-event.v1",
            unsigned_event,
        )
        if supplied_digest != expected_digest:
            raise ArtifactMeshDeviceRecoveryRunnerError(
                f"FD4 events[{index}] has an invalid event digest"
            )
        previous = supplied_digest
        events.append(event)
    if event_chain_root != previous:
        raise ArtifactMeshDeviceRecoveryRunnerError(
            "FD4 eventChainRoot does not close the 40-row chain"
        )
    recovery_terminal = next(
        event
        for event in events
        if event["scenarioID"] == "nofault.recoveryComplete.after"
    )
    return events, recovery_terminal


def _validate_assertions(value: Any) -> list[dict[str, Any]]:
    if not isinstance(value, list) or len(value) != len(ASSERTION_COUNTS):
        raise ArtifactMeshDeviceRecoveryRunnerError(
            "FD4 evidence must contain exactly nine ordered physical assertions"
        )
    keys = {
        "assertionID",
        "evidenceDigest",
        "expectedObservationCount",
        "observedObservationCount",
        "violationCount",
    }
    result: list[dict[str, Any]] = []
    evidence_digests: set[str] = set()
    for index, (item, expected) in enumerate(zip(value, ASSERTION_COUNTS)):
        row = _require_exact_object(item, keys, f"FD4 assertions[{index}]")
        assertion_id, count = expected
        if row["assertionID"] != assertion_id:
            raise ArtifactMeshDeviceRecoveryRunnerError(
                f"FD4 assertions[{index}] is out of order"
            )
        for key in ("expectedObservationCount", "observedObservationCount"):
            if type(row[key]) is not int or row[key] != count:
                raise ArtifactMeshDeviceRecoveryRunnerError(
                    f"FD4 assertions[{index}].{key} is incomplete"
                )
        if type(row["violationCount"]) is not int or row["violationCount"] != 0:
            raise ArtifactMeshDeviceRecoveryRunnerError(
                f"FD4 assertions[{index}] contains a violation"
            )
        digest = _require_digest(
            row["evidenceDigest"],
            f"FD4 assertions[{index}].evidenceDigest",
        )
        if digest in evidence_digests:
            raise ArtifactMeshDeviceRecoveryRunnerError(
                "FD4 assertion evidence digests must be unique"
            )
        evidence_digests.add(digest)
        result.append(row)
    return result


def _validate_archive(value: Any) -> dict[str, Any]:
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
    archive = _require_exact_object(value, keys, "FD4 archiveAttestation")
    if archive["schema"] != "QinaoArtifactMeshShippingArchiveFactsV1":
        raise ArtifactMeshDeviceRecoveryRunnerError("FD4 archive schema is invalid")
    for key in (
        "archiveDigest",
        "codeIdentityRoot",
        "productManifestRoot",
        "scanManifestDigest",
    ):
        _require_digest(archive[key], f"FD4 archiveAttestation.{key}")
    for key in ("shippingProductCount", "linkMapCount", "moduleInterfaceCount"):
        _require_unsigned(archive[key], f"FD4 archiveAttestation.{key}", 1)
    for key in ("labProductCount", "forbiddenConditionCount", "forbiddenSymbolCount"):
        if type(archive[key]) is not int or archive[key] != 0:
            raise ArtifactMeshDeviceRecoveryRunnerError(
                f"FD4 archiveAttestation.{key} must be zero"
            )
    return archive


def _validate_external_reopen(
    value: Any,
    terminal_event: dict[str, Any],
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
    facts = _require_exact_object(value, keys, "FD4 externalReopenFacts")
    if facts["schema"] != "QinaoArtifactMeshExternalReopenFactsV1":
        raise ArtifactMeshDeviceRecoveryRunnerError(
            "FD4 external-reopen schema is invalid"
        )
    if facts["factorySymbol"] != "QinaoDefaults.makeArtifactMeshStore(configuration:)":
        raise ArtifactMeshDeviceRecoveryRunnerError(
            "FD4 external reopen did not use the production Qinao factory"
        )
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
            raise ArtifactMeshDeviceRecoveryRunnerError(
                f"FD4 externalReopenFacts.{fact_key} is not bound to the terminal event"
            )
    _require_digest(
        facts["storeLineageDigest"], "FD4 externalReopenFacts.storeLineageDigest"
    )
    put_digest = _require_digest(
        facts["putRecordDigest"], "FD4 externalReopenFacts.putRecordDigest"
    )
    reopened_digest = _require_digest(
        facts["reopenedRecordDigest"],
        "FD4 externalReopenFacts.reopenedRecordDigest",
    )
    if put_digest != reopened_digest:
        raise ArtifactMeshDeviceRecoveryRunnerError(
            "FD4 external put and reopened record digests differ"
        )
    open_pid = _require_unsigned(
        facts["openProcessID"], "FD4 externalReopenFacts.openProcessID", 1
    )
    reopen_pid = _require_unsigned(
        facts["reopenProcessID"],
        "FD4 externalReopenFacts.reopenProcessID",
        1,
    )
    if open_pid == reopen_pid or facts["reopenDisposition"] != "resume":
        raise ArtifactMeshDeviceRecoveryRunnerError(
            "FD4 external reopen is not a fresh-process resume"
        )
    return facts


def _validate_broker_response(
    value: Any,
    binding: dict[str, Any],
    lease_digest: str,
    request_digest: str,
) -> dict[str, Any]:
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
    response = _require_exact_object(value, keys, "FD4 evidence")
    if response["schema"] != "QinaoArtifactMeshPhysicalBrokerEvidenceV1":
        raise ArtifactMeshDeviceRecoveryRunnerError("FD4 evidence schema is invalid")
    if type(response["schemaVersion"]) is not int or response["schemaVersion"] != 1:
        raise ArtifactMeshDeviceRecoveryRunnerError("FD4 evidence version is invalid")
    if response["producer"] != "protectedPhysicalBroker":
        raise ArtifactMeshDeviceRecoveryRunnerError(
            "FD4 evidence is generic or app-authored"
        )
    _require_same_binding(response, binding, "FD4 evidence")
    if (
        response["leaseDigest"] != lease_digest
        or response["requestDigest"] != request_digest
    ):
        raise ArtifactMeshDeviceRecoveryRunnerError(
            "FD4 evidence is replayed or request-misbound"
        )
    events, terminal_event = _validate_event_chain(
        response["events"],
        response["eventChainRoot"],
    )
    _validate_assertions(response["physicalAssertions"])
    _validate_archive(response["archiveAttestation"])
    _validate_external_reopen(response["externalReopenFacts"], terminal_event)
    if response["terminal"] != "physicalEvidenceComplete":
        raise ArtifactMeshDeviceRecoveryRunnerError(
            "FD4 evidence has no complete terminal"
        )
    if len(events) != 40:
        raise AssertionError("validated event count drifted")
    return response


def _build_custody_request(
    binding: dict[str, Any],
    lease_digest: str,
    broker_response_digest: str,
    event_chain_root: str,
) -> dict[str, Any]:
    return {
        "schema": "QinaoArtifactMeshCustodyCleanupRequestV1",
        "schemaVersion": PROTOCOL_VERSION,
        **binding,
        "leaseDigest": lease_digest,
        "brokerResponseDigest": broker_response_digest,
        "eventChainRoot": event_chain_root,
    }


def _validate_custody_proof(
    value: Any,
    binding: dict[str, Any],
    lease_digest: str,
    broker_response_digest: str,
    request_digest: str,
) -> dict[str, Any]:
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
    proof = _require_exact_object(value, keys, "FD5 custody proof")
    if proof["schema"] != "QinaoArtifactMeshCustodyProofV1":
        raise ArtifactMeshDeviceRecoveryRunnerError("FD5 proof schema is invalid")
    if type(proof["schemaVersion"]) is not int or proof["schemaVersion"] != 1:
        raise ArtifactMeshDeviceRecoveryRunnerError("FD5 proof version is invalid")
    if proof["producer"] != "encryptedCustodyBroker":
        raise ArtifactMeshDeviceRecoveryRunnerError(
            "FD5 proof is generic or app-authored"
        )
    _require_same_binding(proof, binding, "FD5 custody proof")
    expected_digests = {
        "leaseDigest": lease_digest,
        "brokerResponseDigest": broker_response_digest,
        "requestDigest": request_digest,
    }
    for key, expected in expected_digests.items():
        if proof[key] != expected:
            raise ArtifactMeshDeviceRecoveryRunnerError(
                f"FD5 custody proof {key} is replayed or misbound"
            )
    receipt_digests = [
        _require_digest(proof[key], f"FD5 custody proof.{key}")
        for key in (
            "overwriteReceiptDigest",
            "cleanupReceiptDigest",
            "keyDestructionReceiptDigest",
            "residueScanDigest",
        )
    ]
    if len(set(receipt_digests)) != len(receipt_digests):
        raise ArtifactMeshDeviceRecoveryRunnerError(
            "FD5 custody receipt digests must be distinct"
        )
    _require_unsigned(
        proof["encryptedRootCount"], "FD5 custody proof.encryptedRootCount", 1
    )
    _require_unsigned(
        proof["overwrittenRegularFileCount"],
        "FD5 custody proof.overwrittenRegularFileCount",
        1,
    )
    if proof["cleanupDisposition"] != "removed":
        raise ArtifactMeshDeviceRecoveryRunnerError("FD5 custody cleanup is incomplete")
    if proof["keyDisposition"] != "destroyed":
        raise ArtifactMeshDeviceRecoveryRunnerError("FD5 custody key was not destroyed")
    for key in ("residueFileCount", "residueByteCount"):
        if type(proof[key]) is not int or proof[key] != 0:
            raise ArtifactMeshDeviceRecoveryRunnerError(
                f"FD5 custody proof.{key} must be zero"
            )
    if proof["terminal"] != "custodyClosed":
        raise ArtifactMeshDeviceRecoveryRunnerError(
            "FD5 custody proof has no closed terminal"
        )
    return proof


def _run_protocol_sockets(
    lease_capability: socket.socket,
    broker_capability: socket.socket,
    custody_capability: socket.socket,
    *,
    deadline: Optional[float] = None,
) -> dict[str, Any]:
    protocol_deadline = (
        time.monotonic() + PROTOCOL_TIMEOUT_SECONDS if deadline is None else deadline
    )
    lease, binding, lease_digest = _validate_lease(
        _receive_protocol_frame(lease_capability, "FD3 lease", protocol_deadline)
    )
    del lease
    broker_request = _build_broker_request(binding, lease_digest)
    broker_request_digest = _protocol_digest(
        "qinao.artifact-mesh.physical-broker.request.v1",
        broker_request,
    )
    _send_protocol_frame(
        broker_capability,
        broker_request,
        "FD4 request",
        protocol_deadline,
    )
    broker_response = _validate_broker_response(
        _receive_protocol_frame(
            broker_capability,
            "FD4 evidence",
            protocol_deadline,
        ),
        binding,
        lease_digest,
        broker_request_digest,
    )
    broker_response_digest = _protocol_digest(
        "qinao.artifact-mesh.physical-broker.evidence.v1",
        broker_response,
    )
    custody_request = _build_custody_request(
        binding,
        lease_digest,
        broker_response_digest,
        broker_response["eventChainRoot"],
    )
    custody_request_digest = _protocol_digest(
        "qinao.artifact-mesh.custody.request.v1",
        custody_request,
    )
    _send_protocol_frame(
        custody_capability,
        custody_request,
        "FD5 request",
        protocol_deadline,
    )
    custody_proof = _validate_custody_proof(
        _receive_protocol_frame(
            custody_capability,
            "FD5 custody proof",
            protocol_deadline,
        ),
        binding,
        lease_digest,
        broker_response_digest,
        custody_request_digest,
    )
    custody_proof_digest = _protocol_digest(
        "qinao.artifact-mesh.custody.proof.v1",
        custody_proof,
    )
    evidence_root = _protocol_digest(
        "qinao.artifact-mesh.device-recovery.terminal.v1",
        {
            "leaseDigest": lease_digest,
            "brokerResponseDigest": broker_response_digest,
            "custodyProofDigest": custody_proof_digest,
        },
    )
    return {
        "rowsValidated": 40,
        "assertionsValidated": 9,
        "terminal": "custodyClosed",
        "leaseDigest": lease_digest,
        "brokerResponseDigest": broker_response_digest,
        "custodyProofDigest": custody_proof_digest,
        "evidenceRoot": evidence_root,
    }


def run_production(arguments: argparse.Namespace) -> int:
    qinao_keys = sorted(key for key in os.environ if key.startswith("QINAO_"))
    if qinao_keys:
        raise ArtifactMeshDeviceRecoveryRunnerError(
            f"production rejects QINAO_* environment keys: {qinao_keys!r}"
        )
    _require_capability_socket(arguments.lease_fd, 3, "lease capability")
    _require_capability_socket(
        arguments.physical_broker_fd, 4, "physical broker capability"
    )
    _require_capability_socket(arguments.custody_fd, 5, "custody capability")
    identities = {
        (os.fstat(descriptor).st_dev, os.fstat(descriptor).st_ino)
        for descriptor in (3, 4, 5)
    }
    if len(identities) != 3:
        raise ArtifactMeshDeviceRecoveryRunnerError(
            "lease, physical-broker, and custody capabilities must be distinct"
        )
    capabilities: list[socket.socket] = []
    try:
        for descriptor in (3, 4, 5):
            capabilities.append(socket.socket(fileno=os.dup(descriptor)))
        result = _run_protocol_sockets(
            capabilities[0],
            capabilities[1],
            capabilities[2],
        )
    finally:
        for capability in capabilities:
            capability.close()
    print(
        "artifact-mesh-device-recovery: PASS mode=device "
        f"rows={result['rowsValidated']} "
        f"assertions={result['assertionsValidated']} "
        f"terminal={result['terminal']} "
        f"evidence_root={result['evidenceRoot']}"
    )
    return 0


def main(argv: Optional[Sequence[str]] = None) -> int:
    values = list(sys.argv[1:] if argv is None else argv)
    try:
        arguments = _dispatch_parser(values)
        if arguments.mode == "candidate-preflight":
            return run_candidate_preflight(arguments)
        return run_production(arguments)
    except ArtifactMeshDeviceRecoveryRunnerError as error:
        print(f"artifact-mesh-device-recovery: ERROR {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
