#!/usr/bin/env python3
"""Run one iOS Swift-package test target and prove non-empty xcresult evidence."""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import os
import selectors
import signal
import stat
import subprocess
import sys
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Any


EXIT_INVALID = 1
EXIT_XCODEBUILD_FAILURE = 2
EXIT_EVIDENCE_FAILURE = 3
EXIT_CLEANUP_FAILURE = 4
DEFAULT_TIMEOUT_SECONDS = 30 * 60
TERMINATION_GRACE_SECONDS = 2.0
PROCESS_READ_CHUNK_BYTES = 64 * 1024
XCODEBUILD_OUTPUT_LIMIT_BYTES = 64 * 1024 * 1024
XCRESULT_OUTPUT_LIMIT_BYTES = 16 * 1024 * 1024
XCRESULT_SCHEMA_VERSION = "0.4.0"
REPOSITORY_ROOT = Path(__file__).resolve().parents[1]
BUNDLE_NODE_TYPES = {"Unit test bundle", "UI test bundle"}
STERILE_PATH = "/usr/bin:/bin:/usr/sbin:/sbin"


class ValidationError(ValueError):
    """A caller-controlled input violates the closed invocation contract."""


class InvocationError(OSError):
    """A protected subprocess could not complete inside its hard bounds."""


class EvidenceError(ValueError):
    """The result bundle did not prove the requested execution."""


class CleanupError(OSError):
    """An invocation-created root could not be removed safely."""


class ClosedArgumentParser(argparse.ArgumentParser):
    """Turn argparse failures into the runner's stable invalid-input result."""

    def error(self, message: str) -> None:
        raise ValidationError(message)


class StoreOnceAction(argparse.Action):
    """Reject option shadowing instead of silently accepting the last value."""

    def __call__(
        self,
        parser: argparse.ArgumentParser,
        namespace: argparse.Namespace,
        values: Any,
        option_string: str | None = None,
    ) -> None:
        seen = getattr(namespace, "_qinao_seen_singletons", None)
        if seen is None:
            seen = set()
            setattr(namespace, "_qinao_seen_singletons", seen)
        if self.dest in seen:
            parser.error(f"{option_string} must appear at most once")
        seen.add(self.dest)
        setattr(namespace, self.dest, values)


@dataclass(frozen=True)
class ExecutionEvidence:
    target: str
    discovered: int
    executed: int
    digest: str


@dataclass
class SecureOutputRoot:
    """A private output namespace bound to opened directory identities."""

    requested_path: Path
    label: str
    parent_path: Path
    parent_fd: int
    parent_identity: tuple[int, int]
    anchor_name: str
    anchor_fd: int
    anchor_identity: tuple[int, int]
    payload_fd: int
    payload_identity: tuple[int, int]
    home_fd: int
    home_identity: tuple[int, int]
    temporary_fd: int
    temporary_identity: tuple[int, int]
    actual_path: Path
    home_path: Path
    temporary_path: Path
    closed: bool = False


def parse_args() -> argparse.Namespace:
    parser = ClosedArgumentParser(description=__doc__, allow_abbrev=False)
    parser.add_argument(
        "--xcodebuild-executable",
        type=Path,
        required=True,
        action=StoreOnceAction,
    )
    parser.add_argument(
        "--xcresulttool-executable",
        type=Path,
        required=True,
        action=StoreOnceAction,
    )
    parser.add_argument(
        "--package-path",
        type=Path,
        required=True,
        action=StoreOnceAction,
    )
    parser.add_argument("--scheme", required=True, action=StoreOnceAction)
    parser.add_argument("--destination", required=True, action=StoreOnceAction)
    parser.add_argument(
        "--derived-data-path",
        type=Path,
        required=True,
        action=StoreOnceAction,
    )
    parser.add_argument(
        "--result-bundle-path",
        type=Path,
        required=True,
        action=StoreOnceAction,
    )
    parser.add_argument(
        "--require-target",
        required=True,
        action=StoreOnceAction,
    )
    parser.add_argument(
        "--timeout-seconds",
        type=float,
        default=DEFAULT_TIMEOUT_SECONDS,
        action=StoreOnceAction,
    )
    return parser.parse_args()


def require_stable_text(value: str, option: str) -> str:
    if (
        not value
        or value != value.strip()
        or value.startswith("-")
        or any(not character.isprintable() for character in value)
    ):
        raise ValidationError(f"{option} must be one non-empty stable value")
    return value


def has_symlink_component(path: Path) -> bool:
    current = Path(path.anchor)
    for part in path.parts[1:]:
        current = current / part
        try:
            metadata = os.lstat(current)
        except FileNotFoundError:
            continue
        except OSError as error:
            raise ValidationError(
                f"cannot inspect path component {current}: {error}"
            ) from error
        if stat.S_ISLNK(metadata.st_mode):
            return True
    return False


def path_is_within(path: Path, root: Path) -> bool:
    try:
        path.relative_to(root)
    except ValueError:
        return False
    return True


def validate_executable(path: Path, option: str) -> Path:
    prefix = f"{option} must be an absolute canonical regular non-symlink executable"
    if not path.is_absolute():
        raise ValidationError(f"{prefix}: path is not absolute")
    if has_symlink_component(path):
        raise ValidationError(f"{prefix}: path contains a symbolic link")
    try:
        metadata = os.lstat(path)
        resolved = path.resolve(strict=True)
    except (OSError, RuntimeError) as error:
        raise ValidationError(f"{prefix}: path is unavailable: {error}") from error
    if stat.S_ISLNK(metadata.st_mode) or resolved != path:
        raise ValidationError(f"{prefix}: path is symlinked or not canonical")
    if not stat.S_ISREG(metadata.st_mode):
        raise ValidationError(f"{prefix}: path is not a regular file")
    if not os.access(path, os.X_OK):
        raise ValidationError(f"{prefix}: path is not executable")
    return path


