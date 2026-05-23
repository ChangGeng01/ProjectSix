# Migration Guide: v0.61.0 → v0.62.x

Consumer-shaped migration guide for the v0.61.0 → v0.62.x upgrade。
For substrate-internal chapter history see [CHANGELOG.md](./CHANGELOG.md)。
For release-level summary see [RELEASE_NOTES.md](./RELEASE_NOTES.md)。

---

## TL;DR

| Item | Action required |
|---|---|
| Calibration cache schemaVersion | **Regenerate** — bumped 1 → 4 across chapters 757,877,879 |
| New auto-routing thresholds | Optional — defaults preserve v0.61.0 behavior at sub-threshold sizes |
| MatMul MPSGraph routing | Auto — flips at workProduct ≥ 16M (256³) |
| Batched cosine rayon | Auto — flips at corpus rows ≥ 3000 |
| Audit aggregation rayon | Auto — flips at session records ≥ 1000 |
| Decline-pending-consumer kernels | No action — audit-only |
| Forwarder migration | NEW removals — see「Removed deprecated paths」 below |

---

## Step 1: Regenerate the calibration cache

If your host pins `expectedSchemaVersion` when calling
`BASAutoRouteCalibrationStore.load(...)`,you must bump it from
**1 to 4**。 If you use the helper
`BASAutoRouteCalibrationStore.loadOrCalibrate(...)`,it will detect
the stale schema + regenerate automatically — no code change
needed,just a one-time slower first launch。

### Manual store callers

```swift
// v0.61.0
try BASAutoRouteCalibrationStore.validate(
    report,
    expectedSchemaVersion: 1,    // ← was 1
    ...
)

// v0.62.x
try BASAutoRouteCalibrationStore.validate(
    report,
    expectedSchemaVersion: 4,    // ← bump to 4
    ...
)
```

### What the bumps cover

| Bump | Chapter | New field |
|---|---|---|
| 1 → 2 | 七百三十 | (consolidation;no new field exposed to consumers) |
| 2 → 3 | 八百七十七 / M3065 | `matMulMPSGraphActorMinProduct` + `auditAggregationRayonMinRecords` |
| 3 → 4 | 八百七十九 / M3080 | `batchedCosineRayonChunkRows` |

All field additions defaulted to measured Mac mini values so loading
behavior is preserved post-regeneration。 Per-device tuning is
opt-in via the new fields。

---

## Step 2: (Optional) Adopt the new routing thresholds

All new thresholds live on `BASAutoRouteThresholds`。 Defaults are
backward-compatible: if you don't set them,you get the v0.62.x
measured Mac mini values which preserve v0.61.0 behavior for
sub-threshold workloads。

| New field | Default | Behavior |
|---|---|---|
| `matMulMPSGraphActorMinProduct` | 16_777_216 (256³) | MPSGraph executable cache for large matmuls;Rust + MSL for small |
| `auditAggregationRayonMinRecords` | 1000 | Rayon par_iter for large sessions;sequential for small |
| `batchedCosineRayonMinRows` | 3000 | Rayon par_chunks_mut for large corpora;sequential SIMD for small |
| `batchedCosineRayonChunkRows` | 64 (wired in v0.62.1) | Per-task row count for rayon worker chunks。 Tune per device |

Custom thresholds are passed in like:

```swift
let custom = BASAutoRouteThresholds(
    batchedCosineRayonMinRows: 500,    // lower threshold for large-corpus hosts
    batchedCosineRayonChunkRows: 128   // larger chunk for lower core counts
)
let r = BASAutoRouteRanker.batchedCosineSimilarity(
    query: q, corpus: c, dim: d,
    thresholds: custom)
```

If unset,`.mSeriesDefault` is used (the measured Mac mini values)。

---

## Step 3: Removed deprecated paths (NO net removals in v0.61.0 → v0.62.x)

Chapter 八百九十一.5 / M3146 honest correction:the original
placeholder + chapter 八百九十一 partial fix both incorrectly
cited chapter 八百七十八 as a forwarder-removal chapter。 In fact:

