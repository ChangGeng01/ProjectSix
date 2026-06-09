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
  > **⛔ REFUTED 2026-06-09 — see §10.2.** This "GPU poisoned until reboot" claim was a CONFOUND. The
  > "subsequent launch load-wedges (zero log)" observation coincided with the period before the
  > `BAS_ENDURANCE_AUTOSTART=1` fix — a relaunched app sat idle at the autostart=off screen producing zero
  > log, which read as "load-wedged." With autostart fixed, a measured on-device control (§10.2) shows a
  > full-MLX relaunch on a just-wedged device **loads and runs normally with NO reboot**, and a sibling Metal
  > queue keeps completing command buffers **throughout** the wedge. The GPU is NOT poisoned. Keep this line
  > for the audit trail; the operative finding is §10.2.

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

> **↻ REVISED 2026-06-09 — see §10.2.** The on-device measurement retired the "device-poison / needs-reboot"
> premise. The recovery is simpler than §9 assumed: **detect stall → kill → relaunch → resume-from-checkpoint**,
> with **NO reboot-on-poison step** (the GPU is never poisoned). And because the fault is MLX **in-process**
> (not Apple firmware), true prevention is NOT merely an upstream dependency — it is a reachable bug in the
> vendored MLX (a completion-handler lost-signal / lock-inversion). §9's "no in-app fix / impossible" was
> predicated on the now-refuted poison claim.

## 10. Layer-pin (2026-06-09): "is it Metal or MLX?" — verified split, with an honesty correction to §9

A 9-agent layer-pin workflow traced the vendored MLX C++ core + Metal backend + Apple `metal-cpp`, then
adversarially refuted its own verdict (metal-skeptic / mlx-skeptic / epistemics-skeptic). The result **splits the
question in two and assigns DIFFERENT confidence to each half** — and corrects an over-claim that had crept into
§9's "upstream MLX/**Metal**" framing.

