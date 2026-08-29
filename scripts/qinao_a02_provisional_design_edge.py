#!/usr/bin/env python3
"""Rebuild the non-authoritative A0.2 design-source byte projection.

This module's public API deliberately has no authority-bearing input or effect
surface.  Its current code path inspects fixed Git objects and reconstructs two
review-only trees inside an ephemeral bare repository.  It does not validate
authority, open a durable identity, publish an authority artifact, create a
commit, or move a ref.  Python itself is not an OS capability sandbox; an
external build/runtime confinement proof remains required before stronger
physical-isolation claims can be made.

The command always exits non-zero after a successful reconstruction because
this capability cannot accept or evaluate external V1 transition-02
predecessor evidence.  Its JSON is conditionally reproducible review evidence
while the pinned source objects remain available, never an admission result or
a claim that external evidence does not exist.
"""

from __future__ import annotations

import argparse
import fcntl
import hashlib
import json
import os
import re
import selectors
import signal
import stat
import subprocess
import sys
import tempfile
import time
import unicodedata
from contextlib import contextmanager
from dataclasses import dataclass
from pathlib import Path
from typing import Callable, Iterator, Sequence


GIT = Path("/usr/bin/git")
SCHEMA = "qinao-a02-provisional-review-projection-v1"
BLOCKER = (
    "BLOCKED_V1_TRANSITION02_PREDECESSOR_EVIDENCE_"
    "UNAVAILABLE_TO_PROVISIONAL_CAPABILITY"
)
EXIT_BLOCKED = 40
RUNTIME_ROOT = Path("/private/tmp/qinao-a02-provisional-runtime-v1")
COMMAND_TIMEOUT_SECONDS = 30.0
MAX_COMMAND_INPUT_BYTES = 16 * 1024 * 1024
MAX_COMMAND_STDOUT_BYTES = 32 * 1024 * 1024
MAX_COMMAND_STDERR_BYTES = 2 * 1024 * 1024
MAX_TREE_ENTRIES = 100_000
MAX_TREE_PATH_BYTES = 4096
MAX_SCRATCH_DELETE_ENTRIES = 200_000
MAX_SCRATCH_DELETE_DEPTH = 128

SELECTED_DEVELOPMENT_BOOTSTRAP_COMMIT = (
    "7e4aa2d626e2c94b1b1f3405fb8454e73448514f"
)
SELECTED_DEVELOPMENT_BOOTSTRAP_TREE = (
    "47304602b7d1c1eba8eed571dbc65ee36c3a5f21"
)
SOURCE_0802_COMMIT = "c8f80486895e12e26d567e610c35a6e2141b3489"
SOURCE_0802_TREE = "2f484874b8b6d49b8bcd595bf3a3ff6c835fb509"
SOURCE_0810_COMMIT = "4a9298db261bcfda97ea1748baad65649156ba66"
SOURCE_0810_TREE = "22382c1de6680a263ec4a2f4a6c989c0f0e6e220"
PREDICTED_REVIEW_TREE_AFTER_0802 = (
    "4fd48205c1716f9ce23efd8885c94afdcdf70311"
)
PREDICTED_REVIEW_TREE_AFTER_0810 = (
    "0fa81fb9d1c3498fd8bb75d4c46a048f3b64260e"
)


@dataclass(frozen=True)
class SourceTuple:
    path: str
    git_mode: str
    git_blob: str
    byte_length: int
    sha256: str

    def json_value(self) -> dict[str, object]:
        return {
            "path": self.path,
            "gitMode": self.git_mode,
            "gitBlob": self.git_blob,
            "byteLength": self.byte_length,
            "sha256": self.sha256,
        }


SOURCE_0802 = SourceTuple(
    path=(
        "docs/superpowers/specs/"
        "2026-08-02-qinao-biomimetic-sovereign-agent-system-design.md"
    ),
    git_mode="100644",
    git_blob="f3d4186769fd0119a418097fea8821d597770189",
    byte_length=81128,
    sha256="40d322f052425a7e56f03b826922181047c30ac908c35c922a5481e4ddf29aa6",
)
SOURCE_0810 = SourceTuple(
    path=(
        "docs/superpowers/specs/"
        "2026-08-10-qinao-global-invariant-firewall-and-recovery-design.md"
    ),
    git_mode="100644",
    git_blob="887c23a28fb9098d86d252aa8b6dc9153380738b",
    byte_length=233726,
    sha256="4eb06cde16e0cf5985c7272147ced9274dd83648a098772c8b5a06f7b3ebeab6",
)
SOURCE_TUPLES = (SOURCE_0802, SOURCE_0810)

ZERO_AUTHORITY_SIDE_EFFECTS = {
    "authoritySignerCalls": 0,
    "authorityClaimCalls": 0,
    "authorityCommitCalls": 0,
    "authorityRefMutationCalls": 0,
}

_HEX_OID = re.compile(r"[0-9a-f]{40}\Z")


class ProjectionError(RuntimeError):
    """The fixed byte projection cannot be reproduced exactly."""


@dataclass(frozen=True)
class TreeEntry:
    mode: str
    kind: str
    oid: str
    name: bytes


@dataclass(frozen=True)
class ProjectionSession:
    repository: Path
    git_dir: Path
    environment: dict[str, str]
    tree_after_0802: str
    tree_after_0810: str


def _base_environment() -> dict[str, str]:
    # Never let the caller redirect repository, object, index, replacement,
    # config, or transport behavior through inherited Git control variables.
    environment = {
        key: value
        for key, value in os.environ.items()
        if not key.startswith("GIT_")
    }
    environment.update(
        {
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
            "LC_ALL": "C",
            "PATH": "/usr/bin:/bin",
        }
    )
    return environment


