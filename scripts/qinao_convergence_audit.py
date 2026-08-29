#!/usr/bin/env python3
"""Durable, standard-library-only audit primitives for Qinao convergence.

The module deliberately has no repository import root and no network side
effect at import time.  Durable authority is an immutable identity plus a
canonical append-only digest chain below a caller-selected run root.
"""

from __future__ import annotations

import argparse
import base64
import ctypes
import errno
import fcntl
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import re
import secrets
import stat
import subprocess
import sys
import sysconfig
import time
from typing import Any, Dict, Iterable, List, Mapping, Optional, Sequence, Tuple


MAX_JSON_BYTES = 16 * 1024 * 1024
MAX_SAFE_INTEGER = (1 << 53) - 1
ERRATUM_DIGEST = "ad01e833fef13bb68e2d536d9774a005d9bf30b6987b0215caad954527ba737b"
REPAIR_ERRATUM_DIGEST = "71cf7f9ed83f8106cf75040d8d6592dd3437fd3fd9f61cbaa9c8f7c5120fc55f"
EXACT_PROBES = ("probe.gV8vVx", "probe.9erZU8", "probe.U4rXSq")
N34_NAME = "tree-prediction.N34crC"
RULE_SET_VERSION = "qinao.secret-scan.v1"
FROZEN_WT = "/Users/changgeng/Project/Project06/Project06/.worktrees/qinao-git-only-convergence"
FROZEN_BRANCH = "refs/heads/codex/qinao-git-only-convergence"
FROZEN_S = "4a9298db261bcfda97ea1748baad65649156ba66"
FROZEN_D = "e602fe41ca74efad44ef00a3a34c930cfe41e2ce"
FROZEN_C = "91bfb4c851279235ccde2ec21902c6a4c83555ee"
FROZEN_C_TREE = "3a1674651a95e91b321b637b801db66d71e6fafb"
FROZEN_C_RAW_SHA256 = "a1a74d94777b2d304ac978952a1cab6b3087857f423e15488b8b3940459e3532"
FROZEN_CONFIG_DIGEST = "46548761eae4d5f932d4a714a4fca4cb1276185765367220e7bb1c67838f2f0c"
FROZEN_RAW_CONFIG_DIGEST = "0a3325514a9ecbcf15f02aa3e0a7c03ffdaa0598b78799abc3e16fdf87963b05"
FROZEN_CONFIG_KEYS_DIGEST = "860dc0a57590606408d92f84407ce8101c229b731fa9bfca73425aef70cebb37"
FROZEN_MERGE_MANIFEST_DIGEST = "c66d5150df01c632c23f34ebc5069bfda427853ae121a9764e35e8f913ebe59b"
BOOTSTRAP_COMMIT_MESSAGE = b"feat: add durable Qinao run ledger\n"
BOOTSTRAP_IMPLEMENTATION_COMMIT = "1e18da38a498549687dd646a43d34d0637b23aed"
BOOTSTRAP_IMPLEMENTATION_TREE = "b170bd6b2f45d4d5fb7c5759d3bab6698ebf37b0"
BOOTSTRAP_IMPLEMENTATION_RAW_SHA256 = "fd9073cdf2bd643ed11ffa35288ade4f03db2fcf08844921cf9dd330f1896810"
BOOTSTRAP_REPAIR_MESSAGE = b"fix: admit frozen Qinao bootstrap terminals\n"
HISTORICAL_SCANNER_NAME = "capture.task3-secret.ee573e0d5235"
HISTORICAL_SCANNER_RECORD_SHA256 = "6b9096da064d2d16d1518a5efd6ca573fa0cc3db13bbc48b62185c0e16a78316"
HISTORICAL_SCANNER_RECORD_DIGEST = "fe924341b5bf1c12fb0ebf293196ababdc885e4396791285c1e3ef07ced662c5"
SCANNER_TERMINAL_SHA256 = "37a40f08d8548dba289b9b0bb35bcf63b359f6d37ee86044ebc6b6da080b9ec1"
PRESERVED_TRANSITION_NAME = "capture.sterile-python.f24d9641fa44"
PRESERVED_TRANSITION_SHA256 = "87a6e1139bb25853d01b9cb33b57c084294c2b33e7d557dbe51776bb04923ea4"
PRESERVED_TRANSITION_INVOCATION_SHA256 = "9175bb32393d58b131e67be03ebf40a1be05f8265d29c146ff1cbb9c813bafff"
TASK3_TRACKED_PATHS = (
    b"scripts/qinao_convergence_audit.py",
    b"scripts/test_qinao_convergence_audit.py",
)
PROTECTED_WITNESS = {
    "worktree": "/Users/changgeng/Project/Project06/Project06/.worktrees/qinao-dual-space-controlled-convergence",
    "branch": "refs/heads/codex/qinao-dual-space-controlled-convergence",
    "head": "29d953a8ab7f1b8cfe83ae1f99c9ace620b2f895",
    "tree": "1f1efdf28bd31bb8fd5ec043e1f4f44fa11f6d01",
    "indexSha256": "089b62d56244917e72b528d9bc832fcf9dceeb9ba37fe5016f503fbedcd67592",
    "stageSha256": "4e942296c7e6ff7bf7b61457e31b5cfef62bb1915c36ae00e1f8380cad590599",
    "stageFlagsSha256": "19776d5274171c529bfc69ebe8ab81ffcbe36a21811b0a2503236850f23e5149",
    "porcelainV1Sha256": "45faece29aad471828a39eef3acc600d8828bf0e45133ad72ce83b76a1a6c875",
    "porcelainV2Sha256": "f3cf7d41c4e7b928737e10d86f980baa0f0126af67581d8b237c9481f7496539",
    "trackedDiffSha256": "58628700af05929c4f8d0d3a57c0f6dbf16fdff2ddc1a61be854ead0b5f9e7b2",
    "preservationManifestSha256": "67b8958268caeda7b1dfcdd9f249824fd9b70ebbfdcf01aa528cacf89da88e3c",
    "statusPathSha256": "822567f429bde6fd90256c348d8e09836521f64bfcdfedc5bc8dd91fff5accf4",
}

LOCAL_PYTHON_LAUNCHER = b"""qinao_python() {
  /bin/test \"$#\" -ge 1
  /bin/test -d \"$RUN_ROOT/home\"
  /bin/test -d \"$RUN_ROOT/tmp\"
  /usr/bin/env -i HOME=\"$RUN_ROOT/home\" TMPDIR=\"$RUN_ROOT/tmp\" LANG=C LC_ALL=C PATH=/usr/bin:/bin /usr/bin/python3 -I -S -B \"$WT/scripts/qinao_convergence_audit.py\" sterile-python --root \"$RUN_ROOT\" --repository \"$WT\" -- \"$@\"
}
"""
CI_PYTHON_PREFIX = b"/usr/bin/env -i HOME=/nonexistent LANG=C LC_ALL=C PATH=/usr/bin:/bin /usr/bin/python3 -I -S -B scripts/qinao_convergence_audit.py sterile-python --profile ci --ci-runner-home \"$QINAO_RUNNER_ROOT\""
BOOTSTRAP_TEST_COMMAND = b"/usr/bin/python3 -I -S -B scripts/test_qinao_convergence_audit.py SterilePythonLauncherTests LedgerTests SecretScanWorktreeTests"
HISTORICAL_DEBT_PATH = b"scripts/check_sovereign_redaction.sh"
HISTORICAL_DEBT_SHA256 = "dd664420b3eab666879ddddebf1d9f00470d8fd8ecf3744ec9c8a221375c0ee0"
HISTORICAL_DEBT_CALLERS = (
    b".github/workflows/test.yml",
    b"Archive/Legacy/scripts/run_quality_gate.sh",
    b"scripts/check_qinao_import_boundaries.sh",
)
_CURRENT_STERILE_INVOCATION: Optional[Dict[str, Any]] = None


class AuditError(Exception):
    """Closed-world validation failure."""


class SecretScanError(AuditError):
    """A redacted secret-scan failure."""

    def __init__(self, message: str, record: Mapping[str, Any]):
        super().__init__(message)
        self.record = dict(record)


def _sha256(payload: bytes) -> str:
    return hashlib.sha256(payload).hexdigest()


def _validate_unicode(value: str) -> None:
    try:
        value.encode("utf-8", "strict")
    except UnicodeEncodeError as exc:
        raise AuditError("invalid Unicode") from exc
    if any(0xD800 <= ord(character) <= 0xDFFF for character in value):
        raise AuditError("invalid Unicode surrogate")


def _validate_json_value(value: Any) -> None:
    if value is None or isinstance(value, bool):
        return
    if isinstance(value, int):
        if abs(value) > MAX_SAFE_INTEGER:
            raise AuditError("unsafe integer")
        return
    if isinstance(value, float):
        raise AuditError("floats are forbidden")
    if isinstance(value, str):
        _validate_unicode(value)
        return
    if isinstance(value, list):
        for item in value:
            _validate_json_value(item)
        return
    if isinstance(value, dict):
        for key, item in value.items():
            if not isinstance(key, str):
                raise AuditError("JSON object key must be a string")
            _validate_unicode(key)
            _validate_json_value(item)
        return
    raise AuditError("unsupported JSON type")


def canonical_json_bytes(value: Any) -> bytes:
    _validate_json_value(value)
    try:
        encoded = json.dumps(
            value,
            ensure_ascii=False,
            allow_nan=False,
            sort_keys=True,
            separators=(",", ":"),
        ).encode("utf-8", "strict") + b"\n"
    except (TypeError, ValueError, UnicodeEncodeError) as exc:
        raise AuditError("noncanonical JSON value") from exc
    if len(encoded) > MAX_JSON_BYTES:
        raise AuditError("canonical JSON exceeds bound")
    return encoded


def _reject_constant(_value: str) -> None:
    raise AuditError("non-finite number")


def _parse_integer(value: str) -> int:
    parsed = int(value, 10)
    if abs(parsed) > MAX_SAFE_INTEGER:
        raise AuditError("unsafe integer")
    return parsed


def _reject_float(_value: str) -> None:
    raise AuditError("floats are forbidden")


def _pairs_no_duplicates(pairs: Sequence[Tuple[str, Any]]) -> Dict[str, Any]:
    result: Dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            raise AuditError("duplicate JSON key")
        result[key] = value
    return result


def parse_canonical_json(payload: bytes) -> Any:
    if not isinstance(payload, bytes) or not payload or len(payload) > MAX_JSON_BYTES:
        raise AuditError("invalid canonical JSON byte count")
    try:
        text = payload.decode("utf-8", "strict")
    except UnicodeDecodeError as exc:
        raise AuditError("invalid UTF-8") from exc
    try:
        value = json.loads(
            text,
            object_pairs_hook=_pairs_no_duplicates,
            parse_int=_parse_integer,
            parse_float=_reject_float,
            parse_constant=_reject_constant,
        )
    except AuditError:
        raise
    except (json.JSONDecodeError, ValueError) as exc:
        raise AuditError("malformed JSON") from exc
    _validate_json_value(value)
    if canonical_json_bytes(value) != payload:
        raise AuditError("noncanonical JSON bytes")
    return value


def _parse_exact_commit_metadata(
    payload: bytes,
    *,
    expected_tree: str,
    expected_parent: str,
    expected_message: bytes,
    label: str,
) -> Dict[str, Any]:
    if not isinstance(payload, bytes) or not payload or len(payload) > MAX_JSON_BYTES:
        raise AuditError(label + " commit byte count")
    if b"\x00" in payload or payload.count(b"\n\n") != 1:
        raise AuditError(label + " commit separator")
    header_block, message = payload.split(b"\n\n", 1)
    headers = header_block.split(b"\n")
    if len(headers) != 4:
        raise AuditError(label + " commit header count")
    expected_prefixes = (b"tree ", b"parent ", b"author ", b"committer ")
    if tuple(line.split(b" ", 1)[0] + b" " for line in headers) != expected_prefixes:
        raise AuditError(label + " commit header order or optional header")
    if headers[0] != b"tree " + expected_tree.encode("ascii"):
        raise AuditError(label + " commit tree")
    if headers[1] != b"parent " + expected_parent.encode("ascii"):
        raise AuditError(label + " commit parent")
    identity_pattern = re.compile(
        rb"\A(?:author|committer) Qinao development "
        rb"<qinao-development@invalid\.local> ([1-9][0-9]*) ([+-])([0-9]{2})([0-9]{2})\Z"
    )
    identities = []
    for line in headers[2:]:
        match = identity_pattern.fullmatch(line)
        if match is None:
            raise AuditError(label + " commit identity drift")
        hours = int(match.group(3))
        minutes = int(match.group(4))
        if hours > 14 or minutes > 59 or (hours == 14 and minutes != 0):
            raise AuditError(label + " commit identity timezone")
        identities.append(line.decode("ascii"))
    if message != expected_message:
        raise AuditError(label + " commit message")
    return {
        "schemaVersion": "qinao.exact-commit.v1",
        "tree": expected_tree,
        "parent": expected_parent,
        "author": identities[0],
        "committer": identities[1],
        "message": message.decode("ascii"),
        "rawCommitSize": len(payload),
        "rawCommitSha256": _sha256(payload),
    }


def parse_bootstrap_commit_metadata(
    payload: bytes,
    *,
    expected_tree: str,
    expected_parent: str,
) -> Dict[str, Any]:
    result = _parse_exact_commit_metadata(
        payload,
        expected_tree=expected_tree,
        expected_parent=expected_parent,
        expected_message=BOOTSTRAP_COMMIT_MESSAGE,
        label="bootstrap",
    )
    result["schemaVersion"] = "qinao.bootstrap-commit.v1"
    return result


def validate_preledger_commit_chain(
    *,
    b0_oid: str,
    b0_payload: bytes,
    b1_oid: str,
    b1_payload: bytes,
    b0_changed_paths: Sequence[bytes],
    b1_changed_paths: Sequence[bytes],
) -> Dict[str, Any]:
    if b0_oid != BOOTSTRAP_IMPLEMENTATION_COMMIT:
        raise AuditError("bootstrap implementation commit drift")
    if not re.fullmatch(r"[0-9a-f]{40}", b1_oid) or b1_oid in (
        FROZEN_C,
        BOOTSTRAP_IMPLEMENTATION_COMMIT,
    ):
        raise AuditError("bootstrap repair commit identity drift")
    if _sha256(b0_payload) != BOOTSTRAP_IMPLEMENTATION_RAW_SHA256:
        raise AuditError("bootstrap implementation raw commit drift")
    b0_metadata = parse_bootstrap_commit_metadata(
        b0_payload,
        expected_tree=BOOTSTRAP_IMPLEMENTATION_TREE,
        expected_parent=FROZEN_C,
    )
    if not b1_payload.startswith(b"tree ") or b"\n" not in b1_payload:
        raise AuditError("bootstrap repair tree header")
    try:
        b1_tree = b1_payload.split(b"\n", 1)[0][5:].decode("ascii", "strict")
    except UnicodeDecodeError as exc:
        raise AuditError("bootstrap repair tree ASCII") from exc
    if not re.fullmatch(r"[0-9a-f]{40}", b1_tree):
        raise AuditError("bootstrap repair tree")
    b1_metadata = _parse_exact_commit_metadata(
        b1_payload,
        expected_tree=b1_tree,
        expected_parent=BOOTSTRAP_IMPLEMENTATION_COMMIT,
        expected_message=BOOTSTRAP_REPAIR_MESSAGE,
        label="bootstrap repair",
    )
    for label, paths in (
        ("implementation", tuple(b0_changed_paths)),
        ("repair", tuple(b1_changed_paths)),
    ):
        if paths != TASK3_TRACKED_PATHS:
            raise AuditError("bootstrap " + label + " path delta drift")
    ordered = [BOOTSTRAP_IMPLEMENTATION_COMMIT, b1_oid]
    return {
        "schemaVersion": "qinao.preledger-commit-chain.v1",
        "orderedCommitChain": ordered,
        "orderedCommitChainDigest": _sha256(canonical_json_bytes(ordered)),
        "implementationCommitMetadata": b0_metadata,
        "repairCommitMetadata": b1_metadata,
    }