- **Forwarder migration happened in chapter 八百三十一**
  (mini-arc 5 of v0.61.0)。 9/9 forwarder shims archived → 2,133
  LOC removed。 See CHANGELOG `[0.61.0]` section line ~3593。
- **Chapter 八百七十八 did NOT remove forwarders**。 It addressed
  self-assessment concerns + 9th-pass review HIGH items
  (sweep-count drift,tearDown leaks,Cargo.lock drift)。
- **v0.62.0 → v0.62.3 removed NOTHING net** — all consumer-
  visible changes in this version range are additive (new
  fields,new optional opt-ins,one Rust default flip preserving
  byte-equality)。

**Action required if upgrading from < v0.61.0**: read the
v0.61.0 CHANGELOG section + grep your downstream code for any
`*ForwarderShim` / `*Deprecated` / `*ArchivedForwarder` symbols
that were removed in mini-arc 5。 The substrate's chapter 831
audit confirmed zero in-substrate callers,but downstream
consumers may have grown dependencies on the shims pre-v0.61.0。

**Action required if upgrading from v0.61.0 → v0.62.x**: NONE
in this category。 Symbol-removal is empty across the v0.62.x
range。 See Step 5 for the actual additive deltas。

---

## Step 4: DECLINE-PENDING-CONSUMER kernels — no action required

Chapters 874,875,876 audited 7 candidate kernels (5 `.metal` + 2
MPSGraph) and confirmed they have **0 production consumers** in the
substrate or any known downstream consumer。 They remain in the tree
+ have audit-trigger tests pinning the conditions under which a
future chapter should re-evaluate the decline。

If you have a downstream consumer with measured pressure on any
of these,file an issue with the measurement so the substrate can
schedule a wire-or-decline chapter。

---

## Step 5: v0.62.0 → v0.62.x patch deltas (chapter 八百九十一 / M3145 MEDIUM-M4 fix)

The v0.62.0 → v0.62.3 upgrade ships 3 patch tags worth of
incremental consumer-visible changes。 All are backward-compatible
+ additive — but a thorough upgrade pass should know what
changed。

### v0.62.0 → v0.62.1 (chapter 八百八十)

- **NEW** `BASAutoRouteThresholds.batchedCosineRayonChunkRows: Int = 64`
  field is now wired through Rust C ABI (chapter 879 added the
  field as a contract;chapter 880 delivered the wiring)。 Hosts
  running per-device calibration can now legitimately tune this。
  Default 64 preserves chapter 872 byte-equality。
- NO schemaVersion bump beyond chapter 879's 3→4 (chapter 880 reused
  the existing field)。

### v0.62.1 → v0.62.2 (chapters 八百八十一-八百八十四)

- **NEW** `BASCognitiveOSBundleOptions.enableRAGRetrieval: Bool = false`
  flag (chapter 882 Gap 2 carrier)。 Codable-safe via chapter 891
  custom `init(from:)` that uses `decodeIfPresent ?? false` for
  every field including this new one — pre-v0.62.2 persisted JSON
  loads cleanly。
- **NEW** `BASCognitiveOSBundle.embeddingProvider: (any
  BASMemory.BASEmbeddingProvider)?` slot + new builder overload
  `BASCognitiveOSBuilder.build(options:embeddingProvider:)`。
- Bundle's `populatedCount` IGNORES the RAG slots (routing
  hints,not primitives)。
- NO schemaVersion bump (Bundle/Options are routing hints,not
  versioned data)。

### v0.62.2 → v0.62.3 (chapters 八百八十五-八百八十九)

- **CONSUMER-VISIBLE BEHAVIOR CHANGE** (chapter 888):
  `BASBadToneLinter.lint(inputs:)` now routes through Rust by
  default on iOS / macOS (chapter 889 LIVE measurement: 7.32-
  7.45× faster across input batch sizes 10/100/1000)。 Swift
  fallback preserved as
  `BASBadToneLinter.lintViaSwiftFallback(inputs:)` for:
  - watchOS / Linux (no XCFramework slice)
  - Hosts that explicitly opt out
  - Cross-language byte-equality tests
  Byte-equality across all 23 BadTone substrings is pinned by
  `BASChapter891ReviewFixTests.testMEDIUM3_AllTwentyThree
  SubstringsByteEqual`。 If your host called `BASBadToneLinter
  .lint(...)` and depended on the EXACT Swift iteration order
  (rule-major within prompt vs Rust's RedLineId-discriminant-
  major),switch to `lintViaSwiftFallback` to preserve order。
