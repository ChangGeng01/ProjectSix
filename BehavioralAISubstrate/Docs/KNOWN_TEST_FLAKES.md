# Known Test Flakes — triage registry

> **Purpose (ch 1044 查缺补漏):** the full `swift test` sweep exits non-zero from
> a small set of **toolchain/infra flakes that are NOT real regressions**. This
> knowledge was scattered (a SIGBUS doctrine in `Sources/`, plus tribal memory)
> and its absence caused a real mistake this session: a sweep's "1 failure" was
> misread as a regression and a correct commit was needlessly reverted. This doc
> is the canonical registry so that never repeats.

## The triage rule (read this first)
A full `swift test` exiting non-zero does **NOT** mean a regression. Triage:
1. Get the aggregate: `grep -E "Executed [0-9]+ tests, with" sweep.log | tail -1`.
   **0 XCTest failures = no regression**, regardless of process exit code.
2. For any real failure line (`grep -E "XCTAssert.* failed|error: -\[|' failed \("`),
   check it against the flakes below.
3. **Re-run the suspect in isolation** (`swift test --filter <Suite>`). A flake
   passes alone; a regression fails alone.
4. Only a real `XCTAssert* failed` that **persists in isolation** AND is in code
   you touched is a regression.

Gate development on the **fast, clean filtered suites** (e.g.
`BASChapter1039DeliberationLoopTests`, the per-feature suites), NOT the noisy full
sweep.

## Flake 1 — swift-testing helper SIGBUS (`signal code 10`)
- **Signature:** `swiftpm-testing-helper … --testing-library swift-testing' exited
  with unexpected signal code 10`. Exits the runner non-zero **even with 0 XCTest
  failures** (the crash is in the swift-testing library portion, which runs AFTER
  the XCTest suite has already passed).
- **Cause:** toolchain bug — `async XCTest method + startSession + actor hop` on
  Xcode 26.x / Swift 6.3 / macOS 26 SDK; crashes before the test body runs.
- **Canonical record:** `Sources/BASRuntimeCore/BASSignalTenIntegrationTestTriage
  Doctrine.swift` (documents 12 quarantined async tests). It is **non-deterministic
  about WHICH test it lands on** — it hopped between unrelated tests across
  identical-code runs this session.
- **Not a regression.** Affected `@Test` suites pass under narrow `--filter`.

## Flake 2 — CoreData / NSXPC sandbox failure (`134060`) — THE ONE THAT CAUSED A WRONG REVERT
- **Signature (multiple forms):** `CoreData: error: Failed to create
  NSXPCConnection`; `Unable to send to server; failed after N attempts`;
  `addPersistentStoreWithType … NSCocoaErrorDomain Code=134060`. ~80-125 such
  noise lines appear in a full sweep.
  Those `134060` / NSXPCConnection LOG lines are a genuine sandbox/XPC artifact and
  are safe to ignore.
- **⚠️ CORRECTION (2026-07-11 deep-audit — this entry was a stale lying contract):**
  the `BASProductionAdoptionSmokeTests.testCanonicalAuditComplianceHostAdoption`
  atomID cross-store parity mismatch that historically co-occurred with this noise
  was **never caused by CoreData/NSXPC** — that test uses `BASSQLBrainHistoryStore`
  (SQLite) + `BASRustBrainHistoryStore` (Rust) and touches **no** CoreData (grep:
  0 CoreData/NSXPC refs). The real root cause was an **unstable sort**: under load
  both stores rounded `retrievedAt` to the same millisecond and `sorted(by:)` is not
  stable, so the two stores' recentRecords order (hence the joined atomID) diverged.
  **FIXED in commit `2c50050a5` (2026-06-11)** via a `(retrievedAt DESC, turnRef DESC)`
  tiebreaker threaded identically into **both** stores, pinned by
  `testRecentRecordsTiebreaksDeterministicallyUnderTimestampTie`. At HEAD the
  atomID-parity assertion is **deterministically green.**
- **Therefore a failure of the atomID cross-store parity assertion at HEAD is a REAL
  regression (turnRef threading broken) — do NOT wave it off as infra noise.** Only
  the raw `134060` / NSXPCConnection LOG lines are the ignorable flake. (This corrects
  the entry that, in ch1042, misread this symptom as a flake and triggered a needless
  revert+reapply of a correct commit — the exact misdiagnosis this stale text would
  have caused an auditor to repeat.)

## Flake 3 — wall-clock perf benchmark
- **Signature:** `BASChapter905StorePerfBenchmarkTests.testBenchmarkVaultSave100`
  — `XCTAssertLessThan` on a timing ratio; can fail under sweep CPU load.
- **Proof it's a flake:** passes in isolation (`swift test --filter
  BASChapter905StorePerfBenchmarkTests` → 5/0). Did not even trigger in the ch1044
  audit sweeps (vault.save ratio ~0.88-0.89x, well within the 2× band).
- **Not a regression** unless it fails in isolation.

## Honest note
These are **infra/toolchain flakes**, not substrate bugs — but their existence
means the full sweep is not a clean pass/fail signal, which is itself the
motivation for the audit's HIGH-2 finding (no clean substrate-wide byte-equality
harness in CI). Flake 1 (SIGBUS) is the documented toolchain bug; Flakes 2-3 are
environment-sensitive. Re-run isolated; trust the 0-XCTest-failure count + the
fast filtered suites. See `Docs/ARCHITECTURE_AUDIT_ch1044.md`.