def _run(
    command: Sequence[str],
    *,
    cwd: Path,
    environment: dict[str, str] | None = None,
    input_bytes: bytes | None = None,
) -> bytes:
    if input_bytes is not None and len(input_bytes) > MAX_COMMAND_INPUT_BYTES:
        raise ProjectionError("command input exceeds the fixed byte budget")

    process = subprocess.Popen(
        list(command),
        cwd=cwd,
        env=environment or _base_environment(),
        stdin=subprocess.PIPE if input_bytes is not None else subprocess.DEVNULL,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        start_new_session=True,
    )
    assert process.stdout is not None
    assert process.stderr is not None
    stdout = bytearray()
    stderr = bytearray()
    deadline = time.monotonic() + COMMAND_TIMEOUT_SECONDS
    try:
        with selectors.DefaultSelector() as streams:
            os.set_blocking(process.stdout.fileno(), False)
            os.set_blocking(process.stderr.fileno(), False)
            streams.register(
                process.stdout,
                selectors.EVENT_READ,
                ("output", stdout, MAX_COMMAND_STDOUT_BYTES),
            )
            streams.register(
                process.stderr,
                selectors.EVENT_READ,
                ("output", stderr, MAX_COMMAND_STDERR_BYTES),
            )
            input_view = memoryview(input_bytes or b"")
            input_offset = 0
            if input_bytes is not None:
                assert process.stdin is not None
                if input_view:
                    os.set_blocking(process.stdin.fileno(), False)
                    streams.register(
                        process.stdin,
                        selectors.EVENT_WRITE,
                        ("input", input_view, 0),
                    )
                else:
                    process.stdin.close()
            while streams.get_map():
                remaining = deadline - time.monotonic()
                if remaining <= 0:
                    raise ProjectionError("command exceeded the fixed time budget")
                events = streams.select(remaining)
                if not events:
                    raise ProjectionError("command exceeded the fixed time budget")
                for key, _ in events:
                    stream_kind, buffer, maximum = key.data
                    if stream_kind == "input":
                        try:
                            written = os.write(
                                key.fd,
                                input_view[input_offset : input_offset + 64 * 1024],
                            )
                        except BlockingIOError:
                            continue
                        except BrokenPipeError:
                            written = 0
                        input_offset += written
                        if written == 0 or input_offset == len(input_view):
                            streams.unregister(key.fileobj)
                            key.fileobj.close()
                        continue
                    try:
                        chunk = os.read(key.fd, 64 * 1024)
                    except BlockingIOError:
                        continue
                    if not chunk:
                        streams.unregister(key.fileobj)
                        key.fileobj.close()
                        continue
                    if len(buffer) + len(chunk) > maximum:
                        raise ProjectionError(
                            "command output exceeds the fixed byte budget"
                        )
                    buffer.extend(chunk)
        remaining = max(0.0, deadline - time.monotonic())
        try:
            return_code = process.wait(timeout=remaining)
        except subprocess.TimeoutExpired as error:
            raise ProjectionError("command exceeded the fixed time budget") from error
    except BaseException:
        try:
            os.killpg(process.pid, signal.SIGKILL)
        except ProcessLookupError:
            pass
        except PermissionError:
            try:
                process.kill()
            except ProcessLookupError:
                pass
        try:
            process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            pass
        raise
    finally:
        if process.stdin is not None and not process.stdin.closed:
            process.stdin.close()
        if not process.stdout.closed:
            process.stdout.close()
        if not process.stderr.closed:
            process.stderr.close()

    if return_code != 0:
        stderr_text = bytes(stderr).decode("utf-8", "replace").strip()
        raise ProjectionError(
            f"command failed ({return_code}): {command!r}: {stderr_text}"
        )
    return bytes(stdout)


def _repository_git(repository: Path, arguments: Sequence[str]) -> bytes:
    return _run(
        [str(GIT), "-C", str(repository), *arguments],
        cwd=repository,
    )


def _isolated_git(
    session_git_dir: Path,
    environment: dict[str, str],
    arguments: Sequence[str],
    *,
    input_bytes: bytes | None = None,
) -> bytes:
    return _run(
        [str(GIT), f"--git-dir={session_git_dir}", *arguments],
        cwd=session_git_dir.parent,
        environment=environment,
        input_bytes=input_bytes,
    )


def _one_line(raw: bytes, label: str) -> str:
    value = raw.decode("ascii", "strict").strip()
    if "\n" in value or not value:
        raise ProjectionError(f"{label} did not resolve to one value")
    return value


def _require_oid(value: str, label: str) -> str:
    if _HEX_OID.fullmatch(value) is None:
        raise ProjectionError(f"{label} is not a lowercase 40-hex Git object ID")
    return value


def _common_objects(repository: Path) -> Path:
    raw = _repository_git(repository, ["rev-parse", "--git-common-dir"])
    common = Path(raw.decode("utf-8", "strict").strip())
    if not common.is_absolute():
        common = (repository / common).resolve()
    objects = (common / "objects").resolve(strict=True)
    if not objects.is_dir():
        raise ProjectionError(f"Git object directory is unavailable: {objects}")
    return objects


def _validated_runtime_root(repository: Path, object_directory: Path) -> Path:
    try:
        os.mkdir(RUNTIME_ROOT, 0o700)
    except FileExistsError:
        pass
    metadata = os.lstat(RUNTIME_ROOT)
    if not stat.S_ISDIR(metadata.st_mode) or stat.S_ISLNK(metadata.st_mode):
        raise ProjectionError("provisional runtime root is not a real directory")
    if metadata.st_uid != os.getuid() or stat.S_IMODE(metadata.st_mode) != 0o700:
        raise ProjectionError("provisional runtime root ownership or mode mismatch")
    resolved = RUNTIME_ROOT.resolve(strict=True)
    if resolved != RUNTIME_ROOT:
        raise ProjectionError("provisional runtime root has redirected path components")

    forbidden_roots = {
        repository.resolve(strict=True),
        object_directory.resolve(strict=True),
        object_directory.parent.resolve(strict=True),
    }
    for forbidden in forbidden_roots:
        if resolved.is_relative_to(forbidden) or forbidden.is_relative_to(resolved):
            raise ProjectionError("provisional runtime root overlaps source state")
    return resolved


