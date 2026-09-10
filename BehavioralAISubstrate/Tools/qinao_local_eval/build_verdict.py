"""QINAO Local-Model verdict builder. Reads base+tuned values, applies thresholds, rolls up the 25 model CRITICAL gates.
Usage: python build_verdict.py <base_tag> <tuned_tag>
Writes verdict.json + prints report.

Verdict fields (H23, 2026-07-08):
  model_eval_ok        — every CRITICAL gate the eval CAN adjudicate is a genuine PASS
                         (FAIL / PENDING / threshold-ATTEST on a verifiable gate all block).
  attestations_pending — architectural CRITICAL gates (#88/#89/#92) a model eval cannot
                         verify; cleared only by a real deployment attestation channel.
  release_ok_model     — model_eval_ok AND no attestations_pending (full release).

THREAT MODEL (honest scope): the `_prov` provenance stamps + fail-closed loading defend
against ACCIDENTAL self-certification theatre — hardcoded literals, missing/truncated
values, a bare /tmp injection with no provenance. They are NOT tamper-evidence: `_prov`
is plaintext in the same writable values file, so a motivated forger who also writes
`_prov:{kind:"computed"}` can still flip `model_eval_ok`. Real tamper-resistance would
need a signed / writer-owned channel. What IS structurally unforgeable from the values
file is `release_ok_model`: attestations_pending derives from gate IDENTITY
(ATTEST_ONLY_CRITICAL membership), so the FINAL release stays blocked regardless of forgery.
"""

import json
import math
import os
import re
import sys

sys.path.insert(0, os.path.dirname(__file__))
from qinao_humaneval_evidence import (
    DATASET_ID,
    DATASET_SPLIT,
    EVIDENCE_SCHEMA,
    MAX_HUMANEVAL_SAMPLES,
)
from registry import METRICS, MODEL_CRITICAL, ATTEST_ONLY_CRITICAL, by_num


_SHA256 = re.compile(r"^[0-9a-f]{64}$")
_HUMANEVAL_PRODUCERS = {
    "qinao_humaneval",
    "qinao_humaneval_paired",
}
_HUMANEVAL_COMPARABLE_FIELDS = (
    "schema",
    "producer",
    "run_id",
    "harness_sha256",
    "dataset_id",
    "dataset_split",
    "dataset_fingerprint",
    "sample_set_sha256",
    "sample_count",
)


def _load_values(arg):
    """H23: fail-closed JSON load. A tag resolves to /tmp/qinao_values_<tag>.json; a
    path is read directly (used by the gate-integrity tests). A missing / malformed /
    truncated file exits non-zero — a broken values file must NEVER silently become an
    empty dict that PENDINGs every gate into a misleading 'nothing failed' verdict."""
    path = arg if os.path.exists(arg) else f"/tmp/qinao_values_{arg}.json"
    try:
        with open(path) as fh:
            data = json.load(fh)
    except FileNotFoundError:
        sys.stderr.write(f"build_verdict: values file not found: {path}\n")
        sys.exit(2)
    except json.JSONDecodeError as e:
        sys.stderr.write(
            f"build_verdict: malformed/truncated values JSON {path}: {e}\n"
        )
        sys.exit(2)
    if not isinstance(data, dict):
        sys.stderr.write(f"build_verdict: values JSON is not an object: {path}\n")
        sys.exit(2)
    return data


def num(x):
    if isinstance(x, bool):
        return None
    try:
        value = float(x)
    except (TypeError, ValueError):
        return None
    return value if math.isfinite(value) else None


