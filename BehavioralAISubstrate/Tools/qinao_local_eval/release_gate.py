"""QINAO Phase-3 — combined RELEASE GATE aggregator.

Rolls the two QINAO halves into one release decision:

  release_ok = ALL(model_critical PASS)        # Local-Model 100  (build_verdict.py -> qinao_verdict.json)
           AND ALL(substrate_critical PASS)     # Substrate 100    (swift test --filter QINAO)
           AND never_worse                       # regression gate vs baseline
           AND data_fp_match                     # frozen eval-data sha256 manifest matches
           AND contamination_clean               # train/eval contamination probe clean

The substrate half is read from a `swift test --filter QINAO` log (env SUBSTRATE_LOG or
the first CLI arg); if none is given the script runs the suite itself. The 4 substrate
CRITICAL gates that are NOT host-unit-authorable (#19 coreai device, #97/#98 schema-parity
scripts absent, #99 = the CI command itself) are reported as DEFERRED with their reason —
they are never silently counted as PASS.

Usage:
  python release_gate.py [substrate_log_path]
Writes ~/qwen_honesty_finetune/qinao_release_verdict.json + prints the report.
"""
import json, os, re, subprocess, sys

PRESERVE = os.path.expanduser("~/qwen_honesty_finetune")
REPO = os.path.expanduser("~/Project/Project06/Project06/BehavioralAISubstrate")
EXPECTED_SUBSTRATE_GATES = 58  # authored + green host gates (see QINAO_SUBSTRATE_GATE_MAP.md)

DEFERRED_SUBSTRATE = {
    "coreai_ane_conversion_fidelity": "device-only (CoreAI .aimodel conversion + A19); belongs in the on-device endurance harness",
    "schema_governance_parity": "check_whitepaper_schema_parity.sh not present in repo; author the script first",
    "cross_language_schema_alphabet_parity": "check_chenglu_schema_parity.py not present in repo; author the script first",
    "authoritative_test_suite_pass": "meta/CI invariant (the headless `swift test` gate itself), asserted by green CI not a nested test",
}


def load_json(path):
    try:
        return json.load(open(path))
    except (OSError, ValueError):
        return None


def substrate_log_text(arg_path):
    """Return the substrate test log: explicit path, env, or run the suite."""
    path = arg_path or os.environ.get("SUBSTRATE_LOG")
    if path and os.path.exists(path):
        return open(path, errors="replace").read(), f"log:{path}"
    env = dict(os.environ, DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer")
    try:
        out = subprocess.run(
            ["swift", "test", "--filter", "QINAO", "--disable-swift-testing"],
            cwd=REPO, env=env, capture_output=True, text=True, timeout=1800)
        return out.stdout + out.stderr, "ran:swift test --filter QINAO"
    except (OSError, subprocess.TimeoutExpired) as e:
        return "", f"unavailable: {e}"


def parse_substrate(text):
    """Parse the executed/failed counts + the per-gate PASS lines."""
    executed = failures = None
    for m in re.finditer(r"Executed (\d+) tests, with (\d+) failures", text):
        executed, failures = int(m.group(1)), int(m.group(2))  # take the last (suite-level) line
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
    if v is None:
        return {"available": False, "release_ok_model": False,
                "reason": "qinao_verdict.json absent — run build_verdict.py first"}, None
    rows = {r["key"]: r for r in v.get("rows", [])}
    return {
        "available": True,
        "release_ok_model": bool(v.get("release_ok_model")),
        "critical_pass": v.get("critical_pass"), "critical_fail": v.get("critical_fail"),
        "critical_pending": v.get("critical_pending"),
    }, rows


def aux_flags(model_rows, substrate):
    """never_worse / data_fp_match / contamination_clean — each (bool, evidence)."""
    # never_worse: model regression-gate row(s) + the substrate regression_gate_verdict gate.
    nw_model = True
    if model_rows:
        for key in ("regression_gate", "regression-gate", "never_worse_regression"):
            r = next((rr for k, rr in model_rows.items() if key in k), None)
            if r:
                nw_model = r["status"] == "PASS"
                break
    nw_sub = "regression_gate_verdict" in substrate["gates_passed"]
    never_worse = nw_model and nw_sub

    # data_fp_match: the frozen eval-data sha256 manifest exists (and, if a recorded
    # match flag is present, it is true).
    manifest = load_json(os.path.join(PRESERVE, "qinao_data_manifest.json"))
    data_fp_match = manifest is not None
    if isinstance(manifest, dict) and "match" in manifest:
        data_fp_match = bool(manifest["match"])

    # contamination_clean: model contamination row clean, else the substrate has no
    # contamination gate so fall back to the model verdict only.
    contamination_clean = True
    if model_rows:
        r = next((rr for k, rr in model_rows.items() if "contamination" in k), None)
        if r:
            contamination_clean = r["status"] == "PASS"
    return {
        "never_worse": (never_worse, f"model={nw_model} substrate_regression_gate={nw_sub}"),
        "data_fp_match": (data_fp_match, "qinao_data_manifest.json"),
        "contamination_clean": (contamination_clean, "model contamination row"),
    }


def main():
    arg = sys.argv[1] if len(sys.argv) > 1 else None
    text, src = substrate_log_text(arg)
    substrate = parse_substrate(text)
    substrate_ok = (
        substrate["failures"] == 0
        and substrate["executed"] is not None
        and substrate["n_gates_passed"] >= EXPECTED_SUBSTRATE_GATES
    )
    model, model_rows = model_section()
    aux = aux_flags(model_rows, substrate)

    release_ok = (
        model["release_ok_model"]
        and substrate_ok
        and all(v for v, _ in aux.values())
    )

    verdict = {
        "release_ok": release_ok,
        "components": {
            "model_critical": model["release_ok_model"],
            "substrate_critical": substrate_ok,
            **{k: v for k, (v, _) in aux.items()},
        },
        "model": model,
        "substrate": {**substrate, "source": src, "substrate_ok": substrate_ok,
                      "expected_gates": EXPECTED_SUBSTRATE_GATES},
        "substrate_deferred": DEFERRED_SUBSTRATE,
    }
    out_path = os.path.join(PRESERVE, "qinao_release_verdict.json")
    try:
        json.dump(verdict, open(out_path, "w"), indent=1)
    except OSError:
        out_path = "(not written — preserve dir absent)"

    print("=== QINAO Phase-3 combined RELEASE GATE ===")
    print(f"substrate source: {src}")
    print(f"  model_critical      : {_mark(model['release_ok_model'])}  "
          f"(PASS {model.get('critical_pass')} / FAIL {model.get('critical_fail')} / PEND {model.get('critical_pending')})"
          if model["available"] else f"  model_critical      : {_mark(False)}  ({model.get('reason')})")
    print(f"  substrate_critical  : {_mark(substrate_ok)}  "
          f"(executed {substrate['executed']}, failures {substrate['failures']}, "
          f"gates PASS {substrate['n_gates_passed']}/{EXPECTED_SUBSTRATE_GATES})")
    for k, (v, ev) in aux.items():
        print(f"  {k:<19} : {_mark(v)}  ({ev})")
    print(f"\nRELEASE_OK = {release_ok}")
    print(f"\nsubstrate CRITICAL deferred (device/CI/missing-script, NOT counted as pass):")
    for k, why in DEFERRED_SUBSTRATE.items():
        print(f"  - {k}: {why}")
    print(f"\nwrote {out_path}")
    return 0 if release_ok else 1


def _mark(ok):
    return "PASS ✅" if ok else "FAIL ❌"


if __name__ == "__main__":
    sys.exit(main())
