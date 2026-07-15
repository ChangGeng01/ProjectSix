"""x-test-integrity F6 teeth: qinao_device's NAMED metric keys must be translated
to the registry NUMBERS build_verdict looks up, else the device gates stay
PENDING forever. Pure Python, no model/device. Run:
    uv run --with pytest pytest test_device_key_translation.py
"""
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
import qinao_device as qd  # noqa: E402
import build_verdict as bv  # noqa: E402


def test_named_device_metrics_get_numeric_keys():
    out = qd.to_numeric_device_keys({
        "decode_tok_s": 42.0, "ttft_ms": 100.0, "prefill_tok_s": 900.0,
        "peak_ram_mb": 6000.0, "thermal_drift_pct": 12.0,
        "turn_p50_ms": 50.0,  # unmapped diagnostic
    })
    assert out["65"] == 42.0
    assert out["66"] == 100.0
    assert out["67"] == 900.0
    assert out["68"] == 6000.0
    assert out["71"] == 12.0
    # named diagnostics preserved; unmapped stays named-only
    assert out["decode_tok_s"] == 42.0
    assert out["turn_p50_ms"] == 50.0
    assert not any(k.isdigit() and k not in {"65", "66", "67", "68", "71"} for k in out)


def test_immutable_does_not_mutate_input():
    src = {"decode_tok_s": 42.0}
    _ = qd.to_numeric_device_keys(src)
    assert src == {"decode_tok_s": 42.0}, "input dict must not be mutated"


def test_translated_metrics_flow_into_verdict_not_pending():
    # Before F6: a device value under a named key was invisible to build_verdict
    # (#65 stayed PENDING). After translation it is a computed row.
    named_only = {"decode_tok_s": 42.0}
    assert next(r for r in bv.build({}, named_only)["rows"] if r["num"] == 65)["status"] == "PENDING"
    translated = qd.to_numeric_device_keys(named_only)
    assert next(r for r in bv.build({}, translated)["rows"] if r["num"] == 65)["status"] != "PENDING"