def _self_digest_record(value: Mapping[str, Any], field: str = "recordDigest") -> Dict[str, Any]:
    if field in value:
        raise AuditError("self-digest field already present")
    result = dict(value)
    result[field] = _sha256(canonical_json_bytes(result))
    return result


def _verify_self_digest(value: Mapping[str, Any], field: str = "recordDigest") -> None:
    digest = value.get(field)
    if not isinstance(digest, str) or not re.fullmatch(r"[0-9a-f]{64}", digest):
        raise AuditError("missing self digest")
    unsigned = dict(value)
    del unsigned[field]
    if _sha256(canonical_json_bytes(unsigned)) != digest:
        raise AuditError("self digest mismatch")


def _write_all(fd: int, payload: bytes) -> None:
    view = memoryview(payload)
    written = 0
    while written < len(view):
        count = os.write(fd, view[written:])
        if count <= 0:
            raise OSError("short write made no progress")
        written += count


def _fsync_directory(path: Path) -> None:
    flags = os.O_RDONLY | getattr(os, "O_DIRECTORY", 0) | getattr(os, "O_NOFOLLOW", 0)
    fd = os.open(str(path), flags)
    try:
        os.fsync(fd)
    finally:
        os.close(fd)


def _ordinary_directory(path: Path, expected_mode: Optional[int] = None) -> os.stat_result:
    try:
        observed = path.lstat()
    except FileNotFoundError as exc:
        raise AuditError("required directory absent: " + str(path)) from exc
    if not stat.S_ISDIR(observed.st_mode) or path.is_symlink():
        raise AuditError("directory is not ordinary: " + str(path))
    if expected_mode is not None and stat.S_IMODE(observed.st_mode) != expected_mode:
        raise AuditError("directory mode mismatch: " + str(path))
    return observed


def _ordinary_file(path: Path, *, expected_mode: Optional[int] = None, single_link: bool = True) -> os.stat_result:
    try:
        observed = path.lstat()
    except FileNotFoundError as exc:
        raise AuditError("required file absent: " + str(path)) from exc
    if not stat.S_ISREG(observed.st_mode) or path.is_symlink():
        raise AuditError("path is not an ordinary file: " + str(path))
    if single_link and observed.st_nlink != 1:
        raise AuditError("hard link surprise: " + str(path))
    if expected_mode is not None and stat.S_IMODE(observed.st_mode) != expected_mode:
        raise AuditError("file mode mismatch: " + str(path))
    return observed


def _read_ordinary(path: Path, *, maximum: int = MAX_JSON_BYTES, single_link: bool = True) -> bytes:
    before = _ordinary_file(path, single_link=single_link)
    if before.st_size > maximum:
        raise AuditError("file exceeds bound: " + str(path))
    flags = os.O_RDONLY | getattr(os, "O_NOFOLLOW", 0)
    fd = os.open(str(path), flags)
    try:
        opened = os.fstat(fd)
        if not stat.S_ISREG(opened.st_mode):
            raise AuditError("opened object is not regular")
        chunks: List[bytes] = []
        remaining = maximum + 1
        while remaining:
            chunk = os.read(fd, min(1024 * 1024, remaining))
            if not chunk:
                break
            chunks.append(chunk)
            remaining -= len(chunk)
        payload = b"".join(chunks)
        if len(payload) > maximum:
            raise AuditError("file exceeds bound: " + str(path))
        after_fd = os.fstat(fd)
    finally:
        os.close(fd)
    after_path = path.lstat()
    stable = (
        before.st_dev,
        before.st_ino,
        before.st_mode,
        before.st_nlink,
        before.st_size,
        before.st_mtime_ns,
    ) == (
        after_fd.st_dev,
        after_fd.st_ino,
        after_fd.st_mode,
        after_fd.st_nlink,
        after_fd.st_size,
        after_fd.st_mtime_ns,
    ) == (
        after_path.st_dev,
        after_path.st_ino,
        after_path.st_mode,
        after_path.st_nlink,
        after_path.st_size,
        after_path.st_mtime_ns,
    )
    if not stable:
        raise AuditError("concurrent file change: " + str(path))
    return payload


def write_canonical_exclusive(path: Path, value: Any) -> bytes:
    path = Path(path)
    _ordinary_directory(path.parent)
    payload = canonical_json_bytes(value)
    flags = os.O_WRONLY | os.O_CREAT | os.O_EXCL | getattr(os, "O_NOFOLLOW", 0)
    fd = os.open(str(path), flags, 0o600)
    try:
        _write_all(fd, payload)
        os.fsync(fd)
    finally:
        os.close(fd)
    _fsync_directory(path.parent)
    return payload


def _write_bytes_exclusive(path: Path, payload: bytes, mode: int = 0o600) -> None:
    _ordinary_directory(path.parent)
    flags = os.O_WRONLY | os.O_CREAT | os.O_EXCL | getattr(os, "O_NOFOLLOW", 0)
    fd = os.open(str(path), flags, mode)
    try:
        _write_all(fd, payload)
        os.fsync(fd)
    finally:
        os.close(fd)
    _fsync_directory(path.parent)


def _mkdir_exclusive(path: Path, mode: int = 0o700) -> None:
    path = Path(path)
    _ordinary_directory(path.parent)
    os.mkdir(str(path), mode)
    observed = _ordinary_directory(path, mode)
    if observed.st_nlink < 2:
        raise AuditError("directory link count invalid")
    _fsync_directory(path)
    _fsync_directory(path.parent)


def _read_canonical_file(path: Path) -> Any:
    _ordinary_file(path, expected_mode=0o600)
    return parse_canonical_json(_read_ordinary(path))


def _validate_run_root(root: Path, *, allow_ledger: bool = True) -> None:
    root = Path(root)
    _ordinary_directory(root, 0o700)
    _ordinary_directory(root / "home", 0o700)
    _ordinary_directory(root / "tmp", 0o700)
    _ordinary_directory(root / "bootstrap", 0o700)
    allowed = {"home", "tmp", "bootstrap"}
    if allow_ledger:
        allowed.add("ledger")
    for child in root.iterdir():
        if child.name in allowed or child.name.startswith("ledger.init."):
            continue
        raise AuditError("unexpected run-root child: " + child.name)


def _publish_no_replace(root: Path, staging_name: str) -> None:
    if "/" in staging_name or staging_name in ("", ".", ".."):
        raise AuditError("invalid staging name")
    root_fd = os.open(
        str(root),
        os.O_RDONLY | getattr(os, "O_DIRECTORY", 0) | getattr(os, "O_NOFOLLOW", 0),
    )
    try:
        library = ctypes.CDLL(None, use_errno=True)
        try:
            renameatx_np = library.renameatx_np
        except AttributeError as exc:
            raise AuditError("renameatx_np unavailable") from exc
        renameatx_np.argtypes = [ctypes.c_int, ctypes.c_char_p, ctypes.c_int, ctypes.c_char_p, ctypes.c_uint]
        renameatx_np.restype = ctypes.c_int
        result = renameatx_np(root_fd, os.fsencode(staging_name), root_fd, b"ledger", 0x00000004)
        if result != 0:
            observed_errno = ctypes.get_errno()
            if observed_errno == errno.EEXIST:
                raise FileExistsError(errno.EEXIST, "ledger already exists")
            if observed_errno in (errno.ENOTSUP, getattr(errno, "EOPNOTSUPP", errno.ENOTSUP)):
                raise AuditError("no-replace publication unsupported")
            raise OSError(observed_errno, os.strerror(observed_errno))
        os.fsync(root_fd)
    finally:
        os.close(root_fd)


def _new_record(
    identity: Mapping[str, Any],
    sequence: int,
    previous_digest: str,
    operation_kind: str,
    input_digest: str,
    declared_filenames: Sequence[str],
    completion_state: str,
    payload: Mapping[str, Any],
) -> Dict[str, Any]:
    if not re.fullmatch(r"[0-9a-f]{64}", input_digest):
        raise AuditError("input digest must be SHA-256")
    record = {
        "schemaVersion": "qinao.ledger-record.v1",
        "runId": identity["runId"],
        "sequence": sequence,
        "previousRecordDigest": previous_digest,
        "recordId": secrets.token_hex(16),
        "operationKind": operation_kind,
        "inputDigest": input_digest,
        "declaredFilenames": list(declared_filenames),
        "completionState": completion_state,
    }
    for key, value in payload.items():
        if key in record or key == "recordDigest":
            raise AuditError("record payload field collision")
        record[key] = value
    return _self_digest_record(record)


def _write_initial_records(staging: Path, identity: Mapping[str, Any], imports: Sequence[Mapping[str, Any]]) -> None:
    previous = identity["identityDigest"]
    sequence = 1
    for imported in imports:
        input_digest = _sha256(canonical_json_bytes(imported))
        record = _new_record(
            identity,
            sequence,
            previous,
            "bootstrap-import",
            input_digest,
            [],
            "complete",
            {"bootstrapImport": dict(imported)},
        )
        write_canonical_exclusive(staging / "records" / ("%016d.json" % sequence), record)
        previous = record["recordDigest"]
        sequence += 1
    terminal_payload = {
        "bootstrapImportCount": len(imports),
        "bootstrapImportsDigest": _sha256(canonical_json_bytes(list(imports))),
    }
    terminal = _new_record(
        identity,
        sequence,
        previous,
        "bootstrap-completed",
        terminal_payload["bootstrapImportsDigest"],
        [],
        "complete",
        terminal_payload,
    )
    write_canonical_exclusive(staging / "records" / ("%016d.json" % sequence), terminal)


def init_run_state(
    root: Path,
    identity_fields: Mapping[str, Any],
    *,
    bootstrap_imports: Sequence[Mapping[str, Any]],
) -> Dict[str, Any]:
    root = Path(root).resolve()
    _validate_run_root(root)
    supplied = dict(identity_fields)
    supplied.setdefault("creationNonce", secrets.token_hex(16))
    # Nanosecond epoch values exceed the canonical safe-integer domain.  The
    # identity treats the timestamp as a decimal string, never as arithmetic.
    supplied.setdefault("createdUnixNs", str(time.time_ns()))
    supplied["runId"] = _sha256(canonical_json_bytes(supplied))[:32]
    identity = _self_digest_record(supplied, field="identityDigest")
    published = root / "ledger"
    if published.exists() or published.is_symlink():
        existing = _read_canonical_file(published / "identity.json")
        comparable_existing = dict(existing)
        for volatile in ("creationNonce", "createdUnixNs", "runId", "identityDigest"):
            comparable_existing.pop(volatile, None)
        comparable_supplied = dict(identity_fields)
        if comparable_existing != comparable_supplied:
            raise AuditError("identity mismatch")
        recovered = recover_run_state(root)
        if recovered["classification"] != "complete":
            raise AuditError("published ledger indeterminate")
        return existing

    staging = root / ("ledger.init." + secrets.token_hex(6))
    _mkdir_exclusive(staging)
    for directory in ("records", "phases", "captures", "resources", "resource-snapshots", "invocations"):
        _mkdir_exclusive(staging / directory)
    write_canonical_exclusive(staging / "identity.json", identity)
    _write_bytes_exclusive(staging / "lock", b"")
    _write_initial_records(staging, identity, bootstrap_imports)
    for directory in ("records", "phases", "captures", "resources", "resource-snapshots", "invocations", ""):
        _fsync_directory(staging / directory if directory else staging)
    root_fd = os.open(str(root), os.O_RDONLY | getattr(os, "O_DIRECTORY", 0))
    try:
        fcntl.flock(root_fd, fcntl.LOCK_EX)
        try:
            _publish_no_replace(root, staging.name)
        except FileExistsError:
            existing = _read_canonical_file(published / "identity.json")
            comparable_existing = dict(existing)
            for volatile in ("creationNonce", "createdUnixNs", "runId", "identityDigest"):
                comparable_existing.pop(volatile, None)
            if comparable_existing != dict(identity_fields):
                raise AuditError("identity mismatch after publication race")
            return existing
        finally:
            fcntl.flock(root_fd, fcntl.LOCK_UN)
    finally:
        os.close(root_fd)
    return identity


def _recover_records(root: Path) -> Tuple[Dict[str, Any], List[Dict[str, Any]]]:
    ledger = root / "ledger"
    _ordinary_directory(ledger, 0o700)
    identity = _read_canonical_file(ledger / "identity.json")
    _verify_self_digest(identity, "identityDigest")
    _ordinary_file(ledger / "lock", expected_mode=0o600)
    records_dir = ledger / "records"
    _ordinary_directory(records_dir, 0o700)
    names = sorted(path.name for path in records_dir.iterdir())
    records: List[Dict[str, Any]] = []
    previous = identity["identityDigest"]
    seen_ids = set()
    for expected, name in enumerate(names, 1):
        if name != "%016d.json" % expected:
            raise AuditError("record sequence gap or unexpected filename")
        record = _read_canonical_file(records_dir / name)
        _verify_self_digest(record)
        if record.get("sequence") != expected or record.get("runId") != identity.get("runId"):
            raise AuditError("record identity or sequence mismatch")
        if record.get("previousRecordDigest") != previous:
            raise AuditError("record chain fork")
        record_id = record.get("recordId")
        if not isinstance(record_id, str) or record_id in seen_ids:
            raise AuditError("duplicate record ID")
        seen_ids.add(record_id)
        previous = record["recordDigest"]
        records.append(record)
    if not records or records[-1].get("operationKind") not in (
        "bootstrap-completed",
        "frontier-start",
        "frontier-complete",
        "capture-allocated",
        "capture-sealed",
        "resource-allocated",
        "resource-snapshot",
        "git-state-snapshot",
        "sterile-invocation-started",
        "sterile-invocation-completed",
    ):
        raise AuditError("terminal chain state unknown")
    return identity, records


