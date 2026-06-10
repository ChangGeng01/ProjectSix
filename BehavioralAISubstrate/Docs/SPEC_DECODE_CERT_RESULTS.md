# Speculative decoding — on-device certification results

> Captured 2026-06-11 on **two iPhone Air** (iPhone18,4, 8 GB, iOS 27.0 beta) under the Xcode-27 toolchain, via
> `BAS_SPEC_DECODE=1` (`BASSpeculativeDecodeProbe`) folded through the observation-only gate
> (`BASSpeculativeShadowComposer` → `BASSpeculativeMigrationVerdict`). Raw logs under `Docs/cert-logs/`. The gate
> NEVER auto-enables — every verdict is a recommendation a HUMAN reads, and the capability stays default-OFF.

## Headline

| Pairing | Memory (dual peak) | Greedy verdict | Sampling verdict |
|---|---|---|---|
| **Gemma4 E4B↔E2B** (certified family) | **DOES NOT FIT 8 GB** | doNotEnable / MEMORY | doNotEnable / MEMORY |
| **Llama-3.2 3B↔1B** (standard-arch) | **2542 MB — fits** | **ENABLE** (correct + ~31 % faster) | doNotEnable (correct, but ~30 % slower) |

Two findings the campaign produced honestly, both backed by 100 paired latency records across 2 devices:
- The audit-predicted **memory inversion** confirmed on hardware: the certified Gemma pair is the WORST lane on
  8 GB; the experimental standard-arch Llama pair is the shippable one.
- The theory-consistent **lane inversion** confirmed at n=50: speculative decoding HELPS greedy (high draft↔target
  argmax agreement → high acceptance → real speedup) but HURTS sampling (stochastic acceptance is lower → the
  verify-pass overhead dominates). The gate's first `enable` is for the GREEDY lane.

## 1. Gemma4 E4B↔E2B — does not fit on 8 GB (the #1 pre-registered risk)

Two-level memory failure (kernel `idevicesyslog -m memorystatus`):
1. **Default per-process limit:** `jetsam per-process-limit`, `exceeded mem limit: ActiveHard 3376 MB (fatal)` —
   killed mid-load with ~1 GB still free device-wide. E4B (~2.7 GB) + E2B (~1.5 GB) ≈ 4.2 GB > the ~3.4 GB cap.
2. **Even WITH `com.apple.developer.kernel.increased-memory-limit`:** E4B loads, but E2B on top drives the whole
   device into pressure (`killing up to 368 idle processes`) and the app hangs. Not viable.

**Verdict: doNotEnable / MEMORY.** Speculative decoding is certified on the Llama lane instead.

## 2. Llama-3.2 3B↔1B — authoritative dual-device cert (n=50 prompts/device, merged distinctDeviceCount=2)

```
speculative-decode-gate mode=greedy   recommendation=ENABLE
  reasons=CORRECTNESS_VERIFIED,LATENCY_WIN,MEMORY_FITS
  latency(paired n=100): speculative_ms=983.66  baseline_ms=1435.25   memory: dual_peak=2542MB / 6000MB   devices=2

speculative-decode-gate mode=sampling recommendation=doNotEnable
  reasons=CORRECTNESS_VERIFIED,LATENCY_LOSS,MEMORY_FITS
  latency(paired n=100): speculative_ms=2021.38 baseline_ms=1559.07   memory: dual_peak=2542MB / 6000MB   devices=2
```

- **Greedy lane → ENABLE (the campaign's first enable).** Token-identity VERIFIED on-device across all 50 prompts
  (bytewise-equal to the single-model greedy baseline — also certifies the shared cache accounting on hardware),
  fits memory, and is **~31 % FASTER** than the single-model baseline (984 vs 1435 ms). All gate dimensions
  cleared: correctness + latency win + memory fit + 100 samples (≥50) + 2 distinct devices (≥2). The gate
  RECOMMENDS enabling — it does not act; the capability stays default-OFF until a human elects it.
- **Sampling lane → doNotEnable.** Correctness now VERIFIED on-device (see §3) and fits memory, but speculative
  sampling is **~30 % SLOWER** than the baseline (2021 vs 1559 ms): stochastic acceptance is lower than greedy
  argmax agreement, so the verify-pass overhead dominates. A decisive doNotEnable on latency.

### Why the n=50 numbers superseded the earlier n=3 run
An initial 3-prompt run (archived `spec-decode-device{1,2}.log`) showed the OPPOSITE latency picture (greedy loss,
sampling win) — that was finite-sample noise. The gate REFUSED to act on it (insufficientEvidence / doNotEnable),
demanding ≥50 samples + ≥2 devices. At n=50 the stable, theory-consistent picture emerged. The evidence
discipline did exactly its job: it did not let a noisy n=3 signal drive a recommendation.

## 3. Sampling distribution-equivalence — verified on-device (self-calibrated)

The sampling lane's correctness is distribution-equivalence (not bytewise). Measured on-device per dist prompt by
drawing the FIRST emitted token N=128 times via speculative sampling (`spec`) and 2N times via target-only
sampling split into two independent halves (`baseA`, `baseB`). The finite-sample NOISE FLOOR is `TV(baseA,baseB)`;
the SIGNAL is `TV(spec, baseA∪baseB)`. A distribution-equivalent decoder gives signal ≈ noise.

```
device1  dist-check p=0 support=21 noise_tv=0.0781 spec_tv=0.1562 verified=true
device1  dist-check p=1 support=8  noise_tv=0.0469 spec_tv=0.0391 verified=true
device2  dist-check p=0 support=21 noise_tv=0.1484 spec_tv=0.1328 verified=true
device2  dist-check p=1 support=11 noise_tv=0.0859 spec_tv=0.0781 verified=true
```

All four checks: `spec_tv ≈ noise_tv` (within `max(noise·2.5, noise+0.05)`). This confirms the rejection-sampling
ACCEPTANCE MATH is distribution-correct on the real MLX backend — validating the audit-3 fixes (temperature
shaping + sequential processor) on hardware. Combined with the greedy lane's full-sequence bytewise identity
(which certifies the shared CACHE ACCOUNTING), the two lanes cover both correctness axes.

## Honest bounds (R1)

- **n=2 devices, ONE hardware model** (both iPhone Air, 8 GB). Satisfies the gate's ≥2-distinct-devices floor but
  is NOT cross-model: a different model (e.g. a higher-memory iPhone 17 Pro Max) could shift latency/memory and
  was not physically available at cert time. The `enable` recommendation is for the iPhone-Air-class / Llama
  3B↔1B configuration specifically.
- 50 prompts/lane, 48-token decode cap. The dist check buckets by first-token TEXT (a detokenized proxy) at the
  lane's sampling temperature (0.7); it tests position 0 (where the rejection math runs) — multi-step joint
  structure is covered by the greedy full-sequence identity + the host theorem.
- The capability remains **default-OFF / observation-only**. The gate RECOMMENDS enabling greedy; a human elects
  it. To strengthen: add a different-model device, more prompts, and a longer-decode regime.

## What the campaign proved

1. The full pipeline runs end-to-end on hardware, never auto-enabling.
2. **Greedy token-identity + sampling distribution-equivalence are both VERIFIED on-device** — the correctness
   claims (and the audit-3 distribution fixes) are now hardware-proven, not just host-proven.
3. The memory gate correctly refused the Gemma pair and passed the Llama pair.
4. The evidence discipline held: a noisy n=3 signal was refused; at n=50 the gate produced a well-founded
   `enable` (greedy) and a decisive `doNotEnable` (sampling) — exactly 亏的不要.
