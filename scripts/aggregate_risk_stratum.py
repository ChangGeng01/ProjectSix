#!/usr/bin/env python3
"""chapter 二百六十二 / M745 — Mac-side stratum-aggregator for
ADR-012 Hybrid offline-pipeline.

附录 V Stage 4 Step 2 of 5. Reads bench JSONL across many sessions,
aggregates by stratum (tone × stake × confidant), strips host-
specific identifiers, emits a generalized stratum stats JSON the
operator reviews before producing a `BASRiskCalibrationBundle`.

## ADR-012 doctrine alignment

This script implements the **offline aggregation** step of ADR-012
(`docs/ARCHITECTURE_DECISION_RECORDS.md`):

  - Reads ONLY benchmark JSONL data (chapter 二百八 ADR-006
    observability source).
  - Strips session-specific / host-specific fields per
    chapter 一百零二 五级删除 + 不变量 #3:
      * NO `prompt` text
      * NO `timestamp`, `iteration`, `seed`
      * NO LLM body (any of `firstTriedBody`, `fallbackBody`,
        `body`, `response`, etc.)
      * NO `errorMessage` (may contain user input echoes)
      * NO any `*Ref` field (sessionRef, turnRef, etc.)
  - Outputs ONLY generalized signal: per-stratum row counts +
    per-stratum permitMode distribution + per-stratum LLM
    success/failure rates.
  - Output file is the input to a separate operator-decision step
    that produces a `BASRiskCalibrationBundle` (chapter 二百六十三).

This script does NOT auto-emit a bundle. It does NOT modify any
production state. It does NOT touch the substrate runtime. The
output JSON is decision support — the operator decides whether
the deltas justify a bundle ship.

## Usage

```sh
# Aggregate one session's bench output
/tmp/coreml-py312/bin/python3 scripts/aggregate_risk_stratum.py \\
    --input /tmp/iphone-rawllm-pull/ \\
    --output /tmp/risk-stratum-aggregate-2026-05-07.json

# Aggregate multiple sessions' bench outputs (e.g. monthly rollup)
/tmp/coreml-py312/bin/python3 scripts/aggregate_risk_stratum.py \\
    --input /tmp/iphone-rawllm-pull/ \\
            /tmp/iphone-hybrid-bench-2026-05/ \\
            /tmp/cross-device-bench-2026-04/ \\
    --output /tmp/risk-stratum-aggregate-monthly.json

# Specific stratum keys (default: tone × stake × confidant)
/tmp/coreml-py312/bin/python3 scripts/aggregate_risk_stratum.py \\
    --input /tmp/iphone-rawllm-pull/ \\
    --stratum-keys tone stake \\
    --output /tmp/risk-stratum-tone-stake.json
```

## Doctrine pins

- **不变量 #2 神经不掌权**: this script is observability-only;
  does NOT mutate any permit decision; output is decision-support
  for operator review.
- **不变量 #3 私有经验不进权重**: host-specific fields are
  STRIPPED before aggregation. Only stratum keys + counts survive.
- **ADR-006 strict**: bench data is observability ONLY at per-
  turn scope. ADR-012 permits this between-deploy aggregation
  but the script's output is itself observability — operator
  must explicitly produce a bundle (chapter 二百六十三+) and
  ship it (chapter 二百六十四+) to affect any decision.
- **chapter 一百零二 五级删除**: if a row's `forgetMarker` field
  indicates user-revoked data, the script must skip it. (Until
  bench JSONL carries that field, the input is assumed clean —
  operators are responsible for filtering revoked sessions out
  of their input directories before aggregation.)
- **Anti-magic-number**: stratum keys, default thresholds, and
  forbidden-field allowlist all named constants.

## Honest scope limit

This is the **infrastructure** chapter. Stratum delta computation
+ bundle creation are chapters 二百六十三 + 二百六十四. The output
of this script is per-stratum stats, NOT threshold deltas. The
operator reads the stats and decides whether to author a bundle.
That decision step is intentionally manual + human-in-the-loop per
ADR-012.
"""

from __future__ import annotations

import argparse
import json
import os
import sys
from collections import Counter, defaultdict
from datetime import datetime
from glob import glob
from pathlib import Path
from typing import Any, Iterator

