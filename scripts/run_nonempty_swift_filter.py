#!/usr/bin/env python3
"""Run a closed Swift test-suite alternation with diagnostic xUnit checks.

The local descriptor binding below closes ordinary pathname replacement and
non-vacuity gaps. It does not authenticate same-UID writers, moved aliases, or
watcher provenance. Any ``runnerAuthenticated`` authority claim still requires
the separately credentialed protected harness/guest required by Amendment 2.
"""

from __future__ import annotations

import argparse
import os
import re
import selectors
import signal
import stat
import subprocess
import sys
import tempfile
import time
import xml.etree.ElementTree as ElementTree
from pathlib import Path


EXIT_INVALID = 1
EXIT_BUILD_FAILURE = 2
EXIT_DISCOVERY_FAILURE = 3
EXIT_ZERO_EXECUTION = 4
EXIT_TEST_FAILURE = 5
SUITE_NAME = r"[A-Za-z_][A-Za-z0-9_]*"
CLOSED_ALTERNATION = re.compile(rf"{SUITE_NAME}(?:\|{SUITE_NAME})*")
DOTTED_SUITE = re.compile(rf"{SUITE_NAME}(?:\.{SUITE_NAME})*")
FULLY_QUALIFIED_SUITE = re.compile(rf"{SUITE_NAME}(?:\.{SUITE_NAME})+")
MAX_XUNIT_BYTES = 16 * 1024 * 1024
XUNIT_READ_CHUNK_BYTES = 1024 * 1024
SWIFT_TIMEOUT_SECONDS = 30 * 60
SWIFT_TERMINATION_GRACE_SECONDS = 5.0
PROCESS_READ_CHUNK_BYTES = 64 * 1024
SWIFT_STDOUT_LIMIT_BYTES = 64 * 1024 * 1024
SWIFT_STDERR_LIMIT_BYTES = 64 * 1024 * 1024
BOUND_METADATA_FIELDS = (
    "st_dev",
    "st_ino",
    "st_mode",
    "st_nlink",
    "st_size",
    "st_mtime_ns",
    "st_ctime_ns",
)


class FilterError(ValueError):
    """A fail-closed filter or package validation error."""


class DiscoveryError(ValueError):
    """SwiftPM discovery output was missing, ambiguous, or malformed."""


class EvidenceError(ValueError):
    """Structured test-execution evidence was missing or malformed."""


class SwiftInvocationError(OSError):
    """The Swift tool process could not be started."""


class ProcessOutputLimitExceeded(OSError):
    """A protected child emitted one byte beyond its declared stream cap."""


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--swift-executable", type=Path, required=True)
    parser.add_argument("--package-path", type=Path, required=True)
    parser.add_argument("--filter", required=True)
    parser.add_argument("--require-suite", action="append")
    parser.add_argument("--require-test", action="append")
    return parser.parse_args()


def validate_executable(path: Path, option: str) -> Path:
    prefix = f"{option} must be an absolute canonical regular non-symlink executable"
    if not path.is_absolute():
        raise FilterError(f"{prefix}: path is not absolute")
    try:
        metadata = os.lstat(path)
        resolved = path.resolve(strict=True)
    except (OSError, RuntimeError) as error:
        raise FilterError(f"{prefix}: path is unavailable: {error}") from error
    if stat.S_ISLNK(metadata.st_mode) or resolved != path:
        raise FilterError(f"{prefix}: path is symlinked or not canonical")
    if not stat.S_ISREG(metadata.st_mode):
        raise FilterError(f"{prefix}: path is not a regular file")
    if not os.access(path, os.X_OK):
        raise FilterError(f"{prefix}: path is not executable")
    return path


def derived_suites(filter_value: str) -> list[str]:
    if CLOSED_ALTERNATION.fullmatch(filter_value) is None:
        raise FilterError(
            "--filter must be a closed alternation such as SuiteA|SuiteB|SuiteC"
        )
    suites = filter_value.split("|")
    if len(suites) != len(set(suites)):
        raise FilterError(
            "--filter must be a closed alternation with unique suite names"
        )
    return suites