def _humaneval_evidence_provenance(values):
    provenance = values.get("_prov")
    if not isinstance(provenance, dict):
        return None
    metric = provenance.get("30")
    if (
        not isinstance(metric, dict)
        or metric.get("kind") != "computed"
        or metric.get("runner") not in _HUMANEVAL_PRODUCERS
    ):
        return None
    evidence = metric.get("evidence")
    if not isinstance(evidence, dict):
        return None
    if evidence.get("schema") != EVIDENCE_SCHEMA:
        return None
    if evidence.get("producer") != metric.get("runner"):
        return None
    if not isinstance(evidence.get("run_id"), str) or not evidence["run_id"]:
        return None
    if not isinstance(evidence.get("tag"), str) or not evidence["tag"]:
        return None
    if not _SHA256.fullmatch(str(evidence.get("subject_sha256", ""))):
        return None
    if not _SHA256.fullmatch(str(evidence.get("harness_sha256", ""))):
        return None
    if not _SHA256.fullmatch(str(evidence.get("sample_set_sha256", ""))):
        return None
    if (
        type(evidence.get("sample_count")) is not int
        or not 0 < evidence["sample_count"] <= MAX_HUMANEVAL_SAMPLES
    ):
        return None
    if (
        type(evidence.get("passed")) is not int
        or not 0 <= evidence["passed"] <= evidence["sample_count"]
    ):
        return None
    raw_score = evidence.get("score")
    raw_value = values.get("30")
    if (
        isinstance(raw_score, bool)
        or not isinstance(raw_score, (int, float))
        or isinstance(raw_value, bool)
        or not isinstance(raw_value, (int, float))
    ):
        return None
    score = float(raw_score)
    value = float(raw_value)
    if not math.isfinite(score) or not math.isfinite(value):
        return None
    if not 0 <= score <= 100 or value != score:
        return None
    if score != round(evidence["passed"] / evidence["sample_count"] * 100, 1):
        return None
    if evidence.get("dataset_id") != DATASET_ID:
        return None
    if evidence.get("dataset_split") != DATASET_SPLIT:
        return None
    if (
        not isinstance(evidence.get("dataset_fingerprint"), str)
        or not evidence["dataset_fingerprint"]
    ):
        return None
    return evidence


def _humaneval_comparison(base, tuned):
    """Require two current, receipt-validated observations of the same task set."""

    base_evidence = _humaneval_evidence_provenance(base)
    tuned_evidence = _humaneval_evidence_provenance(tuned)
    if base_evidence is None or tuned_evidence is None:
        return False, "HumanEval current-run evidence unavailable"
    if base_evidence["tag"] == tuned_evidence["tag"]:
        return False, "HumanEval base and tuned tags must be distinct"
    if base_evidence["subject_sha256"] == tuned_evidence["subject_sha256"]:
        return False, "HumanEval base and tuned subject identities must be distinct"
    for field in _HUMANEVAL_COMPARABLE_FIELDS:
        if base_evidence[field] != tuned_evidence[field]:
            label = {
                "sample_set_sha256": "sample set",
                "sample_count": "sample count",
                "dataset_fingerprint": "dataset fingerprint",
                "harness_sha256": "harness",
                "run_id": "run",
                "producer": "producer",
            }.get(field, field.replace("_", " "))
            return False, f"HumanEval {label} mismatch"
    return True, ""


