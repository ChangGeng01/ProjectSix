"""gaps-reconciliation tools-scripts LOW (2026-07-11): macOS seatbelt for executing
model-generated code (the "real sandbox" follow-up to decision 7's -I isolation).
Deny-default: read-only fs EXCEPT sensitive dirs (ssh/aws/keychains denied even for read),
writes confined to the tempdir, network denied outright. Single source of truth — used by
qinao_humaneval.py (and any future harness that runs untrusted generated code)."""
import os, subprocess, tempfile


def sandbox_profile(tmpdir: str) -> str:
    home = os.path.expanduser("~")
    return f"""(version 1)
(deny default)
(allow process*)
(allow sysctl-read)
(allow mach-lookup)
(allow file-read*)
(deny file-read* (subpath "{home}/.ssh") (subpath "{home}/.aws") (subpath "{home}/Library/Keychains"))
(allow file-write* (subpath "{tmpdir}") (subpath "/private/var/folders") (literal "/dev/null"))
(deny network*)
"""


def run_sandboxed(pybin: str, script_path: str, timeout: int = 15):
    """Execute a model-generated script inside the seatbelt. Returns CompletedProcess."""
    with tempfile.NamedTemporaryFile("w", suffix=".sb", delete=False) as sb:
        sb.write(sandbox_profile(os.path.dirname(script_path) or tempfile.gettempdir()))
        sb_path = sb.name
    try:
        return subprocess.run(
            ["/usr/bin/sandbox-exec", "-f", sb_path, pybin, "-I", script_path],
            capture_output=True, timeout=timeout)
    finally:
        try:
            os.unlink(sb_path)
        except OSError:
            pass
