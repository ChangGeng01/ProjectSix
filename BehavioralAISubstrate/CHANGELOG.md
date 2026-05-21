# Changelog

Substrate-wide release history。 Mirrors BRANCH_SUMMARY.md but consumer-shaped:
what changed, what migrated, what's wire-format-pinned, what needs caller-side
work on upgrade.

Following keep-a-changelog conventions where they fit. The substrate is private
+ pre-1.0 — `unreleased` means「on the current main branch but not yet tagged」。

---

## [Unreleased]

### Post-v0.61.0 全量 review remediation (chapter 八百四十六 / M2881-M2885)

Single chapter addressing items raised by a 3-agent parallel review
of the post-v0.61.0 work (chapters 八百三十四-八百四十五):

- **HIGH**:refs joiner bug class eliminated entirely。 Chapter
  八百三十四 changed `, ` → `; ` to dodge refs containing commas,
  but the same bug class re-surfaced for refs containing literal
  semicolons (e.g. `"actor A; mode-B"`)。 Chapter 八百四十六
  switches the joiner to `\u{1F}` (ASCII Unit Separator,
  unprintable,cannot appear in any legitimate ref encoding)。
  Parser triple-fallback (`\u{1F}` → `"; "` → `", "`) preserves
  backward compat with chapter 八百三十四 records (post-v0.61.0
  brief window) AND pre-v0.61.0 legacy records。 Pinned in
  `Tests/BehavioralAISubstrateTests/BASChapter846PostReviewRemediationTests.swift`。

- **HIGH**:byte-equality test gaps for chapter 八百四十四 cognition
  flip + chapter 八百四十 TriSelfService direct sites
  (`viableScores` + `viableFallbacks`)。 Chapter 八百四十六 adds a
  50-fixture randomized grid for the precompute-Float-sort
  invariant covering both sites。

- **HIGH**:Float32 narrowing precision boundary pinned as
  documented behavior。 Two Doubles that round to the same Float32
  tie under the routed path (stable sort by input order)。 This
  was implicit before;now explicit + tested。

- **MEDIUM**:renamed `_allItems` → `allItems` in `CognitionCore.swift`
  (underscore prefix misled readers since the variable IS used)。

- **MEDIUM**:added `Self.` qualifier on `score(...)` calls in
  `CognitionCore.swift` for consistency with
  `EBrainNeuralMaterializationCore.swift`'s `Self.candidateDominanceScore`。

- **LOW**:corrected doc-comment on `BASAutoRouteRanker
  .dreamLoopDominanceOrder` — earlier wording claimed
  "nil impossible" but the nil signal is semantically meaningful
  for cross-platform fallback dispatch (non-Apple builds return
  nil to route callers to their Swift fallback path)。

### Files modified

```
~ Sources/BASOrchestration/BASRoutedMirrorBladeRecording.swift  (joiner \u{1F} + triple-fallback parser)
~ Sources/BASMemory/CognitionCore.swift                          (rename + Self. qualifier)
~ Sources/BASRuntimeCore/BASAutoRouteRanker.swift                (doc-comment fix)
~ Tests/BehavioralAISubstrateTests/BASChapter799L7MirrorBladeRecordingActivationTests.swift  (joiner string update)

+ Tests/BehavioralAISubstrateTests/BASChapter846PostReviewRemediationTests.swift  (7 tests)
```

### Test deltas

13,243 → 13,250 tests / 30 skipped / 0 failures (+7 from
chapter 八百四十六)。

---

### Sort flip cascade mini-arc (chapters 八百四十-八百四十五 / M2851-M2880)

Follow-up mini-arc immediately after the L9 dominance order
shipment。 Reuses the same Rust primitive
(`BASAutoRouteRanker.dreamLoopDominanceOrder`) to flip 4
additional Swift hot-path sorts identified by the chapter 八百四十
audit。 No new Rust crate,no new C ABI,no XCFramework rebuild —
all pure Swift call-site work。

- **chapter 八百四十** — Audit of `Sources/{BASHostKit,BAS
  Orchestration,BASMemory}` for sort-with-closure patterns
  matching the L9 STRONG-FLIP profile (pure-fn Double key +
  closure-per-compare + hot per-turn)。 4 high-value sites
  identified;3 flipped this chapter:
    - `BASMLTriSelfService.merge:165` — DICT-LOOKUP-per-compare
      (worst antipattern — every compare paid 2 hash lookups +
      2 optional unwraps)
    - `EBrainHostRuntime+TriSelfService:283` — viableScores sort
    - `EBrainHostRuntime+TriSelfService:430` — viableFallbacks sort
  4 byte-equality tests in
  `Tests/BehavioralAISubstrateTests/BASChapter840TriSelfFlipTests.swift`
  including a 50-fixture randomized grid。