**(A) The UNRECOVERABILITY (why it can't be aborted in-process) = an MLX problem. HIGH confidence — proven by
reading the vendored source, verbatim:**
- `event.cpp:24-25` — `Event::wait()` calls `waitUntilSignaledValue(value(), -1)`; the `-1` fills the
  `uint64_t milliseconds` timeout slot (`MTLEvent.hpp:73`) = `UINT64_MAX` (~584M yr), so the timeout-throw at
  `event.cpp:26` is **unreachable** — an effectively-infinite wait.
- `eval.cpp:92` — `gpu::synchronize()` calls bare `cb->waitUntilCompleted()`, which has **no timeout variant**
  in the Metal API (`MTLCommandBuffer.hpp:456`); `check_error` runs only *after* completion, so a never-completing
  buffer is an **unobservable infinite hang, never a thrown error**. (Two independent infinite host-block paths.)
- No in-wait cancellation — `Task.isCancelled` is checked only **between tokens** (`MLXLMCommon/Evaluate.swift:1691/1723`);
  `next()` at `:689` does `step()` + `asyncEval(token)` at `:700` with **no cancel check**, so a zero-token wedge in
  the *first* eval is never reached. (Corrects §9's mis-cite "Evaluate.swift:689-705" — those lines are `next()`'s
  body, which contains no cancel check; the real checks are at 1691/1723 in `MLXLMCommon`, not `MLXLLM`.)
- Process-global `NSRecursiveLock evalLock` (`Transforms+Eval.swift:9,17`) wraps `mlx_eval`, so one wedged decode
  freezes **every** eval in the process.
> MLX *could* make this a CLEAN catchable failure (the `milliseconds` slot already exists — pass e.g. 30000) — but
> it requires fixing **both** wait sites (the `event.cpp` SharedEvent wait *and* the `eval.cpp:92`
> `waitUntilCompleted`, which has no timeout API), and even then the `Scheduler` destructor re-enters `synchronize`
> at teardown. No shipping MLX has this → it is a **hypothetical upstream fix** (file an mlx-swift issue). It buys
> *recoverable-as-clean-failure*, NOT *recoverable-as-keep-running* (the GPU stays wedged regardless).

**(B) The FAULT (where the hang physically lives) = sub-process / GPU-resident. HIGH confidence it is BELOW the
process; but the OWNER is UNDETERMINED — MEDIUM confidence — between Apple firmware and an MLX-caused GPU bug:**
- The decisive measured symptom (§8: survives app kill, cleared only by full reboot; OOM measured-out at 730+MB
  free) proves the stuck state lives **below the process boundary** — a pure in-process Swift/C++ deadlock would
  die with the process. This much is solid.
- **It does NOT prove "Apple Metal/AGX firmware" specifically.** The adversarial pass showed the *same* symptom
  fits an **MLX-caused** GPU fault at least as well:
  - MLX commits per-decode buffers via `commandBufferWithUnretainedReferences()` (`device.cpp:405`) then eagerly
    `release()`/`null()`s them (`device.cpp:411/418-420`) — if MLX recycles a buffer the in-flight GPU command
    still references, **MLX faults the GPU context itself** (a use-after-free / premature-donation, owned by MLX's
    allocator/memory-pool — the same pool the §8 `clearCache` lever pokes).
  - A CPU-side completion-handler **lock-inversion** on `stream.fence_mtx` (`device.cpp:466/489`) + scheduler mtx,
    under the global `evalLock` — the GPU could FINISH yet the SharedEvent never get signaled: an MLX-internal
    deadlock indistinguishable from a firmware wedge at the symptom level.
  - (An MLX-authored GPU `while(1)` spin exists at `fence.metal:40-52` / CPU spin `fence.cpp:65-66`, but on the
    `MLX_METAL_FAST_SYNCH` path which **defaults OFF**, `utils.h:159` — ships but off the default path.)
- The cumulative-threshold signature (§6: 512→256 prefill *doubled* responses-before-wedge 3→6; §8: OFF @56) fits
  an **MLX software resource leak** as well as a firmware one — accumulation-toward-a-limit is the hallmark of a
  software leak, so it does not break the tie.
- **Unknowable from code/symptoms alone:** the exact Apple AGX driver line / IOAccelerator queue field / firmware
  condition (closed source, below the `metal-cpp` objc bridge); and whether the owner is Apple-firmware vs an
  MLX-resource/lock bug. n=1 device, n=1 OS (iOS 26.5), zero GPU-side capture.

**Honesty correction to §9:** §9 said the wedge "is an upstream MLX/**Metal** limitation … not a substrate bug."
The UNRECOVERABILITY half is correct (MLX, upstream). But §9 *implicitly assumed* the FAULT is Apple-Metal/firmware
and concluded "true prevention is IMPOSSIBLE." **That assumption is not proven.** If the fault owner is an MLX
buffer-lifecycle or lock-ordering bug (in `device.cpp`, which is in the **vendored MLX we control**), then a real
**prevention** fix could exist — which would reopen "完全解决" beyond the watchdog. §9's "impossible" should be read
as "impossible *given the unproven assumption that the fault is Apple firmware*," not as an established fact.

**The one discriminating experiment that would settle it (NEVER RUN — this is the honest open gate):** after a
wedge, on the *contaminated* device, submit a **trivial non-MLX Metal command buffer** (a bare `MTLCommandQueue` +
no-op compute) and sample `cbuf.status` / take a Metal System Trace or GPU frame capture.
- If the bare command buffer **also** hangs/errors → the GPU client is genuinely wedged below MLX → leaning Apple
  driver/firmware → our ceiling is the external watchdog + reboot-on-poison (§8/§9 stand).
- If the bare command buffer **succeeds** → the contamination is MLX-state-specific (buffer lifecycle / lock) →
  a real **prevention** fix could live in the vendored MLX, and "完全解决" is back on the table.

**Net answer to "Metal or MLX?":** the *inability to abort it* is **MLX, for sure**; the *hang itself* is **below
the process, for sure**, but **Metal-firmware-vs-MLX-bug is undetermined** and is decidable by the trivial-Metal
probe above — which we have not yet run.

### 10.1 The discriminating probe — BUILT (2026-06-09), ready to run on-device

The trivial-Metal control is now implemented (was: "never run"):
- **`Sources/BASMetalSubstrate/BASMetalGPUProbe.swift`** — an MLX-FREE raw-Metal probe: its own `MTLDevice` +
  `MTLCommandQueue` + a trivial inline compute kernel, with completion awaited via `addCompletedHandler` + a
  **timed `DispatchSemaphore`** (NOT `waitUntilCompleted` — deliberately avoiding the exact MLX trap, so a wedged
  GPU yields `.timedOut` instead of hanging the probe thread). `runSuite()` for the one-shot control;
  `BASMetalGPUProbeSession` for the long-lived concurrent heartbeat. Validated on macOS GPU (`ALL_COMPLETED`).
- **Runner wiring** (`DeviceTestApp/Sources/App/BASEnduranceAppRunner.swift`), default-OFF:
  - `BAS_METAL_PROBE_ONLY=1` → fresh-process control: run ONLY the bare-Metal probe (no model load, no MLX),
    emit `📊 ch1025 metal-probe context=probe-only verdict=…`. Launch it on a *contaminated* device.
  - `BAS_METAL_PROBE_CONCURRENT=1` → a sibling-queue heartbeat (`📊 ch1025 metal-probe-hb …`) sampled every
    `BAS_METAL_PROBE_HB_SEC` during the MLX run — gives a same-run signal (do hb lines keep `status=completed`
    after the `🧠 mlx` lines stop, or flip to `status=timedOut` at the wedge?).
- **`scripts/run-metal-probe-experiment.sh`** — the two-phase harness: (A) endurance + heartbeat until wedge,
  (B) kill → relaunch PROBE-ONLY on the contaminated device → print the discriminating verdict.

Reading: `verdict=ALL_COMPLETED` on a *confirmed-contaminated* device ⇒ MLX-CAUSED (prevention fix possible in
vendored MLX); `verdict=WEDGED` ⇒ Apple-firmware-leaning (external watchdog ceiling stands). **The on-device
result will be recorded here honestly (pass OR fail) once the run completes.**

### 10.2 ON-DEVICE RESULT (2026-06-09, iPhone Air, iOS 26.5) — the GPU is NOT the fault; the wedge is MLX-process-local

Ran the experiment on a physical iPhone Air. **Triple-dissociation, all three angles agree: the GPU device is
healthy during and after the wedge; the hang is specific to the MLX eval path within a process; killing the
process FULLY recovers with NO reboot.**

1. **DURING the wedge — sibling Metal queue stays alive.** A normal endurance run (concurrent heartbeat on)
   wedged at MLX response #17 (last decode normal: `latency_ms=2387`, then frozen inside the next eval; `avail_mb≈300`,
   not OOM). The MLX-FREE sibling-queue heartbeat completed **56/56 samples (0 timedOut, 0 errored)** at ~4 ms
   each — **including 8+ samples (t_sec 750→859) AFTER MLX froze.** A GPU-device/firmware-wide wedge cannot keep
   executing another queue's command buffers; the GPU was demonstrably processing work while MLX's eval thread
   was parked. ⇒ the fault is NOT a GPU/Metal-firmware-wide hang.