def evaluate(thr, direction, val, bval, num=None, prov=None):
    """Return PASS/FAIL/PENDING/NOTE/ATTEST + a note.

    H23: `num` (the metric number) and `prov` (its provenance entry, or None) gate the
    anti-theatre rules BEFORE any threshold logic:
      * an ATTEST_ONLY_CRITICAL gate (architectural deployment fact) is ALWAYS ATTEST —
        no recorded or injected value can launder it into a genuine PASS;
      * a MODEL_CRITICAL gate whose value carries no `kind=="computed"` provenance is a
        hand-injected literal → ATTEST (never counts toward release_ok)."""
    metric_num = num  # the metric number arg
    tonum = globals()[
        "num"
    ]  # the module-level float-coercion helper (arg name shadows it)
    if val is None:
        return "PENDING", "not computed"
    if metric_num in ATTEST_ONLY_CRITICAL:
        return "ATTEST", f"architectural attestation (eval cannot verify): {val}"
    if metric_num in MODEL_CRITICAL and (
        not isinstance(prov, dict) or prov.get("kind") != "computed"
    ):
        return (
            "ATTEST",
            f"no computed provenance — recorded literal, not a verified pass: {val}",
        )
    if thr in (
        "frozen",
        "=target",
        "all",
    ):  # attestation gates: a recorded value is NOT a verified pass
        return "ATTEST", f"attested (NOT independently verified): {val}"
    v = tonum(val)
    if (
        v is None
    ):  # non-numeric recorded value (provenance, manifest, etc.) -> recorded gate
        return "NOTE", f"recorded: {val}"
    # base-relative (both directions)
    m = re.match(r"(<=|>=)base(-([\d.]+))?$", thr)
    if m:
        if tonum(bval) is None:
            return "PENDING", f"{val} (base unavailable: {bval})"
        tol = float(m.group(3) or 0)
        if m.group(1) == ">=":
            return (
                "PASS" if v >= tonum(bval) - tol else "FAIL"
            ), f"{val} vs base {bval} (-{tol})"
        return (
            "PASS" if v <= tonum(bval) + tol else "FAIL"
        ), f"{val} vs base {bval} (+{tol})"
    if thr.startswith("~"):  # near-target (e.g. ~0 PII): pass within 0.5
        t = tonum(thr[1:])
        if t is not None and v is not None:
            return ("PASS" if abs(v - t) <= 0.5 else "FAIL"), f"{val} ~{t}"
    if thr in ("report", "calib", "record", "stable", "converge", "small", "~3GB"):
        return "NOTE", str(val)
    if thr in ("=0",):
        return ("PASS" if v == 0 else "FAIL"), str(val)
    if thr in ("100", "=target", "all", "~1.58", "~0.15"):
        if thr == "100":
            return ("PASS" if v == 100 else "FAIL"), str(val)
        return "NOTE", str(val)
    mm = re.match(r"(<=|<|>=|>)\s*([\d.]+)", thr)
    if mm and v is not None:
        op, t = mm.group(1), float(mm.group(2))
        ok = {"<=": v <= t, "<": v < t, ">=": v >= t, ">": v > t}[op]
        return ("PASS" if ok else "FAIL"), f"{val} {op}{t}"
    return "NOTE", str(val)


