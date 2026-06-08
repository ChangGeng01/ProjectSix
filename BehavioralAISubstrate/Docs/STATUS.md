# STATUS — current-state "you-are-here" index

> **Purpose (WS6):** `ADR_INDEX.md` maps every `ADR-NNN` to its defining doc (a reference map). This
> file is the **currency-ranked** complement: at a glance, what is SHIPPED + load-bearing vs DESIGN-only
> vs DEFERRED, plus the live known-issues + the honest pilot status. When an ADR body and the code
> disagree, **the code wins** — flag the doc, don't trust "historical description" as "current state."
> Keep this file current as ADRs land.

## 1. Shipped + live (or opt-in, byte-equal-off by default)

Foundational behavioral doctrine (always-on contracts): **ADR-006/012** (risk-calibration timing +
payload), **ADR-014** (opt-in / 红线 7 byte-equal-off), **ADR-018/019/020** (deliberation loop,
consequential wiring, evidence-resolution two-phase verdict).

Built + tested, **opt-in / byte-equal-off** (host elects; `makeWithDefaults()` stays legacy):
- **ADR-024** one-verdict-kernel — Step 1 (`evaluateLevel`) landed byte-equal + load-bearing. **Steps 2-3
  SUPERSEDED** (coordinator can't adopt the kernel byte-equally: rich-frames vs projected-primitives
  mismatch; keep-both forbids collapsing the two authorities — see ADR-024 REFRAME). Step 4 = optional
  deferred tidy. Drift handled by the kernel + `BASCoordinatorConsistencyCheck`, not a shared kernel.
- **ADR-025/026/032** Ed25519 commit authority + enforcer + per-op seam (`BASSovereignGatedCommit`) +
  turn-level host-side gate (`BASSovereignGatedTurn`, single-source digest formula, fail-closed; 12 tests) —
  the crypto commit-gate MECHANISM (runTurn is pure-emit → the gate is host-side by design; live needs a host
  keyring + adoption) · **ADR-027** constitution-vault seal · **ADR-028** LLM invocation contract ·
  **ADR-029** distillation bank · **ADR-030** `brain.chat` facade.
- **ADR-032** governance enablement — observe-mode contracts/traces ON by default (zero output change).
  The **crypto commit-verify** subset now has a host-side MECHANISM (`BASSovereignGatedTurn`, above);
  rejection / dual-key / deny still REFUSED pending a host keyring/policy (R1). See ADR-032 UPDATE.
- **ADR-033** main-chain wiring (MiniLM memory + durable SQL/vector index + native executors + fabric,
  host-injected) · **ADR-034** agent-fabric multi-round authoritative loop.
- **ADR-036** L8 cosineTopK retrieve takeover (the ONLY sanctioned NON-byte-equal path; host opt-in).
- **ADR-037** global durable cosineTopK recall on-device (opt-in; on-device verified; hardened — engine
  bounded in lockstep, monotonic sync).
