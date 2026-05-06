#!/usr/bin/env python3
"""chapter 二百五十七 / M743 — Mac-side bench-pull + retrain
orchestration.

附录 V Stage 3 Step 2 of 5 — closes the data-feedback loop
between iPhone real-bench output and Mac-side ChengluPreflight
retraining.

Pipeline (per chapter 一百七十七 / chapter 一百九十 / 附录 V V.6):

    iPhone runs --rawllm 8h bench
            ↓                       (chapter 二百五十六 — user action)
    devicectl pull JSONL → /tmp/iphone-rawllm-pull/
            ↓                       (this script, step 1)
    bench_to_train.py → ChengluMultiHead_vN.mlpackage
            ↓                       (this script, step 2 → bench_to_train.py)
    diff vs prior version
            ↓                       (this script, step 3 → compare_mlpackages.py)
    operator approves → bundle into SampleHost/Resources/
                                    (chapter 二百五十九 — user action)

This script orchestrates **steps 1-3**. The user actions (step 0
real bench + step 4 bundle) remain manual.

## Usage

```sh
# Live mode — pull from connected iPhone, retrain
/tmp/coreml-py312/bin/python3 scripts/pull_iphone_bench_and_retrain.py \\
    --device <device-uuid> \\
    --pull-dest /tmp/iphone-rawllm-pull \\
    --output SampleHost/ChengluMultiHead_v0.3.mlpackage

# Dry-run mode — validate args + run downstream against
# already-pulled data (no devicectl call)
/tmp/coreml-py312/bin/python3 scripts/pull_iphone_bench_and_retrain.py \\
    --skip-pull \\
    --pull-dest /tmp/iphone-rawllm-pull \\
    --output /tmp/test-multihead.mlpackage

# Pull only — useful for collecting bench data to inspect first
/tmp/coreml-py312/bin/python3 scripts/pull_iphone_bench_and_retrain.py \\
    --device <device-uuid> \\
    --pull-dest /tmp/iphone-rawllm-pull \\
    --skip-train
```

## Failure modes (honest)

The pull step fails if the iPhone is locked / not connected /
the SampleHost app hasn't run. The train step fails if there are
zero rows (chapter 二百八 ADR-006 .rawLLM mode is **required**;
default --reflective bench produces 100% llmSkipped). Each step
emits a typed error so the operator knows where the loop broke.

## Doctrine pins

- **不变量 #2 神经不掌权**: the trained .mlpackage is a new
  offline candidate. It does NOT auto-deploy. Operator review
  + explicit canary + bundle replacement (chapter 二百五十九) is
  the controlling step.
- **chapter 一百七十七 P0 -> P2**: this script is the P2 data-
  feedback rung. P0 (rule-based) + P1 (single-CoreML head) are
  pre-existing.
- **chapter 二百八 ADR-006**: bench JSONL is observability ONLY.
  This script reads the JSONL but does NOT mutate any production
  permit decision; the trained model is a candidate, not a
  permit.

## chapter 二百四十八 / M735 doctrine alignment

The pull-then-retrain orchestration mirrors the persistence
chapter idiom: storage primitive (chapter 二百四十八), schema
adapter (chapter 二百四十九), thin orchestration (chapter
二百五十). Here the analog is: real bench ship (chapter
一百七十七), feature schema (chapter 一百九十), thin
orchestration (this script).
"""

from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess
import sys
from glob import glob
from pathlib import Path
from typing import Optional

# chapter 二百五十七 — anti-magic-number per chapter 一百十三:
# every literal threshold / file-name / SQLite filename gets a
# named constant so the orchestration semantics are auditable
# from one place.

#: Default bench-pull destination root if caller doesn't supply.
DEFAULT_PULL_DEST = "/tmp/iphone-rawllm-pull"

#: Default trained-model output if caller doesn't supply.
DEFAULT_OUTPUT_PACKAGE = "/tmp/ChengluMultiHead_vCandidate.mlpackage"

#: Bundle ID of the SampleHost app on iPhone — exposed as a
#: constant so a future BundleID rename has one site to update.
SAMPLEHOST_BUNDLE_ID = "com.changgeng.samplehost"

#: Where SampleHost writes its bench JSONL on the iPhone (chapter
#: 一百九十一 unified storage layout).
IPHONE_BENCH_SUBDIR = "Documents/iphone-hybrid-bench"

