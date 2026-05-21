# INTEGRATION_AUDIT.md — Audit Pipeline Integration Guide

Host adopter guide for the audit pipeline shipped between chapters
七百九十八 → 八百二十九 (v0.61.0 candidate scope)。 Covers
recorders / batch optimization / replay engine / diff / archive
/ aggregation / time-window primitives,end-to-end through
SQLite-backed storage adapters。

---

## TL;DR — 5-line host setup

```swift
import BASMemory
import BASSovereign
import BASOrchestration

// 1. Open SQLite-backed stores (one per audit dimension)
let presenceStore = try BASSQLitePresenceObservationStore(databaseURL: presenceDB)
let unknownStore = try BASSQLiteUnknownLedgerStore(databaseURL: unknownDB)
let contradictionStore = try BASSQLiteContradictionLedgerStore(databaseURL: contradictionDB)
let atomStore = try BASSQLiteAtomLifecycleStore(databaseURL: atomDB)
let versionStore = try BASSQLiteHostConstitutionVersionTreeStore(databaseURL: versionDB)

// 2. Wire the pipeline
let pipeline = BASAuditPipeline(
    presenceStore: presenceStore,
    unknownStore: unknownStore,
    contradictionStore: contradictionStore,
    atomLifecycleStore: atomStore,
    versionTreeStore: versionStore)

// 3. Per-turn:bundle input + call recordTurn
let turn = BASAuditPipeline.PerTurnInput(
    sessionID: "sess-1",
    turnID: "turn-42",
    nowMs: Int64(Date().timeIntervalSince1970 * 1000),
    eventIDPrefix: "ev-t42",
    observations: presenceObservations,    // optional
    unknownSet: dissectionFrame.unknownSet, // optional
    contradictions: contradictions,         // optional
    atomTransition: atomChange,              // optional
    versionRecord: constitutionEdit)         // optional
let result = try await pipeline.recordTurn(input: turn)
```

That's it。 The pipeline persists 0-5 audit dimensions per turn
through SQLite,survives cold restart,and exposes the full audit
trail through `BASAuditReplayEngine` for analysis。

---

## Architecture

```
                  ┌─────────────────────────┐
                  │  BASAuditPipeline       │
   host turn ──→  │  recordTurn(input:)     │  ──→  5 stores
                  │  → 4 routed recorders   │
                  └─────────────────────────┘
                                                    │
                                                    ↓
                  ┌─────────────────────────┐
                  │  BASAuditReplayEngine   │  ←──  5 stores
   host load ──→  │  loadSession            │
                  │  loadAndSummarize       │
                  └────────────┬────────────┘
                               │
                  SessionAuditTrail
                               │
                   ┌───────────┼───────────────┐
                   ↓           ↓               ↓
        ┌──────────────┐  ┌──────────────┐  ┌──────────────┐
        │ AuditTrail   │  │ AuditTrail   │  │ Aggregation  │
        │ Diff         │  │ Archive      │  │ + TimeWindow │
        │              │  │ (~9× compr)  │  │              │
        └──────────────┘  └──────────────┘  └──────────────┘
```

---

## The 5 audit dimensions

| Layer | Schema | Records what | Store | Recorder |
|---|---|---|---|---|
| L6 | 013 presence_observations | Multi-channel salience signals (task/risk/manipulation/environment/bodyRhythm) | `BASPresenceObservationStore` | `BASRoutedPresenceFusionRecording` |
| L7 | 011 unknown_ledger_records | Decomposition's missing-facts/roles/constraints/permissions/ambiguity | `BASUnknownLedgerStore` | `BASRoutedMirrorBladeRecording` (recordUnknownSet) |
| L7 | 012 contradiction_ledger_records | Decomposition's textual/historical/evidential/role contradictions | `BASContradictionLedgerStore` | `BASRoutedMirrorBladeRecording` (recordContradictions) |
| L8 | 023 atom_lifecycle_events | Memory atom phase transitions (created/admitted/linked/archived/tombstoned) | `BASAtomLifecycleStore` | `BASRoutedAtomLifecycleRecording` |
| L5 | 014 host_constitution_version_tree | Constitution version lineage + SHA-256 signature_hash | `BASHostConstitutionVersionTreeStore` | `BASRoutedHostConstitutionRecording` (recordVersion) |

---

## Storage choice — InMemory vs SQLite

Every storage adapter ships as TWO conformers per protocol:

| Conformer | Use when |
|---|---|
| `BASInMemory*Store` | Tests / latency-budget-constrained hosts;ephemeral (lost on process exit);~500 ns/append |
| `BASSQLite*Store` | Production hosts that need durability;WAL journal + sync NORMAL;~16-62 μs/append (single) or ~0.5-16 μs/append (batched) |

**Single vs batched throughput** (200-event batches,Apple Silicon SSD):

| Store | per-call | batched | speedup |
|---|---:|---:|---:|
| L8 atom-lifecycle | 66 μs | 16 μs | 3.8-4.1× |
| L7 unknown | ~20 μs | ~0.5 μs | 38.5× |
| L6 presence | ~30 μs | ~1.6 μs | 18.7× |
| L7 contradiction | — | — | ≥3× (test-pinned floor) |
| L5 version-tree | — | — | ≥3× |
| L5 deletion-manifest | — | — | ≥3× |

Use the batch API when persisting more than ~10 records at once:

```swift
let records: [BASPresenceObservationRecord] = ...
try await presenceStore.appendBatch(records)
```

---

## Replay + diff + archive

