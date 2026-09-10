# Test skip inventory — every skipped test, why, and how to run it

> **Purpose (不要逃避):** a skipped test is only honest if it is *documented and runnable on demand*, never a
> silent dodge of a failure. This file enumerates **every** skip in the default `swift test --disable-swift-testing`
> run so the skip count is an auditable, runnable contract — not a black box.
>
> **Snapshot:** full suite **15282 tests, 101 skipped, 0 failures** (2026-06-10, macOS 26.5, default Xcode 26.5
> toolchain). Regenerate the authoritative list any time:
> ```sh
> swift test --disable-swift-testing 2>&1 | grep -E ': Test skipped - ' | sed -E 's/^.*: Test skipped - //' \
>   | sort | uniq -c | sort -rn
> ```

## Key finding — NOTHING is silently dodged

- **No skip hides a failure.** Every one is an explicit `XCTSkip` with a precise reason string; the suite is
  `0 failures`.
- **The Metal / MPSGraph GPU kernel tests are NOT skipped** — they RUN. `MTLCreateSystemDefaultDevice()` returns
  a real device inside the `xctest` host on this Mac, so `BASMPSGraph*` / `BASMetal*` kernels execute real GPU
  dispatch in the suite. (The `XCTSkipIf(true, "Metal unavailable …")` lines inside those tests are
  `catch BASKernelError.frameworkUnavailable` fallbacks that only fire on a Metal-less host, e.g. some CI — they
  do not fire here.) The earlier assumption that these were device-only was wrong; the empirical run corrects it.
- The 101 skips are all one of: **print-only benchmark archives**, **env-gated real-model E2E**, **perf /
  captured-baseline benchmarks**, or **platform/soak/coverage gates**. Each is below.

## Inventory by category

| # | Category | Count | Gate | Hides a failure? | How to run |
|---|----------|-------|------|------------------|------------|
| A | Apple FoundationModels real-invocation E2E | 15 | env `QINAO_FM_E2E=1` | No (real-FM path; macOS 26+ + model) | `QINAO_FM_E2E=1 swift test --disable-swift-testing --filter AppleFoundation` |
| B | CoreML real-model E2E + stress | 9 | env `QINAO_COREML_E2E=1` (+`QINAO_COREML_STRESS_20MIN=1` for the 20-min one) | No (bundled model) | `QINAO_COREML_E2E=1 swift test --disable-swift-testing --filter Chenglu` |
| C | MLX real-inference E2E | 7 | env `QINAO_MLX_E2E=1` (downloads ~1.5 GB Gemma) | No (network + weights) | `QINAO_MLX_E2E=1 swift test --disable-swift-testing --filter MLXOrganAdapterE2E` |
| D | Print-only benchmark *archives*, pending asserted replacement (chapter 879) | 30 | unconditional `XCTSkip` | No (these ASSERT nothing — pure `print()` tournaments kept for live-data reference) | re-enable the `XCTSkip` line locally to print live numbers |
| E | Print-only benchmark archives **superseded** by asserted benches (chapter 878.5) | 14 | unconditional `XCTSkip` | No (coverage moved to the asserted successor, which RUNS — see below) | successor tests run in the default suite; re-enable to print legacy numbers |
| F | Perf benchmark gates (ch 952.4 high-bar, regression fuzz) | 9 | env `BAS_FUZZ_BENCH_RUN=1` | No (perf, noisy) | `BAS_FUZZ_BENCH_RUN=1 swift test --disable-swift-testing --filter Benchmark` |
| G | Captured perf baselines w/ recorded verdict (ch 889/890/881) | 9 | unconditional `XCTSkip` w/ recorded measurement | No (one-time measurement; verdict in the skip string) | re-enable the `XCTSkip` to re-measure when the FFI shape changes |
| H | Deferred baseline (ch 892 — bench infra ready) | 4 | unconditional `XCTSkip` | No (deferred measurement) | re-enable + run interactively to capture live numbers |
| I | 1-hour cognitive-OS soak | 1 | env `QINAO_COGOS_SOAK_1H=1` | No (~1 h wall-clock) | `QINAO_COGOS_SOAK_1H=1 swift test --disable-swift-testing --filter Soak` |
| J | Strict per-iteration fuzz coverage | 1 | env `BAS_FUZZ_STRICT_COVERAGE=1` | No (opt-in strictness) | `BAS_FUZZ_STRICT_COVERAGE=1 swift test --disable-swift-testing` |
| K | Platform-only inverse paths | 2 | `#if`/availability | No (the OTHER path runs here) | run on the other platform |

Total: 15+9+7+30+14+9+9+4+1+1+2 = **101**.

### A — Apple FoundationModels real-invocation E2E (`QINAO_FM_E2E=1`)
`AppleFoundationE2ETests`, `AppleFoundationStatelessTests`, `AppleFoundationStreamingTests`,
`AppleFoundationStreamCancellationTests`. These invoke the **real on-device Apple FM model**; the unit suite mocks
it for determinism. macOS 26.5 here HAS FoundationModels (`#available` true), so they are runnable on demand. The
FM adapter itself is already runtime-certified (ADR — FoundationModels macOS + iPhone Air device cert).