def build(base, tuned):
    """Roll up all metrics into the release verdict. Pure function of the two values
    dicts — importable and unit-testable without argv or the filesystem."""
    # Provenance side-channel (H23 F1): qinao_eval stamps `_prov[str(num)] = {"kind": ...}`
    # for every value it computes/attests. A CRITICAL value with no matching provenance is
    # a hand-injected literal and can never be a genuine PASS.
    tuned_prov = tuned.get("_prov", {}) if isinstance(tuned.get("_prov"), dict) else {}
    rows = []
    for n_, key, cat, direction, thr, level, comp in METRICS:
        bval = base.get(str(n_))
        tval = tuned.get(str(n_))
        if n_ == 30:
            comparable, comparison_note = _humaneval_comparison(base, tuned)
            if comparable:
                status, note = evaluate(
                    thr,
                    direction,
                    tval,
                    bval,
                    num=n_,
                    prov=tuned_prov.get(str(n_)),
                )
            else:
                status, note = "PENDING", comparison_note
        else:
            status, note = evaluate(
                thr, direction, tval, bval, num=n_, prov=tuned_prov.get(str(n_))
            )
        rows.append(
            {
                "num": n_,
                "key": key,
                "cat": cat,
                "level": level,
                "dir": direction,
                "threshold": thr,
                "base": bval,
                "tuned": tval,
                "status": status,
                "note": note,
                "critical_gate": n_ in MODEL_CRITICAL,
            }
        )
    crit = [r for r in rows if r["critical_gate"]]
    crit_pass = [
        r for r in crit if r["status"] == "PASS"
    ]  # genuinely computed + passed a real threshold
    crit_fail = [r for r in crit if r["status"] == "FAIL"]
    crit_attest = [
        r for r in crit if r["status"] == "ATTEST"
    ]  # recorded value, NOT independently verified
    crit_pend = [r for r in crit if r["status"] in ("PENDING", "NOTE")]
    computed = [r for r in rows if r["status"] in ("PASS", "FAIL")]
    # H23: split what the model eval CAN certify from what needs a deployment attestation.
    #   model_eval_ok  — every CRITICAL gate the eval can verify (not ATTEST_ONLY) is a
    #                    genuine PASS. This is the honest model-side verdict.
    #   attest_pending — the architectural gates (#88/#89/#92) awaiting a real, separate
    #                    attestation channel — the eval structurally cannot verify them.
    #   release_ok_model — full release: model_eval_ok AND all architectural attestations
    #                    verified. Today that channel does not exist, so this is honestly
    #                    False rather than laundered True from hardcoded literals.
    # model_eval_ok: every verifiable CRITICAL gate is a GENUINE PASS. FAIL blocks;
    # PENDING (uncomputed) blocks fail-closed; and — crucially — a threshold-gated
    # verifiable CRITICAL that lands on ATTEST also blocks. Without that last clause a
    # hand-injected values file (passing literals with no `kind=="computed"` provenance)
    # routes every gate to ATTEST and would sail through as model_eval_ok=True with
    # critical_pass=0 (the H23 injection applied to the 22 verifiable gates). The only
    # verifiable gates that are ATTEST BY DESIGN are the recorded-fact thresholds
    # (frozen / =target / all); those live outside the pass/fail contract, so they are
    # exempted explicitly rather than by a blanket ATTEST tolerance.
    RECORDED_THRESHOLDS = ("frozen", "=target", "all")
    verifiable = [r for r in crit if r["num"] not in ATTEST_ONLY_CRITICAL]
    v_fail = [r for r in verifiable if r["status"] == "FAIL"]
    v_pending = [r for r in verifiable if r["status"] in ("PENDING", "NOTE")]
    v_attest_blocking = [
        r
        for r in verifiable
        if r["status"] == "ATTEST" and r["threshold"] not in RECORDED_THRESHOLDS
    ]
    attest_pending = sorted(r["num"] for r in crit if r["num"] in ATTEST_ONLY_CRITICAL)
    model_eval_ok = not v_fail and not v_pending and not v_attest_blocking
    return {
        "n_metrics": len(rows),
        "n_computed": len(computed),
        "model_critical_total": len(crit),
        "critical_pass": len(crit_pass),
        "critical_fail": len(crit_fail),
        "critical_attest": len(crit_attest),
        "critical_pending": len(crit_pend),
        "model_eval_ok": model_eval_ok,
        "attestations_pending": attest_pending,
        "release_ok_model": model_eval_ok and not attest_pending,
        "rows": rows,
    }


