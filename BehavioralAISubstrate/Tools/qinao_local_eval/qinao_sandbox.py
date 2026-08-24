"""Deny-default macOS Seatbelt runner for model-generated Python.

The process exit status is not a completion proof. A trusted launcher emits a
per-run, out-of-band completion witness only when ``runpy.run_path`` returns
normally. Resource-policy breaches are model failures represented by a
bounded, non-zero ``CompletedProcess``; only a wall-clock timeout raises
``subprocess.TimeoutExpired``. Activation and teardown failures remain typed
infrastructure failures.

The completion witness is a control-flow guard, not a cryptographic boundary:
generated code shares the Python interpreter with the launcher and can inspect
frames or enumerate inherited descriptors. Seatbelt and the host process are
the actual security boundaries.

CPU, file-size, and open-descriptor limits are kernel-enforced. Resident
memory, thread count, output size, and aggregate directory quotas are sampled
by the trusted host every five milliseconds and checked again at exit; they are
rapid fail-closed guards with finite overshoot, not hard memory/filesystem
isolation.
"""

from __future__ import annotations

import ctypes
import json
import math
import os
import secrets
import select
import shutil
import signal
import stat
import subprocess
import tempfile
import time
from typing import BinaryIO

try:
    import resource as _resource
except ImportError:  # pragma: no cover - macOS always provides this module
    _resource = None


_ACTIVATION_MAGIC = b"QSB2"
_COMPLETION_MAGIC = b"QSC1"
_RESOURCE_MAGIC = b"QSR1"
_CHALLENGE_BYTES = 32
_MAX_CONTROL_BYTES = 128

# Quantitative host-protection policy. These names are intentionally public so
# tests and future policy review compare against the enforced values.
MAX_CAPTURE_BYTES = 64 * 1024
MAX_SCRIPT_BYTES = 256 * 1024
MAX_SINGLE_FILE_BYTES = 256 * 1024
MAX_DIRECTORY_BYTES = 1024 * 1024
MAX_DIRECTORY_ENTRIES = 64
MAX_RESIDENT_BYTES = 256 * 1024 * 1024
MAX_THREADS = 32
MAX_CPU_SECONDS = 15
MAX_OPEN_FILES = 64
RESOURCE_LIMIT_RETURN_CODE = 120
INCOMPLETE_RETURN_CODE = 121
_MONITOR_INTERVAL_SECONDS = 0.005
_SOURCE_READ_CHUNK = 64 * 1024

_TRUSTED_LAUNCHER = """\
import errno
import json
import os
import resource
import runpy
import sys

activation_fd = int(sys.argv[1])
completion_fd = int(sys.argv[2])
resource_fd = int(sys.argv[3])
activation_magic = bytes.fromhex(sys.argv[4])
completion_magic = bytes.fromhex(sys.argv[5])
resource_magic = bytes.fromhex(sys.argv[6])
script_path = sys.argv[7]
limits = json.loads(sys.argv[8])

for name, soft, hard in limits:
    kind = getattr(resource, name, None)
    if kind is None:
        raise RuntimeError("required resource limit is unavailable: " + name)
    try:
        resource.setrlimit(kind, (int(soft), int(hard)))
    except BaseException as error:
        raise RuntimeError("could not enforce resource limit: " + name) from error

os.write(activation_fd, activation_magic)
os.close(activation_fd)
sys.argv = [script_path]
if hasattr(sys, "orig_argv"):
    sys.orig_argv = [sys.executable, script_path]

try:
    runpy.run_path(script_path, run_name="__main__")
except MemoryError:
    os.write(resource_fd, resource_magic + b":memory")
    raise
except OSError as error:
    if error.errno == errno.EFBIG:
        os.write(resource_fd, resource_magic + b":single-file")
    elif error.errno in (errno.EMFILE, errno.ENFILE):
        os.write(resource_fd, resource_magic + b":open-files")
    raise
except BaseException:
    raise
else:
    os.write(completion_fd, completion_magic)
finally:
    for descriptor in (completion_fd, resource_fd):
        try:
            os.close(descriptor)
        except OSError:
            pass
"""