#: Path to bench_to_train.py relative to repo root. Resolved at
#: runtime via __file__.
BENCH_TO_TRAIN_RELATIVE = "bench_to_train.py"


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(
        prog="pull_iphone_bench_and_retrain",
        description=(
            "Pull iPhone .rawLLM bench JSONL, retrain "
            "ChengluMultiHead, diff vs prior version. "
            "附录 V Stage 3 Step 2 of 5."
        ))
    p.add_argument(
        "--device",
        help=(
            "iPhone device UUID (from `xcrun devicectl list "
            "devices`). Required unless --skip-pull."))
    p.add_argument(
        "--pull-dest",
        default=DEFAULT_PULL_DEST,
        help=(
            "Local directory where devicectl will deposit JSONL. "
            f"Default: {DEFAULT_PULL_DEST}."))
    p.add_argument(
        "--output",
        default=DEFAULT_OUTPUT_PACKAGE,
        help=(
            "Path to write trained .mlpackage. Default: "
            f"{DEFAULT_OUTPUT_PACKAGE}."))
    p.add_argument(
        "--base-corpus",
        default=None,
        help=(
            "Optional base-corpus directory (chapter 175/176 "
            "5,088-row adversarial corpus) to merge with bench "
            "data. If absent, train on bench data alone (chapter "
            "一百九十 honesty: pure-bench is a smaller signal)."))
    p.add_argument(
        "--prior-package",
        default=None,
        help=(
            "Optional prior .mlpackage to diff against. If "
            "supplied, runs scripts/compare_mlpackages.py after "
            "retrain so the operator sees the head-by-head delta."))
    p.add_argument(
        "--skip-pull",
        action="store_true",
        help=(
            "Skip devicectl pull. Use when bench JSONL is "
            "already in --pull-dest from a prior run / manual "
            "copy. Useful for retrain-only iteration without "
            "the iPhone connected."))
    p.add_argument(
        "--skip-train",
        action="store_true",
        help=(
            "Skip retrain step. Use to inspect bench data "
            "before deciding whether to retrain."))
    p.add_argument(
        "--clean-pull-dest",
        action="store_true",
        help=(
            "Wipe --pull-dest before pulling. Off by default — "
            "preserves prior session data so multi-pull "
            "concatenation works."))
    return p.parse_args()


# MARK: - Step 1 — devicectl pull


def run_devicectl_pull(
    *,
    device: str,
    pull_dest: str,
    clean_dest: bool,
) -> int:
    """Invoke `xcrun devicectl device copy from ...` to pull
    iPhone bench JSONL into `pull_dest`. Returns the count of
    JSONL files staged in pull_dest after the pull (0 if pull
    failed or there was nothing to pull).

    The devicectl command is the same one chapter 一百七十六
    documented for AFM-bench harvest. We're parameterizing the
    bundle ID + source path so the same orchestration works for
    any chapter-176-style harvest.
    """
    if clean_dest and os.path.isdir(pull_dest):
        shutil.rmtree(pull_dest)
    os.makedirs(pull_dest, exist_ok=True)

    cmd = [
        "xcrun", "devicectl", "device", "copy", "from",
        "--device", device,
        "--domain-type", "appDataContainer",
        "--domain-identifier", SAMPLEHOST_BUNDLE_ID,
        "--source", IPHONE_BENCH_SUBDIR,
        "--destination", pull_dest,
    ]
    print(f"[pull] running: {' '.join(cmd)}")
    rc = subprocess.run(cmd, check=False).returncode
    if rc != 0:
        print(
            f"[pull] devicectl exited rc={rc}; check that "
            "(a) device is connected, (b) iPhone is unlocked, "
            "(c) SampleHost has run at least once.",
            file=sys.stderr)
        return 0
    jsonl_files = glob(
        os.path.join(pull_dest, "**", "*.jsonl"),
        recursive=True)
    print(f"[pull] staged {len(jsonl_files)} JSONL files at "
          f"{pull_dest}")
    return len(jsonl_files)


# MARK: - Step 2 — call bench_to_train.py


