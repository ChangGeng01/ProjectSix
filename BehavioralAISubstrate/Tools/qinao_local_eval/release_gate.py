"""QINAO Phase-3 — auxiliary combined evaluation report.

Rolls the computable QINAO observations into a partial evaluation result:

  evaluation_ok = model_eval_ok               # build_verdict.py -> qinao_verdict.json
           AND ALL(substrate_critical PASS)     # Substrate 100    (swift test --filter QINAO)
           AND never_worse                       # regression gate vs baseline
           AND data_fp_match                     # frozen eval-data sha256 manifest matches
           AND contamination_clean               # train/eval contamination probe clean

Full release additionally requires release_ok_model and NO pending model/substrate
CRITICAL requirements. The two deferred substrate checks have no implementation
here, so current reports cannot assert release_ok or exit zero. Plaintext inputs
are observations, not authenticated/current-run evidence or merge authority.

The substrate half is read from a `swift test --filter QINAO` log (env SUBSTRATE_LOG or
the first CLI arg); if none is given the script runs the suite itself. The 2 substrate
CRITICAL gates that are NOT host-unit-authorable (#19 coreai device, #99 = the CI command
itself) are reported as DEFERRED with their reason — they are never silently counted as PASS.
(audit x-test-integrity F10: the #97/#98 schema-parity gates now HAVE tests —
QINAOSchemaGovernanceParityGateTests + BASEBrainSchemaGovernanceRegistryTests — and are
counted, so the old "4 gates … #97/#98 scripts absent" line was stale; DEFERRED_SUBSTRATE below
holds exactly these 2.)

Usage:
  python release_gate.py [substrate_log_path]
Writes ~/qwen_honesty_finetune/qinao_release_verdict.json + prints the report.
"""
import json, os, re, subprocess, sys
from pathlib import Path

PRESERVE = os.path.expanduser("~/qwen_honesty_finetune")
REPO = str(Path(__file__).resolve().parents[2])
EXPECTED_SUBSTRATE_GATES = 98  # authored + green host gates (see QINAO_SUBSTRATE_GATE_MAP.md)

# H23 (mega-audit F3, 2026-07-08): the data-fingerprint gate must re-verify the EVAL
# corpora, not only the 2 train files — contamination hides in the eval sets, and the
# old keymap left them unhashed. TRAIN files are REQUIRED in the manifest (their absence
# fails the gate); EVAL files are verified whenever the manifest names them. `data_eval/`
# is the eval-corpus root (holdout_*.json, tqa_mc.jsonl, syco-eval/*).
FINGERPRINT_KEYMAP = {
    "v6_train":       "data_v6/train.jsonl",
    "v6_fix":         "data_v6/fix_triples.jsonl",
    "eval_holdout":   "data_eval/holdout_belief.json",
    "eval_tqa":       "data_eval/tqa_mc.jsonl",
    "eval_are_sure":  "data_eval/syco-eval/are_you_sure.jsonl",
    "eval_fabricate": "data_eval/syco-eval/fabricate.jsonl",
}
FINGERPRINT_REQUIRED = {"v6_train", "v6_fix"}

DEFERRED_SUBSTRATE = {
    "coreai_ane_conversion_fidelity": "device-only (CoreAI .aimodel conversion + A19); belongs in the on-device endurance harness",
    "authoritative_test_suite_pass": "meta/CI invariant (the headless `swift test` gate itself), asserted by green CI not a nested test",
}


def load_json(path):
    try:
        with open(path) as handle:
            return json.load(handle)
    except (OSError, ValueError):
        return None


