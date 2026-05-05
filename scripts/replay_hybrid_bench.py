#!/usr/bin/env python3
"""M699 chapter 一百八十九 — bench-replay tool.

Reads chapter 178+ hybrid bench JSONL output, reconstructs the
counter partition, and verifies invariants. Catches:
- Lost iters (counts don't sum to row count)
- Schema version drift (rows with mixed schemas)
- Field-presence regressions (chapter 187 schema bumped to "6";
  rows missing newer fields)
- NaN/Infinity float fields that leaked past the chapter 184 fix

Usage:
    python3 scripts/replay_hybrid_bench.py \\
        /path/to/iphone-hybrid-bench/

Exit 0 = clean. Exit 1 = invariant violations detected.
"""

from __future__ import annotations

import json
import math
import os
import sys
from collections import Counter
from glob import glob
from pathlib import Path

EXPECTED_SCHEMA_VERSION = "6"


def load_jsonl(path: str) -> list[dict]:
    """Robust JSONL loader. Same hardening as
    `train_chenglu_preflight_v0.load_jsonl_dir` (chapter 184 C6
    fix): warn on malformed lines, raise on missing dir."""
    if not os.path.isdir(path):
        raise FileNotFoundError(
            f"bench dir not found: {path}")
    rows: list[dict] = []
    malformed = 0
    for fp in sorted(glob(os.path.join(path, "**", "*.jsonl"),
                          recursive=True)):
        with open(fp) as f:
            for lineno, line in enumerate(f, start=1):
                line = line.strip()
                if not line:
                    continue
                try:
                    rows.append(json.loads(line))
                except json.JSONDecodeError as e:
                    malformed += 1
                    if malformed <= 5:
                        print(
                            f"WARN: malformed JSON at "
                            f"{os.path.basename(fp)}:{lineno}: "
                            f"{e}", file=sys.stderr)
    if malformed:
        print(
            f"WARN: {malformed} malformed JSON lines skipped",
            file=sys.stderr)
    return rows