2. **AFTER killing the wedged app — bare Metal is fine.** Relaunched PROBE-ONLY (no MLX) on the same device:
   `verdict=ALL_COMPLETED`, 6/6 completed, **0.69 ms median**. The "contaminated" GPU runs bare Metal perfectly.
3. **AFTER killing the wedged app — full MLX recovers with NO reboot.** Relaunched the FULL Gemma-4-E2B MLX
   endurance on the same just-wedged device: model loaded (`load_ms=2741`), produced 8 healthy decodes
   (~2400 ms, ~50 tok/s), and **COMPLETED**. No load-wedge. No reboot.

**Verdict (measured, code-corroborated):**
- **It is NOT a Metal/GPU-driver/firmware fault.** The GPU stayed healthy throughout (heartbeat + bare-Metal +
  full-MLX-relaunch all succeed). This RETIRES the §8 "GPU poisoned until reboot" claim as a confound (the
  pre-autostart-fix idle-app artifact — see the §8 ⛔ note).
- **It IS MLX-process-local.** The wedge lives in MLX's own in-process eval/command-buffer/lock path: as a
  session accumulates (cumulative threshold, §6), MLX's eval eventually parks forever waiting on ITS command
  buffer's completion **even though the GPU has moved on** — the signature of a CPU-side **completion-handler
  lost-signal / lock-inversion** under the process-global `evalLock` (suspects: `device.cpp:466/489` fence_mtx +
  scheduler mtx; or premature buffer recycling `device.cpp:405/411/418`), NOT a GPU kernel hang. Cleared
  completely by process death.
