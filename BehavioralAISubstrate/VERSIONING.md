# Versioning + Stability Policy

The substrate is **pre-1.0**。 README says「fast-evolving contract」 — this
doc says what that actually means in concrete terms。

---

## Versioning scheme — adapted semver

Format:**`MAJOR.MINOR.PATCH`** as git tags + a string constant in
`BehavioralAISubstrate/Package.swift` comment header (not a SPM-native field
since the substrate isn't published to a registry)。

| Bump | When | Migration burden | Examples |
|------|------|------------------|----------|
| **Patch** (0.56.0 → 0.56.1) | Test fixture refresh,doc fixes,non-behavioral cleanup,bug fix that doesn't change wire format or public API | Zero — `swift package update` + rebuild | chapter 七百五十七 fixture refresh |
| **Minor** (0.56 → 0.57) | MATURATION-arc-shaped chapter cohort sealed,may include schema bumps + opt-in production flips + new optional API,but no breaking public API change | Read CHANGELOG + MIGRATING.md;may need to absorb 10-30s of host-side recalibration on cold start after schema bump | 七百五十一-七百五十六 MATURATION ARC |
| **Major** (0.x → 1.0 → 2.0) | Breaking public API change OR mandatory wire-format migration with no lazy-upgrade path OR substrate-wide doctrine reshuffle | Read MIGRATING.md;may need code changes in host adopters | No major bumps yet。 1.0 not scheduled。 |

**Pre-1.0 convention:** breaking changes between minor versions are allowed
but documented。 Substrate doesn't pretend semver-stable until 1.0。

---

## Public API stability tiers

Not all symbols are equally stable。 The substrate has three tiers:

### Tier 1 — Pinned (byte-equality / wire-format)

Symbols + behaviors that have **byte-equality tests** enforcing they don't
drift。 Breaking these would be caught by the test suite。 Reviewers + SDK
consumers can rely on these across minor bumps without verifying:

- `BASSovereignAuditLedger.appendStep()` canonical-bytes encoding (chapter
  七百十六 50-entry byte-equality test pins this across the routed-seal
  flip)
- All Rust C-ABI functions in `Cargo/*/src/*.rs` declared `#[no_mangle]
  extern "C"` — ABI version reachable via `bas_*_abi_version()`
- SQL schema files in `Sources/*/SQL/*.sql` — the `payload_format`
  dual-read column (chapter 七百三十二) is the migration mechanism for
  schema bumps
- `BASBrainHistoryAtomID.derive(forInput:)` — SHA256-prefix hex derivation;
  cross-store atomID matches by construction (chapter 七百五十七 第四刀
  hardened with `retrievedAt:` threading)
- Calibrator wire format — `BASAutoRouteCalibrationStore.currentSchemaVersion`
  is the migration anchor

### Tier 2 — Stable-shape (sole-import surface)

Symbols + types that hosts can import via BASHostKit。 May get new optional
parameters with default values (backward-compatible),may get new methods,
but existing signatures + Codable wire formats are stable within a minor
version:

- `BASHostConfiguration` + all `Bundle` configuration types
- `BASHostRuntime` + `BASHostSessionRequest` + `BASHostSessionResult`
- `BASCognitiveBrain` public methods (recordSummary,markHelped,etc.)
- `BASCognitiveBrainSummary` Codable wire format
- `BASMemoryUsageRecord` Codable wire format

**Recent example:** chapter 七百五十七 第四刀 added `retrievedAt: Date = Date()`
to `recordSummary(_:)`。 6 existing call sites compiled unchanged via the
default value。 Backward-compatible by construction。

### Tier 3 — Evolving (don't rely on)

Symbols + internals that exist for substrate-internal coordination + may
change without warning between minor versions:

- All `BASChapter###*` types — chapter-shaped scaffolding,not consumer API
- All `BASDoctrine*` types — internal pin records
- `BASEntropyChapterIndex` — internal indexing
- `Cargo/*` Rust internal helpers (anything not marked `extern "C"`)
- `BASChapterDoctrineRegistry` static `all` collection — internal source
  of truth,not a stable enumeration

**If you find yourself importing a tier-3 symbol,raise the contract to
tier-2 in BASHostKit first,then consume via BASHostKit。**

---

## Migration policy

When a release bumps a schema or wire format,the substrate's responsibility:

1. **Lazy-upgrade default** — old wire formats remain readable;new writes
   use the new format。 Example:event log v1 (JSON) rows stay readable
   after v2 (binary) ships;new appends use binary。
2. **Migration anchor** — every schema has an explicit `schemaVersion`
   constant declared in the storage type。 Bumping it triggers an
   explicit migration review。
3. **No silent data loss** — if a host's saved cache becomes invalid
   (e.g。 calibration v1 cache after schemaVersion 2 bumps),the host
   sees the cache file get rejected on load + the substrate re-runs the
   calibration on next call (10-30s on cold start)。

When a release bumps a public API,the substrate's responsibility:

1. **Source compatibility via default-parameter additions** — new
   parameters get defaults that preserve V1 behavior。 Existing call
   sites compile unchanged。
2. **Deprecation cycle for removals** — pre-1.0 the substrate may
   collapse the deprecation window to「next minor」 if usage is internal-only;
   external usage (if any external adopter is known) gets a full minor of
   `@available(*, deprecated)` first。
3. **Document the migration** in CHANGELOG.md「Changed」 + this file's
   migration table。

---

## Migration table (concrete past + future bumps)

| Version | Bump | Action required | Lazy upgrade? |
|---------|------|-----------------|---------------|
| 0.30 (chapter 七百三十 第三刀) | Calibrator schemaVersion 1 → 2 | None — substrate auto-rejects stale cache + recalibrates on next call (10-30s) | YES (auto) |
| 0.32 (chapter 七百三十二 第一刀) | Event log SQLite schemaVersion 1 → 2 | None — substrate dual-reads JSON (v1) + binary (v2);new appends use binary | YES (auto) |
| 0.51 (chapter 七百五十一 第一刀) | L14 routedSeal default OFF → ON | None — byte-equality pinned (chapter 七百十六);output identical | N/A (behavior-pinned) |
| 0.53 (chapter 七百五十三 第一刀) | L14 verdict engine default OFF → ON | None — cross-check belt-and-suspenders preserves security floor | N/A |
| 0.54 (chapter 七百五十四 第一刀) | L11 SQL persistence wire | None for in-memory hosts;hosts wanting SQL persistence call `BASRiskObservationLedger.sharedStorage = ...` opt-in | N/A (opt-in) |

---

## What 1.0 would require

The substrate doesn't claim to be 1.0-ready。 Concrete gates that would have
to be met before tagging 1.0:

1. **Reference host** that exercises L1-L14 in a non-test production-shaped
   integration。 SampleHost is too shallow today (façade smoke only)。
2. **Migration tools** for every schema bump — not just lazy-upgrade,but
   an explicit `swift run BASBrainCLI migrate` command that hosts can run
   ahead-of-time。
3. **API stability declaration** — every public symbol in BASHostKit tagged
   `@available(...)`with intended stability。 No more『fast-evolving contract』
   blanket disclaimer。
4. **Versioned CHANGELOG** going back at least 12 minor releases。
5. **External-adopter validation** — at least one external host (not in
   this monorepo) adopts BASHostKit + ships。

None of these are scheduled。 Substrate stays pre-1.0 indefinitely until
the user signals that the SDK is ready for external adoption。