### Load a session

```swift
let engine = BASAuditReplayEngine(
    presenceStore: ..., unknownStore: ..., contradictionStore: ...,
    atomLifecycleStore: ..., versionTreeStore: ...)
let trail = await engine.loadSession(sessionID: "sess-1", vaultID: "vault-A")
print("Total records: \(trail.totalRecords)")
print("Distinct turns: \(trail.distinctTurnIDs.count)")
```

### Diff two trails

```swift
let baseline = await engine.loadSession(sessionID: "sess-pre")
let current = await engine.loadSession(sessionID: "sess-post")
let delta = BASAuditTrailDiff.diff(baseline: baseline, current: current)
if delta.trailsHaveIdenticalIDSets {
    print("Same audit trail")
} else {
    for line in BASAuditTrailDiff.summaryLines(delta) {
        print(line)
    }
}
```

### Archive for long-running hosts

```swift
let archive = BASAuditTrailArchive.archive(trail: trail)
// archive.turnCount per-turn summary rows; ~9× compression vs raw trail
let asJSON = try JSONEncoder().encode(archive)  // ArchivedTrail is Codable
```

### Aggregate per-session

```swift
let summary = await engine.loadAndSummarize(sessionID: "sess-1")
// summary.presence       BASRoutedAuditAggregation.PresenceSessionSummary
// summary.unknowns       BASRoutedAuditAggregation.UnknownSessionSummary
// summary.contradictions BASRoutedAuditAggregation.ContradictionSessionSummary
```

### Time-windowed filtering

Half-open `[startMs, endMs)` convention:

```swift
let recentPresence = BASRoutedAuditTimeWindow.presence(
    trail.presence, between: nowMs - 60_000, and: nowMs)
let openContradictions = BASRoutedAuditTimeWindow
    .contradictionsUnresolved(trail.contradictions)
```

---

## Cold-restart semantics

Every SQLite store survives process death:close the actor,reopen
the file,records are intact。 The chapter 八百十九 round-trip
stress test pins this at 50 turns × 8 records = 400 events,
verifying payload-byte-identity (not just ID-set identity)。

```swift
// Process A: writes
let writeStore = try BASSQLiteAtomLifecycleStore(databaseURL: path)
try await writeStore.appendEvent(event)
// Process A exits

// Process B: reads
let readStore = try BASSQLiteAtomLifecycleStore(databaseURL: path)
let events = await readStore.events(forSession: "sess")
// events contains everything Process A wrote
```

---

## Cross-platform notes

- **All InMemory stores** + **all SQLite stores** + **all recorder
  pure entry points** (`recordTransition`, `recordUnknownSet`,
  `recordContradictions`, `recordVersion`, `recordDeletion`):
  work on iOS / macOS / Linux / watchOS。
- **Composite Rust-bridge entry points** (`BASAuditPipeline.recordTurn`
  when `atomTransition` is supplied,`BASRoutedAtomLifecycleRecording
  .transitionAndRecord`,`BASRoutedPresenceFusion.fuseAndRecord`):
  gated to iOS / macOS where the Rust XCFramework is available。
  On other platforms,call the pure recorder entry points after
  computing the transition bytes in Swift。

---

## Error semantics

The pipeline has **NO cross-store atomicity** by design。 If recording
fails after L6 has written but before L7 finishes:
- L6 record persisted
- L7 throws → call site sees the throw
- L8/L5 untouched

This matches the「append-only audit log」 semantic for each
individual store。 Hosts that need cross-store atomicity must
implement their own checkpoint/rollback above this layer (e.g.
via the `BASShadowTrialCoordinator` per-turn checkpoint pattern)。

Per-batch atomicity within ONE store IS guaranteed (SQLite
`BEGIN IMMEDIATE` ... `COMMIT`/`ROLLBACK` per appendBatch call)。

---

## Doctrine pin map

The audit pipeline holds all 9 substrate doctrine pins:

| Pin | How |
|---|---|
| 不要 删除 只能 comment / 不要 的 部分 都 archive | All recorders / stores are NEW files in v0.61.0 candidate;no production code touched |
| ADR-014 OPT-IN | Pipeline is opt-in;host wires stores explicitly,substrate default unchanged |
| 不要 json 可以的话 就 sql | Typed SQL columns for each audit dimension;JSON only for variadic ref arrays (target_refs / cascaded_refs / merged_from) |
| 整体 性能 效果 一定要 更好 | CryptoKit SHA-256 default for L5 signature_hash;batched SQLite writes 3-38× faster than single-call |
| 亏的不要硬上 | SQLite is 60-140× slower than InMemory per-append;both paths stay opt-in,hosts choose per latency budget |
| 多做比较 | 5-axis perf measurement (chapter 七百七十八-七百七十九) + scale re-measure (chapter 七百八十七) + storage comparison (chapter 八百三) all sealed |

---

## Chapter pin map

| Concern | Chapter shipping it |
|---|---|
| 4 recorders | 七百九十八-八百一 |
| Storage batch fast path | 八百四-八百六 |
| Replay engine | 八百十六 |
| Cross-session diff | 八百十七 |
| Archive compression | 八百十八 |
| Per-turn integration test | 八百八 |
| Per-session aggregation | 八百十 |
| Time-window filters | 八百十二 |
| 100-turn stress test | 八百十三 |
| Pipeline composition root | 八百十五 |
| Round-trip restore test | 八百十九 |
| Codable conformance | 八百二十一 |
| Cargo lint cleanup | 八百二十九 |