# ----- Anti-magic-number constants -----

#: Default stratum keys per chapter 一百七十六 / 一百九十 analysis —
#: these three signature dimensions had the highest signal in
#: chapter 174 + chapter 178 bench analysis.
DEFAULT_STRATUM_KEYS: tuple[str, ...] = (
    "tone", "stake", "confidant"
)

#: Allowed signature dimensions per `SampleHostPromptSignature`
#: definition (`SampleHost/SampleHostPromptTypes.swift:76`).
#: Misspelled stratum keys at the CLI fail loudly rather than
#: silently producing the empty distribution.
VALID_STRATUM_KEYS: frozenset[str] = frozenset({
    "tone", "domain", "stake",
    "timeframe", "confidant", "askShape"
})

#: Fields the aggregator is FORBIDDEN to copy into output JSON
#: per ADR-012 + 不变量 #3. Any row dict key in this set is
#: dropped before aggregation. Allowlist-style filtering would be
#: stricter but the schema evolves; this denylist captures the
#: known leakage vectors per chapter 一百八十五 / 一百九十一
#: schema bumps.
FORBIDDEN_OUTPUT_FIELDS: frozenset[str] = frozenset({
    # User-input echoes
    "prompt",
    "errorMessage",
    # LLM body fields (any name variant the schema has used
    # historically — chapter 一百八十五+ bench-row schema renames)
    "firstTriedBody", "fallbackBody",
    "body", "response", "completion",
    # Per-iter identifiers
    "timestamp", "iteration", "seed", "stride",
    "mutationSeed", "rowChecksum",
    # Session / turn / user refs
    "sessionRef", "turnRef", "hostRef",
    "userRef", "deviceRef",
    # Anything ending in `Ref` is suspicious — the script's
    # output filter will warn on rows that have unexpected
    # *Ref fields.
})

#: Minimum row count for a stratum to be emitted as a stratum
#: stat. Strata with fewer rows are coalesced into "low_signal"
#: aggregate to avoid leakage via small-cell statistics.
MIN_STRATUM_COUNT_FOR_EMIT: int = 5

# ----- Argument parsing -----


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(
        prog="aggregate_risk_stratum",
        description=(
            "ADR-012 Hybrid offline-pipeline stratum aggregator. "
            "Reads bench JSONL, aggregates by stratum, strips "
            "host-specific identifiers, emits generalized stats. "
            "Output is decision-support for operator-authored "
            "BASRiskCalibrationBundle (chapter 二百六十三+)."
        ))
    p.add_argument(
        "--input",
        nargs="+",
        required=True,
        help=(
            "Input directories containing bench JSONL. Multiple "
            "directories are concatenated (useful for monthly "
            "rollup across many sessions)."))
    p.add_argument(
        "--output",
        required=True,
        help=(
            "Path to write aggregated stratum stats as JSON."))
    p.add_argument(
        "--stratum-keys",
        nargs="+",
        default=list(DEFAULT_STRATUM_KEYS),
        help=(
            "Signature dimensions to aggregate by. Default: "
            f"{DEFAULT_STRATUM_KEYS}. Valid keys: "
            f"{sorted(VALID_STRATUM_KEYS)}."))
    p.add_argument(
        "--min-stratum-count",
        type=int,
        default=MIN_STRATUM_COUNT_FOR_EMIT,
        help=(
            "Minimum row count for a stratum to be emitted "
            "(small cells are coalesced into 'low_signal'). "
            f"Default: {MIN_STRATUM_COUNT_FOR_EMIT}."))
    p.add_argument(
        "--strict",
        action="store_true",
        help=(
            "If set, raise on rows with unexpected fields. "
            "Off by default — unexpected fields are warned + "
            "dropped."))
    return p.parse_args()


# ----- Row reading -----


def iter_jsonl(path: Path) -> Iterator[dict[str, Any]]:
    """Yield rows from a single JSONL file. Skips blank lines
    and lines that don't parse (with stderr warning) — bench
    JSONL is sometimes truncated at end of session."""
    with path.open("r", encoding="utf-8") as fh:
        for lineno, line in enumerate(fh, start=1):
            line = line.strip()
            if not line:
                continue
            try:
                yield json.loads(line)
            except json.JSONDecodeError as e:
                print(
                    f"[warn] {path}:{lineno} skipped: {e}",
                    file=sys.stderr)