def validate_fresh_external_root(path: Path, option: str) -> Path:
    prefix = f"{option} must be a fresh repository-external absolute non-symlink path"
    if not path.is_absolute():
        raise ValidationError(f"{prefix}: path is not absolute")
    if has_symlink_component(path):
        raise ValidationError(f"{prefix}: path contains a symbolic link")
    try:
        os.lstat(path)
    except FileNotFoundError:
        pass
    except OSError as error:
        raise ValidationError(f"{prefix}: cannot inspect path: {error}") from error
    else:
        raise ValidationError(f"{prefix}: path already exists")
    parent = path.parent
    try:
        parent_metadata = os.lstat(parent)
    except OSError as error:
        raise ValidationError(
            f"{prefix}: parent directory is unavailable: {error}"
        ) from error
    if not stat.S_ISDIR(parent_metadata.st_mode):
        raise ValidationError(f"{prefix}: parent is not a directory")
    resolved = path.resolve(strict=False)
    if resolved != path:
        raise ValidationError(f"{prefix}: path is not canonical")
    if path_is_within(resolved, REPOSITORY_ROOT):
        raise ValidationError(f"{prefix}: path is inside the repository")
    return resolved


def validate_package_path(path: Path) -> Path:
    lexical = path if path.is_absolute() else Path.cwd() / path
    if has_symlink_component(lexical):
        raise ValidationError("--package-path must not contain symbolic links")
    try:
        resolved = lexical.resolve(strict=True)
    except OSError as error:
        raise ValidationError(f"--package-path is unavailable: {error}") from error
    manifest = resolved / "Package.swift"
    try:
        package_metadata = os.lstat(resolved)
        manifest_metadata = os.lstat(manifest)
    except OSError as error:
        raise ValidationError(
            f"--package-path is not an exact Swift package: {error}"
        ) from error
    if (
        not stat.S_ISDIR(package_metadata.st_mode)
        or not stat.S_ISREG(manifest_metadata.st_mode)
        or stat.S_ISLNK(manifest_metadata.st_mode)
    ):
        raise ValidationError("--package-path is not an exact Swift package")
    return resolved


def validate_inputs(
    args: argparse.Namespace,
) -> tuple[Path, Path, Path, str, Path, Path]:
    xcodebuild_executable = validate_executable(
        args.xcodebuild_executable,
        "--xcodebuild-executable",
    )
    xcresulttool_executable = validate_executable(
        args.xcresulttool_executable,
        "--xcresulttool-executable",
    )
    package = validate_package_path(args.package_path)
    require_stable_text(args.scheme, "--scheme")
    require_stable_text(args.destination, "--destination")
    target = require_stable_text(args.require_target, "--require-target")
    if (
        not math.isfinite(args.timeout_seconds)
        or args.timeout_seconds <= 0
        or args.timeout_seconds > DEFAULT_TIMEOUT_SECONDS
    ):
        raise ValidationError(
            f"--timeout-seconds must be in (0, {DEFAULT_TIMEOUT_SECONDS}]"
        )
    derived_data = validate_fresh_external_root(
        args.derived_data_path,
        "--derived-data-path",
    )
    result_bundle = validate_fresh_external_root(
        args.result_bundle_path,
        "--result-bundle-path",
    )
    if (
        derived_data == result_bundle
        or derived_data in result_bundle.parents
        or result_bundle in derived_data.parents
    ):
        raise ValidationError(
            "DerivedData and result bundle must be distinct non-overlapping "
            "fresh repository-external roots"
        )
    return (
        package,
        derived_data,
        result_bundle,
        target,
        xcodebuild_executable,
        xcresulttool_executable,
    )


def directory_open_flags() -> int:
    required = ("O_CLOEXEC", "O_DIRECTORY", "O_NOFOLLOW")
    missing = [name for name in required if not hasattr(os, name)]
    if missing:
        raise ValidationError(
            "secure output binding is unavailable: " + ", ".join(missing)
        )
    return os.O_RDONLY | os.O_CLOEXEC | os.O_DIRECTORY | os.O_NOFOLLOW


def directory_identity(metadata: os.stat_result) -> tuple[int, int]:
    return (metadata.st_dev, metadata.st_ino)


def validate_bound_directory(
    metadata: os.stat_result,
    *,
    label: str,
    allow_shared_sticky: bool,
) -> None:
    if not stat.S_ISDIR(metadata.st_mode) or metadata.st_nlink < 1:
        raise ValidationError(f"{label} is not a stable directory")
    writable_by_others = metadata.st_mode & (stat.S_IWGRP | stat.S_IWOTH)
    is_sticky = metadata.st_mode & stat.S_ISVTX
    shared_sticky = bool(allow_shared_sticky and writable_by_others and is_sticky)
    if metadata.st_uid != os.getuid() and not shared_sticky:
        raise ValidationError(f"{label} is not owned by the invoking user")
    if writable_by_others and not shared_sticky:
        raise ValidationError(f"{label} permits unsafe directory substitution")


def open_absolute_directory_no_symlinks(path: Path, label: str) -> int:
    """Open every absolute component relative to the preceding bound fd."""

    if not path.is_absolute():
        raise ValidationError(f"{label} is not absolute")
    flags = directory_open_flags()
    try:
        descriptor = os.open(path.anchor, flags)
    except OSError as error:
        raise ValidationError(f"cannot open {label}: {error}") from error
    try:
        for component in path.parts[1:]:
            try:
                next_descriptor = os.open(
                    component,
                    flags,
                    dir_fd=descriptor,
                )
            except OSError as error:
                raise ValidationError(
                    f"cannot bind {label} without symbolic links: {error}"
                ) from error
            os.close(descriptor)
            descriptor = next_descriptor
        metadata = os.fstat(descriptor)
        if not stat.S_ISDIR(metadata.st_mode):
            raise ValidationError(f"{label} is not a directory")
        return descriptor
    except Exception:
        os.close(descriptor)
        raise


