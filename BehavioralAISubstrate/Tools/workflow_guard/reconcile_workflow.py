#!/usr/bin/env python3
"""Workflow completeness guard (2026-07-11, self-directed close of the monitoring hole).

The recurring failure mode I could NOT catch reliably by vigilance — TWICE the operator caught
it, not me: a workflow's parallel()/pipeline() uses .filter(Boolean), so an agent that dies
(StructuredOutput retry cap, API server error) resolves to null and its item is SILENTLY dropped
from the synthesis — neither surfaced as a finding nor recorded as killed. The `<failures>` block
and the `<usage>` agents_error>0 both signal it, but the journal (the source of truth) does not.

This makes the check MECHANICAL, not vigilance-based:
  reconcile_workflow.py <journal.jsonl> --expect <agent_count_from_usage>
It reports:
  - result_count vs expected agent_count  → the silent-drop count (the load-bearing number)
  - any result whose payload is an error/empty (defensive)
  - a candidates-vs-verdicts diff when the journal carries a producer array + per-item verdicts
    (the design-workflow shape), naming the un-adjudicated items.
Exit 1 if any gap is found — so a wrapper can HARD-FAIL instead of trusting a clean-looking synthesis.
"""
import json
import sys
from typing import Any


def load_results(journal_path: str) -> list[Any]:
    out = []
    with open(journal_path) as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                o = json.loads(line)
            except json.JSONDecodeError:
                continue
            if o.get("type") == "result":
                out.append(o.get("result"))
    return out


def is_empty_result(r: Any) -> bool:
    return r is None or (isinstance(r, str) and not r.strip()) or (isinstance(r, dict) and not r)


def candidate_verdict_diff(results: list[Any]) -> tuple[list[str], list[str]]:
    """Best-effort: collect candidate names from producer arrays, verdict names from judge results.
    Returns (candidate_names, verdict_names). A producer emits a list under a *levers*/*candidates*/
    *findings*/*rows* key; a verdict is a dict carrying a name-ish key plus a survives/verdict field."""
    cand, verd = [], []
    array_keys = ("levers", "candidates", "findings", "rows", "classifications", "items")
    name_keys = ("name", "id", "file", "title")
    verdict_keys = ("survives", "verdict", "holds", "is_fatal", "outcome")
    for r in results:
        if not isinstance(r, dict):
            continue
        for ak in array_keys:
            if isinstance(r.get(ak), list):
                for item in r[ak]:
                    if isinstance(item, dict):
                        for nk in name_keys:
                            if item.get(nk):
                                cand.append(str(item[nk]))
                                break
        if any(k in r for k in verdict_keys):
            for nk in name_keys:
                if r.get(nk):
                    verd.append(str(r[nk]))
                    break
    return cand, verd


def main() -> int:
    if len(sys.argv) < 2:
        print("usage: reconcile_workflow.py <journal.jsonl> [--expect N]", file=sys.stderr)
        return 2
    journal = sys.argv[1]
    expect = None
    if "--expect" in sys.argv:
        expect = int(sys.argv[sys.argv.index("--expect") + 1])

    results = load_results(journal)
    gaps = []

    if expect is not None and len(results) < expect:
        gaps.append(
            f"SILENT DROP: {expect - len(results)} agent(s) produced no result "
            f"(journal has {len(results)}, usage reported {expect}) — a failed agent's item "
            f"was .filter(Boolean)'d out of the synthesis. Reconcile candidates-vs-verdicts.")

    empties = sum(1 for r in results if is_empty_result(r))
    if empties:
        gaps.append(f"{empties} result(s) empty/error payload — inspect before trusting synthesis.")

    cand, verd = candidate_verdict_diff(results)
    if cand and verd:
        verd_set = set(verd)
        dropped = [c for c in cand if c not in verd_set]
        # Only meaningful when there ARE verdicts to compare against.
        if len(dropped) and len(verd) >= max(1, len(cand) // 2):
            gaps.append(
                f"UN-ADJUDICATED: {len(dropped)} candidate(s) have no matching verdict "
                f"(judge a candidate by hand): {dropped[:8]}")

    print(f"results={len(results)} expected={expect} candidates={len(cand)} verdicts={len(verd)}")
    if gaps:
        for g in gaps:
            print("  ⚠️  " + g)
        return 1
    print("  ✓ no silent drops detected")
    return 0


if __name__ == "__main__":
    sys.exit(main())
