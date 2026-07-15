"""audit tools-scripts / decision 7 teeth: the StateLake device-prep integrity checks must fail-closed
so they SURVIVE `python -O` (which strips bare `assert`). read_statelake()'s payload-checksum pin and
main()'s CKPT-key sanity previously used bare `assert`, which silently vanishes under -O — a corrupt or
tampered .statelake payload would then rehydrate UNCHECKED (the exact defect class fixed for the b2
freeze-clause pins in commit 13afefed8). A regression to bare `assert` reds this lint. Static, no deps.
Run: uv run --with pytest pytest test_statelake_checksum_survives_optimize.py
"""
import os
import re

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = "mamba3_statelake_device_prep.py"


def test_statelake_integrity_checks_survive_optimize():
    src = open(os.path.join(HERE, SRC)).read()
    # The payload-checksum pin must fail-closed via `raise StateLakeError` (mirroring the binding-key
    # check + the library reader mamba3_statelake.deserialize_artifact), never a bare `assert`.
    assert re.search(r"raise\s+SL\.StateLakeError\(\s*[\"']checksum mismatch", src), (
        f"{SRC}: read_statelake() must `raise SL.StateLakeError` on a checksum mismatch (fail-closed, "
        "survives python -O)")
    # No bare `assert` guarding an integrity/sanity comparison (the checksum blob, or the CKPT-key
    # check) — those are stripped under `python -O` / PYTHONOPTIMIZE.
    offenders = re.findall(
        r"^\s*assert\s+.*(?:sha256|checksum|hexdigest|unexp)\b.*$", src, re.M)
    assert not offenders, (
        f"{SRC}: an integrity/sanity check reverted to a bare `assert` (stripped under python -O): "
        + " | ".join(offenders))