def _project_state(root: Path, records: Sequence[Mapping[str, Any]]) -> Dict[str, Any]:
    open_frontiers: Dict[str, Dict[str, Any]] = {}
    completed_frontiers: Dict[str, Dict[str, Any]] = {}
    captures: Dict[str, Dict[str, Any]] = {}
    resources: Dict[str, Dict[str, Any]] = {}
    for record in records:
        kind = record["operationKind"]
        if kind == "frontier-start":
            frontier_id = record["frontierId"]
            if frontier_id in open_frontiers or frontier_id in completed_frontiers:
                raise AuditError("frontier ID collision")
            open_frontiers[frontier_id] = dict(record)
        elif kind == "frontier-complete":
            frontier_id = record["frontierId"]
            if frontier_id not in open_frontiers:
                raise AuditError("orphan frontier completion")
            completed_frontiers[frontier_id] = dict(record)
            del open_frontiers[frontier_id]
        elif kind == "capture-allocated":
            capture_id = record["captureId"]
            if capture_id in captures:
                raise AuditError("capture ID collision")
            captures[capture_id] = {"allocation": dict(record), "state": "allocated"}
        elif kind == "capture-sealed":
            capture_id = record["captureId"]
            if capture_id not in captures or captures[capture_id]["state"] != "allocated":
                raise AuditError("orphan capture seal")
            captures[capture_id]["state"] = "sealed"
            captures[capture_id]["seal"] = dict(record)
        elif kind == "resource-allocated":
            resource_id = record["resourceId"]
            if resource_id in resources:
                raise AuditError("resource ID collision")
            resources[resource_id] = {"allocation": dict(record), "snapshots": []}
        elif kind == "resource-snapshot":
            resource_id = record["resourceId"]
            if resource_id not in resources:
                raise AuditError("orphan resource snapshot")
            resources[resource_id]["snapshots"].append(dict(record))

    allocated_paths = {Path(value["allocation"]["absolutePath"]) for value in captures.values()}
    capture_root = root / "ledger" / "captures"
    for phase in capture_root.iterdir():
        if not phase.is_dir() or phase.is_symlink():
            raise AuditError("unexpected capture phase entry")
        for generation in phase.iterdir():
            if generation not in allocated_paths:
                raise AuditError("orphan capture generation")
    resource_paths = {Path(value["allocation"]["absolutePath"]) for value in resources.values()}
    resource_root = root / "ledger" / "resources"
    for kind_dir in resource_root.iterdir():
        if not kind_dir.is_dir() or kind_dir.is_symlink():
            raise AuditError("unexpected resource kind entry")
        for generation in kind_dir.iterdir():
            if generation not in resource_paths:
                raise AuditError("orphan resource generation")
    return {
        "open": open_frontiers,
        "completed": completed_frontiers,
        "captures": captures,
        "resources": resources,
    }


def recover_run_state(root: Path) -> Dict[str, Any]:
    root = Path(root).resolve()
    try:
        _validate_run_root(root)
        identity, records = _recover_records(root)
        projected = _project_state(root, records)
        return {
            "classification": "complete",
            "identity": identity,
            "records": records,
            "nextSequence": len(records) + 1,
            "openFrontiers": list(projected["open"].values()),
            "captures": projected["captures"],
            "resources": projected["resources"],
        }
    except (AuditError, OSError, ValueError, KeyError, TypeError) as exc:
        return {
            "classification": "indeterminate",
            "reason": str(exc),
            "records": [],
            "nextSequence": None,
            "openFrontiers": [],
            "captures": {},
            "resources": {},
        }


def _append_record(
    root: Path,
    operation_kind: str,
    input_digest: str,
    declared_filenames: Sequence[str],
    completion_state: str,
    payload: Mapping[str, Any],
) -> Dict[str, Any]:
    root = Path(root).resolve()
    lock_path = root / "ledger" / "lock"
    flags = os.O_RDWR | getattr(os, "O_NOFOLLOW", 0)
    fd = os.open(str(lock_path), flags)
    try:
        fcntl.flock(fd, fcntl.LOCK_EX)
        recovered = recover_run_state(root)
        if recovered["classification"] != "complete":
            raise AuditError("ledger is indeterminate")
        records = recovered["records"]
        identity = recovered["identity"]
        previous = records[-1]["recordDigest"]
        sequence = len(records) + 1
        record = _new_record(
            identity,
            sequence,
            previous,
            operation_kind,
            input_digest,
            declared_filenames,
            completion_state,
            payload,
        )
        write_canonical_exclusive(root / "ledger" / "records" / ("%016d.json" % sequence), record)
        return record
    finally:
        try:
            fcntl.flock(fd, fcntl.LOCK_UN)
        finally:
            os.close(fd)


def frontier_start(
    root: Path,
    *,
    frontier_kind: str,
    input_digest: str,
    declared_paths: Sequence[str],
    expected_tests: Sequence[str],
    allowed_child_kinds: Sequence[str] = (),
    parent_frontier: Optional[str] = None,
    component_kind: Optional[str] = None,
    resource_id: Optional[str] = None,
    operation_class: Optional[str] = None,
) -> Dict[str, Any]:
    recovered = recover_run_state(root)
    if recovered["classification"] != "complete":
        raise AuditError("ledger is indeterminate")
    open_rows = recovered["openFrontiers"]
    if len(set(declared_paths)) != len(declared_paths):
        raise AuditError("duplicate declared path")
    if parent_frontier is None:
        if any(row.get("parentFrontierId") is None for row in open_rows):
            raise AuditError("an open peer frontier already exists")
        if frontier_kind == "local-resource":
            raise AuditError("peer disguised as child")
    else:
        parents = [row for row in open_rows if row.get("frontierId") == parent_frontier]
        if len(parents) != 1:
            raise AuditError("parent frontier absent or completed")
        parent = parents[0]
        if parent.get("frontierKind") != "task" or parent.get("parentFrontierId") is not None:
            raise AuditError("invalid child parent")
        if any(row.get("parentFrontierId") == parent_frontier for row in open_rows):
            raise AuditError("one child is already open")
        if frontier_kind != "local-resource" or declared_paths:
            raise AuditError("child repository mutation is forbidden")
        if component_kind not in parent.get("allowedChildKinds", []):
            raise AuditError("unenumerated component kind")
        if not resource_id:
            raise AuditError("resource child requires resource")
        if operation_class != "read-only-no-remote-write":
            raise AuditError("child remote-write mutation is forbidden")
    frontier_id = secrets.token_hex(16)
    return _append_record(
        root,
        "frontier-start",
        input_digest,
        list(declared_paths),
        "open",
        {
            "frontierId": frontier_id,
            "frontierKind": frontier_kind,
            "declaredPaths": list(declared_paths),
            "expectedTests": list(expected_tests),
            "allowedChildKinds": list(allowed_child_kinds),
            "parentFrontierId": parent_frontier,
            "componentKind": component_kind,
            "resourceId": resource_id,
            "operationClass": operation_class,
        },
    )


def frontier_complete(
    root: Path,
    frontier_id: str,
    *,
    input_digest: str,
    declared_paths: Sequence[str],
    outcome: str,
    resource_snapshot_digest: Optional[str] = None,
) -> Dict[str, Any]:
    recovered = recover_run_state(root)
    if recovered["classification"] != "complete":
        raise AuditError("ledger is indeterminate")
    matches = [row for row in recovered["openFrontiers"] if row.get("frontierId") == frontier_id]
    if len(matches) != 1:
        raise AuditError("exact open frontier absent")
    start = matches[0]
    if start.get("inputDigest") != input_digest:
        raise AuditError("frontier input digest mismatch")
    if start.get("declaredPaths") != list(declared_paths):
        raise AuditError("frontier declared path mismatch")
    if any(row.get("parentFrontierId") == frontier_id for row in recovered["openFrontiers"]):
        raise AuditError("frontier child is open")
    if outcome == "tainted-preserved":
        if start.get("frontierKind") != "local-resource":
            raise AuditError("tainted-preserved is resource-local only")
        if start.get("operationClass") != "read-only-no-remote-write":
            raise AuditError("tainted frontier could have remote write")
        if not isinstance(resource_snapshot_digest, str) or not re.fullmatch(r"[0-9a-f]{64}", resource_snapshot_digest):
            raise AuditError("tainted-preserved requires complete resource snapshot")
    elif outcome != "completed":
        raise AuditError("unknown frontier outcome")
    return _append_record(
        root,
        "frontier-complete",
        input_digest,
        list(declared_paths),
        outcome,
        {
            "frontierId": frontier_id,
            "frontierKind": start["frontierKind"],
            "parentFrontierId": start.get("parentFrontierId"),
            "resourceSnapshotDigest": resource_snapshot_digest,
        },
    )


def _safe_component(value: str, label: str) -> str:
    if not re.fullmatch(r"[a-z0-9][a-z0-9._-]{0,79}", value):
        raise AuditError("unsafe " + label)
    return value


def allocate_capture(root: Path, phase: str, *, frontier_id: Optional[str] = None) -> Dict[str, Any]:
    root = Path(root).resolve()
    phase = _safe_component(phase, "capture phase")
    lock_path = root / "ledger" / "lock"
    fd = os.open(str(lock_path), os.O_RDWR | getattr(os, "O_NOFOLLOW", 0))
    try:
        fcntl.flock(fd, fcntl.LOCK_EX)
        recovered = recover_run_state(root)
        if recovered["classification"] != "complete":
            raise AuditError("ledger is indeterminate")
        phase_root = root / "ledger" / "captures" / phase
        if not phase_root.exists():
            _mkdir_exclusive(phase_root)
        else:
            _ordinary_directory(phase_root, 0o700)
        sequence = recovered["nextSequence"]
        capture_id = secrets.token_hex(16)
        capture_path = phase_root / ("%016d-%s" % (sequence, capture_id))
        # The never-used generation precedes its allocation record while the
        # same ledger lock is held; a crash at this boundary is intentionally
        # an orphan/indeterminate state, never a reused directory.
        _mkdir_exclusive(capture_path)
        record = _new_record(
            recovered["identity"],
            sequence,
            recovered["records"][-1]["recordDigest"],
            "capture-allocated",
            _sha256((phase + "\0" + capture_id).encode("ascii")),
            [],
            "allocated",
            {
                "captureId": capture_id,
                "phase": phase,
                "absolutePath": str(capture_path),
                "frontierId": frontier_id,
            },
        )
        write_canonical_exclusive(root / "ledger" / "records" / ("%016d.json" % sequence), record)
        return record
    finally:
        try:
            fcntl.flock(fd, fcntl.LOCK_UN)
        finally:
            os.close(fd)


def _capture_by_id(root: Path, capture_id: str) -> Dict[str, Any]:
    recovered = recover_run_state(root)
    if recovered["classification"] != "complete":
        raise AuditError("ledger is indeterminate")
    try:
        return recovered["captures"][capture_id]
    except KeyError as exc:
        raise AuditError("unknown capture ID") from exc


def seal_capture(root: Path, capture_id: str, filenames: Sequence[str]) -> Dict[str, Any]:
    root = Path(root).resolve()
    capture = _capture_by_id(root, capture_id)
    if capture["state"] != "allocated":
        raise AuditError("capture already sealed")
    if not filenames or len(filenames) != len(set(filenames)):
        raise AuditError("capture whitelist must be nonempty and unique")
    for name in filenames:
        if not isinstance(name, str) or name in ("", ".", "..", "manifest.json") or "/" in name or "\x00" in name:
            raise AuditError("unsafe capture whitelist name")
    capture_path = Path(capture["allocation"]["absolutePath"])
    _ordinary_directory(capture_path, 0o700)
    actual = sorted(path.name for path in capture_path.iterdir())
    if actual != sorted(filenames):
        raise AuditError("capture whitelist does not equal generation members")
    entries = []
    for name in filenames:
        path = capture_path / name
        observed = _ordinary_file(path)
        payload = _read_ordinary(path, single_link=True)
        fd = os.open(str(path), os.O_RDONLY | getattr(os, "O_NOFOLLOW", 0))
        try:
            os.fsync(fd)
        finally:
            os.close(fd)
        entries.append(
            {
                "nameB64": base64.b64encode(os.fsencode(name)).decode("ascii"),
                "mode": "%04o" % stat.S_IMODE(observed.st_mode),
                "size": len(payload),
                "sha256": _sha256(payload),
            }
        )
    manifest = _self_digest_record(
        {
            "schemaVersion": "qinao.capture-manifest.v1",
            "captureId": capture_id,
            "entries": entries,
        },
        field="manifestDigest",
    )
    write_canonical_exclusive(capture_path / "manifest.json", manifest)
    _fsync_directory(capture_path)
    return _append_record(
        root,
        "capture-sealed",
        manifest["manifestDigest"],
        list(filenames),
        "sealed",
        {
            "captureId": capture_id,
            "absolutePath": str(capture_path),
            "manifestPath": str(capture_path / "manifest.json"),
            "sealDigest": manifest["manifestDigest"],
        },
    )


def allocate_resource(root: Path, resource_kind: str) -> Dict[str, Any]:
    root = Path(root).resolve()
    resource_kind = _safe_component(resource_kind, "resource kind")
    lock_path = root / "ledger" / "lock"
    fd = os.open(str(lock_path), os.O_RDWR | getattr(os, "O_NOFOLLOW", 0))
    try:
        fcntl.flock(fd, fcntl.LOCK_EX)
        recovered = recover_run_state(root)
        if recovered["classification"] != "complete":
            raise AuditError("ledger is indeterminate")
        kind_root = root / "ledger" / "resources" / resource_kind
        if not kind_root.exists():
            _mkdir_exclusive(kind_root)
        else:
            _ordinary_directory(kind_root, 0o700)
        sequence = recovered["nextSequence"]
        resource_id = secrets.token_hex(16)
        resource_path = kind_root / ("%016d-%s" % (sequence, resource_id))
        _mkdir_exclusive(resource_path)
        record = _new_record(
            recovered["identity"],
            sequence,
            recovered["records"][-1]["recordDigest"],
            "resource-allocated",
            _sha256((resource_kind + "\0" + resource_id).encode("ascii")),
            [],
            "allocated",
            {
                "resourceId": resource_id,
                "resourceKind": resource_kind,
                "absolutePath": str(resource_path),
            },
        )
        write_canonical_exclusive(root / "ledger" / "records" / ("%016d.json" % sequence), record)
        return record
    finally:
        try:
            fcntl.flock(fd, fcntl.LOCK_UN)
        finally:
            os.close(fd)


def _resource_manifest(path: Path) -> List[Dict[str, Any]]:
    _ordinary_directory(path, 0o700)
    entries: List[Dict[str, Any]] = []
    for current, directory_names, file_names in os.walk(str(path), topdown=True, followlinks=False):
        current_path = Path(current)
        directory_names.sort(key=os.fsencode)
        file_names.sort(key=os.fsencode)
        for name in directory_names:
            child = current_path / name
            observed = child.lstat()
            if not stat.S_ISDIR(observed.st_mode) or child.is_symlink():
                raise AuditError("resource symlink or special directory")
            relative = os.fsencode(str(child.relative_to(path)))
            entries.append(
                {
                    "pathB64": base64.b64encode(relative).decode("ascii"),
                    "type": "directory",
                    "mode": "%04o" % stat.S_IMODE(observed.st_mode),
                    "size": 0,
                    "sha256": None,
                }
            )
        for name in file_names:
            child = current_path / name
            observed = child.lstat()
            if child.is_symlink():
                raise AuditError("resource symlink")
            if not stat.S_ISREG(observed.st_mode):
                raise AuditError("resource special file")
            if observed.st_nlink != 1:
                raise AuditError("resource hard link surprise")
            payload = _read_ordinary(child)
            relative = os.fsencode(str(child.relative_to(path)))
            entries.append(
                {
                    "pathB64": base64.b64encode(relative).decode("ascii"),
                    "type": "file",
                    "mode": "%04o" % stat.S_IMODE(observed.st_mode),
                    "size": len(payload),
                    "sha256": _sha256(payload),
                }
            )
    entries.sort(key=lambda row: base64.b64decode(row["pathB64"]))
    return entries