def required_suite_map(
    required: list[str] | None,
    suites: list[str],
) -> dict[str, str]:
    if required is None:
        return {}
    if (
        len(required) != len(suites)
        or len(required) != len(set(required))
        or any(DOTTED_SUITE.fullmatch(item) is None for item in required)
    ):
        raise FilterError(
            "--require-suite set must equal the complete filter-derived set"
        )
    mapped: dict[str, str] = {}
    for identity in required:
        selector = identity.rsplit(".", 1)[-1]
        if selector not in suites or selector in mapped:
            raise FilterError(
                "--require-suite set must equal the complete filter-derived set"
            )
        mapped[selector] = identity
    if set(mapped) != set(suites):
        raise FilterError(
            "--require-suite set must equal the complete filter-derived set"
        )
    return mapped


def required_test_set(
    required: list[str] | None,
    suites: list[str],
) -> set[str]:
    if required is None:
        return set()
    if len(required) != len(set(required)):
        raise FilterError("--require-test IDs must be unique")

    parsed: set[str] = set()
    for test_id in required:
        if test_id.count("/") != 1:
            raise FilterError(
                "--require-test must be Module.Suite/testName with one slash"
            )
        classname, test_name = test_id.split("/", 1)
        if (
            FULLY_QUALIFIED_SUITE.fullmatch(classname) is None
            or not test_name
            or any(
                character.isspace() or not character.isprintable()
                for character in test_name
            )
        ):
            raise FilterError(
                "--require-test must be a non-empty printable "
                "Module.Suite/testName without whitespace"
            )
        if classname.rsplit(".", 1)[-1] not in suites:
            raise FilterError("--require-test must belong to a filter-derived suite")
        parsed.add(test_id)
    return parsed


def parse_discovered_test_ids(output: str) -> dict[str, str]:
    discovered: dict[str, str] = {}
    for line in output.splitlines():
        if not line or line != line.strip() or "/" not in line:
            raise DiscoveryError("swift test list emitted a non-test or malformed line")
        classname, name = line.split("/", 1)
        if (
            DOTTED_SUITE.fullmatch(classname) is None
            or not name
            or name != name.strip()
        ):
            raise DiscoveryError(f"swift test list emitted malformed test ID: {line!r}")
        if line in discovered:
            raise DiscoveryError(f"swift test list emitted duplicate test ID: {line}")
        discovered[line] = classname
    if not discovered:
        raise DiscoveryError("swift test list emitted no test IDs")
    return discovered


def resolve_suite_identities(
    discovered: dict[str, str],
    suites: list[str],
    required: dict[str, str],
) -> dict[str, str]:
    classnames = set(discovered.values())
    resolved: dict[str, str] = {}
    problems: list[str] = []
    for selector in suites:
        required_identity = required.get(selector)
        if required_identity is not None and "." in required_identity:
            candidates = [required_identity] if required_identity in classnames else []
        else:
            candidates = sorted(
                classname
                for classname in classnames
                if classname.rsplit(".", 1)[-1] == selector
            )
        if len(candidates) == 1:
            resolved[selector] = candidates[0]
        elif not candidates:
            problems.append(f"{selector} (missing)")
        else:
            problems.append(f"{selector} (ambiguous: {', '.join(candidates)})")
    if problems:
        raise DiscoveryError(
            "derived suites not discovered exactly: " + "; ".join(problems)
        )
    return resolved


def expected_test_ids(
    discovered: dict[str, str],
    suite_identities: dict[str, str],
) -> set[str]:
    identities = set(suite_identities.values())
    expected = {
        test_id for test_id, classname in discovered.items() if classname in identities
    }
    missing_suites = [
        selector
        for selector, classname in suite_identities.items()
        if classname not in {discovered[test_id] for test_id in expected}
    ]
    if missing_suites:
        raise DiscoveryError(
            "derived suites contain no discovered test IDs: "
            + ", ".join(missing_suites)
        )
    return expected


def validate_required_test_discovery(
    required: set[str],
    discovered: dict[str, str],
    suite_identities: dict[str, str],
) -> None:
    if not required:
        return
    selected_identities = set(suite_identities.values())
    wrong_suites = sorted(
        test_id
        for test_id in required
        if test_id.split("/", 1)[0] not in selected_identities
    )
    if wrong_suites:
        raise DiscoveryError(
            "required test IDs are outside the exact resolved suites: "
            + ", ".join(wrong_suites)
        )
    missing = sorted(required - set(discovered))
    if missing:
        raise DiscoveryError(
            "required test IDs not discovered exactly: " + ", ".join(missing)
        )


def bound_metadata_tuple(metadata: os.stat_result) -> tuple[int, ...]:
    return tuple(int(getattr(metadata, field)) for field in BOUND_METADATA_FIELDS)