class SandboxInfrastructureError(RuntimeError):
    """The generated program never entered or left a proven sandbox runtime."""

    def __init__(
        self,
        message: str,
        *,
        returncode: int | None = None,
        stderr: bytes = b"",
    ) -> None:
        super().__init__(message)
        self.returncode = returncode
        self.stderr = stderr


def _seatbelt_string(path: str) -> str:
    return json.dumps(path, ensure_ascii=False)


def sandbox_profile(tmpdir: str) -> str:
    run_root = os.path.realpath(tmpdir)
    home = os.path.realpath(os.path.expanduser("~"))
    return f"""(version 1)
(deny default)
(allow process*)
(deny process-fork)
(allow sysctl-read)
(allow mach-lookup)
(allow file-read*)
(deny file-read* (subpath {_seatbelt_string(os.path.join(home, '.ssh'))}) (subpath {_seatbelt_string(os.path.join(home, '.aws'))}) (subpath {_seatbelt_string(os.path.join(home, 'Library/Keychains'))}))
(allow file-write* (subpath {_seatbelt_string(run_root)}) (literal "/dev/null"))
(deny network*)
"""


def _minimal_environment(run_root: str) -> dict[str, str]:
    return {
        "HOME": run_root,
        "TMPDIR": run_root,
        "PATH": "/usr/bin:/bin:/usr/sbin:/sbin",
        "LANG": "C",
        "LC_ALL": "C",
    }


def _challenge(prefix: bytes) -> bytes:
    return prefix + secrets.token_bytes(_CHALLENGE_BYTES)


def _read_exact(read_fd: int, expected_size: int, deadline: float) -> bytes:
    marker = bytearray()
    while len(marker) < expected_size:
        remaining = deadline - time.monotonic()
        if remaining <= 0:
            break
        try:
            readable, _, _ = select.select([read_fd], [], [], remaining)
        except InterruptedError:
            continue
        if not readable:
            break
        chunk = os.read(read_fd, expected_size - len(marker))
        if not chunk:
            break
        marker.extend(chunk)
    return bytes(marker)


def _read_activation(read_fd: int, deadline: float, expected: bytes) -> bytes:
    return _read_exact(read_fd, len(expected), deadline)


def _read_available(read_fd: int, maximum: int = _MAX_CONTROL_BYTES) -> bytes:
    """Read only currently available control bytes, never waiting on leaked writers."""

    output = bytearray()
    os.set_blocking(read_fd, False)
    while len(output) <= maximum:
        try:
            chunk = os.read(read_fd, maximum + 1 - len(output))
        except BlockingIOError:
            break
        except InterruptedError:
            continue
        if not chunk:
            break
        output.extend(chunk)
    return bytes(output[: maximum + 1])


def _kill_process_group(process: subprocess.Popen[bytes]) -> None:
    try:
        os.killpg(process.pid, signal.SIGKILL)
    except ProcessLookupError:
        pass
    except OSError as error:
        raise SandboxInfrastructureError(
            "failed to clean sandbox process group", returncode=process.poll()
        ) from error


def _validated_timeout(timeout: int | float) -> float:
    if isinstance(timeout, bool) or not isinstance(timeout, (int, float)):
        raise SandboxInfrastructureError("sandbox timeout must be a finite positive number")
    try:
        value = float(timeout)
    except (OverflowError, TypeError, ValueError) as error:
        raise SandboxInfrastructureError(
            "sandbox timeout must be a finite positive number"
        ) from error
    if not math.isfinite(value) or value <= 0:
        raise SandboxInfrastructureError("sandbox timeout must be a finite positive number")
    return value


def _effective_limit(name: str, requested: int) -> int:
    if _resource is None:
        raise SandboxInfrastructureError("required resource limits are unavailable")
    kind = getattr(_resource, name, None)
    if kind is None:
        raise SandboxInfrastructureError(f"required resource limit is unavailable: {name}")
    try:
        _soft, hard = _resource.getrlimit(kind)
    except (OSError, ValueError) as error:
        raise SandboxInfrastructureError(
            f"could not verify required resource limit: {name}"
        ) from error
    infinity = getattr(_resource, "RLIM_INFINITY", -1)
    if hard != infinity:
        requested = min(requested, int(hard))
    if requested <= 0:
        raise SandboxInfrastructureError(f"required resource limit is unusable: {name}")
    return requested


