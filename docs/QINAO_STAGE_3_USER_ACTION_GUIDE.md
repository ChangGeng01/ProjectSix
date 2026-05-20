# 附录 V Stage 3 — Real Bench Data User-Action Guide

> **⚠ Workflow updated 2026-05-21** — SampleHost was reconstituted as a
> standalone SPM iOS package at `/SampleHost/Package.swift`。 The
> `xcodebuild -project Before.xcodeproj -scheme SampleHost ...`
> commands below should be updated to the new shape:
>
> ```sh
> cd SampleHost
> xcodebuild -scheme SampleHost \
>     -configuration Release \
>     -destination 'generic/platform=iOS' \
>     DEVELOPMENT_TEAM=<your-team-id> \
>     -allowProvisioningUpdates build
> ```
>
> (drop the `-project Before.xcodeproj` flag,run from inside `SampleHost/`
> since the package's auto-generated workspace is implicit)。 The data-
> pipeline scripts (`scripts/bench_to_train.py` etc.) remain operational —
> they only need the on-device JSONL file,which the new SampleHost
> writes to the same path the old Before-scheme SampleHost did。

**chapter 二百五十六 / M751** — operator-facing procedure document.

This document explains what the user must do to feed the附录 V
Hybrid pipeline (chapters 二百五十七-二百七十) with real iPhone
bench data. The substrate-side enablement was shipped in chapter
二百八 / ADR-006 (`.rawLLM` mode); the orchestration tooling
shipped in chapters 二百五十七 (pull/retrain) + 二百六十二
(aggregator) + 二百六十三 (typed bundle) + 二百六十四 (deploy
gate). What's left is the human-side action: run the bench,
review the output, deploy.

This is **not** a code chapter. The substrate is ready; this
is the procedure record so future operators can reproduce.

---

## Procedure

### Phase 1 — Run the iPhone bench (chapter 二百五十六)

**Hardware**: iPhone 17e (or any iPhone running the SampleHost
build).

**Setup**:
1. Build SampleHost in Release configuration:
   ```sh
   xcodebuild -project Before.xcodeproj -scheme SampleHost \
       -configuration Release \
       -destination 'generic/platform=iOS' \
       DEVELOPMENT_TEAM=<your-team-id> \
       -allowProvisioningUpdates build
   ```
2. Install on the device:
   ```sh
   xcrun devicectl device install app \
       --device <device-uuid> \
       <path-to>/Build/Products/Release-iphoneos/SampleHost.app
   ```
3. Launch SampleHost.

**Bench configuration** (in-app):
- SmokeMode: `.rawLLM` (chapter 二百八 / ADR-006). This forces
  `dispatchPolicy = .singleLLM` regardless of substrate's permit
  decision — the LLM fires on every iter, producing real body
  data. Substrate's permit-mode is still recorded in JSONL.
- Workflow profile: `.primary` (operator's bench-data
  accumulation choice; chapter 二百四).
- Hours: 8 (canonical bench length per chapter 一百七十六).
- Prompt source: `.benign` (chapter 二百五) or `.heavy` per
  operator preference.

**Run**: tap "Start hybrid bench" and leave running for 8 hours.
The phone needs to stay foregrounded (chapter 一百七十六
foreground policy); plug into power and disable auto-lock.

**Expected output**: ~50K-200K rows of JSONL across multiple
files in the iPhone's `Documents/iphone-hybrid-bench/` directory.

### Phase 2 — Pull bench data + retrain candidate (chapter 二百五十七)

```sh
/tmp/coreml-py312/bin/python3 \
    scripts/pull_iphone_bench_and_retrain.py \
    --device <device-uuid> \
    --pull-dest /tmp/iphone-rawllm-pull \
    --output /tmp/ChengluMultiHead_v0.3.mlpackage \
    --base-corpus /tmp/iphone-afm-bench-final-pull/ \
    --prior-package SampleHost/ChengluMultiHead_v0.2.mlpackage
```

This invokes (a) `devicectl device copy from ...` to pull JSONL,
(b) `bench_to_train.py` to retrain the `ChengluMultiHead`
mlpackage, (c) `compare_mlpackages.py` to diff against the prior
shipped version.

**Expected output**: a new `.mlpackage` candidate. Operator
decides whether the head-by-head deltas justify shipping.

### Phase 3 — Aggregate stratum stats (chapter 二百六十二)

```sh
/tmp/coreml-py312/bin/python3 \
    scripts/aggregate_risk_stratum.py \
    --input /tmp/iphone-rawllm-pull \
    --output /tmp/risk-stratum-aggregate-2026-05-07.json \
    --stratum-keys tone stake confidant \
    --min-stratum-count 50
```

Aggregates by stratum, strips host-specific identifiers (per
ADR-012), emits typed JSON. Operator reviews this output.

### Phase 4 — Author calibration bundle (chapter 二百六十三)

This step is **operator decision**. Reading the stratum stats,
the operator decides:
1. Are any thresholds drifting? (e.g. is "angry/high" tripping
   block much more often than the threshold is set for?)
2. If yes, what threshold deltas would correct? (per-stratum
   medium/high/extreme deltas in `[-0.25, +0.25]`)
3. What sovereign warrant ref? (operator obtains from L14
   warrant signing path)

Author the bundle in Swift (or via JSON if a future operator-
review CLI exists; chapter 二百五十九 ships that):

```swift
let bundle = BASRiskCalibrationBundle(
    bundleVersion: "v1.0.0",
    aggregateProvenanceRef:
        "agg:rollup:sha256-of-aggregate-json",
    strataDeltas: [
        BASRiskCalibrationStratumDelta(
            stratumKey: "tone=angry|stake=high|confidant=public",
            mediumThresholdDelta: -0.05,
            evidenceRowCount: 500,
            reasonCodes: ["rollup:apr", "review:operator-1"])
    ],
    sovereignWarrantRef: "warrant:abc123",
    summary: "April rollup — lower medium threshold for high-stake angry")
```

### Phase 5 — Deploy bundle to L11 risk gate (chapter 二百六十四)

```swift
let gate = BASRiskCalibrationGate()  // initial baseline
let outcome = try await gate.replace(bundle)
print(outcome.auditReasonCodes)
```

The gate validates `isWellFormed` + monotonic version + supersedes
chain. Audit emits 5 typed reason codes; pipe into the L14
sovereign audit ledger. Per-turn L11 logic now consults
`gate.effectiveMediumThreshold(forStratumKey:base:)` etc. when
computing thresholds for that stratum.

---

## Doctrine pins held throughout

- **不变量 #2 神经不掌权**: every step except Phase 1 (the
  device-side bench) is operator-driven. The retrain produces a
  candidate; the operator decides whether to ship. The bundle
  authoring is an explicit Swift code artifact reviewed by humans.