def snapshot_resource(root: Path, resource_id: str, frontier_id: Optional[str]) -> Dict[str, Any]:
    root = Path(root).resolve()
    recovered = recover_run_state(root)
    if recovered["classification"] != "complete":
        raise AuditError("ledger is indeterminate")
    try:
        resource = recovered["resources"][resource_id]
    except KeyError as exc:
        raise AuditError("unknown resource ID") from exc
    if frontier_id is not None:
        matches = [row for row in recovered["openFrontiers"] if row.get("frontierId") == frontier_id]
        if len(matches) != 1 or matches[0].get("resourceId") != resource_id:
            raise AuditError("resource is not bound to exact open frontier")
    resource_path = Path(resource["allocation"]["absolutePath"])
    first = _resource_manifest(resource_path)
    second = _resource_manifest(resource_path)
    if first != second:
        raise AuditError("concurrent resource change")
    manifest = _self_digest_record(
        {
            "schemaVersion": "qinao.resource-snapshot.v1",
            "resourceId": resource_id,
            "frontierId": frontier_id,
            "entries": first,
        },
        field="snapshotDigest",
    )
    snapshot_root = root / "ledger" / "resource-snapshots" / resource_id
    if not snapshot_root.exists():
        _mkdir_exclusive(snapshot_root)
    generation = snapshot_root / ("%016d-%s" % (recovered["nextSequence"], secrets.token_hex(8)))
    _mkdir_exclusive(generation)
    write_canonical_exclusive(generation / "manifest.json", manifest)
    record = _append_record(
        root,
        "resource-snapshot",
        manifest["snapshotDigest"],
        [],
        "complete",
        {
            "resourceId": resource_id,
            "frontierId": frontier_id,
            "snapshotDigest": manifest["snapshotDigest"],
            "manifestPath": str(generation / "manifest.json"),
        },
    )
    result = dict(manifest)
    result["recordDigest"] = record["recordDigest"]
    return result


def snapshot_git_state(root: Path, frontier_id: str, adapter: Any) -> Dict[str, Any]:
    def observe() -> Mapping[str, bytes]:
        value = adapter.snapshot() if hasattr(adapter, "snapshot") else adapter()
        if not isinstance(value, Mapping):
            raise AuditError("git-state adapter returned unknown shape")
        return value

    first = observe()
    second = observe()
    if first != second:
        raise AuditError("concurrent Git state change")
    rows = []
    for key in sorted(first):
        payload = first[key]
        if not isinstance(key, str) or not isinstance(payload, bytes):
            raise AuditError("git-state adapter field type")
        rows.append({"field": key, "size": len(payload), "sha256": _sha256(payload)})
    digest = _sha256(canonical_json_bytes(rows))
    return _append_record(
        root,
        "git-state-snapshot",
        digest,
        [],
        "complete",
        {"frontierId": frontier_id, "snapshotDigest": digest, "fields": rows},
    )


def validate_controller_erratum_probes(bootstrap: Path) -> List[Dict[str, Any]]:
    bootstrap = Path(bootstrap)
    _ordinary_directory(bootstrap, 0o700)
    names = sorted(path.name for path in bootstrap.iterdir() if path.name.startswith("probe."))
    if set(names) != set(EXACT_PROBES) or len(names) != 3:
        raise AuditError("unknown probe or fourth probe")
    rows = []
    for name in EXACT_PROBES:
        probe = bootstrap / name
        observed = _ordinary_directory(probe, 0o700)
        children = list(probe.iterdir())
        if observed.st_uid != 501 or observed.st_gid != 20 or [child.name for child in children] != ["objects"]:
            raise AuditError("probe shape drift")
        objects = children[0]
        object_stat = _ordinary_directory(objects, 0o755)
        if object_stat.st_uid != 501 or object_stat.st_gid != 20 or list(objects.iterdir()):
            raise AuditError("probe shape drift")
        rows.append(
            {
                "name": name,
                "classification": "forensic-controller-erratum",
                "evidentiary": False,
                "regularFileCount": 0,
                "regularFileStreamSha256": _sha256(b""),
            }
        )
    return rows


def _parse_key_value_lines(payload: bytes) -> Dict[str, str]:
    try:
        text = payload.decode("ascii", "strict")
    except UnicodeDecodeError as exc:
        raise AuditError("non-ASCII prediction record") from exc
    if not text.endswith("\n"):
        raise AuditError("prediction record missing terminal LF")
    result: Dict[str, str] = {}
    for line in text[:-1].split("\n"):
        if not line or "=" not in line:
            raise AuditError("malformed prediction record")
        key, value = line.split("=", 1)
        if key in result:
            raise AuditError("duplicate prediction key")
        result[key] = value
    return result


def _recursive_regular_manifest(path: Path) -> List[Dict[str, Any]]:
    entries = []
    for current, directory_names, file_names in os.walk(str(path), topdown=True, followlinks=False):
        directory_names.sort(key=os.fsencode)
        file_names.sort(key=os.fsencode)
        current_path = Path(current)
        for name in directory_names:
            child = current_path / name
            if child.is_symlink() or not stat.S_ISDIR(child.lstat().st_mode):
                raise AuditError("bootstrap special directory")
        for name in file_names:
            child = current_path / name
            payload = _read_ordinary(child)
            entries.append(
                {
                    "pathB64": base64.b64encode(os.fsencode(str(child.relative_to(path)))).decode("ascii"),
                    "size": len(payload),
                    "sha256": _sha256(payload),
                }
            )
    entries.sort(key=lambda row: base64.b64decode(row["pathB64"]))
    return entries


def classify_tree_prediction_generations(
    bootstrap: Path,
    *,
    expected_tree: str,
    expected_c: str,
    erratum_digest: str,
) -> List[Dict[str, Any]]:
    bootstrap = Path(bootstrap)
    rows = []
    for generation in sorted(bootstrap.glob("tree-prediction.*"), key=lambda path: path.name):
        _ordinary_directory(generation, 0o700)
        objects = generation / "objects"
        _ordinary_directory(objects, 0o700)
        object_entries = _recursive_regular_manifest(objects)
        result_path = generation / "result.tsv"
        proof_path = generation / "alternate-reuse-proof.tsv"
        if generation.name == N34_NAME:
            expected_children = {
                "objects",
                "shared-objects.before.bin",
                "shared-objects.after.bin",
                "alternate-reuse-proof.tsv",
                "result.tsv",
            }
            if {child.name for child in generation.iterdir()} != expected_children or object_entries:
                raise AuditError("N34 empty primary shape mismatch")
            before = _read_ordinary(generation / "shared-objects.before.bin")
            after = _read_ordinary(generation / "shared-objects.after.bin")
            if before != after:
                raise AuditError("N34 shared object drift")
            shared_digest = _sha256(before)
            proof = _parse_key_value_lines(_read_ordinary(proof_path))
            required_proof = {
                "C": expected_c,
                "predicted_tree": expected_tree,
                "shared_objects_before_sha256": shared_digest,
                "shared_objects_after_sha256": shared_digest,
                "isolated_regular_file_count": "0",
                "closure_missing_count": "0",
                "controller_erratum_sha256": erratum_digest,
            }
            if proof.get("controller_erratum_sha256") != erratum_digest:
                raise AuditError("erratum digest mismatch")
            if proof != required_proof:
                raise AuditError("N34 alternate-reuse proof mismatch")
            result = _parse_key_value_lines(_read_ordinary(result_path))
            if result != {"predicted_tree": expected_tree, "shared_objects_before": shared_digest}:
                raise AuditError("N34 result mismatch")
            rows.append(
                {
                    "name": generation.name,
                    "classification": "forensic-complete-alternate-reuse",
                    "evidentiary": True,
                    "manifest": _recursive_regular_manifest(generation),
                }
            )
            continue
        if proof_path.exists() or proof_path.is_symlink():
            raise AuditError("alternate reuse proof outside N34")
        if not result_path.exists():
            rows.append(
                {
                    "name": generation.name,
                    "classification": "forensic-partial",
                    "evidentiary": False,
                    "manifest": _recursive_regular_manifest(generation),
                }
            )
            continue
        result = _parse_key_value_lines(_read_ordinary(result_path))
        if not object_entries:
            raise AuditError("empty primary outside sole post-C generation")
        if result.get("predicted_tree") != expected_tree:
            raise AuditError("prediction tree mismatch")
        rows.append(
            {
                "name": generation.name,
                "classification": "forensic-complete-primary",
                "evidentiary": True,
                "manifest": _recursive_regular_manifest(generation),
            }
        )
    return rows


def _parse_exact_ordered_rows(
    payload: bytes,
    *,
    delimiter: bytes,
    expected: Sequence[Tuple[bytes, bytes]],
    label: str,
) -> Dict[str, str]:
    if delimiter not in (b"=", b"\t"):
        raise AuditError("unsupported terminal delimiter")
    if not payload.endswith(b"\n") or b"\x00" in payload:
        raise AuditError(label + " terminal framing")
    lines = payload[:-1].split(b"\n")
    if len(lines) != len(expected):
        raise AuditError(label + " terminal row count")
    parsed: Dict[str, str] = {}
    for line, (expected_key, expected_value) in zip(lines, expected):
        if line.count(delimiter) != 1:
            raise AuditError(label + " terminal delimiter")
        key, value = line.split(delimiter, 1)
        if key != expected_key or value != expected_value:
            raise AuditError(label + " terminal key, order, or value")
        try:
            parsed[key.decode("ascii")] = value.decode("ascii")
        except UnicodeDecodeError as exc:
            raise AuditError(label + " terminal ASCII") from exc
    return parsed


def parse_task2_merge_terminal(payload: bytes) -> Dict[str, str]:
    return _parse_exact_ordered_rows(
        payload,
        delimiter=b"=",
        label="task2 merge",
        expected=(
            (b"state", b"complete"),
            (b"C", FROZEN_C.encode("ascii")),
            (b"C_TREE", FROZEN_C_TREE.encode("ascii")),
            (b"predicted_tree", FROZEN_C_TREE.encode("ascii")),
            (b"parents", (FROZEN_S + "," + FROZEN_D).encode("ascii")),
            (b"commit_raw_sha256", FROZEN_C_RAW_SHA256.encode("ascii")),
            (b"config_canonical_sha256", FROZEN_CONFIG_DIGEST.encode("ascii")),
        ),
    )


def parse_task2_resume_terminal(payload: bytes) -> Dict[str, str]:
    return _parse_exact_ordered_rows(
        payload,
        delimiter=b"=",
        label="task2 resume",
        expected=(
            (b"state", b"complete"),
            (b"classification", b"exact-live-clean-4a-no-sequencer"),
            (b"config_raw_sha256", FROZEN_RAW_CONFIG_DIGEST.encode("ascii")),
            (b"config_canonical_sha256", FROZEN_CONFIG_DIGEST.encode("ascii")),
            (b"config_keys_sha256", FROZEN_CONFIG_KEYS_DIGEST.encode("ascii")),
        ),
    )


def parse_tool_projection_terminal(payload: bytes) -> Dict[str, str]:
    return _parse_exact_ordered_rows(
        payload,
        delimiter=b"\t",
        label="tool projection",
        expected=(
            (b"schema", b"qinao.bootstrap-tool-projection-terminal.v1"),
            (b"state", b"complete"),
            (
                b"projectionSha256",
                b"226b58580f76b8712af08fd5ca845dfdf26d1c404718d7bcd1837dde551fc4ea",
            ),
            (
                b"manifestSha256",
                b"1f9f517389e2c0de314915e8313a2a8097b86a4406fa1bf763167a3dd02373c4",
            ),
        ),
    )


HISTORICAL_TERMINAL_REGISTRY: Dict[str, Dict[str, Any]] = {
    "capture.task2-merge.tL6p8x": {
        "parser": parse_task2_merge_terminal,
        "files": {
            "terminal.complete": (424, "807355b71ce44d0305ec51105871c944e25f875fdd12652e11620709600d615d"),
            "replacement-refs.tsv": (0, _sha256(b"")),
            "source-object-closure.txt": (4973795, "4b7fa97d55960b78c386ce21dd7f9678d6650ffae154652150dd3c09eb94e633"),
            "local-config-keys.txt": (4830, FROZEN_CONFIG_KEYS_DIGEST),
            "local-config.canonical": (7465, FROZEN_CONFIG_DIGEST),
            "local-config.raw": (13913, FROZEN_RAW_CONFIG_DIGEST),
            "commit.raw": (359, FROZEN_C_RAW_SHA256),
        },
    },
    "capture.task2-resume.ZbWFBk": {
        "parser": parse_task2_resume_terminal,
        "files": {
            "terminal.complete": (319, "8f276e6d14677ffc98a4096c944554a59a21b28ebf512002d754f835929a3c65"),
            "replacement-refs.tsv": (0, _sha256(b"")),
            "source-object-closure.txt": (4973795, "4b7fa97d55960b78c386ce21dd7f9678d6650ffae154652150dd3c09eb94e633"),
            "local-config-keys.txt": (4830, FROZEN_CONFIG_KEYS_DIGEST),
            "local-config.canonical": (7465, FROZEN_CONFIG_DIGEST),
            "local-config.raw": (13913, FROZEN_RAW_CONFIG_DIGEST),
        },
    },
    "capture.tool-projection.JRp96i": {
        "parser": parse_tool_projection_terminal,
        "files": {
            "terminal.complete": (228, "9a8cf44ce7c68f2cf07a9c8ec53a0711f3e72e056879b73fd600ef36950e6e4b"),
            "projection.sha256": (83, "5c07c953791a83dce476aa95f8b90155582ef494172a8a1d706f3b33232920d2"),
            "projection.before": (8242, "226b58580f76b8712af08fd5ca845dfdf26d1c404718d7bcd1837dde551fc4ea"),
            "projection.after": (8242, "226b58580f76b8712af08fd5ca845dfdf26d1c404718d7bcd1837dde551fc4ea"),
            "manifest.tsv": (443, "1f9f517389e2c0de314915e8313a2a8097b86a4406fa1bf763167a3dd02373c4"),
        },
    },
}


def validate_historical_terminal_generation(generation: Path) -> Dict[str, Any]:
    generation = Path(generation)
    _ordinary_directory(generation, 0o700)
    registry = HISTORICAL_TERMINAL_REGISTRY.get(generation.name)
    if registry is None:
        raise AuditError("structured terminal generation name drift")
    expected_files = registry["files"]
    children = {child.name: child for child in generation.iterdir()}
    if set(children) != set(expected_files):
        raise AuditError("structured terminal sibling set drift")
    manifest = []
    payloads: Dict[str, bytes] = {}
    for name in sorted(expected_files, key=os.fsencode):
        child = children[name]
        observed = _ordinary_file(child, expected_mode=0o600)
        payload = _read_ordinary(child)
        expected_size, expected_digest = expected_files[name]
        digest = _sha256(payload)
        if observed.st_size != expected_size or len(payload) != expected_size:
            raise AuditError("structured terminal sibling size drift")
        if digest != expected_digest:
            raise AuditError("structured terminal sibling digest drift")
        payloads[name] = payload
        manifest.append(
            {
                "pathB64": base64.b64encode(os.fsencode(name)).decode("ascii"),
                "size": len(payload),
                "sha256": digest,
            }
        )
    parsed = registry["parser"](payloads["terminal.complete"])
    if generation.name == "capture.task2-merge.tL6p8x":
        if (
            _sha256(payloads["commit.raw"]) != parsed["commit_raw_sha256"]
            or _sha256(payloads["local-config.canonical"])
            != parsed["config_canonical_sha256"]
        ):
            raise AuditError("task2 merge terminal cross-digest drift")
    elif generation.name == "capture.task2-resume.ZbWFBk":
        cross = {
            "config_raw_sha256": _sha256(payloads["local-config.raw"]),
            "config_canonical_sha256": _sha256(payloads["local-config.canonical"]),
            "config_keys_sha256": _sha256(payloads["local-config-keys.txt"]),
        }
        if any(parsed[key] != value for key, value in cross.items()):
            raise AuditError("task2 resume terminal cross-digest drift")
    else:
        projection_digest = parsed["projectionSha256"]
        if (
            payloads["projection.before"] != payloads["projection.after"]
            or _sha256(payloads["projection.before"]) != projection_digest
            or _sha256(payloads["manifest.tsv"]) != parsed["manifestSha256"]
        ):
            raise AuditError("tool projection terminal cross-digest drift")
        projection_rows = _parse_exact_ordered_rows(
            payloads["projection.sha256"],
            delimiter=b"\t",
            label="projection digest",
            expected=(
                (b"sha256", projection_digest.encode("ascii")),
                (b"bytes", b"8242"),
            ),
        )
        if projection_rows["bytes"] != str(len(payloads["projection.before"])):
            raise AuditError("tool projection byte cross-digest drift")
        expected_manifest = (
            b"schemaVersion\tname\tclassification\tbyteLength\tsha256\n"
            b"1\tprojection.before\tcontent\t8242\t226b58580f76b8712af08fd5ca845dfdf26d1c404718d7bcd1837dde551fc4ea\n"
            b"1\tprojection.after\tcontent\t8242\t226b58580f76b8712af08fd5ca845dfdf26d1c404718d7bcd1837dde551fc4ea\n"
            b"1\tprojection.sha256\tcontent\t83\t5c07c953791a83dce476aa95f8b90155582ef494172a8a1d706f3b33232920d2\n"
            b"1\tmanifest.tsv\tself-including\tSELF\tSELF\n"
            b"1\tterminal.complete\tlast-written-terminal\tDECLARED\tDECLARED\n"
        )
        if payloads["manifest.tsv"] != expected_manifest:
            raise AuditError("tool projection manifest grammar drift")
    return {
        "classification": "forensic-complete-structured",
        "producer": generation.name,
        "terminal": parsed,
        "manifest": manifest,
        "registryDigest": _sha256(
            canonical_json_bytes(
                {
                    "generation": generation.name,
                    "files": [
                        {
                            "name": name,
                            "size": expected_files[name][0],
                            "sha256": expected_files[name][1],
                        }
                        for name in sorted(expected_files, key=os.fsencode)
                    ],
                }
            )
        ),
    }