def all_jsonl_files(input_dirs: list[str]) -> list[Path]:
    """Recursive glob for `*.jsonl` across all input directories.
    Returns a sorted unique list."""
    files: set[Path] = set()
    for d in input_dirs:
        d_path = Path(d).expanduser()
        if not d_path.is_dir():
            print(
                f"[warn] input '{d}' is not a directory; "
                "skipping.",
                file=sys.stderr)
            continue
        for f in d_path.rglob("*.jsonl"):
            if f.is_file():
                files.add(f.resolve())
    return sorted(files)


# ----- Stratum extraction + aggregation -----


def stratum_key(
    row: dict[str, Any], keys: tuple[str, ...]
) -> tuple[str, ...]:
    """Build stratum tuple from row's signature dict. Missing
    fields default to "_unknown" so rows from older schemas
    don't disappear silently."""
    sig = row.get("signature", {}) or {}
    return tuple(str(sig.get(k, "_unknown")) for k in keys)


def extract_safe_outcome(row: dict[str, Any]) -> dict[str, Any]:
    """Keep only the fields needed for stratum stats. Strip
    anything that could carry host-specific signal."""
    return {
        "permitMode": str(row.get("permitMode", "_unknown")),
        "firstTriedLLM": str(
            row.get("firstTriedLLM", "_unknown")),
        "firstTriedStatus": str(
            row.get("firstTriedStatus", "_unknown")),
        "actualRoute": str(row.get("actualRoute", "_unknown")),
        "routerHit": bool(row.get("routerHit", False)),
        "llmSkipped": bool(row.get("llmSkipped", False)),
        "smokeMode": str(row.get("smokeMode", "_unknown")),
    }


def warn_on_unexpected_fields(
    row: dict[str, Any], strict: bool
) -> None:
    """Detect rows that contain fields the aggregator did not
    expect (could indicate schema drift or accidental leakage).
    In strict mode, raises; otherwise warns."""
    suspicious = [
        k for k in row.keys()
        if (k.endswith("Ref") and k != "schemaVersion")
        and k not in FORBIDDEN_OUTPUT_FIELDS
    ]
    if suspicious:
        msg = (f"row has unexpected *Ref fields: {suspicious}; "
               "those are dropped (forbidden by ADR-012)")
        if strict:
            raise RuntimeError(msg)
        print(f"[warn] {msg}", file=sys.stderr)