def main():
    if len(sys.argv) != 3:
        sys.stderr.write("usage: build_verdict.py <base_tag> <tuned_tag>\n")
        sys.exit(2)
    base_tag, tuned_tag = sys.argv[1], sys.argv[2]
    if base_tag == tuned_tag:
        sys.stderr.write("build_verdict: base and tuned tags must be distinct\n")
        sys.exit(2)
    # H23 wire-1/2 (2026-07-09): fold in the orphan harness side-files
    # (qinao_read/bench/humaneval/bench_zh/cmmlu/gsm8k_fair/forget/…) that
    # build_verdict never read, so their CRITICAL gates flow into the verdict
    # instead of staying silently PENDING. The merge stamps computed provenance
    # for MODEL_CRITICAL metrics so they count as genuine passes, not ATTEST.
    from qinao_merge import merge_known_sidefiles
    from qinao_humaneval_evidence import (
        observe_humaneval_output_set,
        optional_humaneval_run_context_from_env,
    )

    try:
        humaneval_context = optional_humaneval_run_context_from_env(
            required_tags=(base_tag, tuned_tag)
        )
    except ValueError as error:
        sys.stderr.write(
            f"build_verdict: invalid HumanEval current-run context: {error}\n"
        )
        sys.exit(2)
    if humaneval_context is None:
        base = merge_known_sidefiles(_load_values(base_tag), base_tag)
        tuned = merge_known_sidefiles(_load_values(tuned_tag), tuned_tag)
        verdict = build(base, tuned)
    else:
        # One ordered shared-lock observation prevents a verdict from combining
        # base generation A with tuned generation B during a writer transition.
        with observe_humaneval_output_set(
            humaneval_context, (base_tag, tuned_tag)
        ) as humaneval_observation:
            base = merge_known_sidefiles(
                _load_values(base_tag),
                base_tag,
                humaneval_context=humaneval_context,
                humaneval_observation=humaneval_observation,
            )
            tuned = merge_known_sidefiles(
                _load_values(tuned_tag),
                tuned_tag,
                humaneval_context=humaneval_context,
                humaneval_observation=humaneval_observation,
            )
            verdict = build(base, tuned)
    verdict["model"] = tuned_tag
    verdict["base"] = base_tag
    _out = os.environ.get(
        "QINAO_VERDICT_OUT",
        os.path.expanduser("~/qwen_honesty_finetune/qinao_verdict.json"),
    )
    os.makedirs(os.path.dirname(_out), exist_ok=True)
    json.dump(verdict, open(_out, "w"), indent=1)

    crit_total = verdict["model_critical_total"]
    crit_attest = [
        r for r in verdict["rows"] if r["critical_gate"] and r["status"] == "ATTEST"
    ]
    computed = [r for r in verdict["rows"] if r["status"] in ("PASS", "FAIL")]
    crit_pend = [
        r
        for r in verdict["rows"]
        if r["critical_gate"] and r["status"] in ("PENDING", "NOTE")
    ]
    print(f"=== QINAO Local-Model verdict: {tuned_tag} vs {base_tag} ===")
    print(
        f"metrics {verdict['n_metrics']} | computed {verdict['n_computed']} | model-CRITICAL {crit_total}: "
        f"PASS {verdict['critical_pass']} FAIL {verdict['critical_fail']} "
        f"ATTEST {verdict['critical_attest']} PENDING {verdict['critical_pending']}"
    )
    print(
        f"model_eval_ok = {verdict['model_eval_ok']}  (no verifiable-CRITICAL FAIL/PENDING/NOTE; recorded attestations don't block)"
    )
    print(
        f"attestations_pending = {verdict['attestations_pending']}  (architectural gates a model eval cannot verify — need a deployment attestation channel)"
    )
    print(
        f"release_ok_model = {verdict['release_ok_model']}  (model_eval_ok AND all architectural attestations verified)"
    )
    if crit_attest:
        print(
            "\n-- CRITICAL gates that only ATTEST (recorded, NOT verified — do not count as pass) --"
        )
        for r in crit_attest:
            print(f"  #{r['num']:<3} {r['key']:<28} ({r['threshold']}) {r['note']}")
    print("\n-- computed metrics (base -> tuned) --")
    for r in computed:
        flag = "🔴CRIT" if r["critical_gate"] else r["level"][:4]
        print(
            f"  #{r['num']:<3} {r['key']:<28} [{flag:<6}] {r['status']:<7} {r['note']}"
        )
    print(
        "\n-- CRITICAL gates still PENDING (need impl: bench/rag/safety/device/judge) --"
    )
    for r in crit_pend:
        print(
            f"  #{r['num']:<3} {r['key']:<28} ({r['threshold']}) <- {by_num()[r['num']][6]}"
        )


if __name__ == "__main__":
    main()
