#!/usr/bin/env python3
"""M751 chapter 二百 — synthetic loop closure smoke generator.

Generates synthetic base-corpus + bench JSONL data in canonical
schema shapes so `bench_to_train.py` can run end-to-end without
needing real LLM responses. PURPOSE: validate the pipeline
mechanics (extract → augment → retrain → emit .mlpackage) work
end-to-end, NOT to produce a useful model.

Doctrine: synthetic data is mechanically valid (correct schema,
plausible values) but NOT statistically representative of real
LLM behavior. v0.5_synthetic.mlpackage will pass shape tests but
should NEVER be bundled into the production app.

Usage:
    python3 scripts/synthesize_corpus.py \\
        --base-out /tmp/synthetic-base/ \\
        --bench-out /tmp/synthetic-bench/ \\
        --base-rows 200 \\
        --bench-rows 200
"""

from __future__ import annotations

import argparse
import json
import os
import random
import sys
import time
from datetime import datetime, timedelta, timezone
from pathlib import Path

sys.path.insert(0, os.path.dirname(__file__))
from chenglu_feature_schema import (  # noqa: E402
    TONES, DOMAINS, STAKES, TIMEFRAMES, CONFIDANTS, ASKSHAPES,
    MUTATIONS, VERBOSITY_THRESHOLD_CHARS,
)

# Plausible LLM body templates so afmBodyLength varies.
BODY_SHORT = "Brief acknowledgment of the question."
BODY_MEDIUM = " ".join([BODY_SHORT] * 25)        # ~1000 chars
BODY_LONG = " ".join([BODY_MEDIUM] * 3)          # ~3000 chars

PERMIT_MODES = [
    "answer", "delay", "block", "compare", "escalate",
    "mirror", "replace", "draft_only", "local_only",
]

THERMAL_STATES = ["nominal", "fair", "serious", "critical"]


def make_signature(rng: random.Random) -> dict:
    return {
        "tone": rng.choice(TONES),
        "domain": rng.choice(DOMAINS),
        "stake": rng.choice(STAKES),
        "timeframe": rng.choice(TIMEFRAMES),
        "confidant": rng.choice(CONFIDANTS),
        "askShape": rng.choice(ASKSHAPES),
    }


def make_base_row(rng: random.Random, idx: int) -> dict:
    """chapter 175/176-style train_row shape. bench_to_train.py's
    load_jsonl_dir returns these as-is (no projection)."""
    sig = make_signature(rng)
    permit = rng.choices(
        PERMIT_MODES,
        weights=[40, 15, 15, 5, 3, 5, 5, 6, 6])[0]  # answer-heavy
    body_len_pick = rng.choices(
        [50, 1000, 3000], weights=[30, 50, 20])[0]
    return {
        "signature": sig,
        "mutationSeed": rng.choice(MUTATIONS),
        "permitMode": permit,
        "afmStatus": "ok" if rng.random() < 0.85
            else rng.choice(["guardrailViolation", "afmTimeout"]),
        "afmBodyLength": body_len_pick + rng.randint(-50, 50),
        "afmDurationMs": rng.uniform(1500, 8000),
        "thermalState": rng.choices(
            THERMAL_STATES, weights=[40, 30, 25, 5])[0],
        "batteryLevel": rng.uniform(0.3, 1.0),
        "lowPowerMode": rng.random() < 0.1,
        "hourOfDay": rng.randint(0, 23),
    }