def stat_directory_at(
    directory_fd: int,
    name: str,
    *,
    label: str,
) -> os.stat_result:
    try:
        metadata = os.stat(name, dir_fd=directory_fd, follow_symlinks=False)
    except OSError as error:
        raise ValidationError(f"cannot inspect {label}: {error}") from error
    if not stat.S_ISDIR(metadata.st_mode):
        raise ValidationError(f"{label} is not a directory")
    return metadata


def require_missing_at(directory_fd: int, name: str, label: str) -> None:
    try:
        os.stat(name, dir_fd=directory_fd, follow_symlinks=False)
    except FileNotFoundError:
        return
    except OSError as error:
        raise ValidationError(f"cannot inspect {label}: {error}") from error
    raise ValidationError(f"{label} appeared after fresh-root validation")


def _remove_directory_contents(directory_fd: int, depth: int = 0) -> None:
    if depth > 256:
        raise CleanupError("secure cleanup exceeded its directory-depth limit")
    flags = directory_open_flags()
    try:
        entries = list(os.scandir(directory_fd))
    except OSError as error:
        raise CleanupError(f"cannot enumerate secure cleanup root: {error}") from error
    for entry in entries:
        name = entry.name
        if not name or name in {".", ".."} or Path(name).name != name:
            raise CleanupError(f"unsafe cleanup entry name: {name!r}")
        try:
            before = entry.stat(follow_symlinks=False)
        except OSError as error:
            raise CleanupError(
                f"cannot inspect cleanup entry {name}: {error}"
            ) from error
        if stat.S_ISDIR(before.st_mode):
            try:
                child_fd = os.open(name, flags, dir_fd=directory_fd)
            except OSError as error:
                raise CleanupError(
                    f"cannot bind cleanup directory {name}: {error}"
                ) from error
            try:
                if directory_identity(os.fstat(child_fd)) != directory_identity(before):
                    raise CleanupError(f"cleanup directory changed: {name}")
                _remove_directory_contents(child_fd, depth + 1)
                current = os.stat(
                    name,
                    dir_fd=directory_fd,
                    follow_symlinks=False,
                )
                if directory_identity(current) != directory_identity(before):
                    raise CleanupError(f"cleanup directory path changed: {name}")
            except CleanupError:
                raise
            except OSError as error:
                raise CleanupError(
                    f"cannot verify cleanup directory {name}: {error}"
                ) from error
            finally:
                os.close(child_fd)
            try:
                os.rmdir(name, dir_fd=directory_fd)
            except OSError as error:
                raise CleanupError(
                    f"cannot remove cleanup directory {name}: {error}"
                ) from error
        else:
            try:
                os.unlink(name, dir_fd=directory_fd)
            except OSError as error:
                raise CleanupError(
                    f"cannot remove cleanup entry {name}: {error}"
                ) from error


def require_secure_output_binding(
    binding: SecureOutputRoot,
    *,
    require_output_missing: bool,
) -> None:
    if binding.closed:
        raise ValidationError(f"{binding.label} secure binding is closed")
    for name, descriptor, expected_identity in (
        ("parent", binding.parent_fd, binding.parent_identity),
        ("anchor", binding.anchor_fd, binding.anchor_identity),
        ("payload", binding.payload_fd, binding.payload_identity),
        ("home", binding.home_fd, binding.home_identity),
        ("temporary", binding.temporary_fd, binding.temporary_identity),
    ):
        try:
            descriptor_metadata = os.fstat(descriptor)
        except OSError as error:
            raise ValidationError(
                f"{binding.label} {name} descriptor identity is unavailable: {error}"
            ) from error
        if (
            not stat.S_ISDIR(descriptor_metadata.st_mode)
            or directory_identity(descriptor_metadata) != expected_identity
        ):
            raise ValidationError(f"{binding.label} {name} descriptor identity changed")
    path_fd = open_absolute_directory_no_symlinks(
        binding.parent_path,
        f"{binding.label} parent path",
    )
    try:
        if directory_identity(os.fstat(path_fd)) != binding.parent_identity:
            raise ValidationError(f"{binding.label} parent path was substituted")
    finally:
        os.close(path_fd)
    anchor_metadata = stat_directory_at(
        binding.parent_fd,
        binding.anchor_name,
        label=f"{binding.label} private anchor",
    )
    if directory_identity(anchor_metadata) != binding.anchor_identity:
        raise ValidationError(f"{binding.label} private anchor was substituted")
    if stat.S_IMODE(anchor_metadata.st_mode) != 0o500:
        raise ValidationError(f"{binding.label} private anchor mode changed")
    for name, expected in (
        ("payload", binding.payload_identity),
        ("home", binding.home_identity),
        ("tmp", binding.temporary_identity),
    ):
        metadata = stat_directory_at(
            binding.anchor_fd,
            name,
            label=f"{binding.label} private {name}",
        )
        if directory_identity(metadata) != expected:
            raise ValidationError(
                f"{binding.label} private {name} directory was substituted"
            )
        if stat.S_IMODE(metadata.st_mode) != 0o700:
            raise ValidationError(
                f"{binding.label} private {name} directory mode changed"
            )
    if require_output_missing:
        require_missing_at(
            binding.payload_fd,
            binding.requested_path.name,
            binding.label,
        )


