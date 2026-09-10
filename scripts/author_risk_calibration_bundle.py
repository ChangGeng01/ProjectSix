#!/usr/bin/env python3
"""chapter 二百五十九 / M752 — operator review CLI for authoring
`BASRiskCalibrationBundle` JSON.

附录 V Stage 4 — operator decision-support tool. Reads
chapter 二百六十二 stratum aggregate JSON; prompts the operator
for per-stratum threshold deltas; emits a typed
`BASRiskCalibrationBundle` JSON the host can hand to
`BASRiskCalibrationGate.replace(_:)` (chapter 二百六十四).

The bundle authoring is **operator decision** per ADR-012.
This CLI does NOT auto-derive deltas from stats — operators
read the stats and decide. The CLI's job is:

  1. Show stats per stratum so the operator can see the
     distribution
  2. Walk the operator through entering deltas + warrant ref
     interactively (or accept an input JSON)
  3. Emit the typed bundle JSON for substrate-side consumption

## Usage

```sh
# Interactive mode — prompts operator for each stratum
/tmp/coreml-py312/bin/python3 \\
    scripts/author_risk_calibration_bundle.py \\
    --aggregate /tmp/risk-stratum-aggregate-2026-05-07.json \\
    --bundle-version v1.0.0 \\
    --warrant-ref warrant:abc123 \\
    --output /tmp/calibration-bundle-v1.0.0.json

# Non-interactive mode — accept deltas via JSON
/tmp/coreml-py312/bin/python3 \\
    scripts/author_risk_calibration_bundle.py \\
    --aggregate /tmp/risk-stratum-aggregate-2026-05-07.json \\
    --deltas-input /tmp/operator-deltas.json \\
    --bundle-version v1.0.0 \\
    --warrant-ref warrant:abc123 \\
    --output /tmp/calibration-bundle-v1.0.0.json
```

`--deltas-input` JSON shape:

```json
{
  "deltas": [
    {
      "stratumKey": "tone=angry|stake=high|confidant=public",
      "mediumThresholdDelta": -0.05,
      "highThresholdDelta": 0.0,
      "extremeThresholdDelta": 0.0,
      "evidenceRowCount": 500,
      "reasonCodes": ["rollup:apr", "review:claude-prim"]
    }
  ],
  "supersedesBundleVersion": null,
  "summary": "April rollup — lower medium threshold for high-stake angry"
}
```

## Doctrine pins

- **不变量 #2 神经不掌权**: bundle is operator-authored. CLI
  doesn't auto-derive deltas — operator reviews stats + decides.
- **不变量 #3 私有经验不进权重**: stratum keys are generalized
  signals (tone × stake × confidant). Stats input was already
  filtered by chapter 二百六十二 aggregator.
- **ADR-012**: bundle is between-deploy mutation. CLI emits a
  candidate JSON; operator integrates explicitly via Swift code
  (or a host-supplied loader).
- **chapter 一百十三 anti-magic-number**: clamping bounds match
  Swift-side `BASRiskCalibrationStratumDelta.maximumAbsoluteDelta`
  (0.25). Documented; CLI rejects out-of-range input with an
  error message naming the constant.

## Honest scope limit

This is **decision support** — the operator still makes the
calibration decision. The CLI's typed JSON output matches
`BASRiskCalibrationBundle` Codable property names so an
operator can read the JSON, copy values into Swift code, and
construct a `BASRiskCalibrationBundle(...)` directly.

**Date format note**: CLI emits `producedAt` as ISO-8601 UTC
string; Swift's `JSONDecoder` default treats `Date` as
`timeIntervalSinceReferenceDate` Double. Hosts that want to
deserialize the CLI output directly via `JSONDecoder` must
configure `decoder.dateDecodingStrategy = .iso8601`. The typical
workflow is operator inspection → Swift code construction, NOT
auto-deserialization, so this is a documentation note rather
than a strict compatibility break.
"""

from __future__ import annotations

import argparse
import json
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

# ----- Anti-magic-number constants -----

#: Match Swift-side BASRiskCalibrationStratumDelta.maximumAbsoluteDelta
MAXIMUM_ABSOLUTE_DELTA: float = 0.25

#: Match Swift-side BASRiskCalibrationBundle.currentSchemaVersion
BUNDLE_SCHEMA_VERSION: str = "1.0.0"