def collect_bootstrap_imports(
    root: Path,
    *,
    scanner_record: Path,
    expected_tree: str,
    expected_c: str,
    erratum_digest: str,
    repair_erratum_digest: Optional[str] = None,
    selected_entry_map_digest: Optional[str] = None,
) -> List[Dict[str, Any]]:
    root = Path(root).resolve()
    bootstrap = root / "bootstrap"
    _ordinary_directory(bootstrap, 0o700)
    if erratum_digest != ERRATUM_DIGEST:
        raise AuditError("controller erratum digest mismatch")
    repair_mode = (
        repair_erratum_digest is not None or selected_entry_map_digest is not None
    )
    if repair_mode and (
        repair_erratum_digest != REPAIR_ERRATUM_DIGEST
        or not isinstance(selected_entry_map_digest, str)
        or re.fullmatch(r"[0-9a-f]{64}", selected_entry_map_digest) is None
    ):
        raise AuditError("controller repair erratum or entry map digest mismatch")

    probes = validate_controller_erratum_probes(bootstrap)
    predictions = classify_tree_prediction_generations(
        bootstrap,
        expected_tree=expected_tree,
        expected_c=expected_c,
        erratum_digest=erratum_digest,
    )
    rows: List[Dict[str, Any]] = []
    for probe in probes:
        row = dict(probe)
        row["schemaVersion"] = "qinao.bootstrap-import.v1"
        row["kind"] = "controller-probe"
        row["erratumDigest"] = erratum_digest
        rows.append(_self_digest_record(row, field="bootstrapImportDigest"))
    for prediction in predictions:
        row = dict(prediction)
        row["schemaVersion"] = "qinao.bootstrap-import.v1"
        row["kind"] = "tree-prediction"
        row["erratumDigest"] = erratum_digest
        rows.append(_self_digest_record(row, field="bootstrapImportDigest"))

    supplied_scanner_record = Path(scanner_record)
    _ordinary_file(supplied_scanner_record, expected_mode=0o600)
    scanner_record = supplied_scanner_record.resolve(strict=True)
    scanner_parent = scanner_record.parent
    _ordinary_directory(scanner_parent, 0o700)
    if scanner_record.name != "secret-scan.json" or scanner_parent.parent != bootstrap:
        raise AuditError("bootstrap scanner path is outside one capture generation")
    scanner = _read_canonical_file(scanner_record)
    _verify_self_digest(scanner)
    scanner_entries = scanner.get("entries")
    if (
        scanner.get("schemaVersion") != "qinao.secret-scan-worktree.v1"
        or scanner.get("ruleSetVersion") != RULE_SET_VERSION
        or scanner.get("ruleSetDigest") != RULE_SET_DIGEST
        or scanner.get("ruleCount") != len(SECRET_RULES)
        or not isinstance(scanner.get("scannedFileCount"), int)
        or scanner.get("scannedFileCount", 0) <= 0
        or not isinstance(scanner.get("scannedByteCount"), int)
        or scanner.get("scannedByteCount", 0) <= 0
        or scanner.get("findingCount") != 0
        or scanner.get("findings") != []
        or not isinstance(scanner_entries, list)
        or scanner.get("scannedFileCount") != len(scanner_entries)
    ):
        raise AuditError("bootstrap scanner record is not a successful frozen scan")
    entry_paths = set()
    scanned_bytes = 0
    for entry in scanner_entries:
        if not isinstance(entry, dict) or set(entry) != {
            "pathB64",
            "source",
            "size",
            "sha256",
        }:
            raise AuditError("bootstrap scanner entry shape drift")
        try:
            path_bytes = base64.b64decode(entry["pathB64"], validate=True)
        except (TypeError, ValueError) as exc:
            raise AuditError("bootstrap scanner path encoding drift") from exc
        _safe_relative_bytes(path_bytes)
        if (
            path_bytes in entry_paths
            or entry["source"] not in ("index", "worktree")
            or not isinstance(entry["size"], int)
            or entry["size"] < 0
            or not isinstance(entry["sha256"], str)
            or re.fullmatch(r"[0-9a-f]{64}", entry["sha256"]) is None
        ):
            raise AuditError("bootstrap scanner entry value drift")
        entry_paths.add(path_bytes)
        scanned_bytes += entry["size"]
    if scanned_bytes != scanner["scannedByteCount"]:
        raise AuditError("bootstrap scanner byte count drift")
    selected_entries_digest = _sha256(canonical_json_bytes(scanner_entries))
    if repair_mode:
        if scanner_parent.name == HISTORICAL_SCANNER_NAME:
            raise AuditError("historical scanner cannot be selected for repair")
        if re.fullmatch(r"capture\.task3-secret\.[0-9a-f]{12}", scanner_parent.name) is None:
            raise AuditError("selected repair scanner generation name drift")
        if selected_entries_digest != selected_entry_map_digest:
            raise AuditError("selected repair scanner entry map drift")
        if any(entry["source"] != "index" for entry in scanner_entries):
            raise AuditError("selected repair scanner is not a staged clean scan")

    admitted_names = set(EXACT_PROBES)
    admitted_names.update(row["name"] for row in predictions)
    structured_seen = set()
    literal_scanner_roles = set()
    for generation in sorted(bootstrap.glob("capture.*"), key=lambda path: path.name):
        _ordinary_directory(generation, 0o700)
        admitted_names.add(generation.name)
        manifest = _recursive_regular_manifest(generation)
        names = {os.fsdecode(base64.b64decode(item["pathB64"])) for item in manifest}
        terminal_names = names & {
            "terminal.complete",
            "terminal.failed",
            "terminal.transition",
            "terminal.json",
        }
        if len(terminal_names) > 1:
            raise AuditError("bootstrap diagnostic has multiple terminal records")
        classification = "forensic-partial"
        selected = False
        extra_fields: Dict[str, Any] = {}
        if terminal_names == {"terminal.complete"}:
            terminal_payload = _read_ordinary(generation / "terminal.complete")
            if generation.name in HISTORICAL_TERMINAL_REGISTRY:
                structured = validate_historical_terminal_generation(generation)
                structured_seen.add(generation.name)
                classification = structured["classification"]
                extra_fields.update(
                    {
                        "producerTerminal": structured["terminal"],
                        "producerRegistryDigest": structured["registryDigest"],
                    }
                )
            elif terminal_payload == b"complete\n":
                if repair_mode and generation.name == HISTORICAL_SCANNER_NAME:
                    if set(names) != {"secret-scan.json", "terminal.complete"}:
                        raise AuditError("historical scanner sibling set drift")
                    historical_terminal = generation / "terminal.complete"
                    historical_record_path = generation / "secret-scan.json"
                    if (
                        _ordinary_file(historical_terminal, expected_mode=0o600).st_size != 9
                        or _sha256(terminal_payload) != SCANNER_TERMINAL_SHA256
                        or _ordinary_file(historical_record_path, expected_mode=0o600).st_size
                        != 2453270
                        or _sha256(_read_ordinary(historical_record_path))
                        != HISTORICAL_SCANNER_RECORD_SHA256
                    ):
                        raise AuditError("historical scanner generation drift")
                    historical_scanner = _read_canonical_file(historical_record_path)
                    _verify_self_digest(historical_scanner)
                    if (
                        historical_scanner.get("recordDigest")
                        != HISTORICAL_SCANNER_RECORD_DIGEST
                        or historical_scanner.get("ruleSetDigest") != RULE_SET_DIGEST
                        or historical_scanner.get("ruleCount") != len(SECRET_RULES)
                        or historical_scanner.get("scannedFileCount") != 10436
                        or historical_scanner.get("scannedByteCount") != 290972359
                        or historical_scanner.get("findingCount") != 0
                        or historical_scanner.get("findings") != []
                    ):
                        raise AuditError("historical scanner record drift")
                    classification = "bootstrap-secret-scan-prior-complete"
                    literal_scanner_roles.add("historical")
                    extra_fields.update(
                        {
                            "selected": False,
                            "scannerRecordDigest": historical_scanner["recordDigest"],
                            "scannerRecordSha256": HISTORICAL_SCANNER_RECORD_SHA256,
                            "scannerEntryMapDigest": _sha256(
                                canonical_json_bytes(historical_scanner["entries"])
                            ),
                            "ruleSetDigest": historical_scanner["ruleSetDigest"],
                            "scannedFileCount": historical_scanner["scannedFileCount"],
                            "scannedByteCount": historical_scanner["scannedByteCount"],
                        }
                    )
                elif generation == scanner_parent:
                    classification = "bootstrap-secret-scan-complete"
                    selected = True
                    literal_scanner_roles.add("selected")
                    extra_fields.update(
                        {
                            "selected": True,
                            "scannerRecordDigest": scanner["recordDigest"],
                            "scannerRecordSha256": _sha256(_read_ordinary(scanner_record)),
                            "scannerEntryMapDigest": selected_entries_digest,
                            "ruleSetDigest": scanner["ruleSetDigest"],
                            "scannedFileCount": scanner["scannedFileCount"],
                            "scannedByteCount": scanner["scannedByteCount"],
                        }
                    )
                else:
                    raise AuditError("literal complete marker outside scanner role")
            else:
                raise AuditError("bootstrap complete terminal drift")
        elif terminal_names == {"terminal.failed"}:
            if _read_ordinary(generation / "terminal.failed") != b"failed\n":
                raise AuditError("bootstrap failed terminal drift")
            classification = "forensic-complete-failed"
        elif terminal_names == {"terminal.transition"}:
            transition = _read_canonical_file(generation / "terminal.transition")
            _verify_self_digest(transition)
            invocation_path = generation / "invocation.json"
            invocation_record = _read_canonical_file(invocation_path)
            _verify_self_digest(invocation_record)
            if (
                set(names) != {"invocation.json", "terminal.transition"}
                or transition.get("schemaVersion") != "qinao.bootstrap-init-transition.v1"
                or transition.get("invocationDigest") != invocation_record.get("recordDigest")
                or invocation_record.get("schemaVersion") != "qinao.sterile-invocation.v1"
            ):
                raise AuditError("bootstrap init transition drift")
            if generation.name == PRESERVED_TRANSITION_NAME and (
                _sha256(_read_ordinary(generation / "terminal.transition"))
                != PRESERVED_TRANSITION_SHA256
                or _sha256(_read_ordinary(invocation_path))
                != PRESERVED_TRANSITION_INVOCATION_SHA256
            ):
                raise AuditError("preserved bootstrap init transition drift")
            classification = "forensic-init-transition"
        elif terminal_names == {"terminal.json"}:
            terminal = _read_canonical_file(generation / "terminal.json")
            _verify_self_digest(terminal)
            if (
                terminal.get("schemaVersion")
                != "qinao.bootstrap-invocation-terminal.v1"
                or not isinstance(terminal.get("exitCode"), int)
            ):
                raise AuditError("bootstrap invocation terminal drift")
            classification = (
                "forensic-complete"
                if terminal["exitCode"] == 0
                else "forensic-complete-failed"
            )

        if generation == scanner_parent and not selected:
            raise AuditError("selected bootstrap scanner is not the selected terminal role")
        row = {
            "schemaVersion": "qinao.bootstrap-import.v1",
            "kind": "bootstrap-diagnostic",
            "name": generation.name,
            "classification": classification,
            "evidentiary": classification
            in (
                "forensic-complete",
                "forensic-complete-structured",
                "bootstrap-secret-scan-prior-complete",
                "bootstrap-secret-scan-complete",
            ),
            "manifest": manifest,
            "erratumDigest": erratum_digest,
        }
        if repair_mode:
            row["repairErratumDigest"] = repair_erratum_digest
        row.update(extra_fields)
        rows.append(_self_digest_record(row, field="bootstrapImportDigest"))

    observed_names = {child.name for child in bootstrap.iterdir()}
    if observed_names != admitted_names:
        raise AuditError(
            "unexpected bootstrap generation: "
            + ",".join(sorted(observed_names - admitted_names))
        )
    if scanner_parent.name not in admitted_names:
        raise AuditError("selected bootstrap scanner was not imported")
    if repair_mode:
        if structured_seen != set(HISTORICAL_TERMINAL_REGISTRY):
            raise AuditError("historical structured terminal registry incomplete")
        if literal_scanner_roles != {"historical", "selected"}:
            raise AuditError("scanner role set drift")
        if PRESERVED_TRANSITION_NAME not in admitted_names:
            raise AuditError("preserved bootstrap transition absent")
    rows.sort(key=lambda row: row["name"])
    return rows


SECRET_RULES = (
    ("github-classic-token", re.compile(rb"ghp_[A-Za-z0-9]{20,}")),
    ("github-fine-grained-token", re.compile(rb"github_pat_[A-Za-z0-9_]{20,}")),
    ("aws-access-key", re.compile(rb"AKIA[0-9A-Z]{16}")),
    ("private-key", re.compile(rb"-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----")),
    ("credential-assignment", re.compile(rb"(?i)(?:password|passwd|api[_-]?key|access[_-]?token)\s*[:=]\s*(['\"])[A-Za-z0-9_./+=-]{16,}\1")),
    ("connection-string", re.compile(rb"(?i)(?:postgres|mysql|mongodb(?:\+srv)?)://[^\s/@:]+:[^\s/@]+@")),
    ("private-marker", re.compile(rb"(?i)(?:temp_clone_token|private_transcript|unredacted_recovery)\s*[:=]")),
)
RULE_SET_DIGEST = _sha256(
    canonical_json_bytes(
        {
            "version": RULE_SET_VERSION,
            "rules": [{"id": rule_id, "patternSha256": _sha256(regex.pattern)} for rule_id, regex in SECRET_RULES],
        }
    )
)


