# CH 1025.8 — Device Endurance Run #2 (devicectl path) + Honest Coverage Audit

> **Status: COMPLETE & CLEAN — with one honesty correction (fabric did NOT run).**
> Second full 100-iter on-device endurance run on iPhone Air, launched via the
> **`devicectl` app-launch path** (not `xcodebuild test`). 100/100 iters, 300 MLX
> inferences, 0 errors, 0 crashes, no memory leak. Completed in **7.09h** vs the
> prior run's 10.07h (CH_1025_7). This report records the results, the
> apples-to-apples comparison, and a coverage-honesty finding: **the agent fabric
> was constructed but never activated**, and the boot-inventory log line
> overclaims it as activated.

---

## 1. What actually ran (HONEST inventory)

The boot line emits `exercised=...` — here is the **verified** per-component truth
(grepped from the run log, not the self-reported inventory string):

| Component | Claimed (boot line) | **Verified reality** | Evidence |
|---|---|---|---|
| MLX Gemma 4 E2B 4-bit | exercised | ✅ **300 real inferences** | `mlx ... est_tokens=... latency_ms=...` ×300 |
| CoreML BASContextClassifier (18K) | exercised | ✅ per-prompt | `BASCognitiveBrain loaded`; classifier feeds `brain iter=` |
| L0→L14 cascade (all 14) | exercised | ✅ per-prompt, real decisions | `brain iter=N task=... risk=... candidates=3`, `host_gate`, `L0frame` ×300 |
| L8 hippocampal memory (LRU) | exercised | ✅ bounded, 3-atom stable | `atoms=`: 0→…→**3 held for 215 prompts** |
| **agent fabric (`fabric_runTurn`)** | **`ch1025.6_activated`** | ❌ **NOT ACTIVATED** | `fabric iter=N activated=false skip=env-var gate disabled` ×300 |
| Mamba SSM | `ch1033_boot_probe` | ◐ boot probe only (honestly labeled) | one-time boot probe, not per-turn |

**The single defect: the boot-inventory line claims fabric was "activated" — it was
not.** See §4.

---

## 2. Results (this run — CH_1025_8)

| Metric | Value |
|---|---|
| Launch | 2026-05-31 07:38:39, `devicectl device process launch` (PTY-free, app-mode) |
| Device | iPhone Air (iPhone18,4), iOS 26.5 (23F77), UDID `5E5C3C5C…` |
| Config | 100 iters · 3 MLX prompts/iter · 60s base cooldown · adaptive=1 · **fabric OFF** |
| Duration | **25,509s = 7.09h** (iter-100 start @ 25,417s + 92s final iter) |
| Iters | **100/100** (natural completion) |
| MLX | **300** inferences · avg 26,831ms · p50 27,028ms · p99 60,785ms · **245,850 tokens** |
| Thermal (after-iter ×100) | **0 serious · 77 fair · 23 nominal** — never crossed into serious |
| Cooldown recovery | every iter recovered to nominal (`fair→nominal` / `nominal→nominal`) |
| Memory | max RSS 2,865.8 MB · one reclamation 2,690→2,036 MB · ended ~2,036 MB · **endpoint_delta < 0 → no leak** |
| L8 atoms | warmed to 3, held **3 for 215 prompts** (deterministic, bounded) |
| Errors / crashes | **0 / 0** |

---

## 3. Comparison vs CH_1025_7 (the prior 10.07h run)

Same device, same HEAD, same config (fabric off in both). Apples-to-apples:

| Metric | CH_1025_7 (prior) | CH_1025_8 (this) | Δ |
|---|---|---|---|
| Duration | 36,240s = **10.07h** | 25,509s = **7.09h** | **−2.98h (−30%)** |
| Iters | 100/100 | 100/100 | = |
| MLX avg latency | 27,002ms | 26,831ms | ≈ identical |
| MLX p99 latency | 74,503ms | **60,785ms** | −13.7s (lower tail) |
| Total tokens | 247,133 | 245,850 | ≈ identical |
| **Thermal: serious** | **13 iters** (1–13, cold heat-saturation) | **0 iters** | **−13** |
| Thermal: fair / nominal | 46 / 41 | 77 / 23 | warmer steady-state, never serious |
| Memory peak | ~2,872 MB | ~2,866 MB | ≈ identical |
| Reclamation | iter 15→16 (2,872→1,464) | one mid/late (2,690→2,036) | both bounded |
| L8 stable atoms | 3 (×215 prompts) | 3 (×215 prompts) | **identical** ✅ |

### Why this run was ~3h faster (honest analysis)

- **The whole delta is thermal-cooldown wall-time, not compute.** MLX avg latency is
  ≈identical (26.8 vs 27.0s) — the substrate + model compute is stable run-to-run.
- **Prior run: 13 `serious` iters (1–13).** Per CH_1025_7's key finding, the A19
  recovers `serious → nominal` **only with cooldown ≥180s**; so iters 1–13 forced
  the adaptive cooldown up to 180–300s, and the schedule stayed cooldown-heavy.
  That extra recovery time ≈ the ~3h difference.
- **This run: 0 `serious`.** With no serious, the adaptive cooldown stayed near its
  60s base → ~3h saved.
