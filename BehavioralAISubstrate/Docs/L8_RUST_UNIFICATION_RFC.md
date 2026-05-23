# L8 Rust Unification RFC — Chapter 八百九十三 / M3155

## Status

- **Proposed**: chapter 八百九十三 (this RFC)
- **Trigger**: user directive 「把 L8 统一成: SQL event log / atom
  lifecycle / tombstone 作为 source of truth,Rust retrieval /
  reducer / ranker / provenance / batch scoring 做热路径,Swift
  actor 只做 orchestration 和 Apple 平台边界」
- **Was previously DECLINED** in chapter 八百八十四 (Gap 1 audit)
  with 3 triggers documented;user directive is the consumer-
  pressure trigger that lifts the decline。
- **Implementation**: chapters 八百九十四+ (multi-arc)

## Goal

Three-layer architecture:

```
┌──────────────────────────────────────────────────────────┐
│  Swift Actor (BAS*Store actors)                          │
│  - Orchestration: coordinate calls across stores          │
│  - Apple boundary: CryptoKit, NLEmbedding, Foundation     │
│  - NO direct SQL queries                                  │
│  - NO compute hot paths                                   │
└──────────────────────────────────────────────────────────┘
                            ↓ FFI
┌──────────────────────────────────────────────────────────┐
│  bas-l8-engine (NEW Rust crate)                           │
│  - Owns rusqlite handle + schema migrations               │
│  - Hot paths: retrieval / reducer / ranker / provenance   │
│    / batch scoring                                         │
│  - Depends on existing bas-* crates for compute primitives│
│  - Force-linked into bas-memory-usage-tracker umbrella    │
└──────────────────────────────────────────────────────────┘
                            ↓ rusqlite (bundled)
┌──────────────────────────────────────────────────────────┐
│  SQLite (source of truth)                                 │
│  - Sources/BASMemory/SQL/*.sql schemas                    │
│  - Same on-disk format as today (zero migration needed)   │
│  - WAL mode preserved                                     │
└──────────────────────────────────────────────────────────┘
```

## Current state (grounded by 2 discovery agents)

### SQLite-backed Swift actors (17 total)

**L8 core** (9 actors):
| # | Actor | LOC | Pub funcs | Risk |
|---|---|---|---|---|
| 1 | BASSQLiteMemoryAtomStore | 628 | 6 | MED |
| 2 | BASSQLiteAtomLifecycleStore | 450 | 5 | MED |
| 3 | BASSQLiteHostConstitutionDeletionManifestStore | 392 | 5 | **LOW** ← pilot |
| 4 | BASSQLiteUserStateStorage | 500 | 4 | MED |
| 5 | BASSQLiteHostConstitutionVersionTreeStore | 438 | 6 | MED |
| 6 | BASSQLiteVectorIndexStorage | 632 | 5 | MED |
| 7 | BASHostConstitutionSQLiteStorage | 621 | 5 | HIGH |
| 8 | **BASMemoryUsageTracker** | **2,714** | **32** | **HIGH** |
| 9 | BASSQLiteEventLogStorage | 974 | 4 | HIGH |

**Adjacent durable stores** (8 actors,not migration target for v1):
BASSQLiteKnowledgeGraphStorage,BASSQLiteEvalRunStorage,
BASSQLiteContradictionLedgerStore,BASSQLiteUnknownLedgerStore,
BASSQLitePresenceObservationStore,BASSovereignLedgerSQLiteStorage,
BASRiskObservationsSQLiteStorage,BASUpdateTicketLifecycleSQLiteStorage

### SQL schemas (Sources/BASMemory/SQL/)

001-005:memory usage / replay / episode / bundle / tombstone (BASMemoryUsageTracker)
014:host constitution version tree
015:host constitution deletion manifest (← pilot schema)
020-022:shadow trial / evolution seals / retraction orders
023:atom lifecycle events

### Existing Rust crates (7, all PURE-compute today)

All 7 link ZERO of {rusqlite,libsql,sqlx,sqlite} — Swift owns ALL
SQLite via system `import SQLite3`。 Single XCFramework binary
ships all 7 force-linked through `bas-memory-usage-tracker` umbrella。

### Hot-path inventory

| Operation | Frequency | Currently |
|---|---|---|
| Retrieval (vector top-k) | per-turn × per-query | Swift BASVectorIndex + SQLite preload |
| Retrieval usage logging | per-turn × per-atom | Swift BASMemoryUsageTracker (schema 001) |
| Event-log append | per-event (many/turn) | Swift BASSQLiteEventLogStorage |
| Reducer (event → state) | per-event | Swift BASMemoryAtomReducer (pure) |
| Atom-lifecycle transition | per-atom-event | Swift BASSQLiteAtomLifecycleStore (schema 023) |
| Provenance / sovereign gates | per-decision | Swift sovereign-tier actors |
| Ranker (atom scoring) | per-turn | Swift BASMemoryImportanceScorer (pure) |
| Batch scoring / audit replay | per-session | Swift BASAuditReplayEngine |