def create_secure_output_root(path: Path, label: str) -> SecureOutputRoot:
    """Atomically bind the requested root as a private output namespace."""

    parent_path = path.parent
    parent_fd = open_absolute_directory_no_symlinks(
        parent_path,
        f"{label} parent",
    )
    anchor_fd = -1
    payload_fd = -1
    home_fd = -1
    temporary_fd = -1
    anchor_name = ""
    try:
        parent_metadata = os.fstat(parent_fd)
        validate_bound_directory(
            parent_metadata,
            label=f"{label} parent",
            allow_shared_sticky=True,
        )
        require_missing_at(parent_fd, path.name, label)
        anchor_name = path.name
        try:
            os.mkdir(anchor_name, mode=0o700, dir_fd=parent_fd)
        except FileExistsError as error:
            raise ValidationError(f"{label} appeared before private binding") from error
        except OSError as error:
            raise ValidationError(
                f"cannot create {label} private anchor: {error}"
            ) from error
        try:
            os.chmod(
                anchor_name,
                0o700,
                dir_fd=parent_fd,
                follow_symlinks=False,
            )
            anchor_fd = os.open(
                anchor_name,
                directory_open_flags(),
                dir_fd=parent_fd,
            )
        except OSError as error:
            raise ValidationError(
                f"cannot bind {label} private anchor: {error}"
            ) from error
        anchor_metadata = os.fstat(anchor_fd)
        validate_bound_directory(
            anchor_metadata,
            label=f"{label} private anchor",
            allow_shared_sticky=False,
        )
        try:
            for name in ("payload", "home", "tmp"):
                os.mkdir(name, mode=0o700, dir_fd=anchor_fd)
                os.chmod(
                    name,
                    0o700,
                    dir_fd=anchor_fd,
                    follow_symlinks=False,
                )
        except OSError as error:
            raise ValidationError(
                f"cannot create {label} private runtime directories: {error}"
            ) from error
        payload_fd = os.open(
            "payload",
            directory_open_flags(),
            dir_fd=anchor_fd,
        )
        home_fd = os.open(
            "home",
            directory_open_flags(),
            dir_fd=anchor_fd,
        )
        temporary_fd = os.open(
            "tmp",
            directory_open_flags(),
            dir_fd=anchor_fd,
        )
        payload_metadata = os.fstat(payload_fd)
        home_metadata = os.fstat(home_fd)
        temporary_metadata = os.fstat(temporary_fd)
        os.fchmod(anchor_fd, 0o500)
        anchor_path = path
        binding = SecureOutputRoot(
            requested_path=path,
            label=label,
            parent_path=parent_path,
            parent_fd=parent_fd,
            parent_identity=directory_identity(parent_metadata),
            anchor_name=anchor_name,
            anchor_fd=anchor_fd,
            anchor_identity=directory_identity(anchor_metadata),
            payload_fd=payload_fd,
            payload_identity=directory_identity(payload_metadata),
            home_fd=home_fd,
            home_identity=directory_identity(home_metadata),
            temporary_fd=temporary_fd,
            temporary_identity=directory_identity(temporary_metadata),
            actual_path=anchor_path / "payload" / path.name,
            home_path=anchor_path / "home",
            temporary_path=anchor_path / "tmp",
        )
        require_secure_output_binding(binding, require_output_missing=True)
        return binding
    except Exception as original_error:
        cleanup_errors: list[str] = []
        for descriptor_name, descriptor in (
            ("payload", payload_fd),
            ("home", home_fd),
            ("temporary", temporary_fd),
        ):
            if descriptor < 0:
                continue
            try:
                os.close(descriptor)
            except OSError as error:
                cleanup_errors.append(
                    f"cannot close partial {descriptor_name} binding: {error}"
                )
        if anchor_fd >= 0:
            try:
                os.fchmod(anchor_fd, 0o700)
                _remove_directory_contents(anchor_fd)
            except (CleanupError, OSError) as error:
                cleanup_errors.append(f"cannot clean partial private anchor: {error}")
        if anchor_fd >= 0:
            try:
                os.close(anchor_fd)
            except OSError as error:
                cleanup_errors.append(f"cannot close partial private anchor: {error}")
        if anchor_name:
            try:
                os.rmdir(anchor_name, dir_fd=parent_fd)
            except OSError as error:
                cleanup_errors.append(f"cannot remove partial private anchor: {error}")
        try:
            os.close(parent_fd)
        except OSError as error:
            cleanup_errors.append(f"cannot close partial parent binding: {error}")
        if cleanup_errors:
            raise CleanupError(
                f"{label} partial cleanup failed: " + "; ".join(cleanup_errors)
            ) from original_error
        raise


def cleanup_secure_output_root(binding: SecureOutputRoot) -> None:
    if binding.closed:
        return
    errors: list[str] = []
    try:
        try:
            os.fchmod(binding.anchor_fd, 0o700)
        except OSError as error:
            errors.append(f"cannot unlock private anchor: {error}")
        for attribute, descriptor_name in (
            ("payload_fd", "payload"),
            ("home_fd", "home"),
            ("temporary_fd", "temporary"),
        ):
            descriptor = getattr(binding, attribute)
            if descriptor < 0:
                continue
            try:
                os.close(descriptor)
            except OSError as error:
                errors.append(f"cannot close {descriptor_name} binding: {error}")
            setattr(binding, attribute, -1)
        if not errors:
            try:
                _remove_directory_contents(binding.anchor_fd)
            except CleanupError as error:
                errors.append(str(error))
        try:
            current = os.stat(
                binding.anchor_name,
                dir_fd=binding.parent_fd,
                follow_symlinks=False,
            )
            if directory_identity(current) != binding.anchor_identity:
                errors.append("private anchor path changed before removal")
            elif not errors:
                os.rmdir(binding.anchor_name, dir_fd=binding.parent_fd)
        except OSError as error:
            errors.append(f"cannot remove private anchor: {error}")
        try:
            require_missing_at(
                binding.parent_fd,
                binding.requested_path.name,
                binding.label,
            )
        except ValidationError as error:
            errors.append(str(error))
    finally:
        for descriptor in (binding.anchor_fd, binding.parent_fd):
            try:
                os.close(descriptor)
            except OSError as error:
                errors.append(f"cannot close secure binding: {error}")
        binding.closed = True
    if errors:
        raise CleanupError(f"{binding.label} cleanup failed: " + "; ".join(errors))