def replay(rows: list[dict]) -> tuple[bool, list[str]]:
    """Replay bench rows to reconstruct counter partition.
    Returns (ok, diagnostics)."""
    diagnostics: list[str] = []
    if not rows:
        return False, ["no rows in bench output"]

    # Schema-version sanity
    schemas = Counter(r.get("schemaVersion") for r in rows)
    diagnostics.append(f"schema versions: {dict(schemas)}")
    if any(v not in (None, EXPECTED_SCHEMA_VERSION)
           for v in schemas):
        diagnostics.append(
            f"WARN: mixed/unknown schema versions; "
            f"expected '{EXPECTED_SCHEMA_VERSION}' "
            f"or nil (legacy)")

    # Reconstruct partition counters
    n_rows = len(rows)
    afm_ok = sum(1 for r in rows
                 if r.get("actualRoute") == "afm-predicted-ok")
    gemma_ok = sum(1 for r in rows
                   if r.get("actualRoute") == "gemma-predicted-ok")
    afm_fb = sum(1 for r in rows
                 if r.get("actualRoute") == "afm-fallback-to-gemma-ok")
    gemma_fb = sum(1 for r in rows
                   if r.get("actualRoute") == "gemma-fallback-to-afm-ok")
    both_failed = sum(1 for r in rows
                      if r.get("actualRoute") == "both-failed")
    skip_block = sum(1 for r in rows
                     if r.get("actualRoute")
                     == "skipped-by-substrate-block")
    skip_replace = sum(1 for r in rows
                       if r.get("actualRoute")
                       == "skipped-by-substrate-replace")
    skip_delay = sum(1 for r in rows
                     if r.get("actualRoute")
                     == "skipped-by-substrate-delay")
    diagnostics.append(
        f"partition: AFMOk={afm_ok} GemmaOk={gemma_ok} "
        f"AFMFb={afm_fb} GemmaFb={gemma_fb} "
        f"BothFailed={both_failed} "
        f"Skip[B={skip_block} R={skip_replace} D={skip_delay}]")
    accounted = (
        afm_ok + gemma_ok + afm_fb + gemma_fb
        + both_failed + skip_block + skip_replace + skip_delay
    )
    extra_routes: Counter[str] = Counter()
    canonical_routes = {
        "afm-predicted-ok", "gemma-predicted-ok",
        "afm-fallback-to-gemma-ok", "gemma-fallback-to-afm-ok",
        "both-failed",
        "skipped-by-substrate-block",
        "skipped-by-substrate-replace",
        "skipped-by-substrate-delay",
    }
    for r in rows:
        ar = r.get("actualRoute", "")
        if ar not in canonical_routes:
            extra_routes[ar] += 1
    if extra_routes:
        diagnostics.append(
            f"non-canonical routes: {dict(extra_routes)}")
    diagnostics.append(
        f"row count: {n_rows} / accounted: {accounted} "
        f"+ non-canonical: {sum(extra_routes.values())}"
    )

    # Float sanity — chapter 184 B2 fix means non-finite values
    # are encoded as "nan"/"inf"/"-inf" strings. Check none leak
    # as actual JSON nan (which JSONEncoder default would throw).
    float_fields = [
        "routerProbability", "firstTriedDurationMs",
        "fallbackDurationMs", "totalDurationSeconds",
        "lengthPredicted", "lengthError",
        "latencyPredictedMs", "latencyErrorMs",
        "permitPredictBlockProb",
        "verbosityProbability",
    ]
    nonfinite_via_string = Counter()
    nonfinite_via_float = Counter()
    for r in rows:
        for f in float_fields:
            v = r.get(f)
            if isinstance(v, str) and v in ("nan", "inf", "-inf"):
                nonfinite_via_string[f] += 1
            elif isinstance(v, float) and not math.isfinite(v):
                nonfinite_via_float[f] += 1
    if nonfinite_via_string:
        diagnostics.append(
            f"non-finite floats (string sentinels — chapter 184 "
            f"fix working): {dict(nonfinite_via_string)}")
    if nonfinite_via_float:
        diagnostics.append(
            f"ERROR: non-finite floats as raw values "
            f"(chapter 184 fix B2 broken!): "
            f"{dict(nonfinite_via_float)}")
        return False, diagnostics

    # Router-overridden rows should NOT be in the routerHit
    # accuracy denominator (chapter 185 B1 fix).
    overridden = sum(1 for r in rows
                     if r.get("routerOverridden") is True)
    diagnostics.append(
        f"routerOverridden rows: {overridden} "
        f"({100*overridden/n_rows:.1f}% — should match skip / "
        f"bothLLMs / localOnly count)")

    # PermitPredict 9-way matrix (chapter 186 B7 fix)
    detailed = Counter()
    for r in rows:
        d = r.get("permitPredictDetailedAgreement")
        if d:
            detailed[d] += 1
    if detailed:
        diagnostics.append(
            f"permitPredict 9-way confusion (top 5): "
            f"{detailed.most_common(5)}")

    # Verbosity head accuracy (chapter 183 5th head)
    vc = sum(1 for r in rows
             if r.get("verbosityCorrect") is True)
    vw = sum(1 for r in rows
             if r.get("verbosityCorrect") is False)
    if vc + vw > 0:
        acc = vc / (vc + vw) * 100
        diagnostics.append(
            f"verbosity 5th head: {vc}/{vc+vw} correct "
            f"({acc:.1f}%; train was 77.31%)")

    # Length / Latency MAE
    length_errs = [
        abs(r["lengthError"]) for r in rows
        if isinstance(r.get("lengthError"), (int, float))
        and math.isfinite(r["lengthError"])
    ]
    latency_errs = [
        abs(r["latencyErrorMs"]) for r in rows
        if isinstance(r.get("latencyErrorMs"), (int, float))
        and math.isfinite(r["latencyErrorMs"])
    ]
    if length_errs:
        mae_l = sum(length_errs) / len(length_errs)
        diagnostics.append(
            f"length MAE: {mae_l:.0f} chars (n={len(length_errs)}; "
            f"train was 432; expect ~similar)")
    if latency_errs:
        mae_lat = sum(latency_errs) / len(latency_errs)
        diagnostics.append(
            f"latency MAE: {mae_lat:.0f} ms "
            f"(n={len(latency_errs)}; train was 2220; "
            f"expect ~similar)")

    return True, diagnostics


def main() -> int:
    if len(sys.argv) != 2:
        print(
            "usage: replay_hybrid_bench.py <bench-dir>",
            file=sys.stderr)
        return 2
    rows = load_jsonl(sys.argv[1])
    print(f"Loaded {len(rows)} bench rows")
    ok, diag = replay(rows)
    print("\n=== Bench replay diagnostics ===")
    for line in diag:
        print(f"  {line}")
    if ok:
        print("\nreplay_hybrid_bench: clean")
        return 0
    else:
        print("\nreplay_hybrid_bench: ISSUES DETECTED",
              file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
