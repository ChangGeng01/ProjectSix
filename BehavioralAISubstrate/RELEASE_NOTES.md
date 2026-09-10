# BehavioralAISubstrate — Release Notes

Consumer-shaped release notes。 For substrate-internal chapter history see
[CHANGELOG.md](./CHANGELOG.md)。 For migration steps between versions see
[MIGRATION_GUIDE_v0.61_to_v0.62.md](./MIGRATION_GUIDE_v0.61_to_v0.62.md)
(and successor guides as they ship)。

---

## v0.62.3 — 2026-05-23 — Discovery-driven extensions + BadTone Rust flip

**Theme**: Discovery agent post-v0.62.2 surfaced
`BASBadToneLinter` as the HIGH-confidence remaining Swift→Rust
migration candidate。 Chapters 八百八十五-八百八十九 ship the flip。

### What changed for consumers

- **BASBadToneLinter.lint() routes through Rust by default**
  (chapter 888): on iOS / macOS the production default is now
  the Rust path via `BASBadToneLintBridge.lintViaRust`。 LIVE
  measurement (chapter 889): Rust 7.32-7.45× faster than Swift
  across input batch sizes 10/100/1000。 Swift fallback preserved
  as `lintViaSwiftFallback` for watchOS / Linux + opt-out。
- **NEW `BASRAGRetriever.resolveCandidatesSync(...)`** (chapter
  886): sync Stage-4 helper for the RAG pipeline。 Hosts that
  pre-compute embeddings + top-k candidates can resolve atoms
  synchronously without async boundaries (closes chapter 883
  Trigger C decline)。
- **NEW Rust crate-level `forget_cascade_filter_batch_rayon`**
  (chapter 885): pure-Rust batched cascade kernel for future
  consumers that batch ≥ 512 cascades per call。 No FFI yet —
  awaits consumer pressure (DECLINE-PENDING-CONSUMER per
  ch 874/875 pattern)。
- **`bas-red-team-bench` extended with BadTone category**
  (chapter 887): RedLineId::ALL bumped 24 → 30, +23 forbidden
  substrings, XCFramework rebuilt。

### Action required for upgrade

- **None for default callers** — Rust + Swift produce byte-
  equal violations (pinned by chapter 891 全23 substring test)。
- **For callers who depend on Swift iteration order** (rule-
  major within prompt): switch from
  `BASBadToneLinter.lint(...)` to `BASBadToneLinter
  .lintViaSwiftFallback(...)` explicitly。
- **For callers of `BASRedTeamBatchClassifier.classify(...)`**:
  output now also includes BadTone matches (0x40-0x45)。 The
  decoder defensively handles unknown IDs (chapter 759 V1 ABI
  design),so this is non-breaking,but add a `default:` or
  `case 0x40 ... 0x45:` arm if you switch on `redLineId`。

---

## v0.62.2 — 2026-05-23 — 5-gap audit + Gap 2 RAG carrier

**Theme**: User-surfaced 5 architectural gaps after v0.62.1
ship。 User-selected scope:「Gaps 2+3 ship,Gaps 1+4+5 DECLINE」。

### What changed for consumers

- **NEW `BASCognitiveOSBundleOptions.enableRAGRetrieval: Bool
  = false`** flag + **NEW `BASCognitiveOSBundle.embeddingProvider:
  (any BASMemory.BASEmbeddingProvider)?`** slot (chapter 882
  Gap 2 carrier)。 ADR-014 OPT-IN — default false preserves
  pre-v0.62.2 behavior。
- **NEW `BASCognitiveOSBuilder.build(options:embeddingProvider:)`**
  overload accepts host-supplied embedding provider。 Existing
  `build(options:)` overload preserved + delegates with `nil`。
- **Gap 3 forget cascade Rust path stays OFF** (chapter 881
  measured DECLINE — Swift Set wins 2-3× at every production
  size 10×1 → 10K×1K)。 No consumer change required。