### B — CoreML real-model E2E (`QINAO_COREML_E2E=1`)
- `BASChengluFullChainE2ETests` — runs against the **bundled** `.mlmodel`/`.mlmodelc`; passes with just the flag
  (verified below).
- `BASChengluRealModelE2EHarnessTests` (6) — **double-gated**: also need per-model path env vars
  (`QINAO_CHENGLU_{LATENCY,LENGTH,MULTIHEAD,PERMIT_PREDICT,PREFLIGHT}_PATH`) pointing at **external** `.mlmodel`
  files not bundled in the repo. The operator supplies those artifacts to exercise the multi-head harness.
- `BASChenglu20MinStressTests` — also needs `QINAO_COREML_STRESS_20MIN=1` (20-min runtime).

### C — MLX real-inference E2E (`QINAO_MLX_E2E=1`)
`MLXOrganAdapterE2ETests`, `BASChapter952RealMLXOnDeviceTests`, `BASChapter952_4HighBarBenchmarkTests`. First run
downloads ~1.5 GB Gemma weights from Hugging Face, then runs real MLX inference. Network + disk → opt-in.

### D + E — print-only benchmark archives (chapters 879, 878.5)
These were **exploratory tournaments** that `print()` timing comparisons between implementations (CPU vs GPU vs
Rust, etc.) during development. **They assert nothing**, so skipping them loses zero coverage.
- **E (14, superseded):** the chosen winner is pinned by an *asserted* successor that RUNS in the default suite —
  `BASChapter872BatchedCosineRayonTests`, `BASChapter871MatMul5WayBenchmarkTests` +
  `BASChapter871BrainMPSGraphMatMulParityTests`, `BASChapter868FlashAttentionAssertedBenchmarkTests`. The archives
  are kept only for live-data reference.
- **D (30, pending replacement):** chapter-879 activation/ledger/tournament archives with **no asserted successor
  yet** — known technical debt, honestly labeled (`… without asserted-bench replacement yet`). Converting each to
  an asserted bench (like the chapter-878.5 successors) is tracked future work; until then they stay print-only +
  skipped to save CI time.

### F + G + H — perf benchmarks / captured baselines
Perf measurements are noisy and machine-specific, so they are opt-in (`BAS_FUZZ_BENCH_RUN=1`) or carry a **recorded
verdict in the skip string** (e.g. ch 889: "Rust wins by 7.32–7.45× at inputs ∈ {10,100,1000}", captured
2026-05-23). Re-enable to re-measure when the relevant code shape changes.

### I + J — soak / strict-coverage
The 1-hour soak (`QINAO_COGOS_SOAK_1H=1`) and strict per-iteration fuzz coverage (`BAS_FUZZ_STRICT_COVERAGE=1`)
are too slow / strict for every CI run; runnable on demand.

### K — platform-only inverse paths
- `BASSovereignKeychainBindingTests.testNonDarwinPathsReturnPlatformUnavailable` — the `.platformUnavailable`
  contract is only reachable where `canImport(Security)` is false (Linux). On macOS the REAL Keychain paths run.
- `AppleFoundationOrganAdapterTests.testProviderUnavailableOnUnsupportedOS` — the stub/unavailable path is only
  reachable where FoundationModels is absent. On macOS 26.5 the REAL availability path runs.
Both are unavoidable: one platform cannot exercise both sides of an availability fork in one run.

## Verified-passing log (proving the env-gated tests actually pass — not "trust me, skipped")

Ran 2026-06-10, macOS 26.5, default Xcode 26.5 toolchain:

- **Apple FoundationModels E2E (`QINAO_FM_E2E=1`) → 17/17 PASS, 0 skipped** (16.3 s, real on-device FM
  invocation): `AppleFoundationE2ETests` 7/7, `AppleFoundationStatelessTests` 3/3,
  `AppleFoundationStreamCancellationTests` 2/2, `AppleFoundationStreamingTests` 5/5. The category-A skips are a
  pure CI-speed/determinism opt-out — the path is fully green on demand.
- **CoreML E2E (`QINAO_COREML_E2E=1`) → full-chain path PASS; 6 harness tests have a SECOND gate.** Setting
  `QINAO_COREML_E2E=1` runs `BASChengluFullChainE2ETests` (bundled `.mlmodel`/`.mlmodelc`), but the 6
  `BASChengluRealModelE2EHarnessTests` then skip again on per-model **path** env vars
  (`QINAO_CHENGLU_{LATENCY,LENGTH,MULTIHEAD,PERMIT_PREDICT,PREFLIGHT}_PATH`) pointing at external `.mlmodel`
  files that are NOT bundled in the repo. So category B is double-gated: the env flag is necessary but not
  sufficient — those 6 need external model artifacts supplied by the operator. Honest correction to the table
  above: only the full-chain CoreML E2E is bundled-runnable; the multi-head harness requires external models.

NOT run here (genuinely heavy / external, run commands in the table above): MLX E2E (≈1.5 GB Gemma download),
the 1-hour soak, and the 20-min CoreML stress.