def sterile_subprocess_environment(binding: SecureOutputRoot) -> dict[str, str]:
    return {
        "HOME": os.fspath(binding.home_path),
        "LANG": "C",
        "LC_ALL": "C",
        "PATH": STERILE_PATH,
        "TMPDIR": os.fspath(binding.temporary_path) + os.sep,
        "__CF_USER_TEXT_ENCODING": "0x0:0:0",
    }


def close_process_pipes(process: subprocess.Popen[bytes]) -> None:
    if process.stdout is not None:
        process.stdout.close()
    if process.stderr is not None:
        process.stderr.close()


def terminate_unbound_process_leader(
    process: subprocess.Popen[bytes],
) -> None:
    """Best-effort cleanup without ever signaling an unverified process group."""
    try:
        process.kill()
    except (PermissionError, ProcessLookupError):
        pass
    close_process_pipes(process)
    try:
        process.wait(timeout=TERMINATION_GRACE_SECONDS)
    except (ChildProcessError, subprocess.TimeoutExpired):
        pass


def bind_isolated_process_group(
    process: subprocess.Popen[bytes],
    command_name: str,
) -> int:
    """Bind the isolated group before any later group-wide signal is allowed."""
    try:
        process_group_id = os.getpgid(process.pid)
    except OSError as error:
        terminate_unbound_process_leader(process)
        raise InvocationError(
            f"cannot bind {command_name} isolated process group: {error}"
        ) from error
    if process_group_id != process.pid or process_group_id == os.getpgrp():
        terminate_unbound_process_leader(process)
        raise InvocationError(
            f"{command_name} did not enter its required isolated process group"
        )
    return process_group_id


def process_group_exists(process_group_id: int) -> bool:
    try:
        os.killpg(process_group_id, 0)
    except ProcessLookupError:
        return False
    except PermissionError:
        return True
    return True


def terminate_process_group(
    process: subprocess.Popen[bytes],
    *,
    process_group_id: int,
    grace_seconds: float = TERMINATION_GRACE_SECONDS,
) -> None:
    if process_group_id != process.pid or process_group_id == os.getpgrp():
        terminate_unbound_process_leader(process)
        raise InvocationError("refusing to signal an unbound process group")
    signal_error: PermissionError | None = None
    try:
        os.killpg(process_group_id, signal.SIGTERM)
    except ProcessLookupError:
        pass
    except PermissionError as error:
        signal_error = error
    deadline = time.monotonic() + grace_seconds
    while time.monotonic() < deadline:
        process.poll()
        if not process_group_exists(process_group_id):
            break
        time.sleep(min(0.02, max(0.0, deadline - time.monotonic())))
    if process_group_exists(process_group_id):
        try:
            os.killpg(process_group_id, signal.SIGKILL)
        except ProcessLookupError:
            pass
        except PermissionError as error:
            signal_error = error
    close_process_pipes(process)
    try:
        process.wait(timeout=grace_seconds)
    except ChildProcessError:
        pass
    except subprocess.TimeoutExpired as error:
        process.kill()
        try:
            process.wait(timeout=grace_seconds)
        except subprocess.TimeoutExpired as final_error:
            raise InvocationError(
                "process group could not be reaped after termination"
            ) from final_error
        raise InvocationError(
            "process group required direct leader termination"
        ) from error
    if signal_error is not None:
        raise InvocationError(
            f"process group termination was denied: {signal_error}"
        ) from signal_error


def run_process(
    command: list[str],
    *,
    cwd: Path,
    environment: dict[str, str],
    timeout_seconds: float,
    output_limit_bytes: int,
) -> subprocess.CompletedProcess[bytes]:
    process_group_options: dict[str, Any]
    if sys.version_info >= (3, 11):
        process_group_options = {"process_group": 0}
    else:
        # Python 3.9 has no Popen(process_group=); this runner is
        # deliberately single-threaded, so the narrow setpgrp fallback is safe.
        process_group_options = {"preexec_fn": os.setpgrp}
    try:
        process = subprocess.Popen(
            command,
            cwd=cwd,
            env=environment,
            stdin=subprocess.DEVNULL,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=False,
            pass_fds=(),
            umask=0o077,
            **process_group_options,
        )
    except OSError as error:
        raise InvocationError(f"cannot start {command[0]}: {error}") from error
    process_group_id = bind_isolated_process_group(process, command[0])
    if process.stdout is None or process.stderr is None:
        terminate_process_group(
            process,
            process_group_id=process_group_id,
        )
        raise InvocationError(f"{command[0]} output pipes are unavailable")

    buffers = {"stdout": bytearray(), "stderr": bytearray()}
    selector = selectors.DefaultSelector()
    deadline = time.monotonic() + timeout_seconds
    process_group_termination_attempted = False
    try:
        for stream_name, stream in (
            ("stdout", process.stdout),
            ("stderr", process.stderr),
        ):
            os.set_blocking(stream.fileno(), False)
            selector.register(stream, selectors.EVENT_READ, stream_name)
        open_streams = 2
        while open_streams:
            remaining = deadline - time.monotonic()
            if remaining <= 0:
                raise subprocess.TimeoutExpired(command, timeout_seconds)
            events = selector.select(remaining)
            if not events:
                continue
            for key, _mask in events:
                stream_name = key.data
                buffer = buffers[stream_name]
                read_size = min(
                    PROCESS_READ_CHUNK_BYTES,
                    output_limit_bytes + 1 - len(buffer),
                )
                chunk = os.read(key.fd, read_size)
                if not chunk:
                    selector.unregister(key.fileobj)
                    key.fileobj.close()
                    open_streams -= 1
                    continue
                buffer.extend(chunk)
                if len(buffer) > output_limit_bytes:
                    raise InvocationError(
                        f"{command[0]} {stream_name} exceeded "
                        f"{output_limit_bytes} bytes"
                    )
        remaining = deadline - time.monotonic()
        if remaining <= 0:
            raise subprocess.TimeoutExpired(command, timeout_seconds)
        returncode = process.wait(timeout=remaining)
        if process_group_exists(process_group_id):
            process_group_termination_attempted = True
            terminate_process_group(
                process,
                process_group_id=process_group_id,
            )
            raise InvocationError(
                f"{command[0]} leader exited {returncode} while "
                "process-group descendants remained alive"
            )
    except subprocess.TimeoutExpired as error:
        terminate_process_group(
            process,
            process_group_id=process_group_id,
        )
        raise InvocationError(
            f"{command[0]} timed out after {timeout_seconds:g} seconds"
        ) from error
    except InvocationError:
        if not process_group_termination_attempted and process_group_exists(
            process_group_id
        ):
            terminate_process_group(
                process,
                process_group_id=process_group_id,
            )
        raise
    except OSError as error:
        terminate_process_group(
            process,
            process_group_id=process_group_id,
        )
        raise InvocationError(f"{command[0]} output capture failed: {error}") from error
    finally:
        selector.close()
    return subprocess.CompletedProcess(
        command,
        returncode,
        bytes(buffers["stdout"]),
        bytes(buffers["stderr"]),
    )