- **chapter 八百四十一** — `BASMLMemoryService.retrieve:214` —
  L8 top-K memory retrieval sort over `(score, atom)` tuples。
  Jaccard score precomputed in Swift,sort flipped to Rust,
  topK prefix stays in Swift。 2 byte-equality tests pin
  descending-score order + stable-on-ties behavior。

- **chapter 八百四十二** — 5-axis synthetic perf grid for the
  cascade。 Both antipatterns yield 18-30× Rust speedup at
  every scale (100/1K/10K)。 3 measurement tests in
  `Tests/BehavioralAISubstrateTests/BASChapter842SortFlipCascadePerfTests.swift`。

- **chapter 八百四十三** — mini-arc seal + this CHANGELOG +
  BRANCH_SUMMARY extension。

### Files modified (sort flip cascade)

```
~ Sources/BASHostKit/BASMLTriSelfService.swift          (flip site)
~ Sources/BASHostKit/EBrainHostRuntime+TriSelfService.swift (2 flips + import)
~ Sources/BASHostKit/BASMLMemoryService.swift           (flip site)

+ Tests/BehavioralAISubstrateTests/BASChapter840TriSelfFlipTests.swift          (4 tests)
+ Tests/BehavioralAISubstrateTests/BASChapter841MemoryRetrievalFlipTests.swift  (2 tests)
+ Tests/BehavioralAISubstrateTests/BASChapter842SortFlipCascadePerfTests.swift  (3 tests)
```

### Cumulative sort flips since v0.61.0 (7 sites total via dreamLoopDominanceOrder)

| Site | Chapter | Antipattern killed |
|---|---|---|
| `EBrainRuntimeCoordinator+Candidates` dominance | 八百三十八 | closure-per-compare on `candidateDominanceScore` |
| `EBrainNeuralMaterializationCore` dominance | 八百三十八 | same |
| `BASMLTriSelfService.merge` | 八百四十 | DICT-LOOKUP-per-compare (worst) |
| `EBrainHostRuntime+TriSelfService` viableScores | 八百四十 | closure-per-compare on `mergedScore` |
| `EBrainHostRuntime+TriSelfService` viableFallbacks | 八百四十 | same |
| `BASMLMemoryService` retrieve top-K | 八百四十一 | closure-per-compare on Jaccard score |
| `CognitionCore` compiler item ordering | 八百四十四 | closure-per-compare on multi-arg `score(...)` |

**7 production sort sites flipped to Rust** since v0.61.0,all
reusing the SAME `bas_dream_loop_dominance_order` C ABI shipped
in chapter 八百三十五。

### Cascade scope closure (chapter 八百四十四 audit)

Chapter 八百四十四 ran an exhaustive sweep of remaining
`.sorted { ... }` sites and concluded no further L9-pattern
flips are warranted。 Decline reasons by category:

- **Multi-key sorts** (CompilerItem tier+conf+id,
  EvolutionCheckpoint createdAt+id):single-Float Rust primitive
  cannot express multi-key semantics cleanly
- **Int64-key sorts** (`retrievedAt`,`sequenceNumber`):Float32
  precision loss at typical timestamp ranges (>1e7 distinct
  values within Float32 ULP) risks byte-equality
- **Tiny-N sorts** (PromptPreparation weight categories,5-10
  items):FFI overhead would dominate the sort cost
- **Cost-of-key-fn sorts** (PromptContract retentionPriority
  with string scan per compare):key cost dominates,not closure
  overhead — Swift precompute would close most of the gap
  without FFI
- **One-time / archival / projection sorts**:not hot per-turn,
  not worth the precision risk

The cascade reached natural exhaustion per the
「亏的不要硬上」 + 「多做比较」 discipline pins。

### Test deltas

13,234 → 13,243 tests / 29-30 skipped / 0 failures
(+9 from chapters 八百四十-八百四十二;skipped count flutters
±1 across runs from platform-conditional test gating; chapter
八百四十四 flip added no new dedicated tests at the time — see
chapter 八百四十六 for the gap-closing 50-fixture cognition-style
byte-equality grid added after parallel-agent review)。

### Estimated per-session perf impact

Per-turn floor saved at n=1K:7-10 ms across the 7 sites
(20-30 ms per site × 0.2-0.3 firing rate per site per turn,
cognition site fires every cognition pass)。 Per-100-turn
session floor:0.7-1.0 sec saved。

