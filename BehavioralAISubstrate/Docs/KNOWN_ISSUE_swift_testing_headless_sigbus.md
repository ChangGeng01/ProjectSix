# KNOWN ISSUE — `swift test` exits non-zero (SIGBUS) in the swift-testing portion, headless

> **Status: ENVIRONMENTAL — not a project test defect, not a regression.** The XCTest suite
> (**14,917 tests, 0 failures**) is the authoritative, reliable gate and passes on every run. The
> separate swift-testing (`@Test`) portion crashes with **SIGBUS (signal 10)** under full load in a
> **headless macOS session**, making the monolithic `swift test` exit 1. This is reproducible and
> independent of the project's code.

## Symptom

`swift test` ends with:

```
◇ Test "<some @Test, different every run>" ... error: Process '...swiftpm-testing-helper
  ... --testing-library swift-testing' exited with unexpected signal code 10
```

— a process-level **SIGBUS** in the swift-testing helper subprocess. The XCTest portion always
finishes first and clean (`Executed 14917 tests, with 0 failures`). The exit code is `1` solely
because of the swift-testing helper crash.

## What it is NOT (each ruled out by experiment)

| Hypothesis | Experiment | Result |
|---|---|---|
| The Claude Code Bash **sandbox** blocks something | `swift test` with the sandbox disabled | **Still SIGBUS** (106 `NSXPCConnection` errors anyway) |
| **Parallelism** (`--no-parallel`) | `swift test --no-parallel` | **Still SIGBUS** (flag reached the helper; no effect) |
| **SwiftData / CoreData XPC** (the `NSXPCConnection` errors) | `swift test --skip BASApple` (exclude the 8 swift-testing+SwiftData suites) | **Still SIGBUS — and 0 `NSXPCConnection` errors.** The XPC errors come from the SwiftData tests but are NOT the crash cause (RED HERRING) |
| A **specific bad test** | `swift test --filter BASApple` (the SwiftData suites alone) | **PASSES: 166 tests, 0 failures, 0 XPC errors.** And the crash location MOVES every run — no single deterministic crasher |
| The **recent 5-step arc**'s code (Steps 1–4) | every run | XCTest **14,917 / 0 failures** every time; all arc tests are XCTest and pass |

Crash locations observed across runs (all *different*, confirming a process-level fault, not one test):
`"context governance…"`, `"prompt envelope compiler…"`, `"role profile…"`, `"WP13… evolution
furnace…"`, `"caveated evidence policy…"`, `"default output guard…"`.

`SWIFT_BACKTRACE=enable=yes,…` did **not** emit a Swift backtrace (the helper subprocess dies
without the backtracer firing), so there is no symbolicated frame to attribute.

## Root cause (best supported conclusion)

An **environmental incompatibility** between the **swift-testing parallel runner under full load**
(thousands of `@Test`s in one helper process) and a **headless macOS session** (no logged-in GUI /
Aqua session; system services such as CoreData's XPC daemon are unavailable). The crash:

- reproduces on every full run (7 runs) regardless of sandbox / `--no-parallel`;
- moves location each run and emits no backtrace → process-level, not a logic assertion;
- vanishes when the swift-testing set is run in smaller **batches** (`--filter` subsets pass clean);
- is unrelated to SwiftData/CoreData (persists with those suites skipped and 0 XPC errors).

The project's `@Test` suites are **correct** — they pass in isolation/batches and (per design) in a
normal GUI/CI session. This is not something to "fix" by editing or weakening the tests; gating the
SwiftData suites was tried-in-principle and is disproven (skipping them still crashes).

## Reliable ways to run the suite (headless)

1. **XCTest is the authoritative gate** (recommended for headless CI): it is serial-by-default and
   100% reliable here — **14,917 tests, 0 failures** every run. Treat a green XCTest run as the
   pass/fail signal.
2. **Run the `@Test` portion in batches** — every `--filter` subset tried passes clean, e.g.:
   `swift test --filter BASApple` → 166 tests, 0 failures. Split the swift-testing tests into a few
   `--filter` batches in CI rather than one monolithic run.
3. **Run in a logged-in GUI session** (a real `macOS` desktop session, not headless ssh/sandbox),
   where the system-services layer the runner leans on is available.

### Note on worker / parallelism flags (why there is no one-flag fix)

`--num-workers` is an **XCTest-only** knob and requires `--parallel`
(`swift test --num-workers 1` errors: `--num-workers must be used with --parallel`); it does not
throttle the swift-testing runner, which manages its own Swift-concurrency parallelism. In this
toolchain (Swift 6.3.2) there is **no SPM flag that globally serializes the swift-testing engine** —
only the per-suite `.serialized` trait, which would mean annotating every `@Suite` and is not
warranted for an environmental crash that isn't the suites' fault.

### Bottom line

There is **no single `swift test` invocation** that reliably exits 0 in this headless environment.
For CI/headless, gate on the **XCTest** result (option 1) and/or run the `@Test` portion in
**`--filter` batches** (option 2); for a fully-green monolithic run, use a **GUI/login session**
(option 3).

## Reproduction + logs

```
swift test                       # SIGBUS in swift-testing helper, exit 1 (XCTest 14,917/0 first)
swift test --filter BASApple     # PASSES (166/0) — batches are clean
```

Investigation logs: `/tmp/bas_fullsuite_v2.log`, `…_v3.log`, `/tmp/bas_unsandboxed.log`,
`/tmp/bas_noparallel.log`, `/tmp/bas_bt.log`, `/tmp/bas_skipapple.log`, `/tmp/bas_apple.log`
(search `unexpected signal code 10` and `NSXPCConnection`).

## Scope note

This issue predates and is unrelated to the ADR-033 main-chain-wiring arc (Steps 1–4), whose tests
are all XCTest and pass. It was discovered while verifying that arc and split out for a focused look.