def validate_created_directory(
    path: Path,
    *,
    require_nonempty: bool,
    require_info_plist: bool = False,
) -> tuple[int, int, int, int, int]:
    if has_symlink_component(path):
        raise EvidenceError(f"created path is symlinked: {path}")
    try:
        metadata = os.lstat(path)
    except OSError as error:
        raise EvidenceError(f"created directory is missing: {path}: {error}") from error
    if not stat.S_ISDIR(metadata.st_mode):
        raise EvidenceError(f"created path is not a directory: {path}")
    try:
        entries = os.listdir(path)
    except OSError as error:
        raise EvidenceError(
            f"created directory cannot be read: {path}: {error}"
        ) from error
    if require_nonempty and not entries:
        raise EvidenceError(f"created directory is empty: {path}")
    if require_info_plist:
        info_path = path / "Info.plist"
        try:
            info_metadata = os.lstat(info_path)
        except OSError as error:
            raise EvidenceError(
                f"result bundle Info.plist is missing: {error}"
            ) from error
        if (
            not stat.S_ISREG(info_metadata.st_mode)
            or stat.S_ISLNK(info_metadata.st_mode)
            or info_metadata.st_size <= 0
        ):
            raise EvidenceError("result bundle Info.plist is unsafe or empty")
    return (
        metadata.st_dev,
        metadata.st_ino,
        metadata.st_mode,
        metadata.st_mtime_ns,
        metadata.st_ctime_ns,
    )


def run_xcresult_surface(
    surface: str,
    *,
    xcresulttool_executable: Path,
    package: Path,
    result_bundle: Path,
    environment: dict[str, str],
    timeout_seconds: float,
) -> bytes:
    command = [
        os.fspath(xcresulttool_executable),
        "get",
        "test-results",
        surface,
        "--schema-version",
        XCRESULT_SCHEMA_VERSION,
        "--path",
        str(result_bundle),
        "--compact",
    ]
    try:
        completed = run_process(
            command,
            cwd=package,
            environment=environment,
            timeout_seconds=timeout_seconds,
            output_limit_bytes=XCRESULT_OUTPUT_LIMIT_BYTES,
        )
    except InvocationError as error:
        raise EvidenceError(f"xcresulttool {surface} failed: {error}") from error
    if completed.returncode != 0:
        raise EvidenceError(f"xcresulttool {surface} exited {completed.returncode}")
    if not completed.stdout:
        raise EvidenceError(f"xcresulttool {surface} emitted no JSON")
    return completed.stdout


def parse_json_object(raw: bytes, surface: str) -> dict[str, Any]:
    try:
        text = raw.decode("utf-8", errors="strict")
    except UnicodeDecodeError as error:
        raise EvidenceError(f"xcresulttool {surface} is not strict UTF-8") from error
    try:

        def reject_duplicate_keys(
            pairs: list[tuple[str, Any]],
        ) -> dict[str, Any]:
            parsed: dict[str, Any] = {}
            for key, item in pairs:
                if key in parsed:
                    raise EvidenceError(
                        f"xcresulttool {surface} contains duplicate key {key!r}"
                    )
                parsed[key] = item
            return parsed

        def reject_nonfinite_constant(value: str) -> None:
            raise EvidenceError(
                f"xcresulttool {surface} contains non-finite JSON {value}"
            )

        value = json.loads(
            text,
            object_pairs_hook=reject_duplicate_keys,
            parse_constant=reject_nonfinite_constant,
        )
    except EvidenceError:
        raise
    except (json.JSONDecodeError, RecursionError) as error:
        raise EvidenceError(f"xcresulttool {surface} is not one JSON value") from error
    if not isinstance(value, dict):
        raise EvidenceError(f"xcresulttool {surface} root is not an object")
    return value


def exact_integer(value: Any, field: str) -> int:
    if type(value) is not int:
        raise EvidenceError(f"summary field {field} is not an integer")
    return value


