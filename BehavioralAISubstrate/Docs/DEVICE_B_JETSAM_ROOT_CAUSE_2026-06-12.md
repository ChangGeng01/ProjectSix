# Root-cause: device-B "卡死" during the 10h dual-device run (2026-06-12)

**Verdict: it is JETSAM (memory OOM kill on the model-load spike), NOT the MLX GPU wedge.**
The Gemma device died 355× during the run; rigorous forensics from the live data pin the cause to
memory, and identify a non-obvious property of the Gemma-3n architecture.

## Evidence (live run, deviceB = Gemma-4-E4B then E2B)

| | active MLX mem | footprint | headroom vs 3376MB jetsam cap | outcome |
|---|---|---|---|---|
| A Llama-3.2-3B (dense) | **1723.7 MB** | 2617.5 MB | **758 MB** | 0 jetsam, 0 wedge — clean |
| B Gemma-4-E2B (nested) | **2512.6 MB** | 3104.9 MB | **271 MB** | jetsam on load spike, 355× |
| B Gemma-4-E4B (original) | ~4 GB est. | > cap | negative | died on first load (never decoded) |

Distinguishing facts (why memory, not GPU wedge):
1. **355 of 361 watchdog recovery events were "APP GONE" (process vanished, procs=0), only 6 were
   stall-wedges.** A GPU wedge leaves the process ALIVE but stalled; a vanished process is a kill.
2. **All 355 "APP GONE" fired at responses=0** (during model load, before any decode) — a load-time
   death, the signature of a load-spike jetsam.
3. **The U3 liveness monitor (in-app, GPU-probe-backed) reported 0 decode stalls.** If this were the
   GPU wedge, the GPU-probe would have flagged it. Zero stalls = not a GPU hang.
4. **`app_alive` is reliable** (8/8 rapid devicectl queries returned procs=1) — the "APP GONE" events
   are real kills, not false positives from a flaky process query.

## The non-obvious finding: Gemma-3n "E2B" ≠ 2 GB

Gemma-3n is a nested / MatFormer architecture: the "**E2B**" / "**E4B**" names describe the EFFECTIVE
(selectively-activated) parameter count, NOT the loaded weight size. The actual 4-bit weights are far
larger than a dense model of the same "effective B":

- **Gemma-3n E2B loads 2512 MB active — MORE than dense Llama-3.2-**3B**'s 1723 MB.**
- Gemma-3n E4B loads ~4 GB → exceeds the 3376 MB per-process jetsam cap outright (never survives load).

So the model NAME misleads memory budgeting. On an 8 GB iPhone with a ~3376 MB per-process jetsam cap,
**Gemma-3n is the memory-hostile architecture for on-device endurance**, the opposite of what "E2B"
implies. Dense models (Llama / Qwen) at the same nominal size are far lighter.

## Compounding factor: unbounded cross-restart memory growth

The durable, cross-restart self-populating memory store GREW across the 355 relaunches:
`store_atoms` went **129 → 504** (and vector_index_entries 129 → 504). Each relaunch reloads the larger
store, so the footprint creeps UP over a long churning run — shrinking the jetsam margin further with
every restart. A bounded / pruned self-populate cap across restarts would stop this creep.

## What this means for future development

1. **Pick dense architectures (Llama, Qwen) for on-device endurance.** Gemma-3n's nested weights blow
   the memory budget; Llama-3.2-3B ran 0-jetsam / 0-wedge with 758 MB headroom.
2. **Budget by MEASURED active memory, not the model's "B" name.** Gemma-3n E2B = 2.5 GB active.
3. **Bound the model-load spike** for any marginal model: the steady state (3105 MB) was under the cap,
   but the LOAD transient tipped it over. `MLX.Memory.memoryLimit` (makes malloc wait instead of
   jetsam) bounds the spike; a lower `BAS_MLX_CACHE_LIMIT_MB` (256) buys ~256 MB of headroom.
4. **Cap the cross-restart self-populate growth** so footprint doesn't creep over a long run.
5. **The U3 liveness monitor earned its keep:** it correctly distinguished memory-death (0 GPU stalls)
   from a GPU wedge — the diagnosis above rests on that signal.

## The watchdog held the line

The fixed watchdog (915a94aea: mlx_count integer fix + app_alive crash detection) survived all 355
jetsam kills by kill+relaunch — without it, device B would have stayed dead after the first one. The
run kept producing fragmented Gemma data + this jetsam-rate evidence. That is the ADR-038 external-
recovery doctrine working as designed.