def _validate_private_directory_metadata(
    metadata: os.stat_result,
    label: str,
) -> None:
    if not stat.S_ISDIR(metadata.st_mode) or stat.S_ISLNK(metadata.st_mode):
        raise ProjectionError(f"{label} is not a real directory")
    if metadata.st_uid != os.getuid() or stat.S_IMODE(metadata.st_mode) != 0o700:
        raise ProjectionError(f"{label} ownership or mode mismatch")


def _validate_private_directory(path: Path, label: str) -> None:
    try:
        metadata = os.lstat(path)
    except OSError as error:
        raise ProjectionError(f"{label} is unavailable") from error
    _validate_private_directory_metadata(metadata, label)


def _validate_lock_file(path: Path, descriptor: int, label: str) -> None:
    try:
        opened = os.fstat(descriptor)
        linked = os.lstat(path)
    except OSError as error:
        raise ProjectionError(f"{label} is unavailable") from error
    if not stat.S_ISREG(opened.st_mode) or not stat.S_ISREG(linked.st_mode):
        raise ProjectionError(f"{label} is not a regular file")
    if (
        opened.st_dev != linked.st_dev
        or opened.st_ino != linked.st_ino
        or opened.st_uid != os.getuid()
        or stat.S_IMODE(opened.st_mode) != 0o600
        or opened.st_nlink != 1
    ):
        raise ProjectionError(f"{label} identity, ownership, or mode mismatch")


def _lock_open_flags() -> int:
    return os.O_RDWR | getattr(os, "O_CLOEXEC", 0) | getattr(os, "O_NOFOLLOW", 0)


def _create_lock_file(path: Path, label: str) -> int:
    try:
        descriptor = os.open(
            path,
            _lock_open_flags() | os.O_CREAT | os.O_EXCL,
            0o600,
        )
    except OSError as error:
        raise ProjectionError(f"could not create {label}") from error
    try:
        os.fchmod(descriptor, 0o600)
        _validate_lock_file(path, descriptor, label)
        return descriptor
    except BaseException:
        os.close(descriptor)
        raise


def _open_or_create_janitor_lock(runtime_root: Path) -> int:
    path = runtime_root / ".janitor.lock"
    try:
        return _create_lock_file(path, "runtime janitor lock")
    except ProjectionError as create_error:
        try:
            descriptor = os.open(path, _lock_open_flags())
        except OSError:
            raise create_error
        try:
            _validate_lock_file(path, descriptor, "runtime janitor lock")
            return descriptor
        except BaseException:
            os.close(descriptor)
            raise


def _open_existing_lease(path: Path) -> int:
    try:
        descriptor = os.open(path, _lock_open_flags())
    except OSError as error:
        raise ProjectionError("scratch lease is unavailable") from error
    try:
        _validate_lock_file(path, descriptor, "scratch lease")
        return descriptor
    except BaseException:
        os.close(descriptor)
        raise


def _path_is_absent(path: Path, label: str) -> bool:
    try:
        os.lstat(path)
    except FileNotFoundError:
        return True
    except OSError as error:
        raise ProjectionError(f"could not inspect {label}") from error
    return False


def _directory_open_flags() -> int:
    return (
        os.O_RDONLY
        | getattr(os, "O_CLOEXEC", 0)
        | getattr(os, "O_DIRECTORY", 0)
        | getattr(os, "O_NOFOLLOW", 0)
    )


def _clear_private_directory_fd(
    descriptor: int,
    *,
    root_device: int,
    budget: list[int],
    depth: int,
) -> None:
    if depth > MAX_SCRATCH_DELETE_DEPTH:
        raise ProjectionError("scratch directory depth exceeds the fixed budget")
    try:
        names = os.listdir(descriptor)
    except OSError as error:
        raise ProjectionError("could not enumerate scratch directory") from error
    for name in names:
        budget[0] += 1
        if budget[0] > MAX_SCRATCH_DELETE_ENTRIES:
            raise ProjectionError("scratch entry count exceeds the fixed budget")
        try:
            metadata = os.stat(name, dir_fd=descriptor, follow_symlinks=False)
        except FileNotFoundError:
            continue
        except OSError as error:
            raise ProjectionError("could not inspect scratch entry") from error
        if not stat.S_ISDIR(metadata.st_mode):
            try:
                os.unlink(name, dir_fd=descriptor)
            except FileNotFoundError:
                continue
            except OSError as error:
                raise ProjectionError("could not unlink scratch entry") from error
            continue
        if metadata.st_dev != root_device:
            raise ProjectionError("scratch directory crosses a device boundary")
        try:
            child_descriptor = os.open(
                name,
                _directory_open_flags(),
                dir_fd=descriptor,
            )
        except FileNotFoundError:
            continue
        except OSError as error:
            raise ProjectionError("could not open scratch directory") from error
        try:
            opened = os.fstat(child_descriptor)
            if not os.path.samestat(metadata, opened):
                raise ProjectionError("scratch directory identity changed")
            _clear_private_directory_fd(
                child_descriptor,
                root_device=root_device,
                budget=budget,
                depth=depth + 1,
            )
            try:
                current = os.stat(
                    name,
                    dir_fd=descriptor,
                    follow_symlinks=False,
                )
            except FileNotFoundError:
                continue
            if not os.path.samestat(opened, current):
                raise ProjectionError("scratch directory identity changed")
            try:
                os.rmdir(name, dir_fd=descriptor)
            except FileNotFoundError:
                continue
            except OSError as error:
                raise ProjectionError("could not remove scratch directory") from error
        finally:
            os.close(child_descriptor)


