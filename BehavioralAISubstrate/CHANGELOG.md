# Changelog

Substrate-wide release history。 Mirrors BRANCH_SUMMARY.md but consumer-shaped:
what changed, what migrated, what's wire-format-pinned, what needs caller-side
work on upgrade.

Following keep-a-changelog conventions where they fit. The substrate is private
+ pre-1.0 — `unreleased` means「on the current main branch but not yet tagged」。

---

## [Unreleased] — STORAGE ACTIVATION + AUDIT REPLAY EVOLUTION

Tag candidate: v0.61.0 (post-evolution arc)。 Covers chapters
七百九十八 → 八百二十 / M2641-M2755 (23-chapter combined mini-arc
completing the storage-adapter activation,batch fast paths,
audit-loop closure,time-windowing,full-pipeline stress
validation,read-side replay engine,cross-session diff,
archival/compaction,and round-trip restore validation)。

Five sub-arcs:

 0. (preserved from v0.60.0 candidate scope) Recording activation
    + storage batch + audit loop + composition root + stress —
    chapters 七百九十八 → 八百十五 ship 4 recorders,6
    appendBatch methods,replay helpers,aggregation primitives,
    time-windowing,full-pipeline stress test,BASAuditPipeline
    composition root。
 1. AUDIT REPLAY EVOLUTION sub-arc (chapters 八百十六 → 八百二十):
    - BASAuditReplayEngine session loader (chapter 八百十六)
    - BASAuditTrailDiff cross-session ID delta (chapter 八百十七)
    - BASAuditTrailArchive compression (~9× reduction, chapter 八百十八)
    - Round-trip restore stress test (chapter 八百十九)
    - Mini-arc 4 seal (chapter 八百二十)

### Added — AUDIT REPLAY EVOLUTION (chapters 八百十六 → 八百二十)

The audit loop is now bidirectional:hosts can write via
`BASAuditPipeline`,read via `BASAuditReplayEngine`,diff two
trails via `BASAuditTrailDiff`,and compress old trails via
`BASAuditTrailArchive`。

| Chapter | Module | Capability | Tests |
|---|---|---|---|
| 八百十六 | BASAuditReplayEngine | loadSession / loadAndSummarize | 6 |
| 八百十七 | BASAuditTrailDiff | per-store ID delta + summaryLines | 6 |
| 八百十八 | BASAuditTrailArchive | per-turn compression (~9×) | 7 |
| 八百十九 | (test only) | 50-turn round-trip restore through SQLite | 2 |

Use cases enabled:
 - Resume audit state after process restart (existing capability
   from chapter 七百九十二 SQLite stores,now exposed via
   typed `SessionAuditTrail`)
 - Diagnose「what changed between session A and session B」
 - Verify post-replay state matches pre-replay (round-trip
   identity check at audit-trail level)
 - Bound on-device storage for long-running hosts via archival
   compression (preserves aggregate-level information,drops
   per-event detail)
 - Detect dropped/duplicated rows during on-device ↔ cloud sync
   (foundation for future device-sync arc)

---

## [Unreleased - v0.60.0 RECORDING + STORAGE BATCH (snapshot)]

Tag candidate (intermediate): v0.60.0。 Covers chapters 七百九十八
→ 八百十四 / M2641-M2725 (17-chapter combined mini-arc completing
the storage-adapter activation,batch fast paths,audit-loop closure,
time-windowing,and full-pipeline stress validation)。 Four sub-arcs:

 1. Chapters 七百九十八-八百二:Recording activation — 4 recorder
    utilities turn the v0.59.0 storage adapters from「protocol
    exists」 into「production-default-ready opt-in side channels」。
 2. Chapters 八百三-八百七:Storage batch optimization — transaction-
    wrapped appendBatch on all 6 SQLite stores + InMemory vs SQLite
    informational perf scorecard (3-38× speedup measured)。
 3. Chapters 八百八-八百十一:Audit-loop completion — per-turn
    integration test + recorder replay helpers + per-session
    aggregation primitives。
 4. Chapters 八百十二-八百十四:Query + stress + seal — half-open
    time-window helpers + 100-turn full-pipeline stress test +
    final scorecard。

### Added — Time-windowed audit queries (chapter 八百十二)