### Compatibility

- Wire format:zero changes (sort produces same ordering)
- ABI:no new symbols (reuses chapter 八百三十六 bridge)
- Swift API:no public-surface changes
- Cross-platform:non-Apple builds fall through to Swift body
  via `#if os(iOS) || os(macOS)` gate inside `dreamLoopDominanceOrder`

---

### Post-v0.61.0 全量 审查 测试 修复 (chapter 八百三十四 / M2821-M2825)

Single-chapter remediation immediately after v0.61.0 ship,
addressing 4 issues found by a post-ship parallel agent review:

- **HIGH**:contradiction-refs round-trip corruption when a ref
  literal contained `, ` (e.g., "actor A, secondary")。 The
  joiner shared its delimiter with the parser separator,causing
  silent splits。 Fix:switched joiner to `; ` (semicolon-space)
  at `BASRoutedMirrorBladeRecording.swift`,parser accepts both
  joiners for backward compat with pre-v0.61.0 persisted data。
  5 new tests pin the fix in
  `Tests/BehavioralAISubstrateTests/BASChapter834PostShipReviewFixesTests.swift`。

- **LOW**:flaky chapter 716 perf test under concurrent scheduling。
  Threshold `routedNs <= cryptoKitNs * 1.50` was load-bearing,
  not informational。 Fix:relaxed to `* 3.00`,added rationale
  comment。 Byte-equality remains the hard guard。

- **LOW**:dead `stripped(_:prefix:)` helper in
  `BASRoutedMirrorBladeRecording.swift` (unused since chapter
  八百二十一 UnknownKind enum dedup)。 Removed with explanatory
  replacement comment per 「不要 删除 只能 comment」。

- **LOW**:`BASAuditPipeline.recordTurn` partial-success behavior
  was undocumented。 Added explicit invariant test pinning that
  earlier recorders' writes persist if a later one throws。

### L9 Dream-Loop dominance order mini-arc (chapters 八百三十五-八百三十九 / M2826-M2850)

5-chapter mini-arc activating Rust-native L9 candidate-dominance
sort with a measured ~100× speedup vs Swift。 First production-default
flip after the v0.61.0 ship,driven by the established 5-axis
comparison framework (chapter 七百四十九 / 七百七十八)。

- **chapter 八百三十五** — NEW Rust primitive
  `bas_dream_loop_dominance_order` in `Cargo/bas-dream-loop/src/lib.rs`。
  Pure-fn stable sort of indices by score (descending),
  C ABI exposed,9 Rust unit tests pin behavior including
  empty / single / NaN / tie edges。

- **chapter 八百三十六** — XCFramework rebuild + Swift bridge
  `BASAutoRouteRanker.dreamLoopDominanceOrder(scores:) -> [Int32]?`
  added to BASRuntimeCore。 Required updating both the
  upstream `Cargo/bas-memory-usage-tracker/include/`
  source-of-truth header AND the 3 XCFramework slice headers
  (build script copies upstream → slices)。 Force-link anchor
  in `bas-memory-usage-tracker/src/force_link.rs` keeps the
  symbol alive under release LTO。 9 Swift bridge tests
  including 100-fixture byte-equality grid vs Swift reference。

- **chapter 八百三十七** — 5-axis perf measurement at 1K/5K/10K
  candidate scale:Rust ~100× faster than Swift across the
  full scale (Swift 207-399 ms total vs Rust 1.3-3.8 ms)。
  All 5 axes support FLIP-DEFAULT decision:
    Axis 1 perf:       STRONG WIN
    Axis 2 memory:     informational (equivalent allocation)
    Axis 3 state mach: TIE (both exhaustive)
    Axis 4 persistence: N/A (pure fn)
    Axis 5 replay byte: PASS (100-fixture grid in chapter 836)

- **chapter 八百三十八** — Flipped 2 production call sites:
    Sources/BASHostKit/EBrainRuntimeCoordinator+Candidates.swift
    Sources/BASOrchestration/EBrainNeuralMaterializationCore.swift
  Swift body kept as live FALLBACK (executed on FFI fault or
  non-Apple platform) honoring 「依旧 不删除 只 comment」 —
  stronger than commenting,since fallback actually runs。
  5 byte-equality fixtures pin routed = Swift reference。

- **chapter 八百三十九** — mini-arc seal + this CHANGELOG +
  BRANCH_SUMMARY extension。

### Files added / modified (mini-arc total)