def terminate_process_group(
    process: subprocess.Popen[bytes],
    *,
    grace_seconds: float,
) -> None:
    try:
        os.killpg(process.pid, signal.SIGTERM)
    except (PermissionError, ProcessLookupError):
        pass
    time.sleep(grace_seconds)
    try:
        os.killpg(process.pid, signal.SIGKILL)
    except (PermissionError, ProcessLookupError):
        pass
    if process.stdout is not None:
        process.stdout.close()
    if process.stderr is not None:
        process.stderr.close()
    try:
        process.wait(timeout=grace_seconds)
    except ChildProcessError:
        return
    except subprocess.TimeoutExpired:
        process.kill()
        try:
            process.wait(timeout=grace_seconds)
        except subprocess.TimeoutExpired as error:
            raise SwiftInvocationError(
                "swift tool process could not be reaped after timeout"
            ) from error


def run_swift(
    arguments: list[str],
    *,
    swift_executable: Path,
    timeout_seconds: float = SWIFT_TIMEOUT_SECONDS,
    termination_grace_seconds: float = SWIFT_TERMINATION_GRACE_SECONDS,
    stdout_limit_bytes: int,
    stderr_limit_bytes: int,
) -> subprocess.CompletedProcess[bytes]:
    if (
        timeout_seconds <= 0
        or termination_grace_seconds <= 0
        or stdout_limit_bytes <= 0
        or stderr_limit_bytes <= 0
    ):
        raise SwiftInvocationError(
            "swift tool invocation requires positive time and output bounds"
        )
    command = [os.fspath(swift_executable), *arguments]
    try:
        process = subprocess.Popen(
            command,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=False,
            start_new_session=True,
            pass_fds=(),
        )
    except OSError as error:
        raise SwiftInvocationError(f"swift tool invocation failed: {error}") from error
    if process.stdout is None or process.stderr is None:
        terminate_process_group(
            process,
            grace_seconds=termination_grace_seconds,
        )
        raise SwiftInvocationError("swift tool output pipes are unavailable")
    stdout_buffer = bytearray()
    stderr_buffer = bytearray()
    selector = selectors.DefaultSelector()
    deadline = time.monotonic() + timeout_seconds
    try:
        os.set_blocking(process.stdout.fileno(), False)
        os.set_blocking(process.stderr.fileno(), False)
        selector.register(
            process.stdout,
            selectors.EVENT_READ,
            ("stdout", stdout_buffer, stdout_limit_bytes),
        )
        selector.register(
            process.stderr,
            selectors.EVENT_READ,
            ("stderr", stderr_buffer, stderr_limit_bytes),
        )
        open_streams = 2
        while open_streams:
            remaining_seconds = deadline - time.monotonic()
            if remaining_seconds <= 0:
                raise subprocess.TimeoutExpired(
                    command,
                    timeout_seconds,
                    output=bytes(stdout_buffer),
                    stderr=bytes(stderr_buffer),
                )
            events = selector.select(remaining_seconds)
            if not events:
                continue
            for key, _mask in events:
                stream_name, buffer, limit_bytes = key.data
                read_size = min(
                    PROCESS_READ_CHUNK_BYTES,
                    limit_bytes + 1 - len(buffer),
                )
                chunk = os.read(key.fd, read_size)
                if not chunk:
                    selector.unregister(key.fileobj)
                    key.fileobj.close()
                    open_streams -= 1
                    continue
                buffer.extend(chunk)
                if len(buffer) > limit_bytes:
                    raise ProcessOutputLimitExceeded(
                        f"swift tool {stream_name} limit exceeded ({limit_bytes} bytes)"
                    )
        remaining_seconds = deadline - time.monotonic()
        if remaining_seconds <= 0:
            raise subprocess.TimeoutExpired(
                command,
                timeout_seconds,
                output=bytes(stdout_buffer),
                stderr=bytes(stderr_buffer),
            )
        returncode = process.wait(timeout=remaining_seconds)
    except ProcessOutputLimitExceeded as error:
        terminate_process_group(
            process,
            grace_seconds=termination_grace_seconds,
        )
        raise SwiftInvocationError(f"{error}") from error
    except subprocess.TimeoutExpired as error:
        try:
            terminate_process_group(
                process,
                grace_seconds=termination_grace_seconds,
            )
        except OSError as termination_error:
            raise SwiftInvocationError(
                "swift tool invocation timed out and process-group "
                f"termination failed: {termination_error}"
            ) from termination_error
        raise SwiftInvocationError(
            f"swift tool invocation timed out after {timeout_seconds:g} seconds"
        ) from error
    except OSError as error:
        terminate_process_group(
            process,
            grace_seconds=termination_grace_seconds,
        )
        raise SwiftInvocationError(
            f"swift tool output capture failed: {error}"
        ) from error
    finally:
        selector.close()
    return subprocess.CompletedProcess(
        command,
        returncode,
        bytes(stdout_buffer),
        bytes(stderr_buffer),
    )