def _safe_relative_bytes(path_bytes: bytes) -> Path:
    if not path_bytes or b"\x00" in path_bytes or path_bytes.startswith(b"/"):
        raise AuditError("unsafe relative path")
    parts = path_bytes.split(b"/")
    if any(part in (b"", b".", b"..") for part in parts):
        raise AuditError("path escape")
    return Path(os.fsdecode(path_bytes))


def _scan_payload(path_bytes: bytes, payload: bytes) -> List[Dict[str, Any]]:
    findings = []
    for rule_id, expression in SECRET_RULES:
        for match in expression.finditer(payload):
            findings.append(
                {
                    "ruleId": rule_id,
                    "pathB64": base64.b64encode(path_bytes).decode("ascii"),
                    "fileSha256": _sha256(payload),
                    "offset": match.start(),
                    "length": match.end() - match.start(),
                }
            )
    return findings


def secret_scan_worktree_selection(
    index_entries: Mapping[bytes, bytes],
    repository: Path,
    declared_paths: Sequence[bytes],
    actual_dirty_paths: Sequence[bytes],
) -> Dict[str, Any]:
    repository = Path(repository).resolve()
    declared = list(declared_paths)
    actual = list(actual_dirty_paths)
    if len(set(declared)) != len(declared) or len(set(actual)) != len(actual):
        raise AuditError("duplicate dirty path")
    if not set(actual).issubset(set(declared)):
        raise AuditError("undeclared dirty path")
    selected: List[Tuple[bytes, bytes, str]] = []
    for path_bytes in sorted(index_entries):
        payload = index_entries[path_bytes]
        if not isinstance(path_bytes, bytes) or not isinstance(payload, bytes):
            raise AuditError("index selection type")
        _safe_relative_bytes(path_bytes)
        selected.append((path_bytes, payload, "index"))
    for path_bytes in sorted(actual):
        relative = _safe_relative_bytes(path_bytes)
        absolute = repository / relative
        if repository not in absolute.resolve(strict=False).parents:
            raise AuditError("path escape")
        payload = _read_ordinary(absolute, maximum=64 * 1024 * 1024)
        selected.append((path_bytes, payload, "worktree"))
    if not selected:
        raise AuditError("zero selection")
    findings = []
    entries = []
    for path_bytes, payload, source in selected:
        findings.extend(_scan_payload(path_bytes, payload))
        entries.append(
            {
                "pathB64": base64.b64encode(path_bytes).decode("ascii"),
                "source": source,
                "size": len(payload),
                "sha256": _sha256(payload),
            }
        )
    record = _self_digest_record(
        {
            "schemaVersion": "qinao.secret-scan-worktree.v1",
            "ruleSetVersion": RULE_SET_VERSION,
            "ruleSetDigest": RULE_SET_DIGEST,
            "ruleCount": len(SECRET_RULES),
            "scannedFileCount": len(selected),
            "scannedByteCount": sum(len(payload) for _, payload, _ in selected),
            "findingCount": len(findings),
            "entries": entries,
            "findings": findings,
        }
    )
    if findings:
        raise SecretScanError(
            "secret scan hit: redacted finding count %d" % len(findings),
            record,
        )
    return record


def validate_python_entrypoint_stream(
    blobs: Mapping[bytes, bytes],
    *,
    mode: str,
    debt_callers: Sequence[bytes] = (),
) -> Dict[str, Any]:
    if mode not in ("at-C", "final-H"):
        raise AuditError("unknown scanner mode")
    executable = 0
    debt = 0
    for path, payload in blobs.items():
        if payload in (LOCAL_PYTHON_LAUNCHER, CI_PYTHON_PREFIX, BOOTSTRAP_TEST_COMMAND):
            executable += 1
            continue
        if (
            path == HISTORICAL_DEBT_PATH
            and _sha256(payload) == HISTORICAL_DEBT_SHA256
        ):
            if mode == "final-H":
                raise AuditError("migration debt remains at final H")
            if tuple(debt_callers) != HISTORICAL_DEBT_CALLERS:
                raise AuditError("historical migration debt caller set drift")
            debt += 1
            continue
        if b"python3" in payload or b"/usr/bin/python" in payload:
            raise AuditError("unreviewed raw Python executable entry")
    if debt == 0 and debt_callers:
        raise AuditError("migration debt callers supplied without exact debt")
    caller_stream = (
        b"\x00".join(HISTORICAL_DEBT_CALLERS) + b"\x00"
        if debt
        else b""
    )
    return {
        "executableEntrypointCount": executable,
        "migrationDebtCount": debt,
        "migrationDebtBlobSha256": HISTORICAL_DEBT_SHA256 if debt else None,
        "migrationDebtCallerDigest": _sha256(caller_stream),
        "scannedBlobCount": len(blobs),
    }


def validate_plan_fence_stream(blobs: Mapping[bytes, bytes]) -> Dict[str, Any]:
    checked = 0
    sterile = b"/usr/bin/env -i \\\n  HOME=/nonexistent LANG=C LC_ALL=C PATH=/usr/bin:/bin \\\n  /bin/bash --noprofile --norc -s -- qinao-plan-step"
    for payload in blobs.values():
        for match in re.finditer(rb"```(?:bash|sh)\n(.*?)```", payload, re.DOTALL):
            checked += 1
            body = match.group(1)
            if (b"python" in body or b"qinao_python" in body) and sterile not in body:
                raise AuditError("plan fence is not rooted in sterile outer shell")
    return {"checkedFenceCount": checked}


FORBIDDEN_ENVIRONMENT = {
    "BASH_ENV",
    "ENV",
    "CDPATH",
    "SHELLOPTS",
    "PYTHONHOME",
    "PYTHONPATH",
    "PYTHONSTARTUP",
    "PYTHONINSPECT",
    "PYTHONWARNINGS",
    "PYTHONBREAKPOINT",
    "SSL_CERT_FILE",
    "SSL_CERT_DIR",
    "SSLKEYLOGFILE",
    "REQUESTS_CA_BUNDLE",
    "CURL_CA_BUNDLE",
    "GIT_SSL_CAINFO",
    "HTTP_PROXY",
    "HTTPS_PROXY",
    "ALL_PROXY",
    "NO_PROXY",
    "http_proxy",
    "https_proxy",
    "all_proxy",
    "no_proxy",
    "GH_TOKEN",
    "GITHUB_TOKEN",
}
# Apple's /usr/bin/python3 launcher deterministically projects these four
# CommandLineTools fields after the outer env-i boundary.  They are recorded
# and path-validated below; callers still cannot supply arbitrary values.
INTERPRETER_INJECTED_ENVIRONMENT = {"CPATH", "LIBRARY_PATH", "MANPATH", "SDKROOT"}
ALLOWED_STERILE_ENVIRONMENT = {
    "HOME",
    "TMPDIR",
    "LANG",
    "LC_ALL",
    "PATH",
    "__CF_USER_TEXT_ENCODING",
} | INTERPRETER_INJECTED_ENVIRONMENT


def _hash_path_projection(path: Path, *, suffixes: Optional[Tuple[str, ...]] = None) -> str:
    hasher = hashlib.sha256()
    if not path.exists() and not path.is_symlink():
        hasher.update(b"absent\x00" + os.fsencode(str(path)))
        return hasher.hexdigest()
    if path.is_file() and not path.is_symlink():
        hasher.update(os.fsencode(str(path)) + b"\x00" + _read_ordinary(path, maximum=256 * 1024 * 1024, single_link=False))
        return hasher.hexdigest()
    for current, directory_names, file_names in os.walk(str(path), topdown=True, followlinks=False):
        directory_names.sort(key=os.fsencode)
        file_names.sort(key=os.fsencode)
        current_path = Path(current)
        for name in directory_names + file_names:
            child = current_path / name
            relative = os.fsencode(str(child.relative_to(path)))
            observed = child.lstat()
            if stat.S_ISLNK(observed.st_mode):
                hasher.update(relative + b"\x00L\x00" + os.fsencode(os.readlink(child)) + b"\x00")
            elif stat.S_ISDIR(observed.st_mode):
                hasher.update(relative + b"\x00D\x00" + ("%o" % stat.S_IMODE(observed.st_mode)).encode() + b"\x00")
            elif stat.S_ISREG(observed.st_mode):
                if suffixes is not None and not name.endswith(suffixes):
                    continue
                payload = _read_ordinary(child, maximum=256 * 1024 * 1024, single_link=False)
                hasher.update(relative + b"\x00F\x00" + str(len(payload)).encode() + b"\x00" + hashlib.sha256(payload).digest())
            else:
                raise AuditError("special runtime path")
    return hasher.hexdigest()


def sterile_runtime_projection() -> Dict[str, Any]:
    import ssl

    executable = Path("/usr/bin/python3")
    stdlib = Path(sysconfig.get_path("stdlib")).resolve()
    ssl_module = Path(ssl.__file__).resolve()
    default_paths = ssl.get_default_verify_paths()
    ca_hasher = hashlib.sha256()
    for value in (
        default_paths.cafile,
        default_paths.capath,
        default_paths.openssl_cafile_env,
        default_paths.openssl_cafile,
        default_paths.openssl_capath_env,
        default_paths.openssl_capath,
    ):
        ca_hasher.update((value or "<none>").encode("utf-8") + b"\x00")
    for candidate in (default_paths.cafile, default_paths.capath):
        if candidate:
            ca_hasher.update(bytes.fromhex(_hash_path_projection(Path(candidate))))
    openssl_hasher = hashlib.sha256()
    openssl_hasher.update(ssl.OPENSSL_VERSION.encode("utf-8") + b"\x00")
    openssl_hasher.update(bytes.fromhex(_hash_path_projection(ssl_module)))
    return {
        "executable": "/usr/bin/python3",
        "pythonVersion": sys.version,
        "interpreterSha256": _hash_path_projection(executable),
        "stdlibPath": str(stdlib),
        "stdlibDigest": _hash_path_projection(stdlib, suffixes=(".py", ".so", ".dylib")),
        "opensslVersion": ssl.OPENSSL_VERSION,
        "opensslDigest": openssl_hasher.hexdigest(),
        "defaultCADigest": ca_hasher.hexdigest(),
    }


def validate_sterile_target(argv: Sequence[str], *, profile: str) -> None:
    if profile not in ("bootstrap", "ledger", "ci"):
        raise AuditError("unknown sterile profile")
    if list(argv) == ["bootstrap-self-test"] and profile == "bootstrap":
        return
    if len(argv) >= 3 and argv[0:2] == ["-m", "unittest"]:
        if all(argument not in ("-c", "-") for argument in argv):
            return
    closed_commands = {
        "init-run-state",
        "allocate-capture",
        "seal-capture",
        "allocate-resource",
        "snapshot-resource",
        "snapshot-git-state",
        "frontier-start",
        "frontier-complete",
        "recover-captures",
        "secret-scan-worktree",
    }
    if argv and argv[0] in closed_commands:
        return
    raise AuditError("closed target mode required")


def _tracked_repository_paths(repository: Path) -> set:
    environment = {
        "HOME": "/nonexistent",
        "LANG": "C",
        "LC_ALL": "C",
        "PATH": "/usr/bin:/bin",
        "GIT_CONFIG_GLOBAL": "/dev/null",
        "GIT_CONFIG_SYSTEM": "/dev/null",
        "GIT_NO_REPLACE_OBJECTS": "1",
        "GIT_NO_LAZY_FETCH": "1",
        "GIT_OPTIONAL_LOCKS": "0",
        "GIT_TERMINAL_PROMPT": "0",
        "GIT_LFS_SKIP_SMUDGE": "1",
    }
    result = subprocess.run(
        [
            "/usr/bin/git",
            "--no-pager",
            "--no-optional-locks",
            "--no-replace-objects",
            "-c",
            "core.hooksPath=/dev/null",
            "-C",
            str(repository),
            "ls-files",
            "-z",
        ],
        env=environment,
        stdin=subprocess.DEVNULL,
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        check=False,
    )
    if result.returncode != 0:
        return set()
    return set(part for part in result.stdout.split(b"\x00") if part)


def _validate_import_inventory(repository: Path) -> Dict[str, Any]:
    repository = repository.resolve()
    tracked = _tracked_repository_paths(repository)
    admitted_untracked = {
        b"scripts/qinao_convergence_audit.py",
        b"scripts/test_qinao_convergence_audit.py",
    }
    artifacts = []
    sources = 0
    for current, directory_names, file_names in os.walk(str(repository), topdown=True, followlinks=False):
        directory_names[:] = sorted(
            [name for name in directory_names if name not in (".git", ".build", "DerivedData")],
            key=os.fsencode,
        )
        for name in sorted(file_names, key=os.fsencode):
            child = Path(current) / name
            if child.is_symlink():
                raise AuditError("undeclared import artifact: symlink")
            relative = os.fsencode(str(child.relative_to(repository)))
            lowered = name.lower()
            if lowered.endswith((".pyc", ".pyo", ".pth", ".egg", ".zip")) or name in ("sitecustomize.py", "usercustomize.py") or name == "__pycache__":
                raise AuditError("undeclared import artifact: " + os.fsdecode(relative))
            if lowered.endswith(".py"):
                sources += 1
                if relative not in tracked and relative not in admitted_untracked:
                    raise AuditError("undeclared import artifact: " + os.fsdecode(relative))
            artifacts.append(relative)
    return {
        "candidateFileCount": len(artifacts),
        "pythonSourceCount": sources,
        "trackedPathDigest": _sha256(b"\x00".join(sorted(tracked)) + (b"\x00" if tracked else b"")),
    }


def _bootstrap_invocation_start(root: Path, record: Mapping[str, Any]) -> Path:
    diagnostic = root / "bootstrap" / ("capture.sterile-python." + secrets.token_hex(6))
    _mkdir_exclusive(diagnostic)
    write_canonical_exclusive(diagnostic / "invocation.json", record)
    return diagnostic


def _bootstrap_init_transition(root: Path, record: Mapping[str, Any]) -> Path:
    diagnostic = root / "bootstrap" / ("capture.sterile-python." + secrets.token_hex(6))
    _mkdir_exclusive(diagnostic)
    write_canonical_exclusive(diagnostic / "invocation.json", record)
    terminal = _self_digest_record(
        {
            "schemaVersion": "qinao.bootstrap-init-transition.v1",
            "invocationDigest": record["recordDigest"],
        }
    )
    write_canonical_exclusive(diagnostic / "terminal.transition", terminal)
    return diagnostic


def _bootstrap_invocation_finish(diagnostic: Path, exit_code: int) -> None:
    terminal = _self_digest_record(
        {
            "schemaVersion": "qinao.bootstrap-invocation-terminal.v1",
            "exitCode": exit_code,
        }
    )
    write_canonical_exclusive(diagnostic / "terminal.json", terminal)


def _bootstrap_invocation_finish_if_needed(
    diagnostic: Path,
    *,
    exit_code: int,
    is_init_transition: bool,
) -> None:
    if not is_init_transition:
        _bootstrap_invocation_finish(diagnostic, exit_code)


def _load_test_module(repository: Path):
    path = repository / "scripts" / "test_qinao_convergence_audit.py"
    _ordinary_file(path)
    spec = importlib.util.spec_from_file_location("scripts.test_qinao_convergence_audit", str(path))
    if spec is None or spec.loader is None:
        raise AuditError("test module loader unavailable")
    loaded = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = loaded
    spec.loader.exec_module(loaded)
    return loaded