- **Leading hypothesis for *why* no serious spike** (hedged — cannot be proven from
  logs alone): this run was **immediately preceded by the 2-iter smoke**, so the
  MLX model + Metal shader cache were **warm** (`MLXOrganAdapter load_ms=2,729` vs
  the prior cold `58,309`). The prior run's serious phase was explicitly the
  *cold-start MLX heat-saturation* of shader JIT + model load during iters 1–13;
  a pre-warmed cache plausibly skips it. **Caveat:** ambient temperature / device
  thermal state at launch could also contribute and cannot be isolated here. Same
  code, same config → this is an *environmental/thermal* difference, not a
  behavioral one.

**Reproducibility verdict:** the substrate behaved **identically** where it should
(MLX latency, L8 atom trajectory, memory bounding, decision cascade); the only
difference is thermal wall-time. That is the desired property for a deterministic
decision core.

---

## 4. Finding: agent fabric was NOT activated + the inventory overclaims it

### The truth
Every one of the 300 prompts logged:
```
🪧 ch1025 fabric iter=N prompt=M activated=false skip=env-var gate disabled
   fabric deltas_emitted=- deltas_accepted=-
```
`deltas_emitted=-` (a dash, not 0) — `runTurn()`'s fabric path was never entered.

### Root cause
- The fabric pipeline **is constructed** at boot: `📍 fabric pipeline constructed
  (4-seat roster: scout/planner/risk/surface)` and passed in as
  `agentFabric: fabricRuntime` (`BASEnduranceAppRunner.swift:481`).
- But activation is gated **inside** `runTurn` by the **`BAS_AGENT_FABRIC`** env var
  (`BASEnduranceAppRunner.swift:441-442, 623-625`): unset → `activated=false` with a
  skip reason; `enabled` → fabric coordinates.
- **Neither this launch nor the documented launch command sets `BAS_AGENT_FABRIC`.**
  So fabric-off is the *default*, and this run ran with it off.

### The honesty bug
`BASEnduranceAppRunner.swift:542-545` builds the boot inventory as a **hardcoded
string literal**:
```swift
"exercised=mlx_gemma4_E2B_4bit+" +
... +
"fabric_runTurn(ch1025.6_activated)+" +   // ← unconditional; says "activated" even when gate is OFF
```
It is **decoupled from the actual gate state**, so it claims `activated` while every
prompt reports `activated=false`. (There is prior history here — a `ch 1038 不满2
fix` comment at line ~640 already wrestled with fabric-activation honesty.)

### Recommended fix (small, honest)
Make the inventory token reflect reality — e.g. derive it from the same gate the
per-prompt line uses: `fabric_runTurn(constructed_not_activated)` when
`BAS_AGENT_FABRIC` is unset, `fabric_runTurn(activated)` only when it actually
coordinates. This removes the only dishonest line in the endurance log.

### Self-correction (诚实模式)
In the live status updates during/after this run I stated "L0-L14 + MLX + **fabric**
+ Mamba all ran," citing this inventory line. **That was an overclaim** — fabric did
not run. Recording the correction here so the report and the chat agree.

---

## 5. Engineering finding: `devicectl` is the sandbox-drivable path

- `xcodebuild test` against a physical device **cannot be driven from the agent
  sandbox**: it requires a console PTY, and the sandbox denies pty allocation
  (`openpty: Device not configured`, errno 6/ENXIO) — confirmed both directly and
  via a `script(1)` wrapper. This is a sandbox limit, not a device/code issue.
- The **`devicectl device process launch`** app-mode path (`BASEnduranceAppRunner`)
  is **PTY-free** and works from the sandbox (device info, install, launch, and
  `copy from` for log retrieval all succeed). It is also, per the runner's own
  header, **preemption-resistant** (survives Mac-side Xcode session cleanup that
  killed a prior `xcodebuild test` run).
- **Conclusion:** for agent-driven on-device endurance, use the devicectl app-launch
  path. The `scripts/run-iphone-air-internal-loop-10hr.sh` (xcodebuild-test) script
  remains valid only when launched from a real terminal with a PTY.
- Env vars for `devicectl` (Xcode 26.5): JSON dict via `-e`, e.g.
  `-e '{"BAS_ENDURANCE_AUTOSTART":"1","BAS_INTERNAL_ITER_COUNT":"100", ...}'`
  (the header's `--environment KEY=VALUE` form is from an older devicectl).

---

## 6. Recommendations / next steps

1. **Fix the inventory overclaim** (§4) — one-line honesty fix in
   `BASEnduranceAppRunner.swift`.
2. **If fabric coverage is desired:** re-run with `BAS_AGENT_FABRIC=enabled` added to
   the launch env. This will exercise the 4-seat fabric coordination per prompt
   (expect higher latency + heat). A short run (≈20–30 iters) suffices to validate
   fabric — a full 10h is not required just to cover it.
3. **No substrate fix required from this run** — the decision core, MLX, classifier,
   and L8 memory all behaved correctly and deterministically.

---

## 7. Artifacts
- Device log (preserved): `/tmp/ch1025-10hr/FINAL-10hr-run.log` (5,714 lines, 708K).
- Prior run report: `Docs/CH_1025_7_ENDURANCE_FINAL_REPORT.md`.
- Runner: `DeviceTestApp/Sources/App/BASEnduranceAppRunner.swift`.
- Launch (this run): `devicectl device process launch --device 5E5C3C5C… --terminate-existing -e '{…ITER_COUNT:100, MLX_PROMPTS:3, COOLDOWN:60, ADAPTIVE:1…}' com.changgeng.basdevicetest` (fabric OFF — no `BAS_AGENT_FABRIC`).