def run_bench_to_train(
    *,
    bench_dir: str,
    output_package: str,
    base_corpus: Optional[str],
) -> int:
    """Invoke scripts/bench_to_train.py. Returns the script's
    exit code (0 on success, non-zero on any pipeline failure
    e.g. zero rows, schema mismatch, etc.)."""
    here = Path(__file__).resolve().parent
    bench_script = here / BENCH_TO_TRAIN_RELATIVE
    if not bench_script.exists():
        print(
            f"[train] bench_to_train.py not found at "
            f"{bench_script}; ship chapter 一百九十 first.",
            file=sys.stderr)
        return 2
    cmd = [
        sys.executable,
        str(bench_script),
        "--bench", bench_dir,
        "--output", output_package,
    ]
    if base_corpus:
        cmd.extend(["--base-corpus", base_corpus])
    print(f"[train] running: {' '.join(cmd)}")
    return subprocess.run(cmd, check=False).returncode


# MARK: - Step 3 — diff vs prior


def run_compare_mlpackages(
    *,
    prior_package: str,
    new_package: str,
) -> int:
    """Invoke scripts/compare_mlpackages.py if available. Best-
    effort: returns 0 if comparison ran, non-zero otherwise.
    Failure here is non-fatal — the operator just doesn't get a
    head-by-head delta report."""
    here = Path(__file__).resolve().parent
    compare_script = here / "compare_mlpackages.py"
    if not compare_script.exists():
        print(
            "[diff] compare_mlpackages.py not present; "
            "skipping diff. (Operator can compare manually.)",
            file=sys.stderr)
        return 1
    cmd = [
        sys.executable,
        str(compare_script),
        "--baseline", prior_package,
        "--candidate", new_package,
    ]
    print(f"[diff] running: {' '.join(cmd)}")
    return subprocess.run(cmd, check=False).returncode


# MARK: - Orchestrator


def main() -> int:
    args = parse_args()

    # Step 1 — pull
    pulled_count = 0
    if args.skip_pull:
        if not os.path.isdir(args.pull_dest):
            print(
                f"[pull] --pull-dest {args.pull_dest} does not "
                "exist; nothing to train on.",
                file=sys.stderr)
            return 1
        print("[pull] skipped (--skip-pull); using existing data "
              f"at {args.pull_dest}.")
        existing = glob(
            os.path.join(args.pull_dest, "**", "*.jsonl"),
            recursive=True)
        pulled_count = len(existing)
        print(f"[pull] found {pulled_count} pre-existing "
              "JSONL files.")
    else:
        if not args.device:
            print(
                "[pull] --device is required unless --skip-pull. "
                "Find UUID via `xcrun devicectl list devices`.",
                file=sys.stderr)
            return 2
        pulled_count = run_devicectl_pull(
            device=args.device,
            pull_dest=args.pull_dest,
            clean_dest=args.clean_pull_dest)
        if pulled_count == 0:
            print(
                "[pull] no JSONL pulled — bailing before train.",
                file=sys.stderr)
            return 3

    # Step 2 — retrain
    if args.skip_train:
        print("[train] skipped (--skip-train).")
        return 0
    train_rc = run_bench_to_train(
        bench_dir=args.pull_dest,
        output_package=args.output,
        base_corpus=args.base_corpus)
    if train_rc != 0:
        print(
            f"[train] bench_to_train.py exited rc={train_rc}; "
            "no retrained model produced.",
            file=sys.stderr)
        return 4
    if not Path(args.output).exists():
        print(
            f"[train] expected output package at {args.output} "
            "not found post-train.",
            file=sys.stderr)
        return 5
    print(f"[train] candidate model written to {args.output}")

    # Step 3 — diff (best effort)
    if args.prior_package:
        diff_rc = run_compare_mlpackages(
            prior_package=args.prior_package,
            new_package=args.output)
        # Diff failure is non-fatal — the candidate model is
        # still on disk for operator review.
        if diff_rc != 0:
            print(
                f"[diff] compare exited rc={diff_rc}; manual "
                "review required.",
                file=sys.stderr)

    print(
        "\n=== summary ===\n"
        f"  bench JSONL files: {pulled_count}\n"
        f"  candidate package: {args.output}\n"
        f"  prior baseline:    {args.prior_package or '(none)'}\n"
        "\nNext (manual): chapter 二百五十九 — bundle the "
        "candidate into SampleHost/Resources/ after operator "
        "review.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
