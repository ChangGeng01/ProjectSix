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


def test_f10_deferred_substrate_holds_exactly_the_two_unauthorable_gates():
    # audit x-test-integrity F10: the docstring's stale "4 gates … #97/#98 scripts absent" was
    # corrected to 2 — DEFERRED_SUBSTRATE must hold exactly #19 (coreai device) + #99 (CI invariant),
    # NOT the schema-parity gates, which now have tests and are counted.
    assert set(rg.DEFERRED_SUBSTRATE) == {
        "coreai_ane_conversion_fidelity", "authoritative_test_suite_pass"
    }, "DEFERRED_SUBSTRATE drifted — reconcile the docstring count too"
    assert not any("schema" in k for k in rg.DEFERRED_SUBSTRATE), \
        "#97/#98 schema-parity gates must NOT be deferred (they now have tests)"
    # The docstring must say "2 substrate CRITICAL gates", matching the dict.
    assert "2 substrate\nCRITICAL gates" in rg.__doc__ or "2 substrate CRITICAL gates" in rg.__doc__.replace("\n", " ")
