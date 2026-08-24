"""Real macOS Seatbelt teeth for the HumanEval generated-code boundary."""
import errno
import os
import re
import signal
import shutil
import socket
import subprocess
import sys
import tempfile
import time
from pathlib import Path
from unittest import mock

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import qinao_sandbox as qs

PYBIN = sys.executable
MODEL_TIMEOUT_PROBE_SECONDS = 1.0

def _run(code: str, timeout: float = 15, *, cpu_seconds=None):
    with tempfile.NamedTemporaryFile("w", suffix=".py", delete=False) as f:
        f.write(code); path = f.name
    try:
        return qs.run_sandboxed(
            PYBIN, path, timeout=timeout, cpu_seconds=cpu_seconds
        )
    finally:
        os.unlink(path)


def _as_bytes(value):
    if value is None:
        return b""
    return value if isinstance(value, bytes) else value.encode()


def _child_pid(output):
    match = re.search(rb"CHILD_PID=(\d+)", _as_bytes(output))
    return int(match.group(1)) if match else None


def _pid_exists(pid):
    if pid is None:
        return False
    try:
        os.kill(pid, 0)
    except ProcessLookupError:
        return False
    except PermissionError:
        return True
    return True


def _kill_probe(pid):
    if pid is None:
        return
    try:
        os.kill(pid, signal.SIGKILL)
    except ProcessLookupError:
        pass


def _expect_typed_infrastructure(call):
    try:
        call()
    except qs.SandboxInfrastructureError:
        return
    except BaseException as error:
        raise AssertionError(
            f"expected SandboxInfrastructureError, got {type(error).__name__}: {error}"
        ) from error
    raise AssertionError("expected SandboxInfrastructureError")


def _assert_bounded_policy_failure(result, reason):
    assert isinstance(result, subprocess.CompletedProcess), result
    assert result.returncode == qs.RESOURCE_LIMIT_RETURN_CODE, result
    assert f"resource-limit/{reason}".encode() in result.stderr, result.stderr[-400:]
    assert len(result.stdout) <= qs.MAX_CAPTURE_BYTES
    assert len(result.stderr) <= qs.MAX_CAPTURE_BYTES


def _run_recording_private_root(code, timeout=5, *, cpu_seconds=None):
    roots = []
    real_mkdtemp = tempfile.mkdtemp

    def recording_mkdtemp(*args, **kwargs):
        root = real_mkdtemp(*args, **kwargs)
        roots.append(root)
        return root

    with mock.patch.object(qs.tempfile, "mkdtemp", side_effect=recording_mkdtemp):
        result = _run(code, timeout=timeout, cpu_seconds=cpu_seconds)
    assert roots, "sandbox never allocated its private root"
    assert all(not os.path.lexists(root) for root in roots), roots
    return result


class _FakeProcess:
    def __init__(self):
        self.pid = 987654321
        self.returncode = None
        self.communicate_calls = 0

    def communicate(self, timeout=None):
        self.communicate_calls += 1
        self.returncode = 0
        return b"model-stdout", b"model-stderr"

    def poll(self):
        return self.returncode


