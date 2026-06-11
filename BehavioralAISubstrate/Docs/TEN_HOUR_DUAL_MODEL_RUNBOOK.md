# 10-Hour Dual-Model Endurance Run-Book — iPhone Air (max data for future development)

**Goal:** one unattended 10-hour sitting that yields the most data per device-hour — two contrasting
models × a knob sweep that gives clean A/B device evidence for the levers built this session
(`kvBits`, `maxKVSize`, the U1 speculation memory governor, the U3 liveness monitor, the ADR-018
shadow-trial carrier), on top of long-run stability / thermal / memory / sovereign-chain data.

**One command:**
```bash
BUILD=1 bash scripts/run-iphone-air-dual-model-sweep.sh
```
(omit `BUILD=1` if the app is already installed). A `SCALE=0.1` env runs a ~1h dry-run of the full
sweep shape first — **do this once before the real 10h run** to confirm the device path end-to-end.

---

## Why this design

- **Decode is 99% of a turn** (`CONCURRENCY_MEASUREMENT_FINDINGS.md`), so the data that matters is
  decode-side: latency distribution, KV memory, throughput, wedge/thermal behavior. The sweep targets
  exactly the decode levers that lack device evidence.
- **Wedge survival is the #1 threat over 10h.** The MLX wedge is an uncancellable Metal-eval hang
  (ADR-038 §9-10) — it cannot be fixed in-process; the proven mitigation is external kill+relaunch.
  This run-book wraps the validated `run-endurance-watchdog.sh` (11/11 wedges auto-recovered, 0 reboots)
  so the 10h window survives any number of wedges.
- **A/B cleanliness:** every knob phase differs from its model's baseline by ONE lever, so the pulled
  data is directly comparable. The two models are deliberately different architectures.

## The two models

| | Model | `BAS_MLX_MODEL` | Arch | Spec-decode | Why |
|---|---|---|---|---|
| **A** | Llama-3.2-3B | `llama` | standard (no Gemma-3n wedge) | CERTIFIED 3B↔1B, 2542MB FITS | stable workhorse for the KV sweep + governor + spec-decode |
| **B** | Gemma-4-E4B | `e4b` | Gemma-3n (wedge-prone, cache-cap-stabilized) | single-model | quality default + architecture contrast + real wedge/liveness exercise |

## Phase table (600 min = 10h)

| Phase | Model | Min | Delta vs baseline | Yields |
|---|---|---|---|---|
| A1 | Llama | 90 | — (spec-decode ON, governor armed) | baseline latency/thermal/memory; spec-decode; sovereign chain; field metrics; shadow-trial |
| A2 | Llama | 75 | `+BAS_KV_BITS=4` | KV-quant A/B vs A1 (throughput + KV memory + quality-by-hand) |
| A3 | Llama | 60 | `+BAS_KV_BITS=8` | 3-point KV-quant sweep (off / 4 / 8) |
| A4 | Llama | 75 | `+BAS_MAX_KV_SIZE=512` | rotating-KV cap A/B vs A1 |
| B1 | Gemma | 120 | — (single-model default) | architecture contrast: Gemma-3n wedge/thermal/memory under the 512MB cache cap; liveness + watchdog recovery stats |
| B2 | Gemma | 90 | `+BAS_KV_BITS=4` | KV-quant A/B on Gemma-3n |
| B3 | Gemma | 90 | `+BAS_MAX_KV_SIZE=512` | rotating-KV cap A/B on Gemma-3n |

**Every phase also carries** (byte-safe, pure observation): `BAS_LIVENESS_MONITOR=1`,
`BAS_SHADOW_TRIAL_LOOP=1`, `BAS_SHADOW_PARITY=enabled`. Always-on in the runner: the sovereign
per-turn signed ledger, A3 MetricKit field metrics, the P0 phase-split verdict. Cooldown is adaptive
(base 60s); the governor is armed on the Llama phases (byte-safe — greedy spec-decode is token-identical,
so a draft drop/restore changes latency only).

**Wedge-vs-cooldown safety:** `STALL_SEC=420` is set ABOVE the adaptive cooldown ceiling
(`base*3+120 = 300s`) + a slow decode, so a legitimate cooldown is never mistaken for a wedge. A real
wedge during active decode is still caught within ~7 min.

## Pre-flight (operator, one-time)

1. iPhone Air plugged into the Mac, **charging**.
2. iPhone **unlocked**, Settings → Display & Brightness → **Auto-Lock → Never**.
3. Developer cert trusted; the app installed (`BUILD=1` does this).
4. Confirm the device ID: `xcrun devicectl list devices` → set `DEVICE_ID=...` if it differs from the
   default in the script.
5. **Dry-run:** `SCALE=0.1 bash scripts/run-iphone-air-dual-model-sweep.sh` (~1h) — confirms every phase
   launches, logs, and archives. Inspect one `phase-*/` dir for the expected files before committing 10h.

