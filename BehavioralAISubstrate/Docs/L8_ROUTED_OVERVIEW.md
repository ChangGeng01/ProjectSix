# L8 Routed Storage — Integrator Overview

**Audience**: New consumers integrating the substrate's L8
storage layer。 Picks up where `L8_RUST_UNIFICATION_RFC.md`
(architecture) and `L8_ARC_SEAL.md` (project state) leave off。

## TL;DR

The substrate ships **two parallel L8 storage paths** as of
chapter 九百二十一:

1. **Legacy Swift SQLite actors** (e.g. `BASMemoryUsageTracker`,
   `BASSQLiteEventLogStorage`) — production default,unchanged
   from chapter 二百四十八。 These are the canonical path until
   a future flip lands。
2. **Rust-backed routed bridges** (`BASRouted*Store`,
   `BASRouted*Storage`) — additive,opt-in,measured TIE for
   storage-only ops + 3-134× FFI-hop reduction for hot-path
   consolidation primitives。 Documented as FLIP-READY but no
   production runtime switch exists yet。

**Choose the legacy actor unless you specifically need a
hot-path consolidation primitive** (see「When to use the
routed path」 below)。

## Which routed bridge maps to which legacy actor

| Legacy Swift actor (production default) | Rust-backed bridge | Schema | Status (chapter 九百三十三 / M3370 honesty pass) |
|---|---|---|---|
| `BASSQLiteHostConstitutionDeletionManifestStore` | `BASRoutedHostConstitutionDeletionManifestStore` | 015 | **Full** (ch 935 implemented `manifests(forVault:)` + `manifests(forType:)` via probe+fill JSON FFI — round-trip verified by BASChapter935 tests) |
| `BASSQLiteAtomLifecycleStorage` | `BASRoutedAtomLifecycleStore` | 023 | **Full** (ch 934 implemented `events(forAtom:)` + `events(forSession:)` via NEW probe+fill JSON FFI — round-trip verified by BASChapter934 tests) |
| `BASSQLiteUserStateStorage` | `BASRoutedUserStateStore` | user_states | **Full** (ch 936 implemented `state(forID:)` + `latestState(forSession:)` via probe+fill payload_json FFI — round-trip verified by BASChapter936 tests) |
| `BASSQLiteHostConstitutionVersionTreeStore` | `BASRoutedHostConstitutionVersionTreeStore` | 014 | **Full** (ch 937 implemented `versions(forVault:)` + `rollbackPoints(forVault:)` + `version(forID:)` via probe+fill JSON FFI;signature_hash BLOB → base64 string in JSON — round-trip verified by BASChapter937 tests) |
| `BASSQLiteVectorIndexStorage` | `BASRoutedVectorIndexStorage` | vector_index | Full + hot-path `cosineTopK` |
| `BASSQLiteEventLogStorage` | `BASRoutedEventLogStorage` | event_log v2 | **Full** (ch 938 implemented `events(forSession:)` + `events(sinceTimestampMs:limit:)` via probe+fill JSON FFI;payload_json passthrough with `WHERE payload_format=1` filter — round-trip verified by BASChapter938 tests) |
| `BASMemoryUsageTracker` (6 tables) | 3 sub-stores + 1 unified facade (below) | records / replay+audit / notes+bundles+tombstones | Full via facade |
| `BASHostConstitutionSQLiteStorage` | `BASRoutedHostConstitutionVaultStorage` | host_constitution_vaults | Full |

### Partial-conformance stub list — what's still NOT implemented

These methods exist in the Routed bridge's protocol surface but return empty/nil regardless of stored data。 Full-row queries require Rust FFI extensions per the deferred 「.5」 chapters。 Consumers calling these methods today silently get empty results:

