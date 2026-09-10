# Phase B-1 — BASContextClassifier training pipeline

**Chapter 七百三十六 / M2250** — first real ML adapter for the
14-layer 电子脑.

## Pipeline architecture

```
corpus.jsonl (text + taskType labels, hand-labeled)
    ↓
train.py (PyTorch, hash-bucket bag + 2-layer MLP)
    ↓
context_classifier.pt + label_index.json
    ↓
convert.py (coremltools)
    ↓
BASContextClassifier.mlpackage
    ↓
[Phase B-2: copy into Sources/BASRuntimeCore/Resources/]
    ↓
[Phase B-3: BASContextClassifierMLAdapter loads + infers]
    ↓
[Phase B-4: BASCognitiveBrain swaps placeholder → ML adapter]
```

User's conceptual mapping:
- **Python** = 工厂 (factory) — produces .mlpackage artifacts
- **CoreML** = 芯片适配层 (chip adapter layer) — runtime
- **Swift** = 身体 (body) — orchestration
- **Rust** = 神经系统 (nervous system) — deeper substrate
  (future)

## How to run

```bash
cd Scripts/PhaseB_ContextClassifier

# Install deps (one-time)
pip3 install 'torch>=2.10.0' packaging coremltools

# Train (~5 seconds on CPU)
python3 train.py
# → context_classifier.pt, label_index.json

# Convert
python3 convert.py
# → BASContextClassifier.mlpackage
```

## Checkpoint loading requirements

Both `convert.py` and `convert_coreai.py` use `checkpoint_loader.py` to load
on CPU with explicit `weights_only=True`. The supported checkpoint is the
tensor `state_dict`, integer dimensions/seed and primitive labels saved by
`train.py`; arbitrary Python objects/custom classes are not supported. A
restricted-load failure is fatal: there is no unrestricted retry or added
allowlist.

Conversion requires **PyTorch >= 2.10.0** and `packaging` (public PEP 440
version comparison). Older, invalid or unverifiable versions are rejected
before loading; prereleases below the final floor are rejected, while
standard local version metadata is supported. This floor addresses the
known restricted-loader flaw in
[GHSA-63cw-57p8-fm3p](https://github.com/advisories/GHSA-63cw-57p8-fm3p);
the older 2.6.0 floor is insufficient. Restricted loading is not a guarantee
against all future PyTorch vulnerabilities or resource exhaustion.

For the separate Core AI backend, use a compatible Python 3.12 environment
with `coreai-torch`, `'torch>=2.10.0'` and `packaging` (see
`convert_coreai.py`). If backend dependency constraints conflict, resolve
that environment separately; do not lower the floor or disable restricted
loading.

Run the local checkpoint regression tests with an environment containing
PyTorch >= 2.10.0 and `packaging`:

```bash
python3 -B -m unittest -v test_checkpoint_loading
```

Tests use temporary checkpoints and real PyTorch loading, tracing and
export; Apple conversion backends/output writers are replaced, so these
tests do not prove real CoreML/Core AI conversion compatibility.

## Files

| File | Purpose |
|---|---|
| `corpus.jsonl` | 299 hand-labeled examples (IMBALANCED: chat 71, manipulationRisk 68, task 55, choice 32, conflict 25, highPressure 24, highConsequence 24 — corrected 2026-06-11; the stale "105/15-per-class" claim predated corpus growth) |
| `train.py` | PyTorch training script |
| `convert.py` | PyTorch → CoreML conversion |
| `label_index.json` | Generated: class label order (Swift must match) |
| `context_classifier.pt` | Generated: PyTorch checkpoint |
| `BASContextClassifier.mlpackage` | Generated: CoreML artifact |

## 7-class label space

Matches `BASContextTaskType` cases at
`Sources/BASOrchestration/EBrainL6SituationFieldCore.swift:1`:

1. `chat` — casual conversation
2. `task` — actionable work request
3. `choice` — A-or-B decision
4. `conflict` — competing values / disagreement
5. `highPressure` — urgent / time-critical
6. `manipulationRisk` — social engineering / coercion
7. `highConsequence` — irreversible / high-stakes decision

## Honest scope acknowledgments

**This is Phase B-1 — a SEED.** Tiny model on tiny data:

- 299 training examples (imbalanced, 24-71 per class) — production
  needs 1000+ per class
- Bag-of-256-hash-buckets — production needs real word
  embeddings or a transformer encoder
- 2-layer MLP, ~18K parameters — production might need a
  small transformer (~1-10M params)
- No train/val/test split — production needs held-out eval
- No data augmentation
- No cross-validation
- Manual labels by single author — production needs
  multi-annotator agreement

**Expected accuracy: 60-80% on training set** (mostly
memorization of the 105 examples). Phase B-2 will expand
corpus + architecture. The Phase B-1 goal is to UNBLOCK the
pipeline (real .mlpackage → Swift inference → cascade
replacement), not to ship a high-accuracy model.

## Determinism contract

The hash-bucket function in `train.py` (SHA256-prefix) MUST
be reproduced byte-identically in Swift at inference time.
Phase B-3 will ship `BASContextClassifierInputEncoder.swift`
with the same algorithm + a parity test.

## What's next (Phase B-2 → B-4)

- **Phase B-2** (chapter 七百三十七): Run the scripts to
  produce a real `.mlpackage`, check it into
  `Sources/BASRuntimeCore/Resources/` as a Package resource.
- **Phase B-3** (chapter 七百三十八): Build
  `BASContextClassifierMLAdapter` actor in
  `Sources/BASRuntimeCore/` loading the .mlpackage + a
  parity-tested Swift input encoder.
- **Phase B-4** (chapter 七百三十九): Replace
  `BASPlaceholderContextService` with a `BASMLContextService`
  that uses the adapter. Update `BASCognitiveBrain`
  default to use it. Integration test proves real inference.
