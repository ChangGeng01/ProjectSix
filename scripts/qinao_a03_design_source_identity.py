#!/usr/bin/env python3
"""Prepare the blocked, non-authoritative A0.3a design-source identity.

This capability delegates fixed Git-object reconstruction to the frozen A0.2
observer and independently compares its result with one closed expected
identity set.  It also reopens and hashes the repository-external A0.2 custody
directory.  Neither observation is authority: this module has no signer,
receipt-acceptance, controller-claim, commit, ref-CAS, or install surface.

A successful observation still exits non-zero.  A governed V1 transition-02
predecessor terminal, its externally amended terminal shape, the V2 schema and
signer scope, an incumbent-controller durable claim/private epoch, and same-UID
capability isolation all remain outside this capability.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import signal
import stat
import subprocess
import sys
import threading
from pathlib import Path
from types import ModuleType
from typing import Sequence


SCHEMA = "qinao-a03-design-source-identity-freeze-v1"
EXIT_BLOCKED = 41
EXIT_UNAVAILABLE = 42

A02_SCHEMA = "qinao-a02-provisional-review-projection-v1"
A02_COMMIT = "bef9cea290d161da7510c6624bc676fd181cfd10"
A02_TREE = "26495bad43991149264c177fbb01212da952f464"
A02_PROJECTION_DIGEST = (
    "cf8290927c19deddc37938f7ded85a985a286923ab1501d5401879149fcb8298"
)
A02_FROZEN_SHA256 = (
    "cab70d307dd1e289850fe741b67ad64c9a252913ddccd9ba00c13d1b065f6f2b"
)
A02_SOURCE_RELATIVE_PATH = "scripts/qinao_a02_provisional_design_edge.py"
A02_SOURCE_BYTES = 51142
A02_SOURCE_GIT_BLOB = "75f7ef3a7a05b06d454d49ec407a14034bdfd9e6"
A02_SOURCE_SHA256 = (
    "9229f962f9581f7f942b5f08838f0f9199810dc366e62b03cc0206fe68f09f0d"
)
A02_PRIVATE_MODULE_NAME = "_qinao_a02_pinned_9229f962f958"
A02_ERRATUM_RELATIVE_PATH = (
    "docs/superpowers/evidence/"
    "2026-08-29-qinao-a02-shared-object-database-writes-erratum.json"
)
A02_ERRATUM_BYTES = 3446
A02_ERRATUM_SHA256 = (
    "4e51270815584488bbd33054ff7b61f2c4f7ea9040f98ed5e86aa1bf3ae8b93a"
)
GIT = Path("/usr/bin/git")

BOOTSTRAP_COMMIT = "7e4aa2d626e2c94b1b1f3405fb8454e73448514f"
BOOTSTRAP_TREE = "47304602b7d1c1eba8eed571dbc65ee36c3a5f21"
SOURCE_0802_COMMIT = "c8f80486895e12e26d567e610c35a6e2141b3489"
SOURCE_0802_TREE = "2f484874b8b6d49b8bcd595bf3a3ff6c835fb509"
SOURCE_0810_COMMIT = "4a9298db261bcfda97ea1748baad65649156ba66"
SOURCE_0810_TREE = "22382c1de6680a263ec4a2f4a6c989c0f0e6e220"
REVIEW_BASE_TREE = "4fd48205c1716f9ce23efd8885c94afdcdf70311"
CANDIDATE_TREE = "0fa81fb9d1c3498fd8bb75d4c46a048f3b64260e"

PATH_0802 = (
    "docs/superpowers/specs/"
    "2026-08-02-qinao-biomimetic-sovereign-agent-system-design.md"
)
PATH_0810 = (
    "docs/superpowers/specs/"
    "2026-08-10-qinao-global-invariant-firewall-and-recovery-design.md"
)
SOURCE_TUPLES: list[dict[str, object]] = [
    {
        "path": PATH_0802,
        "gitMode": "100644",
        "gitBlob": "f3d4186769fd0119a418097fea8821d597770189",
        "byteLength": 81128,
        "sha256": (
            "40d322f052425a7e56f03b826922181047c30ac908c35c922a5481e4ddf29aa6"
        ),
    },
    {
        "path": PATH_0810,
        "gitMode": "100644",
        "gitBlob": "887c23a28fb9098d86d252aa8b6dc9153380738b",
        "byteLength": 233726,
        "sha256": (
            "4eb06cde16e0cf5985c7272147ced9274dd83648a098772c8b5a06f7b3ebeab6"
        ),
    },
]

CUSTODY_BUNDLE_NAME = "qinao-a02-nonauthoritative-object-capsule.bundle"
CUSTODY_BUNDLE_BYTES = 327689560
CUSTODY_BUNDLE_SHA256 = (
    "3b29335f12ae680329e19723b1f292641a66358ae47a04a1ee996957b034b36f"
)
CUSTODY_MANIFEST_NAME = "MANIFEST.sha256"
CUSTODY_MANIFEST_BYTES = 301
CUSTODY_MANIFEST_SHA256 = (
    "674cb04da3d5ab80d3f22cb6a52494f4a6e8c36947a0755faff1ddf2b718fd70"
)
CUSTODY_REVIEW_NAME = "qinao-a02-postcommit-custody-receipt.json"
CUSTODY_REVIEW_BYTES = 7053
CUSTODY_REVIEW_SHA256 = (
    "5b01e9705e54a46699f77efa9f0a5bfa064ed8358b15399dbcec9c50037a7371"
)
CUSTODY_RECOVERY_NAME = "RECOVERY.md"
CUSTODY_RECOVERY_BYTES = 1683
CUSTODY_RECOVERY_SHA256 = (
    "0d0d7f4d7cc5278e1f3e98d5be857edda6799aa09a3a0f8324656c7cd5337277"
)

BUNDLE_REFS = [
    {
        "ref": "refs/heads/codex/qinao-a02-provisional-verifier-20260828",
        "oid": A02_COMMIT,
    },
    {
        "ref": "refs/heads/codex/qinao-p0-preservation-20260828",
        "oid": SOURCE_0810_COMMIT,
    },
    {
        "ref": "refs/heads/codex/qinao-dual-space-design",
        "oid": BOOTSTRAP_COMMIT,
    },
]

BLOCKERS = [
    "BLOCKED_GOVERNED_V1_TRANSITION02_PREDECESSOR_TERMINAL_NOT_BOUND",
    (
        "BLOCKED_V1_TRANSITION02_PREDECESSOR_TERMINAL_SHAPE_"
        "REQUIRES_EXTERNAL_AMENDMENT"
    ),
    "BLOCKED_EXTERNALLY_GOVERNED_V2_DESIGN_EDGE_SCHEMA_SCOPE_NOT_BOUND",
    "BLOCKED_CONTROLLER_DURABLE_CLAIM_AND_PRIVATE_SOURCE_EPOCH_NOT_BOUND",
    "BLOCKED_SAME_UID_CAPABILITY_ISOLATION_NOT_PROVEN",
]

ZERO_AUTHORITY_EFFECTS = {
    "externalSignerCalls": 0,
    "externalReceiptAcceptanceCalls": 0,
    "controllerClaimCalls": 0,
    "authorityCommitCalls": 0,
    "protectedRefCASCalls": 0,
    "installCalls": 0,
}

_EXPECTED_NAMES = {
    CUSTODY_BUNDLE_NAME,
    CUSTODY_MANIFEST_NAME,
    CUSTODY_REVIEW_NAME,
    CUSTODY_RECOVERY_NAME,
}
_EXPECTED_MANIFEST = (
    f"{CUSTODY_BUNDLE_SHA256}  {CUSTODY_BUNDLE_NAME}\n"
    f"{CUSTODY_REVIEW_SHA256}  {CUSTODY_REVIEW_NAME}\n"
    f"{CUSTODY_RECOVERY_SHA256}  {CUSTODY_RECOVERY_NAME}\n"
).encode("ascii")
_EXPECTED_BUNDLE_HEADER = (
    "# v2 git bundle\n"
    f"{A02_COMMIT} refs/heads/codex/qinao-a02-provisional-verifier-20260828\n"
    f"{SOURCE_0810_COMMIT} refs/heads/codex/qinao-p0-preservation-20260828\n"
    f"{BOOTSTRAP_COMMIT} refs/heads/codex/qinao-dual-space-design\n"
    "\n"
).encode("ascii")
_EXPECTED_LIST_HEADS = _EXPECTED_BUNDLE_HEADER.split(b"\n", 1)[1].rstrip(b"\n")

MAX_SMALL_CUSTODY_BYTES = 1024 * 1024
HASH_CHUNK_BYTES = 1024 * 1024
MAX_BUNDLE_HEADER_BYTES = 16 * 1024
BUNDLE_COMMAND_TIMEOUT_SECONDS = 60
MAX_BUNDLE_COMMAND_OUTPUT_BYTES = 64 * 1024
MAX_REGISTERED_WORKTREES = 256
MAX_OBJECT_DATABASE_ENTRIES = 200_000
MAX_OBJECT_DATABASE_DEPTH = 128
MAX_OBJECT_DATABASE_BYTES = 64 * 1024 * 1024 * 1024
A02_RUNTIME_ROOT = Path("/private/tmp/qinao-a02-provisional-runtime-v1")
PRIVATE_REPOSITORY_NAME = "verified-a02-custody.git"
_PROCESS_STATE_MODULE_NAME = "_qinao_a03_source_identity_process_state_v1"
_PROCESS_STATE_MARKER = "qinao-a03-source-identity-process-state-v1"
_PROCESS_STATE_LOCK_ATTRIBUTE = "pinned_a02_process_lock"
_MISSING_MODULE = object()


def _install_shared_process_state() -> tuple[ModuleType, object]:
    candidate = ModuleType(_PROCESS_STATE_MODULE_NAME)
    candidate.__qinao_process_state_marker__ = _PROCESS_STATE_MARKER
    candidate.pinned_a02_process_lock = threading.RLock()
    state = sys.modules.setdefault(_PROCESS_STATE_MODULE_NAME, candidate)
    lock = getattr(state, _PROCESS_STATE_LOCK_ATTRIBUTE, None)
    if (
        type(state) is not ModuleType
        or state.__name__ != _PROCESS_STATE_MODULE_NAME
        or getattr(state, "__qinao_process_state_marker__", None)
        != _PROCESS_STATE_MARKER
        or type(lock) is not type(candidate.pinned_a02_process_lock)
    ):
        raise RuntimeError("A0.3 process-state holder collision")
    return state, lock


_PROCESS_STATE_HOLDER, _PINNED_A02_PROCESS_LOCK = _install_shared_process_state()

class SourceIdentityError(RuntimeError):
    """A0.2 did not reproduce the one closed A0.3a expected identity."""


class PinnedA02Error(RuntimeError):
    """The byte-pinned A0.2 implementation could not be loaded or executed."""


class SourceIsolationError(RuntimeError):
    """The live source could not be kept outside write-capable Git execution."""


class CustodyError(RuntimeError):
    """Repository-external custody did not match the closed reviewed bytes."""


def _validated_pinned_a02_process_lock() -> object:
    state = sys.modules.get(_PROCESS_STATE_MODULE_NAME)
    if (
        state is not _PROCESS_STATE_HOLDER
        or getattr(state, "__qinao_process_state_marker__", None)
        != _PROCESS_STATE_MARKER
        or getattr(state, _PROCESS_STATE_LOCK_ATTRIBUTE, None)
        is not _PINNED_A02_PROCESS_LOCK
    ):
        raise PinnedA02Error("A0.3 process-state holder changed")
    return _PINNED_A02_PROCESS_LOCK


def _verified_a02_source_bytes(path: Path) -> bytes:
    flags = os.O_RDONLY | getattr(os, "O_CLOEXEC", 0) | getattr(os, "O_NOFOLLOW", 0)
    descriptor = os.open(path, flags)
    try:
        before = os.fstat(descriptor)
        if not stat.S_ISREG(before.st_mode):
            raise PinnedA02Error("pinned A0.2 source is not a regular file")
        if before.st_uid != os.getuid():
            raise PinnedA02Error("pinned A0.2 source has an unexpected owner")
        if stat.S_IMODE(before.st_mode) != 0o644:
            raise PinnedA02Error("pinned A0.2 source mode is not 0644")
        if before.st_nlink != 1:
            raise PinnedA02Error("pinned A0.2 source has an unexpected link count")
        if before.st_size != A02_SOURCE_BYTES:
            raise PinnedA02Error("pinned A0.2 source byte length mismatch")
        chunks: list[bytes] = []
        total = 0
        while True:
            chunk = os.read(descriptor, 64 * 1024)
            if not chunk:
                break
            chunks.append(chunk)
            total += len(chunk)
            if total > A02_SOURCE_BYTES:
                raise PinnedA02Error("pinned A0.2 source exceeds its fixed length")
        after = os.fstat(descriptor)
        if _identity_tuple(after) != _identity_tuple(before):
            raise PinnedA02Error("pinned A0.2 source changed while being read")
        path_metadata = os.lstat(path)
        if _identity_tuple(path_metadata) != _identity_tuple(before):
            raise PinnedA02Error("pinned A0.2 source path changed while being read")
    finally:
        os.close(descriptor)

    raw = b"".join(chunks)
    if len(raw) != A02_SOURCE_BYTES:
        raise PinnedA02Error("pinned A0.2 source was truncated")
    if hashlib.sha256(raw).hexdigest() != A02_SOURCE_SHA256:
        raise PinnedA02Error("pinned A0.2 source SHA-256 mismatch")
    git_blob = hashlib.sha1(
        f"blob {len(raw)}\0".encode("ascii") + raw
    ).hexdigest()
    if git_blob != A02_SOURCE_GIT_BLOB:
        raise PinnedA02Error("pinned A0.2 source Git blob mismatch")
    return raw


def _load_pinned_a02_module_unlocked() -> ModuleType:
    source_path = Path(__file__).resolve(strict=True).with_name(
        Path(A02_SOURCE_RELATIVE_PATH).name
    )
    source = _verified_a02_source_bytes(source_path)
    module = ModuleType(A02_PRIVATE_MODULE_NAME)
    module.__file__ = str(source_path)
    module.__package__ = ""
    module.__loader__ = None
    previous = sys.modules.get(A02_PRIVATE_MODULE_NAME, _MISSING_MODULE)
    sys.modules[A02_PRIVATE_MODULE_NAME] = module
    try:
        try:
            code = compile(source, str(source_path), "exec", dont_inherit=True)
            exec(code, module.__dict__)
        except Exception as error:
            raise PinnedA02Error(
                "byte-pinned A0.2 implementation failed to load"
            ) from error
        if (
            getattr(module, "GIT", None) != GIT
            or getattr(module, "RUNTIME_ROOT", None) != A02_RUNTIME_ROOT
            or not callable(getattr(module, "prepare_provisional", None))
            or not callable(getattr(module, "_validated_runtime_root", None))
            or not callable(getattr(module, "_scratch_session", None))
        ):
            raise PinnedA02Error("byte-pinned A0.2 implementation surface mismatch")
        return module
    finally:
        if previous is _MISSING_MODULE:
            sys.modules.pop(A02_PRIVATE_MODULE_NAME, None)
        else:
            sys.modules[A02_PRIVATE_MODULE_NAME] = previous


def _load_pinned_a02_module() -> ModuleType:
    with _validated_pinned_a02_process_lock():
        return _load_pinned_a02_module_unlocked()


def _pinned_a02_module() -> ModuleType:
    return _load_pinned_a02_module()


def _git_environment() -> dict[str, str]:
    return {
        "GIT_CONFIG_NOSYSTEM": "1",
        "GIT_CONFIG_GLOBAL": "/dev/null",
        "GIT_CONFIG_COUNT": "3",
        "GIT_CONFIG_KEY_0": "core.hooksPath",
        "GIT_CONFIG_VALUE_0": "/dev/null",
        "GIT_CONFIG_KEY_1": "core.fsmonitor",
        "GIT_CONFIG_VALUE_1": "false",
        "GIT_CONFIG_KEY_2": "diff.external",
        "GIT_CONFIG_VALUE_2": "/usr/bin/false",
        "GIT_NO_REPLACE_OBJECTS": "1",
        "GIT_NO_LAZY_FETCH": "1",
        "GIT_ATTR_NOSYSTEM": "1",
        "GIT_OPTIONAL_LOCKS": "0",
        "GIT_PAGER": "cat",
        "GIT_TERMINAL_PROMPT": "0",
        "HOME": "/var/empty",
        "LC_ALL": "C",
        "PATH": "/usr/bin:/bin",
        "TMPDIR": "/private/tmp",
    }


def _run_git(
    arguments: Sequence[str],
    *,
    cwd: Path,
    pass_fds: tuple[int, ...] = (),
) -> bytes:
    process = subprocess.Popen(
        [str(GIT), *arguments],
        cwd=cwd,
        env=_git_environment(),
        stdin=subprocess.DEVNULL,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        start_new_session=True,
        pass_fds=pass_fds,
    )
    try:
        stdout, stderr = process.communicate(timeout=BUNDLE_COMMAND_TIMEOUT_SECONDS)
    except subprocess.TimeoutExpired as error:
        try:
            os.killpg(process.pid, signal.SIGKILL)
        except (PermissionError, ProcessLookupError):
            process.kill()
        process.wait()
        raise CustodyError("Git observation exceeded its fixed time budget") from error
    if (
        len(stdout) > MAX_BUNDLE_COMMAND_OUTPUT_BYTES
        or len(stderr) > MAX_BUNDLE_COMMAND_OUTPUT_BYTES
    ):
        raise CustodyError("Git observation exceeded its output budget")
    if process.returncode != 0:
        detail = stderr.decode("utf-8", "replace").strip()
        raise CustodyError(
            f"Git observation failed ({process.returncode}): {detail}"
        )
    return stdout


def _strict_json_object(pairs: list[tuple[str, object]]) -> dict[str, object]:
    result: dict[str, object] = {}
    for key, value in pairs:
        if key in result:
            raise CustodyError(f"duplicate JSON key: {key}")
        result[key] = value
    return result


def _verified_a02_erratum() -> dict[str, object]:
    path = Path(__file__).resolve(strict=True).parents[1] / A02_ERRATUM_RELATIVE_PATH
    flags = os.O_RDONLY | getattr(os, "O_CLOEXEC", 0) | getattr(os, "O_NOFOLLOW", 0)
    descriptor = os.open(path, flags)
    try:
        before = os.fstat(descriptor)
        if (
            not stat.S_ISREG(before.st_mode)
            or before.st_uid != os.getuid()
            or stat.S_IMODE(before.st_mode) != 0o644
            or before.st_nlink != 1
            or before.st_size != A02_ERRATUM_BYTES
        ):
            raise SourceIdentityError("A0.2 erratum file shape mismatch")
        chunks: list[bytes] = []
        total = 0
        while True:
            chunk = os.read(descriptor, 64 * 1024)
            if not chunk:
                break
            chunks.append(chunk)
            total += len(chunk)
            if total > A02_ERRATUM_BYTES:
                raise SourceIdentityError("A0.2 erratum exceeds its byte length")
        after = os.fstat(descriptor)
        linked = os.lstat(path)
        if (
            _identity_tuple(after) != _identity_tuple(before)
            or _identity_tuple(linked) != _identity_tuple(before)
        ):
            raise SourceIdentityError("A0.2 erratum changed while being read")
    finally:
        os.close(descriptor)
    raw = b"".join(chunks)
    if (
        len(raw) != A02_ERRATUM_BYTES
        or hashlib.sha256(raw).hexdigest() != A02_ERRATUM_SHA256
    ):
        raise SourceIdentityError("A0.2 erratum byte identity mismatch")
    document = json.loads(
        raw.decode("utf-8", "strict"),
        object_pairs_hook=_strict_json_object,
    )
    if (
        not isinstance(document, dict)
        or document.get("schema")
        != "qinao-a02-provisional-review-projection-v1-erratum-v1"
        or document.get("classification")
        != "appendOnlyHistoricalSemanticErratum"
        or document.get("supersededClaim", {}).get("jsonPointer")
        != "/deterministicProjection/sharedObjectDatabaseWrites"
        or document.get("supersededClaim", {}).get("disposition")
        != "invalidatedAsOverbroad"
        or document.get("authority", {}).get("semanticAuthority") != "none"
        or document.get("authority", {}).get("deepScan3")
        != "notStartedAndNotAuthorized"
    ):
        raise SourceIdentityError("A0.2 erratum semantic boundary mismatch")
    return {
        "relativePath": A02_ERRATUM_RELATIVE_PATH,
        "byteLength": A02_ERRATUM_BYTES,
        "sha256": A02_ERRATUM_SHA256,
        "schema": document["schema"],
    }


def _identity_tuple(value: os.stat_result) -> tuple[int, ...]:
    return (
        value.st_dev,
        value.st_ino,
        value.st_mode,
        value.st_uid,
        value.st_gid,
        value.st_nlink,
        value.st_size,
        value.st_mtime_ns,
        value.st_ctime_ns,
        getattr(value, "st_flags", 0),
    )


def _object_database_metadata_inventory(
    object_database: Path,
) -> tuple[int, int, tuple[tuple[object, ...], ...]]:
    root = object_database.resolve(strict=True)
    root_metadata = os.lstat(root)
    if not stat.S_ISDIR(root_metadata.st_mode) or stat.S_ISLNK(root_metadata.st_mode):
        raise SourceIsolationError("source object database is not a real directory")
    if root_metadata.st_uid != os.getuid():
        raise SourceIsolationError("source object database has an unexpected owner")

    root_device = root_metadata.st_dev
    entries: list[tuple[object, ...]] = []
    total_bytes = 0

    def visit(path: Path, relative: str, depth: int) -> None:
        nonlocal total_bytes
        if depth > MAX_OBJECT_DATABASE_DEPTH:
            raise SourceIsolationError("object database exceeds the depth budget")
        try:
            metadata = os.lstat(path)
        except OSError as error:
            raise SourceIsolationError("object database entry is unavailable") from error
        if metadata.st_dev != root_device:
            raise SourceIsolationError("object database crosses a device boundary")
        if metadata.st_uid != os.getuid():
            raise SourceIsolationError("object database entry has an unexpected owner")
        if stat.S_ISDIR(metadata.st_mode):
            kind = "directory"
        elif stat.S_ISREG(metadata.st_mode):
            kind = "regular"
            if metadata.st_nlink != 1:
                raise SourceIsolationError(
                    "object database regular file has an unexpected link count"
                )
            total_bytes += metadata.st_size
            if total_bytes > MAX_OBJECT_DATABASE_BYTES:
                raise SourceIsolationError("object database exceeds the byte budget")
        else:
            raise SourceIsolationError("object database contains a special entry")
        entries.append((relative, kind, *_identity_tuple(metadata)))
        if len(entries) > MAX_OBJECT_DATABASE_ENTRIES:
            raise SourceIsolationError("object database exceeds the entry budget")
        if kind == "directory":
            try:
                children = sorted(path.iterdir(), key=lambda value: value.name)
            except OSError as error:
                raise SourceIsolationError(
                    "object database directory cannot be enumerated"
                ) from error
            for child in children:
                child_relative = child.name if relative == "." else f"{relative}/{child.name}"
                if len(child_relative.encode("utf-8")) > 4096:
                    raise SourceIsolationError("object database path exceeds the budget")
                visit(child, child_relative, depth + 1)

    visit(root, ".", 0)
    return root_device, total_bytes, tuple(entries)


def _materialize_private_repository_from_held_bundle(
    session: Path,
    bundle_descriptor: int,
    bundle_before: os.stat_result,
    *,
    expected_heads: bytes,
) -> tuple[Path, dict[str, object]]:
    session_metadata = os.lstat(session)
    if (
        not stat.S_ISDIR(session_metadata.st_mode)
        or stat.S_ISLNK(session_metadata.st_mode)
        or session_metadata.st_uid != os.getuid()
        or stat.S_IMODE(session_metadata.st_mode) != 0o700
    ):
        raise SourceIsolationError("private materialization session is not 0700")
    if (
        not stat.S_ISREG(bundle_before.st_mode)
        or bundle_before.st_uid != os.getuid()
        or bundle_before.st_nlink != 1
        or _identity_tuple(os.fstat(bundle_descriptor))
        != _identity_tuple(bundle_before)
    ):
        raise SourceIsolationError("held bundle identity is invalid")

    private_repository = session / PRIVATE_REPOSITORY_NAME
    empty_template = session / "empty-git-template"
    empty_template.mkdir(mode=0o700)
    _run_git(
        [
            "init",
            "--bare",
            "--object-format=sha1",
            f"--template={empty_template}",
            str(private_repository),
        ],
        cwd=session,
    )

    inherited = os.dup(bundle_descriptor)
    try:
        os.lseek(inherited, 0, os.SEEK_SET)
        try:
            unbundled_heads = _run_git(
                [
                    "-C",
                    str(private_repository),
                    "bundle",
                    "unbundle",
                    f"/dev/fd/{inherited}",
                ],
                cwd=session,
                pass_fds=(inherited,),
            ).rstrip(b"\n")
        except CustodyError as error:
            raise SourceIsolationError(
                "held bundle could not materialize a private repository"
            ) from error
    finally:
        os.close(inherited)
    if unbundled_heads != expected_heads:
        raise SourceIsolationError("private unbundle ref inventory mismatch")
    if _identity_tuple(os.fstat(bundle_descriptor)) != _identity_tuple(bundle_before):
        raise SourceIsolationError("held bundle changed across private unbundle")

    return private_repository, {
        "inputMechanism": "gitBundleUnbundleFromHeldDescriptor",
        "sourcePathReopenUsed": False,
        "ordinaryCopyFallbackUsed": False,
        "hardlinkFallbackUsed": False,
        "liveSourceObjectDatabaseFallbackUsed": False,
        "exactBundleHeadsMatched": True,
    }


def _execute_pinned_a02_from_bundle_unlocked(
    repository: Path,
    source_object_database: Path,
    bundle_descriptor: int,
    bundle_before: os.stat_result,
    module: ModuleType,
    *,
    expected_heads: bytes = _EXPECTED_LIST_HEADS,
) -> tuple[dict[str, object], dict[str, object]]:
    repository = repository.resolve(strict=True)
    source_object_database = source_object_database.resolve(strict=True)
    source_inventory_before = _object_database_metadata_inventory(
        source_object_database
    )
    _bundle_sha_before, _prefix = _hash_open_descriptor(
        bundle_descriptor,
        bundle_before,
        CUSTODY_BUNDLE_NAME,
        bundle_before.st_size,
    )

    try:
        runtime_root = module._validated_runtime_root(
            repository,
            source_object_database,
        )
        with module._scratch_session(runtime_root) as session:
            private_repository, materialization = (
                _materialize_private_repository_from_held_bundle(
                    session,
                    bundle_descriptor,
                    bundle_before,
                    expected_heads=expected_heads,
                )
            )
            object_format = _run_git(
                ["-C", str(private_repository), "rev-parse", "--show-object-format"],
                cwd=session,
            )
            if object_format != b"sha1\n":
                raise SourceIsolationError("private repository object format mismatch")
            private_objects = (
                private_repository / "objects"
            ).resolve(strict=True)
            if _paths_overlap(private_objects, source_object_database):
                raise SourceIsolationError("private and source object databases overlap")
            _require_absent_alternate_database_files(private_objects)
            private_inventory = _object_database_metadata_inventory(private_objects)
            if private_inventory[1] <= 0:
                raise SourceIsolationError("private object database is empty")

            original_runtime_root = module.RUNTIME_ROOT
            inner_runtime_root = session / A02_RUNTIME_ROOT.name
            module.RUNTIME_ROOT = inner_runtime_root
            try:
                result = module.prepare_provisional(private_repository)
            finally:
                module.RUNTIME_ROOT = original_runtime_root
            if module.RUNTIME_ROOT != original_runtime_root:
                raise SourceIsolationError("pinned A0.2 runtime root was not restored")
            if not isinstance(result, dict):
                raise PinnedA02Error("byte-pinned A0.2 returned a non-object")
            _require_absent_alternate_database_files(private_objects)
    except SourceIsolationError:
        raise
    except Exception as error:
        raise PinnedA02Error("byte-pinned A0.2 private execution failed") from error
    finally:
        source_inventory_after = _object_database_metadata_inventory(
            source_object_database
        )
        if source_inventory_after != source_inventory_before:
            raise SourceIsolationError(
                "source object database changed across private A0.2 execution"
            )
        if _identity_tuple(os.fstat(bundle_descriptor)) != _identity_tuple(bundle_before):
            raise SourceIsolationError("held custody bundle changed during execution")

    return result, {
        "writeCapableGitInput": (
            "ephemeralPrivateBareRepositoryFromHeldCustodyBundle"
        ),
        "bundleMaterialization": materialization,
        "sourceRepositoryObjectDatabaseObservation": (
            "boundedSelectedMetadataEndpointInventoryEqualBeforeAfter"
        ),
        "privateEphemeralObjectMetadataMayChange": True,
        "liveSourceObjectDatabaseUsedAsAlternate": False,
        "runtimeOwnershipProtocol": "singlePinnedA02ScratchLeaseProtocol",
        "nestedLeaseCount": 2,
        "runtimeRootReboundAndRestored": True,
    }


def _execute_pinned_a02_from_bundle(
    repository: Path,
    source_object_database: Path,
    bundle_descriptor: int,
    bundle_before: os.stat_result,
    module: ModuleType,
    *,
    expected_heads: bytes = _EXPECTED_LIST_HEADS,
) -> tuple[dict[str, object], dict[str, object]]:
    with _validated_pinned_a02_process_lock():
        return _execute_pinned_a02_from_bundle_unlocked(
            repository,
            source_object_database,
            bundle_descriptor,
            bundle_before,
            module,
            expected_heads=expected_heads,
        )


def _open_custody_directory(directory: Path) -> tuple[int, os.stat_result]:
    flags = (
        os.O_RDONLY
        | getattr(os, "O_CLOEXEC", 0)
        | getattr(os, "O_NOFOLLOW", 0)
        | getattr(os, "O_DIRECTORY", 0)
    )
    descriptor = os.open(directory, flags)
    try:
        metadata = os.fstat(descriptor)
        if not stat.S_ISDIR(metadata.st_mode):
            raise CustodyError("custody path is not a directory")
        if metadata.st_uid != os.getuid():
            raise CustodyError("custody directory has an unexpected owner")
        if stat.S_IMODE(metadata.st_mode) != 0o700:
            raise CustodyError("custody directory POSIX mode is not 0700")
        immutable_flag = getattr(stat, "UF_IMMUTABLE", 0)
        if immutable_flag == 0 or not (
            getattr(metadata, "st_flags", 0) & immutable_flag
        ):
            raise CustodyError("custody directory is not user-immutable")
        if set(os.listdir(descriptor)) != _EXPECTED_NAMES:
            raise CustodyError("custody directory has missing or extra entries")
        path_metadata = os.lstat(directory)
        if _identity_tuple(path_metadata) != _identity_tuple(metadata):
            raise CustodyError("custody directory path is not the opened generation")
        return descriptor, metadata
    except BaseException:
        os.close(descriptor)
        raise


def _open_mode_restricted_file(
    directory_descriptor: int,
    name: str,
    expected_bytes: int,
) -> tuple[int, os.stat_result]:
    flags = os.O_RDONLY | getattr(os, "O_CLOEXEC", 0) | getattr(os, "O_NOFOLLOW", 0)
    descriptor = os.open(name, flags, dir_fd=directory_descriptor)
    try:
        metadata = os.fstat(descriptor)
        if not stat.S_ISREG(metadata.st_mode):
            raise CustodyError(f"{name} is not a regular file")
        if metadata.st_uid != os.getuid():
            raise CustodyError(f"{name} has an unexpected owner")
        if stat.S_IMODE(metadata.st_mode) != 0o400:
            raise CustodyError(f"{name} POSIX mode is not 0400")
        if metadata.st_nlink != 1:
            raise CustodyError(f"{name} has an unexpected hard-link count")
        if metadata.st_size != expected_bytes:
            raise CustodyError(f"{name} byte length mismatch")
        immutable_flag = getattr(stat, "UF_IMMUTABLE", 0)
        if immutable_flag == 0 or not (getattr(metadata, "st_flags", 0) & immutable_flag):
            raise CustodyError(f"{name} is not user-immutable")
        path_metadata = os.stat(
            name,
            dir_fd=directory_descriptor,
            follow_symlinks=False,
        )
        if _identity_tuple(path_metadata) != _identity_tuple(metadata):
            raise CustodyError(f"{name} path is not the opened file object")
        return descriptor, metadata
    except BaseException:
        os.close(descriptor)
        raise


def _hash_open_descriptor(
    descriptor: int,
    before: os.stat_result,
    name: str,
    expected_bytes: int,
    *,
    capture_prefix: int = 0,
) -> tuple[str, bytes]:
    os.lseek(descriptor, 0, os.SEEK_SET)
    digest = hashlib.sha256()
    prefix = bytearray()
    total = 0
    while True:
        chunk = os.read(descriptor, HASH_CHUNK_BYTES)
        if not chunk:
            break
        digest.update(chunk)
        total += len(chunk)
        if total > expected_bytes:
            raise CustodyError(f"{name} exceeds its fixed byte length")
        if len(prefix) < capture_prefix:
            prefix.extend(chunk[: capture_prefix - len(prefix)])
    if total != expected_bytes:
        raise CustodyError(f"{name} byte length changed while being read")
    after = os.fstat(descriptor)
    if _identity_tuple(after) != _identity_tuple(before):
        raise CustodyError(f"{name} changed while being read")
    return digest.hexdigest(), bytes(prefix)


def _read_open_small_file(
    descriptor: int,
    before: os.stat_result,
    name: str,
    expected_bytes: int,
) -> tuple[str, bytes]:
    if expected_bytes > MAX_SMALL_CUSTODY_BYTES:
        raise CustodyError(f"{name} exceeds the small-file budget")
    os.lseek(descriptor, 0, os.SEEK_SET)
    chunks: list[bytes] = []
    total = 0
    while True:
        chunk = os.read(descriptor, min(64 * 1024, expected_bytes + 1 - total))
        if not chunk:
            break
        chunks.append(chunk)
        total += len(chunk)
        if total > expected_bytes:
            raise CustodyError(f"{name} exceeds its fixed byte length")
    after = os.fstat(descriptor)
    if _identity_tuple(after) != _identity_tuple(before):
        raise CustodyError(f"{name} changed while being read")
    raw = b"".join(chunks)
    if len(raw) != expected_bytes:
        raise CustodyError(f"{name} byte length changed while being read")
    return hashlib.sha256(raw).hexdigest(), raw


def _require_same_custody_generation(
    directory: Path,
    directory_descriptor: int,
    directory_before: os.stat_result,
    files: dict[str, tuple[int, os.stat_result]],
) -> None:
    directory_after = os.fstat(directory_descriptor)
    if _identity_tuple(directory_after) != _identity_tuple(directory_before):
        raise CustodyError("opened custody directory generation changed")
    path_directory = os.lstat(directory)
    if _identity_tuple(path_directory) != _identity_tuple(directory_before):
        raise CustodyError("custody directory pathname changed generation")
    if set(os.listdir(directory_descriptor)) != _EXPECTED_NAMES:
        raise CustodyError("custody directory namespace changed")
    for name, (descriptor, before) in files.items():
        after = os.fstat(descriptor)
        if _identity_tuple(after) != _identity_tuple(before):
            raise CustodyError(f"opened {name} object changed")
        path_metadata = os.stat(
            name,
            dir_fd=directory_descriptor,
            follow_symlinks=False,
        )
        if _identity_tuple(path_metadata) != _identity_tuple(before):
            raise CustodyError(f"{name} pathname changed generation")


def _validate_custody_review(document: object) -> None:
    if not isinstance(document, dict):
        raise CustodyError("custody review is not a JSON object")
    if document.get("schema") != "qinao.a02-postcommit-custody-receipt.v1":
        raise CustodyError("custody review schema mismatch")
    authority = document.get("authority")
    if authority != {
        "semanticAuthority": "none",
        "nonAuthoritative": True,
        "installable": False,
        "role": "custody-and-rebuild-evidence-only",
        "externalV1Transition02PredecessorEvidence": "not-obtained",
        "a03Admission": "closed",
    }:
        raise CustodyError("custody review authority boundary mismatch")
    a02_commit = document.get("a02Commit")
    if not isinstance(a02_commit, dict) or (
        a02_commit.get("ref")
        != "refs/heads/codex/qinao-a02-provisional-verifier-20260828"
        or a02_commit.get("commit") != A02_COMMIT
        or a02_commit.get("tree") != A02_TREE
    ):
        raise CustodyError("custody review A0.2 commit/tree mismatch")
    capsule = document.get("capsule")
    if not isinstance(capsule, dict) or (
        capsule.get("file") != CUSTODY_BUNDLE_NAME
        or capsule.get("kind") != "git-bundle"
        or capsule.get("objectFormat") != "sha1"
        or capsule.get("bytes") != CUSTODY_BUNDLE_BYTES
        or capsule.get("sha256") != CUSTODY_BUNDLE_SHA256
        or capsule.get("gitBundleVerify") != "pass-complete-history"
        or capsule.get("refs") != BUNDLE_REFS
        or capsule.get("scope")
        != {
            "selfContainedForA02RequiredGitObjects": True,
            "selfContainedForAllExternalGitLFSPayloads": False,
            "statement": (
                "The capsule preserves the Git object closure required to rebuild "
                "and verify A0.2. Git LFS payloads stored outside Git object storage "
                "are not claimed to be included."
            ),
        }
    ):
        raise CustodyError("custody review capsule identity/scope mismatch")
    projection = document.get("projection")
    if not isinstance(projection, dict) or (
        projection.get("treeAfter0802Only") != REVIEW_BASE_TREE
        or projection.get("treeAfter0802Then0810Only") != CANDIDATE_TREE
        or projection.get("digest") != A02_PROJECTION_DIGEST
    ):
        raise CustodyError("custody review projection mismatch")
    hard_gates = document.get("hardGates")
    if (
        not isinstance(hard_gates, dict)
        or hard_gates.get("deepScan3") != "not-started-and-not-authorized"
    ):
        raise CustodyError("custody review Deep Scan boundary mismatch")


def _paths_overlap(left: Path, right: Path) -> bool:
    return left == right or left in right.parents or right in left.parents


def _parse_registered_worktrees(raw: bytes) -> list[Path]:
    if not raw.endswith(b"\0\0"):
        raise CustodyError("Git worktree inventory is not NUL-terminated")
    records = raw[:-2].split(b"\0\0")
    if not records or len(records) > MAX_REGISTERED_WORKTREES:
        raise CustodyError("Git worktree inventory cardinality is invalid")
    worktrees: list[Path] = []
    for record in records:
        fields = record.split(b"\0")
        if not fields or any(field == b"" for field in fields):
            raise CustodyError("Git worktree inventory record is malformed")
        worktree_fields = [
            field[len(b"worktree ") :]
            for field in fields
            if field.startswith(b"worktree ")
        ]
        if len(worktree_fields) != 1 or not fields[0].startswith(b"worktree "):
            raise CustodyError("Git worktree inventory lacks one leading path")
        if any(field == b"prunable" or field.startswith(b"prunable ") for field in fields):
            raise CustodyError("Git worktree inventory contains a prunable entry")
        try:
            path_text = worktree_fields[0].decode("utf-8", "strict")
        except UnicodeError as error:
            raise CustodyError("Git worktree path is not UTF-8") from error
        path = Path(path_text)
        if not path.is_absolute():
            raise CustodyError("Git worktree path is not absolute")
        resolved = path.resolve(strict=True)
        if not resolved.is_dir():
            raise CustodyError("registered Git worktree is not a directory")
        worktrees.append(resolved)
    if len(set(worktrees)) != len(worktrees):
        raise CustodyError("Git worktree inventory contains duplicate paths")
    return worktrees


def _require_absent_alternate_database_files(object_database: Path) -> None:
    for name in ("alternates", "http-alternates"):
        path = object_database / "info" / name
        try:
            os.lstat(path)
        except FileNotFoundError:
            continue
        raise CustodyError(f"primary object database {name} file must be absent")


def _repository_storage_roots(
    repository: Path,
) -> tuple[dict[str, Path], str]:
    resolved = repository.resolve(strict=True)
    if not resolved.is_dir():
        raise CustodyError("repository path is not a directory")
    commands = {
        "worktree": ["-C", str(resolved), "rev-parse", "--show-toplevel"],
        "gitDirectory": [
            "-C",
            str(resolved),
            "rev-parse",
            "--absolute-git-dir",
        ],
        "gitCommonDirectory": [
            "-C",
            str(resolved),
            "rev-parse",
            "--path-format=absolute",
            "--git-common-dir",
        ],
        "primaryObjectDatabase": [
            "-C",
            str(resolved),
            "rev-parse",
            "--path-format=absolute",
            "--git-path",
            "objects",
        ],
    }
    roots: dict[str, Path] = {}
    for label, command in commands.items():
        raw = _run_git(command, cwd=resolved)
        if not raw.endswith(b"\n") or b"\n" in raw[:-1]:
            raise CustodyError(f"{label} path observation is malformed")
        try:
            text = raw[:-1].decode("utf-8", "strict")
        except UnicodeError as error:
            raise CustodyError(f"{label} path is not UTF-8") from error
        if not text:
            raise CustodyError(f"{label} path observation is malformed")
        roots[label] = Path(text).resolve(strict=True)
    worktree_raw = _run_git(
        ["-C", str(resolved), "worktree", "list", "--porcelain", "-z"],
        cwd=resolved,
    )
    worktrees = _parse_registered_worktrees(worktree_raw)
    for index, worktree in enumerate(worktrees):
        roots[f"registeredWorktree[{index}]"] = worktree
    _require_absent_alternate_database_files(roots["primaryObjectDatabase"])
    snapshot = hashlib.sha256(
        b"QINAO-A03-REPOSITORY-STORAGE-SNAPSHOT-V1\0"
        + worktree_raw
        + b"\0".join(
            f"{label}={path}".encode("utf-8")
            for label, path in sorted(roots.items())
        )
        + b"\0alternates=absent\0http-alternates=absent"
    ).hexdigest()
    return roots, snapshot


def _require_repository_external_custody(
    repository: Path,
    custody_directory: Path,
) -> tuple[dict[str, object], str]:
    custody_directory = custody_directory.resolve(strict=True)
    roots, snapshot = _repository_storage_roots(repository)
    for label, root in roots.items():
        if _paths_overlap(custody_directory, root):
            raise CustodyError(f"custody directory overlaps repository {label}")
    return {
        "canonicalPathWorktreeDisjoint": True,
        "canonicalPathAllRegisteredWorktreesDisjoint": True,
        "canonicalPathGitDirectoryDisjoint": True,
        "canonicalPathGitCommonDirectoryDisjoint": True,
        "canonicalPathPrimaryObjectDatabaseDisjoint": True,
        "primaryObjectDatabaseAlternatesFile": "absent",
        "primaryObjectDatabaseHttpAlternatesFile": "absent",
        "environmentAlternateObjectDatabasesInherited": False,
        "mountAliasIsolation": "notProven",
    }, snapshot


def _run_bound_bundle_command(
    bundle_descriptor: int,
    operation: str,
    repository: Path,
) -> bytes:
    if operation not in {"verify", "list-heads"}:
        raise CustodyError("unsupported bundle observation operation")
    inherited = os.dup(bundle_descriptor)
    try:
        os.lseek(inherited, 0, os.SEEK_SET)
        return _run_git(
            ["bundle", operation, f"/dev/fd/{inherited}"],
            cwd=repository,
            pass_fds=(inherited,),
        )
    finally:
        os.close(inherited)


def _observe_bound_custody(
    repository: Path,
    custody_directory: Path,
    *,
    bundle_consumer: object | None = None,
) -> dict[str, object] | tuple[dict[str, object], object]:
    repository = repository.resolve(strict=True)
    directory = custody_directory.resolve(strict=True)
    if directory != custody_directory.expanduser().absolute():
        raise CustodyError("custody directory must be an exact canonical path")
    expected_sizes = {
        CUSTODY_BUNDLE_NAME: CUSTODY_BUNDLE_BYTES,
        CUSTODY_MANIFEST_NAME: CUSTODY_MANIFEST_BYTES,
        CUSTODY_REVIEW_NAME: CUSTODY_REVIEW_BYTES,
        CUSTODY_RECOVERY_NAME: CUSTODY_RECOVERY_BYTES,
    }
    directory_descriptor = -1
    files: dict[str, tuple[int, os.stat_result]] = {}
    try:
        directory_descriptor, directory_before = _open_custody_directory(directory)
        for name in sorted(_EXPECTED_NAMES):
            files[name] = _open_mode_restricted_file(
                directory_descriptor,
                name,
                expected_sizes[name],
            )
        externality, repository_boundary_snapshot = (
            _require_repository_external_custody(repository, directory)
        )
        _require_same_custody_generation(
            directory,
            directory_descriptor,
            directory_before,
            files,
        )

        manifest_descriptor, manifest_before = files[CUSTODY_MANIFEST_NAME]
        manifest_sha, manifest_raw = _read_open_small_file(
            manifest_descriptor,
            manifest_before,
            CUSTODY_MANIFEST_NAME,
            CUSTODY_MANIFEST_BYTES,
        )
        if (
            manifest_sha != CUSTODY_MANIFEST_SHA256
            or manifest_raw != _EXPECTED_MANIFEST
        ):
            raise CustodyError("custody manifest bytes mismatch")

        review_descriptor, review_before = files[CUSTODY_REVIEW_NAME]
        review_sha, review_raw = _read_open_small_file(
            review_descriptor,
            review_before,
            CUSTODY_REVIEW_NAME,
            CUSTODY_REVIEW_BYTES,
        )
        if review_sha != CUSTODY_REVIEW_SHA256:
            raise CustodyError("custody review SHA-256 mismatch")
        review = json.loads(
            review_raw.decode("utf-8", "strict"),
            object_pairs_hook=_strict_json_object,
        )
        _validate_custody_review(review)

        recovery_descriptor, recovery_before = files[CUSTODY_RECOVERY_NAME]
        recovery_sha, recovery_raw = _read_open_small_file(
            recovery_descriptor,
            recovery_before,
            CUSTODY_RECOVERY_NAME,
            CUSTODY_RECOVERY_BYTES,
        )
        if recovery_sha != CUSTODY_RECOVERY_SHA256:
            raise CustodyError("custody recovery guide SHA-256 mismatch")

        bundle_descriptor, bundle_before = files[CUSTODY_BUNDLE_NAME]
        bundle_sha, bundle_prefix = _hash_open_descriptor(
            bundle_descriptor,
            bundle_before,
            CUSTODY_BUNDLE_NAME,
            CUSTODY_BUNDLE_BYTES,
            capture_prefix=MAX_BUNDLE_HEADER_BYTES,
        )
        if bundle_sha != CUSTODY_BUNDLE_SHA256:
            raise CustodyError("custody bundle SHA-256 mismatch")
        header_end = bundle_prefix.find(b"\n\n")
        if header_end < 0:
            raise CustodyError("custody bundle header exceeds its fixed budget")
        header = bundle_prefix[: header_end + 2]
        if header != _EXPECTED_BUNDLE_HEADER:
            raise CustodyError("custody bundle header/ref/prerequisite mismatch")

        _run_bound_bundle_command(bundle_descriptor, "verify", repository)
        list_heads = _run_bound_bundle_command(
            bundle_descriptor,
            "list-heads",
            repository,
        ).rstrip(b"\n")
        if list_heads != _EXPECTED_LIST_HEADS:
            raise CustodyError("custody bundle list-heads mismatch")

        consumer_result: object | None = None
        if bundle_consumer is not None:
            if not callable(bundle_consumer):
                raise CustodyError("bundle consumer is not callable")
            consumer_result = bundle_consumer(bundle_descriptor, bundle_before)

        bundle_sha_after, bundle_prefix_after = _hash_open_descriptor(
            bundle_descriptor,
            bundle_before,
            CUSTODY_BUNDLE_NAME,
            CUSTODY_BUNDLE_BYTES,
            capture_prefix=MAX_BUNDLE_HEADER_BYTES,
        )
        if bundle_sha_after != bundle_sha or bundle_prefix_after != bundle_prefix:
            raise CustodyError("custody bundle changed across Git observation")
        for name, expected_raw in (
            (CUSTODY_MANIFEST_NAME, manifest_raw),
            (CUSTODY_REVIEW_NAME, review_raw),
            (CUSTODY_RECOVERY_NAME, recovery_raw),
        ):
            descriptor, before = files[name]
            _sha_after, raw_after = _read_open_small_file(
                descriptor,
                before,
                name,
                expected_sizes[name],
            )
            if raw_after != expected_raw:
                raise CustodyError(f"{name} changed across Git observation")
        _require_same_custody_generation(
            directory,
            directory_descriptor,
            directory_before,
            files,
        )
        if directory.resolve(strict=True) != directory:
            raise CustodyError("custody directory canonical path changed")
        externality_after, repository_boundary_snapshot_after = (
            _require_repository_external_custody(repository, directory)
        )
        if (
            externality_after != externality
            or repository_boundary_snapshot_after != repository_boundary_snapshot
        ):
            raise CustodyError("repository storage boundary changed during observation")
        _require_same_custody_generation(
            directory,
            directory_descriptor,
            directory_before,
            files,
        )
    finally:
        for descriptor, _metadata in files.values():
            os.close(descriptor)
        if directory_descriptor >= 0:
            os.close(directory_descriptor)

    observation: dict[str, object] = {
        "classification": (
            "canonicalPathRepositoryExternalModeRestrictedCustodyObservation"
        ),
        "repositorySeparation": externality,
        "capsule": {
            "file": CUSTODY_BUNDLE_NAME,
            "bytes": CUSTODY_BUNDLE_BYTES,
            "sha256": CUSTODY_BUNDLE_SHA256,
        },
        "manifest": {
            "file": CUSTODY_MANIFEST_NAME,
            "sha256": CUSTODY_MANIFEST_SHA256,
            "targetCount": 3,
        },
        "postcommitReview": {
            "file": CUSTODY_REVIEW_NAME,
            "sha256": CUSTODY_REVIEW_SHA256,
        },
        "recoveryGuide": {
            "file": CUSTODY_RECOVERY_NAME,
            "sha256": CUSTODY_RECOVERY_SHA256,
        },
        "bundle": {
            "gitBundleVerify": "pass",
            "completeHistory": True,
            "objectFormat": "sha1",
            "refs": list(BUNDLE_REFS),
        },
        "filesystem": {
            "currentUidOwned": True,
            "directoryPosixMode0700": True,
            "filesPosixMode0400": True,
            "filesSingleLink": True,
            "userImmutable": True,
            "symlinksAccepted": False,
            "aclIsolation": "notProven",
            "sameUidCapabilityIsolation": "notProven",
            "directoryFdAnchored": True,
            "allFileDescriptorsHeldAcrossObservation": True,
            "bundleGitVerificationInput": "sameOpenFileObjectAsDigest",
            "postGitContentRehash": True,
        },
        "selfContainedForA02RequiredGitObjects": True,
        "selfContainedForAllExternalGitLFSPayloads": False,
        "controllerDurableClaimBound": False,
        "incumbentArtifactMeshReceiptBound": False,
        "semanticAuthority": "none",
    }
    if bundle_consumer is None:
        return observation
    return observation, consumer_result


def _prepare_projection_and_observe_custody(
    repository: Path,
    custody_directory: Path,
) -> tuple[dict[str, object], dict[str, object], dict[str, object]]:
    repository = repository.resolve(strict=True)
    module = _pinned_a02_module()
    roots_before, boundary_before = _repository_storage_roots(repository)
    source_object_database = roots_before["primaryObjectDatabase"]
    source_inventory_before = _object_database_metadata_inventory(
        source_object_database
    )

    def execute(
        bundle_descriptor: int,
        bundle_before: os.stat_result,
    ) -> tuple[dict[str, object], dict[str, object]]:
        return _execute_pinned_a02_from_bundle(
            repository,
            source_object_database,
            bundle_descriptor,
            bundle_before,
            module,
        )

    try:
        combined = _observe_bound_custody(
            repository,
            custody_directory,
            bundle_consumer=execute,
        )
    finally:
        roots_after, boundary_after = _repository_storage_roots(repository)
        if (
            boundary_after != boundary_before
            or roots_after != roots_before
            or roots_after["primaryObjectDatabase"] != source_object_database
        ):
            raise SourceIsolationError(
                "repository storage boundary changed across A0.3 observation"
            )
        source_inventory_after = _object_database_metadata_inventory(
            source_object_database
        )
        if source_inventory_after != source_inventory_before:
            raise SourceIsolationError(
                "source object database changed across A0.3 observation"
            )

    if not isinstance(combined, tuple) or len(combined) != 2:
        raise CustodyError("custody bundle execution result is malformed")
    custody, execution = combined
    if (
        not isinstance(custody, dict)
        or not isinstance(execution, tuple)
        or len(execution) != 2
        or not isinstance(execution[1], dict)
    ):
        raise CustodyError("custody bundle execution result is malformed")
    projection = _validate_a02_projection(execution[0])
    return projection, execution[1], custody


def _expected_source_observations() -> list[dict[str, object]]:
    return [
        {
            "role": "design08_02ReviewSource",
            "commitOid": SOURCE_0802_COMMIT,
            "treeOid": SOURCE_0802_TREE,
            "tuple": dict(SOURCE_TUPLES[0]),
            "semanticAuthority": "none",
        },
        {
            "role": "design08_10PreservationSource",
            "commitOid": SOURCE_0810_COMMIT,
            "treeOid": SOURCE_0810_TREE,
            "tuple": dict(SOURCE_TUPLES[1]),
            "semanticAuthority": "none",
        },
    ]


def _validate_a02_projection(projection: object) -> dict[str, object]:
    if not isinstance(projection, dict):
        raise SourceIdentityError("A0.2 projection is not a JSON object")
    canonical = (
        json.dumps(
            projection,
            ensure_ascii=False,
            sort_keys=True,
            separators=(",", ":"),
        ).encode("utf-8")
        + b"\n"
    )
    if hashlib.sha256(canonical).hexdigest() != A02_FROZEN_SHA256:
        raise SourceIdentityError("A0.2 full canonical output identity mismatch")
    expected_observations = _expected_source_observations()
    projection_source = projection.get("projectionSource")
    deterministic = projection.get("deterministicProjection")
    authority_gate = projection.get("authorityGate")
    expected_authority_gate = {
        "state": "blocked",
        "blockers": [
            {
                "code": (
                    "BLOCKED_V1_TRANSITION02_PREDECESSOR_EVIDENCE_"
                    "UNAVAILABLE_TO_PROVISIONAL_CAPABILITY"
                ),
                "waivable": False,
            }
        ],
        "currentCodePathEffects": {
            "authorityClaimCalls": 0,
            "authorityCommitCalls": 0,
            "authorityRefMutationCalls": 0,
            "authoritySignerCalls": 0,
        },
    }
    if (
        projection.get("schema") != A02_SCHEMA
        or projection.get("semanticAuthority") != "none"
        or projection.get("nonAuthoritative") is not True
        or projection.get("installable") is not False
        or projection.get("projectionDigest") != A02_PROJECTION_DIGEST
        or not isinstance(projection_source, dict)
        or projection_source.get("selectedDevelopmentBootstrapCommit")
        != BOOTSTRAP_COMMIT
        or projection_source.get("selectedDevelopmentBootstrapTree") != BOOTSTRAP_TREE
        or projection_source.get("orderedSourceTuples") != SOURCE_TUPLES
        or projection_source.get("sourceObservations") != expected_observations
        or not isinstance(deterministic, dict)
        or deterministic.get("reviewTreeAfter0802") != REVIEW_BASE_TREE
        or deterministic.get("projectedTreeOidEphemeral") != CANDIDATE_TREE
        or deterministic.get("changedEntryCount") != 1
        or deterministic.get("onlyChangedPath") != PATH_0810
        or authority_gate != expected_authority_gate
    ):
        raise SourceIdentityError("A0.2 projection does not match the closed identity")
    return projection


def _identity_digest(value: dict[str, object]) -> str:
    canonical = json.dumps(
        value,
        ensure_ascii=False,
        sort_keys=True,
        separators=(",", ":"),
    ).encode("utf-8")
    domain = b"QINAO-A03-DESIGN-SOURCE-IDENTITY-FREEZE-V1\0"
    return hashlib.sha256(
        domain + len(canonical).to_bytes(8, "big") + canonical
    ).hexdigest()


def prepare_identity_freeze(
    repository: Path,
    custody_directory: Path,
) -> dict[str, object]:
    """Prepare one blocked A0.3a identity after exact A0.2/custody observation."""

    raw_projection, execution_isolation, custody = (
        _prepare_projection_and_observe_custody(repository, custody_directory)
    )
    projection = _validate_a02_projection(raw_projection)
    a02_erratum = _verified_a02_erratum()
    result: dict[str, object] = {
        "schema": SCHEMA,
        "semanticAuthority": "none",
        "nonAuthoritative": True,
        "installable": False,
        "a03Complete": False,
        "phase": {
            "stage": "A0.3a",
            "completion": "partialBlocked",
            "opensA04": False,
        },
        "derivation": {
            "derivationSource": "A0.2.prepare_provisional",
            "verificationInheritance": "fixedIdentityFactsOnlyWithBoundErratum",
            "independentFailureDomains": False,
            "sourceObjectEpochBinding": "notProven",
            "executionIsolation": execution_isolation,
            "historicalA02ClaimDisposition": {
                "jsonPointer": (
                    "/deterministicProjection/sharedObjectDatabaseWrites"
                ),
                "historicalValue": 0,
                "status": "supersededAsOverbroad",
                "counterexample": "alternatePackedObjectMtimeFreshenObserved",
                "acceptedSemanticScope": "none",
                "boundErratum": a02_erratum,
            },
            "a02Implementation": {
                "relativePath": A02_SOURCE_RELATIVE_PATH,
                "byteLength": A02_SOURCE_BYTES,
                "gitBlob": A02_SOURCE_GIT_BLOB,
                "sha256": A02_SOURCE_SHA256,
                "loadMethod": "verifiedBytesDirectExecPerInvocation",
            },
            "a02OutputValidation": "fullCanonicalBytesSha256",
        },
        "designSourceIdentity": {
            "orderedSourceTuples": [dict(value) for value in SOURCE_TUPLES],
            "sourceObservations": _expected_source_observations(),
            "orderMeaning": "08-02-then-08-10",
        },
        "designProjectionIdentity": {
            "a02Commit": A02_COMMIT,
            "a02Tree": A02_TREE,
            "a02FrozenProjectionSha256": A02_FROZEN_SHA256,
            "a02ProjectionDigest": projection["projectionDigest"],
            "bootstrapCommit": BOOTSTRAP_COMMIT,
            "bootstrapTree": BOOTSTRAP_TREE,
            "reviewBaseTree": REVIEW_BASE_TREE,
            "transitionCandidateTree": CANDIDATE_TREE,
            "changedEntryCount": 1,
            "onlyChangedPath": PATH_0810,
        },
        "custodyEvidence": custody,
        "predecessorEvidence": {
            "governedInputState": "notBound",
            "globalNonexistenceClaimed": False,
            "historicalV1TerminalVariants": [
                "signedDesignEdgeReceipt",
                "exactAlreadyPresentTerminal",
            ],
            "requiredShapeResolution": "externalAmendmentRequired",
        },
        "authorityGate": {
            "state": "blocked",
            "blockers": [
                {"code": code, "waivable": False}
                for code in BLOCKERS
            ],
            "currentCodePathEffects": dict(ZERO_AUTHORITY_EFFECTS),
        },
        "deepScan3": "notStartedAndNotAuthorized",
    }
    result["identityDigest"] = _identity_digest(result)
    return result


def _evaluation_unavailable_document() -> dict[str, object]:
    return {
        "schema": SCHEMA,
        "semanticAuthority": "none",
        "evaluationDisposition": "evaluationUnavailable",
        "nonAuthoritative": True,
        "installable": False,
        "a03Complete": False,
        "phase": {
            "completion": "evaluationUnavailable",
            "opensA04": False,
        },
        "authorityGate": {
            "state": "blocked",
            "blockers": [
                {
                    "code": "BLOCKED_EVALUATION_UNAVAILABLE",
                    "waivable": False,
                }
            ],
            "currentCodePathEffects": dict(ZERO_AUTHORITY_EFFECTS),
        },
        "deepScan3": "notStartedAndNotAuthorized",
    }


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description=(
            "Rebuild the exact A0.3a source-identity projection; "
            "this command is never an authority terminal."
        )
    )
    parser.add_argument(
        "--repository",
        required=True,
        type=Path,
        help="Repository containing the exact A0.2 source objects.",
    )
    parser.add_argument(
        "--custody-directory",
        required=True,
        type=Path,
        help="Mode-restricted repository-external A0.2 custody directory.",
    )
    return parser


def main(arguments: Sequence[str] | None = None) -> int:
    parsed = _parser().parse_args(arguments)
    try:
        result = prepare_identity_freeze(
            parsed.repository,
            parsed.custody_directory,
        )
        sys.stdout.write(
            json.dumps(
                result,
                ensure_ascii=False,
                sort_keys=True,
                separators=(",", ":"),
            )
            + "\n"
        )
        return EXIT_BLOCKED
    except (OSError, RuntimeError, UnicodeError, ValueError):
        unavailable = _evaluation_unavailable_document()
        sys.stderr.write(
            json.dumps(
                unavailable,
                ensure_ascii=False,
                sort_keys=True,
                separators=(",", ":"),
            )
            + "\n"
        )
        return EXIT_UNAVAILABLE


if __name__ == "__main__":
    raise SystemExit(main())