## Target architecture

### New crate: `bas-l8-engine`

- **Cargo.toml deps**: rusqlite (bundled feature) + bas-atom-lifecycle
  + bas-memory-atom-store + bas-retrieval-ranker + bas-substrate-core
  + bas-event-log-codec
- **Public surface** (prefix `bas_l8_*`):
  - `bas_l8_engine_init(db_path_utf8, db_path_len) -> *mut L8Engine`
  - `bas_l8_engine_close(*mut L8Engine) -> i32`
  - `bas_l8_atom_insert/update/tombstone/query(...)`
  - `bas_l8_atom_lifecycle_append(...)` (schema 023)
  - `bas_l8_deletion_manifest_append(...)` (schema 015,pilot)
  - `bas_l8_retrieval_topk(query_vec, k, ...)`
  - `bas_l8_forget_cascade_apply(...)`
  - `bas_l8_provenance_seal(...)`
  - `bas_l8_event_log_append(...)`
  - `bas_l8_abi_version() -> i32`
- **Schema migrations**: same SQL files Swift currently uses,read
  + applied by Rust at engine_init。 No on-disk format change。
- **WAL mode**: PRAGMA preserved
- **Force-linked**: `bas-memory-usage-tracker/Cargo.toml` adds
  bas-l8-engine to deps + `force_link.rs` adds anchor。

### Rusqlite choice

rusqlite + `bundled` feature:
- Sync API matches Swift actor sync semantics (no async needed)
- Self-contained build (no system SQLite version pinning)
- ~500 KB binary growth (single hit,umbrella shipping)
- Mature + production-proven in Rust ecosystem

REJECTED libsql (distributed-ready features unneeded on-device)。
REJECTED sqlx (async runtime would force tokio,big size growth)。

### Swift actor refactor pattern

For each migrated actor,Swift becomes a thin wrapper:

```swift
public actor BAS<X>Store {
    private let engine: OpaquePointer  // *mut L8Engine
    private let urlPath: String

    public init(databaseURL: URL) throws {
        // Apple boundary: URL → C string
        let path = databaseURL.path
        // Rust owns the SQLite handle from here on
        self.engine = path.withCString { cPath in
            bas_l8_engine_init(cPath, path.utf8.count)
        }
        if engine == nil {
            throw BASL8Error.openFailed
        }
        self.urlPath = path
    }

    deinit {
        bas_l8_engine_close(engine)
    }

    // Public methods become thin FFI passthroughs
    public func append(...) {
        // Apple boundary: Swift types → C buffers
        // Rust hot path
        bas_l8_X_append(engine, ...)
        // Apple boundary: C result → Swift types
    }
}
```

Swift body preserved per 红线 7 as `BASInMemory<X>Store` for
opt-out + cross-platform fallback (watchOS / Linux per chapter
888 pattern)。

## Migration sequence (proposed)

Per chapter 870 cycle-break discipline:smallest highest-confidence
first,then expand。

| # | Chapter | Migration | Risk | Why this order |
|---|---|---|---|---|
| 1 | 八百九十三 (this) | RFC | LOW | Plan |
| 2 | 八百九十四 | NEW `bas-l8-engine` crate skeleton + rusqlite link + ABI version + force_link | LOW | Foundation,no migration yet |
| 3 | 八百九十五 | BASSQLiteHostConstitutionDeletionManifestStore migration (LOW-risk pilot) | LOW | 392 LOC,5 pub funcs,append-only,isolated schema 015 |
| 4 | 八百九十六 | BASSQLiteAtomLifecycleStore migration | MED | 450 LOC,paired with bas-atom-lifecycle Rust crate |
| 5 | 八百九十七 | BASSQLiteMemoryAtomStore migration | MED | 628 LOC,implements BASMemoryAtomStore protocol |
| 6 | 八百九十八 | BASSQLiteUserStateStorage migration | MED | 500 LOC,reducer-feeding |
| 7 | 八百九十九 | BASSQLiteHostConstitutionVersionTreeStore migration | MED | 438 LOC,audit-replay consumer |
| 8 | 九百 | BASSQLiteVectorIndexStorage migration | MED | 632 LOC,per-turn retrieval hot path |
| 9 | 九百一 | BASSQLiteEventLogStorage migration | HIGH | 974 LOC,turn-loop append |
| 10 | 九百二 | BASMemoryUsageTracker migration (biggest) | HIGH | 2,714 LOC,multi-schema,32 funcs |
| 11 | 九百三 | BASHostConstitutionSQLiteStorage migration | HIGH | 621 LOC,sovereign gates + boot |
| 12 | 九百四 | Hot-path consolidation: retrieval + reducer + ranker through l8-engine | MED | Wire chapter 882/886 RAG carrier through new engine |
| 13 | 九百五 | Batch scoring + provenance hot paths through l8-engine | MED | Audit replay + sovereign gates |
| 14 | 九百六 | Swift actor thinning: each migrated actor reduced to ≤ 100 LOC | LOW | Post-migration cleanup |
| 15 | 九百七 | Apple boundary cleanup: CryptoKit / NLEmbedding isolated | LOW | Final polish |
| 16 | 九百八 | Multi-pass review + arc seal | LOW | Catch shoemaker's children |

