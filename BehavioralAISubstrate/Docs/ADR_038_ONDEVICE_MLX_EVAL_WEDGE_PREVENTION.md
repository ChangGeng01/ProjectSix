# ADR-038 — On-device MLX/Metal GPU-eval wedge: prevention + real-device re-certification

> **Status: re-certified on iPhone Air (iOS 26.5), 2026-06-07. Run A PASS; Run B WEDGE.** The WS1 typed
> prompt did NOT eliminate the wedge (it moved iter1/prompt2 → iter2/prompt2) → **feed-forward stays
> default-OFF; prevention UNPROVEN.** Records what the HARDWARE actually showed — not inference. Per
> 亏的不要上 (R1): macOS-green ≠ certified; this ADR is written to the device's ACTUAL result, pass OR fail —
> and it failed, honestly.

## 1. The wedge (what we are preventing)

Under sustained on-device decode the substrate could hit a **synchronous, UNCANCELLABLE Metal eval that
hangs with ZERO token progress** — the app freezes mid-decode, no new tokens, no new log lines. The
historical trigger was the **Agent-Fabric feed-forward enriched prompt** built from raw JSON conclusions
(`patchJson`): an out-of-distribution (OOD) prefill for the 4-bit Gemma decoder that wedged reliably at
**iter=1 / prompt=2** (the first enriched prompt). Default-off restored a 2408-iter June-4 baseline.

**Why there is no timeout / no in-process recovery (deliberate).** A per-turn timeout was REMOVED because
a Swift task cannot cancel a synchronous Metal GPU eval — the eval owns the thread until the GPU returns.
So once wedged, the only recourse is killing the app. The strategy is therefore **PREVENTION** (lower the
trigger probability), not recovery. This ADR does not claim a recovery mechanism exists; it does not.

## 2. Prevention mechanisms (all opt-in / byte-equal-off by default)

- **WS1 — typed-summary enriched prompt** (`fe9ab255b`, `BASAgentFabricAuthoritativeProjection`). The
  feed-forward prompt no longer carries `patchJson` free-text (the OOD-prefill mass: braces/quotes/nested
  JSON). Each accepted conclusion becomes ONE typed line — `- <domain> (<deltaType>, conf X.XX)
  [<topReasonCode>]` — from a controlled vocabulary, sanitized through `plainSummary`, capped at the 512
  `maxContextBlockChars` backstop. This directly attacks the OOD-prefill trigger.
- **WS2 — explicit low decode cap** (committed this session, `BAS_INTERNAL_MAX_DECODE_TOKENS`, default
  256). Bounds decode LENGTH (defense-in-depth + more wedge-exposure coverage/hour). It does NOT lower the
  zero-token PREFILL-wedge probability — honest framing: WS1 attacks the prefill, WS2 bounds the decode.
- **Pre-existing gates:** the feed-forward stays **default-OFF** (`BAS_FABRIC_AUTH_FEEDFORWARD`), and the
  512-char context-block backstop bounds the enriched prompt regardless.

## 3. CRITICAL honesty — the prior on-device runs were INVALID (stale binary)

A 亏的不要上 catch worth recording: the first re-cert attempts this session **launched a STALE app**.
`devicectl process launch` only launches the *installed* binary — the WS1/WS2 build had been compiled but
**never installed** (the app on the device dated to the ch1063/1064 era). The tell: responses ran to
**1408 est_tokens, uncapped** — yet a WS2 build caps at 256 *even if the env var is absent* (the code
defaults to 256). So neither WS1 (typed prompt) nor WS2 (cap) was actually being exercised; an earlier
"256-cap working" read was a coincidence of short prompts. **Certifying off those runs would have been a
false certification.** Fix: rebuilt `BASDeviceTestApp` (scheme `BASDeviceTestApp`, team U4ZLQM8399) and
freshly installed it on the iPhone Air before re-running. Every result below is from the REAL WS1+WS2 build.

## 4. Run A — baseline re-cert (feed-forward OFF, 256-cap)