#: Match Swift-side BASRiskCalibrationStratumDelta.currentSchemaVersion
DELTA_SCHEMA_VERSION: str = "1.0.0"


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(
        prog="author_risk_calibration_bundle",
        description=(
            "ADR-012 operator review CLI for authoring "
            "BASRiskCalibrationBundle JSON. Reads stratum "
            "aggregate stats; emits a typed bundle JSON the "
            "host substrate can deserialize."
        ))
    p.add_argument(
        "--aggregate",
        required=True,
        help=(
            "Path to chapter 二百六十二 aggregate JSON "
            "(scripts/aggregate_risk_stratum.py output)."))
    p.add_argument(
        "--bundle-version",
        required=True,
        help=(
            "Monotonic bundle version string, e.g. v1.0.0. "
            "Must be strictly greater than the prior bundle "
            "version when deployed via gate.replace(_:)."))
    p.add_argument(
        "--warrant-ref",
        required=True,
        help=(
            "L14 sovereign warrant reference. Required by "
            "ADR-012; the L11 gate rejects bundles with empty "
            "warrant refs."))
    p.add_argument(
        "--output",
        required=True,
        help="Path to write the bundle JSON.")
    p.add_argument(
        "--deltas-input",
        default=None,
        help=(
            "Optional JSON file with operator-supplied deltas. "
            "If absent, CLI runs interactively. Format: "
            "{\"deltas\": [...], \"supersedesBundleVersion\": "
            "\"v0.X\", \"summary\": \"...\"}"))
    p.add_argument(
        "--supersedes",
        default=None,
        help=(
            "Optional supersedesBundleVersion. If set + "
            "non-empty, the produced bundle declares it "
            "supersedes a specific prior version."))
    p.add_argument(
        "--summary",
        default="",
        help="Optional human-readable summary.")
    return p.parse_args()


def validate_delta(
    raw: dict[str, Any], index: int
) -> dict[str, Any]:
    """Validate one delta dict; return cleaned copy or raise
    `RuntimeError` with operator-readable explanation."""
    required = {"stratumKey"}
    for key in required:
        if not raw.get(key):
            raise RuntimeError(
                f"delta #{index}: missing required field "
                f"'{key}'")

    medium = float(raw.get("mediumThresholdDelta", 0))
    high = float(raw.get("highThresholdDelta", 0))
    extreme = float(raw.get("extremeThresholdDelta", 0))
    for name, val in (
        ("mediumThresholdDelta", medium),
        ("highThresholdDelta", high),
        ("extremeThresholdDelta", extreme),
    ):
        if abs(val) > MAXIMUM_ABSOLUTE_DELTA:
            raise RuntimeError(
                f"delta #{index} {name}={val} exceeds "
                f"maximumAbsoluteDelta={MAXIMUM_ABSOLUTE_DELTA} "
                f"(Swift-side will clamp; reject here so the "
                "operator notices)")
    evidence = int(raw.get("evidenceRowCount", 0))
    if evidence < 0:
        raise RuntimeError(
            f"delta #{index} evidenceRowCount must be >= 0; "
            f"got {evidence}")
    reasons = raw.get("reasonCodes", []) or []
    if not isinstance(reasons, list):
        raise RuntimeError(
            f"delta #{index} reasonCodes must be a list; "
            f"got {type(reasons).__name__}")

    return {
        "schemaVersion": DELTA_SCHEMA_VERSION,
        "stratumKey": str(raw["stratumKey"]).strip(),
        "mediumThresholdDelta": medium,
        "highThresholdDelta": high,
        "extremeThresholdDelta": extreme,
        "evidenceRowCount": evidence,
        "reasonCodes": [str(r).strip() for r in reasons
                        if str(r).strip()],
    }


def interactive_prompt(
    aggregate: dict[str, Any]
) -> tuple[list[dict[str, Any]], str | None, str]:
    """Prompt the operator to enter deltas for each stratum
    visible in the aggregate. Returns (deltas, supersedes,
    summary)."""
    print(
        "[operator-review] interactive mode — enter deltas "
        "per stratum.")
    deltas: list[dict[str, Any]] = []
    strata = aggregate.get("strata", [])
    for i, s in enumerate(strata):
        key_dict = s.get("stratum", {})
        # Render stratum as canonical key (sorted keys for
        # deterministic format).
        stratum_key = "|".join(
            f"{k}={key_dict[k]}" for k in sorted(key_dict))
        permit_mode = s.get("permitMode", {})
        print(f"\n[{i+1}/{len(strata)}] stratum: {stratum_key}")
        print(f"  rowCount: {s.get('rowCount', 0)}")
        print(f"  permitMode: {permit_mode}")
        print(f"  routerHits: {s.get('routerHits', 0)} / "
              f"llmSkipped: {s.get('llmSkipped', 0)}")
        choice = input(
            "  enter deltas? [y/N] ").strip().lower()
        if choice != "y":
            continue
        try:
            medium = float(input(
                f"    mediumThresholdDelta "
                f"(±{MAXIMUM_ABSOLUTE_DELTA}, default 0): ")
                or "0")
            high = float(input(
                f"    highThresholdDelta "
                f"(±{MAXIMUM_ABSOLUTE_DELTA}, default 0): ")
                or "0")
            extreme = float(input(
                f"    extremeThresholdDelta "
                f"(±{MAXIMUM_ABSOLUTE_DELTA}, default 0): ")
                or "0")
        except ValueError as e:
            print(f"  [skip] invalid number: {e}")
            continue
        reasons_raw = input(
            "    reasonCodes (comma-separated, optional): "
        ).strip()
        reasons = [r.strip() for r in reasons_raw.split(",")
                   if r.strip()]
        deltas.append(validate_delta({
            "stratumKey": stratum_key,
            "mediumThresholdDelta": medium,
            "highThresholdDelta": high,
            "extremeThresholdDelta": extreme,
            "evidenceRowCount": s.get("rowCount", 0),
            "reasonCodes": reasons,
        }, i))
    print(f"\n[operator-review] {len(deltas)} deltas captured.")
    supersedes_raw = input(
        "supersedesBundleVersion (empty for none): ").strip()
    supersedes = supersedes_raw if supersedes_raw else None
    summary = input(
        "summary (free-form, optional): ").strip()
    return deltas, supersedes, summary


