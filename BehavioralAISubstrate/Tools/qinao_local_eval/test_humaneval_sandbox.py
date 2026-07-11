"""gaps-reconciliation tools-scripts LOW (2026-07-11): teeth for the HumanEval exec seatbelt.
Hostile model-generated code must be DENIED (sensitive read / network / out-of-tempdir write)
while benign check()-style code still scores. Run: python3 -m pytest test_humaneval_sandbox.py"""
import os, sys, tempfile
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from qinao_sandbox import run_sandboxed

PYBIN = sys.executable

def _run(code: str):
    with tempfile.NamedTemporaryFile("w", suffix=".py", delete=False) as f:
        f.write(code); path = f.name
    try:
        return run_sandboxed(PYBIN, path, timeout=15)
    finally:
        os.unlink(path)

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
    r = _run("import tempfile\nwith tempfile.NamedTemporaryFile('w') as f: f.write('ok')\nprint('done')\n")
    assert r.returncode == 0, r.stderr.decode()[:400]

if __name__ == "__main__":   # no-pytest fallback: plain-python runner
    fns = [v for k, v in sorted(globals().items()) if k.startswith("test_") and callable(v)]
    for fn in fns:
        fn(); print(f"PASS {fn.__name__}")
    print(f"{len(fns)}/{len(fns)} sandbox teeth green")
