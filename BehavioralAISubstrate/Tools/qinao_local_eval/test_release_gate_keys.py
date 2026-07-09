"""x-test-integrity F4 teeth: the authored-gate-key extractor must NOT truncate a
mixed-case test-name suffix (which permanently failed the joint release gate).
Run: uv run --with pytest pytest test_release_gate_keys.py
"""
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
import release_gate as rg  # noqa: E402


def test_mixed_case_gate_key_is_not_truncated():
    # the exact real test name that regressed the gate
    keys = rg.gate_keys_in_text("    func test_qinao_permit_escalation_never_loosen_realFold() {")
    assert "permit_escalation_never_loosen_realFold" in keys
    assert "permit_escalation_never_loosen_real" not in keys  # the old [a-z0-9_]+ truncation


def test_lowercase_keys_still_extracted():
    text = "func test_qinao_belief_syco() {}\nfunc test_qinao_over_refusal_zero() {}"
    assert rg.gate_keys_in_text(text) == {"belief_syco", "over_refusal_zero"}


def test_authored_gate_keys_includes_the_real_mixed_case_key():
    # end-to-end against the real test tree — the key that permanently failed the gate
    keys = rg.authored_gate_keys()
    assert "permit_escalation_never_loosen_realFold" in keys, \
        "the mixed-case gate key must be discovered whole, not truncated"
