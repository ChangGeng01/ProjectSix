"""Deny-default macOS Seatbelt runner for model-generated Python."""

from __future__ import annotations

import json
import os
import select
import shutil
import signal
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


def _collect_after_kill(
    process: subprocess.Popen[bytes],
) -> tuple[bytes, bytes]:
    _kill_process_group(process)
    try:
        return process.communicate(timeout=2)
    except subprocess.TimeoutExpired as error:
        raise SandboxInfrastructureError(
            "sandbox process group did not terminate",
            returncode=process.poll(),
            stderr=error.stderr or b"",
        ) from error


def run_sandboxed(
    pybin: str,
    script_path: str,
    timeout: int | float = 15,
) -> subprocess.CompletedProcess[bytes]:
    """Run generated Python only after an out-of-band Seatbelt activation proof."""

    if isinstance(timeout, bool) or not isinstance(timeout, (int, float)) or timeout <= 0:
        raise SandboxInfrastructureError("sandbox timeout must be a positive number")

    run_root: str | None = None
    process: subprocess.Popen[bytes] | None = None
    read_fd = write_fd = -1
    command: list[str] = []
    deadline = time.monotonic() + float(timeout)
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
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                pass_fds=(write_fd,),
                start_new_session=True,
            )
        except (OSError, TypeError, ValueError) as error:
            raise SandboxInfrastructureError("failed to launch sandbox runtime") from error
        finally:
            if write_fd >= 0:
                os.close(write_fd)
                write_fd = -1

        try:
            marker = _read_activation(read_fd, deadline)
        except OSError as error:
            _stdout, stderr = _collect_after_kill(process)
            raise SandboxInfrastructureError(
                "failed to authenticate sandbox activation",
                returncode=process.returncode,
                stderr=stderr,
            ) from error
        finally:
            if read_fd >= 0:
                os.close(read_fd)
                read_fd = -1

        if marker != _ACTIVATION_MAGIC:
            _stdout, stderr = _collect_after_kill(process)
            raise SandboxInfrastructureError(
                "sandbox activation was not authenticated",
                returncode=process.returncode,
                stderr=stderr,
            )

        remaining = max(0.0, deadline - time.monotonic())
        try:
            stdout, stderr = process.communicate(timeout=remaining)
        except subprocess.TimeoutExpired:
            stdout, stderr = _collect_after_kill(process)
            raise subprocess.TimeoutExpired(
                command,
                timeout,
                output=stdout,
                stderr=stderr,
            ) from None

        _kill_process_group(process)
        return subprocess.CompletedProcess(
            command,
            process.returncode,
            stdout,
            stderr,
        )
    finally:
        if write_fd >= 0:
            os.close(write_fd)
        if read_fd >= 0:
            os.close(read_fd)
        if process is not None:
            try:
                _kill_process_group(process)
            except SandboxInfrastructureError:
                if process.poll() is None:
                    raise
        if run_root is not None:
            shutil.rmtree(run_root, ignore_errors=True)