def _fake_runtime_probe(*, close_failure=None, activation_error=None, remove_error=False):
    roots = []
    pipes = []
    close_counts = {}
    kill_calls = []
    popen_kwargs = []
    remove_calls = []
    process = _FakeProcess()
    real_mkdtemp = tempfile.mkdtemp
    real_pipe = os.pipe
    real_close = os.close
    real_rmtree = shutil.rmtree

    def recording_mkdtemp(*args, **kwargs):
        root = real_mkdtemp(*args, **kwargs)
        roots.append(root)
        return root

    def recording_pipe():
        descriptors = real_pipe()
        pipes.append(descriptors)
        return descriptors

    def injected_close(descriptor):
        close_counts[descriptor] = close_counts.get(descriptor, 0) + 1
        target = None
        if pipes and close_failure in ("read", "write"):
            target = pipes[0][1 if close_failure == "write" else 0]
        if descriptor == target and close_counts[descriptor] == 1:
            real_close(descriptor)
            raise OSError(errno.EIO, f"simulated {close_failure}-fd close failure")
        return real_close(descriptor)

    def fake_popen(*args, **kwargs):
        popen_kwargs.append(kwargs)
        return process

    def fake_kill(candidate):
        kill_calls.append(candidate)

    def fake_activation(*_args):
        if activation_error is not None:
            raise activation_error
        return qs._ACTIVATION_MAGIC

    def injected_rmtree(path, *args, **kwargs):
        remove_calls.append((path, kwargs))
        if remove_error:
            if kwargs.get("ignore_errors"):
                return None
            raise OSError(errno.EIO, "simulated final removal failure")
        # Keep shutil's private directory descriptors out of the activation-FD
        # close accounting; descriptor numbers may be legitimately reused.
        with mock.patch.object(qs.os, "close", real_close):
            return real_rmtree(path, *args, **kwargs)

    source = tempfile.NamedTemporaryFile("w", suffix=".py", delete=False)
    source.write("print('model')\n")
    source.close()
    patches = (
        mock.patch.object(qs.tempfile, "mkdtemp", side_effect=recording_mkdtemp),
        mock.patch.object(qs.os, "pipe", side_effect=recording_pipe),
        mock.patch.object(qs.os, "close", side_effect=injected_close),
        mock.patch.object(qs.subprocess, "Popen", side_effect=fake_popen),
        mock.patch.object(qs, "_kill_process_group", side_effect=fake_kill),
        mock.patch.object(qs, "_read_activation", side_effect=fake_activation),
        mock.patch.object(qs.shutil, "rmtree", side_effect=injected_rmtree),
    )
    try:
        with patches[0], patches[1], patches[2], patches[3], patches[4], patches[5], patches[6]:
            outcome = None
            caught = None
            try:
                outcome = qs.run_sandboxed(PYBIN, source.name)
            except BaseException as error:
                caught = error
        return {
            "caught": caught,
            "outcome": outcome,
            "roots": roots,
            "pipes": pipes,
            "close_counts": close_counts,
            "kill_calls": kill_calls,
            "popen_kwargs": popen_kwargs,
            "remove_calls": remove_calls,
            "process": process,
        }
    finally:
        os.unlink(source.name)
        for descriptors in pipes:
            for descriptor in descriptors:
                if descriptor in close_counts:
                    continue
                try:
                    real_close(descriptor)
                except OSError:
                    pass
        for root in roots:
            if os.path.lexists(root):
                real_rmtree(root, ignore_errors=True)


def _assert_total_teardown_after_close_failure(failing_end):
    probe = _fake_runtime_probe(close_failure=failing_end)
    caught = probe["caught"]
    assert isinstance(caught, qs.SandboxInfrastructureError), caught
    read_fd, write_fd = probe["pipes"][0]
    failing_fd = write_fd if failing_end == "write" else read_fd
    assert probe["close_counts"][failing_fd] == 1, "ambiguous close was retried"
    for descriptors in probe["pipes"]:
        for descriptor in descriptors:
            assert probe["close_counts"][descriptor] == 1, (
                "a remaining control descriptor was not closed",
                descriptors,
                probe["close_counts"],
            )
    assert probe["kill_calls"] == [probe["process"]]
    assert probe["process"].communicate_calls == 1, "launched process was not reaped"
    assert probe["remove_calls"], "private root removal was not attempted"
    assert all(not os.path.lexists(root) for root in probe["roots"])


def _force_remove_tree(path):
    if not path or not os.path.lexists(path):
        return
    if os.path.islink(path):
        os.unlink(path)
        return
    try:
        os.chmod(path, 0o700)
    except OSError:
        pass
    for directory, names, _files in os.walk(path, topdown=True, followlinks=False):
        for name in names:
            candidate = os.path.join(directory, name)
            if not os.path.islink(candidate):
                try:
                    os.chmod(candidate, 0o700)
                except OSError:
                    pass
    shutil.rmtree(path, ignore_errors=True)


def _permission_sabotage_code(external_directory, *, exit_code=None, hangs=False):
    return (
        "import os, sys, time\n"
        "root = os.environ['TMPDIR']\n"
        "nested = os.path.join(root, 'locked', 'deeper')\n"
        "os.makedirs(nested)\n"
        f"os.symlink({external_directory!r}, os.path.join(root, 'outside-link'))\n"
        "print(f'RUN_ROOT={root}', flush=True)\n"
        "os.chmod(nested, 0)\n"
        "os.chmod(os.path.dirname(nested), 0)\n"
        "os.chmod(root, 0)\n"
        + ("time.sleep(10)\n" if hangs else "")
        + (f"raise SystemExit({exit_code})\n" if exit_code is not None else "")
    )


