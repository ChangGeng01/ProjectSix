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
- **Action taken (operator-elected):** on this `enable` recommendation, GREEDY speculative decoding is now
  **default-ON, but GATED** (see below). Sampling stays OFF (certified doNotEnable). To strengthen the bound
  further: add a different-model device, more prompts, and a longer-decode regime.

## Action: greedy speculative decoding is now default-on (gated, byte-identical fallback)

Acting on the greedy `enable`, `MLXOrganAdapter.speculativeDecoding` now defaults to `.greedy` — but it engages
ONLY where it is provably net-positive and safe. Three gates, each failing closed to single-model (byte-identical):

1. **Request gate (byte-safety):** only a GREEDY request (`temperature == 0`) speculates. A scout (0.1) / core
   (0.7) request is a SAMPLING request — converting it to greedy would change its output, so it stays single-model.
   Enforced by `MLXOrganAdapter.requestEligibleForSpeculation`.
2. **Capability gate (memory):** the draft is auto-resolved from `speculativePairings` and auto-loaded ONLY if the
   estimated dual residency fits a conservative per-process budget (`BASMLXMemoryBudget.dualResidencyFits`,
   default 3000 MB). So Llama/Qwen 3B↔1B (~2.5 GB) engages; Gemma4 E4B+E2B (~4.2 GB) does NOT (stays single-model,
   matching the §1 finding). No `increased-memory-limit` entitlement required for the Llama pair.
3. **Sampling stays OFF:** never auto-engaged (certified doNotEnable — slower); a host must elect it explicitly.

Net effect: a greedy turn on a fitting same-family pair gets the ~31 % latency win at byte-identical output; every
other turn is unchanged. ADR-014 spirit preserved (turn outputs do not change). A host can opt out
(`speculativeDecoding: .off`) or raise the fit budget on an entitled / higher-memory device
(`speculativeFitBudgetBytes:`).

## Satisfaction pass — closing the residual gaps (hardware-verified)

### The shipping default-on AUTO path is hardware-verified (both devices, `verified=true`)

The n=50 cert drove explicitly-constructed adapters; the actual default path had only host tests. The
`BAS_SPEC_DEFAULTON` probe ran THAT path — bare `MLXOrganAdapter(model: .speculativeOptimalTarget)`, everything
auto — on both iPhone Airs:

```
gemma-default will_engage=false            (the shipping Gemma default correctly DORMANT — no load attempted)
auto-plan     will_engage=true draft=mlx.llama3_2.1b.it.4bit
auto-loaded   speculation_active=true draft_load_failure=none
RESULT        stream_byte_identical=10/10  draft_byte_identical=10/10
FINAL         verified=true                (identical on device 2)
```

This also hardware-verifies the NON-STREAMING `draft(_:)` speculative route (10/10 bytewise) and the new
observability surface (`isSpeculationActive` / `draftLoadFailureReason`). Note: on this short-answer 10-prompt
set spec ≈ base (~879 vs ~891 ms) — the latency CLAIM remains the n=50 cert's ~31 %; this probe certifies the
PATH and BYTES, not throughput.

### Coverage note — which entry points speculate

`streamDraft(_:)` AND `draft(_:)` both route through the gates. `draftMultiTurn` is DELIBERATELY excluded: its
value is ChatSession KV-cache reuse (only the new turn prefills); the speculative path builds fresh caches per
call, so routing multi-turn through it would re-prefill the whole conversation every turn — a net loss (亏的不要).

### numDraftTokens sweep (sampling lane) — DIRECTIONAL, not a cert

`BAS_SPEC_SWEEP` measured the sampling lane at numDraftTokens ∈ {1,2,3} (10 short prompts/config, Llama pair):

| | n=1 | n=2 | n=3 | baseline |
|---|---|---|---|---|
| device 1 | **855 ms** | 1013 | 1029 | 1479 |
| device 2 | **821 ms** | 1031 | 1244 | 1413 |

Cross-device-consistent direction: **n=1 is markedly better than the default n=2**, and on THIS prompt set every
n beat the baseline. TWO honest confounds: (a) fixed run order (n=1 coolest → baseline hottest; thermal drift
inflates later configs), (b) prompt-set sensitivity — the n=50 cert (50 varied prompts) measured sampling n=2 as
~30 % SLOWER, so the cert's `doNotEnable` REMAINS the authoritative sampling verdict. What the sweep adds: a
properly randomized n=1 / 50-prompt re-cert is the right next experiment if the sampling lane is ever wanted.

## What the campaign proved

1. The full pipeline runs end-to-end on hardware, never auto-enabling.
2. **Greedy token-identity + sampling distribution-equivalence are both VERIFIED on-device** — the correctness
   claims (and the audit-3 distribution fixes) are now hardware-proven, not just host-proven.
3. The memory gate correctly refused the Gemma pair and passed the Llama pair.
4. The evidence discipline held: a noisy n=3 signal was refused; at n=50 the gate produced a well-founded
   `enable` (greedy) and a decisive `doNotEnable` (sampling) — exactly 亏的不要.

## Tranche A1 lane confirmation (2026-06-12, decode-elevation program)

The certified-but-dormant greedy lane is now WIRED into the endurance decode path
(`BAS_GREEDY_SPEC_LANE=1`, commit 533d5a184) and was re-confirmed PAIRED on the actual device A
(iPhone Air, post-10h-run thermal state, Llama-3.2-3B↔1B, n=3 prompts, maxDecodeTokens=256):

```
🏎 greedy-spec-lane is_speculation_active=true
📊 greedy-spec-ab n=3 spec_ms=7937 baseline_ms=10659 speedup=1.34x
```

**+34% paired** (same prompts, same thermal window, draft toggled via unloadDraftModel/loadDraftModel)
— consistent with (slightly above) the n=100 cert's +31%. Absolute tok/s is NOT comparable across
sessions (the device had just finished a 10h run — hot); the paired delta is the valid number. The
production chooser for this lane is `BASDecodeLanePolicy` (deterministic/factual → greedy; A2,
20abf2d2a). The KV levers were A/B'd in the same 10h run and DECLINED at this regime
(`KV_LEVERS_DEVICE_VERDICT_2026-06-12.md`) — greedy spec-decode is the real decode lever.

## Tranche A3 — greedy numDraftTokens sweep, first run (2026-06-12): INCONCLUSIVE-WITHIN-DRIFT

The thermal-confound-killed sweep (`BAS_SPEC_GREEDY_SWEEP=1`, shuffled order + baseline bracket) ran on
device A immediately after the 10h endurance run + A1 A/B — i.e. on a HOT device:

```
shuffled_order=[3, 1, 4, 2]  baseline-pre 879ms → baseline-post 1522ms  drift=+73.1%
n=3 958 · n=1 876 · n=4 1155 · n=2 1716
FINAL best_n=1 best_ms=876 baseline_bracket_ms=1200 verdict=INCONCLUSIVE-WITHIN-DRIFT
```

**The bracket did its job**: with +73% thermal slide the config means are position-dominated (n=2 ran
last/hottest at 1716ms — hotter than the post-baseline), so the probe REFUSED the WIN the old
sequential sweep would have claimed. This run is evidence the old "n=1 best" hint was thermal, not n.

**Standing state**: `numDraftTokens` default stays 2 — independently validated by the A1 PAIRED A/B
(+34% at n=2, same-thermal-window pairing). **Re-run this sweep on a COLD device** for a clean draft-
length verdict; until then no default change.
