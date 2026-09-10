# ChengluPreflight self-improvement loop — operator runbook

Documents the end-to-end self-improvement pipeline for the
ChengluPreflight CoreML router (chapter 一百七十七+) and the
ChengluMultiHead 5-head model (chapter 一百八十一+).

This README walks through the **mechanically-validated synthetic
loop** (chapter 二百). The same flow with REAL iPhone bench data
is the production cycle.

## Loop diagram

```
[1] iPhone hybrid bench (10h preferred)
     |
     | Documents/iphone-hybrid-bench/*.jsonl (chapter 192 v9)
     v
[2] scripts/bench_to_train.py
     |
     | extracts (signature, label) pairs from non-skipped iters
     v
[3] augment chapter 175/176 base corpus (5,088 rows)
     |
     v
[4] retrain ChengluMultiHead → emit v0.{N+1}.mlpackage
     |
     v
[5] coremltools.MLModel → load + predict verification
     |
     v
[6] calibration_check + holdout validation
     |
     v
[7] (operator decision) ship v0.{N+1} to app bundle?
     | yes → replace SampleHost/ChengluMultiHead_v0.mlpackage
     | rebuild + redeploy
     v
[8] next bench uses new model → cycle continues
```

## Quick smoke (synthetic data, ~30s)

Validates the pipeline mechanics without needing real iPhone
data. Useful as a regression check after editing `bench_to_train.py`
or training scripts.

```bash
# Step 1: synthesize 200 base + 200 bench rows
/tmp/coreml-py312/bin/python3 scripts/synthesize_corpus.py \
    --base-out /tmp/synthetic-base/ \
    --bench-out /tmp/synthetic-bench/ \
    --base-rows 200 --bench-rows 200

# Step 2: pre-flight check — bench data viable for training?
/tmp/coreml-py312/bin/python3 scripts/bench_to_train.py \
    --bench /tmp/synthetic-bench/ \
    --analyze-only

# Step 3: full retrain end-to-end
/tmp/coreml-py312/bin/python3 scripts/bench_to_train.py \
    --base-corpus /tmp/synthetic-base/ \
    --bench /tmp/synthetic-bench/ \
    --output /tmp/ChengluMultiHead_v0_5_synthetic.mlpackage \
    --require-bench-rows 50

# Step 4: verify .mlpackage loads + predicts
/tmp/coreml-py312/bin/python3 scripts/verify_v0_5_synthetic.py \
    /tmp/ChengluMultiHead_v0_5_synthetic.mlpackage

# Step 5: calibration check
/tmp/coreml-py312/bin/python3 scripts/calibration_check.py \
    --mlpackage /tmp/ChengluMultiHead_v0_5_synthetic.mlpackage \
    --eval-corpus /tmp/synthetic-base/
```

Synthetic-trained `.mlpackage` is **doctrine-REFUSED** for
production bundle. It exists only to validate pipeline mechanics.

## Real-data loop (10h iPhone bench)

### Pre-bench

1. Open SampleHost on real iPhone (NOT sim — sim has no AFM/Gemma)
2. Verify Gemma is loaded: tap "Run Hybrid Test" — should
   produce non-empty body (first time may take 5-15 min for
   Gemma weights download)
3. Set bench params (chapter 192-198 sliders):
   - Hours: 10.0
   - Smoke mode: heavy-tailed (production-realistic + adversarial)
   - Pause on .serious thermal: ON (chapter 197 M740)
   - Cool every: 1000 iters (chapter 198 M744)
   - Cool sleep: 30s (more aggressive than default 10s for 10h)
   - LLM timeout: 60s (default)
   - Other sliders: defaults

### Run

4. Plug iPhone into charger
5. tap "Start"
6. Operator monitors live dashboard:
   - **Thermal NOW** (red on critical / orange on serious)
   - **Cooling sleeps fired** counter
   - **LLM timeouts fired** counter
   - **Stuck-substrate / LLM** entries (post-M739, fire-on-entry)
   - **Drift > σ-thresh alarms**
