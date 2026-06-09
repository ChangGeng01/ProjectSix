# Upstream issue draft — mlx-swift / mlx: on-device (iOS) decode wedge — uncancellable infinite hang in `eval`, GPU exonerated

> Draft for filing at https://github.com/ml-explore/mlx-swift/issues (cross-ref mlx core). Prepared from
> on-device measurements in this repo's ADR-038 §10 / §10.2 / §10.3. Review before filing; trim repo-specific bits.

## Summary

On a physical iPhone (iPhone Air, iOS 26.5), autoregressive LLM **decode occasionally wedges**: the calling
thread parks **forever** inside `eval`, **uncancellable**, and every subsequent `eval` in the process freezes
behind the process-global `evalLock`. Crucially, **the GPU is healthy the whole time** — a *separate*, MLX-free
`MTLCommandQueue` keeps completing trivial command buffers (~4 ms each) **during** the wedge, and **killing +
relaunching the process fully recovers with no device reboot**. So this is **not** a GPU/driver/firmware hang and
**not** OOM — it is a **process-local, CPU-side lost-completion-signal** in MLX's scheduler.

We isolated it with a sequence of on-device controls (details below) and localized the block to
**`scheduler::wait_for_one()`** (the `completion_cv` is woken only by `notify_task_completion`, which is fired
from a command buffer's `addCompletedHandler` — if that handler never fires, the wait parks forever).

## Environment

- Device: iPhone Air (A-series), physical device (not Simulator). Reproduces on **iOS 26.5 AND iOS 27.0
  (Build 24A5355q)** — i.e. a newer OS does not fix it (the GPU is exonerated; see below).
- Model: Gemma-4-E2B 4-bit (quantized), via MLXLLM/MLXLMCommon generate (`ChatSession.respond`).
- **Latest MLX stack:** mlx-swift-lm **3.x main line** (has SpeculativeGenerator + batched RoPE); mlx-swift core
  0.31.1 (latest 0.31.4 has no scheduler/eval/generate change). So this is **not** a stale-version artifact.
- Reproduces reliably with **large prefills** (a big enriched feed-forward prompt wedges within ~3 decodes);
  small prompts wedge variably (~12 to 56+ decodes, or not in a short window). Cumulative/probabilistic.

## Critical observation: SPINNING (not frozen) + UNBOUNDED allocation

With per-wait tripwires (`--console`), at the wedge the process is **actively running thousands of evals**
(`scheduler::wait_for_one` called ~5600–5750×, all returning) while producing **zero** new tokens — `respond()`
for the wedged turn never returns. The GPU keeps completing work (each `wait_for_one` returns) → **CPU-side
livelock, not a GPU hang**. A drain-trip diagnostic at `transforms.cpp` (the throttle in `eval_impl`) shows:
- **The throttle trips on the TASK clause**: `n_active_tasks()` is **pinned at exactly 11** (> `MAX_ACTIVE_TASKS=10`),
  with `mem_trip=0` on **every** trip — `get_active_memory()` (134→2585 MB) stays far below `get_memory_limit()`
  (~11 GB). So it is **not** the memory-pressure clause.
- **`get_active_memory()` grows UNBOUNDEDLY** (134 → 2585 MB and still climbing when killed at 240 s) for a single
  turn whose prompt is only ~35–134 tokens. A finite prefill/step graph would peak then emit a token; this looks
  like an **unbounded allocation / re-evaluation** — something keeps submitting work / never marks an output
  available. This is the core unresolved question.

## Levers we tried that did NOT fix it (so you can skip them)

- **Bounding `Event::wait`** (a finite timeout via `waitUntilSignaledValue(value(), ms)`): the timeout **never
  fired** at the wedge → the decode does not block in `Event::wait`.
- **Raising `MAX_ACTIVE_TASKS`** (10 → 64): **still wedged** (if anything earlier) → the `wait_for_one` throttle
  is a *symptom*, not the cause.
- **`Memory.clearCache()` / a small `Memory.cacheLimit`**: made it **worse** (earlier wedge).
- **Newer mlx-swift / -lm**: we are already on the latest LM line; no relevant fix in 0.31.2-0.31.4.
- **`TokenIterator.next()` stop condition is correct** in the vendored copy (`if tokenCount >= maxTokens { return
  nil }`) → not a runaway-past-maxTokens loop.
- **Chunking the Gemma4 (VLM) prefill** (mirroring `LLMModel.prepare`'s chunked loop, at chunk size 32):
  **still wedged** → the un-chunked prefill *graph size* is not the cause.
- **Raising the memory limit is irrelevant**: the drain-trip is the task clause, never the memory clause
  (`active_memory` ≪ `memory_limit`).

## Where it points (for a maintainer)

The remaining, unresolved question is **why `n_active_tasks` pins at 11 and `active_memory` grows unbounded for a
single short turn that emits no token** — i.e. what keeps submitting GPU work / never marks the turn's output
array available, specifically for **Gemma4 (Gemma-3n E2B, per-layer-inputs architecture)** on iOS. It is NOT the
generic decode loop (small prompts/other models don't wedge), NOT `Event::wait`/`synchronize`, NOT the throttle
ceiling, NOT memory pressure, NOT prefill graph size. It is cumulative across turns (fresh `ChatSession` each
turn, so it is MLX *process-global* state, not session/KV state). A repro harness can be shared.

## What we measured (the controls that exonerate the GPU)

1. **Sibling Metal queue stays alive during the wedge.** A concurrent, **MLX-free** probe (its own
   `MTLDevice`/`MTLCommandQueue` + a trivial compute kernel, completion via `addCompletedHandler` + a *timed*
   `DispatchSemaphore`) completed **56/56** samples at ~4 ms — including **8+ samples AFTER decode froze**. A
   GPU/driver-wide hang cannot keep executing another queue's command buffers.
2. **Bare Metal after kill = fine.** Post-wedge, a fresh process running only the trivial Metal probe →
   all-completed, ~0.7 ms median.
3. **Full MLX relaunch after kill = fine, no reboot.** Post-wedge, relaunching the full model → loads + decodes
   normally + completes. Reproduced n=2. (This retired our earlier "GPU poisoned until reboot" hypothesis as a
   harness confound.)
4. **Not OOM.** Wedges fire with 700+ MB free; `Memory.clearCache()` made it fire *earlier*, not later.

## Localization (mlx-swift vendored mlx 0.31.1 line refs)

- The decode `eval()` path: `eval(outputs)` → `eval_impl(...).wait()` (transforms.cpp) → `array::wait()` →
  `event().wait()` → **`Event::wait()`** (backend/metal/event.cpp), which calls
  `waitUntilSignaledValue(value(), -1)` — an effectively-infinite wait (`-1` → `UINT64_MAX` ms).
- **We tested an opt-in finite timeout on `Event::wait` on-device — it did NOT fire at the wedge.** So the block
  is *not* `Event::wait`.
- **Prime suspect: `scheduler::wait_for_one()`** (scheduler.h): `completion_cv.wait(lk, [...] {
  n_active_tasks() < n_tasks_old })`. `n_active_tasks_` is decremented + `completion_cv.notify_all()` only by
  **`notify_task_completion`**, which is invoked from a command buffer's `addCompletedHandler`
  (backend/metal/eval.cpp). **If that completion handler never fires (or fires without advancing the counter),
  `wait_for_one()` parks forever** — matching every symptom (CPU-side, uncancellable, GPU still healthy,
  cleared by process restart). Other candidates we have not yet ruled out: `gpu::synchronize`'s
  `cb->waitUntilCompleted()` (eval.cpp; no timeout API) and `Fence::wait` (backend/metal/fence.cpp).

## Why it is uncancellable / unrecoverable in-process

- The whole synchronous `eval` runs under a **process-global** `NSRecursiveLock evalLock`
  (Transforms+Eval.swift), so one wedged decode freezes **every** `eval` in the process.
- There is **no in-wait cancellation** — `Task.isCancelled` is only checked *between* tokens in the generate
  loop, never inside the blocking wait.
- **The error path is swallowed even if it fires:** `mlx_eval` (mlx-c) catches `std::exception` → `mlx_error()`
  → returns 1, but **mlx-swift discards the return code** (`_ = evalLock.withLock { mlx_eval(...) }`,
  Transforms+Eval.swift). So a bounded/throwing wait would not surface to Swift callers without also propagating
  the code (or installing a throwing `mlx_error` handler).

## Requests

1. **A cancellable / timeout-bounded eval path** (honor `Task.cancel`, or a deadline) so a wedged decode becomes
   a catchable error instead of an uncancellable infinite hang.
2. **Robustness against a lost completion signal in the scheduler** — e.g. a bounded `wait_for_one` that surfaces
   a diagnostic (`n_active_tasks`, last-committed buffer status) instead of parking forever; and/or hardening the
   `addCompletedHandler → notify_task_completion` path so a completed/abandoned command buffer always advances
   the counter.
3. **Propagate `mlx_eval` failures to Swift** (check the return code / a throwing error hook) so callers can
   recover rather than silently continue.

## Repro sketch

Run MLXLLM generate on an iPhone with Gemma-4-E2B-4bit in a loop with **large prefills** (e.g. feed each turn's
output back as the next prompt). Within a few decodes the generate call hangs permanently; a concurrent
`MTLCommandQueue` continues to complete command buffers; killing + relaunching the app resumes normally with no
reboot. (We can share a minimal harness.)

## Cross-reference

This repo's ADR-038 §10/§10.2/§10.3 has the full measurement log, the MLX-free probe
(`BASMetalGPUProbe`), and the experiment scripts.
