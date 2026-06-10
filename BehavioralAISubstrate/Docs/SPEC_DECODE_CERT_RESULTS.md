# Speculative decoding — on-device certification results

> Captured 2026-06-11 on **two iPhone Air** (iPhone18,4, 8 GB, iOS 27.0 beta) under the Xcode-27 toolchain, via
> `BAS_SPEC_DECODE=1` (`BASSpeculativeDecodeProbe`) folded through the observation-only gate
> (`BASSpeculativeShadowComposer` → `BASSpeculativeMigrationVerdict`). Raw logs archived under
> `Docs/cert-logs/spec-decode-device{1,2}.log`. The gate NEVER auto-enables — every verdict below is a
> recommendation a human reads.

## Headline (亏的不要)

| Pairing | Memory (dual peak) | Greedy verdict | Sampling verdict |
|---|---|---|---|
| **Gemma4 E4B↔E2B** (certified family) | **DOES NOT FIT** | doNotEnable / MEMORY | doNotEnable / MEMORY |
| **Llama-3.2 3B↔1B** (standard-arch) | **2533 MB — fits** | doNotEnable / LATENCY_LOSS | insufficientEvidence (LATENCY_WIN, correctness unproven on-device) |

The audit-predicted **inversion confirmed on hardware**: the *certified-family* Gemma pair is the WORST
spec-decode lane on 8 GB; the *experimental* standard-arch Llama pair is the shippable one.

## 1. Gemma4 E4B↔E2B — does not fit on 8 GB (the #1 pre-registered risk, materialized)

Two-level memory failure (kernel `idevicesyslog -m memorystatus`):

1. **Default per-process limit:** `jetsam per-process-limit (code 7)`, `exceeded mem limit: ActiveHard 3376 MB
   (fatal)` — killed mid-load with ~1 GB still free DEVICE-wide. E4B (~2.7 GB) + E2B (~1.5 GB) ≈ 4.2 GB > the
   ~3.4 GB default app cap. (E4B had never run on-device before — endurance always used E2B.)
2. **With `com.apple.developer.kernel.increased-memory-limit`:** no per-process kill (E4B loads), but loading
   E2B on top drove the WHOLE DEVICE into pressure — `Pressure level has been elevated for too long. killing up
   to 368 idle processes` — and the app HUNG in the draft load. Not viable.

**Verdict: doNotEnable / MEMORY.** The increased-memory-limit + extended-virtual-addressing entitlements were
added to the cert app (they ARE provisionable via Automatic signing) so the limit could be probed — but the
honest conclusion stands: Gemma4 E4B+E2B dual residency is not deployable on the 8 GB iPhone Air.

## 2. Llama-3.2 3B↔1B — fits; measured per-mode (merged, distinctDeviceCount=2, n=6 paired)

```
speculative-decode-gate mode=greedy   recommendation=doNotEnable
  reasons=CORRECTNESS_VERIFIED,LATENCY_LOSS,MEMORY_FITS,SAMPLES_BELOW_MIN
  correctness=verified   latency(paired n=6): speculative_ms=1229.67 baseline_ms=1025.83   memory: 2533MB/6000MB

speculative-decode-gate mode=sampling recommendation=insufficientEvidence
  reasons=CORRECTNESS_NO_EVIDENCE,LATENCY_WIN,MEMORY_FITS,SAMPLES_BELOW_MIN
  correctness=n/a        latency(paired n=6): speculative_ms=975.33 baseline_ms=1409.33    memory: 2533MB/6000MB
```

- **Greedy lane — doNotEnable (LATENCY_LOSS).** Token-identity VERIFIED on-device (the speculative greedy stream
  is byte-equal to the single-model greedy baseline — the core correctness claim, confirmed on hardware) and the
  pair fits memory. BUT speculative greedy is **~20 % SLOWER** than the single-model baseline at this regime
  (short prompts, 64-token decode cap): the draft-acceptance savings do not overcome the verify-pass overhead.
  A decisive doNotEnable.
- **Sampling lane — insufficientEvidence (a real but unconfirmed LATENCY_WIN).** Speculative sampling is
  **~31 % FASTER** than the baseline (975 vs 1409 ms), consistently across both devices, and fits memory. The
  gate still refuses to enable: on-device correctness (distribution-equivalence) was NOT measured here
  (CORRECTNESS_NO_EVIDENCE — it is the host-proven property of `BASSpeculativeRejectionSampler`, not re-checked
  on device), and the sample count (n=6) is far below the ≥50 bar. The latency win is the strongest positive
  signal of the campaign, but the gate honestly will not recommend enabling without device-measured correctness
  and more samples.

## Honest bounds (R1)

- **n=2 devices, ONE hardware model** (both iPhone Air, 8 GB, iOS 27 beta) — satisfies the gate's ≥2-distinct-
  devices floor but is NOT cross-model coverage (a 6 GB or higher-memory device could differ).
- **3 prompts/lane, 64-token decode cap** — tiny sample; latency numbers are noisy (per-prompt baseline greedy
  ranged 601–2563 ms). The mode-level means are directional, not a throughput cert.
- Greedy correctness is **bytewise on-device**; sampling correctness is host-proven only (the gate marks it
  NO_EVIDENCE on device — no overclaim).
- The capability remains **default-OFF / observation-only**; nothing here enables it. Re-run with more prompts,
  an on-device sampling distribution check, and a higher-memory device to move the sampling lane past
  insufficientEvidence.

## What the campaign proved

1. The whole pipeline runs end-to-end on hardware: dual-residency load → speculative + baseline drive → paired
   measurement → per-mode ledger → composer → verdict → render — all observation-only, never auto-enabling.
2. **Greedy token-identity holds on-device** (the bytewise-correctness claim is now hardware-verified, not just
   host-proven).
3. The memory gate is real: it correctly refused the Gemma pair (would have OOM'd) and passed the Llama pair.
4. The honesty gates fire exactly as designed — LATENCY_LOSS kills greedy, NO_EVIDENCE + SAMPLES_BELOW_MIN hold
   sampling at insufficient despite a real latency win.