def _assert_permission_sabotaged_root_removed(*, exit_code=None, hangs=False):
    run_root = None
    with tempfile.TemporaryDirectory(prefix="qinao-cleanup-outside-") as outside:
        sentinel = Path(outside) / "must-survive"
        sentinel.write_text("outside", encoding="utf-8")
        try:
            code = _permission_sabotage_code(
                os.path.realpath(outside), exit_code=exit_code, hangs=hangs
            )
            result = _run(
                code,
                timeout=MODEL_TIMEOUT_PROBE_SECONDS if hangs else 15,
            )
            _assert_bounded_policy_failure(result, "directory-observability")
            output = result.stdout
            match = re.search(rb"RUN_ROOT=([^\r\n]+)", output)
            assert match, output
            run_root = match.group(1).decode()
            assert not os.path.lexists(run_root), "permission-sabotaged root leaked"
            assert sentinel.read_text(encoding="utf-8") == "outside"
        finally:
            _force_remove_tree(run_root)


def _detached_probe_code(marker, *, parent_hangs):
    child = (
        "import time; "
        "time.sleep(0.35); "
        f"open({marker!r}, 'w').write('escaped'); "
        "time.sleep(5)"
    )
    return (
        "import subprocess, sys, time\n"
        "try:\n"
        f"    p = subprocess.Popen([sys.executable, '-c', {child!r}], "
        "start_new_session=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)\n"
        "    print(f'CHILD_PID={p.pid}', flush=True)\n"
        "except OSError:\n"
        "    print('CHILD_DENIED', flush=True)\n"
        + ("time.sleep(10)\n" if parent_hangs else "")
    )


def _group_probe_code(*, parent_hangs):
    return (
        "import subprocess, sys, time\n"
        "p = subprocess.Popen([sys.executable, '-c', 'import time; time.sleep(5)'], "
        "stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)\n"
        "print(f'CHILD_PID={p.pid}', flush=True)\n"
        + ("time.sleep(10)\n" if parent_hangs else "")
    )

def test_benign_check_scores():
    r = _run("def add(a,b):\n    return a+b\nassert add(2,2)==4\n")
    assert r.returncode == 0, r.stderr.decode()[:400]


def test_normal_runpy_return_has_authenticated_completion_witness():
    r = _run("print('normal-return')\n")
    assert r.returncode == 0, r.stderr.decode()[:400]
    assert r.stdout == b"normal-return\n"


def test_system_exit_zero_cannot_masquerade_as_normal_completion():
    r = _run("raise SystemExit(0)\n")
    assert r.returncode != 0, "activation is not a normal-completion witness"


def test_os_exit_zero_cannot_masquerade_as_normal_completion():
    r = _run("import os\nos._exit(0)\n")
    assert r.returncode != 0, "a zero process status is not a normal-completion witness"


def test_stdout_flood_is_a_bounded_model_policy_failure_with_total_teardown():
    result = _run_recording_private_root(
        "import os\n"
        "chunk = b'x' * 16384\n"
        "while True:\n"
        "    os.write(1, chunk)\n"
    )
    _assert_bounded_policy_failure(result, "stdout-capture")


def test_stderr_flood_is_a_bounded_model_policy_failure_with_total_teardown():
    result = _run_recording_private_root(
        "import os\n"
        "chunk = b'e' * 16384\n"
        "while True:\n"
        "    os.write(2, chunk)\n"
    )
    _assert_bounded_policy_failure(result, "stderr-capture")


def test_cpu_flood_hits_kernel_limit_before_wall_timeout():
    started = time.monotonic()
    result = _run_recording_private_root(
        "while True:\n    pass\n", timeout=5, cpu_seconds=1
    )
    elapsed = time.monotonic() - started
    _assert_bounded_policy_failure(result, "cpu")
    assert elapsed < 4, f"CPU quota was not independently enforced: {elapsed:.2f}s"


def test_handled_sigxcpu_is_cpu_policy_failure_not_success():
    result = _run_recording_private_root(
        "import signal\n"
        "limit_reached = False\n"
        "def handle_limit(*_):\n"
        "    global limit_reached\n"
        "    limit_reached = True\n"
        "signal.signal(signal.SIGXCPU, handle_limit)\n"
        "while not limit_reached:\n"
        "    pass\n",
        timeout=5,
        cpu_seconds=1,
    )
    _assert_bounded_policy_failure(result, "cpu")