def _resource_limits(cpu_seconds: int) -> list[tuple[str, int, int]]:
    file_size = _effective_limit("RLIMIT_FSIZE", MAX_SINGLE_FILE_BYTES)
    open_files = _effective_limit("RLIMIT_NOFILE", MAX_OPEN_FILES)
    cpu_hard = _effective_limit("RLIMIT_CPU", cpu_seconds + 1)
    cpu_soft = min(cpu_seconds, cpu_hard)
    return [
        ("RLIMIT_CPU", cpu_soft, cpu_hard),
        ("RLIMIT_FSIZE", file_size, file_size),
        ("RLIMIT_NOFILE", open_files, open_files),
    ]


class _ProcTaskInfo(ctypes.Structure):
    """Darwin ``struct proc_taskinfo`` from <sys/proc_info.h>."""

    _fields_ = [
        ("virtual_size", ctypes.c_uint64),
        ("resident_size", ctypes.c_uint64),
        ("total_user", ctypes.c_uint64),
        ("total_system", ctypes.c_uint64),
        ("threads_user", ctypes.c_uint64),
        ("threads_system", ctypes.c_uint64),
        ("policy", ctypes.c_int32),
        ("faults", ctypes.c_int32),
        ("pageins", ctypes.c_int32),
        ("cow_faults", ctypes.c_int32),
        ("messages_sent", ctypes.c_int32),
        ("messages_received", ctypes.c_int32),
        ("syscalls_mach", ctypes.c_int32),
        ("syscalls_unix", ctypes.c_int32),
        ("context_switches", ctypes.c_int32),
        ("thread_count", ctypes.c_int32),
        ("running_threads", ctypes.c_int32),
        ("priority", ctypes.c_int32),
    ]


def _load_proc_pidinfo():
    try:
        library = ctypes.CDLL("/usr/lib/libproc.dylib", use_errno=True)
        function = library.proc_pidinfo
        function.argtypes = [
            ctypes.c_int,
            ctypes.c_int,
            ctypes.c_uint64,
            ctypes.c_void_p,
            ctypes.c_int,
        ]
        function.restype = ctypes.c_int
    except (AttributeError, OSError) as error:
        raise SandboxInfrastructureError(
            "Darwin resident-memory accounting is unavailable"
        ) from error
    return function


_PROC_PIDTASKINFO = 4
_PROC_PIDINFO = None


def _process_usage(pid: int) -> tuple[int, int] | None:
    global _PROC_PIDINFO
    if _PROC_PIDINFO is None:
        _PROC_PIDINFO = _load_proc_pidinfo()
    information = _ProcTaskInfo()
    received = _PROC_PIDINFO(
        int(pid),
        _PROC_PIDTASKINFO,
        0,
        ctypes.byref(information),
        ctypes.sizeof(information),
    )
    if received == 0:
        return None
    if received != ctypes.sizeof(information):
        raise SandboxInfrastructureError(
            "Darwin resident-memory accounting returned a partial record"
        )
    return int(information.resident_size), int(information.thread_count)


def _resident_bytes(pid: int) -> int | None:
    usage = _process_usage(pid)
    return None if usage is None else usage[0]


def _verify_memory_accounting() -> None:
    try:
        usage = _process_usage(os.getpid())
    except (OSError, ValueError) as error:
        raise SandboxInfrastructureError(
            "could not verify Darwin resident-memory accounting"
        ) from error
    if usage is None or usage[0] <= 0 or usage[1] <= 0:
        raise SandboxInfrastructureError(
            "Darwin resident-memory accounting could not observe the host process"
        )


def _validated_cpu_seconds(
    cpu_seconds: int | float | None, timeout_value: float
) -> int:
    """Use wall-time-equivalent CPU by default; tests may request a stricter cap."""

    candidate: int | float = (
        min(MAX_CPU_SECONDS, max(1, math.ceil(timeout_value)))
        if cpu_seconds is None
        else cpu_seconds
    )
    if isinstance(candidate, bool) or not isinstance(candidate, (int, float)):
        raise SandboxInfrastructureError("sandbox CPU limit must be a finite positive number")
    try:
        value = float(candidate)
    except (OverflowError, TypeError, ValueError) as error:
        raise SandboxInfrastructureError(
            "sandbox CPU limit must be a finite positive number"
        ) from error
    if not math.isfinite(value) or value <= 0:
        raise SandboxInfrastructureError("sandbox CPU limit must be a finite positive number")
    return max(1, math.ceil(value))


