"""QINAO Phase-2 substrate coverage mapper.
Parses QINAO_SUBSTRATE_100_METRICS.md (100 metrics) + the CRITICAL set from QINAO_RELEASE_GATE_CHECKLIST.md,
extracts each metric's primary BAS symbol, and greps the Swift test suite to map covered-vs-missing.
Emits substrate_registry.json + a coverage verdict. Run from repo root (BehavioralAISubstrate/).
"""
import re, os, json, subprocess, sys

ROOT = os.path.expanduser("~/Project/Project06/Project06/BehavioralAISubstrate")
DOCS = os.path.join(ROOT, "Docs")
TESTS = os.path.join(ROOT, "Tests")

# 1) parse the 100 substrate metrics
rows = []
for line in open(os.path.join(DOCS, "QINAO_SUBSTRATE_100_METRICS.md")):
    m = re.match(r"\|\s*(\d+)\s*\|\s*([a-z0-9_]+)\s*\|(.*)", line)
    if not m: continue
    num, key, rest = int(m.group(1)), m.group(2), m.group(3)
    cols = rest.split("|")
    level = cols[-2].strip() if len(cols) >= 2 else ""
    level = re.search(r"(CRITICAL|HIGH|MEDIUM)", level)
    level = level.group(1) if level else "HIGH"
    defn = cols[0]
    syms = re.findall(r"`?\b(BAS[A-Za-z0-9]+|MLXOrganAdapter|MLXRuntimeConfig)\b", defn)
    rows.append({"num": num, "key": key, "level": level, "symbol": syms[0] if syms else None,
                 "all_symbols": list(dict.fromkeys(syms))[:4]})

# 2) CRITICAL set from the release gate checklist (substrate section)
crit = set()
gate = open(os.path.join(DOCS, "QINAO_RELEASE_GATE_CHECKLIST.md")).read()
sub_section = gate.split("衬底")[-1] if "衬底" in gate else gate
for m in re.finditer(r"`([a-z0-9_]+)`", sub_section):
    crit.add(m.group(1))
for r in rows:
    if r["key"] in crit: r["level"] = "CRITICAL"

# 3) grep the test suite for coverage (by key, then by primary symbol)
def grep_count(pat):
    try:
        out = subprocess.run(["grep", "-rli", "--include=*.swift", pat, TESTS],
                             capture_output=True, text=True, timeout=60)
        return len([l for l in out.stdout.splitlines() if l.strip()])
    except Exception:
        return 0
for r in rows:
    r["by_key"] = grep_count(r["key"])
    r["by_symbol"] = grep_count(r["symbol"]) if r["symbol"] else 0
    if r["by_key"] > 0:        r["coverage"] = "NAMED"        # a test already uses the QINAO metric name
    elif r["by_symbol"] >= 1:  r["coverage"] = "BEHAVIOR"     # symbol tested, but not under the QINAO gate name
    else:                       r["coverage"] = "MISSING"

# 4) verdict
crit_rows = [r for r in rows if r["level"] == "CRITICAL"]
named = [r for r in rows if r["coverage"] == "NAMED"]
behavior = [r for r in rows if r["coverage"] == "BEHAVIOR"]
missing = [r for r in rows if r["coverage"] == "MISSING"]
verdict = {
    "n_metrics": len(rows), "n_critical": len(crit_rows),
    "named_gate": len(named), "behavior_covered": len(behavior), "missing": len(missing),
    "critical_named": len([r for r in crit_rows if r["coverage"] == "NAMED"]),
    "critical_behavior": len([r for r in crit_rows if r["coverage"] == "BEHAVIOR"]),
    "critical_missing": len([r for r in crit_rows if r["coverage"] == "MISSING"]),
    "rows": rows,
}
json.dump(verdict, open(os.path.expanduser("~/qwen_honesty_finetune/qinao_substrate_coverage.json"), "w"), indent=1)
print(f"=== QINAO Substrate-100 coverage ===")
print(f"metrics {len(rows)} | CRITICAL {len(crit_rows)} | NAMED-gate {len(named)} | BEHAVIOR-covered {len(behavior)} | MISSING {len(missing)}")
print(f"CRITICAL: NAMED {verdict['critical_named']} | BEHAVIOR {verdict['critical_behavior']} | MISSING {verdict['critical_missing']}")
print("\n-- CRITICAL metrics with NO behavior test (need authoring) --")
for r in crit_rows:
    if r["coverage"] == "MISSING":
        print(f"  #{r['num']:<3} {r['key']:<40} (symbol: {r['symbol']})")
print("\n-- sample CRITICAL BEHAVIOR-covered (have tests, need QINAO gate name + raised bar) --")
for r in [x for x in crit_rows if x['coverage']=='BEHAVIOR'][:12]:
    print(f"  #{r['num']:<3} {r['key']:<40} {r['symbol']} ({r['by_symbol']} test files)")