def test_ignored_sigxcpu_is_cpu_policy_failure_not_wall_timeout():
    started = time.monotonic()
    try:
        result = _run_recording_private_root(
            "import signal\n"
            "signal.signal(signal.SIGXCPU, signal.SIG_IGN)\n"
            "while True:\n"
            "    pass\n",
            timeout=3,
            cpu_seconds=1,
        )
    except subprocess.TimeoutExpired as error:
        raise AssertionError(
            "the host CPU quota must win before the independent wall timeout"
        ) from error
    elapsed = time.monotonic() - started
    _assert_bounded_policy_failure(result, "cpu")
    assert elapsed < 2.5, f"CPU quota was not independently enforced: {elapsed:.2f}s"


def test_resident_memory_flood_is_terminated_before_host_damage():
    result = _run_recording_private_root(
        "blocks = []\n"
        "while True:\n"
        "    blocks.append(bytearray(8 * 1024 * 1024))\n"
    )
    _assert_bounded_policy_failure(result, "resident-memory")


def test_thread_flood_is_terminated_by_observed_thread_quota():
    result = _run_recording_private_root(
        "import threading\n"
        "gate = threading.Event()\n"
        "threads = []\n"
        f"for _ in range({qs.MAX_THREADS + 16}):\n"
        "    thread = threading.Thread(target=gate.wait, daemon=True)\n"
        "    thread.start()\n"
        "    threads.append(thread)\n"
        "gate.wait()\n"
    )
    _assert_bounded_policy_failure(result, "thread-count")


def test_single_file_limit_is_a_bounded_model_policy_failure():
    result = _run_recording_private_root(
        "import os\n"
        "path = os.path.join(os.environ['TMPDIR'], 'oversized')\n"
        "with open(path, 'wb') as stream:\n"
        f"    stream.write(b'x' * ({qs.MAX_SINGLE_FILE_BYTES} + 4096))\n"
    )
    _assert_bounded_policy_failure(result, "single-file")


