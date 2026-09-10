# ADR-037 — Global durable cosineTopK recall on-device (opt-in, NON-byte-equal)

## Status

Shipped + **verified on a real device**. Library (`BASGlobalRecallSeam` + the in-memory engine init +
the retrieve global branch) is byte-equal-off by default + macOS-verified. Device-host adoption is
**opt-in** (`BAS_GLOBAL_RECALL=1`, default off) and was confirmed by a real-device 2-launch run
(iPhone Air): launch #1 fresh → `ACTIVE corpus=0`, 2 iters → `synced` corpus 0→1→2; launch #2 same
container → `ACTIVE corpus=2` (engine REBUILT from the durable store = cross-restart global recall, no
re-embed) + `ch1063 reload-at-start store_atoms=2 vector_index_entries=2` (durability survived); launch
#3 gate-unset → `global recall OFF` (default-off confirmed). Supersedes ADR-036's "DeviceTestApp
adoption (deferred)" — including its misdiagnosed blocker.

## Context

ADR-036 shipped an opt-in cosineTopK retrieve takeover but wired it only on the host path; the device
left the seam nil. Two reasons were given for deferring on-device adoption: (1) the device's durable
index `BASSQLiteVectorIndexStorage` has no cosineTopK engine, and (2) "the sim build links fail
environmentally, so it can't be runtime-verified" (so swapping a load-bearing durable backend was
declined per R1 / 亏的不要上).

Investigation found **(2) was a misdiagnosis**. The Rust L8 engine already links + runs on a physical
device: ch1027 `BASRustVerifyProbe` reports `all_ok=true` in the shipping app; the `ios-arm64` device
slice of `BASRustMemoryTracker.xcframework` exports the cosineTopK FFI symbols as defined text; the App
target statically links the engine via `BASMemory → BASRustMemoryTrackerBinary`; and the xcframework
ships all three slices (ios-arm64, ios-arm64-simulator, macos-arm64). The "sim fails" phrase conflated
the headless swift-testing SIGBUS (a host test-runner issue) and the MPSGraph simulator device-init
NSException (unrelated to Rust). There was never a device link failure.

The operator chose the **compelling** scope: use cosineTopK for GLOBAL semantic recall over the FULL
durable corpus. Precise framing (a later audit corrected an over-claim): `refresh()` already loads the
full durable corpus into the snapshot UNCAPPED, so the score-all baseline DOES see every atom right
after a refresh; `selfPopulateCap` (64) only trims the snapshot **mid-run** as self-populated frames are
appended (`removeFirst`). So the genuine wins are (a) **ranking semantics + perf** — one Rust cosineTopK
FFI call over the whole corpus vs. N Swift cosine calls — and (b) **steady-state reach**: on turns after
the snapshot has trimmed toward ~64, global recall still ranks the entire corpus while the baseline sees
only the recent window. (The macOS needle test proves the beyond-window reach; the on-device run had a
tiny corpus (2–4 ≪ 64), so the at-scale beyond-window + cap behavior is proven by tests, not exercised
on device.)

## What landed

- **In-memory engine** (`BASRoutedVectorIndexStorage.init(inMemory:)`): a SEPARATE Rust L8 engine over
  `:memory:` (passes `(nil, 0)` to `bas_l8_engine_init` ⇒ `open_in_memory`). It must NOT share the
  durable WAL file with `BASSQLiteVectorIndexStorage`: the engine uses `rusqlite` **bundled** SQLite
  while the durable store uses **system** SQLite3 — two distinct sqlite libraries coordinating one
  `-shm` wal-index is undefined behavior / corruption. The in-memory engine is a derived, rebuildable
  replica; the durable store is never touched.
- **Library seam** (`BASGlobalRecallSeam` = `cosineTopK` + `atomForID`) on `BASL8RoutedMemoryService`
  and `BASRoutedMemoryPersistence`, threaded through `makeWithDefaults(memoryPersistence:)`.
  `retrieve()` gains a three-way branch: GLOBAL (rank the full corpus via the engine, resolve winning
  atom_ids BEYOND the snapshot window via `atomForID`) → the existing windowed `cosineTopKSync`
  (ADR-036) → the score-all baseline. The shared floor + constitution + `score DESC, atomID ASC` +
  `prefix(topK)` + bundle-assembly tail is UNCHANGED, so the returned bundle is byte-deterministic
  within its membership. `memoryAtom(from:)` was promoted to `public` so the host builds its resolver
  with the exact atom shape (no drift).
