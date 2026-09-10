# ANE utilization — measured findings (T1.2, 2026-06-11)

> First HARDWARE evidence for the substrate's Neural-Engine story. Until this probe, the ANE narrative was a
> static lookup table (`BASANEKernelEligibilityClassifier`: "matMul/attention → aneNative") with zero
> measurement — no `MLComputePlan` reference existed anywhere in the codebase. `BASANEUtilizationProbe`
> (`BAS_ANE_PROBE=1`) measured the two production CoreML heads on BOTH iPhone Airs (iOS 27.0):
> per-op `MLComputePlan` device histograms under `.all`, plus `.cpuOnly` vs `.all` wall-clock A/B.
> Raw logs: `Docs/cert-logs/ane-probe-device{1,2}.log`.

## The measured truth (cross-device identical)

| Head | Planner placement (`.all`) | cpuOnly A/B | Verdict |
|---|---|---|---|
| **context-classifier** (2-layer MLP, ~18K params, fp32) | `cpu=2/2` ops — **zero ANE, zero GPU** | 0.085 vs 0.087 ms (no delta) | CPU is where it runs AND belongs |
| **MiniLM embedder** (L6-v2, fp32) | `gpu=164/164` ops — **zero ANE** | 3.4 ms (cpuOnly) vs **47.2 ms (.all) — 14× SLOWER** | the deliberate `.cpuOnly` default is hardware-VINDICATED |

- **Not one op on either head was planned onto the Neural Engine** — on either device.
- The MiniLM `.all` regression is dramatic: CoreML plans every op to GPU and dispatch overhead destroys a
  model this small. The historical `.cpuOnly` doctrine (set because the ANE/GPU fp16 path produced NaN at
  conversion time) is doubly justified: the NaN did NOT reproduce in this run (0/30 outputs), but the 14×
  latency loss alone settles it.
- The static `BASANEKernelEligibilityClassifier` tier table ("matMul → aneNative") is now **contradicted by
  the planner for the actual production heads**: tier tables describe op-type *capability*, not placement —
  the planner weighs model size/precision/shape, and at this scale it picks CPU/GPU, never ANE.

## What this means (honest implications)

1. **For tiny heads, CPU is the certified winner.** Context-classifier 0.085 ms, CoreML incumbent paired
   0.14 ms (T1.1 campaign) — both far below any per-turn relevance threshold. No accelerator work is
   justified at this head size (亏的不要).
2. **The "ANE-native" mandate needs a different shape of model.** The planner will only place fp16,
   appropriately-shaped, sufficiently-large networks on the ANE. Any T3.3 neural-head plan that wants ANE
   must (a) convert to fp16 (revisiting the NaN history with a per-op tolerance check), (b) re-run THIS probe
   and see `ane=` in the histogram, (c) win a paired latency gate. Until then, "ANE-native" stays an
   unearned label and CPU/CoreML stays the runtime of record.
3. **The eligibility classifier should be re-labeled** from "aneNative" to "aneCapable(op-type)" semantics in
   any future consultation work — its tiers must not be read as placement predictions (this doc is the
   correction of record; the code comment fix can ride any future touch of that file).

## Honest bounds

n=2 devices, ONE hardware model (iPhone Air, A-series of this generation); fp32 model artifacts as shipped;
`MLComputePlan` reports the PLANNER's intent (the strongest in-process signal — actual silicon dispatch can
differ only further AWAY from ANE, not toward it); A/B wall-clock includes feature-provider overhead equally
on both sides. Probe is observation-only — no production configuration changed.
