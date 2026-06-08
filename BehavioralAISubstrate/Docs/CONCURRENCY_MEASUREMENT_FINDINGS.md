# Concurrency / throughput — measurement findings (measure-first arc)

> **Verdict: the substrate is NOT the throughput bottleneck. The MLX GPU decode is (~98% of turn time),
> and it is inherently serial + uncancellable.** Substrate-side parallelism (stage fan-out, concurrent
> turns) would not move the needle; the storage concurrency is already fine. This arc deliberately
> MEASURED before refactoring — and the data says don't do the high-risk, low-ROI work.

## M1.1 — per-turn substrate vs MLX (on-device, iPhone Air)

From real on-device runs (MLX `latency_ms` summed per iter vs total `iter_ms`):

| iter | MLX decode | total turn | MLX % | rest (substrate+fabric+log) |
|---|---|---|---|---|
| 1 | 1866 ms | 1894 ms | 98.5% | 1.5% |
| 2 | 1666 ms | 1711 ms | 97.4% | 2.6% |
| 3 | 1837 ms | 1883 ms | 97.6% | 2.4% |
| 4 | 1736 ms | 1785 ms | 97.3% | 2.7% |

**MLX decode is 97–98.5% of every turn.** The whole substrate (brain.process L1-L14 cascade) is a fraction
of the ~2-3% remainder (which also includes fabric + per-prompt snapshots + logging). A new
`📊 ch1025 turn-breakdown` scorecard line splits `brain_ms` vs `mlx_ms` vs `other_ms` exactly.
**On-device CAPTURED (2026-06-09, iPhone Air, current binary, via `scripts/run-device-app-cert.sh`):**
`📊 ch1025 turn-breakdown iter=1 iter_ms=2577 brain_ms=21 mlx_ms=2551 other_ms=5 substrate_pct=0.8 mlx_pct=99.0`
— the substrate (L1–L14 cascade) is **0.8%** of the turn; MLX decode is **99.0%**. The macOS iter-vs-MLX ratio
(~98%) estimate is now confirmed on-device with the exact per-component breakdown (`brain_ms=21 / mlx_ms=2551`).
(Note: the full-MLX-turn run is intermittently subject to the ADR-038 MLX eval wedge — a 4-turn attempt wedged;
the 2-turn retry completed. The wedge is uncancellable/prevention-only; it does not affect this measurement's
validity, only the ease of capturing it.)

## M1.2 — L8 retrieval concurrent-read scaling (macOS, 18-core)

- **Nonisolated `cosineTopKAtomIDsSync` (the hot retrieve path) SCALES:** 1→413, 4→1423 (3.4×), 8→2520
  (6.1×), 16→2905 (7×) reads/s. It bypasses the actor and scales to ~core count — NOT a serialization
  bottleneck.
- **Actor-isolated async path:** ~800 ops/s, flat across reader counts — the serialization ceiling the
  operator flagged. But the hot read already bypasses it, so it doesn't gate retrieval.

## M1.3 — concurrent-write integrity + ceiling (macOS)

- **Event append:** 8 writers × 250 = 2000 concurrent appends → sequence numbers **gapless + unique**
  (0..<2000), no lost writes, no dup event_ids (the `BEGIN IMMEDIATE` atomicity holds under concurrent actor
  calls). ~20K appends/s.
- **Atom admit / remove (五级删除 DELETE):** 600 concurrent admits all land; 300 concurrent removes leave a
  consistent count (no double-delete, no torn count). ~21K admits/s.
- Writes serialize but are **integrity-correct + ~20K ops/s** — far above any realistic per-turn write rate.

## Phase-2 decision (gated on the data)

- **Stage fan-out (point 1) — SKIP.** The turn is ~98% MLX decode; the substrate stages are ~2%; the
  parallel groups (M1 4-way, O 12-way) are a fraction of that, and the gain is only max()-vs-sum within it.
  Refactoring the 2129-line monolithic `runTurn` to fan out for <1-2% is 亏的不要上. The dormant executors
  (`BASParallelStageDispatchExecutor`, `BASNativeStageExecutor`) stay READY + determinism-safe
  (`BASParallelStageAssembleOrder.canonicalOutputs`); wire them only if the substrate ever becomes a
  meaningful turn fraction (re-run `turn-breakdown` to re-check).
- **Scheduler (point 4) — no change.** Size-based routing already exists (`BASAutoRouteRanker`:
  `matMulMetalMinProduct`, `batchedCosineRayonMinRows=3000`) and **rayon is live** for large batches; no
  benchmark surfaced a suboptimal regime (retrieval reads scale; writes are fast). Revisit only at much
  larger corpus scale.
- **Concurrent turns (point 5) — SKIP.** The single GPU decode is the bottleneck, is serial, and is
  uncancellable (ADR-038). Concurrent turns would contend for the one GPU + amplify the MLX wedge risk for
  ZERO throughput gain (~98% of the turn is already GPU-serial). Multiple-brains is device-hostile (~100 MB
  each) — only if a real multi-user use-case demands it.
- **Concurrent reads/writes (points 2/3) — already fine** (above); no work needed.

## Where the throughput lever actually is

Throughput ≈ MLX decode tokens/s on the device GPU. The real levers are all MLX-side: smaller/faster model
or heavier quantization, fewer decode tokens (the WS2 cap), speculative decoding, or batching prompts into
one decode. The substrate is already not in the way — measure-first confirmed it before any refactor.