- **Host adoption** (DeviceTestApp `BASEnduranceAppRunner`, `BAS_GLOBAL_RECALL=1`): builds the
  in-memory engine + a bounded `BASGlobalRecallResolver` (NSLock-guarded, insertion-order FIFO,
  `BAS_GLOBAL_RECALL_CAP` default 4096) from the durable store at startup WITHOUT re-embedding (reuses
  persisted vectors — preserves ch1064), wires the seam, and folds NEW durable atoms in after each
  `drainMemoryIntents()` (incremental sync). The engine stores every atom under one recall domain
  (`Parameters.atomSource`); the resolver returns each atom's REAL domain so the constitution filter is
  unaffected.

## Why this is NON-byte-equal (honest — the accepted semantic change)

Same class as ADR-036, now over the full corpus: the engine truncates to top-K ordered by
`(score DESC, rowid)` BEFORE the Swift floor/constitution filter, so (1) tie membership at the K-th
boundary can keep the lower rowid where the score-all path keeps the lower content-derived atomID, and
(2) an atom the score-all path would reach deeper for may fall outside the engine's pre-filter top-K.
Additionally, the recall POOL changes from the ≤64 window to the full durable corpus (the intended
behavior). All gated behind the opt-in seam — the library default (`makeWithDefaults`, nil seam) keeps
the byte-deterministic windowed/score-all path, so ADR-014 / 红线 7 hold for every host that doesn't
elect it.

## Domain-pin

The engine loads every durable atom under one recall domain (`Parameters.atomSource`) and `cosineTopK`
queries that domain — so ALL durable atoms are globally recall-eligible under one ranking pool, even
atoms whose original `sourceType` differs. The constitution filter still uses each atom's REAL domain
(returned by the resolver), so domain restriction is unaffected — only the cosine ranking pool is
unified. A per-domain engine load + multi-domain query is a documented follow-up.

## Concurrency contract

The seam's `cosineTopK` (engine) + `atomForID` (resolver) are SYNCHRONOUS reads bypassing actor
serialization — called inside the ch883 sync `retrieve()` WITHIN a turn. The engine `upsert` + resolver
`put` (startup build + incremental sync) run BETWEEN turns. The runner awaits `process()` (which runs
retrieve) fully before `drainMemoryIntents()` + the sync, so the sync read never overlaps a write
(turn-phase separation). Latent footgun if turns are ever parallelized — keep drain+sync fully awaited
before the next `process()`.

## Durability preserved by construction

The durable `BASSQLiteMemoryAtomStore` (atoms) and `BASSQLiteVectorIndexStorage` (embeddings) write
paths are BYTE-UNCHANGED. The in-memory engine is rebuilt from them at startup and is never the durable
writer, so ch1063 (content) / ch1064 (embeddings) cross-restart durability is unaffected by this
change. The on-device re-verification therefore reduces to "the existing durability markers still hold
AND global recall is live across a restart."

## Verification

- `swift build` + the macOS test suite green: `BASADR037GlobalRecallTests` (in-memory engine
  ranks/resolves/isolates; a needle OUTSIDE the ≤64 window is recalled globally while the legacy
  nil-seam path cannot; determinism; constitution uses the REAL domain; nil seam ⇒ score-all
  unchanged) + `BASCognitiveBrainCascadeDigestTests` byte-equal net (seam nil default).
- On-device (real-device 2-launch via `devicectl`, the ch1063/ch1064 runtime-marker method — the
  durability XCTest suites are gated `!os(iOS)`):
  - Launch #1 (fresh container, `BAS_GLOBAL_RECALL=1`): `ADR-037 global recall ACTIVE corpus=0`;
    `ch1063 … store_atoms=0`; `ADR-037 … global recall synced +N corpus=…` increments; run
    self-populates.
  - Launch #2 (same container): `ch1063 … store_atoms=>0 vector_index_entries=>0` (durable survived —
    the UNCHANGED proof); `ADR-037 … ACTIVE corpus=>0` (engine rebuilt from the durable store, no
    re-embed); global recall live across the restart.
  - Launch #3 (`BAS_GLOBAL_RECALL` unset): `ADR-037 global recall OFF`; run completes (gate truly
    default-off on-device).
  - If any cannot be confirmed on-device → the runner wiring is reverted (seam stays nil); the library
    seam still ships (adoptable, byte-equal-off). 亏的不要上 / R1.