`BASRoutedAuditTimeWindow` ships per-type filters for the 6
audit record shapes (presence / unknown / contradiction-resolved
/ contradiction-unresolved / version / deletion / atom-event)。
Half-open `[startMs, endMs)` convention pinned。 `since(sinceMs:)`
shortcut equals `between(sinceMs, .max)`。 Stable filter preserves
input insertion order。 10 invariant tests cover edge cases
including the nullable `resolvedAtMs` column on schema 012。

### Added — Audit pipeline stress test (chapter 八百十三)

100-turn realistic per-session load:5 presence + 3 unknowns +
1 contradiction per turn = 900 audit records persisted through
SQLite。 Exercises the FULL pipeline (record → batch → query
→ replay → aggregate → time-window) end-to-end。 Per-channel
+ per-kind counts hit exactly 100 each as expected;time-window
slices to the middle 50 turns yield exactly 250 records;
replay of turn-42 reconstructs the original BASUnknownSet
byte-equivalent。 Completes in 0.140s。

### Added — Audit loop closure (chapters 八百八 → 八百十)

The recording loop is now FULLY CLOSED:host → recorder → store
→ query → replay → aggregate → host。 Hosts can persist audit
trails through SQLite,survive cold restart,reconstruct runtime
types,and roll up into per-session summaries without
substrate-side code paths needing modification。

| Chapter | What |
|---------|------|
| 八百八 | Per-turn integration test exercising all 4 recorders + 6 stores end-to-end (4 tests) |
| 八百九 | Recorder replay helpers — inverse functions of the encoding (channelByte↔kind,reconstructUnknownSet,reconstructContradictions) (11 tests) |
| 八百十 | Per-session aggregation primitives (PresenceSessionSummary / UnknownSessionSummary / ContradictionSessionSummary) (8 tests) |

### Added — Storage batch optimization (chapters 八百三 → 八百七)

Per-store `appendBatch` (or `appendEventBatch` / `appendVersion`-
variants) on every storage adapter pair。 SQLite path wraps N
inserts in `BEGIN IMMEDIATE; ...; COMMIT;` with a single re-used
prepared statement;InMemory path mirrors the API via per-record
loop (actor isolation suffices)。 ROLLBACK on first error keeps
the「append-only audit log」 semantic atomic per batch。

Measured speedups (200-event batches,Apple Silicon SSD):

| Store | per-call | batch | speedup |
|-------|----------|-------|---------|
| L8 atom-lifecycle (023)            | 66 μs | 16 μs | 3.8-4.1× |
| L7 unknown-ledger (011)            | ~20 μs | ~0.5 μs | 38.5× |
| L7 contradiction-ledger (012)      | — | — | (test pinned to ≥3× floor) |
| L6 presence-observations (013)     | ~30 μs | ~1.6 μs | 18.7× |
| L5 host-constitution-version-tree (014) | — | — | (test pinned to ≥3× floor) |
| L5 host-constitution-deletion (015)| — | — | (test pinned to ≥3× floor) |

Variance reflects per-store column complexity (L8 has 4 byte-to-
string mappers per row;L7 unknown has 6 primitive columns)。
Theoretical max not reached because synchronous=NORMAL still
issues fsync per WAL frame inside the transaction。

### Added — Storage InMemory vs SQLite scorecard (chapter 八百三)

Honest informational measurement (no flip rule):
- InMemory: 437-585 ns/append (O(1) array + dict index)
- SQLite (single-call): 36-62 μs/append (60-140× slower than InMemory)
- SQLite (batched, chapter 八百四+): 0.5-16 μs/append

Hosts choose per durability vs latency budget。 Both paths stay
opt-in per ADR-014。

### Added — 4 routed-recorder utilities (29 new tests)

Each recorder pairs a substrate runtime surface with a host-
supplied storage conformer。 「依旧 不删除 只 comment」 — original
runtime paths untouched;recorders are purely additive opt-in seams。

| Recorder | Pairs with | Tests |
|---|---|---|
| BASRoutedPresenceFusionRecording | L6 fuse + BASPresenceObservationStore (013) | 5 |
| BASRoutedMirrorBladeRecording | L7 BASUnknownSet/BASContradictionRecord + 011/012 stores | 8 |
| BASRoutedAtomLifecycleRecording | L8 BASAtomLifecycleBridge + 023 store | 7 |
| BASRoutedHostConstitutionRecording | L5 host-constitution mutation + 014/015 stores | 9 |

Common shape across all 4 recorders:
- Pure `record...(...)` entry point (all platforms,no Rust dep)
- Composite `...andRecord(...)` entry point where applicable
  (iOS/macOS only when paired with Rust bridge invocation)