def _remove_private_directory_if_present(path: Path, label: str) -> None:
    runtime_root = path.parent
    if not path.name.startswith("session-"):
        raise ProjectionError("scratch session path is outside the closed namespace")
    try:
        root_descriptor = os.open(runtime_root, _directory_open_flags())
    except OSError as error:
        raise ProjectionError("could not open provisional runtime root") from error
    try:
        opened_root = os.fstat(root_descriptor)
        linked_root = os.lstat(runtime_root)
        _validate_private_directory_metadata(opened_root, "provisional runtime root")
        if not os.path.samestat(opened_root, linked_root):
            raise ProjectionError("provisional runtime root identity changed")
        try:
            metadata = os.stat(
                path.name,
                dir_fd=root_descriptor,
                follow_symlinks=False,
            )
        except FileNotFoundError:
            return
        _validate_private_directory_metadata(metadata, label)
        if metadata.st_dev != opened_root.st_dev or os.path.ismount(path):
            raise ProjectionError("scratch session is a mount point")
        try:
            session_descriptor = os.open(
                path.name,
                _directory_open_flags(),
                dir_fd=root_descriptor,
            )
        except FileNotFoundError:
            return
        try:
            opened_session = os.fstat(session_descriptor)
            if not os.path.samestat(metadata, opened_session):
                raise ProjectionError("scratch session identity changed")
            _clear_private_directory_fd(
                session_descriptor,
                root_device=opened_root.st_dev,
                budget=[0],
                depth=0,
            )
            try:
                current = os.stat(
                    path.name,
                    dir_fd=root_descriptor,
                    follow_symlinks=False,
                )
            except FileNotFoundError:
                return
            if not os.path.samestat(opened_session, current):
                raise ProjectionError("scratch session identity changed")
            try:
                os.rmdir(path.name, dir_fd=root_descriptor)
            except FileNotFoundError:
                return
            except OSError as error:
                raise ProjectionError("could not remove scratch session") from error
        finally:
            os.close(session_descriptor)
    finally:
        os.close(root_descriptor)


def _reap_stale_sessions(runtime_root: Path) -> None:
    for candidate in runtime_root.iterdir():
        if candidate.name == ".janitor.lock":
            continue
        if not candidate.name.startswith("session-"):
            raise ProjectionError("unexpected entry in provisional runtime root")
        try:
            _validate_private_directory(candidate, "scratch session")
        except ProjectionError:
            if _path_is_absent(candidate, "scratch session"):
                continue
            raise
        lease_path = candidate / "lease.lock"
        try:
            lease_descriptor = _open_existing_lease(lease_path)
        except ProjectionError:
            if not _path_is_absent(lease_path, "scratch lease"):
                raise
            _remove_private_directory_if_present(candidate, "scratch session")
            continue
        try:
            try:
                fcntl.flock(
                    lease_descriptor,
                    fcntl.LOCK_EX | fcntl.LOCK_NB,
                )
            except BlockingIOError:
                continue
            _remove_private_directory_if_present(candidate, "scratch session")
        finally:
            os.close(lease_descriptor)