- **Gap 2 wiring deferred** (chapter 883 DECLINE — async/sync
  protocol mismatch requires substrate-wide refactor;chapter
  886's `resolveCandidatesSync` is the side-step path)。
- **Gaps 1+4+5 DECLINE-WITH-TRIGGER** (chapter 884 audit —
  Rust SQLite ownership + Provenance lineage ledger + Sharded
  multi-writer all declined with per-gap trigger conditions
  documented)。

### Action required for upgrade

- **None for default callers** — all changes additive。
- **For callers that persist `BASCognitiveOSBundleOptions`
  as JSON** (e.g。 chapter 七百三十 Codable surface): chapter
  891 added a custom `init(from:)` using `decodeIfPresent ??
  false` for every field — pre-v0.62.2 JSON loads cleanly。
  Pre-chapter-891 had a backward-compat bug (synthesized
  decoder would throw `keyNotFound("enableRAGRetrieval")` on
  old payloads)。 Upgrade to v0.62.3+ to get the fix。

---

## v0.62.1 — 2026-05-23 — 全面收尾 — CHUNK_ROWS wiring + release docs

**Theme**: Deliver the chapter 879 promised CHUNK_ROWS contract
+ ship consumer-shaped release docs。

### What changed for consumers

**Theme**: 全面收尾 — fulfill chapter 八百七十九's CHUNK_ROWS forwarding
promise + ship release docs。

### What changed for consumers

- **Per-device tunable batched-cosine parallelism**: The
  `BASAutoRouteThresholds.batchedCosineRayonChunkRows` field (added in
  v0.62.0 / chapter 879 as a contract) is now WIRED through to the
  Rust rayon worker chunk size。 Hosts running per-device calibration
  can now legitimately set this to tune parallel-task granularity per
  CPU。 Default (=64) preserves byte-equality with v0.62.0 behavior。
- **No schema bump**: `BASAutoRouteCalibrationReport.schemaVersion`
  stays at **4** (the v0.62.0 value)。 Existing v0.62.0 caches load
  cleanly into v0.62.1。
- **No breaking API changes**。 The Swift bridge signature
  (`BASAutoRouteRanker.batchedCosineSimilarity(...)`) is unchanged —
  the new parameter flows through the existing `thresholds` arg。

### Action required for upgrade

**None。** Default chunk_rows = 64 is byte-equal to v0.62.0 behavior。
If you maintain your own calibration store,you may now legitimately
tune `batchedCosineRayonChunkRows` based on device measurement;
existing stores remain valid。

### Tests added

- `BASChapter880ChunkRowsWiringTests` (4 tests) pinning byte-equality
  across `[1, 8, 32, 64, 128, 512, 1024]` chunk values + Rust-side
  clamp invariants (0 → 1, > 4096 → 4096) + default value pin。

### Deferred to v0.62.2

- Sample integration for the DECLINE-PENDING-CONSUMER MPSGraph
  kernels (RMSNorm,RoPE)。 Substrate-side wiring exists;a
  downstream consumer with measured pressure is the gate per
  「亏的不要硬上」 discipline。

---

## v0.62.0 — 2026-05-22 — MIGRATION ARC SEAL

**Theme**: Swift → Rust/MPSGraph migration arc (chapters 871-879)
shipped + audit-only resolution of deferred items。

### What changed for consumers

- **NEW MatMul routing via MPSGraph executable cache** (chapter 871):
  `BASCognitiveBrain.mpsGraphMatMul(...)` available。 Auto-router
  flips to it at workProduct ≥ `matMulMPSGraphActorMinProduct`
  (default 16M = 256³)。 Measured 1.07-1.38× over MSL custom kernel
  at 256³+ on Mac mini。 Below threshold,Rust + MSL paths remain。
- **NEW batched cosine rayon path** (chapter 872): wired for corpus
  rows ≥ `batchedCosineRayonMinRows` (default 3000)。 Measured 1.74×
  over sequential SIMD at 5K rows × dim=384,261-356× over Swift
  per-pair。 Below threshold,sequential SIMD remains。
- **NEW audit aggregation rayon paths** (chapter 873):
  `BASRoutedAuditAggregation` presence / unknown / contradiction
  aggregations all rayon-backed for sessions ≥
  `auditAggregationRayonMinRecords` (default 1000)。
- **MPSGraph RoPE + RMSNorm DECLINED-PENDING-CONSUMER** (chapters
  874,875): kernels exist + audit tests pin trigger conditions for
  re-evaluation。 No consumer change required。
- **5 scaffolding `.metal` kernels + 2 unwired MPSGraph kernels
  re-audited DECLINED** (chapter 876): same DECLINE-PENDING-CONSUMER
  pattern。 No consumer change required。
- **Calibration schemaVersion 1 → 4** (across chapters 757,877,
  879): three field additions across the arc bumped the schema。
  Old caches must be regenerated (calibrate-or-load will do this
  automatically on first load failure)。

### Action required for upgrade

- **Delete + regenerate calibration cache** on first upgrade if your
  host pins `expectedSchemaVersion`。 The
  `BASAutoRouteCalibrationStore.loadOrCalibrate(...)` helper handles
  this automatically if you use it,but custom store callers should
  bump their expected version。 See MIGRATION_GUIDE for exact path。
- **No breaking API removals**。 All new routing paths additive
  via `BASAutoRouteThresholds`;defaults preserve pre-arc behavior
  for sub-threshold workloads。

### Substrate test stats at v0.62.0

- **13,382 tests pass / 75 skipped / 0 failures**
- 14-pass review discipline ledger documented in chapter ledger
  (see `Tests/.../BASChapter879*AuditTests.swift` for the meta-
  discipline pins)

### Deferred to v0.62.1+ (delivered in v0.62.1)

- CHUNK_ROWS field forwarded through to Rust C ABI (delivered as
  chapter 880 — v0.62.1)
- Sample integration for the decline-pending-consumer MPSGraph
  kernels (deferred to v0.62.2 per 14th-pass reviewer)

---

## v0.61.0 — 2026-05-21 — STORAGE ACTIVATION + AUDIT REPLAY

(See [CHANGELOG.md `[0.61.0]` section](./CHANGELOG.md) for full
detail。 Highlights: storage layer activation,audit replay,forwarder
migration,adopter docs。)

### What changed for consumers

- Storage layer activated end-to-end。
- Audit replay flow available for postmortem analysis。
- Forwarder migration completed (deprecated paths removed in v0.62.0
  per chapter 八百七十八)。

---

## Versioning policy

- **Patch (`v0.62.1`)**: additive,non-breaking,no schema bump。
- **Minor (`v0.62.0`)**: may add fields,bump schemas,deprecate
  paths。 Breaking removals scheduled separately。
- **Major (`v1.0.0`)**: NOT YET CUT。 Pre-1.0 substrate;`v0.62.x`
  series is the current production tag line。

---

## Verification before consuming a new version

Per substrate discipline run:

```bash
swift build                                # must succeed
swift test 2>&1 | grep "Executed [0-9]"    # must show 0 failures
bash scripts/pre-commit-gates.sh           # must show 3/3 PASS
```

If any gate fails on a fresh checkout of a tagged version,file an
issue with the failing output。 The substrate's tag lines are
expected to pass these gates at commit time per the chapter ledger
(see CHANGELOG `Verification` sub-sections per chapter)。
