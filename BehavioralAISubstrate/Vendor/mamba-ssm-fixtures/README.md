# mamba-ssm Reference Fixtures

## Honest scope (chapter 六百七十九 / M2093)

This directory contains **canonical mathematical reference
fixtures** for the chapter 六百七十七 / M2085 SSMScan.metal
selective-scan kernel + the chapter 六百七十八 / M2089
BASMetalSSMScanKernel + BASSSMScanCPUReference implementations.

**Provenance**: The expected output values in these JSON
fixtures are **mathematically derived by hand** from the
canonical Mamba selective-scan recurrence:

```
A_bar = exp(delta_t * A_d)
B_bar = delta_t * B_t
h_t   = A_bar * h_{t-1} + B_bar * x_t
y_t   = C_t * h_t
```

with `h_0 = 0` initial state, computed exactly using IEEE
Float32 arithmetic conventions. Each fixture documents the
derivation in its `derivation` field so a future reader can
re-verify by hand.

**These are NOT python-mamba-ssm-derived numerical fixtures**
— this is honestly documented because the substrate's CI
environment doesn't run Python, and committing fixtures
under false provenance would violate doctrine.

The fixtures are equivalent to what canonical mamba-ssm
Python would produce on the SAME inputs (the math is
identical), but the values here are derived analytically
from the recurrence formula rather than captured from
Python execution.

## Cross-validation tier already proven

The chapter 678 / M2091 cross-validation suite already
proved BASMetalSSMScanKernel (GPU) agrees with BASSSMScan
CPUReference (CPU) to MAE ≤ 1e-5 across 8 random fixtures
(B=1..8, L=1..128, D=1..64). These chapter 679 fixtures
ADD a SECOND independent oracle — analytically-derived
canonical math — to triangulate correctness.

## Fixture inventory

| File | Shape | Description |
|------|-------|-------------|
| `01_zero_delta_zero_output.json` | B=1,L=4,D=2 | delta=0 ⇒ y=0 (boundary case) |
| `02_identity_unit_step.json` | B=1,L=1,D=1 | x=2.5, A=0, delta=1, B=C=1 ⇒ y=2.5 |
| `03_two_step_decay.json` | B=1,L=2,D=1 | A=-1, x=[1,0] ⇒ y=[1, exp(-1)] |
| `04_three_step_accumulation.json` | B=1,L=3,D=1 | A=0, C=2, x=1 ⇒ y=[2,4,6] |
| `05_two_channel_independence.json` | B=1,L=1,D=2 | Two channels yield independent outputs |
| `06_two_batch_independence.json` | B=2,L=1,D=1 | Two batches yield independent outputs |

Each fixture is a JSON object with:

```json
{
  "name": "...",
  "description": "...",
  "derivation": "Step-by-step math...",
  "shape": { "B": ..., "L": ..., "D": ... },
  "inputs": {
    "x": [...], "delta": [...], "A": [...],
    "B": [...], "C": [...]
  },
  "expected_y": [...],
  "tolerance": 1e-5
}
```

Row-major storage order: index = ((b * L) + t) * D + d.