def replay_output(completed: subprocess.CompletedProcess[bytes]) -> None:
    if completed.stdout:
        print(
            completed.stdout.decode("utf-8", errors="replace"),
            end="",
        )
    if completed.stderr:
        print(
            completed.stderr.decode("utf-8", errors="replace"),
            end="",
            file=sys.stderr,
        )


def swift_testing_xunit_path(primary: Path) -> Path:
    return primary.with_name(f"{primary.stem}-swift-testing{primary.suffix}")


def validate_xunit_directory_metadata(
    path: Path,
    metadata: os.stat_result,
) -> None:
    if (
        not stat.S_ISDIR(metadata.st_mode)
        or metadata.st_nlink < 1
        or metadata.st_uid != os.getuid()
    ):
        raise EvidenceError(f"structured xUnit directory has unsafe metadata: {path}")


def validate_xunit_file_metadata(
    name: str,
    metadata: os.stat_result,
) -> None:
    if (
        not stat.S_ISREG(metadata.st_mode)
        or metadata.st_nlink != 1
        or metadata.st_uid != os.getuid()
        or metadata.st_size <= 0
        or metadata.st_size > MAX_XUNIT_BYTES
    ):
        raise EvidenceError(f"structured xUnit report has unsafe file metadata: {name}")


def bounded_pread(fd: int, expected_size: int) -> bytes:
    chunks: list[bytes] = []
    offset = 0
    while offset < expected_size:
        requested = min(
            XUNIT_READ_CHUNK_BYTES,
            expected_size - offset,
        )
        chunk = os.pread(fd, requested, offset)
        if not chunk:
            break
        chunks.append(chunk)
        offset += len(chunk)
    return b"".join(chunks)


def secure_xunit_bytes_from_directory(
    directory_fd: int,
    name: str,
) -> tuple[bytes, tuple[int, int]]:
    if (
        not name
        or name in {".", ".."}
        or Path(name).name != name
        or "/" in name
        or "\x00" in name
    ):
        raise EvidenceError(f"structured xUnit report has unsafe basename: {name!r}")
    flags = os.O_RDONLY | os.O_CLOEXEC | os.O_NOFOLLOW | os.O_NONBLOCK
    try:
        fd = os.open(name, flags, dir_fd=directory_fd)
    except FileNotFoundError:
        raise
    except OSError as error:
        raise EvidenceError(
            f"structured xUnit report cannot be opened safely: {name}: {error}"
        ) from error
    try:
        before = os.fstat(fd)
        validate_xunit_file_metadata(name, before)
        before_tuple = bound_metadata_tuple(before)
        try:
            raw = bounded_pread(fd, before.st_size)
        except OSError as error:
            raise EvidenceError(
                f"structured xUnit report cannot be read: {name}: {error}"
            ) from error
        after = os.fstat(fd)
        try:
            path_after = os.stat(
                name,
                dir_fd=directory_fd,
                follow_symlinks=False,
            )
        except OSError as error:
            raise EvidenceError(
                f"structured xUnit report path changed while being read: "
                f"{name}: {error}"
            ) from error
        if (
            len(raw) != before.st_size
            or bound_metadata_tuple(after) != before_tuple
            or bound_metadata_tuple(path_after) != before_tuple
        ):
            raise EvidenceError(
                f"structured xUnit report changed while being read: {name}"
            )
        lowered = raw.lower()
        if b"<!doctype" in lowered or b"<!entity" in lowered:
            raise EvidenceError(
                f"structured xUnit report contains forbidden DTD/entity: {name}"
            )
        return raw, (before.st_dev, before.st_ino)
    except EvidenceError:
        raise
    except OSError as error:
        raise EvidenceError(
            f"structured xUnit report cannot be read safely: {name}: {error}"
        ) from error
    finally:
        os.close(fd)


