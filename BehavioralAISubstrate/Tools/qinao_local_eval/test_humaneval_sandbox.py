"""Real macOS Seatbelt teeth for the HumanEval generated-code boundary."""
import os
import re
import signal
import subprocess
import sys
import tempfile
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import qinao_sandbox as qs

PYBIN = sys.executable

def _run(code: str, timeout: float = 15):
    with tempfile.NamedTemporaryFile("w", suffix=".py", delete=False) as f:
        f.write(code); path = f.name
    try:
        return qs.run_sandboxed(PYBIN, path, timeout=timeout)
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

def test_sensitive_read_denied():
    home = os.path.expanduser("~")
    r = _run(f"import os\nos.listdir({home + '/Library/Keychains'!r})\n")
    assert r.returncode != 0, "reading Keychains must be denied"
    assert b"PermissionError" in r.stderr or b"Operation not permitted" in r.stderr

def test_network_denied():
    r = _run("import socket\nsocket.create_connection(('1.1.1.1', 80), timeout=3)\n")
    assert r.returncode != 0, "network must be denied"

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


def test_model_can_print_same_error_text_without_forging_infrastructure():
    text = "sandbox-exec: sandbox_apply: Operation not permitted"
    r = _run(f"import sys\nprint({text!r}, file=sys.stderr)\nraise SystemExit(9)\n")
    assert r.returncode == 9
    assert text.encode() in r.stderr


def test_same_macos_temp_root_sibling_write_is_denied():
    with tempfile.TemporaryDirectory(prefix="qinao-sandbox-sibling-") as directory:
        sibling = os.path.realpath(os.path.join(directory, "sibling.txt"))
        r = _run(f"open({sibling!r}, 'w').write('cross-run')\n")
        assert r.returncode != 0, "a run must not write a sibling under the macOS temp root"
        assert not os.path.exists(sibling)


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
                _run(_detached_probe_code(marker, parent_hangs=True), timeout=0.2)
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
                _group_probe_code(parent_hangs=True), timeout=0.2
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