- SQLite cold-restart proven (write → close → reopen → match)
- Doctrine-pinned defaults (per-category confidence,salience
  semantics,refs JSON encoding,etc。)

### Added — Schema-aligned enums + helpers

- `BASRoutedPresenceFusion.channelKindByByte` — schema-013 string
  array indexed by Rust `PresenceChannel` byte (task / risk /
  manipulation / environment / bodyRhythm)
- `BASRoutedMirrorBladeRecording.UnknownRecordingConfig` —
  per-category confidence overrides + init-time clamp01
- `BASRoutedMirrorBladeRecording.ContradictionRecordingConfig` —
  defaultConfidence + inlineRefs knobs
- `BASRoutedAtomLifecycleRecording.RecordingError.invalidTransitionByte`
  — fail-fast on out-of-range bridge input,store stays clean
- `BASRoutedHostConstitutionRecording.DeletionType` — schema-015
  CHECK literal enum (cascade / selective / rollback) pinned via
  rawValue mapping + exhaustive-case test

### Doctrine pins preserved

- 不要 删除 只能 comment — every recorder lives in a new file;
  no edit to existing routed paths or storage adapters
- ADR-014 OPT-IN — host supplies the store conformer (InMemory
  reference or SQLite-backed);substrate default behavior unchanged
- 不要 json 可以的话 就 sql — typed columns + JSON only for
  variadic ref arrays (target_refs / cascaded_refs / merged_from)
- 整体 性能 效果 一定要 更好 — CryptoKit SHA-256 default for L5
  signature_hash (hardware-accelerated AMX engine,~34× faster
  than software Rust path per chapter 七百四 measurement)
- 亏的不要硬上 — composite Rust+record path platform-gated to
  iOS/macOS;pure recordTransition entry point available
  cross-platform

### Test sweep

29 new tests across 4 chapter-XYZ files,all green。 No existing
test touched。 Storage adapters from v0.59.0 are now exercised
through realistic write paths,not just unit-tested scaffold。

---

## [0.59.0] — 2026-05-21 — STORAGE COMPLETION ARC

Tag covers chapters 七百八十七 → 七百九十七 / M2586-M2640
(11-chapter arc completing the full L5/L6/L7/L8 SQLite-backed
storage adapter stack)。

### Added — 6 storage adapter pairs (12 actors total)

For each of 6 ledger schemas:protocol seam +
BASInMemory*Store reference actor + BASSQLite*Store production
conformer:

| Schema | Layer | Adapter pair |
|--------|-------|--------------|
| 011_unknown_ledger_records      | L7 | unknown |
| 012_contradiction_ledger_records | L7 | contradiction |
| 013_presence_observations       | L6 | presence |
| 014_host_constitution_version_tree | L5 | version-tree |
| 015_host_constitution_deletion_manifest | L5 | deletion-manifest |
| 023_atom_lifecycle_events       | L8 | atom-lifecycle |

All SQLite stores share:
- Owned SQLite handle in actor (WAL + sync NORMAL)
- PRAGMA user_version schemaVersion branch
- Auto-applied schema from BASSQLSchemaGen-emitted constant
  (whole-blob exec to handle comment-embedded semicolons)
- Insertion-order queries (ORDER BY timestamp ASC, rowid ASC)
- Typed StorageError enum + duplicate ID detection
- Cross-mirror equivalence with InMemory reference proven

### Added — L8 atom-lifecycle storage adapter end-to-end

Built on the chapter 七百八十二-七百八十四 Rust crate + bridge +
SQL schema foundation:
- Cold-restart replay integration test through JSON snapshot
- Cold-restart through SQLite real DB (write → close → reopen
  → reconstruct identical state)

### Added — 5-axis perf framework + scale-test cascade

- BASCrossLanguagePerfHarness (chapter 七百七十八):reusable
  STRONG-FLIP/MODEST-FLIP/TIE/LOSS verdict harness
- Chapter 七百八十七 ran the 3 TIE crates from 七百七十九 at
  N=100/1000/10000:**honest negative — no new flip signals**

### Honest negative results held

- TIE re-measure at scale (chapter 七百八十七):no reproducible
  flip signal for host-constitution / lease-life / mirror-blade
  beyond noise jitter
- bas-atom-lifecycle showed 3.48× at N=100 but TIE at larger N
  → likely cache warmup,not real signal → stays opt-in