@contextmanager
def _scratch_session(runtime_root: Path) -> Iterator[Path]:
    """Create leased scratch and reap prior sessions whose lease was lost."""

    _validate_private_directory(runtime_root, "provisional runtime root")
    janitor_descriptor = _open_or_create_janitor_lock(runtime_root)
    janitor_locked = False
    session: Path | None = None
    lease_descriptor: int | None = None
    try:
        fcntl.flock(janitor_descriptor, fcntl.LOCK_EX)
        janitor_locked = True
        _reap_stale_sessions(runtime_root)
        session = Path(tempfile.mkdtemp(prefix="session-", dir=runtime_root))
        _validate_private_directory(session, "scratch session")
        lease_descriptor = _create_lock_file(
            session / "lease.lock",
            "scratch lease",
        )
        fcntl.flock(lease_descriptor, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BaseException:
        try:
            if session is not None:
                _remove_private_directory_if_present(session, "scratch session")
        finally:
            if lease_descriptor is not None:
                os.close(lease_descriptor)
        raise
    finally:
        try:
            if janitor_locked:
                fcntl.flock(janitor_descriptor, fcntl.LOCK_UN)
        finally:
            os.close(janitor_descriptor)

    assert session is not None
    assert lease_descriptor is not None
    try:
        yield session
    finally:
        cleanup_janitor_descriptor: int | None = None
        cleanup_janitor_locked = False
        try:
            cleanup_janitor_descriptor = _open_or_create_janitor_lock(runtime_root)
            fcntl.flock(cleanup_janitor_descriptor, fcntl.LOCK_EX)
            cleanup_janitor_locked = True
            _remove_private_directory_if_present(session, "scratch session")
        finally:
            try:
                if cleanup_janitor_descriptor is not None:
                    try:
                        if cleanup_janitor_locked:
                            fcntl.flock(
                                cleanup_janitor_descriptor,
                                fcntl.LOCK_UN,
                            )
                    finally:
                        os.close(cleanup_janitor_descriptor)
            finally:
                os.close(lease_descriptor)


def _verify_fixed_commit_tree(
    repository: Path,
    commit_oid: str,
    expected_tree: str,
) -> None:
    resolved_commit = _one_line(
        _repository_git(repository, ["rev-parse", f"{commit_oid}^{{commit}}"]),
        "development bootstrap commit",
    )
    resolved_tree = _one_line(
        _repository_git(repository, ["rev-parse", f"{commit_oid}^{{tree}}"]),
        "development bootstrap tree",
    )
    if resolved_commit != commit_oid or resolved_tree != expected_tree:
        raise ProjectionError("fixed development bootstrap identity mismatch")


def _parse_ls_tree(raw: bytes) -> list[TreeEntry]:
    entries: list[TreeEntry] = []
    for record in raw.split(b"\0"):
        if not record:
            continue
        header, separator, name = record.partition(b"\t")
        if not separator:
            raise ProjectionError("malformed ls-tree record")
        if len(entries) >= MAX_TREE_ENTRIES:
            raise ProjectionError("tree entry count exceeds the fixed budget")
        if len(name) > MAX_TREE_PATH_BYTES:
            raise ProjectionError("tree path exceeds the fixed byte budget")
        fields = header.split(b" ")
        if len(fields) != 3:
            raise ProjectionError("malformed ls-tree header")
        mode, kind, oid = (field.decode("ascii", "strict") for field in fields)
        _require_oid(oid, "ls-tree object")
        entries.append(TreeEntry(mode=mode, kind=kind, oid=oid, name=name))
    return entries


def _repository_entries(repository: Path, tree_oid: str) -> list[TreeEntry]:
    _require_oid(tree_oid, "tree")
    object_type = _one_line(
        _repository_git(repository, ["cat-file", "-t", tree_oid]),
        "tree object type",
    )
    if object_type != "tree":
        raise ProjectionError(f"object is {object_type}, not an exact tree")
    raw = _repository_git(repository, ["ls-tree", "-z", tree_oid])
    return _parse_ls_tree(raw)


def _repository_recursive_entries(repository: Path, tree_oid: str) -> list[TreeEntry]:
    _require_oid(tree_oid, "tree")
    object_type = _one_line(
        _repository_git(repository, ["cat-file", "-t", tree_oid]),
        "tree object type",
    )
    if object_type != "tree":
        raise ProjectionError(f"object is {object_type}, not an exact tree")
    raw = _repository_git(repository, ["ls-tree", "-r", "-z", tree_oid])
    return _parse_ls_tree(raw)


def _isolated_entries(session: ProjectionSession, tree_oid: str) -> list[TreeEntry]:
    _require_oid(tree_oid, "tree")
    object_type = _one_line(
        _isolated_git(
            session.git_dir,
            session.environment,
            ["cat-file", "-t", tree_oid],
        ),
        "tree object type",
    )
    if object_type != "tree":
        raise ProjectionError(f"object is {object_type}, not an exact tree")
    raw = _isolated_git(
        session.git_dir,
        session.environment,
        ["ls-tree", "-z", tree_oid],
    )
    return _parse_ls_tree(raw)


def _isolated_recursive_entries(
    session: ProjectionSession,
    tree_oid: str,
) -> list[TreeEntry]:
    _require_oid(tree_oid, "tree")
    object_type = _one_line(
        _isolated_git(
            session.git_dir,
            session.environment,
            ["cat-file", "-t", tree_oid],
        ),
        "tree object type",
    )
    if object_type != "tree":
        raise ProjectionError(f"object is {object_type}, not an exact tree")
    raw = _isolated_git(
        session.git_dir,
        session.environment,
        ["ls-tree", "-r", "-z", tree_oid],
    )
    return _parse_ls_tree(raw)


def _entry_at_path(
    entries_for_tree: Callable[[str], list[TreeEntry]],
    tree_oid: str,
    path: str,
) -> TreeEntry | None:
    current_tree = tree_oid
    components = [component.encode("utf-8") for component in path.split("/")]
    for index, component in enumerate(components):
        matches = [entry for entry in entries_for_tree(current_tree) if entry.name == component]
        if len(matches) > 1:
            raise ProjectionError(f"duplicate tree entry at {path}")
        if not matches:
            return None
        entry = matches[0]
        if index == len(components) - 1:
            return entry
        if entry.kind != "tree" or entry.mode != "040000":
            return entry
        current_tree = entry.oid
    raise AssertionError("path must contain at least one component")


def _repository_blob(repository: Path, oid: str) -> bytes:
    return _repository_git(repository, ["cat-file", "blob", oid])


def _isolated_blob(session: ProjectionSession, oid: str) -> bytes:
    return _isolated_git(
        session.git_dir,
        session.environment,
        ["cat-file", "blob", oid],
    )


def _entry_matches(
    entry: TreeEntry | None,
    source: SourceTuple,
    blob_reader: Callable[[str], bytes],
) -> bool:
    if entry is None:
        return False
    if (
        entry.mode != source.git_mode
        or entry.kind != "blob"
        or entry.oid != source.git_blob
    ):
        return False
    raw = blob_reader(entry.oid)
    return (
        len(raw) == source.byte_length
        and hashlib.sha256(raw).hexdigest() == source.sha256
    )


def _path_collision_key(raw: bytes) -> str | None:
    try:
        value = raw.decode("utf-8", "strict")
    except UnicodeDecodeError:
        return None
    return unicodedata.normalize("NFC", value).casefold().rstrip(" .")


def _verify_source_object(
    repository: Path,
    source_commit: str,
    expected_tree: str,
    source: SourceTuple,
) -> None:
    resolved = _one_line(
        _repository_git(repository, ["rev-parse", f"{source_commit}^{{commit}}"]),
        f"source commit for {source.path}",
    )
    if resolved != source_commit:
        raise ProjectionError(f"source commit mismatch for {source.path}")
    resolved_tree = _one_line(
        _repository_git(repository, ["rev-parse", f"{source_commit}^{{tree}}"]),
        f"source tree for {source.path}",
    )
    if resolved_tree != expected_tree:
        raise ProjectionError(f"source tree mismatch for {source.path}")
    entry = _entry_at_path(
        lambda tree: _repository_entries(repository, tree),
        resolved_tree,
        source.path,
    )
    if not _entry_matches(entry, source, lambda oid: _repository_blob(repository, oid)):
        raise ProjectionError(f"fixed source tuple mismatch for {source.path}")


def _rewrite_tree_path(
    git_dir: Path,
    environment: dict[str, str],
    tree_oid: str,
    components: Sequence[bytes],
    source: SourceTuple,
) -> str:
    entries = _parse_ls_tree(
        _isolated_git(git_dir, environment, ["ls-tree", "-z", tree_oid])
    )
    target = components[0]
    by_name = {entry.name: entry for entry in entries}
    if len(by_name) != len(entries):
        raise ProjectionError("tree contains duplicate names")

    if len(components) == 1:
        by_name[target] = TreeEntry(
            mode=source.git_mode,
            kind="blob",
            oid=source.git_blob,
            name=target,
        )
    else:
        child = by_name.get(target)
        if child is None or child.kind != "tree" or child.mode != "040000":
            raise ProjectionError(f"missing parent directory for {source.path}")
        child_oid = _rewrite_tree_path(
            git_dir,
            environment,
            child.oid,
            components[1:],
            source,
        )
        by_name[target] = TreeEntry(
            mode="040000",
            kind="tree",
            oid=child_oid,
            name=target,
        )

    payload = b"".join(
        entry.mode.encode("ascii")
        + b" "
        + entry.kind.encode("ascii")
        + b" "
        + entry.oid.encode("ascii")
        + b"\t"
        + entry.name
        + b"\0"
        for entry in by_name.values()
    )
    return _one_line(
        _isolated_git(
            git_dir,
            environment,
            ["mktree", "-z"],
            input_bytes=payload,
        ),
        f"rewritten tree for {source.path}",
    )


def _verify_one_path_delta(
    session_git_dir: Path,
    environment: dict[str, str],
    base_tree: str,
    candidate_tree: str,
    source: SourceTuple,
) -> None:
    raw = _isolated_git(
        session_git_dir,
        environment,
        [
            "diff-tree",
            "-r",
            "--no-commit-id",
            "--name-status",
            "-z",
            base_tree,
            candidate_tree,
        ],
    )
    if raw != b"A\0" + source.path.encode("utf-8") + b"\0":
        raise ProjectionError(f"projection is not the exact one-path delta: {source.path}")


@contextmanager
def _projection_session(repository: Path) -> Iterator[ProjectionSession]:
    repository = repository.resolve(strict=True)
    if not repository.is_dir():
        raise ProjectionError(f"repository is not a directory: {repository}")

    _verify_fixed_commit_tree(
        repository,
        SELECTED_DEVELOPMENT_BOOTSTRAP_COMMIT,
        SELECTED_DEVELOPMENT_BOOTSTRAP_TREE,
    )
    _verify_source_object(
        repository,
        SOURCE_0802_COMMIT,
        SOURCE_0802_TREE,
        SOURCE_0802,
    )
    _verify_source_object(
        repository,
        SOURCE_0810_COMMIT,
        SOURCE_0810_TREE,
        SOURCE_0810,
    )
    object_directory = _common_objects(repository)
    runtime_root = _validated_runtime_root(repository, object_directory)

    with _scratch_session(runtime_root) as temp:
        git_dir = temp / "objects-only.git"
        empty_template = temp / "empty-git-template"
        empty_template.mkdir(mode=0o700)
        _run(
            [
                str(GIT),
                "init",
                "--bare",
                "--object-format=sha1",
                f"--template={empty_template}",
                str(git_dir),
            ],
            cwd=temp,
        )
        alternate_object_link = temp / "source-objects"
        os.symlink(
            str(object_directory),
            alternate_object_link,
            target_is_directory=True,
        )
        alternate_metadata = os.lstat(alternate_object_link)
        if (
            not stat.S_ISLNK(alternate_metadata.st_mode)
            or os.readlink(alternate_object_link) != str(object_directory)
        ):
            raise ProjectionError("source object link identity mismatch")
        environment = _base_environment()
        environment["GIT_ALTERNATE_OBJECT_DIRECTORIES"] = str(
            alternate_object_link
        )
        environment["GIT_INDEX_FILE"] = str(temp / "projection.index")

        _isolated_git(
            git_dir,
            environment,
            ["read-tree", SELECTED_DEVELOPMENT_BOOTSTRAP_TREE],
        )
        _isolated_git(
            git_dir,
            environment,
            [
                "update-index",
                "--add",
                "--cacheinfo",
                SOURCE_0802.git_mode,
                SOURCE_0802.git_blob,
                SOURCE_0802.path,
            ],
        )
        index_tree_0802 = _one_line(
            _isolated_git(git_dir, environment, ["write-tree"]),
            "index projection after 08-02",
        )
        structural_tree_0802 = _rewrite_tree_path(
            git_dir,
            environment,
            SELECTED_DEVELOPMENT_BOOTSTRAP_TREE,
            [part.encode("utf-8") for part in SOURCE_0802.path.split("/")],
            SOURCE_0802,
        )
        if not (
            index_tree_0802
            == structural_tree_0802
            == PREDICTED_REVIEW_TREE_AFTER_0802
        ):
            raise ProjectionError("independent 08-02 tree calculations disagree")

        _isolated_git(
            git_dir,
            environment,
            [
                "update-index",
                "--add",
                "--cacheinfo",
                SOURCE_0810.git_mode,
                SOURCE_0810.git_blob,
                SOURCE_0810.path,
            ],
        )
        index_tree_0810 = _one_line(
            _isolated_git(git_dir, environment, ["write-tree"]),
            "index projection after 08-10",
        )
        structural_tree_0810 = _rewrite_tree_path(
            git_dir,
            environment,
            structural_tree_0802,
            [part.encode("utf-8") for part in SOURCE_0810.path.split("/")],
            SOURCE_0810,
        )
        if not (
            index_tree_0810
            == structural_tree_0810
            == PREDICTED_REVIEW_TREE_AFTER_0810
        ):
            raise ProjectionError("independent 08-10 tree calculations disagree")

        _verify_one_path_delta(
            git_dir,
            environment,
            SELECTED_DEVELOPMENT_BOOTSTRAP_TREE,
            index_tree_0802,
            SOURCE_0802,
        )
        _verify_one_path_delta(
            git_dir,
            environment,
            index_tree_0802,
            index_tree_0810,
            SOURCE_0810,
        )

        yield ProjectionSession(
            repository=repository,
            git_dir=git_dir,
            environment=environment,
            tree_after_0802=index_tree_0802,
            tree_after_0810=index_tree_0810,
        )


def _classify_in_session(session: ProjectionSession, tree_oid: str) -> dict:
    _require_oid(tree_oid, "tree")
    if tree_oid in {session.tree_after_0802, session.tree_after_0810}:
        entries_for_tree = lambda tree: _isolated_entries(session, tree)
        recursive_entries = lambda tree: _isolated_recursive_entries(session, tree)
        blob_reader = lambda oid: _isolated_blob(session, oid)
    else:
        entries_for_tree = lambda tree: _repository_entries(session.repository, tree)
        recursive_entries = lambda tree: _repository_recursive_entries(
            session.repository,
            tree,
        )
        blob_reader = lambda oid: _repository_blob(session.repository, oid)

    entry_0802 = _entry_at_path(entries_for_tree, tree_oid, SOURCE_0802.path)
    entry_0810 = _entry_at_path(entries_for_tree, tree_oid, SOURCE_0810.path)

    exact_0802 = _entry_matches(entry_0802, SOURCE_0802, blob_reader)
    exact_0810 = _entry_matches(entry_0810, SOURCE_0810, blob_reader)
    status_0802 = "exact" if exact_0802 else ("absent" if entry_0802 is None else "foreign")
    status_0810 = "exact" if exact_0810 else ("absent" if entry_0810 is None else "foreign")

    unexpected_0810_like = False
    if entry_0810 is None:
        expected_path = SOURCE_0810.path.encode("utf-8")
        expected_name = expected_path.rsplit(b"/", 1)[-1]
        expected_path_key = _path_collision_key(expected_path)
        expected_name_key = _path_collision_key(expected_name)
        for entry in recursive_entries(tree_oid):
            if entry.name == expected_path:
                continue
            alternate_name = entry.name.rsplit(b"/", 1)[-1]
            entry_path_key = _path_collision_key(entry.name)
            alternate_name_key = _path_collision_key(alternate_name)
            if (
                entry.oid == SOURCE_0810.git_blob
                or alternate_name == expected_name
                or entry.name.startswith(expected_path + b".")
                or (
                    entry_path_key is not None
                    and expected_path_key is not None
                    and (
                        entry_path_key == expected_path_key
                        or entry_path_key.startswith(expected_path_key + ".")
                    )
                )
                or (
                    alternate_name_key is not None
                    and expected_name_key is not None
                    and alternate_name_key == expected_name_key
                )
            ):
                unexpected_0810_like = True
                break

    findings: list[dict[str, str]] = []
    if not exact_0802:
        findings.append({"code": "invalid0802Predecessor"})
    if (entry_0810 is not None and not exact_0810) or unexpected_0810_like:
        findings.append({"code": "foreign0810Identity"})
    if unexpected_0810_like:
        findings.append({"code": "unexpected0810LikePath"})

    if not exact_0802:
        matrix_case = "invalid0802Predecessor"
        required_disposition = "failClosed"
        projection_disposition = "notPrepared"
    elif (
        entry_0810 is not None and not exact_0810
    ) or unexpected_0810_like:
        matrix_case = "foreign0810Identity"
        required_disposition = "quarantineRequired"
        projection_disposition = "notPrepared"
    elif entry_0810 is None:
        matrix_case = "exact0802_0810Absent"
        required_disposition = "stopForIncumbentAdmissionController"
        projection_disposition = (
            "preparedNonAuthoritative"
            if tree_oid == session.tree_after_0802
            else "notPreparedUnadmittedObservedTree"
        )
    else:
        # This capability accepts no external authority evidence.  Therefore
        # the matching-receipt matrix member is intentionally unreachable.
        matrix_case = "exactPairUnadmittedOrNonmatchingV2Evidence"
        required_disposition = "quarantineRequired"
        projection_disposition = "notPrepared"

    if tree_oid == session.tree_after_0802:
        projection_relationship = "matchesPredictedReviewTreeAfter0802"
    elif tree_oid == session.tree_after_0810:
        projection_relationship = "matchesPredictedReviewTreeAfter0810"
    else:
        projection_relationship = "divergesFromPredictedReviewTrees"

    return {
        "observedTree": {
            "treeOid": tree_oid,
            "design08_02": status_0802,
            "design08_10": status_0810,
        },
        "findings": findings,
        "presenceMatrix": {
            "case": matrix_case,
            "projectionRelationship": projection_relationship,
            "projectionDisposition": projection_disposition,
            "predecessorAuthority": "unverified",
            "externalEvidenceDisposition": "notAcceptedByThisCapability",
            "requiredDisposition": required_disposition,
        },
        "authorityGate": {
            "state": "blocked",
            "blockers": [{"code": BLOCKER, "waivable": False}],
            "currentCodePathEffects": dict(ZERO_AUTHORITY_SIDE_EFFECTS),
        },
    }


def classify_presence(repository: Path, tree_oid: str) -> dict:
    """Observe content separately from projection and authority disposition."""

    with _projection_session(repository) as session:
        return _classify_in_session(session, tree_oid)


def _projection_digest(value: dict[str, object]) -> str:
    canonical = json.dumps(
        value,
        ensure_ascii=False,
        sort_keys=True,
        separators=(",", ":"),
    ).encode("utf-8")
    domain = b"QINAO-A02-PROVISIONAL-REVIEW-PROJECTION-V1\0"
    return hashlib.sha256(domain + len(canonical).to_bytes(8, "big") + canonical).hexdigest()


def prepare_provisional(repository: Path) -> dict:
    """Return a deterministic review projection and a mandatory typed blocker."""

    with _projection_session(repository) as session:
        observation = _classify_in_session(session, session.tree_after_0802)
        projected_pair = _classify_in_session(session, session.tree_after_0810)
        if (
            observation["presenceMatrix"]["case"] != "exact0802_0810Absent"
            or observation["presenceMatrix"]["projectionDisposition"]
            != "preparedNonAuthoritative"
            or projected_pair["presenceMatrix"]["case"]
            != "exactPairUnadmittedOrNonmatchingV2Evidence"
        ):
            raise ProjectionError("closed provisional presence matrix did not hold")

        projection: dict[str, object] = {
            "schema": SCHEMA,
            "semanticAuthority": "none",
            "nonAuthoritative": True,
            "rebuildability": {
                "state": "conditional",
                "prerequisite": (
                    "fixedSourceObjectsRemainAvailableAndByteExact"
                ),
            },
            "installable": False,
            "projectionSource": {
                "sourceObjectSnapshotIsolation": False,
                "sourceObjectEpochBinding": "notProven",
                "selectedDevelopmentBootstrapCommit": (
                    SELECTED_DEVELOPMENT_BOOTSTRAP_COMMIT
                ),
                "selectedDevelopmentBootstrapTree": (
                    SELECTED_DEVELOPMENT_BOOTSTRAP_TREE
                ),
                "orderedSourceTuples": [
                    source.json_value() for source in SOURCE_TUPLES
                ],
                "sourceObservations": [
                    {
                        "role": "design08_02ReviewSource",
                        "commitOid": SOURCE_0802_COMMIT,
                        "treeOid": SOURCE_0802_TREE,
                        "tuple": SOURCE_0802.json_value(),
                        "semanticAuthority": "none",
                    },
                    {
                        "role": "design08_10PreservationSource",
                        "commitOid": SOURCE_0810_COMMIT,
                        "treeOid": SOURCE_0810_TREE,
                        "tuple": SOURCE_0810.json_value(),
                        "semanticAuthority": "none",
                    },
                ],
            },
            "observedTree": observation["observedTree"],
            "findings": observation["findings"],
            "presenceMatrix": observation["presenceMatrix"],
            "deterministicProjection": {
                "kind": "ephemeralIsolatedGitTrees",
                "reviewTreeAfter0802": session.tree_after_0802,
                "projectedTreeOidEphemeral": session.tree_after_0810,
                "changedEntryCount": 1,
                "onlyChangedPath": SOURCE_0810.path,
                "nonTargetEntryGitObjectIdentitiesUnchanged": True,
                "onePathDeltaProof": "exactGitTreeIdentityAndDiffTree",
                "projectedPresenceCase": projected_pair["presenceMatrix"]["case"],
                "algorithms": [
                    "isolatedTemporaryIndex",
                    "recursiveTreeRewrite",
                ],
                "independentFailureDomains": False,
                "agreementScope": "distinctProceduresSharedGitImplementation",
                "sharedObjectDatabaseWrites": 0,
                "persistentGitObjectsRemainingAfterNormalCompletion": 0,
                "ephemeralBareRepository": {
                    "symbolicHeadCreatedByGitInit": True,
                    "removedAfterNormalCompletion": True,
                },
            },
            "runtimeScratch": {
                "namespace": RUNTIME_ROOT.name,
                "pythonTempfileAmbientConfigurationIgnored": True,
                "normalExitCleanup": "synchronous",
                "forcedTerminationSynchronousCleanupGuaranteed": False,
                "interruptedSessionRecovery": {
                    "trigger": "nextStart",
                    "eligibleWhen": (
                        "leaseUnlockedAndPathOwnershipModeIdentityValid"
                    ),
                    "invalidStateDisposition": "failClosed",
                },
                "orphanSubprocessTerminationGuaranteedAfterParentSIGKILL": False,
                "sameUidNamespaceAdversaryResistance": (
                    "fdAnchoredTraversalWithIdentityChecksNotCapabilityIsolation"
                ),
                "osResourceIsolation": "wallClockAndPipeByteBudgetsOnly",
                "persistentControlFiles": [".janitor.lock"],
            },
            "authorityGate": observation["authorityGate"],
        }
        projection["projectionDigest"] = _projection_digest(projection)
        return projection


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Rebuild fixed A0.2 review bytes; this command is never terminal.",
    )
    parser.add_argument(
        "--repository",
        required=True,
        type=Path,
        help="Repository containing the fixed source objects.",
    )
    parser.add_argument(
        "--classify-tree",
        help="Optional lowercase tree object ID to classify.",
    )
    return parser