def open_xunit_directory(path: Path) -> tuple[int, tuple[int, ...]]:
    flags = os.O_RDONLY | os.O_CLOEXEC | os.O_NOFOLLOW | os.O_NONBLOCK | os.O_DIRECTORY
    try:
        directory_fd = os.open(path, flags)
    except OSError as error:
        raise EvidenceError(
            f"structured xUnit directory cannot be opened safely: {path}: {error}"
        ) from error
    try:
        metadata = os.fstat(directory_fd)
        validate_xunit_directory_metadata(path, metadata)
        return directory_fd, bound_metadata_tuple(metadata)
    except EvidenceError:
        os.close(directory_fd)
        raise
    except OSError as error:
        os.close(directory_fd)
        raise EvidenceError(
            f"structured xUnit directory cannot be bound safely: {path}: {error}"
        ) from error


def require_stable_xunit_directory(
    directory_fd: int,
    directory_path: Path,
    before_tuple: tuple[int, ...],
) -> None:
    try:
        after = os.fstat(directory_fd)
    except OSError as error:
        raise EvidenceError(
            "structured xUnit report cannot be read safely: "
            f"directory {directory_path}: {error}"
        ) from error
    if bound_metadata_tuple(after) != before_tuple:
        raise EvidenceError(
            "structured xUnit report changed while being read: "
            f"directory {directory_path}"
        )


def xunit_directory_identity(
    metadata: os.stat_result,
) -> tuple[int, int]:
    return (metadata.st_dev, metadata.st_ino)


def require_xunit_directory_path_identity(
    directory_fd: int,
    directory_path: Path,
    expected_identity: tuple[int, int],
) -> tuple[int, ...]:
    try:
        bound_metadata = os.fstat(directory_fd)
        validate_xunit_directory_metadata(directory_path, bound_metadata)
    except EvidenceError:
        raise
    except OSError as error:
        raise EvidenceError(
            f"structured xUnit directory binding is unavailable: "
            f"{directory_path}: {error}"
        ) from error
    if xunit_directory_identity(bound_metadata) != expected_identity:
        raise EvidenceError(
            f"structured xUnit directory binding identity changed: {directory_path}"
        )
    path_fd, path_tuple = open_xunit_directory(directory_path)
    try:
        if (path_tuple[0], path_tuple[1]) != expected_identity:
            raise EvidenceError(
                f"structured xUnit directory path identity changed: {directory_path}"
            )
    finally:
        os.close(path_fd)
    return bound_metadata_tuple(bound_metadata)


def prebind_xunit_output_directory(
    directory_path: Path,
    expected_names: tuple[str, ...],
) -> tuple[int, tuple[int, int]]:
    """Bind an empty local diagnostic namespace before launching Swift."""
    if len(expected_names) != len(set(expected_names)):
        raise EvidenceError("structured xUnit expected report basenames must be unique")
    for name in expected_names:
        if (
            not name
            or name in {".", ".."}
            or Path(name).name != name
            or "/" in name
            or "\x00" in name
        ):
            raise EvidenceError(
                f"structured xUnit report has unsafe basename: {name!r}"
            )
    directory_fd, directory_tuple = open_xunit_directory(directory_path)
    try:
        try:
            entries = os.listdir(directory_fd)
        except OSError as error:
            raise EvidenceError(
                f"structured xUnit output directory cannot be enumerated: "
                f"{directory_path}: {error}"
            ) from error
        if entries:
            raise EvidenceError(
                f"structured xUnit output directory must start empty: {directory_path}"
            )
        return directory_fd, (directory_tuple[0], directory_tuple[1])
    except EvidenceError:
        os.close(directory_fd)
        raise


def secure_xunit_bytes(path: Path) -> bytes:
    """Read one ordinary diagnostic report without authenticating its writer."""
    directory_fd, directory_tuple = open_xunit_directory(path.parent)
    try:
        raw, _ = secure_xunit_bytes_from_directory(
            directory_fd,
            path.name,
        )
        require_stable_xunit_directory(
            directory_fd,
            path.parent,
            directory_tuple,
        )
        return raw
    finally:
        os.close(directory_fd)


