# Dual-Device 10h Run — Data-Driven Component Verdict (2026-06-12)

Source: the 2-device 10h sweep `Docs/cert-logs/dual-device-20260612-034321/` (deviceA-llama A1–A4,
deviceB-e2b-recovery B1–B3; gitignored — carries device sovereign keys + sqlite). Doctrine: 实测胜出才晋升 ·
亏的不要 · ADR-014 (default-off = byte-equal) · ADR-039 (decode is the observation lane).

**Data-quality note:** the per-phase subdirs within a device are byte-identical COPIES (same md5) — the
42 spec-defaulton "hits" collapse to **2 real runs (1/device)**, not 8 independent samples. Device A vs B
genuinely differ. The authoritative speculative numbers are the gate's own merged n=100 / 2-device lines.

## Scorecard

| Lever | Key number (read from logs) | Verdict |
|---|---|---|
| **Greedy spec-decode (Llama 3B↔1B), deterministic lane** | merged n=100 `speculative_ms=983.66` vs `baseline_ms=1435.25` → **1.459× (+31.5%)**, recommendation=**ENABLE**; per-device A 1.49× / B 1.43×; `stream_byte_identical=10/10`, `draft_byte_identical=10/10` both devices; `dual_peak=2542 / 6000 MB` | **PROMOTE** (the one certified decode win) |
| Sampling spec-decode lane | merged n=100 `2021.38` vs `1559.07` → **0.77× (−29.7%)**, `doNotEnable` | **DECLINE** |
| `numDraftTokens` default (=2) | greedy A3 sweep baseline drift **+73.1%**, n2 hottest @1716ms, `INCONCLUSIVE-WITHIN-DRIFT`; the only n=1 "win" is sampling-lane + self-flagged directional | **HOLD = 2** |
| Llama-3B sustained decode + thermal (10h) | pooled nominal **38.3 tok/s** (n=283); thermal never left **nominal/fair** (serious=0, critical=0); `active_cpu=6/6` 100%; cooldown plateau capped **100s** (180s/300s floors never hit); rss declines (no leak) | **No throttle exists**; cooldown floors are dead margin on this device/model |
| **E4B vs E2B on 11.5 GB iPhone Air** | E4B = **2 jetsam deaths at weight-load** (responses=0) + 1 MetricKit `memoryException`; E2B survives `peak 3114 MB / avail 261 MB` under the **~3376 MB ActiveHard cap** | **DECLINE E4B / PROMOTE E2B** on ≤12 GB |
| U1 governor / U3 liveness fire-under-pressure | governor markers = **0**; liveness `ARMED ×734, 0 trips` | **INCONCLUSIVE** (armed, never crossed threshold — the only failure was instant mid-load jetsam, which both bypass) |
| ANE for decode | ANE ops = **0** everywhere; embed CPU-only **0.07–0.08×** vs GPU/ANE (13× slower) | **DECLINE** (confirms ADR-039; decode stays CPU byte-deterministic) |
| Metal SSM/attn parity (ch1065) | `parity_mae=1.421e-09` wherever Metal ran (A19) | **HOLDS** (observation lane) |
| Core AI on-device migration | parity `agree=56/56 max_mae=1e-6` BUT gate `doNotMigrate ×7`: candidate **4–6× slower** (0.61–0.80 vs 0.14 ms), MEMORY_LOSS, devices=1 | **stay shadow** (ADR-041; parity met, latency/memory/min-device unmet) |

## Landed this commit (byte-safe, data-grounded)

- **`BASMLXMemoryBudget` pre-load admission gate** — `measurediPhoneAirActiveHardCapBytes` (3376 MB) +
  `estimatedPeakFootprintBytes(forProviderID:)` (MEASURED E2B 3114 / Llama-3B 2969; DERIVED E4B 4314 =
  weights + the measured Gemma-3n overhead) + `wouldExceedActiveHardCap(...)`. The E4B deaths happened
  *at load, before the first token*, so no runtime watermark/liveness can catch them — only a PRE-LOAD
  check. A nil estimate ⇒ ADMIT (never refuse what the data can't justify). +4 tests.
- **`MLXModelCatalog.recommendedDefault(forActiveHardCapBytes:)`** — device-aware selector: returns E2B
  under the iPhone Air cap (where E4B jetsams), E4B under a larger cap. **Additive** — does NOT change
  `defaultEntries` or the hardcoded `MLXOrganAdapter` default (byte-equal-off, ADR-014); a host opts in.

## Landed in the follow-up (08d2fec4e — operator-elected)

- **In-`loadModel` admission enforcement** — opt-in `enforceMemoryAdmission` + `activeHardCapBytes` on
  `MLXOrganAdapter` (default off ⇒ byte-equal). When on, `loadModel` refuses an over-cap single-model
  load BEFORE the materialize step → catchable error instead of the uncatchable mid-load jetsam.
- **`prewarmGreedySpeculative()` wired into host warm-up** — `BASEnduranceAppRunner` JITs the greedy spec
  lane (`try?`, best-effort) right after `loadModel`, before the first scored turn; the concurrent method
  itself was committed per operator direction (verified sound). Byte-safe (falls back to `prewarm()`).

## Deferred (data-backed but gated)

- **Lower the steady-state cooldown plateau** (<100s) to reclaim wall-clock — data shows ample thermal
  headroom (never left nominal/fair), but this changes iter cadence → needs its own cold-device A/B;
  default stays 100s until measured. (Operator has signalled willingness to run hotter.)
- **Adopt `BASDecodeLanePolicy` (deterministic/factual → greedy) at production call sites** — the seam is
  host-electable; the verifier default-flip to greedy still needs a verification-quality A/B.

## Open (needs a targeted re-run — data could not answer)

1. Clean **cold-device randomized greedy `numDraftTokens` sweep** (every greedy sweep so far drifted +73%).
2. Does the U1 governor `dropDraft`/`restoreDraft` loop actually fire+recover? (0 markers — never crossed
   the watermark; needs a deliberately-over-budget pair or shrunk budget to exercise it.)
3. Does the U3 liveness monitor trip+surface a verdict? (`ARMED, 0 trips`; needs a real decode-time wedge.)
4. Exact E4B kill footprint (it died before any sys line — the 4314 MB is derived, not read).