def _read_source_snapshot(script_path: str) -> tuple[bytes | None, str | None]:
    """Open once without following links and take a bounded, stable byte snapshot."""

    required_flags = ("O_CLOEXEC", "O_NOFOLLOW", "O_NONBLOCK")
    if any(not hasattr(os, name) for name in required_flags):
        raise SandboxInfrastructureError(
            "secure generated-program snapshot flags are unavailable"
        )
    descriptor = -1
    try:
        descriptor = os.open(
            script_path,
            os.O_RDONLY | os.O_CLOEXEC | os.O_NOFOLLOW | os.O_NONBLOCK,
        )
        before = os.fstat(descriptor)
        if not stat.S_ISREG(before.st_mode):
            raise SandboxInfrastructureError("generated program must be a regular file")
        if before.st_size > MAX_SCRIPT_BYTES:
            return None, "generated-program-size"
        chunks: list[bytes] = []
        total = 0
        while True:
            chunk = os.read(descriptor, min(_SOURCE_READ_CHUNK, MAX_SCRIPT_BYTES + 1 - total))
            if not chunk:
                break
            chunks.append(chunk)
            total += len(chunk)
            if total > MAX_SCRIPT_BYTES:
                return None, "generated-program-size"
        after = os.fstat(descriptor)
        stable_fields = (
            "st_dev",
            "st_ino",
            "st_mode",
            "st_size",
            "st_mtime_ns",
            "st_ctime_ns",
        )
        if any(getattr(before, field) != getattr(after, field) for field in stable_fields):
            raise SandboxInfrastructureError(
                "generated program changed while its private snapshot was read"
            )
        snapshot = b"".join(chunks)
        if len(snapshot) != before.st_size:
            raise SandboxInfrastructureError(
                "generated program snapshot length did not match authenticated metadata"
            )
        return snapshot, None
    except SandboxInfrastructureError:
        raise
    except (OSError, TypeError, ValueError) as error:
        raise SandboxInfrastructureError("could not securely snapshot generated program") from error
    finally:
        if descriptor >= 0:
            try:
                os.close(descriptor)
            except OSError as error:
                raise SandboxInfrastructureError(
                    "could not close generated-program snapshot"
                ) from error


def _make_tree_removable(run_root: str) -> None:
    """Restore directory traversal without following generated symlinks."""

    pending = [run_root]
    while pending:
        path = pending.pop()
        try:
            metadata = os.lstat(path)
        except FileNotFoundError:
            continue
        if not stat.S_ISDIR(metadata.st_mode) or stat.S_ISLNK(metadata.st_mode):
            continue
        os.chmod(path, 0o700, follow_symlinks=False)
        with os.scandir(path) as entries:
            for entry in entries:
                if entry.is_dir(follow_symlinks=False):
                    pending.append(entry.path)


def _remove_run_root(run_root: str) -> None:
    recovery_error: OSError | None = None
    try:
        _make_tree_removable(run_root)
    except OSError as error:
        recovery_error = error
    try:
        shutil.rmtree(run_root)
    except OSError as error:
        if recovery_error is not None:
            raise error from recovery_error
        raise
    if os.path.lexists(run_root):
        raise OSError(f"sandbox run root still exists after removal: {run_root}")