`BAS_FABRIC_AUTH_FEEDFORWARD=0`, `BAS_INTERNAL_MAX_DECODE_TOKENS=256`. Early-ended once clean (per the
operator's "提早结束 if no problem" directive) — a **smoke-level re-cert (~21 iters)**, NOT a full
endurance soak (stated honestly; the June-4 2408-iter anchor remains the endurance reference).

- **Cap VERIFIED:** every one of 21 mlx responses bounded to `est_tokens` 309–350 — the char-proxy of the
  256-token cap — vs **1408** on the stale build. WS2's `maxOutputTokens` genuinely reaches MLX.
- **Baseline stable:** iter=1/prompt=2 wedge point CLEARED; iters advanced monotonically; thermal
  nominal→fair (never serious/critical); 0 crashes; RSS steady (one-time model load only, no leak).
- **Verdict: PASS** — the default-off baseline does not wedge, and WS2 is real.

## 5. Run B — the decisive wedge test (feed-forward ON + WS1 typed prompt)

`BAS_FABRIC_AUTH_FEEDFORWARD=1`, typed enriched prompt (WS1), 256-cap, 10 iters × 2 prompts. **Decisive
question:** does the typed enriched prompt clear the historical iter=1/prompt=2 wedge (MLX makes token
progress, no zero-token hang)?

> **RESULT: WEDGE at iter=2/prompt=2.** The typed prompt CLEARED the historical iter=1/prompt=2 point —
> that first enriched prompt (`prompt_len=543`) decoded fine (`resp_len=1262, est_tokens=316, 6.9s,
> 45.9 tok/s`), and iter=2/prompt=1 decoded too (`est_tokens=36`). But **iter=2/prompt=2 WEDGED**: the
> orchestration set it up (L0frame / candidates / host_gate / leases all logged for iter=2/prompt=2) and
> then the MLX decode hung with **ZERO token progress** — no `mlx iter=2 prompt=2` line ever appeared; the
> log froze for ~2.5 min (>> the ~7s a normal decode takes), no crash. The app was killed (uncancellable).
> The wedge did not disappear — **it MOVED two prompts later.**

## 6. Verdict

**Prevention UNPROVEN — the wedge PERSISTS (moved iter1/prompt2 → iter2/prompt2) even with the WS1 typed
prompt.** Honest reading:

- **WS1 is a real PARTIAL improvement** — the controlled-vocabulary typed prompt cleared the exact point
  where the `patchJson` free-text reliably wedged. But it does NOT eliminate the wedge: a clean typed
  enriched prompt still triggered the zero-token Metal hang two prompts later. So the trigger is **more
  general than the `patchJson` OOD-prefill shape** — any sufficiently-enriched feed-forward prefill can
  hit it.
- **The feed-forward therefore STAYS default-OFF.** It still wedges with the typed prompt → it cannot be
  enabled. WS1 + WS2 are committed (they cleared the first point + cap decode) but they are **NOT** a green
  light for feed-forward. The default-off baseline (Run A re-confirmed stable, cap verified) remains the
  safe path — the iron rule (亏的不要上) stopped a feed-forward enablement that still wedges.
- **No in-process recovery** (unchanged — Swift cannot cancel a synchronous Metal eval).
- **Next falsification levers** (in order, each its own on-device A/B): shrink `maxContextBlockChars` to
  256 then 128; fold ONLY the top-1 conclusion; drop the `[reasonCode]` provenance header / plain-prose
  the block. If ALL prompt-shaping still wedges → the wedge is prefill-LENGTH/shape-fundamental, and only
  non-prompt levers remain: a smaller/different decoder, or an EXTERNAL watchdog that detects the
  zero-token freeze and relaunches (in-process cancellation being impossible).

### Lever-1 result (Run C, on-device 2026-06-08): shrink maxContextBlockChars 512→256 — DELAYED, did NOT clear

The first falsification lever was built (configurable `contextBlock` maxChars / topConclusionsOnly,
committed) + run on-device: `BAS_FABRIC_AUTH_FEEDFORWARD=1 BAS_FABRIC_CONTEXT_BLOCK_CHARS=256`, 10 iters ×
2 prompts. **RESULT: WEDGE at iter=4/prompt=1** — 6 clean mlx responses (vs Run B's 3 at 512) then a
zero-token hang. So halving the enriched prefill (prompt_len ~323 vs Run B's 543) roughly DOUBLED the
responses-before-wedge (3 → 6) but did **not** eliminate it; the wedge moved iter2 → iter4.

**Conclusion:** the wedge is **cumulative**, not pure prefill-shape — it recurs after ~N enriched decodes,
and smaller prefills push N higher (more progress) without clearing it. Consistent with GPU-state /
resource accumulation across the feed-forward decode path, NOT a per-prompt OOD-shape trigger.
**Prompt-shaping (size) is therefore INSUFFICIENT** — shrinking delays the wedge but cannot prevent it.
The honest read: the real levers are non-prompt (smaller/different decoder, or an external watchdog-
relaunch). **Feed-forward STAYS default-OFF** (the iron rule held — the lever was tried on-device and
honestly failed, not force-enabled).

## 7. Posture + deferred follow-ups

- **Feed-forward stays OPT-IN (default 0)** regardless of Run B. A default-flip needs BOTH sustained
  safety (a LONG Run B, not this smoke) AND demonstrated VALUE (the enriched N→N+1 prompt measurably
  helps) — a separate, later, sustained-proof-gated decision.
- **No in-process wedge recovery** exists or is added (correct — Swift cannot cancel a synchronous Metal
  eval). Prevention only.
- **Deferred:** the library `budget.maxDecodeTokens → request` wiring (WS2 is endurance-host-scoped only);
  a sustained (multi-hour) Run B before any default-flip.

## 8. GPU-memory lever — the in-process root-cause probe (2026-06-09): REFUTED, honest FAIL

A fresh investigation (operator + a 15-agent root-cause workflow) refuted the §1 "OOD-prefill" framing and
converged on a never-tried lever: the MLX **Metal buffer/allocator cache is never bounded or drained anywhere
in our code** (zero `Memory.clearCache()` / `Memory.cacheLimit` calls). The endurance runner uses the STATELESS
`MLXOrganAdapter.draft` (fresh `ChatSession` per call ⇒ no cross-decode KV reuse), so whatever accumulates is
process-global GPU state, and the cumulative wedge signature (§6: 512→256 prefill doubled responses-before-wedge
3→6) pointed at the unbounded cache → working-set pressure as the hypothesis.

Lever (additive, opt-in, default OFF, byte-equal-off): `MLXOrganAdapter.drainGPUCache()` (`Memory.clearCache()`)
+ `setGPUCacheLimit(bytes:)` (`Memory.cacheLimit`), wired into the endurance loop behind `BAS_MLX_DRAIN_CACHE`
+ `BAS_MLX_CACHE_LIMIT_MB`.

**On-device A/B (iPhone Air, feed-forward OFF, raw in-distribution prompts, ITER=40, decode=96):**

| config | wedge at | avail at wedge | footprint |
|---|---|---|---|
| OFF (no lever) | **56 responses** | **311 MB** | ~3064 MB |
| cap=64 MB + drain | 6 responses | 741 MB | ~2635 MB |
| drain-only (no cap) | ~15 responses (then crawled to a stall) | 734 MB | ~2642 MB |

**VERDICT — the lever does NOT clear the wedge; the OOM hypothesis is REFUTED by measurement:**
- The wedge fires with **730+ MB FREE** under both lever configs — so it is **NOT memory exhaustion**. The
  unbounded-cache → OOM root-cause is wrong.
- The drain DID bound the footprint (~2642 vs 3064 MB; avail 734 vs 311 MB) — but that was **irrelevant**:
  memory was never the trigger. Worse, the lever configs wedge **EARLIER** (6, 15) than the no-lever baseline
  (56), and `clearCache()` every iteration progressively **slows** the run (an extra synchronous GPU
  sync/dealloc each iter appears to poke the same uncancellable Metal hang sooner). The lever is counterproductive.
- **Refined root cause:** the wedge is the uncancellable synchronous Metal command-buffer hang (the eval that
  never returns), triggered by accumulated GPU/Metal **state not captured by RSS/footprint** — not memory
  pressure. Prevention-by-memory fails.
- **Device-contamination finding:** once a run wedges, the device GPU stays poisoned — every subsequent launch
  **load-wedges** (app alive, zero log) until a **full device reboot**. This independently confirms there is no
  in-process recovery and reinforces that an **EXTERNAL watchdog-relaunch** (kill + relaunch the app, and on
  repeat-load-wedge, reboot the device) is the only viable mitigation.

**Disposition:** the lever code stays as an opt-in MEMORY tool (default OFF) — it genuinely bounds footprint,
which may help unrelated memory-pressure cases — but it is **documented as NOT a wedge fix**. The honest next
lever is the external watchdog-relaunch, not another in-process memory knob.

**Tooling fix found en route:** the devicectl cert harness never set `BAS_ENDURANCE_AUTOSTART=1`, so headless
launches sat idle until a manual Start tap; fixed in `scripts/run-device-app-cert.sh`.

## 9. Can it be COMPLETELY solved? Investigation verdict (2026-06-09): NO in-process fix on iOS

An 8-agent complete-fix workflow evaluated every remaining avenue for TRUE PREVENTION (the wedge never
affects the product), each adversarially verified against the vendored MLX source. **All four dead-end:**

- **Deep in-process state reset — feasibility NONE.** `clearCache()` was shallow (freed buffers only). MLX
  0.31.1 exposes **no API** to reset/recreate the process-global singletons that hold the wedge state, and the
  one operation that would "drain" the command queue (`Stream().synchronize()` / `eval`) **is itself the
  operation that wedges**. A new `Stream`/`MTLCommandQueue` per turn is a partial reset that does not escape.
- **Model / quant swap — shifts N, never prevents.** A different arch runs the *same* `mlx_eval` under the
  *same* process-global `evalLock` (Transforms+Eval.swift:9; cancellation only between tokens at
  Evaluate.swift:689-705); the KV-cache type is irrelevant. At best it moves the threshold.
- **Upstream MLX — no fix exists.** No newer mlx-swift / mlx core adds a cancellable or timeout-bounded eval
  or otherwise fixes the decode hang.
- **iOS recovery / out-of-process — not viable on iOS.** The eval is synchronous, global-locked, no-timeout,
  **uncancellable** — a watchdog can only DETECT (a token heartbeat off the eval thread), never kill it or free
  the GPU. iOS cannot spawn a helper process (extensions jetsam at this model's ~3 GB; no long-running compute
  extension; XPC reaches only system services, not an app-hosted service), and **cannot self-relaunch after a
  jetsam kill** (BGTaskScheduler is a maintenance wake, not crash recovery).

**Verdict (honest, code-grounded — not inferred):** a COMPLETE in-process fix is **IMPOSSIBLE on iOS** for this
uncancellable synchronous Metal eval hang. It is an **upstream MLX/Metal limitation** (no cancellable/timeout
eval, no reset API), not a substrate bug we can fix in our code.

**The achievable ceiling:**
- **Test / endurance / cert context (Mac-driven):** an EXTERNAL Mac watchdog-relaunch harness (heartbeat
  stall-detect → terminate → relaunch → resume-from-checkpoint → reboot-on-device-poison) makes UNATTENDED runs
  survive wedges. The common wedge auto-recovers; the device-poison case needs a reboot, and a passcode device
  needs a manual unlock after reboot unless it is in an MDM-kiosk (no-passcode) mode. This is "complete" for the
  unattended test workflow, NOT true prevention.
- **End-user product:** the wedge remains a force-quit-and-reboot event until **upstream MLX gains a cancellable
  / timeout-bounded eval** (file/track an mlx-swift issue) OR the model is run on a runtime that has one. There
  is no in-app fix.

**Recommendation:** build the external watchdog for our cert/endurance workflow (the only measured-viable path);
treat true prevention as an upstream dependency, not an open substrate task.