## Honest scope / follow-ups

- **Cap coverage (FIFO, lockstep)**: the `cap` (default 4096) bounds BOTH the resolver map AND the
  engine — the host evicts from both in lockstep (resolver `put` returns evicted ids; the runner
  `engine.remove`s them), so engine-rows == resolver-keys and the engine's vectors (the memory weight)
  are actually bounded. Eviction is insertion-order **FIFO** (recency: the newest `cap` atoms stay).
  Atoms past the cap fall out of global recall (the durable store keeps them — a recall-coverage
  trade-off, not data loss). Cap sizing: 4096 × (atom + ~384-float vector) ≈ tens of MB; env-overridable.
- **Per-turn sync is monotonic**: gated on a "seen" set (`globalRecallSynced`), each atom synced once —
  NOT on resolver presence (which re-finds evicted atoms and would oscillate the capped membership +
  thrash O(corpus)/turn past the cap). The seen-set is O(durable-corpus) of atomID strings (cheap vs.
  the vectors). A `loadAtomsSince(count:)` high-water gate is a deferred O(1)-memory optimization.
- **Multi-domain recall** deferred (single recall-domain pin).
- **`cosineTopKSync` vs `globalRecall` coexistence**: `retrieve()` prefers `globalRecall`; a host that
  wires both leaves `cosineTopKSync` dead. Documented precedence; minor.

## Audit & hardening (全面 audit)

A multi-perspective audit confirmed byte-equal-off holds + the on-device claims are accurate, and found
two HIGH defects on the opt-in path (since fixed — all on the opt-in path; the default is unaffected):
- **HIGH-1** — the engine was unbounded (only the resolver was capped) → memory growth past the cap +
  cosineTopK returning resolver-evicted ids → silent recall loss. Fixed by lockstep engine/resolver
  eviction (above) + a macOS test (`testEngineEvictionKeepsCorpusBoundedAndResolvable`).
- **HIGH-2** — the per-turn sentinel used resolver presence, which both stranded a no-embedding atom
  (never retried) AND oscillated the capped membership past the cap. Fixed by the monotonic seen-set
  gate (above) + upsert-first-then-put ordering (no engine/resolver divergence on a write failure).
- Hardening: a DEBUG turn-phase-separation assertion (the sync read must not overlap a between-turns
  write), a single-sourced cap floor/default, the FIFO comment correction, and logged (no longer
  swallowed) engine-upsert AND evict-remove errors. The runner eviction/sync logic is host code (not
  SPM-testable); it is review-verified, with the engine-side lockstep covered by the macOS test + the
  on-device run.

### Deferred follow-ups (re-audit — accepted, not blocking)
- **`created_at_ms` tie ordering**: `fetchAllAtoms` is `ORDER BY created_at_ms ASC` (millisecond wall
  clock) with no secondary key, so atoms admitted within the same ms have an unspecified order. At the
  `suffix(cap)` boundary this can wobble which atom occupies the last cap slot by ±1ms — self-healing
  (an excluded new atom is left unseen ⇒ retried), never silent recall loss. A `…, atom_id ASC`
  secondary key would make it deterministic, but it touches the load-bearing durable query, so deferred
  per R1 (no recall-correctness need).
- **Per-turn `store.allAtoms()` full re-read** is O(corpus)/turn (the seen-set avoids re-*syncing*, not
  re-*reading*). A `loadAtomsSince(count:)` high-water API would make both the re-read and the seen-set
  O(1); deferred (negligible at endurance cadence).
- **Resolver↔engine glue test**: the engine-side lockstep is macOS-tested; a DeviceTestApp-target unit
  test asserting `BASGlobalRecallResolver.put`'s returned-evicted contract + `resolver.count ==
  engine.totalCount` after a >cap run would lock the host glue against regression (needs the app test
  target).
- **DEBUG tripwire symmetry**: the assertion guards the resolver read (`atomForID`); the engine read
  (`cosineTopK`) is unguarded when it returns `[]`. DEBUG-only; the single-task driver holds the real
  invariant.