def _filesystem_breach(
    run_root: str, *, stdout_fd: int, stderr_fd: int
) -> str | None:
    """Return the first unprovable or exceeded private-directory resource."""

    entries_seen = 0
    logical_bytes = 0
    directory_flags = (
        os.O_RDONLY
        | getattr(os, "O_CLOEXEC", 0)
        | getattr(os, "O_DIRECTORY", 0)
        | getattr(os, "O_NOFOLLOW", 0)
        | getattr(os, "O_NONBLOCK", 0)
    )
    if not all(hasattr(os, name) for name in ("O_CLOEXEC", "O_DIRECTORY", "O_NOFOLLOW")):
        return "directory-observability"

    def scan_directory(descriptor: int) -> str | None:
        nonlocal entries_seen, logical_bytes
        with os.scandir(descriptor) as children:
            for child in children:
                metadata = os.stat(
                    child.name,
                    dir_fd=descriptor,
                    follow_symlinks=False,
                )
                entries_seen += 1
                if entries_seen > MAX_DIRECTORY_ENTRIES:
                    return "directory-entry-count"
                mode = metadata.st_mode
                if stat.S_ISDIR(mode) and not stat.S_ISLNK(mode):
                    child_fd = os.open(
                        child.name,
                        directory_flags,
                        dir_fd=descriptor,
                    )
                    try:
                        opened = os.fstat(child_fd)
                        if (opened.st_dev, opened.st_ino) != (
                            metadata.st_dev,
                            metadata.st_ino,
                        ):
                            return "directory-observability"
                        breach = scan_directory(child_fd)
                        if breach is not None:
                            return breach
                    finally:
                        os.close(child_fd)
                    continue
                if not (stat.S_ISREG(mode) or stat.S_ISLNK(mode)):
                    return "unsupported-filesystem-object"
                logical_bytes += int(metadata.st_size)
                if stat.S_ISREG(mode) and metadata.st_size > MAX_SINGLE_FILE_BYTES:
                    return "single-file"
                if logical_bytes > MAX_DIRECTORY_BYTES:
                    return "directory-total"
        return None

    root_fd = -1
    breach: str | None = None
    try:
        root_fd = os.open(run_root, directory_flags)
        breach = scan_directory(root_fd)
        if breach is None:
            for label, descriptor in (("stdout", stdout_fd), ("stderr", stderr_fd)):
                size = os.fstat(descriptor).st_size
                if size > MAX_CAPTURE_BYTES:
                    breach = f"{label}-capture"
                    break
    except (OSError, ValueError):
        breach = "directory-observability"
    finally:
        if root_fd >= 0:
            try:
                os.close(root_fd)
            except OSError:
                breach = "directory-observability"
    return breach


def _monitor_process(
    process: subprocess.Popen[bytes],
    *,
    deadline: float,
    run_root: str,
    stdout_fd: int,
    stderr_fd: int,
) -> tuple[str, str | None]:
    """Wait for exit while enforcing host-observed aggregate resource quotas."""

    while True:
        breach = _filesystem_breach(
            run_root, stdout_fd=stdout_fd, stderr_fd=stderr_fd
        )
        if breach is not None:
            return "resource", breach
        returncode = process.poll()
        if returncode is None:
            try:
                usage = _process_usage(process.pid)
            except SandboxInfrastructureError:
                return "infra", "memory-observability"
            if usage is None:
                # libproc can stop exposing a process a few milliseconds
                # before waitpid publishes its final status. Give that exit
                # transition a tightly bounded chance to converge; continued
                # unobservability while alive remains an infrastructure fault.
                transition_deadline = min(deadline, time.monotonic() + 0.02)
                while time.monotonic() < transition_deadline:
                    returncode = process.poll()
                    if returncode is not None:
                        break
                    time.sleep(0.001)
                if returncode is None:
                    return "infra", "memory-observability"
            else:
                resident, threads = usage
                if resident > MAX_RESIDENT_BYTES:
                    return "resource", "resident-memory"
                if threads > MAX_THREADS:
                    return "resource", "thread-count"
        if returncode is not None:
            breach = _filesystem_breach(
                run_root, stdout_fd=stdout_fd, stderr_fd=stderr_fd
            )
            return ("resource", breach) if breach is not None else ("exited", None)
        remaining = deadline - time.monotonic()
        if remaining <= 0:
            return "timeout", None
        time.sleep(min(_MONITOR_INTERVAL_SECONDS, remaining))


def _bounded_file_read(stream: BinaryIO, maximum: int) -> bytes:
    stream.seek(0)
    value = stream.read(maximum + 1)
    if not isinstance(value, bytes):
        raise OSError("sandbox capture did not produce bytes")
    return value[:maximum]


def _bounded_append(value: bytes, suffix: bytes, maximum: int) -> bytes:
    suffix = suffix[-maximum:]
    keep = max(0, maximum - len(suffix))
    return value[:keep] + suffix