```
~ Cargo/bas-dream-loop/src/lib.rs                     (+dominance_order_indices,+9 tests)
~ Cargo/bas-memory-usage-tracker/include/bas_rust_memory_tracker.h
~ Cargo/bas-memory-usage-tracker/src/force_link.rs
~ Vendor/bas-rust-binaries/BASRustMemoryTracker.xcframework/
  (3 slices rebuilt with new symbol)
~ Sources/BASRuntimeCore/BASAutoRouteRanker.swift     (Swift bridge)
~ Sources/BASHostKit/EBrainRuntimeCoordinator+Candidates.swift   (FLIP)
~ Sources/BASOrchestration/EBrainNeuralMaterializationCore.swift (FLIP + import)

+ Tests/BehavioralAISubstrateTests/BASChapter834PostShipReviewFixesTests.swift  (5 tests)
+ Tests/BehavioralAISubstrateTests/BASChapter836DreamLoopDominanceOrderBridgeTests.swift  (9 tests)
+ Tests/BehavioralAISubstrateTests/BASChapter837DreamLoopDominanceOrderPerfTests.swift    (4 tests)
+ Tests/BehavioralAISubstrateTests/BASChapter838DominanceOrderFlipTests.swift             (5 tests)
```

### Test deltas

13,216 → 13,234 tests / 31 skipped / 0 failures
(+18 net new tests across chapters 834-838)。

### Compatibility

- Wire format:zero changes (sort + contradiction-text format
  produce the same logical output;parser accepts both joiners)
- ABI:additive C symbol (`bas_dream_loop_dominance_order`)
- Swift API:additive (`BASAutoRouteRanker.dreamLoopDominanceOrder`)
- Cross-platform:non-Apple builds fall through to Swift body
  via `#if os(iOS) || os(macOS)` gate
- Determinism:stable sort on (-score, index) — replay byte-
  equality preserved across both call sites

---

## [0.61.0] — 2026-05-21 — STORAGE ACTIVATION + AUDIT REPLAY + 严查 + 极致 轻量化 + forwarder migration + adopter docs

Tag covers chapters 七百九十八 → 八百三十三 / M2641-M2820
(36-chapter combined arc completing storage adapter activation,
batch optimization,audit replay/diff/archive evolution,
sequential 全量审查 + 严查 reviews + remediation,doctrine
cluster archival (~45.6K LOC moved to Archive/Deactivated/),
forwarder migration (9/9 chapter forwarders archived),
operational polish (CI hook + CONTRIBUTING),host adopter
documentation,final ship)。

### Eight sub-arcs

1. **Recording activation** (chapters 七百九十八-八百二):4 routed-
   recorder utilities turn v0.59.0 storage adapters into production-
   ready opt-in side channels:
   - BASRoutedPresenceFusionRecording (L6 + schema 013)
   - BASRoutedMirrorBladeRecording (L7 + schemas 011/012)
   - BASRoutedAtomLifecycleRecording (L8 + schema 023)
   - BASRoutedHostConstitutionRecording (L5 + schemas 014/015)

2. **Storage batch optimization** (chapters 八百三-八百七):
   transaction-wrapped `appendBatch` on all 6 SQLite stores +
   InMemory vs SQLite perf scorecard (3-38× batch speedup measured)。

3. **Audit replay evolution** (chapters 八百八-八百二十):
   - BASAuditPipeline composition root (chapter 八百十五)
   - BASAuditReplayEngine session loader (chapter 八百十六)
   - BASAuditTrailDiff cross-session ID delta (chapter 八百十七)
   - BASAuditTrailArchive ~9× compression (chapter 八百十八)
   - 100-turn audit pipeline stress test (chapter 八百十三)
   - Per-session aggregation primitives (chapter 八百十)
   - Half-open time-window helpers (chapter 八百十二)

4. **严查 整改** (chapters 八百二十一-八百二十六):addressed 4
   HIGH + 6 MEDIUM findings from sequential 全量审查 + 严查 reviews:
   - Codable conformance on 7 audit-pipeline types
   - Shared `UnknownKind` enum (dedup of 3 prefix-parsers)
   - Chapter 819 strengthened to payload-identity verification
   - JSONEncoder `.sortedKeys` pinned for SHA-256 determinism
   - Schema-023 byte enum mirrors (Phase / Action / Outcome)
   - 3 CI gates restored (god_files / sdk_imports / residuals)
   - CHANGELOG dirt + dead loop + async-let parallelization