| Bridge | Stubbed method | Returns | Deferred to |
|---|---|---|---|
| ~~DeletionManifest~~ | ~~`manifests(forVault: String) async -> [BASHostConstitutionDeletionRecord]`~~ | **SHIPPED ch 935** | ✓ |
| ~~DeletionManifest~~ | ~~`manifests(forType: String) async -> [...]`~~ | **SHIPPED ch 935** | ✓ |
| ~~AtomLifecycle~~ | ~~`events(forAtom: String) async -> [BASAtomLifecycleEvent]`~~ | **SHIPPED ch 934** | ✓ |
| ~~AtomLifecycle~~ | ~~`events(forSession: String) async -> [...]`~~ | **SHIPPED ch 934** | ✓ |
| ~~UserState~~ | ~~`state(forID: String) async -> BASUserState?`~~ | **SHIPPED ch 936** | ✓ |
| ~~UserState~~ | ~~`latestState(forSession: String) async -> BASUserState?`~~ | **SHIPPED ch 936** | ✓ |
| ~~VersionTree~~ | ~~`versions(forVault: String) async -> [BASHostConstitutionVersionRecord]`~~ | **SHIPPED ch 937** | ✓ |
| ~~VersionTree~~ | ~~`rollbackPoints(forVault: String) async -> [...]`~~ | **SHIPPED ch 937** | ✓ |
| ~~VersionTree~~ | ~~`version(forID: String) async -> BASHostConstitutionVersionRecord?`~~ | **SHIPPED ch 937** | ✓ |
| ~~EventLog~~ | ~~`events(forSession: String) async -> [BASEventLogEntry]`~~ | **SHIPPED ch 938** | ✓ |
| ~~EventLog~~ | ~~`events(sinceTimestampMs: Int64, limit: Int) async -> [...]`~~ | **SHIPPED ch 938** | ✓ |

**ARC SUBSTANCE CLOSURE (ch 938)**:All 11 originally-stubbed methods across 5 bridges are now implemented。 The「Full」 labels in the bridge-mapping table are now HONEST。 USER-PASS finding from ch 933 fully closed。

**Why deferred**:full-row queries require Rust FFI primitives that decode TEXT/BLOB columns + reconstruct typed Swift structs。 Per ADR-014 OPT-IN doctrine,Routed bridges ship append/count first (which the Swift fallback ALSO supports) and add read-paths only when consumer pressure warrants the FFI work。

**Currently** no consumer calls these methods AT the Routed bridge layer — all read-path consumers go through the legacy Swift actor。 The partial-conformance stub satisfies the protocol contract for compile-time substitutability without doing the FFI work prematurely。

**What this means for you**:if you swap a `BASSQLite*` actor for its `BASRouted*` bridge in production,**APPEND/COUNT will work but READ will silently return empty**。 Per ADR-014 OPT-IN,no Routed bridge is production-default for this exact reason。

**chapter 九百三十三 / M3370 fix** (as of ch 933 — subsequently extended through ch 944 with 15 meta passes + USER-PASS + 2 USER-PASS-2 catches):this section + the「Partial」 status labels above were missing from the OVERVIEW table。 12 review passes audited cumulative numbers and discipline meta but did NOT verify the OVERVIEW table's substantive claims against actual source code。 User caught this gap by reading the linked file。 Discipline meta-lesson: doc complexity reviews need to include SUBSTANCE-vs-source-code checks,not just cross-doc consistency。 (ch 944 16P-doc-CRIT-1 found a SECOND substance lie in this same OVERVIEW doc — wal_autocheckpoint=1000 was stale,actual source is 1024。 Same SUBSTANCE-vs-source-code class — fix shipped ch 944。)

## The MemoryUsageTracker family

`BASMemoryUsageTracker` is the largest legacy actor (2,714
LOC,6 tables)。 Per 「细心继续」 discipline the port was
split into 3 sub-stores + 1 unified facade:

