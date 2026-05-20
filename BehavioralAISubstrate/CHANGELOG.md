# Changelog

Substrate-wide release history。 Mirrors BRANCH_SUMMARY.md but consumer-shaped:
what changed, what migrated, what's wire-format-pinned, what needs caller-side
work on upgrade.

Following keep-a-changelog conventions where they fit. The substrate is private
+ pre-1.0 — `unreleased` means「on the current main branch but not yet tagged」。

---

## [0.56.0] — 2026-05-20 — MATURATION ARC SEAL + post-severance polish

Tag covers chapters 七百二 → 七百五十七 (the full branch arc that delivered the
14-layer 电子脑 as a standalone substrate)。 Before-host severance + quality-gate
retire + SDK-readiness polish。

### Added
- **L13 Evolution Furnace** is now correctly documented as implemented
  (was wrongly marked「deferred」 in the root README)。 Implementation lives
  in `Sources/BASHostKit/EBrainRuntimeCoordinator+EvolutionGovernance.swift`
  + `BASEBrainTurnResultEvolutionBundle.swift`。
- **3 MATURATION-ARC production-default Rust flips** (chapter 七百五十一-七百五十六):
  L14 chain seal (1.24×), L14 verdict engine (13.84×), L11 SQL persistence go-live。
  Brings substrate-wide total to **12 production-default flips** across 56 chapters。
- **Runtime crash contracts** section in README — documents all 14 `precondition(...)`
  / `fatalError(...)` foot-guns SDK consumers must avoid (chapter 七百五十七 第四刀)。
- **`retrievedAt:` parameter** threaded through `BASCognitiveBrain.recordSummary`
  into both `BASSQLBrainHistoryStore.recordSummary` and `BASRustBrainHistoryStore.recordSummary`
  → cross-store atomID parity now deterministic by construction (chapter 七百五十七 第四刀)。

### Changed
- **Calibrator schema 1 → 2** (chapter 七百三十 第三刀):the auto-router calibration
  cache file's schemaVersion bumped。 Pre-existing host calibration caches will be
  rejected on first load post-upgrade and re-calibration runs (10-30s on cold start)。
  No host-side migration required。 See MIGRATING.md for details。
- **Event log SQLite schema 1 → 2** (chapter 七百三十二 第一刀):added
  `payload_format INTEGER NOT NULL DEFAULT 1` column for dual-read JSON ↔ binary
  payload codec。 Lazy-upgrade on read — existing rows stay JSON until rewritten。
  No host-side migration required。 See MIGRATING.md for details。
- **README products list** corrected — was listing 9 of 16 .library products;
  now lists all 16 + the `BASBrainCLI` executable, grouped by layer。

### Architecture milestones
- **56-chapter MATURATION ARC sealed** — branch trajectory documented in
  `BRANCH_SUMMARY.md` 七百二-七百五十六。 Six sub-arcs delivered:
  multi-language scaffold / per-primitive auto-router buildout / aggressive
  evolution / quality refinement / tiered-compression idiom / layer migration。
- **Doctrine 大幅度 缩减** (chapter 七百五十二): ~11,389 active LOC of
  doctrine surface deactivated。 Registry is sole source-of-truth for chapter data。
- **Before iOS host SEVERED** (2026-05-20):legacy reference host moved to
  `/Archive/Legacy/Before/`。 Substrate stands alone。 SampleHost is the only
  living reference (currently shallow,reconstitution pending)。
- **Before-quality-gate scripts RETIRED** (2026-05-20):4 scripts +
  5 companion docs moved to `Archive/Legacy/`。 Substrate gates now SPM-driven
  (`swift build` + `swift test`)。

### Test surface
- Full sweep: **12,965 tests / 31 skipped / 0 failures** in 89s (verified
  2026-05-20)。 99.99% pass rate sustained across the arc。
- 7 stale test fixtures from chapters 七百二十-七百五十六 refreshed
  (chapter 716 tearDown stale-restore + chapter 704/705 ABI floor + chapter 710
  schema-pin + chapter 七百三十二 schema bump in BASEventLogTests)。

### Removed
- Nothing。 Per substrate-wide discipline 「依旧 不删除 只 comment」 / 「不要 删除
  创建个 文件夹 把 不需要的文件 都转移 进 文件夹」,deprecated code is commented-
  out (`#if false`) and out-of-scope files are relocated to `Archive/`。

---

## [Pre-0.56.0] — chapter 七百二 → 七百五十六 chapter-by-chapter history

Detailed chapter-shaped history lives in
`BRANCH_SUMMARY.md` and `docs/BEHAVIORAL_AI_SUBSTRATE_CHANGELOG.md`。 The
changelog here picks up at the first tagged release;earlier history is
historical-record-shaped, not consumer-shaped。

---

## Stability + semver intent

- **0.x.y** = pre-stable。 Breaking changes documented per minor release。
- **Minor bump** (0.56 → 0.57) = MATURATION-arc-shaped chapter cohort sealed,
  may include schema bumps and contract changes。
- **Patch bump** (0.56.0 → 0.56.1) = cleanup / test fixture / doc fixes only,
  no behavior change。
- **1.0.0** would mean:semver-stable public API surface + migration tools
  for every schema bump + reference host that exercises L1-L14 in production。
  None of those gates are met yet。 No timeline。

See VERSIONING.md for the full stability policy + STABILITY.md for which
APIs are pinned vs evolving。