## Discipline pins (per chapter)

- **Measurement first** (ch 870 cycle-break): each migrated store
  gets a Swift baseline bench BEFORE the Rust path is shipped。 If
  Rust loses,DECLINE (don't flip)。
- **Byte-equality** (ch 887/888 pattern): each migration test
  asserts Rust + Swift produce IDENTICAL results for the same
  inputs。
- **红线 7 Swift fallback**: Swift body preserved (renamed to
  `lintViaSwiftFallback` style or kept as `BASInMemory<X>Store`)
  for watchOS / Linux + opt-out。
- **ADR-014 OPT-IN inverted**: chapter 七百七十七 precedent — default
  flips ON only when Rust path measured ≥ 1.0× of Swift。
- **Single XCFramework rebuild** per chapter (additive only)。
- **N-pass review** per chapter (1 pass minimum for arc-pace push;
  3-pass at risk-HIGH chapters 九百一-九百三)。

## Risk + revert per chapter

| Phase | Revert mechanism |
|---|---|
| 894 crate skeleton | `cargo remove bas-l8-engine` + drop from umbrella |
| 895-九百 (LOW/MED migrations) | Each migration is opt-in via
  Swift constructor switch — revert = pass `useRustEngine: false` |
| 九百一-九百三 (HIGH migrations) | Same opt-in pattern + cross-
  flow tests pinned |
| 九百四-九百五 (hot-path) | Routing flip can revert via
  `BASAutoRouteThresholds` field |
| 九百六-九百七 (cleanup) | Pure cleanup,no behavior change |

## Open questions for next chapter

1. Should `bas-l8-engine` use a global `*mut L8Engine` per process
   OR allow multiple engines (e.g。 for tests + production)?
   - **Recommendation**: multiple engines (test isolation matters)
2. Should rusqlite transactions be exposed to Swift OR wrapped
   internally per operation?
   - **Recommendation**: wrapped internally,Swift never sees
     transaction handles
3. Should `bas_l8_*` return errors via i32 status codes OR a
   richer typed error?
   - **Recommendation**: i32 status codes (mirrors existing
     `bas_rust_tracker_*` idiom)
4. SQL migrations:Rust reads from existing `Sources/BASMemory/
   SQL/*.sql` files at engine_init OR ships embedded `include_str!
   ("../sql/001_*.sql")`?
   - **Recommendation**: include_str! (embed) — no IO at init,
     reproducible builds

## Verification gate per chapter

```bash
cd Cargo && cargo test -p bas-l8-engine    # Rust unit tests
cd .. && swift build                         # Swift package builds
swift test --filter <NewMigrationTests>     # New tests pass
swift test 2>&1 | grep "Executed [0-9]"     # Full sweep no regression
bash scripts/pre-commit-gates.sh            # 3 gates PASS
```

## Cross-references

- chapter 870:cycle-break discipline (measure first)
- chapter 七百七十七:Product Rust flip precedent
- chapter 八百七十二:VectorIndex rayon flip precedent
- chapter 八百八十四:Gap 1 DECLINE that THIS RFC lifts
- chapter 八百九十:string-FFI cost structural pattern (must
  watch for in each migration — if string-FFI cost > Swift
  total at production size,that store DECLINES per chapter
  881/890 doctrine)
- chapter 八百九十一 / Docs/DECLINE_PATTERNS.md:DECLINE-WITH-
  TRIGGER vs DECLINE-PENDING-CONSUMER discipline
- chapter 八百九十一.5:18th-pass review + shoemaker's children
  pattern doctrine

## Out of scope (deferred to v0.64+)

- 8 adjacent durable actors (sovereign + risk + ticket lifecycle)
  — same pattern,bigger blast radius
- Multi-process / distributed SQLite (libsql) — wait for measured
  need
- Provenance lineage ledger (chapter 884 Gap 4 DECLINE) —
  separate arc when audit/compliance pressure surfaces
- Sharded multi-writer (chapter 884 Gap 5 DECLINE) — same
- Removing Swift fallback entirely — keep per 红线 7 indefinitely
