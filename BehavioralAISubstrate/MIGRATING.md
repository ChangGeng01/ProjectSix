# Migration Guide

Concrete migration steps for each schema / wire-format / API bump in the
substrate's history。 If you're upgrading across multiple minor versions,
read each section in order from your current version forward。

The substrate's migration philosophy:**lazy-upgrade by default,
explicit caller-side action only when lazy-upgrade is impossible**。

---

## From 0.55 to 0.56 — MATURATION ARC + Before severance

### No host-side code change required

The maturation arc landed 3 new production-default Rust flips,but each
preserved byte-equality with the prior Swift path:

| Flip | Verification | Host-side action |
|------|-------------|------------------|
| L14 chain seal routed | 50-entry byte-equality (chapter 七百十六) | None |
| L14 verdict engine routed | Stage 2+3 routed,cross-check `max(hits.minLevel, routedLevel)` preserves security floor | None |
| L11 SQL persistence wire | Opt-in via `BASRiskObservationLedger.sharedStorage = ...`;default nil = ADR-014 compat | Opt-in only if you want SQL persistence |

### What's the L11 opt-in look like

If you want risk observations to persist across cold restarts:

```swift
import BASPolicy

// At app startup,after acquiring a SQLite handle:
let storage = try BASRiskObservationsSQLiteStorage(databaseURL: storageURL)
BASRiskObservationLedger.sharedStorage = storage
```

If you don't set `sharedStorage`,L11 stays in-memory (backward compat
with all pre-chapter-七百五十四 hosts)。

---

## Calibrator cache (schemaVersion 1 → 2,landed at chapter 七百三十 第三刀)

### What changed

`BASAutoRouteCalibrator` writes a calibration report to disk
(`BASAutoRouteCalibrationStore.cacheURL`)。 The schemaVersion bumped to 2
because new auto-router families landed (BPE,int8,PQ) whose thresholds
aren't representable in v1 caches。

### What happens to an existing v1 cache file

1. Host upgrades substrate from 0.29 → 0.30+
2. Next call to `loadOrCalibrate(...)` reads the v1 cache file
3. `validate()` rejects it with「cache=1 expected=2」 message
4. Substrate falls through to `calibrateFn()` → fresh calibration runs (10-30s on cold start)
5. New v2 cache written to the same URL
6. Subsequent calls hit the v2 cache

**Host-side action: none。** This is purely automatic。 The user-visible
cost is a one-time 10-30s delay on the first app-launch after upgrade。

### How to skip the recalibration entirely

If you want to avoid the cold-start cost (e.g。 you trust your old thresholds
or you want to control timing):

```swift
import BASRuntimeCore

// Read the old v1 report manually + migrate the fields you care about:
let oldReport = try BASAutoRouteCalibrationStore.load(from: cacheURL)
let migratedReport = BASAutoRouteCalibrationReport(
    schemaVersion: 2,                        // bump
    measuredAtEpochSec: oldReport.measuredAtEpochSec,
    substrateVersion: oldReport.substrateVersion,
    deviceFingerprint: oldReport.deviceFingerprint,
    measurements: oldReport.measurements,    // legacy measurements still useful
    thresholds: oldReport.thresholds)        // legacy thresholds still applicable
try BASAutoRouteCalibrationStore.write(migratedReport, to: cacheURL)
```

But the default auto-recalibrate is usually fine。 Only do this if you
have a specific reason。

---

## Event log SQLite schema (schemaVersion 1 → 2,landed at chapter 七百三十二 第一刀)

### What changed

The `replay_log_events` table got a new column:
`payload_format INTEGER NOT NULL DEFAULT 1`。 Values:
- `1` = JSON payload (v1,legacy)
- `2` = binary payload (v2,new appends)

### What happens to existing event_log databases

1. Host upgrades substrate from 0.31 → 0.32+
2. Substrate opens existing SQLite database
3. `BASSQLiteEventLogStorage` detects schema version 1 (or missing
   `payload_format` column) and runs:
   ```sql
   ALTER TABLE replay_log_events ADD COLUMN payload_format INTEGER NOT NULL DEFAULT 1;
   ```
4. Existing rows now have `payload_format = 1` (JSON)
5. New appends use `payload_format = 2` (binary,30-50% smaller)
6. Reads use `payload_format` to choose decoder (dual-read)

**Host-side action: none。** Lazy upgrade is automatic on first open。 You
get a one-time DDL execution at app launch after upgrade。

### How to force a full migration (optional)

If you want to rewrite all v1 rows to v2 binary (saves storage):

```swift
import BASRuntimeCore

let storage = BASSQLiteEventLogStorage(databaseURL: dbURL)
try await storage.rewriteAllRowsToBinaryFormat()
// Reads + writes all rows in a single transaction;v1 → v2
```

This is opt-in and slow (10-100ms per 1000 rows)。 The lazy-upgrade default
is usually fine — v1 rows stay readable forever。

---

## API change:`recordSummary` adds `retrievedAt:` parameter (chapter 七百五十七 第四刀)

### What changed

```swift
// Before:
public func recordSummary(
    _ summary: BASCognitiveBrainSummary
) async throws -> String

// After:
public func recordSummary(
    _ summary: BASCognitiveBrainSummary,
    retrievedAt: Date = Date()      // NEW,default makes V1 callers source-compatible
) async throws -> String
```

### What happens to existing callers

**Nothing。** The new parameter has a default value `Date()`,which preserves
V1 behavior — each call still stamps its own timestamp。 Existing call sites
compile + run unchanged。

### Why we added it

`BASCognitiveBrain.recordSummaryObservation` now captures a single `Date()`
at the brain layer + threads it into both `BASSQLBrainHistoryStore` and
`BASRustBrainHistoryStore`,so cross-store `recentRecords(limit:)` ordering
matches by construction。 Without this,clock skew between Swift `Date()`
and Rust `SystemTime` could produce different「most recent」 records from
the two stores even though both held the same SET。

If you wire your own dual-store consumer,you should follow the same
pattern:

```swift
let now = Date()
_ = try await sqlStore.recordSummary(summary, retrievedAt: now)
_ = try await rustStore.recordSummary(summary, retrievedAt: now)
```

If you only use one store (typical),the default `Date()` is fine。

---

## Pre-0.30 — see git history

For migrations before chapter 七百三十 (substrate 0.30),consult:
- `BRANCH_SUMMARY.md` — branch-arc-shaped narrative
- `docs/BEHAVIORAL_AI_SUBSTRATE_CHANGELOG.md` — chapter-shaped detailed log

These are historical-record-shaped,not migration-guide-shaped。 If you
need migration help for pre-0.30,file an issue with your current substrate
version + target version。

---

## General migration discipline

1. **Always read CHANGELOG.md before bumping minor or major versions。**
2. **Always run the full test sweep after upgrading:**
   ```bash
   cd BehavioralAISubstrate && swift test
   ```
   Expected:12,965 tests / 31 skipped / 0 failures (substrate 0.56.0)。
3. **If a schema bump rejects your existing cache file,don't manually
   edit it。** Let the substrate's lazy-upgrade path handle it。
4. **If you find yourself writing migration glue code outside this doc,
   the substrate's migration policy is incomplete — please open an issue
   with the missing case。**
