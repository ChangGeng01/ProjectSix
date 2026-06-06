# ADR-037 — Global durable cosineTopK recall on-device (opt-in, NON-byte-equal)

## Status

Library shipped + macOS-verified (`BASGlobalRecallSeam` + the in-memory engine init + the retrieve
global branch, all byte-equal-off by default). Device-host adoption is **opt-in** (`BAS_GLOBAL_RECALL=1`,
default off) and gated on real-device 2-launch verification (see Verification). Supersedes ADR-036's
"DeviceTestApp adoption (deferred)" — including its misdiagnosed blocker.

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
durable corpus — not just the ≤`selfPopulateCap` (64) in-memory recall window — so the brain can recall
a relevant memory from far outside the recent window. This is a real recall-quality + perf win (1 Rust
FFI scoring call over the whole corpus vs. N Swift cosine calls over a tiny window that cannot even see
older atoms).

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
  in-memory engine + a bounded `BASGlobalRecallResolver` (NSLock-guarded, insertion-order LRU,
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

- **LRU coverage**: atoms past the cap (default 4096) fall out of global recall until re-touched. The
  durable store keeps them (no data loss) — a recall-coverage trade-off, not a durability loss.
  Cap sizing: 4096 atoms × (small atom + a ~384-float vector) ≈ tens of MB on iPhone; env-overridable.
- **Between-turns `store.allAtoms()` delta scan** is O(corpus)/turn — negligible at endurance cadence
  (one MLX inference + cooldown per turn). A `loadAtomsSince(count:)` is a deferred optimization.
- **Multi-domain recall** deferred (single recall-domain pin).
- **`cosineTopKSync` vs `globalRecall` coexistence**: `retrieve()` prefers `globalRecall`; a host that
  wires both leaves `cosineTopKSync` dead. Documented precedence; minor.
