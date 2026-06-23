"""QINAO Local-Model verdict builder. Reads base+tuned values, applies thresholds, rolls up the 25 model CRITICAL gates.
Usage: python build_verdict.py <base_tag> <tuned_tag>
Writes verdict.json + prints report. release_ok_model = all model CRITICAL gates PASS.
"""
import json, re, sys, os
sys.path.insert(0, os.path.dirname(__file__))
from registry import METRICS, MODEL_CRITICAL, by_num

base_tag, tuned_tag = sys.argv[1], sys.argv[2]
base = json.load(open(f"/tmp/qinao_values_{base_tag}.json"))
tuned = json.load(open(f"/tmp/qinao_values_{tuned_tag}.json"))

def num(x):
    try: return float(x)
    except (TypeError, ValueError): return None

def evaluate(thr, direction, val, bval):
    """Return PASS/FAIL/PENDING/NOTE + a note."""
    if val is None: return "PENDING", "not computed"
    if thr in ("frozen","=target","all"):  # attestation gates: a recorded value is NOT a verified pass
        return "ATTEST", f"attested (NOT independently verified): {val}"
    v = num(val)
    if v is None:  # non-numeric recorded value (provenance, manifest, etc.) -> recorded gate
        return "NOTE", f"recorded: {val}"
    # base-relative (both directions)
    m = re.match(r"(<=|>=)base(-([\d.]+))?$", thr)
    if m:
        if v is None or num(bval) is None: return "NOTE", f"{val} (base {bval})"
        tol = float(m.group(3) or 0)
        if m.group(1) == ">=": return ("PASS" if v >= num(bval) - tol else "FAIL"), f"{val} vs base {bval} (-{tol})"
        return ("PASS" if v <= num(bval) + tol else "FAIL"), f"{val} vs base {bval} (+{tol})"
    if thr.startswith("~"):  # near-target (e.g. ~0 PII): pass within 0.5
        t = num(thr[1:])
        if t is not None and v is not None: return ("PASS" if abs(v - t) <= 0.5 else "FAIL"), f"{val} ~{t}"
    if thr in ("report","calib","record","stable","converge","small","~3GB"): return "NOTE", str(val)
    if thr in ("=0",): return ("PASS" if v == 0 else "FAIL"), str(val)
    if thr in ("100","=target","all","~1.58","~0.15"):
        if thr == "100": return ("PASS" if v == 100 else "FAIL"), str(val)
        return "NOTE", str(val)
    mm = re.match(r"(<=|<|>=|>)\s*([\d.]+)", thr)
    if mm and v is not None:
        op, t = mm.group(1), float(mm.group(2))
        ok = {"<=": v <= t, "<": v < t, ">=": v >= t, ">": v > t}[op]
        return ("PASS" if ok else "FAIL"), f"{val} {op}{t}"
    return "NOTE", str(val)

rows = []
for (n_, key, cat, direction, thr, level, comp) in METRICS:
    bval = base.get(str(n_)); tval = tuned.get(str(n_))
    status, note = evaluate(thr, direction, tval, bval)
    rows.append({"num": n_, "key": key, "cat": cat, "level": level, "dir": direction,
                 "threshold": thr, "base": bval, "tuned": tval, "status": status, "note": note,
                 "critical_gate": n_ in MODEL_CRITICAL})

# rollups
crit = [r for r in rows if r["critical_gate"]]
crit_pass = [r for r in crit if r["status"] == "PASS"]              # genuinely computed + passed a real threshold
crit_fail = [r for r in crit if r["status"] == "FAIL"]
crit_attest = [r for r in crit if r["status"] == "ATTEST"]          # recorded value, NOT independently verified
crit_pend = [r for r in crit if r["status"] in ("PENDING", "NOTE")]
computed = [r for r in rows if r["status"] in ("PASS", "FAIL")]
# release requires EVERY critical gate to be a genuine PASS — ATTEST/PENDING/NOTE/FAIL all block.
verdict = {
    "model": tuned_tag, "base": base_tag,
    "n_metrics": len(rows), "n_computed": len(computed),
    "model_critical_total": len(crit), "critical_pass": len(crit_pass),
    "critical_fail": len(crit_fail), "critical_attest": len(crit_attest), "critical_pending": len(crit_pend),
    "release_ok_model": len(crit_pass) == len(crit),
    "rows": rows,
}
json.dump(verdict, open(os.path.expanduser("~/qwen_honesty_finetune/qinao_verdict.json"), "w"), indent=1)

print(f"=== QINAO Local-Model verdict: {tuned_tag} vs {base_tag} ===")
print(f"metrics {len(rows)} | computed {len(computed)} | model-CRITICAL {len(crit)}: PASS {len(crit_pass)} FAIL {len(crit_fail)} ATTEST {len(crit_attest)} PENDING {len(crit_pend)}")
print(f"release_ok_model = {verdict['release_ok_model']}  (needs all {len(crit)} CRITICAL genuinely PASS; ATTEST/PENDING do NOT count)")
if crit_attest:
    print("\n-- CRITICAL gates that only ATTEST (recorded, NOT verified — do not count as pass) --")
    for r in crit_attest: print(f"  #{r['num']:<3} {r['key']:<28} ({r['threshold']}) {r['note']}")
print("\n-- computed metrics (base -> tuned) --")
for r in computed:
    flag = "🔴CRIT" if r["critical_gate"] else r["level"][:4]
    print(f"  #{r['num']:<3} {r['key']:<28} [{flag:<6}] {r['status']:<7} {r['note']}")
print("\n-- CRITICAL gates still PENDING (need impl: bench/rag/safety/device/judge) --")
for r in crit_pend:
    print(f"  #{r['num']:<3} {r['key']:<28} ({r['threshold']}) <- {by_num()[r['num']][6]}")
