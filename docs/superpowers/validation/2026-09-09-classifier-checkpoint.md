# Context-classifier checkpoint correction

Scope: the two PhaseB_ContextClassifier converter entrypoints. Both now use
one sibling loader with explicit CPU `weights_only=True`, no unrestricted retry,
and an enforced PyTorch >= 2.10.0 floor using `packaging.version.Version`.
This does not establish checkpoint authenticity, a resource limit, or immunity
from future library vulnerabilities.

## Verification on 2026-09-09

- Seven real-PyTorch unittest cases (38 format/version/entrypoint subcases)
  passed in 0.735s. ZIP and legacy reducer payloads were rejected without
  executing the harmless marker; supported tensor/primitive documents still
  reached both actual converter mains. Version and missing-checkpoint failures
  occur before loading, with no unsafe retry.
- A fresh independent source review found no concrete bypass or regression.
  Its real-backend compatibility gap was subsequently resolved by actual
  conversion and inference, not by assuming stubbed backends were sufficient.
- In an isolated Python 3.12.13 environment on macOS 27, Torch 2.12.0,
  coremltools 9.0, coreai-torch 0.4.2 and coreai-core 1.0.0b2 converted a
  deterministic trainer-shaped 256→64→7 checkpoint through each unchanged
  main entrypoint. Each real runtime passed five numerical and argmax checks
  against PyTorch; maximum absolute error was 5.960464477539063e-08.
- Native outputs were float32 [1,7]. CoreAI retained `main`/`logits`;
  CoreML retained its converter-generated `var_10` output and labels metadata.
  No shipped model or original checkpoint was read or overwritten.

From the classifier directory, the focused reusable test command is:

```bash
python3 -B -m unittest -v test_checkpoint_loading
```

It needs PyTorch >= 2.10.0 and packaging. That unittest module replaces Apple
backends; real-backend verification was a separate disposable host test.
Complete commands, early environment/permission failures, source identities,
test drivers and actual logs are preserved in the plan's private SDD records:
`classifier-checkpoint-report.md`, `classifier-checkpoint-backend-validation.md`
and `classifier-checkpoint-review-disposition.md`.

coremltools warned that Torch 2.12.0 is beyond its declared latest-tested
version; these particular conversions and predictions passed nonetheless.
Python/Torch dependency warnings were retained. Device/ANE performance,
Swift integration, all historical checkpoints and all dependency combinations
were not tested here. This is a scoped correction, not whole-repository or DS3
readiness, and not closure of unrelated Mamba or model-integrity findings.