- **So "is it Metal or MLX?" is now answered: MLX.** Both the *unrecoverability* (§10, proven) AND the *fault
  itself* (§10.2, measured: GPU exonerated) are MLX. The earlier "fault owner undetermined, leaning firmware"
  (§10) is resolved toward **MLX-caused** by the on-device GPU exoneration.

**What this CHANGES (the good news):**
- **Recovery no longer needs a reboot.** Because the GPU is never poisoned and the process is healthy (one thread
  parked; not jetsammed), **kill + relaunch fully recovers**. For the **test/endurance/cert** workflow this makes
  an unattended Mac watchdog trivially reliable: *detect stall (the heartbeat is exactly such a detector, and it
  stays alive) → kill → relaunch → resume-from-checkpoint*. **Drop the reboot-on-poison step** (§9) — it was
  predicated on the refuted poison claim.
- **"完全解决" (true prevention) is genuinely back on the table.** The fault is MLX **in-process** code/state we
  can reach (the vendored MLX, or our usage of it), not Apple firmware. The most likely mechanism — a
  completion-handler lost-signal/lock-inversion where the GPU finishes but MLX never gets signaled — is a
  fixable concurrency bug. Next step to localize the exact line: instrument the wedge point (sample
  `cb.status` / `event` value at the hang, or a GPU capture) to confirm "GPU completed, CPU never signaled" vs
  "buffer never submitted," then fix in vendored MLX or upstream.

### 10.3 A-attempt #1 (2026-06-09): `Event::wait` timeout — shipped, but on-device it does NOT catch the wedge