def make_bench_row(rng: random.Random, idx: int) -> dict:
    """chapter 192 schema v9 hybrid bench row. Must have non-empty
    firstTriedBody + llmSkipped=false to pass
    bench_row_to_train_row's projection filter."""
    sig = make_signature(rng)
    body = rng.choices(
        [BODY_SHORT, BODY_MEDIUM, BODY_LONG],
        weights=[20, 60, 20])[0]
    base_iso = datetime.now(timezone.utc).isoformat()
    permit = rng.choices(
        PERMIT_MODES,
        weights=[50, 10, 10, 5, 3, 10, 5, 4, 3])[0]
    return {
        "schemaVersion": "9",
        "timestamp": base_iso,
        "iteration": idx,
        "seed": idx,
        "stride": 5041,
        "mutationSeed": rng.choice(MUTATIONS),
        "signature": sig,
        "prompt": f"Synthetic prompt {idx}",
        "auditCodeCount": rng.randint(80, 200),
        "permitMode": permit,
        "routerVersion": "v0.4-synthetic",
        "routerPredictedRoute": rng.choice(["afm", "gemma"]),
        "routerProbability": rng.random(),
        "firstTriedLLM": "afm",
        "firstTriedStatus": "ok",
        "firstTriedBody": body,
        "firstTriedDurationMs": rng.uniform(1500, 8000),
        "fallbackTriedLLM": None,
        "fallbackStatus": None,
        "fallbackBody": None,
        "fallbackDurationMs": None,
        "actualRoute": "afm-predicted-ok",
        "routerHit": True,
        "totalDurationSeconds": rng.uniform(0.05, 0.2),
        "errorMessage": None,
        "dispatchPolicy": "single-llm",
        "dispatchTaken": "single-llm",
        "draftOnly": False,
        "llmSkipped": False,
        "postLLMPermitMode": permit,
        "postLLMAuditCodeCount": rng.randint(80, 200),
        "postLLMShifted": False,
        "permitPredictBlockProb": rng.random() * 0.5,
        "permitPredictClass":
            "block" if permit == "block" else "non-block",
        "permitPredictAgreement": True,
        "permitPredictDetailedAgreement":
            f"non-block:{permit}" if permit != "block"
            else "block:block",
        "routerOverridden": False,
        "lengthPredicted": rng.uniform(800, 2500),
        "lengthError": rng.uniform(-300, 300),
        "latencyPredictedMs": rng.uniform(2000, 6000),
        "latencyErrorMs": rng.uniform(-500, 500),
        "verbosityProbability":
            0.7 if len(body) > VERBOSITY_THRESHOLD_CHARS else 0.3,
        "verbosityCorrect": True,
        "thermalState": rng.choices(
            THERMAL_STATES, weights=[40, 30, 25, 5])[0],
        "batteryLevel": rng.uniform(0.3, 1.0),
        "lowPowerMode": rng.random() < 0.1,
        "hourOfDay": rng.randint(0, 23),
        "smokeMode": "canonical",
        "targetLayer": None,
        "targetLayerName": None,
        "anomalyFlags": None,
        "pressureProfile": None,
        "adversarialKind": None,
        "driftSigma": None,
        "pauseSkipped": False,
        # rowChecksum omitted — added by Swift encodeHybrid in
        # production; bench_to_train doesn't read it.
    }


def write_jsonl(rows: list[dict], out_dir: Path,
                shard_name: str) -> None:
    out_dir.mkdir(parents=True, exist_ok=True)
    path = out_dir / shard_name
    with path.open("w") as f:
        for r in rows:
            f.write(json.dumps(r) + "\n")
    print(f"  wrote {len(rows)} rows → {path}")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--base-out", required=True)
    parser.add_argument("--bench-out", required=True)
    parser.add_argument("--base-rows", type=int, default=200)
    parser.add_argument("--bench-rows", type=int, default=200)
    parser.add_argument("--seed", type=int, default=42)
    args = parser.parse_args()

    rng = random.Random(args.seed)
    print(f"=== synthesize_corpus.py (seed={args.seed}) ===")

    base_rows = [make_base_row(rng, i)
                 for i in range(args.base_rows)]
    write_jsonl(base_rows, Path(args.base_out),
                "synthetic-base.jsonl")

    bench_rows = [make_bench_row(rng, i)
                  for i in range(args.bench_rows)]
    write_jsonl(bench_rows, Path(args.bench_out),
                "synthetic-bench.jsonl")

    print(f"\nDone. {args.base_rows} base + {args.bench_rows} "
          f"bench rows generated.")
    print(f"\nNext step: ")
    print(f"  python3 scripts/bench_to_train.py \\")
    print(f"    --base-corpus {args.base_out} \\")
    print(f"    --bench {args.bench_out} \\")
    print(f"    --output /tmp/ChengluMultiHead_v0_5_synthetic.mlpackage \\")
    print(f"    --require-bench-rows 50")
    return 0


if __name__ == "__main__":
    sys.exit(main())