def _run_unittest_target(repository: Path, argv: Sequence[str]) -> int:
    import unittest

    if argv[0:2] != ["-m", "unittest"]:
        raise AuditError("closed unittest shape")
    remaining = list(argv[2:])
    verbosity = 2 if "-v" in remaining else 1
    remaining = [item for item in remaining if item != "-v"]
    if not remaining:
        raise AuditError("unittest target missing")
    loaded = _load_test_module(repository)
    prefix = "scripts.test_qinao_convergence_audit"
    suite = unittest.TestSuite()
    loader = unittest.TestLoader()
    for target in remaining:
        if target == prefix:
            suite.addTests(loader.loadTestsFromModule(loaded))
        elif target.startswith(prefix + "."):
            suite.addTests(loader.loadTestsFromName(target[len(prefix) + 1 :], loaded))
        else:
            raise AuditError("unapproved unittest target")
    result = unittest.TextTestRunner(verbosity=verbosity).run(suite)
    return 0 if result.wasSuccessful() and result.testsRun > 0 else 1


def _sterile_python(argv: Sequence[str]) -> int:
    global _CURRENT_STERILE_INVOCATION
    parser = argparse.ArgumentParser(prog="sterile-python")
    parser.add_argument("--root", required=True)
    parser.add_argument("--repository", required=True)
    parser.add_argument("--profile", choices=("bootstrap", "ledger", "ci"))
    parser.add_argument("--ci-runner-home")
    parser.add_argument("target", nargs=argparse.REMAINDER)
    options = parser.parse_args(list(argv))
    target = list(options.target)
    if target and target[0] == "--":
        target = target[1:]
    forbidden = sorted(set(os.environ) & FORBIDDEN_ENVIRONMENT)
    undeclared = sorted(set(os.environ) - ALLOWED_STERILE_ENVIRONMENT)
    if forbidden or undeclared:
        raise AuditError("forbidden environment fields: " + ",".join(forbidden + undeclared))
    if os.environ.get("PATH") != "/usr/bin:/bin" or os.environ.get("LANG") != "C" or os.environ.get("LC_ALL") != "C":
        raise AuditError("sterile environment value drift")
    resolved_executable = Path(sys.executable).resolve()
    admitted_executable_roots = (
        Path("/Library/Developer/CommandLineTools"),
        Path("/Applications/Xcode.app/Contents/Developer"),
        Path("/Applications/Xcode-beta.app/Contents/Developer"),
    )
    if not resolved_executable.is_absolute() or not any(
        root == resolved_executable or root in resolved_executable.parents
        for root in admitted_executable_roots
    ):
        raise AuditError("interpreter path drift")
    flags = {
        "isolated": int(sys.flags.isolated),
        "ignoreEnvironment": int(sys.flags.ignore_environment),
        "noSite": int(sys.flags.no_site),
        "noUserSite": int(sys.flags.no_user_site),
        "dontWriteBytecode": int(sys.flags.dont_write_bytecode),
    }
    if flags != {"isolated": 1, "ignoreEnvironment": 1, "noSite": 1, "noUserSite": 1, "dontWriteBytecode": 1}:
        raise AuditError("interpreter flag drift")
    root = Path(options.root).resolve()
    repository = Path(options.repository).resolve()
    _validate_run_root(root)
    if str(repository) in sys.path or str(repository / "scripts") in sys.path:
        raise AuditError("repository path entered generic sys.path")
    profile = options.profile or ("ledger" if (root / "ledger").is_dir() else "bootstrap")
    if profile == "ci" and not options.ci_runner_home:
        raise AuditError("CI profile requires runner home")
    if profile != "ci" and options.ci_runner_home:
        raise AuditError("runner home forbidden outside CI")
    validate_sterile_target(target, profile=profile)
    inventory = _validate_import_inventory(repository)
    runtime = sterile_runtime_projection()
    invocation = _self_digest_record(
        {
            "schemaVersion": "qinao.sterile-invocation.v1",
            "profile": profile,
            "argv": target,
            "repository": str(repository),
            "runtime": runtime,
            "flags": flags,
            "sysPath": list(sys.path),
            "importInventory": inventory,
        }
    )
    _CURRENT_STERILE_INVOCATION = invocation
    diagnostic: Optional[Path] = None
    is_init_transition = (
        profile == "bootstrap"
        and bool(target)
        and target[0] == "init-run-state"
    )
    if profile == "bootstrap":
        diagnostic = (
            _bootstrap_init_transition(root, invocation)
            if is_init_transition
            else _bootstrap_invocation_start(root, invocation)
        )
    else:
        _append_record(
            root,
            "sterile-invocation-started",
            invocation["recordDigest"],
            [],
            "open",
            {"invocation": invocation},
        )
    exit_code = 2
    try:
        if target == ["bootstrap-self-test"]:
            output = _self_digest_record(
                {
                    "schemaVersion": "qinao.sterile-python.v1",
                    "profile": profile,
                    "flags": flags,
                    "sysPath": list(sys.path),
                    "runtime": runtime,
                    "importInventory": inventory,
                }
            )
            sys.stdout.buffer.write(canonical_json_bytes(output))
            sys.stdout.buffer.flush()
            exit_code = 0
        elif target[0:2] == ["-m", "unittest"]:
            exit_code = _run_unittest_target(repository, target)
        else:
            exit_code = _dispatch_command(target)
        return exit_code
    finally:
        if diagnostic is not None:
            _bootstrap_invocation_finish_if_needed(
                diagnostic,
                exit_code=exit_code,
                is_init_transition=is_init_transition,
            )
        elif profile != "bootstrap":
            _append_record(
                root,
                "sterile-invocation-completed",
                invocation["recordDigest"],
                [],
                "complete" if exit_code == 0 else "failed",
                {"invocationDigest": invocation["recordDigest"], "exitCode": exit_code},
            )