def exact_number(value: Any, field: str) -> float:
    if type(value) not in {int, float} or not math.isfinite(float(value)):
        raise EvidenceError(f"summary field {field} is not a finite number")
    return float(value)


def validate_summary(summary: dict[str, Any]) -> tuple[int, int]:
    required_fields = {
        "title",
        "startTime",
        "finishTime",
        "environmentDescription",
        "topInsights",
        "result",
        "totalTestCount",
        "passedTests",
        "failedTests",
        "skippedTests",
        "expectedFailures",
        "statistics",
        "devicesAndConfigurations",
        "testFailures",
        "runtimeWarnings",
    }
    missing = sorted(required_fields - set(summary))
    if missing:
        raise EvidenceError("summary fields are missing: " + ", ".join(missing))
    for field in (
        "topInsights",
        "statistics",
        "devicesAndConfigurations",
        "testFailures",
        "runtimeWarnings",
    ):
        if not isinstance(summary[field], list):
            raise EvidenceError(f"summary field {field} is not an array")
    start = exact_number(summary["startTime"], "startTime")
    finish = exact_number(summary["finishTime"], "finishTime")
    if start < 0 or finish < start:
        raise EvidenceError("summary does not prove a completed test action")
    if summary["result"] != "Passed":
        raise EvidenceError("summary test action result is not Passed")
    total = exact_integer(summary["totalTestCount"], "totalTestCount")
    passed = exact_integer(summary["passedTests"], "passedTests")
    failed = exact_integer(summary["failedTests"], "failedTests")
    skipped = exact_integer(summary["skippedTests"], "skippedTests")
    expected_failures = exact_integer(
        summary["expectedFailures"],
        "expectedFailures",
    )
    if total <= 0 or passed <= 0 or passed != total:
        raise EvidenceError("summary proves zero or incomplete test execution")
    if failed != 0 or skipped != 0 or expected_failures != 0:
        raise EvidenceError(
            "summary contains failed, skipped, or expected-failure substitutes"
        )
    if summary["testFailures"]:
        raise EvidenceError("summary contains test failure records")
    return total, passed


def walk_nodes(nodes: list[Any]) -> list[dict[str, Any]]:
    flattened: list[dict[str, Any]] = []
    pending = list(reversed(nodes))
    while pending:
        node = pending.pop()
        if not isinstance(node, dict):
            raise EvidenceError("test-results tests contains a non-object node")
        name = node.get("name")
        node_type = node.get("nodeType")
        if not isinstance(name, str) or not name or not isinstance(node_type, str):
            raise EvidenceError("test-results tests contains a malformed node")
        children = node.get("children", [])
        if not isinstance(children, list):
            raise EvidenceError("test-results tests contains malformed children")
        flattened.append(node)
        pending.extend(reversed(children))
    return flattened


def validate_tests_tree(
    tests: dict[str, Any],
    target: str,
) -> tuple[int, int]:
    for field in ("testPlanConfigurations", "devices", "testNodes"):
        if not isinstance(tests.get(field), list):
            raise EvidenceError(f"tests field {field} is missing or malformed")
    roots = tests["testNodes"]
    if len(roots) != 1:
        raise EvidenceError("tests must contain exactly one test action root")
    root = roots[0]
    if (
        not isinstance(root, dict)
        or root.get("nodeType") != "Test Plan"
        or root.get("result") != "Passed"
    ):
        raise EvidenceError("tests does not prove one completed test action")
    flattened = walk_nodes(roots)
    bundles = [node for node in flattened if node["nodeType"] in BUNDLE_NODE_TYPES]
    if len(bundles) != 1 or bundles[0]["name"] != target:
        names = sorted(str(node["name"]) for node in bundles)
        raise EvidenceError(
            "tests target set is not exactly the required target: " + ", ".join(names)
        )
    bundle = bundles[0]
    if bundle.get("result") != "Passed":
        raise EvidenceError("required test target did not complete as Passed")
    bundle_nodes = walk_nodes(bundle.get("children", []))
    cases = [node for node in bundle_nodes if node["nodeType"] == "Test Case"]
    if not cases:
        raise EvidenceError("required test target discovered zero Test Case nodes")
    all_cases = [node for node in flattened if node["nodeType"] == "Test Case"]
    if {id(node) for node in all_cases} != {id(node) for node in cases}:
        raise EvidenceError("tests contains Test Case nodes outside required target")
    identities: set[str] = set()
    for case in cases:
        identity = case.get("nodeIdentifier")
        if not isinstance(identity, str) or not identity or identity in identities:
            raise EvidenceError(
                "required target has missing or duplicate test identity"
            )
        identities.add(identity)
        if case.get("result") != "Passed":
            raise EvidenceError(
                "required target contains a non-Passed Test Case result"
            )
    return len(cases), len(cases)


