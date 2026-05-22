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

## Step 3: Removed deprecated paths (chapter 八百七十八)

v0.62.0 removed forwarder shims that chapter 八百七十八 audited as no
longer in use。 If your host depends on any of these,you must
migrate to the new entry point。

| Removed | Replacement |
|---|---|
| (See chapter 八百七十八 in CHANGELOG for the exact list) | (See chapter 八百七十八 in CHANGELOG) |

The substrate's own test sweep + 3-agent reviews confirmed no
in-repo callers remained。 If your repository is a downstream
consumer,grep your codebase for the removed symbol names before
upgrading。

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