def secure_xunit_reports(
    paths: tuple[Path, Path],
) -> list[tuple[Path, bytes]]:
    """Read ordinary diagnostic reports; this is not runner authentication."""
    if paths[0].parent != paths[1].parent:
        raise EvidenceError(
            "structured xUnit reports must share one bound output directory"
        )
    directory_path = paths[0].parent
    directory_fd, directory_tuple = open_xunit_directory(directory_path)
    present: list[tuple[Path, bytes]] = []
    identities: set[tuple[int, int]] = set()
    try:
        for path in paths:
            try:
                raw, identity = secure_xunit_bytes_from_directory(
                    directory_fd,
                    path.name,
                )
            except FileNotFoundError:
                continue
            if identity in identities:
                raise EvidenceError(
                    "structured xUnit reports alias the same bound inode"
                )
            identities.add(identity)
            present.append((path, raw))
        require_stable_xunit_directory(
            directory_fd,
            directory_path,
            directory_tuple,
        )
    finally:
        os.close(directory_fd)
    if not present:
        raise EvidenceError("structured xUnit reports are missing")
    return present


def secure_xunit_reports_from_prebound_directory(
    directory_fd: int,
    directory_identity: tuple[int, int],
    paths: tuple[Path, Path],
) -> list[tuple[Path, bytes]]:
    if paths[0].parent != paths[1].parent:
        raise EvidenceError(
            "structured xUnit reports must share one bound output directory"
        )
    directory_path = paths[0].parent
    before_tuple = require_xunit_directory_path_identity(
        directory_fd,
        directory_path,
        directory_identity,
    )
    expected_names = {path.name for path in paths}
    try:
        entries = os.listdir(directory_fd)
    except OSError as error:
        raise EvidenceError(
            f"structured xUnit output directory cannot be enumerated: "
            f"{directory_path}: {error}"
        ) from error
    unexpected = sorted(set(entries) - expected_names)
    if unexpected:
        raise EvidenceError(
            "structured xUnit output directory has unexpected entries: "
            + ", ".join(unexpected)
        )

    present: list[tuple[Path, bytes]] = []
    identities: set[tuple[int, int]] = set()
    for path in paths:
        try:
            raw, identity = secure_xunit_bytes_from_directory(
                directory_fd,
                path.name,
            )
        except FileNotFoundError:
            continue
        if identity in identities:
            raise EvidenceError("structured xUnit reports alias the same bound inode")
        identities.add(identity)
        present.append((path, raw))
    require_stable_xunit_directory(
        directory_fd,
        directory_path,
        before_tuple,
    )
    require_xunit_directory_path_identity(
        directory_fd,
        directory_path,
        directory_identity,
    )
    if not present:
        raise EvidenceError("structured xUnit reports are missing")
    return present


def parse_xunit_report(
    path: Path,
) -> list[tuple[str, bool, bool]]:
    raw = secure_xunit_bytes(path)
    return parse_xunit_bytes(raw, path.name)


def parse_xunit_bytes(
    raw: bytes,
    report_name: str,
) -> list[tuple[str, bool, bool]]:
    try:
        text = raw.decode("utf-8", errors="strict")
    except UnicodeDecodeError as error:
        raise EvidenceError(
            f"structured xUnit report must be strict UTF-8 without BOM: {report_name}"
        ) from error
    if text.startswith("\ufeff"):
        raise EvidenceError(
            f"structured xUnit report must be strict UTF-8 without BOM: {report_name}"
        )
    declaration = re.match(r"\A<\?xml(?P<body>[^?]*)\?>", text)
    if declaration is not None:
        encoding = re.search(
            r"\bencoding\s*=\s*(['\"])(?P<value>[^'\"]+)\1",
            declaration.group("body"),
        )
        if encoding is not None and encoding.group("value").casefold() != "utf-8":
            raise EvidenceError(
                f"structured xUnit report must declare UTF-8 encoding: {report_name}"
            )
    lowered = text.casefold()
    if "<!doctype" in lowered or "<!entity" in lowered:
        raise EvidenceError(
            f"structured xUnit report contains forbidden DTD/entity: {report_name}"
        )
    try:
        root = ElementTree.fromstring(text)
    except ElementTree.ParseError as error:
        raise EvidenceError(
            f"malformed structured xUnit report {report_name}: {error}"
        ) from error
    if root.tag != "testsuites":
        raise EvidenceError(f"malformed structured xUnit root in {report_name}")
    cases: list[tuple[str, bool, bool]] = []
    for testcase in root.iter("testcase"):
        classname = testcase.get("classname")
        test_name = testcase.get("name")
        if (
            classname is None
            or DOTTED_SUITE.fullmatch(classname) is None
            or test_name is None
            or not test_name
            or test_name != test_name.strip()
        ):
            raise EvidenceError(f"malformed structured xUnit testcase in {report_name}")
        child_tags = [child.tag for child in testcase]
        if any(
            tag not in {"skipped", "failure", "error", "system-out", "system-err"}
            for tag in child_tags
        ):
            raise EvidenceError(
                f"malformed structured xUnit testcase child in {report_name}"
            )
        skipped = "skipped" in child_tags
        failed = "failure" in child_tags or "error" in child_tags
        if skipped and failed:
            raise EvidenceError(
                f"structured xUnit testcase is both skipped and failed: "
                f"{classname}/{test_name}"
            )
        cases.append((f"{classname}/{test_name}", skipped, failed))
    return cases