def _run_git(repository: Path, arguments: Sequence[str], *, input_bytes: bytes = b"") -> bytes:
    environment = {
        "HOME": "/nonexistent",
        "LANG": "C",
        "LC_ALL": "C",
        "PATH": "/usr/bin:/bin",
        "GIT_CONFIG_GLOBAL": "/dev/null",
        "GIT_CONFIG_SYSTEM": "/dev/null",
        "GIT_NO_REPLACE_OBJECTS": "1",
        "GIT_NO_LAZY_FETCH": "1",
        "GIT_OPTIONAL_LOCKS": "0",
        "GIT_TERMINAL_PROMPT": "0",
        "GIT_LFS_SKIP_SMUDGE": "1",
        "GIT_PAGER": "cat",
    }
    command = [
        "/usr/bin/git",
        "--no-pager",
        "--no-optional-locks",
        "--no-replace-objects",
        "-c",
        "core.hooksPath=/dev/null",
        "-c",
        "core.fsmonitor=false",
        "-c",
        "diff.external=",
        "-c",
        "filter.lfs.clean=",
        "-c",
        "filter.lfs.smudge=",
        "-c",
        "filter.lfs.process=",
        "-c",
        "filter.lfs.required=false",
        "-C",
        str(repository),
    ] + list(arguments)
    result = subprocess.run(
        command,
        env=environment,
        input=input_bytes,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    if result.returncode != 0:
        raise AuditError("local Git command failed: " + " ".join(arguments))
    if len(result.stdout) > 256 * 1024 * 1024:
        raise AuditError("local Git output exceeds bound")
    return result.stdout


def _ascii_git_line(repository: Path, arguments: Sequence[str], label: str) -> str:
    payload = _run_git(repository, arguments)
    try:
        value = payload.decode("ascii", "strict")
    except UnicodeDecodeError as exc:
        raise AuditError(label + " is not ASCII") from exc
    if not value.endswith("\n") or "\n" in value[:-1] or not value[:-1]:
        raise AuditError(label + " is not one line")
    return value[:-1]


def _build_convergence_bootstrap_context(
    repository: Path,
) -> Tuple[Dict[str, Any], List[Dict[str, Any]]]:
    repository = Path(repository).resolve()
    if str(repository) != FROZEN_WT:
        raise AuditError("convergence repository path drift")
    branch = _ascii_git_line(repository, ["symbolic-ref", "-q", "HEAD"], "branch")
    if branch != FROZEN_BRANCH:
        raise AuditError("convergence branch drift")
    head = _ascii_git_line(repository, ["rev-parse", "HEAD"], "HEAD")
    if not re.fullmatch(r"[0-9a-f]{40}", head) or head in (
        FROZEN_C,
        BOOTSTRAP_IMPLEMENTATION_COMMIT,
    ):
        raise AuditError("bootstrap repair commit absent")
    parents = _ascii_git_line(
        repository,
        ["rev-list", "--parents", "-n", "1", head],
        "bootstrap repair parents",
    ).split(" ")
    if parents != [head, BOOTSTRAP_IMPLEMENTATION_COMMIT]:
        raise AuditError("bootstrap repair commit parent drift")
    b1_tree = _ascii_git_line(
        repository,
        ["rev-parse", head + "^{tree}"],
        "bootstrap repair tree",
    )
    b0_raw = _run_git(
        repository,
        ["cat-file", "commit", BOOTSTRAP_IMPLEMENTATION_COMMIT],
    )
    b1_raw = _run_git(repository, ["cat-file", "commit", head])
    b0_changed = [
        item
        for item in _run_git(
            repository,
            [
                "diff-tree",
                "--no-commit-id",
                "--name-only",
                "-z",
                "-r",
                FROZEN_C,
                BOOTSTRAP_IMPLEMENTATION_COMMIT,
            ],
        ).split(b"\x00")
        if item
    ]
    b1_changed = [
        item
        for item in _run_git(
            repository,
            [
                "diff-tree",
                "--no-commit-id",
                "--name-only",
                "-z",
                "-r",
                BOOTSTRAP_IMPLEMENTATION_COMMIT,
                head,
            ],
        ).split(b"\x00")
        if item
    ]
    chain = validate_preledger_commit_chain(
        b0_oid=BOOTSTRAP_IMPLEMENTATION_COMMIT,
        b0_payload=b0_raw,
        b1_oid=head,
        b1_payload=b1_raw,
        b0_changed_paths=b0_changed,
        b1_changed_paths=b1_changed,
    )
    for path in TASK3_TRACKED_PATHS:
        before = _run_git(
            repository,
            ["ls-tree", "-z", BOOTSTRAP_IMPLEMENTATION_COMMIT, "--", os.fsdecode(path)],
        )
        after = _run_git(repository, ["ls-tree", "-z", head, "--", os.fsdecode(path)])
        if not before or not after or before.split(b" ", 1)[0] != after.split(b" ", 1)[0]:
            raise AuditError("bootstrap repair path deletion, rename, or mode drift")
    if _run_git(
        repository,
        ["status", "--porcelain=v2", "-z", "--untracked-files=all"],
    ):
        raise AuditError("bootstrap worktree is not clean")
    if _ascii_git_line(
        repository,
        ["rev-parse", FROZEN_C + "^{tree}"],
        "C tree",
    ) != FROZEN_C_TREE:
        raise AuditError("C tree drift")
    if _ascii_git_line(
        repository,
        ["rev-list", "--parents", "-n", "1", FROZEN_C],
        "C parents",
    ).split(" ") != [FROZEN_C, FROZEN_S, FROZEN_D]:
        raise AuditError("C parent drift")
    c_raw = _run_git(repository, ["cat-file", "commit", FROZEN_C])
    if _sha256(c_raw) != FROZEN_C_RAW_SHA256:
        raise AuditError("C raw commit drift")
    if _ascii_git_line(
        repository,
        ["rev-parse", "--show-object-format"],
        "object format",
    ) != "sha1":
        raise AuditError("object format drift")
    raw_config = _run_git(
        repository,
        ["config", "--local", "--no-includes", "--null", "--show-origin", "--list"],
    )
    if _sha256(raw_config) != FROZEN_RAW_CONFIG_DIGEST:
        raise AuditError("local config raw digest drift")
    replacements = _run_git(
        repository,
        ["for-each-ref", "--format=%(refname)", "refs/replace/"],
    )
    if replacements:
        raise AuditError("replacement refs present")
    closure = _run_git(
        repository,
        [
            "rev-list",
            "--objects",
            "--missing=print",
            FROZEN_S,
            FROZEN_D,
            FROZEN_C,
            BOOTSTRAP_IMPLEMENTATION_COMMIT,
            head,
        ],
    )
    if any(line.startswith(b"?") for line in closure.splitlines()):
        raise AuditError("bootstrap object closure missing")
    attributes = _run_git(
        repository,
        ["show", FROZEN_C + ":.gitattributes"],
    )
    expected_attributes = (
        b"docs/Recovery/3a011899-aafa-43e6-961a-5c2649331735.jsonl "
        b"filter=lfs diff=lfs merge=lfs -text\n"
    )
    if attributes != expected_attributes:
        raise AuditError("C attributes drift")
    common_git = Path(
        _ascii_git_line(
            repository,
            ["rev-parse", "--path-format=absolute", "--git-common-dir"],
            "common Git directory",
        )
    ).resolve()
    git_dir = Path(
        _ascii_git_line(
            repository,
            ["rev-parse", "--path-format=absolute", "--git-dir"],
            "worktree Git directory",
        )
    ).resolve()
    for forbidden_path in (
        common_git / "info" / "attributes",
        git_dir / "info" / "attributes",
        git_dir / "config.worktree",
    ):
        if forbidden_path.exists() or forbidden_path.is_symlink():
            raise AuditError("forbidden administrative path present")
    common_stat = _ordinary_directory(common_git)
    module_path = repository / "scripts" / "qinao_convergence_audit.py"
    module_payload = _read_ordinary(module_path, maximum=8 * 1024 * 1024)
    selected_entry_map_digest = _git_index_entry_map_digest(repository)
    invocation = _CURRENT_STERILE_INVOCATION
    if (
        invocation is None
        or invocation.get("profile") != "bootstrap"
        or not isinstance(invocation.get("recordDigest"), str)
        or not invocation.get("argv")
        or invocation["argv"][0] != "init-run-state"
    ):
        raise AuditError("init lacks exact sterile bootstrap invocation")
    protected_digest = _sha256(canonical_json_bytes(PROTECTED_WITNESS))
    b0_metadata = chain["implementationCommitMetadata"]
    b1_metadata = chain["repairCommitMetadata"]
    implementation_facts = _self_digest_record(
        {
            "schemaVersion": "qinao.bootstrap-commit-facts.v2",
            "role": "bootstrap-implementation",
            "S": FROZEN_S,
            "D": FROZEN_D,
            "C": FROZEN_C,
            "C_TREE": FROZEN_C_TREE,
            "cRawCommitSha256": FROZEN_C_RAW_SHA256,
            "mergeManifestSha256": FROZEN_MERGE_MANIFEST_DIGEST,
            "bootstrapCommit": BOOTSTRAP_IMPLEMENTATION_COMMIT,
            "bootstrapImplementationCommit": BOOTSTRAP_IMPLEMENTATION_COMMIT,
            "bootstrapCommitMetadata": b0_metadata,
            "bootstrapTree": BOOTSTRAP_IMPLEMENTATION_TREE,
            "bootstrapChangedPathB64": [
                base64.b64encode(path).decode("ascii") for path in b0_changed
            ],
            "configDigest": FROZEN_CONFIG_DIGEST,
            "rawConfigDigest": FROZEN_RAW_CONFIG_DIGEST,
            "configKeysDigest": FROZEN_CONFIG_KEYS_DIGEST,
            "protectedWitness": PROTECTED_WITNESS,
            "protectedWitnessDigest": protected_digest,
            "objectFormat": "sha1",
            "erratumDigest": ERRATUM_DIGEST,
        },
        field="bootstrapImportDigest",
    )
    repair_facts = _self_digest_record(
        {
            "schemaVersion": "qinao.bootstrap-commit-facts.v2",
            "role": "bootstrap-repair",
            "bootstrapRepairCommit": head,
            "bootstrapRepairCommitMetadata": b1_metadata,
            "bootstrapRepairTree": b1_tree,
            "bootstrapRepairChangedPathB64": [
                base64.b64encode(path).decode("ascii") for path in b1_changed
            ],
            "cleanStatusSha256": _sha256(b""),
            "orderedPreLedgerCommitChain": chain["orderedCommitChain"],
            "orderedPreLedgerCommitChainDigest": chain[
                "orderedCommitChainDigest"
            ],
            "erratumDigest": ERRATUM_DIGEST,
            "repairErratumDigest": REPAIR_ERRATUM_DIGEST,
            "sterileInvocationDigest": invocation["recordDigest"],
            "repairedModuleSha256": _sha256(module_payload),
        },
        field="bootstrapImportDigest",
    )
    identity_fields = {
        "schemaVersion": "qinao.run-identity.v1",
        "profile": "convergence",
        "repository": str(repository),
        "repositoryCommonDir": str(common_git),
        "repositoryCommonDirDevice": str(common_stat.st_dev),
        "repositoryCommonDirInode": str(common_stat.st_ino),
        "branch": branch,
        "S": FROZEN_S,
        "D": FROZEN_D,
        "C": FROZEN_C,
        "C_TREE": FROZEN_C_TREE,
        "bootstrapCommit": BOOTSTRAP_IMPLEMENTATION_COMMIT,
        "bootstrapTree": BOOTSTRAP_IMPLEMENTATION_TREE,
        "bootstrapRawCommitSha256": BOOTSTRAP_IMPLEMENTATION_RAW_SHA256,
        "bootstrapImplementationCommit": BOOTSTRAP_IMPLEMENTATION_COMMIT,
        "bootstrapImplementationTree": BOOTSTRAP_IMPLEMENTATION_TREE,
        "bootstrapImplementationRawCommitSha256": BOOTSTRAP_IMPLEMENTATION_RAW_SHA256,
        "bootstrapImplementationCommitMetadata": b0_metadata,
        "bootstrapRepairCommit": head,
        "bootstrapRepairTree": b1_tree,
        "bootstrapRepairRawCommitSha256": b1_metadata["rawCommitSha256"],
        "bootstrapRepairCommitMetadata": b1_metadata,
        "preLedgerCommitChain": chain["orderedCommitChain"],
        "preLedgerCommitChainDigest": chain["orderedCommitChainDigest"],
        "configDigest": FROZEN_CONFIG_DIGEST,
        "rawConfigDigest": FROZEN_RAW_CONFIG_DIGEST,
        "configKeysDigest": FROZEN_CONFIG_KEYS_DIGEST,
        "protectedWitnessDigest": protected_digest,
        "mergeManifestSha256": FROZEN_MERGE_MANIFEST_DIGEST,
        "erratumDigest": ERRATUM_DIGEST,
        "repairErratumDigest": REPAIR_ERRATUM_DIGEST,
        "objectFormat": "sha1",
        "ruleSetVersion": RULE_SET_VERSION,
        "ruleSetDigest": RULE_SET_DIGEST,
        "selectedRepairEntryMapDigest": selected_entry_map_digest,
        "moduleSha256": _sha256(module_payload),
        "repairedModuleSha256": _sha256(module_payload),
        "launcherSha256": _sha256(LOCAL_PYTHON_LAUNCHER),
        "sterileInvocationDigest": invocation["recordDigest"],
        "sterileRuntime": invocation["runtime"],
    }
    return identity_fields, [implementation_facts, repair_facts]


def _git_index_entries(repository: Path) -> Dict[bytes, bytes]:
    raw = _run_git(repository, ["ls-files", "--stage", "-z"])
    entries: Dict[bytes, bytes] = {}
    for token in raw.split(b"\x00"):
        if not token:
            continue
        try:
            header, path = token.split(b"\t", 1)
            mode, oid, stage = header.split(b" ")
        except ValueError as exc:
            raise AuditError("malformed index record") from exc
        if stage != b"0" or mode == b"160000":
            raise AuditError("unmerged or gitlink index entry")
        if path in entries:
            raise AuditError("duplicate index path")
        entries[path] = _run_git(repository, ["cat-file", "blob", oid.decode("ascii")])
    return entries


def _git_index_entry_map_digest(repository: Path) -> str:
    index_entries = _git_index_entries(repository)
    rows = [
        {
            "pathB64": base64.b64encode(path).decode("ascii"),
            "source": "index",
            "size": len(index_entries[path]),
            "sha256": _sha256(index_entries[path]),
        }
        for path in sorted(index_entries)
    ]
    if not rows:
        raise AuditError("bootstrap repair index entry map is empty")
    return _sha256(canonical_json_bytes(rows))


def _git_dirty_paths(repository: Path) -> List[bytes]:
    unstaged = _run_git(repository, ["diff", "--name-only", "-z", "--no-ext-diff", "--no-textconv"])
    untracked = _run_git(repository, ["ls-files", "--others", "--exclude-standard", "-z"])
    return sorted(set(part for part in (unstaged + untracked).split(b"\x00") if part))


def _command_secret_scan_worktree(argv: Sequence[str]) -> int:
    parser = argparse.ArgumentParser(prog="secret-scan-worktree")
    parser.add_argument("--repository", required=True)
    parser.add_argument("--output")
    parser.add_argument("--declared-path", action="append", default=[])
    parser.add_argument("--bootstrap-diagnostic-root")
    options = parser.parse_args(list(argv))
    repository = Path(options.repository).resolve()
    try:
        record = secret_scan_worktree_selection(
            _git_index_entries(repository),
            repository,
            [os.fsencode(path) for path in options.declared_path],
            _git_dirty_paths(repository),
        )
    except SecretScanError as exc:
        record = exc.record
        if options.output:
            write_canonical_exclusive(Path(options.output), record)
        if options.bootstrap_diagnostic_root:
            bootstrap = Path(options.bootstrap_diagnostic_root).resolve()
            _ordinary_directory(bootstrap, 0o700)
            diagnostic = bootstrap / ("capture.task3-secret." + secrets.token_hex(6))
            _mkdir_exclusive(diagnostic)
            write_canonical_exclusive(diagnostic / "secret-scan.json", record)
            _write_bytes_exclusive(diagnostic / "terminal.failed", b"failed\n")
        raise
    if options.output:
        write_canonical_exclusive(Path(options.output), record)
    if options.bootstrap_diagnostic_root:
        bootstrap = Path(options.bootstrap_diagnostic_root).resolve()
        _ordinary_directory(bootstrap, 0o700)
        diagnostic = bootstrap / ("capture.task3-secret." + secrets.token_hex(6))
        _mkdir_exclusive(diagnostic)
        write_canonical_exclusive(diagnostic / "secret-scan.json", record)
        _write_bytes_exclusive(diagnostic / "terminal.complete", b"complete\n")
        output = dict(record)
        output["diagnosticPath"] = str(diagnostic)
    else:
        output = record
    sys.stdout.buffer.write(canonical_json_bytes(output))
    return 0


def _emit_canonical(value: Any) -> int:
    sys.stdout.buffer.write(canonical_json_bytes(value))
    sys.stdout.buffer.flush()
    return 0


def _command_init_run_state(argv: Sequence[str]) -> int:
    parser = argparse.ArgumentParser(prog="init-run-state")
    parser.add_argument("--root", required=True)
    parser.add_argument("--repository", required=True)
    parser.add_argument("--profile", required=True, choices=("convergence",))
    parser.add_argument("--bootstrap-import", required=True)
    options = parser.parse_args(list(argv))
    root = Path(options.root).resolve()
    repository = Path(options.repository).resolve()
    identity_fields, commit_facts = _build_convergence_bootstrap_context(repository)
    if not isinstance(commit_facts, list) or len(commit_facts) != 2:
        raise AuditError("pre-ledger commit fact set drift")
    imported = collect_bootstrap_imports(
        root,
        scanner_record=Path(options.bootstrap_import),
        expected_tree=FROZEN_C_TREE,
        expected_c=FROZEN_C,
        erratum_digest=ERRATUM_DIGEST,
        repair_erratum_digest=REPAIR_ERRATUM_DIGEST,
        selected_entry_map_digest=identity_fields[
            "selectedRepairEntryMapDigest"
        ],
    )
    identity_fields = dict(identity_fields)
    historical_rows = [
        row
        for row in imported
        if row.get("classification") == "bootstrap-secret-scan-prior-complete"
    ]
    selected_rows = [
        row
        for row in imported
        if row.get("classification") == "bootstrap-secret-scan-complete"
        and row.get("selected") is True
    ]
    if len(historical_rows) != 1 or len(selected_rows) != 1:
        raise AuditError("bootstrap scanner identity set drift")
    historical = historical_rows[0]
    selected = selected_rows[0]
    identity_fields["historicalBootstrapScanner"] = {
        "generation": historical["name"],
        "recordDigest": historical["scannerRecordDigest"],
        "recordSha256": historical["scannerRecordSha256"],
        "entryMapDigest": historical["scannerEntryMapDigest"],
        "selected": False,
    }
    identity_fields["selectedRepairScanner"] = {
        "generation": selected["name"],
        "recordDigest": selected["scannerRecordDigest"],
        "recordSha256": selected["scannerRecordSha256"],
        "entryMapDigest": selected["scannerEntryMapDigest"],
        "selected": True,
    }
    bootstrap_imports = list(commit_facts) + imported
    identity_fields["bootstrapImportCount"] = len(bootstrap_imports)
    identity_fields["bootstrapImportsDigest"] = _sha256(
        canonical_json_bytes(bootstrap_imports)
    )
    identity = init_run_state(
        root,
        identity_fields,
        bootstrap_imports=bootstrap_imports,
    )
    recovered = recover_run_state(root)
    if (
        recovered["classification"] != "complete"
        or recovered["openFrontiers"]
        or recovered["records"][-1].get("operationKind") != "bootstrap-completed"
        or recovered["records"][-1].get("bootstrapImportCount")
        != len(bootstrap_imports)
    ):
        raise AuditError("published bootstrap ledger failed recovery")
    return _emit_canonical(
        {
            "schemaVersion": "qinao.init-run-state-result.v1",
            "identity": identity,
            "bootstrapImportCount": len(bootstrap_imports),
            "bootstrapImportsDigest": identity_fields["bootstrapImportsDigest"],
            "terminalRecordId": recovered["records"][-1]["recordId"],
            "terminalRecordDigest": recovered["records"][-1]["recordDigest"],
            "nextSequence": recovered["nextSequence"],
        }
    )


def _command_frontier_start(argv: Sequence[str]) -> int:
    parser = argparse.ArgumentParser(prog="frontier-start")
    parser.add_argument("--root", required=True)
    parser.add_argument("--frontier-kind", required=True)
    parser.add_argument("--input-digest", required=True)
    parser.add_argument("--declared-path", action="append", default=[])
    parser.add_argument("--expected-test", action="append", default=[])
    parser.add_argument("--allowed-child-kind", action="append", default=[])
    parser.add_argument("--parent-frontier")
    parser.add_argument("--component-kind")
    parser.add_argument("--resource-id")
    parser.add_argument("--operation-class")
    options = parser.parse_args(list(argv))
    return _emit_canonical(
        frontier_start(
            Path(options.root),
            frontier_kind=options.frontier_kind,
            input_digest=options.input_digest,
            declared_paths=options.declared_path,
            expected_tests=options.expected_test,
            allowed_child_kinds=options.allowed_child_kind,
            parent_frontier=options.parent_frontier,
            component_kind=options.component_kind,
            resource_id=options.resource_id,
            operation_class=options.operation_class,
        )
    )


def _command_frontier_complete(argv: Sequence[str]) -> int:
    parser = argparse.ArgumentParser(prog="frontier-complete")
    parser.add_argument("--root", required=True)
    parser.add_argument("--frontier-id", required=True)
    parser.add_argument("--input-digest", required=True)
    parser.add_argument("--declared-path", action="append", default=[])
    parser.add_argument("--outcome", required=True)
    parser.add_argument("--resource-snapshot-digest")
    options = parser.parse_args(list(argv))
    return _emit_canonical(
        frontier_complete(
            Path(options.root),
            options.frontier_id,
            input_digest=options.input_digest,
            declared_paths=options.declared_path,
            outcome=options.outcome,
            resource_snapshot_digest=options.resource_snapshot_digest,
        )
    )


def _command_allocate_capture(argv: Sequence[str]) -> int:
    parser = argparse.ArgumentParser(prog="allocate-capture")
    parser.add_argument("--root", required=True)
    parser.add_argument("--phase", required=True)
    parser.add_argument("--frontier-id")
    options = parser.parse_args(list(argv))
    return _emit_canonical(
        allocate_capture(
            Path(options.root),
            options.phase,
            frontier_id=options.frontier_id,
        )
    )


def _command_seal_capture(argv: Sequence[str]) -> int:
    parser = argparse.ArgumentParser(prog="seal-capture")
    parser.add_argument("--root", required=True)
    parser.add_argument("--capture-id", required=True)
    parser.add_argument("--filename", action="append", default=[])
    options = parser.parse_args(list(argv))
    return _emit_canonical(
        seal_capture(Path(options.root), options.capture_id, options.filename)
    )


def _command_allocate_resource(argv: Sequence[str]) -> int:
    parser = argparse.ArgumentParser(prog="allocate-resource")
    parser.add_argument("--root", required=True)
    parser.add_argument("--resource-kind", required=True)
    options = parser.parse_args(list(argv))
    return _emit_canonical(
        allocate_resource(Path(options.root), options.resource_kind)
    )


def _command_snapshot_resource(argv: Sequence[str]) -> int:
    parser = argparse.ArgumentParser(prog="snapshot-resource")
    parser.add_argument("--root", required=True)
    parser.add_argument("--resource-id", required=True)
    parser.add_argument("--frontier-id")
    options = parser.parse_args(list(argv))
    return _emit_canonical(
        snapshot_resource(
            Path(options.root),
            options.resource_id,
            options.frontier_id,
        )
    )


def _dispatch_command(argv: Sequence[str]) -> int:
    if not argv:
        raise AuditError("command required")
    command = argv[0]
    remainder = argv[1:]
    if command == "init-run-state":
        return _command_init_run_state(remainder)
    if command == "allocate-capture":
        return _command_allocate_capture(remainder)
    if command == "seal-capture":
        return _command_seal_capture(remainder)
    if command == "allocate-resource":
        return _command_allocate_resource(remainder)
    if command == "snapshot-resource":
        return _command_snapshot_resource(remainder)
    if command == "frontier-start":
        return _command_frontier_start(remainder)
    if command == "frontier-complete":
        return _command_frontier_complete(remainder)
    if command == "secret-scan-worktree":
        return _command_secret_scan_worktree(remainder)
    if command == "recover-captures":
        parser = argparse.ArgumentParser(prog=command)
        parser.add_argument("--root", required=True)
        options = parser.parse_args(list(remainder))
        recovered = recover_run_state(Path(options.root))
        if recovered["classification"] != "complete":
            sys.stdout.buffer.write(canonical_json_bytes(recovered))
            return 2
        return _emit_canonical(recovered)
    raise AuditError("closed command not implemented: " + command)


def main(argv: Optional[Sequence[str]] = None) -> int:
    arguments = list(sys.argv[1:] if argv is None else argv)
    if not arguments:
        raise AuditError("command required")
    if arguments[0] == "sterile-python":
        return _sterile_python(arguments[1:])
    return _dispatch_command(arguments)


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except AuditError as exc:
        sys.stderr.write("qinao audit: " + str(exc) + "\n")
        raise SystemExit(2)