def main() -> int:
    args = parse_args()
    agg_path = Path(args.aggregate).expanduser()
    if not agg_path.is_file():
        print(
            f"[error] aggregate file not found: {agg_path}",
            file=sys.stderr)
        return 2
    with agg_path.open("r", encoding="utf-8") as fh:
        aggregate = json.load(fh)

    # Pull deltas either from --deltas-input or interactively.
    if args.deltas_input:
        deltas_path = Path(args.deltas_input).expanduser()
        if not deltas_path.is_file():
            print(
                f"[error] deltas-input file not found: "
                f"{deltas_path}",
                file=sys.stderr)
            return 3
        with deltas_path.open("r", encoding="utf-8") as fh:
            deltas_data = json.load(fh)
        try:
            deltas = [
                validate_delta(d, i)
                for i, d in enumerate(
                    deltas_data.get("deltas", []))
            ]
        except RuntimeError as e:
            print(f"[error] {e}", file=sys.stderr)
            return 4
        supersedes = deltas_data.get("supersedesBundleVersion")
        summary = deltas_data.get("summary", args.summary or "")
    else:
        try:
            deltas, supersedes, summary = interactive_prompt(
                aggregate)
        except (KeyboardInterrupt, EOFError):
            print("\n[abort] operator cancelled.",
                  file=sys.stderr)
            return 130

    # Per-CLI-arg overrides (CLI flag > file > interactive).
    if args.supersedes:
        supersedes = args.supersedes
    if args.summary:
        summary = args.summary

    # Compute aggregate provenance ref. Per ADR-012 this should
    # be a stable hash of the input JSON; for the CLI we use the
    # file-mtime-range from aggregate provenance + the file path
    # (operator can replace with a sha256 step in their own
    # tooling).
    prov = aggregate.get("provenance", {})
    file_mtime = prov.get("fileMtimeRange", {}).get(
        "latest", "unknown")
    aggregate_provenance_ref = (
        f"agg:{agg_path.name}:mtime-{file_mtime}"
    )

    # Build the bundle dict matching Swift Codable shape.
    bundle = {
        "schemaVersion": BUNDLE_SCHEMA_VERSION,
        "bundleVersion": args.bundle_version.strip(),
        "producedAt":
            datetime.now(timezone.utc).isoformat(),
        "aggregateProvenanceRef": aggregate_provenance_ref,
        "strataDeltas": deltas,
        "sovereignWarrantRef": args.warrant_ref.strip(),
        "supersedesBundleVersion": supersedes,
        "summary": summary,
    }

    # Self-validate isWellFormed (matches Swift-side rule).
    if not bundle["bundleVersion"]:
        print("[error] bundleVersion is empty",
              file=sys.stderr)
        return 5
    if bundle["bundleVersion"] == "v0.0.0-baseline":
        print(
            "[error] bundleVersion cannot be the baseline "
            "sentinel 'v0.0.0-baseline'",
            file=sys.stderr)
        return 6
    if not bundle["aggregateProvenanceRef"]:
        print("[error] aggregateProvenanceRef is empty",
              file=sys.stderr)
        return 7
    if not bundle["sovereignWarrantRef"]:
        print("[error] sovereignWarrantRef is empty",
              file=sys.stderr)
        return 8

    out_path = Path(args.output).expanduser()
    out_path.parent.mkdir(parents=True, exist_ok=True)
    with out_path.open("w", encoding="utf-8") as fh:
        json.dump(bundle, fh, indent=2, sort_keys=True)

    print(
        f"[info] wrote bundle to {out_path}\n"
        f"[summary] version {bundle['bundleVersion']} / "
        f"{len(deltas)} deltas / "
        f"warrant {bundle['sovereignWarrantRef']}\n"
        "Next: hosts deserialize via JSONDecoder().decode("
        "BASRiskCalibrationBundle.self, from: data) and pass "
        "to gate.replace(_:).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