- **不变量 #3 私有经验不进权重**: `aggregate_risk_stratum.py`
  strips host-specific identifiers (timestamps, prompts, bodies,
  *Refs) before output. Bundle's input is generalized signal only.
- **ADR-006 strict**: live bench data is observability ONLY at
  per-turn scope. The retrain + bundle pipeline is offline,
  between-deploy.
- **ADR-012**: this procedure IS the implementation of ADR-012.
  Bundle replacement is between-turn; `bundleVersion` monotonic;
  `sovereignWarrantRef` required.
- **chapter 一百零二 五级删除**: revoked sessions must be filtered
  out of `--input` before aggregation. (Operator pre-filter
  responsibility until bench JSONL carries a `forgetMarker`
  field.)

## What the user must explicitly authorize

The substrate ships these chapters as **infrastructure ready**.
Each phase carries explicit operator authorization gates:

| Phase | Authorization required |
|---|---|
| 1 (run bench) | User initiates bench run; user keeps phone foregrounded for 8h |
| 2 (pull + retrain) | User authorizes devicectl pull; operator reviews retrain output |
| 3 (aggregate) | Operator runs aggregator; reviews stratum stats |
| 4 (author bundle) | Operator decides what deltas to encode; obtains L14 warrant |
| 5 (deploy) | Operator integrates gate into host code; substrate audit records replacement |

---

## Why this is a doc-only chapter

Chapter 二百五十六 (per附录 V plan §V.6) is "real iPhone .rawLLM
8h bench". This is fundamentally **user action** — no code can
produce 8 hours of real device data. The substrate-side
enablement was shipped in chapter 二百八 (ADR-006 `.rawLLM`
mode); the orchestration was shipped in chapter 二百五十七.
Chapter 二百五十六 is the procedure record so the operator
knows exactly what to do, in what order, with what flags.

The other Stage 3 chapters depend on chapter 二百五十六's bench
output:
- chapter 二百五十八 (ChengluPreflight v1 train) → consumes the
  retrain output; ships in chapter 二百五十八 / M752 as a
  synthetic-data train pipeline that demonstrates the mechanics
  with operator-replaceable real-data hook.
- chapter 二百五十九 (v1 bundle ship + canary) → ships in
  chapter 二百五十九 / M753 as an operator review CLI.
- chapter 二百六十 (Multi-CoreML pipeline) → ships in chapter
  二百六十 / M754 as `BASShadowEvaluatorPipeline` composition
  primitive (typed, no real ML required).