## Data: what lands where

Each phase archives the **whole app Documents container** into
`Docs/cert-logs/dual-model-sweep-<stamp>/phase-<id>/`:

| File | Content | Survives kill |
|---|---|---|
| `ch1025-endurance-*.log` | full emitBoth stream (📊 metrics, 🧠 mlx per-decode, 🔐 sovereign, 🧮 governor, 🛡 liveness, 🔁 shadow-trial, P0 phase-split, FINAL summary) | YES (append-only file) |
| `field-metrics.jsonl` | OS-attested MetricKit rows: peak/suspended memory, termination diagnostics, P7 phase attribution | YES |
| `bas-sovereign-ledger.sqlite` (+ `.key`) | per-turn Ed25519-signed + chained audit entries | YES (WAL, per-turn append) |
| `bas-memory-atoms.sqlite` | durable L8 atoms (cross-restart cognitive state) | YES (WAL, per-iter flush) |
| `bas-vector-index.sqlite` | persisted embeddings | YES |

**Lost on a mid-phase kill:** only the in-memory `FINAL` summary line — recomputable from the raw
`🧠 ch1025 mlx` / `📊` log lines. Everything else is append-only and durable.

## Analysis (after the run)

Per phase dir:

- **Latency distribution:** `grep '🧠 ch1025 mlx ' phase-A1/ch1025-endurance-*.log` → per-decode ms;
  compare A1 vs A2 vs A3 (kvBits off/4/8) and A1 vs A4 (maxKVSize). The `FINAL` line gives p50/p99 if the
  phase completed cleanly.
- **KV memory:** `grep '📊 ch1025 mlx-mem' …` → active_mb / cache_mb / peak_mb trajectory; the kvBits /
  maxKVSize phases should show lower KV footprint.
- **Governor:** `grep '🧮 spec-governor' …` → ARM line + any DROP/RESTORE events (Llama phases). If it
  never fires at the default watermark (2542MB < 2700MB), that itself validates the watermark is
  conservative — a watermark-override knob is follow-on work.
- **Liveness / wedge:** `grep '🛡 decode-stall' …` (verdict lines) + the watchdog stdout (wedges
  survived / recovered). Gemma phases (B1-B3) exercise this most.
- **Shadow-trial loop:** `grep '🔁 shadow-trial' …` → FINAL `evaluated`/`advanced` (advanced expected 0 —
  the carrier is carry+visibility, never a learner; a non-zero is a doctrine-violation signal).
- **Sovereign chain:** open `bas-sovereign-ledger.sqlite`; the run logs `🔐 sovereign-loop FINAL
  signed_entries=N head=… chain_verified=true`. Cross-check entry count vs decode count.
- **Thermal/memory long-run:** `grep '📊 ch1025 FINAL' …` → thermal_trajectory, rss trajectory,
  endpoint_delta (negative = no leak, per CH_1025_8).
- **Cross-model contrast:** A1 vs B1 — standard vs Gemma-3n arch on latency, thermal onset, wedge rate,
  memory profile under the same cache cap.

## Knobs reference (set per phase by the driver)

Model select `BAS_MLX_MODEL`; decode levers `BAS_KV_BITS` (4/8) / `BAS_MAX_KV_SIZE`; speculation
`BAS_SPEC_GOVERNOR`; observation `BAS_LIVENESS_MONITOR` (+`_THRESHOLD_SEC`) / `BAS_SHADOW_TRIAL_LOOP` /
`BAS_SHADOW_PARITY`; sizing `BAS_INTERNAL_*` (iter count / mlx prompts / cooldown / max-decode-tokens);
stability `BAS_MLX_CACHE_LIMIT_MB` (default 512, the decisive wedge cap). Full inventory in
`DeviceTestApp/Sources/App/BASEnduranceAppRunner.swift` (`EnduranceEnv` enum + the `env[...]` reads).

## Scripts

- `scripts/run-iphone-air-dual-model-sweep.sh` — the phase driver (this run-book's one command).
- `scripts/run-endurance-watchdog.sh` — the per-phase wedge-surviving watchdog (parameterized 2026-06-12
  with `MODEL` / `MLX_PROMPTS` / `COOLDOWN_SEC` / `ENV_EXTRA` / `ARCHIVE_DIR`; defaults unchanged, so prior
  callers are byte-identical).

## Honest bounds (R1)

- Two devices are in hand but this run-book drives ONE; cross-device merge (2-device parity) is a
  separate step — same-model-on-2-devices, not part of this single-device sweep.
- The KV levers (`kvBits`/`maxKVSize`) CHANGE decode numerics — this run gathers the throughput/memory
  data; the **quality** judgment is by-hand on the logged outputs, and any DEFAULT flip remains a
  separate reviewed commit with its own evidence (ADR-014). This run does not promote anything.
- The governor may not trigger at its conservative watermark on the FITS Llama pair; that is recorded as
  a finding, not a failure.