def aggregate(
    files: list[Path],
    *,
    stratum_keys: tuple[str, ...],
    min_stratum_count: int,
    strict: bool,
) -> dict[str, Any]:
    """Read all files, aggregate per-stratum stats, return a
    dict shaped for JSON serialization."""
    # Per-stratum counters (tuple key → counters)
    stratum_total: Counter[tuple[str, ...]] = Counter()
    stratum_permit: defaultdict[
        tuple[str, ...], Counter[str]
    ] = defaultdict(Counter)
    stratum_llm_first: defaultdict[
        tuple[str, ...], Counter[str]
    ] = defaultdict(Counter)
    stratum_llm_status: defaultdict[
        tuple[str, ...], Counter[str]
    ] = defaultdict(Counter)
    stratum_router_hits: Counter[tuple[str, ...]] = Counter()
    stratum_skipped: Counter[tuple[str, ...]] = Counter()

    total_rows = 0
    skipped_rows = 0
    for f in files:
        for row in iter_jsonl(f):
            total_rows += 1
            warn_on_unexpected_fields(row, strict)
            # Forbidden-field denylist enforcement: even if the
            # caller passed non-allowed *Ref keys, we never emit
            # them. (Defensive — actual emission happens below
            # in `emit_safe_outcome`.)
            key = stratum_key(row, stratum_keys)
            outcome = extract_safe_outcome(row)
            stratum_total[key] += 1
            stratum_permit[key][outcome["permitMode"]] += 1
            stratum_llm_first[key][
                outcome["firstTriedLLM"]] += 1
            stratum_llm_status[key][
                outcome["firstTriedStatus"]] += 1
            if outcome["routerHit"]:
                stratum_router_hits[key] += 1
            if outcome["llmSkipped"]:
                stratum_skipped[key] += 1

    # Coalesce small-signal strata to avoid small-cell leakage
    coalesced_low_signal = Counter()
    coalesced_low_signal_permit: Counter[str] = Counter()
    coalesced_low_signal_llm_first: Counter[str] = Counter()
    coalesced_low_signal_llm_status: Counter[str] = Counter()
    coalesced_router_hits = 0
    coalesced_skipped = 0

    emitted_strata: list[dict[str, Any]] = []
    for key, count in stratum_total.most_common():
        if count >= min_stratum_count:
            emitted_strata.append({
                "stratum": dict(zip(stratum_keys, key)),
                "rowCount": count,
                "permitMode": dict(stratum_permit[key]),
                "firstTriedLLM": dict(stratum_llm_first[key]),
                "firstTriedStatus": dict(
                    stratum_llm_status[key]),
                "routerHits": stratum_router_hits[key],
                "llmSkipped": stratum_skipped[key],
            })
        else:
            coalesced_low_signal["count"] += count
            coalesced_low_signal_permit.update(
                stratum_permit[key])
            coalesced_low_signal_llm_first.update(
                stratum_llm_first[key])
            coalesced_low_signal_llm_status.update(
                stratum_llm_status[key])
            coalesced_router_hits += stratum_router_hits[key]
            coalesced_skipped += stratum_skipped[key]

    # Provenance metadata: file count, total rows, date range
    # (file mtime — not row-level since timestamps are stripped).
    file_mtimes = [
        datetime.fromtimestamp(f.stat().st_mtime).isoformat()
        for f in files
    ]
    provenance = {
        "fileCount": len(files),
        "totalRows": total_rows,
        "skippedRows": skipped_rows,
        "stratumKeys": list(stratum_keys),
        "minStratumCount": min_stratum_count,
        "fileMtimeRange": {
            "earliest": min(file_mtimes) if file_mtimes else None,
            "latest": max(file_mtimes) if file_mtimes else None,
        },
        "generatedAt": datetime.now().isoformat(),
        "doctrine": "ADR-012",
    }

    return {
        "provenance": provenance,
        "strata": emitted_strata,
        "lowSignalCoalesced": {
            "rowCount": coalesced_low_signal["count"],
            "permitMode": dict(coalesced_low_signal_permit),
            "firstTriedLLM": dict(
                coalesced_low_signal_llm_first),
            "firstTriedStatus": dict(
                coalesced_low_signal_llm_status),
            "routerHits": coalesced_router_hits,
            "llmSkipped": coalesced_skipped,
        },
    }


# ----- Main -----


def main() -> int:
    args = parse_args()

    # Validate stratum keys
    invalid = [
        k for k in args.stratum_keys if k not in VALID_STRATUM_KEYS
    ]
    if invalid:
        print(
            f"[error] unknown stratum keys: {invalid}. Valid: "
            f"{sorted(VALID_STRATUM_KEYS)}",
            file=sys.stderr)
        return 2

    files = all_jsonl_files(args.input)
    if not files:
        print(
            f"[error] no .jsonl files found in {args.input}",
            file=sys.stderr)
        return 3

    print(f"[info] processing {len(files)} JSONL files")

    aggregate_data = aggregate(
        files,
        stratum_keys=tuple(args.stratum_keys),
        min_stratum_count=args.min_stratum_count,
        strict=args.strict)

    # Write output
    out_path = Path(args.output).expanduser()
    out_path.parent.mkdir(parents=True, exist_ok=True)
    with out_path.open("w", encoding="utf-8") as fh:
        json.dump(aggregate_data, fh, indent=2, sort_keys=True)
    print(f"[info] wrote stratum aggregate to {out_path}")

    # Summary report to stdout
    prov = aggregate_data["provenance"]
    n_strata = len(aggregate_data["strata"])
    low_signal = aggregate_data["lowSignalCoalesced"]["rowCount"]
    print(
        f"[summary] total rows: {prov['totalRows']} / "
        f"strata: {n_strata} ≥{args.min_stratum_count}-row / "
        f"coalesced low-signal: {low_signal} rows")
    return 0


if __name__ == "__main__":
    sys.exit(main())