| Component | Tables covered | Use when |
|---|---|---|
| **`BASRoutedMemoryUsageTrackerStore`** (facade) | All 6 (records + replay_log + audit_log + notes + bundles + tombstones) | **DEFAULT** — consumer-friendly drop-in replacement |
| `BASRoutedMemoryUsageRecordsStore` (sub-store) | records only | Caller needs caller-supplied recordIDs (facade mints UUIDs) |
| `BASRoutedMemoryUsageLogsStore` (sub-store) | replay_log + audit_log | Direct log access without records overhead |
| `BASRoutedMemoryUsageExtrasStore` (sub-store) | notes + bundles + tombstones | Direct access to「extras」 tables |

**Default recommendation**:use the facade。 The sub-stores
exist for advanced use cases (caller-supplied IDs, sub-table
isolation) and tests。 Each sub-store opens its own L8Engine
handle on the same DB file,which is wasteful for a normal
production app — use the facade。

## When to use the routed path

| Use case | Recommendation |
|---|---|
| New consumer code,no special needs | **Legacy Swift actor** — production default,zero adoption friction |
| Per-turn hot-path query (e.g.「latest 10 events for session」, vector top-k) | **Routed bridge** — chapter 906/909/911/913 hot-path consolidation primitives are flip-ready (see below) |
| Cross-platform L8 (tvOS/watchOS/visionOS) | Currently neither — both gated `#if os(iOS) \|\| os(macOS)` (deferred MED #12) |
| Production-default flip from Swift → Rust storage | NOT TODAY — chapter 905 measurement showed TIE,deferred to consumer-driven trigger |

## Hot-path consolidation primitives (FLIP-READY)

These are Rust-backed primitives that DON'T exist on the
legacy Swift actors。 They collapse N+1 FFI hops into 1,with
measured speedups:

| Bridge | Method | Speedup |
|---|---|---|
| `BASRoutedVectorIndexStorage` | `cosineTopK(forDomain:queryBytes:k:)` | 90-134× (real compute consolidation,apples-to-apples baseline) |
| `BASRoutedVectorIndexStorage` | `cosineTopKWithSkipped(...)` | Same + dim-mismatch counter for provider-upgrade diagnostics |
| `BASRoutedEventLogStorage` | `recentTimestamps(forSession:limit:)` | 17-107× FFI-hop reduction (per ch 916 honesty correction) |
| `BASRoutedMemoryUsageRecordsStore` | `recentRecords(forAtomID:limit:)` | 16-110× FFI-hop reduction |
| `BASRoutedHostConstitutionVaultStorage` | `allVaultMetadata(limit:)` | 3-4× FFI-hop reduction |

These are **the reason the routed path exists**。 If your
consumer doesn't need one of these,the legacy actor is fine。

## Partial-conformance gotchas — HISTORICAL (resolved ch 934-938)

~~Some routed bridges silently return empty arrays for read~~
~~methods that the corresponding Swift actor implements。 If you~~
~~hit one of these,fall back to the legacy actor:~~

~~| Routed bridge | Partial method | Returns |~~
~~|---|---|---|~~
~~| `BASRoutedEventLogStorage` | `events(forSession:)` | `[]` (chapter 901 partial conformance, full impl deferred) |~~
~~| `BASRoutedEventLogStorage` | `events(sinceTimestampMs:limit:)` | `[]` |~~
~~| `BASRoutedHostConstitutionDeletionManifestStore` | `manifests(forVault:)` | `[]` |~~

~~In DEBUG builds (chapter 九百二十一 fix),these now trigger~~
~~`assertionFailure` to surface the partial conformance instead~~
~~of silently returning empty。 In RELEASE they still return~~
~~empty,but the bridge documentation now reflects this。~~

**chapter 九百四十一 / M3410 ANTI-DRIFT CORRECTION (13th-pass review CRITICAL-1)**:
The above table was STILL LIVE after ch 934-938 shipped the full implementations。
This is the same class of doc-vs-source lie that the ch 933 USER-PASS caught:
12 review passes cascaded across cumulative numbers but didn't re-grep this exact
section against current source code。 Section retained as strikethrough for
git-archeology readers — the actual current status is **「Full」** for all 11
methods per the bridge-mapping table at the top of this doc + the
「Partial-conformance stub list」 with all 11 rows marked ✓ SHIPPED。

If you encounter a Routed bridge READ method that returns empty for non-empty
storage,that is a regression — please file a bug + check the BASChapter934-938
round-trip tests are still passing。

## How to opt-in

There is NO production runtime switch (deferred HIGH-#5)。 To
use a routed bridge:
1. Construct it directly:`let store = try BASRoutedVector-
   IndexStorage(databaseURL: url)`
2. Use its hot-path methods directly:`let results = try
   await store.cosineTopK(forDomain: "x", queryBytes: q,
   k: 10)`
3. If you need a method the routed bridge doesn't implement,
   construct the legacy actor instead

A future v0.63+ chapter may ship `BASMemoryStoreFactory.make(
databaseURL:, backend: .swift | .rust) → AnyProtocolType`
for a clean runtime choice。 Until then,construction site
is the choice point。

## Error handling

Each routed bridge has its own `StoreError` enum。 Common
cases (post-chapter 九百十九 CRITICAL fix C1):
- `.engineInitFailed` — L8Engine FFI init returned null
- `.schemaInitFailed(code: Int32)` — schema creation failed
- `.upsertFailed(code: Int32)` — write op failed
- `.readFailed(code: Int32)` — **read op failed** (chapter
  919 added — previously misleading `.upsertFailed`)
- `.invalidArgument(reason: String)` — caller violated a
  precondition (e.g. `k <= 0` or `k > limitCap = 100_000`)

**Catch read failures with `.readFailed`,not `.upsertFailed`**。
Pre-919 code that catches `.upsertFailed` on a read path
would have rolled back a transaction that never happened
(deferred MED #14 cleanup will document this for consumers)。

## Concurrency

- Every routed bridge is a Swift `actor` — calls serialize
  on the actor's executor。
- Internally,each bridge holds an `OpaquePointer` to an
  `L8Engine` (Rust struct wrapping `Mutex<Connection>`)。
  Multiple bridges pointing at the same DB file each have
  their OWN Mutex — see chapter 九百十九 CRITICAL fix C3 for
  the multi-engine race protection (BEGIN IMMEDIATE around
  UPSERT pre-check + INSERT)。
- WAL autocheckpoint is set to **1024 pages** (~4 MB at 4KB
  page size) — sentinel value distinct from SQLite default 1000,
  pinned in ch 920 + corrected to 1024 in ch 927 (per 7P-CRIT-1
  cascade-break:1000 matched the rusqlite/SQLite default which
  made the「explicit pin」 test fake coverage — see ch 931
  rusqlite-default-coincidence discipline)。 Long sessions
  won't accumulate unbounded WAL。 Source-of-truth:
  `Cargo/bas-l8-engine/src/lib.rs:228` (`pragma_update(..., "wal_autocheckpoint", 1024)`) +
  `lib.rs:1539` assertion `wal_autocheckpoint must be 1024 on engine`。

## Where the database lives

The consumer chooses。 Each routed bridge's init takes
`databaseURL: URL`。 For iOS production:
- Recommended location: `FileManager.default.urls(for:
  .applicationSupportDirectory, in: .userDomainMask).first`
- Set `NSURLIsExcludedFromBackupKey` if the DB shouldn't
  iCloud-backup
- Remember to exclude the `-wal` and `-shm` sidecars too

**Production DB location guidance is deferred to a future
infrastructure doc** — not part of the L8 arc。

## Further reading

- `L8_RUST_UNIFICATION_RFC.md` — original chapter 893 RFC
- `L8_ARC_SEAL.md` — final arc state + deferred items registry
- `L8_STORAGE_FLIP_DECLINE_WITH_TRIGGER.md` — why storage-only
  flip stays declined + 4-store trigger fired record
- `DECLINE_PATTERNS.md` — pattern catalog incl. STORAGE_TIE_
  FFI_OVERHEAD