def _evaluation_unavailable_document() -> dict[str, object]:
    return {
        "schema": SCHEMA,
        "semanticAuthority": "none",
        "evaluationDisposition": "evaluationUnavailable",
        "nonAuthoritative": True,
        "installable": False,
        "authorityGate": {
            "state": "blocked",
            "blockers": [
                {
                    "code": "BLOCKED_EVALUATION_UNAVAILABLE",
                    "waivable": False,
                }
            ],
            "currentCodePathEffects": dict(ZERO_AUTHORITY_SIDE_EFFECTS),
        },
    }


def main(arguments: Sequence[str] | None = None) -> int:
    parsed = _parser().parse_args(arguments)
    try:
        if parsed.classify_tree is None:
            result = prepare_provisional(parsed.repository)
        else:
            observation = classify_presence(parsed.repository, parsed.classify_tree)
            result = {
                "schema": SCHEMA,
                "semanticAuthority": "none",
                "nonAuthoritative": True,
                "rebuildability": {
                    "state": "conditional",
                    "prerequisite": (
                        "fixedSourceObjectsRemainAvailableAndByteExact"
                    ),
                },
                "installable": False,
                "observedTree": observation["observedTree"],
                "findings": observation["findings"],
                "presenceMatrix": observation["presenceMatrix"],
                "authorityGate": observation["authorityGate"],
            }
        sys.stdout.write(
            json.dumps(result, ensure_ascii=False, sort_keys=True, separators=(",", ":"))
            + "\n"
        )
        return EXIT_BLOCKED
    except (OSError, ProjectionError, UnicodeError, ValueError):
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
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