- **ADR-039** hybrid Metal/CPU determinism boundary — the doctrine for real GPU compute (byte-determinism
  REQUIRED→CPU/Rust spine: Storage/Memory/EventLog/Replay/Governance; approximate ALLOWED→Metal:
  Embedding/LLM/Planning/Reasoning/Animation/Perception). **macOS mechanisms built (Phases 0-3 + sync-bridge),
  each opt-in / byte-equal-off / macOS-verified:** `BASApproxValue` type-quarantine + spine build-tripwire
  (P0) · per-kernel exec records + `recordSink` (P1) · L8 Metal topK dispatcher + async→sync bridge (P2) ·
  deterministic dispatch router (P3). **On-device cert PASSED** (iPhone Air: `gpu=true`, parity_set_ok,
  `max_score_err=0` — the FIRST on-device execution of the substrate's own Metal kernels, after fixing the
  V2-guard + the loader's source-vs-metallib bug). **Phase 2 L8 LIVE seam BUILT + macOS-certified** —
  Metal cosine-topK over the in-Swift snapshot corpus (`BASMetalCosineTopKSeam`, opt-in `BAS_L8_METAL_TOPK`,
  default byte-equal-off; wedge-safe nil→CPU retreat; boundary-verified by a full spine trace = only atomID
  crosses), DeviceTestApp builds + the per-iter `📊 l8-metal-topk` line is wired; **on-device cert pending an
  awake device** (the device slept between the smoke cert and the run). **Pending:** Phase 4 (Metal SSM
  reasoning — `ssmCaution` stays CPU). See ADR-039 §7.

Process: **ADR-016** milestone-advance convention. Honest corrections (not new behavior): **ADR-031**
(built-vs-wired reckoning), **ADR-035** (multi-lang pilots default-on reconciliation).

## 2. Design-only / deferred (built nothing, or partial + gated)

- **ADR-021** unified evolution architecture — DESIGN synthesis; O0/O1 NO-GO; the wall is
  outcome-blindness (the substrate is not a self-improving learner).
- **ADR-022 / ADR-023** sovereign-verdict parity + reconciliation — **RESOLVED (observability, NOT a halt
  gate). Do not re-attempt R1.** The full-grid sweep proved 100% of the 886 coordinator↔engine divergences
  are the engine being *deliberately stricter* (every escalation carries a reason code). R1 (engine
  missing-lineage → shadowLock) was implemented, **REVERTED** (4 sovereign tests assert deadStop on purpose),
  and operator-ruled **KEEP BOTH** (engine deadStop = independent backstop; coordinator shadowLock =
  recoverable production path) — re-doing it lowers a sovereign verdict + rewrites its guard tests = 红线.
  Engine-parity→halt (Phase-2) is **ABANDONED**; reconciled via `classifyDivergence` →
  `intentionalDefenseInDepth` (shipped, BASHostKit). The REAL halt signal = `BASCoordinatorConsistencyCheck`
  (coordinator vs its own re-derived baseline; shipped + wired). See **ADR-023 §8** before touching this arc.
- **ADR-038** on-device MLX-eval-wedge re-cert — **DONE (honest negative).** Run A PASS (baseline stable,
  256-cap verified on the REAL build — the prior runs unknowingly ran a STALE binary). Run B WEDGE: the WS1
  typed prompt cleared the historical iter1/prompt2 point but the wedge **MOVED to iter2/prompt2** →
  **prevention UNPROVEN; feed-forward stays default-OFF.** WS1+WS2 are partial improvements, not a green
  light. See ADR-038.
- **GHOST:** ADR-013 (a historical chapter note, not a live contract).

## 3. Multi-language pilots — probe vs main-path (honest, #7)

- **SQL + Rust: genuinely main-path** (when the host wires routed memory) — the MiniLM/SQL/vector index
  + the Rust L8 engine cosineTopK are real hot paths (ADR-033/036/037).
- **Metal / C / C++: probe + local bridge only** — observability/telemetry, NOT main-chain hot paths.
  **Metal contributes 0 to live LLM decode — MLX owns the GPU.** Mamba/MPSGraph kernels exist but are
  not on the decode path. `substrateInternalFactoryCallSiteCount = 0` (ADR-035): no pilot routes into
  `BASEBrainTurnResult`; the live brain uses direct-init V1.
- Deferred hygiene: ~10 ungated `import Metal` files + ~60 consumers want `#if canImport(Metal)` guards
  (source clarity; does NOT enable watchOS — MLX deps fail there first). NOT a path to replacing MLX
  decode.

## 4. Known issues + workarounds

- **MLX/Metal GPU-eval wedge** (highest-priority, **UNRESOLVED**): a synchronous, uncancellable Metal eval
  that hangs with zero token progress; **no in-process recovery** (Swift can't cancel it). On-device A/B
  (ADR-038, 2026-06-07): WS1's typed prompt cleared the historical iter1/prompt2 point but the wedge
  **MOVED to iter2/prompt2** — so prompt-shaping prevention is INSUFFICIENT and **feed-forward stays
  default-OFF** (it still wedges). WS2's 256-cap (verified) + the 512 backstop bound exposure but don't
  eliminate it. Next levers + falsification in ADR-038 §6. See `BASEnduranceAppRunner.swift` / `MLXOrganAdapter.swift`.
- **Swift-testing headless SIGBUS** (#6): the `@Test` parallel runner SIGBUSes under full load in a
  headless macOS session (environmental, not project code). Authoritative gate =
  `swift test --disable-swift-testing` (XCTest, 15k+). Entry: `scripts/swift-test-headless.sh`. See
  `Docs/KNOWN_ISSUE_swift_testing_headless_sigbus.md`.
- **Device thermal envelope**: sustained on-device gemma decode drives the device to `serious` thermal
  within ~45 min; the adaptive cooldown manages it (never `critical`). See `Docs/DEVICE_TEST_THERMAL_ENVELOPE.md`.

## 5. Source-of-truth pointers

- `Docs/ADR_INDEX.md` — the full ADR→doc reference map (every `ADR-NNN` resolves).
- `Docs/L8_ARC_SEAL.md` — memory/rusqlite/vector-index wiring + 不变量 #1/#2/#3 + 红线 7.
- `Docs/CH_1024_PLUS_OPTIMIZATION_BACKLOG.md` — endurance/probe status.
- Per-subsystem ADRs as listed above.