7. Bench auto-stops after 10h or operator taps Stop

### Post-bench

8. Pull JSONL via devicectl:

```bash
xcrun devicectl device copy from \
    --device <DEVICE_ID> \
    --domain-type appDataContainer \
    --domain-identifier com.changgeng.samplehost \
    --source Documents/iphone-hybrid-bench \
    --destination /tmp/iphone-bench-pull/
```

9. Run replay:

```bash
python3 scripts/replay_hybrid_bench.py /tmp/iphone-bench-pull/
```

Reports per-layer coverage, anomaly distribution, drift,
adversarial breakdown.

10. Validate JSONL integrity:

```bash
python3 scripts/validate_hybrid_jsonl.py /tmp/iphone-bench-pull/
```

11. Pre-flight bench data:

```bash
python3 scripts/bench_to_train.py \
    --bench /tmp/iphone-bench-pull/ \
    --analyze-only
```

If verdict says "ready for retrain":

12. Run full retrain:

```bash
python3 scripts/bench_to_train.py \
    --base-corpus /tmp/iphone-afm-bench-final-pull/ \
    --bench /tmp/iphone-bench-pull/ \
    --output /tmp/ChengluMultiHead_v0_5_real.mlpackage \
    --require-bench-rows 100
```

13. Verify + calibration:

```bash
python3 scripts/verify_v0_5_synthetic.py \
    /tmp/ChengluMultiHead_v0_5_real.mlpackage

python3 scripts/calibration_check.py \
    --mlpackage /tmp/ChengluMultiHead_v0_5_real.mlpackage \
    --eval-corpus /tmp/iphone-afm-bench-final-pull/
```

14. Operator decision: do calibration metrics improve over v0.4?
    - YES → replace `SampleHost/ChengluMultiHead_v0.mlpackage`
      with the v0.5 file, rebuild, redeploy
    - NO → investigate (more bench data? per-pressure stratification?)
    - MIXED → consider per-stratum sub-models

## Honest scope limits

- **Synthetic loop** validates pipeline mechanics. Synthetic
  data is mechanically valid (correct schema, plausible values)
  but NOT statistically representative of real LLM behavior.
- **Real loop** requires:
  - iOS 26 + Apple Intelligence enabled (for AFM)
  - OR Gemma weights cached (3.4 GB download first run)
  - Heavy-tailed mode + diverse prompts (avoid 100% substrate-skip)
  - Charging during 10h run (battery alone won't survive)
  - Active cooling enabled (chapter 198) — iPhone 17e hits
    .serious thermal in 110s of substrate-only at 18 iter/sec
- **Production bundle swap** requires:
  - Calibration check MACE < 0.05 across 3 binary heads
  - Holdout validation showing held-out accuracy ≥ v0.4 baseline
  - Operator manual review of per-pressure-stratum calibration
  - Production canary (deferred — chapter 202+ candidate)

## Schema versions

| Schema | Version | Chapter |
|---|---|---|
| Hybrid bench JSONL row | v9 | chapter 192 (M725) |
| Manifest | M733 | chapter 194 |
| MultiHead .mlpackage | v0 (production) | chapter 一百八十一 |
| ChengluPreflight .mlpackage | v0.4 | chapter 一百七十七 v0.4 |
| Cross-language schema parity | featureCount=43, 7 alphabets | chapter 一百八十二 |

## Key safety doctrines (chapter 192-199)

- 红线 7 (watcher hint only) — anomaly flags / drift alarms /
  thermal warnings are HINT-ONLY; never replace permit decisions
- Single commit mouth — substrate L11/L14 unchanged across all
  chapters
- 不变量 #3 (private experience does not enter weights) —
  bench data feeds offline retrain only; no live weight mutation
- M739 fire-on-entry (anomaly stuck-state events fire once per
  entry, not every iter while stuck)