def _teardown(
    *,
    process: subprocess.Popen[bytes] | None,
    process_reaped: bool,
    descriptors: tuple[int, ...],
    stdout_stream: BinaryIO | None,
    stderr_stream: BinaryIO | None,
    run_root: str | None,
    fork_denied: bool,
) -> tuple[list[tuple[str, BaseException]], bytes, bytes]:
    """Attempt every independent teardown action and return all failures."""

    failures: list[tuple[str, BaseException]] = []
    for index, descriptor in enumerate(descriptors):
        if descriptor < 0:
            continue
        try:
            os.close(descriptor)
        except OSError as error:
            failures.append((f"control fd {index}", error))

    if process is not None:
        # A completed runtime under the exact no-fork policy cannot have a
        # descendant. On macOS, killpg against that already-reaped empty group
        # can spuriously report EPERM. Fork-admitted test profiles still require
        # the stronger group kill even after their leader exits.
        leader_exited_under_no_fork = fork_denied and process.poll() is not None
        if not leader_exited_under_no_fork:
            try:
                _kill_process_group(process)
            except BaseException as error:
                # The leader can cross from running to reaped between the poll
                # and killpg. Under the authenticated no-fork policy that
                # transition also proves that no descendant group remains.
                if fork_denied:
                    # The policy proves there cannot be descendants, so a
                    # direct leader kill is an equivalent fallback when macOS
                    # refuses killpg during sandbox-exec's exit transition.
                    try:
                        process.kill()
                    except ProcessLookupError:
                        pass
                    except BaseException as leader_error:
                        if process.poll() is None:
                            failures.append(
                                ("no-fork sandbox leader termination", leader_error)
                            )
                else:
                    failures.append(("process-group termination", error))
        if not process_reaped:
            try:
                process.communicate(timeout=2)
            except BaseException as error:
                failures.append(("sandbox process reap", error))

    stdout = b""
    stderr = b""
    for label, stream in (("stdout", stdout_stream), ("stderr", stderr_stream)):
        if stream is None:
            continue
        try:
            captured = _bounded_file_read(stream, MAX_CAPTURE_BYTES)
            if label == "stdout":
                stdout = captured
            else:
                stderr = captured
        except BaseException as error:
            failures.append((f"bounded {label} capture", error))
        try:
            stream.close()
        except BaseException as error:
            failures.append((f"{label} capture close", error))

    if run_root is not None:
        try:
            _remove_run_root(run_root)
        except BaseException as error:
            failures.append(("private run-root removal", error))
    return failures, stdout, stderr


def _cleanup_failure(
    failures: list[tuple[str, BaseException]],
    *,
    process: subprocess.Popen[bytes] | None,
    stderr: bytes,
) -> SandboxInfrastructureError:
    actions = ", ".join(label for label, _error in failures)
    return SandboxInfrastructureError(
        f"sandbox teardown could not be proven: {actions}",
        returncode=process.poll() if process is not None else None,
        stderr=stderr,
    )


def _policy_failure(
    command: list[str],
    *,
    code: int,
    stdout: bytes,
    stderr: bytes,
    reason: str,
) -> subprocess.CompletedProcess[bytes]:
    diagnostic = f"\nqinao-sandbox: model policy failure: {reason}\n".encode("ascii")
    return subprocess.CompletedProcess(
        command,
        code,
        stdout[:MAX_CAPTURE_BYTES],
        _bounded_append(stderr, diagnostic, MAX_CAPTURE_BYTES),
    )


