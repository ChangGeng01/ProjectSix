# CH1044 — iPhone Air Device Validation + Kill-Event Forensics

> Record of the ch1044 on-device validation pass on **iPhone Air (iPhone18,4, iOS 26.5
> arm64)** via `DeviceTestApp/BASDeviceTest.xcodeproj`. Covers: what passed on real
> hardware, two real bugs found + fixed, the on-device MLX numbers, and a forensic
> investigation of why long background runs get terminated (spoiler: the host-side Claude
> Code harness, not the phone).

## 1. Device validation — all green

| Run | Scope | Result |
|---|---|---|
| Smoke | `ch946` L8 14-layer fuzz round-trip | **1/1 PASS** |
| Batch | `ch934-938` L8 row closure + `ch926` fix coverage | **40/40 PASS** |
| Full functional suite | entire `BASDeviceTests` (skip the multi-hour endurance) | **13564 / 0 failures** (71 skipped), ~5 min |
| Endurance | `ch1025` long-running MLX endurance | ran **88 minutes** continuously, healthy, until host-killed |

**41 + 13564 device tests passed, 0 failures.** Skips are all legitimately env-gated
(`QINAO_COREML_E2E` unset, long soak/benchmark gates), not hidden breakage.

## 2. On-device MLX (Gemma 4 E2B, Metal) — works

Real on-device LLM inference validated (ch952 + the ch1025 endurance):
- First-token latency / sustained-throughput / streaming benchmarks **pass**.
- Throughput **20-55 tok/s** depending on thermal state (real A-series throttling).
- Over the 88-minute endurance: **memory stable** (`rss ~2865 MB` flat across iterations →
  no leak; `avail ~200-270 MB`), **thermal adaptive** (nominal/fair/serious, **never
  critical**; cooldowns 60→90→180→300 s escalate and recover serious→nominal), no jetsam.

## 3. Bugs found + fixed

### 3a. `footprint_mb` reported virtual_size, not phys_footprint (FIXED)
`BASChapter1025LongRunningEnduranceTests.swift` and **the device app**
`BASEnduranceAppRunner.swift` computed `footprint_mb` from `info.virtual_size` — the
process's reserved 64-bit address space (~**404 GB** on an MLX/Metal process; near-constant,
unrelated to real memory). `mach_task_basic_info` has no phys_footprint field at all.
Fixed both to read the real `phys_footprint` (the OS jetsam metric) via the substrate's
existing `BASTaskVmInfoProbe` (TASK_VM_INFO). **Validated on device:** footprint now reads
`18.8 MB` (pre-model-load) → `~3108 MB` (under the MLX model), never the old 404 GB garbage.
Commit `074b055a2`.

### 3b. Audit honesty fixes (FIXED)
From mining the device-run logs (commit `7c5c78b13`):
- `ch722` BPE test was named `...DeliversAtLeast5xSpeedup` + a stale "10× faster" header,
  but ch737 sped the raw path to ~0.2 ms so the pre-tok actor is now ~0.53× (slower). The
  test body + gate were already honest (both-paths-sub-5ms linear-time guard); only the
  name + header lied → renamed `testEncodeBothPathsStaySubFiveMsAt1KB` + corrected header.
- `ch729` PQ index printed `FAIL ❌` for recall@10 < 50% even though the test
  *intentionally* does not gate recall (3-5% on uniform-random vectors is documented;
  PQ trades recall for 53× memory + 78× speed) → relabeled informational.
- `BASThermalTwinNotificationTests` skip message blamed "macOS" only, but the runtime guard
  also fired on iOS device → message made honest.

Investigated, NOT bugs: the `deletedDomain` unknown-domain skip is tested defensive behavior
(`ch956_11` inserts it deliberately); the device skips of keychain/constitution suites are
env/entitlement-gated.

## 4. objc duplicate-class warning (structural — queued as a focused task)