def test_directory_total_limit_is_a_bounded_model_policy_failure():
    each = qs.MAX_SINGLE_FILE_BYTES - 32768
    count = (qs.MAX_DIRECTORY_BYTES // each) + 1
    result = _run_recording_private_root(
        "import os\n"
        f"payload = b'x' * {each}\n"
        f"for index in range({count}):\n"
        "    with open(os.path.join(os.environ['TMPDIR'], f'part-{index}'), 'wb') as stream:\n"
        "        stream.write(payload)\n"
    )
    _assert_bounded_policy_failure(result, "directory-total")


def test_directory_entry_limit_is_a_bounded_model_policy_failure():
    result = _run_recording_private_root(
        "import os\n"
        f"for index in range({qs.MAX_DIRECTORY_ENTRIES + 8}):\n"
        "    open(os.path.join(os.environ['TMPDIR'], f'entry-{index}'), 'wb').close()\n"
    )
    _assert_bounded_policy_failure(result, "directory-entry-count")


def test_open_file_limit_is_kernel_enforced_and_reported():
    result = _run_recording_private_root(
        "import os\n"
        "handles = []\n"
        f"for index in range({qs.MAX_OPEN_FILES + 16}):\n"
        "    handles.append(open(os.path.join(os.environ['TMPDIR'], f'open-{index}'), 'wb'))\n"
    )
    _assert_bounded_policy_failure(result, "open-files")

def test_sensitive_read_denied():
    home = os.path.expanduser("~")
    r = _run(f"import os\nos.listdir({home + '/Library/Keychains'!r})\n")
    assert r.returncode != 0, "reading Keychains must be denied"
    assert b"PermissionError" in r.stderr or b"Operation not permitted" in r.stderr

def test_network_denied():
    listener = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    listener.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    listener.bind(("127.0.0.1", 0))
    listener.listen(1)
    listener.settimeout(0.2)
    port = listener.getsockname()[1]
    try:
        r = _run(
            "import socket\n"
            f"socket.create_connection(('127.0.0.1', {port}), timeout=1)\n"
        )
        assert r.returncode != 0, "loopback networking must be denied"
        try:
            connection, _address = listener.accept()
        except TimeoutError:
            pass
        else:
            connection.close()
            raise AssertionError("sandbox connected to the deterministic loopback listener")
    finally:
        listener.close()

def test_out_of_tempdir_write_denied():
    home = os.path.expanduser("~")
    r = _run(f"open({home + '/qinao_sandbox_probe.txt'!r}, 'w').write('x')\n")
    assert r.returncode != 0, "writing outside the tempdir must be denied"
    assert not os.path.exists(home + "/qinao_sandbox_probe.txt")

def test_tempdir_write_allowed():
    r = _run("import os, tempfile\nassert os.path.realpath(tempfile.gettempdir()) == os.path.realpath(os.environ['TMPDIR'])\nwith tempfile.NamedTemporaryFile('w') as f: f.write('ok')\nprint('done')\n")
    assert r.returncode == 0, r.stderr.decode()[:400]


def test_profile_activation_failure_is_typed_infrastructure():
    original = qs.sandbox_profile
    expect_nested_refusal = os.environ.get("QINAO_EXPECT_NESTED_REFUSAL") == "1"
    if not expect_nested_refusal:
        qs.sandbox_profile = lambda _root: "(version 1)\n(not-a-seatbelt-rule)\n"
    try:
        try:
            _run("print('must never execute')\n")
        except qs.SandboxInfrastructureError:
            pass
        else:
            raise AssertionError("a missing activation marker must be typed infrastructure")
    finally:
        qs.sandbox_profile = original


def test_write_fd_close_failure_still_performs_total_teardown():
    _assert_total_teardown_after_close_failure("write")


def test_read_fd_close_failure_still_performs_total_teardown():
    _assert_total_teardown_after_close_failure("read")


def test_after_launch_internal_exception_is_typed_and_totally_cleaned():
    probe = _fake_runtime_probe(
        activation_error=RuntimeError("simulated unexpected activation failure")
    )
    assert isinstance(probe["caught"], qs.SandboxInfrastructureError), probe["caught"]
    assert probe["kill_calls"] == [probe["process"]]
    assert probe["process"].communicate_calls == 1
    assert probe["remove_calls"]
    assert all(not os.path.lexists(root) for root in probe["roots"])


def test_final_directory_removal_failure_is_typed_infrastructure():
    probe = _fake_runtime_probe(remove_error=True)
    assert isinstance(probe["caught"], qs.SandboxInfrastructureError), (
        "a failed final root removal must replace any apparent model result",
        probe["caught"],
        probe["outcome"],
    )
    assert probe["remove_calls"]


def _assert_timeout_rejected_before_resources(value):
    source = tempfile.NamedTemporaryFile("w", suffix=".py", delete=False)
    source.write("print('must not run')\n")
    source.close()
    mkdtemp = mock.Mock(side_effect=AssertionError("mkdtemp called"))
    pipe = mock.Mock(side_effect=AssertionError("pipe called"))
    popen = mock.Mock(side_effect=AssertionError("Popen called"))
    try:
        with (
            mock.patch.object(qs.tempfile, "mkdtemp", mkdtemp),
            mock.patch.object(qs.os, "pipe", pipe),
            mock.patch.object(qs.subprocess, "Popen", popen),
        ):
            _expect_typed_infrastructure(
                lambda: qs.run_sandboxed(PYBIN, source.name, timeout=value)
            )
    finally:
        os.unlink(source.name)
    assert mkdtemp.call_count == 0
    assert pipe.call_count == 0
    assert popen.call_count == 0


def test_nan_timeout_rejected_before_resources():
    _assert_timeout_rejected_before_resources(float("nan"))


def test_positive_infinite_timeout_rejected_before_resources():
    _assert_timeout_rejected_before_resources(float("inf"))


def test_negative_infinite_timeout_rejected_before_resources():
    _assert_timeout_rejected_before_resources(float("-inf"))


def test_float_overflowing_integer_timeout_rejected_before_resources():
    _assert_timeout_rejected_before_resources(10**400)


def test_symlink_program_is_rejected_before_private_resources():
    with tempfile.TemporaryDirectory(prefix="qinao-source-link-") as directory:
        source = Path(directory) / "source.py"
        link = Path(directory) / "link.py"
        source.write_text("print('must-not-run')\n", encoding="utf-8")
        link.symlink_to(source)
        mkdtemp = mock.Mock(side_effect=AssertionError("mkdtemp called"))
        with mock.patch.object(qs.tempfile, "mkdtemp", mkdtemp):
            _expect_typed_infrastructure(
                lambda: qs.run_sandboxed(PYBIN, os.fspath(link))
            )
        assert mkdtemp.call_count == 0


def test_in_place_source_mutation_during_snapshot_fails_closed_before_launch():
    source = tempfile.NamedTemporaryFile("w", suffix=".py", delete=False)
    source.write("#" * (qs._SOURCE_READ_CHUNK + 1024))
    source.close()
    real_read = os.read
    mutated = False

    def mutate_after_first_read(descriptor, size):
        nonlocal mutated
        chunk = real_read(descriptor, size)
        if not mutated:
            mutated = True
            with open(source.name, "a", encoding="utf-8") as stream:
                stream.write("# changed while snapshotting\n")
        return chunk

    mkdtemp = mock.Mock(side_effect=AssertionError("mkdtemp called"))
    try:
        with (
            mock.patch.object(qs.os, "read", side_effect=mutate_after_first_read),
            mock.patch.object(qs.tempfile, "mkdtemp", mkdtemp),
        ):
            _expect_typed_infrastructure(
                lambda: qs.run_sandboxed(PYBIN, source.name)
            )
    finally:
        os.unlink(source.name)
    assert mutated
    assert mkdtemp.call_count == 0


def test_path_replacement_after_secure_open_cannot_change_executed_snapshot():
    with tempfile.TemporaryDirectory(prefix="qinao-source-swap-") as directory:
        source = os.path.join(directory, "source.py")
        replacement = os.path.join(directory, "replacement.py")
        Path(source).write_text("print('opened-original')\n", encoding="utf-8")
        Path(replacement).write_text("raise SystemExit(0)\n", encoding="utf-8")
        real_open = os.open
        swapped = False

        def open_then_swap(path, flags, mode=0o777, *, dir_fd=None):
            nonlocal swapped
            if dir_fd is None:
                descriptor = real_open(path, flags, mode)
            else:
                descriptor = real_open(path, flags, mode, dir_fd=dir_fd)
            if os.fspath(path) == source and not swapped:
                os.replace(replacement, source)
                swapped = True
            return descriptor

        with mock.patch.object(qs.os, "open", side_effect=open_then_swap):
            result = qs.run_sandboxed(PYBIN, source)
        assert swapped
        assert result.returncode == 0, result.stderr.decode(errors="replace")[:400]
        assert result.stdout == b"opened-original\n"


def test_unavailable_memory_accounting_fails_closed_before_private_resources():
    mkdtemp = mock.Mock(side_effect=AssertionError("mkdtemp called"))
    source = tempfile.NamedTemporaryFile("w", suffix=".py", delete=False)
    source.write("print('must-not-run')\n")
    source.close()
    try:
        with (
            mock.patch.object(qs, "_process_usage", return_value=None),
            mock.patch.object(qs.tempfile, "mkdtemp", mkdtemp),
        ):
            _expect_typed_infrastructure(
                lambda: qs.run_sandboxed(PYBIN, source.name)
            )
    finally:
        os.unlink(source.name)
    assert mkdtemp.call_count == 0


def test_model_can_print_same_error_text_without_forging_infrastructure():
    text = "sandbox-exec: sandbox_apply: Operation not permitted"
    r = _run(f"import sys\nprint({text!r}, file=sys.stderr)\nraise SystemExit(9)\n")
    assert r.returncode == 9
    assert text.encode() in r.stderr


def test_model_stdin_is_devnull_and_caller_sentinel_remains():
    saved_stdin = os.dup(0)
    read_fd, write_fd = os.pipe()
    os.write(write_fd, b"S")
    os.close(write_fd)
    try:
        os.dup2(read_fd, 0)
        os.close(read_fd)
        result = _run(
            "import sys\n"
            "data = sys.stdin.buffer.read(1)\n"
            "print('MODEL_STDIN=' + data.hex())\n"
        )
        caller_sentinel = os.read(0, 1)
    finally:
        os.dup2(saved_stdin, 0)
        os.close(saved_stdin)
    assert result.returncode == 0, result.stderr.decode()[:400]
    assert b"MODEL_STDIN=\n" in result.stdout
    assert caller_sentinel == b"S"


def test_same_macos_temp_root_sibling_write_is_denied():
    with tempfile.TemporaryDirectory(prefix="qinao-sandbox-sibling-") as directory:
        sibling = os.path.realpath(os.path.join(directory, "sibling.txt"))
        r = _run(f"open({sibling!r}, 'w').write('cross-run')\n")
        assert r.returncode != 0, "a run must not write a sibling under the macOS temp root"
        assert not os.path.exists(sibling)


def test_quota_scanner_never_follows_generated_symlink():
    with (
        tempfile.TemporaryDirectory(prefix="qinao-quota-root-") as run_root,
        tempfile.TemporaryDirectory(prefix="qinao-quota-outside-") as outside,
    ):
        for index in range(qs.MAX_DIRECTORY_ENTRIES + 8):
            Path(outside, f"outside-{index}").touch()
        os.symlink(outside, os.path.join(run_root, "outside-link"))
        stdout_path = os.path.join(run_root, "stdout.bin")
        stderr_path = os.path.join(run_root, "stderr.bin")
        with open(stdout_path, "x+b", buffering=0) as stdout, open(
            stderr_path, "x+b", buffering=0
        ) as stderr:
            breach = qs._filesystem_breach(
                run_root,
                stdout_fd=stdout.fileno(),
                stderr_fd=stderr.fileno(),
            )
        assert breach is None, "scanner followed a symlink outside its private root"


def test_permission_sabotaged_root_removed_after_success():
    _assert_permission_sabotaged_root_removed()


def test_permission_sabotaged_root_removed_after_nonzero_exit():
    _assert_permission_sabotaged_root_removed(exit_code=7)


def test_permission_sabotaged_root_removed_after_timeout():
    _assert_permission_sabotaged_root_removed(hangs=True)


def test_detached_child_absent_after_normal_return():
    with tempfile.TemporaryDirectory(prefix="qinao-detached-normal-") as directory:
        marker = os.path.realpath(os.path.join(directory, "delayed-marker"))
        pid = None
        try:
            result = _run(_detached_probe_code(marker, parent_hangs=False))
            assert result.returncode == 0, result.stderr.decode()[:400]
            pid = _child_pid(result.stdout)
            time.sleep(0.7)
            assert not os.path.exists(marker), "detached child survived normal return"
            assert not _pid_exists(pid), f"detached child PID {pid} survived normal return"
        finally:
            _kill_probe(pid)


def test_detached_child_absent_after_timeout():
    with tempfile.TemporaryDirectory(prefix="qinao-detached-timeout-") as directory:
        marker = os.path.realpath(os.path.join(directory, "delayed-marker"))
        pid = None
        try:
            try:
                _run(
                    _detached_probe_code(marker, parent_hangs=True),
                    timeout=MODEL_TIMEOUT_PROBE_SECONDS,
                )
            except subprocess.TimeoutExpired as error:
                pid = _child_pid(error.output)
            else:
                raise AssertionError("the activated model program must preserve TimeoutExpired")
            time.sleep(0.7)
            assert not os.path.exists(marker), "detached child survived timeout"
            assert not _pid_exists(pid), f"detached child PID {pid} survived timeout"
        finally:
            _kill_probe(pid)


def _run_with_fork_temporarily_admitted(code, timeout):
    original = qs.sandbox_profile

    def fork_admitted(root):
        return original(root).replace("(deny process-fork)\n", "")

    qs.sandbox_profile = fork_admitted
    try:
        return _run(code, timeout=timeout)
    finally:
        qs.sandbox_profile = original


def test_process_group_cleanup_after_normal_return():
    pid = None
    try:
        result = _run_with_fork_temporarily_admitted(
            _group_probe_code(parent_hangs=False), timeout=2
        )
        assert result.returncode == 0, result.stderr.decode()[:400]
        pid = _child_pid(result.stdout)
        time.sleep(0.2)
        assert pid is not None and not _pid_exists(pid), "same-session child was not reaped"
    finally:
        _kill_probe(pid)


def test_process_group_cleanup_after_timeout():
    pid = None
    try:
        try:
            _run_with_fork_temporarily_admitted(
                _group_probe_code(parent_hangs=True),
                timeout=MODEL_TIMEOUT_PROBE_SECONDS,
            )
        except subprocess.TimeoutExpired as error:
            pid = _child_pid(error.output)
        else:
            raise AssertionError("the model program must time out")
        time.sleep(0.2)
        assert pid is not None and not _pid_exists(pid), "timeout left a same-session child alive"
    finally:
        _kill_probe(pid)

if __name__ == "__main__":   # no-pytest fallback: plain-python runner
    fns = [v for k, v in sorted(globals().items()) if k.startswith("test_") and callable(v)]
    for fn in fns:
        fn(); print(f"PASS {fn.__name__}")
    print(f"{len(fns)}/{len(fns)} sandbox teeth green")