Made `Event::wait` (event.cpp) timeout opt-in (`MLX_EVENT_WAIT_TIMEOUT_MS`, default `-1`/infinite =
byte-identical). On-device test with the **reliable** feed-forward wedge trigger (ADR §6 big-prefill;
fired exactly — iter=2 `prompt_len=537` → stalled at 3 decodes):
- The run wedged inside iter-4's `adapter.draft` (substrate `brain.process` for iter 4 logged; no `🧠 mlx
  iter=4`), sat frozen for the full 17-min window, and **`MLX_EVENT_WAIT_TIMEOUT_MS=30000` did NOT fire**
  (0 timeout errors). ⇒ **the decode block is NOT `Event::wait`.**

Code trace narrowed the real block (the decode `eval()` → `eval_impl().wait()` chain):
- **Prime suspect: `scheduler::wait_for_one()`** (scheduler.h:130-136) — `completion_cv.wait(lk, …)` that is
  woken only by `notify_task_completion` fired from a command buffer's `addCompletedHandler` (eval.cpp:61).
  If the GPU buffer never completes / its handler never fires, this CPU condition-variable parks forever —
  exactly the "completion-handler lost-signal" hypothesis (§10.2), and NOT `Event::wait`. (Other candidates:
  `gpu::synchronize`'s `cb->waitUntilCompleted()` eval.cpp:92; `Fence::wait` fence.cpp.)
- **Binding blocker for in-process recovery:** `mlx_eval` (mlx-c) *catches* C++ exceptions → `mlx_error()` →
  returns 1, **and mlx-swift discards the code** (`_ = evalLock.withLock { mlx_eval(...) }`,
  Transforms+Eval.swift:18). So even a correctly-bounded, catchable timeout will NOT surface to the Swift
  endurance loop as an error unless we ALSO re-plumb the binding (check the code / install a throwing
  `mlx_error` handler / change mlx-swift to propagate).

**Honest verdict on the true in-process fix:** it is a legitimate but **multi-layer MLX-internals arc**, not a
quick patch: (1) localize the exact blocking wait (Event::wait ruled out on-device; `scheduler::wait_for_one`
is the prime suspect), (2) bound it with a timeout, (3) plumb the error through mlx-c → mlx-swift (currently
swallowed), (4) test whether the in-process stream actually recovers after the throw (uncertain — the stuck
command buffer may block subsequent in-process evals, even though a FRESH PROCESS provably recovers, §10.2).
The `Event::wait` timeout stays in (opt-in, default byte-identical, harmless — it may bound other waits) but is
NOT the fix. **Disposition:** the practical "完全解决" remains the watchdog (test/cert auto-recovery, no reboot,
§10.2) + a precise upstream MLX issue (GPU-exonerated completion-handler lost-signal in `scheduler::wait_for_one`);
the deeper in-process fix is a fundable follow-up, not claimed done.

**Honesty bounds:** n=1 device, iOS 26.5; the wedge reproduced across runs (@17, then @12 responses — high
variance in the threshold, but it wedges reliably). The **"kill + relaunch fully recovers, no reboot" result is
now n=2 confirmed**: two independent wedge→kill→full-MLX-relaunch cycles both loaded + ran + COMPLETED normally
on the just-wedged device. The GPU-exoneration is decisive even from a single instance (the heartbeat directly
observed the GPU executing during the wedge — not an inference). The exact MLX line is not yet pinned (closed
below the metal-cpp bridge for the Apple side, but the suspects above are in the vendored MLX C++ we can
instrument — task A/#60).

### 10.4 Phase-1 consolidation (2026-06-09): watchdog VALIDATED on real wedges + upstream issue drafted

- **Watchdog validated in-harness.** `scripts/run-endurance-watchdog.sh WEDGE_FAST=1` (feed-forward big-prefill
  so each segment wedges fast) ran **20 min unattended**: **12 segments, 11 wedges, 11/11 recovered** by
  detect→kill→relaunch, **0 reboots, 0 launch failures** → `RESULT: PASS`. This proves the §10.2 recovery path
  end-to-end in automation (beyond the manual n=2): the wedge is harmless to an unattended Mac-driven run.
- **Upstream issue drafted:** `Docs/UPSTREAM_MLX_EVAL_WEDGE_ISSUE_DRAFT.md` — GPU-exonerated, lost-signal
  localization, binding blocker, repro — ready to file at ml-explore/mlx-swift.

**Practical "完全解决" status:** for the **test/cert/endurance workflow it is DONE** (unattended auto-recovery, no
reboot, validated). For the **end-user product**, true in-process prevention remains the deeper Phase-2 arc
(§10.3) + the upstream ask. Honest caveat carried forward: the exact blocking wait is still unpinned —
`wait_for_one` only blocks when `n_tasks_old > 1` (may not be the single-decode block), and the `Event::wait`
timeout's effect was not positively confirmed — Phase 2 starts with **observability** (device-console capture +
enter/exit tripwires) to pin the wait before bounding it.

## 11. iOS 27 + ROOT-CAUSE LOCALIZED (2026-06-09): scheduler-throttle livelock, n_active_tasks pinned at 11

Device upgraded to **iOS 27.0 (Build 24A5355q)**. The Xcode-26.5 build deploys to it fine. **The wedge
REPRODUCES on iOS 27** (feed-forward, stalled at 3 decodes) → **reconfirms it's MLX, not the OS** (as §10.2
predicted; iOS 27 changes Apple's driver, not MLX's scheduler).

**Localized via `MLX_WEDGE_TRACE` (enter/exit tripwires + `--console` capture), decisive:**
- `Event::wait`: `>1 <1` balanced, 30 s timeout fired **0** times → **NOT** the block (corrects the §10/§10.3
  prime-suspect assumption).
- `gpu::synchronize`: `>3 <3` balanced → not the block.
- **`scheduler::wait_for_one`: called 5754× (matched pairs — it RETURNS each time, not a deadlock), always
  with `n_active_tasks() == 11`.** The flood starts right after `brain iter=4` (the big feed-forward prefill
  decode) and never ends; no `🧠 mlx iter=4` is ever produced.

**Mechanism:** `eval_impl`'s drain throttle (transforms.cpp:242) is
`if (n_active_tasks() > MAX_ACTIVE_TASKS || (active_memory > memory_limit && n>0)) { … wait_for_one(); … }`
with `MAX_ACTIVE_TASKS = 10`. The memory clause is false here (allocator `block_limit_ ≈ 5 GB`, app RSS ~2.9 GB).
The driver is `n_active_tasks() == 11 > 10`: **`n_active_tasks_` has LEAKED** — a `notify_task_completion`
(fired from a command buffer's `addCompletedHandler`, eval.cpp:61) that never fired pins the counter at 11. So
**every** subsequent decode-eval trips the throttle and the generate loop livelocks (thousands of throttled
evals, no token), while the GPU stays healthy (each `wait_for_one` returns as other tasks complete). This is
**exactly the §10.2 picture** — GPU-exonerated, CPU-side MLX scheduler bug — now pinned to the line.

**This is a different bug than the original ADR framing.** The wedge is NOT an "uncancellable synchronous Metal
eval hang" (§1) — it is a **scheduler task-accounting leak → throttle livelock**. The earlier framing was the
best read from the symptoms; the trace corrects it.

**Fix test in flight (decisive):** made `MAX_ACTIVE_TASKS` env-configurable (`BAS_MLX_MAX_ACTIVE_TASKS`, default
10 = upstream). If raising it above the leaked floor (e.g. 64) **un-wedges** the decode → confirms the
n-leak-throttle mechanism AND yields a mitigation (prevention, if the leak is bounded; a delay, if it grows).
If it does NOT un-wedge → the throttle is a symptom and the block is in the generate loop itself. Result (pass
OR fail) recorded here next. The true fix is to stop the `notify_task_completion` leak (upstream MLX);
`BAS_MLX_MAX_ACTIVE_TASKS` + the watchdog are the in-reach levers.

### 11.1 MAX_ACTIVE_TASKS A/B (iOS 27) — REFUTED: the throttle is a symptom, not the cause

On-device A/B, feed-forward wedge:
- CONTROL (default throttle n>10): **WEDGED @ mlx=3**.
- TREATMENT (`BAS_MLX_MAX_ACTIVE_TASKS=64`): **still WEDGED @ mlx=1** (if anything earlier — like `clearCache`
  made it worse in §8).

**Verdict: raising the throttle ceiling does NOT prevent the wedge** → the `wait_for_one` flood is a *symptom*
of the wedge, not its driver. My §11 "n-leak-throttle is the cause" hypothesis is **refuted** by measurement.

**Refined (honest) understanding:** the MLX_WEDGE_TRACE flood (5754 `wait_for_one`, all returning) proves the
process is **SPINNING, not frozen** — it is actively running thousands of evals while producing **no** `🧠 mlx`
line. So the decode `draft()` for the wedged iter never returns even though evals keep completing and the GPU
stays healthy. That is consistent with EITHER:
  (a) a **lost completion signal** that leaks task state (the throttle is then a side-effect we already see), OR
  (b) a **runaway / non-terminating generate loop** — the per-token loop keeps evaluating past `maxTokens`
      without hitting its stop condition (5754 evals ≫ the ~96-token cap would need).
Neither `Event::wait`, `gpu::synchronize`, nor the `wait_for_one` throttle is THE block. The next diagnostic to
distinguish (a) vs (b) is to instrument the **token counter + notify_new_task/notify_task_completion balance**
(does n leak monotonically, or does the token count run away past maxTokens?).

**Disposition:** `BAS_MLX_MAX_ACTIVE_TASKS` stays as an opt-in knob (default 10 = upstream) but is **NOT a fix**
(documented). The practical 完全解决 remains the watchdog (validated 11/11, OS-independent). The precise root is
still open — a deeper MLX/MLXLMCommon generate-loop instrumentation pass, or hand it to upstream with this
(rich) localization.

### 11.2 "Try a newer mlx-swift" — REFUTED by research (we are already current)

Operator-chosen lever: upgrade the vendored MLX stack. Researched before committing to the (large, risky)
re-vendor:
- **mlx-swift-lm** (where the generate loop / `ChatSession.respond` / `TokenIterator` live): our vendored copy
  is already the **3.x main line** (README confirms "new major version 3.x"; we already have
  `SpeculativeGenerator` + batched `RoPEApplication` = 3.31.3 features, and the 2.31.3 "fix concurrency issues" +
  Swift-6 migration are carried into 3.x). **No newer LM line exists to upgrade to.**
- **mlx-swift core**: vendored 0.31.1; latest 0.31.4. The 0.31.2/3/4 release notes are fmt 12.1.0 /
  `mlx_save_safetensors` evalLock / nuclear-norm linalg — **nothing in the scheduler / eval / generate path**.
- **Generate stop-condition is correct** in our copy (`TokenIterator.next`: `if tokenCount >= maxTokens { return
  nil }`, Evaluate.swift:690) → not a runaway-past-maxTokens loop.

**Verdict:** a newer mlx-swift/-lm will **not** fix this wedge — we are already on the latest LM line and the only
available core bump (0.31.4) has no relevant change. (Resolved by research; the risky multi-package re-vendor was
**not** needed — effort saved.) The bug is in the current/latest MLX, on iOS 27, GPU-exonerated → it is a genuine
upstream defect to report, not a stale-version artifact.

### 11.3 Chunked-prefill fix + drain-trip diagnostic (iOS 27) — workflow PRIMARY hypothesis REFUTED

An 8-agent Ultracode workflow (adversarially verified) converged on a PRIMARY root cause: the model is
**Gemma4 (a VLM)**, whose `prepare` override bypasses the `LLMModel` chunked prefill → ONE un-chunked
whole-prompt forward graph drained inline. Implemented the fix (mirror `LLMModel.prepare`'s chunked loop in
`Gemma4.prepare` text branch, env-gated `BAS_MLX_CHUNK_PREFILL` + `BAS_MLX_PREFILL_CHUNK`). On-device A/B + a
drain-trip diagnostic (`[BAS]drain-trip` printing the throttle clause + live memory) settled it:

- **First chunk A/B was a dud** (my error): chunk size 512 > the ~35-134-token feed-forward prompts, so the
  `while tokens.size > 512` loop never ran. Re-tested at chunk=32 (chunking actually runs).
- **chunk=32 → still WEDGED @3** → chunking the prefill does NOT prevent the wedge. **PRIMARY refuted on-device.**
- **Drain-trip clause (5620 trips): ALL `mem_trip=0`** → the **TASK clause** (`n_active_tasks()==11 > MAX=10`),
  NEVER the memory clause (`active_mb` 134→2585 ≪ `limit_mb=11143`). → skeptic-A's memory-pressure-drain
  hypothesis is also **refuted**.
- **`active_mb` grows UNBOUNDEDLY** (134 → 2585 MB and still climbing when killed at 240 s) with `n` pinned at 11
  → an **unbounded allocation / re-evaluation** in iter-4's eval, NOT a finite graph being drained slowly
  (which would peak then emit a token). This matches skeptic-B's untested point C (something keeps
  re-submitting / never marks the output available).

**Net (honest):** the wedge is narrowed to "iter-4's eval allocates unboundedly with `n` pinned at 11" but is
**NOT** any of: Event::wait (§10.3), the throttle ceiling (§11.1), the memory clause (here), or the prefill graph
size (chunking refuted here). The exact cause (what re-submits / leaks) is not pinned to a one-line fix. Per the
operator's "b 实在不行 a", the deep in-process root-cause drill is **exhausted for now** (8-agent workflow + 5
on-device cycles, the primary hypothesis refuted) → consolidate to the watchdog + a rich upstream issue. All
diagnostic env flags (`MLX_WEDGE_TRACE`, `MLX_EVENT_WAIT_TIMEOUT_MS`, `BAS_MLX_MAX_ACTIVE_TASKS`,
`BAS_MLX_CHUNK_PREFILL`, `BAS_MLX_PREFILL_CHUNK`) stay opt-in / default-off (byte-identical) as future tools.

### 11.4 Upstream instruments CRACK the mechanism + "upgrade MLX" proven moot (iOS 27)

**"Upgrade all MLX to latest" — checked at the source level, it cannot fix this wedge:**
- mlx-swift latest (0.31.4) wraps the **same mlx core 0.31.1** (`MLX_VERSION` + `version.h` identical).
- mlx **core 0.32.0** (latest C++): the `eval_impl` drain throttle (transforms.cpp) + `wait_for_one` +
  `notify_task_completion` (scheduler.h) are **byte-identical** to 0.31.1 (only line numbers shifted).
- mlx-swift-lm latest: the `next()`/`step()`/`asyncEval` generate loop is **unchanged**.
→ Every component's wedging code is identical in the latest → a re-vendor would wedge the same way; **not done**.

**The 3 operator-directed instruments (token-loop beacons + task balance + eval-error) settled the mechanism:**
- **NOT a prefill hang.** The beacon ladder shows the decode generating a full turn: `P3-enter-next tc=0…96`,
  `P4/P5/P6` ~204×, `tc` reaching **96** (= maxTokens). The workflow's PRIMARY hypothesis (un-chunked prefill
  graph) is **DEFINITIVELY REFUTED** — tokens flow fine.
- **The wedge is a `step()` (model forward) that HANGS.** The last beacon is `P4-enter-step` with **no
  matching `P6`** (32 s+ gap, still stuck at kill). A single forward never returns.
- **LIVELOCK, not a leak** (settles the §11 question): task balance `created=12000 completed=11989 gap=11
  STABLE` — created/completed climb together, the gap pinned at 11. The stuck forward **submits unbounded GPU
  work** (command buffers climbing past 12,000) that all completes, yet the forward never finishes. So
  `notify_task_completion` does NOT leak (the §11/transforms.cpp:25-30 "never fires" comment is WRONG) — it is
  a self-refilling producer livelock.
- **No swallowed eval error** (the new `mlx_eval` return-code surface fired 0×) → genuine hang, not a hidden error.

**Pinned conclusion:** a single MLX model `step()` forward, for a specific (cumulative, post-N-turns) Gemma-3n-E2B
input on iOS, **submits an unbounded stream of GPU command buffers and never completes** (GPU healthy, CPU
livelocked in the drain throttle). NOT prefill-size, NOT Event::wait, NOT memory clause, NOT the throttle
ceiling, NOT a task-completion leak, NOT a stale MLX version. The remaining question for upstream: WHY does that
one forward submit unbounded work (a runaway op inside the Gemma-3n forward / per-layer-inputs path). The
upstream issue carries this exact mechanism. The `mlx_eval` binding fix (surface the dropped return code) lands
as a standalone correctness improvement regardless.