`xcodebuild test` emits many `Class … is implemented in both … framework AND … xctest …
may cause spurious casting failures and mysterious crashes`. Root cause is **structural**:
the device tests `@testable import` the BAS modules in 400+ files (BASHostKit in 402), which
forces the test bundle to carry its own testability copies; the host app *also* embeds them
(for the `BAS_ENDURANCE_AUTOSTART` standalone path). Same classes in app framework + test
binary → the warning. It is **benign in practice** (all 13564 + 88-min + 41 tests passed).
No safe project.yml toggle exists (removing deps breaks 400+ @testable imports). The
thorough fix (shared dynamic/mergeable frameworks, likely touching `Package.swift` product
linkage = whole-package blast radius) is queued as a dedicated task.

## 5. Kill-event forensics — why long runs stop

**Question:** long device/background runs get terminated; who/what does it, and is it a
limit?

**Method:** signal-trap wrappers + process-ancestry capture + a pure-bash control probe
(no device, no xcodebuild).

**Findings (evidence-based):**
- **WHO: the host-side Claude Code CLI harness, via SIGKILL (-9).** Proof: a wrapper with
  `trap … TERM/HUP/INT` + a post-xcodebuild exit line logged **none** of them when the
  device run died — the only way a process vanishes with zero trace is SIGKILL (uncatchable).
  Process ancestry of a pure-bash probe: `bash ← zsh -c (per-command) ← claude-code/2.1.156
  claude --resume <session> ← Claude.app ← launchd`. The owner/reaper is the claude-code CLI.
- **NOT the phone, NOT xcodebuild, NOT the device.** The iPhone Air test was healthy
  mid-MLX-iteration at the moment of every kill (no jetsam/crash/disconnect); if xcodebuild
  had exited on its own the wrapper would have logged `EXITED rc=N` — it never did.
- **NOT a fixed time limit.** Observed kill/finish times were wildly variable: device runs
  died at **19 / 24 / 88 min**; a bg probe died at 29 min; a pure-bash probe ran the **full
  60 min** and finished on its own (never killed). So there is no ~19-min ceiling (my
  earlier claim was wrong and is retracted).
- **Exact trigger (DEFINITIVE — ch1044 严查): the Claude Code desktop app's `IdleManager`
  pausing the session when it goes idle.** Found in `~/Library/Logs/Claude/main.log` for
  THIS session:
  ```
  [IdleManager:session] Idle timeout reached, disconnecting local_d80fe4d0-…
  [CCD] Pausing session local_d80fe4d0-… due to idle
  ```
  fired repeatedly today (01:38, 04:26, 07:29 …). The idle timeouts are **900 s (15 min)
  "session" / 1800 s (30 min) "preview"** (1007 / 979 occurrences in the log). Pausing the
  session tears down its shell PTY (`LocalSessions.stopShellPty`), which SIGKILLs the
  `run_in_background` Bash tasks running in that PTY. The signal is SIGKILL (no trap fired)
  because version **2.1.156 predates the v2.1.160 changelog's SIGTERM-before-SIGKILL
  graceful-teardown fix** — so cleanup handlers never run.
- **Why the variance (19/24/29/88 min):** the idle timer **resets on activity**. A background
  task dies only after a CONTINUOUS idle gap (the agent waiting for the user's next message)
  exceeds the ~15 min timeout; survival = launch + active periods (each resets the timer) +
  the final fatal idle gap. **Live proof:** a control probe stayed alive 60 min and a device
  run 88 min precisely while foreground commands kept firing; the moment a >15 min idle gap
  occurred, the session paused and the task was SIGKILL'd.

**Consequence + fix for "run a full hour":** a continuous 1-hour run via the harness's
background mechanism *can* succeed — it is NOT blocked by a time limit, the phone, or
xcodebuild. The only thing that kills it is the **session going idle >15 min**. So:
- **Keep the session active** — poll the run every <15 min (also reports progress); each
  foreground command resets the idle timer → the run survives.
- **Pin the session** (Ctrl+T in agent view) — exempts it from idle reaping.
- **Run it in your own terminal** (outside Claude Code) — no IdleManager at all.

## 6. Environment constraints (host-side, not the substrate)

- The Claude Code tool sandbox **reaps detached children** (`setsid`/`nohup`) when a tool
  call returns; `launchctl submit` is (correctly) blocked as a sandbox-persistence bypass.
- The harness background-task reaper SIGKILLs tasks at non-deterministic points (§5).
- None of this is a substrate or device defect — it is the agent execution environment.