def substrate_log_text(arg_path):
    """Return the substrate test log: explicit path, env, or run the suite."""
    path = arg_path if arg_path is not None else os.environ.get("SUBSTRATE_LOG")
    if path is not None:
        try:
            with open(path, errors="replace") as handle:
                return handle.read(), f"log:{path}"
        except OSError as error:
            return "", f"unavailable: requested log {path!r}: {error}"
    env = dict(os.environ, DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer")
    try:
        out = subprocess.run(
            ["swift", "test", "--filter", "QINAO", "--disable-swift-testing"],
            cwd=REPO, env=env, capture_output=True, text=True, timeout=1800)
        source = "ran:swift test --filter QINAO"
        if out.returncode != 0:
            source = f"unavailable: swift test --filter QINAO exit {out.returncode}"
        return out.stdout + out.stderr, source
    except (OSError, subprocess.TimeoutExpired) as e:
        return "", f"unavailable: {e}"


def parse_substrate(text):
    """Parse the executed/failed counts + the per-gate PASS lines."""
    # audit M-j — take the MAX-executed "Executed N tests, with M failures"
    # line, not the LAST. The suite total is always the largest such count
    # (it aggregates every sub-suite, failures included); the old "last" logic
    # misjudged a truncated or stderr-interleaved log whose final line was a
    # small PARTIAL sub-suite count (e.g. a 5-test class with 0 failures
    # trailing after the real 98/3 total). A log truncated BEFORE the total is
    # still caught downstream by the gate-count + membership checks.
    executed = failures = None
    _best = -1
    for m in re.finditer(r"Executed (\d+) tests, with (\d+) failures", text):
        e = int(m.group(1))
        if e > _best:
            _best = e
            executed, failures = e, int(m.group(2))
    # Gate lines come in two print styles: "QINAO-GATE <key>: PASS" (batches 6-9)
    # and "📊 qinao-gate <key>: PASS" (batches 1-5). Match both, case-insensitively.
    gates = sorted(set(re.findall(r"qinao-gate (\w+):? (?:PASS|SKIP)", text, re.I)))
    passed = sorted(set(re.findall(r"qinao-gate (\w+):? PASS", text, re.I)))
    return {
        "executed": executed, "failures": failures,
        "gates_seen": gates, "gates_passed": passed,
        "n_gates_passed": len(passed),
    }


def model_section():
    v = load_json(os.path.join(PRESERVE, "qinao_verdict.json"))

    def unavailable(reason):
        return {"available": False, "model_eval_ok": False,
                "release_ok_model": False,
                "reason": f"qinao_verdict.json unavailable: {reason}"}, None

    if not isinstance(v, dict):
        return unavailable("absent, unreadable or invalid JSON object — run build_verdict.py first")
    for field in ("model_eval_ok", "release_ok_model"):
        if type(v.get(field)) is not bool:
            return unavailable(f"invalid {field}: expected JSON Boolean")
    for field in ("critical_pass", "critical_fail", "critical_attest", "critical_pending"):
        if type(v.get(field)) is not int or v[field] < 0:
            return unavailable(f"invalid {field}: expected nonnegative integer")
    pending = v.get("attestations_pending")
    if (not isinstance(pending, list)
            or any(type(n) is not int or n <= 0 for n in pending)
            or len(set(pending)) != len(pending)):
        return unavailable("invalid attestations_pending: expected distinct positive gate numbers")
    raw_rows = v.get("rows")
    if not isinstance(raw_rows, list) or not raw_rows:
        return unavailable("invalid rows: expected nonempty list")
    rows = {}
    for row in raw_rows:
        if not isinstance(row, dict):
            return unavailable("invalid row: expected object")
        key, status = row.get("key"), row.get("status")
        if not isinstance(key, str) or not key or key in rows:
            return unavailable("invalid row key: expected unique nonempty string")
        if not isinstance(status, str) or status not in {"PASS", "FAIL", "PENDING", "NOTE", "ATTEST"}:
            return unavailable(f"invalid row status: {key}")
        if "critical_gate" in row and type(row["critical_gate"]) is not bool:
            return unavailable(f"invalid row critical_gate Boolean: {key}")
        rows[key] = row
    # Keep useful computed results distinct from the stronger model release claim.
    return {
        "available": True,
        "model_eval_ok": v["model_eval_ok"] is True,
        "release_ok_model": v["release_ok_model"] is True,
        "attestations_pending": pending,
        "critical_rows_pending": [key for key, row in rows.items()
                                  if row.get("critical_gate") is True and row["status"] != "PASS"],
        "critical_pass": v.get("critical_pass"), "critical_fail": v.get("critical_fail"),
        "critical_attest": v.get("critical_attest"), "critical_pending": v.get("critical_pending"),
    }, rows


def regression_gate_status(model_rows):
    """audit M-j — FAIL-CLOSED never_worse (model side). Returns (passed, note).

    The old inline check defaulted `nw_model = True`, so an ABSENT regression
    row — `model_rows` empty/None, or the row renamed/dropped — passed
    never_worse with ZERO regression evidence: fail-open on a safety-critical
    "never ship a model that got worse" gate. Absence is now a FAIL (surfaced
    with a note), mirroring `contamination_clean`'s fail-closed default; only a
    regression row with a genuine PASS passes."""
    if model_rows:
        for key in ("regression_gate", "regression-gate", "never_worse_regression"):
            r = next((rr for k, rr in model_rows.items() if key in k), None)
            if r:
                return (r["status"] == "PASS", f"regression row status={r['status']}")
    return (False, "no model regression_gate row — fail-closed")


def aux_flags(model_rows, substrate):
    """never_worse / data_fp_match / contamination_clean — each (bool, evidence)."""
    # never_worse: model regression-gate row(s) + the substrate regression_gate_verdict gate.
    nw_model, nw_model_note = regression_gate_status(model_rows)
    nw_sub = "regression_gate_verdict" in substrate["gates_passed"]
    never_worse = nw_model and nw_sub

    # data_fp_match: RE-VERIFY the frozen data hashes (sha256[:16]) against the manifest —
    # NOT mere file existence (audit 2026-06-24 flagged the old check as trivially-true).
    # H23 (mega-audit F3, 2026-07-08): re-verify the EVAL sets too, not only the 2 TRAIN
    # files. Contamination lives in the eval corpora — fingerprinting only train left the
    # exact files that could carry leakage unchecked. Any eval-set entry PRESENT in the
    # manifest must match; a manifest that names an eval file whose hash drifted now FAILs.
    import hashlib
    manifest = load_json(os.path.join(PRESERVE, "qinao_data_manifest.json"))
    checked = mismatch = missing = 0
    for k, rel in FINGERPRINT_KEYMAP.items():
        if isinstance(manifest, dict):
            want = manifest.get(k)
        else:
            want = None
        # Train files are REQUIRED in the manifest; eval files are verified when present
        # (they may be added incrementally) — but a NAMED eval file with a missing blob
        # still counts as missing (fail-closed).
        p = os.path.join(PRESERVE, rel)
        if want is None:
            if k in FINGERPRINT_REQUIRED:
                missing += 1
            continue
        if not isinstance(want, str) or not os.path.exists(p):
            missing += 1; continue
        got = hashlib.sha256(open(p, "rb").read()).hexdigest()[:len(want)]
        checked += 1; mismatch += (got != want)
    data_fp_match = (checked > 0 and mismatch == 0 and missing == 0)
    fp_note = f"recomputed {checked} sha256 vs manifest, {mismatch} mismatch, {missing} missing"

    # contamination_clean: the model contamination row must be a genuinely COMPUTED PASS
    # (not ATTEST/hardcoded). The audit flagged the substrate contamination gate as a
    # hardcoded literal, so we only trust a model row whose status is a real PASS.
    contamination_clean = False; cc_note = "no computed contamination row"
    if model_rows:
        r = next((rr for k, rr in model_rows.items() if "contamination" in k), None)
        if r:
            contamination_clean = (r["status"] == "PASS")
            cc_note = f"model contamination row status={r['status']}"
    return {
        "never_worse": (never_worse, f"model={nw_model} ({nw_model_note}) substrate_regression_gate={nw_sub}"),
        "data_fp_match": (data_fp_match, fp_note),
        "contamination_clean": (contamination_clean, cc_note),
    }


# audit x-test-integrity F4 (2026-07-09): the class MUST allow UPPERCASE. It was
# `[a-z0-9_]+`, which stops at the first uppercase letter — truncating a
# mixed-case suffix (e.g. `test_qinao_..._realFold` → key `..._real`). That made
# the authored-key membership check permanently FAIL (the joint release gate
# could never report PASS) from the day such a test was added.
_GATE_KEY_RE = re.compile(r"func test_qinao_([A-Za-z0-9_]+)")


def gate_keys_in_text(text):
    """Substrate gate keys authored in `text` (test source) — pure + testable."""
    return {m.group(1) for m in _GATE_KEY_RE.finditer(text)}


def authored_gate_keys():
    """The set of substrate gate keys actually authored in the test suite (uncommented)."""
    tests = os.path.join(REPO, "Tests", "BehavioralAISubstrateTests")
    keys = set()
    for root, _dirs, files in os.walk(tests):
        for fn in files:
            if fn.endswith(".swift"):
                try:
                    with open(os.path.join(root, fn)) as fh:
                        keys |= gate_keys_in_text(fh.read())
                except OSError:
                    pass
    return keys


def main():
    arg = sys.argv[1] if len(sys.argv) > 1 else None
    text, src = substrate_log_text(arg)
    substrate = parse_substrate(text)
    # MEMBERSHIP check (audit 2026-06-24): every authored gate key must actually appear PASSed in the log —
    # not merely a count >= N (which a stray/duplicate gate could satisfy).
    authored = authored_gate_keys()
    passed = set(substrate["gates_passed"])
    missing_keys = sorted(authored - passed)
    substrate["authored"] = len(authored)
    substrate["missing_keys"] = missing_keys
    substrate_ok = (
        not src.startswith("unavailable:")
        and substrate["failures"] == 0
        and substrate["executed"] is not None
        and substrate["n_gates_passed"] >= EXPECTED_SUBSTRATE_GATES
        and len(authored) > 0
        and len(missing_keys) == 0          # every authored gate genuinely ran + passed
    )
    model, model_rows = model_section()
    aux = aux_flags(model_rows, substrate)

    model_deferred = {
        f"model_attest_{n}": "architectural attestation a model eval cannot verify — "
        "unverified offline/sovereignty/traceability requirement; this report cannot resolve it"
        for n in model.get("attestations_pending", [])
    }
    evaluation_ok = (
        model.get("model_eval_ok", False)
        and substrate_ok
        and all(v for v, _ in aux.values())
    )
    release_ok = (
        evaluation_ok
        and model.get("release_ok_model") is True
        and not model_deferred
        and not model.get("critical_rows_pending")
        and all(model.get(key) == 0 for key in
                ("critical_fail", "critical_attest", "critical_pending"))
        and not DEFERRED_SUBSTRATE
    )

    verdict = {
        "evaluation_ok": evaluation_ok,
        "release_ok": release_ok,
        "components": {
            "model_critical": model.get("model_eval_ok", False),
            "substrate_critical": substrate_ok,
            **{k: v for k, (v, _) in aux.items()},
        },
        "model": model,
        "model_deferred": model_deferred,
        "substrate": {**substrate, "source": src, "substrate_ok": substrate_ok,
                      "expected_gates": EXPECTED_SUBSTRATE_GATES},
        "substrate_deferred": DEFERRED_SUBSTRATE,
    }
    out_path = os.path.join(PRESERVE, "qinao_release_verdict.json")
    try:
        with open(out_path, "w") as handle:
            json.dump(verdict, handle, indent=1)
    except OSError:
        out_path = "(not written — preserve dir absent)"

    print("=== QINAO Phase-3 auxiliary EVALUATION REPORT ===")
    print(f"substrate source: {src}")
    print(f"  model_critical(eval): {_mark(model['model_eval_ok'])}  "
          f"(PASS {model.get('critical_pass')} / FAIL {model.get('critical_fail')} / "
          f"ATTEST {model.get('critical_attest')} / PEND {model.get('critical_pending')})"
          if model["available"] else f"  model_critical      : {_mark(False)}  ({model.get('reason')})")
    print(f"  substrate_host     : {_mark(substrate_ok)}  "
          f"(executed {substrate['executed']}, failures {substrate['failures']}, "
          f"gates PASS {substrate['n_gates_passed']}/{EXPECTED_SUBSTRATE_GATES})")
    for k, (v, ev) in aux.items():
        print(f"  {k:<19} : {_mark(v)}  ({ev})")
    print(f"\nEVALUATION_OK = {evaluation_ok}")
    print(f"RELEASE_OK = {release_ok}")
    print(f"model release_ok_model = {model.get('release_ok_model', False)}")
    if model.get("critical_rows_pending"):
        print(f"model CRITICAL rows not PASS: {model['critical_rows_pending']}")
    if model_deferred:
        print(f"\nmodel CRITICAL deferred (NOT counted as release pass):")
        for k, why in model_deferred.items():
            print(f"  - {k}: {why}")
    print(f"\nsubstrate CRITICAL deferred (device/CI, NOT counted as release pass):")
    for k, why in DEFERRED_SUBSTRATE.items():
        print(f"  - {k}: {why}")
    print(f"\nwrote {out_path}")
    return 0 if release_ok else 1


def _mark(ok):
    return "PASS ✅" if ok else "FAIL ❌"


if __name__ == "__main__":
    sys.exit(main())