def exact_execution_from_reports(
    paths: tuple[Path, Path],
    expected: set[str],
    required: set[str] | None = None,
) -> tuple[set[str], bool]:
    present = secure_xunit_reports(paths)
    return exact_execution_from_report_bytes(present, expected, required)


def exact_execution_from_prebound_reports(
    directory_fd: int,
    directory_identity: tuple[int, int],
    paths: tuple[Path, Path],
    expected: set[str],
    required: set[str] | None = None,
) -> tuple[set[str], bool]:
    """Check local non-vacuity from the namespace bound before Swift launch."""
    present = secure_xunit_reports_from_prebound_directory(
        directory_fd,
        directory_identity,
        paths,
    )
    return exact_execution_from_report_bytes(present, expected, required)


def exact_execution_from_report_bytes(
    present: list[tuple[Path, bytes]],
    expected: set[str],
    required: set[str] | None = None,
) -> tuple[set[str], bool]:
    observed: set[str] = set()
    executed: set[str] = set()
    had_failure = False
    for path, raw in present:
        for test_id, skipped, failed in parse_xunit_bytes(raw, path.name):
            if test_id in observed:
                raise EvidenceError(f"duplicate structured xUnit test ID: {test_id}")
            observed.add(test_id)
            if test_id not in expected:
                raise EvidenceError(f"unknown structured xUnit test ID: {test_id}")
            if not skipped:
                executed.add(test_id)
            had_failure = had_failure or failed
    missing_required = sorted((required or set()) - executed)
    if missing_required:
        raise EvidenceError(
            "required test IDs missing from non-skipped structured xUnit "
            "execution: " + ", ".join(missing_required)
        )
    missing_execution = sorted(expected - executed)
    if missing_execution:
        raise EvidenceError(
            "missing discovered test IDs from non-skipped structured xUnit "
            "execution: " + ", ".join(missing_execution)
        )
    return executed, had_failure


def executed_suite_counts(
    executed: set[str],
    suite_identities: dict[str, str],
) -> dict[str, int]:
    counts = {selector: 0 for selector in suite_identities}
    identity_to_selector = {
        identity: selector for selector, identity in suite_identities.items()
    }
    for test_id in executed:
        classname, _ = test_id.split("/", 1)
        selector = identity_to_selector.get(classname)
        if selector is not None:
            counts[selector] += 1
    return counts