def run_sandboxed(
    pybin: str,
    script_path: str,
    timeout: int | float = 15,
    *,
    cpu_seconds: int | float | None = None,
) -> subprocess.CompletedProcess[bytes]:
    """Run generated Python after activation, quotas, and normal-return proof."""

    timeout_value = _validated_timeout(timeout)
    cpu_limit = _validated_cpu_seconds(cpu_seconds, timeout_value)
    limits = _resource_limits(cpu_limit)
    _verify_memory_accounting()
    public_command = ["/usr/bin/sandbox-exec", pybin, script_path]
    source_snapshot, source_policy_failure = _read_source_snapshot(script_path)
    if source_policy_failure is not None:
        return _policy_failure(
            public_command,
            code=RESOURCE_LIMIT_RETURN_CODE,
            stdout=b"",
            stderr=b"",
            reason=source_policy_failure,
        )
    if source_snapshot is None:
        raise SandboxInfrastructureError("generated program snapshot was unavailable")

    run_root: str | None = None
    process: subprocess.Popen[bytes] | None = None
    stdout_stream: BinaryIO | None = None
    stderr_stream: BinaryIO | None = None
    activation_read = activation_write = -1
    completion_read = completion_write = -1
    resource_read = resource_write = -1
    process_reaped = False
    primary_error: SandboxInfrastructureError | None = None
    primary_cause: BaseException | None = None
    state: str | None = None
    resource_reason: str | None = None
    completion_marker = b""
    resource_marker = b""
    fork_denied = False
    deadline = time.monotonic() + timeout_value

    activation_challenge = _challenge(_ACTIVATION_MAGIC)
    completion_challenge = _challenge(_COMPLETION_MAGIC)
    resource_challenge = _challenge(_RESOURCE_MAGIC)

    try:
        try:
            run_root = os.path.realpath(tempfile.mkdtemp(prefix="qinao-sandbox-"))
            os.chmod(run_root, 0o700)
            private_script = os.path.join(run_root, "program.py")
            with open(private_script, "xb") as private_file:
                written = private_file.write(source_snapshot)
                if written != len(source_snapshot):
                    raise OSError("private generated-program snapshot was truncated")
            os.chmod(private_script, 0o600)
            profile_path = os.path.join(run_root, "profile.sb")
            profile = sandbox_profile(run_root)
            fork_denied = "(deny process-fork)" in profile.splitlines()
            with open(profile_path, "x", encoding="utf-8") as profile_file:
                profile_file.write(profile)
            os.chmod(profile_path, 0o600)
            stdout_path = os.path.join(run_root, "stdout.bin")
            stderr_path = os.path.join(run_root, "stderr.bin")
            stdout_stream = open(stdout_path, "x+b", buffering=0)
            stderr_stream = open(stderr_path, "x+b", buffering=0)
            os.chmod(stdout_path, 0o600)
            os.chmod(stderr_path, 0o600)
            activation_read, activation_write = os.pipe()
            completion_read, completion_write = os.pipe()
            resource_read, resource_write = os.pipe()
            for descriptor in (activation_write, completion_write, resource_write):
                os.set_inheritable(descriptor, True)
        except (OSError, TypeError, ValueError) as error:
            raise SandboxInfrastructureError(
                "failed to prepare private sandbox runtime"
            ) from error

        command = [
            "/usr/bin/sandbox-exec",
            "-f",
            profile_path,
            pybin,
            "-I",
            "-c",
            _TRUSTED_LAUNCHER,
            str(activation_write),
            str(completion_write),
            str(resource_write),
            activation_challenge.hex(),
            completion_challenge.hex(),
            resource_challenge.hex(),
            private_script,
            json.dumps(limits, separators=(",", ":")),
        ]
        try:
            process = subprocess.Popen(
                command,
                cwd=run_root,
                env=_minimal_environment(run_root),
                stdin=subprocess.DEVNULL,
                stdout=stdout_stream,
                stderr=stderr_stream,
                pass_fds=(activation_write, completion_write, resource_write),
                start_new_session=True,
            )
        except (OSError, TypeError, ValueError) as error:
            raise SandboxInfrastructureError("failed to launch sandbox runtime") from error

        descriptor = activation_write
        activation_write = -1
        try:
            os.close(descriptor)
        except OSError as error:
            raise SandboxInfrastructureError(
                "failed to close parent activation writer"
            ) from error
        descriptor = completion_write
        completion_write = -1
        try:
            os.close(descriptor)
        except OSError as error:
            raise SandboxInfrastructureError(
                "failed to close parent completion writer"
            ) from error
        descriptor = resource_write
        resource_write = -1
        try:
            os.close(descriptor)
        except OSError as error:
            raise SandboxInfrastructureError(
                "failed to close parent resource writer"
            ) from error

        try:
            marker = _read_activation(activation_read, deadline, activation_challenge)
        except OSError as error:
            raise SandboxInfrastructureError(
                "failed to authenticate sandbox activation",
                returncode=process.poll(),
            ) from error
        descriptor = activation_read
        activation_read = -1
        try:
            os.close(descriptor)
        except OSError as error:
            raise SandboxInfrastructureError(
                "failed to close parent activation reader",
                returncode=process.poll(),
            ) from error
        if marker != activation_challenge:
            raise SandboxInfrastructureError(
                "sandbox activation was not authenticated", returncode=process.poll()
            )

        state, resource_reason = _monitor_process(
            process,
            deadline=deadline,
            run_root=run_root,
            stdout_fd=stdout_stream.fileno(),
            stderr_fd=stderr_stream.fileno(),
        )
        if state == "exited":
            process_reaped = True
            try:
                completion_marker = _read_available(completion_read)
                resource_marker = _read_available(resource_read)
            except OSError as error:
                raise SandboxInfrastructureError(
                    "failed to read sandbox outcome witnesses",
                    returncode=process.poll(),
                ) from error
        elif state == "infra":
            raise SandboxInfrastructureError(
                f"sandbox resource accounting failed: {resource_reason}",
                returncode=process.poll(),
            )
    except SandboxInfrastructureError as error:
        primary_error = error
        primary_cause = error.__cause__
    except Exception as error:
        primary_error = SandboxInfrastructureError(
            "unexpected failure inside sandbox runtime",
            returncode=process.poll() if process is not None else None,
        )
        primary_cause = error
    finally:
        failures, stdout, stderr = _teardown(
            process=process,
            process_reaped=process_reaped,
            descriptors=(
                activation_read,
                activation_write,
                completion_read,
                completion_write,
                resource_read,
                resource_write,
            ),
            stdout_stream=stdout_stream,
            stderr_stream=stderr_stream,
            run_root=run_root,
            fork_denied=fork_denied,
        )

    if failures:
        cleanup_error = _cleanup_failure(failures, process=process, stderr=stderr)
        raise cleanup_error from failures[0][1]
    if primary_error is not None:
        if primary_error.returncode is None and process is not None:
            primary_error.returncode = process.poll()
        if not primary_error.stderr:
            primary_error.stderr = stderr
        if primary_cause is not None:
            raise primary_error from primary_cause
        raise primary_error
    if state == "timeout":
        raise subprocess.TimeoutExpired(
            public_command, timeout, output=stdout, stderr=stderr
        ) from None
    if state == "resource":
        return _policy_failure(
            public_command,
            code=RESOURCE_LIMIT_RETURN_CODE,
            stdout=stdout,
            stderr=stderr,
            reason=f"resource-limit/{resource_reason or 'unknown'}",
        )
    if state != "exited" or process is None or process.returncode is None:
        raise SandboxInfrastructureError("sandbox runtime produced no authenticated result")

    expected_resource_prefix = resource_challenge + b":"
    if resource_marker:
        resource_payload = resource_marker[len(expected_resource_prefix) :]
        allowed_resource_payloads = {b"memory", b"single-file", b"open-files"}
        if (
            not resource_marker.startswith(expected_resource_prefix)
            or resource_payload not in allowed_resource_payloads
        ):
            resource_reason = "resource-witness-tamper"
        else:
            resource_reason = resource_payload.decode("ascii")
        return _policy_failure(
            public_command,
            code=RESOURCE_LIMIT_RETURN_CODE,
            stdout=stdout,
            stderr=stderr,
            reason=f"resource-limit/{resource_reason}",
        )

    signal_reason = {
        -getattr(signal, "SIGXCPU", 10_000): "cpu",
        -getattr(signal, "SIGXFSZ", 10_001): "single-file",
    }.get(process.returncode)
    if signal_reason is not None:
        return _policy_failure(
            public_command,
            code=RESOURCE_LIMIT_RETURN_CODE,
            stdout=stdout,
            stderr=stderr,
            reason=f"resource-limit/{signal_reason}",
        )
    if process.returncode == 0 and completion_marker != completion_challenge:
        return _policy_failure(
            public_command,
            code=INCOMPLETE_RETURN_CODE,
            stdout=stdout,
            stderr=stderr,
            reason="normal-completion-not-witnessed",
        )
    return subprocess.CompletedProcess(
        public_command,
        process.returncode,
        stdout[:MAX_CAPTURE_BYTES],
        stderr[:MAX_CAPTURE_BYTES],
    )
