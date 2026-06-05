# ADR-036 — L8 retrieve cosineTopK hot-path takeover (host-injected, opt-in, NON-byte-equal)

## Status

Shipped (ch1040 WS3) — **the only sanctioned non-byte-equal path in the substrate**, gated behind a
host-injected seam (default-off ⇒ byte-equal). Operator-decided (the perf-fast option, explicitly over
the byte-equal alternative).

## Context

The ch1040 audit follow-up flagged: *"L8 retrieve is still not the `BASRoutedVectorIndexStorage.cosineTopK`
hot-path takeover."* The L8 `retrieve` (sync, ch883) scored **every** snapshot atom in Swift (N FFI cosine
calls) + sorted, while the index already had an integrated `cosineTopK` (1 FFI call, scores computed in
Rust/SQLite). The operator chose the **perf-fast** takeover (accepting a documented semantic change) over a
byte-equal one.

## The blocker (not in the original plan)

`cosineTopK` returns **rowids**, and `retrieve` must return a `BASMemoryBundle` of **atoms** — but the FFI
surface had **no rowid→atom_id resolution** (`upsert` returns only a return-code, not the assigned rowid;
`read_embedding_for_atom` is atom_id→embedding, forward only). So the takeover was impossible on the Swift
side alone. The Explore agent + the plan both assumed a map existed; it didn't.

## What landed

- **Rust FFI** (`Cargo/bas-l8-engine/src/vector_index.rs`): `atom_id_for_rowid(conn, rowid) -> Option<String>`
  + `bas_l8_vector_index_atom_id_for_rowid` (probe-mode buffer FFI, the reverse of
  `read_embedding_for_atom`). C header decl added. **XCFramework rebuilt** (ios-arm64 + ios-arm64-sim +
  macos-arm64) via `scripts/build-rust-xcframework.sh`.
- **Index accessor** (`BASRoutedVectorIndexStorage`): a `nonisolated` sync
  `cosineTopKAtomIDsSync(forDomain:query:k:) -> [(atomID, score)]` — **1 topK FFI call + K rowid→atom_id
  lookups** (K≪N corpus). `nonisolated` because the underlying FFIs are **synchronous** (the actor only
  wrapped them for isolation), so a sync caller respects **ch883** (retrieve stays sync). It reads
  `enginePtr` directly (already `nonisolated(unsafe) let`, as `deinit` does).
- **Service seam** (`BASL8RoutedMemoryService`): an OPTIONAL host-injected
  `cosineTopKSync: (@Sendable ([Float], Int) -> [(atomID, score)])?`. **nil ⇒ the orchestrated score-all
  path (byte-equal-off, ADR-014 default)**; when wired, `retrieve` ranks via the seam + maps the returned
  atom_ids to snapshot atoms (an atom_id outside the recall window is skipped), then applies the SAME
  floor + constitution filter + final top-K.
- **Factory-path threading** (`BASRoutedMemoryPersistence.cosineTopKSync` → `resolveMemoryService` → the
  service): the opt-in is now reachable via the standard `makeWithDefaults(memoryPersistence:)` host path
  (previously settable only by constructing `BASL8RoutedMemoryService` directly). nil default ⇒
  byte-equal-off, so every host that doesn't elect it is unchanged.

## Why this is NON-byte-equal (honest — the accepted semantic change)

The root cause: the index truncates to top-K **inside the engine, ordered by (score DESC, rowid)**, BEFORE
the Swift floor/constitution filter — whereas the score-all path scores the full corpus, filters, and only
then truncates. Both paths apply the SAME final `score DESC, atomID ASC` sort to whatever survives, so the
difference is purely in *which atoms are members of* the top-K, never an independent reordering of the
returned bundle. Two consequences:
1. **Tie membership at the K-th boundary**: at equal cosine scores the engine keeps the lower **rowid**,
   while the score-all path keeps the lower content-derived **atomID** (the 红线 byte-determinism order). A
   tie straddling the K-th cut can therefore surface a different atom.
2. **Pre-filter truncation**: an atom the score-all path would have reached deeper for (once the floor /
   constitution filter removed higher-scored-but-filtered atoms) may fall outside the engine's pre-filter
   top-K and never be considered at all.

These are accepted (the operator chose perf-fast). The path is therefore **opt-in only** — the library
default (`makeWithDefaults`, nil seam) keeps the byte-deterministic score-all path, so ADR-014 / 红线 7 hold
for every host that doesn't elect it.

## Concurrency contract

The sync accessor bypasses the actor's serialization (reads `enginePtr` directly). The caller MUST
guarantee no concurrent `upsert`/`remove` during the call. The L8 retrieve hot path satisfies this by
**turn-phase separation**: `retrieve` runs synchronously WITHIN a turn; the durable `upsert`/drain runs
asynchronously BETWEEN turns — never overlapping (the host awaits them in sequence).

## Verification

`swift build` green. `BASChapter1062CosineTopKAtomIDsTests` (3 — rowid→atom_id resolution against
deterministic strictly-distinct scores, sync-vs-async score parity, empty-domain safety).
`BASCognitiveBrainCascadeDigestTests` (6) **byte-equal with the seam nil** (the default), proving
byte-equal-off. `BASChapter900VectorIndexByteEq` + `BASChapter906HotPathConsolidation` (the perf baseline) +
the L8 cross-restart suites green. New XCFramework symbol exported (`nm`).

## Honest scope / follow-ups

- **Ships:** the FFI + accessor + opt-in service seam + correctness tests. The default stays byte-equal-off.
- **Perf shape:** 1 topK FFI call + K cheap single-row rowid→atom_id lookups (K≪N) — the dominant N-scoring
  moves into the index. (A single-call atom_id-returning topK would shave the K lookups but needs a
  batch-string ABI; deferred as not worth the complexity at small K.)
- **Domain scoping:** the seam closure owns the domain choice (the index's cosineTopK is per-domain; the
  host wires it for the domain(s) it recalls from).
- **DeviceTestApp adoption (deferred, honest):** the plan's WS3 assumed the app's durable index
  (`BASSQLiteVectorIndexStorage`) could back the seam — it can't: that store is pure sqlite3 with **no
  cosineTopK engine** (the engine lives only on `BASRoutedVectorIndexStorage`, a different actor with a
  different read API + on-disk schema). So DeviceTestApp leaves the seam **nil (byte-equal-off)**. Real
  adoption requires backing it with a routed index for the recall domain **and** re-proving the
  ch1063/ch1064 cross-restart durability **on-device** (the sim build links fail environmentally, so it
  can't be runtime-verified here). Swapping a load-bearing durable backend on a change I can't
  runtime-verify is declined per 亏的不要上 / R1 — the seam ships **adoptable** (threaded through the
  standard factory path) with the exact remaining on-device step recorded. This is the SECOND incorrect
  premise the plan's WS3 carried (the first was the missing rowid→atom_id map, fixed by the new FFI).