- **NEW** `BASRAGRetriever.resolveCandidatesSync(...)` — sync
  Stage-4 helper for the RAG pipeline (chapter 886 Trigger C
  for chapter 883 DECLINE)。 Hosts that pre-compute embeddings
  + top-k candidates can now resolve atoms synchronously
  without async boundaries。
- **NEW** Rust crate-level `forget_cascade_filter_batch_rayon`
  in `bas-retrieval-ranker` (chapter 885)。 No FFI yet — the
  Rust kernel waits for a consumer that batches ≥ 512 cascades
  per call (chapter 885 measurement showed 2.28× win at
  batch=1024)。
- bas-red-team-bench `RedLineId::ALL` extended 24 → 30 with
  BadTone IDs 0x40-0x45 (chapter 887)。 Existing callers of
  `BASRedTeamBatchClassifier.classify(prompts:)` now ALSO
  receive BadTone matches in their output。 The decoder
  defensively handles unknown red-line IDs (chapter 759 V1 ABI
  design) so this is non-breaking,but consumers that switch
  on `redLineId` should add a `default:` arm or `case 0x40
  ...0x45:` BadTone handling。

### v0.62.3 → [Unreleased] (chapters 八百九十 + 八百九十一)

- **NEW** `BASRedTeamBatchClassifier.classifyViaRustOrNil
  (prompts:)` public method (chapter 891 HIGH-1 fix) returning
  Optional so callers can detect Rust failure。 Existing
  `classify(...)` still works unchanged。
- `BASBadToneLintBridge.lintViaRust(...)` now correctly routes
  to BadTone-aware Swift fallback on Rust failure (chapter 891
  HIGH-1 fix — pre-chapter-891 silently dropped all BadTone
  violations on Rust failure)。
- `BASRAGRetriever.resolveCandidatesSync(...)` no longer traps
  on negative `k` (chapter 891 HIGH-2 fix — clamps to 0 +
  emits new reason code)。
- `BASCognitiveOSBundleOptions` Codable decoder is
  backward-compatible for any pre-v0.62.2 persisted JSON
  (chapter 891 HIGH-1 cross-arc fix)。

## Verification after upgrade

Run the substrate's standard gates against your consumer:

```bash
# In substrate root
swift build                                # must succeed
swift test 2>&1 | grep "Executed [0-9]"    # must show 0 failures
bash scripts/pre-commit-gates.sh           # must show 3/3 PASS

# In your consumer
<your test command>                        # your suite must still pass
```

If your consumer's suite regresses after the upgrade and you've
performed Step 1 (cache regeneration),file an issue with the
failing test name + the diff between v0.61.0 + v0.62.x state。 The
substrate's 14-pass review discipline (chapters 八百六十七 → 八百八十)
treated regressions as HIGH-severity gates so an unexpected
regression in your consumer is information the substrate wants。

---

## Rollback

If you need to roll back to v0.61.0:

1. Revert your dependency pin to `v0.61.0`。
2. Delete the calibration cache file (path varies by host;
   typically `~/Library/Caches/.../bas-autoroute-calibration.json`)。
3. v0.61.0 will regenerate the cache at schemaVersion 1。

No data migration is required — the cache file format is
versioned per the schemaVersion field,not stamped into the data
shape itself,so a fresh v0.61.0 cache will coexist with leftover
v0.62.x cache files in adjacent directories without confusion。

---

## Questions

- For substrate-history detail (per-chapter knife list): see
  [CHANGELOG.md](./CHANGELOG.md)
- For release-level summary: see [RELEASE_NOTES.md](./RELEASE_NOTES.md)
- For arc-shape + review-pass discipline: see `BRANCH_SUMMARY.md`
