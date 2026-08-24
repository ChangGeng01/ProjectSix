"""Deny-default macOS Seatbelt runner for model-generated Python."""

from __future__ import annotations

import json
import math
import os
import select
import shutil
import signal
import stat
import subprocess
import tempfile
import time


_ACTIVATION_MAGIC = b"QSB1"
_TRUSTED_LAUNCHER = """\
import os
import runpy
import sys

activation_fd = int(sys.argv[1])
script_path = sys.argv[2]
os.write(activation_fd, b"QSB1")
os.close(activation_fd)
sys.argv = [script_path]
runpy.run_path(script_path, run_name="__main__")
"""


class SandboxInfrastructureError(RuntimeError):
    """The generated program never entered an authenticated sandbox runtime."""

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


def _read_activation(read_fd: int, deadline: float) -> bytes:
    marker = bytearray()
    while len(marker) < len(_ACTIVATION_MAGIC):
        remaining = deadline - time.monotonic()
        if remaining <= 0:
            break
        try:
            readable, _, _ = select.select([read_fd], [], [], remaining)
        except InterruptedError:
            continue
        if not readable:
            break
        chunk = os.read(read_fd, len(_ACTIVATION_MAGIC) - len(marker))
        if not chunk:
            break
        marker.extend(chunk)
    return bytes(marker)


def _kill_process_group(process: subprocess.Popen[bytes]) -> None:
    try:
        os.killpg(process.pid, signal.SIGKILL)
    except ProcessLookupError:
        pass
    except OSError as error:
        raise SandboxInfrastructureError(
            "failed to clean sandbox process group",
            returncode=process.poll(),
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


def _teardown(
    *,
    process: subprocess.Popen[bytes] | None,
    process_reaped: bool,
    read_fd: int,
    write_fd: int,
    run_root: str | None,
) -> tuple[list[tuple[str, BaseException]], bytes, bytes]:
    """Attempt every independent teardown action and return all failures."""

    failures: list[tuple[str, BaseException]] = []
    reaped_stdout = b""
    reaped_stderr = b""

    for label, descriptor in (("activation write fd", write_fd), ("activation read fd", read_fd)):
        if descriptor < 0:
            continue
        try:
            os.close(descriptor)
        except OSError as error:
            failures.append((label, error))

    if process is not None:
        try:
            _kill_process_group(process)
        except BaseException as error:
            failures.append(("process-group termination", error))
        if not process_reaped:
            try:
                reaped_stdout, reaped_stderr = process.communicate(timeout=2)
            except BaseException as error:
                failures.append(("sandbox process reap", error))

    if run_root is not None:
        try:
            _remove_run_root(run_root)
        except BaseException as error:
            failures.append(("private run-root removal", error))

    return failures, reaped_stdout, reaped_stderr


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


def run_sandboxed(
    pybin: str,
    script_path: str,
    timeout: int | float = 15,
) -> subprocess.CompletedProcess[bytes]:
    """Run generated Python only after an out-of-band Seatbelt activation proof."""

    timeout_value = _validated_timeout(timeout)

    run_root: str | None = None
    process: subprocess.Popen[bytes] | None = None
    read_fd = write_fd = -1
    command: list[str] = []
    deadline = time.monotonic() + timeout_value
    process_reaped = False
    result: subprocess.CompletedProcess[bytes] | None = None
    primary_error: SandboxInfrastructureError | None = None
    primary_cause: BaseException | None = None
    model_timed_out = False
    try:
        try:
            run_root = os.path.realpath(tempfile.mkdtemp(prefix="qinao-sandbox-"))
            os.chmod(run_root, 0o700)
            private_script = os.path.join(run_root, "program.py")
            shutil.copyfile(script_path, private_script)
            os.chmod(private_script, 0o600)
            profile_path = os.path.join(run_root, "profile.sb")
            with open(profile_path, "x", encoding="utf-8") as profile_file:
                profile_file.write(sandbox_profile(run_root))
            os.chmod(profile_path, 0o600)
            read_fd, write_fd = os.pipe()
            os.set_inheritable(write_fd, True)
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
            str(write_fd),
            private_script,
        ]
        try:
            process = subprocess.Popen(
                command,
                cwd=run_root,
                env=_minimal_environment(run_root),
                stdin=subprocess.DEVNULL,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                pass_fds=(write_fd,),
                start_new_session=True,
            )
        except (OSError, TypeError, ValueError) as error:
            raise SandboxInfrastructureError("failed to launch sandbox runtime") from error

        descriptor = write_fd
        write_fd = -1
        try:
            os.close(descriptor)
        except OSError as error:
            raise SandboxInfrastructureError(
                "failed to close parent activation writer"
            ) from error

        try:
            marker = _read_activation(read_fd, deadline)
        except OSError as error:
            raise SandboxInfrastructureError(
                "failed to authenticate sandbox activation",
                returncode=process.poll(),
            ) from error

        descriptor = read_fd
        read_fd = -1
        try:
            os.close(descriptor)
        except OSError as error:
            raise SandboxInfrastructureError(
                "failed to close parent activation reader",
                returncode=process.poll(),
            ) from error

        if marker != _ACTIVATION_MAGIC:
            raise SandboxInfrastructureError(
                "sandbox activation was not authenticated",
                returncode=process.poll(),
            )

        remaining = max(0.0, deadline - time.monotonic())
        try:
            stdout, stderr = process.communicate(timeout=remaining)
        except subprocess.TimeoutExpired:
            model_timed_out = True
        else:
            process_reaped = True
            result = subprocess.CompletedProcess(
                command,
                process.returncode,
                stdout,
                stderr,
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
        failures, reaped_stdout, reaped_stderr = _teardown(
            process=process,
            process_reaped=process_reaped,
            read_fd=read_fd,
            write_fd=write_fd,
            run_root=run_root,
        )

    if failures:
        cleanup_error = _cleanup_failure(
            failures,
            process=process,
            stderr=reaped_stderr,
        )
        raise cleanup_error from failures[0][1]
    if primary_error is not None:
        if primary_error.returncode is None and process is not None:
            primary_error.returncode = process.poll()
        if not primary_error.stderr:
            primary_error.stderr = reaped_stderr
        if primary_cause is not None:
            raise primary_error from primary_cause
        raise primary_error
    if model_timed_out:
        raise subprocess.TimeoutExpired(
            command,
            timeout,
            output=reaped_stdout,
            stderr=reaped_stderr,
        ) from None
    if result is None:
        raise SandboxInfrastructureError("sandbox runtime produced no authenticated result")
    return result