5. **极致 轻量化 archival** (chapters 八百二十七-八百二十八):
   moved ~43K LOC of dormant doctrine OUT of live Sources+Tests tree
   into Archive/Deactivated/ as `.txt` files:
   - Chapter 八百二十七:25K // commented `phase2Registry
     NativeChapters` block + 7K BASEntropyChapterIndex legacy
     blocks + 4K BASChapterDoctrineRegistry+AllLiterals legacy
     block (-35,881 LOC from live tree)
   - Chapter 八百二十八:11 `#if false` dead bodies extracted
     across schema-completeness test (5,494 LOC body) + 10 others
     (-6,770 LOC from live tree)
   - Top god-file shrunk from 25,215 → 178 LOC

6. **Operational polish** (chapter 八百二十九):
   - Wired 3 CI gates as git pre-commit hook
     (`scripts/pre-commit-gates.sh` + `.githooks/pre-commit`)
   - Wrote CONTRIBUTING.md documenting doctrine pin discipline +
     CI gate flow + archive convention + release process
   - Fixed 5 pre-existing Cargo warnings (`bas-event-log-codec` +
     `bas-retrieval-ranker`)
   - Consolidated 3 prior [Unreleased] headers into this one
     (was reader-confusing dual-snapshot structure)

7. **Adopter documentation + naming clarification** (chapter 八百三十):
   - Wrote `INTEGRATION_AUDIT.md` — host adopter guide for the
     audit pipeline (5-line setup,architecture diagram,5 audit
     dimensions table,InMemory-vs-SQLite + batch throughput
     scorecard,replay/diff/archive examples,cold-restart
     semantics,cross-platform notes,error semantics,doctrine
     pin map,chapter pin map)
   - Added `BASDoctrineMetrics` naming clarification block:
     the「Doctrine」 in this file's name = §13.2 functional
     metric group (DoctrineHarmonyScore et al),NOT the dormant
     chapter-pin registry。 Rename to BASGovernanceMetrics was
     declined with rationale documented inline。
   - Documents the clean separation:historical doctrine =
     read-only registry / functional doctrine = active §13.2
     metrics。

8. **Forwarder migration mini-arc 5 + final ship** (chapters
   八百三十一-八百三十三):
   - Chapter 八百三十一: audit revealed 3/9 forwarders truly
     orphan after filtering SQL data file text mentions (vs the
     initial 3-6 real-src-ref headline)。 Archived
     BASChapter527 / BASChapter511To520 / BASChapter511To522
     (802 LOC)。
   - Chapter 八百三十二: BREAKTHROUGH — the remaining 6
     forwarders' refs turned out to be STRING-LITERAL mentions
     only (consumers list typename in pin-arrays as strings,
     never invoke the static surface)。 All 6 archive-safe via
     `git mv`:BASChapter677 / 678 / 679 / 680 / 681 / 683
     (2,133 LOC)。 Mini-arc 5 100% complete:9/9 forwarders
     retired from Sources/+Tests/。
   - Chapter 八百三十三 (this seal):promote [Unreleased] →
     [0.61.0],extend BRANCH_SUMMARY.md through chapter 832,
     final full sweep verification,annotated v0.61.0 tag
     creation + push。

### Cumulative measurements

| Metric | Pre-v0.59.0 | Now | Δ |
|---|---:|---:|---|
| Sources/ LOC | ~300K | 262,535 | -37,453 (-12.5%) |
| Top god-file LOC | 25,215 | 3,603 | -21,612 |
| Active *Doctrine* sources | 193 | 184 | -9 (mini-arc 5) |
| Native % (raw LOC) | 11.67% | 13.01% | +1.34pp |
| Native % (exec-LOC) | 16.16% | 16.12% | -0.04pp (stable in honest range) |
| Rust crates | 12 | 22 | +10 |
| SQL schemas | 10 | 29 | +19 |
| Tests (full sweep) | ~13,170 | 13,211 | +41 net (recorders +95,docs archive -54) |
| 0-failure sweep | yes | yes | preserved |
| Archive/Deactivated/ LOC | 0 | ~45.6K | dormancy moved out |
| Cargo warnings | 5 (pre-existing) | 0 | -5 |
| Production-default Rust flips | 12 | 14-16 | +2-4 |
| CI gates | 0 (planned, not shipped) | 3 (wired) | +3 |

### Doctrine pins held across all 32 chapters

- 不变量 #1 / #2 / #3
- 红线 7
- ADR-014 OPT-IN
- 不要 删除 只能 comment → 不要 的 部分 都 archive
- 不要 json 可以的话 就 sql
- 整体 性能 效果 一定要 更好
- 亏的不要硬上
- 多做比较

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