def main() -> int:
    try:
        args = parse_args()
        swift_executable = validate_executable(
            args.swift_executable,
            "--swift-executable",
        )
        suites = derived_suites(args.filter)
        required = required_suite_map(args.require_suite, suites)
        required_tests = required_test_set(args.require_test, suites)
        package_path = args.package_path
        if not package_path.is_dir() or not (package_path / "Package.swift").is_file():
            raise FilterError(
                f"--package-path is not an exact Swift package: {package_path}"
            )
    except FilterError as error:
        print(f"swift-filter: invalid: {error}", file=sys.stderr)
        return EXIT_INVALID

    build_arguments = [
        "build",
        "--package-path",
        str(package_path),
        "--build-tests",
    ]
    try:
        build_result = run_swift(
            build_arguments,
            swift_executable=swift_executable,
            stdout_limit_bytes=SWIFT_STDOUT_LIMIT_BYTES,
            stderr_limit_bytes=SWIFT_STDERR_LIMIT_BYTES,
        )
    except SwiftInvocationError as error:
        print(f"swift-filter: build failure: {error}", file=sys.stderr)
        return EXIT_BUILD_FAILURE
    replay_output(build_result)
    if build_result.returncode != 0:
        print("swift-filter: build failure", file=sys.stderr)
        return EXIT_BUILD_FAILURE

    list_arguments = ["test", "--package-path", str(package_path), "list"]
    list_arguments.append("--skip-build")
    try:
        list_result = run_swift(
            list_arguments,
            swift_executable=swift_executable,
            stdout_limit_bytes=SWIFT_STDOUT_LIMIT_BYTES,
            stderr_limit_bytes=SWIFT_STDERR_LIMIT_BYTES,
        )
    except SwiftInvocationError as error:
        print(f"swift-filter: discovery failure: {error}", file=sys.stderr)
        return EXIT_DISCOVERY_FAILURE
    replay_output(list_result)
    if list_result.returncode != 0:
        print("swift-filter: discovery failure", file=sys.stderr)
        return EXIT_DISCOVERY_FAILURE
    try:
        try:
            discovery_output = list_result.stdout.decode(
                "utf-8",
                errors="strict",
            )
        except UnicodeDecodeError as error:
            raise DiscoveryError("swift test list output is not valid UTF-8") from error
        discovered = parse_discovered_test_ids(discovery_output)
        suite_identities = resolve_suite_identities(
            discovered,
            suites,
            required,
        )
        expected = expected_test_ids(discovered, suite_identities)
        validate_required_test_discovery(
            required_tests,
            discovered,
            suite_identities,
        )
    except DiscoveryError as error:
        missing_discovery = str(error)
        print(
            f"swift-filter: discovery failure; {missing_discovery}",
            file=sys.stderr,
        )
        return EXIT_DISCOVERY_FAILURE

    with tempfile.TemporaryDirectory(prefix="qinao-swift-filter-") as output_directory:
        primary_xunit = Path(output_directory) / "results.xml"
        swift_testing_xunit = swift_testing_xunit_path(primary_xunit)
        try:
            output_directory_fd, output_directory_identity = (
                prebind_xunit_output_directory(
                    Path(output_directory),
                    (primary_xunit.name, swift_testing_xunit.name),
                )
            )
        except EvidenceError as error:
            print(
                f"swift-filter: zero execution; {error}",
                file=sys.stderr,
            )
            return EXIT_ZERO_EXECUTION
        run_arguments = [
            "test",
            "--package-path",
            str(package_path),
            "--skip-build",
            "--parallel",
            "--num-workers",
            "1",
            "--filter",
            args.filter,
            "--xunit-output",
            str(primary_xunit),
        ]
        try:
            try:
                run_result = run_swift(
                    run_arguments,
                    swift_executable=swift_executable,
                    stdout_limit_bytes=SWIFT_STDOUT_LIMIT_BYTES,
                    stderr_limit_bytes=SWIFT_STDERR_LIMIT_BYTES,
                )
            except SwiftInvocationError as error:
                print(f"swift-filter: test failure: {error}", file=sys.stderr)
                return EXIT_TEST_FAILURE
            replay_output(run_result)
            try:
                executed, structured_failure = exact_execution_from_prebound_reports(
                    output_directory_fd,
                    output_directory_identity,
                    (primary_xunit, swift_testing_xunit),
                    expected,
                    required_tests,
                )
            except EvidenceError as error:
                if run_result.returncode != 0:
                    print(
                        "swift-filter: test failure with invalid structured "
                        f"xUnit evidence: {error}",
                        file=sys.stderr,
                    )
                    return EXIT_TEST_FAILURE
                print(
                    f"swift-filter: zero execution; {error}",
                    file=sys.stderr,
                )
                return EXIT_ZERO_EXECUTION
        finally:
            os.close(output_directory_fd)

    counts = executed_suite_counts(executed, suite_identities)
    missing_execution = [suite for suite in suites if counts[suite] == 0]
    if missing_execution:
        print(
            "swift-filter: zero execution; suites executed no tests: "
            + ", ".join(missing_execution),
            file=sys.stderr,
        )
        return EXIT_ZERO_EXECUTION
    if run_result.returncode != 0 or structured_failure:
        print("swift-filter: test failure after exact execution", file=sys.stderr)
        return EXIT_TEST_FAILURE

    count_summary = " ".join(f"{suite}={counts[suite]}" for suite in suites)
    print(f"swift-filter: PASS executed={len(executed)} {count_summary}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