### Bug fix

- SQLite store schema-exec splitter:was using
  `.split(separator: ";")` which broke when schema comment
  headers embed semicolons in narrative text (e.g。 "Default 0;
  flipped to 1 when…")。 All 6 stores now use `sqlite3_exec` on
  the whole multi-statement blob — SQLite handles it natively。

### Architecture milestones

- **Storage adapter pairs:** 0 → 6 (full L5/L6/L7/L8 coverage)
- **SQLite-backed actors:** 0 → 6
- **Cumulative storage test surface:** 48 tests
- **「不要 删除 只能 comment」 doctrine** held throughout:
  6 InMemory reference impls remain the documented live defaults

<!--
NOTE (chapter 八百二十二 / M2761-M2765 严查 cleanup):
A stale `## [Unreleased] — Post-v0.58.0 (chapters 七百八十七-七百九十一)`
section formerly lived here。 Its content (L8 storage adapter scaffold +
TIE re-measure at scale honest-negative results + bas-atom-lifecycle
3.48× flake notes) is already documented in the `[0.59.0]` section above
(see lines「Added — 6 storage adapter pairs」 + 「Added — L8 atom-lifecycle
storage adapter end-to-end」 + 「Honest negative results held」)。

Removed per 严查 finding:duplicate [Unreleased] header confused readers
scanning for current unreleased scope。 The 4 [Unreleased]/[released] tags
in this file are now (top → bottom):
  1. [Unreleased] — STORAGE ACTIVATION + AUDIT REPLAY EVOLUTION (v0.61.0 candidate)
  2. [Unreleased - v0.60.0 RECORDING + STORAGE BATCH (snapshot)] (intermediate)
  3. [0.59.0] — STORAGE COMPLETION ARC (released)
  4. [0.58.0] / [0.57.0] / [0.56.0] / [Pre-0.56.0] (released history)
-->

---

## [0.58.0] — 2026-05-21 — POST-FLIP PRODUCTION ACTIVATION ARC

Tag covers chapters 七百七十四 → 七百八十六 / M2521-M2585
(13 follow-on chapters after v0.57.0 sealed). Theme:translate
the v0.57.0 byte-equality groundwork into actual production
defaults via empirical 5-axis perf measurement,then close the
loop with the L13 Phase 2 + L8 mini-arcs。

### Added — 2 new Rust crates (22 total)

- `bas-shadow-trial` (chapter 七百七十四) — L13 Phase 2 state
  machine port mirroring BASShadowTrialStateMachineCore byte-for-
  byte。 Adapter `BASShadowTrialRustStateMachine` conforms to
  Phase 1 protocol seam,injectable via
  `BASShadowTrialCoordinator.makeWithDefaultStateMachine`。
- `bas-atom-lifecycle` (chapter 七百八十二) — L8 memory atom
  5-phase state machine (Created → Admitted → Linked → Archived →
  Tombstoned) with 20-cell transition matrix。

### Added — 4 new SQL schemas (24 total)

- `020_shadow_trial_records` (chapter 七百七十五) — L13 trial
  audit ledger
- `021_evolution_seals` (chapter 七百七十五) — L13 seal records
- `022_retraction_orders` (chapter 七百七十五) — L13 retraction
  audit
- `023_atom_lifecycle_events` (chapter 七百八十四) — L8 atom
  phase transition event log

### Added — Swift bridge surface

- `BASInternalRustBridges.swift` (post-arc activation B,
  chapter 七百七十四 + 七百八十三):@_silgen_name bindings for
  6 internal-only crates — lease-life,mirror-blade,
  presence-eye,host-constitution,world-prior,shadow-trial,
  atom-lifecycle (+ red-team-bench via module map)
- `BASShadowTrialRustStateMachine` adapter +
  `makeWithDefaultStateMachine` factory (chapters 七百七十六 +
  七百八十一) — Rust state machine pluggable into the existing
  Swift coordinator via init param

### Added — Production-default Rust flips (4 measured-flip routes)

3 STRONG-FLIP (≥2× speedup) + 1 MODEST-FLIP (≥1.2×) — empirically
justified per the chapter 七百七十八 BASCrossLanguagePerfHarness
+ chapter 七百七十九 cascade measurement:

| Path                                    | Speedup |
|-----------------------------------------|--------:|
| `BASRedTeamBatchClassifier.classify`    | 8.71×   |
| `BASRoutedPresenceFusion.fuse`          | 7.51×   |
| `BASRoutedWorldPriorAggregation.*`      | 5.12×   |
| `BASShadowTrialCoordinator.makeWith*`   | 1.24×   |

All flips on iOS / macOS only;watchOS / Linux automatically
falls back to Swift V1 path (chapter 七百八十五 cross-platform
validation suite proves the fallbacks remain byte-equal)。

### Added — Cross-platform validation discipline

- `BASCrossLanguagePerfHarness` (chapter 七百七十八):reusable
  perf framework with typed verdict enum (STRONG-FLIP ≥2× /
  MODEST-FLIP ≥1.2× / TIE 0.83×-1.2× / LOSS <0.83×)
- 47-fixture cross-language equivalence suite (chapter 七百八十五)
  asserts Swift fallback ≡ Rust route for every production-flip
  routed path

### Changed

- XCFramework rebuilt 3 times across the arc to bundle progressively
  more crates:
  - chapter 七百七十三 第二刀:12 → 20 crates (DEEPER ARC close-out)
  - chapter 七百七十四 第一刀:20 → 21 crates (+shadow-trial)
  - chapter 七百八十三:21 → 22 crates (+atom-lifecycle)
- Final macos-arm64 slice SHA:
  `5e5bb95fa794acb8529c41903d1174f44e666c7ec17fede2564896c28811c281`
- All 3 SHA pins (BASRustCoreBridge constants + matching tests)
  bumped + tracked in commit history

### Honest negative results (held to record)

- bas-host-constitution measured **PERFECT TIE (1.00×)** at chapter
  七百七十九 — FFI overhead exactly cancels Rust compute savings。
  Stays opt-in per 「亏的不要硬上」。
- bas-lease-life (1.18×) and bas-mirror-blade (0.99×) also TIE —
  not flipped。
- Plan-agent estimates predicted TIE-or-modest for presence-eye
  and world-prior;actual measurements showed STRONG-FLIP (7.51×
  and 5.12×)。 Honest「surprise」 captured in chapter 七百七十九
  commit log。

### Architecture milestones

- **Rust crate count:** 20 → 22 (+2)
- **SQL schema count:** 19 → 24 (+5 across L13 + L8 sub-arcs)
- **Production-default Rust paths:** 12 (pre-arc) → 16
  (+4 from this arc:red-team + presence + world-prior +
   shadow-trial production factory)
- **Bridge tests:** 86 cross-language tests (52 internal +
  34 SHA pin) + 16 strong-flip equivalence + 47 cross-platform
  fallback = 149 cross-language assertions
- **「依旧 不删除 只 comment」 doctrine** held throughout:
  every Swift V1 path preserved as fallback,not deleted

---

## [0.57.0] — 2026-05-21 — DEEPER LAYER-MIGRATION ARC SEAL

Tag covers chapters 七百五十八 → 七百七十三 / M2441-M2520 (16-chapter
arc executing the 严苛结论 table per layer for the 9 remaining
migration items not covered by the prior LAYER-MIGRATION ARC)。

### Added — 8 new Rust crates

- `bas-sovereign-c-abi` (chapter 七百五十八) — public C ABI wrapper
  for L14 halt signal + integrity scan + tamper-proof audit。 First
  hand-curated C header (`include/bas_sovereign_c_abi.h`) for
  watchOS + 3rd-party C consumers。
- `bas-red-team-bench` (chapter 七百五十九) — batch adversarial-
  prompt classifier (24 red lines / 70 patterns)。 Measured 33-67×
  speedup vs Swift single-threaded baseline。 Wire-format
  `bas_red_team_classify_batch` C ABI。
- `bas-integrity-sentinel` (chapter 七百六十) — typed Rust port of
  BASSovereignIntegritySentinel with structured ScanReport output
  (richer than the bas-sovereign-c-abi thin wrapper)。
- `bas-lease-life` (chapter 七百六十二) — L1 LungStateAccumulator
  pressure decay + BreathScheduler reconcile pure-fn surface。
- `bas-mirror-blade` (chapter 七百六十四) — L7 decomposition state
  classifier (DecomposeState enum + threshold-based emit rules)。
- `bas-presence-eye` (chapter 七百六十六) — L6 signal-fusion
  classifier (5-channel salience × confidence aggregator with
  doctrine-pinned per-channel weights)。
- `bas-host-constitution` (chapter 七百六十八 + 七百六十九) — L5
  host-profile merge logic + deletion manifest classifier (6
  MergeStrategy enums + 11 FieldKind discriminants)。
- `bas-world-prior` (chapter 七百七十一) — L4 typed surface +
  evidence propagation / reversibility / latency aggregation pure
  fns (companion to 4 new SQL schemas)。

### Added — extension to existing crate

- `bas-permit-policy::rule_judgment` module (chapter 七百六十三) —
  L12 BASHostUpdatePolicy port + UpdateAction allow checks。

### Added — 2 new C system bridge probes

- `bas_wallclock_nanos` (chapter 七百六十一) — sleep-INCLUSIVE
  monotonic clock via `mach_absolute_time` + Mach timebase。
  Counterpart to existing `bas_monotonic_nanos` (sleep-excluded
  via CLOCK_UPTIME_RAW)。 Perf TIE measured (0.96-1.04× vs Swift)
  — ships opt-in via `cBridgeEnabled` flag。
- `bas_task_phys_footprint` (chapter 七百六十一) — richer
  per-process memory probe via `task_info(TASK_VM_INFO)` returning
  phys_footprint + compressed + internal bytes (no Swift V1
  equivalent)。

### Added — 9 new SQL schemas

- `011_unknown_ledger_records.sql` — L7 unknown-ledger
- `012_contradiction_ledger_records.sql` — L7 contradiction-ledger
- `013_presence_observations.sql` — L6 multi-channel signal
  persistence
- `014_host_constitution_version_tree.sql` — L5 version lineage
- `015_host_constitution_deletion_manifest.sql` — L5 deletion audit
- `016_world_priors_axioms.sql` — L4 axiom storage
- `017_world_priors_templates.sql` — L4 action template storage
- `018_world_priors_bridges.sql` — L4 cross-domain bridges
- `019_world_priors_domains.sql` — L4 custom domain registry

Total:9 schemas / 31 statements / 25 indexes。

### Added — L13 Phase 1 Swift refactor

- `BASShadowTrialPhase` enum (4 cases) + `BASShadowTrialStateMachine`
  protocol + `BASShadowTrialStateMachineCore` default impl
  (chapter 七百七十二)。 Extracts the L13 state-graph from the 687
  LOC BASShadowTrialCoordinator into a swappable protocol seam。
  Phase 2 Rust port deferred to a future arc;the coordinator
  body stays Swift through Phase 1。

### Changed

- `Cargo/Cargo.toml` workspace gained 8 new members
- `bas-memory-usage-tracker::force_link` extends with anchors for
  each new crate;`bas_substrate_bundle_crate_count()` bumped
  12 → 20。

### Architecture milestones

- **16-chapter DEEPER LAYER-MIGRATION ARC sealed** — branch
  trajectory:chapters 七百五十八-七百七十三 / M2441-M2520。
  All 9 remaining migration items from the 严苛结论 table addressed。
- **Rust crate count:12 → 20** (+8)
- **SQL schema count:10 → 19** (+9)
- **L11 sub-arc DEEPER** (red-team + GSI) shipped Rust crates +
  Swift bridges deactivated via `#if BAS_*_RUST_PATH_ACTIVE` flags
  awaiting XCFramework rebuild。
- **L1 partial sub-arc** measured perf TIE (0.96-1.04×) per
  「亏的不要硬上」 — C probes ship opt-in。

### Honest negative results (held to record)

- L1 C probes perf measurement:TIE (1.2-1.5× was the plan
  estimate;actual ranged 0.96-1.04×)。 Result:OPT-IN ship,
  not production-default flip。
- L12 rule-judgment ports kept tiny per 「L12 不适合大迁」 —
  documented as TINY scope (just BASHostUpdatePolicy port,
  4-bool struct + per-action allow check)。

### Deferred to future arcs

- **L13 Phase 2 Rust port** of ShadowTrialCoordinator state machine
  + 3 SQL schemas (shadow_trial_records / evolution_seals /
  retraction_orders) — user-chosen scope cut at plan time。
- **XCFramework rebuild** wave to activate Swift bridges that
  consume the 8 new crates。 Crates are linked into the staticlib
  via force-link anchors,but the XCFramework headers/ subdirectory
  needs maintenance-side rebuild via
  `scripts/build-rust-xcframework.sh` before Swift hosts can call
  the new C ABI symbols directly。

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