def collect_evidence(
    *,
    xcresulttool_executable: Path,
    package: Path,
    result_bundle: Path,
    result_binding: SecureOutputRoot,
    runtime_binding: SecureOutputRoot,
    target: str,
    environment: dict[str, str],
    timeout_seconds: float,
) -> ExecutionEvidence:
    def require_evidence_bindings() -> None:
        for name, binding in (
            ("result bundle", result_binding),
            ("runtime directory", runtime_binding),
        ):
            try:
                require_secure_output_binding(
                    binding,
                    require_output_missing=False,
                )
            except ValidationError as error:
                raise EvidenceError(f"{name} binding drifted: {error}") from error

    require_evidence_bindings()
    before = validate_created_directory(
        result_bundle,
        require_nonempty=True,
        require_info_plist=True,
    )
    summary_raw = run_xcresult_surface(
        "summary",
        xcresulttool_executable=xcresulttool_executable,
        package=package,
        result_bundle=result_bundle,
        environment=environment,
        timeout_seconds=timeout_seconds,
    )
    require_evidence_bindings()
    tests_raw = run_xcresult_surface(
        "tests",
        xcresulttool_executable=xcresulttool_executable,
        package=package,
        result_bundle=result_bundle,
        environment=environment,
        timeout_seconds=timeout_seconds,
    )
    require_evidence_bindings()
    after = validate_created_directory(
        result_bundle,
        require_nonempty=True,
        require_info_plist=True,
    )
    if after != before:
        raise EvidenceError("result bundle changed during structured extraction")
    summary = parse_json_object(summary_raw, "summary")
    tests = parse_json_object(tests_raw, "tests")
    summary_total, summary_passed = validate_summary(summary)
    discovered, executed = validate_tests_tree(tests, target)
    if summary_total != discovered or summary_passed != executed:
        raise EvidenceError(
            "summary counts do not match the exact passed Test Case tree"
        )
    digest_builder = hashlib.sha256()
    digest_builder.update(b"qinao.xcresult.assertion-evidence.v1\x00summary\x00")
    digest_builder.update(summary_raw)
    digest_builder.update(b"\x00tests\x00")
    digest_builder.update(tests_raw)
    return ExecutionEvidence(
        target=target,
        discovered=discovered,
        executed=executed,
        digest=digest_builder.hexdigest(),
    )


def main() -> int:
    try:
        args = parse_args()
        (
            package,
            derived_data,
            result_bundle,
            target,
            xcodebuild_executable,
            xcresulttool_executable,
        ) = validate_inputs(args)
    except ValidationError as error:
        print(f"xcode-test: invalid: {error}", file=sys.stderr)
        return EXIT_INVALID

    derived_binding: SecureOutputRoot | None = None
    result_binding: SecureOutputRoot | None = None
    try:
        derived_binding = create_secure_output_root(
            derived_data,
            "--derived-data-path",
        )
        result_binding = create_secure_output_root(
            result_bundle,
            "--result-bundle-path",
        )
    except (ValidationError, CleanupError) as error:
        cleanup_errors: list[str] = []
        if isinstance(error, CleanupError):
            cleanup_errors.append(str(error))
        for binding in (result_binding, derived_binding):
            if binding is None:
                continue
            try:
                cleanup_secure_output_root(binding)
            except CleanupError as cleanup_error:
                cleanup_errors.append(str(cleanup_error))
        if cleanup_errors:
            print(
                "xcode-test: cleanup failure: " + "; ".join(cleanup_errors),
                file=sys.stderr,
            )
            return EXIT_CLEANUP_FAILURE
        print(f"xcode-test: invalid: {error}", file=sys.stderr)
        return EXIT_INVALID

    assert derived_binding is not None
    assert result_binding is not None
    actual_derived_data = derived_binding.actual_path
    actual_result_bundle = result_binding.actual_path
    environment = sterile_subprocess_environment(derived_binding)
    outcome: ExecutionEvidence | None = None
    exit_code = 0
    failure_message: str | None = None
    xcodebuild_command = [
        os.fspath(xcodebuild_executable),
        "test",
        "-scheme",
        args.scheme,
        "-destination",
        args.destination,
        "-derivedDataPath",
        str(actual_derived_data),
        "-resultBundlePath",
        str(actual_result_bundle),
        f"-only-testing:{target}",
    ]
    try:
        try:
            require_secure_output_binding(
                derived_binding,
                require_output_missing=True,
            )
            require_secure_output_binding(
                result_binding,
                require_output_missing=True,
            )
            xcodebuild_result = run_process(
                xcodebuild_command,
                cwd=package,
                environment=environment,
                timeout_seconds=args.timeout_seconds,
                output_limit_bytes=XCODEBUILD_OUTPUT_LIMIT_BYTES,
            )
        except (InvocationError, ValidationError) as error:
            exit_code = EXIT_XCODEBUILD_FAILURE
            failure_message = f"xcode-test: xcodebuild failure: {error}"
        else:
            if xcodebuild_result.returncode != 0:
                exit_code = EXIT_XCODEBUILD_FAILURE
                failure_message = (
                    "xcode-test: xcodebuild failure: exited "
                    f"{xcodebuild_result.returncode}"
                )
            else:
                try:
                    require_secure_output_binding(
                        derived_binding,
                        require_output_missing=False,
                    )
                    require_secure_output_binding(
                        result_binding,
                        require_output_missing=False,
                    )
                    validate_created_directory(
                        actual_derived_data,
                        require_nonempty=False,
                    )
                    outcome = collect_evidence(
                        xcresulttool_executable=xcresulttool_executable,
                        package=package,
                        result_bundle=actual_result_bundle,
                        result_binding=result_binding,
                        runtime_binding=derived_binding,
                        target=target,
                        environment=environment,
                        timeout_seconds=args.timeout_seconds,
                    )
                except (EvidenceError, ValidationError) as error:
                    exit_code = EXIT_EVIDENCE_FAILURE
                    failure_message = f"xcode-test: evidence failure: {error}"
    finally:
        cleanup_errors: list[str] = []
        for binding in (result_binding, derived_binding):
            try:
                cleanup_secure_output_root(binding)
            except CleanupError as error:
                cleanup_errors.append(str(error))
        if cleanup_errors:
            exit_code = EXIT_CLEANUP_FAILURE
            failure_message = "xcode-test: cleanup failure: " + "; ".join(
                cleanup_errors
            )
            outcome = None

    if failure_message is not None:
        print(failure_message, file=sys.stderr)
        return exit_code
    if outcome is None:
        print("xcode-test: evidence failure: no outcome", file=sys.stderr)
        return EXIT_EVIDENCE_FAILURE
    print(
        f"xcode-test: PASS target={outcome.target} "
        f"discovered={outcome.discovered} executed={outcome.executed} "
        f"evidence-sha256={outcome.digest}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
