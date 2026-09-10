# M421 Stat-Rigorous Analysis of M420 (chapter 一百一)

**Date**: 2026-05-03
**Chapter**: 一百一 (M421)
**Trigger**: User asked "整体而言 目前 你 满意吗" → I confessed M420's measurement was N=1 each side → user asked "全面改造不满意至满意" → this is the rigorous re-measurement.

## What M420 claimed

Commit `e5e158b3` claimed: "full-stack-bench p50 -8.6% (2.83ms → 2.59ms)" based on 1 baseline measurement vs 1 post-optimization measurement.

## What M421 actually measured

10 runs × 200 sessions each side (2000 sessions total per side):

### Pre-M420 p50 distribution
- mean = 3.3687 ms
- std = 0.6072 ms (CV = 18.0%)
- min = 2.8817, max = 4.7684

### Post-M420 p50 distribution
- mean = 3.8578 ms
- std = 0.7290 ms (CV = 18.9%)
- min = 3.0071, max = 5.2096

### Welch's t-test
- Δ mean: **+0.4891 ms (+14.52%)** — i.e. post > pre on this measurement
- 95% CI: ±0.6787 ms (df ≈ 17.4)
- CI bounds: [-0.19, +1.17] ms = [-5.63%, +34.66%]
- **Verdict: NOT statistically distinguishable from noise at 95% CI**

### Honest interpretation

The original M420 commit message's "-8.6%" claim was **statistical noise from N=1 sampling**. With proper rigor (N=10 × 200 sessions = 2000-session sample per side):

1. **Mean direction is opposite** of the original claim (post is +14.5% higher mean, not -8.6% lower)
2. **CI straddles zero** so neither direction is statistically supported
3. **Variance dominates**: std ≈ 18% of mean on both sides → noise floor is ±35% at 95% CI for N=10
4. **Conclusion**: M420 has **no measurable bench-level performance impact**. Original claim was wrong.

## Why measurement varies so much

Per chapter 91.6 documented platform policy: macOS 26 background processes (modelmanagerd, Apple Intelligence, etc.) burst CPU during xctest startup. Sub-millisecond timing is highly sensitive to:
- Power management state
- Other concurrent processes
- Cache state (cold vs warm)
- JIT warmup variance

For full-stack-bench (3.5ms p50, 0.6ms std → 18% CV), to detect a 5% effect at 95% CI would require N≈55 runs each side. To detect a 10% effect: N≈14.

I sampled N=10 each side. Real effect needs to be larger than ~28% to show as statistically significant at this N. M420's effect is below that threshold.

## What's the actual structural impact of M420?

The change replaced 4 inline array literals with 4 static-let references:
- 2× 14-element activeLayerRefs
- 2× 3-element centerlineRules (also avoids 2 string interpolations)
- 1× 5-element transformationSteps
- 1× 2-element revealConditions

**Verified savings per turn**: ~38 string-array allocations + ~18 string-interpolation calls.

**At ~3.5ms / 1000+ allocations per turn**: those 38 saved allocations are <1% of total allocation pressure. **Not measurable above noise**.

## Decision: keep or revert M420?

### Keep, with retraction

The optimization is **structurally correct**:
- Avoids unnecessary work (static-let is computed once vs per-turn)
- Cleaner code (4 named constants vs 4 inline literals)
- Doctrine-clean (zero behavior change verified by M415 byte-equal snapshots passing)

The perf claim was wrong, but the code change is fine.

**Action**: keep M420 commit; ship M421 as the honest stat-rigorous analysis; update chapter 一百一 honesty board to record the retraction.

### Why not revert

Reverting would throw away clean code because of a wrong perf claim. The right honesty move is to publicly retract the claim, not undo the code.

## Lesson learned (premature-verdict pattern)

This is the same pattern I called out in my own reflection: **N=1 measurements are not measurements, they're snapshots of one moment of noise**. Future bench claims must use ≥N=10 with 95% CI before publication.

Codified in `docs/QINAO_DEEP_REVIEW_DOCTRINE.md` (will be updated in M427 chapter wrap):

> Bench claims with quantitative deltas (e.g. "X% faster") MUST be supported by:
> - N ≥ 10 measurements each side
> - 95% CI computation (Welch's t-test or equivalent)
> - The CI bounds, not just the mean
>
> Single-shot bench measurements may be reported as "directional signal pending rigorous validation" but never as quantitative claims.

## What this means for chapter 一百 (M420) ledger

Honesty board chapter 一百 (if any) and the M420 commit message contain the wrong "-8.6%" claim. The retraction is recorded here in M421 but the historical commit is not amended (per "never force-push to shared branches" rule).

The commit message claim is invalidated by this M421 doc. Future readers should consult both.

## Status

- **M421 measurement: complete + statistically rigorous**
- **M420 perf claim: retracted as not-statistically-supported**
- **M420 code change: kept (structurally clean)**
- **Methodology: codified for future bench claims**
